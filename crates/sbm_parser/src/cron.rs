//! The logged-in account's crontab: the listing script, the document model and
//! the cron expression expansion.
//!
//! Ported from the app's `lib/data/service/cron_manager.dart` and
//! `lib/data/model/server/cron*.dart`; the Dart implementation stays until this
//! one is asserted identical against the same fixtures.
//!
//! The feature is one account's own crontab, as `crontab` itself is: no `-u`,
//! no `/etc/cron.d`, no systemd timers. Running as another user needs sudo,
//! which this does not do — the listing is a read of the account's own spool.
//!
//! ## Division with the caller
//!
//! What is *not* here: the wording of a schedule (`0 3 * * *` → "every day at
//! 03:00"). That is localized per client, so the expansion is returned as
//! numbers and each client says it in its own language. Time is the same
//! question: [`CronClock`] reports the server's own wall clock, and everything
//! on a page is worked out in it, so a client never has to know the server's
//! timezone.

use serde::Serialize;

/// The account's own crontab, the whole of it.
///
/// `crontab -l` and not a `cat` of the spool file: the spool path differs by
/// implementation and needs root on most of them.
///
/// Handed to `sh` rather than run as a command: without an entry the script is
/// parsed by the account's login shell, and fish rejects `LC_ALL=C` and
/// `|| { ... }` outright, which reads as "crontab is not available" with fish's
/// own diagnostic under it.
pub const LIST_SCRIPT: &str = r#"LC_ALL=C
export LC_ALL
command -v crontab >/dev/null 2>&1 || {
  printf 'crontab is not installed\n' >&2
  exit 127
}
printf 'SrvBoxCron.User\t'
id -un || exit $?
printf 'SrvBoxCron.Clock\t%s\n' "$(date +'%s %z' 2>/dev/null)"
printf 'SrvBoxCron.Body\n'
crontab -l
"#;

/// Writes the document on stdin, replacing the account's crontab with it.
pub const SAVE_COMMAND: &str = "crontab -";

/// Exit code the listing uses for "`crontab` is not installed at all", as
/// against a crontab that is empty or one this account may not read.
pub const NOT_INSTALLED_EXIT: i32 = 127;

pub const MARKER_USER: &str = "SrvBoxCron.User\t";
pub const MARKER_CLOCK: &str = "SrvBoxCron.Clock\t";
pub const MARKER_BODY: &str = "SrvBoxCron.Body";

/// Prefix a disabled job is written with, and read back by.
pub const DISABLED_PREFIX: &str = "# ServerBox disabled: ";

#[derive(Debug, Clone, PartialEq, Eq)]
pub enum CronParseError {
    /// The script's own header is missing, so the output was not ours.
    InvalidResponse,
    /// `id -un` printed nothing: the document cannot be attributed.
    NoUser,
}

impl std::fmt::Display for CronParseError {
    fn fmt(&self, f: &mut std::fmt::Formatter<'_>) -> std::fmt::Result {
        f.write_str(match self {
            Self::InvalidResponse => "Invalid crontab response",
            Self::NoUser => "Unable to determine the current user",
        })
    }
}

impl std::error::Error for CronParseError {}

/// Why a line was refused. The message is the client's, so this is only the
/// case, not the sentence.
#[derive(Debug, Clone, Copy, PartialEq, Eq, Serialize)]
#[serde(rename_all = "snake_case")]
pub enum CronValidation {
    ScheduleEmpty,
    CommandEmpty,
    LineBreak,
    /// An `@macro` this app does not know the shape of.
    Macro,
    /// A schedule that is not five whitespace-separated fields.
    FieldCount,
    /// An edit addressed a line that is not a job. Not the same mistake as
    /// [`FieldCount`](Self::FieldCount) and not the same remedy: the expression
    /// is fine, the listing moved, and what the client should do is read it
    /// again rather than change what it typed.
    UnknownLine,
}

impl std::fmt::Display for CronValidation {
    fn fmt(&self, f: &mut std::fmt::Formatter<'_>) -> std::fmt::Result {
        f.write_str(match self {
            Self::ScheduleEmpty => "scheduleEmpty",
            Self::CommandEmpty => "commandEmpty",
            Self::LineBreak => "lineBreak",
            Self::Macro => "macro",
            Self::FieldCount => "fieldCount",
            Self::UnknownLine => "unknownLine",
        })
    }
}

impl std::error::Error for CronValidation {}

/// The server's own clock, as its `date +'%s %z'` reported it.
///
/// Cron matches an expression against the server's wall clock, so a next run
/// worked out in the viewer's timezone names a time the server will not run at
/// — two hours out on a device that travelled, a day out either side of
/// midnight. Everything the caller shows is worked out in this.
#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub struct CronClock {
    /// Seconds since the epoch, UTC.
    pub epoch: i64,
    /// Minutes east of UTC, as `%z` printed.
    pub offset_minutes: i32,
}

impl CronClock {
    /// `<epoch seconds> <±hhmm>`, as `date +'%s %z'` prints it.
    ///
    /// `None` for anything else, which is what a `date` without `%z` produces:
    /// it prints the format back literally. The caller then falls back to a
    /// clock of its own rather than failing the listing.
    pub fn try_parse(value: &str) -> Option<Self> {
        let mut parts = value.split_whitespace();
        let epoch: i64 = parts.next()?.parse().ok()?;
        let zone = parts.next()?;
        if parts.next().is_some() {
            return None;
        }
        let bytes = zone.as_bytes();
        if bytes.len() != 5 {
            return None;
        }
        let sign = match bytes[0] {
            b'+' => 1,
            b'-' => -1,
            _ => return None,
        };
        if !bytes[1..].iter().all(u8::is_ascii_digit) {
            return None;
        }
        let hours: i32 = zone[1..3].parse().ok()?;
        let minutes: i32 = zone[3..5].parse().ok()?;
        Some(Self {
            epoch,
            offset_minutes: sign * (hours * 60 + minutes),
        })
    }

    /// The server's wall clock now, as civil fields.
    pub fn now_wall(&self) -> CivilTime {
        CivilTime::from_epoch_minute((self.epoch + i64::from(self.offset_minutes) * 60) / 60)
    }
}

