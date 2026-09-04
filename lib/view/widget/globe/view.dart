import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:fl_lib/fl_lib.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:server_box/core/diag.dart';
import 'package:server_box/data/model/server/geo.dart';
import 'package:server_box/view/widget/globe/land.dart';
import 'package:server_box/view/widget/globe/layout.dart';
import 'package:server_box/view/widget/globe/painter.dart';
import 'package:server_box/view/widget/globe/projection.dart';

/// One server as the globe needs it: a place, a colour, and a card.
final class GlobeItem {
  const GlobeItem({
    required this.id,
    required this.coord,
    required this.color,
    required this.card,
  });

  final String id;
  final GeoCoord coord;

  /// The status colour, used for the dot and nothing else.
  final Color color;

  /// What floats above the globe. Built by the caller, because a server card
  /// is the caller's business — this widget knows where things are, not what
  /// they say.
  final Widget card;
}

/// The globe, with servers floating over it on leader lines.
///
/// Everything about how it is drawn is in `painter.dart`; everything about
/// where things go is in `projection.dart` and `layout.dart`, both pure. What
/// is left here is the part that has state: which way it is facing, how fast
/// it is still spinning, and which server is selected when there are too many
/// to label at once.
class GlobeView extends StatefulWidget {
  const GlobeView({
    super.key,
    required this.items,
    required this.cardSize,
    this.onTapItem,
    this.initialCoord,
    this.labelLimit = 14,
    this.unplaced = const [],
    this.unplacedLabel,
    this.unplacedAction,
  });

  final List<GlobeItem> items;

  /// Servers nothing could place, along the bottom.
  ///
  /// They have to be somewhere. A server that is simply absent from the globe
  /// reads as the globe having lost it, and the honest answer — "this one has
  /// no coordinate, and here is where to give it one" — is not something a
  /// missing dot can say.
  ///
  /// A row rather than a second globe or a dialog, because for most people it
  /// is empty and for the rest it is one or two: a machine behind NAT, or one
  /// on a range the city data has never heard of. It is the whole list, though,
  /// on an install that has not downloaded that data — nothing places anything
  /// then except a coordinate typed by hand.
  final List<Widget> unplaced;

  /// What the caption over [unplaced] says, or null for "unknown".
  ///
  /// The caller supplies it because the caller is what knows *why* — this
  /// widget is given rectangles. Null is the honest answer when the servers
  /// down there are down there for different reasons; a caption that named one
  /// of them would be wrong about the rest.
  final String? unplacedLabel;

  /// Something to do about the whole strip, on the caption's line.
  ///
  /// One thing rather than one per chip, because when it applies it applies to
  /// all of them: the case it exists for is the city data not being downloaded,
  /// which is why *every* server is down here and not why any particular one
  /// is. The chips each open a server editor; this does not belong among them.
  ///
  /// Beside the caption rather than under it, so the strip keeps the height it
  /// had — see [_buildUnplaced] for why that matters.
  final Widget? unplacedAction;

  /// How big a card is, fixed rather than measured.
  ///
  /// The layout has to know the sizes *before* the cards are built, since it
  /// decides where to build them — and measuring first would mean a layout
  /// pass per frame of a drag. Fixed also means the arrangement does not
  /// reshuffle when a reading changes from 9% to 10%.
  final Size cardSize;

  final void Function(String id)? onTapItem;

  /// Where the globe faces when it opens. Null starts on the first server, so
  /// the thing the user came to look at is the thing in the middle.
  final GeoCoord? initialCoord;

  /// Above this many servers, cards give way to dots.
  ///
  /// Not a rendering limit — the painter would happily draw two hundred. It is
  /// the point past which the de-overlap has to push cards so far from their
  /// points that the leader lines cross and the picture stops meaning
  /// anything. Past it, tapping a dot labels that one.
  final int labelLimit;

  @override
  State<GlobeView> createState() => _GlobeViewState();
}

class _GlobeViewState extends State<GlobeView> with TickerProviderStateMixin {
  /// Where the globe is facing. Only the angles: the centre and the radius
  /// come from the layout on every build.
  double _lat = 20;
  double _lon = 0;
  double _zoom = 1;

