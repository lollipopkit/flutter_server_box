import 'dart:async';

import 'package:fl_lib/fl_lib.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';
import 'package:server_box/core/extension/context/locale.dart';
import 'package:server_box/data/model/server/monitor_overview.dart';
import 'package:server_box/data/model/server/server_private_info.dart';
import 'package:server_box/data/provider/server/monitor_overview.dart';
import 'package:server_box/view/page/monitor/common.dart';
import 'package:server_box/view/page/monitor/tab.dart';

/// One agent's audit log, newest first: sign-ins, terminals, commands, file
/// writes, deployments and the rest, each with where it came from. Read a
/// page at a time, narrowed by the chips over it.
class MonitorAuditView extends ConsumerStatefulWidget {
  const MonitorAuditView({super.key, required this.spi, required this.bar});

  final Spi spi;
  final MonitorBar bar;

  @override
  ConsumerState<MonitorAuditView> createState() => _MonitorAuditViewState();
}

class _MonitorAuditViewState extends ConsumerState<MonitorAuditView> {
  String? _kind;
  String? _result;
  final _entries = <MonitorAuditEntry>[];
  int? _next;
  var _loading = false;
  Object? _error;

  /// Rises with every fresh read, so a page for an older filter is dropped.
  var _generation = 0;

  @override
  void initState() {
    super.initState();
    unawaited(_reload());
  }

  MonitorOverviewNotifier get _agent => ref.read(monitorOverviewProvider(widget.spi.id).notifier);

  Future<void> _reload() async {
    _generation++;
    setState(() {
      _entries.clear();
      _next = null;
      _error = null;
    });
    await _load();
  }

  Future<void> _load() async {
    final generation = _generation;
    setState(() => _loading = true);
    try {
      final page = await _agent.audit(before: _next, kind: _kind, result: _result);
      if (!mounted || generation != _generation) return;
      setState(() {
        _entries.addAll(page.entries);
        _next = page.next;
      });
    } catch (e) {
      if (!mounted || generation != _generation) return;
      setState(() => _error = e);
    } finally {
      if (mounted && generation == _generation) setState(() => _loading = false);
    }
  }

  void _filter({String? kind, String? result}) {
    _kind = kind;
    _result = result;
    unawaited(_reload());
  }

  @override
  Widget build(BuildContext context) {
    // Watched so the agent's client lives while this does.
    ref.watch(monitorOverviewProvider(widget.spi.id));
    return Scaffold(
      appBar: widget.bar([
        BarAction(icon: Icons.refresh, label: libL10n.refresh, loading: _loading, onTap: () => unawaited(_reload())),
      ]),
      body: MonitorList(
        onRefresh: _reload,
        children: [
          UIs.height7,
          _Chips(
            label: libL10n.type,
            options: [
              (null, libL10n.all),
              for (final kind in MonitorAuditKind.all) (kind, auditKindLabel(kind)),
            ],
            selected: _kind,
            onSelected: (kind) => _filter(kind: kind, result: _result),
          ),
          UIs.height7,
          _Chips(
            label: libL10n.result,
            options: [
              (null, libL10n.all),
              for (final result in const ['ok', 'denied', 'error']) (result, auditResultLabel(result)),
            ],
            selected: _result,
            onSelected: (result) => _filter(kind: _kind, result: result),
          ),
          ..._buildEntries(),
        ],
      ),
    );
  }

  List<Widget> _buildEntries() {
    if (_entries.isEmpty) {
      if (_loading) return const [SizedBox(height: 120, child: UIs.centerLoading)];
      if (_error case final error?) {
        return [
          MonitorGroup(
            title: widget.spi.name,
            children: [
              MonitorRow(
                leading: Icon(Icons.error_outline, color: Theme.of(context).colorScheme.error),
                title: libL10n.fail,
                subtitle: '$error',
              ),
            ],
          ),
        ];
      }
      return [MonitorGroup(title: widget.spi.name, empty: l10n.monitorAuditEmpty, children: const [])];
    }
    return [
      MonitorGroup(
        title: widget.spi.name,
        children: [
          for (final (entry, times) in collapseAuditRuns(_entries))
            _AuditRow(key: ValueKey(entry.id), entry: entry, times: times),
        ],
      ),
      if (_next != null)
        Padding(
          padding: const EdgeInsets.only(top: 9),
          child: Center(
            child: _loading
                ? UIs.smallLinearLoading
                : TextButton.icon(
                    icon: const Icon(Icons.expand_more),
                    onPressed: () => unawaited(_load()),
                    label: Text(l10n.monitorLoadMore),
                  ),
          ),
        ),
    ];
  }
}

