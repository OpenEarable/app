import Flutter
import UIKit

@main
@objc class AppDelegate: FlutterAppDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {    
    let controller: FlutterViewController = window?.rootViewController as! FlutterViewController
    let openFolderChannel = FlutterMethodChannel(name: "edu.teco.open_folder", binaryMessenger: controller.binaryMessenger)
    let systemSettingsChannel = FlutterMethodChannel(name: "edu.kit.teco.open_wearable/system_settings", binaryMessenger: controller.binaryMessenger)
    
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

    GeneratedPluginRegistrant.register(with: self)
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }
}