/// A naive date and time — the fields a crontab line is written in.
///
/// Deliberately not instant-bearing: two of these subtract to the true
/// duration between them, which is what lets a client say "in 14 hours" without
/// knowing either timezone.
#[derive(Debug, Clone, Copy, PartialEq, Eq, PartialOrd, Ord)]
pub struct CivilTime {
    pub year: i32,
    pub month: u32,
    pub day: u32,
    pub hour: u32,
    pub minute: u32,
}

impl CivilTime {
    pub fn new(year: i32, month: u32, day: u32, hour: u32, minute: u32) -> Self {
        Self {
            year,
            month,
            day,
            hour,
            minute,
        }
    }

    /// Days since 1970-01-01, Howard Hinnant's `days_from_civil`.
    pub fn days_from_epoch(&self) -> i64 {
        days_from_civil(self.year, self.month, self.day)
    }

    pub fn from_epoch_minute(minute: i64) -> Self {
        let days = minute.div_euclid(1440);
        let rem = minute.rem_euclid(1440);
        let (year, month, day) = civil_from_days(days);
        Self {
            year,
            month,
            day,
            hour: (rem / 60) as u32,
            minute: (rem % 60) as u32,
        }
    }

    pub fn epoch_minute(&self) -> i64 {
        self.days_from_epoch() * 1440 + i64::from(self.hour) * 60 + i64::from(self.minute)
    }

    /// Cron's day of week, where Sunday is `0`.
    pub fn weekday(&self) -> u32 {
        // 1970-01-01 was a Thursday, which is 4 in cron's numbering.
        (self.days_from_epoch() + 4).rem_euclid(7) as u32
    }

    /// `YYYY-MM-DDTHH:MM`, the one spelling the callers read.
    pub fn to_iso(&self) -> String {
        format!(
            "{:04}-{:02}-{:02}T{:02}:{:02}",
            self.year, self.month, self.day, self.hour, self.minute
        )
    }
}

/// Days since 1970-01-01 for a proleptic Gregorian date.
fn days_from_civil(year: i32, month: u32, day: u32) -> i64 {
    let y = if month <= 2 { year - 1 } else { year } as i64;
    let era = if y >= 0 { y } else { y - 399 } / 400;
    let yoe = y - era * 400;
    let m = i64::from(month);
    let doy = (153 * (if m > 2 { m - 3 } else { m + 9 }) + 2) / 5 + i64::from(day) - 1;
    let doe = yoe * 365 + yoe / 4 - yoe / 100 + doy;
    era * 146_097 + doe - 719_468
}

/// The inverse of [`days_from_civil`].
fn civil_from_days(days: i64) -> (i32, u32, u32) {
    let z = days + 719_468;
    let era = if z >= 0 { z } else { z - 146_096 } / 146_097;
    let doe = z - era * 146_097;
    let yoe = (doe - doe / 1460 + doe / 36524 - doe / 146_096) / 365;
    let y = yoe + era * 400;
    let doy = doe - (365 * yoe + yoe / 4 - yoe / 100);
    let mp = (5 * doy + 2) / 153;
    let d = doy - (153 * mp + 2) / 5 + 1;
    let m = if mp < 10 { mp + 3 } else { mp - 9 };
    let year = if m <= 2 { y + 1 } else { y };
    (year as i32, m as u32, d as u32)
}

/// Where the next run of a cron expression is.
///
/// Reading only. What a server runs is decided by its own crond, so anything
/// this cannot parse is shown as written rather than refused: every crond has
/// syntax of its own (`L`, `W`, `CRON_TZ=`, seconds fields), and a line this
/// will not describe is still a line that must not be lost.
#[derive(Debug, Clone, PartialEq, Eq)]
pub struct CronSchedule {
    pub minutes: Vec<u32>,
    pub hours: Vec<u32>,
    pub days_of_month: Vec<u32>,
    pub months: Vec<u32>,
    /// Sunday is `0`; a `7` written in the field is folded onto it.
    pub days_of_week: Vec<u32>,
    /// Whether the day-of-month field was something other than `*`. It matters
    /// after expansion, because a day of month and a day of week that are
    /// *both* restricted match on either one — `0 0 13 * 5` is the 13th of the
    /// month and every Friday, not Friday the 13th.
    pub day_of_month_restricted: bool,
    pub day_of_week_restricted: bool,
    /// `@reboot` runs once when the machine starts, so it has no next time.
    pub is_reboot: bool,
}

/// The macros crond accepts in place of the five fields. `@reboot` is not one.
const MACROS: &[(&str, &str)] = &[
    ("@yearly", "0 0 1 1 *"),
    ("@annually", "0 0 1 1 *"),
    ("@monthly", "0 0 1 * *"),
    ("@weekly", "0 0 * * 0"),
    ("@daily", "0 0 * * *"),
    ("@midnight", "0 0 * * *"),
    ("@hourly", "0 * * * *"),
];

const MONTH_NAMES: &[(&str, u32)] = &[
    ("jan", 1),
    ("feb", 2),
    ("mar", 3),
    ("apr", 4),
    ("may", 5),
    ("jun", 6),
    ("jul", 7),
    ("aug", 8),
    ("sep", 9),
    ("oct", 10),
    ("nov", 11),
    ("dec", 12),
];

const DAY_NAMES: &[(&str, u32)] = &[
    ("sun", 0),
    ("mon", 1),
    ("tue", 2),
    ("wed", 3),
    ("thu", 4),
    ("fri", 5),
    ("sat", 6),
];

/// How far ahead [`CronSchedule::next_run`] looks before answering that there
/// is no next run.
///
/// `0 0 29 2 *` is the reason it is years rather than days: February 29th comes
/// round every four, and a century that is not a leap year pushes it to eight.
const SEARCH_DAYS: i64 = 366 * 8;

