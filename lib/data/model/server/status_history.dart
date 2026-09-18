import 'package:server_box/data/model/server/time_seq.dart';

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

  /// Appends one sample. Callers pass `null` for anything this refresh could
  /// not measure, which keeps every series index-aligned with [time].
  void add({
    required int timeMs,
    double? cpu,
    double? mem,
    double? swap,
    double? disk,
    double? netRx,
    double? netTx,
    double? diskRead,
    double? diskWrite,
    double? gpu,
    double? temp,
    Map<String, double>? temps,
    Map<String, double>? diskReads,
    Map<String, double>? diskWrites,
    Map<String, double>? netRxs,
    Map<String, double>? netTxs,
    double? battery,
  }) {
    // A repeated sampling instant means the source hasn't advanced (monitor
    // refreshes its metrics once per collection cycle, which is slower than
    // the app polls). Appending it again would flat-line the charts.
    if (time.isNotEmpty && timeMs <= time.last) return;

    time.add(timeMs);
    this.cpu.add(cpu);
    this.mem.add(mem);
    this.swap.add(swap);
    this.disk.add(disk);
    this.netRx.add(netRx);
    this.netTx.add(netTx);
    this.diskRead.add(diskRead);
    this.diskWrite.add(diskWrite);
    this.gpu.add(gpu);
    this.temp.add(temp);
    this.battery.add(battery);

    // `time` already holds this sample, so a series appearing now is padded to
    // one short of it.
    _temps.add(temps, time.length);
    _diskReads.add(diskReads, time.length);
    _diskWrites.add(diskWrites, time.length);
    _netRx.add(netRxs, time.length);
    _netTx.add(netTxs, time.length);
  }

  /// Replaces the buffer with [samples], oldest first. Used to prefill from
  /// monitor's stored history before live sampling takes over; a no-op once
  /// live samples exist, so a late-arriving history response can't rewind
  /// what has already been charted.
  void seed(List<StatusHistorySample> samples) {
    if (!isEmpty || samples.isEmpty) return;
    for (final s in samples) {
      add(
        timeMs: s.timeMs,
        cpu: s.cpu,
        mem: s.mem,
        swap: s.swap,
        disk: s.disk,
        netRx: s.netRx,
        netTx: s.netTx,
        diskRead: s.diskRead,
        diskWrite: s.diskWrite,
        temp: s.temp,
        battery: s.battery,
      );
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
    }
  }
}

/// One point handed to [StatusHistory.seed].
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
  final double? temp;
  final double? battery;

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
    this.temp,
    this.battery,
  });
}
