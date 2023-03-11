import 'package:after_layout/after_layout.dart';
import 'package:circle_chart/circle_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/l10n.dart';
import 'package:get_it/get_it.dart';
import 'package:provider/provider.dart';

import '../../../core/route.dart';
import '../../../core/utils/ui.dart';
import '../../../data/model/server/server.dart';
import '../../../data/model/server/server_private_info.dart';
import '../../../data/model/server/server_status.dart';
import '../../../data/provider/server.dart';
import '../../../data/provider/snippet.dart';
import '../../../data/res/color.dart';
import '../../../data/res/menu.dart';
import '../../../data/res/ui.dart';
import '../../../data/res/url.dart';
import '../../../data/store/setting.dart';
import '../../../locator.dart';
import '../../widget/dropdown_menu.dart';
import '../../widget/picker.dart';
import '../../widget/round_rect_card.dart';
import '../../widget/url_text.dart';
import '../docker.dart';
import '../pkg.dart';
import '../sftp/view.dart';
import '../snippet/edit.dart';
import '../ssh.dart';
import 'detail.dart';
import 'edit.dart';

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
  late SettingStore _settingStore;
  late S _s;

  @override
  void initState() {
    super.initState();
    _serverProvider = locator<ServerProvider>();
    _settingStore = locator<SettingStore>();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _media = MediaQuery.of(context);
    _theme = Theme.of(context);
    _s = S.of(context)!;
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return Scaffold(
      body: RefreshIndicator(
        onRefresh: () async =>
            await _serverProvider.refreshData(onlyFailed: true),
        child: Consumer<ServerProvider>(
          builder: (_, pro, __) {
            if (pro.servers.isEmpty) {
              return Center(
                child: Text(
                  _s.serverTabEmpty,
                  textAlign: TextAlign.center,
                ),
              );
            }
            return ListView.separated(
              padding: const EdgeInsets.all(7),
              controller: ScrollController(),
              physics: const AlwaysScrollableScrollPhysics(),
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
          },
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => AppRoute(
          const ServerEditPage(),
          'Add server info page',
        ).go(context),
        tooltip: _s.addAServer,
        heroTag: 'server page fab',
        child: const Icon(Icons.add),
      ),
    );
  }

  Widget _buildEachServerCard(Server si) {
    return RoundRectCard(
      InkWell(
        onLongPress: () => AppRoute(
                ServerEditPage(
                  spi: si.spi,
                ),
                'Edit server info page')
            .go(context),
        child: Padding(
          padding: const EdgeInsets.all(13),
          child: _buildRealServerCard(si.status, si.spi.name, si.cs, si.spi),
        ),
        onTap: () => AppRoute(ServerDetailPage(si.spi.id), 'server detail page')
            .go(context),
      ),
    );
  }

  Widget _buildRealServerCard(ServerStatus ss, String serverName,
      ServerState cs, ServerPrivateInfo spi) {
    final rootDisk = ss.disk.firstWhere((element) => element.loc == '/');

    final topRightStr =
        getTopRightStr(cs, ss.cpu.temp, ss.uptime, ss.failedInfo);
    final hasError = cs == ServerState.failed && ss.failedInfo != null;
    final style = TextStyle(
        color: _theme.textTheme.bodyLarge!.color!.withAlpha(100), fontSize: 11);

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
                              context, _s.error, Text(ss.failedInfo ?? ''), []),
                          child: Text(
                            _s.clickSee,
                            style: style,
                            textScaleFactor: 1.0,
                          ))
                      : Text(topRightStr, style: style, textScaleFactor: 1.0),
                  const SizedBox(width: 9),
                  _buildSSHBtn(spi),
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
            _buildPercentCircle(ss.cpu.usedPercent()),
            _buildPercentCircle(ss.mem.used / ss.mem.total * 100),
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

  Widget _buildSSHBtn(ServerPrivateInfo spi) {
    return GestureDetector(
      child: const Icon(
        Icons.terminal,
        size: 21,
      ),
      onTap: () async {
        if (_settingStore.firstTimeUseSshTerm.fetch()!) {
          await showRoundDialog(
            context,
            _s.attention,
            UrlText(
              text: _s.sshTip(issueUrl),
              replace: 'Github Issue',
            ),
            [
              TextButton(
                onPressed: () {
                  Navigator.of(context).pop();
                  AppRoute(SSHPage(spi: spi), 'ssh page').go(context);
                },
                child: Text(_s.ok),
              )
            ],
          );
          _settingStore.firstTimeUseSshTerm.put(false);
        } else {
          AppRoute(SSHPage(spi: spi), 'ssh page').go(context);
        }
      },
    );
  }

  Widget _buildMoreBtn(ServerPrivateInfo spi) {
    return buildPopuopMenu(
      items: <PopupMenuEntry>[
        ...ServerTabMenuItems.firstItems.map(
          (item) => PopupMenuItem<DropdownBtnItem>(
            value: item,
            child: item.build(_s),
          ),
        ),
        const PopupMenuDivider(height: 1),
        ...ServerTabMenuItems.secondItems.map(
          (item) => PopupMenuItem<DropdownBtnItem>(
            value: item,
            child: item.build(_s),
          ),
        ),
      ],
      onSelected: (value) {
        switch (value as DropdownBtnItem) {
          case ServerTabMenuItems.pkg:
            AppRoute(PkgManagePage(spi), 'pkg manage').go(context);
            break;
          case ServerTabMenuItems.sftp:
            AppRoute(SFTPPage(spi), 'SFTP').go(context);
            break;
          case ServerTabMenuItems.snippet:
            _showSnippetDialog(spi.id);
            break;
          case ServerTabMenuItems.edit:
            AppRoute(ServerEditPage(spi: spi), 'Edit server info').go(context);
            break;
          case ServerTabMenuItems.docker:
            AppRoute(DockerManagePage(spi), 'Docker manage').go(context);
            break;
        }
      },
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

  String getTopRightStr(
      ServerState cs, String temp, String upTime, String? failedInfo) {
    switch (cs) {
      case ServerState.disconnected:
        return _s.disconnected;
      case ServerState.connected:
        if (temp == '') {
          if (upTime == '') {
            return _s.serverTabLoading;
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
      case ServerState.connecting:
        return _s.serverTabConnecting;
      case ServerState.failed:
        if (failedInfo == null) {
          return _s.serverTabFailed;
        }
        if (failedInfo.contains('encypted')) {
          return _s.serverTabPlzSave;
        }
        return failedInfo;
      default:
        return _s.serverTabUnkown;
    }
  }

  Widget _buildIOData(String up, String down) {
    final statusTextStyle = TextStyle(
        fontSize: 9, color: _theme.textTheme.bodyLarge!.color!.withAlpha(177));
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
              progressColor: primaryColor,
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

  void _showSnippetDialog(String id) {
    final provider = locator<SnippetProvider>();
    if (provider.snippets.isEmpty) {
      showRoundDialog(
        context,
        _s.attention,
        Text(_s.noSavedSnippet),
        [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(_s.ok),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              AppRoute(const SnippetEditPage(), 'edit snippet').go(context);
            },
            child: Text(_s.addOne),
          )
        ],
      );
      return;
    }

    var snippet = provider.snippets.first;
    showRoundDialog(
      context,
      _s.choose,
      buildPicker(
        provider.snippets.map((e) => Text(e.name)).toList(),
        (idx) => snippet = provider.snippets[idx],
      ),
      [
        TextButton(
          onPressed: () async {
            Navigator.of(context).pop();
            final result = await _serverProvider.runSnippet(id, snippet);
            showRoundDialog(
              context,
              _s.result,
              Text(result ?? _s.error, style: textSize13),
              [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: Text(_s.ok),
                )
              ],
            );
          },
          child: Text(_s.run),
        )
      ],
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
