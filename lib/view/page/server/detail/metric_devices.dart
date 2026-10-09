import 'package:fl_lib/fl_lib.dart';
import 'package:server_box/core/extension/context/locale.dart';
import 'package:server_box/data/model/server/net_speed.dart';
import 'package:server_box/data/provider/server/single.dart';
import 'package:server_box/data/res/chart_palette.dart';
import 'package:server_box/view/page/server/card/metric.dart';
import 'package:server_box/view/page/server/chart.dart';
import 'package:server_box/view/page/server/detail/metric_model.dart';
import 'package:server_box/view/page/server/reading_text.dart';

/// What one metric's devices are, and what is known about each of them.
///
/// A metric's row is a total, and a total is not what a host with six disks is
/// read for. The focus chart draws one line per device instead, which is only
/// possible for the window this app kept itself — nothing stores a series per
/// device.
class MetricDevices {
  const MetricDevices({
    required this.names,
    required this.byDevice,
    required this.defaults,
    required this.subtitle,
    this.alone,
  });

  /// Busiest first, which is also the order the picker lists them in.
  final List<String> names;

  /// The samples behind each of [names], as [StatusHistory] kept them.
  final Map<String, List<double?>> byDevice;

  /// Drawn when the reader has not chosen: the busiest few, or for sensors the
  /// one per component [_tempSeries] settles on.
  final List<String> defaults;

  /// What the picker says under a device's name — its reading now, which is
  /// what the choice is made on.
  final String Function(String) subtitle;

  /// What is drawn when a single device is: both of its directions, which a
  /// line per device leaves out to stay readable.
  final List<HistorySeries> Function(String)? alone;

  /// The devices behind [kind], or null for a metric that has none and for a
  /// machine with only one of them — there is nothing to pick from or to tell
  /// apart.
  static MetricDevices? of(ServerState si, ServerMetricKind kind) {
    final ss = si.status;
    final h = ss.history;
    switch (kind) {
      case ServerMetricKind.diskIo:
        final io = ss.diskIO;
        final names = [...io.devices]
          ..sort((a, b) {
            double of(String d) {
              final (r, w) = io.speedBytes(d);
              return (r ?? 0) + (w ?? 0);
            }

            return of(b).compareTo(of(a));
          });
        if (names.length < 2) return null;
        return MetricDevices(
          names: names,
          // The direction the row and the headline lead with. Six devices in
          // both directions is twelve lines, which is a picture of nothing.
          byDevice: h.diskWritesByDevice,
          defaults: names.take(kMaxDeviceLines).toList(),
          subtitle: (d) {
            final (r, w) = io.speedBytes(d);
            return '${ReadingFmt.rate(w)} ${l10n.write} · ${ReadingFmt.rate(r)} ${l10n.read}';
          },
          alone: (d) => [
            HistorySeries(
              '$d ${l10n.write}',
              ChartPalette.lines[0],
              h.diskWritesByDevice[d] ?? const [],
            ),
            HistorySeries(
              '$d ${l10n.read}',
              ChartPalette.lines[1],
              h.diskReadsByDevice[d] ?? const [],
            ),
          ],
        );
      case ServerMetricKind.netSpeed:
        final ns = ss.netSpeed;
        return _net(
          ns,
          busy: (d) =>
              (ns.speedInBytesOf(device: d) ?? 0) +
              (ns.speedOutBytesOf(device: d) ?? 0),
          tx: h.netTxByDevice,
          rx: h.netRxByDevice,
          subtitle: (d) =>
              '↑ ${ReadingFmt.rate(ns.speedOutBytesOf(device: d))} · '
              '↓ ${ReadingFmt.rate(ns.speedInBytesOf(device: d))}',
        );
      case ServerMetricKind.netTraffic:
        final ns = ss.netSpeed;
        double? total(BigInt? v) => v?.toDouble();
        Map<String, List<double?>> added(Map<String, List<double?>> rates) => {
          for (final MapEntry(:key, :value) in rates.entries)
            key: cumulativeBytes(h.time, value),
        };
        return _net(
          ns,
          busy: (d) =>
              (total(ns.sizeInBytesOf(device: d)) ?? 0) +
              (total(ns.sizeOutBytesOf(device: d)) ?? 0),
          tx: added(h.netTxByDevice),
          rx: added(h.netRxByDevice),
          subtitle: (d) =>
              '↑ ${ReadingFmt.size(total(ns.sizeOutBytesOf(device: d)))} · '
              '↓ ${ReadingFmt.size(total(ns.sizeInBytesOf(device: d)))}',
        );
      case ServerMetricKind.temp:
        final names = [...ss.temps.devices]
          ..sort((a, b) => (ss.temps.get(b) ?? -1).compareTo(ss.temps.get(a) ?? -1));
        if (names.length < 2) return null;
        return MetricDevices(
          names: names,
          byDevice: h.tempsByDevice,
          // Not the hottest few: a Mac reports fourteen PMU dies within a
          // degree of each other, and picking by temperature alone draws them
          // all and drops the SSD.
          defaults: switch ([
            for (final s in _tempSeries(si))
              if (names.contains(s.label)) s.label,
          ]) {
            // History with the aggregate only — seeded from an agent, before
            // the first live sample — names no sensor: the hottest stands in.
            [] => [names.first],
            final picked => picked,
          },
          subtitle: (d) {
            final v = ss.temps.get(d);
            return v == null ? '--' : ReadingFmt.temp(v);
          },
        );
      case ServerMetricKind.cpu:
      case ServerMetricKind.mem:
      case ServerMetricKind.swap:
      case ServerMetricKind.disk:
      case ServerMetricKind.gpu:
      case ServerMetricKind.battery:
        return null;
    }
  }
}

/// The interfaces behind the network's speed or traffic, by [busy].
///
/// Every interface but loopback can be picked, bridges and tunnels included:
/// on a host whose traffic goes through `vmbr0` that is the one worth reading.
/// Drawn by default are the real ones, which are what the totals add up.
MetricDevices? _net(
  NetSpeed ns, {
  required double Function(String) busy,
  required Map<String, List<double?>> tx,
  required Map<String, List<double?>> rx,
  required String Function(String) subtitle,
}) {
  final names = [...ns.ifaces]..sort((a, b) => busy(b).compareTo(busy(a)));
  if (names.length < 2) return null;
  return MetricDevices(
    names: names,
    // Out, as the row and the headline lead with it.
    byDevice: tx,
    defaults: names
        .where(ns.realIfaces.contains)
        .take(kMaxDeviceLines)
        .toList(),
    subtitle: subtitle,
    alone: (d) => [
      HistorySeries('$d ↑', ChartPalette.lines[0], tx[d] ?? const []),
      HistorySeries('$d ↓', ChartPalette.lines[1], rx[d] ?? const []),
    ],
  );
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
const _kTempCategories = <List<String>>[
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

double? _latest(List<double?> values) {
  for (var i = values.length - 1; i >= 0; i--) {
    if (values[i] != null) return values[i];
  }
  return null;
}

List<HistorySeries> _tempSeries(ServerState si) {
  final h = si.status.history;
  if (h.tempsByDevice.isEmpty) {
    return [HistorySeries(libL10n.temperature, ChartPalette.accent, h.temp)];
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
      HistorySeries(e.key, ChartPalette.lines[i % kMaxDeviceLines], e.value),
  ];
}
