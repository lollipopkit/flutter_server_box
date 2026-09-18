import 'package:intl/intl.dart';
import 'package:server_box/core/extension/context/locale.dart';

/// A cron expression, expanded far enough to say when it next runs and what it
/// means in words.
///
/// This is for reading only. What a server runs is decided by its own crond,
/// so anything this cannot parse is shown as it was written rather than
/// refused: every crond has syntax of its own (`L`, `W`, `CRON_TZ=`, seconds
/// fields), and a line the page will not describe is still a line the page
/// must not lose.
final class CronSchedule {
  const CronSchedule._({
    required this.minutes,
    required this.hours,
    required this.daysOfMonth,
    required this.months,
    required this.daysOfWeek,
    required this.dayOfMonthRestricted,
    required this.dayOfWeekRestricted,
  }) : isReboot = false;

  const CronSchedule._reboot()
    : minutes = const {},
      hours = const {},
      daysOfMonth = const {},
      months = const {},
      daysOfWeek = const {},
      dayOfMonthRestricted = false,
      dayOfWeekRestricted = false,
      isReboot = true;

  /// `@reboot` runs once when the machine starts, so it has no next time and
  /// no schedule to expand.
  static const reboot = CronSchedule._reboot();

  /// The macros crond accepts in place of the five fields, and what each one
  /// stands for. `@reboot` is [reboot] and is not here.
  static const macros = <String, String>{
    '@yearly': '0 0 1 1 *',
    '@annually': '0 0 1 1 *',
    '@monthly': '0 0 1 * *',
    '@weekly': '0 0 * * 0',
    '@daily': '0 0 * * *',
    '@midnight': '0 0 * * *',
    '@hourly': '0 * * * *',
  };

  /// How far ahead [nextRun] looks before answering that there is no next run.
  ///
  /// `0 0 29 2 *` is the reason it is years rather than days: February 29th
  /// comes round every four, and a century that is not a leap year pushes it
  /// to eight.
  static const _searchDays = 366 * 8;

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

  final bool isReboot;

  static CronSchedule? tryParse(String expression) {
    var expr = expression.trim();
    if (expr.isEmpty) return null;
    if (expr.startsWith('@')) {
      final macro = expr.toLowerCase();
      if (macro == '@reboot') return reboot;
      final expanded = macros[macro];
      if (expanded == null) return null;
      expr = expanded;
    }

    final fields = expr.split(RegExp(r'\s+'));
    if (fields.length != 5) return null;
    final minutes = _parseField(fields[0], 0, 59);
    final hours = _parseField(fields[1], 0, 23);
    final daysOfMonth = _parseField(fields[2], 1, 31);
    final months = _parseField(fields[3], 1, 12, names: _monthNames);
    final daysOfWeek = _parseField(fields[4], 0, 7, names: _dayNames);
    if (minutes == null ||
        hours == null ||
        daysOfMonth == null ||
        months == null ||
        daysOfWeek == null) {
      return null;
    }

    return CronSchedule._(
      minutes: minutes,
      hours: hours,
      daysOfMonth: daysOfMonth,
      months: months,
      daysOfWeek: daysOfWeek.map((day) => day % 7).toSet(),
      dayOfMonthRestricted: fields[2] != '*',
      dayOfWeekRestricted: fields[4] != '*',
    );
  }

  /// The next minute this matches, strictly after [from].
  ///
  /// [from] and the answer are both the server's wall clock, carried as
  /// UTC-flagged [DateTime]s so that neither the device's timezone nor a DST
  /// change of its own moves them — see [CronClock].
  DateTime? nextRun(DateTime from) {
    if (isReboot || minutes.isEmpty || hours.isEmpty) return null;
    // Strictly after the minute [from] is in: a job whose minute is the
    // current one has already run this minute.
    final start = DateTime.utc(
      from.year,
      from.month,
      from.day,
      from.hour,
      from.minute,
    ).add(const Duration(minutes: 1));
    final sortedHours = hours.toList()..sort();
    final sortedMinutes = minutes.toList()..sort();

    for (var offset = 0; offset < _searchDays; offset++) {
      final day = DateTime.utc(start.year, start.month, start.day + offset);
      if (!matchesDate(day)) continue;
      for (final hour in sortedHours) {
        for (final minute in sortedMinutes) {
          final at = DateTime.utc(day.year, day.month, day.day, hour, minute);
          if (at.isBefore(start)) continue;
          return at;
        }
      }
    }
    return null;
  }

