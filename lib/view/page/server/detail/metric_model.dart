import 'package:fl_lib/fl_lib.dart';
import 'package:flutter/material.dart';
import 'package:icons_plus/icons_plus.dart';
import 'package:server_box/core/extension/context/locale.dart';
import 'package:server_box/data/model/app/server_detail_card.dart';
import 'package:server_box/data/model/server/server.dart';
import 'package:server_box/data/model/server/status_history.dart';
import 'package:server_box/data/model/server/system.dart';
import 'package:server_box/data/provider/server/single.dart';
import 'package:server_box/data/res/chart_palette.dart';
import 'package:server_box/view/page/server/card/metric.dart';
import 'package:server_box/view/page/server/chart.dart';
import 'package:server_box/view/page/server/reading_text.dart';

/// How far back the chart looks.
///
/// [live] is what this app has watched happen since it connected — the one
/// window every server has, because it is kept here. The rest are asked of a
/// monitor agent, which is the only thing that stores anything.
enum HistoryRange {
  live(null, 'live'),
  m5(5, '5m'),
  h1(60, '1h'),
  h6(360, '6h'),
  h24(1440, '24h'),
  d7(10080, '7d'),
  d30(43200, '30d');

  const HistoryRange(this.minutes, this._short);

  /// Null for [live]. The agent clamps this to 5 minutes … 7 days, which is
  /// what this list stays inside.
  final int? minutes;

  final String _short;

  String get label => this == live ? l10n.rangeLive : _short;

  /// The ones offered on the card itself. The rest are behind the picker,
  /// because a row of six chips is a row nobody reads.
  static const inline = [live, h1, h24];
}

/// One figure beside a metric's headline, and what it is of.
typedef MetricStat = ({String k, String v});

/// One metric: a value now, a line over time, and — when it is the one being
/// read — whatever else the machine says about it.
///
/// Everything the rows and the focus card draw, worked out once per build off
/// the same samples, so a row and the chart above it can never disagree.
///
/// What is here and what is a card below is one question: whether the machine
/// reports a value that can be read off a line. Everything that can is a row,
/// including the three the page used to draw as cards of their own (GPU load,
/// the hottest sensor, the battery); a table or a one-off reading cannot be,
/// and stays a card.
class DetailMetric {
  const DetailMetric({
    required this.kind,
    required this.label,
    required this.icon,
    required this.value,
    required this.note,
    required this.bigNote,
    required this.series,
    required this.format,
    this.percent,
    this.stats = const [],
    this.binary = false,
    this.error,
  });

  final ServerMetricKind kind;
  final String label;
  final IconData icon;

  // No colour. Every reading is drawn in the same one, which is the theme's
  // and not the reading's — see [ChartPalette.accent]. The lines of [series]
  // are the exception, and carry their own.

  /// The reading now, as the row and the headline both show it.
  final String value;

  /// What the row says beside the value: what the percentage is of, or the
  /// peak of the window for a rate.
  final String note;

  /// Beside the headline in the focus card.
  final String bigNote;

  /// 0-1 for a percentage metric, null for a rate: only the first kind has a
  /// bar, because only it has a full.
  final double? percent;

  final List<MetricStat> stats;
  final List<HistorySeries> series;
  final String Function(double) format;

  /// Whether the axis should step in multiples of 1024.
  final bool binary;

  /// What this metric's section of the status said instead of a reading.
  ///
  /// Not a page-wide banner: the rest of the readings are fine, and a failure
  /// that takes the whole page with it hides the nine things that did work.
  final String? error;

  bool get hasChart => series.any((s) => s.hasSpots);

  /// The same metric, with what its section said instead of a reading.
  DetailMetric failing(String error) => DetailMetric(
    kind: kind,
    label: label,
    icon: icon,
        value: l10n.unavailable,
    note: error,
    bigNote: '',
    series: const [],
    format: format,
    error: error,
  );
}

/// What one range answered, and the instant it describes.
typedef HistoryRangeAnswer = ({List<StatusHistorySample> samples, DateTime at});

/// The values of every series over one window, whichever source they came
/// from: this app's rolling buffer, or the agent's store.
class MetricWindow {
  const MetricWindow({
    this.times = const [],
    this.cpu = const [],
    this.mem = const [],
    this.swap = const [],
    this.disk = const [],
    this.diskRead = const [],
    this.diskWrite = const [],
    this.netRx = const [],
    this.netTx = const [],
    this.gpu = const [],
    this.temp = const [],
    this.battery = const [],
  });

