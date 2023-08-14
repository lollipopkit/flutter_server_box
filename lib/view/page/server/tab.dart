import 'dart:io' show Directory, File, Platform, Process;

import 'package:after_layout/after_layout.dart';
import 'package:circle_chart/circle_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/l10n.dart';
import 'package:get_it/get_it.dart';
import 'package:provider/provider.dart';
import 'package:toolbox/core/extension/order.dart';
import 'package:toolbox/data/model/app/net_view.dart';
import 'package:toolbox/data/model/server/snippet.dart';
import 'package:toolbox/data/provider/snippet.dart';
import 'package:toolbox/view/page/process.dart';
import 'package:toolbox/view/widget/tag/picker.dart';
import 'package:toolbox/view/widget/tag/switcher.dart';

import '../../../core/route.dart';
import '../../../core/utils/misc.dart' hide pathJoin;
import '../../../core/utils/platform.dart';
import '../../../core/utils/server.dart';
import '../../../core/utils/ui.dart';
import '../../../data/model/server/disk.dart';
import '../../../data/model/server/server.dart';
import '../../../data/model/server/server_private_info.dart';
import '../../../data/model/server/server_status.dart';
import '../../../data/provider/server.dart';
import '../../../data/res/color.dart';
import '../../../data/model/app/menu.dart';
import '../../../data/res/ui.dart';
import '../../../data/store/setting.dart';
import '../../../locator.dart';
import '../../widget/popup_menu.dart';
import '../../widget/round_rect_card.dart';
import '../docker.dart';
import '../pkg.dart';
import '../storage/sftp.dart';
import '../ssh/term.dart';
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

  String? _tag;

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
      body: _buildBody(),
      floatingActionButton: FloatingActionButton(
        onPressed: () => AppRoute(
          const ServerEditPage(),
          'Add server info page',
        ).go(context),
        tooltip: _s.addAServer,
        heroTag: 'server',
        child: const Icon(Icons.add),
      ),
    );
  }

  Widget _buildBody() {
    return RefreshIndicator(
      onRefresh: () async =>
          await _serverProvider.refreshData(onlyFailed: true),
      child: Consumer<ServerProvider>(
        builder: (_, pro, __) {
          if (!pro.tags.contains(_tag)) {
            _tag = null;
          }
          if (pro.serverOrder.isEmpty) {
            return Center(
              child: Text(
                _s.serverTabEmpty,
                textAlign: TextAlign.center,
              ),
            );
          }
          final filtered = pro.serverOrder
              .where((e) => pro.servers.containsKey(e))
              .where((e) =>
                  _tag == null ||
                  (pro.servers[e]?.spi.tags?.contains(_tag) ?? false))
              .toList();
          return ReorderableListView.builder(
            header: TagSwitcher(
              tags: pro.tags,
              width: _media.size.width,
              onTagChanged: (p0) => setState(() {
                _tag = p0;
              }),
              initTag: _tag,
              all: _s.all,
            ),
            footer: const SizedBox(height: 77),
            padding: const EdgeInsets.fromLTRB(7, 10, 7, 7),
            onReorder: (oldIndex, newIndex) => setState(() {
              pro.serverOrder.moveByItem(
                filtered,
                oldIndex,
                newIndex,
                property: _settingStore.serverOrder,
              );
            }),
            buildDefaultDragHandles: false,
            itemBuilder: (_, index) => ReorderableDelayedDragStartListener(
              key: ValueKey('$_tag${filtered[index]}'),
              index: index,
              child: _buildEachServerCard(pro.servers[filtered[index]]),
            ),
            itemCount: filtered.length,
          );
        },
      ),
    );
  }

  Widget _buildEachServerCard(Server? si) {
    if (si == null) {
      return placeholder;
    }
    return GestureDetector(
      key: Key(si.spi.id + (_tag ?? '')),
      onTap: () {
        if (si.state.canViewDetails) {
          AppRoute(
            ServerDetailPage(si.spi.id),
            'server detail page',
          ).go(context);
        } else if (si.status.failedInfo != null) {
          _showFailReason(si.status);
        }
      },
      child: RoundRectCard(
        Padding(
          padding: const EdgeInsets.all(13),
          child: _buildRealServerCard(si.status, si.state, si.spi),
        ),
      ),
    );
  }

  Widget _buildRealServerCard(
    ServerStatus ss,
    ServerState cs,
    ServerPrivateInfo spi,
  ) {
    final rootDisk = findRootDisk(ss.disk);
    late final List<Widget> children;
    var height = 23.0;
    if (cs != ServerState.finished) {
      children = [
        _buildServerCardTitle(ss, cs, spi),
      ];
    } else {
      height = 137;
      children = [
        _buildServerCardTitle(ss, cs, spi),
        height13,
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            _buildPercentCircle(ss.cpu.usedPercent()),
            _buildPercentCircle(ss.mem.usedPercent * 100),
            _buildNet(ss),
            _buildIOData(
                'Total:\n${rootDisk?.size}', 'Used:\n${rootDisk?.usedPercent}%')
          ],
        ),
        height13,
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
      ];
    }

    return AnimatedContainer(
      duration: const Duration(milliseconds: 377),
      curve: Curves.fastEaseInToSlowEaseOut,
      height: height,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: children,
      ),
    );
  }

  Widget _buildServerCardTitle(
    ServerStatus ss,
    ServerState cs,
    ServerPrivateInfo spi,
  ) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 7),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Text(
                spi.name,
                style: textSize13Bold,
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
              _buildTopRightText(ss, cs),
              width13,
              _buildSSHBtn(spi),
              _buildMoreBtn(spi),
            ],
          )
        ],
      ),
    );
  }

  Widget _buildTopRightText(ServerStatus ss, ServerState cs) {
    final topRightStr = _getTopRightStr(
      cs,
      ss.temps.first,
      ss.uptime,
      ss.failedInfo,
    );
    if (cs == ServerState.failed && ss.failedInfo != null) {
      return GestureDetector(
        onTap: () => _showFailReason(ss),
        child: Text(
          _s.viewErr,
          style: textSize12Grey,
          textScaleFactor: 1.0,
        ),
      );
    }
    return Text(
      topRightStr,
      style: textSize12Grey,
      textScaleFactor: 1.0,
    );
  }

  void _showFailReason(ServerStatus ss) {
    showRoundDialog(
      context: context,
      title: Text(_s.error),
      child: SingleChildScrollView(
        child: Text(ss.failedInfo ?? _s.unknownError),
      ),
      actions: [
        TextButton(
          onPressed: () => copy2Clipboard(ss.failedInfo!),
          child: Text(_s.copy),
        )
      ],
    );
  }

  Widget _buildSSHBtn(ServerPrivateInfo spi) {
    return GestureDetector(
      child: const Icon(Icons.terminal, size: 21),
      onTap: () => gotoSSH(spi),
    );
  }

  Widget _buildMoreBtn(ServerPrivateInfo spi) {
    return PopupMenu(
      items: ServerTabMenuType.values.map((e) => e.build(_s)).toList(),
      padding: const EdgeInsets.symmetric(horizontal: 10),
      onSelected: (ServerTabMenuType value) async {
        switch (value) {
          case ServerTabMenuType.pkg:
            AppRoute(PkgManagePage(spi), 'pkg manage').checkClientAndGo(
              context: context,
              s: _s,
              id: spi.id,
            );
            break;
          case ServerTabMenuType.sftp:
            AppRoute(SftpPage(spi), 'SFTP').checkClientAndGo(
              context: context,
              s: _s,
              id: spi.id,
            );
            break;
          case ServerTabMenuType.snippet:
            final provider = locator<SnippetProvider>();
            final snippets = await showDialog<List<Snippet>>(
              context: context,
              builder: (_) => TagPicker<Snippet>(
                items: provider.snippets,
                containsTag: (t, tag) => t.tags?.contains(tag) ?? false,
                tags: provider.tags.toSet(),
                name: (t) => t.name,
              ),
            );
            if (snippets == null) {
              return;
            }
            final result = await _serverProvider.runSnippets(spi.id, snippets);
            if (result != null && result.isNotEmpty) {
              showRoundDialog(
                context: context,
                title: Text(_s.result),
                child: Text(result),
                actions: [
                  TextButton(
                    onPressed: () => copy2Clipboard(result),
                    child: Text(_s.copy),
                  )
                ],
              );
            }
            break;
          case ServerTabMenuType.edit:
            AppRoute(ServerEditPage(spi: spi), 'Edit server info').go(context);
            break;
          case ServerTabMenuType.docker:
            AppRoute(DockerManagePage(spi), 'Docker manage').checkClientAndGo(
              context: context,
              s: _s,
              id: spi.id,
            );
            break;
          case ServerTabMenuType.process:
            AppRoute(ProcessPage(spi: spi), 'process page').checkClientAndGo(
              context: context,
              s: _s,
              id: spi.id,
            );
            break;
        }
      },
    );
  }

  Widget _buildNet(ServerStatus ss) {
    return ValueListenableBuilder<NetViewType>(
      valueListenable: _settingStore.netViewType.listenable(),
      builder: (_, val, __) {
        final data = val.build(ss);
        return AnimatedSwitcher(
          duration: const Duration(milliseconds: 177),
          child: _buildIOData(data.up, data.down),
        );
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

  String _getTopRightStr(
    ServerState cs,
    double? temp,
    String upTime,
    String? failedInfo,
  ) {
    switch (cs) {
      case ServerState.disconnected:
        return _s.disconnected;
      case ServerState.finished:
        final tempStr = temp == null ? '' : '${temp.toStringAsFixed(1)}°C';
        final items = [tempStr, upTime];
        final str = items.where((element) => element.isNotEmpty).join(' | ');
        if (str.isEmpty) return _s.noResult;
        return str;
      case ServerState.loading:
        return _s.serverTabLoading;
      case ServerState.connected:
        return _s.connected;
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

  Future<void> gotoSSH(ServerPrivateInfo spi) async {
    // as a `Mobile first` app -> handle mobile first
    //
    // run built-in ssh on macOS due to incompatibility
    if (!isDesktop || isMacOS) {
      AppRoute(SSHPage(spi: spi), 'ssh page').go(context);
      return;
    }
    final extraArgs = <String>[];
    if (spi.port != 22) {
      extraArgs.addAll(['-p', '${spi.port}']);
    }

    final path = () {
      final tempKeyFileName = 'srvbox_pk_${spi.pubKeyId}';
      return pathJoin(Directory.systemTemp.path, tempKeyFileName);
    }();
    final file = File(path);
    final shouldGenKey = spi.pubKeyId != null;
    if (shouldGenKey) {
      if (await file.exists()) {
        await file.delete();
      }
      await file.writeAsString(getPrivateKey(spi.pubKeyId!));
      extraArgs.addAll(["-i", path]);
    }

    List<String> sshCommand = ["ssh", "${spi.user}@${spi.ip}"] + extraArgs;
    final system = Platform.operatingSystem;
    switch (system) {
      case "windows":
        await Process.start("cmd", ["/c", "start"] + sshCommand);
        break;
      case "linux":
        await Process.start("x-terminal-emulator", ["-e"] + sshCommand);
        break;
      default:
        showSnackBar(context, Text('Mismatch system: $system'));
    }
    // For security reason, delete the private key file after use
    if (shouldGenKey) {
      if (!await file.exists()) return;
      await Future.delayed(const Duration(seconds: 2), file.delete);
    }
  }

  @override
  bool get wantKeepAlive => true;

  @override
  Future<void> afterFirstLayout(BuildContext context) async {
    await GetIt.I.allReady();
    if (_serverProvider.servers.isEmpty) {
      await _serverProvider.loadLocalData();
    }
    _serverProvider.startAutoRefresh();
  }
}
