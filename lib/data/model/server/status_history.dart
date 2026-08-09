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
  /// ~25 minutes at the app's default refresh interval, and enough to make
  /// monitor's 300-bucket history seed fit exactly
  static const capacity = 300;

  /// Percent, 0-100
  final cpu = Fifo<double?>(capacity: capacity);
  final mem = Fifo<double?>(capacity: capacity);
  final disk = Fifo<double?>(capacity: capacity);
  final battery = Fifo<double?>(capacity: capacity);

  /// Bytes per second
  final netRx = Fifo<double?>(capacity: capacity);
  final netTx = Fifo<double?>(capacity: capacity);
  final diskRead = Fifo<double?>(capacity: capacity);
  final diskWrite = Fifo<double?>(capacity: capacity);

  /// Celsius. The aggregate reading, kept for sources that only expose one
  /// (and for [seed], since monitor's stored history has a single column).
  final temp = Fifo<double?>(capacity: capacity);

  /// Celsius per sensor, for hosts that expose several. Every series is
  /// index-aligned with [time] like the fixed ones: a device that appears
  /// mid-run is backfilled with nulls, and one that disappears keeps getting
  /// them, so index `i` means the same sample in all of them.
  final _tempsByDevice = <String, Fifo<double?>>{};
  Map<String, List<double?>> get tempsByDevice => _tempsByDevice;

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
    double? disk,
    double? netRx,
    double? netTx,
    double? diskRead,
    double? diskWrite,
    double? temp,
    Map<String, double>? temps,
    double? battery,
  }) {
    // A repeated sampling instant means the source hasn't advanced (monitor
    // refreshes its metrics once per collection cycle, which is slower than
    // the app polls). Appending it again would flat-line the charts.
    if (time.isNotEmpty && timeMs <= time.last) return;

    time.add(timeMs);
    this.cpu.add(cpu);
    this.mem.add(mem);
    this.disk.add(disk);
    this.netRx.add(netRx);
    this.netTx.add(netTx);
    this.diskRead.add(diskRead);
    this.diskWrite.add(diskWrite);
    this.temp.add(temp);
    this.battery.add(battery);

    final reported = temps ?? const <String, double>{};
    for (final device in {..._tempsByDevice.keys, ...reported.keys}) {
      final series = _tempsByDevice.putIfAbsent(device, () {
        // `time` already holds this sample, so pad to one short of it
        final f = Fifo<double?>(capacity: capacity);
        for (var i = 1; i < time.length; i++) {
          f.add(null);
        }
        return f;
      });
      series.add(reported[device]);
    }
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

/// One point handed to [StatusHistory.seed].
class StatusHistorySample {
  final int timeMs;
  final double? cpu;
  final double? mem;
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
    this.disk,
    this.netRx,
    this.netTx,
    this.diskRead,
    this.diskWrite,
    this.temp,
    this.battery,
  });
}
