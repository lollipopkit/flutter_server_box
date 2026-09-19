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

  /// One card in full: every reading it reports, and what is holding its
  /// memory.
  ///
  /// The row above carries the two figures that fit on a line — load and
  /// temperature — and this is the rest, in the order it is read in: what the
  /// card is, what it is doing, then who is doing it. A process list on its
  /// own was what this used to be, which left a card reporting no processes
  /// with nothing to open at all.
  void _onTapGpuItem(GpuItem item) {
    final mem = item.memory;
    final scheme = Theme.of(context).colorScheme;
    final rows = <({String k, String v})>[
      if (item.utilization case final util?) (k: l10n.used, v: _pct(util)),
      if (item.temperature case final t?)
        (k: libL10n.temperature, v: _formatTemp(t.toDouble())),
      if (item.power case final power?) (k: l10n.power, v: power),
      if (item.fanSpeed case final fan?)
        (k: l10n.fan, v: '$fan${item.vendor == 'nvidia' ? '%' : ' RPM'}'),
      if (item.clockSpeed case final clock?)
        (k: l10n.clockSpeed, v: '$clock MHz'),
      if (mem != null)
        (k: libL10n.memory, v: '${mem.used} / ${mem.total} ${mem.unit}'),
      (k: l10n.vendor, v: item.vendor),
    ];
    final processes = mem?.processes ?? const <GpuSmiMemProcess>[];

    showRowsSheet<void>(
      context,
      rows: (_) => [
        Padding(
          padding: const EdgeInsets.fromLTRB(17, 5, 17, 9),
          child: Text(
            '${item.name} · ${item.id}',
            style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w500),
          ),
        ),
        for (final (i, row) in rows.indexed) ...[
          if (i > 0) const Divider(height: 1, indent: 17, endIndent: 17),
          _buildReadoutRow(k: row.k, v: row.v),
        ],
        if (processes.isNotEmpty) ...[
          Padding(
            padding: const EdgeInsets.fromLTRB(17, 17, 17, 5),
            child: Text(
              l10n.processesFmt(processes.length),
              style: UIs.text11Grey.copyWith(color: scheme.primary),
            ),
          ),
          for (final process in processes)
            _buildReadoutRow(
              k: process.name,
              sub: 'PID ${process.pid}',
              v: '${process.memory} MiB',
            ),
        ],
      ],
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

  List<HistorySeries> _tempSeries(ServerState si) {
    final h = si.status.history;
    if (h.tempsByDevice.isEmpty) {
      return [HistorySeries(libL10n.temperature, _kDeviceColors.first, h.temp)];
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
        HistorySeries(e.key, _kDeviceColors[i % _kDeviceColors.length], e.value),
    ];
  }

}

/// Palette for the lines of one metric's devices — sensors, disks,
/// interfaces. As long as [_kMaxDeviceLines], so two lines never share one.
const _kDeviceColors = ChartPalette.devices;

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
