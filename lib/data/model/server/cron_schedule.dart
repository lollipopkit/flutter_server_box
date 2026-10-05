import 'package:intl/intl.dart';
import 'package:server_box/core/extension/context/locale.dart';
import 'package:server_box/src/rust/api/cron.dart' as ffi;

/// A cron expression, expanded by `sbm_parser::cron` far enough to say when it
/// next runs, and said in words here: the wording is the one part each client
/// keeps.
///
/// This is for reading only. What a server runs is decided by its own crond,
/// so anything this cannot parse is shown as it was written rather than
/// refused: every crond has syntax of its own (`L`, `W`, `CRON_TZ=`, seconds
/// fields), and a line the page will not describe is still a line the page
/// must not lose.
final class CronSchedule {
  CronSchedule._(this.expression, ffi.CronScheduleFields fields)
    : minutes = fields.minutes.toSet(),
      hours = fields.hours.toSet(),
      daysOfMonth = fields.daysOfMonth.toSet(),
      months = fields.months.toSet(),
      daysOfWeek = fields.daysOfWeek.toSet(),
      dayOfMonthRestricted = fields.dayOfMonthRestricted,
      dayOfWeekRestricted = fields.dayOfWeekRestricted,
      isReboot = fields.isReboot;

  final String expression;
  final Set<int> minutes;
  final Set<int> hours;
  final Set<int> daysOfMonth;
  final Set<int> months;

  /// Sunday is `0`; a `7` written in the field is folded onto it.
  final Set<int> daysOfWeek;

  /// Whether the day of month field was something other than `*`.
  ///
  /// It matters after the field is expanded, because a day of month and a day
  /// of week that are *both* restricted match on either one — `0 0 13 * 5` is
  /// the 13th of the month and every Friday, not Friday the 13th.
  final bool dayOfMonthRestricted;

  /// Whether the day of week field was something other than `*`.
  final bool dayOfWeekRestricted;

  /// `@reboot` runs once when the machine starts, so it has no next time.
  final bool isReboot;

  static CronSchedule? tryParse(String expression) {
    final fields = ffi.cronScheduleParse(expression: expression);
    return fields == null ? null : CronSchedule._(expression, fields);
  }

  /// The next minute this matches, strictly after [from].
  ///
  /// [from] and the answer are both the server's wall clock, carried as
  /// UTC-flagged [DateTime]s so that neither the device's timezone nor a DST
  /// change of its own moves them — see [CronClock].
  DateTime? nextRun(DateTime from) {
    final at = ffi.cronNextRun(
      expression: expression,
      from: ffi.CronWall(
        year: from.year,
        month: from.month,
        day: from.day,
        hour: from.hour,
        minute: from.minute,
      ),
    );
    if (at == null) return null;
    return DateTime.utc(at.year, at.month, at.day, at.hour, at.minute);
  }

  /// This schedule in words, or `null` when it cannot be said in one line.
  ///
  /// A caller shows the expression itself instead. Every branch here describes
  /// *every* field the schedule restricts: a sentence that quietly drops one
  /// says the line runs more often than it does.
  String? describe() {
    if (isReboot) return l10n.cronAtBoot;

    final minute = minutes.length == 1 ? minutes.first : null;
    final hour = hours.length == 1 ? hours.first : null;
    final everyMonth = months.length == 12;
    final everyDay =
        everyMonth && !dayOfMonthRestricted && !dayOfWeekRestricted;

    // The repeating forms say nothing about which days they fall on, so they
    // are the whole line only when it runs every day.
    if (everyDay) {
      if (minutes.length == 60 && hours.length == 24) return l10n.cronEveryMin;
      if (hours.length == 24) {
        final step = _stepOf(minutes, 0, 59);
        if (step != null) return l10n.cronEveryMinsFmt(step);
        if (minute != null) return l10n.cronHourlyAtFmt(_two(minute));
      }
      if (minute != null) {
        final step = _stepOf(hours, 0, 23);
        if (step != null) {
          return minute == 0
              ? l10n.cronEveryHoursFmt(step)
              : l10n.cronEveryHoursAtFmt(step, _two(minute));
        }
      }
    }

    if (minute == null || hour == null || !everyMonth) return null;
    final at = '${_two(hour)}:${_two(minute)}';
    if (dayOfMonthRestricted && dayOfWeekRestricted) return null;
    if (dayOfWeekRestricted) {
      if (_setEquals(daysOfWeek, const {1, 2, 3, 4, 5})) {
        return l10n.cronWeekdaysAtFmt(at);
      }
      if (daysOfWeek.length == 1) {
        return l10n.cronWeekdayAtFmt(weekdayName(daysOfWeek.first), at);
      }
      return null;
    }
    if (dayOfMonthRestricted) {
      if (daysOfMonth.length == 1) {
        return l10n.cronMonthlyAtFmt(daysOfMonth.first, at);
      }
      return null;
    }
    return l10n.cronDailyAtFmt(at);
  }

