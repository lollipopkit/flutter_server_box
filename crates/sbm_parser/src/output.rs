//! What one command printed, in the shape the parsers in this crate read.
//!
//! Written for [`crate::service`], which was the first module to take several
//! commands' output at once and had to tell a failure's `stderr` from a
//! success's `stdout`. It is not a service concept: every module here that
//! parses command output reads this, and the agent's own runner
//! (`monitor/src/api/privileged.rs`) builds one from `std::process::Output` for
//! all of them.

/// What one command printed, and whether it succeeded.
///
/// The three parts are kept apart rather than flattened into one string
/// because a failure's detail is `stderr` and a success's payload is `stdout`:
/// the Dart port reads a listing out of `stdout` and reports `combined`, and
/// one field could not do both.
#[derive(Debug, Clone, PartialEq, Eq)]
pub struct CommandOutput {
    pub stdout: String,
    pub stderr: String,
    /// Whether the command exited zero.
    pub succeeded: bool,
}

impl CommandOutput {
    /// A command that ran and exited zero.
    pub fn ok(stdout: impl Into<String>) -> Self {
        Self {
            stdout: stdout.into(),
            stderr: String::new(),
            succeeded: true,
        }
    }

    /// A command that ran and did not exit zero.
    pub fn failed(stderr: impl Into<String>) -> Self {
        Self {
            stdout: String::new(),
            stderr: stderr.into(),
            succeeded: false,
        }
    }

    pub fn new(stdout: impl Into<String>, stderr: impl Into<String>, succeeded: bool) -> Self {
        Self {
            stdout: stdout.into(),
            stderr: stderr.into(),
            succeeded,
        }
    }

    /// Both streams in the order a terminal would have shown them.
    ///
    /// Both, not `stderr` alone: a command that printed a partial listing and
    /// then failed has that listing in `stdout`, and it is what the failure's
    /// detail is read beside.
    pub fn combined(&self) -> String {
        if self.stderr.is_empty() {
            self.stdout.clone()
        } else {
            format!("{}{}", self.stdout, self.stderr)
        }
    }

    /// [`combined`](Self::combined), trimmed — what a notice's detail is.
    pub fn detail(&self) -> Option<String> {
        let detail = self.combined();
        let trimmed = detail.trim();
        (!trimmed.is_empty()).then(|| trimmed.to_string())
    }
}
