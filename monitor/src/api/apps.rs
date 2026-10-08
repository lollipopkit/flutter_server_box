//! `/api/v1/apps*` — desk apps an admin installs (`docs/dev/desk-sys.md`).
//!
//! - `GET /apps`: the installed apps. Every account sees the approved ones;
//!   an admin also those waiting for approval.
//! - `POST /apps` (admin): a package (`.fsba`, a gzipped tar) as the body.
//!   Checked whole, then stored waiting for approval; a new version of an
//!   installed app keeps its approval only when it asks for nothing more.
//! - `PUT /apps/{id}/approval` (admin, password): approves exactly the
//!   permissions the manifest lists.
//! - `DELETE /apps/{id}` (admin, password).
//! - `GET /apps/{id}/launch`: where the panel loads the app's UI from: a
//!   ticketed path, since an iframe sends no bearer header.
//! - `GET /apps/{id}/ui/{ticket}/{path}`: the bundle's files, sandboxed by
//!   their CSP so they run in an opaque origin even when opened directly.
//!
//! # Trust
//!
//! An app's code never runs in the panel's own origin (it could read the
//! session token there): the panel frames it with `sandbox="allow-scripts"`
//! and the files carry `Content-Security-Policy: sandbox …; connect-src
//! 'none'`, so the bundle reaches nothing but the desk's message bridge.
//! Installing is an admin's decision and approving one asks for the admin's
//! password. The files live in the database (outside every `fs.roots`), so
//! no file grant can rewrite approved code.
//!
//! A `web` app is UI only: its permissions are the desk's (`notifications`,
//! `background`). A `wasm` app adds `backend.wasm`, run by the agent
//! (`api::app_runtime`), and may ask for what that reaches (`status`,
//! `files.read`, `exec`), each still bounded by the calling account's grants.

use std::collections::{BTreeMap, BTreeSet, HashSet};
use std::io::Read;
use std::sync::Arc;

use ntex::util::Bytes;
use ntex::web::{self, HttpRequest, HttpResponse};
use serde::{Deserialize, Serialize};
use sha2::{Digest, Sha256};

use super::admin::{Reauth, reauth};
use super::authz::{self, Caller};
use super::server::AppState;
use super::ws::audit::{Action, Event, Kind, Outcome, peer_ip};

/// The upload, compressed.
pub const MAX_PACKAGE_BYTES: usize = 20 << 20;
/// Everything in it, uncompressed: read and counted entry by entry, so a
/// small archive that inflates without end is refused at this point.
const MAX_UNPACKED_BYTES: u64 = 20 << 20;
const MAX_FILES: usize = 2000;
/// Room for the archive's own headers on top of the files' bytes.
const HEADER_ALLOWANCE: u64 = 4 << 20;
const MAX_PATH_BYTES: usize = 200;
const MAX_MANIFEST_BYTES: u64 = 64 << 10;
/// How long a launch ticket opens the UI for.
const TICKET_SECS: i64 = 12 * 3600;
const API_VERSION: u32 = 1;

/// What a `web` app may ask for. A backend's (`files.read`, `exec`, …)
/// come with `wasm`.
const WEB_PERMISSIONS: &[&str] = &["notifications", "background"];
const WASM_PERMISSIONS: &[&str] = &["notifications", "background", "status", "files.read", "exec"];
/// The panel's own apps (`desk/apps/<id>`): an installed app never takes
/// one's id, nor the storage its users keep under it.
const BUILT_IN: &[&str] = &[
    "status", "files", "terminal", "containers", "process", "services", "cron", "system_users", "firewall", "snippets",
    "remote_desktop", "benchmark", "virt", "bmc", "backup", "settings",
];
const TONES: &[&str] = &["berry", "soft", "ink", "sky", "teal", "violet", "amber", "leaf", "pale", "bright", "mist"];

// -----------------------------------------------------------------------------
// Manifest
// -----------------------------------------------------------------------------

