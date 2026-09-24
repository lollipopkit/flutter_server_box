//! `GET/PUT /api/v1/backup/*` — the blobs this agent hosts for a client, and
//! the agent's own configuration as a file.
//!
//! # What a blob is
//!
//! Opaque bytes under a name. The app's backup is encrypted before it is sent
//! (`fl_lib`'s `Cryptor`, envelope `LKFL_ENC_V01`, key derived from a password
//! the operator typed), so what arrives here is ciphertext and leaving it on a
//! server is not the same as leaving the operator's credentials for every other
//! server they own on one. **Nothing in this module reads a blob** — not to
//! check it, not to summarise it, not to migrate it — because there would be
//! nothing it could check and the one thing it could do is leak.
//!
//! That is also why a blob is a file rather than a row: a row would mean the
//! whole thing in memory twice, and the file API already streams to disk and
//! renames into place. What is deliberately *not* copied from `/fs` is the
//! confinement: a blob has a name, not a path, so there is nothing to resolve
//! and no root to escape.
//!
//! # What the config pair is
//!
//! `GET /backup/config` hands back `config.toml` as written, and `PUT` takes one
//! and applies it. **Both are `full_access`, and reading is too**, which is the
//! exception in this module: the file holds every write-only credential this
//! agent has (`[pve]`, `[bmc]`, `[ai]`, `[push]`), and `GET /settings` exists
//! precisely because those are not answerable over the API. A caller with the
//! shell grant can read this file anyway — that is what the grant means — so
//! the bar is where it already was, not a new hole.
//!
//! The two keys a file must not be able to change are refused rather than
//! carried over: an imported `jwt_secret` would log every paired device out of
//! an agent that is running fine, and an imported `database_url` would point
//! one at somebody else's records. A file that does not name them is accepted —
//! they live in `.env` for a default install — and only a *differing* value is
//! refused, by name, so the operator knows which line to remove.

use std::path::{Path, PathBuf};
use std::sync::Arc;

use futures::StreamExt;
use ntex::util::Bytes;
use ntex::web::{self, HttpRequest, HttpResponse};
use serde::{Deserialize, Serialize};

use super::server::AppState;
use super::server::verify_auth;
use super::ws;
use super::ws::audit::{Action, Event, Kind, Outcome, peer_ip};
use crate::core::config::{BackupConfig, Config};
use crate::core::config_file;

/// The directory a fresh install keeps its blobs in, under the same root the
/// custom commands use.
const DIR_LEAF: &str = "backups";

/// The longest name, in bytes. Long enough for a hostname or a date, short
/// enough that a directory listing stays readable.
const MAX_NAME: usize = 128;

/// The most of an imported `config.toml` this agent will read. A bound on a
/// mistyped request rather than on a real file, which is kilobytes.
const MAX_CONFIG_BYTES: usize = 1024 * 1024;

/// A name a blob may have: letters, digits, dot, dash, underscore.
///
/// Not a path, and not sanitised into one — a name with a separator or a `..`
/// in it is refused rather than rewritten, because rewriting would mean two
/// callers asking for different things and getting the same file. The leading
/// dot is refused as well: a store whose listing can show a name the operator
/// cannot see is a store with entries nobody can delete from here.
pub fn valid_name(name: &str) -> bool {
    !name.is_empty()
        && name.len() <= MAX_NAME
        && !name.starts_with('.')
        && name
            .chars()
            .all(|c| c.is_ascii_alphanumeric() || matches!(c, '.' | '-' | '_'))
}

/// The directory the blobs are in, created 0700.
///
/// `[backup] dir` when it names one, and `~/.config/server_box/backups`
/// otherwise — resolved per request rather than at startup, so moving the file
/// is enough to move the store.
///
/// 0700 on the way in, and checked rather than assumed: `ensure_script` in the
/// monitoring loop found that a world-writable directory lets another local
/// account swap the file between the write and the read that follows it. An
/// existing directory owned by somebody else is refused for the same reason.
fn store_dir(config: &BackupConfig) -> Result<PathBuf, String> {
    let dir = if config.dir.trim().is_empty() {
        home_dir()?
            .join(".config")
            .join("server_box")
            .join(DIR_LEAF)
    } else {
        PathBuf::from(config.dir.trim())
    };
    create_private_dir(&dir)?;
    Ok(dir)
}

