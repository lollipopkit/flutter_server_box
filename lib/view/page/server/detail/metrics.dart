part of 'view.dart';

/// How far back the chart looks.
///
/// [live] is what this app has watched happen since it connected — the one
/// window every server has, because it is kept here. The rest are asked of a
/// monitor agent, which is the only thing that stores anything.
enum _HistoryRange {
  live(null, 'live'),
  m5(5, '5m'),
  h1(60, '1h'),
  h6(360, '6h'),
  h24(1440, '24h'),
  d7(10080, '7d'),
  d30(43200, '30d');

  const _HistoryRange(this.minutes, this._short);

  /// Null for [live]. The agent clamps this to 5 minutes … 7 days, which is
  /// what this list stays inside.
  final int? minutes;

  final String _short;

  String get label => this == live ? l10n.rangeLive : _short;

  /// The ones offered on the card itself. The rest are behind the picker,
  /// because a row of six chips is a row nobody reads.
  static const inline = [live, h1, h24];
}

/// One metric: a value now, a line over time, and — when it is the one being
/// read — whatever else the machine says about it.
///
/// What is here and what is a card below is one question: whether the machine
/// reports a value that can be read off a line. Everything that can is a row,
/// including the three the page used to draw as cards of their own (GPU load,
/// the hottest sensor, the battery); a table or a one-off reading cannot be,
/// and stays a card.
enum _MetricKind { cpu, mem, swap, disk, diskIo, net, gpu, temp, battery }

typedef _Stat = ({String k, String v});

