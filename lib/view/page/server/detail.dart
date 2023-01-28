import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:toolbox/core/extension/numx.dart';
import 'package:toolbox/data/model/server/dist.dart';
import 'package:toolbox/data/model/server/net_speed.dart';
import 'package:toolbox/data/model/server/server.dart';
import 'package:toolbox/data/model/server/server_status.dart';
import 'package:toolbox/data/provider/server.dart';
import 'package:toolbox/data/res/color.dart';
import 'package:toolbox/data/res/font_style.dart';
import 'package:toolbox/data/res/padding.dart';
import 'package:toolbox/data/store/setting.dart';
import 'package:toolbox/generated/l10n.dart';
import 'package:toolbox/locator.dart';
import 'package:toolbox/view/widget/round_rect_card.dart';

class ServerDetailPage extends StatefulWidget {
  const ServerDetailPage(this.id, {Key? key}) : super(key: key);

  final String id;

  @override
  _ServerDetailPageState createState() => _ServerDetailPageState();
}

const width13 = SizedBox(
  width: 13,
);

class _ServerDetailPageState extends State<ServerDetailPage>
    with SingleTickerProviderStateMixin {
  late MediaQueryData _media;
  late S _s;
  late Color pColor;
  bool _showDistLogo = true;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _media = MediaQuery.of(context);
    _s = S.of(context);
    _showDistLogo = locator<SettingStore>().showDistLogo.fetch()!;
    pColor = primaryColor;
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<ServerProvider>(builder: (_, provider, __) {
      return _buildMainPage(
        provider.servers.firstWhere(
          (e) => '${e.info.ip}:${e.info.port}' == widget.id,
        ),
      );
    });
  }

  Widget _buildMainPage(ServerInfo si) {
    return Scaffold(
      appBar: AppBar(
        title: Text(si.info.name, style: textSize18),
      ),
      body: ListView(
        padding: const EdgeInsets.all(13),
        children: [
          ...(_buildLinuxIcon(si.status.sysVer) ?? []),
          _buildUpTimeAndSys(si.status),
          _buildCPUView(si.status),
          _buildMemView(si.status),
          _buildDiskView(si.status),
          _buildNetView(si.status.netSpeed),
          // avoid the hieght of navigation bar
          SizedBox(height: _media.padding.bottom),
        ],
      ),
    );
  }

  List<Widget>? _buildLinuxIcon(String sysVer) {
    if (!_showDistLogo) return null;
    final iconPath = sysVer.dist?.iconPath;
    if (iconPath == null) return null;
    return [
      SizedBox(height: _media.size.height * 0.03),
      ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: _media.size.height * 0.13,
          maxWidth: _media.size.width * 0.6,
        ),
        child: Image.asset(
          iconPath,
          fit: BoxFit.contain,
        ),
      ),
      SizedBox(height: _media.size.height * 0.03),
    ];
  }

  Widget _buildCPUView(ServerStatus ss) {
    final tempWidget = ss.cpu2Status.temp.isEmpty
        ? const SizedBox()
        : Text(
            ss.cpu2Status.temp,
            style: textSize13Grey,
          );
    return RoundRectCard(
      Padding(
        padding: roundRectCardPadding,
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Text(
                    '${ss.cpu2Status.usedPercent(coreIdx: 0).toInt()}%',
                    style: textSize27,
                    textScaleFactor: 1.0,
                  ),
                  tempWidget
                ],
              ),
              Row(
                children: [
                  _buildDetailPercent(ss.cpu2Status.user, 'user'),
                  width13,
                  _buildDetailPercent(ss.cpu2Status.sys, 'sys'),
                  width13,
                  _buildDetailPercent(ss.cpu2Status.iowait, 'io'),
                  width13,
                  _buildDetailPercent(ss.cpu2Status.idle, 'idle')
                ],
              )
            ],
          ),
          _buildCPUProgress(ss)
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

  Widget _buildCPUProgress(ServerStatus ss) {
    return SizedBox(
      height: 12.0 * ss.cpu2Status.coresCount,
      child: ListView.builder(
        physics: const NeverScrollableScrollPhysics(),
        padding: const EdgeInsets.only(top: 13),
        itemBuilder: (ctx, idx) {
          if (idx == 0) return const SizedBox();
          return Padding(
            padding: const EdgeInsets.all(2),
            child: _buildProgress(ss.cpu2Status.usedPercent(coreIdx: idx)),
          );
        },
        itemCount: ss.cpu2Status.coresCount,
      ),
    );
  }

  Widget _buildProgress(double percent) {
    if (percent > 100) percent = 100;
    final percentWithinOne = percent / 100;
    return LinearProgressIndicator(
      value: percentWithinOne,
      minHeight: 7,
      backgroundColor: progressColor.resolve(context),
      color: pColor,
    );
  }

  Widget _buildUpTimeAndSys(ServerStatus ss) {
    return RoundRectCard(Padding(
      padding: roundRectCardPadding,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(ss.sysVer, style: textSize11, textScaleFactor: 1.0),
          Text(
            ss.uptime,
            style: textSize11,
            textScaleFactor: 1.0,
          ),
        ],
      ),
    ));
  }

  Widget _buildMemView(ServerStatus ss) {
    final used = ss.memory.used / ss.memory.total * 100;
    final free = ss.memory.free / ss.memory.total * 100;
    final avail = ss.memory.avail / ss.memory.total * 100;

    return RoundRectCard(Padding(
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
                  const SizedBox(width: 7),
                  Text('of ${(ss.memory.total * 1024).convertBytes}',
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
          const SizedBox(
            height: 11,
          ),
          _buildProgress(used)
        ],
      ),
    ));
  }

  Widget _buildDiskView(ServerStatus ss) {
    final clone = ss.disk.toList();
    for (var item in ss.disk) {
      if (ignorePath.any((ele) => item.mountLocation.contains(ele))) {
        clone.remove(item);
      }
    }
    final children = clone
        .map((disk) => Padding(
              padding: const EdgeInsets.all(3),
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
                      Text(disk.mountPath,
                          style: textSize11, textScaleFactor: 1.0)
                    ],
                  ),
                  _buildProgress(disk.usedPercent.toDouble())
                ],
              ),
            ))
        .toList();
    return RoundRectCard(Padding(
      padding: roundRectCardPadding,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: children,
      ),
    ));
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

    return RoundRectCard(Padding(
      padding: roundRectCardPadding,
      child: Column(
        children: children,
      ),
    ));
  }

  Widget _buildNetSpeedTop() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: const [
          Icon(
            Icons.device_hub,
            size: 17,
          ),
          Icon(Icons.arrow_downward, size: 17),
          Icon(Icons.arrow_upward, size: 17),
        ],
      ),
    );
  }

  Widget _buildNetSpeedItem(NetSpeed ns, String device) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          SizedBox(
              width: _media.size.width / 4,
              child: Text(device, style: textSize11, textScaleFactor: 1.0)),
          SizedBox(
            width: _media.size.width / 4,
            child: Text(ns.speedIn(device: device),
                style: textSize11,
                textAlign: TextAlign.center,
                textScaleFactor: 1.0),
          ),
          SizedBox(
            width: _media.size.width / 4,
            child: Text(ns.speedOut(device: device),
                style: textSize11,
                textAlign: TextAlign.right,
                textScaleFactor: 1.0),
          )
        ],
      ),
    );
  }

  static const ignorePath = [
    '/run',
    '/sys',
    '/dev/shm',
    '/snap',
    '/var/lib/docker',
    '/dev/tty'
  ];
}
