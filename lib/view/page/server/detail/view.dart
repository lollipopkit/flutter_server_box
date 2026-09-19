import 'dart:async';
import 'dart:math' as math;
import 'package:extended_image/extended_image.dart';
import 'package:fl_chart/fl_chart.dart';
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
import 'package:server_box/core/service/self_addr.dart';
import 'package:server_box/data/model/app/scripts/cmd_types.dart';
import 'package:server_box/data/model/app/server_detail_card.dart';
import 'package:server_box/data/model/server/battery.dart';
import 'package:server_box/data/model/server/cpu.dart';
import 'package:server_box/data/model/server/disk.dart';
import 'package:server_box/data/model/server/disk_smart.dart';
import 'package:server_box/data/model/server/gpu.dart';
import 'package:server_box/data/model/server/sensors.dart';
import 'package:server_box/data/model/server/server.dart' as server_model;
import 'package:server_box/data/model/server/server_private_info.dart';
import 'package:server_box/data/model/server/status_history.dart';
import 'package:server_box/data/model/server/system.dart';
import 'package:server_box/data/model/server/try_limiter.dart';
import 'package:server_box/data/provider/bmc/bmc.dart';
import 'package:server_box/data/provider/server/all.dart';
import 'package:server_box/data/provider/server/single.dart';
import 'package:server_box/data/res/chart_palette.dart';
import 'package:server_box/data/res/store.dart';
import 'package:server_box/data/res/url.dart';
import 'package:server_box/view/page/pve.dart';
import 'package:server_box/view/page/server/card/card.dart';
import 'package:server_box/view/page/server/card/metric.dart';
import 'package:server_box/view/page/server/detail/window_gaps.dart';
import 'package:server_box/view/page/server/edit/edit.dart';
import 'package:server_box/view/page/server/monitor_settings/page.dart';
import 'package:server_box/view/widget/server_func_btns.dart';
import 'package:server_box/view/widget/server_share.dart';

part 'cards.dart';
part 'metrics.dart';
part 'misc.dart';

class ServerDetailPage extends ConsumerStatefulWidget {
  final SpiRequiredArgs args;

  /// Whether this is a page of its own or the inside of one.
  ///
  /// The server tab grows a card into this rather than pushing it, so there is
  /// already a bar over it carrying the way back and the switcher between
  /// machines — and a second one under it would be the page saying its own
  /// name twice.
  final bool bare;

  const ServerDetailPage({super.key, required this.args, this.bare = false});

  @override
  ConsumerState<ServerDetailPage> createState() => _ServerDetailPageState();

  static const route = AppRouteArg(
    page: ServerDetailPage.new,
    path: '/servers/detail',
  );
}

/// Left over on either side of the bar, so the page it floats above is still
/// visible past it and it never reads as a second edge to the window.
const _kFuncBarSideRoom = 100.0;

/// One row of buttons with their labels: a 17pt icon over a line of 11pt text,
/// plus the buttons' own inset and the row's, and a little over.
const _kFuncBarHeight = 56.0;

/// What the grid keeps clear below its last card, so the bar is never over
/// something that cannot be scrolled out from under it.
const _kFuncBarInset = _kFuncBarHeight + 26;

/// From here the facts sit beside the readings rather than under them.
///
/// Below it the chart would be left under 400pt, which is too narrow to read
/// a shape in — and the facts are what can afford to wait, since they are the
/// part of the page that does not move.
const _kColumnsWidth = 800.0;

