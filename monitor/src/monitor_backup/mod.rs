//! Backups of this monitor's own settings to a WebDAV folder (issue #1771).
//!
//! What a backup holds is `snapshot`: the settings tables, the files they
//! name and `config.toml`, never history. Each one is a `tar.gz` encrypted
//! with age to an X25519 key whose secret half lives only in the folder,
//! encrypted with the operator's passphrase (`serverbox-monitor-key-<id>.age`).
//! The monitor keeps the public half, so it backs up unattended and cannot read
//! its own backups; restoring takes the passphrase. Both files are plain age:
//! `age -d` reads them without ServerBox.
//!
//! Every [`CHECK_EVERY`] the settings are hashed (`snapshot::digest`); a
//! backup is made when what matters changed, or once a day when only what
//! changes on its own did. The newest `keep` stay; a failure is said on the
//! desk and through the push channels once per cause.

pub mod snapshot;
pub mod webdav;

use std::path::{Path, PathBuf};
use std::sync::Arc;
use std::sync::atomic::{AtomicBool, AtomicU64, Ordering};
use std::time::Duration;

use age::secrecy::{ExposeSecret, SecretString};
use serde::{Deserialize, Serialize};
use sha2::{Digest as _, Sha256};
use sqlx::SqlitePool;
use tokio::sync::Notify;
use zeroize::Zeroizing;

use crate::api::desk::{Level, Source};
use crate::api::server::AppState;
use crate::core::blobs::Blobs;
use crate::db::sealed::{self, Sealer};
use crate::stacks::Refusal;
use webdav::{Dav, DavError};

/// The largest backup made or read.
pub const MAX_BYTES: u64 = 100 << 20;
/// The shortest passphrase taken: it is what stands between whoever can read
/// the folder and every backup, offline.
pub const MIN_PASSPHRASE: usize = 12;
const MAX_PASSPHRASE: usize = 1024;
const CHECK_EVERY: Duration = Duration::from_secs(600);
const MAX_KEEP: i64 = 100;
const BACKUP_PREFIX: &str = "serverbox-monitor-";
const BACKUP_SUFFIX: &str = ".tar.gz.age";
const KEY_PREFIX: &str = "serverbox-monitor-key-";
const KEY_SUFFIX: &str = ".age";
/// A backup's time in its name: milliseconds, so two made within a second
/// are two files, and names sort as times do.
const NAME_TIME: &str = "%Y%m%dT%H%M%S%.3fZ";
/// The largest key file read.
const MAX_KEY_FILE: usize = 64 << 10;

fn refusal(status: u16, error: &'static str) -> Refusal {
    Refusal { status, error, field: None }
}

/// The folder's answer, as `webdav.<code>` (502).
fn dav_refusal(e: &DavError) -> Refusal {
    refusal(502, e.prefixed())
}

// -----------------------------------------------------------------------------
// Names
// -----------------------------------------------------------------------------

/// The key a recipient is named by in file names: the first 8 hex digits of
/// its SHA-256.
pub fn key_id(recipient: &str) -> String {
    hex::encode(Sha256::digest(recipient.as_bytes()))[..8].to_string()
}

/// 8 lowercase hex digits: a key id or a monitor's instance.
fn is_id(s: &str) -> bool {
    s.len() == 8 && s.bytes().all(|b| b.is_ascii_digit() || (b'a'..=b'f').contains(&b))
}

/// A new instance id for this monitor's files.
fn new_instance() -> String {
    let mut bytes = [0u8; 4];
    getrandom::fill(&mut bytes).expect("the system's random source");
    hex::encode(bytes)
}

fn key_file(instance: &str, key: &str) -> String {
    format!("{KEY_PREFIX}{instance}-{key}{KEY_SUFFIX}")
}

fn backup_file(instance: &str, at: chrono::DateTime<chrono::Utc>, key: &str) -> String {
    format!("{BACKUP_PREFIX}{instance}-{}-{key}{BACKUP_SUFFIX}", at.format(NAME_TIME))
}

/// What a backup's file name says.
#[derive(Debug, Clone, PartialEq, Eq)]
pub struct BackupName {
    /// The monitor that made it.
    pub instance: String,
    pub at: chrono::DateTime<chrono::Utc>,
    /// The key it is encrypted to.
    pub key: String,
}

impl BackupName {
    pub fn key_file(&self) -> String {
        key_file(&self.instance, &self.key)
    }
}

/// [name] read as a backup's, or `None` for any other name.
pub fn parse_backup(name: &str) -> Option<BackupName> {
    let rest = name.strip_prefix(BACKUP_PREFIX)?.strip_suffix(BACKUP_SUFFIX)?;
    let mut parts = rest.split('-');
    let (instance, at, key) = (parts.next()?, parts.next()?, parts.next()?);
    if parts.next().is_some() || !is_id(instance) || !is_id(key) {
        return None;
    }
    let at = chrono::NaiveDateTime::parse_from_str(at, NAME_TIME).ok()?.and_utc();
    Some(BackupName { instance: instance.into(), at, key: key.into() })
}

/// `(instance, key id)` of a key file's name.
fn parse_key_file(name: &str) -> Option<(&str, &str)> {
    let (instance, key) = name.strip_prefix(KEY_PREFIX)?.strip_suffix(KEY_SUFFIX)?.split_once('-')?;
    (is_id(instance) && is_id(key)).then_some((instance, key))
}

// -----------------------------------------------------------------------------
// Settings
// -----------------------------------------------------------------------------

/// The stored row (`monitor_backup`, migration 039).
#[derive(Debug, Clone, sqlx::FromRow)]
pub struct Row {
    pub instance: String,
    pub url: String,
    pub username: String,
    pub password: Option<String>,
    pub allow_insecure: bool,
    pub enabled: bool,
    pub keep: i64,
    pub recipient: Option<String>,
    pub stable_hash: Option<String>,
    pub full_hash: Option<String>,
    pub last_backup_at: Option<String>,
    pub last_name: Option<String>,
    pub last_error: Option<String>,
    pub last_error_at: Option<String>,
}

pub async fn row(db: &SqlitePool) -> sqlx::Result<Option<Row>> {
    sqlx::query_as(
        "SELECT instance, url, username, password, allow_insecure, enabled, keep, recipient, stable_hash, full_hash, \
         last_backup_at, last_name, last_error, last_error_at FROM monitor_backup WHERE id = 1",
    )
    .fetch_optional(db)
    .await
}

impl Row {
    /// The folder's client. A password the credentials key no longer opens
    /// is refused as the server would refuse it, so it is entered again.
    pub fn dav(&self, sealer: &Sealer) -> Result<Dav, DavError> {
        let folder = webdav::folder_url(&self.url, self.allow_insecure)?;
        let password = sealer.open_opt(sealed::BACKUP_PASSWORD, self.password.as_deref()).map_err(|e| {
            tracing::warn!("monitor backup: {e}");
            DavError::Unauthorized
        })?;
        Ok(Dav::new(folder, &self.username, password.as_deref()))
    }
}

