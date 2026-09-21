import 'dart:math' as math;

import 'package:fl_chart/fl_chart.dart';
import 'package:fl_lib/fl_lib.dart';
import 'package:flutter/material.dart';

/// What a reading's history is drawn as, wherever it is drawn.
///
/// Pulled out of the detail page so that the card in the list can draw the
/// same chart: the card grows into that page, and a bar sparkline cannot
/// become a line chart without the change being the thing you notice. One
/// widget, one axis, one set of lines — what differs between the two is how
/// much of it is faded in.
/// A stretch of the window with nothing in it, and why.
///
/// The axis is the window that was asked for, so a window the samples do not
/// fill has to say so rather than let the line span it: a chart that joins
/// 09:37 to now through a four-minute hole draws a machine that was idle, and
/// one that compresses three stored hours into a 24-hour axis lies about what
/// it is showing.
typedef ChartBand = ({int from, int to, String label});

/// Keeps [child] as it was for as long as [hold].
///
/// For a subtree that is expensive to build and has nothing to say while
/// something else is moving. A chart is the case this exists for: while the
/// card in the list grows into the page, what is around the chart changes on
/// every frame, and the chart is handed a new window each time because its
/// axis runs to *now*. Rebuilding it for that means walking every sample, and
/// then handing fl_chart a new `LineChartData` to diff, sixty times a second —
/// for a line that has not changed and a window that has moved by a third of a
/// second.
///
/// Keeps the last stable child while the parent transition is in progress.
///
/// The child must be captured at the transition boundary. Capturing one build
/// early leaves stale chart content visible during the reverse animation.
class Held extends StatefulWidget {
  const Held({super.key, required this.hold, required this.child});

  final bool hold;
  final Widget child;

  @override
  State<Held> createState() => _HeldState();
}

class _HeldState extends State<Held> {
  late Widget _held = widget.child;

  @override
  void didUpdateWidget(Held old) {
    super.didUpdateWidget(old);
    if (!widget.hold || !old.hold) _held = widget.child;
  }

  @override
  Widget build(BuildContext context) => _held;
}

/// One chart: the series drawn on its shared axis, and how to label that axis.
class MetricChartSpec {
  final List<HistorySeries> series;
  final String Function(double) format;

  /// The instant of each sample, shared by every series because they are
  /// index-aligned by construction. Empty plots against the sample index,
  /// which is what a chart with no window to honour wants.
  final List<int> times;

  /// The window the axis covers, whether or not the samples reach its edges.
  /// Null takes the extent of the data, as a chart with no [times] must.
  final ({int from, int to})? window;

  /// The stretches of [window] no sample falls in.
  final List<ChartBand> bands;

  /// How tall the plot is, which the focus card decides by how much room the
  /// window has: a shape is only readable in so little height.
  final double height;

  /// Whether [height] is the whole block rather than the plot.
  ///
  /// The focus card draws one metric at a time and the metrics do not agree on
  /// how many lines they have — a legend under two series, none under one — so
  /// without this the card changed height as the reader moved between them.
  /// Filling takes the difference out of the plot instead.
  final bool fill;

  /// Whether the values are byte-based, so the axis should step in multiples
  /// of 1024 rather than of 10 — see [niceAxis]
  final bool binaryScale;

  /// How much of the chart's own chrome is drawn: the scale down the left,
  /// the lines across, the room above and below that its outermost labels
  /// hang into, and the touch that puts a value under the pointer.
  ///
  /// 0 is the same line with none of it, which is what a chart the height of
  /// two lines of text can show — five tick labels in 44 points is a smear.
  /// Anything between is the one growing into the other: the gutter is a
  /// width, so the plot narrows into it rather than jumping when it appears.
  ///
  /// The scale itself does not change with this. What the line is drawn
  /// against is the same at both ends, or the card and the page would be two
  /// different readings of the same numbers.
  final double axis;

  const MetricChartSpec({
    required this.series,
    required this.format,
    this.times = const [],
    this.window,
    this.bands = const [],
    this.binaryScale = false,
    this.height = 110,
    this.fill = false,
    this.axis = 1,
  });

  bool get hasData => series.any((s) => s.hasSpots);
}

