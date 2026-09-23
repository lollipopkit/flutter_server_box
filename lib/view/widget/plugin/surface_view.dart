import 'dart:async';
import 'dart:convert';

import 'package:fl_lib/fl_lib.dart';
import 'package:flutter/material.dart';
import 'package:server_box/data/model/plugin/health.dart';
import 'package:server_box/data/model/plugin/l10n.dart';
import 'package:server_box/data/model/plugin/node.dart';
import 'package:server_box/data/provider/plugin/bridge.dart';
import 'package:server_box/data/provider/plugin/runtime.dart';
import 'package:server_box/data/store/plugin_health.dart';
import 'package:server_box/view/widget/plugin/render.dart';
import 'package:server_box/view/widget/plugin/surface.dart';

/// Everything one surface needs to be loaded.
class PluginSurfaceSpec {
  const PluginSurfaceSpec({
    required this.pluginId,
    required this.manifestJson,
    required this.source,
    required this.kind,
    required this.contributionId,
    this.granted = const [],
    this.config = const {},
    this.serverId,
    this.l10n = PluginL10n.empty,
    this.assetDir,
  });

  final String pluginId;
  final String manifestJson;

  /// `plugin.js`.
  final String source;

  /// `page`, `card`, `tab` or `settings`. PLUGINS.md section 5.3.
  final String kind;

  /// Which contribution of the plugin this is, so one offering two cards can
  /// tell them apart.
  final String contributionId;

  final List<String> granted;
  final Map<String, String> config;

  /// The server this surface is bound to, or null for a global one.
  final String? serverId;

  final PluginL10n l10n;

  /// The plugin's own directory, where an `image` node's file is looked up.
  final String? assetDir;

  /// The stable contribution this surface displays.
  ///
  /// This is not a runtime instance id. Two copies of the same page have the
  /// same key and still need separate callbacks, handles and QuickJS state.
  String get contributionKey =>
      '$pluginId:$kind:$contributionId:${serverId ?? '-'}';

  /// Inputs captured when a QuickJS instance is created.
  bool runtimeDiffersFrom(PluginSurfaceSpec other) =>
      contributionKey != other.contributionKey ||
      manifestJson != other.manifestJson ||
      source != other.source ||
      !_sameSet(granted, other.granted) ||
      !_sameMap(config, other.config);

  static bool _sameSet(List<String> a, List<String> b) =>
      a.length == b.length && a.toSet().containsAll(b);

  static bool _sameMap(Map<String, String> a, Map<String, String> b) {
    if (a.length != b.length) return false;
    for (final entry in a.entries) {
      if (b[entry.key] != entry.value || !b.containsKey(entry.key)) {
        return false;
      }
    }
    return true;
  }
}

/// A plugin's surface: one instance, its tree, and the refresh that drives it.
///
/// The instance lives exactly as long as this widget. That is what makes the
/// revision cache and the SDK's own previous tree agree — both are per
/// surface, and a surface that goes away takes both.
class PluginSurfaceView extends StatefulWidget {
  const PluginSurfaceView({
    super.key,
    required this.spec,
    required this.service,
    this.refreshInterval,
    this.fleetServerIds,
  });

  final PluginSurfaceSpec spec;
  final PluginRuntimeService service;

  /// How often `tick` runs while this is on screen, or null for never.
  ///
  /// Only while visible: a card behind another tab has nothing to show, and a
  /// plugin ticking there is a plugin running commands nobody asked for.
  final Duration? refreshInterval;

  /// Every machine this surface is about, for one bound to none.
  ///
  /// A fleet-wide surface — a tab — has no `serverId`, so without this its
  /// hook would arrive naming nothing and a plugin could only find the servers
  /// by calling `sb.server.list` itself. Handing them over is the same
  /// disclosure either way, and is gated on the same grant: see
  /// [PluginRuntimeService.hook].
  ///
  /// Null where the surface is about one machine, or about none at all.
  final List<String>? fleetServerIds;

  @override
  State<PluginSurfaceView> createState() => _PluginSurfaceViewState();
}

class _PluginSurfaceViewState extends State<PluginSurfaceView> {
  static int _nextInstance = 0;

  late final _state = PluginSurfaceState(
    l10n: widget.spec.l10n,
    assetDir: widget.spec.assetDir,
  );

