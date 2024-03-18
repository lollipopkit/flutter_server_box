import 'package:flutter/material.dart';
import 'package:toolbox/core/extension/numx.dart';
import 'package:toolbox/core/extension/widget.dart';
import 'package:toolbox/data/model/server/pve.dart';
import 'package:toolbox/data/model/server/server_private_info.dart';
import 'package:toolbox/data/provider/pve.dart';
import 'package:toolbox/data/res/ui.dart';
import 'package:toolbox/view/widget/appbar.dart';
import 'package:toolbox/view/widget/future_widget.dart';
import 'package:toolbox/view/widget/percent_circle.dart';

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
  late final pve = PveProvider(spi: widget.spi);
  late MediaQueryData _media;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _media = MediaQuery.of(context);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const CustomAppBar(
        title: Text('PVE'),
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (pve.err.value != null) {
      return Center(
        child: Text('Failed to connect to PVE: ${pve.err.value}'),
      );
    }
    return FutureWidget(
      future: pve.list(),
      error: (e, _) {
        return Center(
          child: Text('Failed to list PVE: $e'),
        );
      },
      loading: UIs.centerLoading,
      success: (data) {
        if (data == null) {
          return const Center(
            child: Text('No PVE Resource found'),
          );
        }

        PveResType? lastType;
        return ListView.separated(
          padding: const EdgeInsets.symmetric(
            horizontal: _kHorziPadding,
            vertical: 7,
          ),
          itemCount: data.length + 1,
          separatorBuilder: (context, index) {
            final type = switch (data[index]) {
              final PveNode _ => PveResType.node,
              final PveQemu _ => PveResType.qemu,
              final PveLxc _ => PveResType.lxc,
              final PveStorage _ => PveResType.storage,
              final PveSdn _ => PveResType.sdn,
            };
            if (type == lastType) {
              return UIs.placeholder;
            }
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
          },
          itemBuilder: (context, index) {
            if (index == 0) return UIs.placeholder;
            final item = data[index - 1];
            switch (item) {
              case final PveNode item:
                lastType = PveResType.node;
                return _buildNode(item);
              case final PveQemu item:
                lastType = PveResType.qemu;
                return _buildQemu(item);
              case final PveLxc item:
                lastType = PveResType.lxc;
                return _buildLxc(item);
              case final PveStorage item:
                lastType = PveResType.storage;
                return _buildStorage(item);
              case final PveSdn item:
                lastType = PveResType.sdn;
                return _buildSdn(item);
            }
          },
        );
      },
    );
  }

  Widget _buildQemu(PveQemu item) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        ListTile(
          title: Text(item.name),
          trailing: Text(item.topRight),
        ),
        if (item.isRunning) Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            _wrap(PercentCircle(percent: (item.cpu / item.maxcpu) * 100), 4),
            _wrap(PercentCircle(percent: (item.mem / item.maxmem) * 100), 4),
            _wrap(PercentCircle(percent: (item.disk / item.maxdisk) * 100), 4),
            _wrap(
                Column(
                  children: [
                    Text(
                      item.netin.bytes2Str,
                      style: const TextStyle(fontSize: 10, color: Colors.grey),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 3),
                    Text(
                      item.netout.bytes2Str,
                      style: const TextStyle(fontSize: 10, color: Colors.grey),
                      textAlign: TextAlign.center,
                    )
                  ],
                ),
                4),
          ],
        ),
        if (item.isRunning) UIs.height13,
      ],
    ).card;
  }

  Widget _buildLxc(PveLxc item) {
    return ListTile(
      title: Text(item.name),
      trailing: Text(item.status),
    ).card;
  }

  Widget _buildNode(PveNode item) {
    return ListTile(
      title: Text(item.node),
      trailing: Text(item.status),
    ).card;
  }

  Widget _buildStorage(PveStorage item) {
    return ListTile(
      title: Text(item.storage),
      trailing: Text(item.status),
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
}
