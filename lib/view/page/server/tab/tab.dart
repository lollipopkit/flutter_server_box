import 'dart:async';
import 'dart:math' as math;

import 'package:fl_lib/fl_lib.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:icons_plus/icons_plus.dart';
import 'package:material_ui/material_ui.dart';
import 'package:server_box/core/diag.dart';
import 'package:server_box/core/extension/context/locale.dart';
import 'package:server_box/core/route.dart';
import 'package:server_box/core/utils/tag_group.dart';
import 'package:server_box/data/model/app/keybinding.dart';
import 'package:server_box/data/model/app/tab.dart';
import 'package:server_box/data/model/bmc/bmc_target.dart';
import 'package:server_box/data/model/server/server.dart';
import 'package:server_box/data/model/server/server_private_info.dart';
import 'package:server_box/data/model/server/server_sort.dart';
import 'package:server_box/data/model/server/try_limiter.dart';
import 'package:server_box/data/model/status/card_item.dart';
import 'package:server_box/data/model/uptimer/uptimer.dart';
import 'package:server_box/data/provider/app/keybindings.dart';
import 'package:server_box/data/provider/app/session_requests.dart';
import 'package:server_box/data/provider/bmc/bmc.dart';
import 'package:server_box/data/provider/bmc/selection.dart';
import 'package:server_box/data/provider/bmc/summary.dart';
import 'package:server_box/data/provider/bmc/targets.dart';
import 'package:server_box/data/provider/server/all.dart';
import 'package:server_box/data/provider/server/connections.dart';
import 'package:server_box/data/provider/server/metric.dart';
import 'package:server_box/data/provider/server/reading_fmt.dart';
import 'package:server_box/data/provider/server/selection.dart';
import 'package:server_box/data/provider/server/single.dart';
import 'package:server_box/data/provider/server/sort.dart';
import 'package:server_box/data/provider/uptimer/detail.dart';
import 'package:server_box/data/provider/uptimer/selection.dart';
import 'package:server_box/data/provider/uptimer/uptimer.dart';
import 'package:server_box/data/store/stores.dart';
import 'package:server_box/src/rust/api/bmc.dart';
import 'package:server_box/view/page/bmc/card.dart';
import 'package:server_box/view/page/bmc/common.dart';
import 'package:server_box/view/page/bmc/detail.dart';
import 'package:server_box/view/page/bmc/drives.dart';
import 'package:server_box/view/page/bmc/edit.dart';
import 'package:server_box/view/page/bmc/logs.dart';
import 'package:server_box/view/page/server/add_menu.dart';
import 'package:server_box/view/page/server/card/actions.dart';
import 'package:server_box/view/page/server/card/card.dart';
import 'package:server_box/view/page/server/card/density.dart';
import 'package:server_box/view/page/server/card/notices.dart';
import 'package:server_box/view/page/server/card/sizes.dart';
import 'package:server_box/view/page/server/card/swap.dart';
import 'package:server_box/view/page/server/card/switcher.dart';
import 'package:server_box/view/page/server/detail/bar_actions.dart';
import 'package:server_box/view/page/server/detail/view.dart';
import 'package:server_box/view/page/server/edit/edit.dart';
import 'package:server_box/view/page/server/full_screen.dart';
import 'package:server_box/view/page/server/state_ui.dart';
import 'package:server_box/view/page/server/tab/element_flight.dart';
import 'package:server_box/view/page/server/tab/empty.dart';
import 'package:server_box/view/page/server/tab/func_bar.dart';
import 'package:server_box/view/page/server/tab/group_heading.dart';
import 'package:server_box/view/page/server/tab/selection_bar.dart';
import 'package:server_box/view/page/server/tab/strip.dart';
import 'package:server_box/view/page/server/text_scale.dart';
import 'package:server_box/view/page/server/widget/server_globe.dart';
import 'package:server_box/view/page/server/widget/server_side_tile.dart';
import 'package:server_box/view/page/uptimer/card.dart';
import 'package:server_box/view/page/uptimer/common.dart';
import 'package:server_box/view/page/uptimer/detail.dart';
import 'package:server_box/view/page/uptimer/edit.dart';
import 'package:server_box/view/widget/pane_settings.dart';
import 'package:server_box/view/widget/server_sort_rows.dart';
import 'package:server_box/view/widget/tag_switcher.dart';
import 'package:window_manager/window_manager.dart';

part 'bar.dart';
part 'bulk.dart';
part 'detail_host.dart';
part 'grid.dart';
part 'full_screen.dart';
part 'pane.dart';
part 'sheets.dart';
part 'utils.dart';