  /// The name of cron's [day], where Sunday is `0`, in the app's language.
  static String weekdayName(int day) {
    // 2024-01-07 was a Sunday, so cron's day 0 is that date and the rest are
    // the days after it.
    final date = DateTime.utc(2024, 1, 7 + day);
    return DateFormat.EEEE(l10n.localeName).format(date);
  }

  /// The step of a `*/n` field, or `null` when [values] is not one.
  ///
  /// It has to start at [min] and reach the end of the field, because that is
  /// what "every n minutes" means — `0,20,40` is every 20 minutes and
  /// `0,20,30` is three times an hour.
  static int? _stepOf(Set<int> values, int min, int max) {
    if (values.length < 2) return null;
    final sorted = values.toList()..sort();
    if (sorted.first != min) return null;
    final step = sorted[1] - sorted[0];
    if (step < 2) return null;
    for (var i = 1; i < sorted.length; i++) {
      if (sorted[i] - sorted[i - 1] != step) return null;
    }
    if (sorted.last + step <= max) return null;
    return step;
  }

  static bool _setEquals(Set<int> a, Set<int> b) {
    return a.length == b.length && a.containsAll(b);
  }

  static String _two(int value) => value.toString().padLeft(2, '0');
}

/// The server's own clock, as its crontab listing reported it.
///
/// Cron matches an expression against the server's wall clock, so a next run
/// worked out in the device's timezone names a time the server will not run
/// at — two hours out on a phone that travelled, a day out either side of
/// midnight. [offset] is what `date +%z` said and [skew] is how far the
/// server's clock is from this device's.
final class CronClock {
  const CronClock({required this.offset, required this.skew});

  /// What to use when the server did not say — an old agent, a `date` without
  /// `%z`. The device's own timezone is a guess, but it is the right one for
  /// the common case of a server in the timezone its owner lives in.
  static CronClock get device =>
      CronClock(offset: DateTime.now().timeZoneOffset, skew: Duration.zero);

  /// The server's offset from UTC.
  final Duration offset;

  /// The server's clock minus this device's, when the listing was read.
  final Duration skew;

  /// What the server's `date +'%s %z'` said, read against this device's
  /// clock at [now].
  factory CronClock.fromServer({
    required int epochSeconds,
    required int offsetMinutes,
    DateTime? now,
  }) {
    final at = (now ?? DateTime.now()).toUtc();
    return CronClock(
      offset: Duration(minutes: offsetMinutes),
      skew: DateTime.fromMillisecondsSinceEpoch(
        epochSeconds * 1000,
        isUtc: true,
      ).difference(at),
    );
  }

  /// The instant the server's clock is at now.
  DateTime nowInstant() => DateTime.now().toUtc().add(skew);

  /// [instant] read off the server's wall clock.
  ///
  /// The result is flagged UTC and is not: it is a naive date and time, the
  /// one a `crontab` line is written in.
  DateTime toWall(DateTime instant) => instant.add(offset);

  /// The instant at which the server's wall clock reads [wall].
  DateTime toInstant(DateTime wall) => wall.subtract(offset);

  /// The server's wall clock now.
  DateTime nowWall() => toWall(nowInstant());
}