/// Everything the rows and the focus card draw, worked out once per build off
/// the same samples, so a row and the chart above it can never disagree.
class _MetricView {
  const _MetricView({
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

  final _MetricKind kind;
  final String label;
  final IconData icon;

  // No colour. What a reading is drawn in depends on whether it is the one
  // this page is focused on, which is not something a reading knows about
  // itself — see [_seriesColor].

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

  final List<_Stat> stats;
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
  _MetricView failing(String error) => _MetricView(
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
typedef _RangeAnswer = ({List<StatusHistorySample> samples, DateTime at});

/// The values of every series over one window, whichever source they came
/// from: this app's rolling buffer, or the agent's store.
class _Window {
  const _Window({
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
  factory _Window.live(StatusHistory h) => _Window(
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
  /// empty here however long the window is — see [_MetricView.hasChart],
  /// which is what the card asks before drawing. GPU load is empty for every
  /// agent: nothing stores it, so the only window it has is the live one.
  factory _Window.of(List<StatusHistorySample> samples) => _Window(
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

/// How a reading is written, wherever it is written: the row, the headline,
/// the stats and the picker all say the same number the same way.
String _pct(double? v) => v == null ? '--' : '${(v * 10).round() / 10}%';
String _rate(double? bytesPerSec) =>
    bytesPerSec == null ? '--' : '${bytesPerSec.bytes2Str}/s';
String _rateOf(double v) => '${v.bytes2Str}/s';

/// The status sections a metric's reading comes from, by the names both
/// mappers record failures under. A metric is broken when any of them is.
const _kMetricSections = <_MetricKind, List<String>>{
  _MetricKind.cpu: ['cpu'],
  _MetricKind.mem: ['mem'],
  _MetricKind.swap: ['swap'],
  _MetricKind.disk: ['disk'],
  _MetricKind.diskIo: ['diskio'],
  _MetricKind.net: ['net'],
  _MetricKind.gpu: ['gpu', 'gpus'],
  _MetricKind.temp: ['temps'],
  _MetricKind.battery: ['battery'],
};

/// What went wrong reading [kind], if anything did.
String? _sectionErr(server_model.ServerStatus ss, _MetricKind kind) {
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
_MetricView _failedMetric(
  _MetricKind kind,
  String label,
  IconData icon,
  String err,
) => _MetricView(
  kind: kind,
  label: label,
  icon: icon,
    value: '',
  note: '',
  bigNote: '',
  series: const [],
  format: _pct,
).failing(err);

/// Whether this server has said anything about itself yet.
bool _neverSampled(ServerState si) =>
    si.status.more.isEmpty && si.status.history.isEmpty;

/// The rows a machine has before it has answered.
///
/// Every machine has these five, so they are drawn with dashes rather than
/// left out: what the page looks like while it waits is what it will look
/// like, and one that grows a row at a time as the first status lands moves
/// everything under each one. The first answer replaces them — and removes the
/// ones this machine does not report, which is the one shape change worth
/// making.
List<_MetricView> _blankMetrics() {
  _MetricView dash(_MetricKind kind, String label, IconData icon) =>
      _MetricView(
        kind: kind,
        label: label,
        icon: icon,
        value: _pct(null),
        note: '',
        bigNote: '',
        series: const [],
        format: _pct,
      );

  return [
    dash(_MetricKind.cpu, 'CPU', ServerDetailCards.cpu.icon),
    dash(_MetricKind.mem, libL10n.memory, ServerDetailCards.mem.icon),
    dash(_MetricKind.swap, 'Swap', ServerDetailCards.swap.icon),
    dash(_MetricKind.disk, libL10n.disk, ServerDetailCards.disk.icon),
    dash(_MetricKind.net, libL10n.net, ServerDetailCards.net.icon),
  ];
}

/// The GPU carrying the most work — the one the row reads, and the one the
/// card leads with. Null on a host with no GPU at all; the first card on one
/// whose driver reports no utilisation.
GpuItem? _busiestGpu(server_model.ServerStatus ss) {
  GpuItem? top;
  for (final gpu in ss.gpus) {
    if (top == null || (gpu.utilization ?? -1) > (top.utilization ?? -1)) {
      top = gpu;
    }
  }
  return top;
}

/// The sensor the temperature row reads: the hottest, which is the one that
/// will be a problem. Null on a host whose sensors have no reading yet.
(String, double)? _hottestSensor(server_model.ServerStatus ss) {
  String? name;
  double? top;
  for (final device in ss.temps.devices) {
    final value = ss.temps.get(device);
    if (value == null) continue;
    if (top == null || value > top) {
      name = device;
      top = value;
    }
  }
  return name == null || top == null ? null : (name, top);
}

/// How many lines a metric's devices are drawn as at most.
///
/// The palette's length, and about as many as a chart this size can be read
/// with. A host with more says so and opens the rest in the picker.
const _kMaxDeviceLines = 6;

/// The block the chart lives in, by width.
///
/// A height, not a minimum: every state of it — a chart, one with a legend
/// under it, a request in flight, a metric with nothing stored — is this tall,
/// so moving between metrics does not move the rows below.
const _kFocusChartHeight = 216.0;
const _kFocusChartHeightNarrow = 140.0;


// --- What the rows and the focus card are made of ---

extension on _ServerDetailPageState {
  /// Every metric this machine reports, in the order they are read in.
  ///
  /// A metric the machine does not have is absent rather than dimmed: a row
  /// still costs a line to scan past, and one that can never have a value
  /// reads as broken. What is missing is said once, under the list.
  List<_MetricView> _metrics(ServerState si, _Window w) {
    final ss = si.status;
    if (_neverSampled(si)) return _blankMetrics();
    final views = <_MetricView>[];

    // Always a row, even before the first sample: every machine has a CPU, so
    // an absent row would say this one does not rather than that nothing has
    // been measured yet — which is what the dash says.
    final cpu = ss.cpu.usedPercent(coreIdx: 0);
    {
      views.add(
        _MetricView(
          kind: _MetricKind.cpu,
          label: 'CPU',
          icon: ServerDetailCards.cpu.icon,
          value: _pct(cpu),
          note: ss.cpu.brand.keys.firstOrNull ?? '',
          bigNote: '${_pct(ss.cpu.idle)} idle',
          percent: cpu == null ? null : cpu / 100,
          stats: [
            (k: 'user', v: _pct(ss.cpu.user)),
            if (ss.system == SystemType.linux) ...[
              (k: 'sys', v: _pct(ss.cpu.sys)),
              (k: 'io', v: _pct(ss.cpu.iowait)),
            ],
            (k: 'idle', v: _pct(ss.cpu.idle)),
          ],
          series: [HistorySeries('CPU', ChartPalette.promoted, w.cpu)],
          format: _pct,
        ),
      );
    }

    if (ss.mem.total > 0) {
      final used = ss.mem.usedPercent * 100;
      final total = (ss.mem.total * 1024).bytes2Str;
      views.add(
        _MetricView(
          kind: _MetricKind.mem,
          label: libL10n.memory,
          icon: ServerDetailCards.mem.icon,
          value: _pct(used),
          note: '${((ss.mem.total - ss.mem.free) * 1024).bytes2Str} / $total',
          bigNote: l10n.ofFmt(total),
          percent: used / 100,
          stats: [
            (k: 'free', v: _pct(ss.mem.free / ss.mem.total * 100)),
            (k: 'avail', v: _pct(ss.mem.availPercent * 100)),
          ],
          series: [HistorySeries(libL10n.memory, ChartPalette.promoted, w.mem)],
          format: _pct,
        ),
      );
    } else if (_sectionErr(ss, _MetricKind.mem) case final err?) {
      views.add(
        _failedMetric(
          _MetricKind.mem,
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
        _MetricView(
          kind: _MetricKind.swap,
          label: 'Swap',
          icon: ServerDetailCards.swap.icon,
          value: _pct(used),
          note: l10n.ofFmt(total),
          bigNote: l10n.ofFmt(total),
          percent: used / 100,
          stats: [
            (k: 'cached', v: _pct(ss.swap.cached / ss.swap.total * 100)),
          ],
          series: [HistorySeries('Swap', ChartPalette.promoted, w.swap)],
          format: _pct,
        ),
      );
    } else if (_sectionErr(ss, _MetricKind.swap) case final err?) {
      views.add(
        _failedMetric(
          _MetricKind.swap,
          'Swap',
          ServerDetailCards.swap.icon,
          err,
        ),
      );
    }

    if (ss.disk.isNotEmpty) {
      final usage = DiskUsage.parse(ss.disk);
      final used = usage.usedPercent;
      views.add(
        _MetricView(
          kind: _MetricKind.disk,
          label: libL10n.disk,
          icon: ServerDetailCards.disk.icon,
          value: _pct(used),
          note: '${usage.used.kb2Str} / ${usage.size.kb2Str}',
          bigNote: l10n.ofFmt(usage.size.kb2Str),
          percent: used / 100,
          series: [HistorySeries(libL10n.disk, ChartPalette.promoted, w.disk)],
          format: _pct,
        ),
      );
    } else if (_sectionErr(ss, _MetricKind.disk) case final err?) {
      views.add(
        _failedMetric(
          _MetricKind.disk,
          libL10n.disk,
          ServerDetailCards.disk.icon,
          err,
        ),
      );
    }

    final (read, write) = ss.diskIO.allSpeedBytes;
    if (read != null || write != null) {
      views.add(
        _MetricView(
          kind: _MetricKind.diskIo,
          label: l10n.diskIo,
          icon: MingCute.transfer_3_line,
          value: _rate(write),
          // The one that is going to be a problem, not the average of them:
          // a machine with six disks is busy because one of them is.
          note: _busiestNote(
            ss.diskIO.devices.length,
            _busiest(ss.diskIO.devices, (dev) {
              final (r, wr) = ss.diskIO.speedBytes(dev);
              return (r ?? 0) + (wr ?? 0);
            }),
          ),
          bigNote: '${l10n.write} · ${_rate(read)} ${l10n.read}',
          stats: _rateStats(w.diskWrite),
          // Per device where there is more than one, because that is the
          // question a machine with six disks raises. With one there is
          // nothing to tell apart and the two directions are worth more.
          series:
              _deviceSeries(si, _MetricKind.diskIo) ??
              [
                HistorySeries(l10n.read, ChartPalette.devices[0], w.diskRead),
                HistorySeries(l10n.write, ChartPalette.devices[1], w.diskWrite),
              ],
          format: _rateOf,
          binary: true,
        ),
      );
    }

    final ns = ss.netSpeed;
    if (ns.devices.isNotEmpty) {
      final rx = ns.speedInBytesOf();
      final tx = ns.speedOutBytesOf();
      views.add(
        _MetricView(
          kind: _MetricKind.net,
          label: libL10n.net,
          icon: ServerDetailCards.net.icon,
          value: _rate(tx),
          note: _busiestNote(
            ns.realIfaces.length,
            _busiest(
              ns.realIfaces,
              (dev) =>
                  (ns.speedInBytesOf(device: dev) ?? 0) +
                  (ns.speedOutBytesOf(device: dev) ?? 0),
            ),
          ),
          bigNote: '↑ · ${_rate(rx)} ↓',
          stats: _rateStats(w.netTx),
          series:
              _deviceSeries(si, _MetricKind.net) ??
              [
                HistorySeries('↓', ChartPalette.devices[0], w.netRx),
                HistorySeries('↑', ChartPalette.devices[1], w.netTx),
              ],
          format: _rateOf,
          binary: true,
        ),
      );
    } else if (_sectionErr(ss, _MetricKind.net) case final err?) {
      views.add(
        _failedMetric(
          _MetricKind.net,
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
    if (_busiestGpu(ss) case final gpu?) {
      final mem = gpu.memory;
      final used = gpu.utilization;
      views.add(
        _MetricView(
          kind: _MetricKind.gpu,
          label: 'GPU',
          icon: ServerDetailCards.gpu.icon,
          value: _pct(used),
          note: ss.gpus.length > 1
              ? _busiestNote(ss.gpus.length, gpu.name)
              : gpu.name,
          bigNote: mem == null
              ? gpu.name
              : '${gpu.name} · ${mem.used} ${l10n.ofFmt('${mem.total} ${mem.unit}')}',
          percent: used == null ? null : used / 100,
          stats: [
            if (mem != null)
              (k: libL10n.memory, v: '${mem.used} / ${mem.total} ${mem.unit}'),
            if (gpu.temperature case final t?)
              (k: libL10n.temperature, v: _formatTemp(t.toDouble())),
          ],
          series: [HistorySeries('GPU', ChartPalette.promoted, w.gpu)],
          format: _pct,
        ),
      );
    }

    if (_hottestSensor(ss) case (final sensor, final celsius)) {
      views.add(
        _MetricView(
          kind: _MetricKind.temp,
          label: libL10n.temperature,
          icon: ServerDetailCards.temp.icon,
          value: _formatTemp(celsius),
          note: ss.temps.devices.length > 1
              ? l10n.sensorsHottestFmt(ss.temps.devices.length, sensor)
              : sensor,
          bigNote: sensor,
          series:
              _deviceSeries(si, _MetricKind.temp) ??
              [HistorySeries(libL10n.temperature, ChartPalette.promoted, w.temp)],
          format: _formatTemp,
        ),
      );
    }

    // The first battery, not every one: a laptop has one and a host reporting
    // several is reporting its mouse and its keyboard, which the card below
    // lists in full.
    if (ss.batteries.firstOrNull case final battery?) {
      final percent = battery.percent?.toDouble();
      views.add(
        _MetricView(
          kind: _MetricKind.battery,
          label: libL10n.battery,
          icon: ServerDetailCards.battery.icon,
          value: _pct(percent),
          note: [battery.status.name, ?battery.name].join(' · '),
          bigNote: battery.status.name,
          percent: percent == null ? null : percent / 100,
          stats: [
            if (battery.cycle case final cycle?) (k: l10n.cycle, v: '$cycle'),
          ],
          series: [HistorySeries(libL10n.battery, ChartPalette.promoted, w.battery)],
          format: _pct,
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
  static String? _busiest(Iterable<String> devices, double Function(String) of) {
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
  /// screen, and how wide that window is.
  List<_Stat> _rateStats(List<double?> values) {
    double? peak;
    for (final v in values) {
      if (v == null) continue;
      if (peak == null || v > peak) peak = v;
    }
    return [
      if (peak != null) (k: l10n.peak, v: _rate(peak)),
      // The length of the window, not its name: a named one has no short name
      // and its two timestamps are the header's business.
      (k: l10n.window, v: _windowLength()),
    ];
  }
}

// --- The devices a metric is the sum of ---

/// What one metric's devices are, and what is known about each of them.
///
/// A metric's row is a total, and a total is not what a host with six disks is
/// read for. The focus chart draws one line per device instead, which is only
/// possible for the window this app kept itself — nothing stores a series per
/// device.
class _Devices {
  const _Devices({
    required this.names,
    required this.byDevice,
    required this.defaults,
    required this.subtitle,
  });

  /// Busiest first, which is also the order the picker lists them in.
  final List<String> names;

  /// The samples behind each of [names], as [StatusHistory] kept them.
  final Map<String, List<double?>> byDevice;

  /// Drawn when the reader has not chosen: the busiest few, or for sensors the
  /// one per component [_ServerDetailPageState._tempSeries] settles on.
  final List<String> defaults;

  /// What the picker says under a device's name — its reading now, which is
  /// what the choice is made on.
  final String Function(String) subtitle;
}

extension on _ServerDetailPageState {
  /// The devices behind [kind], or null for a metric that has none and for a
  /// machine with only one of them — there is nothing to pick from or to tell
  /// apart.
  _Devices? _devicesOf(ServerState si, _MetricKind kind) {
    final ss = si.status;
    final h = ss.history;
    switch (kind) {
      case _MetricKind.diskIo:
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
        return _Devices(
          names: names,
          // The direction the row and the headline lead with. Six devices in
          // both directions is twelve lines, which is a picture of nothing.
          byDevice: h.diskWritesByDevice,
          defaults: names.take(_kMaxDeviceLines).toList(),
          subtitle: (d) {
            final (r, w) = io.speedBytes(d);
            return '${_rate(w)} ${l10n.write} · ${_rate(r)} ${l10n.read}';
          },
        );
      case _MetricKind.net:
        final ns = ss.netSpeed;
        final names = [...ns.realIfaces]
          ..sort((a, b) {
            double of(String d) =>
                (ns.speedInBytesOf(device: d) ?? 0) +
                (ns.speedOutBytesOf(device: d) ?? 0);
            return of(b).compareTo(of(a));
          });
        if (names.length < 2) return null;
        return _Devices(
          names: names,
          byDevice: h.netTxByDevice,
          defaults: names.take(_kMaxDeviceLines).toList(),
          // The totals below the rates: they are what an interface has moved
          // since the machine came up, which is the other thing a list of
          // interfaces is read for.
          subtitle: (d) =>
              '↑ ${_rate(ns.speedOutBytesOf(device: d))} · '
              '↓ ${_rate(ns.speedInBytesOf(device: d))}\n'
              '${ns.sizeOut(device: d)} | ${ns.sizeIn(device: d)}',
        );
      case _MetricKind.temp:
        final names = [...ss.temps.devices]
          ..sort((a, b) => (ss.temps.get(b) ?? -1).compareTo(ss.temps.get(a) ?? -1));
        if (names.length < 2) return null;
        return _Devices(
          names: names,
          byDevice: h.tempsByDevice,
          // Not the hottest few: a Mac reports fourteen PMU dies within a
          // degree of each other, and picking by temperature alone draws them
          // all and drops the SSD.
          defaults: [
            for (final s in _tempSeries(si))
              if (names.contains(s.label)) s.label,
          ],
          subtitle: (d) {
            final v = ss.temps.get(d);
            return v == null ? '--' : _formatTemp(v);
          },
        );
      case _MetricKind.cpu:
      case _MetricKind.mem:
      case _MetricKind.swap:
      case _MetricKind.disk:
      case _MetricKind.gpu:
      case _MetricKind.battery:
        return null;
    }
  }

  /// The devices drawn for [kind], in [_Devices.names] order so a device keeps
  /// its colour as the busiest one changes.
  List<String> _plottedDevices(_MetricKind kind, _Devices devices) {
    final picked = _devicePick[kind];
    if (picked == null) return devices.defaults;
    return [
      for (final name in devices.names)
        if (picked.contains(name)) name,
    ];
  }

  /// One line per device, or null where the aggregate is what there is: a
  /// single device, or a window that came from a store that has only totals.
  List<HistorySeries>? _deviceSeries(ServerState si, _MetricKind kind) {
    // These come from the rolling buffer, whose samples are the live window's.
    // Drawn against any other window they would be plotted at instants they
    // were not taken at.
    if (_custom != null || _range != _HistoryRange.live) return null;
    final devices = _devicesOf(si, kind);
    if (devices == null) return null;
    final series = [
      for (final (i, name) in _plottedDevices(kind, devices).indexed)
        HistorySeries(
          name,
          _kDeviceColors[i % _kDeviceColors.length],
          devices.byDevice[name] ?? const <double?>[],
        ),
    ];
    // Before the first sample of a device that only just appeared there is
    // nothing under its name, and a legend of empty lines is worse than the
    // totals.
    return series.any((s) => s.hasSpots) ? series : null;
  }
}

// --- The section itself ---

extension on _ServerDetailPageState {
  /// The window the chart is drawing, which is either what this app has seen
  /// or what the agent answered for the chosen range.
  _Window _window(ServerState si) {
    if (_custom != null) {
      final answer = _customAnswer;
      return answer == null ? const _Window() : _Window.of(answer.samples);
    }
    final minutes = _range.minutes;
    if (minutes == null) return _Window.live(si.status.history);
    final answer = _rangeWindows[_range];
    if (answer == null) return const _Window();
    return _Window.of(answer.samples);
  }

  /// How long after the last sample the live window starts showing a gap.
  ///
  /// Three polls, and never under half a minute: one poll running long is a
  /// slow script, not a stopped app, and a band that appears every time a
  /// refresh takes its time teaches the reader to ignore bands.
  Duration get _staleAfter {
    final seconds = _settings.serverStatusUpdateInterval.fetch();
    final polls = Duration(seconds: (seconds > 0 ? seconds : 10) * 3);
    return polls < const Duration(seconds: 30)
        ? const Duration(seconds: 30)
        : polls;
  }

  /// When the newest sample was taken, if that is long enough ago to be worth
  /// saying — otherwise null, which is the ordinary case.
  ///
  /// A backgrounded app runs no timers, so a page returned to after four
  /// minutes is showing four-minute-old numbers that look exactly like current
  /// ones. Nothing on the page moves to say so, which is why this is said in
  /// three places at once: here, in the rows, and as the gap at the end of the
  /// chart.
  DateTime? _staleSince(ServerState si) {
    final times = si.status.history.time;
    if (times.isEmpty) return null;
    final at = DateTime.fromMillisecondsSinceEpoch(times.last);
    return DateTime.now().difference(at) > _staleAfter ? at : null;
  }

  /// The axis the chart draws, and the stretches of it no sample falls in.
  ///
  /// The axis is the window that was *asked for*. Taking it from the samples
  /// instead makes every window look full: three stored hours drawn on a
  /// 24-hour request would fill the card, and a page left in the background
  /// for four minutes would draw a line straight across the gap.
  ({({int from, int to})? window, List<ChartBand> bands}) _chartWindow(
    ServerState si,
    _MetricView m,
    _Window w,
  ) {
    final times = w.times;
    if (times.isEmpty) return (window: null, bands: const []);
    final first = times.first;
    final last = times.last;

    if (_custom case final window?) {
      final from = window.from.millisecondsSinceEpoch;
      final to = window.to.millisecondsSinceEpoch;
      return (
        window: (from: from, to: to),
        bands: _bandsIn(from: from, to: to, first: first, last: last),
      );
    }

    final minutes = _range.minutes;
    if (minutes == null) {
      // What this app has watched. Up to now only once the readings have
      // stopped, which is when the distance to the last of them is worth
      // seeing — see [watchedWindow] for what it was before that.
      final now = DateTime.now().millisecondsSinceEpoch;
      final stopped = now - last > _staleAfter.inMilliseconds;
      return (
        window: watchedWindow(times, m.series, until: stopped ? now : null),
        bands: stopped
            ? [(from: last, to: now, label: l10n.noData)]
            : const [],
      );
    }

    final answer = _rangeWindows[_range];
    final to = answer?.at.millisecondsSinceEpoch ?? last;
    final from = to - minutes * 60 * 1000;
    return (
      window: (from: from, to: to),
      bands: _bandsIn(from: from, to: to, first: first, last: last),
    );
  }

  /// What a stored window did not come back with, said in the band.
  ///
  /// Two buckets of tolerance at each end: the agent averages the window into
  /// at most [_kRangePoints] of them, so the outermost points sit a bucket
  /// inside the window however much it kept — and a band drawn for that is a
  /// band on every chart.
  List<ChartBand> _bandsIn({
    required int from,
    required int to,
    required int first,
    required int last,
  }) {
    final tolerance = ((to - from) ~/ _kRangePoints) * 2;
    return [
      for (final gap in windowGaps(
        from: from,
        to: to,
        first: first,
        last: last,
        leadTolerance: tolerance,
        trailTolerance: tolerance,
      ))
        (
          from: gap.from,
          to: gap.to,
          // Where it stops being true is the fact: a gap at the start of the
          // window says when the readings begin, and one at the end has
          // nothing to name — it runs to now.
          label: gap.leading
              ? l10n.noDataBeforeFmt(_clockOf(first))
              : l10n.noData,
        ),
    ];
  }

  /// A sample's instant as a clock reading — the day where the window spans
  /// one, because "no data before 11:20" is a different fact on Tuesday.
  String _clockOf(int timeMs) {
    final at = DateTime.fromMillisecondsSinceEpoch(timeMs);
    final sameDay = DateTime.now().difference(at) < const Duration(hours: 12);
    return DateFormat(
      sameDay ? 'HH:mm' : 'MMM d HH:mm',
      l10n.localeName,
    ).format(at);
  }

  /// One metric drawn in full, the rest a line each.
  Widget _buildMetrics(ServerState si, {required bool wide}) {
    final window = _window(si);
    final views = _metrics(si, window);
    if (views.isEmpty) return UIs.placeholder;
    final focus =
        views.firstWhereOrNull((e) => e.kind == _focusMetric) ?? views.first;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _buildFocusCard(si, focus, window, wide: wide),
        UIs.height7,
        // The cards bring their own margin, which is what spaces them.
        for (final view in views)
          _buildMetricRow(
            view,
            selected: view.kind == focus.kind,
            wide: wide,
            staleAt: _staleSince(si),
          ),
      ],
    );
  }

  Widget _buildFocusCard(
    ServerState si,
    _MetricView m,
    _Window w, {
    required bool wide,
  }) {
    final axis = _chartWindow(si, m, w);
    final chart = _buildFocusChart(si, m, w, axis, wide: wide);
    // What a window that could not be filled actually holds. Only when it is
    // short: on a window the agent covered, "stored 24 h · window 24 h" is two
    // ways of saying the axis.
    final stats = [
      ...m.stats,
      if (axis.bands.firstOrNull case final gap?
          when (_custom != null || _range != _HistoryRange.live) &&
              w.times.isNotEmpty)
        (
          k: l10n.stored,
          v: Duration(milliseconds: w.times.last - gap.to).toAgoStr,
        ),
      // Only for a window the reader named: how dense it came back is a
      // property of that window, while a preset's density is the same every
      // time and worth no line.
      if (_custom != null && w.times.isNotEmpty)
        (k: l10n.samples, v: '${w.times.length}'),
    ];
    final device = _buildDeviceControl(si, m);
    final note = _historyNote(si, wide: wide);
    // Two groups with the room between them, not five children sharing it:
    // everything in this line is as long as the language or the machine makes
    // it, and a `Flexible` narrower than its share leaves the difference as
    // slack at the end of the row — which holds the ranges off the edge.
    //
    // The shares are 2:3 because that is roughly what the two sides need: the
    // right holds the note and three chips, the left a name and a device
    // count. At 1:3 the left was a quarter of the card and the count came out
    // as "2 o…".
    final head = Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Flexible(
          flex: 2,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(m.icon, size: 18, color: ChartPalette.reading(promoted: true)),
              const SizedBox(width: 9),
              Flexible(
                child: Text(
                  m.label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
              // Narrow, the header is a name and the ranges and nothing fits
              // between them: the control goes on the note's line below, which
              // is otherwise a line of grey text with the rest of the card's
              // width to itself.
              if (wide && device != null) ...[
                const SizedBox(width: 13),
                Flexible(child: device),
              ],
            ],
          ),
        ),
        Flexible(
          flex: 3,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (wide && note != null) ...[
                Flexible(
                  child: Text(
                    note,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.right,
                    style: UIs.text11Grey,
                  ),
                ),
                const SizedBox(width: 9),
              ],
              Flexible(child: _buildRangeChips(si, wide: wide)),
            ],
          ),
        ),
      ],
    );

    final headline = [
      Text(m.value, style: UIs.text27),
      const SizedBox(width: 9),
      Flexible(
        child: Text(
          m.bigNote,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: UIs.text13Grey,
        ),
      ),
    ];

    // The key goes on a wrapper, not on the card: `CardX` hands its own key to
    // the `Card` it builds, and a `GlobalKey` on two widgets at once is an
    // error rather than a duplicate.
    return KeyedSubtree(
      key: _focusCardKey,
      child: CardX(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(17, 13, 17, 13),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Stated rather than natural — see [ServerCardSizes.openHead].
              // It is also where the card this page grew out of put its own,
              // which is what lets the page take over without the chart
              // moving.
              SizedBox(height: ServerCardSizes.openHead, child: head),
              UIs.height7,
              if (wide)
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Flexible(
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: headline,
                      ),
                    ),
                    if (stats.isNotEmpty)
                      Flexible(
                        child: SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          reverse: true,
                          child: _buildStats(stats),
                        ),
                      ),
                  ],
                )
              else ...[
                Row(crossAxisAlignment: CrossAxisAlignment.end, children: headline),
                if (stats.isNotEmpty) ...[
                  UIs.height7,
                  _buildStats(stats),
                ],
                if (note != null || device != null) ...[
                  UIs.height7,
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          note ?? '',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: UIs.text11Grey,
                        ),
                      ),
                      ?device,
                    ],
                  ),
                ],
              ],
              chart,
              ?_buildFocusDetail(si, m.kind),
            ],
          ),
        ),
      ),
    );
  }

  /// The chart, or the one line that says why there isn't one.
  Widget _buildFocusChart(
    ServerState si,
    _MetricView m,
    _Window w,
    ({({int from, int to})? window, List<ChartBand> bands}) axis, {
    required bool wide,
  }) {
    final height = wide ? _kFocusChartHeight : _kFocusChartHeightNarrow;
    // A section that failed has no line to draw and a reason worth reading in
    // full, so it takes the chart's place rather than being squeezed into the
    // row's one line.
    if (m.error case final err?) {
      return SizedBox(
        height: height,
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(vertical: 13),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                SelectableText(
                  err,
                  textAlign: TextAlign.center,
                  style: UIs.text12Grey.copyWith(fontFamily: 'monospace'),
                ),
                UIs.height13,
                Text(
                  l10n.metricUnavailableTip,
                  textAlign: TextAlign.center,
                  style: UIs.text11Grey,
                ),
              ],
            ),
          ),
        ),
      );
    }
    // Only the chart waits. The range is a question about the chart, and the
    // headline and the rows below go on being what the machine is doing now.
    if (_customBusy || (_custom == null && _rangeBusy.contains(_range))) {
      return _buildChartNotice(
        height,
        l10n.loadingRangeFmt(_rangeLabel(wide: true)),
        waiting: true,
      );
    }
    if (!m.hasChart) {
      // Waiting and having nothing are different answers. Before the first
      // sample the page is not empty, it is early — and the progress line is
      // what says which of the two this is.
      if (_neverSampled(si)) {
        return _buildChartNotice(
          height,
          l10n.waitingFirstSample,
          waiting: true,
        );
      }
      return _buildChartNotice(
        height,
        // "Nothing measured yet" is about the buffer this app fills as it
        // watches. A window asked of the agent that came back empty is a
        // different answer, whatever the preset behind it happens to be.
        _custom == null && _range == _HistoryRange.live
            ? l10n.noHistoryYet
            : l10n.noStoredHistoryFor(m.label),
      );
    }
    return MetricChart(
      MetricChartSpec(
        series: m.series,
        format: m.format,
        times: w.times,
        window: axis.window,
        bands: axis.bands,
        binaryScale: m.binary,
        height: height,
        fill: true,
      ),
    );
  }

  /// The chart's place, holding a sentence instead of a chart.
  ///
  /// The same block either way — a request in flight and a metric with nothing
  /// stored are both "no line yet", and the card is one height whatever it is
  /// showing. [waiting] adds the progress line: an indeterminate 3pt rule
  /// rather than a spinner, because what is waiting is this strip and not the
  /// page.
  Widget _buildChartNotice(
    double height,
    String text, {
    bool waiting = false,
  }) {
    return SizedBox(
      height: height,
      child: Column(
        children: [
          if (waiting)
            const LinearProgressIndicator(minHeight: 3, backgroundColor: Colors.transparent),
          Expanded(
            child: Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 17),
                child: Text(
                  text,
                  textAlign: TextAlign.center,
                  style: UIs.text12Grey,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// What the machine says about this metric beyond the one number — the
  /// mounts, the interfaces, the cores. It belongs to the metric being read,
  /// not to the page, which is why it is inside the card rather than under it.
  Widget? _buildFocusDetail(ServerState si, _MetricKind kind) {
    final ss = si.status;
    switch (kind) {
      case _MetricKind.cpu:
        if (!_cpuViewAsProgress) return null;
        return Padding(
          padding: const EdgeInsets.only(top: 13),
          child: Column(children: _buildCPUProgress(ss.cpu)),
        );
      case _MetricKind.disk:
      case _MetricKind.diskIo:
      case _MetricKind.net:
      case _MetricKind.mem:
      case _MetricKind.swap:
      case _MetricKind.gpu:
      case _MetricKind.temp:
      case _MetricKind.battery:
        // The devices behind a metric are reached from the control in the
        // header, not listed under the chart. Once every device has a line of
        // its own the chart's legend is that list, and a second copy of it
        // below would be the same names twice.
        return null;
    }
  }

  /// Which of a metric's devices the chart draws, and the way to change it.
  ///
  /// A control rather than a list under the chart: once every device has a
  /// line of its own the legend *is* that list, and the question left is which
  /// of them are worth a line — a host reports as many interfaces as it has
  /// and most of them are idle tunnels.
  ///
  /// The disk row is the exception: what a filesystem is at has no line, so
  /// its devices are a list to read rather than a set to choose from.
  Widget? _buildDeviceControl(ServerState si, _MetricView m) {
    final ss = si.status;
    if (m.kind == _MetricKind.disk) {
      if (ss.disk.length < 2) return null;
      final disks = [...ss.disk]
        ..sort((a, b) => b.usedPercent.compareTo(a.usedPercent));
      return _deviceButton(
        l10n.devicesFmt(disks.length),
        () => _showClosableDetailDialog(
          title: libL10n.device,
          child: SizedBox(
            width: double.maxFinite,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  for (final disk in disks)
                    _buildDiskItemWithHierarchy(disk, ss, 0),
                ],
              ),
            ),
          ),
        ),
      );
    }

    final devices = _devicesOf(si, m.kind);
    if (devices == null) return null;
    // What the legend is showing, out of what the machine reports. Only the
    // live window draws a line each, so anywhere else this is the count alone.
    // "6 of 8" is about the lines on the chart, and those are drawn from the
    // rolling buffer — so only the live window has any. Anywhere else the
    // honest answer is how many devices the machine has.
    final label = _custom == null && _range == _HistoryRange.live
        ? l10n.devicesPlottedFmt(
            _plottedDevices(m.kind, devices).length,
            devices.names.length,
          )
        : l10n.devicesFmt(devices.names.length);
    return _deviceButton(label, () => _showDevicePicker(si, m.kind));
  }

  Widget _deviceButton(String label, VoidCallback onTap) {
    return InkWell(
      borderRadius: BorderRadius.circular(7),
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 3),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.list, size: 15, color: UIs.textGrey.color),
            UIs.width7,
            // The count is as long as the language makes it, and everything
            // in this header is competing for one line.
            Flexible(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: UIs.text12Grey,
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// The devices, ticked where they are drawn.
  ///
  /// Stays open as they are ticked, and the chart behind it follows each tap:
  /// which lines are worth drawing is a question answered by looking at them,
  /// not by predicting them and closing a sheet.
  Future<void> _showDevicePicker(ServerState si, _MetricKind kind) async {
    final scheme = Theme.of(context).colorScheme;
    await showRowsSheet<void>(
      context,
      rows: (_) => [
        StatefulBuilder(
          builder: (_, setSheetState) {
            // Re-read on every rebuild: a poll lands while the sheet is open,
            // and the readings under the names are what the choice is made on.
            final devices = _devicesOf(
              ref.read(serverProvider(widget.args.spi.id)),
              kind,
            );
            if (devices == null) return UIs.placeholder;
            final plotted = _plottedDevices(kind, devices).toSet();

            return Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                for (final name in devices.names)
                  ListTile(
                    selected: plotted.contains(name),
                    title: Text(name),
                    subtitle: Text(
                      devices.subtitle(name),
                      style: UIs.text12Grey,
                    ),
                    trailing: plotted.contains(name)
                        ? Icon(Icons.check, color: scheme.primary)
                        : null,
                    onTap: () {
                      _toggleDevice(kind, name, plotted);
                      setSheetState(() {});
                    },
                  ),
              ],
            );
          },
        ),
      ],
    );
  }

  /// Adds or removes one device from what the chart draws.
  ///
  /// The last one on cannot be turned off: an empty chart is not a view of
  /// anything, and "nothing is selected" is not a state this page can explain
  /// in the space a legend has.
  void _toggleDevice(_MetricKind kind, String name, Set<String> plotted) {
    if (plotted.contains(name) && plotted.length == 1) {
      Toast.show(l10n.oneDeviceAtLeast);
      return;
    }
    _rebuild(() {
      final picked = _devicePick.putIfAbsent(kind, () => {...plotted});
      if (!picked.remove(name)) picked.add(name);
    });
  }

  Widget _buildStats(List<_Stat> stats) {
    if (stats.isEmpty) return UIs.placeholder;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (final (i, s) in stats.indexed) ...[
          if (i > 0) const SizedBox(width: 17),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                s.v,
                style: const TextStyle(
                  fontSize: 15,
                  fontFeatures: [FontFeature.tabularFigures()],
                ),
              ),
              Text(s.k, style: UIs.text11Grey),
            ],
          ),
        ],
      ],
    );
  }

  /// Brings the chart back on screen, if tapping a row sent a metric to a card
  /// that is no longer there.
  ///
  /// Nine rows and the cards under them are taller than a phone, so the row
  /// that promotes a metric is regularly below the card it promotes it into —
  /// and from down there the tap does nothing visible at all. Only when it is
  /// off screen: a chart that jumps every time a row is tapped is a page that
  /// moves under the hand that is using it.
  void _revealFocus() {
    final ctx = _focusCardKey.currentContext;
    if (ctx == null || !_scrollCtrl.hasClients) return;
    final target = ctx.findRenderObject();
    if (target == null) return;
    final viewport = RenderAbstractViewport.maybeOf(target);
    if (viewport == null) return;

    // The two offsets that put the card against each edge of the viewport.
    // Anywhere between them it is already whole on screen.
    final toTop = viewport.getOffsetToReveal(target, 0).offset;
    final toBottom = viewport.getOffsetToReveal(target, 1).offset;
    final position = _scrollCtrl.position;
    final current = position.pixels;
    if (current <= toTop && current >= toBottom) return;

    _scrollCtrl.animateTo(
      current > toTop
          ? toTop.clamp(position.minScrollExtent, position.maxScrollExtent)
          : toBottom.clamp(position.minScrollExtent, position.maxScrollExtent),
      duration: Durations.medium2,
      curve: Curves.easeOutCubic,
    );
  }

  /// A metric that is not being read: what it is at, and how to read it.
  Widget _buildMetricRow(
    _MetricView m, {
    required bool selected,
    required bool wide,
    DateTime? staleAt,
  }) {
    final scheme = Theme.of(context).colorScheme;
    final fg = selected ? scheme.onSecondaryContainer : null;
    // A reading that is no longer current is drawn as one: the figure goes
    // muted and the note beside it says when it was taken, rather than what
    // the figure is of. Colour is not the only carrier — the timestamp is,
    // and for a section that failed the note is what it said.
    final value = Text(
      m.value,
      style: TextStyle(
        fontSize: 15,
        fontWeight: FontWeight.w500,
        color: m.error != null
            ? scheme.error
            : staleAt != null
            ? UIs.textGrey.color
            : fg,
        fontFeatures: const [FontFeature.tabularFigures()],
      ),
    );
    // A failure outranks staleness here the way it does in the colour above.
    // Both at once is the common case — a section stops answering and the
    // reading it left goes stale — and the timestamp says when this was last
    // true, while the note says why it is not true now. Only one of them fits,
    // and it is the second.
    final note = m.error != null || staleAt == null
        ? m.note
        : l10n.atTimeFmt(_clockOf(staleAt.millisecondsSinceEpoch));

    void promote() {
      _rebuild(() => _focusMetric = m.kind);
      // Kept, so the card this page grew out of shows the same reading when it
      // shrinks back into the list.
      ServerPromoted.put(
        widget.args.spi.id,
        ServerMetricKind.values.firstWhere((e) => e.name == m.kind.name),
      );
      _revealFocus();
    }

    // The same widget the card in the list draws, at the far end of the
    // movement that turns one into the other. Two rows built from the same
    // numbers would have to be crossed over when the page takes the card
    // over, and a crossing is what reads as the page having been rebuilt.
    if (wide) {
      return MetricRow(
        icon: m.icon,
        label: m.label,
        color: ChartPalette.reading(promoted: selected),
        value: m.value,
        note: note,
        percent: m.percent,
        error: m.error,
        selected: selected,
        onTap: promote,
      );
    }

    final Widget body;
    {
      body = Row(
        children: [
          // Narrow has no trailing glyph, so the icon and the value are the
          // whole of what says this row failed — the wide one says it three
          // times over.
          Icon(
            m.icon,
            size: 18,
            color: m.error != null
                ? scheme.error
                : selected
                ? fg
                : ChartPalette.reading(promoted: false),
          ),
          const SizedBox(width: 9),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  m.label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    color: fg,
                  ),
                ),
                if (note.isNotEmpty)
                  Text(
                    note,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: UIs.text11Grey,
                  ),
              ],
            ),
          ),
          const SizedBox(width: 9),
          value,
        ],
      );
    }

    // A card, like everything else on this page. Drawn as one rather than as a
    // list row: what is under it is the same surface the chart above sits on,
    // and a row with no card of its own disappeared into the page.
    return CardX(
      color: selected ? scheme.secondaryContainer : null,
      child: InkWell(
        onTap: promote,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(13, 9, 13, 9),
          child: body,
        ),
      ),
    );
  }
}

