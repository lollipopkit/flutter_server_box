import 'dart:async';

import 'package:dartssh2/dartssh2.dart';
import 'package:fl_lib/fl_lib.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:server_box/core/route.dart';
import 'package:server_box/core/utils/refresh_interval.dart';
import 'package:server_box/data/model/app/scripts/shell_func.dart';
import 'package:server_box/data/model/server/proc.dart';
import 'package:server_box/data/provider/server/single.dart';

class ProcessPage extends ConsumerStatefulWidget {
  final SpiRequiredArgs args;

  const ProcessPage({super.key, required this.args});

  @override
  ConsumerState<ProcessPage> createState() => _ProcessPageState();

  static const route = AppRouteArg(page: ProcessPage.new, path: '/process');
}

class _ProcessPageState extends ConsumerState<ProcessPage> {
  Timer? _timer;
  late MediaQueryData _media;

  SSHClient? _client;

  PsResult _result = const PsResult(procs: []);
  bool _checkedIncompleteData = false;

  // Issue #64
  // In cpu mode, the process list will change in a high frequency.
  // So user will easily know that the list is refreshed.
  ProcSortMode _procSortMode = ProcSortMode.cpu;
  final _sortModes = List<ProcSortMode>.from(ProcSortMode.values);

  late final _provider = serverProvider(widget.args.spi.id);

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    final serverState = ref.read(_provider);
    _client = serverState.client;
    _refresh();
    final duration = serverStatusRefreshInterval();
    if (duration != null) {
      _timer = Timer.periodic(duration, (_) => _refresh());
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _media = MediaQuery.of(context);
  }

  Future<void> _refresh() async {
    if (!mounted) return;
    try {
      final serverState = ref.read(_provider);
      final systemType = serverState.status.system;
      final result = await _client
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
    } catch (e) {
      if (mounted) {
        context.showSnackBar(libL10n.error);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final actions = <Widget>[
      PopupMenuButton<ProcSortMode>(
        onSelected: (value) {
          setState(() {
            _procSortMode = value;
          });
        },
        icon: const Icon(Icons.sort),
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
                    proc.binary,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text(
                    proc.command,
                    style: UIs.textGrey,
                    maxLines: 3,
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
    );
  }

  double get _leadingWidth =>
      (_media.size.width / 6).clamp(44.0, 72.0).toDouble();
}

extension _ProcessPageStateWidgets on _ProcessPageState {
  Widget _buildItemTrail(Proc proc) {
    final items = <({String up, String down})>[
      if (proc.cpu != null) (up: proc.cpu!.toStringAsFixed(1), down: 'cpu'),
      if (proc.mem != null) (up: proc.mem!.toStringAsFixed(1), down: 'mem'),
      if (proc.readSpeed != null)
        (up: _formatSpeed(proc.readSpeed!), down: 'R'),
      if (proc.writeSpeed != null)
        (up: _formatSpeed(proc.writeSpeed!), down: 'W'),
    ];
    final showCompactStats = _media.size.width < 520 && items.length > 2;
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
          constraints: const BoxConstraints.tightFor(width: 36, height: 36),
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
                        await _client?.run('kill ${proc.pid}');
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
      width: 108,
      child: Wrap(
        runSpacing: 4,
        children: [
          for (final item in items)
            SizedBox(width: 54, child: _buildStatText(item)),
        ],
      ),
    );
  }

  Widget _buildStatText(({String up, String down}) item) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          width: 52,
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
}
