import 'package:flutter/widgets.dart';

import '../../font/metrics/font_metrics.dart';
import '../../render/layout/line.dart';
import '../../render/layout/min_dimension.dart';
import '../../render/layout/multiscripts.dart';
import '../../render/layout/reset_dimension.dart';
import '../../render/layout/shift_baseline.dart';
import '../../render/layout/vlist.dart';
import '../../render/svg/static.dart';
import '../../render/symbols/make_symbol.dart';
import '../../utils/unicode_literal.dart';
import '../options.dart';
import '../size.dart';
import '../spacing.dart';
import '../style.dart';
import '../syntax_tree.dart';
import '../types.dart';

/// N-ary operator node.
///
/// Examples: `\sum`, `\int`
class NaryOperatorNode extends SlotableNode<EquationRowNode?> {
  /// Unicode symbol for the operator character.
  final String operator;

  /// Lower limit.
  final EquationRowNode? lowerLimit;

  /// Upper limit.
  final EquationRowNode? upperLimit;

  /// Argument for the N-ary operator.
  final EquationRowNode naryand;

  /// Whether the limits are displayed as under/over or as scripts.
  final bool? limits;

  /// Special flag for `\smallint`.
  final bool allowLargeOp; // for \smallint

  NaryOperatorNode({
    required this.operator,
    required this.lowerLimit,
    required this.upperLimit,
    required this.naryand,
    this.limits,
    this.allowLargeOp = true,
  });

  @override
  BuildResult buildWidget(
      MathOptions options, List<BuildResult?> childBuildResults) {
    final large =
        allowLargeOp && (options.style.size == MathStyle.display.size);
    final font = large
        ? FontOptions(fontFamily: 'Size2')
        : FontOptions(fontFamily: 'Size1');
    Widget operatorWidget;
    CharacterMetrics symbolMetrics;
    if (!_stashedOvalNaryOperator.containsKey(operator)) {
      final lookupResult = lookupChar(operator, font, Mode.math);
      if (lookupResult == null) {
        symbolMetrics = const CharacterMetrics(0, 0, 0, 0, 0);
        operatorWidget = Container();
      } else {
        symbolMetrics = lookupResult;
        final symbolWidget =
            makeChar(operator, font, symbolMetrics, options, needItalic: true);
        operatorWidget = symbolWidget;
      }
    } else {
      final baseSymbol = _stashedOvalNaryOperator[operator]!;
      symbolMetrics = lookupChar(baseSymbol, font, Mode.math)!;
      final baseSymbolWidget =
          makeChar(baseSymbol, font, symbolMetrics, options, needItalic: true);

      final oval = staticSvg(
          '${operator == '\u222F' ? 'oiint' : 'oiiint'}'
          'Size${large ? '2' : '1'}',
          options);

      operatorWidget = Row(
        crossAxisAlignment: CrossAxisAlignment.baseline,
        textBaseline: TextBaseline.alphabetic,
        mainAxisAlignment: MainAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          ResetDimension(
            horizontalAlignment: CrossAxisAlignment.start,
            width: 0.0,
            child: ShiftBaseline(
              offset: large ? 0.08.cssEm.toLpUnder(options) : 0.0,
              child: oval,
            ),
          ),
          baseSymbolWidget,
        ],
      );
    }

    // Attach limits to the base symbol
    if (lowerLimit != null || upperLimit != null) {
      // Should we place the limit as under/over or sub/sup
      final shouldLimits = limits ??
          (_naryDefaultLimit.contains(operator) &&
              options.style.size == MathStyle.display.size);
      final italic = symbolMetrics.italic.cssEm.toLpUnder(options);
      if (!shouldLimits) {
        operatorWidget = Multiscripts(
          isBaseCharacterBox: false,
          baseResult: BuildResult(
              widget: operatorWidget, options: options, italic: italic),
          subResult: childBuildResults[0],
          supResult: childBuildResults[1],
        );
      } else {
        final spacing =
            options.fontMetrics.bigOpSpacing5.cssEm.toLpUnder(options);
        operatorWidget = Padding(
          padding: EdgeInsets.only(
            top: upperLimit != null ? spacing : 0,
            bottom: lowerLimit != null ? spacing : 0,
          ),
          child: VList(
            baselineReferenceWidgetIndex: upperLimit != null ? 1 : 0,
            children: [
              if (upperLimit != null)
                VListElement(
                  hShift: 0.5 * italic,
                  child: MinDimension(
                    minDepth: options.fontMetrics.bigOpSpacing3.cssEm
                        .toLpUnder(options),
                    bottomPadding: options.fontMetrics.bigOpSpacing1.cssEm
                        .toLpUnder(options),
                    child: childBuildResults[1]!.widget,
                  ),
                ),
              operatorWidget,
              if (lowerLimit != null)
                VListElement(
                  hShift: -0.5 * italic,
                  child: MinDimension(
                    minHeight: options.fontMetrics.bigOpSpacing4.cssEm
                        .toLpUnder(options),
                    topPadding: options.fontMetrics.bigOpSpacing2.cssEm
                        .toLpUnder(options),
                    child: childBuildResults[0]!.widget,
                  ),
                ),
            ],
          ),
        );
      }
    }
    final widget = Line(
      children: [
        LineElement(
          child: operatorWidget,
          trailingMargin:
              getSpacingSize(AtomType.op, naryand.leftType, options.style)
                  .toLpUnder(options),
        ),
        LineElement(
          child: childBuildResults[2]!.widget,
          trailingMargin: 0.0,
        ),
      ],
    );
    return BuildResult(
      widget: widget,
      options: options,
      italic: childBuildResults[2]!.italic,
    );
  }

  @override
  List<MathOptions> computeChildOptions(MathOptions options) => [
        options.havingStyle(options.style.sub()),
        options.havingStyle(options.style.sup()),
        options,
      ];

  @override
  List<EquationRowNode?> computeChildren() => [lowerLimit, upperLimit, naryand];

  @override
  AtomType get leftType => AtomType.op;

  @override
  AtomType get rightType => naryand.rightType;

  @override
  bool shouldRebuildWidget(MathOptions oldOptions, MathOptions newOptions) =>
      oldOptions.sizeMultiplier != newOptions.sizeMultiplier;

  @override
  NaryOperatorNode updateChildren(List<EquationRowNode?> newChildren) =>
      NaryOperatorNode(
        operator: operator,
        lowerLimit: newChildren[0],
        upperLimit: newChildren[1],
        naryand: newChildren[2]!,
        limits: limits,
        allowLargeOp: allowLargeOp,
      );

  @override
  Map<String, Object?> toJson() => super.toJson()
    ..addAll({
      'operator': unicodeLiteral(operator),
      if (upperLimit != null) 'upperLimit': upperLimit!.toJson(),
      if (lowerLimit != null) 'lowerLimit': lowerLimit!.toJson(),
      'naryand': naryand.toJson(),
      if (limits != null) 'limits': limits,
      if (allowLargeOp != true) 'allowLargeOp': allowLargeOp,
    });
}

const _naryDefaultLimit = {
  '\u220F',
  '\u2210',
  '\u2211',
  '\u22c0',
  '\u22c1',
  '\u22c2',
  '\u22c3',
  '\u2a00',
  '\u2a01',
  '\u2a02',
  '\u2a04',
  '\u2a06',
};

const _stashedOvalNaryOperator = {
  '\u222F': '\u222C',
  '\u2230': '\u222D',
};
