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
            _buildHistoryLine('CPU', points, (e) => e.cpu, unit: '%'),
            _buildHistoryLine('RAM', points, (e) => e.memory, unit: '%'),
            _buildHistoryLine(
              libL10n.disk,
              points,
              (e) => e.disk,
              unit: '%',
            ),
            _buildHistoryLine(
              '${libL10n.net} ↓',
              points,
              (e) => e.netRxSpeed,
              formatY: _formatSpeed,
            ),
            _buildHistoryLine(
              '${libL10n.net} ↑',
              points,
              (e) => e.netTxSpeed,
              formatY: _formatSpeed,
            ),
            _buildHistoryLine(
              'DiskIO ${l10n.read}',
              points,
              (e) => e.diskioReadSpeed,
              formatY: _formatSpeed,
            ),
            _buildHistoryLine(
              'DiskIO ${l10n.write}',
              points,
              (e) => e.diskioWriteSpeed,
              formatY: _formatSpeed,
            ),
            if (hasTemp)
              _buildHistoryLine(
                libL10n.temperature,
                points,
                (e) => e.temperature ?? 0,
                unit: '°C',
              ),
            if (hasBattery)
              _buildHistoryLine(
                libL10n.battery,
                points,
                (e) => e.batteryPercent ?? 0,
                unit: '%',
              ),
          ],
        ),
      );
    });
  }

  String _formatSpeed(double bytesPerSec) => '${bytesPerSec.bytes2Str}/s';

  Widget _buildHistoryLine(
    String title,
    List<MonitorHistoryPoint> points,
    double Function(MonitorHistoryPoint) selector, {
    String? unit,
    String Function(double)? formatY,
  }) {
    final spots = <FlSpot>[
      for (var i = 0; i < points.length; i++)
        FlSpot(
          (DateTime.tryParse(points[i].timestamp)?.millisecondsSinceEpoch ??
                  i)
              .toDouble(),
          selector(points[i]),
        ),
    ];
    final format = formatY ?? (v) => '${v.toStringAsFixed(1)}${unit ?? ''}';
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 17, vertical: 7),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: UIs.text12Grey),
          SizedBox(
            height: 100,
            child: _buildAutoLineChart(
              spots,
              tooltipPrefix: '$title: ',
              formatY: format,
            ),
          ),
        ],
      ),
    );
  }
}

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

/// Like [_buildLineChart] but with a Y axis auto-scaled to the data range,
/// for series that aren't a 0-100 percentage (network/diskio speeds,
/// temperature) — used by monitor's history charts (`_buildMonitorHistory`).
Widget _buildAutoLineChart(
  List<FlSpot> spots, {
  String? tooltipPrefix,
  String Function(double)? formatY,
}) {
  if (spots.isEmpty) return UIs.placeholder;

  final ys = spots.map((e) => e.y);
  var minY = ys.reduce((a, b) => a < b ? a : b);
  var maxY = ys.reduce((a, b) => a > b ? a : b);
  if (minY == maxY) {
    minY -= 1;
    maxY += 1;
  } else {
    final pad = (maxY - minY) * 0.1;
    minY -= pad;
    maxY += pad;
  }
  final format = formatY ?? (v) => v.toStringAsFixed(1);

  return LineChart(
    LineChartData(
      lineTouchData: LineTouchData(
        touchTooltipData: LineTouchTooltipData(
          tooltipPadding: const EdgeInsets.all(5),
          tooltipBorderRadius: BorderRadius.circular(8),
          getTooltipItems: (List<LineBarSpot> touchedSpots) {
            return touchedSpots.map((e) {
              return LineTooltipItem(
                '$tooltipPrefix${format(e.y)}',
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
            reservedSize: 44,
            getTitlesWidget: (val, meta) =>
                Text(format(val), style: UIs.text12Grey),
          ),
        ),
      ),
      borderData: FlBorderData(show: false),
      minY: minY,
      maxY: maxY,
      lineBarsData: [
        LineChartBarData(
          spots: spots,
          isCurved: false,
          barWidth: 2,
          isStrokeCapRound: true,
          color: UIs.primaryColor,
          dotData: const FlDotData(show: false),
          belowBarData: BarAreaData(show: false),
        ),
      ],
    ),
  );
}
