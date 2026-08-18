//! Reading and writing the custom-command directory on this machine.
//!
//! The same directory the app writes over SSH and the generated status script
//! reads (`sbm_parser::script`): one file per command, named so that sorting
//! the directory sorts it into the user's order, and the name base64-encoded
//! so that none of it reaches a shell. Here it is a local path rather than a
//! shell expression, because the monitor is on the machine.
//!
//! Nothing here executes a command. The extended collection cycle does, by
//! running the status script, which reads this directory — so writing a file
//! here is arranging for code to run as the agent's user, and the endpoint
//! that does it is gated accordingly.

use std::path::{Path, PathBuf};

use sbm_parser::script;
use serde::{Deserialize, Serialize};

/// One command as the panel edits it.
#[derive(Debug, Clone, Serialize, Deserialize, PartialEq, Eq)]
pub struct CustomCmd {
    pub name: String,
    pub cmd: String,
}

/// Longest name accepted, in bytes of the encoded file name's input.
///
/// The name is base64-encoded into a file name, which grows it by a third and
/// shares a 255-byte budget with the order prefix. This leaves room on every
/// filesystem worth naming, and matches what the app's editor allows.
const MAX_NAME_LEN: usize = 64;

#[derive(Debug)]
pub enum Error {
    /// No home directory in the process environment, so there is no directory
    /// to speak of. A service can be started this way, and inventing one
    /// relative to the working directory would put the user's commands
    /// somewhere neither the script nor the app would look.
    NoHome,
    Invalid(String),
    Io(std::io::Error),
}

impl std::fmt::Display for Error {
    fn fmt(&self, f: &mut std::fmt::Formatter<'_>) -> std::fmt::Result {
        match self {
            Error::NoHome => write!(f, "no home directory for this process"),
            Error::Invalid(msg) => write!(f, "{msg}"),
            Error::Io(e) => write!(f, "{e}"),
        }
    }
}

impl From<std::io::Error> for Error {
    fn from(e: std::io::Error) -> Self {
        Error::Io(e)
    }
}

fn dir() -> Result<PathBuf, Error> {
    script::custom_cmd_dir_path().ok_or(Error::NoHome)
}

/// The installed commands, in file-name order — the order they run in.
///
/// A directory that does not exist reads as no commands rather than an error:
/// it is what a machine that has never had one looks like, and the panel
/// should offer to add the first rather than report a fault.
///
/// Files that are not ours are skipped, not fatal. The directory is on
/// someone's machine and a stray file in it should not cost them the editor.
pub fn list() -> Result<Vec<CustomCmd>, Error> {
    read_dir(&dir()?)
}

fn read_dir(dir: &Path) -> Result<Vec<CustomCmd>, Error> {
    if !dir.is_dir() {
        return Ok(Vec::new());
    }
    let mut found: Vec<(String, CustomCmd)> = Vec::new();
    for entry in std::fs::read_dir(dir)? {
        let entry = entry?;
        if !entry.file_type()?.is_file() {
            continue;
        }
        let file_name = entry.file_name().to_string_lossy().into_owned();
        let Some(name) = script::custom_cmd_name_from_file(&file_name) else { continue };
        // Command text a user typed; a file that is not UTF-8 is not one of
        // ours no matter what it is called.
        let Ok(cmd) = std::fs::read_to_string(entry.path()) else { continue };
        found.push((file_name, CustomCmd { name, cmd }));
    }
    // By file name, which is what the script's own `Sort-Object Name` / glob
    // expansion does. The zero-padded order prefix makes that numeric order.
    found.sort_by(|a, b| a.0.cmp(&b.0));
    Ok(found.into_iter().map(|(_, c)| c).collect())
}

/// Replaces the directory with [`cmds`], in this order.
///
/// Written aside and moved into place, so a collection cycle landing mid-write
/// runs the old set or the new one and never half of each. The old directory
/// goes with the move, which is also how a deleted command stops running.
pub fn replace(cmds: &[CustomCmd]) -> Result<(), Error> {
    validate(cmds)?;
    write_dir(&dir()?, cmds)
}