/// One chart plus the legend line carrying each series' latest value —
/// mirrors `monitor/frontend/src/components/LineChart.svelte`.
///
/// The same widget on a card in the list and on the page that card grows into:
/// what changes between them is the height and how much of the chrome is
/// faded in, not what is drawing the line.
class MetricChart extends StatelessWidget {
  const MetricChart(this.spec, {super.key});

  final MetricChartSpec spec;

  @override
  Widget build(BuildContext context) {
    final bars = <LineChartBarData>[];
    for (final s in spec.series) {
      final spots = s.spotsAgainst(spec.times);
      if (spots.isEmpty) continue;
      bars.add(
        LineChartBarData(
          spots: spots,
          isCurved: false,
          barWidth: 1.5,
          isStrokeCapRound: true,
          color: s.color,
          // A lone sample is a point, and there is nothing to draw a line
          // between: with the dots off, the first poll's worth of a machine
          // was a plot with nothing in it, for as long as the second took to
          // arrive. From two on it is the line, and a dot per sample on it
          // would be what is read instead.
          dotData: FlDotData(
            show: spots.length == 1,
            getDotPainter: (_, _, _, _) =>
                FlDotCirclePainter(radius: 2, color: s.color, strokeWidth: 0),
          ),
          belowBarData: BarAreaData(show: false),
        ),
      );
    }
    if (bars.isEmpty) return UIs.placeholder;

    final hasLegend = spec.series.length > 1 && spec.axis >= 1;
    final body = Padding(
      // The extra bottom allowance is only for the axis' own overflow: fl_chart
      // centres the lowest label on the bottom gridline, so roughly half of it
      // hangs outside the plot box. A legend below already absorbs that, and
      // adding the allowance there too left a visible gap under the card.
      //
      // The top keeps the topmost axis label off whatever heading is above it;
      // at 7 the two touched.
      //
      // Nothing at the sides. What this is drawn in has an inset of its own,
      // and 17 more on each was a chart 34 in from the edge of its card with
      // a gutter on top of that — a fifth of a phone's width spent on holding
      // the line away from a heading it lines up with better.
      padding: EdgeInsets.lerp(
        EdgeInsets.zero,
        EdgeInsets.fromLTRB(0, 15, 0, hasLegend ? 0 : 15),
        spec.axis.clamp(0.0, 1.0),
      )!,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          () {
            final plot = buildHistoryLineChart(
              bars,
              series: spec.series,
              format: spec.format,
              binaryScale: spec.binaryScale,
              window: spec.window,
              bands: spec.bands,
              axis: spec.axis.clamp(0.0, 1.0),
            );
            return spec.fill
                ? Expanded(child: plot)
                : SizedBox(height: spec.height, child: plot);
          }(),
          // Only worth drawing when there is something to tell apart. A lone
          // line needs no key: the card already names its subject, and the
          // value is a touch away in the tooltip.
          if (hasLegend) ...[
            UIs.height13,
            Wrap(
              spacing: 13,
              runSpacing: 3,
              children: [
                for (final s in spec.series)
                  if (s.latest != null)
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 7,
                          height: 7,
                          decoration: BoxDecoration(
                            color: s.color,
                            shape: BoxShape.circle,
                          ),
                        ),
                        UIs.width7,
                        Text(
                          '${s.label} ${spec.format(s.latest!)}',
                          style: UIs.text12Grey,
                        ),
                      ],
                    ),
              ],
            ),
          ],
        ],
      ),
    );
    return spec.fill ? SizedBox(height: spec.height, child: body) : body;
  }
}


/// One line. Reads straight off a [StatusHistory] ring buffer, whose gaps are
/// `null` for "not measured at that sample" — those points are skipped rather
/// than plotted as 0, so an interface that only just appeared doesn't drag the
/// line down to the axis.
class HistorySeries {
  final String label;
  final Color color;
  final List<double?> values;

  const HistorySeries(this.label, this.color, this.values);

  /// Whether there is anything to draw, which is what every caller asking for
  /// [spots] was really asking.
  bool get hasSpots => values.any((e) => e != null);

  /// The points, against [times] where the chart has a window to honour and
  /// against the sample index where it does not.
  ///
  /// A sample with no instant is dropped rather than placed at 0: the two
  /// lists are built together and a mismatch means the buffer moved under the
  /// build, not that the reading happened at the epoch.
  List<FlSpot> spotsAgainst(List<int> times) => [
    for (var i = 0; i < values.length; i++)
      if (values[i] case final v?)
        if (times.isEmpty)
          FlSpot(i.toDouble(), v)
        else if (i < times.length)
          FlSpot(times[i].toDouble(), v),
  ];