impl CronSchedule {
    pub fn try_parse(expression: &str) -> Option<Self> {
        let trimmed = expression.trim();
        if trimmed.is_empty() {
            return None;
        }
        if let Some(name) = trimmed.strip_prefix('@') {
            let lower = format!("@{}", name.to_lowercase());
            if lower == "@reboot" {
                return Some(Self {
                    minutes: Vec::new(),
                    hours: Vec::new(),
                    days_of_month: Vec::new(),
                    months: Vec::new(),
                    days_of_week: Vec::new(),
                    day_of_month_restricted: false,
                    day_of_week_restricted: false,
                    is_reboot: true,
                });
            }
            return MACROS
                .iter()
                .find(|(name, _)| *name == lower)
                .and_then(|(_, expanded)| Self::try_parse(expanded));
        }

        let fields: Vec<&str> = trimmed.split_whitespace().collect();
        if fields.len() != 5 {
            return None;
        }
        let minutes = parse_field(fields[0], 0, 59, None)?;
        let hours = parse_field(fields[1], 0, 23, None)?;
        let days_of_month = parse_field(fields[2], 1, 31, None)?;
        let months = parse_field(fields[3], 1, 12, Some(MONTH_NAMES))?;
        let days_of_week = parse_field(fields[4], 0, 7, Some(DAY_NAMES))?;

        let mut folded: Vec<u32> = days_of_week.iter().map(|day| day % 7).collect();
        folded.sort_unstable();
        folded.dedup();

        Some(Self {
            minutes,
            hours,
            days_of_month,
            months,
            days_of_week: folded,
            day_of_month_restricted: fields[2] != "*",
            day_of_week_restricted: fields[4] != "*",
            is_reboot: false,
        })
    }

    /// Whether this schedule runs at all on `day`.
    pub fn matches_date(&self, day: &CivilTime) -> bool {
        if !self.months.contains(&day.month) {
            return false;
        }
        let by_day_of_month = self.days_of_month.contains(&day.day);
        let by_day_of_week = self.days_of_week.contains(&day.weekday());
        if self.day_of_month_restricted && self.day_of_week_restricted {
            return by_day_of_month || by_day_of_week;
        }
        if self.day_of_month_restricted {
            return by_day_of_month;
        }
        if self.day_of_week_restricted {
            return by_day_of_week;
        }
        true
    }

    /// The next minute this matches, strictly after `from`.
    ///
    /// `from` and the answer are both the server's wall clock.
    pub fn next_run(&self, from: CivilTime) -> Option<CivilTime> {
        if self.is_reboot || self.minutes.is_empty() || self.hours.is_empty() {
            return None;
        }
        // Strictly after the minute `from` is in: a job whose minute is the
        // current one has already run this minute.
        let start = from.epoch_minute() + 1;
        let mut minutes = self.minutes.clone();
        minutes.sort_unstable();
        let mut hours = self.hours.clone();
        hours.sort_unstable();

        for offset in 0..SEARCH_DAYS {
            let day = CivilTime::from_epoch_minute(start + offset * 1440);
            if !self.matches_date(&day) {
                continue;
            }
            for hour in &hours {
                for minute in &minutes {
                    let at = CivilTime::new(day.year, day.month, day.day, *hour, *minute);
                    if at.epoch_minute() < start {
                        continue;
                    }
                    return Some(at);
                }
            }
        }
        None
    }
}

/// One token's worth of a field, expanded. `None` for anything unreadable, so
/// the whole field is refused rather than partly read.
fn parse_token(token: &str, min: u32, max: u32, names: Option<&[(&str, u32)]>) -> Option<Vec<u32>> {
    if token.is_empty() {
        return None;
    }
    let mut body = token;
    let mut step: u32 = 1;
    let stepped = token.contains('/');
    if let Some(slash) = token.find('/') {
        body = &token[..slash];
        step = token[slash + 1..].parse().ok()?;
        if step < 1 {
            return None;
        }
    }

    let from: u32;
    let to: u32;
    if body == "*" {
        from = min;
        to = max;
    } else {
        let parts: Vec<&str> = body.split('-').collect();
        if parts.len() > 2 {
            return None;
        }
        from = field_value(parts[0], names, min, max)?;
        if parts.len() == 2 {
            to = field_value(parts[1], names, min, max)?;
        } else {
            // `5/10` is the rest of the field from 5 on; a bare `5` is itself.
            to = if stepped { max } else { from };
        }
    }

    // A descending range — `22-2`, `fri-mon` — is answered by nobody in
    // particular: vixie and cronie refuse the file, busybox sets no bits and
    // the line never fires, and some others wrap it round. Reading it as a wrap
    // would put a next run on the page for a line the server may never run,
    // which is worse than saying nothing.
    if to < from {
        return None;
    }
    Some((from..=to).step_by(step as usize).collect())
}

fn field_value(raw: &str, names: Option<&[(&str, u32)]>, min: u32, max: u32) -> Option<u32> {
    let token = raw.trim();
    if token.is_empty() {
        return None;
    }
    let value = match token.parse::<u32>() {
        Ok(number) => number,
        Err(_) => {
            let lower = token.to_lowercase();
            names?.iter().find(|(name, _)| *name == lower)?.1
        }
    };
    if value < min || value > max {
        return None;
    }
    Some(value)
}

fn parse_field(field: &str, min: u32, max: u32, names: Option<&[(&str, u32)]>) -> Option<Vec<u32>> {
    let mut values: Vec<u32> = Vec::new();
    for token in field.split(',') {
        let parsed = parse_token(token.trim(), min, max, names)?;
        values.extend(parsed);
    }
    if values.is_empty() {
        return None;
    }
    values.sort_unstable();
    values.dedup();
    Some(values)
}

/// One readable line of a crontab.
#[derive(Debug, Clone, PartialEq, Eq)]
pub struct CronJob {
    /// Index into [`CronDocument::lines`], which is what an edit addresses.
    pub line_index: usize,
    pub schedule: String,
    pub command: String,
    pub enabled: bool,
}

impl CronJob {
    pub fn parsed(&self) -> Option<CronSchedule> {
        CronSchedule::try_parse(&self.schedule)
    }

    /// Everything a client needs to draw the row, in one value.
    pub fn view(&self, now: Option<CivilTime>) -> CronJobView {
        let schedule = self.parsed();
        let (minutes, hours, days_of_month, months, days_of_week) = match &schedule {
            Some(parsed) => (
                parsed.minutes.clone(),
                parsed.hours.clone(),
                parsed.days_of_month.clone(),
                parsed.months.clone(),
                parsed.days_of_week.clone(),
            ),
            None => (Vec::new(), Vec::new(), Vec::new(), Vec::new(), Vec::new()),
        };
        CronJobView {
            line_index: self.line_index,
            schedule: self.schedule.clone(),
            command: self.command.clone(),
            enabled: self.enabled,
            parsed: schedule.is_some(),
            is_reboot: schedule.as_ref().is_some_and(|s| s.is_reboot),
            minutes,
            hours,
            days_of_month,
            months,
            days_of_week,
            day_of_month_restricted: schedule
                .as_ref()
                .is_some_and(|s| s.day_of_month_restricted),
            day_of_week_restricted: schedule.as_ref().is_some_and(|s| s.day_of_week_restricted),
            next_run: now.and_then(|now| {
                schedule
                    .as_ref()
                    .and_then(|s| s.next_run(now))
                    .map(|at| at.to_iso())
            }),
        }
    }
}

