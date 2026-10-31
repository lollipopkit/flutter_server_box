import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:server_box/data/model/server/cron_schedule.dart';

import '../../helpers/rust_lib_helper.dart';

/// A wall clock reads the same whatever timezone the device is in, which is
/// why every time here is UTC-flagged and none of them is an instant.
DateTime _wall(
  int year,
  int month,
  int day, [
  int hour = 0,
  int minute = 0,
]) => DateTime.utc(year, month, day, hour, minute);

void main() {
  setUpAll(() async {
    await initRustLibForTest();
    // [CronSchedule.weekdayName] formats through intl, which the app has
    // loaded by the time a page is on screen and a test does not.
    await initializeDateFormatting('en');
  });

  group('parse', () {
    test('expands every form a field can take', () {
      final schedule = CronSchedule.tryParse('0,30 9-17/4 * jan-mar mon-fri')!;

      expect(schedule.minutes, {0, 30});
      expect(schedule.hours, {9, 13, 17});
      expect(schedule.daysOfMonth, hasLength(31));
      expect(schedule.months, {1, 2, 3});
      expect(schedule.daysOfWeek, {1, 2, 3, 4, 5});
      expect(schedule.dayOfMonthRestricted, isFalse);
      expect(schedule.dayOfWeekRestricted, isTrue);
    });

    // vixie and cronie refuse the file, busybox sets no bits so the line never
    // fires, and some others wrap it round. Reading it either way would put a
    // next run on the page for a line the server may never run.

    // A line this cannot read is still a line the page must keep, so parsing
    // answers null rather than throwing or guessing.
  });

  group('next run', () {
    test('is the next minute the expression matches, never this one', () {
      final schedule = CronSchedule.tryParse('*/15 * * * *')!;

      expect(schedule.nextRun(_wall(2026, 3, 1, 9, 0)), _wall(2026, 3, 1, 9, 15));
      expect(schedule.nextRun(_wall(2026, 3, 1, 9, 14)), _wall(2026, 3, 1, 9, 15));
      expect(schedule.nextRun(_wall(2026, 3, 1, 9, 59)), _wall(2026, 3, 1, 10, 0));
    });

    /// crond runs a line whose day of month *and* day of week are both
    /// restricted on either of them, so `13th or Friday` is not `Friday the
    /// 13th` — a schedule read the other way would name a next run months off.
  });

  group('describe', () {
    test('says the common schedules in words', () {
      String? describe(String expr) => CronSchedule.tryParse(expr)?.describe();

      expect(describe('@reboot'), 'At boot');
      expect(describe('* * * * *'), 'Every minute');
      expect(describe('*/5 * * * *'), 'Every 5 minutes');
      expect(describe('30 * * * *'), 'Every hour at :30');
      expect(describe('0 */6 * * *'), 'Every 6 hours');
      expect(describe('15 */6 * * *'), 'Every 6 hours at :15');
      expect(describe('0 2 * * *'), 'Every day at 02:00');
      expect(describe('@daily'), 'Every day at 00:00');
      expect(describe('15 3 * * 1-5'), 'On weekdays at 03:15');
      expect(describe('30 4 * * 0'), 'Every Sunday at 04:30');
      expect(describe('0 0 1 * *'), 'Day 1 of every month at 00:00');
    });

    /// A description that drops a field says the line runs more often than it
    /// does. Where there is no sentence for the whole thing, the page shows
    /// the expression instead.
    test('says nothing rather than half of it', () {
      String? describe(String expr) => CronSchedule.tryParse(expr)?.describe();

      // Every 5 minutes, but only on weekdays.
      expect(describe('*/5 * * * 1-5'), isNull);
      // Twice a day.
      expect(describe('0 2,14 * * *'), isNull);
      // Only in one month.
      expect(describe('0 0 1 1 *'), isNull);
      // Three days of the week.
      expect(describe('0 9 * * 1,3,5'), isNull);
      // A step that stops before the end of the field runs four times in the
      // first half hour and not at all in the second, which "every 10
      // minutes" would not lead anyone to expect.
      expect(describe('0-30/10 * * * *'), isNull);
    });
  });

  group('clock', () {
    test('reads what date printed', () {
      final clock = CronClock.fromServer(
        epochSeconds: 1772000000,
        offsetMinutes: 480,
        now: DateTime.fromMillisecondsSinceEpoch(1772000000 * 1000, isUtc: true),
      );

      expect(clock.offset, const Duration(hours: 8));
      expect(clock.skew, Duration.zero);
      expect(clock.nowWall().hour, clock.nowInstant().add(clock.offset).hour);
    });

    test('carries a negative offset and a clock that disagrees', () {
      final clock = CronClock.fromServer(
        epochSeconds: 1772000060,
        offsetMinutes: -210,
        now: DateTime.fromMillisecondsSinceEpoch(1772000000 * 1000, isUtc: true),
      );

      expect(clock.offset, const Duration(hours: -3, minutes: -30));
      expect(clock.skew, const Duration(minutes: 1));
    });

    test('a wall time converts back to the instant it happens at', () {
      const clock = CronClock(offset: Duration(hours: 8), skew: Duration.zero);
      final wall = _wall(2026, 3, 1, 2, 0);

      expect(clock.toInstant(wall), DateTime.utc(2026, 2, 28, 18, 0));
      expect(clock.toWall(clock.toInstant(wall)), wall);
    });
  });
}
