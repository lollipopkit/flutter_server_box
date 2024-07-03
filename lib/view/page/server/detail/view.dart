import 'package:extended_image/extended_image.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:fl_lib/fl_lib.dart';
import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:icons_plus/icons_plus.dart';
import 'package:provider/provider.dart';
import 'package:server_box/core/extension/context/locale.dart';
import 'package:server_box/data/model/app/server_detail_card.dart';
import 'package:server_box/data/model/app/shell_func.dart';
import 'package:server_box/data/model/server/battery.dart';
import 'package:server_box/data/model/server/cpu.dart';
import 'package:server_box/data/model/server/disk.dart';
import 'package:server_box/data/model/server/dist.dart';
import 'package:server_box/data/model/server/net_speed.dart';
import 'package:server_box/data/model/server/nvdia.dart';
import 'package:server_box/data/model/server/sensors.dart';
import 'package:server_box/data/model/server/server_private_info.dart';
import 'package:server_box/data/model/server/system.dart';
import 'package:server_box/data/res/store.dart';
import 'package:server_box/view/widget/server_func_btns.dart';

import '../../../../core/route.dart';
import '../../../../data/model/server/server.dart';
import '../../../../data/provider/server.dart';

part 'misc.dart';

class ServerDetailPage extends StatefulWidget {
  const ServerDetailPage({super.key, required this.spi});

  final ServerPrivateInfo spi;

  @override
  State<ServerDetailPage> createState() => _ServerDetailPageState();
}

