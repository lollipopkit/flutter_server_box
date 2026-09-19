import 'dart:math' as math;

import 'package:flutter/material.dart';

/// The window of one reading, drawn as bars.
///
/// A shape rather than a chart: there is no axis, no tooltip and no legend,
/// because what a card is read for is whether a machine is climbing — the
/// numbers for that are already on the rows below it. The detail page's chart
/// is the one with the axis on it.
///
/// Bars rather than a line: a line through a window with gaps in it has to
/// either join across them, which draws a machine that was idle, or break,
/// which at this size is a line with specks missing. A bar per sample simply
/// is not drawn where there is no sample.
class Sparkline extends StatelessWidget {
  const Sparkline({
    super.key,
    required this.samples,
    required this.color,
    this.height = 44,
    this.max,
  });

  /// Oldest first. A poll that measured nothing holds null.
  final List<double?> samples;

  final Color color;
  final double height;

  /// The top of the scale. Null takes it from the window, which is what a rate
  /// needs — a percentage passes 100 so that two cards are comparable.
  final double? max;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: height,
      width: double.infinity,
      child: CustomPaint(
        painter: _SparkPainter(
          samples: samples,
          color: color,
          // A window with nothing in it still draws its floor: a card that
          // leaves the space blank reads as broken rather than as new, and the
          // bars arrive into a shape that was already there.
          base: Theme.of(context).colorScheme.surfaceContainerHighest,
          max: max,
        ),
      ),
    );
  }
}

class _SparkPainter extends CustomPainter {
  const _SparkPainter({
    required this.samples,
    required this.color,
    required this.base,
    required this.max,
  });

  final List<double?> samples;
  final Color color;
  final Color base;
  final double? max;

  /// The design's bar: as wide as the space allows, never under 2, with 2
  /// between them.
  static const _minBar = 2.0;
  static const _gap = 2.0;
  static const _radius = Radius.circular(2);

  @override
  void paint(Canvas canvas, Size size) {
    if (size.width <= 0 || size.height <= 0) return;

    // The floor, which is also the whole of an empty window.
    final floor = Paint()..color = base;
    canvas.drawRRect(
      RRect.fromLTRBR(0, size.height - 1, size.width, size.height, _radius),
      floor,
    );
    if (samples.isEmpty) return;

    // How many of the newest samples fit. The window is dropped from the left
    // rather than squeezed: a bar under two pixels is not a bar.
    final fits = ((size.width + _gap) / (_minBar + _gap)).floor();
    if (fits <= 0) return;
    final shown = samples.length <= fits
        ? samples
        : samples.sublist(samples.length - fits);

    final barW = (size.width - _gap * (shown.length - 1)) / shown.length;
    if (barW <= 0) return;

    var top = max ?? 0;
    if (max == null) {
      for (final v in shown) {
        if (v != null && v > top) top = v;
      }
      if (top <= 0) return;
    }

    final paint = Paint()..color = color;
    for (var i = 0; i < shown.length; i++) {
      final v = shown[i];
      if (v == null || v <= 0) continue;
      // Clamped so a reading past the scale — a rate that spiked after the
      // window's peak was taken — draws full height instead of overshooting.
      final h = math.max(1.0, math.min(1.0, v / top) * size.height);
      final x = i * (barW + _gap);
      canvas.drawRRect(
        RRect.fromLTRBAndCorners(
          x,
          size.height - h,
          x + barW,
          size.height,
          topLeft: _radius,
          topRight: _radius,
        ),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(_SparkPainter old) =>
      old.color != color ||
      old.base != base ||
      old.max != max ||
      !_same(old.samples, samples);

  static bool _same(List<double?> a, List<double?> b) {
    if (identical(a, b)) return true;
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }
}