  BigInt? _instance;
  String? _runtimeInstanceId;
  PluginNode? _tree;
  String? _error;
  Timer? _timer;

  /// Bumped whenever the instance is replaced, so a call that outlives it
  /// publishes nothing. Every await re-checks it.
  int _generation = 0;

  /// How many callers are waiting for this plugin instance right now.
  ///
  /// **The runtime serves one call per instance at a time**, and it delivers
  /// an outstanding host call's answer only while it is inside one. So an
  /// answer that arrives during a call is drained by that call, and one that
  /// arrives while this is zero reaches the plugin only if something calls in
  /// — which is what [_onHostAnswered] is for.
  int _callsInFlight = 0;

  /// An answer arrived while a call was running. See [_onHostAnswered].
  bool _answeredDuringCall = false;

  /// A periodic or answer-driven tick already entered the runtime.
  bool _tickRunning = false;

  /// At least one more tick was requested while the current one ran.
  bool _tickQueued = false;

  @override
  void initState() {
    super.initState();
    unawaited(_load());
  }

  @override
  void didUpdateWidget(covariant PluginSurfaceView old) {
    super.didUpdateWidget(old);
    final presentationChanged =
        old.spec.l10n != widget.spec.l10n ||
        old.spec.assetDir != widget.spec.assetDir;
    if (presentationChanged) {
      _state
        ..l10n = widget.spec.l10n
        ..assetDir = widget.spec.assetDir;
    }
    if (widget.spec.runtimeDiffersFrom(old.spec)) {
      unawaited(_reload());
      return;
    }
    if (presentationChanged) {
      _state.refreshPresentation();
      setState(() {});
    }
    if (old.refreshInterval != widget.refreshInterval) _restartTimer();
  }

  @override
  void dispose() {
    _timer?.cancel();
    _generation++;
    final instance = _instance;
    final runtimeInstanceId = _runtimeInstanceId;
    _instance = null;
    _runtimeInstanceId = null;
    if (runtimeInstanceId != null) {
      widget.service.bridge.onPatch.remove(runtimeInstanceId);
      widget.service.bridge.onAnswered.remove(runtimeInstanceId);
    }
    // Not awaited, and not skipped: unloading waits for the plugin's thread,
    // which is not something `dispose` may do — but the instance has to go, or
    // its thread outlives every surface that ever showed it.
    if (instance != null) unawaited(widget.service.unload(instance));
    _state.dispose();
    super.dispose();
  }

  /// Swaps the running instance for one compiled from the current source.
  ///
  /// Unloads *before* loading, so the two never exist together: each holds a
  /// QuickJS context and an OS thread, and a reload that overlapped them would
  /// cost both for as long as the new one takes to compile — on every edit.
  Future<void> _reload() async {
    final old = _instance;
    _generation++;
    _instance = null;
    _runtimeInstanceId = null;
    if (old != null) await widget.service.unload(old);
    if (!mounted) return;
    // The new instance numbers its revisions from the start, and the cache is
    // keyed by nothing but the number.
    _state.reset();
    await _load();
  }