// --- The range, and where it comes from ---

extension on _ServerDetailPageState {
  /// How the app reaches this machine — the transport that leads, which is
  /// the one a poll uses unless it fails over.
  String _transportName(ServerState si) {
    return switch (si.spi.transport) {
      ServerTransport.monitorHttp => 'monitor',
      ServerTransport.ssh => 'SSH',
    };
  }

  /// The one line under the header, when there is something for it to say.
  ///
  /// Null on an ordinary card. It used to name where the window came from —
  /// "stored history", "since connect · not stored" — on every card of every
  /// server, which is a line that never changes and was read once. Where the
  /// samples come from is already answered by which ranges the header offers.
  String? _historyNote(ServerState si, {bool wide = true}) {
    // A page whose newest sample is minutes old is the one fact the reader
    // needs, and the only one worth a line of its own.
    if (_staleSince(si) case final at?) return l10n.lastSampleFmt(at.toAgoStr());
    // Narrow, the header's chip holds only the window's length, so this line
    // is where its two ends fit.
    if (!wide && _custom != null) return _rangeLabel(wide: true);
    return null;
  }

  /// How long the window on screen is, however it was named.
  String _windowLength() {
    final window = _custom;
    if (window == null) return _range.label;
    return window.to.difference(window.from).toAgoStr;
  }

