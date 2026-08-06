//ignore_for_file: lines_longer_than_80_chars
import 'dart:math' as math;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';

import '../constants.dart';
import '../utils/render_box_offset.dart';
import '../utils/render_box_layout.dart';

class LineParentData extends ContainerBoxParentData<RenderBox> {
  // The first canBreakBefore has no effect
  bool canBreakBefore = false;

  BoxConstraints Function(double height, double depth)? customCrossSize;

  double trailingMargin = 0.0;

  bool alignerOrSpacer = false;

  @override
  String toString() =>
      '${super.toString()}; canBreakBefore = $canBreakBefore; customSize = ${customCrossSize != null}; trailingMargin = $trailingMargin; alignerOrSpacer = $alignerOrSpacer';
}

class LineElement extends ParentDataWidget<LineParentData> {
  final bool canBreakBefore;
  final BoxConstraints Function(double height, double depth)? customCrossSize;
  final double trailingMargin;
  final bool alignerOrSpacer;

  const LineElement({
    Key? key,
    this.canBreakBefore = false,
    this.customCrossSize,
    this.trailingMargin = 0.0,
    this.alignerOrSpacer = false,
    required Widget child,
  }) : super(key: key, child: child);

  @override
  void applyParentData(RenderObject renderObject) {
    assert(renderObject.parentData is LineParentData);
    final parentData = renderObject.parentData as LineParentData;
    var needsLayout = false;

    if (parentData.canBreakBefore != canBreakBefore) {
      parentData.canBreakBefore = canBreakBefore;
      needsLayout = true;
    }

    if (parentData.customCrossSize != customCrossSize) {
      parentData.customCrossSize = customCrossSize;
      needsLayout = true;
    }

    if (parentData.trailingMargin != trailingMargin) {
      parentData.trailingMargin = trailingMargin;
      needsLayout = true;
    }

    if (parentData.alignerOrSpacer != alignerOrSpacer) {
      parentData.alignerOrSpacer = alignerOrSpacer;
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
    properties.add(FlagProperty('canBreakBefore',
        value: canBreakBefore, ifTrue: 'allow breaking before'));
    properties.add(FlagProperty('customSize',
        value: customCrossSize != null, ifTrue: 'using relative size'));
    properties.add(DoubleProperty('trailingMargin', trailingMargin));
    properties.add(FlagProperty('alignerOrSpacer',
        value: alignerOrSpacer, ifTrue: 'is a alignment symbol'));
  }

  @override
  Type get debugTypicalAncestorWidgetClass => Line;
}

/// Line provides abilities for line breaks, delim-sizing and background color indicator.
class Line extends MultiChildRenderObjectWidget {
  Line({
    Key? key,
    this.crossAxisAlignment = CrossAxisAlignment.baseline,
    this.minDepth = 0.0,
    this.minHeight = 0.0,
    this.textBaseline = TextBaseline.alphabetic,
    this.textDirection,
    List<Widget> children = const [],
  }) : super(key: key, children: children);

  final CrossAxisAlignment crossAxisAlignment;

  final double minDepth;

  final double minHeight;

  final TextBaseline textBaseline;

  final TextDirection? textDirection;

  bool get _needTextDirection => true;

  @protected
  TextDirection? getEffectiveTextDirection(BuildContext context) =>
      textDirection ?? (_needTextDirection ? Directionality.of(context) : null);

  @override
  RenderLine createRenderObject(BuildContext context) => RenderLine(
        crossAxisAlignment: crossAxisAlignment,
        minDepth: minDepth,
        minHeight: minHeight,
        textBaseline: textBaseline,
        textDirection: getEffectiveTextDirection(context),
      );

  @override
  void updateRenderObject(BuildContext context, RenderLine renderObject) =>
      renderObject
        ..crossAxisAlignment = crossAxisAlignment
        ..minDepth = minDepth
        ..minHeight = minHeight
        ..textBaseline = textBaseline
        ..textDirection = getEffectiveTextDirection(context);

