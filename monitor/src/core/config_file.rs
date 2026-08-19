//! Reading and writing `config.toml` at runtime (the settings page's
//! read-modify-write path), as opposed to `config::Config::load`'s
//! startup-time layering of env vars and defaults.
//!
//! Three properties this module exists to provide:
//!
//! - **Atomic replacement.** A plain `fs::write` truncates first, so a crash
//!   or a full disk mid-write leaves a half-written config that fails to
//!   parse on the next start. Writes go to a temp file in the same directory
//!   and land via `rename`, which is atomic on POSIX — a concurrent reader
//!   sees either the whole old file or the whole new one.
//! - **Bounded backups.** Every save keeps a timestamped copy as a manual
//!   undo path, but only the newest [`MAX_BACKUPS`] are retained; they used
//!   to accumulate forever.
//! - **Diagnosable read failures.** The path is relative to the process
//!   working directory (every supported deployment sets it — see
//!   `WorkingDirectory` in `install.sh` and `WORKDIR` in the `Dockerfile`),
//!   so a read error reports the resolved directory instead of just "No such
//!   file or directory".
//!
//! Serialising concurrent writers is the caller's job: `AppState.config_write`
//! is held across the whole read-modify-write, since two handlers each doing
//! their own read-then-write would otherwise clobber each other's changes
//! even though every individual write is atomic.

use std::fs;
use std::fs::OpenOptions;
use std::io::Write;
use std::path::{Path, PathBuf};

use crate::core::config::Config;
use crate::utils::error::{MonitorError, Result};

pub const CONFIG_PATH: &str = "config.toml";

const BACKUP_PREFIX: &str = "config.toml.bak-";

/// How many timestamped backups to keep. Enough to walk back out of a few
/// consecutive bad saves; beyond that the file is better recovered from
/// whatever manages the deployment.
const MAX_BACKUPS: usize = 5;

fn config_err(msg: impl Into<String>) -> MonitorError {
    MonitorError::Config(anyhow::anyhow!(msg.into()))
}

/// Where `CONFIG_PATH` resolves to, for error messages only.
fn resolved_dir() -> String {
    std::env::current_dir()
        .map(|d| d.display().to_string())
        .unwrap_or_else(|e| format!("<unknown cwd: {e}>"))
}

/// Reads `config.toml` fresh off disk.
///
/// The settings endpoints deliberately use this instead of `AppState.config`:
/// that is an `Arc<Config>` snapshot taken at startup and kept as-is for the
/// fields that need a restart, so reading it back would show stale values
/// right after a successful save.
pub fn read() -> Result<Config> {
    let content = fs::read_to_string(CONFIG_PATH).map_err(|e| {
        config_err(format!(
            "Failed to read {CONFIG_PATH} (working directory: {}): {e}",
            resolved_dir()
        ))
    })?;
    toml::from_str(&content).map_err(|e| config_err(format!("Failed to parse {CONFIG_PATH}: {e}")))
}

/// Serialises [`Config`], backs up the current file, and replaces it atomically.
pub fn write(config: &Config) -> Result<()> {
    let content = toml::to_string_pretty(config)
        .map_err(|e| config_err(format!("Failed to serialize config: {e}")))?;

    let path = Path::new(CONFIG_PATH);
    let dir = path.parent().filter(|p| !p.as_os_str().is_empty());

    // Best-effort: a failed backup must not block the save itself, but it is
    // worth a warning since it removes the undo path for this change.
    if let Ok(existing) = fs::read(path) {
        match backup_path() {
            Ok(backup) => {
                if let Err(e) = write_private_new(&backup, &existing) {
                    tracing::warn!("Failed to back up {CONFIG_PATH} before saving: {e}");
                } else {
                    prune_backups(dir);
                }
            }
            Err(e) => tracing::warn!("Failed to name a backup for {CONFIG_PATH}: {e}"),
        }
    }

    write_atomic(path, content.as_bytes())
}

