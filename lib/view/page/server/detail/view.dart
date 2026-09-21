import 'dart:async';
import 'package:extended_image/extended_image.dart';
import 'package:fl_lib/fl_lib.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_markdown_plus/flutter_markdown_plus.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:icons_plus/icons_plus.dart';
import 'package:intl/intl.dart';
import 'package:redfish/redfish.dart';
import 'package:server_box/core/extension/context/locale.dart';
import 'package:server_box/core/extension/server.dart';
import 'package:server_box/core/route.dart';
import 'package:server_box/data/model/app/server_detail_card.dart';
import 'package:server_box/data/model/server/battery.dart';
import 'package:server_box/data/model/server/disk_smart.dart';
import 'package:server_box/data/model/server/gpu.dart';
import 'package:server_box/data/model/server/sensors.dart';
import 'package:server_box/data/model/server/server.dart' as server_model;
import 'package:server_box/data/model/server/server_private_info.dart';
import 'package:server_box/data/model/server/try_limiter.dart';
import 'package:server_box/data/provider/bmc/bmc.dart';
import 'package:server_box/data/provider/server/all.dart';
import 'package:server_box/data/provider/server/single.dart';
import 'package:server_box/data/res/chart_palette.dart';
import 'package:server_box/data/res/store.dart';
import 'package:server_box/data/res/url.dart';
import 'package:server_box/view/page/pve.dart';
import 'package:server_box/view/page/server/card/metric.dart';
import 'package:server_box/view/page/server/card/sizes.dart';
import 'package:server_box/view/page/server/chart.dart';
import 'package:server_box/view/page/server/detail/focus_parts.dart';
import 'package:server_box/view/page/server/detail/info_card.dart';
import 'package:server_box/view/page/server/detail/metric_devices.dart';
import 'package:server_box/view/page/server/detail/metric_model.dart';
import 'package:server_box/view/page/server/detail/readout.dart';
import 'package:server_box/view/page/server/detail/window_gaps.dart';
import 'package:server_box/view/page/server/edit/edit.dart';
import 'package:server_box/view/page/server/metric_row.dart';
import 'package:server_box/view/page/server/monitor_settings/page.dart';
import 'package:server_box/view/page/server/reading_text.dart';
import 'package:server_box/view/page/server/text_scale.dart';
import 'package:server_box/view/widget/built_from.dart';
import 'package:server_box/view/widget/server_func_btns.dart';
import 'package:server_box/view/widget/server_share.dart';

part 'bmc.dart';
part 'extra_cards.dart';
part 'notices.dart';
part 'range.dart';
part 'readings.dart';

class ServerDetailPage extends ConsumerStatefulWidget {
  final SpiRequiredArgs args;

  /// Whether this is a page of its own or the inside of one.
  ///
  /// The server tab grows a card into this rather than pushing it, so there is
  /// already a bar over it carrying the way back and the switcher between
  /// machines — and a second one under it would be the page saying its own
  /// name twice.
  final bool bare;

  /// How far the card that is becoming this page has got, or null when this
  /// page was not arrived at that way.
  ///
  /// What it drives is everything the card has no counterpart for — the facts
  /// beside the readings, the tables under them. Those used to be built the
  /// moment the movement ended, so a card grew into a page and then the page
  /// filled in, which is two arrivals for one tap. On this they come in while
  /// the chart is still growing.
  final Animation<double>? entrance;

  /// Whether the readings are this page's to draw.
  ///
  /// False while the card is still the one drawing them: the two are the same
  /// widgets in the same boxes, so both on screen at once is the same thing
  /// drawn twice. The block is still laid out — what is beside and below it is
  /// placed against it — but nothing of it is painted.
  final bool readingsShowing;

  const ServerDetailPage({
    super.key,
    required this.args,
    this.bare = false,
    this.entrance,
    this.readingsShowing = true,
  });

  @override
  ConsumerState<ServerDetailPage> createState() => _ServerDetailPageState();

  static const route = AppRouteArg(
    page: ServerDetailPage.new,
    path: '/servers/detail',
  );
}

