import 'package:after_layout/after_layout.dart';
import 'package:circle_chart/circle_chart.dart';
import 'package:dropdown_button2/dropdown_button2.dart';
import 'package:flutter/material.dart';
import 'package:get_it/get_it.dart';
import 'package:marquee/marquee.dart';
import 'package:provider/provider.dart';
import 'package:pull_to_refresh/pull_to_refresh.dart';
import 'package:toolbox/core/route.dart';
import 'package:toolbox/data/model/server/server.dart';
import 'package:toolbox/data/model/server/server_connection_state.dart';
import 'package:toolbox/data/model/server/server_private_info.dart';
import 'package:toolbox/data/model/server/server_status.dart';
import 'package:toolbox/data/provider/server.dart';
import 'package:toolbox/data/res/color.dart';
import 'package:toolbox/data/store/setting.dart';
import 'package:toolbox/locator.dart';
import 'package:toolbox/view/page/server/detail.dart';
import 'package:toolbox/view/page/server/edit.dart';
import 'package:toolbox/view/page/snippet/list.dart';
import 'package:toolbox/view/widget/round_rect_card.dart';

class ServerPage extends StatefulWidget {
  final TabController tabController;
  const ServerPage(this.tabController, {Key? key}) : super(key: key);

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
    if (widget.tabController.index == 0) {
      FocusScope.of(context).unfocus();
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final autoUpdate =
        locator<SettingStore>().serverStatusUpdateInterval.fetch() != 0;
    final child = Consumer<ServerProvider>(builder: (_, pro, __) {
      if (pro.servers.isEmpty) {
        return const Center(
          child: Text(
            'There is no server.\nClick the fab to add one.',
            textAlign: TextAlign.center,
          ),
        );
      }
      return ListView.separated(
        padding: const EdgeInsets.all(7),
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
        tooltip: 'add a server',
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
          padding: const EdgeInsets.symmetric(horizontal: 11),
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
                      ? ConstrainedBox(
                          constraints: BoxConstraints(
                              maxWidth: _media.size.width * 0.57,
                              maxHeight: 15),
                          child: Marquee(
                              accelerationDuration: const Duration(seconds: 3),
                              accelerationCurve: Curves.linear,
                              decelerationDuration: const Duration(seconds: 3),
                              decelerationCurve: Curves.linear,
                              text: topRightStr,
                              textScaleFactor: 1.0,
                              style: style),
                        )
                      : Text(topRightStr, style: style, textScaleFactor: 1.0),
                  const SizedBox(
                    width: 13,
                  ),
                  DropdownButtonHideUnderline(
                    child: DropdownButton2(
                      customButton: const Icon(
                        Icons.list_alt,
                        size: 19,
                      ),
                      customItemsIndexes: const [3],
                      customItemsHeight: 8,
                      items: [
                        ...MenuItems.firstItems.map(
                          (item) => DropdownMenuItem<MenuItem>(
                            value: item,
                            child: MenuItems.buildItem(item),
                          ),
                        ),
                        const DropdownMenuItem<Divider>(
                            enabled: false, child: Divider()),
                        ...MenuItems.secondItems.map(
                          (item) => DropdownMenuItem<MenuItem>(
                            value: item,
                            child: MenuItems.buildItem(item),
                          ),
                        ),
                      ],
                      onChanged: (value) {
                        final item = value as MenuItem;
                        switch (item) {
                          case MenuItems.sftp:
                            //Do something
                            break;
                          case MenuItems.apt:
                            //Do something
                            break;
                          case MenuItems.snippet:
                            AppRoute(
                                    SnippetListPage(
                                      spi: spi,
                                    ),
                                    'snippet list')
                                .go(context);
                            break;
                          case MenuItems.edit:
                            AppRoute(
                                    ServerEditPage(
                                      spi: spi,
                                    ),
                                    'Edit server info page')
                                .go(context);
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
                  ),
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
            _buildIOData('Conn:\n' + ss.tcp.maxConn.toString(),
                'Fail:\n' + ss.tcp.fail.toString()),
            _buildIOData('Total:\n' + rootDisk.size,
                'Used:\n' + rootDisk.usedPercent.toString() + '%')
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
        )
      ],
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
        return 'Disconnected';
      case ServerConnectionState.connected:
        return temp == '' ? (upTime == '' ? 'Loading...' : upTime) : temp;
      case ServerConnectionState.connecting:
        return 'Connecting...';
      case ServerConnectionState.failed:
        if (failedInfo == null) {
          return 'Failed';
        }
        if (failedInfo.contains('encypted')) {
          return 'Please "save" this private key again.';
        }
        return failedInfo;
      default:
        return 'Unknown State';
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

class MenuItem {
  final String text;
  final IconData icon;

  const MenuItem({
    required this.text,
    required this.icon,
  });
}

class MenuItems {
  static const List<MenuItem> firstItems = [sftp, snippet, apt];
  static const List<MenuItem> secondItems = [edit];

  static const sftp = MenuItem(text: 'SFTP', icon: Icons.home);
  static const snippet = MenuItem(text: 'Snippet', icon: Icons.label);
  static const apt = MenuItem(text: 'Apt', icon: Icons.system_security_update);
  static const edit = MenuItem(text: 'Edit', icon: Icons.settings);

  static Widget buildItem(MenuItem item) {
    return Row(
      children: [
        Icon(item.icon),
        const SizedBox(
          width: 10,
        ),
        Text(
          item.text,
        ),
      ],
    );
  }

  static onChanged(BuildContext context, MenuItem item) {
    switch (item) {
      case MenuItems.sftp:
        //Do something
        break;
      case MenuItems.apt:
        //Do something
        break;
      case MenuItems.snippet:
        //Do something
        break;
      case MenuItems.edit:
        //Do something
        break;
    }
  }
}
