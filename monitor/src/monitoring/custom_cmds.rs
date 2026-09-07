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

use std::{
    fs::OpenOptions,
    path::{Path, PathBuf},
};

use fs2::FileExt;
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
    /// The directory is not what the caller read. See [`Listing::fingerprint`].
    Conflict,
    Io(std::io::Error),
}

impl std::fmt::Display for Error {
    fn fmt(&self, f: &mut std::fmt::Formatter<'_>) -> std::fmt::Result {
        match self {
            Error::NoHome => write!(f, "no home directory for this process"),
            Error::Invalid(msg) => write!(f, "{msg}"),
            Error::Conflict => write!(
                f,
                "the custom commands changed since they were loaded; reload and try again"
            ),
            Error::Io(e) => write!(f, "{e}"),
        }
    }
}

/// One reading of the directory.
#[derive(Debug, Clone, PartialEq, Eq)]
pub struct Listing {
    pub commands: Vec<CustomCmd>,
    /// What the directory held when this was read.
    ///
    /// A write replaces the whole set, so two clients editing the same machine
    /// would each send their own copy and the second would silently discard
    /// the first's edits. Handing this back to [`replace`] refuses that write
    /// instead.
    ///
    /// Only ever compared with another value from this function. The app
    /// reaches the same directory over SSH and computes its own fingerprint in
    /// the shell (`sbm_parser::script`); the two are different values of the
    /// same directory and never meet, because each client checks against what
    /// it read itself.
    pub fingerprint: String,
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
pub fn list() -> Result<Listing, Error> {
    listing(&dir()?)
}

fn listing(dir: &Path) -> Result<Listing, Error> {
    let commands = read_dir(dir)?;
    Ok(Listing {
        fingerprint: fingerprint(&commands),
        commands,
    })
}

/// Length-prefixed rather than delimited: a name and a body are both arbitrary
/// text, and a separator either of them could contain would let two different
/// sets hash the same.
fn fingerprint(commands: &[CustomCmd]) -> String {
    use sha2::Digest;

    let mut hasher = sha2::Sha256::new();
    for command in commands {
        for part in [&command.name, &command.cmd] {
            hasher.update((part.len() as u64).to_le_bytes());
            hasher.update(part.as_bytes());
        }
    }
    hasher
        .finalize()
        .iter()
        .map(|b| format!("{b:02x}"))
        .collect()
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
        let Some(name) = script::custom_cmd_name_from_file_for_current_platform(&file_name) else {
            continue;
        };
        // Command text a user typed; a file that is not UTF-8 is not one of
        // ours no matter what it is called.
        let Ok(cmd) = std::fs::read_to_string(entry.path()) else {
            continue;
        };
        found.push((file_name, CustomCmd { name, cmd }));
    }
    // By file name, which is what the script's own `Sort-Object Name` / glob
    // expansion does. The zero-padded order prefix makes that numeric order.
    found.sort_by(|a, b| a.0.cmp(&b.0));
    Ok(found.into_iter().map(|(_, c)| c).collect())
}

/// Replaces the directory with [`cmds`], in this order.
///
/// Written aside and installed with a rollback directory. A crash after the
/// old directory moves aside is repaired before the next write, so an aborted
/// update cannot permanently erase the user's commands.
///
/// `expect` is the [`Listing::fingerprint`] the caller edited from, checked
/// under the same lock the write takes. `None` skips the check — right only
/// for a caller that never read the directory.
pub fn replace(cmds: &[CustomCmd], expect: Option<&str>) -> Result<(), Error> {
    validate(cmds)?;
    write_dir(&dir()?, cmds, expect)
}

