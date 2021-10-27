import 'package:after_layout/after_layout.dart';
import 'package:circle_chart/circle_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_staggered_animations/flutter_staggered_animations.dart';
import 'package:get_it/get_it.dart';
import 'package:provider/provider.dart';
import 'package:toolbox/core/route.dart';
import 'package:toolbox/data/model/server.dart';
import 'package:toolbox/data/model/server_connection_state.dart';
import 'package:toolbox/data/model/server_status.dart';
import 'package:toolbox/data/provider/server.dart';
import 'package:toolbox/data/store/setting.dart';
import 'package:toolbox/locator.dart';
import 'package:toolbox/view/page/server/detail.dart';
import 'package:toolbox/view/page/server/edit.dart';

class ServerPage extends StatefulWidget {
  const ServerPage({Key? key}) : super(key: key);

  @override
  _ServerPageState createState() => _ServerPageState();
}

class _ServerPageState extends State<ServerPage>
    with AutomaticKeepAliveClientMixin, AfterLayoutMixin {
  late MediaQueryData _media;
  late ThemeData _theme;
  late Color _primaryColor;

  late ServerProvider _serverProvider;

  @override
  void initState() {
    super.initState();
    _serverProvider = locator<ServerProvider>();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _media = MediaQuery.of(context);
    _theme = Theme.of(context);
    _primaryColor = Color(locator<SettingStore>().primaryColor.fetch()!);
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return Scaffold(
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 7),
        child: AnimationLimiter(
            child: Consumer<ServerProvider>(builder: (_, pro, __) {
          return Column(
              children: AnimationConfiguration.toStaggeredList(
            duration: const Duration(milliseconds: 377),
            childAnimationBuilder: (widget) => SlideAnimation(
              verticalOffset: 50.0,
              child: FadeInAnimation(
                child: widget,
              ),
            ),
            children: [
              const SizedBox(height: 13),
              ...pro.servers.map((e) => _buildEachServerCard(e))
            ],
          ));
        })),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () =>
            AppRoute(const ServerEditPage(), 'Add server info page')
                .go(context),
        tooltip: 'add a server',
        heroTag: 'server page fab',
        child: const Icon(Icons.add),
      ),
    );
  }

  Widget _buildEachServerCard(ServerInfo si) {
    return GestureDetector(
        child: _buildEachCardContent(si),
        onLongPress: () {
          AppRoute(
                  ServerEditPage(
                    spi: si.info,
                  ),
                  'Edit server info page')
              .go(context);
        });
  }

  Widget _buildEachCardContent(ServerInfo si) {
    return Card(
      child: InkWell(
        child: Padding(
          padding: const EdgeInsets.all(13),
          child: _buildRealServerCard(
              si.status, si.info.name ?? '', si.connectionState),
        ),
        onTap: () =>
            AppRoute(ServerDetailPage(si.client.id!), 'server detail page')
                .go(context),
      ),
    );
  }

  Widget _buildRealServerCard(
      ServerStatus ss, String serverName, ServerConnectionState cs) {
    final rootDisk =
        ss.disk!.firstWhere((element) => element!.mountLocation == '/');

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              serverName,
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
              textScaleFactor: 1.0,
            ),
            Text(getTopRightStr(cs, ss.uptime!),
                textScaleFactor: 1.0,
                style: TextStyle(
                    color: _theme.textTheme.bodyText1!.color!.withAlpha(100),
                    fontSize: 11))
          ],
        ),
        const SizedBox(
          height: 17,
        ),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            _buildPercentCircle(ss.cpuPercent!, 'CPU'),
            _buildPercentCircle(
                ss.memList![1]! / ss.memList![0]! * 100 + 0.01, 'Mem'),
            _buildIOData('Net', 'Conn:\n' + ss.tcp!.maxConn!.toString(),
                'Fail:\n' + ss.tcp!.fail.toString()),
            _buildIOData('Disk', 'Total:\n' + rootDisk!.size!,
                'Used:\n' + rootDisk.usedPercent.toString() + '%')
          ],
        ),
      ],
    );
  }

  String getTopRightStr(ServerConnectionState cs, String upTime) {
    switch (cs) {
      case ServerConnectionState.disconnected:
        return 'Disconnected';
      case ServerConnectionState.connected:
        return upTime;
      case ServerConnectionState.connecting:
        return 'Connecting...';
      case ServerConnectionState.failed:
        return 'Failed';
      default:
        return 'Unknown State';
    }
  }

  Widget _buildIOData(String title, String up, String down) {
    final statusTextStyle = TextStyle(
        fontSize: 9, color: _theme.textTheme.bodyText1!.color!.withAlpha(177));
    return SizedBox(
      width: _media.size.width * 0.2,
      height: _media.size.height * 0.1,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          const SizedBox(),
          Column(
            children: [
              Text(
                up,
                style: statusTextStyle,
                textAlign: TextAlign.center,
                textScaleFactor: 1.0,
              ),
              const SizedBox(height: 3),
              Text(
                down + '\n',
                style: statusTextStyle,
                textAlign: TextAlign.center,
                textScaleFactor: 1.0,
              )
            ],
          ),
          Text(
            title,
            style: const TextStyle(fontSize: 12),
            textAlign: TextAlign.center,
            textScaleFactor: 1.0,
          )
        ],
      ),
    );
  }

  Widget _buildPercentCircle(double percent, String title) {
    if (percent == 0.0) percent += 0.01;
    if (percent == 100.0) percent -= 0.01;
    return SizedBox(
      width: _media.size.width * 0.2,
      height: _media.size.height * 0.1,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Stack(
            children: [
              CircleChart(
                progressColor: _primaryColor,
                progressNumber: percent,
                maxNumber: 100,
                width: _media.size.width * 0.37,
                height: _media.size.height * 0.09,
              ),
              Positioned.fill(
                child: Center(
                  child: Text(
                    '${percent.toStringAsFixed(1)}%',
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontSize: 11),
                    textScaleFactor: 1.0,
                  ),
                ),
              ),
            ],
          ),
          Text(
            title,
            style: const TextStyle(fontSize: 12),
            textAlign: TextAlign.center,
            textScaleFactor: 1.0,
          ),
        ],
      ),
    );
  }

  @override
  bool get wantKeepAlive => true;

  @override
  Future<void> afterFirstLayout(BuildContext context) async {
    await GetIt.I.allReady();
    await _serverProvider.loadLocalData();
    await _serverProvider.refreshData();
    await _serverProvider.startAutoRefresh();
  }
}
