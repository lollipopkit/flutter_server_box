/// What a plugin has been doing, in the terms a report can be written in.
///
/// **The question this answers is "the plugin does nothing".** That is what a
/// user reports, and it covers three different failures that look identical
/// from the outside: the collection did not run (a command, a request), the
/// plugin itself threw, or the tree it produced never reached the screen. An
/// author cannot tell them apart from a screenshot, and the app's log is on the
/// user's device.
///
/// **Nothing here is a value.** No command output, no configuration, no HTTP
/// body, no message — only *which stage*, *what class of failure*, *when* and
/// *how long*. That is not a setting: a report is written to be pasted
/// somewhere public, and a stage name is safe to publish where the text after
/// it is not. What the message said is in the log and on the surface itself,
/// which the person having the problem can read and choose to send.
library;

/// Where a plugin was when something happened.
///
/// Grouped the way an author has to act on them, which is the whole point of
/// recording a stage at all.
enum PluginStage {
  /// Compiling `plugin.js` and building the instance. A failure here is the
  /// bundle, and nothing else the plugin does has run.
  load,

  /// `init` — where a plugin reads its stored state.
  init,

  /// `open` — the first tree.
  open,

  /// `onEvent` — something the user did.
  event,

  /// `tick` — the refresh interval.
  tick,

  /// `onHook` — where a plugin collects.
  hook,

  /// A command on a server. **Collection**, not the plugin's own code: the
  /// plugin ran, and the machine did not answer.
  exec,

  /// An HTTP request. Collection, for the same reason.
  http,

  /// `sb.ui.patch` — the plugin had something to draw and it did not land.
  /// A surface that is not on screen is the ordinary case and is not recorded.
  patch,

  /// A status plugin's `statusCmd` or `parse`.
  status;

  /// What a report calls it. Stable: it is what a bug report will quote, and a
  /// name that moves with a refactor makes two reports incomparable.
  String get name => switch (this) {
    PluginStage.load => 'load',
    PluginStage.init => 'init',
    PluginStage.open => 'open',
    PluginStage.event => 'event',
    PluginStage.tick => 'tick',
    PluginStage.hook => 'hook',
    PluginStage.exec => 'exec',
    PluginStage.http => 'http',
    PluginStage.patch => 'patch',
    PluginStage.status => 'status',
  };

  static PluginStage? byName(String name) =>
      PluginStage.values.where((s) => s.name == name).firstOrNull;

  /// Which of the three things a user means by "it does nothing".
  PluginStageKind get kind => switch (this) {
    PluginStage.exec || PluginStage.http => PluginStageKind.collecting,
    PluginStage.patch => PluginStageKind.drawing,
    _ => PluginStageKind.running,
  };
}

/// The three failures that look the same from outside. See [PluginStage.kind].
enum PluginStageKind {
  /// The plugin ran and the thing it asked about did not answer.
  collecting,

  /// The plugin's own code threw, or would not load.
  running,

  /// It had something to draw and it did not reach the screen.
  drawing,
}

/// One thing that happened, kept only as its shape.
class PluginEvent {
  const PluginEvent({
    required this.stage,
    required this.at,
    required this.elapsed,
    this.failure,
  });

  final PluginStage stage;
  final DateTime at;

  /// How long it took. Half of "the plugin does nothing" is "it is slow", and
  /// nothing else on the device records it.
  final Duration elapsed;

  /// A short tag for what class of failure it was — `timeout`, `denied`,
  /// `threw` — or null for a success.
  ///
  /// **A tag, never a message.** A message carries paths, host names and
  /// whatever the plugin put in it; a tag is a word this app chose.
  final String? failure;

  bool get ok => failure == null;

  Map<String, Object?> toJson() => {
    'stage': stage.name,
    'at': at.millisecondsSinceEpoch,
    'ms': elapsed.inMilliseconds,
    if (failure != null) 'failure': failure,
  };

  static PluginEvent? fromJson(Object? raw) {
    if (raw is! Map) return null;
    final stage = PluginStage.byName('${raw['stage']}');
    final at = raw['at'];
    if (stage == null || at is! int) return null;
    final failure = raw['failure'];
    return PluginEvent(
      stage: stage,
      at: DateTime.fromMillisecondsSinceEpoch(at),
      elapsed: Duration(milliseconds: raw['ms'] is int ? raw['ms'] as int : 0),
      failure: failure is String && failure.isNotEmpty ? failure : null,
    );
  }
}

/// One plugin's record. See the library doc for what is deliberately absent.
class PluginHealth {
  const PluginHealth({
    required this.pluginId,
    this.lastOk,
    this.lastFailure,
    this.failuresSinceOk = 0,
  });

  final String pluginId;

  /// The last thing that worked, and the last that did not.
  ///
  /// Both, rather than the most recent of the two: a plugin whose page opens
  /// and whose collection fails is a different report from one that will not
  /// load, and keeping only the latest makes them read the same.
  final PluginEvent? lastOk;
  final PluginEvent? lastFailure;

  /// How many failures since the last success.
  ///
  /// One failure is a server that was asleep; forty is a plugin that has not
  /// worked since it was updated, and the difference is the first thing worth
  /// knowing.
  final int failuresSinceOk;

  bool get isEmpty => lastOk == null && lastFailure == null;

  PluginHealth record(PluginEvent event) => PluginHealth(
    pluginId: pluginId,
    lastOk: event.ok ? event : lastOk,
    lastFailure: event.ok ? lastFailure : event,
    failuresSinceOk: event.ok ? 0 : failuresSinceOk + 1,
  );

  Map<String, Object?> toJson() => {
    if (lastOk != null) 'ok': lastOk!.toJson(),
    if (lastFailure != null) 'failure': lastFailure!.toJson(),
    'failures': failuresSinceOk,
  };

  factory PluginHealth.fromJson(String pluginId, Object? raw) {
    if (raw is! Map) return PluginHealth(pluginId: pluginId);
    return PluginHealth(
      pluginId: pluginId,
      lastOk: PluginEvent.fromJson(raw['ok']),
      lastFailure: PluginEvent.fromJson(raw['failure']),
      failuresSinceOk: raw['failures'] is int ? raw['failures'] as int : 0,
    );
  }
}
