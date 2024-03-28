import 'package:after_layout/after_layout.dart';
import 'package:flutter/material.dart';
import 'package:get_it/get_it.dart';
import 'package:provider/provider.dart';
import 'package:toolbox/core/extension/context/common.dart';
import 'package:toolbox/core/extension/context/dialog.dart';
import 'package:toolbox/core/extension/context/locale.dart';
import 'package:toolbox/core/extension/media_queryx.dart';
import 'package:toolbox/core/extension/numx.dart';
import 'package:toolbox/core/extension/ssh_client.dart';
import 'package:toolbox/core/utils/platform/base.dart';
import 'package:toolbox/core/utils/share.dart';
import 'package:toolbox/data/model/app/shell_func.dart';
import 'package:toolbox/data/model/server/try_limiter.dart';
import 'package:toolbox/data/res/provider.dart';
import 'package:toolbox/data/res/store.dart';
import 'package:toolbox/view/widget/percent_circle.dart';

import '../../../core/route.dart';
import '../../../data/model/app/net_view.dart';
import '../../../data/model/server/server.dart';
import '../../../data/model/server/server_private_info.dart';
import '../../../data/provider/server.dart';
import '../../../data/res/ui.dart';
import '../../widget/cardx.dart';
import '../../widget/server_func_btns.dart';
import '../../widget/tag.dart';

class ServerPage extends StatefulWidget {
  const ServerPage({super.key});

  @override
  _ServerPageState createState() => _ServerPageState();
}

