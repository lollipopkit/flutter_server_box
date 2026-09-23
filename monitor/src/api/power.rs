//! `POST /api/v1/power` — shut down, reboot or suspend the machine the agent
//! runs on.
//!
//! # Why this is not `/exec`
//!
//! The command text already exists — [`sbm_parser::script::ShellFunc`] carries
//! `SbShutdown`, `SbReboot` and `SbSuspend`, and the app runs the same three
//! over SSH. Sending that text through `/exec` would work and would make every
//! caller responsible for the `sudo -S` dance, the password pipe and reading a
//! rejection off stderr; three of them would each do it slightly differently.
//! Asking for an action instead puts that in one place, on the same script
//! the app runs, so a change to either reaches both.
//!
//! # Why the password is a field
//!
//! `stdin` is how `sudo -S` gets one with no terminal to type it into, and it
//! travels as its own field for the reason `/exec`'s does: a password written
//! into a command line lands in the machine's process list and in the audit
//! row. Nothing here records it.
//!
//! A rejection is answered as data rather than as a status code — see
//! [`sbm_parser::script::sudo_password_rejected`] — because the caller's next
//! move is to ask the user for a different password, and the exit code alone
//! cannot tell that apart from the machine refusing to power off.
//!
//! # Authority
//!
//! `remote_access.full_access`, the same grant the shell, `/exec` and the
//! terminal need. Anyone who can open a shell can run `shutdown` in it.

use std::sync::Arc;

use ntex::web::{self, HttpRequest, HttpResponse};
use serde::{Deserialize, Serialize};

use super::server::AppState;
use super::server::verify_auth;
use super::ws;
use super::ws::audit::{Action, Event, Kind, Outcome, peer_ip};
use crate::monitoring::run_local_shell_func;

/// What the machine is being asked to do.
#[derive(Debug, Clone, Copy, Deserialize)]
#[serde(rename_all = "lowercase")]
pub enum PowerAction {
    Shutdown,
    Reboot,
    Suspend,
}

impl PowerAction {
    fn shell_func(self) -> sbm_parser::script::ShellFunc {
        match self {
            PowerAction::Shutdown => sbm_parser::script::ShellFunc::Shutdown,
            PowerAction::Reboot => sbm_parser::script::ShellFunc::Reboot,
            PowerAction::Suspend => sbm_parser::script::ShellFunc::Suspend,
        }
    }

    /// The word the audit row is written with. Stable, and not the `Debug`
    /// form, so a rename of the variant cannot rewrite history.
    fn as_str(self) -> &'static str {
        match self {
            PowerAction::Shutdown => "shutdown",
            PowerAction::Reboot => "reboot",
            PowerAction::Suspend => "suspend",
        }
    }
}

#[derive(Deserialize)]
pub struct PowerRequest {
    action: PowerAction,
    /// For `sudo -S`. Never logged.
    #[serde(default)]
    password: Option<String>,
}

#[derive(Serialize)]
struct PowerResponse {
    /// Null when the command was killed for exceeding its timeout — a machine
    /// suspending under a command that then never returns is a normal way for
    /// this to end, so it is not an error.
    exit_code: Option<i32>,
    stdout: String,
    stderr: String,
    /// `sudo` refused the password that was sent. Told apart from any other
    /// non-zero exit because it is the one outcome the caller can act on.
    sudo_rejected: bool,
    /// Whether either stream hit the output cap, so the caller knows the text
    /// it is reading is a prefix.
    truncated: bool,
    timed_out: bool,
}

pub async fn power(
    req: HttpRequest,
    body: web::types::Json<PowerRequest>,
    app_state: web::types::State<Arc<AppState>>,
) -> Result<HttpResponse, web::Error> {
    if verify_auth(&req, &app_state.config.get_jwt_secret()).is_err() {
        return Ok(HttpResponse::Unauthorized().finish());
    }

    let remote_ip = peer_ip(&req);
    let secure = ws::is_secure_transport(&req, app_state.tls_active);

    // Re-checked at the moment of use rather than trusted from the capabilities
    // the client was told earlier: that answer is a UI hint, and the UI is not
    // a boundary.
    if !app_state.full_access_allowed(secure) {
        Event::new(Kind::Power, Action::Denied, Outcome::Denied)
            .remote_ip(remote_ip)
            .detail("full access disabled")
            .record(&app_state.db)
            .await;
        return Ok(HttpResponse::Forbidden().finish());
    }

    let action = body.action;
    // Logged before it runs: the command that succeeds is the one that takes
    // the agent down with it, and a row written afterwards would never be.
    Event::new(Kind::Power, Action::Open, Outcome::Ok)
        .remote_ip(remote_ip.clone())
        .subject(action.as_str())
        .record(&app_state.db)
        .await;

    let output = run_local_shell_func(action.shell_func(), body.password.as_deref().map(str::as_bytes))
        .await;
    let output = match output {
        Ok(output) => output,
        // Reported as a field rather than as a failure: what the command
        // printed is still worth reading, and the caller's own output is a
        // prefix of it either way. A spawn that failed is the one that is
        // actually an error.
        Err(crate::utils::error::MonitorError::Io(e))
            if crate::utils::command::is_output_overflow(&e) =>
        {
            return Ok(HttpResponse::Ok().json(&PowerResponse {
                exit_code: None,
                stdout: String::new(),
                stderr: String::new(),
                sudo_rejected: false,
                truncated: true,
                timed_out: false,
            }));
        }
        Err(e) => {
            Event::new(Kind::Power, Action::Close, Outcome::Error)
                .remote_ip(remote_ip)
                .subject(action.as_str())
                .detail(e.to_string())
                .record(&app_state.db)
                .await;
            return Ok(HttpResponse::InternalServerError().finish());
        }
    };

    let Some(output) = output else {
        return Ok(HttpResponse::Ok().json(&PowerResponse {
            exit_code: None,
            stdout: String::new(),
            stderr: String::new(),
            sudo_rejected: false,
            truncated: false,
            timed_out: true,
        }));
    };

    let stdout = String::from_utf8_lossy(&output.stdout).into_owned();
    let stderr = String::from_utf8_lossy(&output.stderr).into_owned();
    let sudo_rejected = sbm_parser::script::sudo_password_rejected(&stderr);
    if !output.status.success() {
        // The outcome, not the text: a `sudo` refusal quotes nothing secret,
        // but the general rule for this column is that it never carries what a
        // command printed.
        Event::new(Kind::Power, Action::Close, Outcome::Error)
            .remote_ip(remote_ip)
            .subject(action.as_str())
            .detail(if sudo_rejected {
                "sudo password rejected"
            } else {
                "command failed"
            })
            .record(&app_state.db)
            .await;
    }

    Ok(HttpResponse::Ok().json(&PowerResponse {
        exit_code: output.status.code(),
        stdout,
        stderr,
        sudo_rejected,
        truncated: false,
        timed_out: false,
    }))
}