  /// How far the globe may be pushed in and out.
  ///
  /// Out stops at 1: below it the sphere is a marble in a large empty box, and
  /// there is nothing further away to see — the whole map is already on it. In
  /// stops where the sphere is about twice the short side of its box, past
  /// which the cards have nowhere left to sit around it.
  static const minZoom = 1.0;
  static const maxZoom = 3.5;

  /// How many scroll pixels double the zoom, as the exponent's divisor.
  ///
  /// Tuned against a mouse notch, which macOS reports as a `dy` of about 40:
  /// that comes to roughly 15% a notch, so half a dozen of them cross the
  /// whole range. A trackpad's stream of small deltas covers the same distance
  /// for the same physical movement, which is what the exponent buys.
  static const _kZoomPerScrollPixel = 240.0;

  /// Degrees per second, while the globe is still coasting.
  Offset _spin = Offset.zero;

  /// Which server is labelled when there are too many to label them all.
  String? _selected;

  /// Whether the globe has been pointed at something on purpose.
  ///
  /// Two things set it: finding a coordinate to open facing, and the user
  /// turning the globe. After either, where it opened is no longer a question
  /// anyone is asking — see [didUpdateWidget].
  bool _faced = false;

  Ticker? _coast;
  Duration _lastTick = Duration.zero;

  /// Turns the globe on its own while a server is hidden round the back.
  ///
  /// Half the sphere is facing away at any moment, so a server on the far side
  /// is not merely small — it is *absent*, with no dot, no card and nothing to
  /// say it exists. A globe that never moves therefore silently omits servers,
  /// and the only way to know is to guess and drag.
  ///
  /// Stopped for good by the first touch, and never resumed: a globe that
  /// starts turning again after being aimed somewhere is a globe fighting the
  /// person using it. It also stops on its own once nothing is hidden, so an
  /// install whose servers all sit on one face turns until they are all in
  /// view and then holds still.
  Ticker? _auto;
  Duration _lastAutoTick = Duration.zero;
  bool _autoAllowed = true;

  /// A revolution in half a minute, so the far side arrives within fifteen
  /// seconds and the near side is readable the whole time. Fast enough to be
  /// worth waiting for, slow enough not to read as a screensaver.
  static const _kAutoDegPerSecond = 12.0;

  late final AnimationController _entrance = AnimationController(
    vsync: this,
    duration: Durations.medium4,
  )..forward();

  ui.FragmentShader? _shader;
  GlobeLand? _land;

  /// How tall the unplaced strip is, once it has been laid out.
  ///
  /// Cards are kept out of it — see [_place]. It cannot be a constant: the
  /// strip is a caption over chips the *caller* builds, so its height is
  /// whatever those come to. Measured and fed back on the next frame, which is
  /// safe because the strip fades in with the entrance: the one frame in which
  /// a card could overlap is a frame the strip is transparent for.
  double _unplacedHeight = 0;
  final _unplacedKey = GlobalKey();