#[derive(Debug, Clone, PartialEq, Serialize, Deserialize)]
#[serde(deny_unknown_fields)]
pub struct Manifest {
    pub id: String,
    pub version: String,
    pub api: u32,
    pub kind: String,
    /// A string, or translations by locale (`en` required then).
    pub title: serde_json::Value,
    pub glyph: String,
    pub tone: String,
    #[serde(default)]
    pub permissions: Vec<String>,
    #[serde(default, skip_serializing_if = "Option::is_none")]
    pub instances: Option<u32>,
    #[serde(default, skip_serializing_if = "Option::is_none")]
    pub size: Option<Size>,
    #[serde(default, skip_serializing_if = "Option::is_none")]
    pub min_size: Option<Size>,
    #[serde(default, skip_serializing_if = "Option::is_none")]
    pub opens: Option<Opens>,
    #[serde(default, skip_serializing_if = "Vec::is_empty")]
    pub keywords: Vec<String>,
}

#[derive(Debug, Clone, Copy, PartialEq, Serialize, Deserialize)]
#[serde(deny_unknown_fields)]
pub struct Size {
    pub width: u32,
    pub height: u32,
}

#[derive(Debug, Clone, PartialEq, Serialize, Deserialize)]
#[serde(deny_unknown_fields)]
pub struct Opens {
    #[serde(default)]
    pub dirs: bool,
    #[serde(default)]
    pub ext: Vec<String>,
}

/// Why a package was refused: a stable code, and the entry when there is one.
#[derive(Debug, Clone, PartialEq, Eq, Serialize)]
pub struct Refusal {
    pub error: &'static str,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub path: Option<String>,
}

fn refused(error: &'static str) -> Refusal {
    Refusal { error, path: None }
}

fn refused_at(error: &'static str, path: &str) -> Refusal {
    Refusal { error, path: Some(path.chars().take(MAX_PATH_BYTES).collect()) }
}

/// A third party's id: a publisher prefix, `_`, a name (`acme_notes`), as a
/// desk app id (`api::desk::valid_app_id`). The prefix keeps it off the
/// built-in apps' plain names.
pub fn valid_package_id(id: &str) -> bool {
    !BUILT_IN.contains(&id)
        && super::desk::valid_app_id(id)
        && id.split_once('_').is_some_and(|(publisher, name)| publisher.len() >= 2 && !name.is_empty())
}

fn short_text(text: &str, max: usize) -> bool {
    (1..=max).contains(&text.chars().count()) && !text.chars().any(char::is_control)
}

fn valid_size(s: &Size) -> bool {
    (200..=4000).contains(&s.width) && (150..=4000).contains(&s.height)
}

pub fn check_manifest(m: &Manifest) -> Result<(), Refusal> {
    if !valid_package_id(&m.id) {
        return Err(refused("invalidId"));
    }
    if !short_text(&m.version, 32) {
        return Err(refused("invalidVersion"));
    }
    if m.api != API_VERSION {
        return Err(refused("unsupportedApi"));
    }
    let allowed = match m.kind.as_str() {
        "web" => WEB_PERMISSIONS,
        "wasm" => WASM_PERMISSIONS,
        _ => return Err(refused("invalidKind")),
    };
    let title_ok = match &m.title {
        serde_json::Value::String(t) => short_text(t, 64),
        serde_json::Value::Object(map) => {
            map.contains_key("en")
                && map.len() <= 32
                && map.iter().all(|(locale, t)| {
                    short_text(locale, 16) && t.as_str().is_some_and(|t| short_text(t, 64))
                })
        }
        _ => false,
    };
    if !title_ok {
        return Err(refused("invalidTitle"));
    }
    if !(1..=64).contains(&m.glyph.len()) || !m.glyph.bytes().all(|b| b.is_ascii_lowercase() || b.is_ascii_digit() || b == b'_') {
        return Err(refused("invalidGlyph"));
    }
    if !TONES.contains(&m.tone.as_str()) {
        return Err(refused("invalidTone"));
    }
    let mut seen = HashSet::new();
    for p in &m.permissions {
        if !allowed.contains(&p.as_str()) {
            return Err(refused("invalidPermission"));
        }
        if !seen.insert(p) {
            return Err(refused("invalidPermission"));
        }
    }
    if m.instances.is_some_and(|n| !(1..=8).contains(&n)) {
        return Err(refused("invalidInstances"));
    }
    if m.size.as_ref().is_some_and(|s| !valid_size(s)) || m.min_size.as_ref().is_some_and(|s| !valid_size(s)) {
        return Err(refused("invalidSize"));
    }
    if let Some(opens) = &m.opens {
        let ext_ok = opens.ext.len() <= 32
            && opens.ext.iter().all(|e| e == "*" || ((1..=16).contains(&e.len()) && e.bytes().all(|b| b.is_ascii_lowercase() || b.is_ascii_digit())));
        if !ext_ok {
            return Err(refused("invalidOpens"));
        }
    }
    if m.keywords.len() > 16 || !m.keywords.iter().all(|k| short_text(k, 32)) {
        return Err(refused("invalidKeywords"));
    }
    Ok(())
}