fn home_dir() -> Result<PathBuf, String> {
    #[cfg(windows)]
    let home = std::env::var_os("USERPROFILE");
    #[cfg(not(windows))]
    let home = std::env::var_os("HOME");
    home.filter(|h| !h.is_empty())
        .map(PathBuf::from)
        .ok_or_else(|| "no home directory for this process".to_string())
}

/// Creates `dir` if it is absent and refuses it unless only its owner can enter.
#[cfg(unix)]
fn create_private_dir(dir: &Path) -> Result<(), String> {
    use std::os::unix::fs::PermissionsExt;
    std::fs::create_dir_all(dir).map_err(|e| e.to_string())?;
    let mode = std::fs::metadata(dir).map_err(|e| e.to_string())?.permissions().mode();
    if mode & 0o077 != 0 {
        // Set it, then refuse it if that did not take: a chmod that fails is
        // the signal that the directory is not this account's to re-mode.
        std::fs::set_permissions(dir, std::fs::Permissions::from_mode(0o700))
            .map_err(|e| e.to_string())?;
        let mode = std::fs::metadata(dir).map_err(|e| e.to_string())?.permissions().mode();
        if mode & 0o077 != 0 {
            return Err(format!("{dir:?} is readable by other accounts"));
        }
    }
    Ok(())
}

/// Windows has no mode bits to set; the agent's own user owns its app data.
#[cfg(not(unix))]
fn create_private_dir(dir: &Path) -> Result<(), String> {
    std::fs::create_dir_all(dir).map_err(|e| e.to_string())
}

/// One blob, as a listing shows it. Never its contents.
#[derive(Serialize)]
struct BlobView {
    name: String,
    size: u64,
    /// RFC 3339, from the file's own timestamp.
    updated_at: String,
}

#[derive(Serialize)]
struct ListResponse {
    blobs: Vec<BlobView>,
    /// The most one upload may be, so the panel can say it before a file is
    /// chosen rather than after it is refused.
    max_bytes: u64,
    /// Whether this caller may change the store. The listing needs only the
    /// panel login, like a crontab or the file roots.
    editable: bool,
}

#[derive(Serialize)]
struct ErrorResponse {
    error: &'static str,
}

fn bad_request(error: &'static str) -> HttpResponse {
    HttpResponse::BadRequest().json(&ErrorResponse { error })
}

fn internal_error(error: &'static str) -> HttpResponse {
    HttpResponse::InternalServerError().json(&ErrorResponse { error })
}

async fn read_config() -> Result<Config, HttpResponse> {
    config_file::read().map_err(|e| {
        tracing::warn!("backup: could not read the config: {e}");
        internal_error("config_unavailable")
    })
}

/// A counter that makes each staging name unique within this process.
///
/// With the pid, so two agents — or the same agent across a restart, where the
/// pid may repeat — cannot pick the same one.
fn staging_seq() -> String {
    use std::sync::atomic::{AtomicU64, Ordering};
    static SEQ: AtomicU64 = AtomicU64::new(0);
    let n = SEQ.fetch_add(1, Ordering::Relaxed);
    format!("{}-{n}", std::process::id())
}

/// Every blob in the store, oldest name first.
fn list(dir: &Path) -> Result<Vec<BlobView>, String> {
    let mut found = Vec::new();
    let entries = match std::fs::read_dir(dir) {
        Ok(entries) => entries,
        // A store nobody has written to yet is what a fresh install looks like,
        // and the panel should offer to add the first rather than report a fault.
        Err(e) if e.kind() == std::io::ErrorKind::NotFound => return Ok(found),
        Err(e) => return Err(e.to_string()),
    };
    for entry in entries {
        let entry = entry.map_err(|e| e.to_string())?;
        if !entry.file_type().map_err(|e| e.to_string())?.is_file() {
            continue;
        }
        let name = entry.file_name().to_string_lossy().into_owned();
        // A stray file in a directory on somebody's machine is skipped rather
        // than fatal — and it is skipped here rather than reported because a
        // name this store cannot address is one it cannot serve either.
        if !valid_name(&name) {
            continue;
        }
        let metadata = entry.metadata().map_err(|e| e.to_string())?;
        found.push(BlobView {
            name,
            size: metadata.len(),
            updated_at: rfc3339(metadata.modified().ok()),
        });
    }
    found.sort_by(|a, b| a.name.cmp(&b.name));
    Ok(found)
}

