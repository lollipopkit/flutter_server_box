//ignore_for_file: lines_longer_than_80_chars
import 'dart:math' as math;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';

import '../utils/render_box_layout.dart';

class VListParentData extends ContainerBoxParentData<RenderBox> {
  BoxConstraints Function(double width)? customCrossSize;

  double trailingMargin = 0.0;

  double hShift = 0.0;

  @override
  String toString() =>
      '${super.toString()}; customCrossSize=${customCrossSize != null}; trailingMargin=$trailingMargin; horizontalShift=$hShift';
}

class VListElement extends ParentDataWidget<VListParentData> {
  final BoxConstraints Function(double width)? customCrossSize;

  final double trailingMargin;

  final double hShift;

  const VListElement({
    Key? key,
    this.customCrossSize,
    this.trailingMargin = 0.0,
    this.hShift = 0.0,
    required Widget child,
  }) : super(key: key, child: child);

  @override
  void applyParentData(RenderObject renderObject) {
    assert(renderObject.parentData is VListParentData);
    final parentData = renderObject.parentData as VListParentData;
    var needsLayout = false;

    if (parentData.customCrossSize != customCrossSize) {
      parentData.customCrossSize = customCrossSize;
      needsLayout = true;
    }

    if (parentData.trailingMargin != trailingMargin) {
      parentData.trailingMargin = trailingMargin;
      needsLayout = true;
    }

    if (parentData.hShift != hShift) {
      parentData.hShift = hShift;
      needsLayout = true;
    }

    if (needsLayout) {
      final targetParent = renderObject.parent;
      if (targetParent is RenderObject) targetParent.markNeedsLayout();
    }
  }

  @override
  void debugFillProperties(DiagnosticPropertiesBuilder properties) {
    super.debugFillProperties(properties);
    properties.add(FlagProperty('customSize',
        value: customCrossSize != null, ifTrue: 'using relative size'));
    properties.add(DoubleProperty('trailingMargin', trailingMargin));
    properties.add(DoubleProperty('horizontalShift', hShift));
  }

  @override
  Type get debugTypicalAncestorWidgetClass => VList;
}

/// Vertical List exposes layout width to children, allows arbitrary horizontal
/// shift, and passes baseline information to parent.
///
/// Should be used in combination with [VListElement] and [LayoutBuilder]
///
/// The children are grouped into fixed ([VListElement.customCrossSize] == null
/// ) and custom-sized ([VListElement.customCrossSize] != null).
///
/// Each child is positioned as follows:
///
/// - On the vertical axis, [VList] will stack all children with spacings
/// specified by [VListElement.trailingMargin] (can be negative, 0 if not
/// specified).
/// - On the horizontal axis, [VList] will first position the child according
/// to [crossAxisAlignment], then apply a shift specified by
/// [VListElement.hShift].
///
/// The layout process is as follows:
///
/// - Layout all fixed children with [crossAxisAlignment]
/// - Apply [VListElement.hShift].
/// - Calculate width and height to contain all fixed children, including
/// negative overflow. Use this width to generate constraints for all
/// custom-sized children.
/// - Layout all children with [crossAxisAlignment]
/// - Apply [VListElement.hShift].
/// - Calculate width and height to contain all children. x = 0 will be aligned
/// to the leftmost of children.
///
/// In implementation it is a two-pass layout process and even more efficient
/// than Flutter's Column.
class VList extends MultiChildRenderObjectWidget {
  VList({
    Key? key,
    this.textBaseline = TextBaseline.alphabetic,
    this.baselineReferenceWidgetIndex = 0,
    // this.baselineOffset = 0,
    this.crossAxisAlignment = CrossAxisAlignment.center,
    this.textDirection,
    List<Widget> children = const [],
  }) : super(key: key, children: children);
  final TextBaseline textBaseline;
  final int baselineReferenceWidgetIndex;
  // final double baselineOffset;
  final CrossAxisAlignment crossAxisAlignment;
  final TextDirection? textDirection;
  bool get _needTextDirection =>
      crossAxisAlignment == CrossAxisAlignment.start ||
      crossAxisAlignment == CrossAxisAlignment.end;

  @protected
  TextDirection? getEffectiveTextDirection(BuildContext context) =>
      textDirection ?? (_needTextDirection ? Directionality.of(context) : null);
  @override
  RenderRelativeWidthColumn createRenderObject(BuildContext context) =>
      RenderRelativeWidthColumn(
        textBaseline: textBaseline,
        baselineReferenceWidgetIndex: baselineReferenceWidgetIndex,
        // baselineOffset: baselineOffset,
        crossAxisAlignment: crossAxisAlignment,
        textDirection: getEffectiveTextDirection(context),
      );

