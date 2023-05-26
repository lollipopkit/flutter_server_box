import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/l10n.dart';
import 'package:provider/provider.dart';
import 'package:toolbox/core/extension/order.dart';
import 'package:toolbox/data/model/server/cpu_status.dart';
import 'package:toolbox/data/model/server/disk_info.dart';
import 'package:toolbox/data/model/server/dist.dart';
import 'package:toolbox/data/model/server/memory.dart';
import 'package:toolbox/data/model/server/temp.dart';
import 'package:toolbox/data/res/misc.dart';

import '../../../core/extension/numx.dart';
import '../../../data/model/server/net_speed.dart';
import '../../../data/model/server/server.dart';
import '../../../data/model/server/server_status.dart';
import '../../../data/provider/server.dart';
import '../../../data/res/color.dart';
import '../../../data/res/ui.dart';
import '../../../data/store/setting.dart';
import '../../../locator.dart';
import '../../widget/round_rect_card.dart';

class ServerDetailPage extends StatefulWidget {
  const ServerDetailPage(this.id, {Key? key}) : super(key: key);

  final String id;

  @override
  _ServerDetailPageState createState() => _ServerDetailPageState();
}

class _ServerDetailPageState extends State<ServerDetailPage>
    with SingleTickerProviderStateMixin {
  late MediaQueryData _media;
  late S _s;
  late List<String> _cardsOrder;
  final _setting = locator<SettingStore>();

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _media = MediaQuery.of(context);
    _s = S.of(context)!;
  }

  @override
  void initState() {
    super.initState();
    _cardsOrder = _setting.detailCardOrder.fetch()!;
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<ServerProvider>(builder: (_, provider, __) {
      final s = provider.servers[widget.id];
      if (s == null) {
        return Scaffold(
          body: Center(
            child: Text(_s.noClient),
          ),
        );
      }
      return _buildMainPage(s);
    });
  }

  Widget _buildMainPage(Server si) {
    return Scaffold(
      appBar: AppBar(
        title: Text(si.spi.name, style: textSize18),
      ),
      body: ReorderableListView(
        padding: EdgeInsets.only(
            left: 13, right: 13, top: 13, bottom: _media.padding.bottom),
        onReorder: (int oldIndex, int newIndex) {
          setState(() {
            _cardsOrder.move(oldIndex, newIndex, _setting.detailCardOrder);
          });
        },
        header: _buildLinuxIcon(si.status.sysVer),
        footer: height13,
        children: _buildMainList(si.status),
      ),
    );
  }

  List<Widget> _buildMainList(ServerStatus ss) {
    final map = Map.fromIterables(
      defaultDetailCardOrder,
      [
        _buildUpTimeAndSys(ss.sysVer, ss.uptime),
        _buildCPUView(ss.cpu),
        _buildMemView(ss.mem),
        _buildSwapView(ss.swap),
        _buildDiskView(ss.disk),
        _buildNetView(ss.netSpeed),
        _buildTemperature(ss.temps),
      ],
    );
    return _cardsOrder
        .map((e) => SizedBox(key: ValueKey(e), child: map[e]))
        .toList();
  }

  Widget _buildLinuxIcon(String sysVer) {
    if (!_setting.showDistLogo.fetch()!) return placeholder;
    final iconPath = sysVer.dist?.iconPath;
    if (iconPath == null) return placeholder;
    return ConstrainedBox(
      constraints: BoxConstraints(
        maxHeight: _media.size.height * 0.13,
        maxWidth: _media.size.width * 0.6,
      ),
      child: Image.asset(
        iconPath,
        fit: BoxFit.contain,
      ),
    );
  }

  Widget _buildCPUView(CpuStatus cs) {
    return RoundRectCard(
      Padding(
        padding: roundRectCardPadding,
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '${cs.usedPercent(coreIdx: 0).toInt()}%',
                style: textSize27,
                textScaleFactor: 1.0,
              ),
              Row(
                children: [
                  _buildDetailPercent(cs.user, 'user'),
                  width13,
                  _buildDetailPercent(cs.sys, 'sys'),
                  width13,
                  _buildDetailPercent(cs.iowait, 'io'),
                  width13,
                  _buildDetailPercent(cs.idle, 'idle')
                ],
              )
            ],
          ),
          height13,
          _buildCPUProgress(cs)
        ]),
      ),
    );
  }

  Widget _buildDetailPercent(double percent, String timeType) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Text(
          '${percent.toStringAsFixed(1)}%',
          style: const TextStyle(fontSize: 13),
          textScaleFactor: 1.0,
        ),
        Text(
          timeType,
          style: const TextStyle(fontSize: 10, color: Colors.grey),
          textScaleFactor: 1.0,
        ),
      ],
    );
  }

  Widget _buildCPUProgress(CpuStatus cs) {
    final children = <Widget>[];
    for (var i = 0; i < cs.coresCount; i++) {
      if (i == 0) continue;
      children.add(
        Padding(
          padding: const EdgeInsets.all(2),
          child: _buildProgress(cs.usedPercent(coreIdx: i)),
        ),
      );
    }
    return Column(children: children);
  }

  Widget _buildProgress(double percent) {
    if (percent > 100) percent = 100;
    final percentWithinOne = percent / 100;
    return LinearProgressIndicator(
      value: percentWithinOne,
      minHeight: 7,
      backgroundColor: progressColor.resolve(context),
      color: primaryColor,
    );
  }

  Widget _buildUpTimeAndSys(String sysVer, String uptime) {
    return RoundRectCard(
      Padding(
        padding: roundRectCardPadding,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(sysVer, style: textSize11, textScaleFactor: 1.0),
            Text(
              uptime,
              style: textSize11,
              textScaleFactor: 1.0,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMemView(Memory mem) {
    final free = mem.free / mem.total * 100;
    final avail = mem.availPercent * 100;
    final used = mem.usedPercent * 100;

    return RoundRectCard(
      Padding(
        padding: roundRectCardPadding,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Text('${used.toStringAsFixed(0)}%', style: textSize27),
                    width7,
                    Text('of ${(mem.total * 1024).convertBytes}',
                        style: textSize13Grey)
                  ],
                ),
                Row(
                  children: [
                    _buildDetailPercent(free, 'free'),
                    width13,
                    _buildDetailPercent(avail, 'avail'),
                  ],
                ),
              ],
            ),
            height13,
            _buildProgress(used)
          ],
        ),
      ),
    );
  }

  Widget _buildSwapView(Swap swap) {
    if (swap.total == 0) return placeholder;
    final used = swap.usedPercent * 100;
    final cached = swap.cached / swap.total * 100;
    return RoundRectCard(
      Padding(
        padding: roundRectCardPadding,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Text('${used.toStringAsFixed(0)}%', style: textSize27),
                    width7,
                    Text('of ${(swap.total * 1024).convertBytes} ',
                        style: textSize13Grey)
                  ],
                ),
                _buildDetailPercent(cached, 'cached'),
              ],
            ),
            height13,
            _buildProgress(used)
          ],
        ),
      ),
    );
  }

  Widget _buildDiskView(List<DiskInfo> disk) {
    disk.removeWhere((e) {
      for (final ingorePath in _setting.diskIgnorePath.fetch()!) {
        if (e.path.startsWith(ingorePath)) return true;
      }
      return false;
    });
    final children = disk
        .map((disk) => Padding(
              padding: const EdgeInsets.symmetric(vertical: 3),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        '${disk.usedPercent}% of ${disk.size}',
                        style: textSize11,
                        textScaleFactor: 1.0,
                      ),
                      Text(disk.path, style: textSize11, textScaleFactor: 1.0)
                    ],
                  ),
                  _buildProgress(disk.usedPercent.toDouble())
                ],
              ),
            ))
        .toList();
    return RoundRectCard(
      Padding(
        padding: roundRectCardPadding,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: children,
        ),
      ),
    );
  }

  Widget _buildNetView(NetSpeed ns) {
    final children = <Widget>[
      _buildNetSpeedTop(),
      const Divider(
        height: 7,
      )
    ];
    if (ns.devices.isEmpty) {
      children.add(Center(
        child: Text(
          _s.noInterface,
          style: const TextStyle(color: Colors.grey, fontSize: 13),
        ),
      ));
    } else {
      children.addAll(ns.devices.map((e) => _buildNetSpeedItem(ns, e)));
    }

    return RoundRectCard(
      Padding(
        padding: roundRectCardPadding,
        child: Column(
          children: children,
        ),
      ),
    );
  }

  Widget _buildNetSpeedTop() {
    return const Padding(
      padding: EdgeInsets.only(bottom: 3),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Icon(Icons.device_hub, size: 17),
          Icon(Icons.arrow_downward, size: 17),
          Icon(Icons.arrow_upward, size: 17),
        ],
      ),
    );
  }

  Widget _buildNetSpeedItem(NetSpeed ns, String device) {
    final width = (_media.size.width - 34 - 34) / 2.9;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          SizedBox(
            width: width / 1.2,
            child: Text(
              device,
              style: textSize11,
              textScaleFactor: 1.0,
            ),
          ),
          SizedBox(
            width: width,
            child: Text(
              '${ns.speedIn(device: device)} | ${ns.totalIn(device: device)}',
              style: textSize11,
              textAlign: TextAlign.center,
              textScaleFactor: 0.87,
            ),
          ),
          SizedBox(
            width: width,
            child: Text(
              '${ns.speedOut(device: device)} | ${ns.totalOut(device: device)}',
              style: textSize11,
              textAlign: TextAlign.right,
              textScaleFactor: 0.87,
            ),
          )
        ],
      ),
    );
  }

  Widget _buildTemperature(Temperatures temps) {
    if (temps.isEmpty) {
      return placeholder;
    }
    final List<Widget> children = [
      const Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Icon(Icons.device_hub, size: 17),
          Icon(Icons.ac_unit, size: 17),
        ],
      ),
      const Padding(
        padding: EdgeInsets.symmetric(vertical: 3),
        child: Divider(height: 7),
      ),
    ];
    children.addAll(temps.devices.map((key) => Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              key,
              style: textSize11,
              textScaleFactor: 1.0,
            ),
            Text(
              '${temps.get(key)}°C',
              style: textSize11,
              textScaleFactor: 1.0,
            ),
          ],
        )));
    return RoundRectCard(Padding(
      padding: roundRectCardPadding,
      child: Column(children: children),
    ));
  }
}
