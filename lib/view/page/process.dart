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
const _processCommandTimeout = Duration(seconds: 30);

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
  Completer<void>? _refreshCompleter;

  PsResult _result = const PsResult(procs: []);
  bool _hasLoaded = false;
  bool _isRefreshing = false;
  SystemType? _systemType;
  _ProcessCapabilities _capabilities = _ProcessCapabilities.empty;

  // Issue #64: CPU sorting keeps high-churn lists visibly fresh and surfaces
  // the processes that normally need attention first.
  ProcSortMode _procSortMode = ProcSortMode.cpu;
  bool _sortAscending = ProcSortMode.cpu.defaultAscending;

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
    final refreshCompleter = Completer<void>();
    _refreshCompleter = refreshCompleter;
    _isRefreshing = true;
    if (_hasLoaded) setState(() {});
    try {
      final serverState = ref.read(_provider);
      final systemType = serverState.status.system;
      _systemType = systemType;
      final client = serverState.client;
      if (!_canRunProcessCmd(serverState)) {
        _hasLoaded = true;
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
          .timeout(_processCommandTimeout)
          .string;
      if (!mounted) return;
      if (result == null || result.trim().isEmpty) {
        _result = const PsResult(procs: []);
        _updateCapabilities(_result);
        _hasLoaded = true;
        if (userTriggered) context.showSnackBar(libL10n.empty);
        return;
      }

      final requestedSort = _procSortMode;
      var parsed = PsResult.parse(
        result,
        sort: requestedSort,
        ascending: _sortAscending,
        previous: _result,
      );
      final sortChanged = _updateCapabilities(parsed);
      if (sortChanged) {
        parsed = parsed.sortedBy(_procSortMode, ascending: _sortAscending);
      }
      _result = parsed;
      _hasLoaded = true;
    } on TimeoutException catch (e, s) {
      Loggers.app.warning('Process page command timed out', e, s);
      if (mounted && (userTriggered || !_hasLoaded)) {
        context.showSnackBar(libL10n.error);
      }
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
      if (!refreshCompleter.isCompleted) refreshCompleter.complete();
      if (identical(_refreshCompleter, refreshCompleter)) {
        _refreshCompleter = null;
      }
    }
  }

  bool _updateCapabilities(PsResult result) {
    _capabilities = _ProcessCapabilities.from(result.procs);
    if (!_capabilities.supportsSort(_procSortMode)) {
      _procSortMode = _capabilities.preferredSort;
      _sortAscending = _procSortMode.defaultAscending;
      return true;
    }
    return false;
  }

  void _selectSort(ProcSortMode mode) {
    if (!_capabilities.supportsSort(mode)) return;
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

  void _rebuild() {
    if (mounted) setState(() {});
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
            _capabilities,
          );
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _buildProcessBar(),
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
}