/// What the grid keeps clear below its last card, so the bar is never over
/// something that cannot be scrolled out from under it.
///
/// Kept even when this page is not the one drawing the bar: [ServerDetailPage
/// .bare] means the tab floats it above, over the same content.
const _kFuncBarInset = kFuncBarInset;

/// Whether there is anything to render for [state].
///
/// Losing the connection must not empty the page: the status already fetched
/// is still the most recent thing known about the server, and the error card
/// explains why it stopped updating. Collapsing to the placeholder on
/// `ServerConn.failed` threw both away, so a monitor going offline looked
/// identical to a server that had never been opened.
///
/// `more` is the "has ever been fetched" signal — every successful status
/// apply populates it on both transports, and `keepStatusWhenErr` in
/// `ServerNotifier` already relies on that.
///
/// Top level because the server tab asks it too: it draws the function row
/// above a page it hosts, and what that row can do is a different answer on a
/// machine with nothing to show yet.
bool serverDetailHasContent(ServerState state) {
  if (state.status.more.isNotEmpty) return true;
  // Connecting is something to show: the rows every machine has, drawn with
  // dashes, under a progress line. What this used to do instead — a spinner
  // and "waiting for connection" — made the page arrive twice, once as a
  // placeholder and once as itself, with everything in a different place.
  if (state.conn.busy) return true;
  // Having a connection is not having anything to show. Read as "connected is
  // enough", this page opened onto a grid of empty cards — dashes where the
  // CPU goes, `0% of 1 KB` for the disk — for as long as the first fetch took,
  // which on a server that is merely slow is a while. `finished` is the state
  // that means a status came back; it is only ever left for another *later*
  // fetch, so the page does not flicker back on refresh.
  return state.conn == server_model.ServerConn.finished;
}

/// The entries the function row draws for [si], and whether any can be used.
///
/// One answer for the page and for the tab that hosts it: a machine with
/// nothing to show yet keeps the row, greyed, so the positions stay put while
/// it connects — see `_buildNothingYet`.
({List<ServerFuncEntry> entries, bool any}) serverDetailFuncBtns(
  ServerState si,
) {
  final entries = serverFuncBtnsFor(si.spi, si.remoteAccess);
  if (!serverDetailHasContent(si)) {
    return (
      entries: [for (final e in entries) (btn: e.btn, available: false)],
      any: false,
    );
  }
  return (entries: entries, any: entries.any((e) => e.available));
}

