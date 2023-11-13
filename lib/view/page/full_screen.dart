import 'dart:async';
import 'dart:math';

import 'package:after_layout/after_layout.dart';
import 'package:circle_chart/circle_chart.dart';
import 'package:flutter/material.dart';
import 'package:get_it/get_it.dart';
import 'package:provider/provider.dart';
import 'package:toolbox/core/extension/context/locale.dart';
import 'package:toolbox/core/route.dart';
import 'package:toolbox/data/model/server/disk.dart';
import 'package:toolbox/data/provider/server.dart';
import 'package:toolbox/data/res/provider.dart';
import 'package:toolbox/data/res/store.dart';
import 'package:toolbox/data/res/ui.dart';

import '../../core/analysis.dart';
import '../../core/update.dart';
import '../../core/utils/ui.dart';
import '../../data/model/app/net_view.dart';
import '../../data/model/server/server.dart';
import '../../data/model/server/server_private_info.dart';
import '../../data/res/color.dart';

class FullScreenPage extends StatefulWidget {
  const FullScreenPage({Key? key}) : super(key: key);

  @override
  _FullScreenPageState createState() => _FullScreenPageState();
}

class _FullScreenPageState extends State<FullScreenPage> with AfterLayoutMixin {
  late MediaQueryData _media;
  late ThemeData _theme;
  late Timer _timer;
  late int _rotateQuarter;

  final _pageController = PageController(initialPage: 0);

  @override
  void initState() {
    super.initState();
    switchStatusBar(hide: true);
    _rotateQuarter = Stores.setting.fullScreenRotateQuarter.fetch();
    _timer = Timer.periodic(const Duration(minutes: 1), (_) {
      if (mounted) {
        setState(() {});
      } else {
        _timer.cancel();
      }
    });
  }

  @override
  void dispose() {
    super.dispose();
    _timer.cancel();
    _pageController.dispose();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _media = MediaQuery.of(context);
    _theme = Theme.of(context);
  }

  double get _offset {
    // based on screen width
    final x = _screenWidth * 0.03;
    var r = Random().nextDouble();
    final n = Random().nextBool() ? -1 : 1;
    return n * x * r;
  }