/// A [`CronJob`] plus its expansion, as an endpoint hands it out.
#[derive(Debug, Clone, Serialize)]
pub struct CronJobView {
    pub line_index: usize,
    pub schedule: String,
    pub command: String,
    pub enabled: bool,
    /// Whether the schedule is one this app reads. `false` means the fields
    /// below are empty and the client shows the expression as written.
    pub parsed: bool,
    pub is_reboot: bool,
    pub minutes: Vec<u32>,
    pub hours: Vec<u32>,
    pub days_of_month: Vec<u32>,
    pub months: Vec<u32>,
    pub days_of_week: Vec<u32>,
    pub day_of_month_restricted: bool,
    pub day_of_week_restricted: bool,
    /// `YYYY-MM-DDTHH:MM` on the server's wall clock, or `None` when the
    /// schedule has no next run or the server did not report its clock.
    pub next_run: Option<String>,
}

/// A crontab as a list of lines plus the jobs read out of it.
///
/// Lines are authoritative: [`render`](Self::render) writes back every one of
/// them, so a comment, an environment assignment or a syntax this app does not
/// understand survives a save untouched. A page that showed only the jobs would
/// have to be trusted not to lose the rest.
#[derive(Debug, Clone, PartialEq, Eq)]
pub struct CronDocument {
    pub lines: Vec<String>,
    jobs: Vec<CronJob>,
}

impl CronDocument {
    pub fn parse(raw: &str) -> Self {
        let normalized = raw.replace("\r\n", "\n").replace('\r', "\n");
        let mut lines: Vec<String> = if normalized.is_empty() {
            Vec::new()
        } else {
            normalized.split('\n').map(str::to_owned).collect()
        };
        if lines.last().is_some_and(String::is_empty) {
            lines.pop();
        }
        let jobs = parse_jobs(&lines);
        Self { lines, jobs }
    }

    pub fn jobs(&self) -> &[CronJob] {
        &self.jobs
    }

    /// Every line that is not a task: comments, environment assignments, and
    /// anything this app could not read as one.
    ///
    /// They are what a client shows so that a crontab another tool manages does
    /// not look like it lost them.
    pub fn preserved(&self) -> Vec<&str> {
        let task_lines: Vec<usize> = self.jobs.iter().map(|job| job.line_index).collect();
        self.lines
            .iter()
            .enumerate()
            .filter(|(index, line)| !task_lines.contains(index) && !line.trim().is_empty())
            .map(|(_, line)| line.as_str())
            .collect()
    }

    pub fn render(&self) -> String {
        if self.lines.is_empty() {
            return String::new();
        }
        format!("{}\n", self.lines.join("\n"))
    }

    /// Replaces the job at `line_index`, or appends one when it is `None`.
    pub fn upsert(
        &self,
        line_index: Option<usize>,
        schedule: &str,
        command: &str,
        enabled: bool,
    ) -> Result<Self, CronValidation> {
        if let Some(error) = validate(schedule, command) {
            return Err(error);
        }
        let line = render_job(schedule.trim(), command.trim(), enabled);
        let mut next = self.lines.clone();
        match line_index {
            None => next.push(line),
            Some(index) => {
                self.job_at(index)?;
                let slot = next.get_mut(index).ok_or(CronValidation::UnknownLine)?;
                *slot = line;
            }
        }
        Ok(Self::from_lines(next))
    }

    pub fn remove(&self, line_index: usize) -> Result<Self, CronValidation> {
        self.job_at(line_index)?;
        let mut next = self.lines.clone();
        next.remove(line_index);
        Ok(Self::from_lines(next))
    }

    pub fn set_enabled(&self, line_index: usize, enabled: bool) -> Result<Self, CronValidation> {
        let job = self.job_at(line_index)?;
        let (schedule, command) = (job.schedule.clone(), job.command.clone());
        self.upsert(Some(line_index), &schedule, &command, enabled)
    }

    /// The job at `line_index`, or why the edit naming it is refused.
    ///
    /// Every edit addresses a line by its index in a listing the client was
    /// given, and only a job has an index there. So an index that is out of
    /// range, or that now holds a comment or an environment assignment, is a
    /// listing that moved: applying the edit anyway would overwrite a line the
    /// client never saw, and dropping a comment it was shown.
    fn job_at(&self, line_index: usize) -> Result<&CronJob, CronValidation> {
        self.jobs
            .iter()
            .find(|job| job.line_index == line_index)
            .ok_or(CronValidation::UnknownLine)
    }

    fn from_lines(lines: Vec<String>) -> Self {
        let jobs = parse_jobs(&lines);
        Self { lines, jobs }
    }
}

/// What is wrong with the line these two would make, or `None`.
///
/// It says nothing about whether the schedule will ever fire: `0 0 31 2 *` is a
/// valid line that runs never, and so is anything a crond understands that this
/// does not. What it refuses is what would damage the file — a line break splits
/// one task into two — and what no crond accepts.
pub fn validate(schedule: &str, command: &str) -> Option<CronValidation> {
    let clean_schedule = schedule.trim();
    let clean_command = command.trim();
    if clean_schedule.is_empty() {
        return Some(CronValidation::ScheduleEmpty);
    }
    if clean_command.is_empty() {
        return Some(CronValidation::CommandEmpty);
    }
    if has_line_break(clean_schedule) || has_line_break(clean_command) {
        return Some(CronValidation::LineBreak);
    }
    if clean_schedule.starts_with('@') {
        // One token, no whitespace: `@reboot`, `@daily`. Anything longer is a
        // macro this app does not know, and `@daily 0 3 * * *` is not a line.
        if clean_schedule.split_whitespace().count() != 1 {
            return Some(CronValidation::Macro);
        }
        return None;
    }
    if clean_schedule.split_whitespace().count() != 5 {
        return Some(CronValidation::FieldCount);
    }
    None
}

fn has_line_break(value: &str) -> bool {
    value.contains('\n') || value.contains('\r') || value.contains('\0')
}