extension _ProcessPageStateWidgets on _ProcessPageState {
  Widget _buildProcessBar() {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 6, 8, 6),
      child: Row(
        children: [
          Text(
            context.l10n.processCount(_result.procs.length),
            style: theme.textTheme.labelLarge?.copyWith(
              color: scheme.onSurfaceVariant,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
          const Spacer(),
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
      return RefreshIndicator(
        onRefresh: () => _refresh(userTriggered: true),
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            SliverFillRemaining(
              hasScrollBody: false,
              child: CenterGreyTitle(
                libL10n.empty,
              ).paddingSymmetric(horizontal: 13),
            ),
          ],
        ),
      );
    }
    final scheme = Theme.of(context).colorScheme;
    final columns = _buildColumns(layout);
    return Column(
      children: [
        _buildHeader(columns),
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
                  _buildProcessRow(_result.procs[index], layout, columns),
            ),
          ),
        ),
      ],
    );
  }

  List<_ProcColumn> _buildColumns(_ProcessLayout layout) => [
    _ProcColumn(
      width: _pidWidth,
      label: 'PID',
      sortMode: ProcSortMode.pid,
      value: (proc) => '${proc.pid}',
      style: _ProcColumnStyle.mono,
    ),
    _ProcColumn(
      visible: layout.showUser,
      width: _userWidth,
      label: libL10n.user,
      sortMode: ProcSortMode.user,
      value: (proc) => proc.user ?? '—',
    ),
    _ProcColumn(
      visible: layout.showCpu,
      width: _metricWidth,
      label: 'CPU',
      sortMode: ProcSortMode.cpu,
      value: (proc) => _formatCpu(proc.cpu),
      textAlign: TextAlign.end,
      style: _ProcColumnStyle.mono,
    ),
    _ProcColumn(
      visible: layout.showMem,
      width: _metricWidth,
      label: 'MEM',
      sortMode: ProcSortMode.mem,
      value: (proc) => _formatPercent(proc.mem),
      textAlign: TextAlign.end,
      style: _ProcColumnStyle.mono,
    ),
    _ProcColumn(
      visible: layout.showRss,
      width: _rssWidth,
      label: 'RSS',
      sortMode: ProcSortMode.rss,
      value: _formatRss,
      textAlign: TextAlign.end,
      style: _ProcColumnStyle.mono,
    ),
    _ProcColumn(
      visible: layout.showRead,
      width: _ioWidth,
      label: 'R/s',
      sortMode: ProcSortMode.read,
      value: (proc) => _formatNullableSpeed(proc.readSpeed),
      textAlign: TextAlign.end,
      style: _ProcColumnStyle.mono,
    ),
    _ProcColumn(
      visible: layout.showWrite,
      width: _ioWidth,
      label: 'W/s',
      sortMode: ProcSortMode.write,
      value: (proc) => _formatNullableSpeed(proc.writeSpeed),
      textAlign: TextAlign.end,
      style: _ProcColumnStyle.mono,
    ),
    _ProcColumn(
      label: libL10n.name,
      sortMode: ProcSortMode.name,
      value: (proc) => proc.command.isEmpty ? '—' : proc.command,
      style: _ProcColumnStyle.command,
    ),
  ].where((column) => column.visible).toList(growable: false);

  Widget _buildHeader(List<_ProcColumn> columns) {
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
            for (final (index, column) in columns.indexed) ...[
              _buildColumnCell(
                column,
                _SortHeader(
                  label: column.label,
                  active: _procSortMode == column.sortMode,
                  ascending: _sortAscending,
                  alignEnd: column.textAlign == TextAlign.end,
                  onTap: () => _selectSort(column.sortMode),
                ),
              ),
              if (index < columns.length - 1) const SizedBox(width: _cellGap),
            ],
            const SizedBox(width: _actionWidth),
          ],
        ),
      ),
    );
  }

  Widget _buildProcessRow(
    Proc proc,
    _ProcessLayout layout,
    List<_ProcColumn> columns,
  ) {
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
            for (final (index, column) in columns.indexed) ...[
              _buildColumnCell(
                column,
                _buildProcessValue(
                  proc,
                  column,
                  layout: layout,
                  theme: theme,
                  monoStyle: monoStyle,
                ),
              ),
              if (index < columns.length - 1) const SizedBox(width: _cellGap),
            ],
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

  Widget _buildColumnCell(_ProcColumn column, Widget child) {
    final width = column.width;
    return width == null
        ? Expanded(child: child)
        : SizedBox(width: width, child: child);
  }

  Widget _buildProcessValue(
    Proc proc,
    _ProcColumn column, {
    required _ProcessLayout layout,
    required ThemeData theme,
    required TextStyle? monoStyle,
  }) {
    final text = Text(
      column.value(proc),
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      textAlign: column.textAlign,
      style: switch (column.style) {
        _ProcColumnStyle.body => theme.textTheme.bodySmall,
        _ProcColumnStyle.mono => monoStyle,
        _ProcColumnStyle.command => theme.textTheme.bodyMedium,
      },
    );
    if (column.style != _ProcColumnStyle.command) return text;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        text,
        if (layout.compact) ...[
          const SizedBox(height: 3),
          _buildCompactMetadata(proc),
        ],
      ],
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
            if (proc.vsz != null) _buildDetailLine('VSZ', _formatVsz(proc)),
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
}

extension _ProcessPageStateUtils on _ProcessPageState {
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

  String _formatVsz(Proc proc) {
    final raw = proc.vsz;
    if (raw == null || raw.isEmpty || raw == '-') return '—';
    final vszKb = int.tryParse(raw);
    return vszKb == null ? raw : (vszKb * 1024).bytes2Str;
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
}

extension _ProcessPageStateActions on _ProcessPageState {
  Future<void> _confirmKill(Proc proc) async {
    final confirmed = await context.showRoundDialog<bool>(
      title: libL10n.attention,
      child: Text(
        libL10n.askContinue('${libL10n.stop} ${libL10n.process}(${proc.pid})'),
      ),
      actions: Btnx.cancelOk,
    );
    if (confirmed != true || !mounted) return;
    await context.showLoadingDialog(fn: () => _killAndRefresh(proc.pid));
  }

