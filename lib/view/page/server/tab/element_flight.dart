import 'package:fl_lib/fl_lib.dart';
import 'package:material_ui/material_ui.dart';

/// Describes a card or detail endpoint tracked by a [StatusElementFlight].
///
/// Using a lightweight [BuildContext] registry instead of `GlobalKey` avoids
/// duplicate-key crashes whenever two copies of a card or detail page briefly
/// coexist in the tree (e.g. during [AnimatedSwitcher] grid↔globe swaps or
/// [DirectionalSwap] detail switches) and cleans up automatically on dispose.
final class FlightAnchorBinding {
  final StatusElementFlight flight;
  final String cardKey;
  final bool isDetail;

  const FlightAnchorBinding({
    required this.flight,
    required this.cardKey,
    required this.isDetail,
  });

  @override
  bool operator ==(Object other) =>
      other is FlightAnchorBinding &&
      identical(other.flight, flight) &&
      other.cardKey == cardKey &&
      other.isDetail == isDetail;

  @override
  int get hashCode => Object.hash(identityHashCode(flight), cardKey, isDetail);
}

/// Registers its [BuildContext] with [StatusElementFlight] while mounted so
/// [StatusElementFlight] can measure the child's overlay [Rect] without
/// attaching a [GlobalKey].
final class FlightAnchor extends StatefulWidget {
  final FlightAnchorBinding? binding;
  final Widget child;

  const FlightAnchor({
    super.key,
    required this.binding,
    required this.child,
  });

  @override
  State<FlightAnchor> createState() => _FlightAnchorState();
}

final class _FlightAnchorState extends State<FlightAnchor> {
  @override
  void initState() {
    super.initState();
    widget.binding?.flight._register(widget.binding!, context);
  }

  @override
  void didUpdateWidget(FlightAnchor oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.binding == widget.binding) return;
    oldWidget.binding?.flight._unregister(oldWidget.binding!, context);
    widget.binding?.flight._register(widget.binding!, context);
  }

  @override
  void dispose() {
    widget.binding?.flight._unregister(widget.binding!, context);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}

/// Shared-element in-place overlay flight controller for Status tab card types
/// that crossfade into their detail pane (e.g. Uptimer heartbeat strip, BMC
/// status/power badge) while the wide two-pane layout animates along [progress].
///
/// Both [departing] and [arriving] subtrees are built once at flight start and
/// wrapped in [RepaintBoundary] + GPU-composited [FadeTransition]; only the
/// target [Rect] interpolation runs per frame. Cleanup is bound directly to the
/// driving [TickerFuture] (`whenCompleteOrCancel`) with a monotonic generation
/// counter so it is immune to Hot Reload, cancellation, and mid-flight switches.
final class StatusElementFlight {
  StatusElementFlight({
    required Animation<double> progress,
    required VoidCallback onChanged,
  }) : _progress = progress,
       _onChanged = onChanged,
       _departOpacity = progress.drive(
         Tween(begin: 1.0, end: 0.0).chain(
           CurveTween(curve: const Interval(0.0, 0.75, curve: Curves.easeOut)),
         ),
       ),
       _arriveOpacity = progress.drive(
         Tween(begin: 0.0, end: 1.0).chain(
           CurveTween(curve: const Interval(0.15, 1.0, curve: Curves.easeIn)),
         ),
       );

  final Animation<double> _progress;
  final VoidCallback _onChanged;
  final Animation<double> _departOpacity;
  final Animation<double> _arriveOpacity;

  final _cardAnchors = <String, List<BuildContext>>{};
  final _detailAnchors = <String, List<BuildContext>>{};
  OverlayEntry? _entry;
  OverlayState? _overlay;
  String? _activeCardKey;
  int _gen = 0;
  Rect? _fromRect;
  Rect? _toRect;

  /// Anchor binding for a grid card identified by [cardKey].
  FlightAnchorBinding cardBinding(String cardKey) =>
      FlightAnchorBinding(flight: this, cardKey: cardKey, isDetail: false);

  /// Anchor binding for the detail view of [cardKey].
  FlightAnchorBinding detailBinding(String cardKey) =>
      FlightAnchorBinding(flight: this, cardKey: cardKey, isDetail: true);

  /// Whether [cardKey]'s shared element is currently flying in the overlay.
  bool isFlying(String cardKey) => _activeCardKey == cardKey;

  void _register(FlightAnchorBinding binding, BuildContext context) {
    final map = binding.isDetail ? _detailAnchors : _cardAnchors;
    map.putIfAbsent(binding.cardKey, () => []).add(context);
  }

  void _unregister(FlightAnchorBinding binding, BuildContext context) {
    final map = binding.isDetail ? _detailAnchors : _cardAnchors;
    final list = map[binding.cardKey];
    if (list == null) return;
    list.remove(context);
    if (list.isEmpty) map.remove(binding.cardKey);
  }

  Rect? _measure(OverlayState overlay, String cardKey, {required bool detail}) {
    if (!overlay.mounted) return null;
    final list = (detail ? _detailAnchors : _cardAnchors)[cardKey];
    if (list == null || list.isEmpty) return null;
    // Prefer the most recently mounted anchor when an AnimatedSwitcher or
    // DirectionalSwap briefly holds both departing and arriving copies.
    for (var i = list.length - 1; i >= 0; i--) {
      final ctx = list[i];
      if (!ctx.mounted) continue;
      final ro = ctx.findRenderObject();
      if (ro is! RenderBox || !ro.attached || !ro.hasSize) continue;
      return rectInOverlay(ctx, overlay);
    }
    return null;
  }

