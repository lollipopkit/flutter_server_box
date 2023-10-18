import Cocoa
import FlutterMacOS

class MainFlutterWindow: NSWindow {
  override func awakeFromNib() {
    let flutterViewController = FlutterViewController()
    let windowFrame = self.frame
    self.contentViewController = flutterViewController
      let newWindowRect = NSRect(x: windowFrame.origin.x, y: windowFrame.origin.y, width: 300, height: 600)
    self.setFrame(newWindowRect, display: true)

    RegisterGeneratedPlugins(registry: flutterViewController)

    super.awakeFromNib()
  }
}
