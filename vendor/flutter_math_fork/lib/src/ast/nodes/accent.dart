import 'package:flutter/material.dart';
import 'package:flutter/widgets.dart';

import '../../render/layout/min_dimension.dart';
import '../../render/layout/reset_dimension.dart';
import '../../render/layout/shift_baseline.dart';
import '../../render/layout/vlist.dart';
import '../../render/svg/static.dart';
import '../../render/svg/stretchy.dart';
import '../../render/symbols/make_symbol.dart';
import '../../utils/unicode_literal.dart';
import '../accents.dart';
import '../options.dart';
import '../size.dart';
import '../syntax_tree.dart';
import '../types.dart';

/// Accent node.
///
/// Examples: `\hat`
class AccentNode extends SlotableNode<EquationRowNode> {
  /// Base where the accent is applied upon.
  final EquationRowNode base;

  /// Unicode symbol of the accent character.
  final String label;

  /// Is the accent strecthy?
  ///
  /// Stretchy accent will stretch according to the width of [base].
  final bool isStretchy;

  /// Is the accent shifty?
  ///
  /// Shifty accent will shift according to the italic of [base].
  final bool isShifty;
  AccentNode({
    required this.base,
    required this.label,
    required this.isStretchy,
    required this.isShifty,
  });

  @override
  BuildResult buildWidget(
      MathOptions options, List<BuildResult?> childBuildResults) {
    // Checking of character box is done automatically by the passing of
    // BuildResult, so we don't need to check it here.
    final baseResult = childBuildResults[0]!;
    final skew = isShifty ? baseResult.skew : 0.0;
    Widget accentWidget;
    if (!isStretchy) {
      Widget accentSymbolWidget;
      // Following comment are selected from KaTeX:
      //
      // Before version 0.9, \vec used the combining font glyph U+20D7.
      // But browsers, especially Safari, are not consistent in how they
      // render combining characters when not preceded by a character.
      // So now we use an SVG.
      // If Safari reforms, we should consider reverting to the glyph.
      if (label == '\u2192') {
        // We need non-null baseline. Because ShiftBaseline cannot deal with a
        // baseline distance of null due to Flutter rendering pipeline design.
        accentSymbolWidget = staticSvg('vec', options, needBaseline: true);
      } else {
        final accentRenderConfig = accentRenderConfigs[label];
        if (accentRenderConfig == null || accentRenderConfig.overChar == null) {
          accentSymbolWidget = Container();
        } else {
          accentSymbolWidget = makeBaseSymbol(
            symbol: accentRenderConfig.overChar!,
            variantForm: false,
            atomType: AtomType.ord,
            mode: Mode.text,
            options: options,
          ).widget;
        }
      }

      // Non stretchy accent can not contribute to overall width, thus they must
      // fit exactly with the width even if it means overflow.
      accentWidget = LayoutBuilder(
        builder: (context, constraints) => ResetDimension(
          depth: 0.0, // Cut off xHeight
          width: constraints.minWidth, // Ensure width
          child: ShiftBaseline(
            // \tilde is submerged below baseline in KaTeX fonts
            relativePos: 1.0,
            // Shift baseline up by xHeight
            offset: -options.fontMetrics.xHeight.cssEm.toLpUnder(options),
            child: accentSymbolWidget,
          ),
        ),
      );
    } else {
      // Strechy accent
      accentWidget = LayoutBuilder(
        builder: (context, constraints) {
          // \overline needs a special case, as KaTeX does.
          if (label == '\u00AF') {
            final defaultRuleThickness = options
                .fontMetrics.defaultRuleThickness.cssEm
                .toLpUnder(options);
            return Padding(
              padding: EdgeInsets.only(bottom: 3 * defaultRuleThickness),
              child: Container(
                width: constraints.minWidth,
                height: defaultRuleThickness, // TODO minRuleThickness
                color: options.color,
              ),
            );
          } else {
            final accentRenderConfig = accentRenderConfigs[label];
            if (accentRenderConfig == null ||
                accentRenderConfig.overImageName == null) {
              return Container();
            }
            var svgWidget = strechySvgSpan(
              accentRenderConfig.overImageName!,
              constraints.minWidth,
              options,
            );
            // \horizBrace also needs a special case, as KaTeX does.
            if (label == '\u23de') {
              return Padding(
                padding: EdgeInsets.only(bottom: 0.1.cssEm.toLpUnder(options)),
                child: svgWidget,
              );
            } else {
              return svgWidget;
            }
          }
        },
      );
    }
    return BuildResult(
      options: options,
      italic: baseResult.italic,
      skew: baseResult.skew,
      widget: VList(
        baselineReferenceWidgetIndex: 1,
        children: <Widget>[
          VListElement(
            customCrossSize: (width) =>
                BoxConstraints(minWidth: width - 2 * skew),
            hShift: skew,
            child: accentWidget,
          ),
          // Set min height
          MinDimension(
            minHeight: options.fontMetrics.xHeight.cssEm.toLpUnder(options),
            topPadding: 0,
            child: baseResult.widget,
          ),
        ],
      ),
    );
  }

  @override
  List<MathOptions> computeChildOptions(MathOptions options) =>
      [options.havingCrampedStyle()];

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
  AccentNode updateChildren(List<EquationRowNode> newChildren) =>
      copyWith(base: newChildren[0]);

  @override
  Map<String, Object?> toJson() => super.toJson()
    ..addAll({
      'base': base.toJson(),
      'label': unicodeLiteral(label),
      'isStretchy': isStretchy,
      'isShifty': isShifty,
    });

  AccentNode copyWith({
    EquationRowNode? base,
    String? label,
    bool? isStretchy,
    bool? isShifty,
  }) =>
      AccentNode(
        base: base ?? this.base,
        label: label ?? this.label,
        isStretchy: isStretchy ?? this.isStretchy,
        isShifty: isShifty ?? this.isShifty,
      );
}
