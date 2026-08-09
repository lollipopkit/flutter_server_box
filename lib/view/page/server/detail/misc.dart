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

  /// Trend charts backed by monitor's `/api/v1/metrics/history` — only
  /// meaningful for servers connected via monitor HTTP (see
  /// `Spi.monitorHttp`); SSH-connected servers have no history concept
  /// beyond the existing in-memory CPU ring buffer, so this card is hidden
  /// for them entirely rather than showing an empty/misleading chart.
  Widget? _buildMonitorHistory(ServerState si) {
    if (si.spi.monitorHttp == null) return null;
    return _monitorHistory.listenVal((points) {
      if (points == null) {
        return const CardX(
          child: Padding(
            padding: EdgeInsets.all(21),
            child: Center(
              child: SizedBox(
                width: 21,
                height: 21,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            ),
          ),
        );
      }
      if (points.isEmpty) return UIs.placeholder;

      final hasTemp = points.any((e) => e.temperature != null);
      final hasBattery = points.any((e) => e.batteryPercent != null);

      return CardX(
        child: ExpandTile(
          title: const Text('History'),
          leading: const Icon(Icons.show_chart, size: 17),
          initiallyExpanded: _getInitExpand(1),
          childrenPadding: const EdgeInsets.only(bottom: 7),
          children: [
            // Grouped the same way monitor's own panel groups them
            // (`Dashboard.svelte`'s usageSeries/networkSeries and
            // `DetailPanel.svelte`'s diskIo chart): series sharing a unit go on
            // one axis, so three percentages read as one comparable picture
            // instead of three separately auto-scaled strips.
            _buildHistoryChart(
              libL10n.used,
              points,
              const [
                _HistorySeries('CPU', Color(0xFF3B82F6), _selCpu),
                _HistorySeries('RAM', Color(0xFF22C55E), _selMem),
                _HistorySeries('Disk', Color(0xFFF59E0B), _selDisk),
              ],
              format: _formatPercent,
              maxY: 100,
            ),
            _buildHistoryChart(
              libL10n.net,
              points,
              const [
                _HistorySeries('↓', Color(0xFF8B5CF6), _selNetRx),
                _HistorySeries('↑', Color(0xFFEC4899), _selNetTx),
              ],
              format: _formatSpeed,
            ),
            _buildHistoryChart(
              'Disk IO',
              points,
              [
                _HistorySeries(l10n.read, const Color(0xFF0EA5E9), _selDioRead),
                _HistorySeries(
                  l10n.write,
                  const Color(0xFFF97316),
                  _selDioWrite,
                ),
              ],
              format: _formatSpeed,
            ),
            if (hasTemp)
              _buildHistoryChart(
                libL10n.temperature,
                points,
                [
                  _HistorySeries(
                    libL10n.temperature,
                    const Color(0xFFEF4444),
                    _selTemp,
                  ),
                ],
                format: _formatTemp,
              ),
            if (hasBattery)
              _buildHistoryChart(
                libL10n.battery,
                points,
                [
                  _HistorySeries(
                    libL10n.battery,
                    const Color(0xFF14B8A6),
                    _selBattery,
                  ),
                ],
                format: _formatPercent,
                maxY: 100,
              ),
          ],
        ),
      );
    });
  }

  /// One chart per unit, all its series overlaid on a shared axis, with a
  /// legend line carrying each series' latest value — mirrors
  /// `monitor/frontend/src/components/LineChart.svelte`.
  Widget _buildHistoryChart(
    String title,
    List<MonitorHistoryPoint> points,
    List<_HistorySeries> series, {
    required String Function(double) format,
    double? maxY,
  }) {
    final bars = <LineChartBarData>[];
    for (final s in series) {
      final spots = <FlSpot>[
        for (var i = 0; i < points.length; i++)
          FlSpot(i.toDouble(), s.selector(points[i])),
      ];
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

    final last = points.last;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 17, vertical: 7),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: UIs.text12Grey),
          UIs.height7,
          Wrap(
            spacing: 13,
            runSpacing: 3,
            children: [
              for (final s in series)
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
                      '${s.label} ${format(s.selector(last))}',
                      style: UIs.text12Grey,
                    ),
                  ],
                ),
            ],
          ),
          UIs.height7,
          SizedBox(
            height: 110,
            child: _buildHistoryLineChart(
              bars,
              series: series,
              format: format,
              maxY: maxY,
            ),
          ),
        ],
      ),
    );
  }
}

