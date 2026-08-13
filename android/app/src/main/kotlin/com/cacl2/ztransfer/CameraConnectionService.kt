package com.cacl2.ztransfer

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.app.Service
import android.content.Context
import android.content.Intent
import android.os.Build
import android.os.IBinder
import android.util.Log

/** Keeps the Nikon PTP/IP process alive while a Wi-Fi camera session is active. */
class CameraConnectionService : Service() {
    override fun onCreate() {
        super.onCreate()
        running = true
        createNotificationChannel()
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        val listening = intent?.getBooleanExtra(EXTRA_LISTENING, false) == true
        startForeground(NOTIFICATION_ID, buildNotification(listening))
        return START_NOT_STICKY
    }

    override fun onBind(intent: Intent?): IBinder? = null

    override fun onDestroy() {
        running = false
        super.onDestroy()
    }

    private fun createNotificationChannel() {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) return
        val manager = getSystemService(NotificationManager::class.java)
        manager.createNotificationChannel(
            NotificationChannel(
                CHANNEL_ID,
                getString(R.string.camera_connection_channel_name),
                NotificationManager.IMPORTANCE_LOW,
            ).apply {
                description = getString(R.string.camera_connection_channel_description)
                setShowBadge(false)
            },
        )
    }

    private fun buildNotification(listening: Boolean): Notification {
        val launchIntent = Intent(this, MainActivity::class.java).apply {
            flags = Intent.FLAG_ACTIVITY_SINGLE_TOP or Intent.FLAG_ACTIVITY_CLEAR_TOP
        }
        val pendingIntent = PendingIntent.getActivity(
            this,
            0,
            launchIntent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
        )
        val builder = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            Notification.Builder(this, CHANNEL_ID)
        } else {
            @Suppress("DEPRECATION")
            Notification.Builder(this)
        }
        return builder
            .setSmallIcon(R.drawable.ic_launcher_monochrome)
            .setContentTitle(getString(R.string.camera_connection_notification_title))
            .setContentText(
                getString(
                    if (listening) R.string.camera_connection_notification_listening
                    else R.string.camera_connection_notification_connected,
                ),
            )
            .setContentIntent(pendingIntent)
            .setOngoing(true)
            .setOnlyAlertOnce(true)
            .setCategory(Notification.CATEGORY_SERVICE)
            .build()
    }

    companion object {
        private const val TAG = "CameraConnectionSvc"
        private const val CHANNEL_ID = "camera_connection"
        private const val NOTIFICATION_ID = 15740
        private const val EXTRA_LISTENING = "listening"

        @Volatile
        private var running = false

        fun start(context: Context, listening: Boolean) {
            val intent = Intent(context, CameraConnectionService::class.java)
                .putExtra(EXTRA_LISTENING, listening)
            runCatching {
                if (running) {
                    context.startService(intent)
                } else if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                    context.startForegroundService(intent)
                } else {
                    context.startService(intent)
                }
            }.onFailure {
                Log.w(TAG, "Unable to start camera keep-alive service", it)
            }
        }

        fun stop(context: Context) {
            runCatching {
                context.stopService(Intent(context, CameraConnectionService::class.java))
                running = false
            }.onFailure {
                Log.w(TAG, "Unable to stop camera keep-alive service", it)
            }
        }
    }
}
