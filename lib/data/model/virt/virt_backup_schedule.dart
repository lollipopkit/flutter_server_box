/// PVE's backup schedule: a **subset of systemd calendar events**
/// (`PVE::CalendarEvent`, the `pve-calendar-event` format), which is what
/// `GET/POST/PUT /cluster/backup` takes as `schedule` and what its own job
/// editor offers through a `pveCalendarEvent` field.
///
/// What PVE accepts, read from its parser and checked against
/// `GET /cluster/jobs/schedule-analyze` on PVE 9.2.2:
///
/// ```
/// 02:30                       every day at 02:30
/// 02:30:15                    with seconds
/// mon..fri 02:30              weekdays (mon,tue,wed,thu,fri also works)
/// mon,wed 03:00               two days
/// sat 03:00                   one day
/// *-*-* 04:00                 a date part
/// hourly  daily  weekly  monthly  yearly     systemd's shorthands
/// *:0/15  */5                 intervals
/// ```
///
/// The whole shape is `[WEEKDAY] [[YYYY-]MM-DD] [HH:MM[:SS]]`, each part
/// optional and in that order, with `..` ranges in any of them — PVE's own
/// documentation (Schedule Format) lists `sat *-1..7 15:00` (the first
/// Saturday of each month), `mon..fri 8..17,22:0/15` and `2015-10-21 01:00`.
///
/// Refused, in PVE's own words (`schedule-analyze`, the same call its
/// editor's "Simulate" button makes): `nope` (`invalid calendar event`, with
/// where the parse stopped), `02:30 mon` (a weekday after the time),
/// `Mon-Fri 02:30` (a range is written `..`), `* 02:30` (a weekday list is
/// never `*`), `mon 02:70` (minutes above 59), anything holding a `;`. `mon
/// 25:00` is **accepted** — the hour field is not range-checked the way the
/// minute is.
///
/// So [virtScheduleIssue] is a local shape check with PVE's own bounds where
/// they are cheap to state (a field's parts at most 59, an interval's step
/// 1..59), and the form's own Validate asks the host
/// (`GET /cluster/jobs/schedule-analyze`) for the rest. A schedule both
/// accept is written; one the host refuses is shown in its words.
///
/// The 32 values `test/unit/virt/virt_backup_job_test.dart` checks were each
/// put to that endpoint on PVE 9.2.2, and the local check's answer matches
/// the host's on every one of them. The documentation's own examples it also
/// checks were not put to a host.
library;

/// The shorthands systemd and PVE both take as a whole schedule.
const virtScheduleShorthands = {
  'minutely',
  'hourly',
  'daily',
  'weekly',
  'monthly',
  'quarterly',
  'semiannually',
  'yearly',
  'annually',
};

final _dayPart = RegExp(r'^([a-z]{3})(\.\.([a-z]{3}))?$');
const _dayNames = {'mon', 'tue', 'wed', 'thu', 'fri', 'sat', 'sun'};

/// A `HH[:MM[:SS]]` field: one to three plain numbers. What each of them may
/// reach is checked in [_isTime], which is where PVE's own bounds live.
final _time = RegExp(r'^\d{1,3}(?::\d{1,3}(?::\d{1,3})?)?$');

/// The same field, but with an interval, a list or a range in any of its
/// parts: `*:0/15`, `0/15`, `0,30:0`, `8..17,22:0/15`.
final _timeInterval = RegExp(
  r'^(?:[\d,/.\-]+|\*)(?::(?:[\d,/.\-]+|\*)(?::(?:[\d,/.\-]+|\*))?)?$',
);

/// A date part (`*-*-*`, `2026-10-01`, `*-1..7`). It always holds a `-`: a
/// bare `*` is a weekday list, and a weekday list is never `*` (`invalid
/// calendar event at '*'`, verified).
final _datePart = RegExp(r'^[*0-9,./]*-[*0-9,./\-]+$');

/// The interval a list or a range carries: `*/5`, `0/15`, `1-5/2`, or none.
final _intervalAt = RegExp(r'/(\d+)');

/// A whole schedule as one field: `*/5` — every five minutes, which is what
/// PVE's own examples use.
final _bareStep = RegExp(r'^\*/\d+$');

/// Why [schedule] cannot be a backup job's schedule, or null when it has the
/// shape of one PVE would take. A value this accepts can still be refused by
/// the host, so the form asks [`VirtBackend.checkSchedule`] for the answer.
VirtBackupScheduleIssue? virtScheduleIssue(String schedule) {
  final s = schedule.trim();
  if (s.isEmpty) return VirtBackupScheduleIssue.empty;
  if (virtScheduleShorthands.contains(s)) return null;
  // A `;` would be PVE's own refusal; a newline only makes the message
  // unreadable.
  if (RegExp(r'[;\n\r]').hasMatch(s)) return VirtBackupScheduleIssue.invalid;
  final parts = s.split(RegExp(r'\s+'));
  // `[WEEKDAY] [DATE] [TIME]`: each in its place, none twice.
  var i = 0;
  if (i < parts.length && _isDayList(parts[i])) i++;
  if (i < parts.length && _datePart.hasMatch(parts[i])) i++;
  if (i < parts.length && _isTime(parts[i])) i++;
  return i == parts.length ? null : VirtBackupScheduleIssue.invalid;
}

/// A time field: `02:30`, `02:30:15`, `*:0/15`, `0/15`, `0,30`, `1-5`.
bool _isTime(String text) {
  if (_time.hasMatch(text)) {
    // Each part's own ceiling: PVE refuses 60 and above in all three
    // (`mon 59:59` is taken, `mon 60:00` and `mon 59:60` are not). The hour
    // is looser than that — `mon 25:00` is accepted — so the form's own
    // Validate is what settles anything subtler.
    return text.split(':').every((p) => int.parse(p) <= 59);
  }
  if (!_timeInterval.hasMatch(text) && !_bareStep.hasMatch(text)) return false;
  // An interval's step is the one number PVE checks in a field it otherwise
  // reads loosely (`*:0/0` and `*/60` are both refused).
  for (final step in _intervalAt.allMatches(text)) {
    // tryParse: a step too long for an int is invalid, not a throw in the
    // editor's build.
    final n = int.tryParse(step.group(1)!);
    if (n == null || n < 1 || n > 59) return false;
  }
  return true;
}

/// `mon`, `mon,wed`, `mon..fri` — a weekday list or one range of them.
bool _isDayList(String text) => text.split(',').every((part) {
  final m = _dayPart.firstMatch(part);
  if (m == null) return false;
  return _dayNames.contains(m.group(1)) &&
      (m.group(3) == null || _dayNames.contains(m.group(3)));
});

/// Why a schedule cannot be sent. See [virtScheduleIssue].
enum VirtBackupScheduleIssue {
  empty,

  /// Not a calendar event at all.
  invalid,
}

/// What the host makes of a schedule: its refusal in its own words, or the
/// next few times it would run (`GET /cluster/jobs/schedule-analyze`, which
/// is what PVE's job editor's "Simulate" button calls).
final class VirtScheduleCheck {
  const VirtScheduleCheck({this.error, this.next = const []});

  /// PVE's refusal, verbatim; null when it takes the schedule.
  final String? error;

  /// When it would next run, oldest first, as PVE computed them (UTC, as the
  /// endpoint answers).
  final List<DateTime> next;

  bool get ok => error == null;
}