  double? get latest {
    for (var i = values.length - 1; i >= 0; i--) {
      final v = values[i];
      if (v != null) return v;
    }
    return null;
  }
}

/// The axis of a chart of what this app watched itself: from the first reading
/// it draws to the last sample taken.
///
/// It ran from the first *sample* to the clock, and a line reached neither
/// end. The left was a poll short because a reading that is a difference has
/// none at the first sample — CPU is the share of the counters between two
/// reads — and the right was short by however long ago the last sample was
/// taken: up to a poll, and for an agent its collection cycle plus whatever
/// the two clocks disagree by. Neither says anything about the machine, and
/// both are a share of the window that is largest exactly when the window is
/// shortest: a fifth of the chart for a machine connected ten seconds ago.
///
/// [until] is the clock, given once the readings have stopped. That distance
/// is the one worth seeing, and it is the only time the axis runs past the
/// last sample.
///
/// To the last *sample* rather than the last reading drawn, so a reading that
/// is no longer being taken ends where it ended instead of being stretched up
/// to the present.
({int from, int to})? watchedWindow(
  List<int> times,
  List<HistorySeries> series, {
  int? until,
}) {
  if (times.isEmpty) return null;
  int? from;
  for (final s in series) {
    final length = math.min(s.values.length, times.length);
    for (var i = 0; i < length; i++) {
      if (s.values[i] == null) continue;
      if (from == null || times[i] < from) from = times[i];
      break;
    }
  }
  if (from == null) return null;
  final last = times.last;
  return (from: from, to: until != null && until > last ? until : last);
}

/// Picks an axis whose ticks land on round numbers.
///
/// Deriving the interval from the data instead (`peak * 1.1 / 4`) produced
/// ticks like 48.4°C and 514.5 KB/s: hard to read, and wide enough that every
/// chart had to reserve a gutter for them.
///
/// [binary] selects the progression. Byte rates are formatted in powers of
/// 1024, so a decimal-round step of 500 000 renders as "488.3 KB/s"; stepping
/// in multiples of 1024 gives "512 KB/s".
({double bottom, double top, double interval}) niceAxis({
  required double trough,
  required double peak,
  required bool binary,
}) {
  // Below this the labels repeat: the formatters carry one decimal for
  // percentages and °C, and whole bytes for rates
  final minInterval = binary ? 1.0 : 0.1;

  if (!peak.isFinite || !trough.isFinite) {
    return binary
        ? (bottom: 0.0, top: 1024.0, interval: 256.0)
        : (bottom: 0.0, top: 1.0, interval: 0.25);
  }

  const targetTicks = 4;
  var lo = trough;
  var hi = peak;

  // A flat line has no span to derive a step from, and taking one from the
  // value's own magnitude pinned it to an edge — a disk sitting at 65.4%
  // produced a 60..80 axis. Give it a span proportional to the value and
  // centre it instead.
  if (hi - lo <= 0) {
    final pad = math.max(hi.abs() * 0.05, minInterval * targetTicks / 2);
    lo -= pad;
    hi += pad;
  }

  final raw = (hi - lo) / targetTicks;

  double interval;
  if (binary) {
    var unit = 1.0;
    while (unit * 1024 <= raw) {
      unit *= 1024;
    }
    const steps = [1, 2, 4, 8, 16, 32, 64, 128, 256, 512, 1024];
    final norm = raw / unit;
    interval = steps.firstWhere((s) => s >= norm, orElse: () => 1024) * unit;
  } else {
    final mag = math.pow(10, (math.log(raw) / math.ln10).floor()).toDouble();
    const steps = [1.0, 2.0, 2.5, 5.0, 10.0];
    final norm = raw / mag;
    interval = steps.firstWhere((s) => s >= norm, orElse: () => 10.0) * mag;
  }
  if (interval < minInterval) interval = minInterval;

  // Snap outwards to whole intervals, which is also where the margin around
  // the data comes from. Data that never went negative doesn't get a negative
  // axis: an idle interface reading "-2 B/s" is not a smaller number, it's an
  // impossible one.
  var bottom = (lo / interval).floor() * interval;
  if (trough >= 0 && bottom < 0) bottom = 0;
  var top = (hi / interval).ceil() * interval;
  if (top <= bottom) top = bottom + interval;
  return (bottom: bottom, top: top, interval: interval);
}