  /// What the chart's window is called.
  ///
  /// A named window says its own start and end where there is room for them —
  /// which is what a reader who typed them in is looking for — and its length
  /// where there is not: 27 characters of timestamps decide the width of a
  /// header that has to stay one line.
  String _rangeLabel({required bool wide}) {
    final window = _custom;
    if (window == null) return _range.label;
    final span = window.to.difference(window.from).toAgoStr;
    if (!wide) return span;
    return '${_clockOf(window.from.millisecondsSinceEpoch)} – '
        '${_clockOf(window.to.millisecondsSinceEpoch)}';
  }

  /// The ranges, and the way to the ones that are not here.
  ///
  /// Three of them where there is room. On a narrow card only the chosen one,
  /// because three chips plus the picker is most of the header at 320pt — and
  /// in a language whose word for "live" is longer, more than all of it.
  Widget _buildRangeChips(ServerState si, {required bool wide}) {
    final stored = si.capabilities.storedHistory;
    final scheme = Theme.of(context).colorScheme;
    final custom = _custom;
    final selected = _range;
    final inline = custom != null
        ? const <_HistoryRange>[]
        : wide
        ? [
            ..._HistoryRange.inline,
            if (!_HistoryRange.inline.contains(selected)) selected,
          ]
        : [selected];

    Widget chip(_HistoryRange range) {
      final on = range == selected;
      final enabled = stored || range == _HistoryRange.live;
      return Material(
        color: on ? scheme.secondaryContainer : Colors.transparent,
        shape: const StadiumBorder(),
        child: InkWell(
          customBorder: const StadiumBorder(),
          onTap: enabled
              ? () => _selectRange(range)
              : () => Toast.show(l10n.historyNoStored),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
            child: Text(
              range.label,
              style: TextStyle(
                fontSize: 12,
                color: on
                    ? scheme.onSecondaryContainer
                    : enabled
                    ? UIs.textGrey.color
                    : scheme.outline,
              ),
            ),
          ),
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(30),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (final range in inline) ...[chip(range), const SizedBox(width: 3)],
          // The window the reader named, in the place the presets would be:
          // it is what the chart is showing, and leaving a preset highlighted
          // beside it would say the chart is showing that instead.
          if (custom != null)
            Material(
              color: scheme.secondaryContainer,
              shape: const StadiumBorder(),
              child: InkWell(
                customBorder: const StadiumBorder(),
                onTap: () => _showRangePicker(si),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 9,
                    vertical: 4,
                  ),
                  child: Text(
                    _rangeLabel(wide: wide),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 12,
                      color: scheme.onSecondaryContainer,
                    ),
                  ),
                ),
              ),
            ),
          if (custom != null) const SizedBox(width: 3),
          InkWell(
            customBorder: const StadiumBorder(),
            onTap: () => _showRangePicker(si),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 4),
              child: Icon(
                Icons.date_range,
                size: 16,
                color: custom != null
                    ? scheme.onSecondaryContainer
                    : UIs.textGrey.color,
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Every window this agent can answer for, and the two fields for one it
  /// has not been asked for yet.
  ///
  /// The presets are the common windows, not the limit: which of them are
  /// offered is decided by what the agent said it keeps, and the line at the
  /// bottom is that answer in full. Writing "24 h" into the app and hoping
  /// would draw an empty chart on an agent keeping three hours and call it a
  /// quiet machine.
  Future<void> _showRangePicker(ServerState si) async {
    final stored = si.capabilities.storedHistory;
    final caps = si.agentCapabilities;
    final earliest = caps?.historyFrom;
    final scheme = Theme.of(context).colorScheme;

    // What the fields start at: the window on screen, or the last day.
    final now = DateTime.now();
    var from = _custom?.from ?? now.subtract(const Duration(hours: 24));
    var to = _custom?.to ?? now;

    final picked = await showRowsSheet<({_HistoryRange? preset, bool custom})>(
      context,
      rows: (ctx) => [
        StatefulBuilder(
          builder: (_, setSheetState) => Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (final range in _HistoryRange.values)
                () {
                  // Beyond what the agent kept, rather than beyond what this
                  // app offers: the row stays, greyed, with the reason — a
                  // window that is simply missing reads as a window this app
                  // decided you could not have.
                  final minutes = range.minutes;
                  final beyond =
                      minutes != null &&
                      earliest != null &&
                      now.subtract(Duration(minutes: minutes)).isBefore(earliest);
                  // A window past a week reaches the agent as `from`/`to`, and
                  // an agent that did not report its retention is one that
                  // predates both — it would clamp to a week and answer for a
                  // window nobody asked for.
                  final unaskable =
                      minutes != null && minutes > 7 * 24 * 60 && caps?.retention == null;
                  final offerable =
                      (stored || range == _HistoryRange.live) &&
                      !beyond &&
                      !unaskable;
                  return ListTile(
                    enabled: offerable,
                    selected: _custom == null && range == _range,
                    title: Text(range.label),
                    subtitle: beyond
                        ? Text(l10n.beyondRetention, style: UIs.text12Grey)
                        : null,
                    trailing: _custom == null && range == _range
                        ? Icon(Icons.check, color: scheme.primary)
                        : null,
                    onTap: offerable
                        ? () => Navigator.of(
                            ctx,
                          ).pop((preset: range, custom: false))
                        : () => Toast.show(
                            beyond ? l10n.beyondRetention : l10n.historyNoStored,
                          ),
                  );
                }(),
              // Only for an agent that reported its retention, which is also
              // the only one that understands `from`/`to`: an older one clamps
              // to a week and answers for a window nobody asked for, which the
              // chart would then draw as a week of readings inside the window
              // that was typed in.
              if (stored && caps?.retention != null) ...[
                const Divider(height: 17, indent: 17, endIndent: 17),
                for (final bound in [true, false])
                  ListTile(
                    leading: const Icon(Icons.event, size: 20),
                    title: Text(bound ? l10n.from : l10n.to),
                    trailing: Text(
                      _clockOf(
                        (bound ? from : to).millisecondsSinceEpoch,
                      ),
                      style: UIs.text13,
                    ),
                    onTap: () async {
                      final at = await _pickInstant(bound ? from : to);
                      if (at == null) return;
                      setSheetState(() {
                        if (bound) {
                          from = at;
                        } else {
                          to = at;
                        }
                      });
                    },
                  ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(17, 7, 17, 0),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      Btn.elevated(
                        text: libL10n.ok,
                        onTap: () => Navigator.of(
                          ctx,
                        ).pop((preset: null, custom: true)),
                      ),
                    ],
                  ),
                ),
                // The fact the choice above is made against, said once and in
                // the agent's own terms: what it keeps, and the oldest reading
                // it actually has.
                if (caps != null)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(17, 13, 17, 5),
                    child: Text(
                      [
                        if (caps.retention case final kept?)
                          l10n.agentRetentionFmt(kept.toAgoStr),
                        if (caps.oldestSample case final oldest?)
                          l10n.oldestSampleFmt(
                            _clockOf(oldest.millisecondsSinceEpoch),
                          ),
                      ].join(' · '),
                      style: UIs.text11Grey,
                    ),
                  ),
              ],
            ],
          ),
        ),
      ],
    );

    if (picked == null) return;
    if (picked.preset case final range?) {
      _rebuild(() {
        _custom = null;
        _customAnswer = null;
      });
      await _selectRange(range);
      return;
    }
    if (!to.isAfter(from)) {
      Toast.show(l10n.rangeEndsBeforeItStarts);
      return;
    }
    await _selectCustom(from, to);
  }

  /// A day and a time, in that order — the two questions a platform has a
  /// picker for, rather than a text field that has to be parsed and explained.
  Future<DateTime?> _pickInstant(DateTime initial) async {
    final day = await showDatePicker(
      context: context,
      initialDate: initial,
      // A window into readings that do not exist yet is not one to offer, and
      // the far end is whatever an agent could conceivably have kept.
      firstDate: DateTime.now().subtract(const Duration(days: 3650)),
      lastDate: DateTime.now(),
    );
    if (day == null || !mounted) return null;
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(initial),
    );
    if (time == null) return null;
    final at = DateTime(day.year, day.month, day.day, time.hour, time.minute);
    // The day picker stops at today; the time picker does not know what time
    // it is, so "today, 23:50" is reachable at 22:00. A window reaching into
    // the future would draw the time that has not happened as a gap in the
    // readings. Clamped rather than refused, because the row shows what it
    // landed on — a tap that silently does nothing is the worse answer.
    final now = DateTime.now();
    return at.isAfter(now) ? now : at;
  }

  /// Asks the agent for a window nobody has asked for before.
  ///
  /// Kept apart from the presets' cache: a named window is asked for once and
  /// replaced by the next one, while the presets are a fixed set worth keeping
  /// as the reader moves between them.
  Future<void> _selectCustom(DateTime from, DateTime to) async {
    if (!mounted) return;
    // Which request this is. A window picked while another is still in flight
    // is the answer that counts, and without this the slower of the two
    // overwrites it on arrival and clears the busy flag the newer one set.
    final generation = ++_historyGeneration;
    _rebuild(() {
      // Every preset request in flight now belongs to a generation that has
      // passed, so its `finally` will not run: left as it is, the range it was
      // fetching stays marked busy, and picking that preset again shows a
      // chart waiting for a request nobody is making.
      _rangeBusy.clear();
      _custom = (from: from, to: to);
      _customAnswer = null;
      _customBusy = true;
    });
    try {
      final samples = await ref
          .read(serverProvider(widget.args.spi.id).notifier)
          .fetchHistoryRange(
            // Sent as well as `from`/`to` so an agent too old for them answers
            // with a window of the same length rather than with its default.
            minutes: to.difference(from).inMinutes.clamp(5, 7 * 24 * 60),
            maxPoints: _kRangePoints,
            from: from,
            to: to,
          );
      if (!mounted || generation != _historyGeneration) return;
      _rebuild(
        () => _customAnswer = (samples: samples, at: DateTime.now()),
      );
    } catch (e, s) {
      Loggers.app.warning('History range for ${widget.args.spi.id}', e, s);
      if (mounted && generation == _historyGeneration) Toast.error('$e');
    } finally {
      if (generation == _historyGeneration) _rebuild(() => _customBusy = false);
    }
  }

  /// Asks the agent for the window, once. The answer is kept until the page
  /// is left: a window an hour wide does not change meaningfully between two
  /// taps, and refetching it on every poll would spend a request a second on
  /// a chart nobody is watching change.
  Future<void> _selectRange(_HistoryRange range) async {
    if (!mounted) return;
    _rebuild(() {
      _range = range;
      _custom = null;
      _customAnswer = null;
    });
    final minutes = range.minutes;
    if (minutes == null ||
        _rangeWindows.containsKey(range) ||
        _rangeBusy.contains(range)) {
      return;
    }

    final generation = _historyGeneration;
    _rebuild(() => _rangeBusy.add(range));
    try {
      final to = DateTime.now();
      final samples = await ref
          .read(serverProvider(widget.args.spi.id).notifier)
          .fetchHistoryRange(
            minutes: minutes,
            maxPoints: _kRangePoints,
            // The same window twice: `minutes` is what an agent predating
            // `from`/`to` understands, and it clamps at a week — which is why
            // the windows past that are offered only to an agent that answered
            // with its retention, since only that one has the newer form.
            from: to.subtract(Duration(minutes: minutes)),
            to: to,
          );
      // The page may have been handed another server while this was in
      // flight, and these samples are the previous one's.
      if (!mounted || generation != _historyGeneration) return;
      _rebuild(
        () => _rangeWindows[range] = (samples: samples, at: DateTime.now()),
      );
    } catch (e, s) {
      Loggers.app.warning('History ${range.label} for ${widget.args.spi.id}', e, s);
      if (mounted && generation == _historyGeneration) Toast.error('$e');
    } finally {
      if (generation == _historyGeneration) {
        _rebuild(() => _rangeBusy.remove(range));
      }
    }
  }
}

