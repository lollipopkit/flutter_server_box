import Cocoa
import FlutterMacOS

@main
class AppDelegate: FlutterAppDelegate {
  override func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
    return true
  }

  override func applicationSupportsSecureRestorableState(_ app: NSApplication) -> Bool {
    return true
  }

  /// AirDrop, "Open With", and a `.sbxsrv` double-clicked in the Finder all
  /// arrive here.
  ///
  /// On a cold open this runs *before* `applicationDidFinishLaunching`, so
  /// there is no engine and no channel yet — which is why [IncomingShare]
  /// holds the bytes rather than delivering them.
  /// `super` first and unconditionally, the same as the iOS scene delegate:
  /// `FlutterAppDelegate` implements this and forwards it to every registered
  /// plugin through `handleOpenURLs:`, so swallowing it would stop any plugin
  /// answering a custom scheme or a deep link — for the sake of a file this
  /// app may not even have been handed.
  override func application(_ application: NSApplication, open urls: [URL]) {
    super.application(application, open: urls)
    IncomingShare.accept(urls)
  }

  override func applicationDidFinishLaunching(_ notification: Notification) {
    // Subscribed at launch because delivery is on the system's schedule: a
    // payload for a crash arrives some time after the launch following it, and
    // a subscriber registered later simply misses that window.
    if #available(macOS 12.0, *) {
      CrashDiagnostics.shared.start()
    }

    if let controller = mainFlutterWindow?.contentViewController as? FlutterViewController {
      let channel = FlutterMethodChannel(name: "about", binaryMessenger: controller.engine.binaryMessenger)
      channel.setMethodCallHandler { (call: FlutterMethodCall, result: @escaping FlutterResult) in
        if call.method == "showAboutPanel" {
          NSApp.orderFrontStandardAboutPanel(nil)
          result(nil)
        } else {
          result(FlutterMethodNotImplemented)
        }
      }

      // The same channel name the other platforms use, so the Dart side has
      // one call rather than a per-platform branch. Only the one method: the
      // rest of `main_chan` is Android and iOS specific.
      let mainChannel = FlutterMethodChannel(
        name: "tech.lolli.toolbox/main_chan",
        binaryMessenger: controller.engine.binaryMessenger
      )
      // Its own channel, for the same reason the tray has one. Only ever
      // carries a nudge; the payload still leaves through `takeOpenedShare`.
      let shareChannel = FlutterMethodChannel(
        name: "tech.lolli.toolbox/incoming_share",
        binaryMessenger: controller.engine.binaryMessenger
      )
      // Captured strongly, and that is the whole of it: the channel is a
      // local, so nothing else holds one. Captured weakly it was deallocated
      // the moment this method returned and every later nudge went to nil.
      // There is no cycle to break: the closure is owned by `IncomingShare`,
      // not by the channel.
      IncomingShare.onArrival = {
        // Already on the main thread, since every URL callback is; hopped
        // explicitly anyway, because a channel call from anywhere else is
        // undefined rather than merely late.
        DispatchQueue.main.async {
          shareChannel.invokeMethod("shareOpened", arguments: nil)
        }
      }

      // Its own channel: the tray talks in both directions and the handler
      // above is already taken.
      if #available(macOS 10.15, *) {
        TrayIcon.shared.attach(FlutterMethodChannel(
          name: "tech.lolli.toolbox/tray",
          binaryMessenger: controller.engine.binaryMessenger
        ))
      }

      mainChannel.setMethodCallHandler { (call: FlutterMethodCall, result: @escaping FlutterResult) in
        // What MetricKit has reported since this was last asked. Cleared by
        // the read — the caller writes them into a log that persists, and
        // keeping a copy here would report the same crash forever.
        if call.method == "takeCrashDiagnostics" {
          if #available(macOS 12.0, *) {
            result(CrashDiagnostics.take())
          } else {
            result(nil)
          }
        } else if call.method == "takeOpenedShare" {
          result(IncomingShare.take())
        } else {
          result(FlutterMethodNotImplemented)
        }
      }
    }
    super.applicationDidFinishLaunching(notification)
  }
}