/// Width to reserve for the left axis, from the labels it will actually draw.
double axisWidth(
  double bottom,
  double top,
  double interval,
  String Function(double) format,
) {
  var longest = 0;
  for (var v = bottom; v <= top + interval / 2; v += interval) {
    final len = format(v).length;
    if (len > longest) longest = len;
  }
  // ~7px per glyph at UIs.text12Grey, plus fl_chart's own 8px label gap
  return (longest * 7.0 + 10).clamp(32.0, 72.0);
}

/// Multi-series chart. Every series shares one axis, whose bounds come from
/// the data rather than from a fixed range.
///
/// Anchoring at 0 was tried first and spent most of the plot on empty axis:
/// a CPU idling at 8% and a machine sitting at 40 °C both drew a flat line
/// hugging the bottom edge. Both bounds now snap outwards to whole intervals,
/// which is also where the margin around the data comes from.
Widget buildHistoryLineChart(
  List<LineChartBarData> bars, {
  required List<HistorySeries> series,
  required String Function(double) format,
  bool binaryScale = false,
  ({int from, int to})? window,
  List<ChartBand> bands = const [],
  double axis = 1,
}) {
  // fl_chart throws a LateInitializationError on `mostLeftSpot` when handed a
  // bar with no spots at all
  if (bars.isEmpty || bars.every((b) => b.spots.isEmpty)) {
    return UIs.placeholder;
  }

  final peak = bars
      .expand((b) => b.spots)
      .map((e) => e.y)
      .fold<double>(0, (a, b) => a > b ? a : b);
  final trough = bars
      .expand((b) => b.spots)
      .map((e) => e.y)
      .fold<double>(double.infinity, (a, b) => a < b ? a : b);
  final scale = niceAxis(trough: trough, peak: peak, binary: binaryScale);
  final bottom = scale.bottom;
  final top = scale.top;
  final interval = scale.interval;
  // Scaled rather than switched: the gutter is what the plot is inset by, so
  // a chart that gained one between two frames would shift its whole line.
  final gutter = axisWidth(bottom, top, interval, format) * axis;

  // The window that was asked for, not the extent of what came back. Equal
  // bounds would give fl_chart a zero-width axis, so a window that has
  // collapsed to an instant falls back to the data.
  var minX = window != null && window.to > window.from
      ? window.from.toDouble()
      : null;
  var maxX = window != null && window.to > window.from
      ? window.to.toDouble()
      : null;
  // And the data can be an instant as well: the first reading of a machine,
  // which is drawn as a point. fl_chart puts everything on a zero-width axis
  // at its left edge, half outside the plot; the middle is where one point
  // with nothing on either side of it belongs.
  if (minX == null || maxX == null) {
    final xs = bars.expand((b) => b.spots).map((e) => e.x);
    final at = xs.first;
    if (xs.every((x) => x == at)) {
      minX = at - 1;
      maxX = at + 1;
    }
  }

  final chart = LineChart(
    // Off while the card is growing into the page.
    //
    // fl_chart answers new data by lerping from the old to it over 150ms —
    // every bar, and every spot of every bar. Between two samples that is what
    // makes the line glide instead of stepping. During the movement this is
    // handed new data on every frame, because the gutter is widening and the
    // grid is fading in, so that lerp is restarted 60 times a second: it never
    // reaches its end and pays for the whole series each time.
    duration: axis > 0 && axis < 1
        ? Duration.zero
        : const Duration(milliseconds: 150),
    LineChartData(
      // A card is read at a glance and has nothing to hold a tooltip; the
      // page it becomes is where a value under the pointer belongs.
      lineTouchData: LineTouchData(
        enabled: axis >= 1,
        touchTooltipData: LineTouchTooltipData(
          tooltipPadding: const EdgeInsets.all(5),
          tooltipBorderRadius: BorderRadius.circular(8),
          // fl_chart wraps at 120 by default, which folded rows like
          // "gas gauge battery 33°C" onto three lines
          maxContentWidth: 220,
          // A spot near the top of the plot puts the tooltip outside the box,
          // where the card clips it. Reflowing it back inside keeps the axis
          // honest — the alternative, reserving headroom by inflating maxY,
          // would permanently shrink the plot for a transient overlay and
          // cannot work at all on the fixed 0-100% charts.
          fitInsideVertically: true,
          fitInsideHorizontally: true,
          getTooltipItems: (touchedSpots) => touchedSpots.map((e) {
            final label = e.barIndex < series.length
                ? series[e.barIndex].label
                : '';
            return LineTooltipItem(
              '$label ${format(e.y)}',
              // One colour for every line. Tinting each row to match its
              // series repeated what the legend already encodes, and on the
              // tooltip's own background the lighter series read as washed
              // out next to the darker ones.
              const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: Colors.white,
              ),
            );
          }).toList(),
        ),
        handleBuiltInTouches: true,
      ),
      gridData: FlGridData(
        show: axis > 0,
        drawVerticalLine: false,
        horizontalInterval: interval,
        getDrawingHorizontalLine: (value) => FlLine(
          color: const Color.fromARGB(43, 88, 91, 94).withValues(alpha: axis),
          strokeWidth: 1,
        ),
      ),
      titlesData: FlTitlesData(
        show: true,
        rightTitles: const AxisTitles(
          sideTitles: SideTitles(showTitles: false),
        ),
        topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
        bottomTitles: const AxisTitles(
          sideTitles: SideTitles(showTitles: false),
        ),
        leftTitles: AxisTitles(
          sideTitles: SideTitles(
            showTitles: axis > 0,
            // Without an explicit interval fl_chart emits a label per pixel
            // step, which stacked them into an unreadable smear
            interval: interval,
            // Sized to the labels this axis will actually draw. A fixed
            // reserve had to assume the worst case, which left a wide empty
            // gutter on every chart whose ticks happened to be short.
            reservedSize: gutter,
            getTitlesWidget: (val, meta) => SideTitleWidget(
              meta: meta,
              child: Text(
                format(val),
                style: UIs.text12Grey.copyWith(
                  color: UIs.text12Grey.color?.withValues(alpha: axis),
                ),
                maxLines: 1,
                softWrap: false,
                overflow: TextOverflow.visible,
              ),
            ),
          ),
        ),
      ),
      borderData: FlBorderData(show: false),
      minX: minX,
      maxX: maxX,
      minY: bottom,
      maxY: top,
      lineBarsData: bars,
    ),
  );

  if (bands.isEmpty || minX == null || maxX == null) return chart;
  return buildBandedChart(
    chart,
    bands: bands,
    minX: minX,
    maxX: maxX,
    axisWidth: gutter,
  );
}