fn render_job(schedule: &str, command: &str, enabled: bool) -> String {
    let line = format!("{schedule} {command}");
    if enabled {
        line
    } else {
        format!("{DISABLED_PREFIX}{line}")
    }
}

fn parse_jobs(lines: &[String]) -> Vec<CronJob> {
    let mut jobs = Vec::new();
    for (index, line) in lines.iter().enumerate() {
        let mut candidate = line.trim_start();
        let mut enabled = true;
        if let Some(rest) = candidate.strip_prefix(DISABLED_PREFIX) {
            candidate = rest.trim_start();
            enabled = false;
        } else if candidate.is_empty() || candidate.starts_with('#') {
            continue;
        }
        let Some((schedule, command)) = parse_job_line(candidate) else {
            continue;
        };
        jobs.push(CronJob {
            line_index: index,
            schedule,
            command,
            enabled,
        });
    }
    jobs
}

/// Splits a line into its schedule and its command.
///
/// The command is taken as the rest of the line rather than a run of tokens:
/// a command is written the way the shell will read it, and `'a   b'` is not
/// the same command as `'a b'`. The schedule, by contrast, is five fields whose
/// own spacing means nothing, so it is rebuilt as single spaces.
fn parse_job_line(line: &str) -> Option<(String, String)> {
    // A macro is one token, then whitespace, then the command.
    if line.starts_with('@') {
        let end = line.find(char::is_whitespace)?;
        let command = line[end..].trim();
        if command.is_empty() {
            return None;
        }
        return Some((line[..end].to_owned(), command.to_owned()));
    }

    let mut rest = line;
    let mut fields: Vec<&str> = Vec::with_capacity(5);
    for _ in 0..5 {
        rest = rest.trim_start();
        if rest.is_empty() {
            return None;
        }
        let end = rest.find(char::is_whitespace).unwrap_or(rest.len());
        fields.push(&rest[..end]);
        rest = &rest[end..];
    }
    let command = rest.trim();
    if command.is_empty() {
        return None;
    }
    Some((fields.join(" "), command.to_owned()))
}

/// Whether `crontab -l` exiting 1 meant "this account has no crontab yet".
///
/// That is the state of every server before its first job, and it has to be an
/// empty document the user can add to, not an error. Each implementation says
/// it differently and all of them exit 1, the same as a real failure: vixie and
/// cronie print `no crontab for NAME`, BSD's prefixes it with `crontab: `, and
/// busybox's `-l` is a `cat` of the spool file, so Alpine and OpenWrt say
/// `crontab: can't open 'NAME': No such file or directory`. dcron prints the
/// first form but exits 0, so it never gets here. Anything else — the spool
/// directory missing, a permission refusal — is reported as what it said.
pub fn is_no_crontab(stderr: &str) -> bool {
    let line = stderr.trim().to_lowercase();
    if line.contains("no crontab for ") {
        return true;
    }
    line.starts_with("crontab: can't open '") && line.ends_with("no such file or directory")
}

/// A crontab and what the server said about itself when it was read.
#[derive(Debug, Clone, PartialEq, Eq)]
pub struct CronCatalog {
    pub user: String,
    pub document: CronDocument,
    pub clock: Option<CronClock>,
}

/// Reads [`LIST_SCRIPT`]'s stdout.
///
/// The header is the script's own, so a response without it is not one of ours
/// — a login banner or a shell that echoed something first would otherwise be
/// read as crontab content and then written back as such.
pub fn parse_list(output: &str) -> Result<CronCatalog, CronParseError> {
    let normalized = output.replace("\r\n", "\n").replace('\r', "\n");
    let body_marker = format!("{MARKER_BODY}\n");
    let body_start = normalized
        .find(&body_marker)
        .ok_or(CronParseError::InvalidResponse)?;
    let header = &normalized[..body_start];

    let user_line = header
        .split('\n')
        .find(|line| line.starts_with(MARKER_USER))
        .ok_or(CronParseError::NoUser)?;
    let user = user_line[MARKER_USER.len()..].trim();
    if user.is_empty() {
        return Err(CronParseError::NoUser);
    }

    let clock = header
        .split('\n')
        .find(|line| line.starts_with(MARKER_CLOCK))
        .and_then(|line| CronClock::try_parse(&line[MARKER_CLOCK.len()..]));

    let body = &normalized[body_start + body_marker.len()..];
    Ok(CronCatalog {
        user: user.to_owned(),
        document: CronDocument::parse(body),
        clock,
    })
}

#[cfg(test)]
mod tests {
    use super::*;

    fn catalog(body: &str) -> CronCatalog {
        parse_list(&format!(
            "SrvBoxCron.User\troot\nSrvBoxCron.Clock\t1789578763 +0800\nSrvBoxCron.Body\n{body}"
        ))
        .expect("parse")
    }

    #[test]
    fn header_carries_user_and_clock() {
        let parsed = catalog("0 3 * * * /usr/local/bin/backup.sh\n");
        assert_eq!(parsed.user, "root");
        let clock = parsed.clock.expect("clock");
        assert_eq!(clock.offset_minutes, 480);
        assert_eq!(clock.epoch, 1789578763);
    }

    #[test]
    fn a_date_without_percent_z_leaves_the_clock_unread() {
        // A `date` that does not know `%z` prints it back literally, which is
        // "nothing said" — not a listing that failed.
        let parsed = parse_list(
            "SrvBoxCron.User\troot\nSrvBoxCron.Clock\t1789578763 %z\nSrvBoxCron.Body\n",
        )
        .expect("parse");
        assert!(parsed.clock.is_none());
    }

    #[test]
    fn a_response_without_the_script_header_is_not_ours() {
        assert_eq!(
            parse_list("no crontab for root\n"),
            Err(CronParseError::InvalidResponse)
        );
    }

    #[test]
    fn an_empty_user_is_refused() {
        assert_eq!(
            parse_list("SrvBoxCron.User\t\nSrvBoxCron.Body\n"),
            Err(CronParseError::NoUser)
        );
    }