/// Millisecond precision so two saves within the same second can't collide on
/// one filename. Legacy second-precision backups from before this module are
/// still pruned correctly — [`prune_backups`] orders by mtime, not by name.
fn backup_path() -> Result<PathBuf> {
    let stamp = chrono::Utc::now().timestamp_millis();
    Ok(PathBuf::from(format!("{BACKUP_PREFIX}{stamp}")))
}

fn write_atomic(path: &Path, bytes: &[u8]) -> Result<()> {
    // Same directory as the target: `rename` is only atomic within a
    // filesystem, and a temp dir may well be on another one.
    let tmp = path.with_extension(format!(
        "tmp-{}-{}",
        std::process::id(),
        chrono::Utc::now().timestamp_nanos_opt().unwrap_or_default()
    ));

    let mut file = private_options()
        .create_new(true)
        .open(&tmp)
        .map_err(|e| {
        config_err(format!("Failed to create temp file {}: {e}", tmp.display()))
    })?;
    let written = file
        .write_all(bytes)
        // fsync before rename: rename only orders the directory entry, it
        // does not flush the new file's contents.
        .and_then(|()| file.sync_all());
    if let Err(e) = written {
        let _ = fs::remove_file(&tmp);
        return Err(config_err(format!(
            "Failed to write temp file {}: {e}",
            tmp.display()
        )));
    }
    drop(file);

    fs::rename(&tmp, path).map_err(|e| {
        let _ = fs::remove_file(&tmp);
        config_err(format!(
            "Failed to replace {} with {}: {e}",
            path.display(),
            tmp.display()
        ))
    })
}

fn private_options() -> OpenOptions {
    let mut options = OpenOptions::new();
    options.write(true);
    #[cfg(unix)]
    {
        use std::os::unix::fs::OpenOptionsExt;
        options.mode(0o600);
    }
    options
}

fn write_private_new(path: &Path, bytes: &[u8]) -> std::io::Result<()> {
    let mut file = private_options().create_new(true).open(path)?;
    file.write_all(bytes)?;
    file.sync_all()
}

