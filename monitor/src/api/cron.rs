//! `GET/PUT /api/v1/cron` — the scheduled tasks of the account the agent runs
//! as.
//!
//! # Why this is not `/exec`
//!
//! The whole feature is one crontab file: read it, change one line, write it
//! back. Sending [`sbm_parser::cron::LIST_SCRIPT`] and `crontab -` through
//! `/exec` would work, and it is what the app does over SSH — but the part that
//! decides *which line* a job is, what a disabled job looks like on disk and
//! what may not be written at all is a model, not a command, and three callers
//! would each reimplement it. It lives in
//! [`sbm_parser::cron`] instead, so the app and this endpoint read the same
//! file the same way.
//!
//! An edit is expressed as an operation on one line rather than as a whole
//! document, which is the second half of that: a client that round-tripped the
//! text would be the thing that decides how a disabled line is spelled, and a
//! client that got it slightly wrong would rewrite a file it does not own.
//! The read is redone at the moment of the write, so a save never writes back
//! a listing taken minutes ago — only the line index can be stale.
//!
//! # What this manages
//!
//! `crontab` itself: the account's own crontab, as the command means. Not
//! `/etc/cron.d`, not `-u` for another account, not systemd timers.
//!
//! # Privilege
//!
//! The `shell` grant for both halves (`api::machine::gate`). Writing it is
//! arranging for code to run on a timer as the agent's account; reading it is
//! reading commands, which is where an argument-borne token sits.

use std::sync::Arc;

use ntex::web::{self, HttpRequest, HttpResponse};
use serde::{Deserialize, Serialize};

use super::exec::{ExecResponse, Limits, run};
use super::machine;
use super::server::AppState;
use super::ws::audit::{Action, Event, Kind, Outcome};
use crate::core::permissions::Grant;
use crate::monitoring::system_type;

/// The listing is one crontab, so this is generous; the cap is here so a
/// runaway `crontab` cannot make the agent buffer without bound.
const MAX_LIST_BYTES: usize = 4 * 1024 * 1024;

#[derive(Serialize)]
struct CronListResponse {
    /// Whether the crontab could be read at all. `false` is a state of the
    /// machine — no `crontab(1)`, a platform that has none — not a failure of
    /// the caller, so it is a field rather than a status code, and the panel
    /// has one page to draw either way.
    available: bool,
    /// Which of the known reasons it was, so the panel phrases it in its own
    /// language. `None` alongside `available: false` means the machine said
    /// something this endpoint does not classify, and `reason` is it.
    reason_kind: Option<CronReason>,
    /// What the machine said, verbatim. Never translated and never classified
    /// away: it is the only thing that distinguishes one failure from another.
    reason: Option<String>,
    /// The account whose crontab this is, as the machine named it.
    user: Option<String>,
    /// The agent machine's wall clock when it was read, `YYYY-MM-DDTHH:MM`.
    ///
    /// Cron matches an expression against the server's own clock, and this is
    /// the one reading of it that came from the machine itself — a client that
    /// used its own would name a time the job will not run at.
    now: Option<String>,
    jobs: Vec<sbm_parser::cron::CronJobView>,
    /// Comments, environment assignments and anything else that is not a job.
    /// A client shows them so a crontab another tool manages does not look like
    /// it lost them.
    preserved: Vec<String>,
}

#[derive(Debug, Clone, Copy, Serialize)]
#[serde(rename_all = "snake_case")]
enum CronReason {
    /// No `crontab(1)` on the machine.
    NotInstalled,
    /// Windows, where `crontab` does not exist and `sh` cannot run the listing.
    UnsupportedPlatform,
    /// The listing ran and its output was not the script's own.
    Unreadable,
}

/// One change to one line.
///
/// The line is addressed by index into the listing the client was given. What
/// is at that index is re-read here, so an index that no longer names a job is
/// refused rather than overwriting whatever moved into its place.
#[derive(Debug, Deserialize)]
#[serde(tag = "op", rename_all = "snake_case")]
pub enum CronEdit {
    /// Replaces the job at `line_index`, or appends when it is `null`.
    Upsert {
        #[serde(default)]
        line_index: Option<usize>,
        schedule: String,
        command: String,
        enabled: bool,
    },
    Remove {
        line_index: usize,
    },
    SetEnabled {
        line_index: usize,
        enabled: bool,
    },
}

