import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:server_box/view/page/server/chart.dart';

/// The axis of a chart of what this app watched itself.
///
/// It ran from the first sample to the clock, so a line reached neither end of
/// its chart — and the two stretches it left were widest on the machine that
/// had only just answered, which is the one being looked at.
void main() {
  HistorySeries series(List<double?> values) =>
      HistorySeries('s', Colors.blue, values);

  const times = [1000, 4000, 7000, 10000];

  test('starts at the first reading drawn, not at the first sample', () {
    // CPU: the share of the counters between two reads, so nothing at the
    // first of them.
    final window = watchedWindow(times, [
      series([null, 12, 14, 13]),
    ]);
    expect(window, (from: 4000, to: 10000));
  });

  test('which with several lines is the earliest of them', () {
    final window = watchedWindow(times, [
      series([null, null, 3, 4]),
      series([null, 1, 2, 3]),
    ]);
    expect(window?.from, 4000);
  });

  test('ends at the last sample, not at the clock', () {
    final window = watchedWindow(times, [
      series([1, 2, 3, 4]),
    ]);
    expect(window, (from: 1000, to: 10000));
  });

  test('and not at the last reading drawn either', () {
    // A reading that is no longer taken ended where it ended. Stretched up to
    // the last sample it would be drawn as current.
    final window = watchedWindow(times, [
      series([1, 2, null, null]),
    ]);
    expect(window?.to, 10000);
  });

  test('runs on to the clock once the readings have stopped', () {
    final window = watchedWindow(
      times,
      [
        series([1, 2, 3, 4]),
      ],
      until: 310000,
    );
    expect(window, (from: 1000, to: 310000));
  });

  test('but never back from the last sample', () {
    // A machine whose clock is ahead of this one reports samples from what is
    // the future here.
    final window = watchedWindow(
      times,
      [
        series([1, 2, 3, 4]),
      ],
      until: 9000,
    );
    expect(window?.to, 10000);
  });

  test('is nothing when there is nothing to draw', () {
    expect(watchedWindow(const [], [series(const [])]), isNull);
    expect(watchedWindow(times, [series([null, null, null, null])]), isNull);
    expect(watchedWindow(times, const []), isNull);
  });

  test('a series longer than the instants it has is read as far as they go', () {
    // The two are built together; a mismatch means the buffer moved under the
    // build, and that is not worth a range error.
    final window = watchedWindow(const [1000, 4000], [
      series([null, null, 5]),
    ]);
    expect(window, isNull);
  });
}
