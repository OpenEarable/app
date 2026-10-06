package edu.kit.teco.openWearable

import android.content.Intent
import android.os.Build
import android.os.Bundle
import android.os.Handler
import android.os.Looper
import android.os.ResultReceiver
import android.provider.Settings
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
  companion object {
    private const val SYSTEM_SETTINGS_CHANNEL = "edu.kit.teco.openWearable/system_settings"
  }

  override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
    super.configureFlutterEngine(flutterEngine)

    MethodChannel(
      flutterEngine.dartExecutor.binaryMessenger,
      "edu.kit.teco.openWearable/audio_recording",
    ).setMethodCallHandler { call, result ->
      val intent = Intent(this, AudioRecordingService::class.java)
      when (call.method) {
        "start" -> {
          val receiver = object : ResultReceiver(Handler(Looper.getMainLooper())) {
            override fun onReceiveResult(code: Int, data: Bundle?) {
              if (code == 0) result.success(null)
              else result.error("audio_recording_service", data?.getString("error"), null)
            }
          }
          intent.putExtra("result", receiver)
          try {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) startForegroundService(intent)
            else startService(intent)
          } catch (error: Exception) {
            result.error("audio_recording_service", error.message, null)
          }
        }
        "stop" -> {
          stopService(intent)
          result.success(null)
        }
        else -> result.notImplemented()
      }
    }

    MethodChannel(
      flutterEngine.dartExecutor.binaryMessenger,
      SYSTEM_SETTINGS_CHANNEL,
    ).setMethodCallHandler { call, result ->
      if (call.method == "openBluetoothSettings") {
        try {
          val intent = Intent(Settings.ACTION_BLUETOOTH_SETTINGS).apply {
            addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
          }
          startActivity(intent)
          result.success(true)
        } catch (_: Exception) {
          result.success(false)
        }
      } else {
        result.notImplemented()
      }
    }
  }

  override fun onDestroy() {
    stopService(Intent(this, AudioRecordingService::class.java))
    super.onDestroy()
  }
}
