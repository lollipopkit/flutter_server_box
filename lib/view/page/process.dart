import 'dart:async';

import 'package:dartssh2/dartssh2.dart';
import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/l10n.dart';
import 'package:toolbox/core/extension/navigator.dart';
import 'package:toolbox/core/extension/stringx.dart';
import 'package:toolbox/core/extension/uint8list.dart';
import 'package:toolbox/core/utils/ui.dart';
import 'package:toolbox/data/model/server/proc.dart';
import 'package:toolbox/data/model/server/server_private_info.dart';
import 'package:toolbox/data/res/ui.dart';
import 'package:toolbox/view/widget/round_rect_card.dart';
import 'package:toolbox/view/widget/two_line_text.dart';

import '../../data/provider/server.dart';
import '../../locator.dart';

class ProcessPage extends StatefulWidget {
  final ServerPrivateInfo spi;
  const ProcessPage({super.key, required this.spi});

  @override
  _ProcessPageState createState() => _ProcessPageState();
}

class _ProcessPageState extends State<ProcessPage> {
  late S _s;
  late Timer _timer;
  SSHClient? _client;

  PsResult _result = PsResult(procs: []);
  int? _lastFocusId;
  ProcSortMode _procSortMode = ProcSortMode.mem;

  final _serverProvider = locator<ServerProvider>();

  @override
  void initState() {
    super.initState();
    _client = _serverProvider.servers[widget.spi.id]?.client;
    if (_client == null) {
      showSnackBar(context, Text(_s.noClient));
      return;
    }
    _timer =
        Timer.periodic(const Duration(seconds: 3), (_) => _refresh());
  }

  Future<void> _refresh() async {
    if (mounted) {
      final result = await _client?.run('ps -aux'.withLangExport).string;
      if (result == null || result.isEmpty) {
        showSnackBar(context, Text(_s.noResult));
        return;
      }
      _result = PsResult.parse(result, sort: _procSortMode);
      setState(() {});
    } else {
      _timer.cancel();
    }
  }

  @override
  void dispose() {
    super.dispose();
    _timer.cancel();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _s = S.of(context)!;
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
        itemBuilder: (_) => ProcSortMode.values
            .map(
              (e) => PopupMenuItem(value: e, child: Text(e.name)),
            )
            .toList(),
      ),
    ];
    if (_result.error != null) {
      actions.add(IconButton(
        icon: const Icon(Icons.error),
        onPressed: () => showRoundDialog(
          context: context,
          title: Text(_s.error),
          child: Text(_result.error!),
        ),
      ));
    }
    Widget child;
    if (_result.procs.isEmpty) {
      child = centerLoading;
    } else {
      child = ListView.builder(
        itemCount: _result.procs.length,
        padding: const EdgeInsets.symmetric(vertical: 3, horizontal: 7),
        itemBuilder: (ctx, idx) {
          final proc = _result.procs[idx];
          return _buildListItem(proc);
        },
      );
    }
    return Scaffold(
      appBar: AppBar(
        centerTitle: true,
        title: TwoLineText(up: widget.spi.name, down: _s.process),
        actions: actions,
      ),
      body: child,
    );
  }

  Widget _buildListItem(Proc proc) {
    return RoundRectCard(ListTile(
      leading: SizedBox(
        width: 57,
        child: TwoLineText(up: proc.pid.toString(), down: proc.user),
      ),
      title: Text(proc.binary),
      subtitle: Text(
        proc.command,
        style: grey,
        maxLines: 3,
        overflow: TextOverflow.fade,
      ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          TwoLineText(up: proc.cpu.toStringAsFixed(1), down: 'cpu'),
          width13,
          TwoLineText(up: proc.mem.toStringAsFixed(1), down: 'mem'),
        ],
      ),
      onTap: () => _lastFocusId = proc.pid,
      onLongPress: () {
        showRoundDialog(
          context: context,
          title: Text(_s.attention),
          child: Text(_s.sureStop(proc.pid)),
          actions: [
            TextButton(
              onPressed: () async {
                await _client?.run('kill ${proc.pid}');
                await _refresh();
                context.pop();
              },
              child: Text(_s.ok),
            ),
          ],
        );
      },
      selected: _lastFocusId == proc.pid,
      autofocus: _lastFocusId == proc.pid,
    ));
  }
}
