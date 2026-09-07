import 'dart:async';
import 'dart:convert';

import 'package:fl_lib/fl_lib.dart';
import 'package:flutter/material.dart';
import 'package:server_box/data/model/plugin/l10n.dart';
import 'package:server_box/data/model/plugin/node.dart';
import 'package:server_box/data/provider/plugin/bridge.dart';
import 'package:server_box/data/provider/plugin/runtime.dart';
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

  /// Unique per surface for as long as it is open, which is also the lifetime
  /// of the SDK's `frame()` state — one instance tracks one tree, so two
  /// surfaces of one plugin must not share an instance.
  String get instanceId =>
      '$pluginId:$kind:$contributionId:${serverId ?? '-'}';
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
  });

  final PluginSurfaceSpec spec;
  final PluginRuntimeService service;

  /// How often `tick` runs while this is on screen, or null for never.
  ///
  /// Only while visible: a card behind another tab has nothing to show, and a
  /// plugin ticking there is a plugin running commands nobody asked for.
  final Duration? refreshInterval;

  @override
  State<PluginSurfaceView> createState() => _PluginSurfaceViewState();
}

class _PluginSurfaceViewState extends State<PluginSurfaceView> {
  late final _state = PluginSurfaceState(l10n: widget.spec.l10n);

  BigInt? _instance;
  PluginNode? _tree;
  String? _error;
  Timer? _timer;

  /// Bumped whenever the instance is replaced, so a call that outlives it
  /// publishes nothing. Every await re-checks it.
  int _generation = 0;

  @override
  void initState() {
    super.initState();
    unawaited(_load());
  }

  @override
  void didUpdateWidget(covariant PluginSurfaceView old) {
    super.didUpdateWidget(old);
    if (old.spec.instanceId != widget.spec.instanceId ||
        old.spec.source != widget.spec.source) {
      unawaited(_reload());
    } else if (old.refreshInterval != widget.refreshInterval) {
      _restartTimer();
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    _generation++;
    final instance = _instance;
    _instance = null;
    widget.service.bridge.onPatch.remove(widget.spec.instanceId);
    // Not awaited, and not skipped: unloading waits for the plugin's thread,
    // which is not something `dispose` may do — but the instance has to go, or
    // its thread outlives every surface that ever showed it.
    if (instance != null) unawaited(widget.service.unload(instance));
    _state.dispose();
    super.dispose();
  }

  Future<void> _reload() async {
    final old = _instance;
    _generation++;
    _instance = null;
    if (old != null) await widget.service.unload(old);
    if (!mounted) return;
    await _load();
  }

  Future<void> _load() async {
    final generation = ++_generation;
    final spec = widget.spec;
    try {
      final instance = await widget.service.load(
        manifestJson: spec.manifestJson,
        source: spec.source,
        instanceId: spec.instanceId,
        granted: spec.granted,
        config: spec.config,
        boundServerId: spec.serverId,
      );
      if (!mounted || generation != _generation) {
        await widget.service.unload(instance);
        return;
      }
      _instance = instance;
      widget.service.bridge.onPatch[spec.instanceId] = _applyPatch;

      // `init` before `open`, and only if the plugin has one: it is where a
      // plugin reads its stored state, and a surface drawn before it would
      // show the empty version of everything.
      if (widget.service.hasExport(instance, 'init')) {
        await widget.service.call(
          instance,
          'init',
          jsonEncode({
            'server': spec.serverId == null
                ? null
                : widget.service.bridge.handles.issue(
                    spec.instanceId,
                    spec.serverId!,
                  ),
            'locale': Localizations.maybeLocaleOf(context)?.toLanguageTag() ??
                'en',
          }),
        );
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
              spec.instanceId,
              spec.serverId!,
            ),
        }),
      );
      _restartTimer();
    } catch (e, s) {
      Loggers.app.warning('Loading ${spec.pluginId}', e, s);
      if (!mounted || generation != _generation) return;
      setState(() => _error = '$e');
    }
  }

  void _restartTimer() {
    _timer?.cancel();
    final interval = widget.refreshInterval;
    if (interval == null) return;
    _timer = Timer.periodic(interval, (_) => unawaited(_tick()));
  }

  Future<void> _tick() async {
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
  }

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
    try {
      final raw = await widget.service.call(instance, export, input);
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
        setState(() => _error = 'the plugin answered a tree that will not read');
        return;
      }
      _state.seedSlots(tree);
      setState(() {
        _tree = tree;
        _error = null;
      });
    } catch (e, s) {
      Loggers.app.warning('$export on ${widget.spec.pluginId}', e, s);
      if (!mounted || generation != _generation) return;
      setState(() => _error = '$e');
    }
  }

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
    if (error != null) return _Failed(pluginId: widget.spec.pluginId, detail: error);
    final tree = _tree;
    if (tree == null) return UIs.centerLoading;
    return PluginRenderer(tree: tree, state: _state, onEvent: _onEvent);
  }
}

/// A plugin that could not be loaded, or whose call threw.
///
/// Named and visible rather than an empty space: a card that silently is not
/// there is indistinguishable from one the user turned off.
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
              Text(pluginId, style: TextStyle(color: color)),
            ],
          ),
          Text(detail, style: UIs.textGrey, maxLines: 3, overflow: TextOverflow.ellipsis),
        ],
      ),
    );
  }
}
