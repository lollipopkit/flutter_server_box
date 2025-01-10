import 'dart:async';

import 'package:fl_lib/fl_lib.dart';
import 'package:flutter/material.dart';
import 'package:server_box/core/extension/context/locale.dart';
import 'package:server_box/data/model/server/pve.dart';
import 'package:server_box/data/model/server/server_private_info.dart';
import 'package:server_box/data/provider/pve.dart';
import 'package:server_box/data/res/store.dart';
import 'package:server_box/view/widget/percent_circle.dart';
import 'package:server_box/view/widget/two_line_text.dart';

final class PvePage extends StatefulWidget {
  final Spi spi;

  const PvePage({
    super.key,
    required this.spi,
  });

  @override
  State<PvePage> createState() => _PvePageState();
}

const _kHorziPadding = 11.0;

final class _PvePageState extends State<PvePage> {
  late final _pve = PveProvider(spi: widget.spi);
  late MediaQueryData _media;
  Timer? _timer;

  @override
  void dispose() {
    super.dispose();
    _timer?.cancel();
    _pve.dispose();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _media = MediaQuery.of(context);
  }

  @override
  void initState() {
    super.initState();
    _initRefreshTimer();
    _afterInit();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: TwoLineText(up: 'PVE', down: widget.spi.name),
        actions: [
          ValBuilder(
            listenable: _pve.err,
            builder: (val) => val == null
                ? UIs.placeholder
                : Btn.icon(
                    icon: const Icon(Icons.refresh),
                    onTap: () {
                      _pve.err.value = null;
                      _pve.list();
                      _initRefreshTimer();
                    },
                  ),
          ),
        ],
      ),
      body: ValBuilder(
        listenable: _pve.err,
        builder: (val) {
          if (val != null) {
            _timer?.cancel();
            return Padding(
              padding: const EdgeInsets.all(13),
              child: Center(
                child: Text(val),
              ),
            );
          }
          return ValBuilder(
            listenable: _pve.data,
            builder: (val) {
              return _buildBody(val);
            },
          );
        },
      ),
    );
  }

  Widget _buildBody(PveRes? data) {
    if (data == null) {
      return UIs.centerLoading;
    }

    PveResType? lastType;
    return ListView.builder(
      padding: const EdgeInsets.symmetric(
        horizontal: _kHorziPadding,
        vertical: 7,
      ),
      itemCount: data.length * 2,
      itemBuilder: (context, index) {
        final item = data[index ~/ 2];
        if (index % 2 == 0) {
          final type = switch (item) {
            final PveNode _ => PveResType.node,
            final PveQemu _ => PveResType.qemu,
            final PveLxc _ => PveResType.lxc,
            final PveStorage _ => PveResType.storage,
            final PveSdn _ => PveResType.sdn,
          };
          if (type == lastType) {
            return UIs.placeholder;
          }
          lastType = type;
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 7),
            child: Align(
              alignment: Alignment.center,
              child: Text(
                type.toStr,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Colors.grey,
                ),
                textAlign: TextAlign.start,
              ),
            ),
          );
        }
        return switch (item) {
          final PveNode _ => _buildNode(item),
          final PveQemu _ => _buildQemu(item),
          final PveLxc _ => _buildLxc(item),
          final PveStorage _ => _buildStorage(item),
          final PveSdn _ => _buildSdn(item),
        };
      },
    );
  }

  Widget _buildNode(PveNode item) {
    final valueAnim = AlwaysStoppedAnimation(UIs.primaryColor);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 13, horizontal: 13),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Text(item.node, style: UIs.text15Bold),
              const Spacer(),
              Text(item.topRight, style: UIs.text12Grey),
            ],
          ),
          UIs.height13,
          // Row(
          //   mainAxisAlignment: MainAxisAlignment.spaceAround,
          //   children: [
          //     _wrap(PercentCircle(percent: item.cpu / item.maxcpu), 3),
          //     _wrap(PercentCircle(percent: item.mem / item.maxmem), 3),
          //   ],
          // ),
          Row(
            children: [
              const Icon(Icons.memory, size: 13, color: Colors.grey),
              UIs.width7,
              const Text('CPU', style: UIs.text12Grey),
              const Spacer(),
              Text(
                '${(item.cpu * 100).toStringAsFixed(1)} %',
                style: UIs.text12Grey,
              ),
            ],
          ),
          const SizedBox(height: 3),
          LinearProgressIndicator(
            value: item.cpu / item.maxcpu,
            minHeight: 7,
            valueColor: valueAnim,
          ),
          UIs.height7,
          Row(
            children: [
              const Icon(Icons.view_agenda, size: 13, color: Colors.grey),
              UIs.width7,
              const Text('RAM', style: UIs.text12Grey),
              const Spacer(),
              Text(
                '${item.mem.bytes2Str} / ${item.maxmem.bytes2Str}',
                style: UIs.text12Grey,
              ),
            ],
          ),
          const SizedBox(height: 3),
          LinearProgressIndicator(
            value: item.mem / item.maxmem,
            minHeight: 7,
            valueColor: valueAnim,
          ),
        ],
      ),
    ).cardx;
  }

  Widget _buildQemu(PveQemu item) {
    if (!item.available) {
      return ListTile(
        title: Text(_wrapNodeName(item), style: UIs.text13Bold),
        trailing: _buildCtrlBtns(item),
      ).cardx;
    }
    final children = <Widget>[
      const SizedBox(height: 5),
      Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          const SizedBox(width: 15),
          Text(
            _wrapNodeName(item),
            style: UIs.text13Bold,
          ),
          Text(
            '  /  ${item.summary}',
            style: UIs.text12Grey,
          ),
          const Spacer(),
          _buildCtrlBtns(item),
          UIs.width13,
        ],
      ),
      UIs.height7,
      AvgWidthRow(
        width: _media.size.width,
        padding: _kHorziPadding * 2 + 26,
        children: [
          PercentCircle(percent: (item.cpu / item.maxcpu) * 100),
          PercentCircle(percent: (item.mem / item.maxmem) * 100),
          Column(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                '${l10n.read}:\n${item.diskread.bytes2Str}',
                style: UIs.text11Grey,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 3),
              Text(
                '${l10n.write}:\n${item.diskwrite.bytes2Str}',
                style: UIs.text11Grey,
                textAlign: TextAlign.center,
              )
            ],
          ),
          Column(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                '↓:\n${item.netin.bytes2Str}',
                style: UIs.text11Grey,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 3),
              Text(
                '↑:\n${item.netout.bytes2Str}',
                style: UIs.text11Grey,
                textAlign: TextAlign.center,
              )
            ],
          ),
        ],
      ),
      const SizedBox(height: 21)
    ];
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: children,
    ).cardx;
  }

  Widget _buildLxc(PveLxc item) {
    if (!item.available) {
      return ListTile(
        title: Text(_wrapNodeName(item), style: UIs.text13Bold),
        trailing: _buildCtrlBtns(item),
      ).cardx;
    }
    final children = <Widget>[
      const SizedBox(height: 5),
      Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          const SizedBox(width: 15),
          Text(
            _wrapNodeName(item),
            style: UIs.text13Bold,
          ),
          Text(
            '  /  ${item.summary}',
            style: UIs.text12Grey,
          ),
          const Spacer(),
          _buildCtrlBtns(item),
          UIs.width13,
        ],
      ),
      UIs.height7,
      AvgWidthRow(
        width: _media.size.width,
        padding: _kHorziPadding * 2 + 26,
        children: [
          PercentCircle(percent: (item.cpu / item.maxcpu) * 100),
          PercentCircle(percent: (item.mem / item.maxmem) * 100),
          Column(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                '${l10n.read}:\n${item.diskread.bytes2Str}',
                style: UIs.text11Grey,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 3),
              Text(
                '${l10n.write}:\n${item.diskwrite.bytes2Str}',
                style: UIs.text11Grey,
                textAlign: TextAlign.center,
              )
            ],
          ),
          Column(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                '↓:\n${item.netin.bytes2Str}',
                style: UIs.text11Grey,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 3),
              Text(
                '↑:\n${item.netout.bytes2Str}',
                style: UIs.text11Grey,
                textAlign: TextAlign.center,
              )
            ],
          ),
        ],
      ),
      const SizedBox(height: 21)
    ];
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: children,
    ).cardx;
  }

  Widget _buildStorage(PveStorage item) {
    return Padding(
      padding: const EdgeInsets.all(13),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(_wrapNodeName(item), style: UIs.text13Bold),
              const Spacer(),
              Text(item.summary, style: UIs.text11Grey),
            ],
          ),
          UIs.height7,
          KvRow(k: libL10n.content, v: item.content),
          KvRow(k: l10n.plugInType, v: item.plugintype),
        ],
      ),
    ).cardx;
  }

  Widget _buildSdn(PveSdn item) {
    return ListTile(
      title: Text(_wrapNodeName(item)),
      trailing: Text(item.summary),
    ).cardx;
  }

  Widget _buildCtrlBtns(PveCtrlIface item) {
    const pad = EdgeInsets.symmetric(horizontal: 7, vertical: 5);
    if (!item.available) {
      return Btn.icon(
          icon: const Icon(Icons.play_arrow, color: Colors.grey),
          onTap: () => _onCtrl(_pve.start, l10n.start, item));
    }
    return Row(
      children: [
        Btn.icon(
            icon: const Icon(Icons.stop, color: Colors.grey, size: 20),
            padding: pad,
            onTap: () => _onCtrl(_pve.stop, l10n.stop, item)),
        Btn.icon(
            icon: const Icon(Icons.refresh, color: Colors.grey, size: 20),
            padding: pad,
            onTap: () => _onCtrl(_pve.reboot, l10n.reboot, item)),
        Btn.icon(
            icon: const Icon(Icons.power_off, color: Colors.grey, size: 20),
            padding: pad,
            onTap: () => _onCtrl(_pve.shutdown, l10n.shutdown, item)),
      ],
    );
  }

  void _onCtrl(PveCtrlFunc func, String action, PveCtrlIface item) async {
    final sure = await context.showRoundDialog<bool>(
      title: libL10n.attention,
      child: Text(libL10n.askContinue('$action ${item.id}')),
      actions: Btnx.okReds,
    );
    if (sure != true) return;

    final (suc, err) = await context.showLoadingDialog(
      fn: () => func(item.node, item.id),
    );
    if (suc == true) {
      context.showSnackBar(libL10n.success);
    } else {
      context.showSnackBar(err?.toString() ?? libL10n.fail);
    }
  }

  /// Add PveNode if [PveProvider.onlyOneNode] is false
  String _wrapNodeName(PveCtrlIface item) {
    if (_pve.onlyOneNode) {
      return item.name;
    }
    return '${item.node} / ${item.name}';
  }

  void _initRefreshTimer() {
    _timer = Timer.periodic(
        Duration(seconds: Stores.setting.serverStatusUpdateInterval.fetch()),
        (_) {
      if (mounted) {
        _pve.list();
      }
    });
  }

  void _afterInit() async {
    await _pve.connected.future;
    if (_pve.release != null && _pve.release!.compareTo('8.0') < 0) {
      if (mounted) {
        context.showSnackBar(l10n.pveVersionLow);
      }
    }
  }
}