/// [Row::dav]'s refusal: the stored address, or the stored password.
fn stored_refusal(e: DavError) -> Refusal {
    match e {
        DavError::InvalidUrl => refusal(400, "invalidUrl"),
        _ => refusal(400, "passwordRequired"),
    }
}

/// What the API answers: never the password.
#[derive(Debug, Clone, Serialize)]
pub struct View {
    pub configured: bool,
    pub url: Option<String>,
    pub username: Option<String>,
    pub has_password: bool,
    pub allow_insecure: bool,
    pub enabled: bool,
    pub keep: i64,
    /// The key backups are encrypted to now; none until a passphrase is set.
    pub key_id: Option<String>,
    pub last_backup_at: Option<String>,
    pub last_name: Option<String>,
    pub last_error: Option<String>,
    pub last_error_at: Option<String>,
    pub running: bool,
    pub max_bytes: u64,
    pub min_passphrase: usize,
}

pub async fn view(state: &AppState) -> View {
    let row = row(&state.db).await.ok().flatten();
    View {
        configured: row.is_some(),
        url: row.as_ref().map(|r| r.url.clone()),
        username: row.as_ref().map(|r| r.username.clone()),
        // One the credentials key no longer opens is asked for again.
        has_password: row.as_ref().is_some_and(|r| state.sealer.open_or_none(sealed::BACKUP_PASSWORD, r.password.as_deref()).is_some()),
        allow_insecure: row.as_ref().is_some_and(|r| r.allow_insecure),
        enabled: row.as_ref().is_none_or(|r| r.enabled),
        keep: row.as_ref().map_or(10, |r| r.keep),
        key_id: row.as_ref().and_then(|r| r.recipient.as_deref()).map(key_id),
        last_backup_at: row.as_ref().and_then(|r| r.last_backup_at.clone()),
        last_name: row.as_ref().and_then(|r| r.last_name.clone()),
        last_error: row.as_ref().and_then(|r| r.last_error.clone()),
        last_error_at: row.as_ref().and_then(|r| r.last_error_at.clone()),
        running: state.monitor_backup.running.load(Ordering::Relaxed),
        max_bytes: MAX_BYTES,
        min_passphrase: MIN_PASSPHRASE,
    }
}

/// A folder to back up to. `password`: absent or null keeps the stored one
/// (only for the same server), `""` removes it.
#[derive(Debug, Clone, Deserialize)]
pub struct Target {
    pub url: String,
    #[serde(default)]
    pub username: String,
    #[serde(default)]
    pub password: Option<String>,
    #[serde(default)]
    pub allow_insecure: bool,
}

#[derive(Debug, Clone, Deserialize)]
pub struct SetSettings {
    #[serde(flatten)]
    pub target: Target,
    #[serde(default = "yes")]
    pub enabled: bool,
    #[serde(default = "ten")]
    pub keep: i64,
}

fn yes() -> bool {
    true
}

fn ten() -> i64 {
    10
}

/// [target] checked, with the stored password filled in where it may be:
/// `(folder, username, password)`. A stored one the credentials key no
/// longer opens is asked for again.
fn resolve(target: &Target, stored: Option<&Row>, sealer: &Sealer) -> Result<(url::Url, String, Option<String>), Refusal> {
    let folder = webdav::folder_url(&target.url, target.allow_insecure).map_err(|_| refusal(400, "invalidUrl"))?;
    let username = target.username.trim().to_string();
    if username.len() > 256 || username.chars().any(char::is_control) || username.contains(':') {
        return Err(refusal(400, "invalidUsername"));
    }
    let password = match &target.password {
        Some(p) if p.is_empty() => None,
        Some(p) if p.len() > 1024 || p.chars().any(char::is_control) => return Err(refusal(400, "invalidPassword")),
        Some(p) => Some(p.clone()),
        None => match stored.and_then(|r| r.password.clone().map(|p| (r, p))) {
            // The stored password goes only to the server it was given for.
            Some((r, p)) => match webdav::folder_url(&r.url, r.allow_insecure) {
                Ok(old) if webdav::same_origin(&old, &folder) => {
                    Some(sealer.open(sealed::BACKUP_PASSWORD, &p).map_err(|_| refusal(400, "passwordRequired"))?)
                }
                _ => return Err(refusal(400, "passwordRequired")),
            },
            None => None,
        },
    };
    Ok((folder, username, password))
}

pub async fn set_settings(state: &AppState, next: SetSettings) -> Result<View, Refusal> {
    if !(1..=MAX_KEEP).contains(&next.keep) {
        return Err(refusal(400, "invalidKeep"));
    }
    let _lock = state.monitor_backup.lock.lock().await;
    let db_error = |e: sqlx::Error| {
        tracing::error!("monitor backup: {e}");
        refusal(500, "internal")
    };
    let stored = row(&state.db).await.map_err(db_error)?;
    let (folder, username, password) = resolve(&next.target, stored.as_ref(), &state.sealer)?;
    let password = state.sealer.seal_opt(sealed::BACKUP_PASSWORD, password.as_deref()).map_err(|e| {
        tracing::error!("monitor backup: {e}");
        refusal(500, "internal")
    })?;
    // The key lives in the folder: another folder needs a passphrase again.
    let same_folder = stored.as_ref().is_some_and(|r| webdav::folder_url(&r.url, r.allow_insecure).is_ok_and(|u| u == folder));
    // Another folder starts over: its own key, and none of the last folder's
    // state.
    sqlx::query(
        "INSERT INTO monitor_backup (id, instance, url, username, password, allow_insecure, enabled, keep, updated_at) \
         VALUES (1, ?9, ?1, ?2, ?3, ?4, ?5, ?6, ?7) \
         ON CONFLICT(id) DO UPDATE SET url = ?1, username = ?2, password = ?3, allow_insecure = ?4, enabled = ?5, keep = ?6, \
         updated_at = ?7, recipient = CASE WHEN ?8 THEN recipient END, \
         stable_hash = CASE WHEN ?8 THEN stable_hash END, full_hash = CASE WHEN ?8 THEN full_hash END, \
         last_backup_at = CASE WHEN ?8 THEN last_backup_at END, last_name = CASE WHEN ?8 THEN last_name END, \
         last_error = CASE WHEN ?8 THEN last_error END, last_error_at = CASE WHEN ?8 THEN last_error_at END",
    )
    .bind(folder.as_str())
    .bind(&username)
    .bind(&password)
    .bind(next.target.allow_insecure)
    .bind(next.enabled)
    .bind(next.keep)
    .bind(chrono::Utc::now().to_rfc3339())
    .bind(same_folder)
    .bind(new_instance())
    .execute(&state.db)
    .await
    .map_err(db_error)?;
    if same_folder && stored.as_ref().is_some_and(|r| next.keep < r.keep) {
        state.monitor_backup.prune_due.store(true, Ordering::Relaxed);
    }
    drop(_lock);
    state.monitor_backup.wake();
    Ok(view(state).await)
}

