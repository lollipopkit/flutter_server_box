import UIKit
import WidgetKit
import Flutter
import ActivityKit

@main
@objc class AppDelegate: FlutterAppDelegate {
    override func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
    ) -> Bool {
        GeneratedPluginRegistrant.register(with: self)
    
        let controller : FlutterViewController = window?.rootViewController as! FlutterViewController
        // Home widget channel (legacy)
        let homeWidgetChannel = FlutterMethodChannel(name: "tech.lolli.toolbox/home_widget", binaryMessenger: controller.binaryMessenger)
        homeWidgetChannel.setMethodCallHandler({(call: FlutterMethodCall, result: @escaping FlutterResult) -> Void in
            if call.method == "update" {
                if #available(iOS 14.0, *) {
                    WidgetCenter.shared.reloadTimelines(ofKind: "StatusWidget")
                }
            }
        })

        // Main channel for cross-platform calls (incl. Live Activities)
        let mainChannel = FlutterMethodChannel(name: "tech.lolli.toolbox/main_chan", binaryMessenger: controller.binaryMessenger)
        mainChannel.setMethodCallHandler({(call: FlutterMethodCall, result: @escaping FlutterResult) -> Void in
            switch call.method {
            case "updateHomeWidget":
                if #available(iOS 14.0, *) {
                    WidgetCenter.shared.reloadTimelines(ofKind: "StatusWidget")
                }
                result(nil)
            case "startLiveActivity":
                if #available(iOS 16.2, *) {
                    if let payload = call.arguments as? String {
                        LiveActivityManager.start(json: payload)
                    }
                }
                result(nil)
            case "updateLiveActivity":
                if #available(iOS 16.2, *) {
                    if let payload = call.arguments as? String {
                        LiveActivityManager.update(json: payload)
                    }
                }
                result(nil)
            case "stopLiveActivity":
                if #available(iOS 16.2, *) {
                    LiveActivityManager.stop()
                }
                result(nil)
            default:
                result(FlutterMethodNotImplemented)
            }
        })
        return super.application(application, didFinishLaunchingWithOptions: launchOptions)
    }

    override func application(_ app: UIApplication, open url: URL, options: [UIApplication.OpenURLOptionsKey : Any] = [:]) -> Bool {
        if url.scheme == "https" || url.scheme == "http" {
            UIApplication.shared.open(url)
        } else {
            // Pass
        }
        return true
    }
    
    override func applicationWillTerminate(_ application: UIApplication) {
        // Stop Live Activity when app is about to terminate
        if #available(iOS 16.2, *) {
            LiveActivityManager.stop()
        }
    }
}
