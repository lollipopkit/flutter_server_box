import 'package:extended_image/extended_image.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:fl_lib/fl_lib.dart';
import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:icons_plus/icons_plus.dart';
import 'package:server_box/core/extension/context/locale.dart';
import 'package:server_box/core/route.dart';
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
import 'package:server_box/view/page/pve.dart';
import 'package:server_box/view/page/server/edit.dart';
import 'package:server_box/view/widget/server_func_btns.dart';
import 'package:server_box/data/model/server/server.dart';

part 'misc.dart';

class ServerDetailPage extends StatefulWidget {
  final SpiRequiredArgs args;
  const ServerDetailPage({super.key, required this.args});

  @override
  State<ServerDetailPage> createState() => _ServerDetailPageState();

  static const route = AppRouteArg(
    page: ServerDetailPage.new,
    path: '/servers/detail',
  );
}

class _ServerDetailPageState extends State<ServerDetailPage> with SingleTickerProviderStateMixin {
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
      _buildCustomCmd,
    ],
  );

  late MediaQueryData _media;
  final List<String> _cardsOrder = [];

  final _settings = Stores.setting;
  final _netSortType = ValueNotifier(_NetSortType.device);
  late final _collapse = _settings.collapseUIDefault.fetch();
  late final _textFactor = TextScaler.linear(_settings.textFactor.fetch());

  @override
  void dispose() {
    super.dispose();
    _netSortType.dispose();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _media = MediaQuery.of(context);
  }

  @override
  void initState() {
    super.initState();
    final order = _settings.detailCardOrder.fetch();
    order.removeWhere((e) => !ServerDetailCards.names.contains(e));
    _cardsOrder.addAll(order);
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.args.spi.server;
    if (s == null) {
      return Scaffold(
        appBar: CustomAppBar(),
        body: Center(child: Text(libL10n.empty)),
      );
    }
    return s.listenVal(_buildMainPage);
  }

  Widget _buildMainPage(Server si) {
    final buildFuncs = !Stores.setting.moveServerFuncs.fetch();
    final logo = _buildLogo(si);
    final children = [
      logo,
      if (buildFuncs) ServerFuncBtns(spi: si.spi),
    ];
    for (final card in _cardsOrder) {
      final buildFunc = _cardBuildMap[card];
      if (buildFunc != null) {
        children.add(buildFunc(si));
      }
    }

    return Scaffold(
      appBar: _buildAppBar(si),
      body: AutoMultiList(
        children: children,
      ),
    );
  }

  CustomAppBar _buildAppBar(Server si) {
    return CustomAppBar(
      title: Text(
        si.spi.name,
        style: TextStyle(
          fontSize: 20,
          color: context.isDark ? Colors.white : Colors.black,
        ),
      ),
      actions: [
        QrShareBtn(
          data: si.spi.toJsonString(),
          tip: si.spi.name,
          tip2: '${l10n.server} ~ ServerBox',
        ),
        IconButton(
          icon: const Icon(Icons.edit),
          onPressed: () async {
            final delete = await ServerEditPage.route.go(
              context,
              args: SpiRequiredArgs(si.spi),
            );
            if (delete == true) {
              context.pop();
            }
          },
        )
      ],
    );
  }

  Widget _buildLogo(Server si) {
    var logoUrl = si.spi.custom?.logoUrl ?? _settings.serverLogoUrl.fetch().selfNotEmptyOrNull;
    if (logoUrl == null) return UIs.placeholder;

    final dist = si.status.more[StatusCmdType.sys]?.dist;
    if (dist != null) {
      logoUrl = logoUrl.replaceFirst('{DIST}', dist.name);
    }
    logoUrl = logoUrl.replaceFirst('{BRIGHT}', context.isDark ? 'dark' : 'light');

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 13),
      child: ExtendedImage.network(
        logoUrl,
        cache: true,
        height: _media.size.height * 0.2,
      ),
    );
  }

  Widget _buildAbout(Server si) {
    final ss = si.status;
    return ExpandTile(
      key: ValueKey(ss.more.hashCode), // Use hashCode to avoid perf issue
      leading: const Icon(MingCute.information_fill, size: 20),
      initiallyExpanded: _getInitExpand(ss.more.entries.length),
      title: Text(libL10n.about),
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
                  Text(
                    e.key.i18n,
                    style: UIs.text13,
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text(
                    e.value,
                    style: UIs.text13Grey,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          )
          .toList(),
    ).cardx;
  }

  Widget _buildCPUView(Server si) {
    final ss = si.status;
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

    final List<Widget> children = Stores.setting.cpuViewAsProgress.fetch()
        ? _buildCPUProgress(ss.cpu)
        : [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 17, vertical: 13),
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
          ];

    if (ss.cpu.brand.isNotEmpty) {
      children.add(Column(
        children: ss.cpu.brand.entries.map(_buildCpuModelItem).toList(),
      ).paddingOnly(top: 13));
    }

    return ExpandTile(
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
      children: children,
    ).cardx;
  }

  Widget _buildCpuModelItem(MapEntry<String, int> e) {
    final name =
        e.key.replaceFirst('Intel(R)', '').replaceFirst('AMD', '').replaceFirst('with Radeon Graphics', '');
    final child = Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        ConstrainedBox(
          constraints: BoxConstraints(
            maxWidth: _media.size.width * .7,
          ),
          child: Text(
            name,
            style: UIs.text13,
            overflow: TextOverflow.ellipsis,
            maxLines: 1,
          ),
        ),
        Text('x ${e.value}', style: UIs.text13Grey, overflow: TextOverflow.clip),
      ],
    );
    return child.paddingSymmetric(horizontal: 17);
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
    const kCoresCountThreshold = kMaxColumn * kRowThreshold;
    final children = <Widget>[];
    final displayCpuIndexSetting = Stores.setting.displayCpuIndex.fetch();

    if (cs.coresCount > kCoresCountThreshold) {
      final numCoresToDisplay = cs.coresCount - 1;
      final numRows = (numCoresToDisplay + kMaxColumn - 1) ~/ kMaxColumn;

      for (var i = 0; i < numRows; i++) {
        final rowChildren = <Widget>[];
        for (var j = 0; j < kMaxColumn; j++) {
          final coreListIndex = i * kMaxColumn + j;
          if (coreListIndex >= numCoresToDisplay) break;

          final coreNumberOneBased = coreListIndex + 1;

          if (displayCpuIndexSetting) {
            rowChildren.add(Text('$coreNumberOneBased', style: UIs.text13Grey));
          }
          rowChildren.add(
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 3),
                child: _buildProgress(cs.usedPercent(coreIdx: coreNumberOneBased)),
              ),
            ),
          );
        }
        if (rowChildren.isNotEmpty) {
          children.add(
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 17),
              child: Row(
                children: rowChildren.joinWith(UIs.width7).toList(),
              ),
            ),
          );
        }
      }
    } else {
      for (var i = 1; i < cs.coresCount; i++) {
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

  Widget _buildMemView(Server si) {
    final ss = si.status;
    final free = ss.mem.free / ss.mem.total * 100;
    final avail = ss.mem.availPercent * 100;
    final used = ss.mem.usedPercent * 100;
    final usedStr = used.toStringAsFixed(0);

    final percentW = Row(
      children: [
        _buildAnimatedText(ValueKey(usedStr), '$usedStr%', UIs.text27),
        UIs.width7,
        Text(
          'of ${(ss.mem.total * 1024).bytes2Str}',
          style: UIs.text13Grey,
        )
      ],
    );

    return Padding(
      padding: UIs.roundRectCardPadding,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              percentW,
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
    ).cardx;
  }

  Widget _buildSwapView(Server si) {
    final ss = si.status;
    if (ss.swap.total == 0) return UIs.placeholder;
    final used = ss.swap.usedPercent * 100;
    final cached = ss.swap.cached / ss.swap.total * 100;

    final percentW = Row(
      children: [
        Text('${used.toStringAsFixed(0)}%', style: UIs.text27),
        UIs.width7,
        Text(
          'of ${(ss.swap.total * 1024).bytes2Str} ',
          style: UIs.text13Grey,
        )
      ],
    );

    return Padding(
      padding: UIs.roundRectCardPadding,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              percentW,
              _buildDetailPercent(cached, 'cached'),
            ],
          ),
          UIs.height13,
          _buildProgress(used)
        ],
      ),
    ).cardx;
  }

  Widget _buildGpuView(Server si) {
    final ss = si.status;
    if (ss.nvidia == null || ss.nvidia?.isEmpty == true) return UIs.placeholder;
    final children = ss.nvidia?.map((e) => _buildGpuItem(e)).toList() ?? [];
    return ExpandTile(
      title: const Text('GPU'),
      leading: const Icon(Icons.memory, size: 17),
      initiallyExpanded: _getInitExpand(children.length, 3),
      children: children,
    ).cardx;
  }

  Widget _buildGpuItem(NvidiaSmiItem item) {
    final mem = item.memory;
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
            onPressed: () => _onTapGpuItem(item),
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
        onTap: () => _nTapGpuProcessItem(process),
        child: const Icon(Icons.info_outline, size: 17),
      ),
    );
  }

  Widget _buildDiskView(Server si) {
    final ss = si.status;
    final children = <Widget>[];

    // Create widgets for each top-level disk
    for (int idx = 0; idx < ss.disk.length; idx++) {
      final disk = ss.disk[idx];
      children.add(_buildDiskItemWithHierarchy(disk, ss, 0));
    }

    if (children.isEmpty) return UIs.placeholder;

    return ExpandTile(
      title: Text(l10n.disk),
      childrenPadding: const EdgeInsets.only(bottom: 7),
      leading: Icon(ServerDetailCards.disk.icon, size: 17),
      initiallyExpanded: _getInitExpand(children.length),
      children: children,
    ).cardx;
  }

  Widget _buildDiskItemWithHierarchy(Disk disk, ServerStatus ss, int depth) {
    // Create a list to hold this disk and its children
    final items = <Widget>[];

    // Add the current disk
    items.add(_buildDiskItem(disk, ss, depth));

    // Recursively add child disks with increased indentation
    if (disk.children.isNotEmpty) {
      for (final childDisk in disk.children) {
        items.add(_buildDiskItemWithHierarchy(childDisk, ss, depth + 1));
      }
    }

    return Column(children: items);
  }

  Widget _buildDiskItem(Disk disk, ServerStatus ss, int depth) {
    final (read, write) = ss.diskIO.getSpeed(disk.path);
    final text = () {
      final use = '${l10n.used} ${disk.used.kb2Str} / ${disk.size.kb2Str}';
      if (read == null || write == null) return use;
      return '$use\n${l10n.read} $read | ${l10n.write} $write';
    }();

    return Padding(
      padding: EdgeInsets.only(
        left: 17.0 + (depth * 15.0), // Indent based on depth
        right: 17.0,
        top: 5.0,
        bottom: 5.0,
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  disk.mount.isEmpty ? disk.path : '${disk.path} (${disk.mount})',
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
          ),
          if (disk.size > BigInt.zero)
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

  Widget _buildNetView(Server si) {
    final ss = si.status;
    final ns = ss.netSpeed;
    final children = <Widget>[];
    final devices = ns.devices;
    if (devices.isEmpty) return UIs.placeholder;

    devices.sort(_netSortType.value.getSortFunc(ns));
    children.addAll(devices.map((e) => _buildNetSpeedItem(ns, e)));

    return ExpandTile(
      leading: Icon(ServerDetailCards.net.icon, size: 17),
      title: Row(
        children: [
          Text(l10n.net),
          UIs.width13,
          _netSortType.listenVal(
            (val) => InkWell(
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
    ).cardx;
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

  Widget _buildTemperature(Server si) {
    final ss = si.status;
    if (ss.temps.isEmpty) {
      return UIs.placeholder;
    }
    return CardX(
      child: ExpandTile(
        title: Text(l10n.temperature),
        leading: const Icon(Icons.ac_unit, size: 20),
        initiallyExpanded: _getInitExpand(ss.temps.devices.length),
        childrenPadding: const EdgeInsets.only(bottom: 7),
        children: ss.temps.devices.map((key) => _buildTemperatureItem(key, ss.temps.get(key))).toList(),
      ),
    );
  }

  Widget _buildTemperatureItem(String key, double? val) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 17, vertical: 5),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Btn.text(
            text: key,
            textStyle: UIs.text15,
            onTap: () => _onTapTemperatureItem(key),
          ).paddingSymmetric(horizontal: 5),
          Text('${val?.toStringAsFixed(1)}°C', style: UIs.text13Grey),
        ],
      ),
    );
  }

  Widget _buildBatteries(Server si) {
    final ss = si.status;
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

  Widget _buildSensors(Server si) {
    final ss = si.status;
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

    final itemW = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          children: [
            Text(si.device, style: UIs.text15),
            UIs.width7,
            Text('(${si.adapter.raw})', style: UIs.text13Grey),
          ],
        ),
        Text(si.summary ?? '', style: UIs.text13Grey),
      ],
    ).expanded();

    return InkWell(
      onTap: () => _onTapSensorItem(si),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 17, vertical: 7),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            itemW,
            UIs.width7,
            const Icon(Icons.keyboard_arrow_right, color: Colors.grey),
          ],
        ),
      ),
    );
  }

  Widget _buildPve(Server si) {
    final addr = si.spi.custom?.pveAddr;
    if (addr == null || addr.isEmpty) return UIs.placeholder;
    return CardX(
      child: ListTile(
        title: const Text('PVE'),
        leading: const Icon(FontAwesome.server_solid, size: 17),
        trailing: const Icon(Icons.chevron_right),
        onTap: () => PvePage.route.go(context, PvePageArgs(spi: si.spi)),
      ),
    );
  }

  Widget _buildCustomCmd(Server si) {
    final ss = si.status;
    if (ss.customCmds.isEmpty) return UIs.placeholder;
    return CardX(
      child: ExpandTile(
        leading: const Icon(MingCute.command_line, size: 17),
        title: Text(l10n.customCmd),
        initiallyExpanded: _getInitExpand(ss.customCmds.length),
        children: ss.customCmds.entries.map(_buildCustomCmdItem).toList(),
      ),
    );
  }

  Widget _buildCustomCmdItem(MapEntry<String, String> cmd) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 17, vertical: 7),
      child: KvRow(
        k: cmd.key,
        v: cmd.value,
        vBuilder: () {
          if (!cmd.value.contains('\n')) return null;
          return GestureDetector(
            onTap: () => _onTapCustomItem(cmd),
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
    return len > 0 && len <= (max ?? 3);
  }
}
