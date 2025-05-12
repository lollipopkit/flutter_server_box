// ignore_for_file: invalid_use_of_protected_member

import 'dart:async';
import 'dart:math' as math;

import 'package:fl_lib/fl_lib.dart';
import 'package:flutter/material.dart';
import 'package:icons_plus/icons_plus.dart';
import 'package:responsive_framework/responsive_framework.dart';
import 'package:server_box/core/extension/context/locale.dart';
import 'package:server_box/core/extension/ssh_client.dart';
import 'package:server_box/core/route.dart';
import 'package:server_box/data/model/app/shell_func.dart';
import 'package:server_box/data/model/server/try_limiter.dart';
import 'package:server_box/data/res/build_data.dart';
import 'package:server_box/data/res/store.dart';
import 'package:server_box/view/page/server/detail/view.dart';
import 'package:server_box/view/page/server/edit.dart';
import 'package:server_box/view/page/setting/entry.dart';
import 'package:server_box/view/widget/percent_circle.dart';

import 'package:server_box/data/model/app/net_view.dart';
import 'package:server_box/data/model/server/server.dart';
import 'package:server_box/data/model/server/server_private_info.dart';
import 'package:server_box/data/provider/server.dart';
import 'package:server_box/view/widget/server_func_btns.dart';

part 'top_bar.dart';
part 'card_stat.dart';
part 'utils.dart';
part 'content.dart';
part 'landscape.dart';

class ServerPage extends StatefulWidget {
  const ServerPage({super.key});

  @override
  State<ServerPage> createState() => _ServerPageState();

  static const route = AppRouteNoArg(
    page: ServerPage.new,
    path: '/servers',
  );
}

const _cardPad = 74.0;
const _cardPadSingle = 13.0;

class _ServerPageState extends State<ServerPage> with AutomaticKeepAliveClientMixin, AfterLayoutMixin {
  late MediaQueryData _media;

  late double _textFactorDouble;
  double _offset = 1;
  late TextScaler _textFactor;

  final _cardsStatus = <String, _CardNotifier>{};

  Timer? _timer;

  final _tag = ''.vn;

  final _scrollController = ScrollController();
  final _autoHideCtrl = AutoHideController();
  final _splitViewCtrl = SplitViewController();

  @override
  void dispose() {
    super.dispose();
    _timer?.cancel();
    _scrollController.dispose();
    _autoHideCtrl.dispose();
    _tag.dispose();
  }

  @override
  void initState() {
    super.initState();
    _startAvoidJitterTimer();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _media = MediaQuery.of(context);
    _updateOffset();
    _updateTextScaler();
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return OrientationBuilder(builder: (_, orientation) {
      if (orientation == Orientation.landscape) {
        final useFullScreen = Stores.setting.fullScreen.fetch();
        // Only enter landscape mode when the screen is wide enough and the
        // full screen mode is enabled.
        if (useFullScreen) return _buildLandscape();
      }
      return _buildPortrait();
    });
  }