    #[test]
    fn jobs_carry_their_line_index_and_disabled_marker() {
        let parsed = catalog(concat!(
            "# managed by hand\n",
            "PATH=/usr/local/bin:/usr/bin\n",
            "0 3 * * * /usr/local/bin/backup.sh\n",
            "# ServerBox disabled: 30 4 * * * /usr/local/bin/other.sh\n",
        ));
        let jobs = parsed.document.jobs();
        assert_eq!(jobs.len(), 2);
        assert_eq!(jobs[0].line_index, 2);
        assert_eq!(jobs[0].schedule, "0 3 * * *");
        assert_eq!(jobs[0].command, "/usr/local/bin/backup.sh");
        assert!(jobs[0].enabled);
        assert_eq!(jobs[1].line_index, 3);
        assert_eq!(jobs[1].schedule, "30 4 * * *");
        assert!(!jobs[1].enabled);
        assert_eq!(
            parsed.document.preserved(),
            vec!["# managed by hand", "PATH=/usr/local/bin:/usr/bin"]
        );
    }

    #[test]
    fn unreadable_lines_are_preserved_rather_than_dropped() {
        // Every crond has syntax of its own; a line this cannot read is still a
        // line that must survive a save untouched.
        let parsed = catalog("0 3 * * * a\nCRON_TZ=Asia/Shanghai\n*/5 * * * * b\n");
        assert_eq!(parsed.document.jobs().len(), 2);
        assert_eq!(parsed.document.preserved(), vec!["CRON_TZ=Asia/Shanghai"]);
        assert_eq!(
            parsed.document.render(),
            "0 3 * * * a\nCRON_TZ=Asia/Shanghai\n*/5 * * * * b\n"
        );
    }

    #[test]
    fn a_macro_line_is_a_job() {
        let parsed = catalog("@reboot /usr/local/bin/once.sh\n");
        let jobs = parsed.document.jobs();
        assert_eq!(jobs.len(), 1);
        assert_eq!(jobs[0].schedule, "@reboot");
        assert_eq!(jobs[0].command, "/usr/local/bin/once.sh");
        assert!(jobs[0].parsed().expect("macro").is_reboot);
    }

    #[test]
    fn a_command_keeps_its_internal_spacing() {
        let parsed = catalog("0 3 * * * /bin/sh -c 'a   b'\n");
        assert_eq!(parsed.document.jobs()[0].command, "/bin/sh -c 'a   b'");
    }

    #[test]
    fn render_gives_the_document_back_byte_for_byte() {
        assert_eq!(CronDocument::parse("").render(), "");
        assert_eq!(CronDocument::parse("0 3 * * * a").render(), "0 3 * * * a\n");
        // A blank line at the end is part of the file, and only the one the
        // split produced is dropped when the file already ends in a newline.
        assert_eq!(
            CronDocument::parse("0 3 * * * a\n\n").render(),
            "0 3 * * * a\n\n"
        );
        for document in [
            "# a\n\n0 3 * * * a\n",
            "0 3 * * * a\n\n\n",
            " \n0 3 * * * a\n",
        ] {
            assert_eq!(CronDocument::parse(document).render(), document);
        }
    }

    #[test]
    fn upsert_appends_or_replaces_by_line_index() {
        let document = CronDocument::parse("# keep\n0 3 * * * a\n");
        let appended = document.upsert(None, "*/5 * * * *", "b", true).expect("append");
        assert_eq!(appended.render(), "# keep\n0 3 * * * a\n*/5 * * * * b\n");

        let replaced = document
            .upsert(Some(1), "30 4 * * *", "c", true)
            .expect("replace");
        assert_eq!(replaced.render(), "# keep\n30 4 * * * c\n");
        assert_eq!(replaced.jobs()[0].line_index, 1);
    }

    #[test]
    fn disable_writes_the_marker_and_keeps_the_line_readable() {
        let document = CronDocument::parse("0 3 * * * a\n");
        let disabled = document.set_enabled(0, false).expect("disable");
        assert_eq!(disabled.render(), "# ServerBox disabled: 0 3 * * * a\n");
        let job = &disabled.jobs()[0];
        assert!(!job.enabled);
        assert_eq!(job.schedule, "0 3 * * *");
        assert_eq!(job.command, "a");
        let re_enabled = disabled.set_enabled(0, true).expect("enable");
        assert_eq!(re_enabled.render(), "0 3 * * * a\n");
    }

    #[test]
    fn remove_takes_the_line_out() {
        let document = CronDocument::parse("# keep\n0 3 * * * a\n");
        assert_eq!(document.remove(1).expect("remove").render(), "# keep\n");
    }

    /// An edit addresses a job by its index in a listing the client was given.
    /// An index that is out of range, or that has come to hold a comment, is a
    /// listing that moved — applying the edit anyway would rewrite a line the
    /// client never saw, and the answer is "read it again", not "your
    /// expression is wrong".
    #[test]
    fn an_edit_naming_a_line_that_is_not_a_job_is_refused() {
        let document = CronDocument::parse("# keep\n0 3 * * * a\n");
        // In range, but a comment.
        assert_eq!(document.remove(0), Err(CronValidation::UnknownLine));
        assert_eq!(
            document.upsert(Some(0), "0 4 * * *", "b", true),
            Err(CronValidation::UnknownLine)
        );
        assert_eq!(document.set_enabled(0, false), Err(CronValidation::UnknownLine));
        // Out of range.
        assert_eq!(document.remove(9), Err(CronValidation::UnknownLine));
        assert_eq!(
            document.upsert(Some(9), "0 4 * * *", "b", true),
            Err(CronValidation::UnknownLine)
        );
        // What the client should have sent, for contrast.
        assert!(document.upsert(Some(1), "0 4 * * *", "b", true).is_ok());
    }

    #[test]
    fn a_line_break_is_refused_because_it_splits_one_task_into_two() {
        assert_eq!(
            validate("0 3 * * *", "a\nb"),
            Some(CronValidation::LineBreak)
        );
        assert_eq!(
            validate("0 3\n* * *", "a"),
            Some(CronValidation::LineBreak)
        );
        assert_eq!(
            CronDocument::parse("")
                .upsert(None, "0 3 * * *", "a\nrm -rf /", true),
            Err(CronValidation::LineBreak)
        );
    }

    #[test]
    fn validation_refuses_only_what_would_damage_the_file() {
        assert_eq!(
            validate("  ", "a"),
            Some(CronValidation::ScheduleEmpty)
        );
        assert_eq!(validate("* * * * *", "  "), Some(CronValidation::CommandEmpty));
        // Valid, and runs never: not this function's business.
        assert_eq!(validate("0 0 31 2 *", "a"), None);
        // Five fields, or one macro token.
        assert_eq!(validate("* * * *", "a"), Some(CronValidation::FieldCount));
        assert_eq!(validate("* * * * * *", "a"), Some(CronValidation::FieldCount));
        assert_eq!(validate("@daily", "a"), None);
        assert_eq!(validate("@every 5m", "a"), Some(CronValidation::Macro));
    }

