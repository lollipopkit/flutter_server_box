import 'package:extended_image/extended_image.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:fl_lib/fl_lib.dart';
import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:icons_plus/icons_plus.dart';
import 'package:server_box/core/extension/context/locale.dart';
import 'package:server_box/core/route.dart';
import 'package:server_box/data/model/app/scripts/cmd_types.dart';
import 'package:server_box/data/model/app/server_detail_card.dart';
import 'package:server_box/data/model/server/amd.dart';
import 'package:server_box/data/model/server/battery.dart';
import 'package:server_box/data/model/server/cpu.dart';
import 'package:server_box/data/model/server/disk.dart';
import 'package:server_box/data/model/server/disk_smart.dart';
import 'package:server_box/data/model/server/net_speed.dart';
import 'package:server_box/data/model/server/nvdia.dart';
import 'package:server_box/data/model/server/sensors.dart';
import 'package:server_box/data/model/server/server.dart';
import 'package:server_box/data/model/server/server_private_info.dart';
import 'package:server_box/data/model/server/system.dart';
import 'package:server_box/data/res/store.dart';
import 'package:server_box/view/page/pve.dart';
import 'package:server_box/view/page/server/edit.dart';
import 'package:server_box/view/page/server/logo.dart';
import 'package:server_box/view/widget/server_func_btns.dart';

part 'misc.dart';

class ServerDetailPage extends StatefulWidget {
  final SpiRequiredArgs args;
  const ServerDetailPage({super.key, required this.args});

  @override
  State<ServerDetailPage> createState() => _ServerDetailPageState();

  static const route = AppRouteArg(page: ServerDetailPage.new, path: '/servers/detail');
}

class _ServerDetailPageState extends State<ServerDetailPage> with SingleTickerProviderStateMixin {
  late final _cardBuildMap = Map.fromIterables(ServerDetailCards.names, [
    _buildAbout,
    _buildCPUView,
    _buildMemView,
    _buildSwapView,
    _buildGpuView,
    _buildDiskView,
    _buildDiskSmart,
    _buildNetView,
    _buildSensors,
    _buildTemperature,
    _buildBatteries,
    _buildPve,
    _buildCustomCmd,
  ]);

  late Size _size;
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
    _size = MediaQuery.sizeOf(context);
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
    final children = <Widget>[if (logo != null) logo, if (buildFuncs) ServerFuncBtns(spi: si.spi)];
    for (final card in _cardsOrder) {
      final child = _cardBuildMap[card]?.call(si);
      if (child != null) {
        children.add(child);
      }
    }