fn write_dir(dir: &Path, cmds: &[CustomCmd]) -> Result<(), Error> {
    let tmp = dir.with_file_name(format!("{}.new", script::CUSTOM_CMD_DIR_LEAF));
    let _ = std::fs::remove_dir_all(&tmp);
    std::fs::create_dir_all(&tmp)?;

    let system = crate::monitoring::monitoring::system_type();
    let ext = script::custom_cmd_file_ext(system);
    for (i, cmd) in cmds.iter().enumerate() {
        let order = (i as u32 + 1) * script::CUSTOM_CMD_ORDER_STEP;
        let file = format!("{}{ext}", script::custom_cmd_file_name(order, &cmd.name));
        std::fs::write(tmp.join(file), &cmd.cmd)?;
    }

    let _ = std::fs::remove_dir_all(dir);
    if let Some(parent) = dir.parent() {
        std::fs::create_dir_all(parent)?;
    }
    std::fs::rename(&tmp, dir)?;
    Ok(())
}

fn validate(cmds: &[CustomCmd]) -> Result<(), Error> {
    let mut seen = std::collections::HashSet::new();
    for cmd in cmds {
        let name = cmd.name.trim();
        if name.is_empty() {
            return Err(Error::Invalid("a command name is empty".into()));
        }
        if name.len() > MAX_NAME_LEN {
            return Err(Error::Invalid(format!(
                "name '{name}' is longer than {MAX_NAME_LEN} bytes"
            )));
        }
        if name != cmd.name {
            return Err(Error::Invalid(format!("name '{name}' has surrounding whitespace")));
        }
        // One file per name: two commands sharing one would be a single file,
        // and the second would silently replace the first.
        if !seen.insert(name) {
            return Err(Error::Invalid(format!("two commands are both named '{name}'")));
        }
        if cmd.cmd.trim().is_empty() {
            return Err(Error::Invalid(format!("command '{name}' is empty")));
        }
    }
    Ok(())
}

#[cfg(test)]
mod tests {
    use super::*;

    fn cmd(name: &str, body: &str) -> CustomCmd {
        CustomCmd { name: name.to_string(), cmd: body.to_string() }
    }

    #[test]
    fn a_written_directory_reads_back_in_the_same_order() {
        let tmp = std::env::temp_dir().join("sbm_custom_cmds_roundtrip/custom_cmds");
        let _ = std::fs::remove_dir_all(tmp.parent().unwrap());
        let cmds = vec![
            cmd("zebra", "echo z"),
            cmd("alpha", "echo a\necho more"),
            // A name that has to survive being a file name, and a body that
            // would end a heredoc if any of this went through a shell.
            cmd("磁盘 / 用量", "EOF'\n df -h #"),
        ];
        write_dir(&tmp, &cmds).unwrap();

        // Insertion order, not alphabetical: the user arranged these.
        assert_eq!(read_dir(&tmp).unwrap(), cmds);
        let _ = std::fs::remove_dir_all(tmp.parent().unwrap());
    }

    #[test]
    fn a_stray_file_is_skipped_and_a_missing_directory_is_empty() {
        let tmp = std::env::temp_dir().join("sbm_custom_cmds_stray/custom_cmds");
        let _ = std::fs::remove_dir_all(tmp.parent().unwrap());
        assert!(read_dir(&tmp).unwrap().is_empty());

        write_dir(&tmp, &[cmd("ok", "echo ok")]).unwrap();
        std::fs::write(tmp.join("README"), "not ours").unwrap();
        assert_eq!(read_dir(&tmp).unwrap(), vec![cmd("ok", "echo ok")]);
        let _ = std::fs::remove_dir_all(tmp.parent().unwrap());
    }

    #[test]
    fn replacing_removes_what_is_gone() {
        let tmp = std::env::temp_dir().join("sbm_custom_cmds_replace/custom_cmds");
        let _ = std::fs::remove_dir_all(tmp.parent().unwrap());
        write_dir(&tmp, &[cmd("old", "echo old"), cmd("kept", "echo kept")]).unwrap();
        write_dir(&tmp, &[cmd("kept", "echo kept")]).unwrap();
        assert_eq!(read_dir(&tmp).unwrap(), vec![cmd("kept", "echo kept")]);
        let _ = std::fs::remove_dir_all(tmp.parent().unwrap());
    }

    #[test]
    fn duplicate_and_empty_names_are_refused() {
        assert!(validate(&[cmd("a", "x"), cmd("a", "y")]).is_err());
        assert!(validate(&[cmd("", "x")]).is_err());
        assert!(validate(&[cmd(" a", "x")]).is_err());
        assert!(validate(&[cmd("a", "  ")]).is_err());
        assert!(validate(&[cmd(&"n".repeat(MAX_NAME_LEN + 1), "x")]).is_err());
        assert!(validate(&[cmd("a", "x"), cmd("b", "y")]).is_ok());
    }
}
