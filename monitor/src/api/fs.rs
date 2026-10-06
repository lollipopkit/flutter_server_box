//! `/api/v1/fs/*` — list, read, write and rearrange files under the roots the
//! operator named.
//!
//! The app's third file backend. It already browses a server's files over SFTP
//! whenever it can reach sshd, so this endpoint exists for exactly one case: a
//! host running the agent with no reachable sshd at all. That is a small set,
//! and it is why this is off by default and why it is confined.
//!
//! **Confinement is the whole design.** `core::fs_roots` resolves every
//! request to a canonical path and refuses anything that lands outside the
//! configured roots. Nothing in this file interprets a path itself; if a
//! handler here takes a `&str` from a client and hands it to `tokio::fs`
//! without going through [`FsRoots`], that is the bug.
//!
//! Its own grant, `files`, not `shell`: that one means "a shell as the
//! agent's user", this one means "these directories", and folding them
//! together would make the narrower thing cost the wider one. Where the roots
//! *are* the whole filesystem the two are equivalent, which is what the
//! startup warning says. `files` is read-only or read-write
//! (`core::permissions::FilesMode`), and which a request needs is decided by
//! what it does — see [`admit`].

use std::path::{Path, PathBuf};
use std::sync::Arc;

use futures::StreamExt;
use ntex::util::Bytes;
use ntex::web::{self, HttpRequest, HttpResponse};
use serde::{Deserialize, Serialize};
use tokio::io::{AsyncReadExt, AsyncSeekExt, AsyncWriteExt};

use super::authz;
use super::server::AppState;
use super::ws::audit::{Action, Event, Kind, Outcome, peer_ip};
use crate::core::fs_roots::FsDenied;
use crate::core::permissions::Grant;

/// How much of a file is read per chunk. The same 32 KiB the SFTP path uses,
/// for the same reason: big enough that the per-chunk overhead disappears,
/// small enough that a slow reader does not park megabytes in a buffer.
const CHUNK: usize = 32 * 1024;

/// Held from a write's version check to its rename, and by `remove` and
/// `rename`: the steps in this agent that replace or take away a file. One
/// lock for all paths because it is held for a stat and a rename, never for an
/// upload, so contention is not worth a lock per path.
static REPLACE: tokio::sync::Mutex<()> = tokio::sync::Mutex::const_new(());

#[derive(Serialize)]
struct EntryView {
    name: String,
    /// `file` | `dir` | `link` | `other`, matching the app's `FileKind`.
    kind: &'static str,
    /// Null where the platform did not say, which the app renders as "no
    /// size" rather than as zero.
    size: Option<u64>,
    /// Seconds since the epoch, as SFTP reports them, so the app's two
    /// backends need no second unit.
    modified: Option<i64>,
    /// Permission bits only — no type bits. The app's `FileEntry.mode` is
    /// defined the same way, so `chmod` can take it back unchanged.
    mode: Option<u32>,
    /// Where a link points, unresolved. Null for anything else.
    link_target: Option<String>,
    /// An opaque token for this exact state of the file, for a write's
    /// `if_version`: the modification time in nanoseconds plus the size. A
    /// whole second is coarse enough that two writes inside one get past a
    /// guard built on it. Null where the platform does not say.
    version: Option<String>,
}

#[derive(Deserialize)]
pub struct PathQuery {
    path: String,
    /// Byte to start reading at, so an interrupted read can be resumed.
    #[serde(default)]
    offset: Option<u64>,
}

#[derive(Deserialize)]
pub struct WriteQuery {
    path: String,
    /// The `version` the caller last saw for this path, as the listing or
    /// `stat` reported it. Present only for an edit that read the file first: a
    /// plain upload states nothing and overwrites.
    #[serde(default)]
    if_version: Option<String>,
}

#[derive(Deserialize)]
pub struct PathBody {
    path: String,
}

#[derive(Deserialize)]
pub struct RemoveBody {
    path: String,
    #[serde(default)]
    recursive: bool,
}

#[derive(Deserialize)]
pub struct RenameBody {
    from: String,
    to: String,
}