/// One row of choices, scrolling sideways where it does not fit.
class _Chips extends StatelessWidget {
  const _Chips({required this.label, required this.options, required this.selected, required this.onSelected});

  final String label;
  final List<(String?, String)> options;
  final String? selected;
  final ValueChanged<String?> onSelected;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        SizedBox(width: 56, child: Text(label, style: UIs.text12Grey)),
        Expanded(
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                for (final (value, text) in options) ...[
                  ChoiceChip(
                    label: Text(text),
                    selected: selected == value,
                    showCheckmark: false,
                    visualDensity: VisualDensity.compact,
                    onSelected: (_) => onSelected(value),
                  ),
                  const SizedBox(width: 6),
                ],
              ],
            ),
          ),
        ),
      ],
    );
  }
}

/// [entries] with each run of rows saying the same thing — a client signing
/// in again and again, a poll — as its newest row and how many there were.
List<(MonitorAuditEntry, int)> collapseAuditRuns(List<MonitorAuditEntry> entries) {
  final out = <(MonitorAuditEntry, int)>[];
  for (final entry in entries) {
    if (out.lastOrNull case (final last, final times) when _sameEvent(last, entry)) {
      out[out.length - 1] = (last, times + 1);
    } else {
      out.add((entry, 1));
    }
  }
  return out;
}

bool _sameEvent(MonitorAuditEntry a, MonitorAuditEntry b) =>
    a.kind == b.kind &&
    a.action == b.action &&
    a.result == b.result &&
    a.subject == b.subject &&
    a.detail == b.detail &&
    a.remoteIp == b.remoteIp &&
    a.systemUser == b.systemUser;

/// [kind] (`login`, `exec`, …) in words; itself for one this app does not know.
String auditKindLabel(String kind) => switch (kind) {
  'login' => libL10n.login,
  'terminal' => libL10n.terminal,
  'exec' => l10n.monitorAuditExec,
  'fs' => libL10n.file,
  'machine' => l10n.monitorAuditMachine,
  'agent' => 'Agent',
  'stack' => l10n.webApps,
  'stream' => l10n.connection,
  'listen' => l10n.monitorAuditListen,
  'ticket' => l10n.monitorAuditTicket,
  'custom_cmd' => l10n.customCmd,
  'push' => l10n.monitorAuditPush,
  'admin' => l10n.monitorAuditAdmin,
  'backup' => libL10n.backup,
  _ => kind,
};

String auditResultLabel(String result) => switch (result) {
  'ok' => libL10n.success,
  'denied' => l10n.monitorAuditDenied,
  'error' => libL10n.error,
  _ => result,
};

class _AuditRow extends StatelessWidget {
  const _AuditRow({super.key, required this.entry, this.times = 1});

  final MonitorAuditEntry entry;

  /// How many rows in a row said this; [entry] is the newest.
  final int times;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final (icon, color) = switch (entry.result) {
      'ok' => (Icons.check_circle_outline, Colors.green),
      'denied' => (Icons.block, scheme.error),
      _ => (Icons.error_outline, Colors.orange),
    };
    return MonitorRow(
      leading: Tooltip(message: auditResultLabel(entry.result), child: Icon(icon, color: color, size: 20)),
      // A sign-in's action only repeats its result.
      title: entry.kind == 'login' ? auditKindLabel(entry.kind) : '${auditKindLabel(entry.kind)} · ${entry.action}',
      subtitle: [?entry.subject, ?entry.detail, ?entry.systemUser].join(' · '),
      trailing: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (entry.at case final at?)
            Tooltip(
              message: at.ymdhms(),
              child: Text(times > 1 ? '×$times · ${at.toAgoStr()}' : at.toAgoStr(), style: UIs.text11Grey),
            ),
          if (entry.remoteIp case final ip?) Text(ip, style: UIs.text11Grey),
        ],
      ),
    );
  }
}