  Future<void> _load() async {
    final generation = ++_generation;
    final spec = widget.spec;
    final runtimeInstanceId = '${spec.contributionKey}#${_nextInstance++}';
    final started = Stopwatch()..start();
    try {
      final instance = await widget.service.load(
        manifestJson: spec.manifestJson,
        source: spec.source,
        instanceId: runtimeInstanceId,
        granted: spec.granted,
        config: spec.config,
        boundServerId: spec.serverId,
      );
      if (!mounted || generation != _generation) {
        await widget.service.unload(instance);
        return;
      }
      _instance = instance;
      _runtimeInstanceId = runtimeInstanceId;
      widget.service.bridge.onPatch[runtimeInstanceId] = _applyPatch;
      widget.service.bridge.onAnswered[runtimeInstanceId] = _onHostAnswered;

      // `init` before `open`, and only if the plugin has one: it is where a
      // plugin reads its stored state, and a surface drawn before it would
      // show the empty version of everything.
      if (widget.service.hasExport(instance, 'init')) {
        _beginCall();
        final initStarted = Stopwatch()..start();
        try {
          await widget.service.call(
            instance,
            'init',
            jsonEncode({
              'server': spec.serverId == null
                  ? null
                  : widget.service.bridge.handles.issue(
                      runtimeInstanceId,
                      spec.serverId!,
                    ),
              'locale':
                  Localizations.maybeLocaleOf(context)?.toLanguageTag() ?? 'en',
            }),
          );
          recordPluginEvent(
            spec.pluginId,
            stage: PluginStage.init,
            elapsed: initStarted.elapsed,
          );
        } catch (e) {
          // Recorded and rethrown: the `catch` below turns it into the message
          // on screen, and what is added here is the *stage*. Without it a
          // plugin that reads its stored state and throws reads as a load
          // failure, which is a different thing to go and look at.
          recordPluginEvent(
            spec.pluginId,
            stage: PluginStage.init,
            elapsed: initStarted.elapsed,
            failure: pluginFailureTag(e),
          );
          rethrow;
        } finally {
          _endCall();
        }
        if (!mounted || generation != _generation) return;
      }

      await _callForUi(
        generation,
        'open',
        jsonEncode({
          'kind': spec.kind,
          'id': spec.contributionId,
          if (spec.serverId != null)
            'server': widget.service.bridge.handles.issue(
              runtimeInstanceId,
              spec.serverId!,
            ),
        }),
      );
      _restartTimer();

      // After `open`, not before: the tree is on screen and the plugin can
      // patch into it as its collection lands, which is the whole reason a
      // hook answers nothing. Awaited so a plugin that collects quickly has
      // filled the page before the first tick, and unawaited by nobody — a
      // slow one holds this future and not the surface.
      unawaited(_fireHook('enter'));
    } catch (e, s) {
      Loggers.app.warning('Loading ${spec.pluginId}', e, s);
      // Recorded whether or not this surface is still on screen: a plugin that
      // will not compile is the same fact either way, and it is the one a
      // report most needs — nothing after it has run.
      recordPluginEvent(
        spec.pluginId,
        stage: PluginStage.load,
        elapsed: started.elapsed,
        failure: pluginFailureTag(e),
      );
      if (!mounted || generation != _generation) return;
      setState(() => _error = '$e');
    }
  }

  /// Tells the plugin this surface was entered.
  ///
  /// The scope is this surface's: the machine it is bound to, or — for one
  /// bound to none, which is what a fleet-wide surface is — every machine the
  /// host will name. Which of those the plugin is actually given is the
  /// service's decision and turns on `server.list`; see
  /// [PluginRuntimeService.hook].
  Future<void> _fireHook(String kind) async {
    final instance = _instance;
    if (instance == null) return;
    final spec = widget.spec;
    _beginCall();
    final started = Stopwatch()..start();
    try {
      // What the plugin threw, or null. A hook that failed leaves the tree it
      // already drew on screen, so nothing the user can see says the
      // collection threw — which is why it is recorded rather than only
      // logged.
      final failed = await widget.service.hook(
        instance,
        kind: kind,
        contributionId: spec.contributionId,
        granted: spec.granted,
        serverIds: spec.serverId != null
            ? [spec.serverId!]
            : (widget.fleetServerIds ?? const []),
      );
      // Only when there was one to run. A plugin that exports no `onHook`
      // collects somewhere else, and recording a success for a call that did
      // not happen would clear the failure count of the call that did.
      if (widget.service.hasExport(instance, 'onHook')) {
        recordPluginEvent(
          spec.pluginId,
          stage: PluginStage.hook,
          elapsed: started.elapsed,
          failure: failed == null ? null : pluginFailureTag(failed),
        );
      }
    } finally {
      _endCall();
    }
  }

  void _restartTimer() {
    _timer?.cancel();
    final interval = widget.refreshInterval;
    if (interval == null) return;
    _timer = Timer.periodic(interval, (_) => unawaited(_tick()));
  }

  Future<void> _tick() async {
    if (_tickRunning) {
      _tickQueued = true;
      return;
    }
    _tickRunning = true;
    try {
      do {
        _tickQueued = false;
        final instance = _instance;
        if (instance == null) return;
        if (!widget.service.hasExport(instance, 'tick')) {
          // Nothing to call. Stopping the timer rather than calling into a
          // missing export every interval for the life of the surface.
          _timer?.cancel();
          _timer = null;
          return;
        }
        await _callForUi(_generation, 'tick', '');
      } while (_tickQueued && mounted && _instance != null);
    } finally {
      _tickRunning = false;
    }
  }

