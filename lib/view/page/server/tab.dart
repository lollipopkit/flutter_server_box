import 'package:after_layout/after_layout.dart';
import 'package:circle_chart/circle_chart.dart';
import 'package:dropdown_button2/dropdown_button2.dart';
import 'package:flutter/material.dart';
import 'package:get_it/get_it.dart';
import 'package:provider/provider.dart';
import 'package:pull_to_refresh/pull_to_refresh.dart';
import 'package:toolbox/core/route.dart';
import 'package:toolbox/core/utils.dart';
import 'package:toolbox/data/model/app/menu_item.dart';
import 'package:toolbox/data/model/server/server.dart';
import 'package:toolbox/data/model/server/server_connection_state.dart';
import 'package:toolbox/data/model/server/server_private_info.dart';
import 'package:toolbox/data/model/server/server_status.dart';
import 'package:toolbox/data/provider/server.dart';
import 'package:toolbox/data/res/color.dart';
import 'package:toolbox/data/store/setting.dart';
import 'package:toolbox/generated/l10n.dart';
import 'package:toolbox/locator.dart';
import 'package:toolbox/view/page/apt.dart';
import 'package:toolbox/view/page/docker.dart';
import 'package:toolbox/view/page/server/detail.dart';
import 'package:toolbox/view/page/server/edit.dart';
import 'package:toolbox/view/page/sftp/view.dart';
import 'package:toolbox/view/page/snippet/list.dart';
import 'package:toolbox/view/widget/round_rect_card.dart';

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
  late RefreshController _refreshController;

  late ServerProvider _serverProvider;
  late S s;

  @override
  void initState() {
    super.initState();
    _serverProvider = locator<ServerProvider>();
    _refreshController = RefreshController();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _media = MediaQuery.of(context);
    _theme = Theme.of(context);
    _primaryColor = primaryColor;
    s = S.of(context);
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final autoUpdate =
        locator<SettingStore>().serverStatusUpdateInterval.fetch() != 0;
    final child = Consumer<ServerProvider>(builder: (_, pro, __) {
      if (pro.servers.isEmpty) {
        return Center(
          child: Text(
            s.serverTabEmpty,
            textAlign: TextAlign.center,
          ),
        );
      }
      return ListView.separated(
        padding: const EdgeInsets.all(7),
        controller: ScrollController(),
        itemBuilder: (ctx, idx) {
          if (idx == pro.servers.length) {
            return SizedBox(height: _media.padding.bottom);
          }
          return _buildEachServerCard(pro.servers[idx]);
        },
        itemCount: pro.servers.length + 1,
        separatorBuilder: (_, __) => const SizedBox(
          height: 3,
        ),
      );
    });
    return Scaffold(
      body: autoUpdate
          ? child
          : SmartRefresher(
              controller: _refreshController,
              child: child,
              onRefresh: () async {
                await _serverProvider.refreshData();
                _refreshController.refreshCompleted();
              },
            ),
      floatingActionButton: FloatingActionButton(
        onPressed: () =>
            AppRoute(const ServerEditPage(), 'Add server info page')
                .go(context),
        tooltip: s.addAServer,
        heroTag: 'server page fab',
        child: const Icon(Icons.add),
      ),
    );
  }

  Widget _buildEachServerCard(ServerInfo si) {
    return RoundRectCard(
      InkWell(
        onLongPress: () => AppRoute(
                ServerEditPage(
                  spi: si.info,
                ),
                'Edit server info page')
            .go(context),
        child: Padding(
            padding: const EdgeInsets.all(13),
            child: _buildRealServerCard(
                si.status, si.info.name, si.connectionState, si.info)),
        onTap: () => AppRoute(ServerDetailPage('${si.info.ip}:${si.info.port}'),
                'server detail page')
            .go(context),
      ),
    );
  }

  Widget _buildRealServerCard(ServerStatus ss, String serverName,
      ServerConnectionState cs, ServerPrivateInfo spi) {
    final rootDisk =
        ss.disk.firstWhere((element) => element.mountLocation == '/');

    final topRightStr =
        getTopRightStr(cs, ss.cpu2Status.temp, ss.uptime, ss.failedInfo);
    final hasError =
        cs == ServerConnectionState.failed && ss.failedInfo != null;
    final style = TextStyle(
        color: _theme.textTheme.bodyText1!.color!.withAlpha(100), fontSize: 11);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 7),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Text(
                    serverName,
                    style: const TextStyle(
                        fontWeight: FontWeight.bold, fontSize: 12),
                    textScaleFactor: 1.0,
                  ),
                  const Icon(
                    Icons.keyboard_arrow_right,
                    size: 17,
                    color: Colors.grey,
                  )
                ],
              ),
              Row(
                children: [
                  hasError
                      ? GestureDetector(
                          onTap: () => showRoundDialog(
                              context, s.error, Text(ss.failedInfo ?? ''), []),
                          child: Text(s.clickSee, style: style))
                      : Text(topRightStr, style: style, textScaleFactor: 1.0),
                  _buildMoreBtn(spi),
                ],
              )
            ],
          ),
        ),
        const SizedBox(
          height: 17,
        ),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            _buildPercentCircle(ss.cpu2Status.usedPercent()),
            _buildPercentCircle(ss.memory.used / ss.memory.total * 100),
            _buildIOData('Conn:\n${ss.tcp.maxConn}', 'Fail:\n${ss.tcp.fail}'),
            _buildIOData(
                'Total:\n${rootDisk.size}', 'Used:\n${rootDisk.usedPercent}%')
          ],
        ),
        const SizedBox(height: 13),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            _buildExplainText('CPU'),
            _buildExplainText('Mem'),
            _buildExplainText('Net'),
            _buildExplainText('Disk'),
          ],
        ),
        const SizedBox(height: 3),
      ],
    );
  }

  Widget _buildMoreBtn(ServerPrivateInfo spi) {
    return DropdownButtonHideUnderline(
      child: DropdownButton2(
        customButton: const Padding(
          padding: EdgeInsets.symmetric(horizontal: 5, vertical: 1.7),
          child: Icon(
            Icons.more_vert,
            size: 17,
          ),
        ),
        customItemsIndexes: [ServerTabMenuItems.firstItems.length],
        customItemsHeight: 8,
        items: [
          ...ServerTabMenuItems.firstItems.map(
            (item) => DropdownMenuItem<DropdownBtnItem>(
              value: item,
              child: item.build,
            ),
          ),
          const DropdownMenuItem<Divider>(enabled: false, child: Divider()),
          ...ServerTabMenuItems.secondItems.map(
            (item) => DropdownMenuItem<DropdownBtnItem>(
              value: item,
              child: item.build,
            ),
          ),
        ],
        onChanged: (value) {
          final item = value as DropdownBtnItem;
          switch (item) {
            case ServerTabMenuItems.apt:
              AppRoute(AptManagePage(spi), 'apt manage page').go(context);
              break;
            case ServerTabMenuItems.sftp:
              AppRoute(SFTPPage(spi), 'SFTP').go(context);
              break;
            case ServerTabMenuItems.snippet:
              AppRoute(
                      SnippetListPage(
                        spi: spi,
                      ),
                      'snippet list')
                  .go(context);
              break;
            case ServerTabMenuItems.edit:
              AppRoute(
                      ServerEditPage(
                        spi: spi,
                      ),
                      'Edit server info page')
                  .go(context);
              break;
            case ServerTabMenuItems.docker:
              AppRoute(DockerManagePage(spi), 'Docker manage page').go(context);
              break;
          }
        },
        itemHeight: 37,
        itemPadding: const EdgeInsets.only(left: 17, right: 17),
        dropdownWidth: 160,
        dropdownPadding: const EdgeInsets.symmetric(vertical: 7),
        dropdownDecoration: BoxDecoration(
          borderRadius: BorderRadius.circular(7),
        ),
        dropdownElevation: 8,
        offset: const Offset(0, 8),
      ),
    );
  }

  Widget _buildExplainText(String text) {
    return SizedBox(
      width: _media.size.width * 0.2,
      child: Text(
        text,
        style: const TextStyle(fontSize: 12),
        textAlign: TextAlign.center,
        textScaleFactor: 1.0,
      ),
    );
  }

  String getTopRightStr(ServerConnectionState cs, String temp, String upTime,
      String? failedInfo) {
    switch (cs) {
      case ServerConnectionState.disconnected:
        return s.disconnected;
      case ServerConnectionState.connected:
        if (temp == '') {
          if (upTime == '') {
            return s.serverTabLoading;
          } else {
            return upTime;
          }
        } else {
          if (upTime == '') {
            return temp;
          } else {
            return '$temp | $upTime';
          }
        }
      case ServerConnectionState.connecting:
        return s.serverTabConnecting;
      case ServerConnectionState.failed:
        if (failedInfo == null) {
          return s.serverTabFailed;
        }
        if (failedInfo.contains('encypted')) {
          return s.serverTabPlzSave;
        }
        return failedInfo;
      default:
        return s.serverTabUnkown;
    }
  }

  Widget _buildIOData(String up, String down) {
    final statusTextStyle = TextStyle(
        fontSize: 9, color: _theme.textTheme.bodyText1!.color!.withAlpha(177));
    return SizedBox(
      width: _media.size.width * 0.2,
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
      width: _media.size.width * 0.2,
      child: Stack(
        children: [
          Center(
            child: CircleChart(
              progressColor: _primaryColor,
              progressNumber: percent,
              maxNumber: 100,
              width: 53,
              height: 53,
            ),
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
    );
  }

  @override
  bool get wantKeepAlive => true;

  @override
  Future<void> afterFirstLayout(BuildContext context) async {
    await GetIt.I.allReady();
    await _serverProvider.loadLocalData();
    await _serverProvider.refreshData();
    _serverProvider.startAutoRefresh();
  }
}
