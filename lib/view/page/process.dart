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

const _compactStatsWidthBreakpoint = 520.0;
const _compactStatsWidth = 108.0;
const _compactStatItemWidth = 54.0;
const _statTextWidth = 52.0;
const _stopButtonSize = 36.0;
const _minLeadingWidth = 44.0;
const _maxLeadingWidth = 72.0;

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
  bool _checkedIncompleteData = false;
  bool _isRefreshing = false;

  // Issue #64
  // In cpu mode, the process list will change in a high frequency.
  // So user will easily know that the list is refreshed.
  ProcSortMode _procSortMode = ProcSortMode.cpu;
  final _sortModes = List<ProcSortMode>.from(ProcSortMode.values);

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
        // Resume periodic refresh and fetch immediately so the user doesn't
        // stare at stale data after returning to the app.
        _startRefreshTimer();
        _refresh();
        break;
      case AppLifecycleState.paused:
        // Stop the timer to avoid wasting battery and traffic while the app
        // is in the background.
        _timer?.cancel();
        _timer = null;
        break;
      default:
        break;
    }
  }

  Future<void> _refresh() async {
    if (!mounted || _isRefreshing) return;
    _isRefreshing = true;
    try {
      final serverState = ref.read(_provider);
      final systemType = serverState.status.system;
      final client = serverState.client;
      // Skip refresh when the server is not connected; showing an "empty"
      // snackbar in this case is misleading. The last successful snapshot
      // (if any) is kept on screen so the user can still inspect stale data.
      if (!_canRunProcessCmd(serverState)) {
        if (mounted) context.showSnackBar(libL10n.disconnected);
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
      if (result == null || result.isEmpty) {
        context.showSnackBar(libL10n.empty);
        return;
      }
      final parsed = PsResult.parse(
        result,
        sort: _procSortMode,
        previous: _result,
      );

      if (!_checkedIncompleteData) {
        final isAnyProcDataNotComplete = parsed.procs.any(
          (e) => e.cpu == null || e.mem == null,
        );
        if (isAnyProcDataNotComplete) {
          _sortModes.removeWhere(
            (e) => e == ProcSortMode.cpu || e == ProcSortMode.mem,
          );
        }
        final hasAnyProcIoData = parsed.procs.any(
          (e) => e.readBytes != null || e.writeBytes != null,
        );
        if (!hasAnyProcIoData) {
          _sortModes.removeWhere(
            (e) => e == ProcSortMode.read || e == ProcSortMode.write,
          );
        }
        if (!_sortModes.contains(_procSortMode)) {
          _procSortMode = _sortModes.first;
        }
        _checkedIncompleteData = true;
      }
      _result = parsed;
      if (mounted) setState(() {});
    } catch (e, s) {
      Loggers.app.warning('Process page refresh failed', e, s);
      if (mounted) {
        context.showSnackBar(libL10n.error);
      }
    } finally {
      _isRefreshing = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    final actions = <Widget>[
      PopupMenuButton<ProcSortMode>(
        onSelected: (value) {
          setState(() {
            _procSortMode = value;
            _result = _result.sortedBy(value);
          });
          _refresh();
        },
        icon: const Icon(Icons.sort),
        tooltip: context.l10n.sort,
        initialValue: _procSortMode,
        itemBuilder: (_) => _sortModes
            .map((e) => PopupMenuItem(value: e, child: Text(e.name)))
            .toList(),
      ),
    ];
    if (_result.error != null) {
      actions.add(
        IconButton(
          icon: const Icon(Icons.error),
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
    Widget child;
    if (_result.procs.isEmpty) {
      child = UIs.centerLoading;
    } else {
      child = ListView.builder(
        itemCount: _result.procs.length,
        padding: const EdgeInsets.symmetric(vertical: 3, horizontal: 7),
        itemBuilder: (_, idx) => _buildListItem(_result.procs[idx]),
      );
    }
    return Scaffold(
      appBar: CustomAppBar(
        centerTitle: true,
        title: TwoLineText(up: libL10n.process, down: widget.args.spi.name),
        actions: actions,
      ),
      body: child,
    );
  }

  Widget _buildListItem(Proc proc) {
    final leading = proc.user == null
        ? Text(proc.pid.toString())
        : TwoLineText(up: proc.pid.toString(), down: proc.user!);
    return CardX(
      key: ValueKey(proc.pid),
      child: InkWell(
        borderRadius: BorderRadius.circular(13),
        onTap: () => _showProcessDetails(proc),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 9),
          child: Row(
            children: [
              SizedBox(width: _leadingWidth, child: leading),
              UIs.width13,
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      proc.binary.isEmpty ? proc.command : proc.binary,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (proc.args.isNotEmpty)
                      Text(
                        proc.args,
                        style: UIs.textGrey,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                  ],
                ),
              ),
              UIs.width7,
              _buildItemTrail(proc),
            ],
          ),
        ),
      ),
    );
  }

  double get _leadingWidth =>
      (_screenWidth / 6).clamp(_minLeadingWidth, _maxLeadingWidth).toDouble();

  double get _screenWidth => MediaQuery.sizeOf(context).width;
}

