//! Process table FFI (sbm_parser::proc)
//!
//! The rows, columns, orders and stop commands the monitor agent's panel
//! reads, for the app's process page. The app runs the process function and
//! the stop command over its own connection; what they print is read here.
//! A reading crosses as `sbm_parser::proc::PsView` JSON, and goes back the
//! same way as the next reading's `previous` (what its read/write speeds are
//! differenced against) or to be ordered again.

use sbm_parser::proc::{self, ProcSignal, ProcSortMode, PsResult, PsView};

use super::parser::parse_system_or_err;

fn sort_mode(sort: Option<String>) -> Result<Option<ProcSortMode>, String> {
    sort.map(|s| serde_json::from_value(serde_json::Value::String(s.clone())).map_err(|_| format!("unknown sort: {s}")))
        .transpose()
}

fn view_json(view: &PsView) -> Result<String, String> {
    serde_json::to_string(view).map_err(|e| e.to_string())
}

/// What the process function printed → `PsView` JSON, ordered by `sort`
/// (`cpu`, `mem`, `rss`, `pid`, `user`, `name`, `read`, `write`) where the
/// table can answer it. `previous` is the last reading that parsed cleanly,
/// as this returned it; `sampled_at_millis` is when `raw` was produced.
pub fn proc_view_json(
    raw: String,
    system: String,
    sort: Option<String>,
    ascending: Option<bool>,
    previous_json: Option<String>,
    sampled_at_millis: i64,
) -> Result<String, String> {
    let system = parse_system_or_err(&system)?;
    let sort = sort_mode(sort)?;
    let previous: Option<PsResult> = match previous_json {
        Some(json) => Some(serde_json::from_str(&json).map_err(|e| e.to_string())?),
        None => None,
    };
    let result = PsResult::parse(&raw, sort.unwrap_or(ProcSortMode::Cpu), ascending, previous.as_ref(), sampled_at_millis);
    view_json(&PsView::of(&result, system, sort, ascending))
}

/// A reading [`proc_view_json`] returned, ordered again.
pub fn proc_sorted_json(view_json_in: String, system: String, sort: Option<String>, ascending: Option<bool>) -> Result<String, String> {
    let system = parse_system_or_err(&system)?;
    let result: PsResult = serde_json::from_str(&view_json_in).map_err(|e| e.to_string())?;
    view_json(&PsView::of(&result, system, sort_mode(sort)?, ascending))
}

/// The command that sends `signal` (`term`, `kill`) to `pid` once its start
/// identity is still `start_id`, or `None` where the platform cannot check
/// it. What it prints is read by [`proc_kill_outcome`].
#[flutter_rust_bridge::frb(sync)]
pub fn proc_kill_command(pid: i64, start_id: Option<String>, system: String, signal: String) -> Result<Option<String>, String> {
    let system = parse_system_or_err(&system)?;
    let signal: ProcSignal =
        serde_json::from_value(serde_json::Value::String(signal.clone())).map_err(|_| format!("unknown signal: {signal}"))?;
    Ok(proc::kill_command(pid, start_id.as_deref(), system, signal))
}

/// What a stop printed: `succeeded`, `target_changed`, `denied` or `failed`.
#[flutter_rust_bridge::frb(sync)]
pub fn proc_kill_outcome(output: String) -> String {
    match proc::kill_outcome(&output) {
        proc::ProcKillOutcome::Succeeded => "succeeded",
        proc::ProcKillOutcome::TargetChanged => "target_changed",
        proc::ProcKillOutcome::Denied => "denied",
        proc::ProcKillOutcome::Failed => "failed",
    }
    .to_owned()
}