  /// Launches a flight for [cardKey] between its grid card slot and detail slot.
  ///
  /// Returns a flight generation token to pass to [end] (e.g. from
  /// `TickerFuture.whenCompleteOrCancel`), or null if no flight was started.
  int? start({
    required BuildContext context,
    required String cardKey,
    required bool opening,
    required Widget departing,
    required Widget arriving,
    Size? departingSize,
    Size? arrivingSize,
    BoxFit fit = BoxFit.fill,
  }) {
    // Always clear any previous active flight (including `_activeCardKey`)
    // before checking early-exit conditions so a prior card is never stuck
    // invisible if this flight skips starting.
    end();
    if (context.reduceMotion) return null;
    final overlay = Overlay.maybeOf(context, rootOverlay: true);
    if (overlay == null || !overlay.mounted) return null;

    if (opening) {
      _fromRect = _measure(overlay, cardKey, detail: false);
      _toRect = null;
      if (_fromRect == null) return null;
    } else {
      _toRect = _measure(overlay, cardKey, detail: true);
      _fromRect = _measure(overlay, cardKey, detail: false);
      if (_toRect == null) return null;
    }

    final gen = ++_gen;
    _overlay = overlay;
    _activeCardKey = cardKey;
    _onChanged();

    Widget wrapBounded(Widget child, Size? size) => size == null
        ? child
        : SizedBox.fromSize(size: size, child: child);

    // Prefer real measured endpoint sizes over fallback estimates.
    final depSize = _fromRect?.size ?? departingSize ?? _toRect?.size;
    final arrSize = _toRect?.size ?? arrivingSize ?? _fromRect?.size;

    // Build the crossfading payload ONCE; each animation tick only moves the
    // Positioned rect while Impeller composites opacity on the GPU.
    final payload = IgnorePointer(
      child: Material(
        type: MaterialType.transparency,
        child: Stack(
          fit: StackFit.expand,
          children: [
            FadeTransition(
              opacity: _departOpacity,
              child: RepaintBoundary(
                child: FittedBox(
                  fit: fit,
                  child: wrapBounded(departing, depSize),
                ),
              ),
            ),
            FadeTransition(
              opacity: _arriveOpacity,
              child: RepaintBoundary(
                child: FittedBox(
                  fit: fit,
                  child: wrapBounded(arriving, arrSize),
                ),
              ),
            ),
          ],
        ),
      ),
    );

    final entry = OverlayEntry(
      builder: (_) => AnimatedBuilder(
        animation: _progress,
        child: payload,
        builder: (_, child) {
          final activeOverlay = _overlay;
          if (gen != _gen ||
              !context.mounted ||
              activeOverlay == null ||
              !activeOverlay.mounted) {
            return const SizedBox.shrink();
          }
          final liveFrom = _measure(activeOverlay, cardKey, detail: false);
          if (liveFrom != null) _fromRect = liveFrom;
          final liveTo = _measure(activeOverlay, cardKey, detail: true);
          if (liveTo != null) _toRect = liveTo;

          final from = _fromRect;
          final to = _toRect;
          final rect = from != null && to != null
              ? Rect.lerp(from, to, _progress.value)
              : (opening ? from : to);
          if (rect == null || rect.isEmpty) return const SizedBox.shrink();
          return Positioned.fromRect(rect: rect, child: child!);
        },
      ),
    );
    overlay.insert(entry);
    _entry = entry;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (gen != _gen || !context.mounted || !identical(_entry, entry)) return;
      final activeOverlay = _overlay;
      if (activeOverlay == null || !activeOverlay.mounted) {
        end(gen);
        return;
      }
      // Once the destination subtree has laid out on frame 1, verify the
      // opposite anchor exists; if the target is not rendered (e.g. scrolled
      // off-screen, narrow rows without a strip, or compact BMC density),
      // abort the flight cleanly instead of hovering a ghost overlay in place.
      final target = opening
          ? (_toRect ?? _measure(activeOverlay, cardKey, detail: true))
          : (_fromRect ?? _measure(activeOverlay, cardKey, detail: false));
      if (target == null) {
        end(gen);
        return;
      }
      if (opening) {
        _toRect = target;
      } else {
        _fromRect = target;
      }
      entry.markNeedsBuild();
    });
    return gen;
  }

  /// Ends the active flight (or only the flight matching [gen] if provided).
  ///
  /// Pass `notify: false` from lifecycle hooks like `State.deactivate` where
  /// calling `setState` is disallowed.
  void end([int? gen, bool notify = true]) {
    if (gen != null && gen != _gen) return;
    final had = _entry != null || _activeCardKey != null;
    _removeOverlay();
    _activeCardKey = null;
    if (had && notify) _onChanged();
  }

  /// Drops the overlay silently during widget disposal.
  void dispose() {
    _removeOverlay();
    _activeCardKey = null;
    _cardAnchors.clear();
    _detailAnchors.clear();
  }

  void _removeOverlay() {
    _gen++;
    final entry = _entry;
    _entry = null;
    _overlay = null;
    _fromRect = null;
    _toRect = null;
    if (entry != null) {
      entry.remove();
      entry.dispose();
    }
  }
}
