//! Scheduled tasks FFI (sbm_parser::cron)
//!
//! The account's own crontab, by the rules the monitor agent's panel uses: the
//! listing script and how its output is read, the document and its edits, and
//! the expansion of an expression and its next run. The app runs the scripts
//! over its own connection; the wording of a schedule and the arithmetic
//! between the server's clock and the device's stay with it.
//!
//! A document crosses as its lines. An edit takes them back and answers the
//! whole new document, so the app never splits, joins or rewrites a line
//! itself.

use sbm_parser::cron::{self, CivilTime, CronDocument, CronFailure, CronSchedule, CronValidation};

/// One job in a document. `line_index` is what an edit names it by.
pub struct CronJobLine {
    pub line_index: u32,
    pub schedule: String,
    pub command: String,
    pub enabled: bool,
}

/// A crontab: every line, the jobs read out of them, the lines that are not
/// jobs (shown so a crontab another tool manages does not look like it lost
/// them), and the text that writes it back.
pub struct CronDocumentData {
    pub lines: Vec<String>,
    pub jobs: Vec<CronJobLine>,
    pub preserved: Vec<String>,
    pub text: String,
}

/// What the server's `date +'%s %z'` said when the listing was read.
pub struct CronServerClock {
    pub epoch_seconds: i64,
    /// Minutes east of UTC.
    pub offset_minutes: i32,
}

pub struct CronListing {
    pub user: String,
    pub document: CronDocumentData,
    /// `None` when the server's `date` could not say.
    pub clock: Option<CronServerClock>,
}

/// A listing or a save the machine refused.
#[derive(Debug, Clone)]
pub struct CronFfiError {
    /// `crontab` is not installed at all.
    pub not_installed: bool,
    /// What the machine said, or why its output was not read.
    pub detail: Option<String>,
}

impl From<CronFailure> for CronFfiError {
    fn from(failure: CronFailure) -> Self {
        Self {
            not_installed: failure.not_installed,
            detail: failure.detail,
        }
    }
}

/// An edit refused. `code` is `sbm_parser::cron::CronValidation`'s
/// (`scheduleEmpty`, `commandEmpty`, `lineBreak`, `macro`, `fieldCount`,
/// `unknownLine`).
#[derive(Debug, Clone)]
pub struct CronEditError {
    pub code: String,
}

impl From<CronValidation> for CronEditError {
    fn from(validation: CronValidation) -> Self {
        Self {
            code: validation.to_string(),
        }
    }
}

/// An expression expanded. Day of week counts Sunday as `0`.
pub struct CronScheduleFields {
    pub minutes: Vec<u32>,
    pub hours: Vec<u32>,
    pub days_of_month: Vec<u32>,
    pub months: Vec<u32>,
    pub days_of_week: Vec<u32>,
    pub day_of_month_restricted: bool,
    pub day_of_week_restricted: bool,
    pub is_reboot: bool,
}

/// A time on the server's wall clock, the fields a crontab line is written in.
pub struct CronWall {
    pub year: i32,
    pub month: u32,
    pub day: u32,
    pub hour: u32,
    pub minute: u32,
}

fn document(document: &CronDocument) -> CronDocumentData {
    CronDocumentData {
        lines: document.lines.clone(),
        jobs: document
            .jobs()
            .iter()
            .map(|job| CronJobLine {
                line_index: job.line_index as u32,
                schedule: job.schedule.clone(),
                command: job.command.clone(),
                enabled: job.enabled,
            })
            .collect(),
        preserved: document.preserved().into_iter().map(str::to_owned).collect(),
        text: document.render(),
    }
}

/// POSIX `sh`, for `ServerExec.run(script, entry: 'sh')`.
#[flutter_rust_bridge::frb(sync)]
pub fn cron_list_script() -> String {
    cron::LIST_SCRIPT.to_owned()
}

/// Takes the document on stdin. A single command: no entry.
#[flutter_rust_bridge::frb(sync)]
pub fn cron_save_command() -> String {
    cron::SAVE_COMMAND.to_owned()
}

/// What [`cron_list_script`] produced. `succeeded` is the app's own verdict on
/// the run, which also knows about a broken stream.
#[flutter_rust_bridge::frb(sync)]
pub fn cron_read_listing(stdout: String, stderr: String, exit_code: Option<i32>, succeeded: bool) -> Result<CronListing, CronFfiError> {
    let catalog = cron::read_listing(&stdout, &stderr, exit_code, succeeded)?;
    Ok(CronListing {
        user: catalog.user,
        document: document(&catalog.document),
        clock: catalog.clock.map(|clock| CronServerClock {
            epoch_seconds: clock.epoch,
            offset_minutes: clock.offset_minutes,
        }),
    })
}

/// Whether [`cron_save_command`] took the document.
#[flutter_rust_bridge::frb(sync)]
pub fn cron_check_save(stdout: String, stderr: String, exit_code: Option<i32>, succeeded: bool) -> Result<(), CronFfiError> {
    Ok(cron::check_save(&stdout, &stderr, exit_code, succeeded)?)
}

/// Replaces the job at `line_index` in `lines`, or appends one when it is
/// `None`.
#[flutter_rust_bridge::frb(sync)]
pub fn cron_upsert(lines: Vec<String>, line_index: Option<u32>, schedule: String, command: String, enabled: bool) -> Result<CronDocumentData, CronEditError> {
    let next = CronDocument::from_lines(lines).upsert(line_index.map(|i| i as usize), &schedule, &command, enabled)?;
    Ok(document(&next))
}

#[flutter_rust_bridge::frb(sync)]
pub fn cron_remove(lines: Vec<String>, line_index: u32) -> Result<CronDocumentData, CronEditError> {
    Ok(document(&CronDocument::from_lines(lines).remove(line_index as usize)?))
}

#[flutter_rust_bridge::frb(sync)]
pub fn cron_set_enabled(lines: Vec<String>, line_index: u32, enabled: bool) -> Result<CronDocumentData, CronEditError> {
    Ok(document(&CronDocument::from_lines(lines).set_enabled(line_index as usize, enabled)?))
}

/// What is wrong with the line these would make, as a
/// [`CronEditError::code`], or `None`.
#[flutter_rust_bridge::frb(sync)]
pub fn cron_validate(schedule: String, command: String) -> Option<String> {
    cron::validate(&schedule, &command).map(|validation| validation.to_string())
}

/// `None` for an expression this does not read; the app shows it as written.
#[flutter_rust_bridge::frb(sync)]
pub fn cron_schedule_parse(expression: String) -> Option<CronScheduleFields> {
    CronSchedule::try_parse(&expression).map(|s| CronScheduleFields {
        minutes: s.minutes,
        hours: s.hours,
        days_of_month: s.days_of_month,
        months: s.months,
        days_of_week: s.days_of_week,
        day_of_month_restricted: s.day_of_month_restricted,
        day_of_week_restricted: s.day_of_week_restricted,
        is_reboot: s.is_reboot,
    })
}

/// The next minute `expression` runs, strictly after `from`; both on the
/// server's wall clock. `None` when it has none or is not read.
#[flutter_rust_bridge::frb(sync)]
pub fn cron_next_run(expression: String, from: CronWall) -> Option<CronWall> {
    let from = CivilTime::new(from.year, from.month, from.day, from.hour, from.minute);
    CronSchedule::try_parse(&expression)?.next_run(from).map(|at| CronWall {
        year: at.year,
        month: at.month,
        day: at.day,
        hour: at.hour,
        minute: at.minute,
    })
}