/// Backs up to [folder] with [fetched]'s key from now on: what a restore on a
/// new machine (the CLI) leaves, so it carries on that monitor's backups as
/// that monitor. A machine with backup settings of its own keeps them all:
/// the other's instance, while that one still runs, would have each prune the
/// other's backups, and its key alone names a key file under the other's
/// instance. Answers whether it was adopted.
pub async fn adopt(db: &SqlitePool, sealer: &Sealer, folder: &url::Url, username: &str, password: Option<&str>, allow_insecure: bool, fetched: &Fetched) -> sqlx::Result<bool> {
    let done = sqlx::query(
        "INSERT INTO monitor_backup (id, instance, url, username, password, allow_insecure, recipient, updated_at) \
         VALUES (1, ?7, ?1, ?2, ?3, ?4, ?5, ?6) ON CONFLICT(id) DO NOTHING",
    )
    .bind(folder.as_str())
    .bind(username)
    .bind(sealer.seal_opt(sealed::BACKUP_PASSWORD, password)?)
    .bind(allow_insecure)
    .bind(&fetched.recipient)
    .bind(chrono::Utc::now().to_rfc3339())
    .bind(&fetched.name.instance)
    .execute(db)
    .await?;
    Ok(done.rows_affected() > 0)
}

/// Removes the settings; what is in the folder stays.
pub async fn remove_settings(state: &AppState) -> Result<(), Refusal> {
    let _lock = state.monitor_backup.lock.lock().await;
    sqlx::query("DELETE FROM monitor_backup").execute(&state.db).await.map_err(|e| {
        tracing::error!("monitor backup: {e}");
        refusal(500, "internal")
    })?;
    Ok(())
}

/// What the folder answered a test with.
#[derive(Debug, Serialize)]
pub struct Probe {
    /// The folder is not there yet; the first backup makes it.
    pub missing: bool,
    pub backups: usize,
}

pub async fn test(state: &AppState, target: &Target) -> Result<Probe, Refusal> {
    let stored = row(&state.db).await.ok().flatten();
    let (folder, username, password) = resolve(target, stored.as_ref(), &state.sealer)?;
    let dav = Dav::new(folder, &username, password.as_deref());
    match dav.list().await {
        Ok(entries) => Ok(Probe { missing: false, backups: entries.iter().filter(|e| parse_backup(&e.name).is_some()).count() }),
        Err(DavError::NotFound) => Ok(Probe { missing: true, backups: 0 }),
        Err(e) => Err(dav_refusal(&e)),
    }
}

// -----------------------------------------------------------------------------
// Keys
// -----------------------------------------------------------------------------

fn check_passphrase(passphrase: &str) -> Result<(), Refusal> {
    let n = passphrase.chars().count();
    if n < MIN_PASSPHRASE || passphrase.len() > MAX_PASSPHRASE {
        return Err(refusal(400, "weakPassphrase"));
    }
    Ok(())
}

/// A new key pair: `(recipient, the identity encrypted with [passphrase],
/// armored)`. scrypt at age's own work factor for this machine.
fn new_key(passphrase: &str) -> anyhow::Result<(String, Vec<u8>)> {
    let identity = age::x25519::Identity::generate();
    let recipient = identity.to_public().to_string();
    let text = Zeroizing::new(format!(
        "# ServerBox Monitor backup key, for {recipient}\n# Decrypt backups with: age -d -i <this file, decrypted> <backup>\n{}\n",
        identity.to_string().expose_secret()
    ));
    let scrypt = age::scrypt::Recipient::new(SecretString::from(passphrase.to_string()));
    let mut out = Vec::new();
    let armored = age::armor::ArmoredWriter::wrap_output(&mut out, age::armor::Format::AsciiArmor)?;
    let mut writer = age::Encryptor::with_recipients(std::iter::once(&scrypt as &dyn age::Recipient))?.wrap_output(armored)?;
    std::io::Write::write_all(&mut writer, text.as_bytes())?;
    writer.finish()?.finish()?;
    Ok((recipient, out))
}

/// The identity in a key file, opened with [passphrase].
fn open_key(file: &[u8], passphrase: &str) -> Result<age::x25519::Identity, Refusal> {
    let identity = age::scrypt::Identity::new(SecretString::from(passphrase.to_string()));
    let decryptor = age::Decryptor::new(age::armor::ArmoredReader::new(file)).map_err(|_| refusal(422, "invalidKeyFile"))?;
    let mut reader = decryptor.decrypt(std::iter::once(&identity as &dyn age::Identity)).map_err(|e| match e {
        age::DecryptError::DecryptionFailed | age::DecryptError::KeyDecryptionFailed | age::DecryptError::NoMatchingKeys => {
            refusal(400, "wrongPassphrase")
        }
        age::DecryptError::ExcessiveWork { .. } => refusal(422, "excessiveWork"),
        _ => refusal(422, "invalidKeyFile"),
    })?;
    let mut text = Zeroizing::new(String::new());
    std::io::Read::read_to_string(&mut reader, &mut text).map_err(|_| refusal(422, "invalidKeyFile"))?;
    text.lines()
        .map(str::trim)
        .find(|l| l.starts_with("AGE-SECRET-KEY-"))
        .and_then(|l| l.parse::<age::x25519::Identity>().ok())
        .ok_or_else(|| refusal(422, "invalidKeyFile"))
}

/// Sets the passphrase: a new key, its file put in the folder, backups from
/// now on to it. Older backups keep their own key file, opened with the
/// passphrase they were made under.
pub async fn set_key(state: &AppState, passphrase: &str) -> Result<View, Refusal> {
    check_passphrase(passphrase)?;
    let _lock = state.monitor_backup.lock.lock().await;
    let stored = row(&state.db).await.ok().flatten().ok_or_else(|| refusal(409, "notConfigured"))?;
    let dav = stored.dav(&state.sealer).map_err(stored_refusal)?;
    let passphrase = Zeroizing::new(passphrase.to_string());
    let (recipient, file) = tokio::task::spawn_blocking(move || new_key(&passphrase))
        .await
        .map_err(|_| refusal(500, "internal"))?
        .map_err(|e| {
            tracing::error!("monitor backup: making a key: {e:#}");
            refusal(500, "internal")
        })?;
    let id = key_id(&recipient);
    put_making_folder(&dav, &key_file(&stored.instance, &id), file).await.map_err(|e| dav_refusal(&e))?;
    sqlx::query("UPDATE monitor_backup SET recipient = ?, stable_hash = NULL, full_hash = NULL, updated_at = ? WHERE id = 1")
        .bind(&recipient)
        .bind(chrono::Utc::now().to_rfc3339())
        .execute(&state.db)
        .await
        .map_err(|_| refusal(500, "internal"))?;
    drop(_lock);
    state.monitor_backup.request_now();
    Ok(view(state).await)
}

/// Puts [bytes] as [name], making the folder first when it is not there.
/// Asked with PROPFIND: servers answer a PUT into a missing folder
/// differently (409, nginx 500).
async fn put_making_folder(dav: &Dav, name: &str, bytes: Vec<u8>) -> Result<(), DavError> {
    match dav.list().await {
        Ok(_) => {}
        Err(DavError::NotFound) => dav.make_folder().await?,
        Err(e) => return Err(e),
    }
    dav.put_bytes(name, bytes).await
}

// -----------------------------------------------------------------------------
// Backing up
// -----------------------------------------------------------------------------