  /// What this app has seen, which is every series it can measure.
  factory MetricWindow.live(StatusHistory h) => MetricWindow(
    times: h.time,
    cpu: h.cpu,
    mem: h.mem,
    swap: h.swap,
    disk: h.disk,
    diskRead: h.diskRead,
    diskWrite: h.diskWrite,
    netRx: h.netRx,
    netTx: h.netTx,
    gpu: h.gpu,
    temp: h.temp,
    battery: h.battery,
  );

  /// What the agent stored. An agent too old to report a series leaves it
  /// empty here however long the window is — see [DetailMetric.hasChart],
  /// which is what the card asks before drawing. GPU load is empty for every
  /// agent: nothing stores it, so the only window it has is the live one.
  factory MetricWindow.of(List<StatusHistorySample> samples) => MetricWindow(
    times: [for (final s in samples) s.timeMs],
    cpu: [for (final s in samples) s.cpu],
    mem: [for (final s in samples) s.mem],
    swap: [for (final s in samples) s.swap],
    disk: [for (final s in samples) s.disk],
    diskRead: [for (final s in samples) s.diskRead],
    diskWrite: [for (final s in samples) s.diskWrite],
    netRx: [for (final s in samples) s.netRx],
    netTx: [for (final s in samples) s.netTx],
    temp: [for (final s in samples) s.temp],
    battery: [for (final s in samples) s.battery],
  );

  /// When each sample was taken, index-aligned with every series.
  final List<int> times;

  final List<double?> cpu;
  final List<double?> mem;
  final List<double?> swap;
  final List<double?> disk;
  final List<double?> diskRead;
  final List<double?> diskWrite;
  final List<double?> netRx;
  final List<double?> netTx;
  final List<double?> gpu;
  final List<double?> temp;
  final List<double?> battery;
}

/// The status sections a metric's reading comes from, by the names both
/// mappers record failures under. A metric is broken when any of them is.
const _kMetricSections = <ServerMetricKind, List<String>>{
  ServerMetricKind.cpu: ['cpu'],
  ServerMetricKind.mem: ['mem'],
  ServerMetricKind.swap: ['swap'],
  ServerMetricKind.disk: ['disk'],
  ServerMetricKind.diskIo: ['diskio'],
  ServerMetricKind.net: ['net'],
  ServerMetricKind.gpu: ['gpu', 'gpus'],
  ServerMetricKind.temp: ['temps'],
  ServerMetricKind.battery: ['battery'],
};

/// What went wrong reading [kind], if anything did.
String? _sectionErr(ServerStatus ss, ServerMetricKind kind) {
  for (final section in _kMetricSections[kind] ?? const <String>[]) {
    if (ss.sectionErrs[section] case final err?) return err;
  }
  return null;
}

/// A row for one of the five every machine has, whose section could not be
/// read.
///
/// Absence is a claim about the machine — that it has no such hardware — and
/// for these five it is never the true one. So the row stays where it was and
/// says what happened to the reading, rather than leaving the reader to notice
/// that a line is gone.
DetailMetric _failedMetric(
  ServerMetricKind kind,
  String label,
  IconData icon,
  String err,
) => DetailMetric(
  kind: kind,
  label: label,
  icon: icon,
    value: '',
  note: '',
  bigNote: '',
  series: const [],
  format: ReadingFmt.pct,
).failing(err);

/// The rows a machine has before it has answered.
///
/// Every machine has these five, so they are drawn with dashes rather than
/// left out: what the page looks like while it waits is what it will look
/// like, and one that grows a row at a time as the first status lands moves
/// everything under each one. The first answer replaces them — and removes the
/// ones this machine does not report, which is the one shape change worth
/// making.
List<DetailMetric> _blankMetrics() {
  DetailMetric dash(ServerMetricKind kind, String label, IconData icon) =>
      DetailMetric(
        kind: kind,
        label: label,
        icon: icon,
        value: ReadingFmt.pct(null),
        note: '',
        bigNote: '',
        series: const [],
        format: ReadingFmt.pct,
      );

  return [
    dash(ServerMetricKind.cpu, 'CPU', ServerDetailCards.cpu.icon),
    dash(ServerMetricKind.mem, libL10n.memory, ServerDetailCards.mem.icon),
    dash(ServerMetricKind.swap, 'Swap', ServerDetailCards.swap.icon),
    dash(ServerMetricKind.disk, libL10n.disk, ServerDetailCards.disk.icon),
    dash(ServerMetricKind.net, libL10n.net, ServerDetailCards.net.icon),
  ];
}

