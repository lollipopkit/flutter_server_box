import 'dart:async';

import 'package:fl_lib/fl_lib.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:server_box/core/extension/context/locale.dart';
import 'package:server_box/core/route.dart';
import 'package:server_box/core/utils/refresh_interval.dart';
import 'package:server_box/data/model/app/scripts/shell_func.dart';
import 'package:server_box/data/model/server/proc.dart';
import 'package:server_box/data/model/server/server.dart';
import 'package:server_box/data/model/server/system.dart';
import 'package:server_box/data/provider/server/single.dart';

const _compactBreakpoint = 700.0;
const _rssBreakpoint = 840.0;
const _ioBreakpoint = 1100.0;
const _horizontalPadding = 12.0;
const _cellGap = 12.0;
const _pidWidth = 68.0;
const _userWidth = 96.0;
const _metricWidth = 68.0;
const _rssWidth = 84.0;
const _ioWidth = 88.0;
const _actionWidth = 44.0;

class ProcessPage extends ConsumerStatefulWidget {
  final SpiRequiredArgs args;

  const ProcessPage({super.key, required this.args});

  @override
  ConsumerState<ProcessPage> createState() => _ProcessPageState();

  static const route = AppRouteArg(page: ProcessPage.new, path: '/process');
}

class _ProcessPageState extends ConsumerState<ProcessPage>
    with WidgetsBindingObserver {
  Timer? _timer;

  PsResult _result = const PsResult(procs: []);
  bool _hasLoaded = false;
  bool _isRefreshing = false;
  SystemType? _systemType;

  // Issue #64: CPU sorting keeps high-churn lists visibly fresh and surfaces
  // the processes that normally need attention first.
  ProcSortMode _procSortMode = ProcSortMode.cpu;
  bool _sortAscending = ProcSortMode.cpu.defaultAscending;
  final _sortModes = <ProcSortMode>[...ProcSortMode.values];

  late final _provider = serverProvider(widget.args.spi.id);

  @override
  void dispose() {
    _timer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _refresh();
    _startRefreshTimer();
  }

  void _startRefreshTimer() {
    _timer?.cancel();
    final duration = serverStatusRefreshInterval();
    if (duration != null) {
      _timer = Timer.periodic(duration, (_) => _refresh());
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    switch (state) {
      case AppLifecycleState.resumed:
        _startRefreshTimer();
        _refresh();
        break;
      case AppLifecycleState.paused:
        _timer?.cancel();
        _timer = null;
        break;
      default:
        break;
    }
  }

  Future<void> _refresh({bool userTriggered = false}) async {
    if (!mounted || _isRefreshing) return;
    _isRefreshing = true;
    if (_hasLoaded) setState(() {});
    try {
      final serverState = ref.read(_provider);
      final systemType = serverState.status.system;
      _systemType = systemType;
      final client = serverState.client;
      if (!_canRunProcessCmd(serverState)) {
        if (userTriggered && mounted) {
          context.showSnackBar(libL10n.disconnected);
        }
        return;
      }
      final result = await client
          ?.run(
            ShellFunc.process.exec(
              widget.args.spi.id,
              systemType: systemType,
              customDir: null,
            ),
          )
          .string;
      if (!mounted) return;
      if (result == null || result.trim().isEmpty) {
        _result = const PsResult(procs: []);
        _hasLoaded = true;
        if (userTriggered) context.showSnackBar(libL10n.empty);
        return;
      }

      var parsed = PsResult.parse(result, previous: _result);
      _updateAvailableSortModes(parsed);
      parsed = parsed.sortedBy(_procSortMode, ascending: _sortAscending);
      _result = parsed;
      _hasLoaded = true;
    } catch (e, s) {
      Loggers.app.warning('Process page refresh failed', e, s);
      if (mounted && (userTriggered || !_hasLoaded)) {
        context.showSnackBar(libL10n.error);
      }
      _hasLoaded = true;
    } finally {
      _isRefreshing = false;
      if (mounted) setState(() {});
    }
  }

  void _updateAvailableSortModes(PsResult result) {
    final procs = result.procs;
    final modes = <ProcSortMode>[
      if (procs.any((proc) => proc.cpu != null)) ProcSortMode.cpu,
      if (procs.any((proc) => proc.mem != null)) ProcSortMode.mem,
      if (procs.any((proc) => proc.rssKb != null)) ProcSortMode.rss,
      if (procs.any((proc) => proc.readSpeed != null)) ProcSortMode.read,
      if (procs.any((proc) => proc.writeSpeed != null)) ProcSortMode.write,
      ProcSortMode.pid,
      if (procs.any((proc) => proc.user?.isNotEmpty == true)) ProcSortMode.user,
      ProcSortMode.name,
    ];
    _sortModes
      ..clear()
      ..addAll(modes);
    if (!_sortModes.contains(_procSortMode)) {
      _procSortMode = _sortModes.first;
      _sortAscending = _procSortMode.defaultAscending;
    }
  }

  void _selectSort(ProcSortMode mode) {
    if (!_sortModes.contains(mode)) return;
    setState(() {
      if (_procSortMode == mode) {
        _sortAscending = !_sortAscending;
      } else {
        _procSortMode = mode;
        _sortAscending = mode.defaultAscending;
      }
      _result = _result.sortedBy(mode, ascending: _sortAscending);
    });
  }

  @override
  Widget build(BuildContext context) {
    final actions = <Widget>[];
    if (_result.error != null) {
      actions.add(
        IconButton(
          icon: const Icon(Icons.error_outline),
          tooltip: libL10n.error,
          onPressed: () => context.showRoundDialog(
            title: libL10n.error,
            child: SingleChildScrollView(child: Text(_result.error!)),
            actions: [
              TextButton(
                onPressed: () => Pfs.copy(_result.error!),
                child: Text(libL10n.copy),
              ),
            ],
          ),
        ),
      );
    }
    return Scaffold(
      appBar: CustomAppBar(
        centerTitle: true,
        title: TwoLineText(up: libL10n.process, down: widget.args.spi.name),
        actions: actions,
      ),
      body: LayoutBuilder(
        builder: (context, constraints) {
          final layout = _ProcessLayout.fromWidth(
            constraints.maxWidth,
            _result.procs,
          );
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _buildToolbar(),
              Divider(
                height: 1,
                color: Theme.of(context).colorScheme.outlineVariant,
              ),
              Expanded(child: _buildProcessContent(layout)),
            ],
          );
        },
      ),
    );
  }

  Widget _buildToolbar() {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 6, 8, 6),
      child: Row(
        children: [
          Text(
            '${_result.procs.length} ${libL10n.process}',
            style: theme.textTheme.labelLarge?.copyWith(
              color: scheme.onSurfaceVariant,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
          const Spacer(),
          PopupMenuButton<ProcSortMode>(
            tooltip: context.l10n.sort,
            icon: Icon(
              Icons.sort,
              color: _sortModes.isEmpty ? null : scheme.primary,
            ),
            onSelected: _selectSort,
            itemBuilder: (_) => [
              for (final mode in _sortModes)
                PopupMenuItem(
                  value: mode,
                  child: Row(
                    children: [
                      Expanded(child: Text(_sortLabel(mode))),
                      if (_procSortMode == mode)
                        Icon(
                          _sortAscending
                              ? Icons.arrow_upward
                              : Icons.arrow_downward,
                          size: 16,
                          color: scheme.primary,
                        ),
                    ],
                  ),
                ),
            ],
          ),
          IconButton(
            tooltip: libL10n.refresh,
            onPressed: _isRefreshing
                ? null
                : () => _refresh(userTriggered: true),
            icon: _isRefreshing
                ? const SizedBox.square(
                    dimension: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.refresh),
          ),
        ],
      ),
    );
  }

  Widget _buildProcessContent(_ProcessLayout layout) {
    if (!_hasLoaded && _result.procs.isEmpty) return UIs.centerLoading;
    if (_result.procs.isEmpty) {
      return CenterGreyTitle(libL10n.empty).paddingSymmetric(horizontal: 13);
    }
    final scheme = Theme.of(context).colorScheme;
    return Column(
      children: [
        _buildHeader(layout),
        Divider(height: 1, color: scheme.outlineVariant),
        Expanded(
          child: RefreshIndicator(
            onRefresh: () => _refresh(userTriggered: true),
            child: ListView.separated(
              physics: const AlwaysScrollableScrollPhysics(),
              itemCount: _result.procs.length,
              separatorBuilder: (_, _) => Divider(
                height: 1,
                color: scheme.outlineVariant.withValues(alpha: 0.55),
              ),
              itemBuilder: (_, index) =>
                  _buildProcessRow(_result.procs[index], layout),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildHeader(_ProcessLayout layout) {
    final scheme = Theme.of(context).colorScheme;
    return ColoredBox(
      color: scheme.surfaceContainerHighest.withValues(alpha: 0.28),
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: _horizontalPadding,
          vertical: 6,
        ),
        child: Row(
          children: [
            SizedBox(
              width: _pidWidth,
              child: _SortHeader(
                label: 'PID',
                active: _procSortMode == ProcSortMode.pid,
                ascending: _sortAscending,
                onTap: () => _selectSort(ProcSortMode.pid),
              ),
            ),
            const SizedBox(width: _cellGap),
            if (layout.showUser) ...[
              SizedBox(
                width: _userWidth,
                child: _SortHeader(
                  label: libL10n.user,
                  active: _procSortMode == ProcSortMode.user,
                  ascending: _sortAscending,
                  onTap: () => _selectSort(ProcSortMode.user),
                ),
              ),
              const SizedBox(width: _cellGap),
            ],
            if (layout.showCpu) ...[
              SizedBox(
                width: _metricWidth,
                child: _SortHeader(
                  label: 'CPU',
                  active: _procSortMode == ProcSortMode.cpu,
                  ascending: _sortAscending,
                  alignEnd: true,
                  onTap: () => _selectSort(ProcSortMode.cpu),
                ),
              ),
              const SizedBox(width: _cellGap),
            ],
            if (layout.showMem) ...[
              SizedBox(
                width: _metricWidth,
                child: _SortHeader(
                  label: 'MEM',
                  active: _procSortMode == ProcSortMode.mem,
                  ascending: _sortAscending,
                  alignEnd: true,
                  onTap: () => _selectSort(ProcSortMode.mem),
                ),
              ),
              const SizedBox(width: _cellGap),
            ],
            if (layout.showRss) ...[
              SizedBox(
                width: _rssWidth,
                child: _SortHeader(
                  label: 'RSS',
                  active: _procSortMode == ProcSortMode.rss,
                  ascending: _sortAscending,
                  alignEnd: true,
                  onTap: () => _selectSort(ProcSortMode.rss),
                ),
              ),
              const SizedBox(width: _cellGap),
            ],
            if (layout.showRead) ...[
              SizedBox(
                width: _ioWidth,
                child: _SortHeader(
                  label: 'R/s',
                  active: _procSortMode == ProcSortMode.read,
                  ascending: _sortAscending,
                  alignEnd: true,
                  onTap: () => _selectSort(ProcSortMode.read),
                ),
              ),
              const SizedBox(width: _cellGap),
            ],
            if (layout.showWrite) ...[
              SizedBox(
                width: _ioWidth,
                child: _SortHeader(
                  label: 'W/s',
                  active: _procSortMode == ProcSortMode.write,
                  ascending: _sortAscending,
                  alignEnd: true,
                  onTap: () => _selectSort(ProcSortMode.write),
                ),
              ),
              const SizedBox(width: _cellGap),
            ],
            Expanded(
              child: _SortHeader(
                label: libL10n.name,
                active: _procSortMode == ProcSortMode.name,
                ascending: _sortAscending,
                onTap: () => _selectSort(ProcSortMode.name),
              ),
            ),
            const SizedBox(width: _actionWidth),
          ],
        ),
      ),
    );
  }

  Widget _buildProcessRow(Proc proc, _ProcessLayout layout) {
    final theme = Theme.of(context);
    final monoStyle = theme.textTheme.bodySmall?.copyWith(
      fontFeatures: const [FontFeature.tabularFigures()],
    );
    return InkWell(
      onTap: () => _showProcessDetails(proc),
      child: Padding(
        padding: EdgeInsets.symmetric(
          horizontal: _horizontalPadding,
          vertical: layout.compact ? 9 : 10,
        ),
        child: Row(
          children: [
            SizedBox(
              width: _pidWidth,
              child: Text('${proc.pid}', style: monoStyle),
            ),
            const SizedBox(width: _cellGap),
            if (layout.showUser) ...[
              SizedBox(
                width: _userWidth,
                child: Text(
                  proc.user ?? '—',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodySmall,
                ),
              ),
              const SizedBox(width: _cellGap),
            ],
            if (layout.showCpu) ...[
              SizedBox(
                width: _metricWidth,
                child: Text(
                  _formatCpu(proc.cpu),
                  textAlign: TextAlign.end,
                  style: monoStyle,
                ),
              ),
              const SizedBox(width: _cellGap),
            ],
            if (layout.showMem) ...[
              SizedBox(
                width: _metricWidth,
                child: Text(
                  _formatPercent(proc.mem),
                  textAlign: TextAlign.end,
                  style: monoStyle,
                ),
              ),
              const SizedBox(width: _cellGap),
            ],
            if (layout.showRss) ...[
              SizedBox(
                width: _rssWidth,
                child: Text(
                  _formatRss(proc),
                  textAlign: TextAlign.end,
                  style: monoStyle,
                ),
              ),
              const SizedBox(width: _cellGap),
            ],
            if (layout.showRead) ...[
              SizedBox(
                width: _ioWidth,
                child: Text(
                  _formatNullableSpeed(proc.readSpeed),
                  textAlign: TextAlign.end,
                  style: monoStyle,
                ),
              ),
              const SizedBox(width: _cellGap),
            ],
            if (layout.showWrite) ...[
              SizedBox(
                width: _ioWidth,
                child: Text(
                  _formatNullableSpeed(proc.writeSpeed),
                  textAlign: TextAlign.end,
                  style: monoStyle,
                ),
              ),
              const SizedBox(width: _cellGap),
            ],
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    proc.command.isEmpty ? '—' : proc.command,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodyMedium,
                  ),
                  if (layout.compact) ...[
                    const SizedBox(height: 3),
                    _buildCompactMetadata(proc),
                  ],
                ],
              ),
            ),
            SizedBox(
              width: _actionWidth,
              child: IconButton(
                tooltip: '${libL10n.stop} ${libL10n.process}',
                visualDensity: VisualDensity.compact,
                constraints: const BoxConstraints.tightFor(
                  width: 40,
                  height: 40,
                ),
                color: theme.colorScheme.error,
                icon: const Icon(Icons.stop_circle_outlined),
                onPressed: _isRefreshing ? null : () => _confirmKill(proc),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCompactMetadata(Proc proc) {
    final style = Theme.of(context).textTheme.labelSmall?.copyWith(
      color: Theme.of(context).colorScheme.onSurfaceVariant,
      fontFeatures: const [FontFeature.tabularFigures()],
    );
    final values = <String>[
      if (proc.user?.isNotEmpty == true) proc.user!,
      if (proc.cpu != null) 'CPU ${_formatCpu(proc.cpu)}',
      if (proc.mem != null) 'MEM ${_formatPercent(proc.mem)}',
      if (proc.rssKb != null) 'RSS ${_formatRss(proc)}',
      if (proc.readSpeed != null) 'R ${_formatSpeed(proc.readSpeed!)}',
      if (proc.writeSpeed != null) 'W ${_formatSpeed(proc.writeSpeed!)}',
    ];
    if (values.isEmpty) return const SizedBox.shrink();
    return Wrap(
      spacing: 12,
      runSpacing: 2,
      children: [for (final value in values) Text(value, style: style)],
    );
  }

  void _confirmKill(Proc proc) {
    context.showRoundDialog(
      title: libL10n.attention,
      child: Text(
        libL10n.askContinue('${libL10n.stop} ${libL10n.process}(${proc.pid})'),
      ),
      actions: [
        Btn.cancel(),
        Btn.ok(
          onTap: () async {
            context.pop();
            await context.showLoadingDialog(
              fn: () => _killAndRefresh(proc.pid),
            );
          },
        ),
      ],
    );
  }

  void _showProcessDetails(Proc proc) {
    context.showRoundDialog(
      title: '${libL10n.process} ${proc.pid}',
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildDetailLine('PID', proc.pid.toString()),
            if (proc.user != null) _buildDetailLine('USER', proc.user!),
            if (proc.cpu != null) _buildDetailLine('CPU', _formatCpu(proc.cpu)),
            if (proc.mem != null)
              _buildDetailLine('MEM', _formatPercent(proc.mem)),
            if (proc.vsz != null) _buildDetailLine('VSZ', proc.vsz!),
            if (proc.rss != null) _buildDetailLine('RSS', _formatRss(proc)),
            if (proc.readSpeed != null)
              _buildDetailLine('R', _formatSpeed(proc.readSpeed!)),
            if (proc.writeSpeed != null)
              _buildDetailLine('W', _formatSpeed(proc.writeSpeed!)),
            if (proc.tty != null) _buildDetailLine('TTY', proc.tty!),
            if (proc.stat != null) _buildDetailLine('STAT', proc.stat!),
            if (proc.start != null) _buildDetailLine('START', proc.start!),
            if (proc.time != null) _buildDetailLine('TIME', proc.time!),
            UIs.height13,
            SelectableText(proc.command),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Pfs.copy(proc.command),
          child: Text(libL10n.copy),
        ),
      ],
    );
  }

  Widget _buildDetailLine(String label, String value) => Text('$label: $value');

  String _sortLabel(ProcSortMode mode) => switch (mode) {
    ProcSortMode.cpu => 'CPU',
    ProcSortMode.mem => 'MEM',
    ProcSortMode.rss => 'RSS',
    ProcSortMode.read => 'R/s',
    ProcSortMode.write => 'W/s',
    ProcSortMode.pid => 'PID',
    ProcSortMode.user => libL10n.user,
    ProcSortMode.name => libL10n.name,
  };

  String _formatPercent(double? value) =>
      value == null ? '—' : '${value.toStringAsFixed(1)}%';

  String _formatCpu(double? value) {
    if (value == null) return '—';
    final formatted = value.toStringAsFixed(1);
    // PowerShell Get-Process reports cumulative CPU seconds, while Unix ps
    // reports a percentage. Keep the unit explicit instead of implying that
    // the Windows value is a percentage.
    return _systemType == SystemType.windows ? '${formatted}s' : '$formatted%';
  }

  String _formatRss(Proc proc) {
    final rssKb = proc.rssKb;
    if (rssKb == null) return proc.rss ?? '—';
    return (rssKb * 1024).bytes2Str;
  }

  String _formatNullableSpeed(double? bytes) =>
      bytes == null ? '—' : _formatSpeed(bytes);

  String _formatSpeed(double bytes) => '${bytes.bytes2Str}/s';

  bool _canRunProcessCmd(ServerState serverState) {
    final client = serverState.client;
    if (client == null || client.isClosed) return false;
    final conn = serverState.conn;
    return conn == ServerConn.connected || conn == ServerConn.finished;
  }

  String _killProcessCmd(int pid, SystemType systemType) =>
      switch (systemType) {
        SystemType.windows => 'taskkill /F /PID $pid',
        SystemType.linux || SystemType.bsd => 'kill $pid',
      };

  Future<void> _killAndRefresh(int pid) async {
    if (!mounted || _isRefreshing) return;
    _isRefreshing = true;
    setState(() {});
    try {
      final serverState = ref.read(_provider);
      final systemType = serverState.status.system;
      await serverState.client?.run(_killProcessCmd(pid, systemType));
    } catch (e, s) {
      Loggers.app.warning('Process kill failed', e, s);
      if (mounted) context.showSnackBar(libL10n.error);
      return;
    } finally {
      _isRefreshing = false;
      if (mounted) setState(() {});
    }
    await _refresh(userTriggered: true);
  }
}

class _ProcessLayout {
  const _ProcessLayout({
    required this.compact,
    required this.showUser,
    required this.showCpu,
    required this.showMem,
    required this.showRss,
    required this.showRead,
    required this.showWrite,
  });

  factory _ProcessLayout.fromWidth(double width, List<Proc> procs) {
    final compact = width < _compactBreakpoint;
    final hasUser = procs.any((proc) => proc.user?.isNotEmpty == true);
    final hasCpu = procs.any((proc) => proc.cpu != null);
    final hasMem = procs.any((proc) => proc.mem != null);
    final hasRss = procs.any((proc) => proc.rssKb != null);
    final hasRead = procs.any((proc) => proc.readSpeed != null);
    final hasWrite = procs.any((proc) => proc.writeSpeed != null);
    return _ProcessLayout(
      compact: compact,
      showUser: !compact && hasUser,
      showCpu: !compact && hasCpu,
      showMem: !compact && hasMem,
      showRss:
          !compact &&
          hasRss &&
          (width >= _rssBreakpoint || (!hasUser && !hasMem)),
      showRead: !compact && width >= _ioBreakpoint && hasRead,
      showWrite: !compact && width >= _ioBreakpoint && hasWrite,
    );
  }

  final bool compact;
  final bool showUser;
  final bool showCpu;
  final bool showMem;
  final bool showRss;
  final bool showRead;
  final bool showWrite;
}

class _SortHeader extends StatelessWidget {
  const _SortHeader({
    required this.label,
    required this.active,
    required this.ascending,
    required this.onTap,
    this.alignEnd = false,
  });

  final String label;
  final bool active;
  final bool ascending;
  final VoidCallback onTap;
  final bool alignEnd;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final color = active ? scheme.primary : scheme.onSurfaceVariant;
    return Semantics(
      button: true,
      selected: active,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(4),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Row(
            mainAxisAlignment: alignEnd
                ? MainAxisAlignment.end
                : MainAxisAlignment.start,
            children: [
              Flexible(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.labelMedium?.copyWith(color: color),
                ),
              ),
              if (active) ...[
                const SizedBox(width: 2),
                Icon(
                  ascending ? Icons.arrow_upward : Icons.arrow_downward,
                  size: 14,
                  color: color,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
