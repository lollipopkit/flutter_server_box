import 'package:flutter/material.dart';

/// One of several things in the same place, replaced by another with a
/// direction.
///
/// A cross-fade says the thing changed. This says which way through the list
/// it went: what is leaving withdraws the way the new one came from, shrinking
/// and going faint as it goes, and what is arriving comes in from the other
/// side at the same pace. So stepping forwards and stepping back are visibly
/// different, which is the whole reason for a list having an order.
///
/// [direction] is +1 for the next one along and -1 for the previous. It is
/// read when [id] changes and held for the length of that movement, so a
/// second change partway through takes over cleanly rather than inheriting the
/// first one's direction.
class DirectionalSwap extends StatefulWidget {
  const DirectionalSwap({
    super.key,
    required this.id,
    required this.direction,
    required this.duration,
    required this.child,
  });

  /// What is on screen. A change to this is what starts the movement.
  final Object id;

  final int direction;
  final Duration duration;
  final Widget child;

  /// How far across its own width each side travels.
  ///
  /// A fraction rather than a distance, so the movement is the same gesture on
  /// a phone and on a desktop. Short: what has to read is the direction, and a
  /// page that slides its whole width is a page that is briefly not there.
  static const travel = 0.14;

  /// How much the one leaving shrinks by, and the one arriving grows from.
  static const shrink = 0.06;

  @override
  State<DirectionalSwap> createState() => _DirectionalSwapState();
}

class _DirectionalSwapState extends State<DirectionalSwap>
    with SingleTickerProviderStateMixin {
  late final _ctrl = AnimationController(vsync: this, duration: widget.duration)
    ..addStatusListener((status) {
      // What is leaving is kept only for as long as it takes to see it go.
      if (status == AnimationStatus.completed && _leaving != null) {
        setState(() => _leaving = null);
      }
    });
  late final _curve = CurvedAnimation(
    parent: _ctrl,
    curve: Curves.fastEaseInToSlowEaseOut,
  );

  Widget? _leaving;
  int _direction = 1;

  @override
  void didUpdateWidget(DirectionalSwap old) {
    super.didUpdateWidget(old);
    _ctrl.duration = widget.duration;
    if (old.id == widget.id) return;
    // The one that was here, kept as it was: it is on its way out and nothing
    // that happens to the new one is about it any more.
    _leaving = old.child;
    _direction = widget.direction == 0 ? 1 : widget.direction;
    _ctrl.forward(from: 0);
  }

  @override
  void dispose() {
    _curve.dispose();
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final leaving = _leaving;
    if (leaving == null) return widget.child;

    return AnimatedBuilder(
      animation: _curve,
      builder: (_, _) {
        final t = _curve.value;
        return Stack(
          fit: StackFit.expand,
          children: [
            // Untouchable while it goes: it is a picture of where you were.
            IgnorePointer(
              child: _side(
                leaving,
                shift: -_direction * DirectionalSwap.travel * t,
                scale: 1 - DirectionalSwap.shrink * t,
                opacity: 1 - t,
              ),
            ),
            _side(
              widget.child,
              shift: _direction * DirectionalSwap.travel * (1 - t),
              scale: 1 - DirectionalSwap.shrink * (1 - t),
              opacity: t,
            ),
          ],
        );
      },
    );
  }

  Widget _side(
    Widget child, {
    required double shift,
    required double scale,
    required double opacity,
  }) {
    return FractionalTranslation(
      translation: Offset(shift, 0),
      child: Transform.scale(
        scale: scale,
        // From the edge it is travelling towards, so the shrink reads as the
        // page receding rather than as it being squeezed in the middle.
        alignment: shift <= 0 ? Alignment.centerLeft : Alignment.centerRight,
        child: Opacity(
          opacity: opacity.clamp(0.0, 1.0),
          // Its own layer: two whole pages are being drawn for the length of
          // this, and the one that is not changing should not be repainted
          // because the other one moved.
          child: RepaintBoundary(child: child),
        ),
      ),
    );
  }
}
