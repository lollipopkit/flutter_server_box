part of 'view.dart';

enum _NetSortType {
  device,
  trans,
  recv,
  ;

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
  List<List<FlSpot>> spots,
  Range<double> x, {
  String? tooltipPrefix,
  bool curve = false,
}) {
  return LineChart(LineChartData(
    lineTouchData: LineTouchData(
      touchTooltipData: LineTouchTooltipData(
        tooltipPadding: const EdgeInsets.all(5),
        tooltipRoundedRadius: 8,
        tooltipMargin: 3,
        getTooltipItems: (List<LineBarSpot> touchedSpots) {
          return touchedSpots.map((e) {
            return LineTooltipItem(
              '$tooltipPrefix${e.barIndex}: ${e.y.toStringAsFixed(2)}',
              const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
              ),
            );
          }).toList();
        },
      ),
      handleBuiltInTouches: true,
    ),
    gridData: FlGridData(
      show: true,
      drawVerticalLine: false,
      horizontalInterval: 20,
      getDrawingHorizontalLine: (value) {
        return const FlLine(
          color: Color(0xff37434d),
          strokeWidth: 1,
        );
      },
    ),
    titlesData: FlTitlesData(
      show: true,
      rightTitles: const AxisTitles(
        sideTitles: SideTitles(showTitles: false),
      ),
      topTitles: const AxisTitles(
        sideTitles: SideTitles(showTitles: false),
      ),
      bottomTitles: const AxisTitles(
        sideTitles: SideTitles(showTitles: false),
      ),
      leftTitles: AxisTitles(
        sideTitles: SideTitles(
          showTitles: true,
          interval: 1,
          getTitlesWidget: (val, meta) {
            if (val % 20 != 0) return UIs.placeholder;
            return Text(
              val.toInt().toString(),
              style: UIs.text12Grey,
            );
          },
          reservedSize: 42,
        ),
      ),
    ),
    borderData: FlBorderData(show: false),
    minX: x.start,
    maxX: x.end,
    minY: 0,
    maxY: 100,
    lineBarsData: spots
        .map((e) => LineChartBarData(
              spots: e,
              isCurved: curve,
              barWidth: 2,
              isStrokeCapRound: true,
              color: primaryColor,
              dotData: const FlDotData(show: false),
              belowBarData: BarAreaData(show: false),
            ))
        .toList(),
  ));
}