#[derive(Deserialize)]
pub struct ChmodBody {
    path: String,
    /// Octal permission bits as a number — `0o755` is 493.
    mode: u32,
}

/// What changes something on disk, and therefore needs `files` with
/// `mode = "write"`. Everything else — the roots, list, stat, read — is a read.
fn writes(action: &str) -> bool {
    matches!(action, "write" | "mkdir" | "remove" | "rename" | "chmod")
}

/// Authorises the request and reports why not.
///
/// Every handler starts here. Re-checked per request rather than trusted from
/// the capabilities the client was told earlier, for the same reason `/exec`
/// re-checks: that answer is a UI hint, and the UI is not a boundary.
async fn admit(
    req: &HttpRequest,
    state: &Arc<AppState>,
    action: &str,
    subject: &str,
) -> Result<(), HttpResponse> {
    let caller = match authz::jwt_caller(req, state).await {
        Ok(caller) => caller,
        Err(_) => return Err(HttpResponse::Unauthorized().finish()),
    };
    let checked = caller.check(Grant::Files, state, authz::is_secure(req, state));
    let read_only = caller
        .grants()
        .files
        .as_ref()
        .is_some_and(|files| !files.allows_write());
    let refusal = match checked {
        Err(why) => Some(why.as_str()),
        Ok(()) if writes(action) && read_only => Some("read-only"),
        Ok(()) => None,
    };
    if let Some(refusal) = refusal {
        Event::new(Kind::Fs, Action::Denied, Outcome::Denied)
            .remote_ip(peer_ip(req))
            .subject(&caller.username)
            .detail(format!("{action}: {refusal}"))
            .record(&state.db)
            .await;
        return Err(HttpResponse::Forbidden().finish());
    }
    // Logged by what was asked for, before it is attempted: an operation that
    // kills the agent still has to appear here.
    Event::new(Kind::Fs, Action::Open, Outcome::Ok)
        .remote_ip(peer_ip(req))
        .subject(format!("{action} {subject}"))
        .record(&state.db)
        .await;
    Ok(())
}

/// Turns a refusal into a response.
///
/// 403 for every kind of refusal, with the same body: telling a caller that a
/// path exists but is out of bounds, as against not existing, would let
/// somebody map the filesystem one status code at a time.
fn denied(e: FsDenied) -> HttpResponse {
    HttpResponse::Forbidden().json(&serde_json::json!({ "error": e.to_string() }))
}

fn failed(e: std::io::Error) -> HttpResponse {
    match e.kind() {
        std::io::ErrorKind::NotFound => {
            HttpResponse::NotFound().json(&serde_json::json!({ "error": "not found" }))
        }
        std::io::ErrorKind::PermissionDenied => {
            HttpResponse::Forbidden().json(&serde_json::json!({ "error": "permission denied" }))
        }
        _ => {
            HttpResponse::InternalServerError().json(&serde_json::json!({ "error": e.to_string() }))
        }
    }
}

/// The directories this agent will serve, so a client can offer them instead
/// of making the user guess.
///
/// Not a hole in the confinement. The roots are the operator's decision and
/// every other handler re-resolves against them per request; this only saves an
/// already-authenticated caller from discovering them one 403 at a time, which
/// it can do anyway. What it is *not* allowed to do is report anything about
/// what lies outside them, which is why `denied` stays uniform.
///
/// Worth having because the alternative is worse in practice: a client with no
/// way to ask starts at `/`, is refused, and has nothing to show for it but the
/// refusal — see the app's file browser, which now offers these as its way out.
pub async fn roots(
    req: HttpRequest,
    state: web::types::State<Arc<AppState>>,
) -> Result<HttpResponse, web::Error> {
    if let Err(res) = admit(&req, &state, "roots", "").await {
        return Ok(res);
    }
    let roots: Vec<String> = state
        .remote_access
        .fs
        .roots
        .as_slice()
        .iter()
        .map(|p| exposed_path(p))
        .collect();
    Ok(HttpResponse::Ok().json(&serde_json::json!({ "roots": roots })))
}

