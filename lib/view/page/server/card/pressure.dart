import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:server_box/data/res/chart_palette.dart';
import 'package:server_box/view/page/server/card/metric.dart';

/// How tall the pressure bar is, and its corner.
///
/// Thicker than the 3pt bar it replaced: this one is several colours laid end
/// to end, and at 3 the shorter segments were a pixel of colour rather than a
/// length to read.
const kPressureHeight = 6.0;

/// The colour of [kind]'s stretch of the pressure bar.
///
/// The series colours, and the bar is the one place in a list where a colour
/// says *which reading*: every bar holds the same three in the same order.
/// Nothing on a tile names them; a line does, and so does the strip over the
/// list, in these same colours. Over its line wins, because that is what the
/// bar is looked at for.
Color pressureColor(
  ServerMetricKind kind, {
  required bool over,
  bool stale = false,
}) => stale
    ? Colors.grey
    : over
    ? StatePalette.warn
    : switch (kind) {
        ServerMetricKind.mem => ChartPalette.mem,
        ServerMetricKind.disk => ChartPalette.diskRead,
        _ => ChartPalette.cpu,
      };

/// Everything a machine is carrying — or a list of them — end to end in one
/// bar. See [pressureOf], which is what the lengths are.
///
/// One widget for the tile, the line and the strip over the list, because it
/// is one reading wherever it is drawn: the same three in the same order at
/// the same weights, so a bar over the list can be read against the bars in
/// it.
///
/// The slot is kept even with nothing in it, so a machine that is down does
/// not make its tile a different height from the rest.
class PressureBar extends StatelessWidget {
  const PressureBar({super.key, required this.segments, this.stale = false});

  final List<ServerPressureSegment> segments;

  /// A connection that is up and no longer sampling. The lengths stay exactly
  /// as they were — the last reading is still the most recent thing known
  /// about the machine — and the colours go, which is the half that has
  /// stopped being true.
  final bool stale;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(kPressureHeight),
      child: Container(
        height: kPressureHeight,
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        // A machine carrying everything at once runs past the end and is
        // clipped there, which is the reading it deserves: full is full, and
        // the bar that answers "which one is under load" does not owe a
        // distinction between loaded and more loaded.
        child: Row(
          children: [
            for (final segment in segments)
              Flexible(
                flex: (segment.share * 1000).round(),
                child: Container(
                  color: pressureColor(
                    segment.kind,
                    over: segment.over,
                    stale: stale,
                  ),
                ),
              ),
            // Whatever is left, as the track. A `Row` holding only the
            // segments would stretch them to the full width.
            Flexible(
              flex: math.max(
                0,
                ((1 - segments.fold(0.0, (a, s) => a + s.share)) * 1000)
                    .round(),
              ),
              child: const SizedBox.shrink(),
            ),
          ],
        ),
      ),
    );
  }
}
