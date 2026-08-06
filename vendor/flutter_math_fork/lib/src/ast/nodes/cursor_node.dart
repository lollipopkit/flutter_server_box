import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

import '../../../ast.dart';
import '../../render/layout/line.dart';
import '../syntax_tree.dart';

/// Node displays vertical bar the size of [MathOptions.fontSize]
/// to replicate a text edit field cursor
class CursorNode extends LeafNode {
  @override
  BuildResult buildWidget(
      MathOptions options, List<BuildResult?> childBuildResults) {
    final baselinePart = 1 - options.fontMetrics.axisHeight / 2;
    final height = options.fontSize * baselinePart * options.sizeMultiplier;
    final baselineDistance = height * baselinePart;
    final cursor = Container(height: height, width: 1.5, color: options.color);
    return BuildResult(
        options: options,
        widget: _BaselineDistance(
          baselineDistance: baselineDistance,
          child: cursor,
        ));
  }

  @override
  AtomType get leftType => AtomType.ord;

  @override
  Mode get mode => Mode.text;

  @override
  AtomType get rightType => AtomType.ord;

  @override
  bool shouldRebuildWidget(MathOptions oldOptions, MathOptions newOptions) =>
      false;
}

/// This render object overrides the return value of
/// [RenderProxyBox.computeDistanceToActualBaseline]
///
/// Used to align [CursorNode] properly in a [RenderLine] in respect to symbols
class _BaselineDistance extends SingleChildRenderObjectWidget {
  const _BaselineDistance({
    Key? key,
    required this.baselineDistance,
    Widget? child,
  }) : super(key: key, child: child);

  final double baselineDistance;

  @override
  _BaselineDistanceBox createRenderObject(BuildContext context) =>
      _BaselineDistanceBox(baselineDistance);
}

class _BaselineDistanceBox extends RenderProxyBox {
  _BaselineDistanceBox(this.baselineDistance);

  final double baselineDistance;

  @override
  double? computeDistanceToActualBaseline(TextBaseline baseline) =>
      baselineDistance;
}