// -----------------------------------------------------------------------------
// Package
// -----------------------------------------------------------------------------

#[derive(Debug)]
pub struct Package {
    pub manifest: Manifest,
    /// By path relative to the package root: `ui/index.html`, `LICENSE`.
    pub files: BTreeMap<String, Vec<u8>>,
    pub sha256: String,
}

/// A path inside a package: relative, `/`-separated, plain components.
fn valid_entry_path(path: &str) -> bool {
    (1..=MAX_PATH_BYTES).contains(&path.len())
        && path.bytes().all(|b| b.is_ascii_alphanumeric() || matches!(b, b'.' | b'_' | b'-' | b'/'))
        && path.split('/').all(|c| !c.is_empty() && c != "." && c != ".." && !c.starts_with('.'))
}

/// What may sit at a package's top: the UI, the manifest, notices.
fn allowed_top(path: &str) -> bool {
    path == "manifest.json" || path == "backend.wasm" || path.starts_with("ui/") || ["LICENSE", "README.md", "NOTICE"].contains(&path)
}

/// Reads and checks a whole package. Nothing is stored before every entry
/// and the manifest are known good.
pub fn read_package(bytes: &[u8]) -> Result<Package, Refusal> {
    if bytes.len() > MAX_PACKAGE_BYTES {
        return Err(refused("tooLarge"));
    }
    let sha256 = hex::encode(Sha256::digest(bytes));
    // Everything inflated is bounded here, headers included: tar reads a
    // long-name or PAX header whole, before any entry's own bound applies.
    let inflated = flate2::read::GzDecoder::new(bytes).take(MAX_UNPACKED_BYTES + HEADER_ALLOWANCE);
    let mut archive = tar::Archive::new(inflated);
    let mut files = BTreeMap::new();
    let mut total: u64 = 0;
    let mut seen = 0usize;
    let entries = archive.entries().map_err(|_| refused("notAPackage"))?;
    for entry in entries {
        let mut entry = entry.map_err(|_| refused("notAPackage"))?;
        // Directories and every other entry count too.
        seen += 1;
        if seen > MAX_FILES {
            return Err(refused("tooManyFiles"));
        }
        let raw = entry.path_bytes();
        let path = std::str::from_utf8(&raw).map_err(|_| refused("invalidPath"))?.trim_start_matches("./").to_string();
        let kind = entry.header().entry_type();
        if kind.is_dir() {
            continue;
        }
        if !kind.is_file() {
            // Links, devices, and the rest.
            return Err(refused_at("notAFile", &path));
        }
        if !valid_entry_path(&path) {
            return Err(refused_at("invalidPath", &path));
        }
        if !allowed_top(&path) {
            return Err(refused_at("unexpectedFile", &path));
        }
        // The header's size is a claim; the reader is bounded by what is
        // left of the budget either way.
        let left = MAX_UNPACKED_BYTES - total;
        let mut data = Vec::new();
        (&mut entry).take(left + 1).read_to_end(&mut data).map_err(|_| refused("notAPackage"))?;
        total += data.len() as u64;
        if total > MAX_UNPACKED_BYTES {
            return Err(refused("tooLarge"));
        }
        if files.insert(path.clone(), data).is_some() {
            return Err(refused_at("duplicateFile", &path));
        }
    }
    let raw = files.get("manifest.json").ok_or_else(|| refused("noManifest"))?;
    if raw.len() as u64 > MAX_MANIFEST_BYTES {
        return Err(refused("invalidManifest"));
    }
    let manifest: Manifest = serde_json::from_slice(raw).map_err(|_| refused("invalidManifest"))?;
    check_manifest(&manifest)?;
    if !files.contains_key("ui/index.html") {
        return Err(refused("noEntry"));
    }
    // A backend is what `wasm` means, and only `wasm` brings one.
    if files.contains_key("backend.wasm") != (manifest.kind == "wasm") {
        return Err(refused("backendMismatch"));
    }
    Ok(Package { manifest, files, sha256 })
}