/// What the agent will answer with at most, and as many as a chart this wide
/// can draw.
const _kRangePoints = 300;

// --- The facts that do not move ---

extension on _ServerDetailPageState {
  /// What the machine is, beside what it is doing.
  ///
  /// Two cards rather than one: the About rows come from the machine and
  /// change (uptime, the delay), the Hardware ones are what it is built of and
  /// do not. Kept out of the metric rows entirely, where they would be the
  /// only lines that never move.
  List<Widget> _buildInfoCards(ServerState si) {
    final ss = si.status;
    final publicIp = SelfAddr.pick(ss.ips);
    // One row, not two: how the app reaches this machine and how long that
    // took are the same fact — a delay means nothing without knowing whether
    // it timed an HTTP request or a shell script on a loaded box.
    final connection = [
      _transportName(si),
      if (si.agentVersion case final version?) 'v$version',
    ].join(' ');
    final about = <({String k, String v, bool secret})>[
      (
        k: libL10n.conn,
        v: si.latencyMs == null
            ? connection
            : '$connection · ${si.latencyMs}ms',
        secret: false,
      ),
      for (final e in ss.more.entries) (k: e.key.i18n, v: e.value, secret: false),
      if (publicIp != null)
        (k: l10n.publicIp, v: publicIp.address, secret: true),
    ];

    final cores = ss.cpu.coresCount;
    final usage = ss.disk.isEmpty ? null : DiskUsage.parse(ss.disk);
    final hardware = <({String k, String v, bool secret})>[
      if (ss.cpu.brand.keys.firstOrNull case final brand?)
        (k: 'CPU', v: brand, secret: false),
      if (cores > 0) (k: l10n.cores, v: '×$cores', secret: false),
      if (ss.mem.total > 0)
        (k: libL10n.memory, v: (ss.mem.total * 1024).bytes2Str, secret: false),
      if (ss.swap.total > 0)
        (k: 'Swap', v: (ss.swap.total * 1024).bytes2Str, secret: false),
      if (usage != null)
        (k: libL10n.disk, v: usage.size.kb2Str, secret: false),
      // What the machine has, not what it is doing with it: the load is the
      // GPU row above, and which cards are in the box belongs with the CPU
      // and the memory.
      if (ss.gpus.isNotEmpty) (k: 'GPU', v: _modelsOf(ss.gpus), secret: false),
    ];

    return [
      // Still the About card the setting knows by name: an install that
      // switched it off keeps it off, and the switch is still in settings to
      // put it back.
      if (about.isNotEmpty && !_cardsOff.contains(ServerDetailCards.about.name))
        _buildInfoCard(MingCute.information_fill, libL10n.about, about),
      if (hardware.isNotEmpty)
        _buildInfoCard(Icons.developer_board, l10n.hardware, hardware),
    ];
  }

