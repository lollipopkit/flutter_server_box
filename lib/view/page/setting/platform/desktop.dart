import 'package:fl_lib/fl_lib.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:icons_plus/icons_plus.dart';
import 'package:server_box/core/extension/context/inset.dart';
import 'package:server_box/core/extension/context/locale.dart';
import 'package:server_box/core/service/tray.dart';
import 'package:server_box/data/model/app/tray.dart';
import 'package:server_box/data/res/store.dart';

/// What only a desktop has, which for now is the status icon.
///
/// Its own page and not a group under **More**, for the reason the iOS page is
/// one: these settings are about the platform rather than about the app, and a
/// list of them under a heading called "more" is where a setting goes to not be
/// found. Titled by which desktop this is — a Windows user reading "macOS"
/// would reasonably wonder whose settings they were looking at.
class DesktopSettingsPage extends ConsumerStatefulWidget {
  /// Whether it is being shown inside the settings pane rather than pushed.
  ///
  /// The pane already names what it is showing, in the one bar the page has;
  /// a second one under it would say it twice.
  final bool embedded;

  const DesktopSettingsPage({super.key, this.embedded = false});

  @override
  ConsumerState<DesktopSettingsPage> createState() =>
      _DesktopSettingsPageState();

  static const route = AppRouteNoArg(
    page: DesktopSettingsPage.new,
    path: '/settings/desktop',
  );

  /// The name of the platform this is running on, which is the page's title.
  static String get platformName {
    if (isMacOS) return 'macOS';
    if (isWindows) return 'Windows';
    return 'Linux';
  }

  static IconData get platformIcon {
    if (isMacOS) return MingCute.apple_fill;
    if (isWindows) return MingCute.windows_fill;
    return MingCute.linux_fill;
  }
}

class _DesktopSettingsPageState extends ConsumerState<DesktopSettingsPage> {
  final _setting = Stores.setting;

  @override
  Widget build(BuildContext context) {
    final body = ListView(
      padding: context.padBottom(const EdgeInsets.symmetric(horizontal: 17)),
      children: [
        _buildKeepRunning(),
        _buildReadings(),
        _buildChart(),
        _buildCompact(),
      ].map((e) => CardX(child: e)).toList(),
    );
    if (widget.embedded) return body;
    return Scaffold(
      appBar: CustomAppBar(title: Text(DesktopSettingsPage.platformName)),
      body: body,
    );
  }

  /// Whether closing the window leaves the app in the tray.
  ///
  /// The switch exists because the answer changes what the close button means,
  /// and a window that refuses to close is the kind of surprise a user should
  /// be able to undo. Off is what every desktop build did before the status
  /// icon.
  Widget _buildKeepRunning() {
    return ListTile(
      title: Text(l10n.trayKeepRunning),
      subtitle: Text(l10n.trayKeepRunningTip, style: UIs.text13Grey),
      trailing: StoreSwitch(
        prop: _setting.trayKeepRunning,
        // The window's own flag is what enforces it, and it is set once at
        // launch — so it has to be told, or the switch would only take effect
        // on the next start.
        callback: (_) => ref.read(trayServiceProvider).applySetting(),
      ),
    );
  }

  /// Which readings a row carries.
  ///
  /// Checkboxes and not a reorderable list: a row is one line beside a name,
  /// and which of the six are on it matters more than their order — which
  /// stays the order they are listed in here.
  Widget _buildReadings() {
    final chosen = _setting.trayMetrics.fetch();
    final names = [
      for (final m in TrayMetric.values)
        if (chosen.contains(m.name)) m.label,
    ];
    return ListTile(
      title: Text(l10n.trayReadings),
      subtitle: Text(
        names.isEmpty ? libL10n.empty : names.join('  '),
        style: UIs.text13Grey,
      ),
      trailing: const Icon(Icons.keyboard_arrow_right),
      onTap: _pickReadings,
    );
  }

  Future<void> _pickReadings() async {
    final picked = {..._setting.trayMetrics.fetch()};
    final ok = await context.showRoundDialog<bool>(
      title: l10n.trayReadings,
      child: StatefulBuilder(
        builder: (_, setState) => Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (final metric in TrayMetric.values)
              CheckboxListTile(
                dense: true,
                title: Text(metric.label),
                value: picked.contains(metric.name),
                onChanged: (on) => setState(() {
                  if (on == true) {
                    picked.add(metric.name);
                  } else {
                    picked.remove(metric.name);
                  }
                }),
              ),
          ],
        ),
      ),
      actions: Btnx.cancelOk,
    );
    if (ok != true) return;
    // Written in the enum's order, which is the order they are drawn.
    await _setting.trayMetrics.set([
      for (final m in TrayMetric.values)
        if (picked.contains(m.name)) m.name,
    ]);
    if (!mounted) return;
    setState(() {});
    await ref.read(trayServiceProvider).applySetting();
  }

  /// Which series the row's chart draws, or none.
  ///
  /// Only the metrics a chart says something about — a disk that is 41% full
  /// for a week is a flat line spending the width of the row on nothing.
  Widget _buildChart() {
    final current = TrayMetric.byName(_setting.trayChart.fetch());
    return ListTile(
      title: Text(l10n.trayChart),
      subtitle: Text(
        current?.label ?? l10n.trayChartNone,
        style: UIs.text13Grey,
      ),
      trailing: const Icon(Icons.keyboard_arrow_right),
      onTap: () => _pickChart(current),
    );
  }

  Future<void> _pickChart(TrayMetric? current) async {
    final options = <String?>[
      null,
      for (final m in TrayMetric.values)
        if (m.chartable) m.name,
    ];
    final picked = await context.showRoundDialog<String>(
      title: l10n.trayChart,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (final name in options)
            ListTile(
              dense: true,
              title: Text(
                name == null ? l10n.trayChartNone : TrayMetric.byName(name)!.label,
              ),
              trailing: (current?.name ?? '') == (name ?? '')
                  ? const Icon(Icons.check, size: 18)
                  : null,
              onTap: () => context.popDialog(name ?? ''),
            ),
        ],
      ),
      actions: [Btn.cancel()],
    );
    if (picked == null) return;
    await _setting.trayChart.set(picked);
    if (!mounted) return;
    setState(() {});
    await ref.read(trayServiceProvider).applySetting();
  }

  Widget _buildCompact() {
    return ListTile(
      title: Text(l10n.trayCompact),
      subtitle: Text(l10n.trayCompactTip, style: UIs.text13Grey),
      trailing: StoreSwitch(
        prop: _setting.trayCompact,
        callback: (_) => ref.read(trayServiceProvider).applySetting(),
      ),
    );
  }
}
