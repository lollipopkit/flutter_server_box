import 'package:flutter/widgets.dart';

import '../../render/layout/min_dimension.dart';
import '../../render/layout/vlist.dart';
import '../options.dart';
import '../size.dart';
import '../style.dart';
import '../syntax_tree.dart';

/// Over node.
///
/// Examples: `\underset`
class OverNode extends SlotableNode<EquationRowNode> {
  /// Base where the over node is applied upon.
  final EquationRowNode base;

  /// Argument above the base.
  final EquationRowNode above;

  /// Special flag for `\stackrel`
  final bool stackRel;

  OverNode({
    required this.base,
    required this.above,
    this.stackRel = false,
  });

  // KaTeX's corresponding code is in /src/functions/utils/assembleSubSup.js
  @override
  BuildResult buildWidget(
      MathOptions options, List<BuildResult?> childBuildResults) {
    final spacing = options.fontMetrics.bigOpSpacing5.cssEm.toLpUnder(options);
    return BuildResult(
      options: options,
      widget: Padding(
        padding: EdgeInsets.only(top: spacing),
        child: VList(
          baselineReferenceWidgetIndex: 1,
          children: <Widget>[
            // TexBook Rule 13a
            MinDimension(
              minDepth:
                  options.fontMetrics.bigOpSpacing3.cssEm.toLpUnder(options),
              bottomPadding:
                  options.fontMetrics.bigOpSpacing1.cssEm.toLpUnder(options),
              child: childBuildResults[1]!.widget,
            ),
            childBuildResults[0]!.widget,
          ],
        ),
      ),
    );
  }

  @override
  List<MathOptions> computeChildOptions(MathOptions options) => [
        options,
        options.havingStyle(options.style.sup()),
      ];

  @override
  List<EquationRowNode> computeChildren() => [base, above];

  @override
  AtomType get leftType => stackRel
      ? AtomType.rel
      : AtomType.ord; // TODO: they should align with binrelclass with base

  @override
  AtomType get rightType => stackRel
      ? AtomType.rel
      : AtomType.ord; // TODO: they should align with binrelclass with base

  @override
  bool shouldRebuildWidget(MathOptions oldOptions, MathOptions newOptions) =>
      false;

  @override
  OverNode updateChildren(List<EquationRowNode> newChildren) =>
      copyWith(base: newChildren[0], above: newChildren[1]);

  @override
  Map<String, Object?> toJson() => super.toJson()
    ..addAll({
      'base': base.toJson(),
      'above': above.toJson(),
      if (stackRel != false) 'stackRel': stackRel,
    });

  OverNode copyWith({
    EquationRowNode? base,
    EquationRowNode? above,
    bool? stackRel,
  }) =>
      OverNode(
        base: base ?? this.base,
        above: above ?? this.above,
        stackRel: stackRel ?? this.stackRel,
      );
}
