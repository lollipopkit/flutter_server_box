// ignore_for_file: invalid_use_of_protected_member

import 'dart:async';
import 'dart:math' as math;

import 'package:fl_lib/fl_lib.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:icons_plus/icons_plus.dart';
import 'package:responsive_framework/responsive_framework.dart';
import 'package:server_box/core/extension/context/locale.dart';
import 'package:server_box/core/route.dart';
import 'package:server_box/data/model/app/error.dart';
import 'package:server_box/data/model/app/net_view.dart';
import 'package:server_box/data/model/app/scripts/cmd_types.dart';
import 'package:server_box/data/model/server/server.dart';
import 'package:server_box/data/model/server/server_private_info.dart';
import 'package:server_box/data/model/server/try_limiter.dart';
import 'package:server_box/data/provider/app/session_requests.dart';
import 'package:server_box/data/provider/server/all.dart';
import 'package:server_box/data/provider/server/selection.dart';
import 'package:server_box/data/provider/server/single.dart';
import 'package:server_box/data/res/build_data.dart';
import 'package:server_box/data/res/store.dart';
import 'package:server_box/view/page/server/connection_stats.dart';
import 'package:server_box/view/page/server/detail/view.dart';
import 'package:server_box/view/page/server/edit/edit.dart';
import 'package:server_box/view/page/setting/entry.dart';
import 'package:server_box/view/widget/pane_settings.dart';
import 'package:server_box/view/widget/percent_circle.dart';
import 'package:server_box/view/widget/server_power.dart';

part 'card_stat.dart';
part 'content.dart';
part 'flight.dart';
part 'landscape.dart';
part 'pane_list.dart';
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

/// Long enough to read as one movement, short enough not to be waited on.
const _kFlightDuration = Durations.medium3;