static SCRATCH: AtomicU64 = AtomicU64::new(0);

/// Whether run [run]'s files are still someone's: this value's ([own]), or
/// a run whose lock file (`run-<run>.lock` in [dir]) a live process holds. A
/// lock outlives no process, so a killed run is never taken for a live one,
/// whatever reuses its PID. A run found over has its lock file removed.
fn run_live(dir: &Path, own: &str, run: &str) -> bool {
    if run == own {
        return true;
    }
    let lock = dir.join(format!("run-{run}.lock"));
    let file = match std::fs::File::open(&lock) {
        Ok(f) => f,
        Err(e) if e.kind() == std::io::ErrorKind::NotFound => return false,
        Err(_) => return true,
    };
    match file.try_lock() {
        Ok(()) => {
            drop(file);
            let _ = std::fs::remove_file(&lock);
            false
        }
        Err(_) => true,
    }
}

/// A folder of its own (0700), removed with this value.
pub struct Scratch(PathBuf);

impl Scratch {
    pub fn path(&self) -> &Path {
        &self.0
    }
}

impl Drop for Scratch {
    /// Off the async workers when there are some: it can be 200 MB of files.
    fn drop(&mut self) {
        let path = std::mem::take(&mut self.0);
        match tokio::runtime::Handle::try_current() {
            Ok(rt) => drop(rt.spawn_blocking(move || std::fs::remove_dir_all(path))),
            Err(_) => drop(std::fs::remove_dir_all(path)),
        }
    }
}

pub struct MonitorBackup {
    dir: PathBuf,
    /// One backup, key change or restore at a time.
    lock: tokio::sync::Mutex<()>,
    running: AtomicBool,
    /// A backup asked for now, changed or not.
    forced: AtomicBool,
    /// `keep` went down: the next check prunes even when nothing changed.
    prune_due: AtomicBool,
    wake: Notify,
    /// Whether a restore may restart the monitor (`utils::supervisor`); off in
    /// tests, whose process it would end.
    restart: AtomicBool,
    /// Names this value's working folders (`work-<run>-<n>`).
    run: String,
    /// `run-<run>.lock`, held while this value lives: what tells [`Self::sweep`]
    /// its folders are not a killed run's.
    held: tokio::sync::Mutex<Option<std::fs::File>>,
}

impl MonitorBackup {
    /// Its working files beside the database file [db] (a protected tree),
    /// or in the temporary directory for an in-memory database.
    pub fn new(db: Option<&Path>) -> Self {
        let dir = match db {
            Some(db) => Self::dir_beside(db),
            None => std::env::temp_dir().join(format!("sbm-monitor-backup-{}", std::process::id())),
        };
        let run = crate::utils::secrets::random_hex(8).unwrap_or_else(|_| format!("{}{}", std::process::id(), SCRATCH.fetch_add(1, Ordering::Relaxed)));
        Self {
            dir,
            lock: tokio::sync::Mutex::new(()),
            running: AtomicBool::new(false),
            forced: AtomicBool::new(false),
            prune_due: AtomicBool::new(false),
            wake: Notify::new(),
            restart: AtomicBool::new(true),
            run,
            held: tokio::sync::Mutex::new(None),
        }
    }

    pub fn dir_beside(db: &Path) -> PathBuf {
        db.parent().unwrap_or_else(|| Path::new(".")).join("monitor-backup")
    }

    pub async fn scratch(&self) -> std::io::Result<Scratch> {
        let n = SCRATCH.fetch_add(1, Ordering::Relaxed);
        let path = self.dir.join(format!("work-{}-{n}", self.run));
        let mut held = self.held.lock().await;
        // Locked before its first folder exists, for as long as this lives.
        let lock = held.is_none().then(|| self.dir.join(format!("run-{}.lock", self.run)));
        let (dir, made) = (self.dir.clone(), path.clone());
        let locked = tokio::task::spawn_blocking(move || -> std::io::Result<Option<std::fs::File>> {
            let mut builder = std::fs::DirBuilder::new();
            #[cfg(unix)]
            std::os::unix::fs::DirBuilderExt::mode(&mut builder, 0o700);
            builder.recursive(true).create(&dir)?;
            let locked = lock
                .map(|lock| {
                    let file = std::fs::OpenOptions::new().create(true).truncate(false).write(true).open(lock)?;
                    file.lock()?;
                    Ok::<_, std::io::Error>(file)
                })
                .transpose()?;
            // Its own, never one found there.
            builder.recursive(false).create(&made)?;
            Ok(locked)
        })
        .await
        .map_err(std::io::Error::other)??;
        if locked.is_some() {
            *held = locked;
        }
        Ok(Scratch(path))
    }

    /// Removes the working folders a run no longer going left (killed, or
    /// exited after a restore before its own removal ran): they hold
    /// `settings.db` unencrypted. One a running CLI is using stays.
    pub fn sweep(&self) {
        let Ok(entries) = std::fs::read_dir(&self.dir) else { return };
        for entry in entries.flatten() {
            let name = entry.file_name();
            let Some(name) = name.to_str() else { continue };
            // A run's lock alone: removed by `run_live` once no one holds it.
            if let Some(run) = name.strip_prefix("run-").and_then(|r| r.strip_suffix(".lock")) {
                run_live(&self.dir, &self.run, run);
                continue;
            }
            let Some(run) = name.strip_prefix("work-").and_then(|r| r.split('-').next()) else { continue };
            if run_live(&self.dir, &self.run, run) {
                continue;
            }
            if let Err(e) = std::fs::remove_dir_all(entry.path()) {
                tracing::warn!("monitor backup: removing {}: {e}", entry.path().display());
            }
        }
    }

    /// Checks again now.
    pub fn wake(&self) {
        self.wake.notify_one();
    }

    /// Backs up now, changed or not.
    pub fn request_now(&self) {
        self.forced.store(true, Ordering::Relaxed);
        self.wake.notify_one();
    }

    /// A restore never restarts the monitor (tests).
    pub fn never_restart(&self) {
        self.restart.store(false, Ordering::Relaxed);
    }

    pub fn is_running(&self) -> bool {
        self.running.load(Ordering::Relaxed)
    }
}

/// Why a backup was not made, by code (what the desk and the API name) and
/// what the log gets.
#[derive(Debug, Clone, PartialEq, Eq)]
pub struct Failure {
    pub code: String,
    pub detail: String,
}

impl Failure {
    fn new(code: &str, detail: impl std::fmt::Display) -> Self {
        Self { code: code.to_string(), detail: detail.to_string() }
    }

    fn dav(e: DavError) -> Self {
        Self::new(e.prefixed(), e)
    }
}

/// What a check did.
#[derive(Debug, Clone, PartialEq, Eq)]
pub enum Outcome {
    /// Nothing to back up to, or turned off.
    NotSet,
    Unchanged,
    /// Made, by its file name, and why pruning the oldest did not finish.
    Made(String, Option<Failure>),
    /// Nothing changed since a check that failed; the folder was asked again
    /// (the last backup there, the oldest pruned): why that failed, if it did.
    Checked(Option<Failure>),
}

