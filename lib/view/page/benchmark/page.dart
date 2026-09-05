// ignore_for_file: invalid_use_of_protected_member

import 'dart:async';

import 'package:fl_lib/fl_lib.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:server_box/core/extension/context/locale.dart';
import 'package:server_box/core/route.dart';
import 'package:server_box/data/model/server/benchmark/benchmark_run.dart';
import 'package:server_box/data/model/server/benchmark/yabs_options.dart';
import 'package:server_box/data/model/server/benchmark/yabs_script.dart';
import 'package:server_box/data/model/server/system.dart';
import 'package:server_box/data/provider/benchmark.dart';
import 'package:server_box/data/provider/server/single.dart';
import 'package:server_box/view/page/benchmark/estimate.dart';
import 'package:server_box/view/page/benchmark/phase.dart';
import 'package:server_box/view/page/benchmark/result.dart';

/// One server's benchmarks: what to run, what is running, and what has run.
///
/// The options are on the page rather than behind a dialog, and every phase yabs
/// can do is one of them. Each costs something only the person paying for the
/// server can weigh — a couple of gigabytes written to a disk, tens of
/// gigabytes of egress, or a public page on someone else's website describing
/// their machine — so the run is configured in full, in the open, before it
/// starts. This app supplies defaults and nothing more.
class BenchmarkPage extends ConsumerStatefulWidget {
  const BenchmarkPage({super.key, required this.args});

  final SpiRequiredArgs args;

  @override
  ConsumerState<BenchmarkPage> createState() => _BenchmarkPageState();

  static const route = AppRouteArg<void, SpiRequiredArgs>(
    page: BenchmarkPage.new,
    path: '/benchmark',
  );
}

class _BenchmarkPageState extends ConsumerState<BenchmarkPage> {
  late final _spi = widget.args.spi;

  var _options = const YabsOptions();
  final _workDirCtrl = TextEditingController();
  final _iperfCtrl = TextEditingController();

  /// Redraws the elapsed time while a run is going. The record itself only
  /// changes when a poll comes back, which is up to twenty seconds apart.
  Timer? _tick;

  @override
  void initState() {
    super.initState();
    // The last run's options are the best guess at the next run's: someone who
    // turned Geekbench on once means it.
    final last = ref.read(benchmarkProvider(_spi)).history.firstOrNull;
    if (last != null) _options = last.options;
    _workDirCtrl.text = _options.workDir;
    _iperfCtrl.text = _options.customIperfServers;
    _tick = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted && ref.read(benchmarkProvider(_spi)).active != null) {
        setState(() {});
      }
    });
  }

  @override
  void dispose() {
    _tick?.cancel();
    _workDirCtrl.dispose();
    _iperfCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(benchmarkProvider(_spi));
    ref.listen<String?>(benchmarkProvider(_spi).select((s) => s.error), (_, err) {
      if (err == null) return;
      Toast.error(l10n.benchmarkStartFailed, body: err);
      ref.read(benchmarkProvider(_spi).notifier).clearError();
    });

    return Scaffold(
      appBar: CustomAppBar(
        title: Text(l10n.benchmark),
      ),
      body: _buildBody(state),
    );
  }
}

// --- Widgets ---

