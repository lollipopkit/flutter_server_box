part of 'view.dart';

extension on _ServerDetailPageState {
  void _showClosableDetailDialog({
    required String title,
    required Widget child,
  }) {
    context.showRoundDialog(
      title: title,
      child: child,
      actions: [
        TextButton(onPressed: () => context.pop(), child: Text(libL10n.close)),
      ],
    );
  }

  void _showGpuProcessesDialog({
    required String title,
    required int itemCount,
    required IndexedWidgetBuilder itemBuilder,
  }) {
    final displayCount = itemCount > 5 ? 5 : itemCount;
    final height = (displayCount > 0 ? displayCount : 1) * 47.0;
    context.showRoundDialog(
      title: title,
      child: SizedBox(
        width: double.maxFinite,
        height: height,
        child: itemCount == 0
            ? Center(child: Text(libL10n.empty))
            : ListView.builder(itemCount: itemCount, itemBuilder: itemBuilder),
      ),
      actions: Btnx.oks,
    );
  }

  void _onTapNvidiaGpuItem(NvidiaSmiItem item) {
    final processes = item.memory.processes;
    _showGpuProcessesDialog(
      title: item.name,
      itemCount: processes.length,
      itemBuilder: (_, idx) => _buildGpuProcessItem(processes[idx]),
    );
  }

  void _onTapAmdGpuItem(AmdSmiItem item) {
    final processes = item.memory.processes;
    _showGpuProcessesDialog(
      title: item.name,
      itemCount: processes.length,
      itemBuilder: (_, idx) => _buildAmdGpuProcessItem(processes[idx]),
    );
  }

