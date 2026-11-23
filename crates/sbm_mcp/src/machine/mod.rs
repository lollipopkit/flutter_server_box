//! What any machine reached through a shell answers: its processes, service
//! units, containers and tmux sessions, and the changes to them — for the
//! monitor on the machine it runs on (its routes and its MCP tools alike) and
//! for the app on each of its servers.
//!
//! Every command and parser is [`sbm_parser`]'s; this is the order they run
//! in and the answer they make. How a command reaches the machine is the
//! host's, through [`Machine`]: the monitor runs it here, the app over SSH,
//! through a monitor, or on this device.

pub mod containers;
pub mod processes;
pub mod services;
pub mod tmux;
mod tools;

use async_trait::async_trait;
use sbm_parser::SystemType;
use sbm_parser::output::CommandOutput;
use sbm_parser::script::ShellFunc;

pub use tools::{call, command_summary, run_command};

/// One command, and how it is to be run.
#[derive(Debug, Clone, Copy)]
pub enum Run<'a> {
    /// A command line for the account's own shell, as `/exec` runs one.
    Line(&'a str),
    /// POSIX shell text, read by `sh` on its stdin as the account itself.
    ///
    /// Text rather than a command line: what `sbm_parser` builds interpolates
    /// values that came over the wire or off the machine, and as input none of
    /// them is ever parsed as the shell's own syntax — whatever the account's
    /// login shell is.
    Sh(&'a str),
    /// [`Run::Sh`] as root through `sudo`. The password, when there is one,
    /// stays off every command line; without one, `sudo -n`.
    Root { text: &'a str, password: Option<&'a str> },
    /// One function of the status script: its copy the host keeps on the
    /// machine.
    Script(ShellFunc),
}

/// What a command did.
#[derive(Debug, Clone, Default, PartialEq, Eq)]
pub struct Ran {
    pub stdout: String,
    pub stderr: String,
    /// `None` when the command was stopped rather than exiting.
    pub exit_code: Option<i32>,
    /// Either stream hit the host's output cap: what is here is a prefix.
    pub truncated: bool,
    /// The host's timeout elapsed and the command was stopped.
    pub timed_out: bool,
}

impl Ran {
    /// The shape `sbm_parser`'s parsers read.
    ///
    /// One that did not finish — stopped at the timeout or cut at the cap —
    /// is a failure carrying why, rather than a run that printed nothing: a
    /// parser reading an empty `stderr` would report the machine as having
    /// said nothing rather than as not having been heard.
    pub fn output(&self) -> CommandOutput {
        if self.timed_out {
            CommandOutput::failed("the command did not finish in time")
        } else if self.truncated {
            CommandOutput::failed("the command printed more than is read")
        } else {
            CommandOutput::new(self.stdout.clone(), self.stderr.clone(), self.exit_code == Some(0))
        }
    }
}

/// [`Ran::output`], or why the command could not be run at all.
pub fn command_output(ran: Result<Ran, String>) -> CommandOutput {
    match ran {
        Ok(ran) => ran.output(),
        Err(e) => CommandOutput::failed(format!("the command could not be run: {e}")),
    }
}

/// Where a change stands, for the host's audit log.
#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum Stage {
    /// Refused before anything ran.
    Refused,
    /// About to run: recorded first, so a change that never answers is on
    /// file anyway.
    Started,
    /// Ran and did not succeed.
    Failed,
}

/// What a host records. Never a password, a value or an output.
#[derive(Debug, Clone, Copy)]
pub enum Audit<'a> {
    /// A change to the machine: [what] is the feature and verb with what it
    /// was about, [detail] why it stopped where it did.
    Change { stage: Stage, what: &'a str, detail: Option<&'a str> },
    /// `run_command`: [line] is [`command_summary`] at [`Stage::Started`] and
    /// why it could not be run at [`Stage::Failed`].
    Command { stage: Stage, line: &'a str },
}

/// The machine, as the host reaches it.
#[async_trait]
pub trait Machine: Send + Sync {
    /// What the machine runs.
    fn system(&self) -> SystemType;

    /// Runs [run] within the host's own bounds, with at least [room] bytes of
    /// output kept: a reading of the whole machine (a process table, every
    /// unit's details) needs more than one command's default. `0` is the
    /// host's default.
    async fn run(&self, run: Run<'_>, room: usize) -> Result<Ran, String>;

    /// Records [audit] where the host keeps such things. Nothing by default.
    async fn record(&self, _audit: Audit<'_>) {}
}

pub(crate) async fn change(m: &dyn Machine, stage: Stage, what: &str, detail: Option<&str>) {
    m.record(Audit::Change { stage, what, detail }).await;
}

/// Runs POSIX shell [text] as the account itself — or, on Windows, which has
/// no `sh`, as a command line: what is run there is one PowerShell line.
pub(crate) async fn shell(m: &dyn Machine, text: &str, room: usize) -> Result<Ran, String> {
    if m.system() == SystemType::Windows {
        m.run(Run::Line(text), room).await
    } else {
        m.run(Run::Sh(text), room).await
    }
}

pub(crate) fn now_millis() -> i64 {
    std::time::SystemTime::now()
        .duration_since(std::time::UNIX_EPOCH)
        .map(|d| d.as_millis() as i64)
        .unwrap_or_default()
}

/// A fake machine for tests: each command's answer by the text it was asked.
#[cfg(test)]
pub(crate) mod fake {
    use super::*;
    use std::sync::Mutex;

    pub struct Fake {
        pub system: SystemType,
        pub answers: Vec<(&'static str, Ran)>,
        pub asked: Mutex<Vec<String>>,
        pub audits: Mutex<Vec<String>>,
    }

    impl Fake {
        pub fn new(system: SystemType, answers: Vec<(&'static str, Ran)>) -> Self {
            Self { system, answers, asked: Mutex::default(), audits: Mutex::default() }
        }
    }

    pub fn ok(stdout: &str) -> Ran {
        Ran { stdout: stdout.into(), exit_code: Some(0), ..Default::default() }
    }

    pub fn failed(stderr: &str, code: i32) -> Ran {
        Ran { stderr: stderr.into(), exit_code: Some(code), ..Default::default() }
    }

    #[async_trait]
    impl Machine for Fake {
        fn system(&self) -> SystemType {
            self.system
        }

        async fn run(&self, run: Run<'_>, _room: usize) -> Result<Ran, String> {
            let text = match run {
                Run::Line(t) | Run::Sh(t) => t.to_owned(),
                Run::Root { text, .. } => format!("root:{text}"),
                Run::Script(func) => format!("script:{}", func.name()),
            };
            self.asked.lock().unwrap().push(text.clone());
            self.answers
                .iter()
                .find(|(needle, _)| text.contains(needle))
                .map(|(_, ran)| ran.clone())
                .ok_or_else(|| format!("no answer for {text}"))
        }

        async fn record(&self, audit: Audit<'_>) {
            self.audits.lock().unwrap().push(format!("{audit:?}"));
        }
    }
}
