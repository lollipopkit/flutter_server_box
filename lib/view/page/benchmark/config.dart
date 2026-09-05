// ignore_for_file: invalid_use_of_protected_member

import 'package:fl_lib/fl_lib.dart';
import 'package:flutter/material.dart';
import 'package:server_box/core/extension/context/locale.dart';
import 'package:server_box/data/model/server/benchmark/yabs_options.dart';
import 'package:server_box/data/model/server/benchmark/yabs_script.dart';
import 'package:server_box/view/page/benchmark/estimate.dart';

/// What a run will do, chosen before it starts.
///
/// Every phase yabs can run is a switch here, because each costs something only
/// the person paying for the server can weigh: gigabytes written to a disk,
/// tens of gigabytes of egress, or a public page on someone else's website
/// describing their machine. The run is configured in full, in the open. This
/// app supplies defaults and nothing more.
class BenchmarkConfig extends StatefulWidget {
  const BenchmarkConfig({
    super.key,
    required this.onStart,
    this.initial,
    this.busy = false,
  });

  /// The last run's options, which are the best guess at the next run's:
  /// somebody who turned Geekbench on once meant it.
  final YabsOptions? initial;

  final bool busy;
  final ValueChanged<YabsOptions> onStart;

  @override
  State<BenchmarkConfig> createState() => _BenchmarkConfigState();
}

class _BenchmarkConfigState extends State<BenchmarkConfig> {
  late var _options = widget.initial ?? const YabsOptions();
  late final _workDirCtrl = TextEditingController(text: _options.workDir);
  late final _iperfCtrl = TextEditingController(
    text: _options.customIperfServers,
  );

  /// One left edge for the icons, one for everything written.
  ///
  /// Pinned here rather than left to `ListTile`'s defaults because this column
  /// mixes three kinds of row — a switch, a dropdown and a text field — and only
  /// the first two are ListTiles. `minLeadingWidth` and `horizontalTitleGap`
  /// both fall back to theme values, so a layout that happened to agree with
  /// them would come apart under a different theme.
  static const _rowLeft = 17.0;
  static const _iconSize = 24.0;
  static const _iconGap = 16.0;

  /// The icon column, left empty.
  ///
  /// A sub-option reserves it rather than indenting by a number of its own:
  /// that is what puts its text on the same edge as the titles above it,
  /// instead of on a third edge between those titles and their icons.
  static const _noIcon = SizedBox(width: _iconSize);

  @override
  void dispose() {
    _workDirCtrl.dispose();
    _iperfCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final estimate = BenchmarkEstimate(_options);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        CardX(
          child: Padding(
            padding: const EdgeInsets.all(13),
            child: Text(l10n.benchmarkIntro, style: UIs.text13Grey),
          ),
        ),
        UIs.height13,
        CardX(child: Column(children: _buildOptions(estimate))),
        UIs.height13,
        _buildSummary(estimate),
        UIs.height13,
        FilledButton.icon(
          onPressed: widget.busy ? null : _onStart,
          icon: widget.busy
              ? const SizedBox(
                  width: 15,
                  height: 15,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.play_arrow),
          label: Text(libL10n.start),
        ),
        UIs.height13,
        Center(
          child: Text(
            l10n.benchmarkUpstream(YabsScript.upstreamVersion),
            style: UIs.text12Grey,
          ),
        ),
      ],
    );
  }
}

// --- Widgets ---

extension _Widgets on _BenchmarkConfigState {
  List<Widget> _buildOptions(BenchmarkEstimate estimate) {
    return [
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
          onChanged: (v) =>
              setState(() => _options = _options.copyWith(reducedNetwork: v)),
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
        // disclosure about their machine, so it is styled as a warning and
        // starts off.
        subtitle: l10n.benchmarkCpuTip,
        value: _options.cpu,
        icon: Icons.memory,
        warn: true,
        onChanged: (v) => setState(() => _options = _options.copyWith(cpu: v)),
      ),
      if (_options.cpu)
        ListTile(
          contentPadding: const EdgeInsets.only(
            left: _BenchmarkConfigState._rowLeft,
            right: 13,
          ),
          minLeadingWidth: _BenchmarkConfigState._iconSize,
          horizontalTitleGap: _BenchmarkConfigState._iconGap,
          leading: _BenchmarkConfigState._noIcon,
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
          _chip(
            Icons.schedule,
            l10n.benchmarkEstimatedTime('${estimate.minutes}'),
          ),
          if (estimate.trafficBytes > 0)
            _chip(
              Icons.swap_vert,
              l10n.benchmarkEstimatedTraffic(estimate.trafficBytes.bytes2Str),
            ),
          if (estimate.requiredFreeBytes case final free?)
            _chip(Icons.sd_storage_outlined, '${libL10n.disk} ${free.bytes2Str}'),
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

  Widget _switch({
    required String title,
    required String subtitle,
    required bool value,
    required ValueChanged<bool> onChanged,
    IconData? icon,
    bool warn = false,
  }) {
    return SwitchListTile(
      contentPadding: const EdgeInsets.only(
        left: _BenchmarkConfigState._rowLeft,
        right: 13,
      ),
      minLeadingWidth: _BenchmarkConfigState._iconSize,
      horizontalTitleGap: _BenchmarkConfigState._iconGap,
      secondary: icon == null
          ? _BenchmarkConfigState._noIcon
          : Icon(icon, size: _BenchmarkConfigState._iconSize),
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
  /// layout.
  Widget _textField({
    required TextEditingController controller,
    required String label,
    required String hint,
    required ValueChanged<String> onChanged,
    IconData? icon,
  }) {
    return Padding(
      padding: const EdgeInsets.only(
        left: _BenchmarkConfigState._rowLeft,
        right: 13,
        bottom: 7,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 9),
            child: SizedBox(
              width: _BenchmarkConfigState._iconSize,
              child: icon == null
                  ? null
                  : Icon(icon, size: _BenchmarkConfigState._iconSize),
            ),
          ),
          const SizedBox(width: _BenchmarkConfigState._iconGap),
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
}

// --- Actions ---

extension _Actions on _BenchmarkConfigState {
  void _onStart() {
    // Read from the controllers rather than from `_options`: `onChanged` fires
    // per keystroke, and a field left focused has still been typed into.
    final options = _options.copyWith(
      workDir: _workDirCtrl.text.trim(),
      customIperfServers: _iperfCtrl.text.trim(),
    );
    setState(() => _options = options);
    widget.onStart(options);
  }
}
