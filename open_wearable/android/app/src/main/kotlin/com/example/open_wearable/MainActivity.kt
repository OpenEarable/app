package edu.kit.teco.openWearable

import android.content.Intent
import android.provider.Settings
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
  companion object {
    private const val SYSTEM_SETTINGS_CHANNEL = "edu.kit.teco.open_wearable/system_settings"
    private const val LIFECYCLE_CHANNEL = "edu.kit.teco.open_wearable/lifecycle"
  }

  private var lifecycleChannel: MethodChannel? = null
  private var hasSentTerminationSignal = false

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

    lifecycleChannel = MethodChannel(
      flutterEngine.dartExecutor.binaryMessenger,
      LIFECYCLE_CHANNEL,
    ).apply {
      setMethodCallHandler { call, result ->
        when (call.method) {
          "beginBackgroundExecution" -> result.success(true)
          "endBackgroundExecution" -> result.success(true)
          else -> result.notImplemented()
        }
      }
    }
  }

  override fun onStop() {
    if (isFinishing && !isChangingConfigurations) {
      notifyAppTerminating(source = "android_onStop")
    }
    super.onStop()
  }

  override fun onDestroy() {
    if (isFinishing) {
      notifyAppTerminating(source = "android_onDestroy")
    }
    lifecycleChannel?.setMethodCallHandler(null)
    lifecycleChannel = null
    super.onDestroy()
  }

  private fun notifyAppTerminating(source: String) {
    if (hasSentTerminationSignal) {
      return
    }
    hasSentTerminationSignal = true
    try {
      lifecycleChannel?.invokeMethod("appTerminating", mapOf("source" to source))
    } catch (_: Exception) {
      // Best effort during process teardown.
    }
  }
}
