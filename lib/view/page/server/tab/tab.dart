// ignore_for_file: invalid_use_of_protected_member

import 'dart:async';
import 'dart:math' as math;

import 'package:fl_lib/fl_lib.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:icons_plus/icons_plus.dart';
import 'package:server_box/core/extension/context/locale.dart';
import 'package:server_box/core/route.dart';
import 'package:server_box/core/utils/tag_group.dart';
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
import 'package:server_box/data/res/store.dart';
import 'package:server_box/view/page/server/detail/view.dart';
import 'package:server_box/view/page/server/edit/edit.dart';
import 'package:server_box/view/page/setting/entry.dart';
import 'package:server_box/view/widget/dist_icon.dart';
import 'package:server_box/view/widget/pane_settings.dart';
import 'package:server_box/view/widget/percent_circle.dart';
import 'package:server_box/view/widget/server_power.dart';

part 'card_stat.dart';
part 'content.dart';
part 'flight.dart';
part 'landscape.dart';
part 'pane_list.dart';
part 'sort.dart';
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
    with AutomaticKeepAliveClientMixin, TickerProviderStateMixin {
  double _textFactorDouble = 1.0;
  final ValueNotifier<double> _offsetNotifier = ValueNotifier(1);
  TextScaler _textFactor = TextScaler.linear(1.0);
  PageController? _landscapeController;
  String? _landscapeSeenId;

  final _cardsStatus = <String, _CardNotifier>{};
  late final ValueNotifier<Set<String>> _tags;

  Timer? _timer;

  final _tag = ''.vn;

  final _scrollController = ScrollController();

  /// Bumped when the sort changes, which is a view over the list rather than
  /// anything the providers hold — so nothing else would rebuild it.
  final _sortVersion = RNode();

  /// The bar's search: what is typed, and whether the bar is a field at all.
  final _search = InlineSearchController();

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
    _sortVersion.dispose();
    _search.dispose();
    _tag.dispose();
    _tags.dispose();
    _offsetNotifier.dispose();
    _landscapeController?.dispose();
    for (final n in _cardsStatus.values) {
      n.dispose();
    }
    _cardsStatus.clear();
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
  void deactivate() {
    _timer?.cancel();
    _timer = null;
    super.deactivate();
  }

  @override
  void activate() {
    super.activate();
    _startAvoidJitterTimer();
  }

  void _pruneCardNotifiers(Set<String> aliveIds) {
    final toRemove = _cardsStatus.keys.where((id) => !aliveIds.contains(id)).toList();
    for (final id in toRemove) {
      _cardsStatus.remove(id)?.dispose();
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    // Listen to provider changes and update the ValueNotifier
    ref.listen(serversProvider, (previous, next) {
      _tags.value = next.tags;
      _pruneCardNotifiers(next.servers.keys.toSet());
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
      // No bar at any width. A phone used to get the app's name and a cog here
      // because this was the one layout with no other way into the settings
      // (#657) — the wider ones have the nav rail, which carries its own. The
      // bottom bar's "more" is that way now, on every phone and every tab, so
      // what was left up here was a title naming the app on the app's own
      // first screen.
      appBar: _buildTagBar(),
      body: Stores.setting.textFactor.listenable().listenVal((val) {
        _updateTextScaler(val);
        // The bar above spends the top inset, as an app bar does; this is what
        // is left, and what it still has to clear is the home indicator.
        return SafeArea(top: false, child: child);
      }),
    );
  }

  Widget _buildPortrait() {
    final serverOrder = ref.watch(serversProvider.select((s) => s.serverOrder));
    final servers = ref.watch(serversProvider.select((s) => s.servers));
    final selected = ref.watch(serverSelectionProvider);
    final selectedSpi = selected == null ? null : servers[selected];

    // Watched only for the order that depends on them, and only in this
    // method — which is a `build`, where `ref.watch` belongs. The sort runs
    // inside a `ListenableBuilder` below, and watching from that callback
    // would be a dependency registered outside the build that owns it.
    //
    // `select` narrows it to the transition: a status poll landing does not
    // reorder the list, a server connecting or dropping does.
    final conns = _SortOrder.stored.field != _SortField.status
        ? const <String, ServerConn>{}
        : {
            for (final id in serverOrder)
              id: ref.watch(serverProvider(id).select((s) => s.conn)),
          };

    // Both settings listened to, not read. They are changed elsewhere — the
    // switch on the settings page, the width by dragging the divider on the
    // terminal or files tab — and this page is kept alive behind those, so a
    // value read when it was last on screen is not the value now. Read that
    // way the switch took effect whenever something unrelated happened to
    // rebuild, and this column stayed at whatever width it opened with while
    // the others moved.
    return PaneSettings.listenAll((paneWidth, paneCollapsed) {
      return AdaptivePanes.detail(
        listWidth: paneWidth,
        onListWidthChanged: PaneSettings.saveWidth,
        collapsed: paneCollapsed,
        onCollapsedChanged: PaneSettings.saveCollapsed,
        collapseTooltip: libL10n.fold,
        expandTooltip: libL10n.open,
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
        //
        // The tag and the sort are listened to *inside* this rather than
        // around the whole layout: they are two ways of viewing the list, and
        // neither says anything about the pane beside it. Read from outside,
        // picking a tag rebuilt the detail page as well.
        listBuilder: (_, split) => _ServerOpenRequest(
          split: split,
          onOpen: _openRequestedServer,
          child: ListenableBuilder(
            // The three ways of viewing the list, and nothing else: a tag, a
            // search and an order.
            listenable: Listenable.merge([_tag, _sortVersion, _search]),
            builder: (_, _) {
                // The settings arrangement, viewed however the sort button
                // says — see [_SortOrder], whose first option is that
                // arrangement unchanged.
                final ordered = _SortOrder.stored.apply(
                  serverOrder,
                  servers,
                  (id) => conns[id] ?? ServerConn.disconnected,
                );
                // The rail gets everything, not the filtered list. It groups
                // by tag instead of filtering to one, and has no switcher of
                // its own — so a tag picked in the grid before a server was
                // opened would hide servers there with nothing on screen to
                // say so or undo it.
              if (split) return _buildPaneList(ordered);
              return _buildScaffold(
                _buildBodySmall(filtered: _filterServers(ordered)),
              );
            },
          ),
        ),
      );
    });
  }

  /// The tag filter and the way to add a server, in the strip every other tab
  /// has: a switcher on the left that opens the rest in a sheet, buttons on
  /// the right.
  ///
  /// It was a pill floating over the grid, which withdrew on a timer and came
  /// back on a tap. That is one more thing to know about this tab than about
  /// any of the others, and the add button had to float with it — so the two
  /// controls this page has were both somewhere that had to be discovered.
  ///
  /// [SessionTabBar.height] rather than a bar of its own measurements: the
  /// strips are read as one line down the app, and a taller one here would
  /// shift the page contents by that much on every switch between tabs.
  PreferredSizeWidget _buildTagBar() {
    return PreferredSizeListenBuilder(
      // Which tag is on, what tags there are to choose between, and how the
      // list is ordered — the sort button draws its own current icon.
      listenable: Listenable.merge([_tags, _tag, _sortVersion]),
      // The wrapper is what the `Scaffold` measures, so it has to be told; its
      // own default is a full toolbar.
      preferSize: const Size.fromHeight(SessionTabBar.height),
      builder: () {
        final tags = _tags.value.toList();
        final current = _tag.value;
        final at = tags.indexOf(current);

        return SizedBox(
          height: SessionTabBar.height,
          child: InlineSearchBar(
            controller: _search,
            child: Row(
            children: [
              Expanded(
                child: SessionSwitcherLabel(
                  name: current.isEmpty ? libL10n.all : '#$current',
                  // Counting from 1, and null on "all" — which is not one of
                  // the tags but the absence of a choice among them, so it
                  // shows the icon instead.
                  position: at < 0 ? null : at + 1,
                  total: tags.length,
                  icon: MingCute.hashtag_line,
                  // Nothing to switch between with no tags anywhere, so the
                  // name is a label rather than a way into a sheet — the same
                  // rule the session strips follow with nothing open.
                  onTap: tags.isEmpty ? null : () => _showTagSheet(tags),
                ),
              ),
              ..._listActions,
              const SizedBox(width: 7),
            ],
            ),
          ),
        );
      },
    );
  }

  /// Find a server by name or address, in the bar and in the list under it.
  ///
  /// The field takes the switcher's place rather than opening a page of
  /// results: what is being searched is on screen, so the list itself is the
  /// result — it narrows as the query is typed and the cards stay the cards,
  /// with everything a card can do still on them.
  ///
  /// It narrows *within* the tag, because both are in this bar and one of them
  /// is visibly on. A search that quietly ignored the tag would answer with
  /// servers the page says it is not showing.
  /// What acts on the list rather than on one server in it.
  ///
  /// One list for the bar on a single column and the rail's head beside a
  /// pane: they act on the same list and had drifted to two orders and two
  /// icon sizes.
  List<Widget> get _listActions => [
    Btn.icon(
      text: libL10n.search,
      icon: const Icon(Icons.search, size: 18),
      onTap: _search.start,
    ),
    Btn.icon(
      text: libL10n.sort,
      icon: Icon(_SortOrder.stored.icon, size: 18),
      onTap: _showSortSheet,
    ),
    // Where a phone pulls the grid down instead — see [_buildBodySmall].
    if (isDesktop)
      Btn.icon(
        text: libL10n.refresh,
        icon: const Icon(Icons.refresh, size: 18),
        onTap: _refreshAll,
      ),
    Btn.icon(
      text: libL10n.add,
      icon: const Icon(Icons.add, size: 18),
      onTap: _onTapAddServer,
    ),
  ];

  /// How to order the list. The default is the arrangement from the settings,
  /// so this starts as a view of what the user already decided rather than as
  /// a decision it takes from them.
  Future<void> _showSortSheet() async {
    await showRowsSheet<void>(
      context,
      rows: (ctx) => [
        for (final order in _SortOrder.all)
          SheetChoiceTile(
            icon: order.icon,
            title: order.label,
            selected: order.isCurrent,
            onTap: () {
              order.save();
              Navigator.of(ctx).pop();
              _sortVersion.notify();
            },
          ),
      ],
    );
  }

  /// The tags, as rows. The same sheet the session switchers open, for the
  /// same reason: a strip of them would be as wide as the names happened to be.
  Future<void> _showTagSheet(List<String> tags) async {
    await showRowsSheet<void>(
      context,
      rows: (ctx) {
        void pick(String tag) {
          Navigator.of(ctx).pop();
          _tag.value = tag;
        }

        return [
          SheetChoiceTile(
            icon: MingCute.hashtag_line,
            title: libL10n.all,
            selected: _tag.value.isEmpty,
            onTap: () => pick(TagSwitcher.kDefaultTag),
          ),
          const Divider(height: 1),
          for (final tag in tags)
            // The same shape as the row above it: the mark, then the name.
            // The mark is the `#`, so the name does not carry one as well.
            SheetChoiceTile(
              icon: MingCute.hashtag_line,
              title: tag,
              selected: tag == _tag.value,
              onTap: () => pick(tag),
            ),
        ];
      },
    );
  }

  Widget _buildBodySmall({required List<String> filtered}) {
    // Crossed rather than swapped. The list emptying under a search and
    // filling again as it is deleted are the two halves of one movement, and
    // an instant cut reads as the page having been replaced rather than as
    // what was typed taking effect.
    //
    // Keyed, because both states are sometimes the same widget type: the
    // grid keeps one key throughout — its own contents animate, and a switch
    // here would fight that — and each empty state has its own, so going from
    // a filtered-out tag to no servers at all is also a crossing.
    return AnimatedSwitcher(
      duration: Durations.medium1,
      // Told to fill, or the grid is as tall as the cards in it: the default
      // layout is a `Stack` that sizes to its child and hands it loose
      // constraints, under which a `SingleChildScrollView` takes the height of
      // its contents — so the list ended partway down the window and was cut
      // off there rather than scrolling.
      layoutBuilder: (current, previous) => Stack(
        fit: StackFit.expand,
        children: [...previous, ?current],
      ),
      child: filtered.isEmpty
          ? _buildEmpty()
          : KeyedSubtree(
              key: const ValueKey('grid'),
              child: _buildGrid(filtered),
            ),
    );
  }

  Widget _buildGrid(List<String> filtered) {

    // Cards are as tall as what they have to say — a server that has not
    // connected is one line, one that has is several charts. Splitting them
    // round-robin into a `ListView` per column left a short column beside a
    // long one and gave each its own scroll position; they flow into whichever
    // column is shortest now, in one scrollable.
    //
    // The animated form, because everything that rearranges this grid does so
    // for a reason worth seeing: a server connects and its card grows, a tag
    // is picked and half of them leave, one is added or deleted. See
    // [AnimatedMasonry] — the card that moves is usually not the card anything
    // happened to, which is exactly why it has to be carried rather than
    // moved.
    final grid = AnimatedMasonry(
      controller: _scrollController,
      // No room kept for chrome at either end: the tag switcher, the sort and
      // the add button are in the bar above this, and nothing floats over it.
      padding: MasonryList.kPadding,
      children: [
        for (final id in filtered)
          // Its own `Consumer`, so a status poll rebuilds the one card whose
          // server answered rather than the grid. Watched from this page's
          // `ref` — which is what a builder would have to do — any server's
          // reading landing rebuilt every card on screen.
          Consumer(
            key: ValueKey(id),
            builder: (_, ref, _) =>
                _buildEachServerCard(ref.watch(serverProvider(id))),
          ),
      ],
    );

    // Pulling is how a phone asks for this; a pointer has the button in the
    // bar. The status poll runs on its own, so neither is the only way — they
    // are for the moment someone wants an answer now.
    if (!isMobile) return grid;
    return RefreshIndicator(onRefresh: _refreshAll, child: grid);
  }

  /// What the page shows with no cards on it, which is two different things.
  ///
  /// A tag with nothing under it is a filter to undo — the servers are still
  /// there, and an empty page that does not say so reads as having lost them.
  /// No servers at all is the first thing a new install sees, and the one
  /// place on this page worth spelling out what to do.
  Widget _buildEmpty() {
    // A search with no hits is a third thing again, and the one that would be
    // read most wrongly: with no tag on, it used to answer "no servers yet"
    // and offer to add one, on a page whose servers are all still there.
    final query = _search.needle;
    if (query.isNotEmpty) {
      return EmptyPane(
        key: const ValueKey('empty-search'),
        icon: Icons.search_off,
        label: query,
        action: Btn.text(text: libL10n.clear, onTap: _search.end),
      );
    }

    if (_tag.value.isNotEmpty) {
      return EmptyPane(
        key: const ValueKey('empty-tag'),
        icon: BoxIcons.bx_server,
        label: '#${_tag.value}',
        action: Btn.text(
          text: libL10n.clear,
          onTap: () => _tag.value = TagSwitcher.kDefaultTag,
        ),
      );
    }

    return EmptyPane(
      key: const ValueKey('empty-none'),
      icon: BoxIcons.bx_server,
      label: l10n.serverTabEmpty,
      action: Btn.text(text: libL10n.add, onTap: _onTapAddServer),
    );
  }

  Future<void> _refreshAll() async {
    await ref.read(serversProvider.notifier).refresh();
  }

  Widget _buildEachServerCard(ServerState srv) {
    final card = CardX(
      key: ValueKey(srv.spi.id),
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

  static const _kCardHeightMin = 23.0;
  static const _kCardHeightFlip = 99.0;
  static const _kCardHeightNormal = 110.0;
}
