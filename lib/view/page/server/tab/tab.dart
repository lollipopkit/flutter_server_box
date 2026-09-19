// ignore_for_file: invalid_use_of_protected_member

import 'dart:async';
import 'dart:math' as math;

import 'package:fl_lib/fl_lib.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:icons_plus/icons_plus.dart';
import 'package:server_box/core/diag.dart';
import 'package:server_box/core/extension/context/locale.dart';
import 'package:server_box/core/extension/context/motion.dart';
import 'package:server_box/core/extension/server.dart';
import 'package:server_box/core/route.dart';
import 'package:server_box/core/utils/tag_group.dart';
import 'package:server_box/data/model/app/server_sort.dart';
import 'package:server_box/data/model/app/tab.dart';
import 'package:server_box/data/model/server/server.dart';
import 'package:server_box/data/model/server/server_private_info.dart';
import 'package:server_box/data/model/server/try_limiter.dart';
import 'package:server_box/data/provider/app/session_requests.dart';
import 'package:server_box/data/provider/server/all.dart';
import 'package:server_box/data/provider/server/selection.dart';
import 'package:server_box/data/provider/server/single.dart';
import 'package:server_box/data/res/chart_palette.dart';
import 'package:server_box/data/res/store.dart';
import 'package:server_box/view/page/server/card/actions.dart';
import 'package:server_box/view/page/server/card/card.dart';
import 'package:server_box/view/page/server/card/density.dart';
import 'package:server_box/view/page/server/card/metric.dart';
import 'package:server_box/view/page/server/card/overview.dart';
import 'package:server_box/view/page/server/card/swap.dart';
import 'package:server_box/view/page/server/card/switcher.dart';
import 'package:server_box/view/page/server/detail/view.dart';
import 'package:server_box/view/page/server/edit/edit.dart';
import 'package:server_box/view/page/setting/entry.dart';
import 'package:server_box/view/widget/edge_fade_scroll.dart';
import 'package:server_box/view/widget/server_func_btns.dart';
import 'package:server_box/view/widget/server_globe.dart';
import 'package:server_box/view/widget/server_share.dart';

part 'landscape.dart';
part 'utils.dart';

class ServerPage extends ConsumerStatefulWidget {
  const ServerPage({super.key});

  @override
  ConsumerState<ServerPage> createState() => _ServerPageState();

  static const route = AppRouteNoArg(page: ServerPage.new, path: '/servers');
}

/// How long a card takes to grow into the page, and to shrink back.
///
/// The design's number for this movement. Long enough that a card changing
/// width reads as one thing moving rather than as the page being replaced,
/// short enough that opening a server is not something to wait for.
const _kOpenDuration = Duration(milliseconds: 350);

/// The strip between the bar and what is under it.
///
/// One height for both of the things that go in it — see [_ServerPageState
/// ._buildStrip] — and the design's for the one that needs the room.
const _kStripHeight = 46.0;

/// The room that strip keeps above and below itself, for both of its faces.
///
/// 12 of visible gap on each side. Above, the bar is 40 tall and its tallest
/// control, the density tabs, is about 32 centred in it: 4 of the bar's own,
/// and this adds 8. Below, the grid's 4 and a card's margin of 4 follow this
/// 4, which is also what is between two cards. It was 0 above and 9 below,
/// which drew as 4 and 17: the summary read as part of the bar, and the cards
/// as a separate block under it.
const _kStripInset = EdgeInsets.only(top: 8, bottom: 4);

