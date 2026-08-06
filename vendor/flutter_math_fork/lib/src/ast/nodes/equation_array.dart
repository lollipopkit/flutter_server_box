import '../../render/layout/eqn_array.dart';
import '../../render/layout/shift_baseline.dart';
import '../../utils/iterable_extensions.dart';
import '../options.dart';
import '../size.dart';
import '../syntax_tree.dart';
import 'matrix.dart';

/// Equantion array node. Brings support for equationa alignment.
class EquationArrayNode extends SlotableNode<EquationRowNode?> {
  /// `arrayStretch` parameter from the context.
  ///
  /// Affects the minimum row height and row depth for each row.
  ///
  /// `\smallmatrix` has an `arrayStretch` of 0.5.
  final double arrayStretch;

  /// Whether to add an extra 3 pt spacing between each row.
  ///
  /// True for `\aligned` and `\alignedat`
  final bool addJot;

  /// Arrayed equations.
  final List<EquationRowNode> body;

  /// Style for horizontal separator lines.
  ///
  /// This includes outermost lines. Different from MathML!
  final List<MatrixSeparatorStyle> hlines;

  /// Spacings between rows;
  final List<Measurement> rowSpacings;

  EquationArrayNode({
    this.addJot = false,
    required this.body,
    this.arrayStretch = 1.0,
    List<MatrixSeparatorStyle>? hlines,
    List<Measurement>? rowSpacings,
  })  : hlines = (hlines ?? [])
            .extendToByFill(body.length + 1, MatrixSeparatorStyle.none),
        rowSpacings =
            (rowSpacings ?? []).extendToByFill(body.length, Measurement.zero);

  @override
  BuildResult buildWidget(
          MathOptions options, List<BuildResult?> childBuildResults) =>
      BuildResult(
        options: options,
        widget: ShiftBaseline(
          relativePos: 0.5,
          offset: options.fontMetrics.axisHeight.cssEm.toLpUnder(options),
          child: EqnArray(
            ruleThickness: options.fontMetrics.defaultRuleThickness.cssEm
                .toLpUnder(options),
            jotSize: addJot ? 3.0.pt.toLpUnder(options) : 0.0,
            arrayskip: 12.0.pt.toLpUnder(options) * arrayStretch,
            hlines: hlines,
            rowSpacings: rowSpacings
                .map((e) => e.toLpUnder(options))
                .toList(growable: false),
            children:
                childBuildResults.map((e) => e!.widget).toList(growable: false),
          ),
        ),
      );

  @override
  List<MathOptions> computeChildOptions(MathOptions options) =>
      List.filled(body.length, options, growable: false);

  @override
  List<EquationRowNode> computeChildren() => body;

  @override
  AtomType get leftType => AtomType.ord;

  @override
  AtomType get rightType => AtomType.ord;

  @override
  bool shouldRebuildWidget(MathOptions oldOptions, MathOptions newOptions) =>
      false;

  @override
  EquationArrayNode updateChildren(List<EquationRowNode> newChildren) =>
      copyWith(body: newChildren);

  @override
  Map<String, Object?> toJson() => super.toJson()
    ..addAll({
      if (addJot != false) 'addJot': addJot,
      'body': body.map((e) => e.toJson()),
      if (arrayStretch != 1.0) 'arrayStretch': arrayStretch,
      'hlines': hlines.map((e) => e.toString()),
      'rowSpacings': rowSpacings.map((e) => e.toString())
    });

  EquationArrayNode copyWith({
    double? arrayStretch,
    bool? addJot,
    List<EquationRowNode>? body,
    List<MatrixSeparatorStyle>? hlines,
    List<Measurement>? rowSpacings,
  }) =>
      EquationArrayNode(
        arrayStretch: arrayStretch ?? this.arrayStretch,
        addJot: addJot ?? this.addJot,
        body: body ?? this.body,
        hlines: hlines ?? this.hlines,
        rowSpacings: rowSpacings ?? this.rowSpacings,
      );
}