/// The type a served file is given, by extension. Anything else is served
/// as bytes, which a browser will not run.
fn mime_of(path: &str) -> &'static str {
    match path.rsplit_once('.').map(|(_, e)| e.to_ascii_lowercase()).as_deref() {
        Some("html") => "text/html; charset=utf-8",
        Some("js" | "mjs") => "text/javascript; charset=utf-8",
        Some("css") => "text/css; charset=utf-8",
        Some("json") => "application/json",
        Some("svg") => "image/svg+xml",
        Some("png") => "image/png",
        Some("jpg" | "jpeg") => "image/jpeg",
        Some("webp") => "image/webp",
        Some("gif") => "image/gif",
        Some("woff2") => "font/woff2",
        Some("woff") => "font/woff",
        Some("wasm") => "application/wasm",
        Some("txt" | "md") => "text/plain; charset=utf-8",
        _ => "application/octet-stream",
    }
}

/// What a served file may do: run its own scripts in an opaque origin and
/// load from its own bundle, nothing else.
const UI_CSP: &str = "sandbox allow-scripts allow-forms; default-src 'self'; script-src 'self' 'wasm-unsafe-eval'; \
style-src 'self' 'unsafe-inline'; img-src 'self' data: blob:; font-src 'self' data:; media-src 'self' data: blob:; \
connect-src 'none'; form-action 'none'; base-uri 'none'; object-src 'none'";

// -----------------------------------------------------------------------------
// Launch tickets
// -----------------------------------------------------------------------------

fn ticket_key(state: &AppState) -> ring::hmac::Key {
    // Derived, so the JWT secret itself signs nothing but tokens.
    let root = ring::hmac::Key::new(ring::hmac::HMAC_SHA256, state.config.get_jwt_secret().as_bytes());
    let derived = ring::hmac::sign(&root, b"sbm desk app ui ticket v1");
    ring::hmac::Key::new(ring::hmac::HMAC_SHA256, derived.as_ref())
}

fn ticket_message(app: &str, package: &str, expires: i64) -> Vec<u8> {
    format!("{app}\n{package}\n{expires}").into_bytes()
}

/// `<expiry>.<mac>`: opens [app]'s package [package] (its sha256) until the
/// expiry; a new package, even under the same version, needs a new ticket.
pub fn mint_ticket(state: &AppState, app: &str, package: &str, now: i64) -> String {
    let expires = now + TICKET_SECS;
    let tag = ring::hmac::sign(&ticket_key(state), &ticket_message(app, package, expires));
    format!("{expires}.{}", hex::encode(tag.as_ref()))
}

pub fn ticket_ok(state: &AppState, ticket: &str, app: &str, package: &str, now: i64) -> bool {
    let Some((expires, mac)) = ticket.split_once('.') else { return false };
    let Ok(expires) = expires.parse::<i64>() else { return false };
    let Ok(mac) = hex::decode(mac) else { return false };
    expires > now
        && expires <= now + TICKET_SECS
        && ring::hmac::verify(&ticket_key(state), &ticket_message(app, package, expires), &mac).is_ok()
}

