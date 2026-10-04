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
/// they are cheap to state (`sbm_virt::backup::schedule_issue`), and the
/// form's own Validate asks the host (`GET /cluster/jobs/schedule-analyze`)
/// for the rest. A schedule both accept is written; one the host refuses is
/// shown in its words.
library;

import 'package:server_box/src/rust/api/backup.dart' as ffi;

/// Why [schedule] cannot be a backup job's schedule, or null when it has the
/// shape of one PVE would take. A value this accepts can still be refused by
/// the host, so the form asks [`VirtBackend.checkSchedule`] for the answer.
VirtBackupScheduleIssue? virtScheduleIssue(String schedule) =>
    switch (ffi.virtScheduleIssue(schedule: schedule)) {
      null => null,
      'schedule_empty' => VirtBackupScheduleIssue.empty,
      _ => VirtBackupScheduleIssue.invalid,
    };

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
