//! The process table of a machine, and the signal that stops one process.
//!
//! The table is [`ShellFunc::Process`] read by [`PsResult::parse`]: by column
//! name where the platform printed a header and by position where it did not,
//! and which columns exist decides which orders and columns a client offers.
//! The stop is a script that checks the PID's start identity before
//! signalling it, with a `sudo` retry for a process this account does not
//! own. Both are [`sbm_parser::proc`]'s.
//!
//! A read/write speed is a difference against an earlier reading, which the
//! caller keeps and hands back as the baseline: the monitor between requests,
//! a page for as long as it is open.

use serde::{Deserialize, Serialize};

use super::{Machine, Ran, Run, Stage, change, now_millis, shell};
use sbm_parser::SystemType;
use sbm_parser::proc::{
    ProcColumns, ProcKillOutcome, ProcLoad, ProcRow, ProcSignal, ProcSortMode, PsParseIssue, PsResult,
};
use sbm_parser::script::ShellFunc;

/// One row per process, and a busy host has thousands: at least this much of
/// the table is read — 1 MiB is exceeded by a few thousand processes, and
/// going over costs the reader the whole page.
const MIN_TABLE_BYTES: usize = 8 * 1024 * 1024;

#[derive(Debug, Serialize)]
pub struct ProcessResponse {
    /// Whether the machine gave a table at all. `false` is a state of the
    /// machine, not a failure of the caller.
    available: bool,
    /// Which of the known reasons it was. `None` alongside `available: false`
    /// means the machine said something not classified here, and `reason` is it.
    reason_kind: Option<ProcessReason>,
    /// What the machine said, verbatim.
    reason: Option<String>,
    procs: Vec<ProcRow>,
    /// Rows the parser had to drop; the rest of the table is still here.
    issue: Option<PsParseIssue>,
    /// The 1, 5 and 15 minute load averages, where the machine reports them.
    load: Option<ProcLoad>,
    /// The instant this reading was taken, in Unix milliseconds.
    sampled_at_millis: i64,
    /// Which columns the machine reported, which is what a client draws.
    columns: ProcColumns,
    /// The orders this table can answer, in the order a client draws them.
    sorts: Vec<ProcSortMode>,
    /// What this answer is ordered by, after the fallbacks.
    sort: Option<ProcSortMode>,
    ascending: Option<bool>,
    /// The signals this platform offers, empty where it has none implemented.
    signals: Vec<ProcSignal>,
}

#[derive(Debug, Clone, Copy, PartialEq, Eq, Serialize)]
#[serde(rename_all = "snake_case")]
pub enum ProcessReason {
    /// The command was stopped at its time limit, or could not be started.
    DidNotFinish,
    /// It printed more than is read — tens of thousands of processes.
    TooLarge,
    /// It ran and printed nothing.
    Empty,
}

/// A fresh reading, its speeds differenced against [baseline]; or, when the
/// machine gave none, the answer that says why.
pub async fn read(m: &dyn Machine, baseline: Option<&PsResult>) -> Result<PsResult, Box<ProcessResponse>> {
    let system = m.system();
    let out = match m.run(Run::Script(ShellFunc::Process), MIN_TABLE_BYTES).await {
        Ok(out) => out,
        Err(error) => return Err(Box::new(unavailable(system, ProcessReason::DidNotFinish, Some(error)))),
    };
    if out.timed_out {
        return Err(Box::new(unavailable(system, ProcessReason::DidNotFinish, None)));
    }
    if out.truncated {
        return Err(Box::new(unavailable(system, ProcessReason::TooLarge, None)));
    }
    if out.stdout.trim().is_empty() {
        // What the machine said is the whole answer: `ps` missing from a
        // minimal image prints to stderr.
        let reason = out.stderr.trim();
        return Err(Box::new(unavailable(system, ProcessReason::Empty, (!reason.is_empty()).then(|| reason.to_owned()))));
    }
    Ok(PsResult::parse(&out.stdout, ProcSortMode::Cpu, Some(false), baseline, now_millis()))
}

/// The table, in the order asked for where it can answer it.
pub async fn table(m: &dyn Machine, sort: Option<ProcSortMode>, ascending: Option<bool>) -> ProcessResponse {
    match read(m, None).await {
        Ok(result) => {
            let (sort, ascending) = resolve_sort(&result, sort, ascending);
            respond(&result.sorted_by(sort, Some(ascending)), m.system(), Some(sort), Some(ascending))
        }
        Err(response) => *response,
    }
}

/// Which of what the caller asked for this table can answer: a mode whose
/// column the machine never filled would order the whole table by nulls.
pub fn resolve_sort(result: &PsResult, sort: Option<ProcSortMode>, ascending: Option<bool>) -> (ProcSortMode, bool) {
    ProcColumns::of(&result.procs).resolve(sort, ascending)
}

/// The body for a machine that gave no table, or none this build could read.
fn unavailable(system: SystemType, kind: ProcessReason, reason: Option<String>) -> ProcessResponse {
    ProcessResponse {
        available: false,
        reason_kind: Some(kind),
        reason,
        procs: Vec::new(),
        issue: None,
        load: None,
        sampled_at_millis: now_millis(),
        columns: ProcColumns::default(),
        sorts: Vec::new(),
        sort: None,
        ascending: None,
        signals: sbm_parser::proc::signals_for(system).to_vec(),
    }
}

