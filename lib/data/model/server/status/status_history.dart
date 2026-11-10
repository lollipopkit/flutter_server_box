import 'package:server_box/data/model/server/status/time_seq.dart';

/// Rolling in-memory trend data for one server, so the chart cards work the
/// same regardless of how the server is reached.
///
/// SSH has no history concept at all — the app is the only thing that ever
/// sees those samples — and monitor's `/api/v1/metrics/history` only covers
/// what its agent stored. Keeping one buffer on this side, appended to after
/// every successful refresh, lets both connection methods drive identical
/// cards; for monitor servers it is additionally seeded once from the agent's
/// history so a freshly opened page isn't blank (see `seed`).
///
/// Every series is sampled together and shares an index, so index `i` of any
/// two series refers to the same refresh. Series a given source can't provide
/// hold `null` at that index rather than a fabricated 0 — a server with no
/// battery must render as "no data", not as a flat 0%.
class StatusHistory {
  /// How many samples any one series keeps — ~5 minutes at the app's default
  /// 3-second refresh interval.
  ///
  /// Fewer than the agent's history holds. [seed] walks the response through
  /// [add], so a longer one keeps its newest [capacity] points and the rest
  /// is dropped on arrival; the chart is the same either way, since a card a
  /// few hundred pixels wide cannot draw more points than it has pixels.
  static const capacity = 100;

  /// Percent, 0-100
  final cpu = Fifo<double?>(capacity: capacity);
  final mem = Fifo<double?>(capacity: capacity);
  final swap = Fifo<double?>(capacity: capacity);
  final disk = Fifo<double?>(capacity: capacity);
  final battery = Fifo<double?>(capacity: capacity);

  /// Bytes per second
  final netRx = Fifo<double?>(capacity: capacity);
  final netTx = Fifo<double?>(capacity: capacity);
  final diskRead = Fifo<double?>(capacity: capacity);
  final diskWrite = Fifo<double?>(capacity: capacity);

  /// Percent. The busiest GPU, for hosts that report one at all.
  final gpu = Fifo<double?>(capacity: capacity);

  /// Celsius. The aggregate reading, kept for sources that only expose one
  /// (and for [seed], since monitor's stored history has a single column).
  final temp = Fifo<double?>(capacity: capacity);

  /// Celsius per sensor, for hosts that expose several.
  final _temps = _DeviceHistory();
  Map<String, List<double?>> get tempsByDevice => _temps.byDevice;

  /// Bytes per second per block device and per interface, for the chart to
  /// draw a line each once a metric is being read in full.
  ///
  /// Only ever live samples: nothing stores these, so a window asked of an
  /// agent has the totals and nothing under them.
  final _diskReads = _DeviceHistory();
  Map<String, List<double?>> get diskReadsByDevice => _diskReads.byDevice;
  final _diskWrites = _DeviceHistory();
  Map<String, List<double?>> get diskWritesByDevice => _diskWrites.byDevice;
  final _netRx = _DeviceHistory();
  Map<String, List<double?>> get netRxByDevice => _netRx.byDevice;
  final _netTx = _DeviceHistory();
  Map<String, List<double?>> get netTxByDevice => _netTx.byDevice;

  /// Milliseconds since epoch of each sample
  final time = Fifo<int>(capacity: capacity);

  int get length => time.length;
  bool get isEmpty => time.isEmpty;

  /// Appends [s]. Anything this refresh could not measure is `null`, which
  /// keeps every series index-aligned with [time].
  void add(StatusHistorySample s) {
    // A repeated sampling instant means the source hasn't advanced (monitor
    // refreshes its metrics once per collection cycle, which is slower than
    // the app polls). Appending it again would flat-line the charts.
    if (time.isNotEmpty && s.timeMs <= time.last) return;

    time.add(s.timeMs);
    cpu.add(s.cpu);
    mem.add(s.mem);
    swap.add(s.swap);
    disk.add(s.disk);
    netRx.add(s.netRx);
    netTx.add(s.netTx);
    diskRead.add(s.diskRead);
    diskWrite.add(s.diskWrite);
    gpu.add(s.gpu);
    temp.add(s.temp);
    battery.add(s.battery);

    // `time` already holds this sample, so a series appearing now is padded to
    // one short of it.
    _temps.add(s.temps, time.length);
    _diskReads.add(s.diskReads, time.length);
    _diskWrites.add(s.diskWrites, time.length);
    _netRx.add(s.netRxs, time.length);
    _netTx.add(s.netTxs, time.length);
  }