class _ServerDetailPageState extends ConsumerState<ServerDetailPage>
    with SingleTickerProviderStateMixin {
  /// The cards that are not one of the metrics the page is built around.
  ///
  /// CPU, memory, swap, disk, network, GPU load, the hottest sensor and the
  /// battery are no longer cards: they are the chart at the top and the rows
  /// under it, which is what this page came to show. What is left here is
  /// everything that is a table or a one-off reading rather than a value with
  /// a line over time — including what those metrics carry beside their
  /// number, like the processes holding a GPU's memory.
  late final _cardBuildMap =
      <ServerDetailCards, Widget? Function(ServerState)>{
        ServerDetailCards.gpu: _buildGpuView,
        ServerDetailCards.smart: _buildDiskSmart,
        ServerDetailCards.sensor: _buildSensors,
        ServerDetailCards.battery: _buildBatteries,
        ServerDetailCards.pve: _buildPve,
        ServerDetailCards.bmc: _buildBmc,
        ServerDetailCards.custom: _buildCustomCmd,
      };

  late Size _size;

  /// Which cards the user has switched off, by [ServerDetailCards.name].
  ///
  /// There is no order any more: the metrics are the page and the rest follow
  /// in the order they are declared in. What is left of the setting is whether
  /// a card is drawn at all.
  final _cardsOff = <String>{};

  /// The metric drawn in full. The rest are a row each.
  ///
  /// The same choice the card in the list draws by, read through
  /// [ServerPromoted]: this page and that card are one structure at two sizes,
  /// so a reading promoted on either has to be the one promoted on the other.
  /// CPU when nothing has been chosen, which is the reading every machine has.
  ///
  /// Listened to by the readings alone — see `_buildMetrics`. It was a field
  /// changed through `setState`, so pressing a row built the whole page again:
  /// every card of facts and every table beside the readings, none of which
  /// is about which reading is drawn in full. That was most of a frame, and
  /// pressing one row after another was a run of frames that did not fit.
  late final _focus = ValueNotifier(_storedFocus);

  ServerMetricKind get _storedFocus =>
      ServerPromoted.of(widget.args.spi.id) ?? ServerMetricKind.cpu;

  /// Which of a metric's devices the chart draws, where the reader has said.
  /// Absent means [MetricDevices.defaults], which is what a page opens on.
  final _devicePick = <ServerMetricKind, Set<String>>{};

  /// The window the chart draws when the reader named one outright, and what
  /// came back for it.
  ///
  /// Wins over [_range] while it is set: the presets are the common windows,
  /// not the only ones an agent can answer for, and what it keeps is the
  /// agent's to say — see `MonitorCapabilities.historyFrom`.
  ({DateTime from, DateTime to})? _custom;
  HistoryRangeAnswer? _customAnswer;
  // ignore: prefer_final_fields — set through `_rebuild` from an extension.
  bool _customBusy = false;

  /// Which server, and which request, the history on this page belongs to.
  ///
  /// Bumped when a request supersedes another and when the page is handed a
  /// different server: both make every answer still in flight one about
  /// something that is no longer on screen. Without it the slower of two
  /// window requests overwrites the newer one, and switching servers in a pane
  /// draws the previous machine's readings under this machine's name.
  int _historyGeneration = 0;

  /// The window the chart draws, and what has been fetched for it.
  HistoryRange _range = HistoryRange.live;
  /// What a range answered, and when it was asked.
  ///
  /// The instant is what the axis is anchored to: a window kept for the length
  /// of a visit would otherwise slide forward against a chart that is not
  /// being refetched, and the gap at its end would grow without anything
  /// having happened.
  final _rangeWindows = <HistoryRange, HistoryRangeAnswer>{};
  final _rangeBusy = <HistoryRange>{};

  final _settings = Stores.setting;

  /// Shared by the grid and the bar floating over it, which is how the bar
  /// knows to get out of the way.
  final _scrollCtrl = ScrollController();

  /// The card the rows promote a metric into, so that tapping one can bring it
  /// back on screen — see `_revealFocus`.
  final _focusCardKey = GlobalKey();
  late final _collapse = _settings.collapseUIDefault.fetch();
  late final _cpuViewAsProgress = _settings.cpuViewAsProgress.fetch();
  late final _displayCpuIndex = _settings.displayCpuIndex.fetch();

  /// Which cards are open, by their `cardKey`.
  ///
  /// Held by the page rather than by each card, because a card does not
  /// outlive a refresh: it is rebuilt by anything that changes the list or how
  /// it is laid out (a status arriving and with it the logo, the error card
  /// appearing, a window resize changing the column count), and a card that
  /// decided for itself would re-apply its default each time — which is what
  /// made the About card spring open on every poll.
  final _cardsOpen = <String, bool>{};

  /// Whether the card [key] is open, opened on first use if [initially].
  bool _cardExpanded(String key, bool initially) =>
      _cardsOpen.putIfAbsent(key, () => initially);

  void _toggleCard(String key) => _cardsOpen[key] = !(_cardsOpen[key] ?? false);

  /// What the parts of this page held in extensions change state through:
  /// `setState` is protected, and an extension is not a subclass.
  void _rebuild(VoidCallback update) {
    if (mounted) setState(update);
  }

  @override
  void dispose() {
    super.dispose();
    _scrollCtrl.dispose();
    _focus.dispose();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _size = MediaQuery.sizeOf(context);
  }

  /// The page is a widget, not a route: choosing another server in a pane
  /// hands this same state a different one. Everything here that is about a
  /// particular machine has to go with it — the windows fetched for it, the
  /// devices picked out of it — and every request still in flight has to stop
  /// counting.
  @override
  void didUpdateWidget(ServerDetailPage old) {
    super.didUpdateWidget(old);
    if (widget.args.spi.id == old.args.spi.id) return;
    _historyGeneration++;
    setState(() {
      _custom = null;
      _customAnswer = null;
      _customBusy = false;
      _rangeWindows.clear();
      _rangeBusy.clear();
      _range = HistoryRange.live;
      _devicePick.clear();
    });
    // Which reading leads is said per machine, like the rest of these.
    _focus.value = _storedFocus;
    // What `initState` does for the server the page opened on: this one's
    // buffer is empty until its own poll fills it, and the agent has the part
    // that happened before the page arrived.
    unawaited(
      ref.read(serverProvider(widget.args.spi.id).notifier).seedHistory(),
    );
  }

  @override
  void initState() {
    super.initState();
    _cardsOff.addAll(_settings.detailCardDisabled.fetch());

    // Prefill the trend buffer from whatever history the source already has,
    // so the chart cards aren't blank on a freshly opened page. A no-op for
    // sources without ServerCapabilities.storedHistory (i.e. SSH), which
    // simply accumulate from here on.
    unawaited(
      ref
          .read(serverProvider(widget.args.spi.id).notifier)
          .seedHistory(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final serverState = ref.watch(serverProvider(widget.args.spi.id));
    if (!_hasContent(serverState)) {
      return _buildNothingYet(serverState);
    }
    return _buildMainPage(serverState);
  }

  /// The page around the readings, or nothing when something else is the page.
  ///
  /// [ServerDetailPage.bare] is the server tab having grown a card into this:
  /// the bar is already up there and so is the window's own inset, so a second
  /// of each would be a page inside a page.
  Widget _hosted(ServerState si, Widget body) {
    if (widget.bare) return body;
    return Scaffold(
      // Says the machine's name and nothing about its state, so it is built
      // when that is edited rather than on every poll.
      appBar: PreferredSize(
        preferredSize: CustomAppBar.calcPreferredSize(),
        child: BuiltFrom(
          [si.spi, PaneScope.closeDetailOf(context) != null, context.isDark],
          builder: (_) => _buildAppBar(si),
        ),
      ),
      // The tab's body carries this already, and a page pushed on its own is
      // outside that. It was a scaler handed to five of this page's texts
      // instead, which replaces the system's for those five: on a phone with
      // its text turned down they were a fifth larger than the rest of the
      // card they were in.
      body: SafeArea(child: ServerTextScale(child: body)),
    );
  }

  bool _hasContent(ServerState state) => serverDetailHasContent(state);

  Widget _buildMainPage(ServerState si) {
    // What this connection can actually serve, asked once and used twice: to
    // decide whether the row is drawn at all, and then as the row's content.
    //
    // Asked of the entries rather than of one capability. `capabilities
    // .terminal` was the gate, and it hid the whole row on a monitor server
    // whose agent grants `[remote_access.fs]` but not `full_access` — that
    // server has a Files button and nothing else, and it went missing from its
    // own page while the Files tab went on listing it.
    // Whether any of them can be used. An entry this connection cannot serve
    // is still on the row, dimmed and last; a row of nothing but those is not
    // a row, and what belongs in its place is the explanation below.
    final (entries: funcBtns, any: buildFuncs) = serverDetailFuncBtns(si);
    final logo = _buildLogo(si);

    // Everything that is not one of the metrics: a table or a one-off reading,
    // which is what makes it a card rather than a row.
    // A layer each, so a poll paints the ones that changed rather than all of
    // them — see `_buildMetricRow`.
    final cards = <Widget>[
      for (final entry in _cardBuildMap.entries)
        if (!_cardsOff.contains(entry.key.name))
          if (entry.value(si) case final card?) RepaintBoundary(child: card),
    ];
    // Beside the readings rather than under them, in the column that says how
    // this machine is reached: the readings are fine and this is about the row
    // of things to do, so it belongs with the facts about the connection and
    // not at the end of what the page came to show. Nothing is drawn while the
    // func bar is there — this only explains a bar that is missing.
    final noAccess = buildFuncs ? null : _buildNoRemoteAccessCard(si);

    // The readings for each of the two shapes this page takes, kept between
    // the builder's runs and dropped whenever this method is called again.
    //
    // A `LayoutBuilder` runs its builder again whenever anything inside it is
    // dirty, not only when its constraints change. While the card that became
    // this page is still growing, the entrance below is dirty on every frame —
    // so without this the whole page, chart and tables included, was built
    // afresh sixty times a second to be moved a few points and faded.
    final byWidth = <bool, Widget>{};

    return _hosted(
      si,
      Stack(
          children: [
            LayoutBuilder(
              builder: (_, cons) => byWidth.putIfAbsent(
                // Of the room this page has, not of the window: inside a pane
                // it is the pane that has to hold two columns.
                cons.maxWidth >= ServerCardSizes.columnsWidth,
                () => _buildReadings(
                  si,
                  logo: logo,
                  cards: cards,
                  bottomInset: buildFuncs ? _kFuncBarInset : 0,
                  noAccess: noAccess,
                  wide: cons.maxWidth >= ServerCardSizes.columnsWidth,
                ),
              ),
            ),
            // Pinned above the readings rather than scrolling with them: it is
            // about the page, and what it says — that the first answer is on
            // its way — stops being true the moment it arrives.
            if (serverNeverSampled(si))
              const Positioned(
                top: 0,
                left: 0,
                right: 0,
                child: LinearProgressIndicator(
                  minHeight: 3,
                  backgroundColor: Colors.transparent,
                ),
              ),
            // Over the page rather than at the top of it. These act on the
            // server, not on any one card, so they belong within reach the
            // whole way down instead of scrolling off after the first chart.
            //
            // The tab hosts its own when it hosts this page — see
            // [ServerDetailPage.bare].
            if (buildFuncs && !widget.bare)
              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                child: HideOnScroll(
                  controller: _scrollCtrl,
                  // A third of this page's elements, and about the machine
                  // rather than about what it is doing: the same buttons on
                  // every poll.
                  child: BuiltFrom(
                    [si.spi, ...funcBtns],
                    builder: (_) => ServerFuncBar(spi: si.spi, btns: funcBtns),
                  ),
                ),
              ),
          ],
        ),
    );
  }

  /// Something the card this page grew out of has no counterpart for, coming
  /// in while that card is still growing.
  ///
  /// Moved rather than laid out differently: what this wraps sits where it
  /// will end up from the first frame, so the readings it is measured against
  /// never shift because it arrived. Nothing at all when the page was not
  /// arrived at that way — see [ServerDetailPage.entrance].
  ///
  /// The curve leaves at rest and gathers pace, which is what keeps it out of
  /// the way of the cards the grid is still fading out underneath.
  Widget _entering(Widget child, {required Offset from}) {
    final entrance = widget.entrance;
    if (entrance == null) return child;
    return AnimatedBuilder(
      animation: entrance,
      // Its own layer, so what happens each frame is an offset and an alpha on
      // a picture that is already drawn. Without it the whole column — every
      // card of facts, every table — is rasterised again for each frame of the
      // movement.
      child: RepaintBoundary(child: child),
      builder: (_, child) {
        final t = Curves.easeInOutCubic.transform(
          entrance.value.clamp(0.0, 1.0),
        );
        // The same two layers once it has arrived, rather than the child
        // handed back bare: that is a different parent at 1 from the one at
        // anything less, so every card of facts and every table was
        // unmounted, built and laid out again on the last frame of the way in
        // and the first of the way back. At 1 neither costs anything — full
        // opacity paints the child directly, and a translation by zero is an
        // offset.
        return Opacity(
          opacity: t,
          child: Transform.translate(offset: from * (1 - t), child: child),
        );
      },
    );
  }

  /// The readings: one metric drawn in full with the rest as rows, and beside
  /// them what the machine is and everything that is a table rather than a
  /// trend.
  ///
  /// Two columns only where both fit. Below that the facts go under the rows
  /// rather than beside them, because a 330pt column takes the chart down to
  /// something too narrow to read a shape in.
  Widget _buildReadings(
    ServerState si, {
    required Widget? logo,
    required List<Widget> cards,
    required double bottomInset,
    required bool wide,
    Widget? noAccess,
  }) {
    final metrics = <Widget>[
      ?logo,
      ?_buildErrCard(si),
      ?_buildStaleCard(si),
      // Laid out whether or not it is painted: what is beside it and under it
      // is placed against it — see [ServerDetailPage.readingsShowing].
      Opacity(
        opacity: widget.readingsShowing ? 1 : 0,
        child: IgnorePointer(
          ignoring: !widget.readingsShowing,
          child: _buildMetrics(si, wide: wide),
        ),
      ),
      // Under the readings rather than in the column beside them: these are
      // tables — sensor rows, GPU processes, SMART attributes — and a 330pt
      // column is not a width any of them was written for.
      if (wide) ...[
        UIs.height13,
        // From below, because that is the edge it is arriving past.
        _entering(
          ServerDetailCardGrid(cards: cards),
          from: const Offset(0, 24),
        ),
      ],
    ];
    final asideItems = <Widget>[
      ..._buildInfoCards(si),
      ?noAccess,
      if (!wide) ServerDetailCardGrid(cards: cards),
    ];
    // In from the side it sits on when there is one, and from below when it is
    // under the readings instead.
    final aside = _entering(
      Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: asideItems,
      ),
      from: wide ? const Offset(24, 0) : const Offset(0, 24),
    );

    return SingleChildScrollView(
      controller: _scrollCtrl,
      // Match the grid's top inset so the card-to-detail transition does not
      // introduce a vertical jump.
      padding: EdgeInsets.fromLTRB(13, 4, 13, bottomInset + 13),
      child: wide
          ? Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: metrics,
                  ),
                ),
                UIs.width13,
                SizedBox(width: ServerCardSizes.aside, child: aside),
              ],
            )
          : Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [...metrics, UIs.height13, aside],
            ),
    );
  }

  /// What the machine is, beside what it is doing.
  ///
  /// Two cards rather than one: the About rows come from the machine and
  /// change (uptime, the delay), the Hardware ones are what it is built of and
  /// do not. Kept out of the metric rows entirely, where they would be the
  /// only lines that never move.
  List<Widget> _buildInfoCards(ServerState si) {
    final about = ServerDetailInfoCard.aboutRows(si);
    final hardware = ServerDetailInfoCard.hardwareRows(si);

    return [
      // Still the About card the setting knows by name: an install that
      // switched it off keeps it off, and the switch is still in settings to
      // put it back.
      if (about.isNotEmpty && !_cardsOff.contains(ServerDetailCards.about.name))
        ServerDetailInfoCard(
          icon: MingCute.information_fill,
          title: libL10n.about,
          rows: about,
        ),
      if (hardware.isNotEmpty)
        ServerDetailInfoCard(
          icon: Icons.developer_board,
          title: l10n.hardware,
          rows: hardware,
        ),
    ];
  }

  CustomAppBar _buildAppBar(ServerState si) {
    // At the root of a detail pane there is nothing to pop, so no back button
    // is drawn and there is no way to hand the width back to the list. Null
    // everywhere else, where the implicit back button is the way out.
    final closeDetail = PaneScope.closeDetailOf(context);
    return CustomAppBar(
      leading: closeDetail == null
          ? null
          : IconButton(
              icon: const Icon(Icons.close),
              tooltip: libL10n.close,
              onPressed: closeDetail,
            ),
      title: Text(
        si.spi.name,
        style: TextStyle(
          fontSize: 20,
          color: context.isDark ? Colors.white : Colors.black,
        ),
      ),
      actions: [
        IconButton(
          icon: const Icon(Icons.share),
          tooltip: libL10n.share,
          onPressed: () => ServerShareUi.send(context, si.spi),
        ),
        // Beside Edit rather than to the right of it: the two are neighbours
        // because they are the same kind of thing at different ends of the
        // wire — Edit is this app's record of the server, this is the agent's
        // own configuration — and Edit stays the rightmost, where the primary
        // action belongs.
        ?_buildMonitorSettingsBtn(si),
        IconButton(tooltip: libL10n.edit,
          icon: const Icon(Icons.edit),
          onPressed: () async {
            final delete = await ServerEditPage.route.go(
              context,
              args: SpiRequiredArgs(si.spi),
            );
            if (delete == true) {
              context.pop();
            }
          },
        ),
      ],
    );
  }

  /// The way into the agent's own configuration, for a server that has one.
  ///
  /// Null for every other server, and asked of `spi.monitorOn` rather than of
  /// [ServerState.capabilities]: what this opens is *the agent's* settings, and
  /// a server with both transports answers capability questions as the union of
  /// the two — so a capability check would show this for an SSH-only server
  /// that happens to share a capability with an agent.
  ///
  /// The switch counts. An agent that is configured and switched off is one
  /// this app does not talk to, and editing its settings is talking to it.
  ///
  /// In the bar, not above the cards.
  ///
  /// It was a full-width card with a title and a line of explanation, sitting
  /// on top of the readings this page exists to show — and it is a way out of
  /// the page rather than anything about the machine, which is what the bar
  /// holds. It also read as a card whose content had failed to load, since
  /// every other card here has a measurement in it.
  ///
  /// Not in the function bar below the cards either: that row is things done
  /// *to* the machine, and this is the agent's own configuration.
  Widget? _buildMonitorSettingsBtn(ServerState si) {
    final monitor = si.spi.monitorOn;
    if (monitor == null) return null;

    return IconButton(
      icon: const Icon(MingCute.settings_2_line),
      tooltip: l10n.monitorSettings,
      onPressed: () => MonitorSettingsPage.route.go(
        context,
        MonitorSettingsArgs(monitor: monitor, subtitle: si.spi.name),
      ),
    );
  }

  /// The large image at the top of a server's page, as published.
  ///
  /// **Not tinted, and that is the difference from the mark.** The small one
  /// beside a server's name in a list is drawn in the row's colour, because a
  /// column of full-colour logos at the size of a line of text reads as noise
  /// (`DistIconOf`). Here there is one image, at a size where the colours are
  /// what makes it recognisable, and nothing to be consistent with.
  ///
  /// The consequence is worth keeping in mind before unifying the two: what
  /// may be drawn here is a wider set than what may be drawn there. Recolouring
  /// is a modification, and at least one project — Rocky Linux — forbids
  /// altering its mark "in any way", which is why no mark ships for it.
  Widget? _buildLogo(ServerState si) {
    final logoUrl = si.getLogoUrl(context);
    // Null, not an empty placeholder: the wrapping Padding was laid out either
    // way, leaving a band of dead space above the first card on every server
    // without a logo configured.
    if (logoUrl == null) return null;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 13),
      child: LayoutBuilder(
        builder: (_, cons) {
          final height = cons.maxWidth * 0.3;
          if (logoUrl.isSvgUrl) {
            return SvgPicture.network(
              logoUrl,
              height: height,
              width: cons.maxWidth,
              fit: BoxFit.contain,
            );
          }
          final dpr = MediaQuery.devicePixelRatioOf(context);
          return ExtendedImage.network(
            logoUrl,
            cache: true,
            cacheWidth: (cons.maxWidth * dpr).round(),
            cacheHeight: (height * dpr).round(),
            clearMemoryCacheWhenDispose: true,
            height: height,
            width: cons.maxWidth,
          );
        },
      ),
    );
  }
}

extension _ViewUtils on String {
  bool get isSvgUrl {
    final uri = Uri.tryParse(this);
    final path = uri?.path.toLowerCase() ?? toLowerCase();
    return path.endsWith('.svg');
  }
}