class ServerPage extends ConsumerStatefulWidget {
  const ServerPage({super.key});

  @override
  ConsumerState<ServerPage> createState() => _ServerPageState();
}

/// How long a card takes to grow into the page, and to shrink back.
///
/// The design's number for this movement. Long enough that a card changing
/// width reads as one thing moving rather than as the page being replaced,
/// short enough that opening a server is not something to wait for.
const _kOpenDuration = Duration(milliseconds: 350);

/// How long the detail's own chrome takes to arrive or go.
///
/// Shorter than the card's movement and out of phase with it — see
/// [_ServerPageState._detailShowing].
const _kChromeDuration = Durations.short4;

/// How quickly the cards that are not being opened get out of the way.
///
/// Over inside the movement's first third, because the page's own facts are
/// coming in over the same ground: two half-transparent layouts on top of each
/// other is a wash, and the cards are the half nobody is looking at. Their
/// slots are held for them either way — what this is is only the paint.
const _kOthersGone = Interval(0, 0.35, curve: Curves.easeOutCubic);

/// How long the list takes to become the globe, and back.
///
/// Longer than the plain cross-fade this replaced (`medium1`): a scale needs
/// room to read as a movement, and at 150 ms it has arrived before the eye has
/// decided anything moved.
const _kViewSwapDuration = Durations.medium2;

/// The grid contracting toward the sphere, and the sphere opening out of it.
///
/// One builder for both children and both directions, because
/// `AnimatedSwitcher` runs the outgoing child's animation in reverse — so a
/// single 0.9 → 1 tween shrinks what is leaving and grows what is arriving,
/// about the same point.
///
/// **That point is the globe's centre, and it is knowable here.** `GlobeView`
/// puts the sphere at the middle of whatever box it is given — `center` is
/// `(size.width / 2, size.height / 2)` — and the `layoutBuilder` below hands
/// both children that same box. So `Alignment.center`, the default, is not a
/// guess at a reasonable anchor; it is where the globe is about to be.
///
/// A morph, with each card flying to its own dot, would need where those dots
/// land — which is not knowable when the transition has to start, because
/// nothing is placed until the lookups come back. Converging on the sphere
/// needs none of that. See TODOS for the full argument.
Widget _viewSwapTransition(Widget child, Animation<double> animation) =>
    FadeTransition(
      opacity: animation,
      // `drive` rather than a `CurvedAnimation`, which owns resources and would
      // be built and dropped on every frame of the transition.
      child: ScaleTransition(
        scale: animation.drive(
          Tween(
            begin: 0.9,
            end: 1.0,
          ).chain(CurveTween(curve: Curves.easeOutCubic)),
        ),
        child: child,
      ),
    );

/// Both children in the same box, which is what makes the anchor above right.
///
/// Also what keeps a scrolling child full height: the default `Stack` sizes to
/// its child and hands it loose constraints, under which a
/// `SingleChildScrollView` takes the height of its contents.
///
/// Exiting children (`previous`) have pointer hits and [HeroMode] disabled on
/// the exact frame they start leaving (preserving each entry's [KeyedSubtree]
/// key so state is never remounted), preventing duplicate [SharedElementHero]
/// tags if a route push begins mid-transition.
Widget _viewSwapLayout(Widget? current, List<Widget> previous) => Stack(
  fit: StackFit.expand,
  children: [
    for (final p in previous)
      IgnorePointer(
        key: p.key,
        ignoring: true,
        child: HeroMode(enabled: false, child: p),
      ),
    if (current != null)
      IgnorePointer(
        key: current.key,
        ignoring: false,
        child: HeroMode(enabled: true, child: current),
      ),
  ],
);

/// How far burn-in protection moves full screen's content, each way.
const _kBurnInShift = 7.0;

