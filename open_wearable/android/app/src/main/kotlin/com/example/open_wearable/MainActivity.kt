package edu.kit.teco.openWearable

import android.content.Intent
import android.provider.Settings
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
  companion object {
    private const val SYSTEM_SETTINGS_CHANNEL = "edu.kit.teco.open_wearable/system_settings"
  }

  override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
    super.configureFlutterEngine(flutterEngine)

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
}