impl CronEdit {
    /// What the audit row says about it. The schedule, never the command: a
    /// command is free text that may hold a token, and this column never
    /// does.
    fn subject(&self) -> String {
        match self {
            Self::Upsert {
                schedule,
                line_index,
                ..
            } => match line_index {
                Some(index) => format!("upsert line {index}: {schedule}"),
                None => format!("append: {schedule}"),
            },
            Self::Remove { line_index } => format!("remove line {line_index}"),
            Self::SetEnabled { line_index, enabled } => format!(
                "{} line {line_index}",
                if *enabled { "enable" } else { "disable" }
            ),
        }
    }
}

#[derive(Serialize)]
struct ErrorResponse {
    /// The [`sbm_parser::cron::CronValidation`] case, so the panel shows its
    /// own sentence rather than a server's English one.
    error: String,
}

/// Reads the crontab and reports it.
pub async fn list(
    req: HttpRequest,
    state: web::types::State<Arc<AppState>>,
) -> Result<HttpResponse, web::Error> {
    if let Err(refused) = machine::gate(&req, &state, Grant::Shell, "cron list").await {
        return Ok(refused);
    }
    Ok(HttpResponse::Ok().json(&read_crontab(&state.remote_access.exec).await))
}

/// Applies one change and answers with the listing as it now stands.
pub async fn edit(
    req: HttpRequest,
    body: web::types::Json<CronEdit>,
    state: web::types::State<Arc<AppState>>,
) -> Result<HttpResponse, web::Error> {
    let edit = body.into_inner();
    let what = format!("cron {}", edit.subject());
    let gated = match machine::gate(&req, &state, Grant::Shell, &what).await {
        Ok(gated) => gated,
        Err(refused) => return Ok(refused),
    };
    let exec = &state.remote_access.exec;

    // Before the machine is touched at all: what a client sent is the
    // client's to get right, and a refusal that depended on whether this
    // machine has `crontab(1)` would be two answers to one mistake.
    if let CronEdit::Upsert {
        schedule, command, ..
    } = &edit
        && let Some(validation) = sbm_parser::cron::validate(schedule, command)
    {
        return Ok(HttpResponse::BadRequest().json(&ErrorResponse {
            error: validation.to_string(),
        }));
    }

    // Read before writing, so the edit lands on the file as it is now rather
    // than on a listing the client took minutes ago.
    let catalog = match read_document(exec).await {
        Ok(catalog) => catalog,
        Err(unavailable) => {
            return Ok(HttpResponse::Ok().json(&CronListResponse::unavailable(unavailable)));
        }
    };
    let applied = match &edit {
        CronEdit::Upsert {
            line_index,
            schedule,
            command,
            enabled,
        } => catalog
            .document
            .upsert(*line_index, schedule, command, *enabled),
        CronEdit::Remove { line_index } => catalog.document.remove(*line_index),
        CronEdit::SetEnabled { line_index, enabled } => {
            catalog.document.set_enabled(*line_index, *enabled)
        }
    };
    let document = match applied {
        Ok(document) => document,
        // An index that no longer names a job: the listing moved under the
        // client. Refused rather than applied to whatever is there now.
        Err(validation) => {
            return Ok(HttpResponse::BadRequest().json(&ErrorResponse {
                error: validation.to_string(),
            }));
        }
    };

    Event::new(Kind::Machine, Action::Open, Outcome::Ok)
        .subject(&gated.caller.username)
        .remote_ip(gated.remote_ip.clone())
        .detail(&what)
        .record(&state.db)
        .await;
    if let Err(unavailable) = write_document(&document.render(), exec).await {
        Event::new(Kind::Machine, Action::Close, Outcome::Error)
            .subject(&gated.caller.username)
            .remote_ip(gated.remote_ip)
            .detail(format!("{what}: write failed ({:?})", unavailable.kind))
            .record(&state.db)
            .await;
        return Ok(HttpResponse::Ok().json(&CronListResponse::unavailable(unavailable)));
    }

    // Re-read rather than reusing `document`: only the machine can say it took
    // what was written, and both endpoints keep one shape.
    Ok(HttpResponse::Ok().json(&read_crontab(exec).await))
}

