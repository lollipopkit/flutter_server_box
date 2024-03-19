import 'dart:async';

import 'package:flutter/material.dart';
import 'package:toolbox/core/extension/context/locale.dart';
import 'package:toolbox/core/extension/numx.dart';
import 'package:toolbox/core/extension/widget.dart';
import 'package:toolbox/data/model/server/pve.dart';
import 'package:toolbox/data/model/server/server_private_info.dart';
import 'package:toolbox/data/provider/pve.dart';
import 'package:toolbox/data/res/color.dart';
import 'package:toolbox/data/res/store.dart';
import 'package:toolbox/data/res/ui.dart';
import 'package:toolbox/view/widget/appbar.dart';
import 'package:toolbox/view/widget/kv_row.dart';
import 'package:toolbox/view/widget/percent_circle.dart';
import 'package:toolbox/view/widget/two_line_text.dart';

final class PvePage extends StatefulWidget {
  final ServerPrivateInfo spi;

  const PvePage({
    super.key,
    required this.spi,
  });

  @override
  _PvePageState createState() => _PvePageState();
}

const _kHorziPadding = 11.0;

final class _PvePageState extends State<PvePage> {
  late final _pve = PveProvider(spi: widget.spi);
  late MediaQueryData _media;
  Timer? _timer;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _media = MediaQuery.of(context);
  }

  @override
  void initState() {
    super.initState();
    _initRefreshTimer();
  }

  @override
  void dispose() {
    super.dispose();
    _timer?.cancel();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: CustomAppBar(
        title: TwoLineText(up: 'PVE', down: widget.spi.name),
      ),
      body: ValueListenableBuilder(
        valueListenable: _pve.data,
        builder: (_, val, __) {
          return _buildBody(val);
        },
      ),
    );
  }

  Widget _buildBody(PveRes? data) {
    if (_pve.err.value != null) {
      return Center(
        child: Text('Failed to connect to PVE: ${_pve.err.value}'),
      );
    }

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
    final valueAnim = AlwaysStoppedAnimation(primaryColor);
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
    ).card;
  }

  Widget _buildQemu(PveQemu item) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        UIs.height13,
        Row(
          children: [
            UIs.width13,
            Text(item.name, style: UIs.text13Bold),
            const Spacer(),
            Text(item.topRight, style: UIs.text12Grey),
            UIs.width13,
          ],
        ),
        if (item.isRunning)
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _wrap(PercentCircle(percent: (item.cpu / item.maxcpu) * 100), 4),
              _wrap(PercentCircle(percent: (item.mem / item.maxmem) * 100), 4),
              _wrap(
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
                  4),
              _wrap(
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
                  4),
            ],
          ),
        UIs.height13,
      ],
    ).card;
  }

  Widget _buildLxc(PveLxc item) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        UIs.height13,
        Row(
          children: [
            UIs.width13,
            Text(item.name, style: UIs.text13Bold),
            const Spacer(),
            Text(item.topRight, style: UIs.text12Grey),
            UIs.width13,
          ],
        ),
        UIs.height7,
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            _wrap(PercentCircle(percent: (item.cpu / item.maxcpu) * 100), 4),
            _wrap(PercentCircle(percent: (item.mem / item.maxmem) * 100), 4),
            _wrap(
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
                4),
            _wrap(
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
                4),
          ],
        ),
        UIs.height13,
      ],
    ).card;
  }

  Widget _buildStorage(PveStorage item) {
    return Padding(
      padding: const EdgeInsets.all(13),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Text(item.storage, style: UIs.text13Bold),
              const Spacer(),
              Text(item.status, style: UIs.text12Grey),
            ],
          ),
          UIs.height7,
          KvRow(k: l10n.content, v: item.content),
          KvRow(k: l10n.plugInType, v: item.plugintype),
        ],
      ),
    ).card;
  }

  Widget _buildSdn(PveSdn item) {
    return ListTile(
      title: Text(item.sdn),
      trailing: Text(item.status),
    ).card;
  }

  Widget _wrap(Widget child, int count) {
    return SizedBox(
      height: (_media.size.width - 2 * _kHorziPadding) / count,
      child: child,
    );
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
}
