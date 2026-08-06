import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';

import '../utils/render_box_layout.dart';
import '../utils/render_box_offset.dart';

class ResetDimension extends SingleChildRenderObjectWidget {
  final double? height;
  final double? depth;
  final double? width;
  final CrossAxisAlignment horizontalAlignment;

  const ResetDimension({
    Key? key,
    this.height,
    this.depth,
    this.width,
    this.horizontalAlignment = CrossAxisAlignment.center,
    required Widget child,
  }) : super(key: key, child: child);

  @override
  RenderResetDimension createRenderObject(BuildContext context) =>
      RenderResetDimension(
        layoutHeight: height,
        layoutWidth: width,
        layoutDepth: depth,
        horizontalAlignment: horizontalAlignment,
      );

  @override
  void updateRenderObject(
          BuildContext context, RenderResetDimension renderObject) =>
      renderObject
        ..layoutHeight = height
        ..layoutDepth = depth
        ..layoutWidth = width
        ..horizontalAlignment = horizontalAlignment;
}

class RenderResetDimension extends RenderShiftedBox {
  RenderResetDimension({
    RenderBox? child,
    double? layoutHeight,
    double? layoutDepth,
    double? layoutWidth,
    CrossAxisAlignment horizontalAlignment = CrossAxisAlignment.center,
  })  : _layoutHeight = layoutHeight,
        _layoutDepth = layoutDepth,
        _layoutWidth = layoutWidth,
        _horizontalAlignment = horizontalAlignment,
        super(child);

  double? get layoutHeight => _layoutHeight;
  double? _layoutHeight;
  set layoutHeight(double? value) {
    if (_layoutHeight != value) {
      _layoutHeight = value;
      markNeedsLayout();
    }
  }

  double? get layoutDepth => _layoutDepth;
  double? _layoutDepth;
  set layoutDepth(double? value) {
    if (_layoutDepth != value) {
      _layoutDepth = value;
      markNeedsLayout();
    }
  }

  double? get layoutWidth => _layoutWidth;
  double? _layoutWidth;
  set layoutWidth(double? value) {
    if (_layoutWidth != value) {
      _layoutWidth = value;
      markNeedsLayout();
    }
  }

  CrossAxisAlignment get horizontalAlignment => _horizontalAlignment;
  CrossAxisAlignment _horizontalAlignment;
  set horizontalAlignment(CrossAxisAlignment value) {
    if (_horizontalAlignment != value) {
      _horizontalAlignment = value;
      markNeedsLayout();
    }
  }

  @override
  double computeMinIntrinsicWidth(double height) =>
      layoutWidth ?? super.computeMinIntrinsicWidth(height);

  @override
  double computeMaxIntrinsicWidth(double height) =>
      layoutWidth ?? super.computeMaxIntrinsicWidth(height);

  @override
  double computeMinIntrinsicHeight(double width) {
    if (layoutHeight == null && layoutDepth == null) {
      return super.computeMinIntrinsicHeight(width);
    }
    if (layoutHeight != null && layoutDepth != null) {
      return layoutHeight! + layoutDepth!;
    }
    return 0;
  }

  @override
  double computeMaxIntrinsicHeight(double width) {
    if (layoutHeight == null && layoutDepth == null) {
      return super.computeMaxIntrinsicHeight(width);
    }
    if (layoutHeight != null && layoutDepth != null) {
      return layoutHeight! + layoutDepth!;
    }
    return 0;
  }

  @override
  double? computeDistanceToActualBaseline(TextBaseline baseline) =>
      layoutHeight ?? super.computeDistanceToActualBaseline(baseline);

  @override
  Size computeDryLayout(BoxConstraints constraints) =>
      _computeLayout(constraints);

  @override
  void performLayout() {
    size = _computeLayout(constraints, dry: false);
  }

  Size _computeLayout(
    BoxConstraints constraints, {
    bool dry = true,
  }) {
    final child = this.child!;
    final childSize = child.getLayoutSize(constraints, dry: dry);

    final childHeight =
        dry ? 0.0 : child.getDistanceToBaseline(TextBaseline.alphabetic)!;
    final childDepth = childSize.height - childHeight;
    final childWidth = childSize.width;

    final height = layoutHeight ?? childHeight;
    final depth = layoutDepth ?? childDepth;
    final width = layoutWidth ?? childWidth;

    var dx = 0.0;
    switch (horizontalAlignment) {
      case CrossAxisAlignment.start:
      case CrossAxisAlignment.stretch:
      case CrossAxisAlignment.baseline:
        break;
      case CrossAxisAlignment.end:
        dx = width - childWidth;
        break;
      case CrossAxisAlignment.center:
      default:
        dx = (width - childWidth) / 2;
        break;
    }

    if (!dry) {
      child.offset = Offset(dx, height - childHeight);
    }

    return Size(width, height + depth);
  }
}