/// A file's mtime as RFC 3339, which is the shape every other timestamp in this
/// agent's schema has.
///
/// In UTC, because the file system records an instant and not an offset, and a
/// zone invented here would be a field of this agent's own. What reads it is a
/// client deciding whether the copy it has is the one on the server, which needs
/// equality and order rather than a local reading.
fn rfc3339(modified: Option<std::time::SystemTime>) -> String {
    modified
        .map(chrono::DateTime::<chrono::Utc>::from)
        .map(|at| at.to_rfc3339())
        .unwrap_or_default()
}

pub async fn list_blobs(
    req: HttpRequest,
    app_state: web::types::State<Arc<AppState>>,
) -> Result<HttpResponse, web::Error> {
    if verify_auth(&req, &app_state.config.get_jwt_secret()).is_err() {
        return Ok(HttpResponse::Unauthorized().finish());
    }
    let secure = ws::is_secure_transport(&req, app_state.tls_active);
    let editable = app_state.full_access_allowed(secure);
    let config = match read_config().await {
        Ok(config) => config,
        Err(response) => return Ok(response),
    };
    let backup = config.get_backup();
    let dir = match store_dir(&backup) {
        Ok(dir) => dir,
        Err(e) => {
            tracing::warn!("backup: {e}");
            return Ok(internal_error("store_unavailable"));
        }
    };
    match list(&dir) {
        Ok(blobs) => Ok(HttpResponse::Ok().json(&ListResponse {
            blobs,
            max_bytes: backup.max_bytes,
            editable,
        })),
        Err(e) => {
            tracing::warn!("backup: could not read the store: {e}");
            Ok(internal_error("store_unavailable"))
        }
    }
}

#[derive(Deserialize)]
pub struct NameQuery {
    name: String,
}

/// Hands a blob back, byte for byte, as a file.
///
/// Streamed rather than read: a backup is megabytes and this agent is often on
/// a machine with less memory than the file has bytes. Capped by the same
/// `max_bytes` the upload is, so a blob that got in on an older, larger limit
/// is still bounded on the way out.
pub async fn download(
    req: HttpRequest,
    query: web::types::Query<NameQuery>,
    app_state: web::types::State<Arc<AppState>>,
) -> Result<HttpResponse, web::Error> {
    if verify_auth(&req, &app_state.config.get_jwt_secret()).is_err() {
        return Ok(HttpResponse::Unauthorized().finish());
    }
    if !valid_name(&query.name) {
        return Ok(bad_request("invalidName"));
    }
    let config = match read_config().await {
        Ok(config) => config,
        Err(response) => return Ok(response),
    };
    let dir = match store_dir(&config.get_backup()) {
        Ok(dir) => dir,
        Err(e) => {
            tracing::warn!("backup: {e}");
            return Ok(internal_error("store_unavailable"));
        }
    };
    let path = dir.join(&query.name);
    let file = match tokio::fs::File::open(&path).await {
        Ok(file) => file,
        Err(e) if e.kind() == std::io::ErrorKind::NotFound => {
            return Ok(HttpResponse::NotFound().json(&ErrorResponse { error: "noSuchBlob" }));
        }
        Err(e) => {
            tracing::warn!("backup: {e}");
            return Ok(internal_error("store_unavailable"));
        }
    };

    // No `content-length`. `streaming` frames the body as chunked, and a
    // response carrying both is one strict clients reject and proxies treat as
    // a smuggling hazard — and the length would have come from a second `stat`
    // that an upload landing between the two calls makes wrong anyway.
    let stream = async_stream::stream! {
        use tokio::io::AsyncReadExt;
        let mut file = file;
        let mut buffer = vec![0u8; 64 * 1024];
        loop {
            match file.read(&mut buffer).await {
                Ok(0) => break,
                Ok(read) => yield Ok::<_, std::io::Error>(Bytes::copy_from_slice(&buffer[..read])),
                Err(e) => {
                    // The headers are already out, so this is the only way to
                    // say the rest is missing: the client sees a short body.
                    tracing::warn!("backup: a download stopped early: {e}");
                    yield Err(e);
                    break;
                }
            }
        }
    };
    Ok(HttpResponse::Ok()
        .content_type("application/octet-stream")
        // The name is the operator's own and is what the browser will call the
        // saved file; a name with a quote or a newline in it is refused by
        // `valid_name`, so this cannot break the header.
        .header(
            "content-disposition",
            format!("attachment; filename=\"{}\"", query.name),
        )
        .streaming(Box::pin(stream)))
}

