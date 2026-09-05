import Foundation

/// A `.sbxsrv` handed to this app by AirDrop, the Files app, or another app's
/// share sheet.
///
/// **Held, not pushed.** On a cold open the URL arrives before the Flutter
/// engine exists, so there is no channel to deliver it on at the moment it
/// happens. The Dart side asks after its first frame and again on every
/// resume, which covers that and the case where the app was already running.
///
/// Only the contents are kept. A file AirDropped to this app lands in
/// `Documents/Inbox`, which the app is expected to empty; one opened in place
/// belongs to wherever the user keeps it and is not this app's to hold on to.
enum IncomingShare {
  /// Matches `ServerShareUi.fileExt` and the document type in the three
  /// `Info-<configuration>.plist` files.
  private static let fileExt = "sbxsrv"

  /// A share payload is a couple of kilobytes. This is not a limit anything
  /// legitimate approaches — it is there so a file that merely has the right
  /// extension cannot be read into memory whole.
  private static let maxBytes = 1 << 20

  private static var pending: String?

  /// Told to the Dart side once a payload is stored, for the case the
  /// lifecycle cannot report: an app that was already frontmost gets no
  /// resume, so nothing would ask and the payload would sit here until an
  /// unrelated one raised it out of nowhere.
  ///
  /// Only the trigger. The bytes still leave through `take()`, so there is one
  /// path that reads and clears them however Dart was told to look.
  ///
  /// Null until the engine exists, which is the cold-launch case -- and that
  /// one is covered by the pull after the first frame.
  static var onArrival: (() -> Void)?
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
      onArrival?()
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
    // A document opened in place — which `LSSupportsOpeningDocumentsInPlace`
    // asks for — comes with a scoped grant rather than blanket read access.
    // A file dropped into the app's own inbox does not, and answers false.
    let scoped = url.startAccessingSecurityScopedResource()
    defer { if scoped { url.stopAccessingSecurityScopedResource() } }

    guard
      let attrs = try? FileManager.default.attributesOfItem(atPath: url.path),
      let size = attrs[.size] as? Int, size <= maxBytes,
      let data = try? Data(contentsOf: url)
    else { return nil }
    let text = String(data: data, encoding: .utf8)

    // The inbox is this app's to clean up, and what is in it is a credential.
    // Anything elsewhere belongs to the user and is left alone.
    if url.path.contains("/Documents/Inbox/") {
      try? FileManager.default.removeItem(at: url)
    }
    return text
  }
}