// -----------------------------------------------------------------------------
// Storage
// -----------------------------------------------------------------------------

#[derive(Debug, Serialize)]
pub struct Installed {
    pub id: String,
    pub version: String,
    /// Of the package: what an approval names, so it approves exactly the
    /// code the admin saw.
    pub sha256: String,
    pub manifest: Manifest,
    /// Null while waiting for approval.
    pub approved_permissions: Option<Vec<String>>,
    pub installed_by: String,
    pub installed_at: String,
    pub approved_at: Option<String>,
}

type Row = (String, String, String, String, Option<String>, String, String, Option<String>);

fn installed(row: Row) -> Option<Installed> {
    let (id, version, sha256, manifest, approved, installed_by, installed_at, approved_at) = row;
    Some(Installed {
        id,
        version,
        sha256,
        manifest: serde_json::from_str(&manifest).ok()?,
        approved_permissions: match approved {
            Some(a) => Some(serde_json::from_str(&a).ok()?),
            None => None,
        },
        installed_by,
        installed_at,
        approved_at,
    })
}

macro_rules! select {
    ($tail:literal) => {
        concat!(
            "SELECT app_id, version, sha256, manifest, approved_permissions, installed_by, installed_at, approved_at \
             FROM desk_app_package ",
            $tail
        )
    };
}

async fn load(db: &sqlx::SqlitePool, id: &str) -> Result<Option<Installed>, sqlx::Error> {
    let row = sqlx::query_as::<_, Row>(select!("WHERE app_id = ?")).bind(id).fetch_optional(db).await?;
    Ok(row.and_then(installed))
}

/// Stores [package], replacing an installed version. Its approval stays only
/// for the very same package (an upload needs no password; an approval does,
/// so new code always waits for one).
async fn store(db: &sqlx::SqlitePool, package: &Package, by: &str) -> Result<Installed, sqlx::Error> {
    let m = &package.manifest;
    let mut tx = db.begin().await?;
    let previous: Option<(String, Option<String>)> =
        sqlx::query_as("SELECT sha256, approved_permissions FROM desk_app_package WHERE app_id = ?")
            .bind(&m.id)
            .fetch_optional(&mut *tx)
            .await?;
    let kept = previous.and_then(|(sha, approved)| approved.filter(|_| sha == package.sha256));
    let now = chrono::Utc::now().to_rfc3339();
    sqlx::query("DELETE FROM desk_app_file WHERE app_id = ?").bind(&m.id).execute(&mut *tx).await?;
    sqlx::query(
        "INSERT INTO desk_app_package (app_id, version, manifest, sha256, approved_permissions, installed_by, installed_at, approved_at) \
         VALUES (?, ?, ?, ?, ?, ?, ?, ?) ON CONFLICT(app_id) DO UPDATE SET version = excluded.version, \
         manifest = excluded.manifest, sha256 = excluded.sha256, approved_permissions = excluded.approved_permissions, \
         installed_by = excluded.installed_by, installed_at = excluded.installed_at, \
         approved_at = CASE WHEN excluded.approved_permissions IS NULL THEN NULL ELSE desk_app_package.approved_at END",
    )
    .bind(&m.id)
    .bind(&m.version)
    .bind(serde_json::to_string(m).unwrap_or_default())
    .bind(&package.sha256)
    .bind(&kept)
    .bind(by)
    .bind(&now)
    .bind(kept.as_ref().map(|_| now.clone()))
    .execute(&mut *tx)
    .await?;
    for (path, bytes) in &package.files {
        sqlx::query("INSERT INTO desk_app_file (app_id, path, bytes) VALUES (?, ?, ?)")
            .bind(&m.id)
            .bind(path)
            .bind(bytes.as_slice())
            .execute(&mut *tx)
            .await?;
    }
    tx.commit().await?;
    Ok(load(db, &m.id).await?.expect("just stored"))
}

// -----------------------------------------------------------------------------
// Handlers
// -----------------------------------------------------------------------------

macro_rules! require {
    ($result:expr) => {{
        match $result {
            Ok(value) => value,
            Err(response) => return Ok(response),
        }
    }};
}

