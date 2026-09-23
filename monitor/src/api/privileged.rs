//! Running shell text as the agent's own account, and as root.
//!
//! Every endpoint that acts on the machine needs the same two things: the
//! agent's own privileges, and `sudo` when that is not enough. The text is
//! POSIX shell handed to `sh` on stdin, which is the shape the shared modules
//! in [`sbm_parser`] document for their commands, and the same one the app
//! feeds over SSH — so one implementation of the handshake serves all of them.
//!
//! # Why stdin rather than a command line
//!
//! Two reasons, and they are different ones. A command built from a value that
//! came in over HTTP would have to survive shell quoting, and the shared
//! modules already quote what they interpolate; handing the whole script to
//! `sh` as its input takes the caller's values out of the shell's syntax
//! entirely, since nothing the machine reads as syntax reaches a command line
//! it is parsed from. **The sudo password** is the sharper case: on a command
//! line it is visible in `/proc/<pid>/cmdline` for as long as the process
//! lives, and to every account on the machine. It is written as the first line
//! of the same pipe instead, and sudo consumes exactly that line before the
//! script begins — which is why `sudo -S` is paired with an empty prompt
//! (`-p ''`), so nothing else is written to that pipe.
//!
//! # `-n` when there is no password
//!
//! Without it sudo reads the script itself as the password it is waiting for,
//! fails to authenticate, and the command silently does not happen. `-n` says
//! "do not prompt", so a machine whose account has passwordless sudo runs the
//! command and one whose account does not answers with a failure that names
//! the reason.

use sbm_parser::service::CommandOutput;
use tokio::process::Command as TokioCommand;

use crate::utils::command::{self, Limits};

/// Runs POSIX shell text as the agent's own account.
///
/// `None` where the command could not be run at all or overran its bounds —
/// which is not the same as a command that ran and failed, and is the reason
/// this returns an `Option` rather than an output with a made-up exit code.
///
/// `limits` is the caller's, because they are a property of what the command
/// prints rather than of how it is run: a `ps` table and a `systemctl show`
/// sweep describe a whole machine, and the 1 MiB default is sized for the one
/// command that prints a page.
pub async fn as_self(
    command_text: &str,
    label: &str,
    limits: Limits,
) -> Option<std::process::Output> {
    command::run(
        TokioCommand::new("sh"),
        label,
        limits,
        Some(command_text.as_bytes()),
    )
    .await
    .unwrap_or_else(|error| {
        tracing::warn!("{label}: {error}");
        None
    })
}

/// Runs POSIX shell text as root, with the password — when there is one —
/// first on the same pipe.
pub async fn as_root(
    command_text: &str,
    label: &str,
    limits: Limits,
    password: Option<&str>,
) -> Option<std::process::Output> {
    let entry = if password.is_some() {
        "sudo -S -p '' sh"
    } else {
        "sudo -n sh"
    };
    let mut command = TokioCommand::new("sh");
    command.arg("-c").arg(entry);
    let mut stdin = String::new();
    if let Some(password) = password {
        stdin.push_str(password);
        stdin.push('\n');
    }
    stdin.push_str(command_text);
    command::run(command, label, limits, Some(stdin.as_bytes()))
        .await
        .unwrap_or_else(|error| {
            tracing::warn!("{label}: {error}");
            None
        })
}

/// Whether sudo refused the password it was given, or was given none and
/// needed one.
///
/// Told apart from any other failure because the caller's next move is to ask
/// the user for a password and send the same request again, and because it must
/// not be reported as "the command failed" when the command never ran.
pub fn sudo_rejected(output: Option<&std::process::Output>) -> bool {
    output.is_some_and(|output| {
        sbm_parser::script::sudo_password_rejected(&String::from_utf8_lossy(&output.stderr))
    })
}

/// What a command printed, in the shape the shared parsers read.
///
/// `unrun_reason` is what `None` becomes: a command that never ran has no
/// stderr and no exit code, and a parser reading an empty `stderr` would report
/// the machine as having said nothing rather than as not having been asked.
pub fn read(output: Option<&std::process::Output>, unrun_reason: &str) -> CommandOutput {
    match output {
        Some(output) => CommandOutput::new(
            String::from_utf8_lossy(&output.stdout).into_owned(),
            String::from_utf8_lossy(&output.stderr).into_owned(),
            output.status.success(),
        ),
        None => CommandOutput::failed(unrun_reason),
    }
}
