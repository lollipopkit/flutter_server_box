import 'package:flutter/material.dart';

import '../../render/layout/custom_layout.dart';
import '../../render/utils/render_box_offset.dart';
import '../options.dart';
import '../size.dart';
import '../syntax_tree.dart';

/// Enclosure node
///
/// Examples: `\colorbox`, `\fbox`, `\cancel`.
class EnclosureNode extends SlotableNode<EquationRowNode> {
  /// Base where the enclosure is applied upon
  final EquationRowNode base;

  /// Whether the enclosure has a border.
  final bool hasBorder;

  /// Border color.
  ///
  /// If null, will default to options.color.
  final Color? bordercolor;

  /// Background color.
  final Color? backgroundcolor;

  /// Special styles for this enclosure.
  ///
  /// Including `'updiagonalstrike'`, `'downdiagnoalstrike'`,
  /// and `'horizontalstrike'`.
  final List<String> notation;

  /// Horizontal padding.
  final Measurement horizontalPadding;

  /// Vertical padding.
  final Measurement verticalPadding;

  EnclosureNode({
    required this.base,
    required this.hasBorder,
    this.bordercolor,
    this.backgroundcolor,
    this.notation = const [],
    this.horizontalPadding = Measurement.zero,
    this.verticalPadding = Measurement.zero,
  });

  @override
  BuildResult buildWidget(
      MathOptions options, List<BuildResult?> childBuildResults) {
    final horizontalPadding = this.horizontalPadding.toLpUnder(options);
    final verticalPadding = this.verticalPadding.toLpUnder(options);

    Widget widget = Stack(
      children: <Widget>[
        Container(
          // color: backgroundcolor,
          decoration: hasBorder
              ? BoxDecoration(
                  color: backgroundcolor,
                  border: Border.all(
                    // TODO minRuleThickness
                    width:
                        options.fontMetrics.fboxrule.cssEm.toLpUnder(options),
                    color: bordercolor ?? options.color,
                  ),
                )
              : null,
          child: Padding(
            padding: EdgeInsets.symmetric(
              vertical: verticalPadding,
              horizontal: horizontalPadding,
            ),
            child: childBuildResults[0]!.widget,
          ),
        ),
        if (notation.contains('updiagonalstrike'))
          Positioned(
            left: 0,
            right: 0,
            top: 0,
            bottom: 0,
            child: LayoutBuilder(
              builder: (context, constraints) => CustomPaint(
                size: constraints.biggest,
                painter: LinePainter(
                  startRelativeX: 0,
                  startRelativeY: 1,
                  endRelativeX: 1,
                  endRelativeY: 0,
                  lineWidth: 0.046.cssEm.toLpUnder(options),
                  color: bordercolor ?? options.color,
                ),
              ),
            ),
          ),
        if (notation.contains('downdiagnoalstrike'))
          Positioned(
            left: 0,
            right: 0,
            top: 0,
            bottom: 0,
            child: LayoutBuilder(
              builder: (context, constraints) => CustomPaint(
                size: constraints.biggest,
                painter: LinePainter(
                  startRelativeX: 0,
                  startRelativeY: 0,
                  endRelativeX: 1,
                  endRelativeY: 1,
                  lineWidth: 0.046.cssEm.toLpUnder(options),
                  color: bordercolor ?? options.color,
                ),
              ),
            ),
          ),
      ],
    );
    if (notation.contains('horizontalstrike')) {
      widget = CustomLayout<int>(
        delegate: HorizontalStrikeDelegate(
          vShift: options.fontMetrics.xHeight.cssEm.toLpUnder(options) / 2,
          ruleThickness:
              options.fontMetrics.defaultRuleThickness.cssEm.toLpUnder(options),
          color: bordercolor ?? options.color,
        ),
        children: <Widget>[
          CustomLayoutId(
            id: 0,
            child: widget,
          ),
        ],
      );
    }
    return BuildResult(
      options: options,
      widget: widget,
    );
  }

  @override
  List<MathOptions> computeChildOptions(MathOptions options) => [options];

  @override
  List<EquationRowNode> computeChildren() => [base];

  @override
  AtomType get leftType => AtomType.ord;

  @override
  AtomType get rightType => AtomType.ord;

  @override
  bool shouldRebuildWidget(MathOptions oldOptions, MathOptions newOptions) =>
      false;

  @override
  EnclosureNode updateChildren(List<EquationRowNode> newChildren) =>
      EnclosureNode(
        base: newChildren[0],
        hasBorder: hasBorder,
        bordercolor: bordercolor,
        backgroundcolor: backgroundcolor,
        notation: notation,
        horizontalPadding: horizontalPadding,
        verticalPadding: verticalPadding,
      );

  @override
  Map<String, Object?> toJson() => super.toJson()
    ..addAll({
      'base': base.toJson(),
      'hasBorder': hasBorder,
      if (bordercolor != null) 'bordercolor': bordercolor,
      if (backgroundcolor != null) 'backgroundcolor': backgroundcolor,
      if (notation.isNotEmpty) 'notation': notation,
      if (horizontalPadding != Measurement.zero)
        'horizontalPadding': horizontalPadding.toString(),
      if (verticalPadding != Measurement.zero)
        'verticalPadding': verticalPadding.toString(),
    });
}

class LinePainter extends CustomPainter {
  final double startRelativeX;
  final double startRelativeY;
  final double endRelativeX;
  final double endRelativeY;
  final double lineWidth;
  final Color color;

  const LinePainter({
    required this.startRelativeX,
    required this.startRelativeY,
    required this.endRelativeX,
    required this.endRelativeY,
    required this.lineWidth,
    required this.color,
  });

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawLine(
      Offset(startRelativeX * size.width, startRelativeY * size.height),
      Offset(endRelativeX * size.width, endRelativeY * size.height),
      Paint()
        ..strokeWidth = lineWidth
        ..color = color,
    );
  }

  @override
  bool shouldRepaint(CustomPainter oldDelegate) => this != oldDelegate;
}

class HorizontalStrikeDelegate extends CustomLayoutDelegate<int> {
  final double ruleThickness;
  final double vShift;
  final Color color;

  HorizontalStrikeDelegate({
    required this.ruleThickness,
    required this.vShift,
    required this.color,
  });

  var height = 0.0;
  var width = 0.0;

  @override
  double computeDistanceToActualBaseline(
          TextBaseline baseline, Map<int, RenderBox> childrenTable) =>
      height;

  @override
  double getIntrinsicSize({
    required Axis sizingDirection,
    required bool max,
    required double extent,
    required double Function(RenderBox child, double extent) childSize,
    required Map<int, RenderBox> childrenTable,
  }) =>
      childSize(childrenTable[0]!, double.infinity);

  @override
  Size computeLayout(
    BoxConstraints constraints,
    Map<int, RenderBox> childrenTable, {
    bool dry = true,
  }) {
    final base = childrenTable[0]!;

    if (dry) {
      return base.getDryLayout(constraints);
    }

    base.layout(constraints, parentUsesSize: true);
    height = base.layoutHeight;
    width = base.size.width;

    return base.size;
  }

  @override
  void additionalPaint(PaintingContext context, Offset offset) {
    context.canvas.drawLine(
      Offset(
        offset.dx,
        offset.dy + height - vShift,
      ),
      Offset(
        offset.dx + width,
        offset.dy + height - vShift,
      ),
      Paint()
        ..strokeWidth = ruleThickness
        ..color = color,
    );
  }
}