/// The column the facts and the tables sit in.
const _kAsideWidth = 330.0;

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
  late _MetricKind _focusMetric = _storedFocus ?? _MetricKind.cpu;

  _MetricKind? get _storedFocus {
    final kind = ServerPromoted.of(widget.args.spi.id);
    if (kind == null) return null;
    return _MetricKind.values.firstWhereOrNull((e) => e.name == kind.name);
  }

  /// Which of a metric's devices the chart draws, where the reader has said.
  /// Absent means [_Devices.defaults], which is what a page opens on.
  final _devicePick = <_MetricKind, Set<String>>{};

  /// The window the chart draws when the reader named one outright, and what
  /// came back for it.
  ///
  /// Wins over [_range] while it is set: the presets are the common windows,
  /// not the only ones an agent can answer for, and what it keeps is the
  /// agent's to say — see `MonitorCapabilities.historyFrom`.
  ({DateTime from, DateTime to})? _custom;
  _RangeAnswer? _customAnswer;
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
  _HistoryRange _range = _HistoryRange.live;
  /// What a range answered, and when it was asked.
  ///
  /// The instant is what the axis is anchored to: a window kept for the length
  /// of a visit would otherwise slide forward against a chart that is not
  /// being refetched, and the gap at its end would grow without anything
  /// having happened.
  final _rangeWindows = <_HistoryRange, _RangeAnswer>{};
  final _rangeBusy = <_HistoryRange>{};

  final _settings = Stores.setting;

  /// Shared by the grid and the bar floating over it, which is how the bar
  /// knows to get out of the way.
  final _scrollCtrl = ScrollController();

  /// The card the rows promote a metric into, so that tapping one can bring it
  /// back on screen — see `_revealFocus`.
  final _focusCardKey = GlobalKey();
  late final _collapse = _settings.collapseUIDefault.fetch();
  late final _textFactor = TextScaler.linear(_settings.textFactor.fetch());
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
      _range = _HistoryRange.live;
      _devicePick.clear();
    });
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

  /// A server with nothing to show, and why.
  ///
  /// One shape for every reason — cannot connect, waiting for permission to
  /// use a plaintext address, answered with nothing: a glyph, a sentence, the
  /// machine's own words underneath, and the actions that change the answer.
  /// The row of things to do stays where it is, greyed: it is not that the
  /// entries went away, it is that nothing can be done through a connection
  /// that is not there, and the positions are worth keeping.
  Widget _buildNothingYet(ServerState si) {
    final notice = _noticeOf(si);

    return _hosted(
      si,
      Stack(
          children: [
            ListView(
              padding: EdgeInsets.fromLTRB(26, 26, 26, _kFuncBarInset + 26),
              children: [
                Icon(
                  notice.glyph,
                  size: 56,
                  color: Theme.of(context).colorScheme.outlineVariant,
                ),
                UIs.height13,
                Text(
                  notice.title,
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 21, fontWeight: FontWeight.w500),
                ),
                if (notice.text.isNotEmpty) ...[
                  UIs.height13,
                  Text(
                    notice.text,
                    textAlign: TextAlign.center,
                    style: UIs.textGrey,
                  ),
                ],
                // What the machine said, as it said it. Selectable and in full:
                // an address or an errno is the part someone needs to paste
                // somewhere, and truncating it is what sends them to the logs.
                if (notice.mono.isNotEmpty) ...[
                  UIs.height13,
                  CardX(
                    child: Padding(
                      padding: const EdgeInsets.all(13),
                      child: SelectableText(
                        notice.mono,
                        textAlign: TextAlign.center,
                        style: UIs.text12Grey.copyWith(fontFamily: 'monospace'),
                      ),
                    ),
                  ),
                ],
                UIs.height13,
                Wrap(
                  alignment: WrapAlignment.center,
                  spacing: 9,
                  runSpacing: 9,
                  children: notice.actions,
                ),
                if (notice.hint.isNotEmpty) ...[
                  UIs.height13,
                  Text(
                    notice.hint,
                    textAlign: TextAlign.center,
                    style: UIs.text11Grey,
                  ),
                ],
              ],
            ),
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: _buildFuncBar(si, [
                for (final entry in serverFuncBtnsFor(si.spi, si.remoteAccess))
                  (btn: entry.btn, available: false),
              ]),
            ),
          ],
        ),
    );
  }

  /// The page around the readings, or nothing when something else is the page.
  ///
  /// [ServerDetailPage.bare] is the server tab having grown a card into this:
  /// the bar is already up there and so is the window's own inset, so a second
  /// of each would be a page inside a page.
  Widget _hosted(ServerState si, Widget body) {
    if (widget.bare) return body;
    return Scaffold(appBar: _buildAppBar(si), body: SafeArea(child: body));
  }

  /// Which of the three this is, and what it says.
  ({
    IconData glyph,
    String title,
    String text,
    String mono,
    List<Widget> actions,
    String hint,
  })
  _noticeOf(ServerState si) {
    final err = si.status.err;
    // `connected` counts: the SSH path sits there through system detection and
    // the script install, two round trips during which there is still nothing
    // to show. Reading it as "not busy" put "Empty" and a Retry button in
    // front of a server that was in the middle of connecting — and disagreed
    // with the server card, which has always treated the three as one state.
    final busy =
        si.conn == server_model.ServerConn.connecting ||
        si.conn == server_model.ServerConn.connected ||
        si.conn == server_model.ServerConn.loading;

    final retry = Btn.elevated(
      text: libL10n.retry,
      icon: const Icon(Icons.refresh, size: 18),
      // The icon variant lays its row out at max size, so without this the
      // button fills whatever it is given and reads as a list row.
      mainAxisSize: MainAxisSize.min,
      gap: 8,
      onTap: () => _reconnect(si),
    );
    final edit = Btn.text(
      text: libL10n.edit,
      onTap: () => ServerEditPage.route.go(
        context,
        args: SpiRequiredArgs(si.spi),
      ),
    );

    // Asked before the error is read: a connection this app has not been
    // allowed to make has not been tried, so whatever else is on `err` is
    // about an earlier address or an earlier setting.
    final monitor = si.spi.monitorHttp;
    if (monitor != null && monitor.needsInsecureOptIn) {
      return (
        glyph: Icons.no_encryption_gmailerrorred_outlined,
        // What is true, not what the setting is called: nothing has been sent
        // to this address yet, and what the button turns on is the sending.
        title: l10n.plainHttpTitle,
        text: l10n.plainHttpTip,
        mono: monitor.addr,
        actions: [
          Btn.elevated(
            // Says what it does to what: the switch it flips is this server's
            // and not a default, which is the question anyone reading this
            // screen is asking.
            text: l10n.allowForThisServer,
            icon: const Icon(Icons.lock_open, size: 18),
            mainAxisSize: MainAxisSize.min,
            gap: 8,
            onTap: () => _allowInsecure(si),
          ),
          edit,
        ],
        hint: l10n.monitorAllowInsecureHttpTip,
      );
    }

    if (err != null) {
      return (
        glyph: Icons.link_off,
        title: err.solution ?? libL10n.fail,
        text: '',
        mono: err.message ?? '',
        actions: [
          retry,
          // The message above is the error's own line; this is everything
          // around it — what the app was doing, and the copy button a bug
          // report needs.
          Btn.text(
            text: l10n.viewError,
            onTap: () => _showErrDetail(si, err),
          ),
          edit,
        ],
        hint: '',
      );
    }

    return (
      glyph: busy ? Icons.hourglass_empty : Icons.inbox_outlined,
      // "Empty" is what a server that answered and had nothing to say would
      // be. One that has not answered yet is connecting, and saying so is the
      // difference between waiting and wondering.
      title: busy ? l10n.waitConnection : libL10n.empty,
      text: '',
      mono: '',
      actions: busy ? const [] : [retry, edit],
      hint: '',
    );
  }

  /// The error as markdown: what to do about it, then what was actually said.
  String _errMarkdown(Err err) {
    return '''
${err.solution ?? libL10n.unknown}

```sh
${err.message ?? 'null'}
```
''';
  }

  /// Saving is the whole of it: `Spi.shouldReconnect` counts a changed
  /// `monitorHttp` — and `MonitorHttpCredential.==` counts `allowInsecure` —
  /// so `updateServer` clears the retry limiter and refreshes on its own.
  /// Reconnecting here as well would be a second attempt at the same thing.
  Future<void> _allowInsecure(ServerState si) async {
    final monitor = si.spi.monitorHttp;
    if (monitor == null) return;
    try {
      await ref
          .read(serversProvider.notifier)
          .updateServer(si.spi, si.spi.copyWith(monitorHttp: monitor.allowingInsecure()));
    } catch (e, s) {
      if (mounted) context.showErrDialog(e, s);
    }
  }

  /// Clears the retry limiter first: the user asking again *is* the new
  /// information, and without this the request is dropped by the backoff that
  /// the previous failures installed.
  void _reconnect(ServerState si) {
    TryLimiter.reset(si.spi.id);
    ref.read(serversProvider.notifier).refresh(spi: si.spi);
  }

  /// Whether there is anything to render.
  ///
  /// Losing the connection must not empty the page: the status already
  /// fetched is still the most recent thing known about the server, and the
  /// error card below explains why it stopped updating. Collapsing to the
  /// placeholder on `ServerConn.failed` threw both away, so a monitor going
  /// offline looked identical to a server that had never been opened.
  ///
  /// `more` is the "has ever been fetched" signal — every successful status
  /// apply populates it on both transports, and `keepStatusWhenErr` in
  /// `ServerNotifier` already relies on that.
  bool _hasContent(ServerState state) {
    if (state.status.more.isNotEmpty) return true;
    // Connecting is something to show: the rows every machine has, drawn with
    // dashes, under a progress line. What this used to do instead — a spinner
    // and "waiting for connection" — made the page arrive twice, once as a
    // placeholder and once as itself, with everything in a different place.
    if (state.conn == server_model.ServerConn.connecting ||
        state.conn == server_model.ServerConn.connected ||
        state.conn == server_model.ServerConn.loading) {
      return true;
    }
    // Having a connection is not having anything to show. Read as "connected
    // is enough", this page opened onto a grid of empty cards — dashes where
    // the CPU goes, `0% of 1 KB` for the disk — for as long as the first fetch
    // took, which on a server that is merely slow is a while. `finished` is
    // the state that means a status came back; it is only ever left for
    // another *later* fetch, so the page does not flicker back on refresh.
    return state.conn == server_model.ServerConn.finished;
  }

  Widget _buildMainPage(ServerState si) {
    // What this connection can actually serve, asked once and used twice: to
    // decide whether the row is drawn at all, and then as the row's content.
    //
    // Asked of the entries rather than of one capability. `capabilities
    // .terminal` was the gate, and it hid the whole row on a monitor server
    // whose agent grants `[remote_access.fs]` but not `full_access` — that
    // server has a Files button and nothing else, and it went missing from its
    // own page while the Files tab went on listing it.
    final funcBtns = serverFuncBtnsFor(si.spi, si.remoteAccess);
    // Whether any of them can be used. An entry this connection cannot serve
    // is still on the row, dimmed and last; a row of nothing but those is not
    // a row, and what belongs in its place is the explanation below.
    final buildFuncs = funcBtns.any((e) => e.available);
    final logo = _buildLogo(si);

    // Everything that is not one of the metrics: a table or a one-off reading,
    // which is what makes it a card rather than a row.
    final cards = <Widget>[
      for (final entry in _cardBuildMap.entries)
        if (!_cardsOff.contains(entry.key.name)) ?entry.value(si),
    ];
    // Beside the readings rather than under them, in the column that says how
    // this machine is reached: the readings are fine and this is about the row
    // of things to do, so it belongs with the facts about the connection and
    // not at the end of what the page came to show. Nothing is drawn while the
    // func bar is there — this only explains a bar that is missing.
    final noAccess = buildFuncs ? null : _buildNoRemoteAccessCard(si);

    return _hosted(
      si,
      Stack(
          children: [
            LayoutBuilder(
              builder: (_, cons) => _buildReadings(
                si,
                logo: logo,
                cards: cards,
                bottomInset: buildFuncs ? _kFuncBarInset : 0,
                noAccess: noAccess,
                // Of the room this page has, not of the window: inside a pane
                // it is the pane that has to hold two columns.
                wide: cons.maxWidth >= _kColumnsWidth,
              ),
            ),
            // Pinned above the readings rather than scrolling with them: it is
            // about the page, and what it says — that the first answer is on
            // its way — stops being true the moment it arrives.
            if (_neverSampled(si))
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
            if (buildFuncs)
              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                child: HideOnScroll(
                  controller: _scrollCtrl,
                  child: _buildFuncBar(si, funcBtns),
                ),
              ),
          ],
        ),
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
      _buildMetrics(si, wide: wide),
      // Under the readings rather than in the column beside them: these are
      // tables — sensor rows, GPU processes, SMART attributes — and a 330pt
      // column is not a width any of them was written for.
      if (wide) ...[UIs.height13, _buildCardGrid(cards)],
    ];
    final aside = <Widget>[
      ..._buildInfoCards(si),
      ?noAccess,
      if (!wide) _buildCardGrid(cards),
    ];

    return SingleChildScrollView(
      controller: _scrollCtrl,
      padding: EdgeInsets.fromLTRB(13, 7, 13, bottomInset + 13),
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
                SizedBox(
                  width: _kAsideWidth,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: aside,
                  ),
                ),
              ],
            )
          : Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [...metrics, UIs.height13, ...aside],
            ),
    );
  }

  /// That every figure on this page was taken a while ago, and the way to ask
  /// again.
  ///
  /// Above the readings, because it is about all of them. Not shown when the
  /// error card is: that card already says why the numbers stopped, and two
  /// cards saying it in different words is one of them too many.
  Widget? _buildStaleCard(ServerState si) {
    if (si.status.err != null) return null;
    final at = _staleSince(si);
    if (at == null) return null;

    return CardX(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(17, 9, 9, 9),
        child: Row(
          children: [
            const Icon(
              Icons.pause_circle_outline,
              size: 18,
              color: Color(0xFFF59E0B),
            ),
            UIs.width13,
            Expanded(
              child: Text(
                l10n.staleSinceFmt(
                  at.toAgoStr(),
                  _clockOf(at.millisecondsSinceEpoch),
                ),
                style: UIs.text12Grey,
              ),
            ),
            UIs.width7,
            Btn.text(text: libL10n.refresh, onTap: () => _reconnect(si)),
          ],
        ),
      ),
    );
  }

  /// Why there is no row of things to do, for a server whose agent grants
  /// nothing.
  ///
  /// Only when the agent has answered: `remoteAccess` is null before the first
  /// poll and for an agent too old to have `/capabilities`, and "we have not
  /// asked yet" must not be drawn as "you are not allowed".
  ///
  /// Only for a server reached *only* through an agent. One that also has SSH
  /// has the row anyway, so there is nothing to explain — and a server with no
  /// agent at all is not what this is about.
  ///
  /// Informational, not a warning. Every switch under `[remote_access]` is off
  /// by default and the docs recommend leaving them that way, so most agents
  /// are in this state on purpose and a red card would be nagging the people
  /// who got it right. What was missing was not a warning but an answer to
  /// "why is there nothing here".
  Widget? _buildNoRemoteAccessCard(ServerState si) {
    if (si.spi.monitorHttp == null || si.spi.ssh != null) return null;
    if (si.remoteAccess == null) return null;

    return CardX(
      child: ListTile(
        leading: const Icon(MingCute.lock_line, size: 20),
        title: Text(l10n.monitorNoRemoteAccess, style: UIs.text12Grey),
        trailing: const Icon(Icons.open_in_new, size: 17),
        onTap: Urls.monitorPermissionsDoc.launchUrl,
      ),
    );
  }

  /// The row of things that can be done to this server, floating over it.
  ///
  /// Takes the entries rather than working them out, so that what is drawn is
  /// the same list `_buildMainPage` decided there was room for.
  Widget _buildFuncBar(ServerState si, List<ServerFuncEntry> btns) {
    return LayoutBuilder(
      builder: (_, cons) => Center(
        child: Padding(
          padding: const EdgeInsets.only(bottom: 13),
          child: ConstrainedBox(
            // The row takes the width it needs up to this; beyond it, it
            // scrolls. Stretched across a desktop window it would stop being a
            // group of buttons and become a band across the page.
            constraints: BoxConstraints(
              maxWidth: (cons.maxWidth - _kFuncBarSideRoom).clamp(
                0.0,
                double.infinity,
              ),
            ),
            child: Material(
              // Raised off the page, because it is the one thing here that is
              // not part of what the page is showing.
              elevation: 3,
              shadowColor: Colors.black26,
              color: Theme.of(context).colorScheme.surfaceContainerHigh,
              borderRadius: BorderRadius.circular(19),
              clipBehavior: Clip.antiAlias,
              child: SizedBox(
                height: _kFuncBarHeight,
                child: ServerFuncBtns(spi: si.spi, btns: btns),
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// Why the status stopped updating. Sits above the cards, which keep
  /// showing the last successful reading — stale data with a visible reason
  /// beats a blank page.
  Widget? _buildErrCard(ServerState si) {
    final err = si.status.err;
    if (err == null) return null;

    final solution = err.solution;
    return CardX(
      child: ListTile(
        leading: const Icon(Icons.error_outline, color: Colors.red, size: 20),
        title: Text(libL10n.error, style: UIs.text15),
        subtitle: Text(
          solution ?? err.message ?? libL10n.unknown,
          style: UIs.text12Grey,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
        trailing: const Icon(Icons.chevron_right, size: 17),
        onTap: () => _showErrDetail(si, err),
      ),
    );
  }

  /// A server that has reported before shows its failure here rather than on
  /// the empty page, so the same one-tap answer has to be offered in both.
  void _showErrDetail(ServerState si, Err err) {
    final md = _errMarkdown(err);
    context.showRoundDialog(
      title: libL10n.error,
      child: SingleChildScrollView(child: SimpleMarkdown(data: md)),
      actions: [
        if (si.spi.monitorHttp?.needsInsecureOptIn == true)
          TextButton(
            // Closes the dialog itself and leaves the work to the page: an
            // `onPressed` replaces the navigator the button would have
            // resolved on its own — see the dialog rules in CLAUDE.md.
            onPressed: () {
              context.popDialog();
              _allowInsecure(si);
            },
            child: Text(l10n.monitorAllowInsecureHttp),
          ),
        TextButton(onPressed: () => Pfs.copy(md), child: Text(libL10n.copy)),
        TextButton(onPressed: () => context.popDialog(), child: Text(libL10n.close)),
      ],
    );
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

  List<Widget> _buildCPUProgress(Cpus cs) {
    const kMaxColumn = 2;
    const kRowThreshold = 4;
    const kCoresCountThreshold = kMaxColumn * kRowThreshold;
    final children = <Widget>[];
    final displayCpuIndexSetting = _displayCpuIndex;

    if (cs.coresCount >= kCoresCountThreshold) {
      final numCoresToDisplay = cs.coresCount;
      final numRows = (numCoresToDisplay + kMaxColumn - 1) ~/ kMaxColumn;

      for (var i = 0; i < numRows; i++) {
        final rowChildren = <Widget>[];
        for (var j = 0; j < kMaxColumn; j++) {
          final coreListIndex = i * kMaxColumn + j;
          if (coreListIndex >= numCoresToDisplay) break;

          final coreNumberOneBased = coreListIndex + 1;

          if (displayCpuIndexSetting) {
            rowChildren.add(Text('$coreNumberOneBased', style: UIs.text13Grey));
          }
          rowChildren.add(
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 3),
                child: _buildProgress(
                  cs.usedPercent(coreIdx: coreNumberOneBased),
                ),
              ),
            ),
          );
        }
        if (rowChildren.isNotEmpty) {
          children.add(
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 17),
              child: Row(children: rowChildren.joinWith(UIs.width7).toList()),
            ),
          );
        }
      }
    } else {
      for (var i = 1; i <= cs.coresCount; i++) {
        children.add(
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 3, horizontal: 17),
            child: _buildProgress(cs.usedPercent(coreIdx: i)),
          ),
        );
      }
    }

    return children;
  }


  Widget _buildProgress(double? percent) {
    // Indeterminate while there is no reading, instead of a full-width 0 bar
    final percentWithinOne = percent == null
        ? null
        : percent.clamp(0, 100) / 100;
    return LinearProgressIndicator(
      value: percentWithinOne,
      minHeight: 7,
      backgroundColor: UIs.halfAlpha,
      color: UIs.primaryColor,
    );
  }

  /// The cards, not the load: what a GPU is doing is the row above, and what
  /// is left is a table — the memory each card has left, its clock and fans,
  /// and the processes holding that memory.
  Widget? _buildGpuView(ServerState si) {
    final gpus = si.status.gpus;
    if (gpus.isEmpty) return null;
    final mem = _busiestGpu(si.status)?.memory;
    final processes = [for (final gpu in gpus) ...?gpu.memory?.processes];

    return _buildReadoutCard(
      cardKey: 'gpu',
      icon: ServerDetailCards.gpu.icon,
      title: 'GPU',
      headline: mem == null
          ? null
          : (
              value: '${mem.used} ${mem.unit}',
              note: [
                l10n.ofFmt('${mem.total} ${mem.unit}'),
                if (processes.isNotEmpty) l10n.processesFmt(processes.length),
              ].join(' · '),
            ),
      rows: gpus.map(_buildGpuItem).toList(),
      footer: _countNote(gpus.length, l10n.unitGpus),
      initiallyExpanded: _getInitExpand(gpus.length, 3),
    );
  }

  Widget _buildGpuItem(GpuItem item) {
    final mem = item.memory;
    final details = [
      ?item.power,
      if (item.fanSpeed != null)
        '${l10n.fan} ${item.fanSpeed}${item.vendor == 'nvidia' ? '%' : ' RPM'}',
      if (item.clockSpeed != null) '${item.clockSpeed} MHz',
      if (mem != null) '${mem.used} / ${mem.total} ${mem.unit}',
    ];
    return _buildReadoutRow(
      k: '${item.name} · ${item.id}',
      sub: details.isEmpty ? null : details.join(' · '),
      v: [
        if (item.utilization case final util?) _pct(util),
        if (item.temperature case final t?) _formatTemp(t.toDouble()),
      ].join(' · '),
      // Every card, not only the ones holding a process: the row is one line
      // of a card that has a dozen readings, and which of them fit there is
      // not a reason to make some cards openable and others dead.
      onTap: () => _onTapGpuItem(item),
    );
  }

  Widget _buildDiskItemWithHierarchy(
    Disk disk,
    server_model.ServerStatus ss,
    int depth,
  ) {
    // Create a list to hold this disk and its children
    final items = <Widget>[];

    // Add the current disk
    items.add(_buildDiskItem(disk, ss, depth));

    // Recursively add child disks with increased indentation
    if (disk.children.isNotEmpty) {
      for (final childDisk in disk.children) {
        items.add(_buildDiskItemWithHierarchy(childDisk, ss, depth + 1));
      }
    }

    return Column(children: items);
  }

  Widget _buildDiskItem(Disk disk, server_model.ServerStatus ss, int depth) {
    final (read, write) = ss.diskIO.getSpeed(disk.path);
    final text = () {
      final use = '${l10n.used} ${disk.used.kb2Str} / ${disk.size.kb2Str}';
      if (read == null || write == null) return use;
      return '$use\n${l10n.read} $read | ${l10n.write} $write';
    }();

    return Padding(
      padding: EdgeInsets.only(
        left: 17.0 + (depth * 15.0), // Indent based on depth
        right: 17.0,
        top: 5.0,
        bottom: 5.0,
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  disk.mount.isEmpty
                      ? disk.path
                      : '${disk.path} (${disk.mount})',
                  style: UIs.text12,
                  textScaler: _textFactor,
                ),
                Text(text, style: UIs.text12Grey, textScaler: _textFactor),
              ],
            ),
          ),
          if (disk.size > BigInt.zero)
            SizedBox(
              height: 41,
              width: 41,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  CircularProgressIndicator(
                    value: disk.usedPercent / 100,
                    strokeWidth: 5,
                    backgroundColor: UIs.halfAlpha,
                    color: UIs.primaryColor,
                  ),
                  Text('${disk.usedPercent}%', style: UIs.text12Grey),
                ],
              ),
            ),
        ],
      ),
    );
  }

  /// Every drive's health in one card, worst first.
  ///
  /// Six drives are not six cards: what is read off this is one conclusion —
  /// whether anything is failing — and the rows are what to look at once the
  /// answer is no longer "all of them passed". The attributes behind a drive
  /// are two dozen numbers and stay one tap away.
  Widget? _buildDiskSmart(ServerState si) {
    final smarts = si.status.diskSmart;
    if (smarts.isEmpty) {
      // `smartctl` is missing, or is there and refused: both are why this card
      // was empty, and neither was ever said. A host with no drives it can read
      // still gets nothing.
      if (si.status.sectionErrs['smart'] case final err?) {
        return _buildFailedCard(
          cardKey: 'smart',
          icon: ServerDetailCards.smart.icon,
          title: l10n.diskHealth,
          err: err,
        );
      }
      return null;
    }

    // Worst first, which is the order the rows are read in and what the
    // headline is about. A drive smartctl could not read sorts between a
    // failing one and a passing one: it is not a drive that is fine.
    final sorted = [...smarts]
      ..sort((a, b) => _smartRank(a).compareTo(_smartRank(b)));
    final worst = sorted.first;
    final wrong = smarts.where((e) => _smartRank(e) < _smartRank(_smartOk));

    DiskSmart? hottest;
    int? oldest;
    for (final smart in smarts) {
      final t = smart.temperature;
      if (t != null && (hottest == null || t > hottest.temperature!)) {
        hottest = smart;
      }
      final hours = smart.powerOnHours;
      if (hours != null && (oldest == null || hours > oldest)) oldest = hours;
    }

    final truncated = smarts.length > _kCardRows;
    return _buildReadoutCard(
      cardKey: 'smart',
      icon: ServerDetailCards.smart.icon,
      title: l10n.diskHealth,
      verdict: _smartVerdict(smarts),
      // The worst conclusion, not a count of drives: what this card answers is
      // whether anything needs replacing, and on the machine where something
      // does, which one and what it said.
      headline: wrong.isEmpty
          ? (
              value: l10n.devicesFmt(smarts.length),
              note: [
                if (hottest?.temperature case final t?)
                  '${l10n.hottest} ${_formatTemp(t)}',
                if (oldest != null) '${l10n.oldest} $oldest ${libL10n.hour}',
              ].join(' · '),
            )
          : (
              // `(total, wrong)`: with no `@` metadata gen-l10n orders the
              // placeholders alphabetically, not as the sentence reads them.
              value: l10n.diskWrongOfFmt(smarts.length, wrong.length),
              note: '${worst.device} · ${_smartSummary(worst)}',
            ),
      rows: sorted.map(_buildDiskSmartItem).toList(),
      footer: _cardFooter([
        truncated
            ? l10n.shownOfFmt(_kCardRows, smarts.length, l10n.unitDevices)
            : l10n.countOfFmt(smarts.length, l10n.unitDevices),
        truncated ? l10n.diskSmartOpenTip : l10n.diskSmartSortedTip,
      ]),
      initiallyExpanded: _getInitExpand(smarts.length),
    );
  }

  /// A passing drive, to rank the others against.
  static const _smartOk = DiskSmart(
    device: '',
    healthy: true,
    rawData: {},
    smartAttributes: {},
  );

  /// Worst first: failing, then whatever reports a non-zero critical count,
  /// then a drive that answered nothing, then the ones that passed. A device
  /// SMART does not apply to is last — it is not a drive with a problem.
  static int _smartRank(DiskSmart smart) {
    if (smart.notApplicable) return 4;
    if (smart.healthy == false) return 0;
    if (smart.faults.isNotEmpty) return 1;
    if (smart.healthy == null) return 2;
    return 3;
  }

  ({String text, _Verdict tone})? _smartVerdict(List<DiskSmart> smarts) {
    final failing = smarts.where((e) => e.healthy == false).length;
    if (failing > 0) {
      return (text: l10n.diskFailingFmt(failing), tone: _Verdict.bad);
    }
    final warning = smarts
        .where((e) => !e.notApplicable && (e.healthy == null || e.faults.isNotEmpty))
        .length;
    if (warning > 0) {
      return (text: l10n.diskWarningFmt(warning), tone: _Verdict.warn);
    }
    return (text: l10n.diskAllPassed, tone: _Verdict.ok);
  }

  /// What a drive says about itself in one phrase: the first count that should
  /// have been zero, or SMART's own verdict when they all are.
  String _smartSummary(DiskSmart smart) {
    if (smart.notApplicable) return l10n.notApplicable;
    final fault = smart.faults.entries.firstOrNull;
    if (fault != null) return '${fault.value} ${fault.key}';
    return switch (smart.healthy) {
      null => libL10n.unknown,
      true => 'PASSED',
      false => 'FAILING',
    };
  }

  Widget _buildDiskSmartItem(DiskSmart smart) {
    final applicable = !smart.notApplicable;
    return _buildReadoutRow(
      k: smart.device,
      sub: smart.model,
      v: [
        _smartSummary(smart),
        if (smart.temperature case final t?) _formatTemp(t),
      ].join(' · '),
      dot: _smartTone(smart).color(Theme.of(context).colorScheme),
      // Nothing to open for a device with no attributes, and a chevron that
      // opens an empty sheet is worse than no chevron.
      onTap: applicable ? () => _onTapDiskSmartItem(smart) : null,
    );
  }

  _Verdict _smartTone(DiskSmart smart) {
    if (smart.notApplicable) return _Verdict.idle;
    if (smart.healthy == false) return _Verdict.bad;
    if (smart.healthy == null || smart.faults.isNotEmpty) return _Verdict.warn;
    return _Verdict.ok;
  }

  /// One drive's attributes: the readings the card has no room for.
  ///
  /// Two dozen numbers do not belong on the page — the card carries the
  /// verdict and this carries the evidence, in the order it is read in: the
  /// health line first, then the counts that should be zero, then how much
  /// the drive has been used. Each count that is not zero keeps its dot, so
  /// the row that made the card say "1 warning" is the one that stands out
  /// here too.
  void _onTapDiskSmartItem(DiskSmart smart) {
    final scheme = Theme.of(context).colorScheme;
    final rows = <({String k, String v, _Verdict? dot})>[
      (
        k: l10n.diskHealth,
        v: switch (smart.healthy) {
          null => libL10n.unknown,
          true => 'PASSED',
          false => 'FAILING',
        },
        dot: _smartTone(smart),
      ),
      for (final entry in DiskSmart.criticalAttributes.entries)
        if (smart.getAttribute(entry.key)?.rawValue case final raw?)
          (
            k: entry.value.label,
            v: '$raw',
            // Read as the count the card read it as, so a row without a dot
            // here is never one the card counted as a fault.
            dot: (DiskSmart.countOf(raw) ?? 0) > 0 ? _Verdict.warn : null,
          ),
      if (smart.powerOnHours case final hours?)
        (k: l10n.powerOnHours, v: '$hours', dot: null),
      if (smart.powerCycleCount case final cycles?)
        (k: l10n.powerCycles, v: '$cycles', dot: null),
      if (smart.ssdLifeLeft case final left?)
        (k: l10n.lifeLeft, v: '$left%', dot: null),
      if (smart.temperature case final t?)
        (k: libL10n.temperature, v: _formatTemp(t), dot: null),
      if (smart.lifetimeWritesGiB case final written?)
        (k: l10n.lifetimeWrite, v: '$written GiB', dot: null),
      if (smart.lifetimeReadsGiB case final read?)
        (k: l10n.lifetimeRead, v: '$read GiB', dot: null),
      if (smart.averageEraseCount case final erases?)
        (k: l10n.averageErase, v: '$erases', dot: null),
      if (smart.unsafeShutdownCount case final unsafe?)
        (k: l10n.unsafeShutdowns, v: '$unsafe', dot: null),
      if (smart.model case final model?) (k: 'Model', v: model, dot: null),
      if (smart.serial case final serial?) (k: 'Serial', v: serial, dot: null),
    ];

    showRowsSheet<void>(
      context,
      rows: (_) => [
        Padding(
          padding: const EdgeInsets.fromLTRB(17, 5, 17, 9),
          child: Text(
            '${smart.device} · ${l10n.attributes}',
            style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w500),
          ),
        ),
        for (final (i, row) in rows.indexed) ...[
          // A line between the readings, not around them: this is a table of
          // numbers and the rule is what keeps a name with its own value.
          if (i > 0) const Divider(height: 1, indent: 17, endIndent: 17),
          _buildReadoutRow(k: row.k, v: row.v, dot: row.dot?.color(scheme)),
        ],
        // Where the numbers came from and when: SMART is read on the extended
        // cadence, so these are minutes old while everything else on the page
        // is seconds old. The command is the other half of the answer — it is
        // what to run to see the same thing.
        Padding(
          padding: const EdgeInsets.fromLTRB(17, 13, 17, 5),
          child: Text(
            [
              'smartctl -A /dev/${smart.device}',
              if (ref.read(serverProvider(widget.args.spi.id))
                      .status
                      .diskSmartAt
                  case final at?)
                l10n.readAgoFmt(at.toAgoStr()),
            ].join(' · '),
            style: UIs.text11Grey.copyWith(fontFamily: 'monospace'),
          ),
        ),
      ],
    );
  }


  /// Every battery but the first, which is the row's.
  ///
  /// A host reporting several is reporting its peripherals — a mouse, a
  /// keyboard, a headset — and those are a table: a name, a state and a charge
  /// each, with no line worth drawing behind any of them. A machine with one
  /// battery has no card at all, because the row already says everything this
  /// would.
  Widget? _buildBatteries(ServerState si) {
    final ss = si.status;
    if (ss.batteries.length < 2) return null;

    return _buildReadoutCard(
      cardKey: 'battery',
      icon: ServerDetailCards.battery.icon,
      title: libL10n.battery,
      rows: ss.batteries.map(_buildBatteryItem).toList(),
      footer: _countNote(ss.batteries.length, l10n.unitBatteries),
      initiallyExpanded: _getInitExpand(ss.batteries.length, 2),
    );
  }

  Widget _buildBatteryItem(Battery battery) {
    return _buildReadoutRow(
      k: battery.name ?? libL10n.unknown,
      sub: [
        battery.status.name,
        if (battery.cycle case final cycle?) '${l10n.cycle} $cycle',
      ].join(' · '),
      v: _pct(battery.percent?.toDouble()),
    );
  }

  /// What `sensors` reports, which is a table and stays one: a summary line
  /// per chip, and the readings behind it on tap.
  Widget? _buildSensors(ServerState si) {
    final ss = si.status;
    if (ss.sensors.isEmpty) {
      if (ss.sectionErrs['sensors'] case final err?) {
        return _buildFailedCard(
          cardKey: 'sensor',
          icon: Icons.thermostat,
          title: libL10n.sensors,
          err: err,
        );
      }
      return null;
    }

    return _buildReadoutCard(
      cardKey: 'sensor',
      icon: Icons.thermostat,
      title: libL10n.sensors,
      rows: ss.sensors.map(_buildSensorItem).toList(),
      footer: _countNote(ss.sensors.length, l10n.unitSensors),
      initiallyExpanded: _getInitExpand(ss.sensors.length, 2),
    );
  }

  Widget _buildSensorItem(SensorItem si) {
    return _buildReadoutRow(
      k: si.device,
      sub: si.summary,
      v: si.adapter.raw,
      onTap: si.summary == null ? null : () => _onTapSensorItem(si),
    );
  }

  Widget? _buildPve(ServerState si) {
    final addr = si.spi.custom?.pveAddr;
    if (addr == null || addr.isEmpty) return null;
    // Nothing is read here: the guests are the PVE page's, and this card is
    // the way to it rather than a summary of what it will say.
    return _buildReadoutCard(
      cardKey: 'pve',
      icon: FontAwesome.server_solid,
      title: 'PVE',
      onTap: () => PvePage.route.go(context, PvePageArgs(spi: si.spi)),
    );
  }

  /// What the BMC says, which is worth showing precisely when the host is not
  /// saying anything.
  ///
  /// Absent unless configured: a card that appeared on every server to say
  /// "not configured" would be a row of noise on the machines that have no BMC,
  /// which is most of them.
  Widget? _buildBmc(ServerState si) {
    if (si.spi.bmc == null) return null;
    final bmc = ref.watch(bmcProvider(si.spi));

    final rows = <Widget>[];
    final system = bmc.topology?.system;
    if (system != null) {
      // The service's own property names, shown as it named them: they are
      // protocol identifiers, and translating them would invite drift between
      // what the card says and what the BMC's own interface says
      for (final (label, value) in [
        ('Model', system.model),
        ('BIOS', system.biosVersion),
        ('Serial', system.serial),
        ('Health', system.health),
      ]) {
        if (value == null || value.isEmpty) continue;
        rows.add(_buildReadoutRow(k: label, v: value));
      }
    }

    final sensors = bmc.sensors;
    for (final reading in [...sensors.temperatures, ...sensors.fans]) {
      rows.add(
        _buildReadoutRow(
          k: reading.name,
          v:
              '${reading.value.toStringAsFixed(reading.unit == 'Cel' ? 1 : 0)}'
              '${reading.unit == 'Cel' ? '°C' : ' ${reading.unit ?? ''}'}',
        ),
      );
    }

    return _buildReadoutCard(
      cardKey: 'bmc',
      icon: Icons.developer_board,
      // A suffix here and the full sentence in the editor, which is the
      // arrangement the Linux pages already use: the list that reaches the
      // feature carries the marker, and the place where it is turned on
      // carries the reason. Repeating `betaTip` on a card that is expanded
      // every time the page opens would make it wallpaper.
      title: 'BMC (Beta)',
      verdict: switch (bmc) {
        BmcState(failure: final failure?) => (
          text: _bmcFailureText(failure, bmc.failureDetail),
          tone: _Verdict.bad,
        ),
        BmcState(hasData: false, isBusy: true) => null,
        BmcState(powerState: PowerState.on) => (
          text: l10n.bmcPowerOn,
          tone: _Verdict.ok,
        ),
        _ => (text: _bmcPowerText(bmc.powerState), tone: _Verdict.warn),
      },
      // Draw, not state: what a BMC is asked first is how much the machine is
      // pulling, which is the one reading the host itself cannot give.
      headline: sensors.watts == null
          ? null
          : (
              value: '${sensors.watts!.toStringAsFixed(0)} W',
              note: [
                for (final fan in sensors.fans.take(1))
                  '${fan.name} ${fan.value.toStringAsFixed(0)} ${fan.unit ?? ''}',
              ].join(),
            ),
      rows: rows,
      // Below the readings and never cut off by [_kCardRows]: these are the
      // actions, and a truncated list must not be able to hide them.
      extra: [if (bmc.hasData) _buildBmcPower(si)],
      footer: _cardFooter([
        _countNote(rows.length, l10n.unitReadings),
        // Said rather than left to look like the whole truth
        if (bmc.sensorsTruncated) l10n.bmcSensorsTruncated,
        // The same reason, for the same kind of cut: discovery takes the first
        // of each collection, so a blade enclosure showed node 1's power state
        // with nothing to say the other nodes existed — and a power action
        // there targets that node alone.
        if (bmc.topology?.hasMultipleSystems == true) l10n.bmcMultipleSystems,
      ]),
      initiallyExpanded: _getInitExpand(rows.length),
    );
  }

  /// The power actions this particular service allows, and no others.
  ///
  /// Asked of `plan`, which resolves an intent against
  /// `ResetType@Redfish.AllowableValues`. An intent the service allows nothing
  /// for is not shown: offering a button that fails when pressed is worse than
  /// never having offered it, and `Nmi` and `PowerCycle` are advertised
  /// unimplemented often enough that this is not hypothetical.
  Widget _buildBmcPower(ServerState si) {
    final notifier = ref.read(bmcProvider(si.spi).notifier);
    final available = [
      for (final intent in PowerIntent.values)
        if (notifier.plan(intent) != null) intent,
    ];
    if (available.isEmpty) return UIs.placeholder;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 7),
      child: Wrap(
        spacing: 7,
        runSpacing: 7,
        children: [
          for (final intent in available)
            OutlinedButton(
              onPressed: () => _onTapBmcPower(si, intent),
              child: Text(_bmcIntentText(intent)),
            ),
        ],
      ),
    );
  }

  Future<void> _onTapBmcPower(ServerState si, PowerIntent intent) async {
    final notifier = ref.read(bmcProvider(si.spi).notifier);
    final request = notifier.plan(intent);
    if (request == null) return;

    // The one thing in this app that can take a running server away from
    // whoever is on it. The dialog names the ResetType actually chosen, not the
    // intent, because they differ — a "restart" is ForceRestart on hardware
    // that has no graceful one, and that is worth seeing before agreeing.
    final ok = await context.showRoundDialog<bool>(
      title: _bmcIntentText(intent),
      child: Text(l10n.bmcPowerConfirm(si.spi.name, request.resetType)),
      actions: Btnx.cancelRedOk,
    );
    if (ok != true) return;

    final result = await notifier.power(intent);
    switch (result) {
      case BmcPowerResult.confirmed:
        Toast.success(l10n.bmcPowerDone);
      // Accepted is not done, and saying so would be reporting the request
      // back as though it were the result
      case BmcPowerResult.accepted:
        Toast.warn(l10n.bmcPowerAccepted);
      case BmcPowerResult.notSupported:
        Toast.error(libL10n.fail, body: l10n.bmcPowerUnsupported);
      case BmcPowerResult.failed:
        Toast.error(libL10n.fail);
    }
  }

  String _bmcIntentText(PowerIntent intent) => switch (intent) {
    PowerIntent.on => l10n.bmcPowerOnAction,
    PowerIntent.gracefulShutdown => l10n.bmcShutdown,
    PowerIntent.forceOff => l10n.bmcForceOff,
    PowerIntent.restart => l10n.restart,
    PowerIntent.powerCycle => l10n.bmcPowerCycle,
  };

  String _bmcPowerText(PowerState state) => switch (state) {
    PowerState.on => l10n.bmcPowerOn,
    PowerState.off => l10n.bmcPowerOff,
    PowerState.poweringOn || PowerState.poweringOff => libL10n.loadingEllipsis,
    PowerState.paused => 'Paused',
    PowerState.unknown => libL10n.unknown,
  };

  String _bmcFailureText(RedfishFailure failure, String? detail) =>
      switch (failure) {
        RedfishFailure.certificateRejected => l10n.bmcCertRejected,
        RedfishFailure.unauthorized => l10n.bmcUnauthorized,
        RedfishFailure.noCredential => l10n.bmcAccountMissing,
        RedfishFailure.notAService => l10n.bmcNotAService,
        RedfishFailure.noSystem => l10n.bmcNoSystem,
        // Names the resource, because it is an answer about one resource
        RedfishFailure.forbidden => '${libL10n.fail}: ${detail ?? ''}',
        // Retrying after a fresh read is the fix, so it is worth saying that
        // rather than showing a generic failure — this is what a change made
        // through the BMC's own web interface in the meantime looks like.
        RedfishFailure.preconditionRequired => l10n.bmcStaleWrite,
        RedfishFailure.unreachable => detail ?? libL10n.fail,
      };

  Widget? _buildCustomCmd(ServerState si) {
    final ss = si.status;
    if (ss.customCmds.isEmpty) return null;
    return _buildReadoutCard(
      cardKey: 'custom',
      icon: MingCute.command_line,
      title: l10n.customCmd,
      rows: ss.customCmds.entries.map(_buildCustomCmdItem).toList(),
      footer: _countNote(ss.customCmds.length, l10n.unitCommands),
      initiallyExpanded: _getInitExpand(ss.customCmds.length),
    );
  }

  Widget _buildCustomCmdItem(MapEntry<String, String> cmd) {
    // A command that printed several lines has only its first on the row; the
    // rest is what tapping opens, because a row is one line by construction.
    final lines = cmd.value.split('\n');
    return _buildReadoutRow(
      k: cmd.key,
      v: lines.first,
      onTap: lines.length > 1 ? () => _onTapCustomItem(cmd) : null,
    );
  }

}

