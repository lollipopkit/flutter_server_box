//! `/api/v1/apps*` — desk apps the operator installs (`docs/dev/desk-sys.md`).
//!
//! - `GET /apps`: the installed apps, approved or waiting for approval.
//! - `POST /apps`: a package (`.fsba`, a gzipped tar) as the body.
//!   Checked whole, then stored waiting for approval; a new version of an
//!   installed app keeps its approval only when it asks for nothing more.
//! - `PUT /apps/{id}/approval` (password): approves exactly the
//!   permissions the manifest lists.
//! - `DELETE /apps/{id}` (password).
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
//! Approving one asks for the password again. The files live in the
//! database, which the file API never reaches (`fs_roots::Protected`), so
//! it cannot rewrite approved code.
//!
//! A `web` app is UI only: its permissions are the desk's (`notifications`,
//! `background`). A `wasm` app (API 2) adds `backend.wasm`, a component the
//! agent runs (`apps::runtime`, `api::app_backend`), and may ask for what
//! that reaches (`status`, `process`, `root`), each still bounded by the
//! transport rule.

use std::collections::{BTreeMap, BTreeSet, HashSet};
use std::io::Read;
use std::sync::Arc;

use ntex::util::Bytes;
use ntex::web::{self, HttpRequest, HttpResponse};
use serde::{Deserialize, Serialize};
use sha2::{Digest, Sha256};

use crate::core::app_id;
use crate::core::blobs::Blobs;
use super::admin::{Reauth, reauth};
use super::authz;
use super::server::AppState;
use super::desk::DeskEvent;
use super::ws::audit::{Action, Event, Kind, Outcome};

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
/// `web`: API 1 or 2 (the same). `wasm`: API 2, a component backend; API 1's
/// core module is refused (TODO: drop API 1 once no `web` package names it).
const WEB_APIS: &[u32] = &[1, 2];
const WASM_API: u32 = 2;

/// What a `web` app may ask for. A backend's come with `wasm`: the status
/// sample, programs as the agent's account, scripts as root (with a sudo
/// password the desk asks for each time), Agent mode's providers and keys,
/// HTTP from the agent.
const WEB_PERMISSIONS: &[&str] = &["notifications", "background"];
const WASM_PERMISSIONS: &[&str] = &["notifications", "background", "status", "process", "root", "providers", "network"];
const TONES: &[&str] = &["berry", "soft", "ink", "sky", "teal", "violet", "amber", "leaf", "pale", "bright", "mist"];

// -----------------------------------------------------------------------------
// Manifest
// -----------------------------------------------------------------------------

#[derive(Debug, Clone, PartialEq, Serialize, Deserialize)]
#[serde(deny_unknown_fields)]
pub struct Manifest {
    /// Who makes it and its name: the id is `<publisher>.<name>`
    /// (`core::app_id`). The panel's own publisher is not one a package takes,
    /// so no package takes a built-in app's id, nor its users' storage.
    pub publisher: String,
    pub name: String,
    pub version: String,
    pub api: u32,
    pub kind: String,
    /// A string, or translations by locale (`en` required then).
    pub title: serde_json::Value,
    /// What it does, in a sentence or two, shown on its App Store page: as
    /// `title`.
    #[serde(default, skip_serializing_if = "Option::is_none")]
    pub description: Option<serde_json::Value>,
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
    /// The systems it is for: `linux`, `macos`, `windows`, or a Linux
    /// distribution by `/etc/os-release`'s `ID` (`ubuntu`); any when empty.
    /// Elsewhere the catalog does not offer it, nor does the agent install it
    /// on its own.
    #[serde(default, skip_serializing_if = "Vec::is_empty")]
    pub os: Vec<String>,
}

impl Manifest {
    /// Whether it is for a machine that is [systems]
    /// (`api::machine::systems`).
    pub fn for_os(&self, systems: &[String]) -> bool {
        self.os.is_empty() || self.os.iter().any(|o| systems.contains(o))
    }
}

