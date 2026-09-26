/// The one bar a tile has room for.
///
/// A tile is read at a glance, in a grid of a hundred, so what its bar says
/// has to be true of the machine and not of one reading: the lengths are what
/// this file is about.
library;

import 'package:flutter/widgets.dart' show IconData;
import 'package:flutter_test/flutter_test.dart';
import 'package:server_box/view/page/server/card/metric.dart';

ServerMetric _metric(ServerMetricKind kind, double? percent) => ServerMetric(
  kind: kind,
  label: kind.name,
  icon: const IconData(0),
  value: '',
  note: '',
  bigNote: '',
  samples: const [],
  times: const [],
  format: (v) => '$v',
  percent: percent,
);

ServerCardReadings _readings(List<ServerMetric> all) =>
    (shown: all, all: all);

void main() {
  double total(List<ServerPressureSegment> segments) =>
      segments.fold(0.0, (a, s) => a + s.share);

  test('the CPU takes its whole share, memory and disk half of theirs', () {
    final segments = serverPressure(
      _readings([
        _metric(ServerMetricKind.cpu, 0.40),
        _metric(ServerMetricKind.mem, 0.60),
        _metric(ServerMetricKind.disk, 0.80),
      ]),
    );

    expect(segments.map((s) => s.kind), [
      ServerMetricKind.cpu,
      ServerMetricKind.mem,
      ServerMetricKind.disk,
    ]);
    expect(segments[0].share, closeTo(0.40, 1e-9));
    expect(segments[1].share, closeTo(0.30, 1e-9));
    expect(segments[2].share, closeTo(0.40, 1e-9));
  });

  test('the order is the same on every tile, whatever order they arrive in', () {
    // The colour is the only thing saying which segment is which, so the
    // sequence has to be one the reader can learn.
    final segments = serverPressure(
      _readings([
        _metric(ServerMetricKind.disk, 0.5),
        _metric(ServerMetricKind.net, 0.5),
        _metric(ServerMetricKind.mem, 0.5),
        _metric(ServerMetricKind.cpu, 0.5),
      ]),
    );
    expect(segments.map((s) => s.kind), [
      ServerMetricKind.cpu,
      ServerMetricKind.mem,
      ServerMetricKind.disk,
    ]);
  });

  test('a reading with no full to be a share of takes no room', () {
    // A rate — the network, the disk's throughput — has no percentage, so
    // there is no length it could be drawn at.
    final segments = serverPressure(
      _readings([
        _metric(ServerMetricKind.cpu, 0.20),
        _metric(ServerMetricKind.net, null),
        _metric(ServerMetricKind.diskIo, null),
      ]),
    );
    expect(segments, hasLength(1));
    expect(segments.single.kind, ServerMetricKind.cpu);
  });

  test('a machine that has said nothing has an empty bar, not a broken one', () {
    expect(serverPressure(null), isEmpty);
    expect(serverPressure(_readings(const [])), isEmpty);
    expect(
      serverPressure(_readings([_metric(ServerMetricKind.cpu, 0)])),
      isEmpty,
    );
  });

  test('everything at once fills the bar and runs past it', () {
    // Which is the reading it deserves: full is full, and a view whose
    // question is "which one is under load" does not owe a distinction
    // between loaded and more loaded.
    final segments = serverPressure(
      _readings([
        _metric(ServerMetricKind.cpu, 1.0),
        _metric(ServerMetricKind.mem, 1.0),
        _metric(ServerMetricKind.disk, 1.0),
      ]),
    );
    expect(total(segments), closeTo(2.0, 1e-9));
  });

  test('an idle machine with a full disk is not an empty bar', () {
    // The whole reason the bar is not one reading.
    final quiet = serverPressure(
      _readings([
        _metric(ServerMetricKind.cpu, 0.04),
        _metric(ServerMetricKind.mem, 0.30),
        _metric(ServerMetricKind.disk, 0.05),
      ]),
    );
    final full = serverPressure(
      _readings([
        _metric(ServerMetricKind.cpu, 0.04),
        _metric(ServerMetricKind.mem, 0.30),
        _metric(ServerMetricKind.disk, 0.98),
      ]),
    );
    expect(total(full), greaterThan(total(quiet) * 2));
  });

  test('a reading over its line says so, and only that one does', () {
    final segments = serverPressure(
      _readings([
        _metric(ServerMetricKind.cpu, 0.10),
        _metric(ServerMetricKind.mem, kServerAlertPercent / 100),
        _metric(ServerMetricKind.disk, 0.10),
      ]),
    );
    expect(segments.map((s) => s.over), [false, true, false]);
  });

  test('a percentage past its own full is held at it', () {
    // Some machines report more than 100% — a load average read as a share, a
    // disk counting reserved blocks. A segment longer than the bar would
    // silently take the room the others are drawn in.
    final segments = serverPressure(
      _readings([_metric(ServerMetricKind.cpu, 3.5)]),
    );
    expect(segments.single.share, 1.0);
  });
}