class _ServerPageState extends ConsumerState<ServerPage>
    with
        AutomaticKeepAliveClientMixin,
        TickerProviderStateMixin,
        WindowListener {
  final _offsetNotifier = ValueNotifier(Offset.zero);
  PageController? _landscapeController;
  String? _landscapeSeenId;

  /// Full screen asked for by the bar's button rather than by turning the
  /// device.
  final _fsManual = ValueNotifier(false);

  /// Whether full screen shows every server, or null for what the window
  /// suits — see [_FullScreen._fsShowsAll].
  bool? _fsAll;

  /// Whether full screen's controls are showing.
  final _fsBar = ValueNotifier(false);

  /// Full screen's key bindings, focused on entering it.
  final _fsKeys = FocusNode(debugLabel: 'server full screen');

  /// Whether the window was full screen before the button made it so, and so
  /// stays that way after.
  bool _fsWindowWasFull = false;

  /// What [ServerFullScreen] has last been told.
  bool _fsPublished = false;

  /// Between [deactivate] and [activate]: no timer is started.
  bool _inactive = false;

  late final ValueNotifier<Set<String>> _tags;

  Timer? _timer;

  final _tag = ''.vn;

  final _scrollController = ScrollController();

  /// What [ServerListDensity.auto] last came to in the grid, for the bar over
  /// it to say.
  ///
  /// Null until a grid has been laid out, or while empty/globe. See [_publishAuto].
  final _autoDensity = ValueNotifier<ServerListDensity?>(null);
  ServerListDensity? _pendingAuto;
  bool _autoPublishScheduled = false;

  /// Actual laid-out `cards`-density height per `StatusCardItem.cardKey`,
  /// paired with a signature of the card's height-affecting state so cached
  /// measurements are reused only while that state is unchanged.
  final _cardHeights = <String, ({Object state, double height})>{};
  final _pendingCardHeights = <String, ({Object state, double height})>{};
  int _cardHeightsEpoch = 0;
  double? _cardHeightsTextScale;
  double? _cardHeightsColWidth;
  Size? _lastGridViewport;
  Timer? _cardHeightCommitTimer;

  /// Bumped when the sort or the density changes, which are views over the
  /// list rather than anything the providers hold — so nothing else would
  /// rebuild it.
  final _sortVersion = RNode();

  /// The bar's search: what is typed, and whether the bar is a field at all.
  ///
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
  final _search = InlineSearchController();

  /// Whether the list is a globe.
  ///
  /// A fourth way of viewing the same servers, beside the tag, the search and
  /// the sort — and stored like the sort is, because reopening the app on the
  /// grid after having chosen the globe reads as the choice not having taken.
  ///
  /// Only ever true when `globeEnabled` is on. The setting is what removes the
  /// feature; this is what the button toggles.
  late final _globe = ValueNotifier(
    Stores.setting.globeEnabled.fetch() &&
        Stores.setting.serverPageGlobe.fetch(),
  );

  /// Turns the globe off when the feature is.
  ///
  /// Read once at construction and never again, the two could disagree: switch
  /// `globeEnabled` off in settings while the globe is showing and the button
  /// that turns it off disappears — because `_listActions` checks the setting
  /// — while the globe stays. That leaves a sphere with every server in the
  /// "unplaced" strip, since `IpGeo` now answers null for all of them, and no
  /// control anywhere to get back to the list.
  void _globeEnabledListener() {
    if (!Stores.setting.globeEnabled.fetch()) _globe.value = false;
    // Unconditionally, and not left to `_globe` to cause: `_listActions` reads
    // the setting directly to decide whether the button exists at all, and
    // `_globe` only notifies when its own value changes. Switching the feature
    // off while the list was showing left the button there — `_globe` was
    // already false — and switching it back on never brought it back.
    _sortVersion.notify();
  }

  /// Builds the grid again when "UI Fold" is switched.
  ///
  /// What a card nobody has touched rests at is that setting's answer — see
  /// [ServerCardExpanded] — and this tab is kept alive behind the settings
  /// page, so nothing else would tell it: the cards stayed as they were until
  /// something unrelated happened to build the grid.
  void _uiFoldListener() {
    _invalidateCardHeights();
    _sortVersion.notify();
  }

  /// Burn-in protection, switched: the shift starts or stops, and full screen
  /// changes colour.
  void _burnInListener() {
    _timer?.cancel();
    _timer = null;
    if (!mounted) return;
    if (Stores.setting.fullScreenJitter.fetch()) {
      _updateOffset();
      if (!_inactive) _startAvoidJitterTimer();
    } else {
      _offsetNotifier.value = Offset.zero;
    }
    setState(() {});
  }

  /// The window left full screen some other way: the page follows it.
  @override
  void onWindowLeaveFullScreen() =>
      unawaited(_exitFullScreen(window: false));

  /// What the globe guide points at: the globe button in the tag bar's
  /// [_Bar._listActions]. Null context when that button is not built — the
  /// bar is gone in full screen landscape.
  final _globeBtnKey = GlobalKey();

  /// Waits out the launch notices before the globe guide is considered.
  ///
  /// Held rather than awaited so [dispose] can cancel it: a bare
  /// `Future.delayed` outlives the page, which in a widget test is a pending
  /// timer after the tree is gone and in the app is work done for a page that
  /// is no longer there.
  Timer? _globeGuideTimer;

  /// What [ImmersiveTab] has last been told, so an unchanged answer is not
  /// repeated.
  bool _immersive = false;

  /// How far the open card has grown into the page: 0 is the grid, 1 the
  /// detail.
  ///
  /// One controller rather than one per card, because only one card is ever
  /// open — which card that is, is [serverSelectionProvider]'s answer.
  late final _openCtrl = AnimationController(
    vsync: this,
    duration: _kOpenDuration,
  );

  /// The design's curve for this movement, at both ends of it: slow to leave
  /// the grid and slow to come to rest in it, which pairs with [ShapeCross]
  /// (`_kShapeCross`) and keeps a resize reading as one continuous movement.
  late final _open = CurvedAnimation(
    parent: _openCtrl,
    curve: Curves.easeInOutCubic,
    reverseCurve: Curves.easeInOutCubic,
  );

  /// How visible a card that is not the one being opened is.
  ///
  /// Derived once rather than read per frame, so the cards it applies to are
  /// the same widgets on every frame of the movement and are not rebuilt.
  late final Animation<double> _othersOpacity = _open.drive(
    Tween(begin: 1.0, end: 0.0).chain(CurveTween(curve: _kOthersGone)),
  );

  /// Crossfade curves for non-morphing resource cards (BMC, Uptimer), derived
  /// once so [FadeTransition] composites on the GPU with zero widget rebuilds.
  late final Animation<double> _cardsFadeOut = _open.drive(
    Tween(begin: 1.0, end: 0.0).chain(
      CurveTween(curve: const Interval(0.0, 0.45, curve: Curves.easeOut)),
    ),
  );
  late final Animation<double> _detailFadeIn = _open.drive(
    Tween(begin: 0.0, end: 1.0).chain(
      CurveTween(curve: const Interval(0.15, 1.0, curve: Curves.easeOutCubic)),
    ),
  );

  /// Which way through the list the last change of machine went: +1 for the
  /// next one along, -1 for the one before.
  ///
  /// What the detail's own switch is drawn with — see [DirectionalSwap]. A
  /// pick from the sheet, where there is no "next", counts as forwards.
  int _swapDirection = 1;

  /// The card that is grown into the page, or is on its way back out of it.
  ///
  /// Not the selection: that is cleared the moment the way back is taken, and
  /// the card still has a movement to make after it — a card whose expansion
  /// hung off the selection snapped back to its column instead of shrinking.
  /// Cleared when the movement has finished, which is what [_openCtrl] says.
  String? _heroId;

  /// How tall each card was in the grid, for the grid that is mounted again on
  /// the way back.
  ///
  /// The grid is dropped while the page has the readings and mounted again
  /// with the open card already at full size, so what it would measure for
  /// that card's slot is the page. In a list of lines that put every line
  /// under it a page-height too low until the card had landed, and then they
  /// travelled up — a second movement after the first. See [MasonryMemory].
  final _gridMemory = MasonryMemory();

  /// What the list is drawn as while a card is out of it — see
  /// [_Grid._buildGrid], which holds it.
  ServerListDensity? _heroDensity;

  /// Whether the detail's own chrome is up: the facts beside the readings and
  /// the row of things to do under them.
  ///
  /// Not simply "is a server open". It arrives once the card has stopped
  /// growing and leaves before it starts shrinking, so that what moves is the
  /// card and nothing else — a bar rising through a card that is still
  /// resizing reads as two things happening rather than one.
  bool _detailShowing = false;

  /// Holds the gap between the chrome going and the card starting back.
  Timer? _closeTimer;

  /// Invalidates pending close callbacks if another item is opened first.
  int _closeSeq = 0;

  /// ID of the server whose context menu is open.
  ///
  String? _menuId;

  /// Whether the function row floating over the open machine is wanted.
  ///
  /// Here rather than inside the page because the row is: it outlives the
  /// page under it, which is replaced at every step through the list.
  final _funcBarVisible = ValueNotifier(true);

  /// Where the page's own key bindings live.
  ///
  /// Focused deliberately — when a machine is opened or a set is started —
  /// rather than on arrival: this tab is kept alive behind the others, and a
  /// node that grabs focus when it is built would take it from whatever tab
  /// the user is actually looking at.
  final _keys = FocusNode(debugLabel: 'server list', skipTraversal: true);

  /// The list as it was last drawn, for the bindings that step through it.
  ///
  /// A key is pressed between builds, so what "the next item" is has to be
  /// something the last build left behind.
  List<StatusCardItem> _lastFiltered = const [];

  /// Card keys (`StatusCardItem.cardKey`) being acted on together.
  final _selected = <String>{};

  late final _elementFlight = StatusElementFlight(
    progress: _open,
    onChanged: () {
      if (mounted) setState(() {});
    },
  );

  int? _startItemFlight(StatusCardItem item, {required bool opening}) {
    final density =
        _heroDensity ??
        _resolvedDensity(ServerDensityPref.of(_tag.value), _lastFiltered);
    return switch (item) {
      ServerCardItem() => null,
      UptimerCardItem(:final monitor) when monitor.heartbeats.isNotEmpty => () {
        final spec = UptimerCard.stripSpecFor(density);
        return _elementFlight.start(
          context: context,
          cardKey: item.cardKey,
          opening: opening,
          departing: UptimerHeartbeatStrip(
            heartbeats: monitor.heartbeats,
            count: spec.count,
            height: spec.height,
            gap: spec.gap,
            radius: spec.radius,
          ),
          arriving: UptimerHeartbeatStrip(
            heartbeats: monitor.heartbeats,
            count: 45,
            height: 22,
            gap: 2,
            radius: 2.5,
          ),
          arrivingSize: const Size(530, 22),
          fit: BoxFit.fill,
        );
      }(),
      UptimerCardItem() => null,
      BmcCardItem(:final target) => () {
        final summary = ref.read(bmcSummaryProvider(target.id));
        final live = ref.read(bmcProvider(target.id));
        final useLive = !opening || live.hasData || live.failure != null;
        final dotColor = useLive
            ? BmcCard.statusDotColorFromBmc(live)
            : BmcCard.statusDotColor(summary);
        final arrivingOrb = useLive
            ? BmcDetailPage.buildStatusOrb(
                context,
                failure: live.failure,
                hasData: live.hasData,
                isBusy: live.isBusy,
                powerState: live.powerState,
              )
            : BmcDetailPage.buildStatusOrb(
                context,
                failure: summary.failure,
                hasData: summary.hasData,
                isBusy: summary.isBusy,
                powerState: summary.powerState,
              );
        return _elementFlight.start(
          context: context,
          cardKey: item.cardKey,
          opening: opening,
          departing: BmcCard.buildMarkBadge(context, dotColor: dotColor),
          arriving: arrivingOrb,
          departingSize: const Size.square(kSideMarkSize),
          arrivingSize: const Size.square(38),
          fit: BoxFit.contain,
        );
      }(),
    };
  }

  bool get _selecting => _selected.isNotEmpty;

  String? _currentOpenKey() {
    final serverId = ref.read(serverSelectionProvider);
    if (serverId != null) return ServerCardItem.keyOf(serverId);
    final bmcId = ref.read(bmcSelectionProvider);
    if (bmcId != null) return BmcCardItem.keyOf(bmcId);
    final uptimerId = ref.read(uptimerSelectionProvider);
    if (uptimerId != null) return UptimerCardItem.keyOf(uptimerId);
    return null;
  }

  /// Opens [item] in place: the card grows to the width of the page and the
  /// rest of the grid makes way.
  void _openDetail(StatusCardItem item) {
    _keys.requestFocus();
    final wasKey = _currentOpenKey();
    final from = wasKey == null
        ? -1
        : _lastFiltered.indexWhere((i) => i.cardKey == wasKey);
    final to = _lastFiltered.indexWhere((i) => i.cardKey == item.cardKey);
    if (from >= 0 && to >= 0 && to != from) {
      _swapDirection = to > from ? 1 : -1;
    }
    _openCtrl.duration = context.motion(_kOpenDuration);
    _funcBarVisible.value = true;
    _heroId = item.cardKey;
    StatusSelection.selectItem(ref, item);
    _closeSeq++;
    _closeTimer?.cancel();
    if (_openCtrl.isCompleted && !_detailShowing) {
      setState(() => _detailShowing = true);
    }
    _elementFlight.end();
    if (wasKey != null) {
      return;
    }
    final flightGen = _startItemFlight(item, opening: true);
    final future = _openCtrl.forward();
    if (flightGen != null) {
      future.whenCompleteOrCancel(() => _elementFlight.end(flightGen));
    }
    if (item is ServerCardItem &&
        _scrollController.hasClients &&
        _scrollController.offset > 0) {
      _scrollController.animateTo(
        0,
        duration: _openCtrl.duration ?? _kOpenDuration,
        curve: Curves.easeInOutCubic,
      );
    }
  }

  /// Puts the page back to the grid, chrome first for Server cards and
  /// immediately for non-morphing cards or interrupted opens.
  void _closeDetail() {
    if (_currentOpenKey() == null && _openCtrl.isDismissed) {
      return;
    }
    final closingKey = _currentOpenKey();
    final closingItem = closingKey == null
        ? null
        : _lastFiltered.firstWhereOrNull((i) => i.cardKey == closingKey);
    final wasDetailShowing = _detailShowing;
    final wasWaitingChrome = _closeTimer?.isActive ?? false;
    // If a Server detail is already waiting out its chrome-exit timer, let the
    // scheduled reverse finish on time instead of resetting or bypassing it.
    if (closingItem is ServerCardItem && wasWaitingChrome) {
      return;
    }
    if (_detailShowing) setState(() => _detailShowing = false);
    _openCtrl.duration = context.motion(_kOpenDuration);
    _closeTimer?.cancel();
    final seq = ++_closeSeq;

    void reverseNow() {
      if (!mounted || seq != _closeSeq) return;
      final latestItem = closingKey == null
          ? null
          : _lastFiltered.firstWhereOrNull((i) => i.cardKey == closingKey) ??
                closingItem;
      final flightGen = latestItem != null
          ? _startItemFlight(latestItem, opening: false)
          : null;
      StatusSelection.selectItem(ref, null);
      final future = _openCtrl.reverse();
      if (flightGen != null) {
        future.whenCompleteOrCancel(() => _elementFlight.end(flightGen));
      }
    }

    // Server detail waits for its chrome to leave before shrinking back.
    if (closingItem is ServerCardItem && wasDetailShowing) {
      _closeTimer = Timer(context.motion(_kChromeDuration), reverseNow);
      return;
    }

    // For BMC/Uptimer, wait one frame only if the grid was unmounted while
    // `_detailShowing` was true so the card's [FlightAnchor] mounts first;
    // when interrupting an in-flight open, reverse immediately.
    if (wasDetailShowing) {
      WidgetsBinding.instance.addPostFrameCallback((_) => reverseNow());
    } else {
      reverseNow();
    }
  }

  /// Drops stale in-place detail state when the open item disappears from the
  /// visible list (e.g. a standalone BMC deleted or linked to a server).
  void _resetMissingHero() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || _heroId == null) return;
      if (_lastFiltered.any((i) => i.cardKey == _heroId)) return;
      _closeSeq++;
      _closeTimer?.cancel();
      _elementFlight.end();
      _openCtrl.value = 0;
      setState(() {
        _heroId = null;
        _detailShowing = false;
      });
      StatusSelection.selectItem(ref, null);
    });
  }

  @override
  void dispose() {
    _elementFlight.dispose();
    _closeTimer?.cancel();
    _cardHeightCommitTimer?.cancel();
    _funcBarVisible.dispose();
    _keys.dispose();
    _open.dispose();
    _openCtrl.dispose();
    _timer?.cancel();
    _globeGuideTimer?.cancel();
    _scrollController.dispose();
    _sortVersion.dispose();
    _autoDensity.dispose();
    _search.dispose();
    Stores.setting.globeEnabled.listenable().removeListener(
      _globeEnabledListener,
    );
    Stores.setting.collapseUIDefault.listenable().removeListener(
      _uiFoldListener,
    );
    _globe.dispose();
    _tag.dispose();
    _tags.dispose();
    Stores.setting.fullScreenJitter.listenable().removeListener(
      _burnInListener,
    );
    if (isDesktop) windowManager.removeListener(this);
    if (_fsManual.value && isDesktop && !_fsWindowWasFull) {
      unawaited(windowManager.setFullScreen(false));
    }
    _fsKeys.dispose();
    _fsManual.dispose();
    _fsBar.dispose();
    _offsetNotifier.dispose();
    _landscapeController?.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    _tags = ValueNotifier({
      ...ref.read(serversProvider).tags,
      ...ref.read(bmcTargetsProvider).tags,
      ...ref.read(uptimerProvider).tags,
    });
    // The chrome follows the card rather than being timed against it: what
    // says the growth has finished is the growth finishing.
    _openCtrl.addStatusListener((status) {
      if (status == AnimationStatus.completed ||
          status == AnimationStatus.dismissed) {
        _elementFlight.end();
      }
      // The card is back in its column, so it is a card again.
      if (status == AnimationStatus.dismissed && _heroId != null) {
        setState(() => _heroId = null);
      }
      final showing = status == AnimationStatus.completed;
      if (showing == _detailShowing) return;
      setState(() => _detailShowing = showing);
    });
    Stores.setting.globeEnabled.listenable().addListener(_globeEnabledListener);
    Stores.setting.collapseUIDefault.listenable().addListener(_uiFoldListener);
    Stores.setting.fullScreenJitter.listenable().addListener(_burnInListener);
    if (isDesktop) windowManager.addListener(this);
    _startAvoidJitterTimer();
    _scheduleGlobeGuide();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _updateOffset();
  }

  @override
  void deactivate() {
    _inactive = true;
    _timer?.cancel();
    _timer = null;
    _elementFlight.end(null, false);
    super.deactivate();
  }

  @override
  void activate() {
    super.activate();
    _inactive = false;
    _startAvoidJitterTimer();
  }

  void _syncTags() {
    final next = {
      ...ref.read(serversProvider).tags,
      ...ref.read(bmcTargetsProvider).tags,
      ...ref.read(uptimerProvider).tags,
    };
    if (_tags.value.length == next.length && _tags.value.containsAll(next)) {
      return;
    }
    _tags.value = next;
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    ref.listen(serversProvider, (_, _) => _syncTags());
    ref.listen(bmcTargetsProvider, (_, _) => _syncTags());
    ref.listen(uptimerProvider, (_, _) => _syncTags());
    return OrientationBuilder(
      builder: (_, orientation) => ValueListenableBuilder(
        valueListenable: _fsManual,
        builder: (_, manual, _) {
          // A phone turned to landscape, with the setting on.
          final turned =
              isMobile &&
              orientation == Orientation.landscape &&
              Stores.setting.fullScreen.fetch();
          _publishFullScreen(manual || turned);
          if (manual || turned) return _buildFullScreen(manual: manual);
          return _buildPortrait();
        },
      ),
    );
  }

  /// The page around the list, or around the globe.
  ///
  /// [bare] is the globe having the window: no bar over it, and — through
  /// [ImmersiveTab] — no navigation under it either. See [_publishImmersive].
  Widget _buildScaffold(
    Widget child, {
    bool bare = false,
    StatusCardItem? openItem,
    List<StatusCardItem> filtered = const [],
  }) {
    return Scaffold(
      appBar: bare ? null : _buildTagBar(openItem, filtered),
      body: ServerTextScale(
        child: SafeArea(top: false, bottom: false, child: child),
      ),
    );
  }

  Widget _buildPortrait() {
    final serverOrder = ref.watch(serversProvider.select((s) => s.serverOrder));
    final servers = ref.watch(serversProvider.select((s) => s.servers));
    final bmcState = ref.watch(bmcTargetsProvider);
    final uptimerState = ref.watch(uptimerProvider);
    final openKey = StatusSelection.watchCardKey(ref);

    final standaloneBmcs = bmcState.standalone(servers.keys.toSet());
    final rawItems = <StatusCardItem>[
      for (final id in serverOrder)
        if (servers[id] case final spi?) ServerCardItem(spi),
      for (final target in standaloneBmcs) BmcCardItem(target),
      for (final monitor in uptimerState.monitorList) UptimerCardItem(monitor),
    ];

    return _ServerOpenRequest(
      split: _opensInPlace(context),
      onOpen: _openRequestedServer,
      child: ListenableBuilder(
        listenable: Listenable.merge([_tag, _sortVersion]),
        builder: (_, _) => Consumer(
          builder: (_, ref, _) {
            final sortOrder = ServerSortOrder.of(_tag.value);
            final needsState = sortOrder.field.readsStatus;
            final serverStates = !needsState
                ? const <String, ServerState>{}
                : {
                    for (final id in serverOrder) id: ref.watch(serverProvider(id)),
                  };
            final bmcStates = !needsState
                ? const <String, BmcSummaryState>{}
                : {
                    for (final target in standaloneBmcs)
                      target.id: ref.watch(bmcSummaryProvider(target.id)),
                  };

            return ListenableBuilder(
              listenable: Listenable.merge([_search, _globe]),
              builder: (_, _) {
                final ordered = sortOrder.applyItems(
                  rawItems,
                  serverStateOf: (id) =>
                      serverStates[id] ?? ref.read(serverProvider(id)),
                  bmcStateOf: (target) =>
                      bmcStates[target.id] ??
                      ref.read(bmcSummaryProvider(target.id)),
                  uptimerHasAlertOf: (m) => uptimerState.hasAlert(m.id),
                );
                final filtered = _filterItems(ordered);
                _lastFiltered = filtered;
                if (_heroId != null &&
                    !filtered.any((i) => i.cardKey == _heroId)) {
                  _resetMissingHero();
                }
                final openItem = openKey == null
                    ? null
                    : filtered.firstWhereOrNull((i) => i.cardKey == openKey);
                final hasServers = filtered.any((i) => i is ServerCardItem);
                final globe = _globe.value && hasServers && openItem == null;
                _publishImmersive(globe);
                return _bound(
                  _buildScaffold(
                    _buildBodySmall(
                      filtered: filtered,
                      globe: globe,
                      openItem: openItem,
                    ),
                    bare: globe,
                    openItem: openItem,
                    filtered: filtered,
                  ),
                );
              },
            );
          },
        ),
      ),
    );
  }

  /// The keys this page answers to.
  ///
  /// Only the ones that act on the page as a whole. What can be done to *one*
  /// machine is on the menu a long press or a right-click opens, and reaching
  /// those from the keyboard needs a card to be focusable first — which is a
  /// separate thing and not this.
  Widget _bound(Widget child) {
    // As set on the shortcuts page: by default the platform's own modifier,
    // since a Mac holds command where everything else holds control.
    final kb = ref.watch(keybindingsProvider);
    void bind(
      Map<ShortcutActivator, VoidCallback> into,
      KbCommand command,
      VoidCallback run,
    ) {
      final a = kb.activatorOf(command);
      if (a != null) into[a] = run;
    }

    final bindings = <ShortcutActivator, VoidCallback>{};
    // What the top-left arrow does, and what a set being built up is
    // abandoned with.
    //
    // Handle the innermost route first. The context menu is a separate
    // route and receives key events before this page.
    bind(bindings, KbCommand.serverClose, () {
      if (_selecting) {
        _endSelecting();
      } else {
        _closeDetail();
      }
    });
    bind(bindings, KbCommand.serverPrev, () => _stepServer(-1));
    bind(bindings, KbCommand.serverNext, () => _stepServer(1));
    // The list, from inside one of its machines. Nothing when the list is
    // already the page — the bar's own search is what that wants.
    bind(bindings, KbCommand.serverList, () {
      final key = _currentOpenKey();
      final item = key == null
          ? null
          : _lastFiltered.firstWhereOrNull((i) => i.cardKey == key);
      if (item != null) _showItemSheet(_lastFiltered, item);
    });

    return CallbackShortcuts(
      bindings: bindings,
      child: Focus(focusNode: _keys, child: child),
    );
  }

  /// The item before or after the open one, wrapping at the ends.
  void _stepServer(int delta) {
    final key = _currentOpenKey();
    if (key == null || _lastFiltered.length < 2) return;
    final at = _lastFiltered.indexWhere((i) => i.cardKey == key);
    if (at < 0) return;
    final next = (at + delta) % _lastFiltered.length;
    _openDetail(_lastFiltered[next]);
  }

  bool _opensInPlace(BuildContext context) =>
      MediaQuery.sizeOf(context).width >= AdaptivePanes.kSplitWidth;

  Widget _buildBodySmall({
    required List<StatusCardItem> filtered,
    required bool globe,
    required StatusCardItem? openItem,
  }) {
    if (globe || filtered.isEmpty) {
      _lastGridViewport = null;
      _publishAuto(null);
    }
    return AnimatedSwitcher(
      duration: context.motion(_kViewSwapDuration),
      reverseDuration: context.motion(_kViewSwapDuration),
      switchInCurve: Curves.easeOutCubic,
      switchOutCurve: Curves.easeInCubic,
      transitionBuilder: _viewSwapTransition,
      layoutBuilder: _viewSwapLayout,
      child: switch (true) {
        _ when globe => _buildGlobe(filtered, immersive: true),
        _ when filtered.isEmpty => _buildEmptyWithNotice(),
        _ => KeyedSubtree(
          key: const ValueKey('grid'),
          child: _buildGrid(filtered, openItem),
        ),
      },
    );
  }

  Widget _buildEmptyWithNotice() {
    final uptimer = ref.watch(uptimerProvider);
    final empty = ServerListEmpty(
      query: _search.needle,
      tag: _tag.value,
      onClearSearch: _search.end,
      onClearTag: () => _tag.value = TagSwitcher.kDefaultTag,
      onAdd: _onTapAddServer,
    );
    if (!uptimer.signedIn || uptimer.error == null) {
      return empty;
    }
    return KeyedSubtree(
      key: const ValueKey('empty-uptimer-err'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          UptimerSyncErrorBanner(
            error: uptimer.error!,
            loading: uptimer.isLoading,
            onRetry: () => unawaited(
              ref.read(uptimerProvider.notifier).refresh(force: true),
            ),
          ),
          Expanded(child: empty),
        ],
      ),
    );
  }

  @override
  bool get wantKeepAlive => true;
}
