package edu.kit.teco.openWearable

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.app.Service
import android.content.Intent
import android.content.pm.ServiceInfo
import android.os.Build
import android.os.Bundle
import android.os.IBinder
import android.os.ResultReceiver

/** Keeps an explicitly started microphone recording audible while the app is backgrounded. */
class AudioRecordingService : Service() {
  override fun onBind(intent: Intent?): IBinder? = null

  override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
    @Suppress("DEPRECATION")
    val receiver = intent?.getParcelableExtra<ResultReceiver>("result")
    try {
      val channelId = "audio_recording"
      val manager = getSystemService(NotificationManager::class.java)
      val builder = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
        manager.createNotificationChannel(
          NotificationChannel(channelId, "Audio recording", NotificationManager.IMPORTANCE_LOW),
        )
        Notification.Builder(this, channelId)
      } else {
        @Suppress("DEPRECATION")
        Notification.Builder(this)
      }
      val openApp = PendingIntent.getActivity(
        this, 0, Intent(this, MainActivity::class.java),
        PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
      )
      val notification = builder
        .setSmallIcon(android.R.drawable.ic_btn_speak_now)
        .setContentTitle("OpenWearables is recording audio")
        .setContentText("Open the app to stop recording.")
        .setContentIntent(openApp)
        .setOngoing(true)
        .setOnlyAlertOnce(true)
        .setCategory(Notification.CATEGORY_SERVICE)
        .build()
      if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) {
        startForeground(104, notification, ServiceInfo.FOREGROUND_SERVICE_TYPE_MICROPHONE)
      } else {
        startForeground(104, notification)
      }
      receiver?.send(0, null)
    } catch (error: Exception) {
      receiver?.send(1, Bundle().apply { putString("error", error.message) })
      stopSelf()
    }
    return START_NOT_STICKY
  }

  override fun onDestroy() {
    stopForeground(STOP_FOREGROUND_REMOVE)
    super.onDestroy()
  }
}