pub async fn list(
    req: HttpRequest,
    query: web::types::Query<PathQuery>,
    state: web::types::State<Arc<AppState>>,
) -> Result<HttpResponse, web::Error> {
    if let Err(res) = admit(&req, &state, "list", &query.path).await {
        return Ok(res);
    }
    let dir = match state.remote_access.fs.roots.resolve_existing(&query.path) {
        Ok(path) => path,
        Err(e) => return Ok(denied(e)),
    };

    let mut reader = match tokio::fs::read_dir(&dir).await {
        Ok(reader) => reader,
        Err(e) => return Ok(failed(e)),
    };
    let roots = &state.remote_access.fs.roots;
    let mut entries = Vec::new();
    loop {
        match reader.next_entry().await {
            // The agent's own state is left out rather than shown and refused:
            // a name that can be listed is a name somebody will try.
            Ok(Some(entry)) if roots.hides(&entry.path()) => {}
            // A write in progress, not a file anyone made: it becomes the real
            // name on rename, or is removed.
            Ok(Some(entry)) if is_staging_name(&entry.file_name().to_string_lossy()) => {}
            Ok(Some(entry)) => entries.push(view_of(&entry.path()).await),
            Ok(None) => break,
            Err(e) => return Ok(failed(e)),
        }
    }
    Ok(HttpResponse::Ok().json(&entries))
}

pub async fn stat(
    req: HttpRequest,
    query: web::types::Query<PathQuery>,
    state: web::types::State<Arc<AppState>>,
) -> Result<HttpResponse, web::Error> {
    if let Err(res) = admit(&req, &state, "stat", &query.path).await {
        return Ok(res);
    }
    let path = match state.remote_access.fs.roots.resolve_existing(&query.path) {
        Ok(path) => path,
        // Absence and refusal are one answer here, as they are everywhere
        // else in this module; the app treats a 404 as "not there".
        Err(FsDenied::OutsideRoots) => {
            return Ok(HttpResponse::NotFound().json(&serde_json::json!({ "error": "not found" })));
        }
        Err(e) => return Ok(denied(e)),
    };
    Ok(HttpResponse::Ok().json(&view_of(&path).await))
}

pub async fn read(
    req: HttpRequest,
    query: web::types::Query<PathQuery>,
    state: web::types::State<Arc<AppState>>,
) -> Result<HttpResponse, web::Error> {
    if let Err(res) = admit(&req, &state, "read", &query.path).await {
        return Ok(res);
    }
    let path = match state.remote_access.fs.roots.resolve_existing(&query.path) {
        Ok(path) => path,
        Err(e) => return Ok(denied(e)),
    };

    let mut file = match tokio::fs::File::open(&path).await {
        Ok(file) => file,
        Err(e) => return Ok(failed(e)),
    };
    let offset = query.offset.unwrap_or(0);
    if offset > 0
        && let Err(e) = file.seek(std::io::SeekFrom::Start(offset)).await
    {
        return Ok(failed(e));
    }
    // Streamed rather than read into memory: this is the endpoint that has to
    // move a file bigger than the agent's own footprint, and `/exec`'s 1 MiB
    // cap is exactly why it could not be that endpoint.
    let stream = async_stream::stream! {
        let mut buf = vec![0u8; CHUNK];
        loop {
            match file.read(&mut buf).await {
                Ok(0) => break,
                Ok(n) => yield Ok::<_, std::io::Error>(Bytes::copy_from_slice(&buf[..n])),
                Err(e) => {
                    yield Err(e);
                    break;
                }
            }
        }
    };

    // No `content-length`. `streaming` frames the body as chunked, and a
    // response carrying both is one strict clients reject and proxies treat as
    // a smuggling hazard — and the length would have come from a second `stat`
    // that a file appended to between the two calls makes wrong anyway.
    // Callers that want a size ask `/fs/stat`.
    //
    // Boxed because an `async_stream` generator holds a self-referential
    // future and so is not `Unpin`, which is what `streaming` asks for.
    Ok(HttpResponse::Ok()
        .content_type("application/octet-stream")
        .streaming(Box::pin(stream)))
}

