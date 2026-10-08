package com.tomassirio.wanderer.wanderer_frontend

import android.annotation.SuppressLint
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.Service
import android.content.ContentValues
import android.content.Context
import android.content.Intent
import android.database.sqlite.SQLiteDatabase
import android.location.Location
import android.os.Build
import android.os.IBinder
import android.os.Looper
import android.util.Log
import androidx.core.app.NotificationCompat
import androidx.core.content.ContextCompat
import com.google.android.gms.location.FusedLocationProviderClient
import com.google.android.gms.location.LocationCallback
import com.google.android.gms.location.LocationRequest
import com.google.android.gms.location.LocationResult
import com.google.android.gms.location.LocationServices
import com.google.android.gms.location.Priority
import java.util.UUID

/**
 * The foreground service that records the live trip's track.
 *
 * While running it keeps the process out of Doze (so the WorkManager sync
 * chain in Dart fires on time) and, when it knows the trip id, records GPS
 * fixes with the fused provider. Fixes arrive in hardware batches (the CPU
 * sleeps in between) and are inserted into `track_points` in
 * `wanderer_track.db`; the Dart TrackSyncService uploads them.
 *
 * It shows a persistent "[name] · Live" notification, which the Dart side
 * replaces (same ID) with the full live-trip one.
 *
 * Lifecycle:
 *  - [ACTION_START] starts it, or restarts recording with a new profile.
 *  - [ACTION_STOP] stops recording and the service (rest / pause / finish).
 *  - Returns [START_STICKY] so Android restarts it after a low-memory kill;
 *    trip name, id and profile are recovered from SharedPreferences.
 */
class TripTrackingService : Service() {

    companion object {
        const val ACTION_START = "com.tomassirio.wanderer.ACTION_START_TRACKING"
        const val ACTION_STOP = "com.tomassirio.wanderer.ACTION_STOP_TRACKING"
        const val EXTRA_TRIP_NAME = "trip_name"
        const val EXTRA_TRIP_ID = "trip_id"
        const val EXTRA_PROFILE = "profile"

        private const val NOTIFICATION_ID = 9001
        private const val CHANNEL_ID = "trip_tracking_channel"

        /**
         * SharedPreferences file used by the Flutter `shared_preferences` plugin.
         * Keys are prefixed with "flutter." by that plugin.
         *
         * The base key name ("active_trip_name_for_updates") must stay in sync
         * with [_activeTripNameKey] in background_update_manager.dart.
         */
        private const val FLUTTER_PREFS = "FlutterSharedPreferences"
        private const val PREFS_TRIP_NAME_KEY = "flutter.active_trip_name_for_updates"
        private const val PREFS_TRIP_ID_KEY = "flutter.active_trip_id_for_updates"
        private const val PREFS_PROFILE_KEY = "flutter.active_recording_profile"

        private const val TAG = "TripTrackingService"
        private const val DB_NAME = "wanderer_track.db"

        /**
         * Recorder knobs per profile ("LIVE" / "SAVER"). The sync knobs
         * (upload interval, auto check-in) live in recording_profile.dart.
         */
        fun locationRequest(profile: String?): LocationRequest = when (profile) {
            "LIVE" -> locationRequest(intervalMs = 10_000, minDistanceM = 10f, maxDelayMs = 60_000)
            else -> locationRequest(intervalMs = 120_000, minDistanceM = 25f, maxDelayMs = 15 * 60_000)
        }

        private fun locationRequest(intervalMs: Long, minDistanceM: Float, maxDelayMs: Long) =
            LocationRequest.Builder(Priority.PRIORITY_HIGH_ACCURACY, intervalMs)
                .setMinUpdateDistanceMeters(minDistanceM)
                .setMaxUpdateDelayMillis(maxDelayMs)
                .build()

        /**
         * Opens the track DB shared with the Dart TrackStore (sqflite, same
         * file). Keep the schema in sync with TrackStore._open; neither side
         * uses user_version.
         */
        fun openTrackDb(context: Context): SQLiteDatabase =
            context.openOrCreateDatabase(DB_NAME, Context.MODE_PRIVATE, null).apply {
                execSQL(
                    "CREATE TABLE IF NOT EXISTS track_points(" +
                        "id TEXT PRIMARY KEY, trip_id TEXT NOT NULL, lat REAL NOT NULL, " +
                        "lon REAL NOT NULL, accuracy_m REAL, altitude_m REAL, " +
                        "recorded_at INTEGER NOT NULL, synced INTEGER NOT NULL DEFAULT 0)"
                )
                execSQL(
                    "CREATE INDEX IF NOT EXISTS track_points_trip " +
                        "ON track_points(trip_id, recorded_at)"
                )
            }
    }