impl Manifest {
    pub fn id(&self) -> String {
        format!("{}.{}", self.publisher, self.name)
    }
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

fn short_text(text: &str, max: usize) -> bool {
    (1..=max).contains(&text.chars().count()) && !text.chars().any(char::is_control)
}

/// A string of at most [max] bytes, or such strings by locale with `en`.
fn localized(text: &serde_json::Value, max: usize) -> bool {
    match text {
        serde_json::Value::String(t) => short_text(t, max),
        serde_json::Value::Object(map) => {
            map.contains_key("en")
                && map.len() <= 32
                && map.iter().all(|(locale, t)| short_text(locale, 16) && t.as_str().is_some_and(|t| short_text(t, max)))
        }
        _ => false,
    }
}

fn valid_size(s: &Size) -> bool {
    (200..=4000).contains(&s.width) && (150..=4000).contains(&s.height)
}

/// [first_party]: the package carries a first-party signature
/// (`apps::sign`), the one way to use the panel's own publisher.
pub fn check_manifest(m: &Manifest, first_party: bool) -> Result<(), Refusal> {
    if (m.publisher == app_id::BUILT_IN_PUBLISHER && !first_party) || app_id::make(&m.publisher, &m.name).is_none() {
        return Err(refused("invalidId"));
    }
    if !short_text(&m.version, 32) {
        return Err(refused("invalidVersion"));
    }
    let (allowed, api_ok) = match m.kind.as_str() {
        "web" => (WEB_PERMISSIONS, WEB_APIS.contains(&m.api)),
        "wasm" => (WASM_PERMISSIONS, m.api == WASM_API),
        _ => return Err(refused("invalidKind")),
    };
    if !api_ok {
        return Err(refused("unsupportedApi"));
    }
    if !localized(&m.title, 64) {
        return Err(refused("invalidTitle"));
    }
    if m.description.as_ref().is_some_and(|d| !localized(d, 600)) {
        return Err(refused("invalidDescription"));
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
    if m.os.len() > 16 || !m.os.iter().all(|o| (1..=32).contains(&o.len()) && o.bytes().all(|b| b.is_ascii_lowercase() || b.is_ascii_digit() || b"._-".contains(&b))) {
        return Err(refused("invalidOs"));
    }
    Ok(())
}

// -----------------------------------------------------------------------------
// Package
// -----------------------------------------------------------------------------

#[derive(Debug, Clone)]
pub struct Package {
    pub manifest: Manifest,
    /// By path relative to the package root: `ui/index.html`, `LICENSE`.
    pub files: BTreeMap<String, Vec<u8>>,
    pub sha256: String,
    /// The first-party key that signed it (`apps::sign`); none for an
    /// unknown publisher.
    pub signed_by: Option<&'static str>,
}

/// A path inside a package: relative, `/`-separated, plain components.
fn valid_entry_path(path: &str) -> bool {
    (1..=MAX_PATH_BYTES).contains(&path.len())
        && path.bytes().all(|b| b.is_ascii_alphanumeric() || matches!(b, b'.' | b'_' | b'-' | b'/'))
        && path.split('/').all(|c| !c.is_empty() && c != "." && c != ".." && !c.starts_with('.'))
}

/// What may sit at a package's top: the UI, the manifest, notices.
fn allowed_top(path: &str) -> bool {
    path == "manifest.json" || path == "backend.wasm" || path.starts_with("ui/") || ["LICENSE", "README.md", "NOTICE", crate::apps::sign::SIGNATURE_FILE].contains(&path)
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
    let signed_by = crate::apps::sign::signer(&files).map_err(refused)?;
    check_manifest(&manifest, signed_by.is_some())?;
    if !files.contains_key("ui/index.html") {
        return Err(refused("noEntry"));
    }
    // A backend is what `wasm` means, and only `wasm` brings one.
    if files.contains_key("backend.wasm") != (manifest.kind == "wasm") {
        return Err(refused("backendMismatch"));
    }
    Ok(Package { manifest, files, sha256, signed_by })
}

/// The digest of [package]'s `backend.wasm`, as the blob store names it.
fn backend_sha_of(package: &Package) -> Option<String> {
    package.files.get("backend.wasm").map(|b| hex::encode(Sha256::digest(b)))
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
    /// code the operator saw.
    pub sha256: String,
    pub manifest: Manifest,
    /// Null while waiting for approval.
    pub approved_permissions: Option<Vec<String>>,
    pub installed_at: String,
    pub approved_at: Option<String>,
    /// The first-party key that signed the package; null for an unknown
    /// publisher.
    pub signed_by: Option<String>,
}

type Row = (String, String, String, String, Option<String>, String, Option<String>, Option<String>);

fn installed(row: Row) -> Option<Installed> {
    let (id, version, sha256, manifest, approved, installed_at, approved_at, signed_by) = row;
    Some(Installed {
        id,
        version,
        sha256,
        manifest: serde_json::from_str(&manifest).ok()?,
        approved_permissions: match approved {
            Some(a) => Some(serde_json::from_str(&a).ok()?),
            None => None,
        },
        installed_at,
        approved_at,
        signed_by,
    })
}

macro_rules! select {
    ($tail:literal) => {
        concat!(
            "SELECT app_id, version, sha256, manifest, approved_permissions, installed_at, approved_at, signed_by \
             FROM desk_app_package ",
            $tail
        )
    };
}

async fn load(db: &sqlx::SqlitePool, id: &str) -> Result<Option<Installed>, sqlx::Error> {
    let row = sqlx::query_as::<_, Row>(select!("WHERE app_id = ?")).bind(id).fetch_optional(db).await?;
    Ok(row.and_then(installed))
}

/// Who stores a package, and so what it is granted.
#[derive(Clone, Copy, PartialEq, Eq)]
enum Install {
    /// An upload, or the catalog's package without a password: its approval
    /// stays only for the very same package (an upload needs no password; an
    /// approval does, so new code always waits for one).
    Upload,
    /// The admin installing with the password, approving exactly what the
    /// manifest asks for.
    Approved,
    /// The agent itself, for a first-party package it ships: approved as
    /// asked, unless the admin uninstalled the app (`desk_app_declined`).
    Agent,
}

/// Stores [package] as [how] says, replacing an installed version: none when
/// the agent's own install finds the app declined. An admin's install takes
/// a decline back. Its files go to [blobs] first, the rows naming them after;
/// the decline is read in the transaction that writes, so an uninstall
/// beside it either comes first and wins or comes after.
async fn store(db: &sqlx::SqlitePool, blobs: &Arc<Blobs>, package: &Package, how: Install) -> anyhow::Result<Option<Installed>> {
    let m = &package.manifest;
    let id = m.id();
    let writing = blobs.writing().await;
    let mut files = Vec::with_capacity(package.files.len());
    for (path, bytes) in &package.files {
        files.push((path, blobs.put(bytes).await?, bytes.len() as i64));
    }
    // IMMEDIATE: it reads the row it replaces, then writes; a deferred
    // transaction upgrading to write beside another writer fails busy at once
    // (an agent starting, installing its own apps while it writes elsewhere).
    let mut tx = db.begin_with("BEGIN IMMEDIATE").await?;
    let previous: Option<(String, Option<String>)> =
        sqlx::query_as("SELECT sha256, approved_permissions FROM desk_app_package WHERE app_id = ?")
            .bind(&id)
            .fetch_optional(&mut *tx)
            .await?;
    let declined: bool = sqlx::query_scalar("SELECT COUNT(*) > 0 FROM desk_app_declined WHERE app_id = ?").bind(&id).fetch_one(&mut *tx).await?;
    if how == Install::Agent && declined {
        drop(tx);
        drop(writing);
        // The files put above belong to nothing.
        blobs.collect_soon(db);
        return Ok(None);
    }
    if how != Install::Agent {
        sqlx::query("DELETE FROM desk_app_declined WHERE app_id = ?").bind(&id).execute(&mut *tx).await?;
    }
    let kept = match how {
        Install::Upload => previous.and_then(|(sha, approved)| approved.filter(|_| sha == package.sha256)),
        Install::Approved | Install::Agent => Some(serde_json::to_string(&m.permissions).unwrap_or_default()),
    };
    let now = chrono::Utc::now().to_rfc3339();
    sqlx::query("DELETE FROM desk_app_file WHERE app_id = ?").bind(&id).execute(&mut *tx).await?;
    sqlx::query(
        "INSERT INTO desk_app_package (app_id, version, manifest, sha256, approved_permissions, installed_at, approved_at, signed_by) \
         VALUES (?, ?, ?, ?, ?, ?, ?, ?) ON CONFLICT(app_id) DO UPDATE SET version = excluded.version, signed_by = excluded.signed_by, \
         manifest = excluded.manifest, sha256 = excluded.sha256, approved_permissions = excluded.approved_permissions, \
         installed_at = excluded.installed_at, \
         approved_at = CASE WHEN excluded.approved_permissions IS NULL THEN NULL WHEN ? THEN excluded.approved_at ELSE desk_app_package.approved_at END",
    )
    .bind(&id)
    .bind(&m.version)
    .bind(serde_json::to_string(m).unwrap_or_default())
    .bind(&package.sha256)
    .bind(&kept)
    .bind(&now)
    .bind(kept.as_ref().map(|_| now.clone()))
    .bind(package.signed_by)
    // Approved now, rather than an approval kept from before.
    .bind(how != Install::Upload)
    .execute(&mut *tx)
    .await?;
    for (path, sha, size) in &files {
        sqlx::query("INSERT INTO desk_app_file (app_id, path, sha256, size) VALUES (?, ?, ?, ?)")
            .bind(&id)
            .bind(path)
            .bind(sha)
            .bind(size)
            .execute(&mut *tx)
            .await?;
    }
    tx.commit().await?;
    drop(writing);
    // The files of the version it replaced.
    blobs.collect_soon(db);
    Ok(Some(load(db, &id).await?.expect("just stored")))
}

// -----------------------------------------------------------------------------
// Handlers
// -----------------------------------------------------------------------------


/// The digest of [id]'s `backend.wasm`, whose compiled copy goes when the
/// package does.
async fn backend_sha(db: &sqlx::SqlitePool, id: &str) -> Option<String> {
    sqlx::query_scalar("SELECT sha256 FROM desk_app_file WHERE app_id = ? AND path = 'backend.wasm'").bind(id).fetch_optional(db).await.ok().flatten()
}

fn not_found() -> HttpResponse {
    HttpResponse::NotFound().json(&refused("notFound"))
}

use super::admin::audit;

pub async fn list(req: HttpRequest, state: web::types::State<Arc<AppState>>) -> Result<HttpResponse, web::Error> {
    require!(authz::jwt_caller(&req, &state).await);
    let rows = sqlx::query_as::<_, Row>(select!("ORDER BY app_id")).fetch_all(&state.db).await;
    match rows {
        Ok(rows) => {
            let apps: Vec<Installed> = rows
                .into_iter()
                .filter_map(installed)
                .collect();
            Ok(HttpResponse::Ok().json(&serde_json::json!({ "apps": apps })))
        }
        Err(e) => Ok(super::respond::internal(&e)),
    }
}

pub async fn install(
    req: HttpRequest,
    body: Bytes,
    state: web::types::State<Arc<AppState>>,
) -> Result<HttpResponse, web::Error> {
    require!(authz::acting_caller(&req, &state).await);
    // Inflating and checking takes a while: off the worker.
    let package = match tokio::task::spawn_blocking(move || read_package(&body)).await {
        Ok(Ok(p)) => p,
        Ok(Err(refusal)) => {
            let status = if refusal.error == "tooLarge" { 413 } else { 400 };
            return Ok(HttpResponse::build(ntex::http::StatusCode::from_u16(status).unwrap()).json(&refusal));
        }
        Err(_) => return Ok(HttpResponse::InternalServerError().json(&refused("internal"))),
    };
    install_package(&req, &state, package, Install::Upload).await
}

/// Why a package was not stored.
enum PutError {
    /// An app its publisher signed is replaced only by a package with the
    /// same signature.
    PublisherChanged,
    InvalidBackend(String),
    Internal(String),
}

/// Stores [package] as [how] says (`store`); none when the agent's own
/// install finds the app declined.
async fn put(state: &AppState, package: &Package, how: Install) -> Result<Option<Installed>, PutError> {
    let signed: Option<Option<String>> = sqlx::query_scalar("SELECT signed_by FROM desk_app_package WHERE app_id = ?")
        .bind(package.manifest.id())
        .fetch_optional(&state.db)
        .await
        .map_err(|e| PutError::Internal(e.to_string()))?;
    if let Some(Some(key)) = signed
        && package.signed_by != Some(key.as_str())
    {
        return Err(PutError::PublisherChanged);
    }
    let before = backend_sha(&state.db, &package.manifest.id()).await;
    // Compiled now (and kept once stored): a backend that is not a component of the
    // agent's world is refused here rather than at its first call.
    if let (Some(sha), Some(bytes)) = (backend_sha_of(package), package.files.get("backend.wasm").cloned())
        && let Err(e) = state.apps.backend(&sha, move || Some(bytes)).await
    {
        return Err(PutError::InvalidBackend(e));
    }
    match store(&state.db, &state.blobs, package, how).await {
        Ok(Some(app)) => {
            if let Some(sha) = before.filter(|sha| backend_sha_of(package).as_deref() != Some(sha)) {
                state.apps.forget(&sha);
            }
            Ok(Some(app))
        }
        Ok(None) => {
            if let Some(sha) = backend_sha_of(package).filter(|sha| before.as_deref() != Some(sha)) {
                state.apps.forget(&sha);
            }
            Ok(None)
        }
        Err(e) => {
            // Not stored: its compiled backend is no app's.
            if let Some(sha) = backend_sha_of(package).filter(|sha| before.as_deref() != Some(sha)) {
                state.apps.forget(&sha);
            }
            Err(PutError::Internal(format!("{e:#}")))
        }
    }
}

/// Stores [package] as the admin's [how] (an upload waits for approval);
/// an app the admin had uninstalled is no longer declined.
async fn install_package(req: &HttpRequest, state: &AppState, package: Package, how: Install) -> Result<HttpResponse, web::Error> {
    match put(state, &package, how).await {
        Ok(Some(app)) => {
            let verb = if how == Install::Approved { "install approved" } else { "install" };
            audit(req, state, Action::Write, format!("app {verb} {} {} {}", app.id, app.version, package.sha256)).await;
            state.desk.send(DeskEvent::Apps);
            Ok(HttpResponse::Ok().json(&app))
        }
        Ok(None) => Ok(super::respond::internal(&"an admin install was refused as declined")),
        Err(PutError::PublisherChanged) => Ok(HttpResponse::Conflict().json(&refused("publisherChanged"))),
        Err(PutError::InvalidBackend(e)) => {
            tracing::info!("app backend refused: {e}");
            Ok(HttpResponse::BadRequest().json(&serde_json::json!({ "error": "invalidBackend", "detail": e.chars().take(300).collect::<String>() })))
        }
        Err(PutError::Internal(e)) => Ok(super::respond::internal(&e)),
    }
}

/// Grants [app] exactly what its manifest asks for, if it is still the
/// package [app] names: false when it was replaced meanwhile.
async fn grant(db: &sqlx::SqlitePool, app: &Installed) -> Result<bool, sqlx::Error> {
    let done = sqlx::query("UPDATE desk_app_package SET approved_permissions = ?, approved_at = ? WHERE app_id = ? AND sha256 = ?")
        .bind(serde_json::to_string(&app.manifest.permissions).unwrap_or_default())
        .bind(chrono::Utc::now().to_rfc3339())
        .bind(&app.id)
        .bind(&app.sha256)
        .execute(db)
        .await?;
    Ok(done.rows_affected() == 1)
}

/// Whether [a] is a later version than [b] (both semver; otherwise not).
fn later(a: &str, b: &str) -> bool {
    matches!((semver::Version::parse(a), semver::Version::parse(b)), (Ok(a), Ok(b)) if a > b)
}

/// The desk apps the agent ships signed with a first-party key (and the
/// store's later first-party versions of them) are part of the desk, as the
/// panel's own apps were: installed and approved on their own, on the
/// systems they are for, and kept at the latest version. One the admin
/// removed (`desk_app_declined`) stays removed until installed again; an
/// installed app of another signature, or a later version, is left alone.
/// Run at start and after the catalog is read.
pub async fn keep_first_party(state: &AppState) {
    let _one = state.apps.first_party.lock().await;
    let systems = super::machine::systems();
    for offered in state.stacks.catalog.desk.all() {
        let package = &offered.package;
        let Some(key) = package.signed_by else { continue };
        if !package.manifest.for_os(systems) {
            continue;
        }
        let id = package.manifest.id();
        let installed = match load(&state.db, &id).await {
            Ok(i) => i,
            Err(e) => {
                tracing::warn!("desk app {id}: {e}");
                continue;
            }
        };
        // Not installed, or an earlier version of the same signature. A
        // package waiting for approval (the admin's install, not yet
        // approved with the password) is the admin's to approve.
        let wanted = match &installed {
            None => true,
            Some(i) => i.signed_by.as_deref() == Some(key) && i.sha256 != package.sha256 && later(&package.manifest.version, &i.version),
        };
        if !wanted {
            continue;
        }
        match put(state, package, Install::Agent).await {
            Ok(Some(app)) => {
                tracing::info!("desk app {id} {} installed", app.version);
                state.desk.send(DeskEvent::Apps);
                Event::new(Kind::Admin, Action::Write, Outcome::Ok)
                    .detail(format!("app preinstall {id} {} {}", app.version, app.sha256))
                    .record(&state.db)
                    .await;
            }
            // Uninstalled by the admin.
            Ok(None) | Err(PutError::PublisherChanged) => {}
            Err(PutError::InvalidBackend(e) | PutError::Internal(e)) => tracing::error!("desk app {id}: {e}"),
        }
    }
}

#[derive(Deserialize)]
#[serde(deny_unknown_fields)]
pub struct Approval {
    /// The package the operator looked at.
    sha256: String,
    permissions: Vec<String>,
    current_password: Option<String>,
}

/// One package of the agent's catalog (`apps::catalog`).
#[derive(Serialize)]
#[serde(rename_all = "camelCase")]
struct OfferedView<'a> {
    id: String,
    version: &'a str,
    sha256: &'a str,
    size: usize,
    manifest: &'a Manifest,
    signed_by: Option<&'static str>,
    source: crate::apps::catalog::Source,
    repo: Option<&'a str>,
}

/// `GET /apps/catalog`: the desk app packages this agent offers, from what
/// it ships and the store's repositories; `POST /stacks/refresh` reads the
/// repositories again.
pub async fn catalog(req: HttpRequest, state: web::types::State<Arc<AppState>>) -> Result<HttpResponse, web::Error> {
    require!(authz::jwt_caller(&req, &state).await);
    let offered = state.stacks.catalog.desk.all();
    let os = super::machine::systems();
    let apps: Vec<OfferedView> = offered
        .iter()
        .filter(|o| o.package.manifest.for_os(os))
        .map(|o| OfferedView {
            id: o.package.manifest.id(),
            version: &o.package.manifest.version,
            sha256: &o.package.sha256,
            size: o.bytes.len(),
            manifest: &o.package.manifest,
            signed_by: o.package.signed_by,
            source: o.source,
            repo: o.repo.as_deref(),
        })
        .collect();
    Ok(HttpResponse::Ok().json(&serde_json::json!({ "apps": apps })))
}

#[derive(Deserialize, Default)]
#[serde(deny_unknown_fields)]
pub struct OfferedInstall {
    /// The package the admin looked at, and exactly what its manifest asks.
    sha256: String,
    permissions: Vec<String>,
    current_password: Option<String>,
}

/// `POST /apps/catalog/{id}/install`: the catalog's package. With the
/// password and what the admin saw (`sha256`, `permissions`), installed and
/// approved at once, so an update never leaves the app waiting; without a
/// body, installed as an upload is: waiting for approval.
pub async fn install_offered(
    req: HttpRequest,
    id: web::types::Path<String>,
    body: Option<web::types::Json<OfferedInstall>>,
    state: web::types::State<Arc<AppState>>,
) -> Result<HttpResponse, web::Error> {
    require!(authz::acting_caller(&req, &state).await);
    let Some(offered) = state.stacks.catalog.desk.get(&id) else { return Ok(not_found()) };
    if !offered.package.manifest.for_os(super::machine::systems()) {
        return Ok(HttpResponse::Conflict().json(&refused("notForThisSystem")));
    }
    let Some(body) = body.map(|b| b.into_inner()) else {
        // Read and checked when the catalog took it.
        return install_package(&req, &state, offered.package.clone(), Install::Upload).await;
    };
    require!(reauth(&req, &state, body.current_password.as_deref()).await);
    let asked: BTreeSet<&String> = offered.package.manifest.permissions.iter().collect();
    let given: BTreeSet<&String> = body.permissions.iter().collect();
    if body.sha256 != offered.package.sha256 || asked != given || body.permissions.len() != given.len() {
        return Ok(HttpResponse::Conflict().json(&refused("permissionsChanged")));
    }
    install_package(&req, &state, offered.package.clone(), Install::Approved).await
}

pub async fn approve(
    req: HttpRequest,
    id: web::types::Path<String>,
    body: web::types::Json<Approval>,
    state: web::types::State<Arc<AppState>>,
) -> Result<HttpResponse, web::Error> {
    require!(authz::acting_caller(&req, &state).await);
    let body = body.into_inner();
    require!(reauth(&req, &state, body.current_password.as_deref()).await);
    let app = match load(&state.db, &id).await {
        Ok(Some(app)) => app,
        Ok(None) => return Ok(not_found()),
        Err(e) => return Ok(super::respond::internal(&e)),
    };
    // Exactly what the manifest asks for: an approval of something else is
    // a screen out of date.
    let asked: BTreeSet<&String> = app.manifest.permissions.iter().collect();
    let given: BTreeSet<&String> = body.permissions.iter().collect();
    if body.sha256 != app.sha256 || asked != given || body.permissions.len() != given.len() {
        return Ok(HttpResponse::Conflict().json(&serde_json::json!({ "error": "permissionsChanged", "app": app })));
    }
    match grant(&state.db, &app).await {
        Ok(true) => {
            audit(&req, &state, Action::Write, format!("app approve {} {} {}", app.id, app.version, app.sha256)).await;
            state.desk.send(DeskEvent::Apps);
            match load(&state.db, &app.id).await {
                Ok(Some(app)) => Ok(HttpResponse::Ok().json(&app)),
                Ok(None) => Ok(not_found()),
                Err(e) => Ok(super::respond::internal(&e)),
            }
        }
        // Replaced between the read and the write.
        Ok(false) => Ok(HttpResponse::Conflict().json(&refused("permissionsChanged"))),
        Err(e) => Ok(super::respond::internal(&e)),
    }
}

pub async fn remove(
    req: HttpRequest,
    id: web::types::Path<String>,
    body: Option<web::types::Json<Reauth>>,
    state: web::types::State<Arc<AppState>>,
) -> Result<HttpResponse, web::Error> {
    require!(authz::acting_caller(&req, &state).await);
    let password = body.and_then(|b| b.into_inner().current_password);
    require!(reauth(&req, &state, password.as_deref()).await);
    let backend = backend_sha(&state.db, &id).await;
    let mut tx = match state.db.begin().await {
        Ok(tx) => tx,
        Err(e) => return Ok(super::respond::internal(&e)),
    };
    let files = sqlx::query("DELETE FROM desk_app_file WHERE app_id = ?").bind(id.as_str()).execute(&mut *tx).await;
    // What its users kept goes with it: an app installed later under this id
    // starts with nothing of theirs.
    let kept = sqlx::query("DELETE FROM desk_app_storage WHERE app_id = ?").bind(id.as_str()).execute(&mut *tx).await;
    if let Err(e) = kept {
        return Ok(super::respond::internal(&e));
    }
    let package = sqlx::query("DELETE FROM desk_app_package WHERE app_id = ?").bind(id.as_str()).execute(&mut *tx).await;
    match (files, package) {
        (Ok(_), Ok(r)) => {
            if r.rows_affected() == 0 {
                return Ok(not_found());
            }
            // A first-party app the agent installs on its own stays removed.
            if state.stacks.catalog.desk.get(&id).is_some_and(|o| o.package.signed_by.is_some()) {
                let declined = sqlx::query("INSERT INTO desk_app_declined (app_id, declined_at) VALUES (?, ?) ON CONFLICT(app_id) DO NOTHING")
                    .bind(id.as_str())
                    .bind(chrono::Utc::now().to_rfc3339())
                    .execute(&mut *tx)
                    .await;
                if let Err(e) = declined {
                    return Ok(super::respond::internal(&e));
                }
            }
            if let Err(e) = tx.commit().await {
                return Ok(super::respond::internal(&e));
            }
            state.blobs.collect_soon(&state.db);
            if let Some(sha) = backend {
                state.apps.forget(&sha);
            }
            // Its job ends before its folder goes: a script may be writing there.
            if let Some(job) = state.apps.end_jobs(&id) {
                for _ in 0..50 {
                    if !job.job.running() {
                        break;
                    }
                    tokio::time::sleep(std::time::Duration::from_millis(100)).await;
                }
            }
            let (apps, app) = (state.apps.clone(), id.to_string());
            let _ = tokio::task::spawn_blocking(move || apps.forget_data(&app)).await;
            audit(&req, &state, Action::Write, format!("app remove {}", id.as_str())).await;
            state.desk.send(DeskEvent::Apps);
            Ok(HttpResponse::NoContent().finish())
        }
        (Err(e), _) | (_, Err(e)) => Ok(super::respond::internal(&e)),
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
        Err(e) => return Ok(super::respond::internal(&e)),
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
            Err(e) => return Ok(super::respond::internal(&e)),
        };
    let Some((sha256, Some(_))) = package else { return Ok(not_found()) };
    if !ticket_ok(&state, &ticket, &id, &sha256, chrono::Utc::now().timestamp()) {
        return Ok(HttpResponse::Forbidden().json(&refused("ticket")));
    }
    let file = format!("ui/{file}");
    if !valid_entry_path(&file) {
        return Ok(not_found());
    }
    let sha: Option<String> = match sqlx::query_scalar("SELECT sha256 FROM desk_app_file WHERE app_id = ? AND path = ?")
        .bind(&id)
        .bind(&file)
        .fetch_optional(&state.db)
        .await
    {
        Ok(s) => s,
        Err(e) => return Ok(super::respond::internal(&e)),
    };
    let Some(sha) = sha else { return Ok(not_found()) };
    let bytes = match state.blobs.read(&sha).await {
        Ok(Some(bytes)) => bytes,
        Ok(None) => return Ok(not_found()),
        Err(e) => return Ok(super::respond::internal(&e)),
    };
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
            publisher: "acme".into(),
            name: "notes".into(),
            version: "1.0.0".into(),
            api: 1,
            kind: "web".into(),
            title: serde_json::json!({ "en": "Notes", "de": "Notizen" }),
            description: Some(serde_json::json!("Notes kept on the server.")),
            glyph: "sticky_note_2".into(),
            tone: "amber".into(),
            permissions: vec!["notifications".into()],
            instances: Some(2),
            size: Some(Size { width: 800, height: 600 }),
            min_size: None,
            opens: Some(Opens { dirs: false, ext: vec!["md".into(), "txt".into()] }),
            keywords: vec![],
            os: Vec::new(),
        }
    }

    /// The examples and the template are what app authors copy: each must be
    /// a manifest the agent takes.
    #[test]
    fn shipped_manifests_are_accepted() {
        let root = std::path::Path::new(env!("CARGO_MANIFEST_DIR"));
        for path in ["examples/desk-app-hello", "examples/desk-app-uptime", "sdk/template"] {
            let text = std::fs::read_to_string(root.join(path).join("manifest.json")).unwrap();
            let m: Manifest = serde_json::from_str(&text).unwrap_or_else(|e| panic!("{path}: {e}"));
            assert_eq!(check_manifest(&m, false), Ok(()), "{path}");
        }
    }

    #[test]
    fn a_manifest_is_checked_field_by_field() {
        assert_eq!(check_manifest(&manifest(), false), Ok(()));
        let mut ours = manifest();
        ours.publisher = "serverbox".into();
        assert_eq!(check_manifest(&ours, true), Ok(()), "signed by a first-party key");
        type Case = (fn(&mut Manifest), &'static str);
        let cases: Vec<Case> = vec![
            (|m| m.publisher = "serverbox".into(), "invalidId"),
            (|m| m.publisher = "a".into(), "invalidId"),
            (|m| m.publisher = "Acme".into(), "invalidId"),
            (|m| m.publisher = "ac.me".into(), "invalidId"),
            (|m| m.name = String::new(), "invalidId"),
            (|m| m.name = "my-notes".into(), "invalidId"),
            (|m| m.version = String::new(), "invalidVersion"),
            (|m| m.api = 3, "unsupportedApi"),
            // A backend of API 1 was a core module the agent no longer runs.
            (|m| m.kind = "wasm".into(), "unsupportedApi"),
            (|m| (m.kind, m.api, m.permissions) = ("wasm".into(), 2, vec!["files.read".into()]), "invalidPermission"),
            (|m| m.kind = "native".into(), "invalidKind"),
            (|m| m.title = serde_json::json!({ "de": "Notizen" }), "invalidTitle"),
            (|m| m.title = serde_json::json!(""), "invalidTitle"),
            (|m| m.description = Some(serde_json::json!({ "de": "Notizen" })), "invalidDescription"),
            (|m| m.description = Some(serde_json::json!("x".repeat(601))), "invalidDescription"),
            (|m| m.glyph = "<svg>".into(), "invalidGlyph"),
            (|m| m.tone = "red".into(), "invalidTone"),
            (|m| m.permissions = vec!["exec".into()], "invalidPermission"),
            (|m| m.permissions = vec!["background".into(), "background".into()], "invalidPermission"),
            (|m| m.instances = Some(0), "invalidInstances"),
            (|m| m.size = Some(Size { width: 10, height: 10 }), "invalidSize"),
            (|m| m.opens = Some(Opens { dirs: false, ext: vec![".md".into()] }), "invalidOpens"),
            (|m| m.os = vec!["Ubuntu 26.04".into()], "invalidOs"),
        ];
        for (change, code) in cases {
            let mut m = manifest();
            change(&mut m);
            assert_eq!(check_manifest(&m, false).map_err(|r| r.error), Err(code), "{m:?}");
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
