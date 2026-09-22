import 'dart:math' as math;
import 'dart:ui' show lerpDouble;

import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';

/// Two shapes of one thing crossed over each other, at a height between them.
///
/// For a pair that cannot be a lerp of one layout: a line in a list and the
/// card it opens into share a server and nothing else. Swapped between two
/// frames, the height changes by a few hundred points on one of them and
/// everything laid out against it moves on that frame too. Here [from] fades
/// out over [to] fading in, and the box goes from [fromHeight] to whatever
/// height [to] lays out at — so a caller driving [t] from its own animation
/// gets the change of shape as part of that movement.
///
/// [t] 0 is [from] alone at [fromHeight]; 1 is [to] alone at its own height.
/// [from] may be null once [t] is 1, to save building it.
class ShapeCross extends StatelessWidget {
  const ShapeCross({
    super.key,
    required this.t,
    required this.fromHeight,
    required this.from,
    required this.to,
    this.minToWidth = 0,
  });

  final double t;
  final double fromHeight;
  final Widget? from;
  final Widget to;

  /// The least width [to] is laid out at, whatever this box is given.
  ///
  /// A tile is narrower than anything a card's layout was written for, and the
  /// card is laid out at the tile's width on the first frames of the cross. It
  /// is laid out at this instead and clipped to the box: what is cut off is
  /// the right-hand side of something still mostly transparent.
  final double minToWidth;

  @override
  Widget build(BuildContext context) {
    final t = this.t.clamp(0.0, 1.0);
    final from = this.from;
    return Stack(
      children: [
        // The clip is here rather than the stack's: a stack clips what its
        // positioned children overflow by, and this is a child painting
        // outside a box that is itself inside the stack.
        ClipRect(
          child: _HeightBetween(
            from: fromHeight,
            t: t,
            minChildWidth: minToWidth,
            child: Opacity(opacity: t, child: to),
          ),
        ),
        if (from != null && t < 1)
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            height: fromHeight,
            // On its way out, so it answers to nothing.
            child: IgnorePointer(
              child: Opacity(opacity: 1 - t, child: from),
            ),
          ),
      ],
    );
  }
}

/// Lays its child out in full and takes a height between [from] and the
/// child's. Does not clip: the child is painted at its own size.
class _HeightBetween extends SingleChildRenderObjectWidget {
  const _HeightBetween({
    required this.from,
    required this.t,
    required this.minChildWidth,
    required super.child,
  });

  final double from;
  final double t;
  final double minChildWidth;

  @override
  RenderObject createRenderObject(BuildContext context) =>
      _RenderHeightBetween(from: from, t: t, minChildWidth: minChildWidth);

  @override
  void updateRenderObject(
    BuildContext context,
    _RenderHeightBetween renderObject,
  ) {
    renderObject
      ..from = from
      ..t = t
      ..minChildWidth = minChildWidth;
  }
}

class _RenderHeightBetween extends RenderProxyBox {
  _RenderHeightBetween({
    required double from,
    required double t,
    required double minChildWidth,
  }) : _from = from,
       _t = t,
       _minChildWidth = minChildWidth;

  double _from;
  set from(double v) {
    if (_from == v) return;
    _from = v;
    markNeedsLayout();
  }

  double _t;
  set t(double v) {
    if (_t == v) return;
    _t = v;
    markNeedsLayout();
  }

  double _minChildWidth;
  set minChildWidth(double v) {
    if (_minChildWidth == v) return;
    _minChildWidth = v;
    markNeedsLayout();
  }

  /// The child's constraints: this box's width, or [_minChildWidth] if that
  /// is more, and as tall as it likes.
  BoxConstraints _childConstraints(BoxConstraints constraints) {
    final width = math.max(constraints.maxWidth, _minChildWidth);
    return BoxConstraints(
      minWidth: math.max(constraints.minWidth, math.min(width, _minChildWidth)),
      maxWidth: width,
    );
  }

  Size _sizeFor(BoxConstraints constraints, Size child) => constraints.constrain(
    Size(
      math.min(child.width, constraints.maxWidth),
      lerpDouble(_from, child.height, _t)!,
    ),
  );

  @override
  void performLayout() {
    final child = this.child;
    if (child == null) {
      size = constraints.constrain(Size(0, _from));
      return;
    }
    child.layout(_childConstraints(constraints), parentUsesSize: true);
    size = _sizeFor(constraints, child.size);
  }

  @override
  Size computeDryLayout(BoxConstraints constraints) {
    final child = this.child;
    if (child == null) return constraints.constrain(Size(0, _from));
    return _sizeFor(
      constraints,
      child.getDryLayout(_childConstraints(constraints)),
    );
  }

  @override
  double computeMinIntrinsicHeight(double width) => lerpDouble(
    _from,
    super.computeMinIntrinsicHeight(math.max(width, _minChildWidth)),
    _t,
  )!;

  @override
  double computeMaxIntrinsicHeight(double width) => lerpDouble(
    _from,
    super.computeMaxIntrinsicHeight(math.max(width, _minChildWidth)),
    _t,
  )!;
}