  void _onTapGpuProcessItem(NvidiaSmiMemProcess process) {
    _showClosableDetailDialog(
      title: '${process.pid}',
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          UIs.height13,
          Text('Memory: ${process.memory} MiB'),
          UIs.height13,
          Text('Process: ${process.name}'),
        ],
      ),
    );
  }

  void _onTapAmdGpuProcessItem(AmdSmiMemProcess process) {
    _showClosableDetailDialog(
      title: '${process.pid}',
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          UIs.height13,
          Text('Memory: ${_formatAmdGpuProcessMemory(process.memory)}'),
          UIs.height13,
          Text('Process: ${process.name}'),
        ],
      ),
    );
  }

  void _onTapCustomItem(MapEntry<String, String> cmd) {
    _showClosableDetailDialog(
      title: cmd.key,
      child: SingleChildScrollView(
        child: Text(cmd.value, style: UIs.text13Grey),
      ),
    );
  }

  void _onTapSensorItem(SensorItem si) {
    context.showRoundDialog(
      title: si.device,
      child: SingleChildScrollView(
        child: SimpleMarkdown(
          data: si.toMarkdown,
          styleSheet: MarkdownStyleSheet(
            tableBorder: TableBorder.all(color: Colors.grey),
            tableHead: const TextStyle(fontWeight: FontWeight.bold),
          ),
        ),
      ),
    );
  }

  void _onTapTemperatureItem(String key) {
    Pfs.copy(key);
    context.showSnackBar('${libL10n.copy} ${libL10n.success}');
  }

  bool _getInitExpand(int len, [int? max]) {
    if (!_collapse) return true;
    if (_size.width > UIs.columnWidth) return true;
    return len > 0 && len <= (max ?? 3);
  }

  /// Trends read one buffer ([ServerStatus.history]) that both connection
  /// methods append to, so an SSH server and a monitor HTTP server render
  /// identically; monitor servers additionally get theirs prefilled from the
  /// agent's stored history (`seedHistoryFromMonitor`).
  ///
  /// Grouping follows monitor's own panel: series sharing a unit go on one
  /// axis so they stay comparable, rather than each getting its own
  /// auto-scaled strip.
  ///
  /// These two return a bare chart, not a card: each is embedded in the CPU or
  /// RAM card beneath the figure it plots. Both keep a fixed 0-100% axis, so
  /// the two cards stay directly comparable even though they no longer share
  /// one plot.
  Widget? _buildCpuChart(ServerState si) => _percentChart(
    'CPU',
    const Color(0xFF3B82F6),
    si.status.history.cpu,
  );

  Widget? _buildMemChart(ServerState si) => _percentChart(
    'RAM',
    const Color(0xFF22C55E),
    si.status.history.mem,
  );

  Widget? _percentChart(String label, Color color, List<double?> values) {
    final spec = _ChartSpec(
      series: [_HistorySeries(label, color, values)],
      format: _formatPercent,
      maxY: 100,
    );
    return spec.hasData ? _buildChart(spec) : null;
  }

  Widget? _buildDiskChart(ServerState si) {
    final h = si.status.history;
    return _chartCard(ServerDetailCards.diskChart, [
      _ChartSpec(
        series: [
          _HistorySeries(libL10n.used, const Color(0xFFF59E0B), h.disk),
        ],
        format: _formatPercent,
        maxY: 100,
      ),
      // Separate chart, not a third line above: a byte rate and a percentage
      // share no axis
      _ChartSpec(
        series: [
          _HistorySeries(l10n.read, const Color(0xFF0EA5E9), h.diskRead),
          _HistorySeries(l10n.write, const Color(0xFFF97316), h.diskWrite),
        ],
        format: _formatSpeed,
        binaryScale: true,
      ),
    ]);
  }

  Widget? _buildNetChart(ServerState si) {
    final h = si.status.history;
    return _chartCard(ServerDetailCards.netChart, [
      _ChartSpec(
        series: [
          _HistorySeries('↓', const Color(0xFF8B5CF6), h.netRx),
          _HistorySeries('↑', const Color(0xFFEC4899), h.netTx),
        ],
        format: _formatSpeed,
        binaryScale: true,
      ),
    ]);
  }

  Widget? _buildTempChart(ServerState si) {
    final h = si.status.history;
    return _chartCard(ServerDetailCards.tempChart, [
      _ChartSpec(
        series: [
          _HistorySeries(
            libL10n.temperature,
            const Color(0xFFEF4444),
            h.temp,
          ),
        ],
        format: _formatTemp,
      ),
      _ChartSpec(
        series: [
          _HistorySeries(libL10n.battery, const Color(0xFF14B8A6), h.battery),
        ],
        format: _formatPercent,
        maxY: 100,
      ),
    ]);
  }

  /// Renders only the specs that actually have data, and nothing at all if
  /// none do — a server with no battery or no thermal sensor must not show an
  /// empty axis.
  Widget? _chartCard(ServerDetailCards card, List<_ChartSpec> specs) {
    final live = specs.where((s) => s.hasData).toList();
    if (live.isEmpty) return null;

    return CardX(
      child: ExpandTile(
        title: Text(card.toStr),
        leading: Icon(card.icon, size: 17),
        initiallyExpanded: _getInitExpand(1),
        childrenPadding: const EdgeInsets.only(bottom: 7),
        children: live.map(_buildChart).toList(),
      ),
    );
  }

  /// One chart plus the legend line carrying each series' latest value —
  /// mirrors `monitor/frontend/src/components/LineChart.svelte`.
  Widget _buildChart(_ChartSpec spec) {
    final bars = <LineChartBarData>[];
    for (final s in spec.series) {
      final spots = s.spots;
      if (spots.isEmpty) continue;
      bars.add(
        LineChartBarData(
          spots: spots,
          isCurved: false,
          barWidth: 1.5,
          isStrokeCapRound: true,
          color: s.color,
          dotData: const FlDotData(show: false),
          belowBarData: BarAreaData(show: false),
        ),
      );
    }
    if (bars.isEmpty) return UIs.placeholder;

    return Padding(
      // Bottom is larger than top on purpose: fl_chart centres the zero axis
      // label on the bottom gridline, so roughly half of it hangs below the
      // plot box. Without the allowance the last chart in a card sits flush
      // against the card's edge.
      padding: const EdgeInsets.fromLTRB(17, 7, 17, 15),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            height: 110,
            child: _buildHistoryLineChart(
              bars,
              series: spec.series,
              format: spec.format,
              maxY: spec.maxY,
              binaryScale: spec.binaryScale,
            ),
          ),
          // Only worth drawing when there is something to tell apart. A lone
          // line needs no key: the card already names its subject, and the
          // value is a touch away in the tooltip.
          if (spec.series.length > 1) ...[
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
  }
}

/// One chart: the series drawn on its shared axis, and how to label that axis.
class _ChartSpec {
  final List<_HistorySeries> series;
  final String Function(double) format;

  /// Fixed axis top for bounded quantities (percentages); auto-scaled when null
  final double? maxY;

  /// Whether the values are byte-based, so the axis should step in multiples
  /// of 1024 rather than of 10 — see [_niceAxis]
  final bool binaryScale;

  const _ChartSpec({
    required this.series,
    required this.format,
    this.maxY,
    this.binaryScale = false,
  });

  bool get hasData => series.any((s) => s.spots.isNotEmpty);
}

/// One line. Reads straight off a [StatusHistory] ring buffer, whose gaps are
/// `null` for "not measured at that sample" — those points are skipped rather
/// than plotted as 0, so an interface that only just appeared doesn't drag the
/// line down to the axis.
class _HistorySeries {
  final String label;
  final Color color;
  final List<double?> values;

  const _HistorySeries(this.label, this.color, this.values);

  List<FlSpot> get spots => [
    for (var i = 0; i < values.length; i++)
      if (values[i] != null) FlSpot(i.toDouble(), values[i]!),
  ];