/// How many lines a metric's devices are drawn as at most.
///
/// The palette's length, and about as many as a chart this size can be read
/// with. A host with more says so and opens the rest in the picker.
const kMaxDeviceLines = 6;

/// What the agent will answer with at most, and as many as a chart this wide
/// can draw.
const kHistoryRangePoints = 300;

// --- What the rows and the focus card are made of ---

/// Every metric this machine reports, in the order they are read in.
///
/// A metric the machine does not have is absent rather than dimmed: a row
/// still costs a line to scan past, and one that can never have a value
/// reads as broken. What is missing is said once, under the list.
///
/// [deviceSeries] is the line per device the page draws for a metric, and
/// null where the totals are what there is — see `_deviceSeries`.
List<DetailMetric> serverDetailMetrics(
  ServerState si,
  MetricWindow w, {
  required List<HistorySeries>? Function(ServerMetricKind kind) deviceSeries,
}) {
  final ss = si.status;
  if (serverNeverSampled(si)) return _blankMetrics();
  final views = <DetailMetric>[];

  // Always a row, even before the first sample: every machine has a CPU, so
  // an absent row would say this one does not rather than that nothing has
  // been measured yet — which is what the dash says.
  final cpu = ss.cpu.usedPercent(coreIdx: 0);
  {
    views.add(
      DetailMetric(
        kind: ServerMetricKind.cpu,
        label: 'CPU',
        icon: ServerDetailCards.cpu.icon,
        value: ReadingFmt.pct(cpu),
        note: ss.cpu.brand.keys.firstOrNull ?? '',
        bigNote: '${ReadingFmt.pct(ss.cpu.idle)} idle',
        percent: cpu == null ? null : cpu / 100,
        // Not idle as well: the line beside the number already says it,
        // and these are read straight after that line.
        stats: [
          (k: 'user', v: ReadingFmt.pct(ss.cpu.user)),
          if (ss.system == SystemType.linux) ...[
            (k: 'sys', v: ReadingFmt.pct(ss.cpu.sys)),
            (k: 'io', v: ReadingFmt.pct(ss.cpu.iowait)),
          ],
        ],
        series: [HistorySeries('CPU', ChartPalette.accent, w.cpu)],
        format: ReadingFmt.pct,
      ),
    );
  }

  if (ss.mem.total > 0) {
    final used = ss.mem.usedPercent * 100;
    final total = (ss.mem.total * 1024).bytes2Str;
    views.add(
      DetailMetric(
        kind: ServerMetricKind.mem,
        label: libL10n.memory,
        icon: ServerDetailCards.mem.icon,
        value: ReadingFmt.pct(used),
        note: '${((ss.mem.total - ss.mem.free) * 1024).bytes2Str} / $total',
        bigNote: l10n.ofFmt(total),
        percent: used / 100,
        stats: [
          (k: 'free', v: ReadingFmt.pct(ss.mem.free / ss.mem.total * 100)),
          (k: 'avail', v: ReadingFmt.pct(ss.mem.availPercent * 100)),
        ],
        series: [HistorySeries(libL10n.memory, ChartPalette.accent, w.mem)],
        format: ReadingFmt.pct,
      ),
    );
  } else if (_sectionErr(ss, ServerMetricKind.mem) case final err?) {
    views.add(
      _failedMetric(
        ServerMetricKind.mem,
        libL10n.memory,
        ServerDetailCards.mem.icon,
        err,
      ),
    );
  }

  if (ss.swap.total > 0) {
    final used = ss.swap.usedPercent * 100;
    final total = (ss.swap.total * 1024).bytes2Str;
    views.add(
      DetailMetric(
        kind: ServerMetricKind.swap,
        label: 'Swap',
        icon: ServerDetailCards.swap.icon,
        value: ReadingFmt.pct(used),
        note: l10n.ofFmt(total),
        bigNote: l10n.ofFmt(total),
        percent: used / 100,
        stats: [
          (k: 'cached', v: ReadingFmt.pct(ss.swap.cached / ss.swap.total * 100)),
        ],
        series: [HistorySeries('Swap', ChartPalette.accent, w.swap)],
        format: ReadingFmt.pct,
      ),
    );
  } else if (_sectionErr(ss, ServerMetricKind.swap) case final err?) {
    views.add(
      _failedMetric(
        ServerMetricKind.swap,
        'Swap',
        ServerDetailCards.swap.icon,
        err,
      ),
    );
  }

  // `diskUsage` is the one reading the card's row, the chart's disk line and
  // the overview also draw — see [ServerStatus.diskUsage]. Null with no disks
  // or an unreadable list, and then there is no row.
  if (ss.diskUsage case final usage?) {
    final used = usage.usedPercent;
    views.add(
      DetailMetric(
        kind: ServerMetricKind.disk,
        label: libL10n.disk,
        icon: ServerDetailCards.disk.icon,
        value: ReadingFmt.pct(used),
        note: '${usage.used.kb2Str} / ${usage.size.kb2Str}',
        bigNote: l10n.ofFmt(usage.size.kb2Str),
        percent: used / 100,
        series: [HistorySeries(libL10n.disk, ChartPalette.accent, w.disk)],
        format: ReadingFmt.pct,
      ),
    );
  } else if (_sectionErr(ss, ServerMetricKind.disk) case final err?) {
    views.add(
      _failedMetric(
        ServerMetricKind.disk,
        libL10n.disk,
        ServerDetailCards.disk.icon,
        err,
      ),
    );
  }

  final (read, write) = ss.diskIO.allSpeedBytes;
  if (read != null || write != null) {
    views.add(
      DetailMetric(
        kind: ServerMetricKind.diskIo,
        label: l10n.diskIo,
        icon: MingCute.transfer_3_line,
        value: ReadingFmt.rate(write),
        // The one that is going to be a problem, not the average of them:
        // a machine with six disks is busy because one of them is.
        note: _busiestNote(
          ss.diskIO.devices.length,
          _busiest(ss.diskIO.devices, (dev) {
            final (r, wr) = ss.diskIO.speedBytes(dev);
            return (r ?? 0) + (wr ?? 0);
          }),
        ),
        bigNote: '${l10n.write} · ${ReadingFmt.rate(read)} ${l10n.read}',
        stats: _rateStats(w.diskWrite),
        // Per device where there is more than one, because that is the
        // question a machine with six disks raises. With one there is
        // nothing to tell apart and the two directions are worth more.
        series:
            deviceSeries(ServerMetricKind.diskIo) ??
            // The one the number above is of first, which is the line in
            // the theme colour — see [ChartPalette.lines].
            [
              HistorySeries(l10n.write, ChartPalette.lines[0], w.diskWrite),
              HistorySeries(l10n.read, ChartPalette.lines[1], w.diskRead),
            ],
        format: ReadingFmt.rateAxis,
        binary: true,
      ),
    );
  }

  final ns = ss.netSpeed;
  if (ns.devices.isNotEmpty) {
    final rx = ns.speedInBytesOf();
    final tx = ns.speedOutBytesOf();
    views.add(
      DetailMetric(
        kind: ServerMetricKind.net,
        label: libL10n.net,
        icon: ServerDetailCards.net.icon,
        value: ReadingFmt.rate(tx),
        note: _busiestNote(
          ns.realIfaces.length,
          _busiest(
            ns.realIfaces,
            (dev) =>
                (ns.speedInBytesOf(device: dev) ?? 0) +
                (ns.speedOutBytesOf(device: dev) ?? 0),
          ),
        ),
        bigNote: '↑ · ${ReadingFmt.rate(rx)} ↓',
        stats: _rateStats(w.netTx),
        series:
            deviceSeries(ServerMetricKind.net) ??
            [
              HistorySeries('↑', ChartPalette.lines[0], w.netTx),
              HistorySeries('↓', ChartPalette.lines[1], w.netRx),
            ],
        format: ReadingFmt.rateAxis,
        binary: true,
      ),
    );
  } else if (_sectionErr(ss, ServerMetricKind.net) case final err?) {
    views.add(
      _failedMetric(
        ServerMetricKind.net,
        libL10n.net,
        ServerDetailCards.net.icon,
        err,
      ),
    );
  }

  // A row rather than a card of its own, like the three above it: what a GPU
  // is doing is one percentage with a line behind it. What it cannot be read
  // off a line — the processes holding its memory, its clock and fans — is
  // the card below, which is what a card is for.
  if (busiestGpu(ss) case final gpu?) {
    final mem = gpu.memory;
    final used = gpu.utilization;
    views.add(
      DetailMetric(
        kind: ServerMetricKind.gpu,
        label: 'GPU',
        icon: ServerDetailCards.gpu.icon,
        value: ReadingFmt.pct(used),
        note: ss.gpus.length > 1
            ? _busiestNote(ss.gpus.length, gpu.name)
            : gpu.name,
        // The card's own, which this line takes over from. It carried the
        // memory too, which is the first of the stats after it.
        bigNote: gpu.name,
        percent: used == null ? null : used / 100,
        stats: [
          if (mem != null)
            (k: libL10n.memory, v: '${mem.used} / ${mem.total} ${mem.unit}'),
          if (gpu.temperature case final t?)
            (k: libL10n.temperature, v: ReadingFmt.temp(t.toDouble())),
        ],
        series: [HistorySeries('GPU', ChartPalette.accent, w.gpu)],
        format: ReadingFmt.pct,
      ),
    );
  }

  if (hottestSensor(ss) case (final sensor, final celsius)) {
    views.add(
      DetailMetric(
        kind: ServerMetricKind.temp,
        label: libL10n.temperature,
        icon: ServerDetailCards.temp.icon,
        value: ReadingFmt.temp(celsius),
        note: ss.temps.devices.length > 1
            ? l10n.sensorsHottestFmt(ss.temps.devices.length, sensor)
            : sensor,
        bigNote: sensor,
        series:
            deviceSeries(ServerMetricKind.temp) ??
            [HistorySeries(libL10n.temperature, ChartPalette.accent, w.temp)],
        format: ReadingFmt.temp,
      ),
    );
  }

  // The first battery, not every one: a laptop has one and a host reporting
  // several is reporting its mouse and its keyboard, which the card below
  // lists in full.
  if (ss.batteries.firstOrNull case final battery?) {
    final percent = battery.percent?.toDouble();
    views.add(
      DetailMetric(
        kind: ServerMetricKind.battery,
        label: libL10n.battery,
        icon: ServerDetailCards.battery.icon,
        value: ReadingFmt.pct(percent),
        note: [battery.status.name, ?battery.name].join(' · '),
        bigNote: battery.status.name,
        percent: percent == null ? null : percent / 100,
        stats: [
          if (battery.cycle case final cycle?) (k: l10n.cycle, v: '$cycle'),
        ],
        series: [HistorySeries(libL10n.battery, ChartPalette.accent, w.battery)],
        format: ReadingFmt.pct,
      ),
    );
  }

  return [
    for (final view in views)
      if (_sectionErr(ss, view.kind) case final err?)
        view.failing(err)
      else
        view,
  ];
}

/// The device carrying the most of this metric right now.
String? _busiest(Iterable<String> devices, double Function(String) of) {
  String? name;
  var top = 0.0;
  for (final device in devices) {
    final value = of(device);
    if (name == null || value > top) {
      name = device;
      top = value;
    }
  }
  return name;
}

/// How many devices a rate is the sum of, and which of them is carrying it.
String _busiestNote(int count, String? busiest) {
  if (count == 0) return '';
  if (busiest == null || count == 1) return l10n.devicesFmt(count);
  return l10n.devicesBusiestFmt(count, busiest);
}

/// What a rate has in place of a full: how high it got in the window on
/// screen.
///
/// And nothing about the window itself. It said how long that was, which for
/// a preset is its name — "Live", under a header whose selected chip says
/// "Live". See `_buildFocusCard` for the one window whose length is not
/// already on screen.
List<MetricStat> _rateStats(List<double?> values) {
  double? peak;
  for (final v in values) {
    if (v == null) continue;
    if (peak == null || v > peak) peak = v;
  }
  return [if (peak != null) (k: l10n.peak, v: ReadingFmt.rate(peak))];
}