/// What backing up needs, apart from the running monitor.
pub struct Host<'a> {
    pub db: &'a SqlitePool,
    pub sealer: &'a Sealer,
    pub blobs: &'a Blobs,
    pub work: &'a MonitorBackup,
    pub server_name: String,
}

/// One check: a backup when the settings changed (or [force]), uploaded,
/// and the oldest past `keep` removed. Records how it went.
pub async fn back_up(host: &Host<'_>, force: bool) -> Result<Outcome, Failure> {
    let _lock = host.work.lock.lock().await;
    let Some(stored) = row(host.db).await.map_err(|e| Failure::new("database", e))? else {
        return Ok(Outcome::NotSet);
    };
    let Some(recipient) = stored.recipient.clone().filter(|_| stored.enabled) else {
        return Ok(Outcome::NotSet);
    };
    host.work.running.store(true, Ordering::Relaxed);
    let result = make(host, &stored, &recipient, force).await;
    host.work.running.store(false, Ordering::Relaxed);
    let now = chrono::Utc::now();
    let _ = match &result {
        // Uploaded: what it holds is recorded whatever the pruning after it
        // did, so a folder that refuses deletes is not sent a new backup at
        // every check.
        Ok((Outcome::Made(name, pruned), digest)) => {
            sqlx::query(
                "UPDATE monitor_backup SET stable_hash = ?, full_hash = ?, last_backup_at = ?, last_name = ?, last_error = ?, \
                 last_error_at = ? WHERE id = 1",
            )
            .bind(&digest.stable)
            .bind(&digest.full)
            .bind(now.to_rfc3339())
            .bind(name)
            .bind(pruned.as_ref().map(|f| &f.code))
            .bind(pruned.as_ref().map(|_| now.to_rfc3339()))
            .execute(host.db)
            .await
        }
        Ok((Outcome::Checked(pruned), _)) => {
            sqlx::query("UPDATE monitor_backup SET last_error = ?, last_error_at = ? WHERE id = 1")
                .bind(pruned.as_ref().map(|f| &f.code))
                .bind(pruned.as_ref().map(|_| now.to_rfc3339()))
                .execute(host.db)
                .await
        }
        // Nothing was asked of the folder: what it said last stands.
        Ok(_) => Ok(Default::default()),
        Err(f) => {
            sqlx::query("UPDATE monitor_backup SET last_error = ?, last_error_at = ? WHERE id = 1")
                .bind(&f.code)
                .bind(now.to_rfc3339())
                .execute(host.db)
                .await
        }
    };
    result.map(|(o, _)| o)
}

async fn make(host: &Host<'_>, stored: &Row, recipient: &str, force: bool) -> Result<(Outcome, snapshot::Digest), Failure> {
    let config = match tokio::fs::read(crate::core::config_file::CONFIG_PATH).await {
        Ok(bytes) => Some(bytes),
        Err(e) if e.kind() == std::io::ErrorKind::NotFound => None,
        Err(e) => return Err(Failure::new("config", e)),
    };
    let digest = snapshot::digest(host.db, host.sealer, config.as_deref()).await.map_err(|e| Failure::new("database", e))?;
    let day_old = stored
        .last_backup_at
        .as_deref()
        .and_then(|t| chrono::DateTime::parse_from_rfc3339(t).ok())
        .is_none_or(|t| chrono::Utc::now().signed_duration_since(t) >= chrono::Duration::hours(24));
    let unchanged = stored.stable_hash.as_deref() == Some(digest.stable.as_str())
        && (stored.full_hash.as_deref() == Some(digest.full.as_str()) || !day_old);
    let prune_due = host.work.prune_due.swap(false, Ordering::Relaxed);
    if unchanged && !force && stored.last_error.is_none() && !prune_due {
        return Ok((Outcome::Unchanged, digest));
    }

    let dav = stored.dav(host.sealer).map_err(Failure::dav)?;
    let id = key_id(recipient);
    let listed = dav.list().await.map_err(Failure::dav)?;
    // Unchanged after a failure or a lower `keep`: asked again so the
    // failure shown is current and the surplus goes, and the last backup
    // sent again only if it is not there.
    if unchanged && !force && stored.last_name.as_ref().is_some_and(|n| listed.iter().any(|e| &e.name == n)) {
        let pruned = prune(&dav, &listed, stored.keep, &stored.instance, &id).await.err();
        return Ok((Outcome::Checked(pruned), digest));
    }
    // Without its key file a backup could never be read.
    if !listed.iter().any(|e| e.name == key_file(&stored.instance, &id)) {
        return Err(Failure::new("keyMissing", "the key file is not in the folder"));
    }

    let scratch = host.work.scratch().await.map_err(|e| Failure::new("io", e))?;
    let db_file = scratch.path().join(snapshot::DATABASE);
    let blobs = snapshot::write_database(host.db, host.sealer, &db_file).await.map_err(|e| Failure::new("database", format!("{e:#}")))?;
    let manifest = snapshot::Manifest {
        format: snapshot::FORMAT,
        monitor_version: env!("CARGO_PKG_VERSION").to_string(),
        migration: crate::db::database::MIGRATOR.iter().map(|m| m.version).max().unwrap_or(0),
        host: host.server_name.clone(),
        created_at: chrono::Utc::now().to_rfc3339(),
    };
    let files: Vec<(String, PathBuf)> = blobs.into_iter().filter_map(|sha| host.blobs.path(&sha).map(|p| (sha, p))).collect();
    let archive = scratch.path().join("backup.tar.gz");
    let encrypted = scratch.path().join("backup.age");
    let recipient = recipient.to_string();
    let (a, e, d) = (archive.clone(), encrypted.clone(), db_file.clone());
    tokio::task::spawn_blocking(move || -> Result<(), Failure> {
        // Measured first, so a set past the limit is never packed.
        let mut total = 0u64;
        for (_, path) in &files {
            match std::fs::metadata(path) {
                Ok(m) => total += m.len(),
                Err(e) if e.kind() == std::io::ErrorKind::NotFound => {}
                Err(e) => return Err(Failure::new("io", e)),
            }
        }
        if total > MAX_BYTES {
            return Err(Failure::new("tooLarge", "past the largest backup"));
        }
        snapshot::write_archive(&a, &manifest, config.as_deref(), &d, &files).map_err(|e| Failure::new("io", format!("{e:#}")))?;
        if std::fs::metadata(&a).map_err(|e| Failure::new("io", e))?.len() > MAX_BYTES {
            return Err(Failure::new("tooLarge", "past the largest backup"));
        }
        encrypt_file(&a, &e, &recipient).map_err(|e| Failure::new("encrypt", format!("{e:#}")))
    })
    .await
    .map_err(|e| Failure::new("internal", e))??;

    let name = backup_file(&stored.instance, chrono::Utc::now(), &id);
    dav.put_file(&name, &encrypted).await.map_err(Failure::dav)?;
    drop(scratch);
    let listed = dav.list().await.map_err(Failure::dav)?;
    if !listed.iter().any(|e| e.name == name) {
        return Err(Failure::new("uploadMissing", "the backup is not in the folder after uploading it"));
    }
    let pruned = prune(&dav, &listed, stored.keep, &stored.instance, &id).await.err();
    Ok((Outcome::Made(name, pruned), digest))
}

