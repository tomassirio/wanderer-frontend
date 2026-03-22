package com.tomassirio.wanderer.wanderer_frontend

import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.Service
import android.content.Context
import android.content.Intent
import android.os.Build
import android.os.IBinder
import androidx.core.app.NotificationCompat

/**
 * A foreground service that keeps the app process alive and exempt from Android's
 * Doze mode while automatic trip location updates are running.
 *
 * Without a foreground service, Android's Doze mode defers WorkManager background
 * tasks indefinitely when the screen is off and the device is idle. The presence
 * of an active foreground service marks the app as "not in the background", which
 * ensures WorkManager one-off tasks fire at their scheduled intervals even when the
 * phone is locked.
 *
 * The service itself does no work — it only shows a persistent "Tracking: [name]"
 * notification. The actual location-update logic continues to run through the
 * existing WorkManager chained task infrastructure (callbackDispatcher in Dart).
 *
 * Lifecycle:
 *  - Started via [ACTION_START] intent when automatic updates are enabled.
 *  - Stopped via [ACTION_STOP] intent when automatic updates are disabled / trip ends.
 *  - Returns [START_STICKY] so Android restarts it after a low-memory kill; the trip
 *    name is recovered from SharedPreferences on restart.
 */
class TripTrackingService : Service() {

    companion object {
        const val ACTION_START = "com.tomassirio.wanderer.ACTION_START_TRACKING"
        const val ACTION_STOP = "com.tomassirio.wanderer.ACTION_STOP_TRACKING"
        const val EXTRA_TRIP_NAME = "trip_name"

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
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        if (intent?.action == ACTION_STOP) {
            stopForegroundCompat()
            stopSelf()
            return START_NOT_STICKY
        }

        // Prefer the name from the intent; fall back to SharedPreferences so
        // the notification is correct when Android restarts the service (START_STICKY).
        val tripName: String = intent?.getStringExtra(EXTRA_TRIP_NAME)
            ?: getSharedPreferences(FLUTTER_PREFS, Context.MODE_PRIVATE)
                .getString(PREFS_TRIP_NAME_KEY, null)
            ?: "Trip"

        createNotificationChannel()
        startForeground(NOTIFICATION_ID, buildNotification(tripName))

        return START_STICKY
    }

    override fun onBind(intent: Intent?): IBinder? = null

    override fun onDestroy() {
        super.onDestroy()
    }

    // -------------------------------------------------------------------------
    // Helpers
    // -------------------------------------------------------------------------

    private fun createNotificationChannel() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val channel = NotificationChannel(
                CHANNEL_ID,
                "Trip Tracking",
                NotificationManager.IMPORTANCE_LOW,
            ).apply {
                description = "Shown while automatic trip location updates are active"
                setShowBadge(false)
            }
            val manager = getSystemService(NOTIFICATION_SERVICE) as NotificationManager
            manager.createNotificationChannel(channel)
        }
    }

    private fun buildNotification(tripName: String) =
        NotificationCompat.Builder(this, CHANNEL_ID)
            .setSmallIcon(R.mipmap.ic_launcher)
            .setContentTitle("Tracking: $tripName")
            .setContentText("Automatic location updates are active")
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
