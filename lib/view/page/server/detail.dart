import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:toolbox/core/extension/context/common.dart';
import 'package:toolbox/core/extension/context/dialog.dart';
import 'package:toolbox/core/extension/context/locale.dart';
import 'package:toolbox/core/extension/order.dart';
import 'package:toolbox/core/extension/status_cmd_type.dart';
import 'package:toolbox/core/extension/widget.dart';
import 'package:toolbox/data/model/server/cpu.dart';
import 'package:toolbox/data/model/server/disk.dart';
import 'package:toolbox/data/model/server/net_speed.dart';
import 'package:toolbox/data/model/server/nvdia.dart';
import 'package:toolbox/data/model/server/server_private_info.dart';
import 'package:toolbox/data/model/server/system.dart';
import 'package:toolbox/data/res/store.dart';
import 'package:toolbox/view/widget/expand_tile.dart';
import 'package:toolbox/view/widget/server_func_btns.dart';

import '../../../core/extension/numx.dart';
import '../../../core/route.dart';
import '../../../data/model/server/server.dart';
import '../../../data/provider/server.dart';
import '../../../data/res/color.dart';
import '../../../data/res/default.dart';
import '../../../data/res/ui.dart';
import '../../widget/appbar.dart';
import '../../widget/cardx.dart';

class ServerDetailPage extends StatefulWidget {
  const ServerDetailPage({super.key, required this.spi});

  final ServerPrivateInfo spi;

  @override
  _ServerDetailPageState createState() => _ServerDetailPageState();
}