fn internal_error(e: &sqlx::Error) -> HttpResponse {
    tracing::error!("apps: {e}");
    HttpResponse::InternalServerError().json(&serde_json::json!({ "error": "internal" }))
}

fn not_found() -> HttpResponse {
    HttpResponse::NotFound().json(&refused("notFound"))
}

async fn audit(req: &HttpRequest, state: &AppState, caller: &Caller, action: Action, detail: String) {
    Event::new(Kind::Admin, action, Outcome::Ok)
        .subject(&caller.username)
        .remote_ip(peer_ip(req))
        .detail(detail)
        .record(&state.db)
        .await;
}

pub async fn list(req: HttpRequest, state: web::types::State<Arc<AppState>>) -> Result<HttpResponse, web::Error> {
    let caller = require!(authz::jwt_caller(&req, &state).await);
    let rows = sqlx::query_as::<_, Row>(select!("ORDER BY app_id")).fetch_all(&state.db).await;
    match rows {
        Ok(rows) => {
            let apps: Vec<Installed> = rows
                .into_iter()
                .filter_map(installed)
                .filter(|a| a.approved_permissions.is_some() || caller.is_admin())
                .collect();
            Ok(HttpResponse::Ok().json(&serde_json::json!({ "apps": apps })))
        }
        Err(e) => Ok(internal_error(&e)),
    }
}

pub async fn install(
    req: HttpRequest,
    body: Bytes,
    state: web::types::State<Arc<AppState>>,
) -> Result<HttpResponse, web::Error> {
    let caller = require!(authz::admin_caller(&req, &state).await);
    // Inflating and checking takes a while: off the worker.
    let package = match tokio::task::spawn_blocking(move || read_package(&body)).await {
        Ok(Ok(p)) => p,
        Ok(Err(refusal)) => {
            let status = if refusal.error == "tooLarge" { 413 } else { 400 };
            return Ok(HttpResponse::build(ntex::http::StatusCode::from_u16(status).unwrap()).json(&refusal));
        }
        Err(_) => return Ok(HttpResponse::InternalServerError().json(&refused("internal"))),
    };
    match store(&state.db, &package, &caller.username).await {
        Ok(app) => {
            audit(&req, &state, &caller, Action::Write, format!("app install {} {} {}", app.id, app.version, package.sha256)).await;
            Ok(HttpResponse::Ok().json(&app))
        }
        Err(e) => Ok(internal_error(&e)),
    }
}

#[derive(Deserialize)]
#[serde(deny_unknown_fields)]
pub struct Approval {
    /// The package the admin looked at.
    sha256: String,
    permissions: Vec<String>,
    current_password: Option<String>,
}

pub async fn approve(
    req: HttpRequest,
    id: web::types::Path<String>,
    body: web::types::Json<Approval>,
    state: web::types::State<Arc<AppState>>,
) -> Result<HttpResponse, web::Error> {
    let caller = require!(authz::admin_caller(&req, &state).await);
    let body = body.into_inner();
    require!(reauth(&req, &state, &caller, body.current_password.as_deref()).await);
    let app = match load(&state.db, &id).await {
        Ok(Some(app)) => app,
        Ok(None) => return Ok(not_found()),
        Err(e) => return Ok(internal_error(&e)),
    };
    // Exactly what the manifest asks for: an approval of something else is
    // a screen out of date.
    let asked: BTreeSet<&String> = app.manifest.permissions.iter().collect();
    let given: BTreeSet<&String> = body.permissions.iter().collect();
    if body.sha256 != app.sha256 || asked != given || body.permissions.len() != given.len() {
        return Ok(HttpResponse::Conflict().json(&serde_json::json!({ "error": "permissionsChanged", "app": app })));
    }
    let done = sqlx::query("UPDATE desk_app_package SET approved_permissions = ?, approved_at = ? WHERE app_id = ? AND sha256 = ?")
        .bind(serde_json::to_string(&app.manifest.permissions).unwrap_or_default())
        .bind(chrono::Utc::now().to_rfc3339())
        .bind(&app.id)
        .bind(&app.sha256)
        .execute(&state.db)
        .await;
    match done {
        Ok(r) if r.rows_affected() == 1 => {
            audit(&req, &state, &caller, Action::Write, format!("app approve {} {} {}", app.id, app.version, app.sha256)).await;
            match load(&state.db, &app.id).await {
                Ok(Some(app)) => Ok(HttpResponse::Ok().json(&app)),
                Ok(None) => Ok(not_found()),
                Err(e) => Ok(internal_error(&e)),
            }
        }
        // Replaced between the read and the write.
        Ok(_) => Ok(HttpResponse::Conflict().json(&refused("permissionsChanged"))),
        Err(e) => Ok(internal_error(&e)),
    }
}