class _ServerPageState extends State<ServerPage>
    with AutomaticKeepAliveClientMixin, AfterLayoutMixin {
  late MediaQueryData _media;

  late double _textFactorDouble;
  late TextScaler _textFactor;

  final _cardsStatus = <String, _CardNotifier>{};

  String? _tag;
  bool _useDoubleColumn = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _media = MediaQuery.of(context);
    _useDoubleColumn = _media.useDoubleColumn &&
        Stores.setting.doubleColumnServersPage.fetch();
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return Scaffold(
      appBar: _buildTagsSwitcher(Pros.server),
      body: ListenableBuilder(
        listenable: Stores.setting.textFactor.listenable(),
        builder: (_, __) {
          _textFactorDouble = Stores.setting.textFactor.fetch();
          _textFactor = TextScaler.linear(_textFactorDouble);
          return _buildBody();
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => AppRoute.serverEdit().go(context),
        tooltip: l10n.addAServer,
        heroTag: 'server',
        child: const Icon(Icons.add),
      ),
    );
  }

  Widget _buildBody() {
    final child = Consumer<ServerProvider>(
      builder: (_, pro, __) {
        if (!pro.tags.value.contains(_tag)) {
          _tag = null;
        }
        if (pro.serverOrder.isEmpty) {
          return Center(
            child: Text(
              l10n.serverTabEmpty,
              textAlign: TextAlign.center,
            ),
          );
        }

        final filtered = _filterServers(pro);
        if (_useDoubleColumn &&
            Stores.setting.doubleColumnServersPage.fetch()) {
          return _buildBodyMedium(pro: pro, filtered: filtered);
        }
        return _buildBodySmall(pro: pro, filtered: filtered);
      },
    );

    // Desktop doesn't support pull to refresh
    if (isDesktop) return child;

    return RefreshIndicator(
      onRefresh: () async => await Pros.server.refresh(onlyFailed: true),
      child: child,
    );
  }

  TagSwitcher _buildTagsSwitcher(ServerProvider provider) {
    return TagSwitcher(
      tags: provider.tags,
      width: _media.size.width,
      onTagChanged: (p0) => setState(() {
        _tag = p0;
      }),
      initTag: _tag,
    );
  }

  Widget _buildBodySmall({
    required ServerProvider pro,
    required List<String> filtered,
    EdgeInsets? padding = const EdgeInsets.fromLTRB(7, 0, 7, 7),
  }) {
    final count = filtered.length + 1;
    return ListView.builder(
      padding: padding,
      itemCount: count,
      itemBuilder: (_, index) {
        // Issue #130
        if (index == count - 1) return UIs.height77;
        return _buildEachServerCard(pro.pick(id: filtered[index]));
      },
    );
  }

  Widget _buildBodyMedium({
    required ServerProvider pro,
    required List<String> filtered,
  }) {
    final mid = (filtered.length / 2).ceil();
    final filteredLeft = filtered.sublist(0, mid);
    final filteredRight = filtered.sublist(mid);
    return Row(
      children: [
        Expanded(
          child: _buildBodySmall(
            pro: pro,
            filtered: filteredLeft,
            padding: const EdgeInsets.only(left: 7),
          ),
        ),
        Expanded(
          child: _buildBodySmall(
            pro: pro,
            filtered: filteredRight,
            padding: const EdgeInsets.only(right: 7),
          ),
        )
      ],
    );
  }

  Widget _buildEachServerCard(Server? srv) {
    if (srv == null) {
      return UIs.placeholder;
    }

    return CardX(
      key: Key(srv.spi.id + (_tag ?? '')),
      child: InkWell(
        onTap: () {
          if (srv.canViewDetails) {
            AppRoute.serverDetail(spi: srv.spi).go(context);
          } else {
            AppRoute.serverEdit(spi: srv.spi).go(context);
          }
        },
        onLongPress: () {
          if (srv.state == ServerState.finished) {
            final id = srv.spi.id;
            final cardStatus = _getCardNoti(id);
            cardStatus.value = cardStatus.value.copyWith(
              flip: !cardStatus.value.flip,
            );
          } else {
            AppRoute.serverEdit(spi: srv.spi).go(context);
          }
        },
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 13, horizontal: 7),
          child: _buildRealServerCard(srv),
        ),
      ),
    );
  }

  /// The child's width mat not equal to 1/4 of the screen width,
  /// so we need to wrap it with a SizedBox.
  Widget _wrapWithSizedbox(Widget child, [bool circle = false]) {
    var width = (_media.size.width - 74) / (circle ? 4 : 4.3);
    if (_useDoubleColumn) width /= 2;
    return SizedBox(
      width: width,
      child: child,
    );
  }

  Widget _buildRealServerCard(Server srv) {
    final id = srv.spi.id;
    final cardStatus = _getCardNoti(id);
    final title = _buildServerCardTitle(srv);

    return ListenableBuilder(
      listenable: cardStatus,
      builder: (_, __) {
        final List<Widget> children = [title];
        if (srv.state == ServerState.finished) {
          if (cardStatus.value.flip) {
            children.addAll(_buildFlippedCard(srv));
          } else {
            children.addAll(_buildNormalCard(srv.status, srv.spi));
          }
        }

        return AnimatedContainer(
          duration: const Duration(milliseconds: 377),
          curve: Curves.fastEaseInToSlowEaseOut,
          height: _calcCardHeight(srv.state, cardStatus.value.flip),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.start,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: children,
          ),
        );
      },
    );
  }

  List<Widget> _buildFlippedCard(Server srv) {
    return [
      UIs.height13,
      Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          IconButton(
            onPressed: () => _askFor(
              func: () async {
                if (Stores.setting.showSuspendTip.fetch()) {
                  await context.showRoundDialog(
                    title: Text(l10n.attention),
                    child: Text(l10n.suspendTip),
                  );
                  Stores.setting.showSuspendTip.put(false);
                }
                srv.client?.execWithPwd(
                  ShellFunc.suspend.exec,
                  context: context,
                  id: srv.id,
                );
              },
              typ: l10n.suspend,
              name: srv.spi.name,
            ),
            icon: const Icon(Icons.stop),
            tooltip: l10n.suspend,
          ),
          IconButton(
            onPressed: () => _askFor(
              func: () => srv.client?.execWithPwd(
                ShellFunc.shutdown.exec,
                context: context,
                id: srv.id,
              ),
              typ: l10n.shutdown,
              name: srv.spi.name,
            ),
            icon: const Icon(Icons.power_off),
            tooltip: l10n.shutdown,
          ),
          IconButton(
            onPressed: () => _askFor(
              func: () => srv.client?.execWithPwd(
                ShellFunc.reboot.exec,
                context: context,
                id: srv.id,
              ),
              typ: l10n.reboot,
              name: srv.spi.name,
            ),
            icon: const Icon(Icons.restart_alt),
            tooltip: l10n.reboot,
          ),
          IconButton(
            onPressed: () => AppRoute.serverEdit(spi: srv.spi).go(context),
            icon: const Icon(Icons.edit),
            tooltip: l10n.edit,
          )
        ],
      )
    ];
  }

  List<Widget> _buildNormalCard(ServerStatus ss, ServerPrivateInfo spi) {
    return [
      UIs.height13,
      Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          _wrapWithSizedbox(PercentCircle(percent: ss.cpu.usedPercent()), true),
          _wrapWithSizedbox(
            PercentCircle(percent: ss.mem.usedPercent * 100),
            true,
          ),
          _wrapWithSizedbox(_buildNet(ss, spi.id)),
          _wrapWithSizedbox(_buildDisk(ss, spi.id)),
        ],
      ),
      UIs.height13,
      if (Stores.setting.moveOutServerTabFuncBtns.fetch() &&
          // Discussion #146
          !Stores.setting.serverTabUseOldUI.fetch())
        SizedBox(
          height: 27,
          child: ServerFuncBtns(spi: spi),
        ),
    ];
  }

  Widget _buildServerCardTitle(Server s) {
    Widget rightCorner = UIs.placeholder;
    if (s.state == ServerState.failed) {
      rightCorner = InkWell(
        onTap: () {
          TryLimiter.reset(s.spi.id);
          Pros.server.refresh(spi: s.spi);
        },
        child: const Padding(
          padding: EdgeInsets.symmetric(horizontal: 7),
          child: Icon(
            Icons.refresh,
            size: 21,
            color: Colors.grey,
          ),
        ),
      );
    } else if (!(s.spi.autoConnect ?? true) &&
        s.state == ServerState.disconnected) {
      rightCorner = InkWell(
        onTap: () => Pros.server.refresh(spi: s.spi),
        child: const Padding(
          padding: EdgeInsets.symmetric(horizontal: 7),
          child: Icon(
            Icons.link,
            size: 21,
            color: Colors.grey,
          ),
        ),
      );
    } else if (Stores.setting.serverTabUseOldUI.fetch()) {
      rightCorner = ServerFuncBtnsTopRight(spi: s.spi);
    }
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 7),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          ConstrainedBox(
            constraints: BoxConstraints(maxWidth: _media.size.width / 2.3),
            child: Text(
              s.spi.name,
              style: UIs.text13Bold,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const Icon(
            Icons.keyboard_arrow_right,
            size: 17,
            color: Colors.grey,
          ),
          const Spacer(),
          _buildTopRightText(s),
          rightCorner,
        ],
      ),
    );
  }

  Widget _buildTopRightText(Server s) {
    if (s.state == ServerState.failed && s.status.err != null) {
      return GestureDetector(
        onTap: () => _showFailReason(s.status),
        child: Text(
          l10n.viewErr,
          style: UIs.text13Grey,
        ),
      );
    }
    return Text(
      s.topRightStr,
      style: UIs.text13Grey,
    );
  }

  void _showFailReason(ServerStatus ss) {
    context.showRoundDialog(
      title: Text(l10n.error),
      child: SingleChildScrollView(
        child: Text(ss.err ?? l10n.unknownError),
      ),
      actions: [
        TextButton(
          onPressed: () => Shares.copy(ss.err!),
          child: Text(l10n.copy),
        )
      ],
    );
  }

  Widget _buildDisk(ServerStatus ss, String id) {
    final cardNoti = _getCardNoti(id);
    return ListenableBuilder(
      listenable: cardNoti,
      builder: (_, __) {
        final isSpeed = cardNoti.value.diskIO ??
            !Stores.setting.serverTabPreferDiskAmount.fetch();

        final (r, w) = ss.diskIO.cachedAllSpeed;

        return AnimatedSwitcher(
          duration: const Duration(milliseconds: 377),
          transitionBuilder: (Widget child, Animation<double> animation) {
            return FadeTransition(opacity: animation, child: child);
          },
          child: _buildIOData(
            isSpeed
                ? '${l10n.read}:\n$r'
                : 'Total:\n${ss.diskUsage?.size.kb2Str}',
            isSpeed
                ? '${l10n.write}:\n$w'
                : 'Used:\n${ss.diskUsage?.used.kb2Str}',
            onTap: () {
              cardNoti.value = cardNoti.value.copyWith(diskIO: !isSpeed);
            },
            key: ValueKey(isSpeed),
          ),
        );
      },
    );
  }

  Widget _buildNet(ServerStatus ss, String id) {
    final cardNoti = _getCardNoti(id);
    final type = cardNoti.value.net ?? Stores.setting.netViewType.fetch();
    final (a, b) = type.build(ss);
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 377),
      transitionBuilder: (Widget child, Animation<double> animation) {
        return FadeTransition(opacity: animation, child: child);
      },
      child: _buildIOData(
        a,
        b,
        onTap: () {
          cardNoti.value = cardNoti.value.copyWith(net: type.next);
        },
        key: ValueKey(type),
      ),
    );
  }

  Widget _buildIOData(
    String up,
    String down, {
    void Function()? onTap,
    Key? key,
  }) {
    final child = Column(
      children: [
        Text(
          up,
          style: const TextStyle(fontSize: 10, color: Colors.grey),
          textAlign: TextAlign.center,
          textScaler: _textFactor,
        ),
        const SizedBox(height: 3),
        Text(
          down,
          style: const TextStyle(fontSize: 10, color: Colors.grey),
          textAlign: TextAlign.center,
          textScaler: _textFactor,
        )
      ],
    );
    if (onTap == null) return child;
    return IconButton(
      key: key,
      padding: const EdgeInsets.symmetric(horizontal: 3),
      onPressed: onTap,
      icon: child,
    );
  }

  @override
  bool get wantKeepAlive => true;

  @override
  Future<void> afterFirstLayout(BuildContext context) async {
    await GetIt.I.allReady();
    await Pros.server.load();
    Pros.server.startAutoRefresh();
  }

  List<String> _filterServers(ServerProvider pro) => pro.serverOrder
      .where((e) => pro.serverOrder.contains(e))
      .where((e) =>
          _tag == null || (pro.pick(id: e)?.spi.tags?.contains(_tag) ?? false))
      .toList();

  double? _calcCardHeight(ServerState cs, bool flip) {
    if (_textFactorDouble != 1.0) return null;
    if (cs != ServerState.finished) {
      return 23.0;
    }
    if (flip) {
      return 80.0;
    }
    if (Stores.setting.moveOutServerTabFuncBtns.fetch() &&
        // Discussion #146
        !Stores.setting.serverTabUseOldUI.fetch()) {
      return 132;
    }
    return 106;
  }

  void _askFor({
    required void Function() func,
    required String typ,
    required String name,
  }) {
    context.showRoundDialog(
      title: Text(l10n.attention),
      child: Text(l10n.askContinue('$typ ${l10n.server}($name)')),
      actions: [
        TextButton(
          onPressed: () {
            context.pop();
            func();
          },
          child: Text(l10n.ok),
        ),
      ],
    );
  }

  _CardNotifier _getCardNoti(String id) => _cardsStatus.putIfAbsent(
        id,
        () => _CardNotifier(const _CardStatus()),
      );
}

typedef _CardNotifier = ValueNotifier<_CardStatus>;

class _CardStatus {
  final bool flip;
  final bool? diskIO;
  final NetViewType? net;

  const _CardStatus({
    this.flip = false,
    this.diskIO,
    this.net,
  });

  _CardStatus copyWith({
    bool? flip,
    bool? diskIO,
    NetViewType? net,
  }) {
    return _CardStatus(
      flip: flip ?? this.flip,
      diskIO: diskIO ?? this.diskIO,
      net: net ?? this.net,
    );
  }
}