/// The body for a table that was read.
pub fn respond(
    result: &PsResult,
    system: SystemType,
    sort: Option<ProcSortMode>,
    ascending: Option<bool>,
) -> ProcessResponse {
    let columns = ProcColumns::of(&result.procs);
    ProcessResponse {
        available: true,
        reason_kind: None,
        reason: None,
        procs: result.procs.iter().map(|proc| ProcRow::of(proc, system)).collect(),
        issue: result.issue.clone(),
        load: result.load,
        sampled_at_millis: result.sampled_at_millis,
        sorts: columns.sorts(),
        columns,
        sort,
        ascending,
        signals: sbm_parser::proc::signals_for(system).to_vec(),
    }
}

/// What stops one process.
#[derive(Debug, Deserialize)]
pub struct KillRequest {
    pub pid: i64,
    /// The identity the listing reported for that PID, checked against the
    /// process's own start time before the signal is sent. A number the kernel
    /// has since handed to something else is refused rather than signalled.
    #[serde(default)]
    pub start_id: Option<String>,
    pub signal: ProcSignal,
    /// For `sudo`, when the process belongs to another account. Never logged,
    /// and never written into a command line.
    #[serde(default)]
    pub password: Option<String>,
}

#[derive(Debug, Serialize)]
pub struct KillResponse {
    /// What happened: `denied` is a process this account does not own,
    /// `target_changed` a table that has moved on.
    outcome: ProcKillOutcome,
    exit_code: Option<i32>,
    /// The machine's own words, both streams.
    stdout: String,
    stderr: String,
    /// `sudo` refused the password that was sent, or was not given one.
    sudo_rejected: bool,
}

/// Why a process was not signalled.
#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum StopRefused {
    /// No way to check the PID before signalling it: a platform without the
    /// script, or a row the machine gave no start identity for.
    Unsafe,
}

/// Signals one process, recording it.
pub async fn stop(m: &dyn Machine, request: KillRequest) -> Result<KillResponse, StopRefused> {
    let what = format!("process stop {} {}", request.signal.name(), request.pid);
    let system = m.system();
    let Some(text) = sbm_parser::proc::kill_command(request.pid, request.start_id.as_deref(), system, request.signal)
    else {
        change(m, Stage::Refused, &what, Some("no way to stop this process safely")).await;
        return Err(StopRefused::Unsafe);
    };

    change(m, Stage::Started, &what, None).await;
    // On Windows a whole `powershell -EncodedCommand` line: PIDs and base64,
    // nothing a command interpreter reads as syntax.
    let mut out = shell(m, &text, 0).await;
    let mut sudo_rejected = false;
    // A process this account does not own is asked again as root, the way a
    // user would `sudo kill`. Windows has no equivalent.
    if system != SystemType::Windows && outcome_of(&out) == Some(ProcKillOutcome::Denied) {
        out = m.run(Run::Root { text: &text, password: request.password.as_deref() }, 0).await;
        sudo_rejected = out.as_ref().is_ok_and(|out| sbm_parser::script::sudo_password_rejected(&out.stderr));
    }

    let outcome = outcome_of(&out).unwrap_or(ProcKillOutcome::Failed);
    let failed = match outcome {
        ProcKillOutcome::Succeeded => None,
        ProcKillOutcome::Denied => Some("permission denied"),
        ProcKillOutcome::TargetChanged => Some("target changed"),
        ProcKillOutcome::Failed if sudo_rejected => Some("sudo password rejected"),
        ProcKillOutcome::Failed => Some("command failed"),
    };
    if let Some(why) = failed {
        change(m, Stage::Failed, &what, Some(why)).await;
    }
    let (stdout, stderr, exit_code) = match out {
        Ok(out) => (out.stdout, out.stderr, out.exit_code),
        Err(e) => (String::new(), e, None),
    };
    Ok(KillResponse { outcome, exit_code, stdout, stderr, sudo_rejected })
}

/// What the machine answered, where it answered at all.
fn outcome_of(out: &Result<Ran, String>) -> Option<ProcKillOutcome> {
    let out = out.as_ref().ok()?;
    if out.timed_out {
        return None;
    }
    Some(sbm_parser::proc::kill_outcome(&out.stdout))
}

#[cfg(test)]
mod tests {
    use super::super::fake::{Fake, ok};
    use super::*;

    #[tokio::test]
    async fn a_row_without_a_start_identity_is_not_signalled() {
        let m = Fake::new(SystemType::Linux, vec![]);
        let request = KillRequest { pid: 42, start_id: None, signal: ProcSignal::Term, password: None };
        assert_eq!(stop(&m, request).await.unwrap_err(), StopRefused::Unsafe);
        assert!(m.asked.lock().unwrap().is_empty());
    }

    #[tokio::test]
    async fn an_empty_table_says_what_the_machine_said() {
        let m = Fake::new(SystemType::Linux, vec![("script:", Ran { stderr: "ps: not found".into(), ..ok("") })]);
        let answer = table(&m, None, None).await;
        assert_eq!(answer.reason_kind, Some(ProcessReason::Empty));
        assert_eq!(answer.reason.as_deref(), Some("ps: not found"));
    }
}
