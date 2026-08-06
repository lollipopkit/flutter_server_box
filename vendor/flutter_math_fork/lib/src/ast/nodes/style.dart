import '../options.dart';
import '../syntax_tree.dart';

/// Node to denote all kinds of style changes.
class StyleNode extends TransparentNode {
  final List<GreenNode> children;

  /// The difference of [MathOptions].
  final OptionsDiff optionsDiff;

  StyleNode({
    required this.children,
    required this.optionsDiff,
  });

  @override
  List<MathOptions> computeChildOptions(MathOptions options) =>
      List.filled(children.length, options.merge(optionsDiff), growable: false);

  @override
  bool shouldRebuildWidget(MathOptions oldOptions, MathOptions newOptions) =>
      false;

  @override
  ParentableNode<GreenNode> updateChildren(List<GreenNode> newChildren) =>
      copyWith(children: newChildren);

  @override
  Map<String, Object?> toJson() => super.toJson()
    ..addAll({
      'children': children.map((e) => e.toJson()).toList(growable: false),
      'optionsDiff': optionsDiff.toString(),
    });

  StyleNode copyWith({
    List<GreenNode>? children,
    OptionsDiff? optionsDiff,
  }) =>
      StyleNode(
        children: children ?? this.children,
        optionsDiff: optionsDiff ?? this.optionsDiff,
      );
}