    #[test]
    fn a_disabled_line_with_an_unescaped_command_is_still_read() {
        // The marker is the whole of the state; nothing else about the line
        // changes when it is disabled.
        let document = CronDocument::parse("# ServerBox disabled:   */5 * * * *   spaced   cmd\n");
        let job = &document.jobs()[0];
        assert!(!job.enabled);
        assert_eq!(job.schedule, "*/5 * * * *");
        assert_eq!(job.command, "spaced   cmd");
    }

    #[test]
    fn no_crontab_is_read_from_every_implementation() {
        assert!(is_no_crontab("no crontab for root\n"));
        assert!(is_no_crontab("crontab: no crontab for lk\n"));
        assert!(is_no_crontab(
            "crontab: can't open 'root': No such file or directory\n"
        ));
        // A real failure is not an empty crontab.
        assert!(!is_no_crontab("crontab: must be suid to work properly\n"));
        assert!(!is_no_crontab(""));
    }

    #[test]
    fn expansion_reads_the_fields() {
        let schedule = CronSchedule::try_parse("0 3 * * *").expect("parse");
        assert_eq!(schedule.minutes, vec![0]);
        assert_eq!(schedule.hours, vec![3]);
        assert_eq!(schedule.days_of_month.len(), 31);
        assert_eq!(schedule.months.len(), 12);
        assert_eq!(schedule.days_of_week.len(), 7);
        assert!(!schedule.day_of_month_restricted);
        assert!(!schedule.day_of_week_restricted);
    }

    #[test]
    fn expansion_reads_steps_lists_ranges_and_names() {
        assert_eq!(
            CronSchedule::try_parse("*/15 * * * *").expect("parse").minutes,
            vec![0, 15, 30, 45]
        );
        assert_eq!(
            CronSchedule::try_parse("0 1,3,5 * * *").expect("parse").hours,
            vec![1, 3, 5]
        );
        assert_eq!(
            CronSchedule::try_parse("0 9-17 * * *").expect("parse").hours,
            (9..=17).collect::<Vec<u32>>()
        );
        assert_eq!(
            CronSchedule::try_parse("0 0 * jan *").expect("parse").months,
            vec![1]
        );
        assert_eq!(
            CronSchedule::try_parse("0 0 * * mon-fri").expect("parse").days_of_week,
            vec![1, 2, 3, 4, 5]
        );
        // A `7` written in the day field is Sunday, which is 0.
        assert_eq!(
            CronSchedule::try_parse("0 0 * * 7").expect("parse").days_of_week,
            vec![0]
        );
        // `5/10` is the rest of the field from 5 on.
        assert_eq!(
            CronSchedule::try_parse("5/10 * * * *").expect("parse").minutes,
            vec![5, 15, 25, 35, 45, 55]
        );
    }

    #[test]
    fn expansion_refuses_what_it_cannot_read() {
        assert!(CronSchedule::try_parse("").is_none());
        assert!(CronSchedule::try_parse("0 3 * *").is_none());
        assert!(CronSchedule::try_parse("0 3 * * * *").is_none());
        assert!(CronSchedule::try_parse("60 3 * * *").is_none());
        assert!(CronSchedule::try_parse("0 24 * * *").is_none());
        assert!(CronSchedule::try_parse("0 0 0 * *").is_none());
        assert!(CronSchedule::try_parse("0 0 * 13 *").is_none());
        assert!(CronSchedule::try_parse("0 0 * * 8").is_none());
        assert!(CronSchedule::try_parse("@every 5m").is_none());
        // A descending range is answered by nobody in particular, so it is
        // refused rather than read as a wrap.
        assert!(CronSchedule::try_parse("0 0 * * fri-mon").is_none());
    }

    #[test]
    fn macros_expand_and_reboot_has_no_expansion() {
        assert_eq!(
            CronSchedule::try_parse("@daily").expect("parse").minutes,
            vec![0]
        );
        let hourly = CronSchedule::try_parse("@hourly").expect("parse");
        assert_eq!(hourly.minutes, vec![0]);
        assert_eq!(hourly.hours.len(), 24);
        assert!(CronSchedule::try_parse("@reboot").expect("parse").is_reboot);
        // Case is not part of the spelling.
        assert!(CronSchedule::try_parse("@DAILY").is_some());
    }

    #[test]
    fn a_date_and_day_that_are_both_restricted_match_on_either() {
        // `0 0 13 * 5` is the 13th of the month and every Friday, not Friday
        // the 13th.
        let schedule = CronSchedule::try_parse("0 0 13 * 5").expect("parse");
        assert!(schedule.day_of_month_restricted);
        assert!(schedule.day_of_week_restricted);
        // 2026-11-13 is a Friday and the 13th; 2026-11-06 is a Friday only.
        assert!(schedule.matches_date(&CivilTime::new(2026, 11, 13, 0, 0)));
        assert!(schedule.matches_date(&CivilTime::new(2026, 11, 6, 0, 0)));
        assert!(!schedule.matches_date(&CivilTime::new(2026, 11, 12, 0, 0)));
    }

    #[test]
    fn the_next_run_is_strictly_after_the_current_minute() {
        let schedule = CronSchedule::try_parse("0 3 * * *").expect("parse");
        // At 03:00 the job has already run this minute.
        assert_eq!(
            schedule.next_run(CivilTime::new(2026, 9, 24, 3, 0)),
            Some(CivilTime::new(2026, 9, 25, 3, 0))
        );
        assert_eq!(
            schedule.next_run(CivilTime::new(2026, 9, 24, 2, 59)),
            Some(CivilTime::new(2026, 9, 24, 3, 0))
        );
    }

    #[test]
    fn the_next_run_crosses_months_and_years() {
        let monthly = CronSchedule::try_parse("0 0 1 * *").expect("parse");
        assert_eq!(
            monthly.next_run(CivilTime::new(2026, 12, 15, 10, 0)),
            Some(CivilTime::new(2027, 1, 1, 0, 0))
        );
        let yearly = CronSchedule::try_parse("0 0 1 1 *").expect("parse");
        assert_eq!(
            yearly.next_run(CivilTime::new(2026, 9, 24, 0, 0)),
            Some(CivilTime::new(2027, 1, 1, 0, 0))
        );
    }

