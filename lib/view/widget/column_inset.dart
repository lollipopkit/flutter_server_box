import 'dart:math' as math;

import 'package:fl_lib/fl_lib.dart';

/// The side padding that centres a [column]-wide column in [width], and never
/// less than [min].
double columnInset(
  double width, {
  double column = PageColumns.columnWidth,
  double min = 17,
}) => math.max((width - column) / 2, min);