pub async fn write(
    req: HttpRequest,
    query: web::types::Query<WriteQuery>,
    mut body: web::types::Payload,
    state: web::types::State<Arc<AppState>>,
) -> Result<HttpResponse, web::Error> {
    if let Err(res) = admit(&req, &state, "write", &query.path).await {
        return Ok(res);
    }
    let path = match state.remote_access.fs.roots.resolve_new(&query.path) {
        Ok(path) => path,
        Err(e) => return Ok(denied(e)),
    };

    // Beside the destination, then renamed: the same contract the app's own
    // backends keep, so a write that dies halfway leaves no half-file under
    // the name something else is about to open. A rename within one directory
    // is atomic; a temp dir elsewhere would make it a copy.
    let staging = staging_path(&path);
    let mut file = match tokio::fs::OpenOptions::new()
        .write(true)
        .create_new(true)
        .open(&staging)
        .await
    {
        Ok(file) => file,
        Err(e) => return Ok(failed(e)),
    };
    // Removes the staged file on every way out but a successful rename,
    // including the one no branch here sees: the client going away mid-upload
    // drops this future, and the half-file must not stay in the directory.
    let mut staged = Staged::new(staging.clone());

    let limit = state.remote_access.fs.max_write_bytes;
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
        if written > limit {
            failure = Some(HttpResponse::PayloadTooLarge().json(&serde_json::json!({
                "error": format!("file exceeds the {limit} byte limit"),
            })));
            break;
        }
        if let Err(e) = file.write_all(&chunk).await {
            failure = Some(failed(e));
            break;
        }
    }

    if failure.is_none()
        && let Err(e) = file.flush().await
    {
        failure = Some(failed(e));
    }
    drop(file);

    if let Some(res) = failure {
        return Ok(res);
    }

    // From here to the rename is one step for every writer in this agent, so
    // two saves of one file cannot both pass the check below and then replace
    // each other. A process outside the agent can still write between the
    // check and the rename: POSIX has no rename-if-unchanged, so that is
    // narrowed to this short window rather than closed.
    let _replacing = REPLACE.lock().await;

    // Optimistic concurrency for the panel's editor: a caller that read the
    // file states the `version` it saw, and one whose file has moved on is
    // answered 409 with nothing written. A file that is no longer there is the
    // same answer — it was deleted after it was opened, and recreating it here
    // would be the lost update this is meant to prevent.
    //
    // After root resolution and the grant check, so a caller that may not write
    // here cannot use the answer to learn a file's state; after the upload, so
    // the check is the last thing before the rename. The comparison is against
    // the resolved target, the same file a listing resolves to (a listing uses
    // `symlink_metadata`, so a link is described rather than followed; for the
    // regular files an editor opens the two agree).
    if let Some(expected) = query.if_version.as_deref()
        && version_at(&path).await.as_deref() != Some(expected)
    {
        return Ok(HttpResponse::Conflict().json(&serde_json::json!({ "error": "modified" })));
    }

    // The staged file was created with the process umask, and the rename
    // carries that mode onto the destination — so overwriting a 0600 file
    // would quietly leave it 0644. Whatever was there keeps its permissions,
    // and a mode that cannot be carried over fails the write rather than
    // replacing a restricted file with an open one.
    if let Ok(existing) = tokio::fs::metadata(&path).await
        && let Err(e) = tokio::fs::set_permissions(&staging, existing.permissions()).await
    {
        tracing::warn!("Could not carry {path:?}'s permissions over: {e}");
        return Ok(failed(e));
    }
    if let Err(e) = tokio::fs::rename(&staging, &path).await {
        return Ok(failed(e));
    }
    staged.keep();
    Ok(HttpResponse::Ok().json(&serde_json::json!({ "bytes": written })))
}

pub async fn mkdir(
    req: HttpRequest,
    body: web::types::Json<PathBody>,
    state: web::types::State<Arc<AppState>>,
) -> Result<HttpResponse, web::Error> {
    if let Err(res) = admit(&req, &state, "mkdir", &body.path).await {
        return Ok(res);
    }
    let path = match state.remote_access.fs.roots.resolve_new(&body.path) {
        Ok(path) => path,
        Err(e) => return Ok(denied(e)),
    };
    match tokio::fs::create_dir_all(&path).await {
        Ok(()) => Ok(HttpResponse::Ok().finish()),
        Err(e) => Ok(failed(e)),
    }
}