fn write_dir(dir: &Path, cmds: &[CustomCmd], expect: Option<&str>) -> Result<(), Error> {
    // The side paths are fixed per directory. Keep the advisory lock through
    // recovery and replacement so concurrent processes cannot reuse them.
    let _lock = replace_lock(dir)?;
    let tmp = side_path(dir, "new");
    let backup = side_path(dir, "old");
    if let Some(parent) = dir.parent() {
        std::fs::create_dir_all(parent)?;
    }
    recover_interrupted_replace(dir, &backup)?;
    // Under the lock and after recovery, so what is compared is the directory
    // this write is about to replace rather than one another writer was still
    // installing.
    if let Some(expect) = expect
        && listing(dir)?.fingerprint != expect
    {
        return Err(Error::Conflict);
    }
    let _ = std::fs::remove_dir_all(&tmp);
    if let Err(error) = std::fs::create_dir_all(&tmp) {
        let _ = std::fs::remove_dir_all(&tmp);
        return Err(Error::Io(error));
    }

    let system = crate::monitoring::system_type();
    let ext = script::custom_cmd_file_ext(system);
    for (i, cmd) in cmds.iter().enumerate() {
        let order = (i as u32 + 1) * script::CUSTOM_CMD_ORDER_STEP;
        let file = format!("{}{ext}", script::custom_cmd_file_name(order, &cmd.name));
        if let Err(error) = std::fs::write(tmp.join(file), &cmd.cmd) {
            let _ = std::fs::remove_dir_all(&tmp);
            return Err(Error::Io(error));
        }
    }

    if dir.exists() {
        if let Err(error) = std::fs::rename(dir, &backup) {
            let _ = std::fs::remove_dir_all(&tmp);
            return Err(Error::Io(error));
        }
        if let Err(error) = std::fs::rename(&tmp, dir) {
            if let Err(restore_error) = std::fs::rename(&backup, dir) {
                return Err(Error::Io(std::io::Error::other(format!(
                    "failed to install {}: {error}; failed to restore {}: {restore_error}",
                    dir.display(),
                    backup.display(),
                ))));
            }
            return Err(Error::Io(error));
        }
    } else {
        std::fs::rename(&tmp, dir)?;
    }
    if let Err(error) = std::fs::remove_dir_all(&backup)
        && error.kind() != std::io::ErrorKind::NotFound
    {
        // The new directory is already installed. Leaving an old backup is
        // safe and lets the next update clean it up; failing the save here
        // would misleadingly tell the caller its commands were not applied.
        tracing::warn!(
            "Failed to remove old custom commands at {}: {error}",
            backup.display()
        );
    }
    Ok(())
}

fn replace_lock(dir: &Path) -> Result<std::fs::File, Error> {
    if let Some(parent) = dir.parent() {
        std::fs::create_dir_all(parent)?;
    }
    let lock = OpenOptions::new()
        .read(true)
        .write(true)
        .create(true)
        .truncate(false)
        .open(side_path(dir, "lock"))?;
    lock.lock_exclusive()?;
    Ok(lock)
}

fn side_path(dir: &Path, suffix: &str) -> PathBuf {
    let leaf = dir
        .file_name()
        .unwrap_or_else(|| script::CUSTOM_CMD_DIR_LEAF.as_ref());
    dir.with_file_name(format!("{}.{}", leaf.to_string_lossy(), suffix))
}