  double? get latest {
    for (var i = values.length - 1; i >= 0; i--) {
      final v = values[i];
      if (v != null) return v;
    }
    return null;
  }
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
({double top, double interval}) _niceAxis(double peak, {required bool binary}) {
  // A flat all-zero window still needs a non-zero range to divide by
  if (peak <= 0) return (top: binary ? 1024 : 1, interval: binary ? 256 : 0.25);

  const targetTicks = 4;
  final raw = peak / targetTicks;

  final double interval;
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

  // Round the top up to a whole number of intervals, which is also where the
  // headroom above the peak comes from
  return (top: (peak / interval).ceil() * interval, interval: interval);
}

/// Width to reserve for the left axis, from the labels it will actually draw.
double _axisWidth(double top, double interval, String Function(double) format) {
  var longest = 0;
  for (var v = 0.0; v <= top + interval / 2; v += interval) {
    final len = format(v).length;
    if (len > longest) longest = len;
  }
  // ~7px per glyph at UIs.text12Grey, plus fl_chart's own 8px label gap
  return (longest * 7.0 + 10).clamp(32.0, 72.0);
}

/// Trailing `.0` dropped: with round ticks the axis reads 0/25/50/75/100, and
/// the decimal was only ever noise there
String _formatPercent(double v) =>
    '${v.toStringAsFixed(v == v.roundToDouble() ? 0 : 1)}%';
String _formatTemp(double v) =>
    '${v.toStringAsFixed(v == v.roundToDouble() ? 0 : 1)}°C';
String _formatSpeed(double bytesPerSec) => '${bytesPerSec.bytes2Str}/s';

String _formatAmdGpuProcessMemory(int rawMemory) {
  final valueInMiB = rawMemory / 1024;
  final formatted = valueInMiB.truncateToDouble() == valueInMiB
      ? valueInMiB.toStringAsFixed(0)
      : valueInMiB.toStringAsFixed(1);
  return '$formatted MiB';
}

extension _ViewUtils on String {
  bool get isSvgUrl {
    final uri = Uri.tryParse(this);
    final path = uri?.path.toLowerCase() ?? toLowerCase();
    return path.endsWith('.svg');
  }
}

enum _NetSortType {
  device,
  trans,
  recv;

  _NetSortType get next {
    switch (this) {
      case device:
        return trans;
      case _NetSortType.trans:
        return recv;
      case recv:
        return device;
    }
  }

  int Function(String, String) getSortFunc(NetSpeed ns) {
    switch (this) {
      case _NetSortType.device:
        return (b, a) => a.compareTo(b);
      // Interfaces with no reading yet sort as slowest rather than jumping
      // around as their first sample lands
      case _NetSortType.recv:
        return (b, a) => (ns.speedInBytes(ns.deviceIdx(a)) ?? -1).compareTo(
          ns.speedInBytes(ns.deviceIdx(b)) ?? -1,
        );
      case _NetSortType.trans:
        return (b, a) => (ns.speedOutBytes(ns.deviceIdx(a)) ?? -1).compareTo(
          ns.speedOutBytes(ns.deviceIdx(b)) ?? -1,
        );
    }
  }
}

/// Multi-series chart for monitor's history card. Unlike [_buildLineChart]
/// (fixed 0-100 percent axis) the Y axis is auto-scaled unless [maxY] is
/// given, and every series shares that one axis so they stay comparable.
///
/// The axis is anchored at 0 rather than padded below the minimum: every
/// quantity plotted here (percentages, byte rates, °C) has 0 as its floor, and
/// the old 10% bottom padding rendered labels like "-3.6%" and "-6979 B/s".
Widget _buildHistoryLineChart(
  List<LineChartBarData> bars, {
  required List<_HistorySeries> series,
  required String Function(double) format,
  double? maxY,
  bool binaryScale = false,
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
  final axis = maxY != null
      ? (top: maxY, interval: maxY / 4)
      : _niceAxis(peak, binary: binaryScale);
  final top = axis.top;
  final interval = axis.interval;

  return LineChart(
    LineChartData(
      lineTouchData: LineTouchData(
        touchTooltipData: LineTouchTooltipData(
          tooltipPadding: const EdgeInsets.all(5),
          tooltipBorderRadius: BorderRadius.circular(8),
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
              TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: e.bar.color,
              ),
            );
          }).toList(),
        ),
        handleBuiltInTouches: true,
      ),
      gridData: FlGridData(
        show: true,
        drawVerticalLine: false,
        horizontalInterval: interval,
        getDrawingHorizontalLine: (value) => const FlLine(
          color: Color.fromARGB(43, 88, 91, 94),
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
            showTitles: true,
            // Without an explicit interval fl_chart emits a label per pixel
            // step, which stacked them into an unreadable smear
            interval: interval,
            // Sized to the labels this axis will actually draw. A fixed
            // reserve had to assume the worst case, which left a wide empty
            // gutter on every chart whose ticks happened to be short.
            reservedSize: _axisWidth(top, interval, format),
            getTitlesWidget: (val, meta) => SideTitleWidget(
              meta: meta,
              child: Text(
                format(val),
                style: UIs.text12Grey,
                maxLines: 1,
                softWrap: false,
                overflow: TextOverflow.visible,
              ),
            ),
          ),
        ),
      ),
      borderData: FlBorderData(show: false),
      minY: 0,
      maxY: top,
      lineBarsData: bars,
    ),
  );
}