pub async fn remove(
    req: HttpRequest,
    body: web::types::Json<RemoveBody>,
    state: web::types::State<Arc<AppState>>,
) -> Result<HttpResponse, web::Error> {
    if let Err(res) = admit(&req, &state, "remove", &body.path).await {
        return Ok(res);
    }
    let path = match state.remote_access.fs.roots.resolve_entry(&body.path) {
        Ok(path) => path,
        Err(e) => return Ok(denied(e)),
    };
    // Nor is a directory the agent's own state is in — see `Protected`.
    if let Err(e) = state.remote_access.fs.roots.check_mutable(&path) {
        return Ok(denied(e));
    }

    // A root itself is not deletable through this API. Removing the thing the
    // confinement is defined against would leave the API pointed at nothing,
    // and no client means to do it.
    if state
        .remote_access
        .fs
        .roots
        .as_slice()
        .iter()
        .any(|root| root == &path)
    {
        return Ok(denied(FsDenied::OutsideRoots));
    }

    // Under the writers' lock, so a guarded write never checks a file this is
    // halfway through removing.
    let _replacing = REPLACE.lock().await;
    let meta = match tokio::fs::symlink_metadata(&path).await {
        Ok(meta) => meta,
        Err(e) => return Ok(failed(e)),
    };
    // A link is deleted, never followed: removing what it points at is not
    // what anyone means by deleting a shortcut — and here it would also be a
    // way to reach outside the roots.
    let result = if meta.is_dir() {
        if body.recursive {
            tokio::fs::remove_dir_all(&path).await
        } else {
            tokio::fs::remove_dir(&path).await
        }
    } else {
        tokio::fs::remove_file(&path).await
    };
    match result {
        Ok(()) => Ok(HttpResponse::Ok().finish()),
        Err(e) => Ok(failed(e)),
    }
}

pub async fn rename(
    req: HttpRequest,
    body: web::types::Json<RenameBody>,
    state: web::types::State<Arc<AppState>>,
) -> Result<HttpResponse, web::Error> {
    if let Err(res) = admit(&req, &state, "rename", &body.from).await {
        return Ok(res);
    }
    let roots = &state.remote_access.fs.roots;
    // Both ends checked. Only checking the source would make rename a way to
    // move a file anywhere the agent can write.
    let from = match roots.resolve_entry(&body.from) {
        Ok(path) => path,
        Err(e) => return Ok(denied(e)),
    };
    let to = match roots.resolve_new(&body.to) {
        Ok(path) => path,
        Err(e) => return Ok(denied(e)),
    };
    // Moving a directory the agent's state is in would carry that state to a
    // name nothing protects — see `Protected`.
    for end in [&from, &to] {
        if let Err(e) = roots.check_mutable(end) {
            return Ok(denied(e));
        }
    }
    // As in `remove`: a root is what the confinement is defined against, and
    // renaming one leaves it pointing at a path that no longer exists — after
    // which every request 403s because nothing under it can be canonicalised.
    if roots.as_slice().iter().any(|root| root == &from) {
        return Ok(denied(FsDenied::OutsideRoots));
    }
    // Under the writers' lock, like a write's own rename.
    let _replacing = REPLACE.lock().await;
    match tokio::fs::rename(&from, &to).await {
        Ok(()) => Ok(HttpResponse::Ok().finish()),
        Err(e) => Ok(failed(e)),
    }
}

pub async fn chmod(
    req: HttpRequest,
    body: web::types::Json<ChmodBody>,
    state: web::types::State<Arc<AppState>>,
) -> Result<HttpResponse, web::Error> {
    if let Err(res) = admit(&req, &state, "chmod", &body.path).await {
        return Ok(res);
    }
    let path = match state.remote_access.fs.roots.resolve_existing(&body.path) {
        Ok(path) => path,
        Err(e) => return Ok(denied(e)),
    };
    // A directory the agent's state is in keeps its mode: opening it up is
    // handing the state to whoever else is on the machine.
    if let Err(e) = state.remote_access.fs.roots.check_mutable(&path) {
        return Ok(denied(e));
    }
    set_mode(&path, body.mode).await
}

