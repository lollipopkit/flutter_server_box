import 'dart:async';

import 'package:dartssh2/dartssh2.dart';
import 'package:fl_lib/fl_lib.dart';
import 'package:flutter/material.dart';
import 'package:server_box/core/extension/context/locale.dart';
import 'package:server_box/data/res/store.dart';

import 'package:server_box/data/model/app/shell_func.dart';
import 'package:server_box/data/model/server/proc.dart';
import 'package:server_box/data/model/server/server_private_info.dart';
import 'package:server_box/view/widget/two_line_text.dart';

class ProcessPage extends StatefulWidget {
  final Spi spi;
  const ProcessPage({super.key, required this.spi});

  @override
  State<ProcessPage> createState() => _ProcessPageState();
}

class _ProcessPageState extends State<ProcessPage> {
  late Timer _timer;
  late MediaQueryData _media;

  SSHClient? _client;

  PsResult _result = const PsResult(procs: []);
  int? _lastFocusId;

  // Issue #64
  // In cpu mode, the process list will change in a high frequency.
  // So user will easily know that the list is refreshed.
  ProcSortMode _procSortMode = ProcSortMode.cpu;
  List<ProcSortMode> _sortModes = List.from(ProcSortMode.values);

  @override
  void dispose() {
    super.dispose();
    _timer.cancel();
  }

  @override
  void initState() {
    super.initState();
    _client = widget.spi.server?.value.client;
    final duration =
        Duration(seconds: Stores.setting.serverStatusUpdateInterval.fetch());
    _timer = Timer.periodic(duration, (_) => _refresh());
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _media = MediaQuery.of(context);
  }

  Future<void> _refresh() async {
    if (mounted) {
      final result =
          await _client?.run(ShellFunc.process.exec(widget.spi.id)).string;
      if (result == null || result.isEmpty) {
        context.showSnackBar(libL10n.empty);
        return;
      }
      _result = PsResult.parse(result, sort: _procSortMode);

      // If there are any [Proc]'s data is not complete,
      // the option to sort by cpu/mem will not be available.
      final isAnyProcDataNotComplete =
          _result.procs.any((e) => e.cpu == null || e.mem == null);
      if (isAnyProcDataNotComplete) {
        _sortModes.removeWhere((e) => e == ProcSortMode.cpu);
        _sortModes.removeWhere((e) => e == ProcSortMode.mem);
      } else {
        _sortModes = ProcSortMode.values;
      }
      setState(() {});
    } else {
      _timer.cancel();
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
      actions.add(IconButton(
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
      ));
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
      appBar: AppBar(
        centerTitle: true,
        title: TwoLineText(up: widget.spi.name, down: l10n.process),
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
      child: ListTile(
        leading: SizedBox(
          width: _media.size.width / 6,
          child: leading,
        ),
        title: Text(proc.binary),
        subtitle: Text(
          proc.command,
          style: UIs.textGrey,
          maxLines: 3,
          overflow: TextOverflow.fade,
        ),
        trailing: _buildItemTrail(proc),
        onTap: () => _lastFocusId = proc.pid,
        onLongPress: () {
          context.showRoundDialog(
            title: libL10n.attention,
            child: Text(libL10n.askContinue(
              '${l10n.stop} ${l10n.process}(${proc.pid})',
            )),
            actions: Btn.ok(onTap: () async {
              context.pop();
              await context.showLoadingDialog(fn: () async {
                await _client?.run('kill ${proc.pid}');
                await _refresh();
              });
            }).toList,
          );
        },
        selected: _lastFocusId == proc.pid,
        autofocus: _lastFocusId == proc.pid,
      ),
    );
  }

  Widget? _buildItemTrail(Proc proc) {
    if (proc.cpu == null && proc.mem == null) {
      return null;
    }
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (proc.cpu != null)
          TwoLineText(
            up: proc.cpu!.toStringAsFixed(1),
            down: 'cpu',
          ),
        UIs.width13,
        if (proc.mem != null)
          TwoLineText(
            up: proc.mem!.toStringAsFixed(1),
            down: 'mem',
          ),
      ],
    );
  }
}