/// Deletes all but the [`MAX_BACKUPS`] most recent backups.
///
/// Ordered by mtime rather than by the timestamp in the name: the name format
/// changed (seconds to milliseconds) and parsing it would silently misorder
/// the two generations against each other.
fn prune_backups(dir: Option<&Path>) {
    let dir = dir.unwrap_or_else(|| Path::new("."));
    let Ok(entries) = fs::read_dir(dir) else { return };

    let mut backups: Vec<(std::time::SystemTime, PathBuf)> = entries
        .flatten()
        .filter(|e| {
            e.file_name()
                .to_str()
                .is_some_and(|n| n.starts_with(BACKUP_PREFIX))
        })
        .filter_map(|e| {
            let modified = e.metadata().and_then(|m| m.modified()).ok()?;
            Some((modified, e.path()))
        })
        .collect();

    if backups.len() <= MAX_BACKUPS {
        return;
    }

    backups.sort_by_key(|backup| std::cmp::Reverse(backup.0));
    for (_, stale) in backups.into_iter().skip(MAX_BACKUPS) {
        if let Err(e) = fs::remove_file(&stale) {
            tracing::warn!("Failed to prune old config backup {}: {e}", stale.display());
        }
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    use std::io::Write;

    /// Each test gets its own directory and runs with it as the working
    /// directory, because `CONFIG_PATH` is deliberately relative. Cargo runs
    /// tests in one process, so the chdir is guarded by a mutex.
    fn with_temp_cwd<T>(f: impl FnOnce(&Path) -> T) -> T {
        use std::sync::{Mutex, OnceLock};
        static CWD_LOCK: OnceLock<Mutex<()>> = OnceLock::new();
        let _guard = CWD_LOCK.get_or_init(|| Mutex::new(())).lock().unwrap_or_else(|e| e.into_inner());

        let dir = std::env::temp_dir().join(format!(
            "sbm-config-test-{}-{}",
            std::process::id(),
            chrono::Utc::now().timestamp_nanos_opt().unwrap_or_default()
        ));
        fs::create_dir_all(&dir).unwrap();
        let previous = std::env::current_dir().unwrap();
        std::env::set_current_dir(&dir).unwrap();

        let result = f(&dir);

        std::env::set_current_dir(previous).unwrap();
        let _ = fs::remove_dir_all(&dir);
        result
    }

    fn minimal_config() -> Config {
        toml::from_str("").expect("an empty config.toml is valid; every field is optional")
    }

    #[test]
    fn read_error_names_the_working_directory() {
        with_temp_cwd(|dir| {
            let err = read().expect_err("no config.toml exists in a fresh directory");
            let msg = err.to_string();
            assert!(
                msg.contains(&dir.display().to_string()),
                "read error should name the resolved cwd, got: {msg}"
            );
        });
    }

    #[test]
    fn write_leaves_no_temp_file_behind() {
        with_temp_cwd(|dir| {
            write(&minimal_config()).unwrap();
            assert!(Path::new(CONFIG_PATH).exists());

            let leftovers: Vec<_> = fs::read_dir(dir)
                .unwrap()
                .flatten()
                .map(|e| e.file_name().to_string_lossy().into_owned())
                .filter(|n| n.contains("tmp-"))
                .collect();
            assert!(leftovers.is_empty(), "temp files left behind: {leftovers:?}");
        });
    }

    #[test]
    fn write_round_trips_through_read() {
        with_temp_cwd(|_| {
            let mut config = minimal_config();
            let mut server = config.get_server();
            server.card_order = vec!["cpu".into(), "memory".into()];
            config.server = Some(server);

            write(&config).unwrap();
            let read_back = read().unwrap();
            assert_eq!(read_back.get_server().card_order, vec!["cpu", "memory"]);
        });
    }

    #[cfg(unix)]
    #[test]
    fn config_and_backups_are_owner_only() {
        use std::os::unix::fs::PermissionsExt;

        with_temp_cwd(|dir| {
            write(&minimal_config()).unwrap();
            write(&minimal_config()).unwrap();

            let config_mode = fs::metadata(CONFIG_PATH).unwrap().permissions().mode() & 0o777;
            assert_eq!(config_mode, 0o600);

            let backup = fs::read_dir(dir)
                .unwrap()
                .flatten()
                .find(|entry| {
                    entry
                        .file_name()
                        .to_str()
                        .is_some_and(|name| name.starts_with(BACKUP_PREFIX))
                })
                .expect("the second save creates a backup");
            let backup_mode = backup.metadata().unwrap().permissions().mode() & 0o777;
            assert_eq!(backup_mode, 0o600);
        });
    }

    #[test]
    fn backups_are_capped_and_keep_the_newest() {
        with_temp_cwd(|dir| {
            // Legacy second-precision names, deliberately mixed in: pruning
            // orders by mtime so both naming generations sort together.
            for (i, name) in ["config.toml.bak-1700000000", "config.toml.bak-1700000001"]
                .iter()
                .enumerate()
            {
                let mut f = fs::File::create(dir.join(name)).unwrap();
                write!(f, "legacy {i}").unwrap();
            }

            for i in 0..MAX_BACKUPS + 3 {
                let mut config = minimal_config();
                // Any field that lands in the written file will do; this one
                // is a `[server]` key, so the section has to exist first —
                // `minimal_config` is an empty file, where it does not.
                config.server.get_or_insert_default().name = Some(format!("save-{i}"));
                write(&config).unwrap();
                // mtime resolution can be coarse; keep the ordering unambiguous
                std::thread::sleep(std::time::Duration::from_millis(10));
            }

            let backups: Vec<_> = fs::read_dir(dir)
                .unwrap()
                .flatten()
                .map(|e| e.file_name().to_string_lossy().into_owned())
                .filter(|n| n.starts_with(BACKUP_PREFIX))
                .collect();
            assert_eq!(
                backups.len(),
                MAX_BACKUPS,
                "expected exactly {MAX_BACKUPS} backups, got {backups:?}"
            );
            assert!(
                !backups.iter().any(|n| n.ends_with("1700000000")),
                "the oldest legacy backup should have been pruned: {backups:?}"
            );
        });
    }
}