/// The chart with the empty stretches of its window marked on it.
///
/// Drawn over the plot rather than as fl_chart range annotations so the label
/// can sit in the band: what makes a gap readable is the sentence in it, and
/// an unlabelled grey rectangle is just a second background.
Widget buildBandedChart(
  Widget chart, {
  required List<ChartBand> bands,
  required double minX,
  required double maxX,
  required double axisWidth,
}) {
  return LayoutBuilder(
    builder: (context, cons) {
      final plotWidth = cons.maxWidth - axisWidth;
      if (plotWidth <= 0) return chart;
      double atX(int x) =>
          axisWidth + plotWidth * ((x - minX) / (maxX - minX)).clamp(0.0, 1.0);

      final scheme = Theme.of(context).colorScheme;
      return Stack(
        children: [
          Positioned.fill(child: chart),
          for (final band in bands)
            () {
              final left = atX(band.from);
              final right = atX(band.to);
              // The edge against the data, which is where the reading stops.
              // The other edge is the end of the axis and needs no line.
              final againstDataOnLeft = band.from > minX;
              return Positioned(
                left: left,
                width: (right - left).clamp(0.0, plotWidth),
                top: 0,
                bottom: 0,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: scheme.onSurface.withValues(alpha: 0.04),
                    border: Border(
                      left: againstDataOnLeft
                          ? BorderSide(color: scheme.outlineVariant)
                          : BorderSide.none,
                      right: againstDataOnLeft
                          ? BorderSide.none
                          : BorderSide(color: scheme.outlineVariant),
                    ),
                  ),
                  child: Center(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 3),
                      child: Text(
                        band.label,
                        textAlign: TextAlign.center,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: UIs.text11Grey,
                      ),
                    ),
                  ),
                ),
              );
            }(),
        ],
      );
    },
  );
}