fn encrypt_file(input: &Path, output: &Path, recipient: &str) -> anyhow::Result<()> {
    let recipient: age::x25519::Recipient = recipient.parse().map_err(|e: &str| anyhow::anyhow!(e))?;
    let mut input = std::fs::File::open(input)?;
    let out = std::fs::File::create(output)?;
    let mut writer = age::Encryptor::with_recipients(std::iter::once(&recipient as &dyn age::Recipient))?.wrap_output(out)?;
    std::io::copy(&mut input, &mut writer)?;
    writer.finish()?.sync_all()?;
    Ok(())
}

/// Keeps this monitor's ([instance]) newest [keep] backups in [listed], and
/// removes its key files no kept backup is made with. Another monitor's files
/// in the same folder are left alone.
async fn prune(dav: &Dav, listed: &[webdav::Entry], keep: i64, instance: &str, current_key: &str) -> Result<(), Failure> {
    let mut mine: Vec<(BackupName, &str)> =
        listed.iter().filter_map(|e| parse_backup(&e.name).filter(|b| b.instance == instance).map(|b| (b, e.name.as_str()))).collect();
    mine.sort_by_key(|(b, _)| b.at);
    let cut = mine.len().saturating_sub(keep.max(1) as usize);
    for (_, old) in &mine[..cut] {
        dav.delete(old).await.map_err(Failure::dav)?;
    }
    let used: std::collections::HashSet<&str> = mine[cut..].iter().map(|(b, _)| b.key.as_str()).collect();
    for e in listed {
        if let Some((owner, key)) = parse_key_file(&e.name)
            && owner == instance
            && key != current_key
            && !used.contains(key)
        {
            dav.delete(&e.name).await.map_err(Failure::dav)?;
        }
        // An upload of ours a stop cut short.
        if e.name.starts_with(&format!("{BACKUP_PREFIX}{instance}-")) && e.name.ends_with(".part") {
            let _ = dav.delete(&e.name).await;
        }
    }
    Ok(())
}

// -----------------------------------------------------------------------------
// Listing and restoring
// -----------------------------------------------------------------------------

#[derive(Debug, Clone, Serialize)]
pub struct Listed {
    pub name: String,
    pub size: u64,
    pub created_at: String,
    pub key_id: String,
    /// The monitor that made it.
    pub instance: String,
    /// Made by this monitor.
    pub own: bool,
    /// Made by this monitor with the key backups go to now.
    pub current_key: bool,
}

/// The backups in [dav]'s folder, newest first. [own] is this monitor's
/// `(instance, recipient)`.
pub async fn list_in(dav: &Dav, own: Option<(&str, Option<&str>)>) -> Result<Vec<Listed>, DavError> {
    let current = own.and_then(|(_, r)| r).map(key_id);
    let mut out: Vec<Listed> = dav
        .list()
        .await?
        .into_iter()
        .filter_map(|e| {
            let b = parse_backup(&e.name)?;
            let mine = own.is_some_and(|(i, _)| i == b.instance);
            Some(Listed {
                name: e.name,
                size: e.size,
                created_at: b.at.to_rfc3339(),
                current_key: mine && current.as_deref() == Some(b.key.as_str()),
                own: mine,
                key_id: b.key,
                instance: b.instance,
            })
        })
        .collect();
    out.sort_by(|a, b| b.created_at.cmp(&a.created_at));
    Ok(out)
}

pub async fn list(state: &AppState) -> Result<Vec<Listed>, Refusal> {
    let stored = row(&state.db).await.ok().flatten().ok_or_else(|| refusal(409, "notConfigured"))?;
    let dav = stored.dav(&state.sealer).map_err(stored_refusal)?;
    match list_in(&dav, Some((&stored.instance, stored.recipient.as_deref()))).await {
        Ok(found) => Ok(found),
        Err(DavError::NotFound) => Ok(Vec::new()),
        Err(e) => Err(dav_refusal(&e)),
    }
}

/// A backup read back and unpacked, ready to put back.
pub struct Fetched {
    pub unpacked: snapshot::Unpacked,
    /// What its file name says.
    pub name: BackupName,
    /// The key it was made with, as its recipient (to carry on backing up to
    /// it after a restore on a new machine).
    pub recipient: String,
    _scratch: Scratch,
}

/// Downloads [name] from [dav], opens its key with [passphrase] and unpacks
/// it. Nothing is changed.
pub async fn fetch(dav: &Dav, work: &MonitorBackup, name: &str, passphrase: &str) -> Result<Fetched, Refusal> {
    let parsed = parse_backup(name).ok_or_else(|| refusal(400, "invalidName"))?;
    let key = match dav.get_bytes(&parsed.key_file(), MAX_KEY_FILE).await {
        Ok(k) => k,
        Err(DavError::NotFound) => return Err(refusal(404, "keyMissing")),
        Err(e) => return Err(dav_refusal(&e)),
    };
    let passphrase = Zeroizing::new(passphrase.to_string());
    let identity = tokio::task::spawn_blocking(move || open_key(&key, &passphrase)).await.map_err(|_| refusal(500, "internal"))??;
    let recipient = identity.to_public().to_string();
    let scratch = work.scratch().await.map_err(|_| refusal(500, "internal"))?;
    let encrypted = scratch.path().join("backup.age");
    match dav.get_file(name, &encrypted, MAX_BYTES + (1 << 20)).await {
        Ok(()) => {}
        Err(DavError::NotFound) => return Err(refusal(404, "notFound")),
        Err(DavError::TooLarge) => return Err(refusal(422, "tooLarge")),
        Err(e) => return Err(dav_refusal(&e)),
    }
    let dir = scratch.path().to_path_buf();
    let unpacked = tokio::task::spawn_blocking(move || -> Result<snapshot::Unpacked, Refusal> {
        let archive = dir.join("backup.tar.gz");
        decrypt_file(&encrypted, &archive, &identity)?;
        let out = dir.join("unpacked");
        std::fs::create_dir(&out).map_err(|_| refusal(500, "internal"))?;
        snapshot::unpack(&archive, &out).map_err(|e| {
            tracing::warn!("monitor backup: {e}");
            refusal(422, "invalidBackup")
        })
    })
    .await
    .map_err(|_| refusal(500, "internal"))??;
    Ok(Fetched { unpacked, name: parsed, recipient, _scratch: scratch })
}

fn decrypt_file(input: &Path, output: &Path, identity: &age::x25519::Identity) -> Result<(), Refusal> {
    let input = std::fs::File::open(input).map_err(|_| refusal(500, "internal"))?;
    let decryptor = age::Decryptor::new(std::io::BufReader::new(input)).map_err(|_| refusal(422, "invalidBackup"))?;
    let mut reader = decryptor.decrypt(std::iter::once(identity as &dyn age::Identity)).map_err(|e| match e {
        age::DecryptError::NoMatchingKeys => refusal(422, "wrongKey"),
        _ => refusal(422, "invalidBackup"),
    })?;
    let mut out = std::fs::File::create(output).map_err(|_| refusal(500, "internal"))?;
    std::io::copy(&mut reader, &mut out).map_err(|_| refusal(422, "invalidBackup"))?;
    Ok(())
}

