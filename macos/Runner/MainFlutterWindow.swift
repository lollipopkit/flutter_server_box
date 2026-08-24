import Cocoa
import FlutterMacOS
import window_manager

class MainFlutterWindow: NSWindow {
  override func awakeFromNib() {
    let flutterViewController = FlutterViewController()
    // Installing the content view controller resizes the window, which is the
    // only reason the frame is captured and put back here.
    //
    // It used to be put back as a hardcoded 400x777 — written in 2023, before
    // the window size was persisted. `_initWindow` has applied the stored size
    // (or 1323x817) a moment later ever since, so the constant no longer chose
    // anything; it only made the window resize one extra time at launch.
    let windowFrame = self.frame
    self.contentViewController = flutterViewController
    self.setFrame(windowFrame, display: true)

    RegisterGeneratedPlugins(registry: flutterViewController)

    super.awakeFromNib()
  }

  override public func order(_ place: NSWindow.OrderingMode, relativeTo otherWin: Int) {
    super.order(place, relativeTo: otherWin)
    hiddenWindowAtLaunch()
  }
}
