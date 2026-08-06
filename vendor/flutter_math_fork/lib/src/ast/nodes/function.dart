import '../../render/layout/line.dart';
import '../options.dart';
import '../spacing.dart';
import '../syntax_tree.dart';

/// Function node
///
/// Examples: `\sin`, `\lim`, `\operatorname`
class FunctionNode extends SlotableNode<EquationRowNode> {
  /// Name of the function.
  final EquationRowNode functionName;

  /// Argument of the function.
  final EquationRowNode argument;

  FunctionNode({
    required this.functionName,
    required this.argument,
  });

  @override
  BuildResult buildWidget(
          MathOptions options, List<BuildResult?> childBuildResults) =>
      BuildResult(
        options: options,
        widget: Line(children: [
          LineElement(
            trailingMargin:
                getSpacingSize(AtomType.op, argument.leftType, options.style)
                    .toLpUnder(options),
            child: childBuildResults[0]!.widget,
          ),
          LineElement(
            trailingMargin: 0.0,
            child: childBuildResults[1]!.widget,
          ),
        ]),
      );

  @override
  List<MathOptions> computeChildOptions(MathOptions options) =>
      List.filled(2, options, growable: false);

  @override
  List<EquationRowNode> computeChildren() => [functionName, argument];

  @override
  AtomType get leftType => AtomType.op;

  @override
  AtomType get rightType => argument.rightType;

  @override
  bool shouldRebuildWidget(MathOptions oldOptions, MathOptions newOptions) =>
      false;

  @override
  FunctionNode updateChildren(List<EquationRowNode> newChildren) =>
      copyWith(functionName: newChildren[0], argument: newChildren[1]);

  @override
  Map<String, Object?> toJson() => super.toJson()
    ..addAll({
      'functionName': functionName.toJson(),
      'argument': argument.toJson(),
    });

  FunctionNode copyWith({
    EquationRowNode? functionName,
    EquationRowNode? argument,
  }) =>
      FunctionNode(
        functionName: functionName ?? this.functionName,
        argument: argument ?? this.argument,
      );
}