  Future<void> _killAndRefresh(int pid) async {
    if (!mounted) return;
    while (_isRefreshing) {
      final refresh = _refreshCompleter;
      if (refresh == null) return;
      await refresh.future;
      if (!mounted) return;
    }
    _isRefreshing = true;
    _rebuild();
    try {
      final serverState = ref.read(_provider);
      final systemType = serverState.status.system;
      await serverState.client
          ?.run(_killProcessCmd(pid, systemType))
          .timeout(_processCommandTimeout);
    } on TimeoutException catch (e, s) {
      Loggers.app.warning('Process kill command timed out', e, s);
      if (mounted) context.showSnackBar(libL10n.error);
      return;
    } catch (e, s) {
      Loggers.app.warning('Process kill failed', e, s);
      if (mounted) context.showSnackBar(libL10n.error);
      return;
    } finally {
      _isRefreshing = false;
      _rebuild();
    }
    await _refresh(userTriggered: true);
  }
}

enum _ProcColumnStyle { body, mono, command }

class _ProcColumn {
  const _ProcColumn({
    required this.label,
    required this.sortMode,
    required this.value,
    this.visible = true,
    this.width,
    this.textAlign = TextAlign.start,
    this.style = _ProcColumnStyle.body,
  });

  final String label;
  final ProcSortMode sortMode;
  final String Function(Proc proc) value;
  final bool visible;
  final double? width;
  final TextAlign textAlign;
  final _ProcColumnStyle style;
}

class _ProcessCapabilities {
  const _ProcessCapabilities({
    required this.hasUser,
    required this.hasCpu,
    required this.hasMem,
    required this.hasRss,
    required this.hasRead,
    required this.hasWrite,
  });

  static const empty = _ProcessCapabilities(
    hasUser: false,
    hasCpu: false,
    hasMem: false,
    hasRss: false,
    hasRead: false,
    hasWrite: false,
  );

  factory _ProcessCapabilities.from(List<Proc> procs) {
    var hasUser = false;
    var hasCpu = false;
    var hasMem = false;
    var hasRss = false;
    var hasRead = false;
    var hasWrite = false;
    for (final proc in procs) {
      hasUser |= proc.user?.isNotEmpty == true;
      hasCpu |= proc.cpu != null;
      hasMem |= proc.mem != null;
      hasRss |= proc.rssKb != null;
      hasRead |= proc.readSpeed != null;
      hasWrite |= proc.writeSpeed != null;
      if (hasUser && hasCpu && hasMem && hasRss && hasRead && hasWrite) break;
    }
    return _ProcessCapabilities(
      hasUser: hasUser,
      hasCpu: hasCpu,
      hasMem: hasMem,
      hasRss: hasRss,
      hasRead: hasRead,
      hasWrite: hasWrite,
    );
  }

  final bool hasUser;
  final bool hasCpu;
  final bool hasMem;
  final bool hasRss;
  final bool hasRead;
  final bool hasWrite;

  bool supportsSort(ProcSortMode mode) => switch (mode) {
    ProcSortMode.cpu => hasCpu,
    ProcSortMode.mem => hasMem,
    ProcSortMode.rss => hasRss,
    ProcSortMode.read => hasRead,
    ProcSortMode.write => hasWrite,
    ProcSortMode.user => hasUser,
    ProcSortMode.pid || ProcSortMode.name => true,
  };

  ProcSortMode get preferredSort {
    if (hasCpu) return ProcSortMode.cpu;
    if (hasMem) return ProcSortMode.mem;
    if (hasRss) return ProcSortMode.rss;
    if (hasRead) return ProcSortMode.read;
    if (hasWrite) return ProcSortMode.write;
    return ProcSortMode.pid;
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

  factory _ProcessLayout.fromWidth(
    double width,
    _ProcessCapabilities capabilities,
  ) {
    final compact = width < _compactBreakpoint;
    return _ProcessLayout(
      compact: compact,
      showUser: !compact && capabilities.hasUser,
      showCpu: !compact && capabilities.hasCpu,
      showMem: !compact && capabilities.hasMem,
      showRss:
          !compact &&
          capabilities.hasRss &&
          (width >= _rssBreakpoint ||
              (!capabilities.hasUser && !capabilities.hasMem)),
      showRead: !compact && width >= _ioBreakpoint && capabilities.hasRead,
      showWrite: !compact && width >= _ioBreakpoint && capabilities.hasWrite,
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
    final semanticsLabel = active
        ? '$label, ${ascending ? context.l10n.ascending : context.l10n.descending}'
        : label;
    return Semantics(
      label: semanticsLabel,
      button: true,
      selected: active,
      excludeSemantics: true,
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
