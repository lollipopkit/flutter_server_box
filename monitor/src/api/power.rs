//! `POST /api/v1/power` — shut down, reboot or suspend the machine the agent
//! runs on.
//!
//! Runs the status script's own `SbShutdown`/`SbReboot`/`SbSuspend`, the
//! functions the app runs over SSH, through `api::exec::run` — so the command
//! text is the app's and the bounds are `/exec`'s. Asking for an action
//! rather than sending that text to `/exec` keeps the `sudo -S` handling and
//! the reading of a refused password in one place.
//!
//! The `shell` grant: anyone who can open a shell can run `shutdown` in it.
//!
//! The password is a field, written to the command's stdin for `sudo -S`, so
//! it never lands in a command line, the process list or the audit row. A
//! refused one is answered as `sudo_rejected` rather than a status code: the
//! caller's next step is to ask for another, and the exit code alone cannot
//! tell that apart from the machine refusing to power off.

use std::sync::Arc;

use ntex::web::{self, HttpRequest, HttpResponse};
use serde::{Deserialize, Serialize};
use sbm_parser::script::ShellFunc;

use super::machine;
use super::server::AppState;
use super::ws::audit::{Action, Event, Kind, Outcome};
use crate::core::permissions::Grant;

#[derive(Debug, Clone, Copy, PartialEq, Eq, Deserialize)]
#[serde(rename_all = "lowercase")]
pub enum PowerAction {
    Shutdown,
    Reboot,
    Suspend,
}

impl PowerAction {
    fn shell_func(self) -> ShellFunc {
        match self {
            PowerAction::Shutdown => ShellFunc::Shutdown,
            PowerAction::Reboot => ShellFunc::Reboot,
            PowerAction::Suspend => ShellFunc::Suspend,
        }
    }

    /// Written into the audit row. Stable on its own, so renaming a variant
    /// cannot rewrite what was recorded.
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
    /// For `sudo -S`. Never recorded.
    #[serde(default)]
    password: Option<String>,
}

#[derive(Serialize)]
struct PowerResponse {
    /// Null when the command did not exit on its own: killed at the timeout,
    /// which is an ordinary way for a suspend to end.
    exit_code: Option<i32>,
    stdout: String,
    stderr: String,
    /// `sudo` refused the password that was sent, or wanted one and got none.
    sudo_rejected: bool,
    truncated: bool,
    timed_out: bool,
}

pub async fn power(
    req: HttpRequest,
    body: web::types::Json<PowerRequest>,
    state: web::types::State<Arc<AppState>>,
) -> Result<HttpResponse, web::Error> {
    let action = body.action;
    let what = format!("power {}", action.as_str());
    let gated = match machine::gate(&req, &state, Grant::Shell, &what).await {
        Ok(gated) => gated,
        Err(refused) => return Ok(refused),
    };

    let cmd = match crate::monitoring::local_script_command(action.shell_func()) {
        Ok(cmd) => cmd,
        Err(e) => {
            tracing::warn!("power: could not write the status script: {e}");
            return Ok(HttpResponse::InternalServerError().finish());
        }
    };

    // Recorded before it runs: the command that succeeds is the one that
    // takes the agent down with it, and a row written afterwards never is.
    Event::new(Kind::Machine, Action::Open, Outcome::Ok)
        .subject(&gated.caller.username)
        .remote_ip(gated.remote_ip.clone())
        .detail(&what)
        .record(&state.db)
        .await;

    // `sudo -S` reads a line; without the newline it waits for the rest.
    let stdin = body.password.as_deref().map(|pw| format!("{pw}\n"));
    let out = match super::exec::run(&cmd, stdin.as_deref(), None, &state.remote_access.exec).await
    {
        Ok(out) => out,
        Err(e) => {
            Event::new(Kind::Machine, Action::Close, Outcome::Error)
                .subject(&gated.caller.username)
                .remote_ip(gated.remote_ip)
                .detail(format!("{what}: {e}"))
                .record(&state.db)
                .await;
            return Ok(HttpResponse::InternalServerError().finish());
        }
    };

    let sudo_rejected = sbm_parser::script::sudo_password_rejected(&out.stderr);
    if out.exit_code.is_some_and(|code| code != 0) {
        // Which way it failed, not what it printed: this column never carries
        // a command's output.
        Event::new(Kind::Machine, Action::Close, Outcome::Error)
            .subject(&gated.caller.username)
            .remote_ip(gated.remote_ip)
            .detail(format!(
                "{what}: {}",
                if sudo_rejected {
                    "sudo password rejected"
                } else {
                    "command failed"
                }
            ))
            .record(&state.db)
            .await;
    }

    Ok(HttpResponse::Ok().json(&PowerResponse {
        exit_code: out.exit_code,
        stdout: out.stdout,
        stderr: out.stderr,
        sudo_rejected,
        truncated: out.truncated,
        timed_out: out.timed_out,
    }))
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn each_action_runs_the_scripts_own_function() {
        for (action, flag) in [
            (PowerAction::Shutdown, ShellFunc::Shutdown.flag()),
            (PowerAction::Reboot, ShellFunc::Reboot.flag()),
            (PowerAction::Suspend, ShellFunc::Suspend.flag()),
        ] {
            let cmd = crate::monitoring::local_script_command(action.shell_func()).unwrap();
            if !cfg!(windows) {
                assert!(cmd.ends_with(&format!(" -{flag}")), "{cmd}");
            }
        }
    }

    #[test]
    fn only_the_three_actions_parse() {
        for ok in ["shutdown", "reboot", "suspend"] {
            assert!(serde_json::from_value::<PowerAction>(serde_json::json!(ok)).is_ok());
        }
        for bad in ["halt", "Shutdown", ""] {
            assert!(serde_json::from_value::<PowerAction>(serde_json::json!(bad)).is_err());
        }
    }
}
