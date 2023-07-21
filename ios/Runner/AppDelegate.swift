import UIKit
import WidgetKit
import Flutter

@UIApplicationMain
@objc class AppDelegate: FlutterAppDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    GeneratedPluginRegistrant.register(with: self)
      if #available(iOS 14.0, *) {
          WidgetCenter.shared.reloadTimelines(ofKind: "StatusWidget")
      }
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }
}
