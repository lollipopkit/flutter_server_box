import 'dart:io';

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

/// What a fresh install starts at, before the user has chosen.
///
/// Android starts at [DiagnosticsLevel.none]; everything else starts at
/// [DiagnosticsLevel.basic].
///
/// The split is about F-Droid, and it works because **F-Droid only distributes
/// the Android build**. Their Tracking anti-feature requires opt-in *and*
/// disabled by default — an intro page supplies the first half, and no amount
/// of asking supplies the second — so the Android default has to be `none`.
/// The desktop and Apple builds never go through that channel, and start at
/// `basic`: failures are reported, nothing is sent in between.
///
/// **Decided at runtime, and that is load-bearing.** The obvious alternative
/// is a compile-time flag — ship `full` in the builds we publish and `none` in
/// F-Droid's — and it cannot work here. F-Droid's metadata carries a `binary:`
/// field for this app, so they rebuild from this source and compare the result
/// byte for byte against the published APK, distributing our signature only
/// when the two match. A flag that differs between them makes the bytes differ
/// and the verification fail. One binary branching on [Platform.isAndroid] is
/// identical either way.
///
/// Detecting the *installer* was the other idea, and is worth ruling out in
/// writing: it exists (`getInstallSourceInfo`, API 30+), but F-Droid has
/// several clients, an APK downloaded from their website reports the system
/// installer like any other sideload, and a reviewer reading the source would
/// still find a path where collection is on by default. Keying on the platform
/// needs none of that.
DiagnosticsLevel get defaultDiagnosticsLevel {
  // An escape hatch for a private build — a beta channel that never goes near
  // F-Droid. Must not be used to vary the published Android build, per above.
  const override = String.fromEnvironment('DIAG_DEFAULT');
  if (override.isNotEmpty) return DiagnosticsLevel.fromName(override);
  return Platform.isAndroid ? DiagnosticsLevel.none : DiagnosticsLevel.basic;
}
