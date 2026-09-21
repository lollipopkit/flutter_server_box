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
import 'package:server_box/data/res/store.dart';
import 'package:server_box/view/page/server/card/actions.dart';
import 'package:server_box/view/page/server/card/card.dart';
import 'package:server_box/view/page/server/card/density.dart';
import 'package:server_box/view/page/server/card/metric.dart';
import 'package:server_box/view/page/server/card/sizes.dart';
import 'package:server_box/view/page/server/card/swap.dart';
import 'package:server_box/view/page/server/card/switcher.dart';
import 'package:server_box/view/page/server/detail/view.dart';
import 'package:server_box/view/page/server/edit/edit.dart';
import 'package:server_box/view/page/server/tab/empty.dart';
import 'package:server_box/view/page/server/tab/func_bar.dart';
import 'package:server_box/view/page/server/tab/group_heading.dart';
import 'package:server_box/view/page/server/tab/selection_bar.dart';
import 'package:server_box/view/page/server/tab/strip.dart';
import 'package:server_box/view/page/server/text_scale.dart';
import 'package:server_box/view/page/setting/entry.dart';
import 'package:server_box/view/widget/server_globe.dart';
import 'package:server_box/view/widget/server_share.dart';

part 'bar.dart';
part 'bulk.dart';
part 'detail_host.dart';
part 'grid.dart';
part 'landscape.dart';
part 'sheets.dart';
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

  /// What [ServerListDensity.auto] last came to in the grid, for the bar over
  /// it to say.
  ///
  /// Null until a grid has been laid out. See [_publishAuto].
  final _autoDensity = ValueNotifier<ServerListDensity?>(null);

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
  void _uiFoldListener() => _sortVersion.notify();

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
    Stores.setting.collapseUIDefault.listenable().addListener(_uiFoldListener);
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
      // page the size it was.
      body: ServerTextScale(
        // The bar above spends the top inset, as an app bar does; this is
        // what is left, and what it still has to clear is the home indicator
        // — especially with [bare] on, since the navigation that used to sit
        // between the two is gone.
        child: SafeArea(top: false, child: child),
      ),
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
    // Every field but the two that read nothing about a machine needs its
    // state, so the whole thing is read for those: `select` cannot narrow "a
    // reading changed".
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
        _ when filtered.isEmpty => ServerListEmpty(
          query: _search.needle,
          tag: _tag.value,
          onClearSearch: _search.end,
          onClearTag: () => _tag.value = TagSwitcher.kDefaultTag,
          onAdd: _onTapAddServer,
        ),
        _ => KeyedSubtree(
          key: const ValueKey('grid'),
          child: _buildGrid(filtered, openId),
        ),
      },
    );
  }

  @override
  bool get wantKeepAlive => true;
}
