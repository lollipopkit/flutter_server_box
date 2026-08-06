import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/widgets.dart';

import '../../render/layout/reset_baseline.dart';
import '../options.dart';
import '../size.dart';
import '../syntax_tree.dart';
import '../types.dart';

/// Space node. Also used for equation alignment.
class SpaceNode extends LeafNode {
  /// Height.
  final Measurement height;

  /// Width.
  final Measurement width;

  /// Depth.
  final Measurement depth;

  /// Vertical shift.
  ///
  ///  For the sole purpose of `\rule`
  final Measurement shift;

  /// Break penalty for a manual line breaking command.
  ///
  /// Related TeX command: \nobreak, \allowbreak, \penalty<number>.
  ///
  /// Should be null for normal space commands.
  final int? breakPenalty;

  /// Whether to fill with text color.
  final bool fill;

  final Mode mode;

  final bool alignerOrSpacer;
  SpaceNode({
    required this.height,
    required this.width,
    this.shift = Measurement.zero,
    this.depth = Measurement.zero,
    this.breakPenalty,
    this.fill = false,
    // this.background,
    required this.mode,
    this.alignerOrSpacer = false,
  });

  SpaceNode.alignerOrSpacer()
      : height = Measurement.zero,
        width = Measurement.zero,
        shift = Measurement.zero,
        depth = Measurement.zero,
        breakPenalty = null,
        fill = true,
        // background = null,
        mode = Mode.math,
        alignerOrSpacer = true;

  @override
  BuildResult buildWidget(
      MathOptions options, List<BuildResult?> childBuildResults) {
    if (alignerOrSpacer == true) {
      return BuildResult(
        options: options,
        widget: Container(height: 0.0),
      );
    }

    final height = this.height.toLpUnder(options);
    final depth = this.depth.toLpUnder(options);
    final width = this.width.toLpUnder(options);
    final shift = this.shift.toLpUnder(options);
    final topMost = math.max(height, -depth) + shift;
    final bottomMost = math.min(height, -depth) + shift;
    return BuildResult(
      options: options,
      widget: ResetBaseline(
        height: topMost,
        child: Container(
          color: fill ? options.color : null,
          height: topMost - bottomMost,
          width: math.max(0.0, width),
        ),
      ),
    );
  }

  @override
  AtomType get leftType => AtomType.spacing;

  @override
  AtomType get rightType => AtomType.spacing;

  @override
  bool shouldRebuildWidget(MathOptions oldOptions, MathOptions newOptions) =>
      oldOptions.sizeMultiplier != newOptions.sizeMultiplier;

  @override
  Map<String, Object?> toJson() => super.toJson()
    ..addAll({
      'mode': mode.toString(),
      'height': height.toString(),
      'width': width.toString(),
      if (depth != Measurement.zero) 'depth': depth.toString(),
      if (shift != Measurement.zero) 'shift': shift.toString(),
      // if (noBreak != false) 'noBreak': noBreak,
      if (breakPenalty != null) 'breakPenalty': breakPenalty,
      if (fill != false) 'fill': fill,
      if (alignerOrSpacer != false) 'alignerOrSpacer': alignerOrSpacer,
    });
}
