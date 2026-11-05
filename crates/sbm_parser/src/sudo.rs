//! How a command reaches root: as the account itself, or through sudo with or
//! without a password. One place for the forms, so the app's privileged
//! scripts, the exec-session kill, a volume upload, file and container
//! commands and the agent's root actions all say the same thing.

use serde::{Deserialize, Serialize};

/// The way into root a command is run with.
#[derive(Debug, Clone, Copy, PartialEq, Eq, Serialize, Deserialize)]
#[serde(rename_all = "snake_case")]
pub enum SudoEntry {
    /// As this account, already root or needing nothing more.
    Direct,
    /// `sudo -n`: refused rather than asking, where no password is known.
    SudoNoPassword,
    /// `sudo -S -p ''`: the password comes first on stdin, one line, and is
    /// never part of the command.
    SudoPassword,
}

impl SudoEntry {
    /// [body], a command line, run this way.
    pub fn wrap(self, body: &str) -> String {
        match self {
            SudoEntry::Direct => body.to_owned(),
            SudoEntry::SudoNoPassword => format!("sudo -n {body}"),
            SudoEntry::SudoPassword => format!("sudo -S -p '' {body}"),
        }
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn each_form_and_never_a_password_in_the_command() {
        assert_eq!(SudoEntry::Direct.wrap("sh"), "sh");
        assert_eq!(SudoEntry::SudoNoPassword.wrap("sh"), "sudo -n sh");
        assert_eq!(SudoEntry::SudoPassword.wrap("sh"), "sudo -S -p '' sh");
    }

    #[test]
    fn names_on_the_wire_are_snake_case() {
        assert_eq!(serde_json::to_string(&SudoEntry::SudoNoPassword).unwrap(), "\"sudo_no_password\"");
    }
}