class _ServerDetailPageState extends State<ServerDetailPage>
    with SingleTickerProviderStateMixin {
  late MediaQueryData _media;
  final Order<String> _cardsOrder = [];

  late final _textFactor = TextScaler.linear(Stores.setting.textFactor.fetch());

  late final _cardBuildMap = Map.fromIterables(
    Defaults.detailCardOrder,
    [
      _buildUpTimeAndSys,
      _buildCPUView,
      _buildMemView,
      _buildSwapView,
      _buildGpuView,
      _buildDiskView,
      _buildNetView,
      _buildTemperature,
    ],
  );

  var _netSortType = _NetSortType.device;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _media = MediaQuery.of(context);
  }

  @override
  void initState() {
    super.initState();
    _cardsOrder.addAll(Stores.setting.detailCardOrder.fetch());
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<ServerProvider>(builder: (_, provider, __) {
      final s = widget.spi.server;
      if (s == null) {
        return Scaffold(
          body: Center(
            child: Text(l10n.noClient),
          ),
        );
      }
      return _buildMainPage(s);
    });
  }

  Widget _buildMainPage(Server si) {
    final buildFuncs = !Stores.setting.moveOutServerTabFuncBtns.fetch();
    return Scaffold(
      appBar: CustomAppBar(
        title: Text(si.spi.name, style: UIs.textSize18),
        actions: [
          IconButton(
            icon: const Icon(Icons.edit),
            onPressed: () async {
              final delete = await AppRoute.serverEdit(spi: si.spi).go(context);
              if (delete == true) {
                context.pop();
              }
            },
          )
        ],
      ),
      body: ListView.builder(
        padding: EdgeInsets.only(
          left: 13,
          right: 13,
          bottom: _media.padding.bottom + 77,
        ),
        itemCount: buildFuncs ? _cardsOrder.length + 1 : _cardsOrder.length,
        itemBuilder: (context, index) {
          if (index == 0 && buildFuncs) {
            return ServerFuncBtns(spi: widget.spi, iconSize: 19);
          }
          if (buildFuncs) index--;
          return _cardBuildMap[_cardsOrder[index]]?.call(si.status);
        },
      ),
    );
  }

  Widget _buildUpTimeAndSys(ServerStatus ss) {
    return CardX(
      child: ExpandTile(
        leading: const Icon(Icons.computer),
        initiallyExpanded: ss.more.entries.length < 7,
        title: Text(l10n.about),
        childrenPadding: const EdgeInsets.symmetric(
          horizontal: 17,
          vertical: 11,
        ),
        children: ss.more.entries
            .map(
              (e) => Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(e.key.i18n, style: UIs.textSize15),
                  Text(e.value, style: UIs.textSize13Grey)
                ],
              ).padding(const EdgeInsets.symmetric(vertical: 2)),
            )
            .toList(),
      ),
    );
  }

  Widget _buildCPUView(ServerStatus ss) {
    final percent = ss.cpu.usedPercent(coreIdx: 0).toInt();
    final details = [
      _buildDetailPercent(ss.cpu.user, 'user'),
      UIs.width13,
      _buildDetailPercent(ss.cpu.idle, 'idle')
    ];
    if (ss.system == SystemType.linux) {
      details.addAll([
        UIs.width13,
        _buildDetailPercent(ss.cpu.sys, 'sys'),
        UIs.width13,
        _buildDetailPercent(ss.cpu.iowait, 'io'),
      ]);
    }

    return CardX(
      child: ExpandTile(
        title: Align(
          alignment: Alignment.centerLeft,
          child: _buildAnimatedText(
            ValueKey(percent),
            '$percent%',
            UIs.textSize27,
          ),
        ),
        childrenPadding: const EdgeInsets.symmetric(vertical: 13),
        initiallyExpanded: ss.cpu.coresCount <= 8,
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: details,
        ),
        children: _buildCPUProgress(ss.cpu),
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
          style: UIs.text12,
          textScaler: _textFactor,
        ),
        Text(
          timeType,
          style: UIs.text12Grey,
          textScaler: _textFactor,
        ),
      ],
    );
  }

  List<Widget> _buildCPUProgress(Cpus cs) {
    final children = <Widget>[];
    for (var i = 0; i < cs.coresCount; i++) {
      if (i == 0) continue;
      children.add(
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 3, horizontal: 17),
          child: _buildProgress(cs.usedPercent(coreIdx: i)),
        ),
      );
    }
    return children;
  }

  Widget _buildProgress(double percent) {
    if (percent > 100) percent = 100;
    final percentWithinOne = percent / 100;
    return LinearProgressIndicator(
      value: percentWithinOne,
      minHeight: 7,
      backgroundColor: DynamicColors.progress.resolve(context),
      color: primaryColor,
    );
  }

  Widget _buildMemView(ServerStatus ss) {
    final free = ss.mem.free / ss.mem.total * 100;
    final avail = ss.mem.availPercent * 100;
    final used = ss.mem.usedPercent * 100;
    final usedStr = used.toStringAsFixed(0);

    return CardX(
      child: Padding(
        padding: UIs.roundRectCardPadding,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    _buildAnimatedText(
                      ValueKey(usedStr),
                      '$usedStr%',
                      UIs.textSize27,
                    ),
                    UIs.width7,
                    Text(
                      'of ${(ss.mem.total * 1024).convertBytes}',
                      style: UIs.textSize13Grey,
                    )
                  ],
                ),
                Row(
                  children: [
                    _buildDetailPercent(free, 'free'),
                    UIs.width13,
                    _buildDetailPercent(avail, 'avail'),
                  ],
                ),
              ],
            ),
            UIs.height13,
            _buildProgress(used)
          ],
        ),
      ),
    );
  }

  Widget _buildSwapView(ServerStatus ss) {
    if (ss.swap.total == 0) return UIs.placeholder;
    final used = ss.swap.usedPercent * 100;
    final cached = ss.swap.cached / ss.swap.total * 100;
    return CardX(
      child: Padding(
        padding: UIs.roundRectCardPadding,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Text('${used.toStringAsFixed(0)}%', style: UIs.textSize27),
                    UIs.width7,
                    Text(
                      'of ${(ss.swap.total * 1024).convertBytes} ',
                      style: UIs.textSize13Grey,
                    )
                  ],
                ),
                _buildDetailPercent(cached, 'cached'),
              ],
            ),
            UIs.height13,
            _buildProgress(used)
          ],
        ),
      ),
    );
  }

  Widget _buildGpuView(ServerStatus ss) {
    if (ss.nvidia == null) return UIs.placeholder;
    final children = ss.nvidia!.map((e) => _buildGpuItem(e)).toList();
    return CardX(
      child: ExpandTile(
        title: const Text('GPU'),
        leading: const Icon(Icons.memory, size: 17),
        initiallyExpanded: children.length <= 3,
        children: children,
      ),
    );
  }

  Widget _buildGpuItem(NvidiaSmiItem item) {
    final mem = item.memory;
    final processes = mem.processes;
    final children = <Widget>[];
    if (processes.isNotEmpty) {
      children.addAll(processes.map((e) => _buildGpuProcessItem(e)));
    }
    return ListTile(
      title: Text(item.name, style: UIs.textSize13),
      subtitle: Text(
        '${item.power} - ${item.temp} °C\n${mem.used} / ${mem.total} ${mem.unit} - ${item.fanSpeed} RPM',
        style: UIs.text12Grey,
        textScaler: _textFactor,
      ),
      contentPadding: const EdgeInsets.only(left: 17, right: 17),
      trailing: Row(
        mainAxisAlignment: MainAxisAlignment.end,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            '${item.percent}%',
            style: UIs.text12Grey,
            textScaler: _textFactor,
          ),
          IconButton(
            onPressed: () {
              final height = () {
                if (processes.length > 5) {
                  return 5 * 47.0;
                }
                return processes.length * 47.0;
              }();
              context.showRoundDialog(
                title: Text(item.name),
                child: SizedBox(
                  width: double.maxFinite,
                  height: height,
                  child: ListView.builder(
                    itemCount: processes.length,
                    itemBuilder: (_, idx) =>
                        _buildGpuProcessItem(processes[idx]),
                  ),
                ),
                actions: [
                  TextButton(
                    onPressed: () => context.pop(),
                    child: Text(l10n.close),
                  )
                ],
              );
            },
            icon: const Icon(Icons.info_outline, size: 17),
          ),
        ],
      ),
    );
  }

  Widget _buildGpuProcessItem(NvidiaSmiMemProcess process) {
    return ListTile(
      title: Text(
        process.name,
        style: UIs.text12,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        textScaler: _textFactor,
      ),
      subtitle: Text(
        'PID: ${process.pid} - ${process.memory} MiB',
        style: UIs.text12Grey,
        textScaler: _textFactor,
      ),
      trailing: const Icon(Icons.info_outline, size: 17).tap(
        onTap: () {
          context.showRoundDialog(
            title: SizedBox(
              width: 377,
              child: Text('${process.pid}', maxLines: 1),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                UIs.height13,
                Text('Memory: ${process.memory} MiB'),
                UIs.height13,
                Text('Process: ${process.name}')
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => context.pop(),
                child: Text(l10n.close),
              )
            ],
          );
        },
      ),
    );
  }

  Widget _buildDiskView(ServerStatus ss) {
    final disks = ss.disk;
    disks.removeWhere((e) {
      for (final ingorePath in Stores.setting.diskIgnorePath.fetch()) {
        if (e.dev.startsWith(ingorePath)) return true;
      }
      return false;
    });
    final children =
        List.generate(disks.length, (idx) => _buildDiskItem(disks[idx], ss));
    return CardX(
      child: ExpandTile(
        title: Text(l10n.disk),
        childrenPadding: const EdgeInsets.only(bottom: 7),
        leading: const Icon(Icons.storage, size: 17),
        initiallyExpanded: children.length <= 7,
        children: children,
      ),
    );
  }

  Widget _buildDiskItem(Disk disk, ServerStatus ss) {
    final (read, write) = ss.diskIO.getSpeed(disk.dev);
    final text = () {
      final use = '${disk.used} / ${disk.size}';
      if (read == null || write == null) return use;
      return '$use\n${l10n.read} $read | ${l10n.write} $write';
    }();
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              disk.dev,
              style: UIs.text12Bold,
              textScaler: _textFactor,
            ),
            Text(
              text,
              style: UIs.text12Grey,
              textScaler: _textFactor,
            )
          ],
        ),
        SizedBox(
          height: 41,
          width: 41,
          child: Stack(
            alignment: Alignment.center,
            children: [
              CircularProgressIndicator(
                value: disk.usedPercent / 100,
                strokeWidth: 5,
                backgroundColor: DynamicColors.progress.resolve(context),
                color: primaryColor,
              ),
              Text('${disk.usedPercent}%', style: UIs.textSize13Grey)
            ],
          ),
        )
      ],
    ).padding(const EdgeInsets.symmetric(horizontal: 17, vertical: 5));
  }

  Widget _buildNetView(ServerStatus ss) {
    final ns = ss.netSpeed;
    final children = <Widget>[];
    if (ns.devices.isEmpty) {
      children.add(Center(
        child: Text(
          l10n.noInterface,
          style: UIs.textSize13Grey,
        ),
      ));
    } else {
      final devices = ns.devices;
      devices.sort(_netSortType.getSortFunc(ns));
      children.addAll(devices.map((e) => _buildNetSpeedItem(ns, e)));
    }
    return CardX(
      child: ExpandTile(
        title: Row(
          children: [
            Text(l10n.net),
            UIs.width13,
            IconButton(
              onPressed: () {
                setState(() {
                  _netSortType = _netSortType.next;
                });
              },
              icon: AnimatedSwitcher(
                duration: const Duration(milliseconds: 377),
                transitionBuilder: (child, animation) => FadeTransition(
                  opacity: animation,
                  child: child,
                ),
                child: Row(
                  key: ValueKey(_netSortType),
                  children: [
                    const Icon(Icons.sort, size: 17),
                    UIs.width7,
                    Text(
                      _netSortType.name,
                      style: UIs.textSize13Grey,
                    ),
                  ],
                ),
              ),
            )
          ],
        ),
        childrenPadding: const EdgeInsets.only(bottom: 11),
        leading: const Icon(Icons.device_hub, size: 17),
        initiallyExpanded: children.length <= 7,
        children: children,
      ),
    );
  }

  Widget _buildNetSpeedItem(NetSpeed ns, String device) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 7, horizontal: 17),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                device,
                style: UIs.text12Bold,
                textScaler: _textFactor,
                maxLines: 1,
                overflow: TextOverflow.fade,
                textAlign: TextAlign.left,
              ),
              Text(
                '${ns.sizeIn(device: device)} | ${ns.sizeOut(device: device)}',
                style: UIs.text12Grey,
                textScaler: _textFactor,
              )
            ],
          ),
          SizedBox(
            width: 170,
            child: Text(
              '↑ ${ns.speedOut(device: device)}\n↓ ${ns.speedIn(device: device)}',
              textAlign: TextAlign.end,
              style: UIs.textSize13Grey,
            ),
          )
        ],
      ),
    );
  }

  Widget _buildTemperature(ServerStatus ss) {
    if (ss.temps.isEmpty) {
      return UIs.placeholder;
    }
    return CardX(
      child: ExpandTile(
        title: Text(l10n.temperature),
        leading: const Icon(Icons.ac_unit, size: 17),
        initiallyExpanded: ss.temps.devices.length <= 7,
        childrenPadding: const EdgeInsets.only(bottom: 7),
        children: ss.temps.devices
            .map((key) => _buildTemperatureItem(key, ss.temps.get(key)))
            .toList(),
      ),
    );
  }

  Widget _buildTemperatureItem(String key, double? val) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 17, vertical: 5),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(key, style: UIs.textSize15),
          Text('${val?.toStringAsFixed(1)}°C', style: UIs.textSize13Grey),
        ],
      ),
    );
  }

  Widget _buildAnimatedText(Key key, String text, TextStyle style) {
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 277),
      child: Text(
        key: key,
        text,
        style: style,
        textScaler: _textFactor,
      ),
      transitionBuilder: (child, animation) => FadeTransition(
        opacity: animation,
        child: child,
      ),
    );
  }
}

enum _NetSortType {
  device,
  trans,
  recv,
  ;

  bool get isDevice => this == _NetSortType.device;
  bool get isIn => this == _NetSortType.recv;
  bool get isOut => this == _NetSortType.trans;

  _NetSortType get next {
    switch (this) {
      case device:
        return trans;
      case _NetSortType.trans:
        return recv;
      case recv:
        return device;
    }
  }

  int Function(String, String) getSortFunc(NetSpeed ns) {
    switch (this) {
      case _NetSortType.device:
        return (b, a) => a.compareTo(b);
      case _NetSortType.recv:
        return (b, a) => ns
            .speedInBytes(ns.deviceIdx(a))
            .compareTo(ns.speedInBytes(ns.deviceIdx(b)));
      case _NetSortType.trans:
        return (b, a) => ns
            .speedOutBytes(ns.deviceIdx(a))
            .compareTo(ns.speedOutBytes(ns.deviceIdx(b)));
    }
  }
}
