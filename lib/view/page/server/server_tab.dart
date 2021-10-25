import 'package:after_layout/after_layout.dart';
import 'package:charts_flutter/flutter.dart' as chart;
import 'package:flutter/material.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_staggered_animations/flutter_staggered_animations.dart';
import 'package:get_it/get_it.dart';
import 'package:provider/provider.dart';
import 'package:toolbox/core/route.dart';
import 'package:toolbox/data/model/server_private_info.dart';
import 'package:toolbox/data/model/server_status.dart';
import 'package:toolbox/data/provider/server.dart';
import 'package:toolbox/locator.dart';
import 'package:toolbox/view/page/server/server_edit.dart';
import 'package:toolbox/view/widget/circle_pie.dart';

class ServerPage extends StatefulWidget {
  const ServerPage({Key? key}) : super(key: key);

  @override
  _ServerPageState createState() => _ServerPageState();
}

class _ServerPageState extends State<ServerPage>
    with AutomaticKeepAliveClientMixin, AfterLayoutMixin {
  late MediaQueryData _media;
  late ThemeData _theme;

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
              ...pro.servers.map((e) => _buildEachServerCard(
                  pro.servers[pro.servers.indexOf(e)].status, e.info))
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

  Widget _buildEachServerCard(ServerStatus ss, ServerPrivateInfo spi) {
    return GestureDetector(
        child: _buildEachCardContent(ss, spi),
        onLongPress: () {
          AppRoute(
                  ServerEditPage(
                    spi: spi,
                  ),
                  'Edit server info page')
              .go(context);
        });
  }

  Widget _buildEachCardContent(ServerStatus ss, ServerPrivateInfo spi) {
    return Card(
      child: InkWell(
        child: Padding(
          padding: const EdgeInsets.all(13),
          child: _buildRealServerCard(ss, spi.name ?? ''),
        ),
        onTap: () {},
      ),
    );
  }

  Widget _buildRealServerCard(ServerStatus ss, String serverName) {
    final cpuData = [
      IndexPercent(0, ss.cpuPercent!.toInt()),
      IndexPercent(1, 100 - ss.cpuPercent!.toInt()),
    ];
    final memData = <IndexPercent>[];
    for (var e in ss.memList!) {
      memData.add(IndexPercent(ss.memList!.indexOf(e), e!.toInt()));
    }

    final mem1 = memData[1];
    memData[1] = memData.last;
    memData.last = mem1;

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
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            Text(ss.uptime!,
                style: TextStyle(
                    color: _theme.textTheme.bodyText1!.color!.withAlpha(100)))
          ],
        ),
        const SizedBox(
          height: 13,
        ),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            _buildPercentCircle(ss.cpuPercent!, 'CPU', [
              chart.Series<IndexPercent, int>(
                id: 'CPU',
                domainFn: (IndexPercent cpu, _) => cpu.id,
                measureFn: (IndexPercent cpu, _) => cpu.percent,
                data: cpuData,
              )
            ]),
            _buildPercentCircle(
                ss.memList![1]! / ss.memList![0]! * 100, 'Mem', [
              chart.Series<IndexPercent, int>(
                id: 'Mem',
                domainFn: (IndexPercent mem, _) => mem.id,
                measureFn: (IndexPercent mem, _) => mem.percent,
                data: memData,
              )
            ]),
            _buildIOData('Net', 'Conn:\n' + ss.tcp!.maxConn!.toString(),
                'Fail:\n' + ss.tcp!.fail.toString()),
            _buildIOData('Disk', 'Total:\n' + rootDisk!.size!,
                'Used:\n' + rootDisk.usedPercent.toString() + '%')
          ],
        ),
      ],
    );
  }

  Widget _buildIOData(String title, String up, String down) {
    final statusTextStyle = TextStyle(
        fontSize: 11, color: _theme.textTheme.bodyText1!.color!.withAlpha(177));
    return SizedBox(
      width: _media.size.width * 0.2,
      height: _media.size.height * 0.1,
      child: Stack(
        children: [
          Positioned.fill(
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    up,
                    style: statusTextStyle,
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 3),
                  Text(
                    down + '\n',
                    style: statusTextStyle,
                    textAlign: TextAlign.center,
                  )
                ],
              ),
            ),
          ),
          Positioned(
              child: Text(title, textAlign: TextAlign.center),
              bottom: 0,
              left: 0,
              right: 0)
        ],
      ),
    );
  }

  Widget _buildPercentCircle(double percent, String title,
      List<chart.Series<IndexPercent, int>> series) {
    return SizedBox(
      width: _media.size.width * 0.2,
      height: _media.size.height * 0.1,
      child: Stack(
        children: [
          DonutPieChart(series),
          Positioned.fill(
            child: Center(
              child: Text(
                '${percent.toStringAsFixed(1)}%\n',
                textAlign: TextAlign.center,
              ),
            ),
          ),
          Positioned(
              child: Text(title, textAlign: TextAlign.center),
              bottom: 0,
              left: 0,
              right: 0)
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