    #[test]
    fn the_next_run_of_a_leap_day_is_four_years_out() {
        // The search window is years rather than days for exactly this.
        let schedule = CronSchedule::try_parse("0 0 29 2 *").expect("parse");
        assert_eq!(
            schedule.next_run(CivilTime::new(2026, 9, 24, 0, 0)),
            Some(CivilTime::new(2028, 2, 29, 0, 0))
        );
        // 2100 is not a leap year, so 2096 is followed by 2104.
        assert_eq!(
            schedule.next_run(CivilTime::new(2096, 3, 1, 0, 0)),
            Some(CivilTime::new(2104, 2, 29, 0, 0))
        );
    }

    #[test]
    fn a_reboot_job_has_no_next_run() {
        let schedule = CronSchedule::try_parse("@reboot").expect("parse");
        assert_eq!(schedule.next_run(CivilTime::new(2026, 9, 24, 0, 0)), None);
    }

    #[test]
    fn what_never_fires_is_answered_as_never() {
        // Valid, matches nothing: answering `None` is right, and the search
        // window is bounded so it terminates.
        let schedule = CronSchedule::try_parse("0 0 30 2 *").expect("parse");
        assert_eq!(schedule.next_run(CivilTime::new(2026, 9, 24, 0, 0)), None);
    }

    #[test]
    fn a_day_of_month_restricted_schedule_matches_its_day() {
        let schedule = CronSchedule::try_parse("0 0 1 * *").expect("parse");
        assert!(schedule.matches_date(&CivilTime::new(2026, 11, 1, 0, 0)));
        assert!(!schedule.matches_date(&CivilTime::new(2026, 11, 2, 0, 0)));
    }

    #[test]
    fn the_civil_calendar_round_trips_against_known_dates() {
        for (y, m, d, days) in [
            (1970, 1, 1, 0),
            (1970, 1, 2, 1),
            (2000, 3, 1, 11017),
            (2024, 2, 29, 19782),
            (2026, 9, 24, 20720),
            (2100, 3, 1, 47541),
        ] {
            assert_eq!(days_from_civil(y, m, d), days, "{y}-{m}-{d}");
            assert_eq!(civil_from_days(days), (y, m, d), "{y}-{m}-{d}");
        }
    }

    #[test]
    fn weekday_matches_the_calendar() {
        // 1970-01-01 was a Thursday; cron counts Sunday as 0.
        assert_eq!(CivilTime::new(1970, 1, 1, 0, 0).weekday(), 4);
        assert_eq!(CivilTime::new(2026, 9, 24, 0, 0).weekday(), 4);
        assert_eq!(CivilTime::new(2024, 1, 7, 0, 0).weekday(), 0);
    }

    #[test]
    fn a_job_view_carries_what_a_client_draws_it_from() {
        let parsed = catalog("0 3 * * * /backup.sh\n");
        let job = &parsed.document.jobs()[0];
        let now = parsed.clock.expect("clock").now_wall();
        let view = job.view(Some(now));
        assert!(view.parsed);
        assert!(!view.is_reboot);
        assert_eq!(view.minutes, vec![0]);
        assert_eq!(view.hours, vec![3]);
        assert_eq!(view.next_run.as_deref().map(|s| s.len()), Some(16));

        // Without a clock there is no next run, and everything else stays.
        let bare = job.view(None);
        assert!(bare.next_run.is_none());
        assert_eq!(bare.minutes, vec![0]);

        // An unreadable schedule keeps the line and reports no expansion.
        // `L` is a real crond's "last day of the month", which this does not
        // read; the row still has to be shown, and saved back untouched.
        let odd = catalog("0 0 L * * /odd.sh\n");
        let view = odd.document.jobs()[0].view(None);
        assert!(!view.parsed);
        assert!(view.minutes.is_empty());
        assert_eq!(view.schedule, "0 0 L * *");
        assert_eq!(view.command, "/odd.sh");
    }

    /// The JSON key set, which is the other half of this type's contract.
    ///
    /// Every client reads these names across a boundary nothing type-checks —
    /// the panel's TypeScript interface, and the app's Dart mirror once it is
    /// migrated. A field renamed here would compile on both sides and arrive
    /// as `undefined` there, so the names are asserted rather than assumed.
    #[test]
    fn the_json_key_set_is_what_the_clients_read() {
        let parsed = catalog("0 3 * * * /backup.sh\n");
        let now = parsed.clock.expect("clock").now_wall();
        let view = parsed.document.jobs()[0].view(Some(now));
        let value = serde_json::to_value(&view).expect("serialize");
        let mut keys: Vec<&str> = value
            .as_object()
            .expect("an object")
            .keys()
            .map(String::as_str)
            .collect();
        keys.sort_unstable();
        assert_eq!(
            keys,
            vec![
                "command",
                "day_of_month_restricted",
                "day_of_week_restricted",
                "days_of_month",
                "days_of_week",
                "enabled",
                "hours",
                "is_reboot",
                "line_index",
                "minutes",
                "months",
                "next_run",
                "parsed",
                "schedule",
            ]
        );
        // `next_run` is answered as `null` rather than left out: an omitted key
        // and a null one reach a client as the same thing, so omitting it would
        // make the shape depend on the value and tell nobody anything.
        assert!(value["next_run"].is_string());
        assert!(serde_json::to_value(parsed.document.jobs()[0].view(None)).expect("serialize")
            ["next_run"]
            .is_null());
    }

    #[test]
    fn the_clock_reports_the_servers_wall_time() {
        // 1789578763 = 2026-09-16T17:12:43Z.
        let clock = CronClock::try_parse("1789578763 +0800").expect("parse");
        assert_eq!(clock.now_wall(), CivilTime::new(2026, 9, 17, 1, 12));
        let west = CronClock::try_parse("1789578763 -0430").expect("parse");
        assert_eq!(west.now_wall(), CivilTime::new(2026, 9, 16, 12, 42));
    }

    #[test]
    fn a_clock_that_is_not_a_clock_is_nothing_said() {
        for value in ["", "1789578763", "1789578763 +08", "abc +0800", "1 +08:00"] {
            assert!(CronClock::try_parse(value).is_none(), "{value}");
        }
    }
}