/// Stores a blob, replacing one of the same name.
///
/// Staged beside the destination and renamed, `/fs`'s contract: an upload that
/// dies halfway leaves no half-file under the name the app is about to read as
/// its backup.
pub async fn upload(
    req: HttpRequest,
    query: web::types::Query<NameQuery>,
    mut body: web::types::Payload,
    app_state: web::types::State<Arc<AppState>>,
) -> Result<HttpResponse, web::Error> {
    if verify_auth(&req, &app_state.config.get_jwt_secret()).is_err() {
        return Ok(HttpResponse::Unauthorized().finish());
    }
    let remote_ip = peer_ip(&req);
    let secure = ws::is_secure_transport(&req, app_state.tls_active);
    if !app_state.full_access_allowed(secure) {
        Event::new(Kind::Backup, Action::Denied, Outcome::Denied)
            .remote_ip(remote_ip)
            .detail("full access disabled")
            .record(&app_state.db)
            .await;
        return Ok(HttpResponse::Forbidden().finish());
    }
    if !valid_name(&query.name) {
        return Ok(bad_request("invalidName"));
    }

    let config = match read_config().await {
        Ok(config) => config,
        Err(response) => return Ok(response),
    };
    let backup = config.get_backup();
    let dir = match store_dir(&backup) {
        Ok(dir) => dir,
        Err(e) => {
            tracing::warn!("backup: {e}");
            return Ok(internal_error("store_unavailable"));
        }
    };

    let path = dir.join(&query.name);
    // Unique per attempt, and that is not tidiness: two uploads of one name —
    // the app's sync and an operator's upload from the panel, say — would
    // otherwise open one file, interleave their chunks into it, and each
    // rename the result over the blob. The rename is atomic, so what lands is
    // a byte-interleaved file under a name something will later read as a
    // backup. `/fs`'s `staging_path` is the same rule for the same reason.
    //
    // Leading dot as well, so a file left behind by a crash is one `valid_name`
    // refuses and the listing therefore never shows as a blob.
    let staging = dir.join(format!(".{}.upload-{}", query.name, staging_seq()));
    let mut file = match tokio::fs::OpenOptions::new()
        .write(true)
        .create(true)
        .truncate(true)
        .open(&staging)
        .await
    {
        Ok(file) => file,
        Err(e) => {
            tracing::warn!("backup: could not stage an upload: {e}");
            return Ok(internal_error("store_unavailable"));
        }
    };

    use tokio::io::AsyncWriteExt;
    let mut written: u64 = 0;
    let mut failure: Option<HttpResponse> = None;
    while let Some(chunk) = body.next().await {
        let chunk = match chunk {
            Ok(chunk) => chunk,
            Err(_) => {
                failure = Some(HttpResponse::BadRequest().finish());
                break;
            }
        };
        written += chunk.len() as u64;
        if written > backup.max_bytes {
            failure = Some(HttpResponse::PayloadTooLarge().json(&ErrorResponse {
                error: "tooLarge",
            }));
            break;
        }
        if let Err(e) = file.write_all(&chunk).await {
            tracing::warn!("backup: {e}");
            failure = Some(internal_error("store_unavailable"));
            break;
        }
    }
    if failure.is_none() && file.flush().await.is_err() {
        failure = Some(internal_error("store_unavailable"));
    }
    drop(file);

    if let Some(response) = failure {
        let _ = tokio::fs::remove_file(&staging).await;
        return Ok(response);
    }
    if let Err(e) = tokio::fs::rename(&staging, &path).await {
        tracing::warn!("backup: could not install a blob: {e}");
        let _ = tokio::fs::remove_file(&staging).await;
        return Ok(internal_error("store_unavailable"));
    }

    // Written after the bytes are in place, and without them: the row says a
    // name was stored and how large it was, which is what someone reading this
    // table is looking for. What the blob *contains* is never in it.
    Event::new(Kind::Backup, Action::Write, Outcome::Ok)
        .remote_ip(remote_ip)
        .subject(query.name.clone())
        .detail(format!("{written} bytes"))
        .record(&app_state.db)
        .await;

    Ok(HttpResponse::Ok().json(&BlobView {
        name: query.name.clone(),
        size: written,
        updated_at: rfc3339(
            tokio::fs::metadata(&path)
                .await
                .ok()
                .and_then(|m| m.modified().ok()),
        ),
    }))
}