extension _ProcessPageStateWidgets on _ProcessPageState {
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
            if (proc.cpu != null)
              _buildDetailLine('CPU', proc.cpu!.toStringAsFixed(1)),
            if (proc.mem != null)
              _buildDetailLine('MEM', proc.mem!.toStringAsFixed(1)),
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

  Widget _buildDetailLine(String label, String value) {
    return Text('$label: $value');
  }

  Widget _buildItemTrail(Proc proc) {
    final items = <({String up, String down})>[
      if (proc.cpu != null) (up: proc.cpu!.toStringAsFixed(1), down: 'cpu'),
      if (proc.mem != null) (up: proc.mem!.toStringAsFixed(1), down: 'mem'),
      if (proc.readSpeed != null)
        (up: _formatSpeed(proc.readSpeed!), down: 'R'),
      if (proc.writeSpeed != null)
        (up: _formatSpeed(proc.writeSpeed!), down: 'W'),
    ];
    final showCompactStats =
        _screenWidth < _compactStatsWidthBreakpoint && items.length > 2;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (showCompactStats)
          _buildCompactStats(items)
        else
          for (final (idx, item) in items.indexed) ...[
            if (idx > 0) UIs.width13,
            _buildStatText(item),
          ],
        if (items.isNotEmpty) UIs.width7,
        IconButton(
          visualDensity: VisualDensity.compact,
          constraints: const BoxConstraints.tightFor(
            width: _stopButtonSize,
            height: _stopButtonSize,
          ),
          icon: const Icon(Icons.stop),
          onPressed: () {
            context.showRoundDialog(
              title: libL10n.attention,
              child: Text(
                libL10n.askContinue(
                  '${libL10n.stop} ${libL10n.process}(${proc.pid})',
                ),
              ),
              actions: [
                Btn.cancel(),
                Btn.ok(
                  onTap: () async {
                    context.pop();
                    await context.showLoadingDialog(
                      fn: () async {
                        final systemType = ref.read(_provider).status.system;
                        await ref
                            .read(_provider)
                            .client
                            ?.run(_killProcessCmd(proc.pid, systemType));
                        await _refresh();
                      },
                    );
                  },
                ),
              ],
            );
          },
        ),
      ],
    );
  }

  Widget _buildCompactStats(List<({String up, String down})> items) {
    return SizedBox(
      width: _compactStatsWidth,
      child: Wrap(
        runSpacing: 4,
        children: [
          for (final item in items)
            SizedBox(width: _compactStatItemWidth, child: _buildStatText(item)),
        ],
      ),
    );
  }

  Widget _buildStatText(({String up, String down}) item) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          width: _statTextWidth,
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(item.up, maxLines: 1),
          ),
        ),
        Text(item.down, style: UIs.textGrey, maxLines: 1),
      ],
    );
  }
}

extension _ProcessPageStateUtils on _ProcessPageState {
  String _formatSpeed(double bytes) => '${bytes.bytes2Str}/s';

  bool _canRunProcessCmd(ServerState serverState) {
    final client = serverState.client;
    if (client == null || client.isClosed) return false;
    // `loading` is a transient state during status parsing; avoid issuing a
    // concurrent process command that may contend with the in-flight status
    // request on the same SSH connection.
    final conn = serverState.conn;
    return conn == ServerConn.connected ||
        conn == ServerConn.finished;
  }

  String _killProcessCmd(int pid, SystemType systemType) =>
      switch (systemType) {
        SystemType.windows => 'Stop-Process -Id $pid -Force',
        SystemType.linux || SystemType.bsd => 'kill $pid',
      };
}