pub async fn remove(
    req: HttpRequest,
    id: web::types::Path<String>,
    body: Option<web::types::Json<Reauth>>,
    state: web::types::State<Arc<AppState>>,
) -> Result<HttpResponse, web::Error> {
    let caller = require!(authz::admin_caller(&req, &state).await);
    let password = body.and_then(|b| b.into_inner().current_password);
    require!(reauth(&req, &state, &caller, password.as_deref()).await);
    let mut tx = match state.db.begin().await {
        Ok(tx) => tx,
        Err(e) => return Ok(internal_error(&e)),
    };
    let files = sqlx::query("DELETE FROM desk_app_file WHERE app_id = ?").bind(id.as_str()).execute(&mut *tx).await;
    // What its users kept goes with it: an app installed later under this id
    // starts with nothing of theirs.
    let kept = sqlx::query("DELETE FROM desk_app_storage WHERE app_id = ?").bind(id.as_str()).execute(&mut *tx).await;
    if let Err(e) = kept {
        return Ok(internal_error(&e));
    }
    let package = sqlx::query("DELETE FROM desk_app_package WHERE app_id = ?").bind(id.as_str()).execute(&mut *tx).await;
    match (files, package) {
        (Ok(_), Ok(r)) => {
            if let Err(e) = tx.commit().await {
                return Ok(internal_error(&e));
            }
            if r.rows_affected() == 0 {
                return Ok(not_found());
            }
            audit(&req, &state, &caller, Action::Write, format!("app remove {}", id.as_str())).await;
            Ok(HttpResponse::NoContent().finish())
        }
        (Err(e), _) | (_, Err(e)) => Ok(internal_error(&e)),
    }
}

pub async fn launch(
    req: HttpRequest,
    id: web::types::Path<String>,
    state: web::types::State<Arc<AppState>>,
) -> Result<HttpResponse, web::Error> {
    require!(authz::jwt_caller(&req, &state).await);
    let app = match load(&state.db, &id).await {
        Ok(Some(app)) if app.approved_permissions.is_some() => app,
        Ok(_) => return Ok(not_found()),
        Err(e) => return Ok(internal_error(&e)),
    };
    let ticket = mint_ticket(&state, &app.id, &app.sha256, chrono::Utc::now().timestamp());
    Ok(HttpResponse::Ok().json(&serde_json::json!({
        "url": format!("/api/v1/apps/{}/ui/{ticket}/index.html", app.id),
        // The desk's design system, which the app's frame loads to look like
        // the desk without carrying any of it (`api::assets::desk_app`).
        "stylesheet": "/desk-app/desk.css",
        "version": app.version,
    })))
}

