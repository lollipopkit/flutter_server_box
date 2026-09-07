import 'dart:async';

import 'package:fl_lib/fl_lib.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:server_box/core/utils/refresh_interval.dart';
import 'package:server_box/data/model/plugin/installed.dart';
import 'package:server_box/data/model/server/server_private_info.dart';
import 'package:server_box/data/model/server/system.dart';
import 'package:server_box/data/provider/plugin/runtime.dart';
import 'package:server_box/data/provider/server/single.dart';
import 'package:server_box/data/store/plugin.dart';
import 'package:server_box/src/rust/api/plugin.dart' as ffi;
import 'package:server_box/src/rust/api/script.dart' as script_ffi;

/// A status plugin's readings on the server detail page. PLUGINS.md section 9.
///
/// A status plugin has no surface: it says which command to run and turns that
/// command's output into readings, and this draws them with the widgets the
/// app draws its own with. That is what lets it ship before the widget
/// vocabulary is settled, and what keeps the worst outcome of a bad status
/// plugin to a wrong number.
///
/// **Collection belongs to the card, not to the poll.** The command is
/// arbitrary shell a plugin returned, and running it for every server on every
/// poll would put it on the hot path for machines nobody is looking at. Here
/// it runs while the card is on screen, on the interval the user set for
/// custom commands — the same reasoning that moved those off the status
/// function.
///
/// One instance and one command per card. Section 9.1 leaves batching several
/// plugins into one round trip to the app, and a detail page has one or two of
/// these: a second connection is not what the extra complication would buy.
class PluginStatusCard extends ConsumerStatefulWidget {
  const PluginStatusCard({
    super.key,
    required this.plugin,
    required this.spi,
    required this.system,
    this.runScript,
  });

  final InstalledPlugin plugin;
  final Spi spi;

  /// What the far side is running, which decides both the command the plugin
  /// answers with and the shell that runs it.
  final SystemType system;

  /// How the generated script reaches the machine, or null for the app's own
  /// way — `ensureExec`, which is the one place that decides whether a command
  /// travels over SSH or a monitor agent.
  ///
  /// A seam rather than a mock, and the same one `SshDataSource` has: a test
  /// can then run the script the app really generated, which is the half that
  /// is worth checking and the half a mocked answer would skip.
  final Future<String> Function(String script, {String? entry})? runScript;

  @override
  ConsumerState<PluginStatusCard> createState() => _PluginStatusCardState();
}

class _PluginStatusCardState extends ConsumerState<PluginStatusCard> {
  ffi.PluginStatusResult? _result;
  String? _error;
  Timer? _timer;
  BigInt? _instance;

  /// Bumped when the instance is replaced, so a collection that outlives it
  /// publishes nothing. Every await re-checks it.
  int _generation = 0;

  /// Held rather than read when needed.
  ///
  /// `dispose` has to unload the instance, and `ref` is unsafe from there —
  /// it resolves through the `BuildContext`, which is deactivated by then.
  /// Riverpod says so with a `StateError` rather than a null, which a test
  /// found here.
  late final PluginRuntimeService _service;

  String get _featureId =>
      '${widget.plugin.id}:${widget.plugin.manifest.status?.id ?? ''}';

