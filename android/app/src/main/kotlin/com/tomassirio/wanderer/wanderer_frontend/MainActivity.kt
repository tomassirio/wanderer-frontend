package com.tomassirio.wanderer.wanderer_frontend

import android.content.Intent
import android.os.Build
import android.os.Bundle
import androidx.activity.enableEdgeToEdge
import io.flutter.embedding.android.FlutterFragmentActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterFragmentActivity() {

    companion object {
        private const val CHANNEL = "com.tomassirio.wanderer.wanderer_frontend/trip_tracking"
    }

    override fun onCreate(savedInstanceState: Bundle?) {
        enableEdgeToEdge()
        super.onCreate(savedInstanceState)
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "startTracking" -> {
                        val tripName = call.argument<String>("tripName") ?: "Trip"
                        val intent = Intent(this, TripTrackingService::class.java).apply {
                            action = TripTrackingService.ACTION_START
                            putExtra(TripTrackingService.EXTRA_TRIP_NAME, tripName)
                        }
                        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                            startForegroundService(intent)
                        } else {
                            startService(intent)
                        }
                        result.success(null)
                    }
                    "stopTracking" -> {
                        val intent = Intent(this, TripTrackingService::class.java).apply {
                            action = TripTrackingService.ACTION_STOP
                        }
                        startService(intent)
                        result.success(null)
                    }
                    else -> result.notImplemented()
                }
            }
    }
}