    return Scaffold(
      appBar: _buildAppBar(si),
      body: SafeArea(child: AutoMultiList(children: children)),
    );
  }

  CustomAppBar _buildAppBar(Server si) {
    return CustomAppBar(
      title: Text(
        si.spi.name,
        style: TextStyle(fontSize: 20, color: context.isDark ? Colors.white : Colors.black),
      ),
      actions: [
        QrShareBtn(data: si.spi.toJsonString(), tip: si.spi.name, tip2: '${l10n.server} ~ ServerBox'),
        IconButton(
          icon: const Icon(Icons.edit),
          onPressed: () async {
            final delete = await ServerEditPage.route.go(context, args: SpiRequiredArgs(si.spi));
            if (delete == true) {
              context.pop();
            }
          },
        ),
      ],
    );
  }

  Widget? _buildLogo(Server si) {
    final logoUrl = si.getLogoUrl(context);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 13),
      child: LayoutBuilder(
        builder: (_, cons) {
          if (logoUrl == null) {
            return UIs.placeholder;
          }
          return ExtendedImage.network(
            logoUrl,
            cache: true,
            height: cons.maxWidth * 0.3,
            width: cons.maxWidth,
          );
        },
      ),
    );
  }

  Widget? _buildAbout(Server si) {
    final ss = si.status;
    return ExpandTile(
      key: ValueKey(ss.more.hashCode), // Use hashCode to avoid perf issue
      leading: const Icon(MingCute.information_fill, size: 20),
      initiallyExpanded: _getInitExpand(ss.more.entries.length),
      title: Text(libL10n.about),
      childrenPadding: const EdgeInsets.symmetric(horizontal: 17, vertical: 11),
      children: ss.more.entries
          .map(
            (e) => Padding(
              padding: const EdgeInsets.symmetric(vertical: 2),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(e.key.i18n, style: UIs.text13, overflow: TextOverflow.ellipsis),
                  Text(e.value, style: UIs.text13Grey, overflow: TextOverflow.ellipsis),
                ],
              ),
            ),
          )
          .toList(),
    ).cardx;
  }

  Widget? _buildCPUView(Server si) {
    final ss = si.status;
    final percent = ss.cpu.usedPercent(coreIdx: 0).toInt();
    final details = [
      _buildDetailPercent(ss.cpu.user, 'user'),
      UIs.width13,
      _buildDetailPercent(ss.cpu.idle, 'idle'),
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
        : [_buildCPUChart(ss)];

    if (ss.cpu.brand.isNotEmpty) {
      children.add(
        Column(children: ss.cpu.brand.entries.map(_buildCpuModelItem).toList()).paddingOnly(top: 13),
      );
    }

    return ExpandTile(
      title: Align(
        alignment: Alignment.centerLeft,
        child: _buildAnimatedText(ValueKey(percent), '$percent%', UIs.text27),
      ),
      childrenPadding: const EdgeInsets.symmetric(vertical: 13),
      initiallyExpanded: _getInitExpand(1),
      trailing: Row(mainAxisSize: MainAxisSize.min, children: details),
      children: children,
    ).cardx;
  }

  Widget _buildCpuModelItem(MapEntry<String, int> e) {
    final name = e.key
        .replaceFirst('Intel(R)', '')
        .replaceFirst('AMD', '')
        .replaceFirst('with Radeon Graphics', '');
    final child = Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        LayoutBuilder(
          builder: (_, cons) {
            return ConstrainedBox(
              constraints: BoxConstraints(maxWidth: cons.maxWidth * .7),
              child: Text(name, style: UIs.text13, overflow: TextOverflow.ellipsis, maxLines: 1),
            );
          },
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
        Text('${percent.toStringAsFixed(1)}%', style: UIs.text12, textScaler: _textFactor),
        Text(timeType, style: UIs.text12Grey, textScaler: _textFactor),
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
              child: Row(children: rowChildren.joinWith(UIs.width7).toList()),
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

  Widget _buildCPUChart(ServerStatus ss) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 17, vertical: 13),
      child: LayoutBuilder(
        builder: (_, cons) {
          return SizedBox(
            height: 137,
            width: cons.maxWidth,
            child: _buildLineChart(
              ss.cpu.spots,
              //ss.cpu.rangeX,
              tooltipPrefix: 'CPU',
            ),
          );
        },
      ),
    );
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

  Widget? _buildMemView(Server si) {
    final ss = si.status;
    final free = ss.mem.free / ss.mem.total * 100;
    final avail = ss.mem.availPercent * 100;
    final used = ss.mem.usedPercent * 100;
    final usedStr = used.toStringAsFixed(0);

    final percentW = Row(
      children: [
        _buildAnimatedText(ValueKey(usedStr), '$usedStr%', UIs.text27),
        UIs.width7,
        Text('of ${(ss.mem.total * 1024).bytes2Str}', style: UIs.text13Grey),
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
          _buildProgress(used),
        ],
      ),
    ).cardx;
  }

  Widget? _buildSwapView(Server si) {
    final ss = si.status;
    if (ss.swap.total == 0) return null;

    final used = ss.swap.usedPercent * 100;
    final cached = ss.swap.cached / ss.swap.total * 100;

    final percentW = Row(
      children: [
        Text('${used.toStringAsFixed(0)}%', style: UIs.text27),
        UIs.width7,
        Text('of ${(ss.swap.total * 1024).bytes2Str} ', style: UIs.text13Grey),
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
            children: [percentW, _buildDetailPercent(cached, 'cached')],
          ),
          UIs.height13,
          _buildProgress(used),
        ],
      ),
    ).cardx;
  }

  Widget? _buildGpuView(Server si) {
    final ss = si.status;
    final hasNvidia = ss.nvidia != null && ss.nvidia!.isNotEmpty;
    final hasAmd = ss.amd != null && ss.amd!.isNotEmpty;

    if (!hasNvidia && !hasAmd) return null;

    final children = <Widget>[];

    // Add NVIDIA GPUs
    if (hasNvidia) {
      children.addAll(ss.nvidia!.map((e) => _buildNvidiaGpuItem(e)));
    }

    // Add AMD GPUs
    if (hasAmd) {
      children.addAll(ss.amd!.map((e) => _buildAmdGpuItem(e)));
    }

    return ExpandTile(
      title: const Text('GPU'),
      leading: const Icon(Icons.memory, size: 17),
      initiallyExpanded: _getInitExpand(children.length, 3),
      children: children,
    ).cardx;
  }

  Widget _buildNvidiaGpuItem(NvidiaSmiItem item) {
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
            onPressed: () => _onTapNvidiaGpuItem(item),
            icon: const Icon(Icons.info_outline, size: 17),
          ),
        ],
      ),
    );
  }

  Widget _buildAmdGpuItem(AmdSmiItem item) {
    final mem = item.memory;
    return ListTile(
      title: Text('${item.name} (AMD)', style: UIs.text13),
      leading: Text(
        '${item.utilization}%\n${item.temp} °C',
        style: UIs.text12Grey,
        textScaler: _textFactor,
        textAlign: TextAlign.center,
      ),
      subtitle: Text(
        '${item.power} - FAN ${item.fanSpeed} RPM\n${item.clockSpeed} MHz\n${mem.used} / ${mem.total} ${mem.unit}',
        style: UIs.text12Grey,
        textScaler: _textFactor,
      ),
      contentPadding: const EdgeInsets.only(left: 17, right: 17),
      trailing: Row(
        mainAxisAlignment: MainAxisAlignment.end,
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(onPressed: () => _onTapAmdGpuItem(item), icon: const Icon(Icons.info_outline, size: 17)),
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
        onTap: () => _onTapGpuProcessItem(process),
        child: const Icon(Icons.info_outline, size: 17),
      ),
    );
  }

  Widget _buildAmdGpuProcessItem(AmdSmiMemProcess process) {
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
        onTap: () => _onTapAmdGpuProcessItem(process),
        child: const Icon(Icons.info_outline, size: 17),
      ),
    );
  }

  Widget? _buildDiskView(Server si) {
    final ss = si.status;
    final children = <Widget>[];

    // Create widgets for each top-level disk
    for (int idx = 0; idx < ss.disk.length; idx++) {
      final disk = ss.disk[idx];
      children.add(_buildDiskItemWithHierarchy(disk, ss, 0));
    }

    if (children.isEmpty) return null;

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
                Text(text, style: UIs.text12Grey, textScaler: _textFactor),
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
                  Text('${disk.usedPercent}%', style: UIs.text12Grey),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget? _buildDiskSmart(Server si) {
    final smarts = si.status.diskSmart;
    if (smarts.isEmpty) return null;
    return CardX(
      child: ExpandTile(
        title: Text(l10n.diskHealth),
        leading: Icon(ServerDetailCards.smart.icon, size: 17),
        childrenPadding: const EdgeInsets.only(bottom: 7),
        initiallyExpanded: _getInitExpand(smarts.length),
        children: smarts.map(_buildDiskSmartItem).toList(),
      ),
    );
  }

  Widget _buildDiskSmartItem(DiskSmart smart) {
    final healthStatus = _getDiskHealthStatus(smart);

    return ListTile(
      dense: true,
      leading: healthStatus.icon,
      title: Text(smart.device, style: UIs.text13, textScaler: _textFactor),
      trailing: Text(
        healthStatus.text,
        style: UIs.text13.copyWith(fontWeight: FontWeight.bold),
        textScaler: _textFactor,
      ),
      subtitle: _buildDiskSmartDetails(smart),
      onTap: () => _onTapDiskSmartItem(smart),
    );
  }

  ({String text, Color color, Widget icon}) _getDiskHealthStatus(DiskSmart smart) {
    if (smart.healthy == null) {
      return (
        text: libL10n.unknown,
        color: Colors.orange,
        icon: const Icon(Icons.help_outline, color: Colors.orange, size: 18),
      );
    } else if (smart.healthy!) {
      return (
        text: 'PASS',
        color: Colors.green,
        icon: const Icon(Icons.check_circle, color: Colors.green, size: 18),
      );
    } else {
      return (text: 'FAIL', color: Colors.red, icon: const Icon(Icons.error, color: Colors.red, size: 18));
    }
  }

  Widget? _buildDiskSmartDetails(DiskSmart smart) {
    final details = <String>[];

    if (smart.model != null) {
      details.add(smart.model!);
    }

    if (smart.temperature != null) {
      details.add('${smart.temperature!.toStringAsFixed(1)}°C');
    }

    if (smart.powerOnHours != null) {
      final hours = smart.powerOnHours!;
      details.add('$hours ${libL10n.hour}');
    }

    if (smart.ssdLifeLeft != null) {
      details.add('Life left: ${smart.ssdLifeLeft}%');
    }

    if (details.isEmpty) return null;

    return Text(
      details.join(' | '),
      style: UIs.text12Grey,
      textScaler: _textFactor,
      maxLines: 2,
      overflow: TextOverflow.ellipsis,
    );
  }

  void _onTapDiskSmartItem(DiskSmart smart) {
    final details = <String>[];

    if (smart.model != null) details.add('Model: ${smart.model}');
    if (smart.serial != null) details.add('Serial: ${smart.serial}');
    if (smart.temperature != null) {
      details.add('Temperature: ${smart.temperature!.toStringAsFixed(1)}°C');
    }

    if (smart.powerOnHours != null) {
      details.add('Power On: ${smart.powerOnHours} ${libL10n.hour}');
    }
    if (smart.powerCycleCount != null) {
      details.add('Power Cycle: ${smart.powerCycleCount}');
    }

    if (smart.ssdLifeLeft != null) {
      details.add('Life Left: ${smart.ssdLifeLeft}%');
    }
    if (smart.lifetimeWritesGiB != null) {
      details.add('Lifetime Write: ${smart.lifetimeWritesGiB} GiB');
    }
    if (smart.lifetimeReadsGiB != null) {
      details.add('Lifetime Read: ${smart.lifetimeReadsGiB} GiB');
    }
    if (smart.averageEraseCount != null) {
      details.add('Avg. Erase: ${smart.averageEraseCount}');
    }
    if (smart.unsafeShutdownCount != null) {
      details.add('Unsafe Shutdown: ${smart.unsafeShutdownCount}');
    }

    final criticalAttrs = [
      'Reallocated_Sector_Ct',
      'Current_Pending_Sector',
      'Offline_Uncorrectable',
      'UDMA_CRC_Error_Count',
    ];

    for (final attrName in criticalAttrs) {
      final attr = smart.getAttribute(attrName);
      if (attr != null && attr.rawValue != null) {
        final value = attr.rawValue.toString();
        details.add('${attrName.replaceAll('_', ' ')}: $value');
      }
    }

    if (details.isEmpty) {
      return;
    }

    final markdown = details.join('\n\n- ');
    context.showRoundDialog(
      title: smart.device,
      child: MarkdownBody(
        data: '- $markdown',
        selectable: true,
        styleSheet: MarkdownStyleSheet.fromTheme(
          Theme.of(context),
        ).copyWith(p: UIs.text13Grey, h2: UIs.text15),
      ),
      actions: Btnx.oks,
    );
  }

  Widget? _buildNetView(Server si) {
    final ss = si.status;
    final ns = ss.netSpeed;
    final children = <Widget>[];
    final devices = ns.devices;
    if (devices.isEmpty) return null;

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
                transitionBuilder: (child, animation) => FadeTransition(opacity: animation, child: child),
                child: Row(
                  children: [
                    const Icon(Icons.sort, size: 17),
                    UIs.width7,
                    Text(val.name, style: UIs.text13Grey),
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
              ),
            ],
          ),
          SizedBox(
            width: 170,
            child: Text(
              '${ns.speedOut(device: device)} ↑\n${ns.speedIn(device: device)} ↓',
              textAlign: TextAlign.end,
              style: UIs.text13Grey,
            ),
          ),
        ],
      ),
    );
  }

  Widget? _buildTemperature(Server si) {
    final ss = si.status;
    if (ss.temps.isEmpty) return null;

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
      padding: const EdgeInsets.only(left: 3, right: 17, top: 5, bottom: 5),
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

  Widget? _buildBatteries(Server si) {
    final ss = si.status;
    if (ss.batteries.isEmpty) return null;

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
              Text('${battery.status.name} - ${battery.cycle}', style: UIs.text13Grey),
            ],
          ),
          Text('${battery.percent?.toStringAsFixed(0)}%', style: UIs.text13Grey),
        ],
      ),
    );
  }

  Widget? _buildSensors(Server si) {
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

  Widget? _buildPve(Server si) {
    final addr = si.spi.custom?.pveAddr;
    if (addr == null || addr.isEmpty) return null;
    return CardX(
      child: ListTile(
        title: const Text('PVE'),
        leading: const Icon(FontAwesome.server_solid, size: 17),
        trailing: const Icon(Icons.chevron_right),
        onTap: () => PvePage.route.go(context, PvePageArgs(spi: si.spi)),
      ),
    );
  }

  Widget? _buildCustomCmd(Server si) {
    final ss = si.status;
    if (ss.customCmds.isEmpty) return null;
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
            child: const Icon(Icons.info_outline, size: 17, color: Colors.grey),
          );
        },
      ),
    );
  }

  Widget _buildAnimatedText(Key key, String text, TextStyle style) {
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 277),
      child: Text(key: key, text, style: style, textScaler: _textFactor),
      transitionBuilder: (child, animation) => FadeTransition(opacity: animation, child: child),
    );
  }
}