/// One line of a history chart. Const-constructible (hence the top-level
/// selector functions below) so the shared groups can be `const` lists.
class _HistorySeries {
  final String label;
  final Color color;
  final double Function(MonitorHistoryPoint) selector;

  const _HistorySeries(this.label, this.color, this.selector);
}

double _selCpu(MonitorHistoryPoint p) => p.cpu;
double _selMem(MonitorHistoryPoint p) => p.memory;
double _selDisk(MonitorHistoryPoint p) => p.disk;
double _selNetRx(MonitorHistoryPoint p) => p.netRxSpeed;
double _selNetTx(MonitorHistoryPoint p) => p.netTxSpeed;
double _selDioRead(MonitorHistoryPoint p) => p.diskioReadSpeed;
double _selDioWrite(MonitorHistoryPoint p) => p.diskioWriteSpeed;
double _selTemp(MonitorHistoryPoint p) => p.temperature ?? 0;
double _selBattery(MonitorHistoryPoint p) => p.batteryPercent ?? 0;

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
      case _NetSortType.recv:
        return (b, a) => ns
            .speedInBytes(ns.deviceIdx(a))
            .compareTo(ns.speedInBytes(ns.deviceIdx(b)));
      case _NetSortType.trans:
        return (b, a) => ns
            .speedOutBytes(ns.deviceIdx(a))
            .compareTo(ns.speedOutBytes(ns.deviceIdx(b)));
    }
  }
}

Widget _buildLineChart(
  List<List<FlSpot>> spots, {
  String? tooltipPrefix,
  bool curve = false,
  int verticalInterval = 20,
}) {
  // `Cpus._updateSpots` seeds an empty Fifo on a core's first sample and only
  // starts filling it on the next one, so the very first frame after connecting
  // hands us empty series. fl_chart's `mostLeftSpot` is late-initialized from
  // the spot list and throws a LateInitializationError on an empty one.
  if (spots.isEmpty || spots.every((e) => e.isEmpty)) return UIs.placeholder;

  return LineChart(
    LineChartData(
      lineTouchData: LineTouchData(
        touchTooltipData: LineTouchTooltipData(
          tooltipPadding: const EdgeInsets.all(5),
          tooltipBorderRadius: BorderRadius.circular(8),
          getTooltipItems: (List<LineBarSpot> touchedSpots) {
            return touchedSpots.map((e) {
              return LineTooltipItem(
                '$tooltipPrefix${e.barIndex}: ${e.y.toStringAsFixed(2)}',
                const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
              );
            }).toList();
          },
        ),
        handleBuiltInTouches: true,
      ),
      gridData: FlGridData(
        show: true,
        drawVerticalLine: false,
        horizontalInterval: verticalInterval.toDouble(),
        getDrawingHorizontalLine: (value) {
          return const FlLine(
            color: Color.fromARGB(43, 88, 91, 94),
            strokeWidth: 1,
          );
        },
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
            interval: 20,
            getTitlesWidget: (val, meta) {
              if (val % verticalInterval != 0) return UIs.placeholder;
              if (val == 0) return const Text('0 %', style: UIs.text12Grey);
              return Text(val.toInt().toString(), style: UIs.text12Grey);
            },
            reservedSize: 27,
          ),
        ),
      ),
      borderData: FlBorderData(show: false),
      minY: -1,
      maxY: 101,
      lineBarsData: spots
          .map(
            (e) => LineChartBarData(
              spots: e,
              isCurved: curve,
              barWidth: 2,
              isStrokeCapRound: true,
              color: UIs.primaryColor,
              dotData: const FlDotData(show: false),
              belowBarData: BarAreaData(show: false),
            ),
          )
          .toList(),
    ),
  );
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