  /// Puts the agent's stored [samples] (oldest first) before the live ones,
  /// so a page opened on a monitor server draws the last hour at once.
  ///
  /// Only the part older than the first live sample goes in: the live samples
  /// are what has been drawn, and a late response must not rewrite them. The
  /// capacity keeps the newest: past it, the oldest stored samples go, never
  /// live ones.
  void seed(List<StatusHistorySample> samples) {
    final firstLive = isEmpty ? null : time.first;
    final older = [
      for (final s in samples)
        if (firstLive == null || s.timeMs < firstLive) s,
    ];
    if (older.isEmpty) return;
    final live = [for (var i = 0; i < length; i++) _sampleAt(i)];
    _clear();
    older.forEach(add);
    live.forEach(add);
  }

  /// The sample at [i], devices included.
  StatusHistorySample _sampleAt(int i) => StatusHistorySample(
    timeMs: time[i],
    cpu: cpu[i],
    mem: mem[i],
    swap: swap[i],
    disk: disk[i],
    netRx: netRx[i],
    netTx: netTx[i],
    diskRead: diskRead[i],
    diskWrite: diskWrite[i],
    gpu: gpu[i],
    temp: temp[i],
    battery: battery[i],
    temps: _temps.at(i),
    diskReads: _diskReads.at(i),
    diskWrites: _diskWrites.at(i),
    netRxs: _netRx.at(i),
    netTxs: _netTx.at(i),
  );

  void _clear() {
    for (final f in [time, cpu, mem, swap, disk, netRx, netTx, diskRead, diskWrite, gpu, temp, battery]) {
      f.clear();
    }
    for (final d in [_temps, _diskReads, _diskWrites, _netRx, _netTx]) {
      d.byDevice.clear();
    }
  }
}

/// One metric's value per device, index-aligned with [StatusHistory.time] like
/// the fixed series: a device that appears mid-run is backfilled with nulls,
/// and one that disappears keeps getting them, so index `i` means the same
/// sample in every series of every metric.
class _DeviceHistory {
  final byDevice = <String, Fifo<double?>>{};

  /// [sampleCount] is how many samples the buffer holds *including* the one
  /// being added, which is what a series appearing now has to be padded to.
  void add(Map<String, double>? reported, int sampleCount) {
    final values = reported ?? const <String, double>{};
    for (final device in {...byDevice.keys, ...values.keys}) {
      final series = byDevice.putIfAbsent(device, () {
        final f = Fifo<double?>(capacity: StatusHistory.capacity);
        for (var i = 1; i < sampleCount; i++) {
          f.add(null);
        }
        return f;
      });
      series.add(values[device]);
      // Gone for a whole buffer: nothing of it is left to draw, and kept, a
      // host cycling through short-lived interfaces grows a series for each.
      if (!values.containsKey(device) && series.every((e) => e == null)) {
        byDevice.remove(device);
      }
    }
  }

  /// What sample [i] had per device, the devices without a reading left out.
  Map<String, double> at(int i) => {
    for (final MapEntry(:key, :value) in byDevice.entries) key: ?value[i],
  };
}

/// One point of a [StatusHistory]: a live refresh's, or a stored one handed
/// to [StatusHistory.seed] (which has no GPU or per-device readings).
class StatusHistorySample {
  final int timeMs;
  final double? cpu;
  final double? mem;
  final double? swap;
  final double? disk;
  final double? netRx;
  final double? netTx;
  final double? diskRead;
  final double? diskWrite;
  final double? gpu;
  final double? temp;
  final double? battery;
  final Map<String, double>? temps;
  final Map<String, double>? diskReads;
  final Map<String, double>? diskWrites;
  final Map<String, double>? netRxs;
  final Map<String, double>? netTxs;

  const StatusHistorySample({
    required this.timeMs,
    this.cpu,
    this.mem,
    this.swap,
    this.disk,
    this.netRx,
    this.netTx,
    this.diskRead,
    this.diskWrite,
    this.gpu,
    this.temp,
    this.battery,
    this.temps,
    this.diskReads,
    this.diskWrites,
    this.netRxs,
    this.netTxs,
  });
}
