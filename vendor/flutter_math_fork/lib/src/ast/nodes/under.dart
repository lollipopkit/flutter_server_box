import 'package:flutter/widgets.dart';

import '../../render/layout/min_dimension.dart';
import '../../render/layout/vlist.dart';
import '../options.dart';
import '../size.dart';
import '../style.dart';
import '../syntax_tree.dart';

/// Under node.
///
/// Examples: `\underset`
class UnderNode extends SlotableNode {
  /// Base where the under node is applied upon.
  final EquationRowNode base;

  /// Argumentn below the base.
  final EquationRowNode below;
  UnderNode({
    required this.base,
    required this.below,
  });

  // KaTeX's corresponding code is in /src/functions/utils/assembleSubSup.js
  @override
  BuildResult buildWidget(
      MathOptions options, List<BuildResult?> childBuildResults) {
    final spacing = options.fontMetrics.bigOpSpacing5.cssEm.toLpUnder(options);
    return BuildResult(
      italic: 0.0,
      options: options,
      widget: Padding(
        padding: EdgeInsets.only(bottom: spacing),
        child: VList(
          baselineReferenceWidgetIndex: 0,
          children: <Widget>[
            childBuildResults[0]!.widget,
            // TexBook Rule 13a
            MinDimension(
              minHeight:
                  options.fontMetrics.bigOpSpacing4.cssEm.toLpUnder(options),
              topPadding:
                  options.fontMetrics.bigOpSpacing2.cssEm.toLpUnder(options),
              child: childBuildResults[1]!.widget,
            ),
          ],
        ),
      ),
    );
  }

  @override
  List<MathOptions> computeChildOptions(MathOptions options) => [
        options,
        options.havingStyle(options.style.sub()),
      ];

  @override
  List<EquationRowNode> computeChildren() => [base, below];

  @override
  AtomType get leftType => AtomType.ord;

  @override
  AtomType get rightType => AtomType.ord;

  @override
  bool shouldRebuildWidget(MathOptions oldOptions, MathOptions newOptions) =>
      false;

  @override
  UnderNode updateChildren(List<EquationRowNode> newChildren) =>
      copyWith(base: newChildren[0], below: newChildren[1]);

  @override
  Map<String, Object?> toJson() => super.toJson()
    ..addAll({
      'base': base.toJson(),
      'below': below.toJson(),
    });

  UnderNode copyWith({
    EquationRowNode? base,
    EquationRowNode? below,
  }) =>
      UnderNode(
        base: base ?? this.base,
        below: below ?? this.below,
      );
}