  /// The app finished something the plugin asked for.
  ///
  /// **A call is the only thing that hands an answer to a plugin**, and the
  /// plugin cannot ask for one. Work a call deliberately did not wait for — a
  /// scan the user can stop, which is the only kind that leaves the instance
  /// free to be told to stop it — therefore arrives with nobody to give it to,
  /// and on a surface with no refresh interval nothing would ever come along.
  /// So this is what calls in.
  ///
  /// **Deferred rather than skipped while a call is running.** A call in
  /// progress usually drains its own answers, but not always: the in-flight
  /// count spans the future, and the export's promise may have settled before
  /// the answer
  /// landed — a window in which "the call will take it" is false and nothing
  /// else was going to. Deferring costs one extra call after a call that had
  /// answers, and that call's own delivery pass takes whatever was stranded.
  void _onHostAnswered() {
    if (_instance == null || !mounted) return;
    if (_callsInFlight > 0) {
      // The tick itself drives every answer it waits for. Scheduling another
      // tick for those answers creates a loop when `onTick` performs a host
      // call: tick -> answer -> tick forever. Timer ticks are still coalesced
      // by [_tick], and an answer that arrives during any other export gets
      // one follow-up tick below.
      if (!_tickRunning) _answeredDuringCall = true;
      return;
    }
    unawaited(_tick());
  }

  /// Ends a call, and follows it with a tick if anything landed during it.
  void _endCall() {
    assert(_callsInFlight > 0);
    _callsInFlight--;
    if (_callsInFlight > 0) return;
    if (!_answeredDuringCall) return;
    _answeredDuringCall = false;
    if (!mounted || _instance == null) return;
    unawaited(_tick());
  }

  void _beginCall() => _callsInFlight++;

  Future<void> _onEvent(Object? msg, Object? value) async {
    final instance = _instance;
    if (instance == null) return;
    if (!widget.service.hasExport(instance, 'onEvent')) return;
    await _callForUi(
      _generation,
      'onEvent',
      jsonEncode({'msg': msg, 'value': value}),
    );
  }

  /// Calls an export that answers `{ui?, values?}` and applies what came back.
  ///
  /// A `values`-only answer is the cheap path and the common one: it sets the
  /// bound slots' notifiers and rebuilds nothing — see PLUGINS.md 5.2.
  Future<void> _callForUi(int generation, String export, String input) async {
    final instance = _instance;
    if (instance == null) return;
    _beginCall();
    final started = Stopwatch()..start();
    try {
      final raw = await widget.service.call(instance, export, input);
      // Before the tree is read: what this records is that the plugin
      // answered, and how long it took. Whether the app could then draw what
      // it said is the branch below and is its own failure.
      recordPluginEvent(
        widget.spec.pluginId,
        stage: _stageOf(export),
        elapsed: started.elapsed,
      );
      if (!mounted || generation != _generation) return;

      final decoded = raw.isEmpty ? null : jsonDecode(raw);
      if (decoded is! Map) return;

      final values = decoded['values'];
      if (values is Map) {
        _state.applyValues({
          for (final e in values.entries)
            if (e.key is String) e.key as String: e.value,
        });
      }

      final ui = decoded['ui'];
      if (ui == null) {
        // "Nothing changed, keep the last tree" — which is what a tick that
        // only moved a value answers, and what makes that path cost nothing.
        if (_error != null) setState(() => _error = null);
        return;
      }
      final tree = PluginNode.fromJson(ui);
      if (tree == null) {
        // The plugin ran and answered; what it answered is not a tree. A
        // *drawing* failure, which is one of the three things "the plugin does
        // nothing" turns out to be.
        recordPluginEvent(
          widget.spec.pluginId,
          stage: PluginStage.patch,
          elapsed: started.elapsed,
          failure: 'bad_tree',
        );
        setState(
          () => _error = 'the plugin answered a tree that will not read',
        );
        return;
      }
      _state.seedSlots(tree);
      setState(() {
        _tree = tree;
        _error = null;
      });
    } catch (e, s) {
      Loggers.app.warning('$export on ${widget.spec.pluginId}', e, s);
      recordPluginEvent(
        widget.spec.pluginId,
        stage: _stageOf(export),
        elapsed: started.elapsed,
        failure: pluginFailureTag(e),
      );
      if (!mounted || generation != _generation) return;
      setState(() => _error = '$e');
    } finally {
      _endCall();
    }
  }

