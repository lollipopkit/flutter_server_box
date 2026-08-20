import UIKit
import WidgetKit
import Flutter
import ActivityKit

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
    override func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
    ) -> Bool {
        return super.application(application, didFinishLaunchingWithOptions: launchOptions)
    }

    func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
        GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)
        setupMethodChannels(binaryMessenger: engineBridge.applicationRegistrar.messenger())
    }

    private func setupMethodChannels(binaryMessenger: FlutterBinaryMessenger) {
        let homeWidgetChannel = FlutterMethodChannel(name: "tech.lolli.toolbox/home_widget", binaryMessenger: binaryMessenger)
        homeWidgetChannel.setMethodCallHandler({(call: FlutterMethodCall, result: @escaping FlutterResult) -> Void in
            switch call.method {
            case "update":
                if #available(iOS 14.0, *) {
                    WidgetCenter.shared.reloadTimelines(ofKind: "StatusWidget")
                }
                result(nil)
            default:
                result(FlutterMethodNotImplemented)
            }
        })

        let mainChannel = FlutterMethodChannel(name: "tech.lolli.toolbox/main_chan", binaryMessenger: binaryMessenger)
        mainChannel.setMethodCallHandler({(call: FlutterMethodCall, result: @escaping FlutterResult) -> Void in
            switch call.method {
            case "updateHomeWidget":
                if #available(iOS 14.0, *) {
                    WidgetCenter.shared.reloadTimelines(ofKind: "StatusWidget")
                }
                result(nil)
            // The three Live Activity cases answer from inside the Task, not
            // after starting it. ActivityKit is what takes the time here, and
            // none of it may run on this thread; replying only once it is done
            // is also what keeps the Dart side's queue ordering these calls.
            case "startLiveActivity":
                if #available(iOS 16.2, *), let payload = call.arguments as? String {
                    Task {
                        await LiveActivityManager.shared.start(json: payload)
                        result(nil)
                    }
                } else {
                    result(nil)
                }
            case "updateLiveActivity":
                if #available(iOS 16.2, *), let payload = call.arguments as? String {
                    Task {
                        await LiveActivityManager.shared.update(json: payload)
                        result(nil)
                    }
                } else {
                    result(nil)
                }
            case "stopLiveActivity":
                if #available(iOS 16.2, *) {
                    Task {
                        await LiveActivityManager.shared.stop()
                        result(nil)
                    }
                } else {
                    result(nil)
                }
            case "setAccessoryWidgetUrl":
                // The accessory families can't carry the intent configuration
                // the home-screen ones use, so they read this key instead —
                // see StatusWidget.getTimeline.
                let defaults = UserDefaults(suiteName: appGroupId)
                if let url = call.arguments as? String, !url.isEmpty {
                    defaults?.set(url, forKey: accessoryKey)
                } else {
                    defaults?.removeObject(forKey: accessoryKey)
                }
                if #available(iOS 14.0, *) {
                    WidgetCenter.shared.reloadTimelines(ofKind: "StatusWidget")
                }
                result(nil)
            default:
                result(FlutterMethodNotImplemented)
            }
        })
    }

    override func application(_ app: UIApplication, open url: URL, options: [UIApplication.OpenURLOptionsKey : Any] = [:]) -> Bool {
        if url.scheme == "https" || url.scheme == "http" {
            UIApplication.shared.open(url)
        } else {
            // Pass
        }
        return true
    }

    override func application(_ application: UIApplication, didDiscardSceneSessions sceneSessions: Set<UISceneSession>) {
        // UIScene apps use this callback when the user closes the app from the
        // app switcher. applicationWillTerminate is not reliable for that path.
        //
        // Deliberately no `super`. This is an optional UIApplicationDelegate
        // method and FlutterAppDelegate does not implement it, so forwarding
        // raises NSInvalidArgumentException and terminates the app. Checked
        // with `otool -oV Flutter`: the selector is in the protocol's name
        // table with no imp behind it.
        if #available(iOS 16.2, *) {
            Task { await LiveActivityManager.shared.stop() }
        }
    }

    override func applicationWillTerminate(_ application: UIApplication) {
        // Stop Live Activity when app is about to terminate
        if #available(iOS 16.2, *) {
            Task { await LiveActivityManager.shared.stop() }
        }
        // This one FlutterAppDelegate does implement, and it is how registered
        // plugins hear that the app is going away.
        super.applicationWillTerminate(application)
    }
}