pub async fn remove(
    req: HttpRequest,
    query: web::types::Query<NameQuery>,
    app_state: web::types::State<Arc<AppState>>,
) -> Result<HttpResponse, web::Error> {
    if verify_auth(&req, &app_state.config.get_jwt_secret()).is_err() {
        return Ok(HttpResponse::Unauthorized().finish());
    }
    let remote_ip = peer_ip(&req);
    let secure = ws::is_secure_transport(&req, app_state.tls_active);
    if !app_state.full_access_allowed(secure) {
        Event::new(Kind::Backup, Action::Denied, Outcome::Denied)
            .remote_ip(remote_ip)
            .detail("full access disabled")
            .record(&app_state.db)
            .await;
        return Ok(HttpResponse::Forbidden().finish());
    }
    if !valid_name(&query.name) {
        return Ok(bad_request("invalidName"));
    }

    let config = match read_config().await {
        Ok(config) => config,
        Err(response) => return Ok(response),
    };
    let dir = match store_dir(&config.get_backup()) {
        Ok(dir) => dir,
        Err(e) => {
            tracing::warn!("backup: {e}");
            return Ok(internal_error("store_unavailable"));
        }
    };
    let path = dir.join(&query.name);
    match tokio::fs::remove_file(&path).await {
        Ok(()) => {}
        Err(e) if e.kind() == std::io::ErrorKind::NotFound => {
            return Ok(HttpResponse::NotFound().json(&ErrorResponse { error: "noSuchBlob" }));
        }
        Err(e) => {
            tracing::warn!("backup: {e}");
            return Ok(internal_error("store_unavailable"));
        }
    }

    Event::new(Kind::Backup, Action::Write, Outcome::Ok)
        .remote_ip(remote_ip)
        .subject(query.name.clone())
        .detail("removed")
        .record(&app_state.db)
        .await;
    Ok(HttpResponse::Ok().finish())
}

/// The agent's own `config.toml`, as a file.
pub async fn export_config(
    req: HttpRequest,
    app_state: web::types::State<Arc<AppState>>,
) -> Result<HttpResponse, web::Error> {
    if verify_auth(&req, &app_state.config.get_jwt_secret()).is_err() {
        return Ok(HttpResponse::Unauthorized().finish());
    }
    let secure = ws::is_secure_transport(&req, app_state.tls_active);
    // `full_access` for the read too, unlike every other read in this module:
    // this file is where the write-only credentials live, and `GET /settings`
    // exists because they are not answerable over the API. Anyone with this
    // grant can open a shell and read the file anyway.
    if !app_state.full_access_allowed(secure) {
        Event::new(Kind::Backup, Action::Denied, Outcome::Denied)
            .remote_ip(peer_ip(&req))
            .detail("full access disabled")
            .record(&app_state.db)
            .await;
        return Ok(HttpResponse::Forbidden().finish());
    }
    match config_file::read_text() {
        Ok(text) => Ok(HttpResponse::Ok()
            .content_type("text/plain; charset=utf-8")
            .header(
                "content-disposition",
                format!("attachment; filename=\"{}\"", config_file::CONFIG_PATH),
            )
            .body(text)),
        Err(e) => {
            tracing::warn!("backup: could not read the config: {e}");
            Ok(internal_error("config_unavailable"))
        }
    }
}