fn recover_interrupted_replace(dir: &Path, backup: &Path) -> Result<(), Error> {
    if !backup.exists() {
        return Ok(());
    }
    if !dir.exists() {
        std::fs::rename(backup, dir)?;
    } else if let Err(error) = std::fs::remove_dir_all(backup)
        && error.kind() != std::io::ErrorKind::NotFound
    {
        return Err(Error::Io(error));
    }
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
            return Err(Error::Invalid(format!(
                "name '{name}' has surrounding whitespace"
            )));
        }
        // One file per name: two commands sharing one would be a single file,
        // and the second would silently replace the first.
        if !seen.insert(name) {
            return Err(Error::Invalid(format!(
                "two commands are both named '{name}'"
            )));
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
    use std::sync::Arc;

    fn cmd(name: &str, body: &str) -> CustomCmd {
        CustomCmd {
            name: name.to_string(),
            cmd: body.to_string(),
        }
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
        write_dir(&tmp, &cmds, None).unwrap();

        // Insertion order, not alphabetical: the user arranged these.
        assert_eq!(read_dir(&tmp).unwrap(), cmds);
        let _ = std::fs::remove_dir_all(tmp.parent().unwrap());
    }

    #[test]
    fn a_stray_file_is_skipped_and_a_missing_directory_is_empty() {
        let tmp = std::env::temp_dir().join("sbm_custom_cmds_stray/custom_cmds");
        let _ = std::fs::remove_dir_all(tmp.parent().unwrap());
        assert!(read_dir(&tmp).unwrap().is_empty());

        write_dir(&tmp, &[cmd("ok", "echo ok")], None).unwrap();
        std::fs::write(tmp.join("README"), "not ours").unwrap();
        assert_eq!(read_dir(&tmp).unwrap(), vec![cmd("ok", "echo ok")]);
        let _ = std::fs::remove_dir_all(tmp.parent().unwrap());
    }

    #[test]
    fn replacing_removes_what_is_gone() {
        let tmp = std::env::temp_dir().join("sbm_custom_cmds_replace/custom_cmds");
        let _ = std::fs::remove_dir_all(tmp.parent().unwrap());
        write_dir(&tmp, &[cmd("old", "echo old"), cmd("kept", "echo kept")], None).unwrap();
        write_dir(&tmp, &[cmd("kept", "echo kept")], None).unwrap();
        assert_eq!(read_dir(&tmp).unwrap(), vec![cmd("kept", "echo kept")]);
        let _ = std::fs::remove_dir_all(tmp.parent().unwrap());
    }

    #[test]
    fn an_interrupted_replace_recovers_the_old_directory() {
        let tmp = std::env::temp_dir().join("sbm_custom_cmds_recovery/custom_cmds");
        let parent = tmp.parent().unwrap();
        let _ = std::fs::remove_dir_all(parent);
        write_dir(&tmp, &[cmd("old", "echo old")], None).unwrap();

        let backup = side_path(&tmp, "old");
        std::fs::rename(&tmp, &backup).unwrap();
        recover_interrupted_replace(&tmp, &backup).unwrap();

        assert_eq!(read_dir(&tmp).unwrap(), vec![cmd("old", "echo old")]);
        assert!(!backup.exists());
        let _ = std::fs::remove_dir_all(parent);
    }

    /// Two panels editing one machine: the second save is refused rather than
    /// discarding the first's edits, and the fingerprint it reloads then works.
    #[test]
    fn a_stale_expectation_is_refused() {
        let tmp = std::env::temp_dir().join("sbm_custom_cmds_cas/custom_cmds");
        let _ = std::fs::remove_dir_all(tmp.parent().unwrap());

        let empty = listing(&tmp).unwrap().fingerprint;
        write_dir(&tmp, &[cmd("a", "echo a")], Some(&empty)).unwrap();

        let loaded = listing(&tmp).unwrap();
        assert_ne!(loaded.fingerprint, empty, "the directory changed");

        // Somebody else saved in between.
        write_dir(&tmp, &[cmd("a", "echo a"), cmd("b", "echo b")], None).unwrap();
        assert!(matches!(
            write_dir(&tmp, &[cmd("a", "mine")], Some(&loaded.fingerprint)),
            Err(Error::Conflict)
        ));
        assert_eq!(
            read_dir(&tmp).unwrap(),
            vec![cmd("a", "echo a"), cmd("b", "echo b")],
            "a refused write must change nothing"
        );

        let reloaded = listing(&tmp).unwrap().fingerprint;
        write_dir(&tmp, &[cmd("a", "mine")], Some(&reloaded)).unwrap();
        assert_eq!(read_dir(&tmp).unwrap(), vec![cmd("a", "mine")]);
        let _ = std::fs::remove_dir_all(tmp.parent().unwrap());
    }

    /// Order is part of what is stored, so a reorder has to be a change.
    #[test]
    fn a_fingerprint_covers_order_names_and_bodies() {
        let a = CustomCmd { name: "a".into(), cmd: "x".into() };
        let b = CustomCmd { name: "b".into(), cmd: "y".into() };
        assert_ne!(fingerprint(&[a.clone(), b.clone()]), fingerprint(&[b, a.clone()]));
        assert_ne!(
            fingerprint(&[a.clone()]),
            fingerprint(&[CustomCmd { name: "a".into(), cmd: "z".into() }])
        );
        // Length-prefixed, so no pair of concatenations can collide.
        assert_ne!(
            fingerprint(&[CustomCmd { name: "ab".into(), cmd: "c".into() }]),
            fingerprint(&[CustomCmd { name: "a".into(), cmd: "bc".into() }])
        );
        assert_eq!(fingerprint(&[a.clone()]), fingerprint(&[a]));
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

    #[test]
    fn concurrent_replacements_leave_one_complete_directory() {
        let tmp = std::env::temp_dir().join(format!(
            "sbm_custom_cmds_concurrent_{}_{}",
            std::process::id(),
            std::time::SystemTime::now()
                .duration_since(std::time::UNIX_EPOCH)
                .unwrap()
                .as_nanos()
        ));
        let dir = tmp.join("custom_cmds");
        let first = vec![cmd("first", "echo first")];
        let second = vec![cmd("second", "echo second")];
        let gate = Arc::new(std::sync::Barrier::new(2));
        let worker_dir = dir.clone();
        let worker_gate = Arc::clone(&gate);
        let worker = std::thread::spawn(move || {
            worker_gate.wait();
            write_dir(&worker_dir, &first, None)
        });

        gate.wait();
        write_dir(&dir, &second, None).unwrap();
        worker.join().unwrap().unwrap();

        let current = read_dir(&dir).unwrap();
        assert!(
            current == vec![cmd("first", "echo first")]
                || current == vec![cmd("second", "echo second")]
        );
        assert!(!side_path(&dir, "new").exists());
        assert!(!side_path(&dir, "old").exists());
        let _ = std::fs::remove_dir_all(tmp);
    }
}