#[cfg(unix)]
async fn set_mode(path: &Path, mode: u32) -> Result<HttpResponse, web::Error> {
    use std::os::unix::fs::PermissionsExt;
    // Permission bits only. The type bits live in the same number on some
    // platforms and setting them is not what `chmod` means.
    let perms = std::fs::Permissions::from_mode(mode & 0o7777);
    match tokio::fs::set_permissions(path, perms).await {
        Ok(()) => Ok(HttpResponse::Ok().finish()),
        Err(e) => Ok(failed(e)),
    }
}

#[cfg(not(unix))]
async fn set_mode(_path: &Path, _mode: u32) -> Result<HttpResponse, web::Error> {
    // Windows has no POSIX mode to set, and the app asks first: its
    // `FileBackendTraits.permissions` is what decides whether the menu entry
    // is drawn at all.
    Ok(HttpResponse::NotImplemented()
        .json(&serde_json::json!({ "error": "this platform has no file modes" })))
}

/// One entry, described the way the app's `FileEntry` is.
///
/// `symlink_metadata` rather than `metadata`: a listing should say "this is a
/// link", not silently describe whatever it points at — which may be outside
/// the roots, or may not exist.
async fn view_of(path: &Path) -> EntryView {
    let name = path
        .file_name()
        .map(|n| n.to_string_lossy().into_owned())
        .unwrap_or_else(|| path.to_string_lossy().into_owned());

    let Ok(meta) = tokio::fs::symlink_metadata(path).await else {
        return EntryView {
            name,
            kind: "other",
            size: None,
            modified: None,
            mode: None,
            link_target: None,
            version: None,
        };
    };

    let kind = if meta.is_symlink() {
        "link"
    } else if meta.is_dir() {
        "dir"
    } else if meta.is_file() {
        "file"
    } else {
        "other"
    };

    let link_target = if meta.is_symlink() {
        tokio::fs::read_link(path)
            .await
            .ok()
            .map(|p| exposed_path(&p))
    } else {
        None
    };

    EntryView {
        name,
        kind,
        size: meta.is_file().then_some(meta.len()),
        modified: meta
            .modified()
            .ok()
            .and_then(|t| t.duration_since(std::time::UNIX_EPOCH).ok())
            .map(|d| d.as_secs() as i64),
        mode: mode_of(&meta),
        link_target,
        version: version_of(&meta),
    }
}

/// This exact state of a file, as an opaque token: modification time in
/// nanoseconds since the epoch and the size. `None` where the platform does not
/// report a time — the caller then has no guard rather than a wrong one.
///
/// Nanoseconds because a second is coarse enough for two writes to share one;
/// the size is there so a change is visible even where the clock has no
/// sub-second resolution.
fn version_of(meta: &std::fs::Metadata) -> Option<String> {
    Some(version_token(meta.modified().ok()?, meta.len()))
}

/// [`version_of`]'s token from its parts. A time before the epoch is a valid
/// time (`touch -d 1960-01-01`) and gets a `-`, rather than no token and so no
/// guard at all.
fn version_token(modified: std::time::SystemTime, size: u64) -> String {
    match modified.duration_since(std::time::UNIX_EPOCH) {
        Ok(after) => format!("{}-{size}", after.as_nanos()),
        Err(before) => format!("-{}-{size}", before.duration().as_nanos()),
    }
}

/// [`version_of`] for a path, resolved. `None` when it cannot be stated — the
/// file is not there, or the platform does not say — which the write's
/// `if_version` check reads as "not what the caller saw".
async fn version_at(path: &Path) -> Option<String> {
    let meta = tokio::fs::metadata(path).await.ok()?;
    version_of(&meta)
}

