// ignore_for_file: invalid_use_of_protected_member

import 'dart:async';
import 'dart:math' as math;

import 'package:fl_lib/fl_lib.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:icons_plus/icons_plus.dart';
import 'package:responsive_framework/responsive_framework.dart';
import 'package:server_box/core/extension/context/locale.dart';
import 'package:server_box/core/extension/ssh_client.dart';
import 'package:server_box/core/route.dart';
import 'package:server_box/data/model/app/net_view.dart';
import 'package:server_box/data/model/app/scripts/cmd_types.dart';
import 'package:server_box/data/model/app/scripts/shell_func.dart';
import 'package:server_box/data/model/server/server.dart';
import 'package:server_box/data/model/server/server_private_info.dart';
import 'package:server_box/data/model/server/try_limiter.dart';
import 'package:server_box/data/provider/server/all.dart';
import 'package:server_box/data/provider/server/single.dart';
import 'package:server_box/data/res/build_data.dart';
import 'package:server_box/data/res/store.dart';
import 'package:server_box/view/page/server/detail/view.dart';
import 'package:server_box/view/page/server/edit/edit.dart';
import 'package:server_box/view/page/setting/entry.dart';
import 'package:server_box/view/widget/percent_circle.dart';
import 'package:server_box/view/widget/server_func_btns.dart';

part 'card_stat.dart';
part 'content.dart';
part 'landscape.dart';
part 'top_bar.dart';
part 'utils.dart';

class ServerPage extends ConsumerStatefulWidget {
  const ServerPage({super.key});

  @override
  ConsumerState<ServerPage> createState() => _ServerPageState();

  static const route = AppRouteNoArg(page: ServerPage.new, path: '/servers');
}

const _cardPad = 74.0;
const _cardPadSingle = 13.0;

class _ServerPageState extends ConsumerState<ServerPage>
    with AutomaticKeepAliveClientMixin, AfterLayoutMixin {
  late double _textFactorDouble;
  double _offset = 1;
  late TextScaler _textFactor;

  final _cardsStatus = <String, _CardNotifier>{};
  late final ValueNotifier<Set<String>> _tags;

  Timer? _timer;

  final _tag = ''.vn;

  final _scrollController = ScrollController();
  final _autoHideCtrl = AutoHideController();

  @override
  void dispose() {
    super.dispose();
    _timer?.cancel();
    _scrollController.dispose();
    _autoHideCtrl.dispose();
    _tag.dispose();
    _tags.dispose();
  }

  @override
  void initState() {
    super.initState();
    _tags = ValueNotifier(ref.read(serversNotifierProvider).tags);
    _startAvoidJitterTimer();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _updateOffset();
  }


  @override
  Widget build(BuildContext context) {
    super.build(context);
    // Listen to provider changes and update the ValueNotifier
    ref.listen(serversNotifierProvider, (previous, next) {
      _tags.value = next.tags;
    });
    return OrientationBuilder(
      builder: (_, orientation) {
        if (orientation == Orientation.landscape) {
          final useFullScreen = Stores.setting.fullScreen.fetch();
          // Only enter landscape mode when the screen is wide enough and the
          // full screen mode is enabled.
          if (useFullScreen) return _buildLandscape();
        }
        return _buildPortrait();
      },
    );
  }

  Widget _buildScaffold(Widget child) {
    return Scaffold(
      appBar: _TopBar(tags: _tags, onTagChanged: (p0) => _tag.value = p0, initTag: _tag.value),
      body: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: _autoHideCtrl.show,
        child: Stores.setting.textFactor.listenable().listenVal((val) {
          _updateTextScaler(val);
          return child;
        }),
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
    final serverState = ref.watch(serversNotifierProvider);
    return _tag.listenVal((val) {
      final filtered = _filterServers(serverState.serverOrder);
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
    });
  }

  Widget _buildBodySmall({required List<String> filtered}) {
    if (filtered.isEmpty) {
      return Center(child: Text(libL10n.empty, textAlign: TextAlign.center));
    }

    return LayoutBuilder(
      builder: (_, cons) {
        // Calculate number of columns based on available width
        final columnsCount = math.max(1, (cons.maxWidth / UIs.columnWidth).floor());
        final padding = columnsCount > 1
            ? const EdgeInsets.fromLTRB(0, 0, 5, 7)
            : const EdgeInsets.fromLTRB(7, 0, 7, 7);

        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: List.generate(columnsCount, (colIndex) {
            // Calculate which servers belong in this column
            final serversInThisColumn = <String>[];
            for (int i = colIndex; i < filtered.length; i += columnsCount) {
              serversInThisColumn.add(filtered[i]);
            }
            final lens = serversInThisColumn.length;

            return Expanded(
              child: ListView.builder(
                controller: colIndex == 0 ? _scrollController : null,
                padding: padding,
                itemCount: lens + 1, // Add 1 for bottom spacing
                itemBuilder: (context, index) {
                  // Last item is just spacing
                  if (index == lens) return SizedBox(height: 77);

                  final individualState = ref.watch(serverNotifierProvider(serversInThisColumn[index]));

                  return _buildEachServerCard(individualState);
                },
              ),
            );
          }),
        );
      },
    );
  }

  Widget _buildEachServerCard(ServerState srv) {
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
    return LayoutBuilder(
      builder: (_, cons) {
        final width = (maxWidth - _cardPad) / 4;
        return SizedBox(width: width, child: child);
      },
    );
  }

  Widget _buildRealServerCard(ServerState srv) {
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

  Widget _buildFlippedCard(ServerState srv) {
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
      ),
    ];

    return Padding(
      padding: const EdgeInsets.only(top: 9),
      child: LayoutBuilder(
        builder: (_, cons) {
          final width = (cons.maxWidth - _cardPad) / children.length;
          return Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: children.map((e) {
              if (width == 0) return e;
              return SizedBox(width: width, child: e);
            }).toList(),
          );
        },
      ),
    );
  }

  Widget _buildNormalCard(ServerStatus ss, Spi spi) {
    return LayoutBuilder(
      builder: (_, cons) {
        final maxWidth = cons.maxWidth;
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            UIs.height13,
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _wrapWithSizedbox(PercentCircle(percent: ss.cpu.usedPercent()), maxWidth, true),
                _wrapWithSizedbox(PercentCircle(percent: ss.mem.usedPercent * 100), maxWidth, true),
                _wrapWithSizedbox(_buildNet(ss, spi.id), maxWidth),
                _wrapWithSizedbox(_buildDisk(ss, spi.id), maxWidth),
              ],
            ),
            UIs.height13,
            if (Stores.setting.moveServerFuncs.fetch()) SizedBox(height: 27, child: ServerFuncBtns(spi: spi)),
          ],
        );
      },
    );
  }

  @override
  bool get wantKeepAlive => true;

  @override
  Future<void> afterFirstLayout(BuildContext context) async {
    ref.read(serversNotifierProvider.notifier).refresh();
    ref.read(serversNotifierProvider.notifier).startAutoRefresh();
  }

  static const _kCardHeightMin = 23.0;
  static const _kCardHeightFlip = 99.0;
  static const _kCardHeightNormal = 108.0;
  static const _kCardHeightMoveOutFuncs = 135.0;
}
