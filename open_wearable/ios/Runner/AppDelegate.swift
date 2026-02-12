import Flutter
import UIKit

@main
@objc class AppDelegate: FlutterAppDelegate {
  private var sensorShutdownBackgroundTask: UIBackgroundTaskIdentifier = .invalid
  private var lifecycleChannel: FlutterMethodChannel?

  private func beginSensorShutdownBackgroundTask() {
    guard sensorShutdownBackgroundTask == .invalid else {
      return
    }

    sensorShutdownBackgroundTask = UIApplication.shared.beginBackgroundTask(
      withName: "SensorShutdown"
    ) { [weak self] in
      self?.endSensorShutdownBackgroundTask()
    }
  }

  private func endSensorShutdownBackgroundTask() {
    guard sensorShutdownBackgroundTask != .invalid else {
      return
    }

    UIApplication.shared.endBackgroundTask(sensorShutdownBackgroundTask)
    sensorShutdownBackgroundTask = .invalid
  }

  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {    
    let controller: FlutterViewController = window?.rootViewController as! FlutterViewController
    let openFolderChannel = FlutterMethodChannel(name: "edu.teco.open_folder", binaryMessenger: controller.binaryMessenger)
    let systemSettingsChannel = FlutterMethodChannel(name: "edu.kit.teco.open_wearable/system_settings", binaryMessenger: controller.binaryMessenger)
    lifecycleChannel = FlutterMethodChannel(name: "edu.kit.teco.open_wearable/lifecycle", binaryMessenger: controller.binaryMessenger)
    
    openFolderChannel.setMethodCallHandler { (call: FlutterMethodCall, result: @escaping FlutterResult) in
      if call.method == "openFolder", let args = call.arguments as? [String: Any], let path = args["path"] as? String {
        guard let url = URL(string: path) else {
          result(FlutterError(code: "INVALID_ARGUMENT", message: "Invalid folder path", details: nil))
          return
        }
        if UIApplication.shared.canOpenURL(url) {
          UIApplication.shared.open(url, options: [:], completionHandler: nil)
          result(nil)
        } else {
          result(FlutterError(code: "UNAVAILABLE", message: "Cannot open folder \(path)", details: nil))
        }
      } else {
        result(FlutterMethodNotImplemented)
      }
    }

    systemSettingsChannel.setMethodCallHandler { (call: FlutterMethodCall, result: @escaping FlutterResult) in
      if call.method == "openBluetoothSettings" {
        guard let settingsUrl = URL(string: UIApplication.openSettingsURLString) else {
          result(false)
          return
        }

        if UIApplication.shared.canOpenURL(settingsUrl) {
          UIApplication.shared.open(settingsUrl, options: [:]) { success in
            result(success)
          }
        } else {
          result(false)
        }
      } else {
        result(FlutterMethodNotImplemented)
      }
    }

    lifecycleChannel?.setMethodCallHandler { [weak self] (call: FlutterMethodCall, result: @escaping FlutterResult) in
      guard let self = self else {
        result(false)
        return
      }

      if call.method == "beginBackgroundExecution" {
        self.beginSensorShutdownBackgroundTask()
        result(true)
      } else if call.method == "endBackgroundExecution" {
        self.endSensorShutdownBackgroundTask()
        result(true)
      } else {
        result(FlutterMethodNotImplemented)
      }
    }

    GeneratedPluginRegistrant.register(with: self)
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }
}
