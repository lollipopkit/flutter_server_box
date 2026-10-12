/// How much diagnostic data leaves the device.
///
/// Not a crash setting. A crash is one of the things reported; the levels
/// differ in whether anything is sent *between* crashes at all.
///
/// The whole scale sits on top of one invariant: **redaction happens where the
/// data is recorded, not where it is sent**. Known server names, addresses and
/// usernames become placeholders in the crumb or log line itself, so no level
/// here is the difference between identifying and not — the difference is how
/// much is sent, and how often.
///
/// The local log is unaffected by both. It never leaves the device on its
/// own: it is what the Logs page shows and what a user pastes into an issue by
/// hand. This setting only decides what is *uploaded*.
enum DiagnosticsLevel {
  /// Nothing is uploaded, ever.
  ///
  /// The app still records locally, so a crash can still be reported by hand
  /// from the prompt after it — that path needs no server and no consent.
  none,

  /// Only when something goes wrong.
  ///
  /// A crash or a caught error, with the build it happened in and the tags
  /// describing this install. Nothing is sent while the app is behaving.
  basic;

  /// Whether anything is sent at all.
  bool get uploads => this != DiagnosticsLevel.none;

  /// Whether breadcrumbs accompany an error.
  bool get sendsBreadcrumbs => this != DiagnosticsLevel.none;

  /// Reads a stored name.
  ///
  /// By name rather than index, per the store's rule: an index silently
  /// changes meaning the moment a case is inserted, and these values outlive
  /// the build that wrote them.
  ///
  /// Anything unrecognised falls back to [none], not to the build's default. A
  /// value that cannot be read is not a record of what the user agreed to, and
  /// the safe reading of "unknown" is to send nothing.
  static DiagnosticsLevel fromName(String? name) {
    // TODO: remove with `DiagnosticsUpload.retireFullLevel`. The removed
    // `full` level sent everything `basic` does, so that is what it becomes.
    if (name == 'full') return DiagnosticsLevel.basic;
    for (final level in DiagnosticsLevel.values) {
      if (level.name == name) return level;
    }
    return DiagnosticsLevel.none;
  }
}

/// What an install is at until the user chooses: [DiagnosticsLevel.none], on
/// every platform.
///
/// Uploading is something the user turns on, never something they find on.
/// The intro and Settings both offer the levels; until one that uploads is
/// picked there, nothing is sent.
///
/// The same on every platform, and in every build: the Android build F-Droid
/// verifies byte for byte against the published APK has no flag to differ by.
const defaultDiagnosticsLevel = DiagnosticsLevel.none;
