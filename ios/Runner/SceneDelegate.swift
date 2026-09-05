import Flutter
import UIKit

/// Exists for one reason: to see the URLs this app is opened with.
///
/// This app adopts `UIApplicationSceneManifest`, and in a scene-based app
/// `UIApplicationDelegate.application(_:open:options:)` is never called — the
/// scene delegate's `scene(_:openURLContexts:)` is, and a *cold* open arrives
/// in `scene(_:willConnectTo:options:)`'s connection options instead. Neither
/// is reachable from `AppDelegate`, so the manifest names this subclass rather
/// than `FlutterSceneDelegate` itself.
///
/// Everything else is the superclass's. This adds two methods and overrides
/// nothing that draws.
@objc(SceneDelegate)
class SceneDelegate: FlutterSceneDelegate {
  /// A file the app was launched to open. `connectionOptions` is the only
  /// place a cold open's URL appears.
  override func scene(
    _ scene: UIScene,
    willConnectTo session: UISceneSession,
    options connectionOptions: UIScene.ConnectionOptions
  ) {
    super.scene(scene, willConnectTo: session, options: connectionOptions)
    IncomingShare.accept(connectionOptions.urlContexts.map { $0.url })
  }

  /// A file opened while this app was already running.
  ///
  /// `super` first and unconditionally: the superclass implements this — it is
  /// how a registered plugin hears about a URL open at all — so swallowing it
  /// would break every plugin that answers one, for the sake of a file this
  /// app may not even have been sent.
  override func scene(
    _ scene: UIScene,
    openURLContexts URLContexts: Set<UIOpenURLContext>
  ) {
    super.scene(scene, openURLContexts: URLContexts)
    IncomingShare.accept(URLContexts.map { $0.url })
  }
}
