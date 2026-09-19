// ignore_for_file: invalid_use_of_protected_member

import 'dart:async';
import 'dart:math' as math;

import 'package:fl_lib/fl_lib.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:icons_plus/icons_plus.dart';
import 'package:server_box/core/diag.dart';
import 'package:server_box/core/extension/context/locale.dart';
import 'package:server_box/core/extension/context/motion.dart';
import 'package:server_box/core/extension/server.dart';
import 'package:server_box/core/route.dart';
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

/// The row of machines that appears above an open one.
const _kSwitcherHeight = 34.0;

/// How long the detail's own chrome takes to arrive or go.
///
/// Shorter than the card's movement and out of phase with it — see
/// [_ServerPageState._detailShowing].
const _kChromeDuration = Durations.short4;

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
    curve: Curves.fastEaseInToSlowEaseOut,
    reverseCurve: Curves.fastEaseInToSlowEaseOut,
  );

  /// Which way through the list the last change of machine went: +1 for the
  /// next one along, -1 for the one before.
  ///
  /// What the detail's own switch is drawn with — see [DirectionalSwap]. A
  /// pick from the sheet, where there is no "next", counts as forwards.
  int _swapDirection = 1;

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
    final needsState = ServerSortOrder.stored.field.readsStatus;
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
          final ordered = ServerSortOrder.stored.apply(
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
      icon: Icon(ServerSortOrder.stored.icon, size: 18),
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

  /// How to order the list. The default is the arrangement from the settings,
  /// so this starts as a view of what the user already decided rather than as
  /// a decision it takes from them.
  Future<void> _showSortSheet() async {
    await showRowsSheet<void>(
      context,
      rows: (ctx) => [
        for (final order in ServerSortOrder.all)
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

  /// The list, and the one card of it that has grown into the page.
  ///
  /// One widget for both, because they are one thing: opening a server does
  /// not replace the list with a page, it takes a card out of the grid and
  /// gives it the width. What is below the card once it has the width — the
  /// readings in full, the facts, the row of things to do — arrives after the
  /// movement has finished, so that only one thing is ever moving.
  Widget _buildGrid(List<String> filtered, String? openId) {
    final open = openId != null && filtered.contains(openId);
    // What the list draws each machine as. Not while one is open: the page has
    // one shape, and the row or tile that was tapped is on its way to it.
    final density = ServerDensityPref.of(_tag.value).resolve(
      count: filtered.length,
      textScale: Stores.setting.textFactor.fetch(),
    );

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
    // Rebuilt on every frame of the opening, which is one card's worth of work
    // while it is open: what the card looks like at each point between is a
    // lerp inside it, so it has to be rebuilt to change. The grid's own
    // geometry is not — the render object is told the width directly.
    final grid = LayoutBuilder(
      builder: (_, cons) => AnimatedBuilder(
        animation: _open,
        builder: (_, _) => AnimatedMasonry(
          controller: _scrollController,
          // The grid's own inset at rest, and the page's once one card is the
          // page — so what the card holds lines up with what the page holds
          // and nothing shifts when the page takes over.
          padding: EdgeInsets.lerp(
            MasonryList.kPadding,
            const EdgeInsets.fromLTRB(13, 7, 13, 13),
            _open.value,
          )!,
          // The cards make way at the same pace as the one growing, so the whole
          // thing reads as one movement rather than as a card growing into a
          // grid that is still settling.
          moveDuration: context.motion(_kOpenDuration),
          changeDuration: context.motion(Durations.medium2),
          // The column each shape wants: a line per machine takes the width, a
          // tile takes as little as a name needs, and a card takes the one width
          // the rest of the app lays a column out at.
          columnWidth: switch (density) {
            ServerListDensity.grid => 170.0,
            ServerListDensity.rows => double.infinity,
            _ => UIs.columnWidth,
          },
          // And how much air each shape wants around it: a wall of tiles reads
          // as a wall at the design's 5, and a list of lines as a list at
          // nothing at all.
          spacing: switch (density) {
            ServerListDensity.grid => 5.0,
            ServerListDensity.rows => 0.0,
            _ => MasonryList.kSpacing,
          },
          expandedKey: open ? ValueKey(openId) : null,
          expansion: _open.value,
          // Under the cards, and only while they are the page: with one of them
          // open the totals would be a summary of a list that is not on screen.
          footer: open ? null : ServerOverview(ids: filtered),
          children: [
            // While one is open it is the only one built: the rest are leaving,
            // which is what the grid already knows how to draw.
            for (final id in open ? [openId] : filtered)
              // Its own `Consumer`, so a status poll rebuilds the one card whose
              // server answered rather than the grid. Watched from this page's
              // `ref` — which is what a builder would have to do — any server's
              // reading landing rebuilt every card on screen.
              Consumer(
                key: ValueKey(id),
                builder: (_, ref, _) => _buildEachServerCard(
                  ref.watch(serverProvider(id)),
                  openness: id == openId ? _open.value : 0,
                  density: density,
                  // What the card will be laid out at once it has the page,
                  // less what the page keeps clear at its edges. Decided from
                  // the grid's own box rather than from the card's, which is
                  // whatever the movement is at.
                  openWidth: cons.maxWidth - 26,
                ),
              ),
          ],
        ),
      ),
    );

    // The readings in full, once the card has stopped growing. Crossed with
    // the card rather than replacing it: by then the two are the same shape —
    // one reading drawn large over the rest as rows — so what the crossing
    // has to carry is the difference between them and not a whole page.
    //
    // The strip of other machines is above both and belongs to neither: it is
    // what the list becomes while one of its cards is open, so it stays
    // whichever of the two is on screen.
    final body = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _buildSwitcher(filtered, openId),
        Expanded(
          child: AnimatedSwitcher(
            // Both halves laid out in the same box. The default stack
            // shrink-wraps and centres, which left the grid's own scrollable
            // as tall as its contents in the middle of the window.
            layoutBuilder: _viewSwapLayout,
            duration: context.motion(_kChromeDuration),
            child: open && _detailShowing
                ? _buildOpenDetail(openId)
                : KeyedSubtree(key: const ValueKey('cards'), child: grid),
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
      child: DirectionalSwap(
        id: id,
        direction: _swapDirection,
        duration: context.motion(_kOpenDuration),
        child: _detailFor(id, spi),
      ),
    );
  }

  Widget _detailFor(String id, Spi spi) {
    return KeyedSubtree(
      key: ValueKey('detail:$id'),
      // Opaque, because it is crossed with the grid underneath it rather than
      // put in its place: a translucent page would show two layouts at once
      // for the length of the fade.
      child: Material(
        type: MaterialType.canvas,
        color: Theme.of(context).scaffoldBackgroundColor,
        child: ServerDetailPage(args: SpiRequiredArgs(spi), bare: true),
      ),
    );
  }

  /// Which machine is on screen, and the rest of them.
  ///
  /// Only while one is open, and above the card rather than in the bar: it is
  /// a row of the list that has made way, so it belongs where the list was.
  /// Closed it has no height at all — the list itself is the switcher then.
  Widget _buildSwitcher(List<String> filtered, String? openId) {
    final at = openId == null ? -1 : filtered.indexOf(openId);

    return AnimatedBuilder(
      animation: _open,
      builder: (_, _) {
        final t = _open.value;
        if (t <= 0) return const SizedBox(width: double.infinity);
        return ClipRect(
          child: Align(
            alignment: Alignment.topLeft,
            heightFactor: t,
            child: Opacity(
              opacity: t,
              child: SizedBox(
                height: _kSwitcherHeight,
                child: EdgeFadeScroll(
                  builder: (_, controller) => ListView(
                    controller: controller,
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(horizontal: 5),
                    children: [
                      for (final (i, id) in filtered.indexed)
                        _buildSwitcherPill(id, current: i == at),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildSwitcherPill(String id, {required bool current}) {
    final scheme = Theme.of(context).colorScheme;
    return Consumer(
      builder: (_, ref, _) {
        final srv = ref.watch(serverProvider(id));
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 3, horizontal: 2),
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
                        color: _dotOf(srv),
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
        );
      },
    );
  }

  /// What a server's state looks like at seven pixels across.
  Color _dotOf(ServerState srv) => switch (srv.conn) {
    ServerConn.finished =>
      serverCardReadings(srv).all.any((m) => m.over)
          ? StatePalette.warn
          : StatePalette.running,
    ServerConn.failed => StatePalette.failed,
    _ => StatePalette.idle,
  };

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
    ServerListDensity density = ServerListDensity.cards,
    double openWidth = 0,
  }) {
    final card = Builder(
      // A context from inside the built tree, so the tap can ask whether a
      // detail pane is on screen. The state's own context is an ancestor of
      // the layout that installs the scope, and the lookup only goes up.
      builder: (context) => ServerCard(
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
        onLongPress: () => _onLongPressCard(srv),
        openness: openness,
        density: density,
        openWidth: openWidth,
        selected: _selecting ? _selected.contains(srv.spi.id) : null,
      ).onSecondary((at) => _onLongPressCard(srv, at)),
    );

    return card;
  }

  @override
  bool get wantKeepAlive => true;
}