  /// Which stage an export call is, for the record.
  static PluginStage _stageOf(String export) => switch (export) {
    'open' => PluginStage.open,
    'tick' => PluginStage.tick,
    'onEvent' => PluginStage.event,
    'init' => PluginStage.init,
    _ => PluginStage.open,
  };

  /// Replaces the subtree a JSON Pointer names in the tree on screen.
  ///
  /// For a plugin streaming a log, so it does not resend the page per line.
  /// A pointer that names nothing is dropped: the tree it was written against
  /// is one the surface may already have replaced.
  void _applyPatch(PluginPatch patch) {
    final tree = _tree;
    if (tree == null) return;
    final replaced = _replaceAt(tree, _pointer(patch.path), patch.node);
    if (replaced == null) return;
    setState(() => _tree = replaced);
  }

  /// The child indices a JSON Pointer walks.
  ///
  /// Only `/c/<n>` steps are honoured, which is the whole of what a pointer
  /// into this tree can mean: `p` and `on` are properties of a node, not
  /// nodes, and a pointer into one would be replacing a value with a widget.
  static List<int> _pointer(String path) {
    final steps = <int>[];
    final parts = path.split('/');
    for (var i = 0; i < parts.length; i++) {
      if (parts[i] != 'c' || i + 1 >= parts.length) continue;
      final index = int.tryParse(parts[i + 1]);
      if (index == null) return const [];
      steps.add(index);
      i++;
    }
    return steps;
  }

  static PluginNode? _replaceAt(
    PluginNode node,
    List<int> steps,
    PluginNode replacement,
  ) {
    if (steps.isEmpty) return replacement;
    final index = steps.first;
    if (index < 0 || index >= node.children.length) return null;
    final child = _replaceAt(
      node.children[index],
      steps.sublist(1),
      replacement,
    );
    if (child == null) return null;
    final children = [...node.children]..[index] = child;
    return PluginNode(
      type: node.type,
      // A new revision, because the app must not hand back the Widget it built
      // for the old one — which is exactly what a stale revision would do.
      rev: null,
      key: node.key,
      props: node.props,
      children: children,
      events: node.events,
    );
  }

  @override
  Widget build(BuildContext context) {
    final error = _error;
    if (error != null) {
      return _Failed(pluginId: widget.spec.pluginId, detail: error);
    }
    final tree = _tree;
    if (tree == null) return UIs.centerLoading;
    return PluginRenderer(tree: tree, state: _state, onEvent: _onEvent);
  }
}

/// A plugin that could not be loaded, or whose call threw.
///
/// Named and visible rather than an empty space: a card that silently is not
/// there is indistinguishable from one the user turned off.
/// What a plugin that threw looks like.
///
/// **Whole, scrollable and selectable.** What lands here is a JavaScript error
/// with the plugin's own stack under it, and it used to be clipped at three
/// lines with an ellipsis — which cut off exactly the part naming the function
/// that failed. The person reading this is the plugin's author, and the next
/// thing they do is paste it somewhere.
///
/// Monospace for the same reason: a stack is code, and a proportional font
/// makes two frames that differ look alike.
class _Failed extends StatelessWidget {
  const _Failed({required this.pluginId, required this.detail});

  final String pluginId;
  final String detail;

  @override
  Widget build(BuildContext context) {
    final color = context.theme.colorScheme.error;
    return Padding(
      padding: const EdgeInsets.all(13),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        spacing: 5,
        children: [
          Row(
            spacing: 5,
            children: [
              Icon(Icons.error_outline, size: 17, color: color),
              Expanded(
                child: Text(
                  pluginId,
                  style: TextStyle(color: color),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          Flexible(
            child: SingleChildScrollView(
              child: SelectableText(
                detail,
                style: const TextStyle(
                  fontSize: 11,
                  fontFamily: 'monospace',
                  color: Colors.grey,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
