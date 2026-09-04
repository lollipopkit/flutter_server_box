import Foundation

/// A `.sbxsrv` handed to this app by AirDrop, the Finder, or another app.
///
/// **Held, not pushed.** A file open can land before the Flutter engine
/// exists — on a cold "Open With" the URL arrives ahead of
/// `applicationDidFinishLaunching` — so there is no channel to deliver it on
/// at the moment it happens. The Dart side asks instead, after its first frame
/// and again on every resume, and this holds the bytes until it does.
///
/// Only the contents are kept. The file itself may be anywhere the user put
/// it, and outside the sandbox this app has no standing claim on it.
enum IncomingShare {
  /// Matches `ServerShareUi.fileExt` and the document type in `Info.plist`.
  private static let fileExt = "sbxsrv"

  /// A share payload is a couple of kilobytes. This is not a limit anything
  /// legitimate approaches — it is there so a file that merely has the right
  /// extension cannot be read into memory whole.
  private static let maxBytes = 1 << 20

  private static var pending: String?

  /// The open arrives on the main thread and the channel call is answered on
  /// it too, so this is not contended. Locked anyway, because "the platform
  /// only ever calls this on the main thread" is an assumption about two
  /// callers rather than one.
  private static let lock = NSLock()

  /// Reads whatever of [urls] this app was opened for, keeping the last one.
  ///
  /// Only the last: the pull side returns one payload and the import is a
  /// dialog per server, so a multi-file open would queue dialogs behind each
  /// other with no way to tell which is which.
  static func accept(_ urls: [URL]) {
    for url in urls where url.pathExtension.lowercased() == fileExt {
      guard let text = read(url) else { continue }
      lock.lock()
      pending = text
      lock.unlock()
    }
  }

  /// The payload waiting, if any. Cleared by the read, so a second resume does
  /// not raise the same file again.
  static func take() -> String? {
    lock.lock()
    defer { lock.unlock() }
    let out = pending
    pending = nil
    return out
  }

  private static func read(_ url: URL) -> String? {
    // The App Store build is sandboxed and a file dropped on the app comes
    // with a scoped grant rather than blanket read access. The DMG build is
    // not sandboxed and this answers false there, which is why the result is
    // checked rather than the call being conditional on the build.
    let scoped = url.startAccessingSecurityScopedResource()
    defer { if scoped { url.stopAccessingSecurityScopedResource() } }

    guard
      let attrs = try? FileManager.default.attributesOfItem(atPath: url.path),
      let size = attrs[.size] as? Int, size <= maxBytes,
      let data = try? Data(contentsOf: url)
    else { return nil }
    return String(data: data, encoding: .utf8)
  }
}
