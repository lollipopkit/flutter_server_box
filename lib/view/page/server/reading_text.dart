import 'dart:ui' show FontFeature;

import 'package:fl_lib/fl_lib.dart';

/// Figures that line up down a column: every digit the same width, so the
/// numbers on six cards, or on forty lines, can be compared down a page.
const kTabularFigures = [FontFeature.tabularFigures()];

/// How a reading is written, wherever it is written.
///
/// A card's rows, the detail page's headline and stats, the overview strip and
/// every chart axis say the same number the same way. The card grows into the
/// page, so a figure written two ways would change at the handover.
abstract final class ReadingFmt {
  /// A share, to one decimal, or a dash before anything has been measured.
  static String pct(double? v) =>
      v == null ? '--' : '${(v * 10).round() / 10}%';

  /// A rate, or a dash before there are two samples to take one from.
  static String rate(double? bytesPerSec) =>
      bytesPerSec == null ? '--' : '${bytesPerSec.bytes2Str}/s';

  /// A rate on an axis, where there is always a value.
  static String rateAxis(double bytesPerSec) => '${bytesPerSec.bytes2Str}/s';

  /// Trailing `.0` dropped: with round ticks the axis reads 0/25/50/75/100,
  /// and the decimal was only ever noise there.
  static String temp(double celsius) =>
      '${celsius.toStringAsFixed(celsius == celsius.roundToDouble() ? 0 : 1)}°C';
}
