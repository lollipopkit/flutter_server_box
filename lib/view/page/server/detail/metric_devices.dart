import 'package:fl_lib/fl_lib.dart';
import 'package:server_box/core/extension/context/locale.dart';
import 'package:server_box/data/model/server/status/net_speed.dart';
import 'package:server_box/data/provider/server/metric.dart';
import 'package:server_box/data/provider/server/reading_fmt.dart';
import 'package:server_box/data/provider/server/single.dart';
import 'package:server_box/data/res/chart_palette.dart';
import 'package:server_box/view/page/server/chart.dart';
import 'package:server_box/view/page/server/detail/metric_model.dart';

/// What one metric's devices are, and what is known about each of them.
///
/// A metric's row is a total, and a total is not what a host with six disks is
/// read for. The focus chart draws one line per device instead, fed either
/// from the live rolling buffer or from a stored Monitor history window
/// (per-interface rates and per-sensor temperatures since migration 044).
class MetricDevices {
  const MetricDevices({
    required this.names,
    required this.byDevice,
    required this.defaults,
    required this.subtitle,
    this.alone,
    this.legend,
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

  /// A device's line in the legend, where [byDevice] is one of several things
  /// the device has: the network's is its upload. Null for its name.
  final String Function(String)? legend;

  /// The devices behind [kind], or null for a metric that has none and for a
  /// machine with only one of them — there is nothing to pick from or to tell
  /// apart.
  static MetricDevices? of(
    ServerState srv,
    ServerMetricKind kind, {
    MetricWindow? window,
  }) {
    final ss = srv.status;
    final w = window ?? MetricWindow.live(ss.history);
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
          byDevice: w.diskWritesByDevice,
          defaults: names.take(kMaxDeviceLines).toList(),
          subtitle: (d) {
            final (r, wr) = io.speedBytes(d);
            return '${ReadingFmt.rate(wr)} ${l10n.write} · ${ReadingFmt.rate(r)} ${l10n.read}';
          },
          alone: (d) => [
            HistorySeries(
              '$d ${l10n.write}',
              ChartPalette.lines[0],
              w.diskWritesByDevice[d] ?? const [],
            ),
            HistorySeries(
              '$d ${l10n.read}',
              ChartPalette.lines[1],
              w.diskReadsByDevice[d] ?? const [],
            ),
          ],
        );
      case ServerMetricKind.netSpeed:
        final ns = ss.netSpeed;
        final live = window == null;
        return _net(
          ns,
          busy: (d) {
            if (live) {
              return (ns.speedInBytesOf(device: d) ?? 0) +
                  (ns.speedOutBytesOf(device: d) ?? 0);
            }
            return _peakOf(w.netRxByDevice[d]) + _peakOf(w.netTxByDevice[d]);
          },
          tx: w.netTxByDevice,
          rx: w.netRxByDevice,
          subtitle: (d) {
            final present = ns.now.any((e) => e.device == d);
            final txRate = present
                ? ns.speedOutBytesOf(device: d)
                : _latest(w.netTxByDevice[d] ?? const []);
            final rxRate = present
                ? ns.speedInBytesOf(device: d)
                : _latest(w.netRxByDevice[d] ?? const []);
            return '↑ ${ReadingFmt.rate(txRate)} · ↓ ${ReadingFmt.rate(rxRate)}';
          },
        );
      case ServerMetricKind.netTraffic:
        final ns = ss.netSpeed;
        final live = window == null;
        double? total(BigInt? v) => v?.toDouble();
        Map<String, List<double?>> added(Map<String, List<double?>> rates) => {
          for (final MapEntry(:key, :value) in rates.entries)
            key: cumulativeBytes(w.times, value),
        };
        return _net(
          ns,
          busy: (d) {
            if (live) {
              return (total(ns.sizeInBytesOf(device: d)) ?? 0) +
                  (total(ns.sizeOutBytesOf(device: d)) ?? 0);
            }
            return _peakOf(w.netRxByDevice[d]) + _peakOf(w.netTxByDevice[d]);
          },
          tx: added(w.netTxByDevice),
          rx: added(w.netRxByDevice),
          subtitle: (d) {
            final present = ns.now.any((e) => e.device == d);
            final txTotal = present ? total(ns.sizeOutBytesOf(device: d)) : null;
            final rxTotal = present ? total(ns.sizeInBytesOf(device: d)) : null;
            return '↑ ${ReadingFmt.size(txTotal)} · ↓ ${ReadingFmt.size(rxTotal)}';
          },
        );
      case ServerMetricKind.temp:
        final names = {
          ...ss.temps.devices,
          ...w.tempsByDevice.keys,
        }.toList()
          ..sort((a, b) {
            final va = ss.temps.get(a) ?? _latest(w.tempsByDevice[a] ?? const []) ?? -1;
            final vb = ss.temps.get(b) ?? _latest(w.tempsByDevice[b] ?? const []) ?? -1;
            return vb.compareTo(va);
          });
        if (names.length < 2) return null;
        return MetricDevices(
          names: names,
          byDevice: w.tempsByDevice,
          // Not the hottest few: a Mac reports fourteen PMU dies within a
          // degree of each other, and picking by temperature alone draws them
          // all and drops the SSD.
          defaults: switch ([
            for (final s in _tempSeries(w))
              if (names.contains(s.label)) s.label,
          ]) {
            // History with the aggregate only — seeded from an agent, before
            // the first live sample — names no sensor: the hottest stands in.
            [] => [names.first],
            final picked => picked,
          },
          subtitle: (d) {
            final v = ss.temps.get(d) ?? _latest(w.tempsByDevice[d] ?? const []);
            return v == null ? '--' : ReadingFmt.temp(v);
          },
        );
      case ServerMetricKind.swap:
        // By priority, the order the kernel fills them in: fixed, so an area
        // keeps its place and colour as the usage moves.
        final areas = [...ss.swapAreas]..sort((a, b) => b.priority.compareTo(a.priority));
        if (areas.length < 2) return null;
        final total = libL10n.total;
        final byPath = {for (final a in areas) a.path: a};
        return MetricDevices(
          // The total first and drawn by default: it is what the row reads.
          names: [total, ...byPath.keys],
          byDevice: {total: w.swap, ...w.swapsByDevice},
          defaults: [total],
          subtitle: (d) {
            final a = byPath[d];
            if (a == null) {
              return '${ReadingFmt.pct(ss.swap.usedPercent * 100)} · '
                  '${ReadingFmt.size(ss.swap.total * 1024.0)}';
            }
            return '${ReadingFmt.pct(switch (a.usedPercent) {
              final p? => p * 100,
              null => null,
            })} · '
                '${ReadingFmt.size(a.used.toDouble())} / ${ReadingFmt.size(a.size.toDouble())} · '
                '${l10n.priority} ${a.priority}';
          },
        );
      case ServerMetricKind.cpu:
      case ServerMetricKind.mem:
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
  final names = {
    ...ns.ifaces,
    ...tx.keys,
    ...rx.keys,
  }.where((d) => !NetSpeed.isLoopback(d)).toList()
    ..sort((a, b) => busy(b).compareTo(busy(a)));
  if (names.length < 2) return null;
  // Only interfaces the window has samples for: one present now but idle
  // throughout a stored window draws nothing.
  bool recorded(String d) =>
      (tx[d]?.any((v) => v != null) ?? false) ||
      (rx[d]?.any((v) => v != null) ?? false);
  final withData = names.where(recorded).toList();
  final pool = withData.isNotEmpty ? withData : names;
  final real = pool.where((d) =>
      ns.realIfaces.contains(d) ||
      NetSpeed.realIfacePrefixs.any((p) => d.startsWith(p)));
  final defaults = (real.isNotEmpty ? real : pool)
      .take(kMaxDeviceLines)
      .toList();
  return MetricDevices(
    names: names,
    // Out, as the row and the headline lead with it.
    byDevice: tx,
    defaults: defaults,
    subtitle: subtitle,
    legend: (d) => '$d ↑',
    alone: (d) => [
      HistorySeries('$d ↑', ChartPalette.lines[0], tx[d] ?? const []),
      HistorySeries('$d ↓', ChartPalette.lines[1], rx[d] ?? const []),
    ],
  );
}

double _peakOf(List<double?>? values) {
  if (values == null) return 0;
  var top = 0.0;
  for (final v in values) {
    if (v != null && v > top) top = v;
  }
  return top;
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

List<HistorySeries> _tempSeries(MetricWindow w) {
  if (w.tempsByDevice.isEmpty) {
    return [HistorySeries(libL10n.temperature, ChartPalette.accent, w.temp)];
  }

  // Hottest first, so "the hottest match in this group" falls out of a
  // single pass and any leftovers are already ranked
  final ranked = w.tempsByDevice.entries.toList()
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