  @override
  void initState() {
    super.initState();
    _service = ref.read(pluginRuntimeProvider);
    unawaited(_collect());
    final interval = customCmdRefreshInterval();
    if (interval != null) {
      _timer = Timer.periodic(interval, (_) => unawaited(_collect()));
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    _generation++;
    final instance = _instance;
    _instance = null;
    // Not awaited, and not skipped: unloading waits for the plugin's thread,
    // which `dispose` may not do — but the instance has to go, or its thread
    // outlives every page that showed it.
    if (instance != null) unawaited(_service.unload(instance));
    super.dispose();
  }

  /// The whole cycle: ask what to run, run it, hand back what it printed.
  ///
  /// The instance is loaded per collection and released after it. A status
  /// plugin holds nothing between collections that it cannot read back out of
  /// its own storage, and a thread per plugin per server kept alive for a
  /// reading taken every half minute is not a trade worth making.
  Future<void> _collect() async {
    final generation = ++_generation;
    final plugin = widget.plugin;
    final status = plugin.manifest.status;
    if (status == null) return;

    // A platform the plugin did not name. Asking anyway gets nothing, or a
    // command for the wrong system — which is a command that fails on the
    // machine it was sent to.
    final platform = switch (widget.system) {
      SystemType.linux => 'linux',
      SystemType.bsd => 'bsd',
      SystemType.windows => 'windows',
    };
    if (!status.platforms.contains(platform)) {
      if (mounted) setState(() => _error = null);
      return;
    }

    BigInt? instance;
    try {
      instance = await _service.load(
        manifestJson: plugin.manifestJson,
        source: plugin.source,
        // Per server: a plugin's command may depend on what was typed into
        // this server's form.
        instanceId: 'status:${plugin.id}:${widget.spi.id}',
        granted: plugin.granted,
        config: PluginCfgStore.instance.fetch(widget.spi.id, plugin.id),
        boundServerId: widget.spi.id,
      );
      if (!mounted || generation != _generation) {
        await _service.unload(instance);
        return;
      }
      _instance = instance;

      final cmd = await _service.statusCmd(instance, platform);
      if (!mounted || generation != _generation) return;

      final script = script_ffi.pluginCmdsCommand(
        system: switch (widget.system) {
          SystemType.windows => 'windows',
          SystemType.bsd => 'bsd',
          _ => 'linux',
        },
        cmds: [script_ffi.PluginCmd(name: _featureId, cmd: cmd.cmd)],
      );
      // Unix reads it on stdin, so nothing in the command has to survive shell
      // quoting. Windows is already a complete command line.
      final entry = widget.system == SystemType.windows ? null : 'sh';
      final output = await (widget.runScript ?? _runOnServer)(
        script,
        entry: entry,
      );
      if (!mounted || generation != _generation) return;

      final segments = await script_ffi.parseScriptSegments(raw: output);
      final mine = segments
          .where((s) => script_ffi.pluginResultName(key: s.key) == _featureId)
          .map((s) => s.value)
          .firstOrNull;
      if (mine == null) {
        throw StateError('the command printed no section of its own');
      }

      final result = await _service.statusParse(instance, mine);
      if (!mounted || generation != _generation) return;
      setState(() {
        _result = result;
        _error = null;
      });
    } catch (e, s) {
      Loggers.app.warning('Status plugin ${plugin.id}', e, s);
      if (!mounted || generation != _generation) return;
      // Kept, not cleared: the readings from the last collection that worked
      // are more useful than a blank card, and the failure is shown beside
      // them.
      setState(() => _error = '$e');
    } finally {
      final loaded = instance;
      if (loaded != null && identical(loaded, _instance)) {
        _instance = null;
        await _service.unload(loaded);
      }
    }
  }

  Future<String> _runOnServer(String script, {String? entry}) async {
    final exec = await ref
        .read(serverProvider(widget.spi.id).notifier)
        .ensureExec();
    final ran = await exec.run(script, entry: entry);
    return ran.stdout;
  }

  @override
  Widget build(BuildContext context) {
    final result = _result;
    final error = _error;
    final title = result?.title.isNotEmpty == true
        ? result!.title
        : widget.plugin.manifest.name;

    return CardX(
      child: Padding(
        padding: const EdgeInsets.all(13),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          spacing: 7,
          children: [
            Row(
              spacing: 7,
              children: [
                const Icon(Icons.extension_outlined, size: 17),
                Text(title, style: UIs.text15Bold),
              ],
            ),
            if (result == null && error == null) UIs.centerLoading,
            for (final item in result?.items ?? const <ffi.PluginStatusItem>[])
              _Reading(item: item),
            if (result?.note case final note?)
              Text(note, style: UIs.text12Grey),
            if (error != null)
              Text(
                error,
                style: TextStyle(
                  fontSize: 11,
                  color: context.theme.colorScheme.error,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
          ],
        ),
      ),
    );
  }
}

/// One reading, drawn the way the app draws its own.
class _Reading extends StatelessWidget {
  const _Reading({required this.item});

  final ffi.PluginStatusItem item;

  @override
  Widget build(BuildContext context) {
    final scheme = context.theme.colorScheme;
    // A name rather than a colour, so a plugin's row looks like the app's own
    // in both themes and cannot ship an unreadable one.
    final tone = switch (item.tone) {
      'muted' => scheme.outline,
      'success' => Colors.green,
      'warning' => Colors.orange,
      'danger' => scheme.error,
      _ => null,
    };
    final percent = item.percent;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        KvRow(
          k: item.label,
          v: item.value,
          vBuilder: tone == null
              ? null
              : () => Text(item.value, style: TextStyle(fontSize: 11, color: tone)),
        ),
        // Absent where the reading is not a proportion — a temperature, a
        // count — and dropped rather than clamped when it was out of range.
        if (percent != null)
          Padding(
            padding: const EdgeInsets.only(bottom: 3),
            child: LinearProgressIndicator(
              value: percent,
              minHeight: 3,
              color: tone,
            ),
          ),
      ],
    );
  }
}