/// One machine's pill in that strip, which is the design's height for it and
/// not the strip's.
const _kPillHeight = 28.0;

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
Widget _viewSwapTransition(Widget child, Animation<double> animation) {
  return FadeTransition(
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
}

/// Both children in the same box, which is what makes the anchor above right.
///
/// Also what keeps a scrolling child full height: the default `Stack` sizes to
/// its child and hands it loose constraints, under which a
/// `SingleChildScrollView` takes the height of its contents.
Widget _viewSwapLayout(Widget? current, List<Widget> previous) =>
    Stack(fit: StackFit.expand, children: [...previous, ?current]);

class _ServerPageState extends ConsumerState<ServerPage>
    with AutomaticKeepAliveClientMixin, TickerProviderStateMixin {
  final ValueNotifier<double> _offsetNotifier = ValueNotifier(1);
  PageController? _landscapeController;
  String? _landscapeSeenId;

  late final ValueNotifier<Set<String>> _tags;

  Timer? _timer;

  final _tag = ''.vn;

  final _scrollController = ScrollController();

  /// Bumped when the sort or the density changes, which are views over the
  /// list rather than anything the providers hold — so nothing else would
  /// rebuild it.
  final _sortVersion = RNode();

  /// The bar's search: what is typed, and whether the bar is a field at all.
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

  /// What the globe guide points at.
  ///
  /// [_listActions] is built from three places — the bar over a single column,
  /// the rail beside a pane, and the row over the globe pane — and the first
  /// two never coexist, being the narrow and wide layouts. The third does
  /// coexist with the second for the length of the pane cross-fade, which is
  /// why it is not given this key. See [_listActions].
  final _globeBtnKey = GlobalKey();

  /// Waits out the launch notices before the globe guide is considered.
  ///
  /// Held rather than awaited so [dispose] can cancel it: a bare
  /// `Future.delayed` outlives the page, which in a widget test is a pending
  /// timer after the tree is gone and in the app is work done for a page that
  /// is no longer there.
  Timer? _globeGuideTimer;

  /// How far the open card has grown into the page: 0 is the grid, 1 the
  /// detail.
  ///
  /// One controller rather than one per card, because only one card is ever
  /// open — which card that is, is [serverSelectionProvider]'s answer.
  late final _openCtrl = AnimationController(
    vsync: this,
    duration: _kOpenDuration,
  );

  /// The design's curve for this movement, at both ends of it: the card leaves
  /// fast and arrives slowly, which is what makes a resize read as one
  /// movement rather than as a jump followed by a settle.
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
  /// A key is pressed between builds, so what "the next machine" is has to be
  /// something the last build left behind.
  List<String> _lastFiltered = const [];

  /// The machines being acted on together, or empty when none are.
  ///
  /// Empty is the ordinary list — no boxes beside the names, taps open — and
  /// anything else turns the bar into what is being done to them. Kept here
  /// rather than in a provider because it is a state of *this page*: leaving
  /// it and coming back is finishing, not resuming.
  final _selected = <String>{};

  bool get _selecting => _selected.isNotEmpty;

  /// Puts [id] in or out of the set, and ends selecting when it empties.
  void _toggleSelected(String id) {
    _keys.requestFocus();
    setState(() {
      if (!_selected.remove(id)) _selected.add(id);
    });
  }

  void _endSelecting() {
    if (_selected.isEmpty) return;
    setState(_selected.clear);
  }

  /// Opens [id] in place: the card grows to the width of the page and the rest
  /// of the grid makes way.
  ///
  /// The selection is the app's, not this page's — the tray opens a server,
  /// and deleting one clears it — so this is the one thing that changes. What
  /// the card looks like at each point between is the card's own business.
  void _openDetail(String id) {
    _keys.requestFocus();
    // Which way through the list this is, so the page it becomes knows which
    // side to come in from.
    final from = _lastFiltered.indexOf(ref.read(serverSelectionProvider) ?? '');
    final to = _lastFiltered.indexOf(id);
    if (from >= 0 && to >= 0 && to != from) {
      _swapDirection = to > from ? 1 : -1;
    }
    // Asked each time rather than once: the switch can be turned on while the
    // app is open, and what it asks for is that this movement stop being one.
    _openCtrl.duration = context.motion(_kOpenDuration);
    final was = ref.read(serverSelectionProvider);
    // Whatever the last machine's page was scrolled to, this one opens at its
    // top — so the row that floats over it is there to be used.
    _funcBarVisible.value = true;
    _heroId = id;
    ref.read(serverSelectionProvider.notifier).select(id);
    _closeTimer?.cancel();
    // Switching from one open server to another is not a second opening: the
    // page is already the detail, and only which card is in it changes.
    if (was != null) return;
    _openCtrl.forward();
    // The card is on its way to the top of the grid, and a viewport scrolled
    // past it would have it grow off screen — so the two travel together.
    if (_scrollController.hasClients && _scrollController.offset > 0) {
      _scrollController.animateTo(
        0,
        duration: _openCtrl.duration ?? _kOpenDuration,
        curve: Curves.fastEaseInToSlowEaseOut,
      );
    }
  }

  /// Puts the page back to the grid, chrome first.
  ///
  /// The reverse of opening in order as well as in direction: what came last
  /// goes first, so the card is the only thing moving while it shrinks.
  void _closeDetail() {
    if (ref.read(serverSelectionProvider) == null) return;
    if (_detailShowing) setState(() => _detailShowing = false);
    _openCtrl.duration = context.motion(_kOpenDuration);
    _closeTimer?.cancel();
    _closeTimer = Timer(context.motion(_kChromeDuration), () {
      if (!mounted) return;
      ref.read(serverSelectionProvider.notifier).select(null);
      _openCtrl.reverse();
    });
  }

  @override
  void dispose() {
    _closeTimer?.cancel();
    _funcBarVisible.dispose();
    _keys.dispose();
    _open.dispose();
    _openCtrl.dispose();
    _timer?.cancel();
    _globeGuideTimer?.cancel();
    _scrollController.dispose();
    _sortVersion.dispose();
    _search.dispose();
    Stores.setting.globeEnabled.listenable().removeListener(
      _globeEnabledListener,
    );
    _globe.dispose();
    _tag.dispose();
    _tags.dispose();
    _offsetNotifier.dispose();
    _landscapeController?.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    _tags = ValueNotifier(ref.read(serversProvider).tags);
    // The chrome follows the card rather than being timed against it: what
    // says the growth has finished is the growth finishing.
    _openCtrl.addStatusListener((status) {
      // The card is back in its column, so it is a card again.
      if (status == AnimationStatus.dismissed && _heroId != null) {
        setState(() => _heroId = null);
      }
      final showing = status == AnimationStatus.completed;
      if (showing == _detailShowing) return;
      setState(() => _detailShowing = showing);
    });
    Stores.setting.globeEnabled.listenable().addListener(_globeEnabledListener);
    _startAvoidJitterTimer();
    _scheduleGlobeGuide();
  }

  /// Starts the wait before [_maybeShowGlobeGuide], if there is anything to
  /// wait for.
  ///
  /// The two conditions checked here are the ones that do not change by
  /// waiting — the guide has been seen, or the feature is off — so a launch
  /// that fails either never arms a timer at all.
  void _scheduleGlobeGuide() {
    if (Stores.setting.globeGuided.fetch()) return;
    if (!Stores.setting.globeEnabled.fetch()) return;
    // Long enough for the launch notices to be up if there are any, so the
    // `isCurrent` check below has something to see. They are dialogs on the
    // root navigator and the guide draws above every route, so it would cover
    // one rather than wait for it.
    _globeGuideTimer = Timer(
      const Duration(seconds: 2),
      () => unawaited(_maybeShowGlobeGuide()),
    );
  }

  /// Points at the globe button, once per install.
  ///
  /// The server tab looks finished without it: a grid of cards with a row of
  /// icons over them, one of which happens to replace the whole list with a
  /// sphere. Nothing about the icon says that, and a view mode nobody presses
  /// is a view mode that does not exist.
  ///
  /// Every early return here leaves the guide for the *next launch* rather
  /// than retrying — the same rule the tab strip's guide follows, and the
  /// reason this runs once from [initState] rather than from a build.
  Future<void> _maybeShowGlobeGuide() async {
    final flag = Stores.setting.globeGuided;
    if (!mounted) return;
    // Already using it. Being shown where the button that is already pressed
    // is reads as the app not knowing what is on screen.
    if (_globe.value) return;
    // One walkthrough per launch, and the tab strip's comes first: it is about
    // how to reach anything at all. On a fresh install that puts this on the
    // second launch, which is also when there is something to look at.
    if (!Stores.setting.navTabMenuGuided.fetch()) return;
    // Nothing to place on a globe, and nothing worth interrupting a first run
    // with.
    if (ref.read(serversProvider).serverOrder.isEmpty) return;
    if (ModalRoute.of(context)?.isCurrent != true) return;
    // The tab is kept alive behind the others, so the wait above can finish
    // after the user has moved on — and the overlay draws above every route,
    // so it would point at a button on a page nobody is looking at. Null is
    // "nobody said", which is this widget mounted outside the home page.
    final tab = ref.read(currentHomeTabProvider);
    if (tab != null && tab != AppTab.server) return;

    final overlay = Overlay.maybeOf(context, rootOverlay: true);
    if (overlay == null) return;
    // Null when the button is not built — the actions row is gone in full
    // screen landscape.
    final spot = rectInOverlay(_globeBtnKey.currentContext, overlay);
    if (spot == null) return;

    await GuideOverlay.show(context, [
      GuideStep(body: context.l10n.globeGuide, spot: spot),
    ]);
    // At most one per install, and the open half of a funnel `globe.open`
    // closes. The guide exists because an icon that replaces the list with a
    // sphere explains nothing about itself; whether it works is whether the
    // installs that saw it are the ones that later pressed the button, and
    // every early return above leaves an install that never saw it.
    Diag.crumb(SbDiag.globe, 'guide');
    // Written when it has been seen through, not when it was scheduled.
    flag.put(true);
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

  @override
  Widget build(BuildContext context) {
    super.build(context);
    // Listen to provider changes and update the ValueNotifier
    ref.listen(serversProvider, (previous, next) => _tags.value = next.tags);
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

  /// The page around the list, or around the globe.
  ///
  /// [bare] is the globe having the window: no bar over it, and — through
  /// [ImmersiveTab] — no navigation under it either. See [_publishImmersive].
  Widget _buildScaffold(
    Widget child, {
    bool bare = false,
    String? openId,
    List<String> filtered = const [],
  }) {
    return Scaffold(
      // No bar at any width. A phone used to get the app's name and a cog here
      // because this was the one layout with no other way into the settings
      // (#657) — the wider ones have the nav rail, which carries its own. The
      // bottom bar's "more" is that way now, on every phone and every tab, so
      // what was left up here was a title naming the app on the app's own
      // first screen.
      appBar: bare ? null : _buildTagBar(openId, filtered),
      // The whole list, not a handful of labels inside it. The setting says
      // how big this page's text is, and it used to reach only the two lines
      // under a card's rings — so turning it up left every other word on the
      // page the size it was. Nothing on a card is a fixed height, so a larger
      // scale makes the cards taller rather than clipping them.
      body: Stores.setting.textFactor.listenable().listenVal((val) {
        return MediaQuery.withNoTextScaling(
          child: Builder(
            builder: (context) => MediaQuery(
              data: MediaQuery.of(
                context,
              ).copyWith(textScaler: TextScaler.linear(val)),
              // The bar above spends the top inset, as an app bar does; this
              // is what is left, and what it still has to clear is the home
              // indicator — especially with [bare] on, since the navigation
              // that used to sit between the two is gone.
              child: SafeArea(top: false, child: child),
            ),
          ),
        );
      }),
    );
  }

  Widget _buildPortrait() {
    final serverOrder = ref.watch(serversProvider.select((s) => s.serverOrder));
    final servers = ref.watch(serversProvider.select((s) => s.servers));
    // Which server has grown into the page, or null for the grid. Read here
    // rather than inside the builder below, which is a listener's callback and
    // not a build of this element.
    final openId = ref.watch(serverSelectionProvider);

    // Watched only for the order that depends on them, and only in this
    // method — which is a `build`, where `ref.watch` belongs. The sort runs
    // inside a `ListenableBuilder` below, and watching from that callback
    // would be a dependency registered outside the build that owns it.
    //
    // `select` narrows it to the transition: a status poll landing does not
    // reorder the list, a server connecting or dropping does.
    // Watched only where the order depends on them, and only in this method —
    // which is a `build`, where `ref.watch` belongs. Every field but the two
    // that read nothing about a machine needs its state, so the whole thing is
    // read for those: `select` cannot narrow "a reading changed".
    final needsState = ServerSortOrder.of(_tag.value).field.readsStatus;
    final states = !needsState
        ? const <String, ServerState>{}
        : {for (final id in serverOrder) id: ref.watch(serverProvider(id))};

    return _ServerOpenRequest(
      split: _opensInPlace(context),
      onOpen: _openRequestedServer,
      child: ListenableBuilder(
        // The four ways of viewing the list, and nothing else: a tag, a
        // search, an order, and whether it is a globe.
        listenable: Listenable.merge([_tag, _sortVersion, _search, _globe]),
        builder: (_, _) {
          // The settings arrangement, viewed however the sort button says —
          // see [ServerSortOrder], whose first option is that arrangement
          // unchanged.
          final ordered = ServerSortOrder.of(_tag.value).apply(
            serverOrder,
            servers,
            (id) => states[id] ?? ref.read(serverProvider(id)),
          );
          final filtered = _filterServers(ordered);
          _lastFiltered = filtered;
          // The empty states win over the globe — see [_buildBodySmall] — so
          // an empty one is not the globe having the window, and the bar with
          // the control that undoes the filter has to stay.
          //
          // And an open server wins over both: tapping a dot on the sphere is
          // how a server is opened from there, so the globe has to give way to
          // what it was asked to open — and it is still what the page goes
          // back to when that is closed.
          final globe =
              _globe.value && filtered.isNotEmpty && openId == null;
          _publishImmersive(globe);
          return _bound(
            _buildScaffold(
              _buildBodySmall(
                filtered: filtered,
                globe: globe,
                openId: openId,
              ),
              bare: globe,
              openId: openId,
              filtered: filtered,
            ),
          );
        },
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
    // The platform's own modifier: a Mac holds command where everything else
    // holds control, and a binding that names the wrong one is a binding
    // nobody can press.
    SingleActivator cmd(LogicalKeyboardKey key) =>
        SingleActivator(key, meta: isMacOS, control: !isMacOS);

    return CallbackShortcuts(
      bindings: {
        // What the top-left arrow does, and what a set being built up is
        // abandoned with.
        //
        // Handle the innermost route first. The context menu is a separate
        // route and receives key events before this page.
        const SingleActivator(LogicalKeyboardKey.escape): () {
          if (_selecting) {
            _endSelecting();
          } else {
            _closeDetail();
          }
        },
        cmd(LogicalKeyboardKey.bracketLeft): () => _stepServer(-1),
        cmd(LogicalKeyboardKey.bracketRight): () => _stepServer(1),
        // The list, from inside one of its machines. Nothing when the list is
        // already the page — the bar's own search is what that wants.
        cmd(LogicalKeyboardKey.keyK): () {
          final openId = ref.read(serverSelectionProvider);
          if (openId != null) _showServerSheet(_lastFiltered, openId);
        },
      },
      child: Focus(focusNode: _keys, child: child),
    );
  }

  /// The machine before or after the open one, wrapping at the ends.
  ///
  /// Wrapping because the list is short and the alternative is a key that
  /// silently does nothing at one end of it.
  void _stepServer(int delta) {
    final openId = ref.read(serverSelectionProvider);
    if (openId == null || _lastFiltered.length < 2) return;
    final at = _lastFiltered.indexOf(openId);
    if (at < 0) return;
    final next = (at + delta) % _lastFiltered.length;
    _openDetail(_lastFiltered[next]);
  }

  /// Whether a server opens where its card is, or as a page of its own.
  ///
  /// One column has no room to grow a card into: the card already has the
  /// width, so growing it would only make it taller, and what a phone can
  /// afford is one thing at a time. Above that the card grows in place and the
  /// list makes way for it, which is what keeps the list one page.
  bool _opensInPlace(BuildContext context) =>
      MediaQuery.sizeOf(context).width >= AdaptivePanes.kSplitWidth;

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
  PreferredSizeWidget _buildTagBar(String? openId, List<String> filtered) {
    if (_selecting) return _buildSelectionBar(filtered);
    return PreferredSizeListenBuilder(
      // Which tag is on, what tags there are to choose between, and how the
      // list is ordered — the sort button draws its own current icon.
      listenable: Listenable.merge([_tags, _tag, _sortVersion]),
      // The wrapper is what the `Scaffold` measures, so it has to be told; its
      // own default is a full toolbar.
      preferSize: const Size.fromHeight(SessionTabBar.height),
      builder: () {
        return SizedBox(
          height: SessionTabBar.height,
          child: InlineSearchBar(
            controller: _search,
            child: LayoutBuilder(
              builder: (_, cons) => Row(
                children: [
                  // The way back comes first and takes no room when there is
                  // nowhere to go back to.
                  //
                  // Inset to where the switcher's own glyph sits when there is
                  // nothing open — `SessionSwitcherLabel` holds it 14 off the
                  // edge, and a button's own 7 is half of that — so the first
                  // thing in the bar is in the same place either way.
                  if (openId != null) const SizedBox(width: 7),
                  if (openId != null)
                    Btn.icon(
                      text: libL10n.close,
                      icon: const Icon(Icons.arrow_back_ios_new, size: 17),
                      onTap: _closeDetail,
                    ),
                  Expanded(
                    child: openId == null
                        ? _buildTagSwitcher()
                        : _buildServerSwitcher(openId, filtered),
                  ),
                  // Not while one is open: the page is one machine then, and
                  // how many of them fit on a screen is not a question it has.
                  if (openId == null)
                    _buildDensityControl(filtered.length, room: cons.maxWidth),
                  // The rest act on the list, and the list is still the page
                  // with one of its cards open — so they stay where they are
                  // rather than following a server into its own page.
                  ..._listActions(globeKey: _globeBtnKey),
                  const SizedBox(width: 7),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  /// What is being done to several machines at once, in the bar's place.
  ///
  /// The bar's own controls are about the list — a tag, a search, an order —
  /// and none of them means anything while a set is being built up. So the
  /// whole strip becomes the set: how many, out of how many, and the things
  /// that can be done to all of them.
  ///
  /// The actions are the single-machine set minus everything that cannot be
  /// done to several: there is no one terminal for three machines, and no one
  /// address to copy.
  PreferredSizeWidget _buildSelectionBar(List<String> filtered) {
    final scheme = Theme.of(context).colorScheme;
    final count = _selected.length;

    return PreferredSize(
      preferredSize: const Size.fromHeight(SessionTabBar.height),
      child: SizedBox(
        height: SessionTabBar.height,
        child: Row(
          children: [
            Btn.icon(
              text: libL10n.close,
              icon: const Icon(Icons.close, size: 18),
              onTap: _endSelecting,
            ),
            Icon(Icons.check_box, size: 19, color: scheme.primary),
            const SizedBox(width: 9),
            Text(
              '$count',
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(width: 7),
            Text('/ ${filtered.length}', style: UIs.text11Grey),
            const Spacer(),
            Btn.icon(
              text: l10n.connect,
              icon: const Icon(Icons.link, size: 18),
              onTap: () => _bulk((spi) {
                ref.read(serversProvider.notifier).refresh(spi: spi);
              }),
            ),
            Btn.icon(
              text: l10n.disconnect,
              icon: const Icon(Icons.link_off, size: 18),
              onTap: () => _bulk((spi) {
                ref.read(serversProvider.notifier).closeServer(id: spi.id);
              }),
            ),
            Btn.icon(
              text: libL10n.tag,
              icon: const Icon(MingCute.hashtag_line, size: 18),
              onTap: _bulkTag,
            ),
            // The one action here that is about the list rather than about the
            // machines. Dragging is how one server is moved, and forty is
            // exactly where dragging stops being a way to do anything.
            Btn.icon(
              text: l10n.move,
              icon: const Icon(Icons.swap_vert, size: 18),
              onTap: _bulkMove,
            ),
            Btn.icon(
              text: libL10n.delete,
              icon: const Icon(Icons.delete, size: 18),
              onTap: _bulkDelete,
            ),
            const SizedBox(width: 7),
          ],
        ),
      ),
    );
  }

  /// Runs [each] over the chosen machines and then stops choosing.
  ///
  /// Stopping is the point: an action that left the set selected would leave
  /// the page in a state whose only purpose was to reach the action.
  void _bulk(void Function(Spi spi) each) {
    final servers = ref.read(serversProvider).servers;
    for (final id in _selected.toList()) {
      final spi = servers[id];
      if (spi != null) each(spi);
    }
    _endSelecting();
  }

  /// Adds one tag to every chosen machine.
  ///
  /// Adds rather than replaces: a tag is one of the things a server is, and a
  /// bulk edit that cleared the others would be a way to lose them quietly.
  Future<void> _bulkTag() async {
    final tag = await context.showRoundDialog<String>(
      title: libL10n.tag,
      child: Input(
        autoFocus: true,
        type: TextInputType.text,
        hint: libL10n.tag,
        onSubmitted: (value) => context.popDialog(value.trim()),
      ),
      actions: Btn.cancel().toList,
    );
    if (tag == null || tag.isEmpty || !mounted) return;

    final notifier = ref.read(serversProvider.notifier);
    final servers = ref.read(serversProvider).servers;
    for (final id in _selected.toList()) {
      final spi = servers[id];
      if (spi == null) continue;
      final tags = {...?spi.tags, tag}.toList();
      try {
        await notifier.updateServer(spi, spi.copyWith(tags: tags));
      } catch (e, st) {
        if (mounted) context.showErrDialog(e, st);
        return;
      }
    }
    _endSelecting();
  }

  /// Moves the chosen machines to one end of the arrangement.
  ///
  /// Both ends and nothing between them. A position to insert at is a number
  /// nobody has — the list being looked at is the whole of what is known about
  /// where things are — and "up one" applied to five machines at once is five
  /// separate answers about what it did.
  Future<void> _bulkMove() async {
    final toTop = await showRowsSheet<bool>(
      context,
      rows: (ctx) => [
        SheetChoiceTile(
          icon: Icons.vertical_align_top,
          title: l10n.moveToTop,
          selected: false,
          onTap: () => Navigator.of(ctx).pop(true),
        ),
        SheetChoiceTile(
          icon: Icons.vertical_align_bottom,
          title: l10n.moveToBottom,
          selected: false,
          onTap: () => Navigator.of(ctx).pop(false),
        ),
      ],
    );
    if (toTop == null || !mounted) return;

    final order = ref.read(serversProvider).serverOrder;
    final moved = moveInOrder(order, _selected, toTop: toTop);
    if (moved.equals(order)) {
      _endSelecting();
      return;
    }

    await ref.read(serversProvider.notifier).updateServerOrder(moved);
    if (!mounted) return;

    // The arrangement is only on screen under `manual`: under any of the
    // comparisons this would be a move with nothing to see, which reads as
    // the action having failed rather than as the sort having hidden it.
    const manual = ServerSortOrder(ServerSortField.manual, ascending: true);
    if (!manual.isCurrentFor(_tag.value)) {
      manual.save(_tag.value);
      _sortVersion.notify();
    }
    _endSelecting();
  }

  /// The one that cannot be undone, so it says how many.
  Future<void> _bulkDelete() async {
    final count = _selected.length;
    final confirmed = await context.showRoundDialog<bool>(
      title: libL10n.attention,
      child: Text(
        libL10n.askContinue('${libL10n.delete} ${libL10n.server}($count)'),
      ),
      actions: Btn.ok(red: true).toList,
    );
    if (confirmed != true || !mounted) return;

    final notifier = ref.read(serversProvider.notifier);
    for (final id in _selected.toList()) {
      try {
        await notifier.delServer(id);
      } catch (e, st) {
        if (mounted) context.showErrDialog(e, st);
        return;
      }
    }
    _endSelecting();
  }

  /// How much of each machine the list draws.
  ///
  /// A real control where the bar has room for one — four positions with the
  /// current one filled, so what the other three are is visible rather than
  /// something to go looking for. Where it has not, the same four are a sheet
  /// behind a button, which is what the tag and the sort already do.
  Widget _buildDensityControl(int count, {required double room}) {
    final stored = ServerDensityPref.of(_tag.value);

    // Room for four labelled positions, the switcher beside them and the four
    // buttons after them. Below it the labels are what would have to shrink,
    // and a segmented control with no labels is four unexplained icons.
    if (room < 860) {
      final resolved = stored.resolve(
        count: count,
        textScale: Stores.setting.textFactor.fetch(),
      );
      return Btn.icon(
        text: resolved.label,
        icon: Icon(resolved.icon, size: 18),
        onTap: () => _showDensitySheet(count),
      );
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 7),
      child: SegmentedTabs<ServerListDensity>(
        segments: [
          for (final density in ServerListDensity.values)
            SegmentedTab(
              value: density,
              label: density.label,
              icon: density.icon,
            ),
        ],
        selected: stored,
        onSelected: _setDensity,
      ),
    );
  }

  void _setDensity(ServerListDensity density) {
    ServerDensityPref.put(_tag.value, density);
    _sortVersion.notify();
  }

  Future<void> _showDensitySheet(int count) async {
    final stored = ServerDensityPref.of(_tag.value);
    await showRowsSheet<void>(
      context,
      rows: (ctx) => [
        for (final density in ServerListDensity.values)
          SheetChoiceTile(
            icon: density.icon,
            title: density.label,
            // What `auto` means right now, said where the choice is made: the
            // control otherwise gives no clue which of the three it picked.
            selected: density == stored,
            onTap: () {
              Navigator.of(ctx).pop();
              _setDensity(density);
            },
          ),
        Padding(
          padding: const EdgeInsets.fromLTRB(17, 7, 17, 27),
          child: Text(
            '${libL10n.auto} · $count → '
            '${ServerListDensity.autoFor(count).label}',
            style: UIs.text11Grey,
            textAlign: TextAlign.center,
          ),
        ),
      ],
    );
  }

  Widget _buildTagSwitcher() {
    final tags = _tags.value.toList();
    final current = _tag.value;
    final at = tags.indexOf(current);

    return SessionSwitcherLabel(
      name: current.isEmpty ? libL10n.all : '#$current',
      // Counting from 1, and null on "all" — which is not one of the tags but
      // the absence of a choice among them, so it shows the icon instead.
      position: at < 0 ? null : at + 1,
      total: tags.length,
      icon: MingCute.hashtag_line,
      // Opens even with no tags anywhere. It used to be a plain label then —
      // the rule the session strips follow with nothing open — but the two
      // cases are not alike: a terminal strip with no sessions is a feature
      // nobody has started using, while this is a filter whose whole
      // vocabulary is defined elsewhere. Someone looking for tags taps the
      // thing marked with a `#`, and a control that does nothing answers
      // neither "there are none" nor "here is where they come from". The
      // sheet says both.
      onTap: () => _showTagSheet(tags),
    );
  }

  /// Which machine is open, as the one control the detail needs of its own.
  ///
  /// The same shape the terminal tab's switcher has — position, name, chevron
  /// — because it answers the same question: this is one of several, and here
  /// is how to reach the others. The strip of pills over the card is the same
  /// list; this is what is left of it once there are more machines than pills
  /// that fit.
  Widget _buildServerSwitcher(String openId, List<String> filtered) {
    final at = filtered.indexOf(openId);
    final spi = ref.read(serversProvider).servers[openId];

    return SessionSwitcherLabel(
      name: spi?.name ?? openId,
      position: at < 0 ? null : at + 1,
      total: filtered.length,
      icon: BoxIcons.bx_server,
      onTap: () => _showServerSheet(filtered, openId),
    );
  }

  /// Every machine, for picking one without going back to the grid.
  ///
  /// The strip of pills over an open card is this same list and answers it for
  /// a handful; past that they stop fitting, and what a longer one wants is
  /// something to type into and the tags to group by.
  Future<void> _showServerSheet(List<String> filtered, String openId) async {
    final picked = await showServerSwitcher(
      context,
      ids: filtered,
      current: openId,
    );
    if (picked == null || !mounted) return;
    _openDetail(picked);
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
  /// [globeKey] marks the globe button for the guide to point at, and is
  /// passed by the two callers that draw the *list* — the bar over a single
  /// column and the rail beside a pane.
  ///
  /// Not by the row over the globe pane, and that is load-bearing rather than
  /// tidiness: the split layout now cross-fades the two panes, so both rows
  /// are mounted at once for the length of the swap, and two widgets carrying
  /// one `GlobalKey` at the same time is an exception rather than a bad
  /// layout. Nothing is lost by leaving it off — the guide returns early when
  /// the globe is already up, so the pane that has no key is never the one it
  /// would have measured.
  List<Widget> _listActions({Key? globeKey}) => [
    Btn.icon(
      text: libL10n.search,
      icon: const Icon(Icons.search, size: 18),
      onTap: _search.start,
    ),
    Btn.icon(
      text: libL10n.sort,
      icon: Icon(ServerSortOrder.of(_tag.value).icon, size: 18),
      onTap: _showSortSheet,
    ),
    // Absent, not disabled, when the feature is off: a button that explains
    // itself by doing nothing is worse than one that is not offered.
    if (Stores.setting.globeEnabled.fetch())
      _globe.listenVal(
        (on) => Btn.icon(
          key: globeKey,
          text: l10n.globe,
          icon: Icon(
            on ? Icons.grid_view_rounded : Icons.public,
            size: 18,
            color: on ? Theme.of(context).colorScheme.primary : null,
          ),
          onTap: _toggleGlobe,
        ),
      ),
    Btn.icon(
      text: libL10n.add,
      icon: const Icon(Icons.add, size: 18),
      onTap: _onTapAddServer,
    ),
  ];

  void _toggleGlobe() {
    if (!_globe.value &&
        _filterServers(ref.read(serversProvider).serverOrder).isEmpty) {
      Toast.show(l10n.serverTabEmpty);
      return;
    }
    final on = !_globe.value;
    _globe.value = on;
    Stores.setting.serverPageGlobe.put(on);
    // The button is the feature's only front door, so this is what says whether
    // it is used at all. The pair matters rather than the opening alone: the
    // choice is remembered across launches, so a globe that is turned back off
    // is the one signal that someone tried it and did not keep it.
    Diag.crumb(SbDiag.globe, on ? 'open' : 'close');
  }

  /// [immersive] is the globe having the window rather than sharing it with a
  /// pane, which is what decides whether it has to carry its own way out: the
  /// bar holding the toggle is not on screen then, and neither is the
  /// navigation.
  Widget _buildGlobe(List<String> filtered, {bool immersive = false}) {
    return ServerGlobe(
      key: const ValueKey('globe'),
      ids: filtered,
      onTapServer: (spi) =>
          _onTapCard(context, ref.read(serverProvider(spi.id))),
      onEditServer: (spi) =>
          ServerEditPage.route.go(context, args: SpiRequiredArgs(spi)),
      action: immersive ? _buildGlobeExit() : null,
    );
  }

  /// The way back to the list, over the globe itself.
  ///
  /// The same icon the bar's toggle wears while the globe is up, because it is
  /// the same control — what is offered is the grid, and the icon says so.
  ///
  /// On a surface of its own rather than a bare icon: it sits over a sphere,
  /// a coastline or a card, and none of those is a background an icon reads
  /// against on its own.
  Widget _buildGlobeExit() {
    final scheme = Theme.of(context).colorScheme;
    return Material(
      color: scheme.surfaceContainerHigh.withValues(alpha: 0.92),
      elevation: 3,
      shape: const CircleBorder(),
      clipBehavior: Clip.antiAlias,
      child: IconButton(
        icon: const Icon(Icons.close, size: 18),
        tooltip: libL10n.close,
        onPressed: _toggleGlobe,
      ),
    );
  }

  /// How to order the list, and whether to cut it into sections.
  ///
  /// The default is the arrangement from the settings, so this starts as a
  /// view of what the user already decided rather than as a decision it takes
  /// from them.
  ///
  /// The two are in one sheet and are not one choice: an order is which
  /// machine comes first, and grouping is which machines are read together.
  /// So picking an order closes the sheet — it is the question that was asked
  /// — and the switch under them does not, because it is a second question
  /// that has only now become visible.
  Future<void> _showSortSheet() async {
    final tag = _tag.value;
    await showRowsSheet<void>(
      context,
      rows: (ctx) => [
        for (final order in ServerSortOrder.all)
          SheetChoiceTile(
            icon: order.icon,
            title: order.label,
            selected: order.isCurrentFor(tag),
            onTap: () {
              order.save(tag);
              Navigator.of(ctx).pop();
              _sortVersion.notify();
            },
          ),
        const Divider(height: 1),
        StatefulBuilder(
          builder: (_, setSheetState) {
            final on = ServerListGrouping.of(tag) == ServerListGrouping.tag;
            return SwitchListTile(
              secondary: const Icon(MingCute.hashtag_line),
              title: Text(l10n.groupByTag),
              // What it is for, where it is turned on: the sections are cut by
              // the tags a machine carries, which is a thing set in the
              // server's own editor and not here.
              subtitle: Text(l10n.groupByTagTip, style: UIs.text11Grey),
              value: on,
              onChanged: (next) {
                ServerListGrouping.put(
                  tag,
                  next ? ServerListGrouping.tag : ServerListGrouping.none,
                );
                setSheetState(() {});
                _sortVersion.notify();
              },
            );
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
          // Where tags come from, for the sheet that would otherwise be one
          // row saying "All" — which reads as a broken filter rather than as
          // an empty one. A server's editor is the only place they are made,
          // and nothing on this tab says so.
          if (tags.isEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(17, 17, 17, 27),
              child: Text(
                l10n.tagsEmptyTip,
                style: UIs.textGrey,
                textAlign: TextAlign.center,
              ),
            )
          else
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

  /// What [ImmersiveTab] has last been told, so an unchanged answer is not
  /// repeated.
  bool _immersive = false;

  /// Says whether the globe is filling this tab.
  ///
  /// Called from a build and applied after the frame, which is the same shape
  /// `_syncFullscreenSystemUi` on the home page has and for the same reason:
  /// the answer is only knowable while laying the page out — it depends on the
  /// split, the filter and the toggle — and a provider must not be written to
  /// during a build.
  void _publishImmersive(bool on) {
    if (_immersive == on) return;
    _immersive = on;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      ref.read(immersiveTabProvider.notifier).update(AppTab.server, wants: on);
    });
  }

  Widget _buildBodySmall({
    required List<String> filtered,
    required bool globe,
    required String? openId,
  }) {
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
      duration: context.motion(_kViewSwapDuration),
      reverseDuration: context.motion(_kViewSwapDuration),
      switchInCurve: Curves.easeOutCubic,
      switchOutCurve: Curves.easeInCubic,
      // Scale and fade rather than fade alone — see [_viewSwapTransition] for
      // why the anchor is the sphere and not merely the middle. It applies to
      // the empty states too, where the same contraction reads as the list
      // being taken away rather than blinking out.
      transitionBuilder: _viewSwapTransition,
      layoutBuilder: _viewSwapLayout,
      child: switch (true) {
        // The empty states win over the globe, and each of the three is worth
        // more than an empty sphere: no servers at all is a new install that
        // needs telling how to add one, and a tag or a search with no hits is
        // a filter to undo — with the control to undo it right there. None of
        // that can be said by a globe with nothing on it.
        _ when globe => _buildGlobe(filtered, immersive: true),
        _ when filtered.isEmpty => _buildEmpty(),
        _ => KeyedSubtree(
          key: const ValueKey('grid'),
          child: _buildGrid(filtered, openId),
        ),
      },
    );
  }

  /// One section's heading: what these machines have in common, how many of
  /// them there are, and how many are over the line.
  ///
  /// The count is what a heading is for at this size — a section of eight is
  /// eight tiles nobody counts — and the alert count beside it is the one
  /// thing that would otherwise need the section read to find. A section with
  /// nothing wrong in it says nothing about alerts rather than saying zero.
  Widget _groupHeading(TagGroup<String> group, {required bool first}) {
    final over = group.items
        .where((id) {
          final srv = ref.read(serverProvider(id));
          return srv.conn == ServerConn.finished &&
              serverCardReadings(srv).all.any((m) => m.over);
        })
        .length;

    return Padding(
      // Lined up with the cards under it, which carry their own margin.
      padding: EdgeInsets.fromLTRB(4, first ? 3 : 17, 4, 7),
      child: Row(
        children: [
          Text(
            group.label ?? l10n.ungrouped,
            style: const TextStyle(
              fontSize: 11,
              height: 1,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.5,
              color: Colors.grey,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(width: 9),
          Expanded(
            child: Divider(
              height: Hairline.thickness,
              thickness: Hairline.thickness,
              color: Hairline.color(context),
            ),
          ),
          const SizedBox(width: 9),
          Text('${group.items.length}', style: UIs.text11Grey),
          if (over > 0) ...[
            const SizedBox(width: 7),
            const Icon(Icons.warning_amber, size: 13, color: StatePalette.warn),
            const SizedBox(width: 3),
            Text(
              '$over',
              style: const TextStyle(
                fontSize: 11,
                height: 1,
                color: StatePalette.warn,
              ),
            ),
          ],
        ],
      ),
    );
  }

  /// The list, and the one card of it that has grown into the page.
  ///
  /// One widget for both, because they are one thing: opening a server does
  /// not replace the list with a page, it takes a card out of the grid and
  /// gives it the width. What is below the card once it has the width — the
  /// readings in full, the facts, the row of things to do — arrives after the
  /// movement has finished, so that only one thing is ever moving.
  Widget _buildGrid(List<String> filtered, String? openId) {
    // What the bar and the readings are of, and what the grid is animating.
    // The two are the same while a machine is open and differ on the way back
    // out: the selection goes first so that the page's chrome can leave, and
    // the card still has to shrink.
    final open = openId != null && filtered.contains(openId);
    final heroId = _heroId;
    final hero = heroId != null && filtered.contains(heroId);
    // What the list draws each machine as. Not while one is open: the page has
    // one shape, and the row or tile that was tapped is on its way to it.
    final density = ServerDensityPref.of(_tag.value).resolve(
      count: filtered.length,
      textScale: Stores.setting.textFactor.fetch(),
    );

    // The sections, or null for one list. Cut before the sort is applied to
    // nothing — `filtered` is already in the chosen order, and grouping keeps
    // that order inside each section rather than replacing it.
    final servers = ref.read(serversProvider).servers;
    final groups = ServerListGrouping.of(_tag.value) == ServerListGrouping.tag
        ? groupByTag(filtered, (id) => servers[id]?.tags)
        : null;

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
    //
    // Rebuilt on every frame of the opening, and only the one card that is
    // opening: what that card looks like at each point between is a lerp
    // inside it, so it has to be rebuilt to change, and the rest of them do
    // not change at all. Their widgets are built once out here, and Flutter
    // skips an element whose widget is the one it already has — otherwise
    // every card on screen, chart included, was rebuilt sixty times a second
    // to be drawn fainter. The grid's own geometry is not rebuilt either; the
    // render object is told the width directly.
    // Kept between the builder's runs, and thrown away whenever this method is
    // called again — which is whenever anything that decides what a card looks
    // like has changed.
    //
    // A `LayoutBuilder` runs its builder again whenever anything inside it is
    // dirty, not only when its constraints change, and during the movement
    // that is every frame. So this is where the cards would be built afresh
    // sixty times a second, each one to be drawn a little fainter.
    final others = <double, Map<String, Widget>>{};

    final grid = LayoutBuilder(
      builder: (_, cons) {
        final rest = others.putIfAbsent(
          cons.maxWidth,
          () => {
            for (final id in filtered)
              if (id != heroId)
                id: Consumer(
                  key: ValueKey(id),
                  builder: (_, ref, _) => _buildEachServerCard(
                    ref.watch(serverProvider(id)),
                    // How far the *page* has taken over, which is what fades
                    // the cards that are not the one being opened. An
                    // animation rather than a number, so the widget this
                    // returns is the one it returned last frame and Flutter
                    // skips it outright.
                    fade: hero ? _othersOpacity : null,
                    density: density,
                    pageWidth: cons.maxWidth,
                  ),
                ),
          },
        );
        // Every one of them, the whole way through. The rest used to be
        // taken out of the list while one was open, which made them leave
        // and then arrive again — a card growing in and shuffling into
        // place for each of them, on a page nobody had asked to rearrange.
        // They fade instead, and their slots are held for them.
        //
        // Its own `Consumer` per card, so a status poll rebuilds the one card
        // whose server answered rather than the grid. Watched from this page's
        // `ref` — which is what a builder would have to do — any server's
        // reading landing rebuilt every card on screen.
        Widget cardOf(String id) =>
            rest[id] ??
            Consumer(
              key: ValueKey(id),
              builder: (_, ref, _) => _buildEachServerCard(
                ref.watch(serverProvider(id)),
                openness: _open.value,
                density: density,
                // The box the page will have, which is this same box: the
                // grid and the page it becomes are the two children of one
                // crossing. The page asks its own width the same question, so
                // both arrive at the same answer about the facts column.
                pageWidth: cons.maxWidth,
              ),
            );

        // One section, or the whole list as one. [scrollable] is off for a
        // grouped list, where the page owns the scrolling and each section is
        // laid out inside it.
        AnimatedMasonry masonry(List<String> ids, {required bool scrollable}) =>
            AnimatedMasonry(
              controller: scrollable ? _scrollController : null,
              scrollable: scrollable,
              // Constant. The card growing out of the grid needs the page's
              // inset rather than the grid's, but taking it from here would
              // change every column's width — so every other card would slide
              // sideways for a movement that is not about them. The card makes
              // up the difference in its own padding instead.
              padding: scrollable ? MasonryList.kPadding : EdgeInsets.zero,
              // The cards make way at the same pace as the one growing, so the
              // whole thing reads as one movement rather than as a card
              // growing into a grid that is still settling.
              moveDuration: context.motion(_kOpenDuration),
              changeDuration: context.motion(Durations.medium2),
              // The column each shape wants: a line per machine takes the
              // width, a tile takes as little as a name needs, and a card
              // takes the one width the rest of the app lays a column out at.
              columnWidth: switch (density) {
                ServerListDensity.grid => 170.0,
                ServerListDensity.rows => double.infinity,
                _ => UIs.columnWidth,
              },
              // And how much air each shape wants around it: a wall of tiles
              // reads as a wall at the design's 5, and a list of lines as a
              // list at nothing at all.
              spacing: switch (density) {
                ServerListDensity.grid => 5.0,
                ServerListDensity.rows => 0.0,
                _ => MasonryList.kSpacing,
              },
              // Only the section the card is in: the others have no card to
              // expand, and a key they do not hold is one they ignore.
              expandedKey: hero && ids.contains(heroId)
                  ? ValueKey(heroId)
                  : null,
              expansion: _open.value,
              // One for every section: a card is known by its server, and is
              // the same height whichever section it is in.
              memory: _gridMemory,
              children: [for (final id in ids) cardOf(id)],
            );

        if (groups == null) {
          return AnimatedBuilder(
            animation: _open,
            builder: (_, _) => masonry(filtered, scrollable: true),
          );
        }

        // A section each, under one scroll position. A masonry per section
        // rather than one with headings in it: the headings span the row and a
        // masonry lays its children into columns, so a heading placed in one
        // would sit in a column beside the cards it is a heading for.
        //
        // The cost is that a card moving between sections — a tag edited — is
        // a card leaving one grid and arriving in another rather than one
        // travelling, which is a fade rather than a flight. That is the right
        // way round: what moved it was not the list rearranging itself.
        return AnimatedBuilder(
          animation: _open,
          builder: (_, _) => SingleChildScrollView(
            controller: _scrollController,
            padding: MasonryList.kPadding,
            physics: const AlwaysScrollableScrollPhysics(),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              mainAxisSize: MainAxisSize.min,
              children: [
                for (final (at, group) in groups.indexed) ...[
                  _groupHeading(group, first: at == 0),
                  masonry(group.items, scrollable: false),
                ],
              ],
            ),
          ),
        );
      },
    );

    // The page is mounted for the whole movement, under the card that is
    // becoming it. What it has that a card has not — the facts beside the
    // readings, the tables under them — comes in while the chart is still
    // growing, rather than after: a card growing into a page and then the page
    // filling in is two arrivals for one tap. Its own readings are laid out
    // and not painted until the card hands them over, since the card is
    // already drawing exactly those widgets in exactly those boxes.
    //
    // The strip above both belongs to neither: it is what the list becomes
    // while one of its cards is open, so it stays whichever of the two is on
    // screen.
    final body = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _buildStrip(filtered, openId),
        Expanded(
          child: Stack(
            fit: StackFit.expand,
            children: [
              if (hero) _buildOpenDetail(heroId),
              // Dropped the moment the page takes the readings over rather
              // than crossed with it: at that point both are drawing the same
              // widgets in the same places, so a crossing would have nothing
              // to carry and 200ms to carry it in.
              if (!_detailShowing)
                KeyedSubtree(key: const ValueKey('cards'), child: grid),
              // Above both, and the tab's rather than the page's — see
              // [_buildFuncBar].
              if (hero)
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: 0,
                  child: _buildFuncBar(heroId),
                ),
            ],
          ),
        ),
      ],
    );

    // Pulling is how a phone asks for this, and the only place anything asks
    // for the whole list at once — the bar's refresh button is gone. Nothing
    // is lost that a pointer cannot reach: the status poll runs on its own,
    // and each card carries its own refresh for the one server behind it.
    if (!isMobile || open) return body;
    return RefreshIndicator(onRefresh: _refreshAll, child: body);
  }

  /// The open server's own page, without the bar this page already has.
  ///
  /// One key for every machine, so that changing which one is open is not a
  /// change the crossing above sees: what that crossing is for is the card
  /// becoming the page, and stepping from one machine to the next is a
  /// movement of its own — see [DirectionalSwap].
  Widget _buildOpenDetail(String id) {
    final spi = ref.read(serversProvider).servers[id];
    if (spi == null) return const SizedBox.shrink();
    return KeyedSubtree(
      key: const ValueKey('detail'),
      // Where the bar floating over this learns that it is being read past.
      // It is not inside the page any more, so it has no controller to ask —
      // and there is a page per machine, so there would be a different one
      // after every step through the list.
      child: NotificationListener<ScrollNotification>(
        onNotification: _onDetailScroll,
        child: DirectionalSwap(
          id: id,
          direction: _swapDirection,
          duration: context.motion(_kOpenDuration),
          child: _detailFor(id, spi),
        ),
      ),
    );
  }

  Widget _detailFor(String id, Spi spi) {
    return KeyedSubtree(
      key: ValueKey('detail:$id'),
      // Opaque, because the grid is drawn on top of it while the card is
      // growing: a translucent page would show the two layouts through each
      // other for the length of the movement.
      child: Material(
        type: MaterialType.canvas,
        color: Theme.of(context).scaffoldBackgroundColor,
        child: ServerDetailPage(
          args: SpiRequiredArgs(spi),
          bare: true,
          // Mounted from the first frame of the movement, so what it has that
          // the card has not arrives with the chart rather than after it.
          entrance: _open,
          // Until then the card is the one drawing them.
          readingsShowing: _detailShowing,
        ),
      ),
    );
  }

  /// The row of things that can be done to the open machine.
  ///
  /// The tab's rather than the page's, so that stepping to another machine
  /// leaves it where it is. The page slides — that is what says which way
  /// through the list the step went — and a row of the same buttons sliding
  /// with it is the one part of that movement that says nothing at all. What
  /// does differ between two machines changes in place, a slot at a time; see
  /// [ServerFuncBtns].
  Widget _buildFuncBar(String id) {
    return Consumer(
      builder: (_, ref, _) {
        final si = ref.watch(serverProvider(id));
        final (entries: btns, any: any) = serverDetailFuncBtns(si);
        // A machine with nothing to show yet keeps the row, greyed: the
        // entries have not gone away, there is simply no connection to do any
        // of them through, and the positions are worth keeping. A machine that
        // is reachable and can serve none of them has no row — what belongs in
        // its place is the page's own explanation.
        final show = serverDetailHasContent(si) ? any : btns.isNotEmpty;
        if (!show) return const SizedBox.shrink();
        // Rises with the card and sinks with it, rather than arriving on its
        // own once the movement is over and vanishing when it starts back.
        // That leaves [HideOnScroll] doing only what it is for — getting out
        // of the way of a page being read past — so its own arrival is off.
        return AnimatedBuilder(
          animation: _open,
          child: RepaintBoundary(
            child: HideOnScroll.driven(
              visible: _funcBarVisible,
              enterDelay: Duration.zero,
              enterDuration: Duration.zero,
              child: ServerFuncBar(spi: si.spi, btns: btns),
            ),
          ),
          builder: (_, child) {
            final t = _open.value;
            if (t >= 1) return child!;
            return Opacity(
              opacity: t.clamp(0.0, 1.0),
              child: Transform.translate(
                offset: Offset(0, (1 - t) * kFuncBarHeight * 0.5),
                child: child,
              ),
            );
          },
        );
      },
    );
  }

  /// Whether the page under the function row is being read past.
  bool _onDetailScroll(ScrollNotification n) {
    // The page's own scrollable, not a list inside one of its cards.
    if (n.depth != 0) return false;
    final next = switch (n) {
      UserScrollNotification(:final direction) => switch (direction) {
        // The direction dragged, not the direction the offset moved: a list
        // settling after a fling is not someone asking for this.
        ScrollDirection.reverse => false,
        ScrollDirection.forward => true,
        ScrollDirection.idle => _funcBarVisible.value,
      },
      _ => _funcBarVisible.value,
    };
    // Always there at the top, whatever the last drag was.
    _funcBarVisible.value =
        next || n.metrics.pixels <= n.metrics.minScrollExtent;
    return false;
  }

  /// The strip between the bar and what is under it.
  ///
  /// Two things in one place, and one question: which machine. With nothing
  /// open it is what the whole list adds up to; with a machine open it is the
  /// rest of the list, as pills. So they are one slot at one height, and going
  /// from one to the other turns the slot over — each face through a quarter
  /// turn, so the strip is edge-on halfway and there is nothing to cross
  /// there. Faded past each other instead, they read as two unrelated rows
  /// swapping places.
  ///
  /// Pinned rather than scrolling with the list, which the overview used to
  /// do: it shares a slot with the switcher now, and the switcher is over the
  /// page rather than in it.
  Widget _buildStrip(List<String> filtered, String? openId) {
    // Both faces built once, out here: the builder below runs on every frame
    // of the movement and returns one of these two, which Flutter skips
    // rebuilding because it is the widget it already has.
    final front = RepaintBoundary(
      child: Padding(
        // Lined up with the cards: the grid's own inset plus a card's margin.
        padding: const EdgeInsets.symmetric(horizontal: 12),
        child: ServerOverview(ids: filtered, open: openId != null),
      ),
    );
    final back = RepaintBoundary(child: _buildSwitcher(filtered, openId));

    // Around the turn rather than inside each face: one definition for both,
    // so what is below starts in the same place whichever face is up, and the
    // axis of the turn is the middle of the strip rather than of the strip
    // plus its gap.
    return Padding(
      padding: _kStripInset,
      child: AnimatedBuilder(
        animation: _open,
        builder: (_, _) {
          final t = _open.value;
          if (t <= 0) return front;
          if (t >= 1) return back;
          final facing = t < 0.5;
          return Transform(
            alignment: Alignment.center,
            transform: Matrix4.identity()
              // Enough for the turn to read as one rather than as a squash,
              // and not so much that the near edge swings out past the bar
              // above.
              ..setEntry(3, 2, 0.0015)
              ..rotateX(facing ? -t * math.pi : (1 - t) * math.pi),
            child: facing ? front : back,
          );
        },
      ),
    );
  }

  /// Which machine is on screen, and the rest of them.
  ///
  /// A row of the list that has made way, so it belongs where the list was.
  Widget _buildSwitcher(List<String> filtered, String? openId) {
    final at = openId == null ? -1 : filtered.indexOf(openId);

    // No gap of its own: [_kStripInset] is around both faces.
    return SizedBox(
      key: const ValueKey('switcher'),
      height: _kStripHeight,
      child: EdgeFadeScroll(
        builder: (_, controller) => ListView(
          controller: controller,
          scrollDirection: Axis.horizontal,
          // Lined up with the cards under it rather than with the window:
          // this is a row of the list, so its first pill starts where the
          // cards start. The pills carry two of their own.
          padding: const EdgeInsets.symmetric(horizontal: 10),
          children: [
            for (final (i, id) in filtered.indexed)
              _buildSwitcherPill(id, current: i == at),
          ],
        ),
      ),
    );
  }

  Widget _buildSwitcherPill(String id, {required bool current}) {
    final scheme = Theme.of(context).colorScheme;
    return Consumer(
      builder: (_, ref, _) {
        final srv = ref.watch(serverProvider(id));
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 2),
          child: Center(
            // Its own height rather than the strip's: the strip is as tall as
            // the overview it shares a slot with, and a pill stretched to that
            // is a button the size of a card.
            child: SizedBox(
              height: _kPillHeight,
              child: Material(
            color: current
                ? scheme.secondaryContainer
                : scheme.surfaceContainerHighest,
            shape: const StadiumBorder(),
            clipBehavior: Clip.antiAlias,
            child: InkWell(
              onTap: current ? null : () => _openDetail(id),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 13),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 7,
                      height: 7,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: serverStateDot(srv),
                      ),
                    ),
                    const SizedBox(width: 7),
                    Text(
                      srv.spi.name,
                      style: TextStyle(
                        fontSize: 12,
                        height: 1,
                        fontWeight: current
                            ? FontWeight.w500
                            : FontWeight.w400,
                        color: current
                            ? scheme.onSecondaryContainer
                            : Colors.grey,
                      ),
                    ),
                  ],
                ),
              ),
            ),
              ),
            ),
          ),
        );
      },
    );
  }

  /// What the page shows with no cards on it, which is three different
  /// things.
  ///
  /// A tag with nothing under it is a filter to undo — the servers are still
  /// there, and an empty page that does not say so reads as having lost them.
  /// A search with no hits is the same again, and the one that would be read
  /// most wrongly: with no tag on it used to answer "no servers yet" and offer
  /// to add one, on a page whose servers are all still there. No servers at
  /// all is the first thing a new install sees, and the one place worth
  /// spelling out what to do.
  ///
  /// Each gets a name for what is empty, a sentence saying why, and one way
  /// out — in that order, because the way out is what the sentence leads to.
  Widget _buildEmpty() {
    final query = _search.needle;
    if (query.isNotEmpty) {
      return EmptyPane(
        key: const ValueKey('empty-search'),
        icon: Icons.search_off,
        title: query,
        // What was searched, since it is neither everything about a server nor
        // an obvious subset of it: a machine is found by what it is called and
        // where it is, which are the two the editor asks for first.
        label: l10n.searchServerTip,
        action: Btn.text(text: libL10n.clear, onTap: _search.end),
      );
    }

    if (_tag.value.isNotEmpty) {
      return EmptyPane(
        key: const ValueKey('empty-tag'),
        icon: MingCute.hashtag_line,
        title: '#${_tag.value}',
        // Where tags come from, which is the question an empty one raises and
        // which nothing on this tab answers.
        label: l10n.tagsEmptyTip,
        action: Btn.text(
          text: libL10n.clear,
          onTap: () => _tag.value = TagSwitcher.kDefaultTag,
        ),
      );
    }

    return EmptyPane(
      key: const ValueKey('empty-none'),
      icon: BoxIcons.bx_server,
      title: l10n.serverTabEmpty,
      label: l10n.addServerTip,
      action: Btn.text(text: libL10n.add, onTap: _onTapAddServer),
    );
  }

  Future<void> _refreshAll() async {
    await ref.read(serversProvider.notifier).refresh();
  }

  Widget _buildEachServerCard(
    ServerState srv, {
    double openness = 0,
    Animation<double>? fade,
    ServerListDensity density = ServerListDensity.cards,
    double pageWidth = 0,
  }) {
    final card = Builder(
      // A context from inside the built tree, so the tap can ask whether a
      // detail pane is on screen, and a menu can be hung off the box this
      // built. The state's own context is an ancestor of the layout that
      // installs the scope, and the lookup only goes up.
      builder: (context) {
        return ServerCard(
          key: ValueKey(srv.spi.id),
          srv: srv,
          promoted: _promotedOf(srv.spi.id),
          onPromote: (kind) => _promote(srv.spi.id, kind),
          // While a set is being built up, a tap is what adds to it: there is
          // nothing else a tap could mean with boxes beside every name, and
          // having to hit the box itself is a 19pt target on a 40pt row.
          onTap: () => _selecting
              ? _toggleSelected(srv.spi.id)
              : _onTapCard(context, srv),
          onLongPress: () =>
              _onLongPressCard(context, srv, density: density),
          openness: openness,
          density: density,
          pageWidth: pageWidth,
          // The same answer `_onTapCard` acts on.
          opensInPlace: _opensInPlace(context),
          selected: _selecting ? _selected.contains(srv.spi.id) : null,
          // Do not show the list highlight while the card is becoming a page.
          highlighted: openness <= 0 && srv.spi.id == _menuId,
        ).onSecondary(
          (at) => _onLongPressCard(context, srv, at: at, density: density),
        );
      },
    );

    if (fade == null) return card;
    // Out of the way of the one being opened, and out of reach while it is:
    // a card that cannot be seen should not be what a tap lands on.
    //
    // The boundary is what makes the fade cheap. Without it the card is
    // rasterised into the opacity layer again on every frame; with it the
    // layer keeps the card's own picture and only its alpha changes.
    return IgnorePointer(
      child: FadeTransition(
        opacity: fade,
        child: RepaintBoundary(child: card),
      ),
    );
  }

  @override
  bool get wantKeepAlive => true;
}