/// Puts [fetched] back into [db] and `config.toml` (under [config_lock]).
/// [create_config]: a `config.toml` missing from the working directory is
/// made from defaults and the backup's. The agent's own directory, where one
/// configured by its environment alone has none; never a CLI's, which may be
/// run anywhere.
pub async fn apply(db: &SqlitePool, sealer: &Sealer, blobs: &Blobs, config_lock: &tokio::sync::Mutex<()>, fetched: &Fetched, create_config: bool) -> Result<snapshot::Restored, Refusal> {
    let mut restored = snapshot::restore_database(db, sealer, blobs, &fetched.unpacked).await.map_err(|e| match e {
        snapshot::RestoreError::Newer => refusal(409, "backupNewer"),
        snapshot::RestoreError::Invalid(why) => {
            tracing::warn!("monitor backup: {why}");
            refusal(422, "invalidBackup")
        }
        snapshot::RestoreError::Other(e) => {
            tracing::error!("monitor backup: restoring: {e:#}");
            refusal(500, "internal")
        }
    })?;
    if let Some(bytes) = &fetched.unpacked.config {
        match std::str::from_utf8(bytes).ok().and_then(|t| toml::from_str::<crate::core::config::Config>(t).ok()) {
            Some(backup) => {
                let _lock = config_lock.lock().await;
                // Merged into this machine's file only: one that is
                // unreadable, or missing where a CLI runs (another directory,
                // maybe), would be replaced by defaults, losing its
                // addresses, TLS and limits.
                let missing = !tokio::fs::try_exists(crate::core::config_file::CONFIG_PATH).await.unwrap_or(true);
                let current = if missing && create_config {
                    Ok(crate::core::config::Config::default())
                } else {
                    crate::core::config_file::read_async().await
                };
                match current {
                    Ok(current) => match crate::core::config_file::write_async(&snapshot::merge_config(current, &backup)).await {
                        Ok(()) => restored.config = true,
                        Err(e) => tracing::error!("monitor backup: writing config.toml: {e}"),
                    },
                    Err(e) => tracing::error!("monitor backup: config.toml kept as it is: {e}"),
                }
            }
            None => tracing::warn!("monitor backup: the backup's config.toml is not one this monitor reads; kept this machine's"),
        }
    }
    Ok(restored)
}

/// Restores [name] from the folder the settings name, with [passphrase]:
/// the account's sessions end (its password is the backup's now) and the
/// monitor restarts where something will start it again.
pub async fn restore(state: &Arc<AppState>, name: &str, passphrase: &str) -> Result<(snapshot::Restored, bool), Refusal> {
    let stored = row(&state.db).await.ok().flatten().ok_or_else(|| refusal(409, "notConfigured"))?;
    let dav = stored.dav(&state.sealer).map_err(stored_refusal)?;
    let _lock = state.monitor_backup.lock.lock().await;
    let fetched = fetch(&dav, &state.monitor_backup, name, passphrase).await?;
    let restored = apply(&state.db, &state.sealer, &state.blobs, &state.config_write, &fetched, true).await?;
    state.blobs.collect_soon(&state.db);
    crate::api::authz::end_account(state, "password_changed");
    let restart = state.monitor_backup.restart.load(Ordering::Relaxed)
        && tokio::task::spawn_blocking(crate::utils::supervisor::restarts_on_exit).await.unwrap_or(false);
    if restart {
        tokio::spawn(async {
            tokio::time::sleep(Duration::from_millis(1500)).await;
            tracing::info!("monitor backup: restored; restarting");
            std::process::exit(crate::utils::supervisor::EXIT_CODE);
        });
    }
    Ok((restored, restart))
}


// -----------------------------------------------------------------------------
// The monitor's loop
// -----------------------------------------------------------------------------

/// Backs up on its own until the monitor stops.
pub async fn start(state: Arc<AppState>) {
    let sweeping = state.clone();
    let _ = tokio::task::spawn_blocking(move || sweeping.monitor_backup.sweep()).await;
    tokio::select! {
        _ = tokio::time::sleep(Duration::from_secs(60)) => {}
        _ = state.monitor_backup.wake.notified() => {}
    }
    loop {
        let force = state.monitor_backup.forced.swap(false, Ordering::Relaxed);
        check(&state, force).await;
        tokio::select! {
            _ = tokio::time::sleep(CHECK_EVERY) => {}
            _ = state.monitor_backup.wake.notified() => {}
        }
    }
}

/// One check, said on the desk when it starts failing and when it works
/// again.
pub async fn check(state: &AppState, force: bool) {
    let before = row(&state.db).await.ok().flatten().and_then(|r| r.last_error);
    let host = Host { db: &state.db, sealer: &state.sealer, blobs: &state.blobs, work: &state.monitor_backup, server_name: state.config.get_server_name() };
    match back_up(&host, force).await {
        Ok(Outcome::Made(name, Some(f))) => {
            tracing::warn!("monitor backup: uploaded {name}; pruning: {}: {}", f.code, f.detail);
            failed(state, before.as_deref(), &f).await;
        }
        Ok(Outcome::Checked(Some(f))) => failed(state, before.as_deref(), &f).await,
        Ok(Outcome::Checked(None)) => back(state, before.is_some()).await,
        Ok(Outcome::Made(name, None)) => {
            tracing::info!("monitor backup: uploaded {name}");
            back(state, before.is_some()).await;
        }
        Ok(_) => {}
        Err(f) => {
            tracing::warn!("monitor backup: {}: {}", f.code, f.detail);
            failed(state, before.as_deref(), &f).await;
        }
    }
}

/// Says backups work again, when the last check had failed ([was_failing]).
async fn back(state: &AppState, was_failing: bool) {
    if was_failing {
        notify(state, Level::Info, "Settings backups work again", "The last one is in the folder.", "backup.back", serde_json::json!({}), false).await;
    }
}

/// Says [f] once per cause: not again while the last check failed the same way.
async fn failed(state: &AppState, before: Option<&str>, f: &Failure) {
    if before == Some(f.code.as_str()) {
        return;
    }
    notify(
        state,
        Level::Warning,
        "Settings backup failed",
        &format!("The monitor's settings were not backed up: {}.", f.code),
        "backup.failed",
        serde_json::json!({ "error": f.code }),
        true,
    )
    .await;
}

