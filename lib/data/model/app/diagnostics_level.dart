import 'dart:io';

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
/// The local log is unaffected by all three. It never leaves the device on its
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
  basic,

  /// Continuously, while the app runs.
  ///
  /// Everything [basic] sends, plus performance traces as they happen rather
  /// than held back until something breaks — which is what makes a problem
  /// visible that never crashes.
  ///
  /// The log stream is not part of this, at any level. It was, and it was the
  /// one channel that carried the app's own log lines off the device
  /// continuously — the thing most likely to hold a string nobody audited. The
  /// log stays on the device, where the Logs page shows it and a crash report
  /// quotes it with the user reading first.
  ///
  /// It is still the level that costs something real: every traced operation
  /// is a request to the server, so a self-hosted instance pays storage and
  /// CPU that scale with how much the app is used rather than how often it
  /// fails.
  full;

  /// Whether anything is sent at all.
  bool get uploads => this != DiagnosticsLevel.none;

  /// Whether breadcrumbs accompany an error.
  bool get sendsBreadcrumbs => this != DiagnosticsLevel.none;

  /// Whether what the app is used for is counted, as it happens.
  ///
  /// Its instrumentation is the breadcrumbs every level already records — see
  /// `AptabaseSink` — so the levels differ in whether the count leaves the
  /// device while nothing is wrong, not in what is recorded.
  bool get sendsAnalytics => this == DiagnosticsLevel.full;

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

/// What a fresh install starts at, before the user has chosen.
///
/// Android starts at [DiagnosticsLevel.none]; everything else starts at
/// [DiagnosticsLevel.basic].
///
/// The split is about F-Droid, which distributes only the Android build. Their
/// Tracking anti-feature requires opt-in *and* disabled by default, so the
/// Android default has to be `none`. The desktop and Apple builds never go
/// through that channel and start at `basic`: failures are reported, nothing
/// is sent in between.
///
/// **Decided at runtime, and that is load-bearing.** F-Droid's metadata
/// carries a `binary:` field for this app, so they rebuild from this source and
/// compare the result byte for byte against the published APK, distributing
/// our signature only when the two match. A compile-time flag that differs
/// between the two builds makes the bytes differ and the verification fail;
/// one binary branching on [Platform.isAndroid] is identical either way.
DiagnosticsLevel get defaultDiagnosticsLevel {
  // An escape hatch for a private build — a beta channel that never goes near
  // F-Droid. Must not be used to vary the published Android build, per above.
  const override = String.fromEnvironment('DIAG_DEFAULT');
  if (override.isNotEmpty) return DiagnosticsLevel.fromName(override);
  return Platform.isAndroid ? DiagnosticsLevel.none : DiagnosticsLevel.basic;
}
