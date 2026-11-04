//! Process table FFI (sbm_parser::proc)
//!
//! The rows, columns, orders and stop commands the monitor agent's panel
//! reads, for the app's process page. The app runs the process function and
//! the stop command over its own connection; what they print is read here.
//! A reading is `sbm_parser::proc::PsView`, mirrored, and goes back as the
//! next reading's `previous` (what its read/write speeds are differenced
//! against) or to be ordered again.

use flutter_rust_bridge::frb;
use sbm_parser::proc;
pub use sbm_parser::proc::{
    Proc, ProcColumns, ProcKillOutcome, ProcLoad, ProcRow, ProcSignal, ProcSortMode, PsParseFailure, PsParseIssue, PsResult, PsView,
};

use super::parser::parse_system_or_err;

// --- Mirrors -----------------------------------------------------------------

#[frb(mirror(Proc))]
pub struct _Proc {
    pub user: Option<String>,
    pub pid: i64,
    pub ppid: Option<i64>,
    pub cpu: Option<f64>,
    pub mem: Option<f64>,
    pub vsz: Option<String>,
    pub rss: Option<String>,
    pub tty: Option<String>,
    pub stat: Option<String>,
    pub nice: Option<i64>,
    pub threads: Option<i64>,
    pub start: Option<String>,
    pub start_id: Option<String>,
    pub time: Option<String>,
    pub elapsed_seconds: Option<i64>,
    pub read_bytes: Option<i64>,
    pub write_bytes: Option<i64>,
    pub read_speed: Option<f64>,
    pub write_speed: Option<f64>,
    pub command: String,
    pub process_name: Option<String>,
}

#[frb(mirror(ProcLoad))]
pub struct _ProcLoad {
    pub one: f64,
    pub five: f64,
    pub fifteen: f64,
}

#[frb(mirror(PsParseFailure))]
pub enum _PsParseFailure {
    UnsupportedOutput,
    InvalidRows,
    InvalidWindowsJson,
    InvalidWindowsRows,
}

#[frb(mirror(PsParseIssue))]
pub struct _PsParseIssue {
    pub failure: PsParseFailure,
    pub diagnostics: String,
}

#[frb(mirror(ProcSortMode))]
pub enum _ProcSortMode {
    Cpu,
    Mem,
    Rss,
    Read,
    Write,
    Pid,
    User,
    Name,
}

#[frb(mirror(ProcSignal))]
pub enum _ProcSignal {
    Term,
    Kill,
}

#[frb(mirror(ProcKillOutcome))]
pub enum _ProcKillOutcome {
    Succeeded,
    TargetChanged,
    Denied,
    Failed,
}

#[frb(mirror(ProcRow))]
pub struct _ProcRow {
    pub proc: Proc,
    pub name: String,
    pub rss_kb: Option<i64>,
    pub is_kernel_thread: bool,
    pub killable: bool,
}

#[frb(mirror(ProcColumns))]
pub struct _ProcColumns {
    pub user: bool,
    pub cpu: bool,
    pub mem: bool,
    pub rss: bool,
    pub read: bool,
    pub write: bool,
    pub read_speed: bool,
    pub write_speed: bool,
}

#[frb(mirror(PsView))]
pub struct _PsView {
    pub procs: Vec<ProcRow>,
    pub issue: Option<PsParseIssue>,
    pub load: Option<ProcLoad>,
    pub sampled_at_millis: i64,
    pub columns: ProcColumns,
    pub sorts: Vec<ProcSortMode>,
    pub sort: ProcSortMode,
    pub ascending: bool,
    pub signals: Vec<ProcSignal>,
}

/// The reading a view was made from: what a later one differences against.
fn result_of(view: PsView) -> PsResult {
    PsResult {
        procs: view.procs.into_iter().map(|r| r.proc).collect(),
        issue: view.issue,
        sampled_at_millis: view.sampled_at_millis,
        load: view.load,
    }
}

// --- Functions ---------------------------------------------------------------

/// What the process function printed, ordered by `sort` where the table can
/// answer it. `previous` is the last reading that parsed cleanly, as this
/// returned it; `sampled_at_millis` is when `raw` was produced.
pub fn proc_view(
    raw: String,
    system: String,
    sort: Option<ProcSortMode>,
    ascending: Option<bool>,
    previous: Option<PsView>,
    sampled_at_millis: i64,
) -> Result<PsView, String> {
    let system = parse_system_or_err(&system)?;
    let previous = previous.map(result_of);
    let result = PsResult::parse(&raw, sort.unwrap_or(ProcSortMode::Cpu), ascending, previous.as_ref(), sampled_at_millis);
    Ok(PsView::of(&result, system, sort, ascending))
}

/// A reading [`proc_view`] returned, ordered again.
pub fn proc_sorted(view: PsView, system: String, sort: Option<ProcSortMode>, ascending: Option<bool>) -> Result<PsView, String> {
    let system = parse_system_or_err(&system)?;
    Ok(PsView::of(&result_of(view), system, sort, ascending))
}

/// The command that sends `signal` to `pid` once its start identity is still
/// `start_id`, or `None` where the platform cannot check it. What it prints
/// is read by [`proc_kill_outcome`].
#[frb(sync)]
pub fn proc_kill_command(pid: i64, start_id: Option<String>, system: String, signal: ProcSignal) -> Result<Option<String>, String> {
    let system = parse_system_or_err(&system)?;
    Ok(proc::kill_command(pid, start_id.as_deref(), system, signal))
}

/// What a stop printed.
#[frb(sync)]
pub fn proc_kill_outcome(output: String) -> ProcKillOutcome {
    proc::kill_outcome(&output)
}