class _ServerDetailPageState extends State<ServerDetailPage>
    with SingleTickerProviderStateMixin {
  late final _cardBuildMap = Map.fromIterables(
    ServerDetailCards.names,
    [
      _buildAbout,
      _buildCPUView,
      _buildMemView,
      _buildSwapView,
      _buildGpuView,
      _buildDiskView,
      _buildNetView,
      _buildSensors,
      _buildTemperature,
      _buildBatteries,
      _buildPve,
      _buildCustom,
    ],
  );

  late MediaQueryData _media;
  final List<String> _cardsOrder = [];

  final _netSortType = ValueNotifier(_NetSortType.device);
  late final _collapse = Stores.setting.collapseUIDefault.fetch();
  late final _textFactor = TextScaler.linear(Stores.setting.textFactor.fetch());

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _media = MediaQuery.of(context);
  }

  @override
  void initState() {
    super.initState();
    final order = Stores.setting.detailCardOrder.fetch();
    order.removeWhere((e) => !ServerDetailCards.names.contains(e));
    _cardsOrder.addAll(order);
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<ServerProvider>(builder: (_, provider, __) {
      final s = widget.spi.server;
      if (s == null) {
        return Scaffold(
          appBar: const CustomAppBar(),
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
    final logoUrl = si.spi.custom?.logoUrl ??
        Stores.setting.serverLogoUrl.fetch().selfIfNotNullEmpty;
    final buildLogo = logoUrl != null;
    final children = [
      if (buildLogo)
        _buildLogo(logoUrl, si.status.more[StatusCmdType.sys]?.dist),
      if (buildFuncs) ServerFuncBtns(spi: widget.spi),
    ];
    for (final card in _cardsOrder) {
      final buildFunc = _cardBuildMap[card];
      if (buildFunc != null) {
        children.add(buildFunc(si.status));
      }
    }
    return Scaffold(
      appBar: _buildAppBar(si),
      body: ListView(
        padding: EdgeInsets.only(
          left: 13,
          right: 13,
          bottom: _media.padding.bottom + 77,
        ),
        children: children,
      ),
    );
  }

  CustomAppBar _buildAppBar(Server si) {
    return CustomAppBar(
      title: Text(si.spi.name, style: UIs.text18),
      actions: [
        IconButton(
          icon: const Icon(Icons.edit),
          onPressed: () async {
            final delete = await AppRoutes.serverEdit(spi: si.spi).go(context);
            if (delete == true) {
              context.pop();
            }
          },
        )
      ],
    );
  }

  Widget _buildLogo(String logoUrl, Dist? dist) {
    if (dist != null) {
      logoUrl = logoUrl
          .replaceFirst('{DIST}', dist.name)
          .replaceFirst('{BRIGHT}', context.isDark ? 'dark' : 'light');
    }
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 13),
      child: ExtendedImage.network(
        logoUrl,
        cache: true,
        height: _media.size.height * 0.2,
      ),
    );
  }

  Widget _buildAbout(ServerStatus ss) {
    return CardX(
      child: ExpandTile(
        leading: const Icon(MingCute.information_fill, size: 20),
        initiallyExpanded: _getInitExpand(ss.more.entries.length),
        title: Text(l10n.about),
        childrenPadding: const EdgeInsets.symmetric(
          horizontal: 17,
          vertical: 11,
        ),
        children: ss.more.entries
            .map(
              (e) => Padding(
                padding: const EdgeInsets.symmetric(vertical: 2),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(e.key.i18n, style: UIs.text13),
                    Text(e.value, style: UIs.text13Grey)
                  ],
                ),
              ),
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
            UIs.text27,
          ),
        ),
        childrenPadding: const EdgeInsets.symmetric(vertical: 13),
        initiallyExpanded: _getInitExpand(1),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: details,
        ),
        children: Stores.setting.cpuViewAsProgress.fetch()
            ? _buildCPUProgress(ss.cpu)
            : [
                Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 17, vertical: 13),
                  child: SizedBox(
                    height: 137,
                    width: _media.size.width - 26 - 34,
                    child: _buildLineChart(
                      ss.cpu.spots,
                      //ss.cpu.rangeX,
                      tooltipPrefix: 'CPU',
                    ),
                  ),
                ),
              ],
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
    const kMaxColumn = 2;
    const kRowThreshold = 4;
    const kCoresCount = kMaxColumn * kRowThreshold;
    final children = <Widget>[];

    if (cs.coresCount > kCoresCount) {
      final rows = cs.coresCount ~/ kMaxColumn;
      for (var i = 0; i < rows; i++) {
        final rowChildren = <Widget>[];
        for (var j = 0; j < kMaxColumn; j++) {
          final idx = i * kMaxColumn + j + 1;
          if (idx >= cs.coresCount) break;
          if (Stores.setting.displayCpuIndex.fetch()) {
            rowChildren.add(Text('$idx', style: UIs.text13Grey));
          }
          rowChildren.add(
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 3),
                child: _buildProgress(cs.usedPercent(coreIdx: idx)),
              ),
            ),
          );
        }
        rowChildren.joinWith(UIs.width7);
        children.add(
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 17),
            child: Row(
              children: rowChildren,
            ),
          ),
        );
      }
    } else {
      for (var i = 0; i < cs.coresCount; i++) {
        if (i == 0) continue;
        children.add(
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 3, horizontal: 17),
            child: _buildProgress(cs.usedPercent(coreIdx: i)),
          ),
        );
      }
    }

    return children;
  }

  Widget _buildProgress(double percent) {
    if (percent > 100) percent = 100;
    final percentWithinOne = percent / 100;
    return LinearProgressIndicator(
      value: percentWithinOne,
      minHeight: 7,
      backgroundColor: UIs.halfAlpha,
      color: UIs.primaryColor,
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
                      UIs.text27,
                    ),
                    UIs.width7,
                    Text(
                      'of ${(ss.mem.total * 1024).bytes2Str}',
                      style: UIs.text13Grey,
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
                    Text('${used.toStringAsFixed(0)}%', style: UIs.text27),
                    UIs.width7,
                    Text(
                      'of ${(ss.swap.total * 1024).bytes2Str} ',
                      style: UIs.text13Grey,
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
    if (ss.nvidia == null || ss.nvidia?.isEmpty == true) return UIs.placeholder;
    final children = ss.nvidia?.map((e) => _buildGpuItem(e)).toList() ?? [];
    return CardX(
      child: ExpandTile(
        title: const Text('GPU'),
        leading: const Icon(Icons.memory, size: 17),
        initiallyExpanded: _getInitExpand(children.length, 3),
        children: children,
      ),
    );
  }

  Widget _buildGpuItem(NvidiaSmiItem item) {
    final mem = item.memory;
    final processes = mem.processes;
    return ListTile(
      title: Text(item.name, style: UIs.text13),
      leading: Text(
        '${item.percent}%\n${item.temp} °C',
        style: UIs.text12Grey,
        textScaler: _textFactor,
        textAlign: TextAlign.center,
      ),
      subtitle: Text(
        '${item.power} - FAN ${item.fanSpeed}%\n${mem.used} / ${mem.total} ${mem.unit}',
        style: UIs.text12Grey,
        textScaler: _textFactor,
      ),
      contentPadding: const EdgeInsets.only(left: 17, right: 17),
      trailing: Row(
        mainAxisAlignment: MainAxisAlignment.end,
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            onPressed: () {
              final height = () {
                if (processes.length > 5) {
                  return 5 * 47.0;
                }
                return processes.length * 47.0;
              }();
              context.showRoundDialog(
                title: item.name,
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
      trailing: InkWell(
        onTap: () {
          context.showRoundDialog(
            title: '${process.pid}',
            titleMaxLines: 1,
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
        child: const Icon(Icons.info_outline, size: 17),
      ),
    );
  }

  Widget _buildDiskView(ServerStatus ss) {
    final children = List.generate(
        ss.disk.length, (idx) => _buildDiskItem(ss.disk[idx], ss));
    return CardX(
      child: ExpandTile(
        title: Text(l10n.disk),
        childrenPadding: const EdgeInsets.only(bottom: 7),
        leading: Icon(ServerDetailCards.disk.icon, size: 17),
        initiallyExpanded: _getInitExpand(children.length),
        children: children,
      ),
    );
  }

  Widget _buildDiskItem(Disk disk, ServerStatus ss) {
    final (read, write) = ss.diskIO.getSpeed(disk.fs);
    final text = () {
      final use = '${l10n.used} ${disk.used.kb2Str} / ${disk.size.kb2Str}';
      if (read == null || write == null) return use;
      return '$use\n${l10n.read} $read | ${l10n.write} $write';
    }();
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 17, vertical: 5),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                disk.fs,
                style: UIs.text12,
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
                  backgroundColor: UIs.halfAlpha,
                  color: UIs.primaryColor,
                ),
                Text('${disk.usedPercent}%', style: UIs.text12Grey)
              ],
            ),
          )
        ],
      ),
    );
  }

  Widget _buildNetView(ServerStatus ss) {
    final ns = ss.netSpeed;
    final children = <Widget>[];
    if (ns.devices.isEmpty) {
      children.add(Center(
        child: Text(
          l10n.noInterface,
          style: UIs.text13Grey,
        ),
      ));
    } else {
      final devices = ns.devices;
      devices.sort(_netSortType.value.getSortFunc(ns));
      children.addAll(devices.map((e) => _buildNetSpeedItem(ns, e)));
    }
    return CardX(
      child: ExpandTile(
        leading: Icon(ServerDetailCards.net.icon, size: 17),
        title: Row(
          children: [
            Text(l10n.net),
            UIs.width13,
            ValBuilder(
              listenable: _netSortType,
              builder: (val) => InkWell(
                onTap: () => _netSortType.value = val.next,
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 377),
                  transitionBuilder: (child, animation) => FadeTransition(
                    opacity: animation,
                    child: child,
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.sort, size: 17),
                      UIs.width7,
                      Text(
                        val.name,
                        style: UIs.text13Grey,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
        childrenPadding: const EdgeInsets.only(bottom: 11),
        initiallyExpanded: _getInitExpand(children.length),
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
                style: UIs.text12,
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
              '${ns.speedOut(device: device)} ↑\n${ns.speedIn(device: device)} ↓',
              textAlign: TextAlign.end,
              style: UIs.text13Grey,
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
        initiallyExpanded: _getInitExpand(ss.temps.devices.length),
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
          Text(key, style: UIs.text15),
          Text('${val?.toStringAsFixed(1)}°C', style: UIs.text13Grey),
        ],
      ),
    );
  }

  Widget _buildBatteries(ServerStatus ss) {
    if (ss.batteries.isEmpty) {
      return UIs.placeholder;
    }
    return CardX(
      child: ExpandTile(
        title: Text(l10n.battery),
        leading: const Icon(Icons.battery_charging_full, size: 17),
        childrenPadding: const EdgeInsets.only(bottom: 7),
        initiallyExpanded: _getInitExpand(ss.batteries.length, 2),
        children: ss.batteries.map(_buildBatteryItem).toList(),
      ),
    );
  }

  Widget _buildBatteryItem(Battery battery) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 17, vertical: 5),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('${battery.name}', style: UIs.text15),
              Text(
                '${battery.status.name} - ${battery.cycle}',
                style: UIs.text13Grey,
              ),
            ],
          ),
          Text(
            '${battery.percent?.toStringAsFixed(0)}%',
            style: UIs.text13Grey,
          ),
        ],
      ),
    );
  }

  Widget _buildSensors(ServerStatus ss) {
    if (ss.sensors.isEmpty) return UIs.placeholder;
    return CardX(
      child: ExpandTile(
        title: Text(l10n.sensors),
        leading: const Icon(Icons.thermostat, size: 17),
        childrenPadding: const EdgeInsets.only(bottom: 7),
        initiallyExpanded: _getInitExpand(ss.sensors.length, 2),
        children: ss.sensors.map(_buildSensorItem).toList(),
      ),
    );
  }

  Widget _buildSensorItem(SensorItem si) {
    if (si.summary == null) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 17, vertical: 7),
        child: Text(si.device),
      );
    }
    return InkWell(
      onTap: () {
        context.showRoundDialog(
          title: si.device,
          child: SingleChildScrollView(
            child: SimpleMarkdown(
              data: si.toMarkdown,
              styleSheet: MarkdownStyleSheet(
                tableBorder: TableBorder.all(color: Colors.grey),
                tableHead: const TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
          ),
        );
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 17, vertical: 7),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Expanded(
                child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    Text(si.device, style: UIs.text15Bold),
                    UIs.width7,
                    Text('(${si.adapter.raw})', style: UIs.text13Grey),
                  ],
                ),
                Text(si.summary ?? '', style: UIs.text13Grey),
              ],
            )),
            UIs.width7,
            const Icon(Icons.keyboard_arrow_right, color: Colors.grey),
          ],
        ),
      ),
    );
  }

  Widget _buildPve(_) {
    final addr = widget.spi.custom?.pveAddr;
    if (addr == null) return UIs.placeholder;
    return CardX(
      child: ListTile(
        title: const Text('PVE'),
        leading: const Icon(FontAwesome.server_solid, size: 17),
        trailing: const Icon(Icons.chevron_right),
        onTap: () => AppRoutes.pve(spi: widget.spi).go(context),
      ),
    );
  }

  Widget _buildCustom(ServerStatus ss) {
    if (ss.customCmds.isEmpty) return UIs.placeholder;
    return CardX(
      child: ExpandTile(
        leading: const Icon(MingCute.command_line, size: 17),
        title: Text(l10n.customCmd),
        initiallyExpanded: _getInitExpand(ss.customCmds.length),
        children: ss.customCmds.entries.map(_buildCustomItem).toList(),
      ),
    );
  }

  Widget _buildCustomItem(MapEntry<String, String> cmd) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 17, vertical: 7),
      child: KvRow(
        k: cmd.key,
        v: cmd.value,
        vBuilder: () {
          if (!cmd.value.contains('\n')) return null;
          return GestureDetector(
            onTap: () {
              context.showRoundDialog(
                title: cmd.key,
                child: SingleChildScrollView(
                  child: Text(cmd.value, style: UIs.text13Grey),
                ),
                actions: [
                  TextButton(
                    onPressed: () => context.pop(),
                    child: Text(l10n.close),
                  ),
                ],
              );
            },
            child: const Icon(
              Icons.info_outline,
              size: 17,
              color: Colors.grey,
            ),
          );
        },
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

  bool _getInitExpand(int len, [int? max]) {
    if (!_collapse) return true;
    return len <= (max ?? 3);
  }
}
