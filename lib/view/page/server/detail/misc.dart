part of 'view.dart';

extension on _ServerDetailPageState {
  void _onTapNvidiaGpuItem(NvidiaSmiItem item) {
    final processes = item.memory.processes;
    final displayCount = processes.length > 5 ? 5 : processes.length;
    final height = displayCount * 47.0;
    context.showRoundDialog(
      title: item.name,
      child: SizedBox(
        width: double.maxFinite,
        height: height,
        child: ListView.builder(
          itemCount: processes.length,
          itemBuilder: (_, idx) => _buildGpuProcessItem(processes[idx]),
        ),
      ),
      actions: Btnx.oks,
    );
  }

  void _onTapAmdGpuItem(AmdSmiItem item) {
    final processes = item.memory.processes;
    final displayCount = processes.length > 5 ? 5 : processes.length;
    final height = displayCount * 47.0;
    context.showRoundDialog(
      title: item.name,
      child: SizedBox(
        width: double.maxFinite,
        height: height,
        child: ListView.builder(
          itemCount: processes.length,
          itemBuilder: (_, idx) => _buildAmdGpuProcessItem(processes[idx]),
        ),
      ),
      actions: Btnx.oks,
    );
  }

  void _onTapGpuProcessItem(NvidiaSmiMemProcess process) {
    context.showRoundDialog(
      title: '${process.pid}',
      titleMaxLines: 1,
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
      actions: [TextButton(onPressed: () => context.pop(), child: Text(libL10n.close))],
    );
  }

  void _onTapAmdGpuProcessItem(AmdSmiMemProcess process) {
    context.showRoundDialog(
      title: '${process.pid}',
      titleMaxLines: 1,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,  
        children: [
          UIs.height13,
          Text('Memory: ${process.memory} ${process.memory > 1024 ? 'MB' : 'KB'}'),
          UIs.height13,
          Text('Process: ${process.name}'),
        ],
      ),
      actions: [TextButton(onPressed: () => context.pop(), child: Text(libL10n.close))],
    );
  }

  void _onTapCustomItem(MapEntry<String, String> cmd) {
    context.showRoundDialog(
      title: cmd.key,
      child: SingleChildScrollView(child: Text(cmd.value, style: UIs.text13Grey)),
      actions: [TextButton(onPressed: () => context.pop(), child: Text(libL10n.close))],
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
}

enum _NetSortType {
  device,
  trans,
  recv;

  bool get isDevice => this == _NetSortType.device;
  bool get isIn => this == _NetSortType.recv;
  bool get isOut => this == _NetSortType.trans;

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
        return (b, a) => ns.speedInBytes(ns.deviceIdx(a)).compareTo(ns.speedInBytes(ns.deviceIdx(b)));
      case _NetSortType.trans:
        return (b, a) => ns.speedOutBytes(ns.deviceIdx(a)).compareTo(ns.speedOutBytes(ns.deviceIdx(b)));
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
          return const FlLine(color: Color.fromARGB(43, 88, 91, 94), strokeWidth: 1);
        },
      ),
      titlesData: FlTitlesData(
        show: true,
        rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
        topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
        bottomTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
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