  @override
  void updateRenderObject(
      BuildContext context, covariant RenderRelativeWidthColumn renderObject) {
    renderObject
      ..textBaseline = textBaseline
      ..baselineReferenceWidgetIndex = baselineReferenceWidgetIndex
      // ..baselineOffset = baselineOffset
      ..crossAxisAlignment = crossAxisAlignment
      ..textDirection = getEffectiveTextDirection(context);
  }

  @override
  void debugFillProperties(DiagnosticPropertiesBuilder properties) {
    super.debugFillProperties(properties);
    properties.add(EnumProperty<TextBaseline>('textBaseline', textBaseline,
        defaultValue: null));
    properties.add(IntProperty(
        'baselineReferenceWidgetNum', baselineReferenceWidgetIndex,
        defaultValue: 0));
    // properties
    // .add(DoubleProperty('baselineOffset', baselineOffset, defaultValue: 0));
    properties.add(EnumProperty<CrossAxisAlignment>(
        'crossAxisAlignment', crossAxisAlignment));
    properties.add(EnumProperty<TextDirection>('textDirection', textDirection,
        defaultValue: null));
  }
}

class RenderRelativeWidthColumn extends RenderBox
    with
        ContainerRenderObjectMixin<RenderBox, VListParentData>,
        RenderBoxContainerDefaultsMixin<RenderBox, VListParentData>,
        DebugOverflowIndicatorMixin {
  RenderRelativeWidthColumn({
    List<RenderBox>? children,
    TextBaseline textBaseline = TextBaseline.alphabetic,
    int baselineReferenceWidgetIndex = 0,
    // double baselineOffset = 0,
    CrossAxisAlignment crossAxisAlignment = CrossAxisAlignment.center,
    TextDirection? textDirection = TextDirection.ltr,
  })  : _textBaseline = textBaseline,
        _baselineReferenceWidgetIndex = baselineReferenceWidgetIndex,
        // _baselineOffset = baselineOffset,
        _crossAxisAlignment = crossAxisAlignment,
        _textDirection = textDirection {
    addAll(children);
  }

  TextBaseline get textBaseline => _textBaseline;
  TextBaseline _textBaseline;
  set textBaseline(TextBaseline value) {
    if (_textBaseline != value) {
      _textBaseline = value;
      markNeedsLayout();
    }
  }

  int get baselineReferenceWidgetIndex => _baselineReferenceWidgetIndex;
  int _baselineReferenceWidgetIndex;
  set baselineReferenceWidgetIndex(int value) {
    if (_baselineReferenceWidgetIndex != value) {
      _baselineReferenceWidgetIndex = value;
      markNeedsLayout();
    }
  }

  // double get baselineOffset => _baselineOffset;
  // double _baselineOffset;
  // set baselineOffset(double value) {
  //   if (_baselineOffset != value) {
  //     _baselineOffset = value;
  //     markNeedsLayout();
  //   }
  // }

  CrossAxisAlignment get crossAxisAlignment => _crossAxisAlignment;
  CrossAxisAlignment _crossAxisAlignment;
  set crossAxisAlignment(CrossAxisAlignment value) {
    if (_crossAxisAlignment != value) {
      _crossAxisAlignment = value;
      markNeedsLayout();
    }
  }

  TextDirection? get textDirection => _textDirection;
  TextDirection? _textDirection;
  set textDirection(TextDirection? value) {
    if (_textDirection != value) {
      _textDirection = value;
      markNeedsLayout();
    }
  }

  bool get _debugHasNecessaryDirections {
    if (crossAxisAlignment == CrossAxisAlignment.start ||
        crossAxisAlignment == CrossAxisAlignment.end) {
      assert(textDirection != null,
          'Vertical $runtimeType with $crossAxisAlignment has a null textDirection, so the alignment cannot be resolved.');
    }
    return true;
  }

  double? _overflow;
  bool get _hasOverflow => _overflow! > precisionErrorTolerance;

  @override
  void setupParentData(RenderBox child) {
    if (child.parentData is! VListParentData) {
      child.parentData = VListParentData();
    }
  }

  double _getIntrinsicSize({
    required Axis sizingDirection,
    required double
        extent, // the extent in the direction that isn't the sizing direction
    required double Function(RenderBox child, double extent)
        childSize, // a method to find the size in the sizing direction
  }) {
    if (sizingDirection == Axis.vertical) {
      // INTRINSIC MAIN SIZE
      // Intrinsic main size is the smallest size the flex container can take
      // while maintaining the min/max-content contributions of its flex items.
      var inflexibleSpace = 0.0;
      var child = firstChild;
      while (child != null) {
        inflexibleSpace += childSize(child, extent);
        final childParentData = child.parentData as VListParentData;
        child = childParentData.nextSibling;
      }
      return inflexibleSpace;
    } else {
      // INTRINSIC CROSS SIZE
      // Intrinsic cross size is the max of the intrinsic cross sizes of the
      // children, after the flexible children are fit into the available space,
      // with the children sized using their max intrinsic dimensions.
      var maxCrossSize = 0.0;
      var child = firstChild;
      while (child != null) {
        final childMainSize = child.getMaxIntrinsicHeight(double.infinity);
        final crossSize = childSize(child, childMainSize);
        maxCrossSize = math.max(maxCrossSize, crossSize);
        final childParentData = child.parentData as VListParentData;
        child = childParentData.nextSibling;
      }
      return maxCrossSize;
    }
  }

  @override
  double computeMinIntrinsicWidth(double height) => _getIntrinsicSize(
        sizingDirection: Axis.horizontal,
        extent: height,
        childSize: (RenderBox child, double extent) =>
            child.getMinIntrinsicWidth(extent),
      );

  @override
  double computeMaxIntrinsicWidth(double height) => _getIntrinsicSize(
        sizingDirection: Axis.horizontal,
        extent: height,
        childSize: (RenderBox child, double extent) =>
            child.getMaxIntrinsicWidth(extent),
      );

  @override
  double computeMinIntrinsicHeight(double width) => _getIntrinsicSize(
        sizingDirection: Axis.vertical,
        extent: width,
        childSize: (RenderBox child, double extent) =>
            child.getMinIntrinsicHeight(extent),
      );

  @override
  double computeMaxIntrinsicHeight(double width) => _getIntrinsicSize(
        sizingDirection: Axis.vertical,
        extent: width,
        childSize: (RenderBox child, double extent) =>
            child.getMaxIntrinsicHeight(extent),
      );

  double? distanceToBaseline;

  @override
  double? computeDistanceToActualBaseline(TextBaseline baseline) {
    assert(!debugNeedsLayout);
    return distanceToBaseline;
  }

  double getRightMost(CrossAxisAlignment crossAxisAlignment, double width) {
    switch (crossAxisAlignment) {
      case CrossAxisAlignment.center:
        return width / 2;
      case CrossAxisAlignment.end:
        return 0;
      case CrossAxisAlignment.start:
      case CrossAxisAlignment.baseline:
      case CrossAxisAlignment.stretch: // TODO
      default:
        return width;
    }
  }

  @override
  Size computeDryLayout(BoxConstraints constraints) =>
      _computeLayout(constraints);

  @override
  void performLayout() {
    size = _computeLayout(constraints, dry: false);
  }

  Size _computeLayout(BoxConstraints constraints, {bool dry = true}) {
    if (!dry) {
      distanceToBaseline = null;
      assert(_debugHasNecessaryDirections);
    }

    // First we lay out all fix-sized children
    var rightMost = 0.0;
    var allocatedSize = 0.0; // Sum of the sizes of the non-flexible children.
    var leftMost = 0.0;
    var child = firstChild;
    final relativeChildren = <RenderBox>[];
    while (child != null) {
      final childParentData = child.parentData as VListParentData;
      if (childParentData.customCrossSize != null) {
        relativeChildren.add(child);
      } else {
        final innerConstraints = BoxConstraints(maxWidth: constraints.maxWidth);
        final childSize = child.getLayoutSize(innerConstraints, dry: dry);
        final width = childSize.width;
        final right = getRightMost(crossAxisAlignment, width);

        leftMost = math.min(leftMost, right - width);
        rightMost = math.max(rightMost, right);
        allocatedSize += childSize.height + childParentData.trailingMargin;
      }
      assert(child.parentData == childParentData);
      child = childParentData.nextSibling;
    }

    final fixedChildrenCrossSize = rightMost - leftMost;

    // Then we lay out custom sized children
    for (final child in relativeChildren) {
      final childParentData = child.parentData as VListParentData;
      assert(childParentData.customCrossSize != null);

      final childConstraints =
          childParentData.customCrossSize!(fixedChildrenCrossSize);
      final childSize = child.getLayoutSize(childConstraints, dry: dry);
      final width = childSize.width;
      final right = getRightMost(crossAxisAlignment, width);

      leftMost = math.min(leftMost, right - width);
      rightMost = math.max(rightMost, right);
      allocatedSize += childSize.height + childParentData.trailingMargin;
    }

    // Calculate size
    final size =
        constraints.constrain(Size(rightMost - leftMost, allocatedSize));
    if (dry) {
      // We can return the size at this point when doing the dry layout.
      return size;
    }

    final actualSize = size.height;
    final crossSize = size.width;
    final actualSizeDelta = actualSize - allocatedSize;
    _overflow = math.max(0.0, -actualSizeDelta);

    // Position elements
    var index = 0;
    var childMainPosition = 0.0;
    child = firstChild;
    while (child != null) {
      final childParentData = child.parentData as VListParentData;
      var childCrossPosition = 0.0;
      switch (crossAxisAlignment) {
        case CrossAxisAlignment.start:
          childCrossPosition = textDirection == TextDirection.ltr
              ? childParentData.hShift - leftMost
              : rightMost - child.size.width + crossSize;
          break;
        case CrossAxisAlignment.end:
          childCrossPosition = textDirection == TextDirection.rtl
              ? childParentData.hShift - leftMost
              : rightMost - child.size.width + crossSize;
          break;
        case CrossAxisAlignment.center:
          childCrossPosition = -child.size.width / 2 - leftMost;
          break;
        case CrossAxisAlignment.stretch:
        case CrossAxisAlignment.baseline:
          childCrossPosition = 0.0;
          break;
      }
      childCrossPosition += childParentData.hShift;
      childParentData.offset = Offset(childCrossPosition, childMainPosition);

      if (index == baselineReferenceWidgetIndex) {
        distanceToBaseline =
            childMainPosition + child.getDistanceToBaseline(textBaseline)!;
      }

      childMainPosition += child.size.height + childParentData.trailingMargin;
      child = childParentData.nextSibling;
      index++;
    }

    return size;
  }

  @override
  bool hitTestChildren(BoxHitTestResult result, {required Offset position}) =>
      defaultHitTestChildren(result, position: position);

  @override
  void paint(PaintingContext context, Offset offset) {
    if (!_hasOverflow) {
      defaultPaint(context, offset);
      return;
    }

    if (size.isEmpty) return;

    context.pushClipRect(
        needsCompositing, offset, Offset.zero & size, defaultPaint);
    assert(() {
      // Only set this if it's null to save work. It gets reset to null if the
      // _direction changes.
      final debugOverflowHints = <DiagnosticsNode>[
        ErrorDescription(
          'The edge of the $runtimeType that is overflowing has been marked '
          'in the rendering with a yellow and black striped pattern. This is '
          'usually caused by the contents being too big for the $runtimeType.',
        ),
        ErrorHint(
          'Consider applying a flex factor (e.g. using an Expanded widget) to '
          'force the children of the $runtimeType to fit within the available '
          'space instead of being sized to their natural size.',
        ),
        ErrorHint(
          'This is considered an error condition because it indicates that there '
          'is content that cannot be seen. If the content is legitimately bigger '
          'than the available space, consider clipping it with a ClipRect widget '
          'before putting it in the flex, or using a scrollable container rather '
          'than a Flex, like a ListView.',
        ),
      ];

      // Simulate a child rect that overflows by the right amount. This child
      // rect is never used for drawing, just for determining the overflow
      // location and amount.
      Rect overflowChildRect;
      overflowChildRect =
          Rect.fromLTWH(0.0, 0.0, 0.0, size.height + _overflow!);

      paintOverflowIndicator(
          context, offset, Offset.zero & size, overflowChildRect,
          overflowHints: debugOverflowHints);
      return true;
    }());
  }

  @override
  Rect? describeApproximatePaintClip(RenderObject child) =>
      _hasOverflow ? Offset.zero & size : null;

  @override
  String toStringShort() {
    var header = super.toStringShort();
    if (_overflow is double && _hasOverflow) header += ' OVERFLOWING';
    return header;
  }

  @override
  void debugFillProperties(DiagnosticPropertiesBuilder properties) {
    super.debugFillProperties(properties);
    properties.add(EnumProperty<CrossAxisAlignment>(
        'crossAxisAlignment', crossAxisAlignment));
    properties.add(EnumProperty<TextDirection>('textDirection', textDirection,
        defaultValue: null));
    properties.add(EnumProperty<TextBaseline>('textBaseline', textBaseline,
        defaultValue: null));
    properties.add(IntProperty(
        'baselineReferenceWidgetIndex', baselineReferenceWidgetIndex));
  }
}