  void _scheduleUnplacedMeasure() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final box =
          _unplacedKey.currentContext?.findRenderObject() as RenderBox?;
      final height = box?.hasSize == true ? box!.size.height : 0.0;
      // Sub-pixel changes are not worth a rebuild, and comparing exactly would
      // make this loop on a fractional layout.
      if ((height - _unplacedHeight).abs() < 0.5) return;
      setState(() => _unplacedHeight = height);
    });
  }

  @override
  void initState() {
    super.initState();
    final start = widget.initialCoord ?? widget.items.firstOrNull?.coord;
    if (start != null) {
      _lat = start.lat;
      _lon = start.lon;
      _faced = true;
    }
    if (widget.unplaced.isNotEmpty) _scheduleUnplacedMeasure();
    unawaited(_loadShader());
    unawaited(_loadLand());
    _syncAutoRotation();
  }

  /// Faces the first server, once there is one to face.
  ///
  /// The coordinate arrives *after* the first build. Nothing is placed until
  /// the lookups finish, so `initState` sees an empty list, starts at a
  /// default, and the globe opens over the Atlantic however many servers are
  /// about to appear on it — which is what it did, because nothing looked
  /// again.
  ///
  /// Only until something has been faced or the user has turned it. A globe
  /// that re-aimed itself every time a lookup came back would snatch the view
  /// away mid-drag.
  @override
  void didUpdateWidget(GlobeView old) {
    super.didUpdateWidget(old);
    // Before the early return below: the servers this is given change while
    // the lookups come back, and whether any of them is hidden changes with
    // them — including from "none" to "some" long after the globe was faced.
    _syncAutoRotation();
    // Here rather than in `build`: the strip only changes when the caller
    // rebuilds, and `build` runs on every frame of a drag.
    if (old.unplaced.length != widget.unplaced.length ||
        (old.unplacedAction == null) != (widget.unplacedAction == null) ||
        old.unplacedLabel != widget.unplacedLabel) {
      _scheduleUnplacedMeasure();
    }
    if (_faced) return;
    final start = widget.initialCoord ?? widget.items.firstOrNull?.coord;
    if (start == null) return;
    setState(() {
      _faced = true;
      _lat = start.lat;
      _lon = start.lon;
    });
    _syncAutoRotation();
  }

  @override
  void dispose() {
    _coast?.dispose();
    _auto?.dispose();
    _entrance.dispose();
    // The program owns GPU memory and is not collected with the widget.
    _shader?.dispose();
    super.dispose();
  }

  Future<void> _loadShader() async {
    try {
      final program = await ui.FragmentProgram.fromAsset('shaders/globe.frag');
      if (!mounted) return;
      setState(() => _shader = program.fragmentShader());
    } catch (e, s) {
      // Not fatal and not worth a dialog: the painter draws a plain gradient
      // sphere instead. Logged because a driver that will not take this is
      // worth knowing about from a report — and reported, because the fallback
      // is silent by design, so nobody would think to send one. How many
      // devices land on it is the only thing that says whether the shader is
      // worth keeping.
      Diag.crumb(
        SbDiag.globe,
        'shader unavailable',
        level: DiagLevel.warning,
        data: {'error': Redact.error(e)},
      );
      Loggers.app.warning('Globe shader unavailable', e, s);
    }
  }

  Future<void> _loadLand() async {
    final land = await BundledLand.load();
    if (!mounted || land == null) return;
    setState(() => _land = land);
  }

  // -- gestures ------------------------------------------------------------

  double _scaleAtStart = 1;

  void _onScaleStart(ScaleStartDetails details) {
    _stopCoasting();
    // The first touch ends it, whatever the touch turns out to be — a drag, a
    // pinch, or a tap that selects a server. All three mean someone is looking
    // at something, and none of them wants the globe to keep moving.
    _stopAutoRotation();
    _reportHandled('gesture');
    _scaleAtStart = _zoom;
    // Whatever it was going to open facing, it is being aimed by hand now.
    _faced = true;
  }

  /// Whether this globe has been touched, so it is said once rather than per
  /// gesture — a drag is a stream of them.
  bool _handled = false;

  /// That someone moved the globe by hand, and with what.
  ///
  /// The globe turns on its own precisely because half of it is facing away,
  /// and whether that is enough is whether people still reach for it. [how]
  /// separates the gesture path from the pointer-signal one, which are
  /// different code reached by different hardware — a wheel is not routed
  /// through the gesture arena at all, and for a while nothing handled it, so
  /// the globe did nothing on a desktop with a mouse.
  void _reportHandled(String how) {
    if (_handled) return;
    _handled = true;
    Diag.crumb(SbDiag.globe, 'turned', data: {'how': how});
  }

  void _onScaleUpdate(ScaleUpdateDetails details, double radius) {
    setState(() {
      if (details.scale != 1) {
        _zoom = (_scaleAtStart * details.scale).clamp(minZoom, maxZoom);
      }
      final moved = _cameraFor(radius, Offset.zero).drag(details.focalPointDelta);
      _lat = moved.lat;
      _lon = moved.lon;
    });
  }

  /// Multiplies the zoom, which is the only way to change it that behaves.
  ///
  /// Zoom is a *ratio*, so a step has to be one too: adding a constant would
  /// move 1.0 → 1.2 by a fifth and 3.0 → 3.2 by a fifteenth, and a wheel notch
  /// would do visibly less the further in it got.
  void _zoomBy(double factor) {
    final next = (_zoom * factor).clamp(minZoom, maxZoom);
    if (next == _zoom) return;
    setState(() => _zoom = next);
  }

  /// A wheel, or a trackpad pinch that arrives as a signal rather than as a
  /// gesture.
  ///
  /// **The whole reason this exists**: `onScaleUpdate` never sees a mouse.
  /// `ScaleGestureRecognizer` is fed by pointers and trackpad pan-zoom events,
  /// and a wheel is neither — it is a `PointerSignalEvent`, which no gesture
  /// recognizer competes for. So the globe zoomed on a phone and on a
  /// trackpad, and did nothing at all on a desktop with a mouse.
  ///
  /// Not zoomed toward the cursor: the projection puts the sphere at the
  /// middle of the box and has nowhere to put it instead, so zooming anywhere
  /// but the centre would need a camera offset that does not exist. Zooming
  /// about the middle is the honest version of what this can do.
  void _onPointerSignal(PointerSignalEvent event) {
    switch (event) {
      case final PointerScrollEvent e:
        // Up is in, which is the direction every map and every document
        // agrees on. `exp` rather than a fixed step per notch so a trackpad's
        // stream of small deltas and a mouse's few large ones cover the same
        // distance for the same physical movement.
        if (e.scrollDelta.dy == 0) return;
        _reportHandled('scroll');
        _zoomBy(math.exp(-e.scrollDelta.dy / _kZoomPerScrollPixel));
      case final PointerScaleEvent e:
        // A trackpad pinch on a platform that reports it as a signal instead
        // of as pan-zoom events. Where both arrive, the gesture wins and this
        // is never called.
        if (e.scale <= 0) return;
        _reportHandled('pinch');
        _zoomBy(e.scale);
      default:
        return;
    }
  }

  void _onScaleEnd(ScaleEndDetails details, double radius) {
    final velocity = details.velocity.pixelsPerSecond;
    // Below this the globe is being let go rather than thrown, and coasting
    // from it reads as the globe drifting on its own.
    if (velocity.distance < 60 || radius <= 0) return;
    const perRadian = 180 / math.pi;
    _spin = Offset(
      -velocity.dx / radius * perRadian,
      velocity.dy / radius * perRadian,
    );
    _startCoasting();
  }

  void _startCoasting() {
    _coast?.dispose();
    _lastTick = Duration.zero;
    _coast = createTicker(_onCoastTick)..start();
  }

  void _stopCoasting() {
    _coast?.dispose();
    _coast = null;
    _spin = Offset.zero;
  }

  /// Friction, integrated properly rather than multiplied once per frame.
  ///
  /// `v *= 0.92` per frame ties how far the globe coasts to the refresh rate:
  /// the same flick travels twice as far at 120 Hz as at 60. Raising the decay
  /// to the power of the elapsed time is the same curve at any frame rate.
  void _onCoastTick(Duration elapsed) {
    final dt = _lastTick == Duration.zero
        ? 1 / 60
        : (elapsed - _lastTick).inMicroseconds / 1e6;
    _lastTick = elapsed;
    if (dt <= 0) return;

    const decayPerSecond = 0.06;
    setState(() {
      _lon = _wrapLon(_lon + _spin.dx * dt);
      _lat = (_lat + _spin.dy * dt).clamp(-90.0, 90.0);
      _spin = _spin * math.pow(decayPerSecond, dt).toDouble();
    });

    // A degree a second is slower than anyone can see, and a ticker that never
    // stops holds a frame callback and the screen awake for the life of the
    // page.
    if (_spin.distance < 1) _stopCoasting();
  }

  /// Whether any server is on the half of the sphere facing away.
  ///
  /// Radius-free: [GlobePoint.depth] comes out of the rotation applied to a
  /// unit vector, and the radius only scales where the point lands on screen.
  /// So this can be asked outside `build`, where the real camera is, which is
  /// what lets the ticker decide whether to keep running.
  bool get _anyHidden {
    if (widget.items.isEmpty) return false;
    final projection = GlobeProjection(_cameraFor(1, Offset.zero));
    for (final item in widget.items) {
      if (!projection.project(item.coord).visible) return true;
    }
    return false;
  }

  /// Starts or stops the idle rotation to match what is on screen.
  ///
  /// Called from the places the answer can change — the first build, a new
  /// list of servers, and each tick — rather than from `build`, which must not
  /// start tickers and would ask on every frame of an unrelated animation.
  void _syncAutoRotation() {
    final want = _autoAllowed && _coast == null && _anyHidden;
    if (want == (_auto != null)) return;
    if (want) {
      _lastAutoTick = Duration.zero;
      _auto = createTicker(_onAutoTick)..start();
    } else {
      _auto?.dispose();
      _auto = null;
    }
  }

  /// Refuses to turn the globe again for the life of this widget.
  void _stopAutoRotation() {
    _autoAllowed = false;
    _auto?.dispose();
    _auto = null;
  }

  void _onAutoTick(Duration elapsed) {
    final dt = _lastAutoTick == Duration.zero
        ? 1 / 60
        : (elapsed - _lastAutoTick).inMicroseconds / 1e6;
    _lastAutoTick = elapsed;
    if (dt <= 0) return;

    // Longitude only. Drifting in latitude as well would wander towards a pole
    // and spend the trip showing ice.
    setState(() => _lon = _wrapLon(_lon + _kAutoDegPerSecond * dt));
    _syncAutoRotation();
  }

  static double _wrapLon(double lon) {
    var wrapped = (lon + 180) % 360;
    if (wrapped < 0) wrapped += 360;
    return wrapped - 180;
  }

  void _onTapUp(TapUpDetails details, double radius, Offset center) {
    // Here as well as in `_onScaleStart`, because a tap that never moves does
    // not start a scale gesture at all — the tap recognizer takes the arena.
    // Without this the globe kept turning the tapped server out of view,
    // which is the app taking back what the tap had just done.
    _stopAutoRotation();
    final projection = GlobeProjection(_cameraFor(radius, center));
    String? hit;
    var best = double.infinity;
    for (final item in widget.items) {
      final point = projection.project(item.coord);
      if (!point.visible) continue;
      final distance = (point.offset - details.localPosition).distance;
      // A dot is 3 px; the target around it is a finger.
      if (distance > 24 || distance >= best) continue;
      best = distance;
      hit = item.id;
    }
    if (hit == null) {
      if (_selected != null) setState(() => _selected = null);
      return;
    }
    if (_labelsEverything) {
      widget.onTapItem?.call(hit);
    } else {
      // With too many to label, the first tap names one and a second opens it.
      setState(() => _selected = _selected == hit ? null : hit);
      if (_selected == null) widget.onTapItem?.call(hit);
    }
  }

  bool get _labelsEverything => widget.items.length <= widget.labelLimit;

  // -- build ---------------------------------------------------------------

  GlobeCamera _cameraFor(double radius, Offset center) =>
      GlobeCamera(lat: _lat, lon: _lon, center: center, radius: radius);

  @override
  Widget build(BuildContext context) {
    final palette = GlobePalette.of(context);
    return LayoutBuilder(
      builder: (context, constraints) {
        final size = Size(constraints.maxWidth, constraints.maxHeight);
        final center = Offset(size.width / 2, size.height / 2);
        // A disc that leaves room around it for the cards, which sit outside
        // the globe rather than on its face.
        final radius = size.shortestSide / 2 * 0.62 * _zoom;
        final camera = _cameraFor(radius, center);
        final projection = GlobeProjection(camera);

        final labelled = _labelledItems();
        final placements = _place(labelled, projection, size, center);
        final byId = {for (final item in widget.items) item.id: item};

        return AnimatedBuilder(
          animation: _entrance,
          builder: (context, _) {
            final t = Curves.easeOutCubic.transform(_entrance.value);
            return Listener(
              // Outside the `GestureDetector` rather than inside: a signal is
              // not routed through the gesture arena at all, so there is no
              // competition to lose and nothing to disambiguate.
              onPointerSignal: _onPointerSignal,
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onScaleStart: _onScaleStart,
                onScaleUpdate: (d) => _onScaleUpdate(d, radius),
                onScaleEnd: (d) => _onScaleEnd(d, radius),
                onTapUp: (d) => _onTapUp(d, radius, center),
                child: Stack(
                clipBehavior: Clip.none,
                children: [
                  Positioned.fill(
                    // Clipped, and only this layer is. The `Stack` above is
                    // `Clip.none` so a card near the rim is not cut off — but
                    // the sphere is wider than the box past about 1.6x zoom,
                    // and unclipped it paints over whatever is beside the
                    // globe: the actions row above it, the pane next to it.
                    child: ClipRect(
                      // Scaled about the middle, so the globe opens out of the
                      // page rather than sliding in from an edge.
                      child: Transform.scale(
                        scale: 0.86 + 0.14 * t,
                        child: CustomPaint(
                        painter: GlobePainter(
                          projection: projection,
                          land: _land,
                          markers: [
                            for (final item in widget.items)
                              (
                                id: item.id,
                                coord: item.coord,
                                color: item.color,
                              ),
                          ],
                          leaders: [
                            for (final p in placements)
                              (
                                card: p.rect,
                                anchor: p.anchor,
                                fade: horizonFadeAt(p.depth),
                              ),
                          ],
                          palette: palette,
                          shader: _shader,
                          opacity: t,
                          ),
                        ),
                      ),
                    ),
                  ),
                  for (final placement in placements)
                    Positioned(
                      // Keyed, and it is not decoration: the placements are
                      // sorted front to back, so two servers swapping depth
                      // mid-rotation swaps their position in this list. With
                      // no key Flutter matches children by index and hands one
                      // card's element the other card's widget — ink splashes
                      // and any per-card state jump between cards as the globe
                      // turns.
                      key: ValueKey(placement.id),
                      left: placement.rect.left,
                      top: placement.rect.top,
                      width: placement.rect.width,
                      height: placement.rect.height,
                      child: Opacity(
                        // The entrance and the horizon, multiplied: a card
                        // near the limb during the opening animation is dim
                        // for both reasons and should not be full strength
                        // for either.
                        opacity: t * horizonFadeAt(placement.depth),
                        // By map rather than `firstWhere`, which is a linear
                        // scan per card inside a build that runs every frame.
                        child: byId[placement.id]?.card ?? const SizedBox(),
                      ),
                    ),
                  if (widget.unplaced.isNotEmpty)
                    Positioned(
                      left: 0,
                      right: 0,
                      bottom: 0,
                      child: Opacity(
                        opacity: t,
                        child: KeyedSubtree(
                          key: _unplacedKey,
                          child: _buildUnplaced(),
                        ),
                      ),
                      ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  /// The strip along the bottom for servers with nowhere to be drawn.
  ///
  /// Scrolls horizontally rather than wrapping, so however many there are the
  /// globe keeps the height it had — a strip that grew upward would change the
  /// radius, which would move every card.
  Widget _buildUnplaced() {
    final scheme = Theme.of(context).colorScheme;
    return DecoratedBox(
      decoration: BoxDecoration(
        // Fades in rather than sitting on a hard edge, so it reads as being
        // below the globe rather than as a panel over it.
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            scheme.surface.withValues(alpha: 0),
            scheme.surface.withValues(alpha: 0.9),
          ],
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 20, 12, 12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.only(left: 4, bottom: 6),
              child: Row(
                children: [
                  Flexible(
                    child: Text(
                      widget.unplacedLabel ?? libL10n.unknown,
                      style: TextStyle(fontSize: 11, color: scheme.outline),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  ?widget.unplacedAction,
                ],
              ),
            ),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                spacing: 8,
                children: widget.unplaced,
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Which servers get a card rather than only a dot.
  ///
  /// Everything, until there are more than [GlobeView.labelLimit] of them —
  /// past which it is whichever one was tapped, and nothing if none was.
  List<GlobeItem> _labelledItems() {
    if (_labelsEverything) return widget.items;
    final selected = _selected;
    if (selected == null) return const [];
    return widget.items.where((item) => item.id == selected).toList();
  }

  List<GlobePlacement> _place(
    List<GlobeItem> items,
    GlobeProjection projection,
    Size size,
    Offset center,
  ) {
    final anchors = <GlobeAnchor>[];
    for (final item in items) {
      final point = projection.project(item.coord);
      // A card for a server on the far side would sit on the globe pointing at
      // nothing. It comes back when the server rotates into view.
      if (!point.visible) continue;
      anchors.add((
        id: item.id,
        at: point.offset,
        depth: point.depth,
        size: widget.cardSize,
      ));
    }
    if (anchors.isEmpty) return const [];
    // Short of the unplaced strip, which is painted over this — it is the last
    // child of the `Stack` and `Positioned` against the bottom. A card laid out
    // under it was drawn beneath its gradient and its chips: unreadable,
    // untappable, and with its leader line running into the strip and stopping.
    //
    // Only the *cards* are kept out. The dots stay where the projection puts
    // them, because a dot is on the globe rather than beside it, and moving one
    // would be drawing the server somewhere it is not.
    final free = math.max(size.height - _unplacedHeight, widget.cardSize.height);
    return layoutGlobeCards(
      anchors: anchors,
      bounds: Rect.fromLTWH(0, 0, size.width, free),
      globeCenter: center,
    );
  }
}