pub async fn ui(
    path: web::types::Path<(String, String, String)>,
    state: web::types::State<Arc<AppState>>,
) -> Result<HttpResponse, web::Error> {
    let (id, ticket, file) = path.into_inner();

    let package: Option<(String, Option<String>)> =
        match sqlx::query_as("SELECT sha256, approved_permissions FROM desk_app_package WHERE app_id = ?")
            .bind(&id)
            .fetch_optional(&state.db)
            .await
        {
            Ok(v) => v,
            Err(e) => return Ok(internal_error(&e)),
        };
    let Some((sha256, Some(_))) = package else { return Ok(not_found()) };
    if !ticket_ok(&state, &ticket, &id, &sha256, chrono::Utc::now().timestamp()) {
        return Ok(HttpResponse::Forbidden().json(&refused("ticket")));
    }
    let file = format!("ui/{file}");
    if !valid_entry_path(&file) {
        return Ok(not_found());
    }
    let bytes: Option<Vec<u8>> = match sqlx::query_scalar("SELECT bytes FROM desk_app_file WHERE app_id = ? AND path = ?")
        .bind(&id)
        .bind(&file)
        .fetch_optional(&state.db)
        .await
    {
        Ok(b) => b,
        Err(e) => return Ok(internal_error(&e)),
    };
    let Some(bytes) = bytes else { return Ok(not_found()) };
    Ok(HttpResponse::Ok()
        .content_type(mime_of(&file))
        .header("content-security-policy", UI_CSP)
        .header("x-content-type-options", "nosniff")
        .header("referrer-policy", "no-referrer")
        // Module scripts load with CORS even from the bundle itself: the
        // frame's origin is opaque. No credentials ride on these requests.
        .header("access-control-allow-origin", "*")
        .header("cross-origin-resource-policy", "cross-origin")
        .header("cache-control", "private, max-age=300")
        .body(bytes))
}

#[cfg(test)]
mod tests {
    use super::*;

    fn manifest() -> Manifest {
        Manifest {
            id: "acme_notes".into(),
            version: "1.0.0".into(),
            api: 1,
            kind: "web".into(),
            title: serde_json::json!({ "en": "Notes", "de": "Notizen" }),
            glyph: "sticky_note_2".into(),
            tone: "amber".into(),
            permissions: vec!["notifications".into()],
            instances: Some(2),
            size: Some(Size { width: 800, height: 600 }),
            min_size: None,
            opens: Some(Opens { dirs: false, ext: vec!["md".into(), "txt".into()] }),
            keywords: vec![],
        }
    }

    #[test]
    fn a_manifest_is_checked_field_by_field() {
        assert_eq!(check_manifest(&manifest()), Ok(()));
        type Case = (fn(&mut Manifest), &'static str);
        let cases: Vec<Case> = vec![
            (|m| m.id = "notes".into(), "invalidId"),
            (|m| m.id = "files".into(), "invalidId"),
            (|m| m.id = "a_notes".into(), "invalidId"),
            (|m| m.id = "Acme_notes".into(), "invalidId"),
            (|m| m.version = String::new(), "invalidVersion"),
            (|m| m.api = 2, "unsupportedApi"),
            (|m| m.kind = "native".into(), "invalidKind"),
            (|m| m.title = serde_json::json!({ "de": "Notizen" }), "invalidTitle"),
            (|m| m.title = serde_json::json!(""), "invalidTitle"),
            (|m| m.glyph = "<svg>".into(), "invalidGlyph"),
            (|m| m.tone = "red".into(), "invalidTone"),
            (|m| m.permissions = vec!["exec".into()], "invalidPermission"),
            (|m| m.permissions = vec!["background".into(), "background".into()], "invalidPermission"),
            (|m| m.instances = Some(0), "invalidInstances"),
            (|m| m.size = Some(Size { width: 10, height: 10 }), "invalidSize"),
            (|m| m.opens = Some(Opens { dirs: false, ext: vec![".md".into()] }), "invalidOpens"),
        ];
        for (change, code) in cases {
            let mut m = manifest();
            change(&mut m);
            assert_eq!(check_manifest(&m).map_err(|r| r.error), Err(code), "{m:?}");
        }
    }

    #[test]
    fn entry_paths_stay_inside_the_package() {
        for ok in ["manifest.json", "ui/index.html", "ui/assets/app-1.js"] {
            assert!(valid_entry_path(ok), "{ok}");
        }
        for bad in ["/etc/passwd", "ui/../x", "ui/./x", "ui//x", "ui\\x", "ui/.hidden", "", "ui/a b"] {
            assert!(!valid_entry_path(bad), "{bad}");
        }
    }
}