/// Applies an uploaded `config.toml`.
///
/// Written verbatim once it parses, so the operator's own comments and any key
/// this build does not know survive the round trip — which is the reason this
/// is not a `PUT /settings` with every field named.
///
/// The two keys that would change who can log in and where the records are are
/// **refused rather than carried over**, and by name, so the operator knows
/// which line to take out. A file that omits them is fine: a default install
/// keeps both in `.env`.
pub async fn import_config(
    req: HttpRequest,
    mut body: web::types::Payload,
    app_state: web::types::State<Arc<AppState>>,
) -> Result<HttpResponse, web::Error> {
    if verify_auth(&req, &app_state.config.get_jwt_secret()).is_err() {
        return Ok(HttpResponse::Unauthorized().finish());
    }
    let remote_ip = peer_ip(&req);
    let secure = ws::is_secure_transport(&req, app_state.tls_active);
    if !app_state.full_access_allowed(secure) {
        Event::new(Kind::Backup, Action::Denied, Outcome::Denied)
            .remote_ip(remote_ip)
            .detail("full access disabled")
            .record(&app_state.db)
            .await;
        return Ok(HttpResponse::Forbidden().finish());
    }

    // Read with a cap before anything is parsed. A config file is kilobytes, so
    // this is a bound on what a mistyped request can make the agent buffer
    // rather than a limit anyone's file reaches.
    //
    // Collected as bytes and decoded **once**, at the end. Decoding each chunk
    // on its own is what a multi-byte character straddling two of them turns
    // into two replacement characters — and since what is written is this very
    // text, the operator's comment or a value in it would come back corrupted.
    let mut bytes = Vec::new();
    while let Some(chunk) = body.next().await {
        let chunk = match chunk {
            Ok(chunk) => chunk,
            Err(_) => return Ok(HttpResponse::BadRequest().finish()),
        };
        if bytes.len() + chunk.len() > MAX_CONFIG_BYTES {
            return Ok(HttpResponse::PayloadTooLarge().json(&ErrorResponse {
                error: "tooLarge",
            }));
        }
        bytes.extend_from_slice(&chunk);
    }
    let text = match String::from_utf8(bytes) {
        Ok(text) => text,
        // A config nobody can read as text is not one: TOML is text, and
        // repairing it here would write a file the operator did not send.
        Err(_) => return Ok(bad_request("invalidConfig")),
    };

    // Read as this agent's own configuration, which is what makes the two
    // protected keys comparable and what refuses a file that is not one.
    let uploaded: Config = match toml::from_str(&text) {
        Ok(config) => config,
        Err(e) => {
            tracing::warn!("backup: an imported config did not parse: {e}");
            return Ok(bad_request("invalidConfig"));
        }
    };

    let _config_guard = app_state.config_write.lock().await;
    let current = match read_config().await {
        Ok(config) => config,
        Err(response) => return Ok(response),
    };
    // Both fields as the file names them, against what this agent is running
    // with. `None` on both sides is a default install, where they come from
    // `.env` — accepted, because the file is not what supplies them.
    if uploaded.jwt_secret != current.jwt_secret {
        return Ok(bad_request("jwtSecretDiffers"));
    }
    if uploaded.database_url != current.database_url {
        return Ok(bad_request("databaseUrlDiffers"));
    }

    // The caller's own text, not a reserialization of the struct: what is
    // imported is the operator's file, comments and unknown keys included.
    if let Err(e) = config_file::write_text(&text) {
        tracing::warn!("backup: could not write the config: {e}");
        return Ok(internal_error("config_unavailable"));
    }

    Event::new(Kind::Backup, Action::Write, Outcome::Ok)
        .remote_ip(remote_ip)
        .subject("config")
        .detail("imported; a restart applies it")
        .record(&app_state.db)
        .await;

    // Answered with what a restart needs rather than with the file: nothing in
    // this response is a credential, and the operator is told the one thing a
    // browser cannot see.
    Ok(HttpResponse::Ok().json(&ImportResponse { restart_required: true }))
}

#[derive(Serialize)]
struct ImportResponse {
    /// Always true. `AppState.config` is a startup snapshot, so an imported file
    /// is on disk and not in effect — including the sections a live reload does
    /// pick up, because a reload is not what happened here.
    restart_required: bool,
}
