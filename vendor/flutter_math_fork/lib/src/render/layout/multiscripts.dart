import 'dart:math' as math;

import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';
import 'package:tuple/tuple.dart';

import '../../ast/options.dart';
import '../../ast/size.dart';
import '../../ast/style.dart';
import '../../ast/syntax_tree.dart';
import '../../utils/iterable_extensions.dart';
import 'custom_layout.dart';

/// This should be the perfect use case for [CustomMultiChildLayout] and
/// [MultiChildLayoutDelegate]. However, they don't support baseline
/// functionalities. So we have to start from [MultiChildRenderObjectWidget].
///
/// This should also be a great showcase for [LayoutId], but the generic
/// parameter prevents us to use or extend from [LayoutId].
///
/// This should also be a great showcase for [MultiChildLayoutParentData],
/// but the lack of generic ([Object] type) is undesirable.

enum _ScriptPos {
  base,
  sub,
  sup,
  presub,
  presup,
}

class Multiscripts extends StatelessWidget {
  const Multiscripts({
    Key? key,
    this.alignPostscripts = false,
    required this.isBaseCharacterBox,
    required this.baseResult,
    this.subResult,
    this.supResult,
    this.presubResult,
    this.presupResult,
  }) : super(key: key);

  final bool alignPostscripts;
  final bool isBaseCharacterBox;

  final BuildResult baseResult;
  final BuildResult? subResult;
  final BuildResult? supResult;
  final BuildResult? presubResult;
  final BuildResult? presupResult;

  @override
  Widget build(BuildContext context) => CustomLayout(
        delegate: MultiscriptsLayoutDelegate(
          alignPostscripts: alignPostscripts,
          italic: baseResult.italic,
          isBaseCharacterBox: isBaseCharacterBox,
          baseOptions: baseResult.options,
          subOptions: subResult?.options,
          supOptions: supResult?.options,
          presubOptions: presubResult?.options,
          presupOptions: presupResult?.options,
        ),
        children: <Widget>[
          CustomLayoutId(
            id: _ScriptPos.base,
            child: baseResult.widget,
          ),
          if (subResult != null)
            CustomLayoutId(
              id: _ScriptPos.sub,
              child: subResult!.widget,
            ),
          if (supResult != null)
            CustomLayoutId(
              id: _ScriptPos.sup,
              child: supResult!.widget,
            ),
          if (presubResult != null)
            CustomLayoutId(
              id: _ScriptPos.presub,
              child: presubResult!.widget,
            ),
          if (presupResult != null)
            CustomLayoutId(
              id: _ScriptPos.presup,
              child: presupResult!.widget,
            ),
        ],
      );
}

// Superscript and subscripts are handled in the TeXbook on page
// 445-446, rules 18(a-f).
class MultiscriptsLayoutDelegate extends IntrinsicLayoutDelegate<_ScriptPos> {
  final bool alignPostscripts;
  final double italic;

  final bool isBaseCharacterBox;
  final MathOptions baseOptions;
  final MathOptions? subOptions;
  final MathOptions? supOptions;
  final MathOptions? presubOptions;
  final MathOptions? presupOptions;

  MultiscriptsLayoutDelegate({
    required this.alignPostscripts,
    required this.italic,
    required this.isBaseCharacterBox,
    required this.baseOptions,
    required this.subOptions,
    required this.supOptions,
    required this.presubOptions,
    required this.presupOptions,
  });

  var baselineDistance = 0.0;

  @override
  double computeDistanceToActualBaseline(
          TextBaseline baseline, Map<_ScriptPos, RenderBox> childrenTable) =>
      baselineDistance;
  // // This will trigger Flutter assertion error
  // nPlus(
  //   childrenTable[_ScriptPos.base].offset.dy,
  //   childrenTable[_ScriptPos.base]
  //       .getDistanceToBaseline(baseline, onlyReal: true),
  // );

  @override
  AxisConfiguration<_ScriptPos> performHorizontalIntrinsicLayout({
    required Map<_ScriptPos, double> childrenWidths,
    bool isComputingIntrinsics = false,
  }) {
    final baseSize = childrenWidths[_ScriptPos.base]!;
    final subSize = childrenWidths[_ScriptPos.sub];
    final supSize = childrenWidths[_ScriptPos.sup];
    final presubSize = childrenWidths[_ScriptPos.presub];
    final presupSize = childrenWidths[_ScriptPos.presup];

    final scriptSpace = 0.5.pt.toLpUnder(baseOptions);

    final extendedSubSize = subSize != null ? subSize + scriptSpace : 0.0;
    final extendedSupSize = supSize != null ? supSize + scriptSpace : 0.0;
    final extendedPresubSize =
        presubSize != null ? presubSize + scriptSpace : 0.0;
    final extendedPresupSize =
        presupSize != null ? presupSize + scriptSpace : 0.0;

    final postscriptWidth = math.max(
      extendedSupSize,
      -(alignPostscripts ? 0.0 : italic) + extendedSubSize,
    );
    final prescriptWidth = math.max(extendedPresubSize, extendedPresupSize);

    final fullSize = postscriptWidth + prescriptWidth + baseSize;

    return AxisConfiguration(
      size: fullSize,
      offsetTable: {
        _ScriptPos.base: prescriptWidth,
        _ScriptPos.sub:
            prescriptWidth + baseSize - (alignPostscripts ? 0.0 : italic),
        _ScriptPos.sup: prescriptWidth + baseSize,
        if (presubSize != null) _ScriptPos.presub: prescriptWidth - presubSize,
        if (presupSize != null) _ScriptPos.presup: prescriptWidth - presupSize,
      },
    );
  }

