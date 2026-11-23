//! `/api/v1/process` — the process table of the machine the agent runs on, and
//! the signal that stops one process.
//!
//! # Why this is not `/exec`
//!
//! Both halves are a model rather than a command. The table is read out of
//! `ps` on Unix and out of PowerShell's JSON on Windows, by column name where
//! the platform printed a header and by position where it did not, and which
//! of those columns exist is what decides which orders the page may offer and
//! which columns it can draw. The stop is a script that checks the PID's start
//! identity before signalling it, and a `sudo` retry for a process this account
//! does not own — a retry that has to keep the script away from sudo's password
//! read. Both live in [`sbm_parser::proc`], asked through
//! [`sbm_mcp::machine::processes`], so the app and this endpoint read and stop
//! one machine the same way, and the panel composes no command line and
//! parses no `ps` output.
//!
//! The table is [`sbm_parser::script::ShellFunc::Process`], run locally: the
//! same text the app uploads and calls with `-p` over SSH, so a change to it
//! reaches both.
//!
//! # The reading is kept between requests
//!
//! A read/write speed is a difference against the previous reading, so one has
//! to be kept somewhere. The app keeps it on the page, and it dies with the
//! page; here it is kept here, for as long as [`BASELINE_MAX_AGE`] allows. A
//! request inside [`REUSE_WINDOW`] of that reading is answered with it rather
//! than with a new one, so a request that is not asking for fresh numbers —
//! the page reordering the table — does not turn an interval of a few
//! milliseconds into a speed.
//!
//! # Privilege
//!
//! Both halves need the transport rule (`api::machine::gate`). Signalling, for
//! the reason the shell is: anyone with one can run `kill`. Reading too: a
//! process's command line is where a token or a password passed as an
//! argument shows up, which `read` (status and charts) was never meant to
//! hand out.

use crate::api::WebError;
use std::sync::Arc;
use std::time::Duration;

use ntex::web::{self, HttpRequest, HttpResponse};
use serde::Deserialize;

use super::machine::{self, Here};
use super::server::AppState;
use sbm_mcp::machine::processes::{self, KillRequest, ProcessResponse, StopRefused};
use sbm_parser::proc::{ProcSortMode, PsResult};

/// How long a reading answers further requests for it.
///
/// A page that reorders the table, or a caller that refreshes twice, asks a
/// question the last reading already answers. Running the command again would
/// answer it with read/write speeds differenced over that few-hundred-
/// millisecond gap — a spike, not a rate — so the reading stands and only its
/// order changes. Shorter than any poll interval the page uses, so an ordinary
/// refresh is never served a reading it already has.
const REUSE_WINDOW: Duration = Duration::from_millis(2000);

/// How old a reading may be and still be what a speed is differenced against.
///
/// Past this the counters moved an unknown number of times, and dividing that
/// by the whole gap reports an average over a period nobody was looking at.
/// The reading is dropped instead, exactly as it is on a page that has just
/// been opened: the first answer has no speeds, and the second one has real
/// ones.
const BASELINE_MAX_AGE: Duration = Duration::from_secs(30);

/// The last reading, so the next one has something to difference against.
///
/// Held on the agent rather than on the caller because the agent is one
/// machine: two browsers looking at the same server are looking at the same
/// interval, and the second one's request is as good an answer as the first's.
pub struct ProcessSample {
    /// When the reading was taken, by this process's clock.
    pub sampled_at_millis: i64,
    pub result: Arc<PsResult>,
}

#[derive(Debug, Deserialize)]
pub struct ProcessQuery {
    /// Which order the caller wants. Omitted is the table's own default, and a
    /// mode this table cannot answer falls back to it rather than ordering
    /// everything by a column of nulls.
    sort: Option<ProcSortMode>,
    /// Which way round. Omitted is that mode's own default — see
    /// [`ProcSortMode::default_ascending`].
    ascending: Option<bool>,
}

/// Reads the process table.
pub async fn list(
    req: HttpRequest,
    query: web::types::Query<ProcessQuery>,
    state: Arc<AppState>,
) -> Result<HttpResponse, WebError> {
    if let Err(refused) = machine::gate(&req, &state, "process list").await {
        return Ok(refused);
    }
    Ok(HttpResponse::Ok().json(&table(&state, query.sort, query.ascending).await))
}

/// The table, in [sort] order. Shared by `/process` and the MCP tool, which
/// is the same reading under the same rule — the transport rule is the
/// caller's, asked before this runs.
pub(crate) async fn table(
    state: &AppState,
    sort: Option<ProcSortMode>,
    ascending: Option<bool>,
) -> ProcessResponse {
    let here = Here::quiet(&state.remote_access.exec);
    let system = crate::monitoring::system_type();
    let now = chrono::Utc::now().timestamp_millis();

    // Copied out rather than held: the branch below runs a command, and
    // holding the lock across it would queue every caller behind whoever
    // asked first. The reading stays in the slot — a request that reorders
    // the table does not change it.
    let stored = state
        .process_sample
        .lock()
        .await
        .as_ref()
        .map(|sample| (now - sample.sampled_at_millis, sample.result.clone()));

    if let Some((age, result)) = &stored
        && *age < REUSE_WINDOW.as_millis() as i64
    {
        let (sort, ascending) = processes::resolve_sort(result, sort, ascending);
        return processes::respond(&result.sorted_by(sort, Some(ascending)), system, Some(sort), Some(ascending));
    }

    // What this reading's speeds are differenced against. An expired one is
    // left in the slot: it is replaced below if this read succeeds.
    let baseline = stored
        .as_ref()
        .filter(|(age, _)| *age <= BASELINE_MAX_AGE.as_millis() as i64)
        .map(|(_, result)| &**result);

    let parsed = match processes::read(&here, baseline).await {
        Ok(parsed) => parsed,
        Err(unavailable) => return *unavailable,
    };
    let (sort, ascending) = processes::resolve_sort(&parsed, sort, ascending);
    let result = Arc::new(parsed.sorted_by(sort, Some(ascending)));
    let response = processes::respond(&result, system, Some(sort), Some(ascending));
    *state.process_sample.lock().await = Some(ProcessSample {
        sampled_at_millis: result.sampled_at_millis,
        result,
    });
    response
}

/// Stops one process.
pub async fn kill(
    req: HttpRequest,
    body: web::types::Json<KillRequest>,
    state: Arc<AppState>,
) -> Result<HttpResponse, WebError> {
    let request = body.into_inner();
    let what = format!("process stop {} {}", request.signal.name(), request.pid);
    let gated = match machine::gate(&req, &state, &what).await {
        Ok(gated) => gated,
        Err(refused) => return Ok(refused),
    };
    match processes::stop(&Here::recorded(&state, gated.remote_ip), request).await {
        Ok(response) => Ok(HttpResponse::Ok().json(&response)),
        Err(StopRefused::Unsafe) => Ok(HttpResponse::BadRequest().build()),
        Err(StopRefused::Signal) => Ok(HttpResponse::BadRequest().build()),
    }
}