  /// The models in a set of cards, counted rather than repeated: two of the
  /// same card is one line about a machine, and four lines of the same name is
  /// four lines of nothing.
  String _modelsOf(List<GpuItem> gpus) {
    final counts = <String, int>{};
    for (final gpu in gpus) {
      counts[gpu.name] = (counts[gpu.name] ?? 0) + 1;
    }
    return [
      for (final e in counts.entries) e.value > 1 ? '${e.key} ×${e.value}' : e.key,
    ].join(', ');
  }

  Widget _buildInfoCard(
    IconData icon,
    String title,
    List<({String k, String v, bool secret})> rows,
  ) {
    return CardX(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(17, 13, 17, 13),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Icon(icon, size: 18, color: Theme.of(context).colorScheme.primary),
                const SizedBox(width: 9),
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
            UIs.height7,
            for (final row in rows)
              Padding(
                key: ValueKey('info-${row.k}'),
                padding: const EdgeInsets.symmetric(vertical: 2),
                child: Row(
                  children: [
                    Text(row.k, style: UIs.text12Grey),
                    UIs.width13,
                    Expanded(
                      child: row.secret
                          ? Align(
                              alignment: Alignment.centerRight,
                              child: _SecretText(row.v),
                            )
                          : Text(
                              row.v,
                              textAlign: TextAlign.right,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: UIs.text13,
                            ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}