  /// Whether this schedule runs at all on [day].
  bool matchesDate(DateTime day) {
    if (!months.contains(day.month)) return false;
    final byDayOfMonth = daysOfMonth.contains(day.day);
    // Dart counts Monday as 1 and Sunday as 7; cron counts Sunday as 0.
    final byDayOfWeek = daysOfWeek.contains(day.weekday % 7);
    if (dayOfMonthRestricted && dayOfWeekRestricted) {
      return byDayOfMonth || byDayOfWeek;
    }
    if (dayOfMonthRestricted) return byDayOfMonth;
    if (dayOfWeekRestricted) return byDayOfWeek;
    return true;
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
        if (step != null) return l10n.cronEveryMinsFmt('$step');
        if (minute != null) return l10n.cronHourlyAtFmt(_two(minute));
      }
      if (minute != null) {
        final step = _stepOf(hours, 0, 23);
        if (step != null) {
          return minute == 0
              ? l10n.cronEveryHoursFmt('$step')
              : l10n.cronEveryHoursAtFmt('$step', _two(minute));
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
        return l10n.cronMonthlyAtFmt('${daysOfMonth.first}', at);
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

  static const _monthNames = <String, int>{
    'jan': 1,
    'feb': 2,
    'mar': 3,
    'apr': 4,
    'may': 5,
    'jun': 6,
    'jul': 7,
    'aug': 8,
    'sep': 9,
    'oct': 10,
    'nov': 11,
    'dec': 12,
  };

  static const _dayNames = <String, int>{
    'sun': 0,
    'mon': 1,
    'tue': 2,
    'wed': 3,
    'thu': 4,
    'fri': 5,
    'sat': 6,
  };

  static Set<int>? _parseField(
    String field,
    int min,
    int max, {
    Map<String, int>? names,
  }) {
    final values = <int>{};
    for (final token in field.split(',')) {
      final parsed = _parseToken(token.trim(), min, max, names);
      if (parsed == null) return null;
      values.addAll(parsed);
    }
    return values.isEmpty ? null : values;
  }

  static Iterable<int>? _parseToken(
    String token,
    int min,
    int max,
    Map<String, int>? names,
  ) {
    if (token.isEmpty) return null;
    var body = token;
    var step = 1;
    final slash = token.indexOf('/');
    if (slash >= 0) {
      body = token.substring(0, slash);
      step = int.tryParse(token.substring(slash + 1)) ?? 0;
      if (step < 1) return null;
    }

    final int from;
    final int to;
    if (body == '*') {
      from = min;
      to = max;
    } else {
      final parts = body.split('-');
      if (parts.length > 2) return null;
      final start = _value(parts.first, names, min, max);
      if (start == null) return null;
      from = start;
      if (parts.length == 2) {
        final end = _value(parts[1], names, min, max);
        if (end == null) return null;
        to = end;
      } else {
        // `5/10` is the rest of the field from 5 on; a bare `5` is itself.
        to = slash >= 0 ? max : start;
      }
    }

    // Counted from [from] rather than between the two, so that a range which
    // wraps — `fri-mon`, `22-4` — keeps its step across the seam.
    final period = max - min + 1;
    final span = to >= from ? to - from : period - (from - to);
    return [
      for (var i = 0; i <= span; i += step) min + ((from - min + i) % period),
    ];
  }

  static int? _value(String raw, Map<String, int>? names, int min, int max) {
    final token = raw.trim();
    if (token.isEmpty) return null;
    final value = int.tryParse(token) ?? names?[token.toLowerCase()];
    if (value == null || value < min || value > max) return null;
    return value;
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

  /// `<epoch seconds> <±hhmm>`, as `date +'%s %z'` prints it.
  static CronClock? tryParse(String value, {DateTime? now}) {
    final parts = value.trim().split(RegExp(r'\s+'));
    if (parts.length != 2) return null;
    final epoch = int.tryParse(parts[0]);
    final zone = RegExp(r'^([+-])(\d{2})(\d{2})$').firstMatch(parts[1]);
    if (epoch == null || zone == null) return null;
    final magnitude = Duration(
      hours: int.parse(zone.group(2)!),
      minutes: int.parse(zone.group(3)!),
    );
    final at = (now ?? DateTime.now()).toUtc();
    return CronClock(
      offset: zone.group(1) == '-' ? -magnitude : magnitude,
      skew: DateTime.fromMillisecondsSinceEpoch(
        epoch * 1000,
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