  @override
  Widget build(BuildContext context) {
    final offset = Offset(_offset, _offset);
    return Scaffold(
      body: SafeArea(
        child: Padding(
          // Avoid display cutout
          // `_screenWidth * 0.03` is the offset value
          padding: EdgeInsets.all(_screenWidth * 0.03),
          child: ValueListenableBuilder<int>(
            valueListenable:
                Stores.setting.fullScreenRotateQuarter.listenable(),
            builder: (_, val, __) {
              _rotateQuarter = val;
              return RotatedBox(
                quarterTurns: val,
                child: Transform.translate(
                  offset: offset,
                  child: Stack(
                    children: [
                      _buildMain(),
                      Positioned(
                        top: 0,
                        left: 0,
                        child: _buildSettingBtn(),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  double get _screenWidth =>
      _rotateQuarter % 2 == 0 ? _media.size.width : _media.size.height;
  double get _screenHeight =>
      _rotateQuarter % 2 == 0 ? _media.size.height : _media.size.width;

  Widget _buildSettingBtn() {
    return IconButton(
        onPressed: () => AppRoute.settings().go(context),
        icon: const Icon(Icons.settings, color: Colors.grey));
  }

  Widget _buildMain() {
    return Consumer<ServerProvider>(builder: (_, pro, __) {
      if (pro.serverOrder.isEmpty) {
        return Center(
          child: TextButton(
              onPressed: () => AppRoute.serverEdit().go(context),
              child: Text(
                l10n.addAServer,
                style: const TextStyle(fontSize: 27),
              )),
        );
      }
      return PageView.builder(
        controller: _pageController,
        itemCount: pro.serverOrder.length,
        itemBuilder: (_, idx) {
          final s = pro.pick(id: pro.serverOrder[idx]);
          if (s == null) {
            return Center(child: Text(l10n.noClient));
          }
          return _buildRealServerCard(s.status, s.state, s.spi);
        },
      );
    });
  }

  Widget _buildRealServerCard(
    ServerStatus ss,
    ServerState cs,
    ServerPrivateInfo spi,
  ) {
    final rootDisk = findRootDisk(ss.disk);

    return InkWell(
      onTap: () => AppRoute.serverDetail(spi: spi).go(context),
      child: Stack(
        children: [
          Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: _buildServerCardTitle(ss, cs, spi)),
          Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              SizedBox(height: _screenWidth * 0.1),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _buildPercentCircle(ss.cpu.usedPercent()),
                  _buildPercentCircle(ss.mem.usedPercent * 100),
                  _buildNet(ss),
                  _buildIOData(
                    'Total:\n${rootDisk?.size}',
                    'Used:\n${rootDisk?.usedPercent}%',
                  )
                ],
              ),
              SizedBox(height: _screenWidth * 0.1),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _buildExplainText('CPU'),
                  _buildExplainText('Mem'),
                  _buildExplainText('Net'),
                  _buildExplainText('Disk'),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildServerCardTitle(
    ServerStatus ss,
    ServerState cs,
    ServerPrivateInfo spi,
  ) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: _screenWidth * 0.05),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          UIs.height13,
          Row(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                spi.name,
                style:
                    const TextStyle(fontWeight: FontWeight.bold, fontSize: 19),
                textScaleFactor: 1.0,
                textAlign: TextAlign.center,
              ),
              const Icon(
                Icons.keyboard_arrow_right,
                size: 21,
                color: Colors.grey,
              )
            ],
          ),
          UIs.height13,
          _buildTopRightText(ss, cs),
        ],
      ),
    );
  }

  Widget _buildTopRightText(ServerStatus ss, ServerState cs) {
    final topRightStr = _getTopRightStr(
      cs,
      ss.temps.first,
      ss.uptime,
      ss.err,
    );
    return Text(
      topRightStr,
      style: UIs.textSize11Grey,
      textScaleFactor: 1.0,
    );
  }

  Widget _buildExplainText(String text) {
    return SizedBox(
      width: _screenHeight * 0.2,
      child: Text(
        text,
        style: const TextStyle(fontSize: 13),
        textAlign: TextAlign.center,
        textScaleFactor: 1.0,
      ),
    );
  }

  String _getTopRightStr(
    ServerState cs,
    double? temp,
    String upTime,
    String? failedInfo,
  ) {
    switch (cs) {
      case ServerState.disconnected:
        return l10n.disconnected;
      case ServerState.connected:
        final tempStr = temp == null ? '' : '${temp.toStringAsFixed(1)}°C';
        final items = [tempStr, upTime];
        final str = items.where((element) => element.isNotEmpty).join(' | ');
        if (str.isEmpty) return l10n.serverTabLoading;
        return str;
      case ServerState.connecting:
        return l10n.serverTabConnecting;
      case ServerState.failed:
        if (failedInfo == null) {
          return l10n.serverTabFailed;
        }
        if (failedInfo.contains('encypted')) {
          return l10n.serverTabPlzSave;
        }
        return failedInfo;
      default:
        return l10n.serverTabUnkown;
    }
  }

  Widget _buildNet(ServerStatus ss) {
    return ValueListenableBuilder<NetViewType>(
      valueListenable: Stores.setting.netViewType.listenable(),
      builder: (_, val, __) {
        final (a, b) = val.build(ss);
        return AnimatedSwitcher(
          duration: const Duration(milliseconds: 177),
          child: _buildIOData(a, b),
        );
      },
    );
  }

  Widget _buildIOData(String up, String down) {
    final statusTextStyle = TextStyle(
        fontSize: 13, color: _theme.textTheme.bodyLarge!.color!.withAlpha(177));
    return SizedBox(
      width: _screenHeight * 0.23,
      child: Column(
        children: [
          const SizedBox(height: 5),
          Text(
            up,
            style: statusTextStyle,
            textAlign: TextAlign.center,
            textScaleFactor: 1.0,
          ),
          const SizedBox(height: 3),
          Text(
            down,
            style: statusTextStyle,
            textAlign: TextAlign.center,
            textScaleFactor: 1.0,
          )
        ],
      ),
    );
  }

  Widget _buildPercentCircle(double percent) {
    if (percent <= 0) percent = 0.01;
    if (percent >= 100) percent = 99.9;
    return SizedBox(
      width: _screenHeight * 0.23,
      child: Stack(
        children: [
          Center(
            child: CircleChart(
              progressColor: primaryColor,
              progressNumber: percent,
              animationDuration: const Duration(milliseconds: 377),
              maxNumber: 100,
              width: _screenWidth * 0.22,
              height: _screenWidth * 0.22,
            ),
          ),
          Positioned.fill(
            child: Center(
              child: Text(
                '${percent.toStringAsFixed(1)}%',
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 15),
                textScaleFactor: 1.0,
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Future<void> afterFirstLayout(BuildContext context) async {
    if (Stores.setting.autoCheckAppUpdate.fetch()) {
      doUpdate(context);
    }
    await GetIt.I.allReady();
    await Pros.server.load();
    await Pros.server.refreshData();
    if (!Analysis.enabled) {
      await Analysis.init();
    }
  }
}