/// A value that is on screen only once someone asks for it.
///
/// A public address is not a secret — anything the server talks to already has
/// it — but it is the one line on this page that identifies the machine to
/// someone reading over a shoulder or watching a screen share, and it is on a
/// card people open for the uptime. Hidden by default costs one tap and
/// removes that.
///
/// **The row that holds this is keyed by its label**, because it is one child
/// of a list whose length is `ss.more.entries.length + 1`. Matched by index, a
/// later poll that adds a `more` entry lines it up against a different
/// subtree, the element is rebuilt from scratch, and an address the user
/// revealed hides itself again mid-session. By label rather than by value, so
/// that an address changing does not count as a different row — see
/// `_buildAboutRow`.
///
/// The placeholder has the same number of characters as the address, not the
/// same width — `•` is not the width of a digit in a proportional face, so
/// revealing does re-flow the row a little. Monospacing the placeholder alone
/// would swap that for a bullet run that does not look like the text it stands
/// for, which is worse on a card people are scanning.
class _SecretText extends StatefulWidget {
  const _SecretText(this.value);

  final String value;

  @override
  State<_SecretText> createState() => _SecretTextState();
}

class _SecretTextState extends State<_SecretText> {
  bool _shown = false;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          _shown ? widget.value : '•' * widget.value.length,
          style: UIs.text13Grey,
          overflow: TextOverflow.ellipsis,
        ),
        IconButton(
          padding: EdgeInsets.zero,
          visualDensity: VisualDensity.compact,
          constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
          iconSize: 15,
          icon: Icon(
            _shown ? Icons.visibility_off_outlined : Icons.visibility_outlined,
          ),
          tooltip: _shown ? libL10n.close : libL10n.open,
          onPressed: () => setState(() => _shown = !_shown),
        ),
      ],
    );
  }
}