class _ServerPageState extends ConsumerState<ServerPage>
    with
        AutomaticKeepAliveClientMixin,
        AfterLayoutMixin,
        TickerProviderStateMixin {
  late double _textFactorDouble;
  final ValueNotifier<double> _offsetNotifier = ValueNotifier(1);
  late TextScaler _textFactor;

  final _cardsStatus = <String, _CardNotifier>{};
  late final ValueNotifier<Set<String>> _tags;

  Timer? _timer;

  final _tag = ''.vn;

  final _scrollController = ScrollController();
  final _autoHideCtrl = AutoHideController();

  /// The server whose card is in the air, or null. Its row in the list is
  /// built hidden and carries [_flightAnchorKey], so the flight has somewhere
  /// to measure and somewhere to land without a second copy showing early.
  final _flyingId = ValueNotifier<String?>(null);

  /// The row or card at the far end of a flight.
  ///
  /// One key for both ends, because the two can never be on screen together:
  /// the compact row only exists while the pane is open, the grid card only
  /// while it is closed, and a flight is what happens in between. Going out it
  /// marks the row being flown to; coming back, the card.
  final _flightAnchorKey = GlobalKey();
  OverlayFlight? _flight;

  /// Deselecting is the whole of "close the pane": the detail is built from
  /// the selection, so dropping it collapses the layout back to the
  /// full-width grid the app starts on.
  ///
  /// A method rather than a closure written at the call site: tearing off the
  /// same instance method twice yields equal values, while a fresh closure per
  /// build would make `PaneScope` notify its dependents on every rebuild.
  void _closeDetail() {
    // A card still on its way to a list that is about to become a grid again
    // would land on nothing.
    _endFlight();
    _flyingId.value = null;

    final id = ref.read(serverSelectionProvider);
    final srv = id == null ? null : ref.read(serverProvider(id));
    ref.read(serverSelectionProvider.notifier).select(null);
    if (srv != null) _flyRowIntoGrid(srv);
  }

  @override
  void dispose() {
    // Before the tickers this state vends go with it: an entry left in the
    // overlay outlives the page that put it there.
    _endFlight();
    _flyingId.dispose();
    _timer?.cancel();
    _scrollController.dispose();
    _autoHideCtrl.dispose();
    _tag.dispose();
    _tags.dispose();
    _offsetNotifier.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    _tags = ValueNotifier(ref.read(serversProvider).tags);
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
    ref.listen(serversProvider, (previous, next) {
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
      appBar: _TopBar(
        tags: _tags,
        onTagChanged: (p0) => _tag.value = p0,
        initTag: _tag.value,
      ),
      body: GestureDetector(
        behavior: HitTestBehavior.translucent,
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
    // Watch serverOrder, tags, and servers to ensure filtered view rebuilds
    // when individual server tags change without affecting the global tag set
    final serverOrder = ref.watch(serversProvider.select((s) => s.serverOrder));
    ref.watch(serversProvider.select((s) => s.tags));
    final servers = ref.watch(serversProvider.select((s) => s.servers));
    final selected = ref.watch(serverSelectionProvider);
    final selectedSpi = selected == null ? null : servers[selected];

    // Both settings listened to, not read. They are changed elsewhere — the
    // switch on the settings page, the width by dragging the divider on the
    // terminal or files tab — and this page is kept alive behind those, so a
    // value read when it was last on screen is not the value now. Read that
    // way the switch took effect whenever something unrelated happened to
    // rebuild, and this column stayed at whatever width it opened with while
    // the others moved.
    return PaneSettings.listen((paneWidth) {
      return _tag.listenVal((val) {
        final filtered = _filterServers(serverOrder);
        return AdaptivePanes(
          primaryWidth: paneWidth,
          onPrimaryWidthChanged: PaneSettings.saveWidth,
          detailId: selectedSpi?.id,
          onCloseDetail: _closeDetail,
          // Null until something is opened, so a fresh launch gets the whole
          // width for browsing rather than a column reserved for nothing.
          detailBuilder: selectedSpi == null
              ? null
              : (_) => ServerDetailPage(args: SpiRequiredArgs(selectedSpi)),
          // Wrapped here rather than around the whole page because this is
          // where `split` is known — it is the layout's own answer, and the
          // `PaneScope` that carries it is installed below this state's
          // context, where an inherited lookup from here cannot reach.
          primaryBuilder: (_, split) => _ServerOpenRequest(
            split: split,
            onOpen: _openRequestedServer,
            child: split
                ? _buildPaneList(filtered)
                : _buildScaffold(_buildBodySmall(filtered: filtered)),
          ),
        );
      });
    });
  }

  Widget _buildBodySmall({required List<String> filtered}) {
    if (filtered.isEmpty) {
      return Center(child: Text(libL10n.empty, textAlign: TextAlign.center));
    }

    // Cards are as tall as what they have to say — a server that has not
    // connected is one line, one that has is several charts. Splitting them
    // round-robin into a `ListView` per column left a short column beside a
    // long one and gave each its own scroll position; they flow into whichever
    // column is shortest now, in one scrollable.
    return MasonryList.builder(
      controller: _scrollController,
      // Room at the bottom for the add button to float over.
      padding: MasonryList.kPadding.copyWith(bottom: 77),
      itemCount: filtered.length,
      // Built as they come into view, so a page of servers watches the ones it
      // is showing rather than all of them.
      itemBuilder: (_, i) =>
          _buildEachServerCard(ref.watch(serverProvider(filtered[i]))),
    );
  }

  Widget _buildEachServerCard(ServerState srv) {
    final card = CardX(
      key: Key(srv.spi.id + _tag.value),
      // A context from inside the built tree, so the tap can ask whether a
      // detail pane is on screen. The state's own context is an ancestor of
      // the layout that installs the scope, and the lookup only goes up.
      child: Builder(
        builder: (context) => InkWell(
          onTap: () => _onTapCard(context, srv),
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
        ).onSecondary(asSecondary(() => _onLongPressCard(srv))),
      ),
    );

    return _flyingId.listenVal((flyingId) {
      if (flyingId != srv.spi.id) return card;
      // Where a card flying back is going. Laid out so it can be measured,
      // unpainted so the copy in the air is the only one visible.
      return Visibility(
        key: _flightAnchorKey,
        visible: false,
        maintainSize: true,
        maintainAnimation: true,
        maintainState: true,
        child: card,
      );
    });
  }

  /// The child's width mat not equal to 1/4 of the screen width,
  /// so we need to wrap it with a SizedBox.
  Widget _wrapWithSizedbox(
    Widget child,
    double maxWidth, [
    bool circle = false,
  ]) {
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
      for (final func in ServerPower.funcs)
        Btn.column(
          onTap: () => ServerPower.confirmAndRun(context, ref, srv.spi, func),
          icon: Icon(ServerPower.icon(func), color: color),
          text: ServerPower.label(func),
          textStyle: textStyle,
        ),
      Btn.column(
        onTap: () => ServerEditPage.route.go(context, args: SpiRequiredArgs(srv.spi)),
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
                _wrapWithSizedbox(
                  // 0 until the second sample lands: the tab list needs a
                  // fixed-size circle, and an empty ring reads the same as idle
                  PercentCircle(percent: ss.cpu.usedPercent() ?? 0),
                  maxWidth,
                  true,
                ),
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
          ],
        );
      },
    );
  }

  @override
  bool get wantKeepAlive => true;

  @override
  Future<void> afterFirstLayout(BuildContext context) async {
    ref.read(serversProvider.notifier).refresh();
    ref.read(serversProvider.notifier).startAutoRefresh();
  }

  static const _kCardHeightMin = 23.0;
  static const _kCardHeightFlip = 99.0;
  static const _kCardHeightNormal = 110.0;
}