  @override
  void debugFillProperties(DiagnosticPropertiesBuilder properties) {
    super.debugFillProperties(properties);
    properties.add(EnumProperty<TextBaseline>('textBaseline', textBaseline,
        defaultValue: null));
    properties.add(EnumProperty<CrossAxisAlignment>(
        'crossAxisAlignment', crossAxisAlignment));
    properties.add(EnumProperty<TextDirection>('textDirection', textDirection,
        defaultValue: null));
  }
}

// RenderLine
class RenderLine extends RenderBox
    with
        ContainerRenderObjectMixin<RenderBox, LineParentData>,
        RenderBoxContainerDefaultsMixin<RenderBox, LineParentData>,
        DebugOverflowIndicatorMixin {
  RenderLine({
    List<RenderBox>? children,
    CrossAxisAlignment crossAxisAlignment = CrossAxisAlignment.baseline,
    double minDepth = 0,
    double minHeight = 0,
    TextBaseline textBaseline = TextBaseline.alphabetic,
    TextDirection? textDirection = TextDirection.ltr,
  })  : _crossAxisAlignment = crossAxisAlignment,
        _minDepth = minDepth,
        _minHeight = minHeight,
        _textBaseline = textBaseline,
        _textDirection = textDirection {
    addAll(children);
  }

  CrossAxisAlignment get crossAxisAlignment => _crossAxisAlignment;
  CrossAxisAlignment _crossAxisAlignment;
  set crossAxisAlignment(CrossAxisAlignment value) {
    if (_crossAxisAlignment != value) {
      _crossAxisAlignment = value;
      markNeedsLayout();
    }
  }

  double get minDepth => _minDepth;
  double _minDepth;
  set minDepth(double value) {
    if (_minDepth != value) {
      _minDepth = value;
      markNeedsLayout();
    }
  }

  double get minHeight => _minHeight;
  double _minHeight;
  set minHeight(double value) {
    if (_minHeight != value) {
      _minHeight = value;
      markNeedsLayout();
    }
  }

  TextBaseline get textBaseline => _textBaseline;
  TextBaseline _textBaseline;
  set textBaseline(TextBaseline value) {
    if (_textBaseline != value) {
      _textBaseline = value;
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
    assert(textDirection != null,
        'Horizontal $runtimeType has a null textDirection, so the alignment cannot be resolved.');
    return true;
  }

  double? _overflow;
  bool get _hasOverflow => _overflow! > precisionErrorTolerance;

  @override
  void setupParentData(RenderBox child) {
    if (child.parentData is! LineParentData) {
      child.parentData = LineParentData();
    }
  }

  double _getIntrinsicSize({
    required Axis sizingDirection,
    required double
        extent, // the extent in the direction that isn't the sizing direction
    required double Function(RenderBox child, double extent)
        childSize, // a method to find the size in the sizing direction
  }) {
    if (sizingDirection == Axis.horizontal) {
      // INTRINSIC MAIN SIZE
      // Intrinsic main size is the smallest size the flex container can take
      // while maintaining the min/max-content contributions of its flex items.
      var inflexibleSpace = 0.0;
      var child = firstChild;
      while (child != null) {
        inflexibleSpace += childSize(child, extent);
        final childParentData = child.parentData as LineParentData;
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
        final childMainSize = child.getMaxIntrinsicWidth(double.infinity);
        final crossSize = childSize(child, childMainSize);
        maxCrossSize = math.max(maxCrossSize, crossSize);
        final childParentData = child.parentData as LineParentData;
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

  double maxHeightAboveBaseline = 0.0;

  double maxHeightAboveEndBaseline = 0.0;

  @override
  double computeDistanceToActualBaseline(TextBaseline baseline) {
    assert(!debugNeedsLayout);
    return maxHeightAboveBaseline;
  }

  @protected
  late List<double> caretOffsets;

  List<double>? alignColWidth;

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
    assert(_debugHasNecessaryDirections);

    // First pass, layout fixed-sized children to calculate height and depth
    var maxHeightAboveBaseline = 0.0;
    var maxDepthBelowBaseline = 0.0;
    var child = firstChild;
    final relativeChildren = <RenderBox>[];
    final alignerAndSpacers = <RenderBox>[];
    final sizeMap = <RenderBox, Size>{};
    while (child != null) {
      final childParentData = child.parentData as LineParentData;
      if (childParentData.customCrossSize != null) {
        relativeChildren.add(child);
      } else if (childParentData.alignerOrSpacer) {
        alignerAndSpacers.add(child);
      } else {
        final childSize = child.getLayoutSize(infiniteConstraint, dry: dry);
        sizeMap[child] = childSize;
        final distance = dry ? 0.0 : child.getDistanceToBaseline(textBaseline)!;
        maxHeightAboveBaseline = math.max(maxHeightAboveBaseline, distance);
        maxDepthBelowBaseline =
            math.max(maxDepthBelowBaseline, childSize.height - distance);
      }
      assert(child.parentData == childParentData);
      child = childParentData.nextSibling;
    }

    // Second pass, layout custom-sized children
    for (final child in relativeChildren) {
      final childParentData = child.parentData as LineParentData;
      assert(childParentData.customCrossSize != null);
      final childConstraints = childParentData.customCrossSize!(
          maxHeightAboveBaseline, maxDepthBelowBaseline);
      final childSize = child.getLayoutSize(childConstraints, dry: dry);
      sizeMap[child] = childSize;
      final distance = dry ? 0.0 : child.getDistanceToBaseline(textBaseline)!;
      maxHeightAboveBaseline = math.max(maxHeightAboveBaseline, distance);
      maxDepthBelowBaseline =
          math.max(maxDepthBelowBaseline, childSize.height - distance);
    }

    // Apply mininmum size constraint
    maxHeightAboveBaseline = math.max(maxHeightAboveBaseline, minHeight);
    maxDepthBelowBaseline = math.max(maxDepthBelowBaseline, minDepth);

    // Third pass. Calculate column width separate by aligners and spacers.
    //
    // Also determine offset for each children in the meantime, as if there are
    // no aligning instructions. If there are indeed none, this will be the
    // final pass.
    child = firstChild;
    var mainPos = 0.0;
    var lastColPosition = mainPos;
    final colWidths = <double>[];
    var caretOffsets = [mainPos];
    while (child != null) {
      final childParentData = child.parentData as LineParentData;
      var childSize = sizeMap[child] ?? Size.zero;
      if (childParentData.alignerOrSpacer) {
        final childConstraints = BoxConstraints.tightFor(width: 0.0);
        childSize = child.getLayoutSize(childConstraints, dry: dry);

        colWidths.add(mainPos - lastColPosition);
        lastColPosition = mainPos;
      }
      if (!dry) {
        childParentData.offset =
            Offset(mainPos, maxHeightAboveBaseline - child.layoutHeight);
      }
      mainPos += childSize.width + childParentData.trailingMargin;

      caretOffsets.add(mainPos);
      child = childParentData.nextSibling;
    }
    colWidths.add(mainPos - lastColPosition);

    var size = constraints.constrain(
        Size(mainPos, maxHeightAboveBaseline + maxDepthBelowBaseline));

    if (!dry) {
      this.caretOffsets = caretOffsets;
      this._overflow = mainPos - size.width;
      this.maxHeightAboveBaseline = maxHeightAboveBaseline;
    } else {
      return size;
    }

    // If we have no aligners or spacers, no need to do the fourth pass.
    if (alignerAndSpacers.isEmpty) return size;

    // If we are have no aligning instructions, no need to do the fourth pass.
    if (this.alignColWidth == null) {
      // Report column width
      this.alignColWidth = colWidths;

      return size;
    }

    // If the code reaches here, means we have aligners/spacers and the
    // aligning instructions.

    // First report first column width.
    final alignColWidth = List.of(this.alignColWidth!, growable: false)
      ..[0] = colWidths.first;
    this.alignColWidth = alignColWidth;

    // We will determine the width of the spacers using aligning instructions
    ///
    ///       Aligner     Spacer      Aligner
    ///         |           |           |
    ///       x | f o o b a |         r | z z z
    ///         |           |-------|   |
    ///     y y | f         | o o b a r |
    ///         |   |-------|           |
    /// Index:  0           1           2
    /// Col: 0        1           2
    ///
    var aligner = true;
    var index = 0;
    for (final alignerOrSpacer in alignerAndSpacers) {
      if (aligner) {
        alignerOrSpacer.layout(BoxConstraints.tightFor(width: 0.0),
            parentUsesSize: true);
      } else {
        alignerOrSpacer.layout(
          BoxConstraints.tightFor(
            width: alignColWidth[index] +
                (index + 1 < alignColWidth.length - 1
                    ? alignColWidth[index + 1]
                    : 0) -
                colWidths[index] -
                (index + 1 < colWidths.length - 1 ? colWidths[index + 1] : 0),
          ),
          parentUsesSize: true,
        );
      }
      aligner = !aligner;
      index++;
    }

    // Fourth pass, determine position for each children
    child = firstChild;
    mainPos = 0.0;
    this.caretOffsets
      ..clear()
      ..add(mainPos);
    while (child != null) {
      final childParentData = child.parentData as LineParentData;
      childParentData.offset =
          Offset(mainPos, maxHeightAboveBaseline - child.layoutHeight);
      mainPos += child.size.width + childParentData.trailingMargin;

      this.caretOffsets.add(mainPos);
      child = childParentData.nextSibling;
    }

    size = constraints.constrain(
        Size(mainPos, maxHeightAboveBaseline + maxDepthBelowBaseline));
    this._overflow = mainPos - size.width;

    return size;
  }

  @override
  bool hitTestChildren(BoxHitTestResult result, {required Offset position}) =>
      defaultHitTestChildren(result, position: position);

  // List<Rect> get rects {
  //   final constraints = this.constraints;
  //   if (constraints is BreakableBoxConstraints) {
  //     var i = 0;
  //     var crossPos = 0.0;
  //     final res = <Rect>[];
  //     for (final size in size.lineSizes) {
  //       final mainPos = i == 0
  //           ? 0.0
  //           : constraints.maxWidthFirstLine - constraints.maxWidthBodyLines;
  //       res.add(Rect.fromLTWH(mainPos, crossPos, size.width, size.height));
  //       crossPos += size.height;
  //       i++;
  //     }
  //     return res;
  //   } else {
  //     return [Rect.fromLTWH(0, 0, size.width, size.height)];
  //   }
  // }

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
      overflowChildRect = Rect.fromLTWH(0.0, 0.0, size.width + _overflow!, 0.0);

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
    if (_overflow != null && _hasOverflow) header += ' OVERFLOWING';
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
    // properties.add(DoubleProperty('baselineOffset', baselineOffset));
  }
}