/// Why the crontab cannot be read or written, in a form the panel can phrase
/// itself and the text it can fall back to.
struct Unavailable {
    kind: CronReason,
    text: Option<String>,
}

impl CronListResponse {
    fn unavailable(reason: Unavailable) -> Self {
        Self {
            available: false,
            reason_kind: Some(reason.kind),
            reason: reason.text,
            user: None,
            now: None,
            jobs: Vec::new(),
            preserved: Vec::new(),
        }
    }
}

/// The crontab as the machine has it, or why it has none to give.
async fn read_document(exec: &Limits) -> Result<sbm_parser::cron::CronCatalog, Unavailable> {
    let unreadable = |text: Option<String>| Unavailable {
        kind: CronReason::Unreadable,
        text,
    };
    if system_type() == sbm_parser::SystemType::Windows {
        // `crontab` is a Unix command and the listing runs under `sh`.
        return Err(Unavailable {
            kind: CronReason::UnsupportedPlatform,
            text: None,
        });
    }

    let output = match machine::as_self(sbm_parser::cron::LIST_SCRIPT, &machine::at_least(exec, MAX_LIST_BYTES)).await {
        Ok(output) if !output.timed_out && !output.truncated => output,
        Ok(_) => return Err(unreadable(Some("the listing did not finish".to_owned()))),
        Err(e) => return Err(unreadable(Some(e.to_string()))),
    };
    let ExecResponse {
        stdout,
        stderr,
        exit_code,
        ..
    } = output;

    sbm_parser::cron::read_listing(&stdout, &stderr, exit_code, exit_code == Some(0)).map_err(unavailable_from)
}

/// A listing or a save the machine refused, as the reason the panel shows.
/// `crontab` missing altogether is its own case and carries no text: there
/// is nothing in it the panel does not already say.
fn unavailable_from(failure: sbm_parser::cron::CronFailure) -> Unavailable {
    if failure.not_installed {
        return Unavailable {
            kind: CronReason::NotInstalled,
            text: None,
        };
    }
    Unavailable {
        kind: CronReason::Unreadable,
        text: failure.detail,
    }
}

/// The same read, as the response body both endpoints answer with.
async fn read_crontab(exec: &Limits) -> CronListResponse {
    let catalog = match read_document(exec).await {
        Ok(catalog) => catalog,
        Err(unavailable) => return CronListResponse::unavailable(unavailable),
    };
    // Absent when the machine's `date` could not say what its offset is — an
    // old agent, or a `date` without `%z`. The schedule still lists; only the
    // next run cannot be placed.
    let now = catalog.clock.map(|clock| clock.now_wall());
    CronListResponse {
        available: true,
        reason_kind: None,
        reason: None,
        user: Some(catalog.user),
        now: now.map(|at| at.to_iso()),
        jobs: catalog
            .document
            .jobs()
            .iter()
            .map(|job| job.view(now))
            .collect(),
        preserved: catalog
            .document
            .preserved()
            .into_iter()
            .map(str::to_owned)
            .collect(),
    }
}

/// Replaces the account's crontab with `document`.
///
/// `crontab -` and not `crontab <file>`: the document goes in on stdin, so it
/// never lands in the machine's process list or in a temporary file, and there
/// is nothing to clean up if this does not finish.
async fn write_document(document: &str, exec: &Limits) -> Result<(), Unavailable> {
    let output = match run("crontab -", Some(document), None, exec).await {
        Ok(output) if !output.timed_out => output,
        Ok(_) => {
            return Err(Unavailable {
                kind: CronReason::Unreadable,
                text: Some("the write timed out".to_owned()),
            });
        }
        Err(e) => {
            return Err(Unavailable {
                kind: CronReason::Unreadable,
                text: Some(e.to_string()),
            });
        }
    };
    sbm_parser::cron::check_save(&output.stdout, &output.stderr, output.exit_code, output.exit_code == Some(0))
        .map_err(unavailable_from)
}