async fn notify(state: &AppState, level: Level, subject: &str, body: &str, kind: &str, params: serde_json::Value, push: bool) {
    if let Err(e) = state.desk.notify(&state.db, level, Source::Backup, subject, body, Some((kind, &params))).await {
        tracing::error!("monitor backup: notifying: {e}");
    }
    if push {
        crate::monitoring::push::push_all(&state.config, &format!("{subject}: {body}")).await;
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[tokio::test]
    async fn only_a_machine_without_backup_settings_takes_the_backups() {
        let db = SqlitePool::connect("sqlite::memory:").await.unwrap();
        crate::db::database::MIGRATOR.run(&db).await.unwrap();
        let sealer = Sealer::temporary();
        let dir = tempfile::tempdir().unwrap();
        let fetched = Fetched {
            unpacked: snapshot::Unpacked {
                manifest: snapshot::Manifest { format: snapshot::FORMAT, monitor_version: "t".into(), migration: 0, host: "b".into(), created_at: "now".into() },
                config: None,
                database: dir.path().join("settings.db"),
                blobs: vec![],
            },
            name: BackupName { instance: "bbbbbbbb".into(), at: chrono::Utc::now(), key: "22222222".into() },
            recipient: "age1other".into(),
            _scratch: Scratch(dir.path().join("work")),
        };
        let folder = url::Url::parse("https://dav.example.com/b/").unwrap();
        let mine = || async { sqlx::query_as::<_, (String, String, Option<String>)>("SELECT instance, url, recipient FROM monitor_backup").fetch_one(&db).await.unwrap() };

        sqlx::query("INSERT INTO monitor_backup (id, instance, url, recipient, updated_at) VALUES (1, 'aaaaaaaa', 'https://dav.example.com/a/', 'age1mine', 'x')")
            .execute(&db)
            .await
            .unwrap();
        assert!(!adopt(&db, &sealer, &folder, "me", None, false, &fetched).await.unwrap());
        assert_eq!(mine().await, ("aaaaaaaa".into(), "https://dav.example.com/a/".into(), Some("age1mine".into())), "its own, all of it");

        sqlx::query("DELETE FROM monitor_backup").execute(&db).await.unwrap();
        assert!(adopt(&db, &sealer, &folder, "me", None, false, &fetched).await.unwrap());
        assert_eq!(mine().await, ("bbbbbbbb".into(), folder.to_string(), Some("age1other".into())));
    }

    #[tokio::test]
    async fn only_a_live_runs_folders_stay() {
        let dir = tempfile::tempdir().unwrap();
        let db = dir.path().join("m.db");
        let work = MonitorBackup::new(Some(&db));
        let mine = work.scratch().await.unwrap();
        // Another run going on (a CLI): its lock held.
        let other = MonitorBackup::new(Some(&db));
        let theirs = other.scratch().await.unwrap();
        // A killed run (its lock file left, unheld), the older namings, none
        // with a lock, whatever process has their PID now.
        let me = std::process::id();
        std::fs::write(work.dir.join("run-deadbeef.lock"), "").unwrap();
        for stale in ["work-deadbeef-0".to_string(), format!("work-{me}-0"), format!("work-{me}-cafe0123-0")] {
            std::fs::create_dir_all(work.dir.join(stale)).unwrap();
        }
        work.sweep();
        let mut left: Vec<_> = std::fs::read_dir(&work.dir).unwrap().map(|e| e.unwrap().file_name().into_string().unwrap()).filter(|n| n.starts_with("work-")).collect();
        left.sort();
        let mut kept = vec![mine.path().file_name().unwrap().to_str().unwrap().to_string(), theirs.path().file_name().unwrap().to_str().unwrap().to_string()];
        kept.sort();
        assert_eq!(left, kept);
        assert!(!work.dir.join("run-deadbeef.lock").exists(), "its lock goes with it");
        std::fs::write(work.dir.join("run-0badf00d.lock"), "").unwrap();
        work.sweep();
        let locks = std::fs::read_dir(&work.dir).unwrap().filter(|e| e.as_ref().unwrap().file_name().to_str().unwrap().starts_with("run-")).count();
        assert_eq!(locks, 2, "a lock with no folder goes too; the live ones stay");
    }

    #[test]
    fn names_carry_the_time_and_the_key() {
        let at = chrono::DateTime::parse_from_rfc3339("2026-10-21T10:15:00.042Z").unwrap().to_utc();
        let name = backup_file("5e6f7a8b", at, "0a1b2c3d");
        assert_eq!(name, "serverbox-monitor-5e6f7a8b-20261021T101500.042Z-0a1b2c3d.tar.gz.age");
        let parsed = parse_backup(&name).unwrap();
        assert_eq!(parsed, BackupName { instance: "5e6f7a8b".into(), at, key: "0a1b2c3d".into() });
        assert_eq!(parsed.key_file(), "serverbox-monitor-key-5e6f7a8b-0a1b2c3d.age");
        assert_eq!(parse_backup("serverbox-monitor-key-5e6f7a8b-0a1b2c3d.age"), None);
        assert_eq!(parse_backup("serverbox-monitor-5e6f7a8b-20261021T101500.042Z-0A1B2C3D.tar.gz.age"), None);
        assert_eq!(parse_backup("serverbox-monitor-20261021T101500.042Z-0a1b2c3d.tar.gz.age"), None, "no instance");
        assert_eq!(parse_key_file("serverbox-monitor-key-5e6f7a8b-0a1b2c3d.age"), Some(("5e6f7a8b", "0a1b2c3d")));
        assert_eq!(parse_key_file(&name), None);
        assert!(is_id(&new_instance()));
    }

    #[test]
    fn a_key_opens_with_its_passphrase_only() {
        let (recipient, file) = new_key("correct horse battery").unwrap();
        assert!(String::from_utf8_lossy(&file).starts_with("-----BEGIN AGE ENCRYPTED FILE-----"));
        let identity = open_key(&file, "correct horse battery").unwrap();
        assert_eq!(identity.to_public().to_string(), recipient);
        assert_eq!(open_key(&file, "wrong horse battery").err().map(|r| r.error), Some("wrongPassphrase"));
        assert_eq!(open_key(b"not age", "x").err().map(|r| r.error), Some("invalidKeyFile"));
    }

    #[test]
    fn a_stored_password_goes_to_its_own_server_only() {
        let sealer = Sealer::temporary();
        let stored = Row {
            instance: "5e6f7a8b".into(),
            url: "https://dav.example.com/a/".into(),
            username: "me".into(),
            password: Some(sealer.seal(sealed::BACKUP_PASSWORD, "pw").unwrap()),
            allow_insecure: false,
            enabled: true,
            keep: 10,
            recipient: None,
            stable_hash: None,
            full_hash: None,
            last_backup_at: None,
            last_name: None,
            last_error: None,
            last_error_at: None,
        };
        let target = |url: &str, password: Option<&str>| Target { url: url.into(), username: "me".into(), password: password.map(String::from), allow_insecure: false };
        assert_eq!(resolve(&target("https://dav.example.com/b", None), Some(&stored), &sealer).unwrap().2.as_deref(), Some("pw"));
        assert_eq!(resolve(&target("https://evil.example.com/a", None), Some(&stored), &sealer).err().map(|r| r.error), Some("passwordRequired"));
        assert_eq!(resolve(&target("https://evil.example.com/a", Some("new")), Some(&stored), &sealer).unwrap().2.as_deref(), Some("new"));
        assert_eq!(resolve(&target("https://dav.example.com/a", Some("")), Some(&stored), &sealer).unwrap().2, None);
        let lost = Sealer::temporary();
        assert_eq!(resolve(&target("https://dav.example.com/b", None), Some(&stored), &lost).err().map(|r| r.error), Some("passwordRequired"));
    }
}