extension _Widgets on _BenchmarkPageState {
  Widget _buildBody(BenchmarkState state) {
    final system = ref.watch(serverProvider(_spi.id)).status.system;
    // yabs is a bash script that reads /proc and downloads Linux binaries.
    // Nothing about it degrades gracefully elsewhere, so the page says so
    // rather than letting a run fail four commands in.
    if (system != SystemType.linux) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 27),
          child: Text(
            l10n.benchmarkLinuxOnly(system.name),
            style: UIs.textGrey,
            textAlign: TextAlign.center,
          ),
        ),
      );
    }

    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 7),
      children: [
        if (state.active case final run?)
          _buildRunning(run, state)
        else
          ..._buildConfig(state),
        UIs.height13,
        if (state.history.isNotEmpty) ...[
          Text('  ${libL10n.log}', style: UIs.textGrey),
          UIs.height7,
          ...state.history.map(_buildHistoryTile),
        ] else if (state.active == null)
          Padding(
            padding: const EdgeInsets.all(27),
            child: Text(
              l10n.benchmarkNoRuns,
              style: UIs.textGrey,
              textAlign: TextAlign.center,
            ),
          ),
        UIs.height13,
        Center(
          child: Text(
            l10n.benchmarkUpstream(YabsScript.upstreamVersion),
            style: UIs.text12Grey,
          ),
        ),
        UIs.height13,
      ],
    );
  }

  Widget _buildRunning(BenchmarkRun run, BenchmarkState state) {
    final phase = BenchmarkPhase.of(run.log);
    return CardX(
      child: Padding(
        padding: const EdgeInsets.all(13),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const SizedBox(
                  width: 17,
                  height: 17,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
                UIs.width13,
                Expanded(
                  child: Text(phase.label, style: UIs.text15Bold),
                ),
                Text(_fmtDuration(run.elapsed), style: UIs.textGrey),
              ],
            ),
            UIs.height13,
            // The estimate is what makes a fifteen-minute wait legible. It is
            // not a progress bar because there is nothing to base one on: yabs
            // reports no progress inside a phase.
            Text(
              l10n.benchmarkEstimatedTime('${BenchmarkEstimate(run.options).minutes}'),
              style: UIs.text12Grey,
            ),
            if (run.log.isNotEmpty) ...[
              UIs.height13,
              _buildLog(run.log, initiallyExpanded: true),
            ],
            UIs.height13,
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton.icon(
                  onPressed: state.isBusy ? null : _onCancel,
                  icon: const Icon(Icons.stop_circle_outlined),
                  label: Text(libL10n.stop),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  List<Widget> _buildConfig(BenchmarkState state) {
    final estimate = BenchmarkEstimate(_options);
    return [
      CardX(
        child: Padding(
          padding: const EdgeInsets.all(13),
          child: Text(l10n.benchmarkIntro, style: UIs.text13Grey),
        ),
      ),
      UIs.height13,
      CardX(
        child: Column(
          children: [
            _switch(
              title: libL10n.disk,
              subtitle: l10n.benchmarkDiskTip,
              value: _options.disk,
              icon: Icons.storage,
              onChanged: (v) => setState(() => _options = _options.copyWith(disk: v)),
            ),
            _switch(
              title: libL10n.network,
              subtitle: l10n.benchmarkNetworkTip,
              value: _options.network,
              icon: Icons.speed,
              onChanged: (v) =>
                  setState(() => _options = _options.copyWith(network: v)),
            ),
            if (_options.network) ...[
              _switch(
                title: l10n.benchmarkReducedNetwork,
                subtitle: l10n.benchmarkReducedNetworkTip(
                  estimate.trafficBytesWith(reduced: false).bytes2Str,
                  estimate.trafficBytesWith(reduced: true).bytes2Str,
                ),
                value: _options.reducedNetwork,
                onChanged: (v) => setState(
                  () => _options = _options.copyWith(reducedNetwork: v),
                ),
              ),
              _textField(
                controller: _iperfCtrl,
                label: l10n.benchmarkCustomIperf,
                hint: l10n.benchmarkCustomIperfTip,
                onChanged: (v) => setState(
                  () => _options = _options.copyWith(customIperfServers: v),
                ),
              ),
            ],
            _switch(
              title: 'CPU',
              // The one option whose cost is not the user's own resources but a
              // disclosure about their machine, so it is styled as a warning
              // and starts off.
              subtitle: l10n.benchmarkCpuTip,
              value: _options.cpu,
              icon: Icons.memory,
              warn: true,
              onChanged: (v) =>
                  setState(() => _options = _options.copyWith(cpu: v)),
            ),
            if (_options.cpu)
              ListTile(
                contentPadding: const EdgeInsets.only(left: _rowLeft, right: 13),
                minLeadingWidth: _iconSize,
                horizontalTitleGap: _iconGap,
                leading: _noIcon,
                title: Text(_options.geekbenchVersion.label, style: UIs.text13),
                trailing: DropdownButton<GeekbenchVersion>(
                  value: _options.geekbenchVersion,
                  underline: UIs.placeholder,
                  items: [
                    for (final v in GeekbenchVersion.values)
                      DropdownMenuItem(value: v, child: Text(v.label)),
                  ],
                  onChanged: (v) => setState(
                    () => _options = _options.copyWith(
                      geekbenchVersion: v ?? _options.geekbenchVersion,
                    ),
                  ),
                ),
              ),
            _switch(
              title: l10n.benchmarkIpInfo,
              subtitle: l10n.benchmarkIpInfoTip,
              value: _options.ipInfo,
              icon: Icons.public,
              warn: true,
              onChanged: (v) =>
                  setState(() => _options = _options.copyWith(ipInfo: v)),
            ),
            _switch(
              title: l10n.benchmarkPreferBin,
              subtitle: l10n.benchmarkPreferBinTip,
              value: _options.preferPrecompiledBinaries,
              icon: Icons.download_outlined,
              onChanged: (v) => setState(
                () => _options = _options.copyWith(preferPrecompiledBinaries: v),
              ),
            ),
            _textField(
              controller: _workDirCtrl,
              label: l10n.benchmarkWorkDir,
              hint: l10n.benchmarkWorkDirTip,
              icon: Icons.folder_outlined,
              onChanged: (v) =>
                  setState(() => _options = _options.copyWith(workDir: v)),
            ),
          ],
        ),
      ),
      UIs.height13,
      _buildSummary(estimate),
      UIs.height13,
      FilledButton.icon(
        onPressed: state.isBusy ? null : _onStart,
        icon: state.isBusy
            ? const SizedBox(
                width: 15,
                height: 15,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : const Icon(Icons.play_arrow),
        label: Text(libL10n.start),
      ),
    ];
  }

  /// What the chosen options will cost, in one place, right above the button
  /// that spends it.
  Widget _buildSummary(BenchmarkEstimate estimate) {
    if (_options.isSystemInfoOnly) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 13),
        child: Text(l10n.benchmarkNothingSelected, style: UIs.text12Grey),
      );
    }
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 13),
      child: Wrap(
        spacing: 13,
        runSpacing: 4,
        children: [
          _chip(Icons.schedule, l10n.benchmarkEstimatedTime('${estimate.minutes}')),
          if (estimate.trafficBytes > 0)
            _chip(
              Icons.swap_vert,
              l10n.benchmarkEstimatedTraffic(estimate.trafficBytes.bytes2Str),
            ),
          if (estimate.requiredFreeBytes case final free?)
            _chip(
              Icons.sd_storage_outlined,
              '${libL10n.disk} ${free.bytes2Str}',
            ),
        ],
      ),
    );
  }

  Widget _chip(IconData icon, String text) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 13, color: UIs.textGrey.color),
        UIs.width7,
        Text(text, style: UIs.text12Grey),
      ],
    );
  }

  /// One left edge for the icons, one for everything written.
  ///
  /// Pinned here rather than left to `ListTile`'s defaults because this column
  /// mixes three kinds of row — a switch, a dropdown and a text field — and
  /// only the first two are ListTiles. `minLeadingWidth` and
  /// `horizontalTitleGap` both fall back to theme values, so a layout that
  /// happened to agree with them would come apart under a different theme.
  static const _rowLeft = 17.0;
  static const _iconSize = 24.0;
  static const _iconGap = 16.0;

  /// The icon column, left empty.
  ///
  /// A sub-option reserves it rather than indenting by a number of its own:
  /// that is what puts its text on the same edge as the titles above it,
  /// instead of on a third edge between those titles and their icons.
  static const _noIcon = SizedBox(width: _iconSize);

  Widget _switch({
    required String title,
    required String subtitle,
    required bool value,
    required ValueChanged<bool> onChanged,
    IconData? icon,
    bool warn = false,
  }) {
    return SwitchListTile(
      contentPadding: const EdgeInsets.only(left: _rowLeft, right: 13),
      minLeadingWidth: _iconSize,
      horizontalTitleGap: _iconGap,
      secondary: icon == null ? _noIcon : Icon(icon, size: _iconSize),
      title: Text(title, style: UIs.text15),
      subtitle: Text(
        subtitle,
        style: warn && value
            ? UIs.text12Grey.copyWith(color: Colors.orange)
            : UIs.text12Grey,
      ),
      value: value,
      onChanged: onChanged,
    );
  }

  /// A row whose control is a text field.
  ///
  /// The name is an ordinary [Text] in the same column as every other row's
  /// title, and the field carries only a hint. It is not the field's own label,
  /// which is what it was: `InputDecorator` paints a resting label through a
  /// transform of its own, so it landed about six logical pixels right of where
  /// its box was placed — visible on screen, invisible to any assertion about
  /// layout. Made structural instead, the title cannot drift from the rows
  /// above it whatever the decorator does.
  Widget _textField({
    required TextEditingController controller,
    required String label,
    required String hint,
    required ValueChanged<String> onChanged,
    IconData? icon,
  }) {
    return Padding(
      padding: const EdgeInsets.only(left: _rowLeft, right: 13, bottom: 7),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 9),
            child: SizedBox(
              width: _iconSize,
              child: icon == null ? null : Icon(icon, size: _iconSize),
            ),
          ),
          const SizedBox(width: _iconGap),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                UIs.height7,
                Text(label, style: UIs.text15),
                Text(hint, style: UIs.text12Grey),
                Input(
                  controller: controller,
                  suggestion: false,
                  onChanged: onChanged,
                  // Without this the field wraps itself in a `CardX` — a card
                  // inside the card this column already is, with padding of its
                  // own.
                  noWrap: true,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLog(String log, {bool initiallyExpanded = false}) {
    return ExpansionTile(
      tilePadding: EdgeInsets.zero,
      initiallyExpanded: initiallyExpanded,
      title: Text(l10n.benchmarkRawLog, style: UIs.text13Grey),
      children: [
        Container(
          width: double.infinity,
          constraints: const BoxConstraints(maxHeight: 300),
          padding: const EdgeInsets.all(11),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(7),
          ),
          child: SingleChildScrollView(
            reverse: true,
            child: SelectableText(
              log,
              style: const TextStyle(fontFamily: 'monospace', fontSize: 11),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildHistoryTile(BenchmarkRun run) {
    final (icon, color) = switch (run.status) {
      BenchmarkStatus.completed => (Icons.check_circle, Colors.green),
      BenchmarkStatus.failed => (Icons.error_outline, Colors.red),
      BenchmarkStatus.cancelled => (Icons.cancel_outlined, Colors.orange),
      BenchmarkStatus.running => (Icons.timelapse, Colors.blue),
    };
    final result = run.result;
    return CardX(
      child: ListTile(
        leading: Icon(icon, color: color),
        title: Text(run.startedAt.ymdhms(), style: UIs.text15),
        subtitle: Text(
          [
            if (result?.cpu.model.isNotEmpty ?? false) result!.cpu.model,
            if (run.status == BenchmarkStatus.failed && run.error.isNotEmpty)
              run.error,
            _fmtDuration(run.elapsed),
          ].join(' · '),
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: UIs.text12Grey,
        ),
        trailing: IconButton(
          icon: const Icon(Icons.delete_outline),
          onPressed: () => _onDelete(run),
        ),
        onTap: () => BenchmarkResultPage.route.go(context, run),
      ),
    );
  }

  static String _fmtDuration(Duration d) {
    final m = d.inMinutes;
    final s = d.inSeconds % 60;
    return '${m}m ${s.toString().padLeft(2, '0')}s';
  }
}

// --- Actions ---

extension _Actions on _BenchmarkPageState {
  Future<void> _onStart() async {
    // Read from the controllers rather than from `_options`: `onChanged` fires
    // per keystroke, and a field left focused has still been typed into.
    final options = _options.copyWith(
      workDir: _workDirCtrl.text.trim(),
      customIperfServers: _iperfCtrl.text.trim(),
    );
    setState(() => _options = options);
    await ref.read(benchmarkProvider(_spi).notifier).start(options);
  }

  Future<void> _onCancel() async {
    final ok = await context.showRoundDialog<bool>(
      title: libL10n.attention,
      child: Text(l10n.benchmarkCancelConfirm),
      actions: Btnx.cancelRedOk,
    );
    if (ok != true) return;
    await ref.read(benchmarkProvider(_spi).notifier).cancel();
  }

  Future<void> _onDelete(BenchmarkRun run) async {
    final ok = await context.showRoundDialog<bool>(
      title: libL10n.attention,
      child: Text(l10n.benchmarkDeleteConfirm),
      actions: Btnx.cancelRedOk,
    );
    if (ok != true) return;
    ref.read(benchmarkProvider(_spi).notifier).remove(run.id);
  }

}
