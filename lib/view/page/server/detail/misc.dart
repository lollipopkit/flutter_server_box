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
  /// Unlike the other three this returns a bare chart, not a card — it is
  /// embedded in the Usage card beneath the CPU and RAM figures it plots.
  Widget? _buildUsageChart(ServerState si) {
    final h = si.status.history;
    final spec = _ChartSpec(
      series: [
        _HistorySeries('CPU', const Color(0xFF3B82F6), h.cpu),
        _HistorySeries('RAM', const Color(0xFF22C55E), h.mem),
      ],
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
      padding: const EdgeInsets.symmetric(horizontal: 17, vertical: 7),
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
            ),
          ),
          UIs.height7,
          // Below the plot: above it, the legend row and the axis' top label
          // sat on adjacent lines and read as one run-on line
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

  const _ChartSpec({
    required this.series,
    required this.format,
    this.maxY,
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

String _formatPercent(double v) => '${v.toStringAsFixed(1)}%';
String _formatTemp(double v) => '${v.toStringAsFixed(1)}°C';
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
  // A flat all-zero window still needs a non-zero range to divide by
  final top = maxY ?? (peak <= 0 ? 1 : peak * 1.1);
  const gridLines = 4;

  return LineChart(
    LineChartData(
      lineTouchData: LineTouchData(
        touchTooltipData: LineTouchTooltipData(
          tooltipPadding: const EdgeInsets.all(5),
          tooltipBorderRadius: BorderRadius.circular(8),
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
        horizontalInterval: top / gridLines,
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
            interval: top / gridLines,
            reservedSize: 56,
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