  Widget _buildScaffold(Widget child) {
    return Scaffold(
      appBar: _TopBar(
        tags: ServerProvider.tags,
        onTagChanged: (p0) => _tag.value = p0,
        initTag: _tag.value,
      ),
      body: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => _autoHideCtrl.show(),
        child: ListenableBuilder(
          listenable: Stores.setting.textFactor.listenable(),
          builder: (_, __) {
            _updateTextScaler();
            return child;
          },
        ),
      ),
      floatingActionButton: AutoHide(
        direction: AxisDirection.right,
        offset: 75,
        scrollController: _scrollController,
        hideController: _autoHideCtrl,
        child: FloatingActionButton(
          heroTag: 'addServer',
          onPressed: _onTapAddServer,
          tooltip: libL10n.add,
          child: const Icon(Icons.add),
        ),
      ),
    );
  }

  Widget _buildPortrait() {
    // final isMobile = ResponsiveBreakpoints.of(context).isMobile;
    return ServerProvider.serverOrder.listenVal(
      (order) {
        return _tag.listenVal(
          (val) {
            final filtered = _filterServers(order);
            final child = _buildScaffold(_buildBodySmall(filtered: filtered));
            // if (isMobile) {
            return child;
            // }

            // return SplitView(
            //   controller: _splitViewCtrl,
            //   leftWeight: 1,
            //   rightWeight: 1.3,
            //   initialRight: Center(child: CircularProgressIndicator()),
            //   leftBuilder: (_, __) => child,
            // );
          },
        );
      },
    );
  }

  Widget _buildBodySmall({
    required List<String> filtered,
    EdgeInsets? padding = const EdgeInsets.fromLTRB(7, 0, 7, 7),
  }) {
    if (filtered.isEmpty) {
      return Center(child: Text(libL10n.empty, textAlign: TextAlign.center));
    }

    // Calculate number of columns based on available width
    final columnsCount = math.max(1, (_media.size.width / UIs.columnWidth).floor());
    
    // Calculate number of rows needed
    final rowCount = (filtered.length + columnsCount - 1) ~/ columnsCount;
    
    return ListView.builder(
      controller: _scrollController,
      padding: padding,
      itemCount: rowCount + 1, // +1 for the bottom space
      itemBuilder: (_, rowIndex) {
        // Bottom space
        if (rowIndex == rowCount) return UIs.height77;
        
        // Create a row of server cards
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 4.0),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: List.generate(columnsCount, (colIndex) {
              final index = rowIndex * columnsCount + colIndex;
              if (index >= filtered.length) return Expanded(child: Container());
              
              final vnode = ServerProvider.pick(id: filtered[index]);
              if (vnode == null) return Expanded(child: UIs.placeholder);
              
              return Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4.0),
                  child: vnode.listenVal(_buildEachServerCard),
                ),
              );
            }),
          ),
        );
      },
    );
  }

  Widget _buildEachServerCard(Server? srv) {
    if (srv == null) {
      return UIs.placeholder;
    }

    return CardX(
      key: Key(srv.spi.id + _tag.value),
      child: InkWell(
        onTap: () => _onTapCard(srv),
        onLongPress: () => _onLongPressCard(srv),
        child: Padding(
          padding: const EdgeInsets.only(
            left: _cardPadSingle,
            right: 3,
            top: _cardPadSingle,
            bottom: _cardPadSingle,
          ),
          child: _buildRealServerCard(srv),
        ),
      ),
    );
  }

  /// The child's width mat not equal to 1/4 of the screen width,
  /// so we need to wrap it with a SizedBox.
  Widget _wrapWithSizedbox(Widget child, double maxWidth, [bool circle = false]) {
    return LayoutBuilder(builder: (_, cons) {
      final width = (maxWidth - _cardPad) / 4;
      return SizedBox(
        width: width,
        child: child,
      );
    });
  }

  Widget _buildRealServerCard(Server srv) {
    final id = srv.spi.id;
    final cardStatus = _getCardNoti(id);
    final title = _buildServerCardTitle(srv);

    return cardStatus.listenVal((_) {
      final List<Widget> children = [title];
      if (srv.conn == ServerConn.finished) {
        if (cardStatus.value.flip) {
          children.add(_buildFlippedCard(srv));
        } else {
          children.add(_buildNormalCard(srv.status, srv.spi));
        }
      }

      final height = _calcCardHeight(srv.conn, cardStatus.value.flip);
      return AnimatedContainer(
        duration: const Duration(milliseconds: 377),
        curve: Curves.fastEaseInToSlowEaseOut,
        height: height,
        // Use [OverflowBox] to dismiss the warning of [Column] overflow.
        child: OverflowBox(
          // If `height == _kCardHeightMin`, the `maxHeight` will be ignored.
          //
          // You can comment the `maxHeight` then connect&disconnect the server
          // to see the difference.
          maxHeight: height != _kCardHeightMin ? height : null,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: children,
          ),
        ),
      );
    });
  }

  Widget _buildFlippedCard(Server srv) {
    const color = Colors.grey;
    const textStyle = TextStyle(fontSize: 13, color: color);
    final children = [
      Btn.column(
        onTap: () => _onTapSuspend(srv),
        icon: const Icon(Icons.stop, color: color),
        text: l10n.suspend,
        textStyle: textStyle,
      ),
      Btn.column(
        onTap: () => _onTapShutdown(srv),
        icon: const Icon(Icons.power_off, color: color),
        text: l10n.shutdown,
        textStyle: textStyle,
      ),
      Btn.column(
        onTap: () => _onTapReboot(srv),
        icon: const Icon(Icons.restart_alt, color: color),
        text: l10n.reboot,
        textStyle: textStyle,
      ),
      Btn.column(
        onTap: () => _onTapEdit(srv),
        icon: const Icon(Icons.edit, color: color),
        text: libL10n.edit,
        textStyle: textStyle,
      )
    ];

    final width = (_media.size.width - _cardPad) / children.length;
    return Padding(
      padding: const EdgeInsets.only(top: 9),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: children.map((e) {
          if (width == 0) return e;
          return SizedBox(width: width, child: e);
        }).toList(),
      ),
    );
  }

  Widget _buildNormalCard(ServerStatus ss, Spi spi) {
    return LayoutBuilder(builder: (_, cons) {
      final maxWidth = cons.maxWidth;
      return Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          UIs.height13,
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _wrapWithSizedbox(PercentCircle(percent: ss.cpu.usedPercent()), maxWidth, true),
              _wrapWithSizedbox(
                PercentCircle(percent: ss.mem.usedPercent * 100),
                maxWidth,
                true,
              ),
              _wrapWithSizedbox(_buildNet(ss, spi.id), maxWidth),
              _wrapWithSizedbox(_buildDisk(ss, spi.id), maxWidth),
            ],
          ),
          UIs.height13,
          if (Stores.setting.moveServerFuncs.fetch() &&
              // Discussion #146
              !Stores.setting.serverTabUseOldUI.fetch())
            SizedBox(
              height: 27,
              child: ServerFuncBtns(spi: spi),
            ),
        ],
      );
    });
  }

  @override
  bool get wantKeepAlive => true;

  @override
  Future<void> afterFirstLayout(BuildContext context) async {
    ServerProvider.refresh();
    ServerProvider.startAutoRefresh();
  }

  static const _kCardHeightMin = 23.0;
  static const _kCardHeightFlip = 99.0;
  static const _kCardHeightNormal = 108.0;
  static const _kCardHeightMoveOutFuncs = 135.0;
}
