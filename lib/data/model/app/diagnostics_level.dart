/// How much diagnostic data leaves the device.
///
/// Not a crash setting. A crash is one of the things reported; the levels
/// differ in whether anything is sent *between* crashes at all.
///
/// The whole scale sits on top of one invariant: **redaction happens where the
/// data is recorded, not where it is sent**. Known server names, addresses and
/// usernames become placeholders in the crumb or log line itself, so no level
/// here is the difference between identifying and not. The difference is how
/// much is sent, and how often.
///
/// The local log is unaffected by all three. It never leaves the device on its
/// own, it is what the Logs page shows, and it is what a user pastes into an
/// issue by hand. This setting only decides what is *uploaded*.
/// What a fresh install starts at, before the user has chosen.
///
/// Compile-time, and **the default is deliberately the quietest one**: a build
/// that was handed no channel is treated as F-Droid's, because that is the
/// distribution where collecting by default is the thing that must not happen.
/// Opt-in *and* disabled by default is what their Tracking anti-feature asks
/// for, and this is the half that "ask on an intro page" cannot supply.
///
/// The release workflow passes `full` for the builds it publishes itself.
/// F-Droid builds from this source without passing anything, so they get
/// `none` — the same binary logic, a different starting point, decided by who
/// built it.
///
/// Either way the intro page is shown and the user can pick any level; this
/// only decides which one is already selected when they see it.
const kDefaultDiagnosticsLevel = String.fromEnvironment(
  'DIAG_DEFAULT',
  defaultValue: 'none',
);

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
  basic,

  /// Continuously, while the app runs.
  ///
  /// Everything [basic] sends, plus the log stream and performance traces as
  /// they happen — not held back until something breaks. This is what makes a
  /// problem visible that never crashes: a connection that takes twelve
  /// seconds, a refresh that quietly fails every time, a screen that is slow
  /// only on one platform.
  ///
  /// It is also the level that costs something real. Every log line and every
  /// traced operation is a request to the server, which for a self-hosted
  /// instance means storage and CPU that scale with how much the app is used
  /// rather than with how often it fails.
  full;

  /// Whether anything is sent at all.
  bool get uploads => this != DiagnosticsLevel.none;

  /// Whether breadcrumbs accompany an error.
  bool get sendsBreadcrumbs => this != DiagnosticsLevel.none;

  /// Whether the log stream is uploaded as it happens.
  bool get streamsLogs => this == DiagnosticsLevel.full;

  /// Whether operations are traced for performance.
  bool get tracesPerformance => this == DiagnosticsLevel.full;

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
    for (final level in DiagnosticsLevel.values) {
      if (level.name == name) return level;
    }
    return DiagnosticsLevel.none;
  }
}