  @override
  AxisConfiguration<_ScriptPos> performVerticalIntrinsicLayout({
    required Map<_ScriptPos, double> childrenHeights,
    required Map<_ScriptPos, double> childrenBaselines,
    bool isComputingIntrinsics = false,
  }) {
    final baseSize = childrenHeights[_ScriptPos.base]!;
    final subSize = childrenHeights[_ScriptPos.sub];
    final supSize = childrenHeights[_ScriptPos.sup];
    final presubSize = childrenHeights[_ScriptPos.presub];
    final presupSize = childrenHeights[_ScriptPos.presup];

    final baseHeight = childrenBaselines[_ScriptPos.base]!;
    final subHeight = childrenBaselines[_ScriptPos.sub];
    final supHeight = childrenBaselines[_ScriptPos.sup];
    final presubHeight = childrenBaselines[_ScriptPos.presub];
    final presupHeight = childrenBaselines[_ScriptPos.presup];

    final postscriptRes = calculateUV(
      base: _ScriptUvConf(baseSize, baseHeight, baseOptions),
      sub: subSize != null
          ? _ScriptUvConf(subSize, subHeight!, subOptions!)
          : null,
      sup: supSize != null
          ? _ScriptUvConf(supSize, supHeight!, supOptions!)
          : null,
      isBaseCharacterBox: isBaseCharacterBox,
    );

    final prescriptRes = calculateUV(
      base: _ScriptUvConf(baseSize, baseHeight, baseOptions),
      sub: presubSize != null
          ? _ScriptUvConf(presubSize, presubHeight!, presubOptions!)
          : null,
      sup: presupSize != null
          ? _ScriptUvConf(presupSize, presupHeight!, presupOptions!)
          : null,
      isBaseCharacterBox: isBaseCharacterBox,
    );

    final subShift = postscriptRes.item2;
    final supShift = postscriptRes.item1;
    final presubShift = prescriptRes.item2;
    final presupShift = prescriptRes.item1;

    // Rule 18f
    final height = [
      baseHeight,
      if (subHeight != null) subHeight - subShift,
      if (supHeight != null) supHeight + supShift,
      if (presubHeight != null) presubHeight - presubShift,
      if (presupHeight != null) presupHeight + presupShift,
    ].max;

    final depth = [
      baseSize - baseHeight,
      if (subHeight != null) subSize! - subHeight + subShift,
      if (supHeight != null) supSize! - supHeight - supShift,
      if (presubHeight != null) presubSize! - presubHeight + presubShift,
      if (presupHeight != null) presupSize! - presupHeight - presupShift,
    ].max;

    if (!isComputingIntrinsics) {
      baselineDistance = height;
    }

    return AxisConfiguration(
      size: height + depth,
      offsetTable: {
        _ScriptPos.base: height - baseHeight,
        if (subHeight != null) _ScriptPos.sub: height + subShift - subHeight,
        if (supHeight != null) _ScriptPos.sup: height - supShift - supHeight,
        if (presubHeight != null)
          _ScriptPos.presub: height + presubShift - presubHeight,
        if (presupHeight != null)
          _ScriptPos.presup: height - presupShift - presupHeight,
      },
    );
  }
}

class _ScriptUvConf {
  final double fullHeight;
  final double baseline;
  final MathOptions options;

  const _ScriptUvConf(this.fullHeight, this.baseline, this.options);
}

Tuple2<double, double> calculateUV({
  required _ScriptUvConf base,
  _ScriptUvConf? sub,
  _ScriptUvConf? sup,
  required bool isBaseCharacterBox,
}) {
  final metrics = base.options.fontMetrics;
  final baseOptions = base.options;

  // TexBook Rule 18a
  final h = base.baseline;
  final d = base.fullHeight - h;
  var u = 0.0;
  var v = 0.0;
  if (sub != null) {
    final r = sub.options.fontMetrics.subDrop.cssEm.toLpUnder(sub.options);
    v = isBaseCharacterBox ? 0 : d + r;
  }
  if (sup != null) {
    final q = sup.options.fontMetrics.supDrop.cssEm.toLpUnder(sup.options);
    u = isBaseCharacterBox ? 0 : h - q;
  }

  if (sup == null && sub != null) {
    // Rule 18b
    final hx = sub.baseline;
    v = math.max(
      v,
      math.max(
        metrics.sub1.cssEm.toLpUnder(baseOptions),
        hx - 0.8 * metrics.xHeight.cssEm.toLpUnder(baseOptions),
      ),
    );
  } else if (sup != null) {
    // Rule 18c
    final dx = sup.fullHeight - sup.baseline;
    final p = (baseOptions.style == MathStyle.display
            ? metrics.sup1
            : (baseOptions.style.cramped ? metrics.sup3 : metrics.sup2))
        .cssEm
        .toLpUnder(baseOptions);

    u = math.max(
      u,
      math.max(
        p,
        dx + 0.25 * metrics.xHeight.cssEm.toLpUnder(baseOptions),
      ),
    );
    // Rule 18d
    if (sub != null) {
      v = math.max(v, metrics.sub2.cssEm.toLpUnder(baseOptions));
      // Rule 18e
      final theta = metrics.defaultRuleThickness.cssEm.toLpUnder(baseOptions);
      final hy = sub.baseline;
      if ((u - dx) - (hy - v) < 4 * theta) {
        v = 4 * theta - u + dx + hy;
        final psi =
            0.8 * metrics.xHeight.cssEm.toLpUnder(baseOptions) - (u - dx);
        if (psi > 0) {
          u += psi;
          v -= psi;
        }
      }
    }
  }
  return Tuple2(u, v);
}
