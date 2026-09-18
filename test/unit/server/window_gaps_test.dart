import 'package:flutter_test/flutter_test.dart';
import 'package:server_box/view/page/server/detail/window_gaps.dart';

/// The arithmetic behind the blank bands on the detail page's chart.
///
/// Where the samples stop is the fact the chart exists to show, and it is the
/// one thing a line drawn across the gap hides: a window the agent could only
/// half fill looks like a full one, and a page left in the background for four
/// minutes looks like a machine that went quiet. The tolerances are what keep
/// that from becoming furniture — every stored window comes back a bucket
/// short of both its ends, and a band on every chart is a band nobody reads.
void main() {
  const minute = 60 * 1000;
  const hour = 60 * minute;

  /// A day-long window ending at a round number, which every case below fills
  /// differently.
  const to = 1000 * hour;
  const from = to - 24 * hour;

  List<WindowGap> gapsWith({
    required int first,
    required int last,
    int tolerance = 5 * minute,
  }) => windowGaps(
    from: from,
    to: to,
    first: first,
    last: last,
    leadTolerance: tolerance,
    trailTolerance: tolerance,
  );

  test('samples reaching both ends leave no gap', () {
    expect(gapsWith(first: from, last: to), isEmpty);
  });

  test('a window the samples start late in has a gap at the front', () {
    final gaps = gapsWith(first: from + 21 * hour, last: to);

    expect(gaps, hasLength(1));
    expect(gaps.single.leading, isTrue);
    expect(gaps.single.from, from);
    expect(gaps.single.to, from + 21 * hour);
  });

  test('samples that stopped early leave a gap at the end', () {
    final gaps = gapsWith(first: from, last: to - 4 * hour);

    expect(gaps, hasLength(1));
    expect(gaps.single.leading, isFalse);
    expect(gaps.single.from, to - 4 * hour);
    expect(gaps.single.to, to);
  });

  test('an hour of samples in the middle of a day is a gap either side', () {
    final gaps = gapsWith(first: from + 10 * hour, last: from + 11 * hour);

    expect(gaps.map((e) => e.leading), [true, false]);
    expect(gaps.first.to, from + 10 * hour);
    expect(gaps.last.from, from + 11 * hour);
  });

  /// Both ends of a stored window are inexact — it comes back bucketed — so a
  /// shortfall inside the tolerance is the bucketing and not a gap.
  test('a shortfall within the tolerance is not a gap', () {
    expect(
      gapsWith(
        first: from + 4 * minute,
        last: to - 4 * minute,
        tolerance: 5 * minute,
      ),
      isEmpty,
    );
    expect(
      gapsWith(
        first: from + 6 * minute,
        last: to - 6 * minute,
        tolerance: 5 * minute,
      ),
      hasLength(2),
    );
  });

  test('a band never reaches outside the window it is drawn on', () {
    // A sample from before the window and one from after it: both are
    // possible, since the window is the request and the samples are the
    // answer to a slightly different one.
    final gaps = gapsWith(first: from - 5 * hour, last: to + 5 * hour);

    expect(gaps, isEmpty, reason: 'samples covering the window leave no gap');

    final clamped = windowGaps(
      from: from,
      to: to,
      first: from + 12 * hour,
      last: to + 5 * hour,
      leadTolerance: 0,
      trailTolerance: 0,
    );
    expect(clamped.single.to, lessThanOrEqualTo(to));
    expect(clamped.single.from, greaterThanOrEqualTo(from));
  });

  test('a window with no width, or samples in no order, has no bands', () {
    expect(
      windowGaps(
        from: to,
        to: to,
        first: to,
        last: to,
        leadTolerance: 0,
        trailTolerance: 0,
      ),
      isEmpty,
    );
    expect(
      windowGaps(
        from: from,
        to: to,
        first: to,
        last: from,
        leadTolerance: 0,
        trailTolerance: 0,
      ),
      isEmpty,
      reason: 'a newest older than the oldest is not a window with two gaps',
    );
  });
}