/// Paths crossing the HTTP boundary use `/` on every platform, matching the
/// app's `FileBackend` contract. Windows canonical paths also carry a `\\?\`
/// prefix that is useful to the OS but not a path a user should have to see or
/// send back.
fn exposed_path(path: &Path) -> String {
    let raw = path.to_string_lossy();
    #[cfg(windows)]
    {
        let without_verbatim = if let Some(rest) = raw.strip_prefix(r"\\?\UNC\") {
            format!(r"\\{rest}")
        } else if let Some(rest) = raw.strip_prefix(r"\\?\") {
            rest.to_string()
        } else {
            raw.into_owned()
        };
        without_verbatim.replace('\\', "/")
    }
    #[cfg(not(windows))]
    {
        raw.into_owned()
    }
}

#[cfg(unix)]
fn mode_of(meta: &std::fs::Metadata) -> Option<u32> {
    use std::os::unix::fs::PermissionsExt;
    Some(meta.permissions().mode() & 0o7777)
}

#[cfg(not(unix))]
fn mode_of(_meta: &std::fs::Metadata) -> Option<u32> {
    None
}

/// The marker [`staging_path`] puts in a name.
const STAGING_MARK: &str = ".sbm-part-";

/// Whether a name is a write's staged copy.
fn is_staging_name(name: &str) -> bool {
    name.contains(STAGING_MARK)
}

/// A staged file that is removed when this is dropped, unless [`Self::keep`]
/// was called after it was renamed into place. A drop runs whichever way the
/// write ends, cancellation included, which no explicit cleanup branch can
/// promise.
struct Staged {
    path: PathBuf,
    keep: bool,
}

impl Staged {
    fn new(path: PathBuf) -> Self {
        Self { path, keep: false }
    }

    fn keep(&mut self) {
        self.keep = true;
    }
}

impl Drop for Staged {
    fn drop(&mut self) {
        if !self.keep {
            // Synchronous on purpose: a drop cannot await, and this is one
            // unlink. After a successful rename the name is already gone.
            let _ = std::fs::remove_file(&self.path);
        }
    }
}

/// Where a write parks its bytes until it can be renamed into place.
///
/// The process id and a counter, so two writes to one path from two requests
/// cannot stage onto each other.
fn staging_path(path: &Path) -> PathBuf {
    use std::sync::atomic::{AtomicU64, Ordering};
    static SEQ: AtomicU64 = AtomicU64::new(0);
    let n = SEQ.fetch_add(1, Ordering::Relaxed);
    let mut name = path.as_os_str().to_os_string();
    name.push(format!("{STAGING_MARK}{}-{n}", std::process::id()));
    PathBuf::from(name)
}

#[cfg(test)]
mod tests {
    use super::*;
    use std::time::{Duration, UNIX_EPOCH};

    #[test]
    fn a_version_tells_both_sides_of_the_epoch_apart() {
        let after = version_token(UNIX_EPOCH + Duration::from_nanos(5), 3);
        let before = version_token(UNIX_EPOCH - Duration::from_nanos(5), 3);
        assert_eq!(after, "5-3");
        assert_eq!(before, "-5-3");
        assert_ne!(after, before);
        assert_eq!(version_token(UNIX_EPOCH, 0), "0-0");
    }

    #[test]
    fn a_staged_file_goes_unless_it_was_kept() {
        let dir = tempfile::tempdir().unwrap();
        let dropped = dir.path().join("a.sbm-part-1-1");
        std::fs::write(&dropped, "half").unwrap();
        drop(Staged::new(dropped.clone()));
        assert!(!dropped.exists(), "a dropped write leaves no staged file");

        let kept = dir.path().join("b.sbm-part-1-2");
        std::fs::write(&kept, "whole").unwrap();
        let mut staged = Staged::new(kept.clone());
        staged.keep();
        drop(staged);
        assert!(kept.exists(), "a kept one is the renamed file's business");
    }

    #[test]
    fn a_staging_name_is_recognised() {
        let staged = staging_path(Path::new("/srv/note.txt"));
        assert!(is_staging_name(&staged.file_name().unwrap().to_string_lossy()));
        assert!(!is_staging_name("note.txt"));
    }
}
