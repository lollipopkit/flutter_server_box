import 'package:flutter/widgets.dart';

import '../../ast/options.dart';
import '../../ast/size.dart';
import '../layout/reset_baseline.dart';
import 'svg_geomertry.dart';
import 'svg_string.dart';

const svgData = {
  //   path, width, height
  'vec': [0.471, 0.714], // values from the font glyph
  'oiintSize1': [0.957, 0.499], // oval to overlay the integrand
  'oiintSize2': [1.472, 0.659],
  'oiiintSize1': [1.304, 0.499],
  'oiiintSize2': [1.98, 0.659],
};

Widget staticSvg(String name, MathOptions options,
    {bool needBaseline = false}) {
  final dimen = svgData[name];
  if (dimen == null) {
    throw ArgumentError.value(name, 'name', 'Invalid static svg name');
  }
  final width = dimen[0];
  final height = dimen[1];
  final viewPortWidth = width.cssEm.toLpUnder(options);
  final viewPortHeight = height.cssEm.toLpUnder(options);

  final svgWidget = svgWidgetFromPath(
    svgPaths[name]!,
    Size(viewPortWidth, viewPortHeight),
    Rect.fromLTWH(0, 0, 1000 * width, 1000 * height),
    options.color,
  );
  if (needBaseline) {
    return ResetBaseline(
      height: viewPortHeight,
      child: svgWidget,
    );
  }
  return svgWidget;
}
