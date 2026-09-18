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
        TextButton(onPressed: () => context.popDialog(), child: Text(libL10n.close)),
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

  void _onTapGpuItem(GpuItem item) {
    final memory = item.memory;
    if (memory == null) return;
    final processes = memory.processes;
    _showGpuProcessesDialog(
      title: item.name,
      itemCount: processes.length,
      itemBuilder: (_, idx) => _buildGpuProcessItem(processes[idx]),
    );
  }

  void _onTapGpuProcessItem(GpuSmiMemProcess process) {
    _showClosableDetailDialog(
      title: '${process.pid}',
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          UIs.height13,
          Text('${libL10n.memory}: ${process.memory} MiB'),
          UIs.height13,
          Text('${libL10n.process}: ${process.name}'),
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

  bool _getInitExpand(int len, [int? max]) {
    if (!_collapse) return true;
    if (_size.width > UIs.columnWidth) return true;
    return len > 0 && len <= (max ?? 3);
  }

  /// Which sensors the temperature metric draws by default, in order: the
  /// hottest sensor matching each group.
  ///
  /// A Mac reports two dozen sensors through one API — fourteen of them PMU
  /// dies within a degree of each other — and a Linux box with several thermal
  /// zones is no better. Plotting all of them produced a legend taller than
  /// the plot and a band of indistinguishable lines; plotting simply the
  /// hottest N filled the chart with near-duplicate dies and dropped the SSD
  /// and the battery entirely. One line per component is what a temperature
  /// chart is read for; everything else is a tap away in the device picker.
  ///
  /// Names come from three unrelated sources, so each group has to cover all
  /// three:
  /// - Linux: the `type` of each `/sys/class/thermal/thermal_zone*`, plus
  ///   hwmon driver names where those are read
  /// - macOS: `sysinfo` Component labels, which are SMC keys spelled out
  /// - Windows: `MSAcpi_ThermalZoneTemperature`'s `InstanceName`, e.g.
  ///   `ACPI\ThermalZone\TZ00_0`
  ///
  /// Matched as lowercase substrings; the first group to match claims the
  /// sensor, so a device is never plotted twice. Order is by how much the
  /// reading usually matters.
  static const _kTempCategories = <List<String>>[
    // CPU / SoC package
    [
      'x86_pkg_temp', 'coretemp', 'k10temp', 'zenpower', 'peci', // Linux x86
      'cpu_thermal', 'cpu-thermal', 'soc_thermal', 'soc-thermal', // Linux ARM
      'bcm2835_thermal', 'tcpu',
      'tdie', 'tcal', 'pmgr soc', 'soc mtr', // macOS
      'cpu', 'package', 'soc',
    ],
    // GPU
    ['amdgpu', 'nouveau', 'radeon', 'gpu', 'tgpu'],
    // Storage
    ['nvme', 'nand', 'ssd', 'drive', 'disk'],
    // Battery / power delivery
    ['gas gauge', 'battery', 'bat0', 'charger'],
    // Wireless
    ['iwlwifi', 'airport', 'wifi', 'wlan'],
    // Board, chipset, ambient. Windows' single ACPI zone lands here, which is
    // fine: a host with one sensor plots it whichever group claims it.
    ['acpitz', 'thermalzone', 'pch', 'tskin', 'tskn', 'ambient', 'thermal'],
  ];

  static double? _latest(List<double?> values) {
    for (var i = values.length - 1; i >= 0; i--) {
      if (values[i] != null) return values[i];
    }
    return null;
  }

  List<_HistorySeries> _tempSeries(ServerState si) {
    final h = si.status.history;
    if (h.tempsByDevice.isEmpty) {
      return [_HistorySeries(libL10n.temperature, _kDeviceColors.first, h.temp)];
    }

    // Hottest first, so "the hottest match in this group" falls out of a
    // single pass and any leftovers are already ranked
    final ranked = h.tempsByDevice.entries.toList()
      ..sort(
        (a, b) => (_latest(b.value) ?? -1).compareTo(_latest(a.value) ?? -1),
      );

    final picked = <MapEntry<String, List<double?>>>[];
    final taken = <String>{};
    for (final group in _kTempCategories) {
      for (final e in ranked) {
        if (taken.contains(e.key)) continue;
        final name = e.key.toLowerCase();
        if (!group.any(name.contains)) continue;
        picked.add(e);
        taken.add(e.key);
        break;
      }
    }

    // A platform naming its sensors in some way this doesn't anticipate still
    // gets a chart, just an unsorted one
    if (picked.isEmpty) picked.add(ranked.first);

    return [
      for (final (i, e) in picked.indexed)
        _HistorySeries(e.key, _kDeviceColors[i % _kDeviceColors.length], e.value),
    ];
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

    final hasLegend = spec.series.length > 1;
    final body = Padding(
      // The extra bottom allowance is only for the axis' own overflow: fl_chart
      // centres the lowest label on the bottom gridline, so roughly half of it
      // hangs outside the plot box. A legend below already absorbs that, and
      // adding the allowance there too left a visible gap under the card.
      //
      // The top keeps the topmost axis label off whatever heading is above it;
      // at 7 the two touched.
      padding: EdgeInsets.fromLTRB(17, 15, 17, hasLegend ? 0 : 15),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          () {
            final plot = _buildHistoryLineChart(
              bars,
              series: spec.series,
              format: spec.format,
              binaryScale: spec.binaryScale,
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

/// Palette for the lines of one metric's devices — sensors, disks,
/// interfaces. Fixed order so a device keeps its colour across rebuilds, and
/// as long as [_kMaxDeviceLines] so two lines never share one.
const _kDeviceColors = [
  Color(0xFFEF4444),
  Color(0xFFF59E0B),
  Color(0xFF8B5CF6),
  Color(0xFF14B8A6),
  Color(0xFF3B82F6),
  Color(0xFFEC4899),
];

/// One chart: the series drawn on its shared axis, and how to label that axis.
class _ChartSpec {
  final List<_HistorySeries> series;
  final String Function(double) format;

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
  /// of 1024 rather than of 10 — see [_niceAxis]
  final bool binaryScale;

  const _ChartSpec({
    required this.series,
    required this.format,
    this.binaryScale = false,
    this.height = 110,
    this.fill = false,
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
({double bottom, double top, double interval}) _niceAxis({
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
double _axisWidth(
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

/// Trailing `.0` dropped: with round ticks the axis reads 0/25/50/75/100, and
/// the decimal was only ever noise there
String _formatTemp(double v) =>
    '${v.toStringAsFixed(v == v.roundToDouble() ? 0 : 1)}°C';

extension _ViewUtils on String {
  bool get isSvgUrl {
    final uri = Uri.tryParse(this);
    final path = uri?.path.toLowerCase() ?? toLowerCase();
    return path.endsWith('.svg');
  }
}

/// Multi-series chart. Every series shares one axis, whose bounds come from
/// the data rather than from a fixed range.
///
/// Anchoring at 0 was tried first and spent most of the plot on empty axis:
/// a CPU idling at 8% and a machine sitting at 40 °C both drew a flat line
/// hugging the bottom edge. Both bounds now snap outwards to whole intervals,
/// which is also where the margin around the data comes from.
Widget _buildHistoryLineChart(
  List<LineChartBarData> bars, {
  required List<_HistorySeries> series,
  required String Function(double) format,
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
  final trough = bars
      .expand((b) => b.spots)
      .map((e) => e.y)
      .fold<double>(double.infinity, (a, b) => a < b ? a : b);
  final axis = _niceAxis(trough: trough, peak: peak, binary: binaryScale);
  final bottom = axis.bottom;
  final top = axis.top;
  final interval = axis.interval;

  return LineChart(
    LineChartData(
      lineTouchData: LineTouchData(
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
            reservedSize: _axisWidth(bottom, top, interval, format),
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
      minY: bottom,
      maxY: top,
      lineBarsData: bars,
    ),
  );
}