    private val fused: FusedLocationProviderClient by lazy {
        LocationServices.getFusedLocationProviderClient(this)
    }
    private var trackDb: SQLiteDatabase? = null
    private var locationCallback: LocationCallback? = null

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        if (intent?.action == ACTION_STOP) {
            stopRecording()
            stopForegroundCompat()
            stopSelf()
            return START_NOT_STICKY
        }

        // Prefer the intent; fall back to SharedPreferences so the service
        // is correct when Android restarts it (START_STICKY, null intent).
        val prefs = getSharedPreferences(FLUTTER_PREFS, Context.MODE_PRIVATE)
        val tripName: String = intent?.getStringExtra(EXTRA_TRIP_NAME)
            ?: prefs.getString(PREFS_TRIP_NAME_KEY, null)
            ?: "Trip"
        val tripId = intent?.getStringExtra(EXTRA_TRIP_ID)
            ?: prefs.getString(PREFS_TRIP_ID_KEY, null)
        val profile = intent?.getStringExtra(EXTRA_PROFILE)
            ?: prefs.getString(PREFS_PROFILE_KEY, null)

        createNotificationChannel()
        startForeground(NOTIFICATION_ID, buildNotification(tripName))

        if (tripId != null) startRecording(tripId, profile)

        return START_STICKY
    }

    override fun onBind(intent: Intent?): IBinder? = null

    override fun onDestroy() {
        stopRecording()
        trackDb?.close()
        trackDb = null
        super.onDestroy()
    }

    // -------------------------------------------------------------------------
    // Recording
    // -------------------------------------------------------------------------

    /** (Re)starts location updates for [tripId] with [profile]'s request. */
    @SuppressLint("MissingPermission") // granted before Dart starts tracking
    private fun startRecording(tripId: String, profile: String?) {
        stopRecording()
        val db = trackDb ?: openTrackDb(this).also { trackDb = it }
        val callback = object : LocationCallback() {
            override fun onLocationResult(result: LocationResult) {
                insertPoints(db, tripId, result.locations)
            }
        }
        try {
            fused.requestLocationUpdates(locationRequest(profile), callback, Looper.getMainLooper())
            locationCallback = callback
            Log.d(TAG, "Recording trip $tripId with profile $profile")
        } catch (e: SecurityException) {
            Log.w(TAG, "No location permission; not recording", e)
        }
    }

    private fun stopRecording() {
        locationCallback?.let { fused.removeLocationUpdates(it) }
        locationCallback = null
    }

    // ponytail: inserts on the main thread; a batch is a few dozen rows at
    // most. Move to a background executor if deliveries ever get large.
    private fun insertPoints(db: SQLiteDatabase, tripId: String, locations: List<Location>) {
        try {
            db.beginTransaction()
            try {
                for (loc in locations) {
                    db.insert("track_points", null, ContentValues().apply {
                        put("id", UUID.randomUUID().toString())
                        put("trip_id", tripId)
                        put("lat", loc.latitude)
                        put("lon", loc.longitude)
                        if (loc.hasAccuracy()) put("accuracy_m", loc.accuracy.toDouble())
                        if (loc.hasAltitude()) put("altitude_m", loc.altitude)
                        put("recorded_at", loc.time)
                        put("synced", 0)
                    })
                }
                db.setTransactionSuccessful()
            } finally {
                db.endTransaction()
            }
        } catch (e: Exception) {
            Log.e(TAG, "Could not store ${locations.size} points", e)
        }
    }

    // -------------------------------------------------------------------------
    // Helpers
    // -------------------------------------------------------------------------

    private fun createNotificationChannel() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val channel = NotificationChannel(
                CHANNEL_ID,
                "Live trip",
                NotificationManager.IMPORTANCE_LOW,
            ).apply {
                description = "Shown while a trip is live, with Check in, Pause and Rest"
                setShowBadge(false)
                setSound(null, null)
            }
            val manager = getSystemService(NOTIFICATION_SERVICE) as NotificationManager
            manager.createNotificationChannel(channel)
        }
    }

    private fun buildNotification(tripName: String) =
        NotificationCompat.Builder(this, CHANNEL_ID)
            .setSmallIcon(R.drawable.ic_stat_wanderer)
            .setColor(ContextCompat.getColor(this, R.color.notification_color))
            .setContentTitle(tripName)
            .setContentText("Live")
            .setOnlyAlertOnce(true)
            .setPriority(NotificationCompat.PRIORITY_LOW)
            .setOngoing(true)
            .setCategory(NotificationCompat.CATEGORY_SERVICE)
            .build()

    @Suppress("DEPRECATION")
    private fun stopForegroundCompat() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.N) {
            stopForeground(STOP_FOREGROUND_REMOVE)
        } else {
            stopForeground(true)
        }
    }
}
