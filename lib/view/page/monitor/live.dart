import 'dart:async';

import 'package:fl_lib/fl_lib.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';
import 'package:server_box/core/extension/context/locale.dart';
import 'package:server_box/data/model/app/error.dart';
import 'package:server_box/data/model/server/monitor_overview.dart';
import 'package:server_box/data/model/server/server_private_info.dart';
import 'package:server_box/data/provider/server/monitor_overview.dart';
import 'package:server_box/view/page/monitor/common.dart';
import 'package:server_box/view/page/monitor/tab.dart';

/// What is signed in to one agent and open on it: terminal sessions,
/// connections and ports relayed through it, the watches' and widgets'
/// tokens, and the devices that signed in with the password. Each can be
/// ended, revoked or forgotten here.
class MonitorLiveView extends ConsumerStatefulWidget {
  const MonitorLiveView({super.key, required this.spi, required this.bar});

  final Spi spi;
  final MonitorBar bar;

  @override
  ConsumerState<MonitorLiveView> createState() => _MonitorLiveViewState();
}

class _MonitorLiveViewState extends ConsumerState<MonitorLiveView> {
  MonitorLive? _live;
  Object? _error;
  var _loading = false;

  @override
  void initState() {
    super.initState();
    unawaited(_load());
  }

  MonitorOverviewNotifier get _agent => ref.read(monitorOverviewProvider(widget.spi.id).notifier);

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final live = await _agent.live();
      if (!mounted) return;
      setState(() {
        _live = live;
        _error = null;
      });
    } catch (e) {
      if (mounted) setState(() => _error = e);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    // Watched so the agent's client lives while this does.
    ref.watch(monitorOverviewProvider(widget.spi.id));
    return Scaffold(
      appBar: widget.bar([
        BarAction(icon: Icons.refresh, label: libL10n.refresh, loading: _loading, onTap: () => unawaited(_load())),
      ]),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    final live = _live;
    if (live == null) {
      if (_error case final error?) return EmptyPane(icon: Icons.error_outline, label: '${libL10n.fail}: $error');
      return UIs.centerLoading;
    }
    String ago(DateTime? at) => at?.toAgoStr() ?? '';
    String line(Iterable<String?> parts) => parts.whereType<String>().where((p) => p.isNotEmpty).join(' · ');
    return MonitorList(
      onRefresh: _load,
      children: [
        MonitorGroup(
          title: l10n.monitorLiveSessions,
          right: '${live.sessions.length}',
          empty: l10n.monitorLiveNoSessions,
          children: [
            for (final s in live.sessions)
              MonitorRow(
                key: ValueKey('session/${s.id}'),
                leading: Icon(Icons.terminal, size: 20, color: s.attached ? Colors.green : UIs.textGrey.color),
                title: s.what,
                subtitle: line([
                  s.attached ? l10n.monitorLiveAttached : l10n.monitorLiveDetached,
                  s.user,
                  s.remoteIp,
                  ago(s.openedAt),
                ]),
                trailing: MonitorRowAction(
                  icon: Icons.close,
                  tooltip: l10n.monitorLiveEnd,
                  onPressed: () => unawaited(_act(l10n.monitorLiveEndSessionConfirm(s.what), () => _agent.endSession(s.id))),
                ),
              ),
          ],
        ),
        MonitorGroup(
          title: l10n.monitorLiveConnections,
          right: '${live.connections.length}',
          empty: l10n.monitorLiveNoConnections,
          children: [
            for (final c in live.connections)
              MonitorRow(
                key: ValueKey('connection/${c.id}'),
                leading: Icon(_connectionIcon(c.kind), size: 20),
                title: c.target,
                subtitle: line([_connectionLabel(c.kind), c.remoteIp, ago(c.openedAt)]),
                trailing: MonitorRowAction(
                  icon: Icons.close,
                  tooltip: l10n.monitorLiveEnd,
                  onPressed: () =>
                      unawaited(_act(l10n.monitorLiveEndConnectionConfirm(c.target), () => _agent.endConnection(c.id))),
                ),
              ),
          ],
        ),
        MonitorGroup(
          title: l10n.monitorLiveWatchTokens,
          right: '${live.watchTokens.length}',
          empty: l10n.monitorLiveNoTokens,
          children: [
            for (final t in live.watchTokens)
              MonitorRow(
                key: ValueKey('watch/${t.clientId}'),
                leading: Icon(t.clientId.startsWith('widget') ? Icons.widgets_outlined : Icons.watch_outlined, size: 20),
                title: t.clientId,
                subtitle: line([if (t.expiresAt case final at?) l10n.monitorLiveExpires(at.ymd())]),
                trailing: MonitorRowAction(
                  icon: Icons.link_off,
                  tooltip: l10n.monitorLiveRevoke,
                  onPressed: () =>
                      unawaited(_act(l10n.monitorLiveRevokeConfirm(t.clientId), () => _agent.revokeWatchToken(t.clientId))),
                ),
              ),
          ],
        ),
        MonitorGroup(
          title: l10n.monitorLiveDevices,
          right: '${live.devices.length}',
          empty: l10n.monitorLiveNoDevices,
          footer: l10n.monitorLiveDevicesTip,
          children: [
            for (final d in live.devices)
              MonitorRow(
                key: ValueKey('device/${d.id}'),
                leading: Icon(_deviceIcon(d.label), size: 20),
                title: d.label.isEmpty ? libL10n.unknown : d.label,
                subtitle: line([d.lastIp, ago(d.lastUsed)]),
                trailing: MonitorRowAction(
                  icon: Icons.delete_outline,
                  tooltip: l10n.monitorLiveForget,
                  onPressed: () => unawaited(
                    _act(
                      l10n.monitorLiveForgetConfirm(d.label.isEmpty ? libL10n.unknown : d.label),
                      () => _agent.forgetDevice(d.id),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ],
    );
  }

  Future<void> _act(String confirm, Future<void> Function() run) async {
    final ok = await context.showRoundDialog<bool>(
      title: libL10n.attention,
      child: Text(confirm),
      actions: Btnx.cancelRedOk,
    );
    if (ok != true || !mounted) return;
    try {
      await run();
    } on MonitorHttpErr catch (e) {
      // Gone already is what was asked for: the list says so once re-read.
      if (e.type != MonitorHttpErrType.notFound) Toast.show(libL10n.fail, body: '$e');
    } catch (e) {
      Toast.show(libL10n.fail, body: '$e');
    }
    await _load();
  }

  /// A device by what it called itself: a phone, a computer, a browser.
  static IconData _deviceIcon(String label) {
    final l = label.toLowerCase();
    if (l.contains('ios') || l.contains('android') || l.contains('iphone')) return Icons.smartphone;
    if (l.contains('mozilla') || l.contains('chrome') || l.contains('safari')) return Icons.language;
    return Icons.computer;
  }

  static IconData _connectionIcon(String kind) => switch (kind) {
    'listen' => Icons.input,
    'virt_console' => Icons.view_in_ar_outlined,
    'rdp' => Icons.desktop_windows_outlined,
    _ => Icons.swap_horiz,
  };

  static String _connectionLabel(String kind) => switch (kind) {
    'stream' => l10n.monitorLiveStream,
    'accepted' => l10n.monitorLiveAccepted,
    'listen' => l10n.monitorAuditListen,
    'virt_console' => l10n.monitorLiveConsole,
    'rdp' => l10n.remoteDesktop,
    _ => kind,
  };
}
