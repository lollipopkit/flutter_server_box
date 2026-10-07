//! `/api/v1/desk*` — what the panel's desk (its web desktop) keeps on the
//! agent, and what the agent has to tell it.
//!
//! - `GET /desk`, `PUT /desk/preferences`: accent, wallpaper, the dock and
//!   the desk's icons, per account.
//! - `GET/PUT/DELETE /desk/wallpaper`: one custom image per account.
//! - `GET/PUT /desk/session?device=`: the windows one browser had open, per
//!   account and device. A write names the revision it was made from and is
//!   refused (409, with what is current) when another tab moved it since.
//! - `GET /desk/notifications`, `POST /desk/notifications/read`: what the
//!   machine said (a monitoring rule that started firing), read per account.
//! - `/desk/apps/{app}/storage`: what an app keeps for itself, see
//!   `api::desk_storage`.
//! - `GET /desk/events`: a `text/event-stream` of the above as they happen,
//!   read with `fetch` and the bearer header (an `EventSource` cannot send
//!   one). A hint to refetch, never the only copy.
//!
//! # Privilege
//!
//! Any signed-in account: a desk is its own, and what a notification says is
//! what `/status` already shows to every role. Nothing here reaches the
//! machine. Every check of shape is here, so a stored row is one the panel
//! can draw; the panel's own checks are for its forms only.

use std::collections::HashSet;
use std::sync::{Arc, Mutex};

use futures::StreamExt;
use ntex::util::Bytes;
use ntex::web::{self, HttpRequest, HttpResponse};
use serde::{Deserialize, Serialize};
use sha2::{Digest, Sha256};
use sqlx::SqlitePool;
use tokio::sync::broadcast;

use super::authz::{self, Caller};
use super::server::AppState;

/// The wallpapers the panel ships, by id (`desk/wallpapers`).
pub const WALLPAPER_PRESETS: &[&str] = &["bloom", "dusk", "nightfall", "graphite"];
pub const DEFAULT_WALLPAPER: &str = "preset:bloom";
const FITS: &[&str] = &["cover", "contain", "fill"];

/// A JSON body here: the session at its bounds is about 1.1 MiB.
pub const MAX_REQUEST: usize = 2 << 20;
pub const MAX_WALLPAPER_BYTES: usize = 8 << 20;
pub const MAX_WINDOWS: usize = 64;
pub const MAX_APP_STATE: usize = 16 << 10;
pub const MAX_DOCK: usize = 64;
pub const MAX_ICONS: usize = 256;
const MAX_LABEL_CHARS: usize = 64;
const MAX_PATH_BYTES: usize = 4096;
/// Window geometry, in CSS pixels; generous, and only so a stored number
/// stays a number the panel can draw.
const COORD: i64 = 100_000;
const MAX_Z: i64 = 1_000_000;
/// Kept notifications; older ones go when a new one comes.
pub const KEEP_NOTIFICATIONS: i64 = 500;
const HEARTBEAT: std::time::Duration = std::time::Duration::from_secs(25);

// -----------------------------------------------------------------------------
// The hub: events, and which rules are firing
// -----------------------------------------------------------------------------

/// What `/desk/events` sends. `user` scopes an event to one account; a
/// notification is everybody's.
#[derive(Debug, Clone)]
pub enum DeskEvent {
    Notification(Notification),
    /// Another tab of `user` wrote its session (or preferences).
    Session { user: i64, device: String, revision: i64 },
    Preferences { user: i64 },
}

pub struct DeskHub {
    events: broadcast::Sender<DeskEvent>,
    /// The monitoring rules firing at the last check: a notification is for a
    /// rule that starts, not for every cycle it stays over.
    firing: Mutex<HashSet<String>>,
}

impl Default for DeskHub {
    fn default() -> Self {
        Self {
            events: broadcast::channel(64).0,
            firing: Mutex::new(HashSet::new()),
        }
    }
}

impl DeskHub {
    pub fn subscribe(&self) -> broadcast::Receiver<DeskEvent> {
        self.events.subscribe()
    }

    fn send(&self, event: DeskEvent) {
        // No receiver is no panel open: nothing to tell.
        let _ = self.events.send(event);
    }

    /// The rules firing now, by name, with what each says: a notification for
    /// each that was not firing at the last check.
    pub async fn rules_checked(&self, db: &SqlitePool, firing: Vec<(String, String)>) {
        let started: Vec<(String, String)> = {
            let mut was = self.firing.lock().unwrap_or_else(|e| e.into_inner());
            let now: HashSet<String> = firing.iter().map(|(name, _)| name.clone()).collect();
            let started = firing
                .into_iter()
                .filter(|(name, _)| !was.contains(name))
                .collect();
            *was = now;
            started
        };
        for (rule, body) in started {
            if let Err(e) = self.notify(db, Level::Warning, Source::Alert, &rule, &body).await {
                tracing::warn!("desk notification for rule '{rule}' not stored: {e}");
            }
        }
    }

    pub async fn notify(
        &self,
        db: &SqlitePool,
        level: Level,
        source: Source,
        subject: &str,
        body: &str,
    ) -> Result<(), sqlx::Error> {
        let created_at = chrono::Utc::now().to_rfc3339();
        let id = sqlx::query(
            "INSERT INTO desk_notification (created_at, level, source, subject, body) VALUES (?, ?, ?, ?, ?)",
        )
        .bind(&created_at)
        .bind(level.as_str())
        .bind(source.as_str())
        .bind(subject)
        .bind(body)
        .execute(db)
        .await?
        .last_insert_rowid();
        sqlx::query("DELETE FROM desk_notification WHERE id <= ?")
            .bind(id - KEEP_NOTIFICATIONS)
            .execute(db)
            .await?;
        self.send(DeskEvent::Notification(Notification {
            id,
            created_at,
            level: level.as_str().to_string(),
            source: source.as_str().to_string(),
            subject: subject.to_string(),
            body: body.to_string(),
            read: false,
        }));
        Ok(())
    }
}

#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum Level {
    Info,
    Warning,
    Critical,
}

impl Level {
    fn as_str(self) -> &'static str {
        match self {
            Level::Info => "info",
            Level::Warning => "warning",
            Level::Critical => "critical",
        }
    }
}

#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum Source {
    Alert,
}

impl Source {
    fn as_str(self) -> &'static str {
        match self {
            Source::Alert => "alert",
        }
    }
}

// -----------------------------------------------------------------------------
// Shapes
// -----------------------------------------------------------------------------

#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize)]
#[serde(deny_unknown_fields)]
pub struct Preferences {
    #[serde(default)]
    pub accent: Option<String>,
    pub wallpaper: String,
    pub wallpaper_fit: String,
    pub dock: Vec<String>,
    pub icons: Vec<Icon>,
    /// Hidden apps keep running; false suspends them.
    #[serde(default = "yes")]
    pub background: bool,
    /// Apps suspended when hidden even while [background] is on.
    #[serde(default)]
    pub background_denied: Vec<String>,
}

fn yes() -> bool {
    true
}

#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize)]
#[serde(deny_unknown_fields)]
pub struct Icon {
    pub id: String,
    /// `app` | `path`.
    pub kind: String,
    /// Empty for an `app` icon shown with the app's title.
    pub app_id: String,
    #[serde(default)]
    pub server_id: Option<String>,
    #[serde(default)]
    pub path: Option<String>,
    pub label: String,
    #[serde(default)]
    pub col: Option<i64>,
    #[serde(default)]
    pub row: Option<i64>,
}

#[derive(Serialize)]
struct DeskView {
    /// `None` until the account saved any: the panel's defaults.
    preferences: Option<Preferences>,
    /// The custom wallpaper's SHA-256, when there is one.
    wallpaper_sha256: Option<String>,
    presets: &'static [&'static str],
}

#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize)]
#[serde(deny_unknown_fields)]
pub struct Window {
    pub window_id: String,
    pub app_id: String,
    #[serde(default)]
    pub server_id: Option<String>,
    pub x: i64,
    pub y: i64,
    pub width: i64,
    pub height: i64,
    pub z: i64,
    pub minimized: bool,
    pub maximized: bool,
    /// The app's own, opaque here; bounded in size.
    #[serde(default)]
    pub app_state: Option<serde_json::Value>,
}

#[derive(Debug, Clone, PartialEq, Eq, Serialize)]
pub struct Session {
    /// 0: nothing stored for this device yet.
    pub revision: i64,
    pub active_window_id: Option<String>,
    pub windows: Vec<Window>,
}

#[derive(Deserialize)]
#[serde(deny_unknown_fields)]
pub struct SessionWrite {
    device: String,
    /// The revision this was made from; 0 for none.
    expected_revision: i64,
    #[serde(default)]
    active_window_id: Option<String>,
    windows: Vec<Window>,
}

#[derive(Deserialize)]
pub struct DeviceQuery {
    device: String,
}

#[derive(Debug, Clone, PartialEq, Eq, Serialize)]
pub struct Notification {
    pub id: i64,
    pub created_at: String,
    pub level: String,
    pub source: String,
    pub subject: String,
    pub body: String,
    pub read: bool,
}

#[derive(Deserialize)]
pub struct NotificationQuery {
    #[serde(default)]
    limit: Option<i64>,
}

#[derive(Deserialize)]
#[serde(deny_unknown_fields)]
pub struct ReadRequest {
    #[serde(default)]
    ids: Vec<i64>,
    #[serde(default)]
    all: bool,
}

// -----------------------------------------------------------------------------
// Checks
// -----------------------------------------------------------------------------

/// Why a write was refused: a stable code for the panel, and where.
#[derive(Debug, Clone, PartialEq, Eq, Serialize)]
pub struct Refusal {
    pub error: &'static str,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub index: Option<usize>,
}

pub(crate) fn refused(error: &'static str, index: Option<usize>) -> Refusal {
    Refusal { error, index }
}

/// A panel-minted id: what `crypto.randomUUID` and short names look like.
pub fn valid_id(id: &str) -> bool {
    (1..=64).contains(&id.len()) && id.bytes().all(|b| b.is_ascii_alphanumeric() || b == b'-' || b == b'_')
}

/// An app id (`desk/apps`): lowercase, digits and `_`, a letter first.
pub fn valid_app_id(id: &str) -> bool {
    (1..=32).contains(&id.len())
        && id.as_bytes()[0].is_ascii_lowercase()
        && id.bytes().all(|b| b.is_ascii_lowercase() || b.is_ascii_digit() || b == b'_')
}

fn valid_label(label: &str) -> bool {
    let chars = label.chars().count();
    (1..=MAX_LABEL_CHARS).contains(&chars) && !label.chars().any(char::is_control)
}

fn valid_server_id(id: &str) -> bool {
    (1..=64).contains(&id.len()) && !id.chars().any(char::is_control)
}

fn valid_accent(accent: &str) -> bool {
    accent.len() == 7
        && accent.starts_with('#')
        && accent[1..].bytes().all(|b| b.is_ascii_digit() || (b'a'..=b'f').contains(&b))
}

pub fn valid_wallpaper(wallpaper: &str) -> bool {
    wallpaper == "custom"
        || wallpaper
            .strip_prefix("preset:")
            .is_some_and(|id| WALLPAPER_PRESETS.contains(&id))
}

/// What is stored is what was checked: the accent lowercased, labels trimmed.
pub fn check_preferences(mut p: Preferences) -> Result<Preferences, Refusal> {
    if let Some(accent) = &p.accent {
        let accent = accent.to_ascii_lowercase();
        if !valid_accent(&accent) {
            return Err(refused("invalidAccent", None));
        }
        p.accent = Some(accent);
    }
    if !valid_wallpaper(&p.wallpaper) {
        return Err(refused("invalidWallpaper", None));
    }
    if !FITS.contains(&p.wallpaper_fit.as_str()) {
        return Err(refused("invalidWallpaperFit", None));
    }
    if p.dock.len() > MAX_DOCK {
        return Err(refused("tooMany", None));
    }
    let mut seen = HashSet::new();
    for (index, app) in p.dock.iter().enumerate() {
        if !valid_app_id(app) {
            return Err(refused("invalidAppId", Some(index)));
        }
        if !seen.insert(app.as_str()) {
            return Err(refused("duplicateApp", Some(index)));
        }
    }
    if p.background_denied.len() > MAX_DOCK {
        return Err(refused("tooMany", None));
    }
    let mut denied = HashSet::new();
    for (index, app) in p.background_denied.iter().enumerate() {
        if !valid_app_id(app) {
            return Err(refused("invalidBackgroundApp", Some(index)));
        }
        if !denied.insert(app.as_str()) {
            return Err(refused("duplicateBackgroundApp", Some(index)));
        }
    }
    if p.icons.len() > MAX_ICONS {
        return Err(refused("tooMany", None));
    }
    let mut ids = HashSet::new();
    for (index, icon) in p.icons.iter_mut().enumerate() {
        icon.label = icon.label.trim().to_string();
        let at = Some(index);
        if !valid_id(&icon.id) {
            return Err(refused("invalidId", at));
        }
        if !ids.insert(icon.id.clone()) {
            return Err(refused("duplicateId", at));
        }
        if !valid_app_id(&icon.app_id) {
            return Err(refused("invalidAppId", at));
        }
        // An app's icon may go unnamed: the panel shows the app's title.
        let unnamed_app = icon.kind == "app" && icon.label.is_empty();
        if !unnamed_app && !valid_label(&icon.label) {
            return Err(refused("invalidLabel", at));
        }
        match icon.kind.as_str() {
            "app" => {
                if icon.path.is_some() || icon.server_id.is_some() {
                    return Err(refused("invalidIcon", at));
                }
            }
            "path" => {
                let path_ok = icon
                    .path
                    .as_deref()
                    .is_some_and(|p| (1..=MAX_PATH_BYTES).contains(&p.len()) && !p.contains('\0'));
                let server_ok = icon.server_id.as_deref().is_some_and(valid_server_id);
                if !path_ok || !server_ok {
                    return Err(refused("invalidIcon", at));
                }
            }
            _ => return Err(refused("invalidIcon", at)),
        }
        let cell_ok = |v: Option<i64>| v.is_none_or(|v| (0..=1000).contains(&v));
        if !cell_ok(icon.col) || !cell_ok(icon.row) {
            return Err(refused("invalidIcon", at));
        }
    }
    Ok(p)
}

pub fn check_session(write: &SessionWrite) -> Result<(), Refusal> {
    if !valid_id(&write.device) {
        return Err(refused("invalidDevice", None));
    }
    if write.expected_revision < 0 {
        return Err(refused("invalidRevision", None));
    }
    if write.windows.len() > MAX_WINDOWS {
        return Err(refused("tooMany", None));
    }
    let mut ids = HashSet::new();
    for (index, w) in write.windows.iter().enumerate() {
        let at = Some(index);
        if !valid_id(&w.window_id) {
            return Err(refused("invalidId", at));
        }
        if !ids.insert(w.window_id.as_str()) {
            return Err(refused("duplicateId", at));
        }
        if !valid_app_id(&w.app_id) {
            return Err(refused("invalidAppId", at));
        }
        if w.server_id.as_deref().is_some_and(|s| !valid_server_id(s)) {
            return Err(refused("invalidServerId", at));
        }
        let coord = |v: i64| (-COORD..=COORD).contains(&v);
        let size = |v: i64| (1..=COORD).contains(&v);
        if !coord(w.x) || !coord(w.y) || !size(w.width) || !size(w.height) || !(0..=MAX_Z).contains(&w.z) {
            return Err(refused("invalidGeometry", at));
        }
        if let Some(state) = &w.app_state
            && state.to_string().len() > MAX_APP_STATE
        {
            return Err(refused("appStateTooLarge", at));
        }
    }
    if let Some(active) = &write.active_window_id
        && !ids.contains(active.as_str())
    {
        return Err(refused("invalidActiveWindow", None));
    }
    Ok(())
}

/// The image's type, read from its first bytes rather than taken from a
/// header the client chose: PNG, JPEG or WebP, nothing else an `<img>` would
/// be asked to decode.
pub fn sniff_image(bytes: &[u8]) -> Option<&'static str> {
    if bytes.starts_with(b"\x89PNG\r\n\x1a\n") {
        Some("image/png")
    } else if bytes.starts_with(&[0xff, 0xd8, 0xff]) {
        Some("image/jpeg")
    } else if bytes.len() >= 12 && &bytes[..4] == b"RIFF" && &bytes[8..12] == b"WEBP" {
        Some("image/webp")
    } else {
        None
    }
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

/// The caller and its account id. A token for an account deleted since is
/// already 401 in `jwt_caller`; the id lookup failing after it is the same.
pub(crate) async fn account(req: &HttpRequest, state: &AppState) -> Result<(Caller, i64), HttpResponse> {
    let caller = authz::jwt_caller(req, state).await?;
    match user_id(&state.db, &caller.username).await {
        Ok(Some(id)) => Ok((caller, id)),
        Ok(None) => Err(HttpResponse::Unauthorized().finish()),
        Err(e) => Err(internal_error(&e)),
    }
}

async fn user_id(db: &SqlitePool, username: &str) -> Result<Option<i64>, sqlx::Error> {
    sqlx::query_scalar("SELECT id FROM users WHERE username = ?")
        .bind(username)
        .fetch_optional(db)
        .await
}

pub(crate) fn internal_error(e: &sqlx::Error) -> HttpResponse {
    tracing::error!("desk: {e}");
    HttpResponse::InternalServerError().json(&serde_json::json!({ "error": "internal" }))
}

pub async fn get(req: HttpRequest, state: web::types::State<Arc<AppState>>) -> Result<HttpResponse, web::Error> {
    let (_, user) = require!(account(&req, &state).await);
    let preferences = match load_preferences(&state.db, user).await {
        Ok(p) => p,
        Err(e) => return Ok(internal_error(&e)),
    };
    let wallpaper_sha256 = match sqlx::query_scalar::<_, String>("SELECT sha256 FROM desk_wallpaper WHERE user_id = ?")
        .bind(user)
        .fetch_optional(&state.db)
        .await
    {
        Ok(sha) => sha,
        Err(e) => return Ok(internal_error(&e)),
    };
    Ok(HttpResponse::Ok().json(&DeskView {
        preferences,
        wallpaper_sha256,
        presets: WALLPAPER_PRESETS,
    }))
}

pub async fn put_preferences(
    req: HttpRequest,
    body: web::types::Json<Preferences>,
    state: web::types::State<Arc<AppState>>,
) -> Result<HttpResponse, web::Error> {
    let (_, user) = require!(account(&req, &state).await);
    let preferences = match check_preferences(body.into_inner()) {
        Ok(p) => p,
        Err(refusal) => return Ok(HttpResponse::BadRequest().json(&refusal)),
    };
    if let Err(e) = store_preferences(&state.db, user, &preferences).await {
        return Ok(internal_error(&e));
    }
    state.desk.send(DeskEvent::Preferences { user });
    Ok(HttpResponse::Ok().json(&preferences))
}

pub async fn get_wallpaper(req: HttpRequest, state: web::types::State<Arc<AppState>>) -> Result<HttpResponse, web::Error> {
    let (_, user) = require!(account(&req, &state).await);
    let row = sqlx::query_as::<_, (String, Vec<u8>, String)>(
        "SELECT mime, bytes, sha256 FROM desk_wallpaper WHERE user_id = ?",
    )
    .bind(user)
    .fetch_optional(&state.db)
    .await;
    match row {
        Ok(Some((mime, bytes, sha))) => {
            let etag = format!("\"{sha}\"");
            let matches = req
                .headers()
                .get("if-none-match")
                .and_then(|v| v.to_str().ok())
                .is_some_and(|v| v == etag);
            let mut res = if matches { HttpResponse::NotModified() } else { HttpResponse::Ok() };
            res.header("etag", etag)
                .header("cache-control", "private, no-cache")
                .header("x-content-type-options", "nosniff");
            Ok(if matches { res.finish() } else { res.content_type(mime).body(bytes) })
        }
        Ok(None) => Ok(HttpResponse::NotFound().json(&refused("notFound", None))),
        Err(e) => Ok(internal_error(&e)),
    }
}

/// The image is the whole body; read in full before anything is written.
pub async fn put_wallpaper(
    req: HttpRequest,
    mut body: web::types::Payload,
    state: web::types::State<Arc<AppState>>,
) -> Result<HttpResponse, web::Error> {
    let (_, user) = require!(account(&req, &state).await);
    let mut data = Vec::new();
    while let Some(chunk) = body.next().await {
        let Ok(chunk) = chunk else {
            return Ok(HttpResponse::BadRequest().finish());
        };
        if data.len() + chunk.len() > MAX_WALLPAPER_BYTES {
            return Ok(HttpResponse::PayloadTooLarge().json(&refused("tooLarge", None)));
        }
        data.extend_from_slice(&chunk);
    }
    let Some(mime) = sniff_image(&data) else {
        return Ok(HttpResponse::UnsupportedMediaType().json(&refused("notAnImage", None)));
    };
    let sha = hex(&Sha256::digest(&data));
    let stored = sqlx::query(
        "INSERT INTO desk_wallpaper (user_id, mime, bytes, sha256) VALUES (?, ?, ?, ?) \
         ON CONFLICT(user_id) DO UPDATE SET mime = excluded.mime, bytes = excluded.bytes, sha256 = excluded.sha256",
    )
    .bind(user)
    .bind(mime)
    .bind(&data)
    .bind(&sha)
    .execute(&state.db)
    .await;
    match stored {
        Ok(_) => {
            state.desk.send(DeskEvent::Preferences { user });
            Ok(HttpResponse::Ok().json(&serde_json::json!({ "sha256": sha })))
        }
        Err(e) => Ok(internal_error(&e)),
    }
}

/// Removes the custom image; a desk that showed it falls back to the default.
pub async fn delete_wallpaper(req: HttpRequest, state: web::types::State<Arc<AppState>>) -> Result<HttpResponse, web::Error> {
    let (_, user) = require!(account(&req, &state).await);
    let mut tx = match state.db.begin().await {
        Ok(tx) => tx,
        Err(e) => return Ok(internal_error(&e)),
    };
    let done = async {
        sqlx::query("DELETE FROM desk_wallpaper WHERE user_id = ?").bind(user).execute(&mut *tx).await?;
        sqlx::query("UPDATE desk_preferences SET wallpaper = ? WHERE user_id = ? AND wallpaper = 'custom'")
            .bind(DEFAULT_WALLPAPER)
            .bind(user)
            .execute(&mut *tx)
            .await?;
        tx.commit().await
    }
    .await;
    match done {
        Ok(()) => {
            state.desk.send(DeskEvent::Preferences { user });
            Ok(HttpResponse::NoContent().finish())
        }
        Err(e) => Ok(internal_error(&e)),
    }
}

pub async fn get_session(
    req: HttpRequest,
    query: web::types::Query<DeviceQuery>,
    state: web::types::State<Arc<AppState>>,
) -> Result<HttpResponse, web::Error> {
    let (_, user) = require!(account(&req, &state).await);
    if !valid_id(&query.device) {
        return Ok(HttpResponse::BadRequest().json(&refused("invalidDevice", None)));
    }
    let loaded = async {
        let mut conn = state.db.acquire().await?;
        load_session(&mut conn, user, &query.device).await
    }
    .await;
    match loaded {
        Ok(session) => Ok(HttpResponse::Ok().json(&session)),
        Err(e) => Ok(internal_error(&e)),
    }
}

pub async fn put_session(
    req: HttpRequest,
    body: web::types::Json<SessionWrite>,
    state: web::types::State<Arc<AppState>>,
) -> Result<HttpResponse, web::Error> {
    let (_, user) = require!(account(&req, &state).await);
    let write = body.into_inner();
    if let Err(refusal) = check_session(&write) {
        return Ok(HttpResponse::BadRequest().json(&refusal));
    }
    match store_session(&state.db, user, &write).await {
        Ok(Stored::Written(revision)) => {
            state.desk.send(DeskEvent::Session {
                user,
                device: write.device.clone(),
                revision,
            });
            Ok(HttpResponse::Ok().json(&serde_json::json!({ "revision": revision })))
        }
        Ok(Stored::Conflict(current)) => Ok(HttpResponse::Conflict().json(&serde_json::json!({
            "error": "conflict",
            "current": current,
        }))),
        Err(e) => Ok(internal_error(&e)),
    }
}

pub async fn notifications(
    req: HttpRequest,
    query: web::types::Query<NotificationQuery>,
    state: web::types::State<Arc<AppState>>,
) -> Result<HttpResponse, web::Error> {
    let (_, user) = require!(account(&req, &state).await);
    let limit = query.limit.unwrap_or(50).clamp(1, 200);
    let rows = sqlx::query_as::<_, (i64, String, String, String, String, String, bool)>(
        "SELECT n.id, n.created_at, n.level, n.source, n.subject, n.body, r.user_id IS NOT NULL \
         FROM desk_notification n \
         LEFT JOIN desk_notification_read r ON r.notification_id = n.id AND r.user_id = ? \
         ORDER BY n.id DESC LIMIT ?",
    )
    .bind(user)
    .bind(limit)
    .fetch_all(&state.db)
    .await;
    let unread = sqlx::query_scalar::<_, i64>(
        "SELECT COUNT(*) FROM desk_notification n WHERE NOT EXISTS \
         (SELECT 1 FROM desk_notification_read r WHERE r.notification_id = n.id AND r.user_id = ?)",
    )
    .bind(user)
    .fetch_one(&state.db)
    .await;
    match (rows, unread) {
        (Ok(rows), Ok(unread)) => {
            let notifications: Vec<Notification> = rows
                .into_iter()
                .map(|(id, created_at, level, source, subject, body, read)| Notification {
                    id,
                    created_at,
                    level,
                    source,
                    subject,
                    body,
                    read,
                })
                .collect();
            Ok(HttpResponse::Ok().json(&serde_json::json!({
                "notifications": notifications,
                "unread": unread,
            })))
        }
        (Err(e), _) | (_, Err(e)) => Ok(internal_error(&e)),
    }
}

pub async fn mark_read(
    req: HttpRequest,
    body: web::types::Json<ReadRequest>,
    state: web::types::State<Arc<AppState>>,
) -> Result<HttpResponse, web::Error> {
    let (_, user) = require!(account(&req, &state).await);
    let body = body.into_inner();
    if body.ids.len() > 200 {
        return Ok(HttpResponse::BadRequest().json(&refused("tooMany", None)));
    }
    let done = if body.all {
        sqlx::query(
            "INSERT OR IGNORE INTO desk_notification_read (user_id, notification_id) \
             SELECT ?, id FROM desk_notification",
        )
        .bind(user)
        .execute(&state.db)
        .await
        .map(|_| ())
    } else {
        mark_ids(&state.db, user, &body.ids).await
    };
    match done {
        Ok(()) => Ok(HttpResponse::NoContent().finish()),
        Err(e) => Ok(internal_error(&e)),
    }
}

async fn mark_ids(db: &SqlitePool, user: i64, ids: &[i64]) -> Result<(), sqlx::Error> {
    let mut tx = db.begin().await?;
    for id in ids {
        // An id that is gone (or never was) marks nothing.
        sqlx::query(
            "INSERT OR IGNORE INTO desk_notification_read (user_id, notification_id) \
             SELECT ?, id FROM desk_notification WHERE id = ?",
        )
        .bind(user)
        .bind(id)
        .execute(&mut *tx)
        .await?;
    }
    tx.commit().await
}

/// `text/event-stream`, one `data:` line of JSON per event:
/// `{"type":"notification","notification":{…}}`,
/// `{"type":"session","device":…,"revision":…}`, `{"type":"preferences"}`,
/// and `{"type":"resync"}` when events were dropped (refetch everything).
/// Ends when the account's password changes or the account goes.
pub async fn events(req: HttpRequest, state: web::types::State<Arc<AppState>>) -> Result<HttpResponse, web::Error> {
    let (caller, user) = require!(account(&req, &state).await);
    let mut rx = state.desk.subscribe();
    let mut changes = state.grants_changed.subscribe();
    let state = state.get_ref().clone();
    let stream = async_stream::stream! {
        yield Ok::<_, std::io::Error>(Bytes::from_static(b": ok\n\n"));
        let mut beat = tokio::time::interval(HEARTBEAT);
        beat.tick().await;
        loop {
            tokio::select! {
                event = rx.recv() => {
                    let json = match event {
                        Ok(DeskEvent::Notification(n)) => serde_json::json!({ "type": "notification", "notification": n }),
                        Ok(DeskEvent::Session { user: u, device, revision }) if u == user => {
                            serde_json::json!({ "type": "session", "device": device, "revision": revision })
                        }
                        Ok(DeskEvent::Preferences { user: u }) if u == user => serde_json::json!({ "type": "preferences" }),
                        Ok(_) => continue,
                        Err(broadcast::error::RecvError::Lagged(_)) => serde_json::json!({ "type": "resync" }),
                        Err(broadcast::error::RecvError::Closed) => break,
                    };
                    yield Ok(Bytes::from(format!("data: {json}\n\n")));
                }
                changed = changes.recv() => {
                    if matches!(changed, Err(broadcast::error::RecvError::Closed)) {
                        break;
                    }
                    if !still_signed_in(&state, &caller).await {
                        break;
                    }
                }
                _ = beat.tick() => {
                    yield Ok(Bytes::from_static(b": ping\n\n"));
                }
            }
        }
    };
    Ok(HttpResponse::Ok()
        .content_type("text/event-stream")
        .header("cache-control", "no-cache")
        .header("x-accel-buffering", "no")
        .streaming(Box::pin(stream)))
}

/// Whether the account behind [caller] is the one that opened the stream:
/// still there, and its password not changed since.
async fn still_signed_in(state: &AppState, caller: &Caller) -> bool {
    authz::caller_named(state, &caller.username)
        .await
        .is_some_and(|now| now.since == caller.since)
}

// -----------------------------------------------------------------------------
// Storage
// -----------------------------------------------------------------------------

async fn load_preferences(db: &SqlitePool, user: i64) -> Result<Option<Preferences>, sqlx::Error> {
    let Some((accent, wallpaper, wallpaper_fit, background)) = sqlx::query_as::<_, (Option<String>, String, String, bool)>(
        "SELECT accent, wallpaper, wallpaper_fit, background FROM desk_preferences WHERE user_id = ?",
    )
    .bind(user)
    .fetch_optional(db)
    .await?
    else {
        return Ok(None);
    };
    let background_denied =
        sqlx::query_scalar::<_, String>("SELECT app_id FROM desk_background_denied WHERE user_id = ? ORDER BY app_id")
            .bind(user)
            .fetch_all(db)
            .await?;
    let dock = sqlx::query_scalar::<_, String>("SELECT app_id FROM desk_dock WHERE user_id = ? ORDER BY position")
        .bind(user)
        .fetch_all(db)
        .await?;
    let icons = sqlx::query_as::<_, (String, String, String, Option<String>, Option<String>, String, Option<i64>, Option<i64>)>(
        "SELECT id, kind, app_id, server_id, path, label, col, row FROM desk_icon WHERE user_id = ? ORDER BY position",
    )
    .bind(user)
    .fetch_all(db)
    .await?
    .into_iter()
    .map(|(id, kind, app_id, server_id, path, label, col, row)| Icon {
        id,
        kind,
        app_id,
        server_id,
        path,
        label,
        col,
        row,
    })
    .collect();
    Ok(Some(Preferences {
        accent,
        wallpaper,
        wallpaper_fit,
        dock,
        icons,
        background,
        background_denied,
    }))
}

async fn store_preferences(db: &SqlitePool, user: i64, p: &Preferences) -> Result<(), sqlx::Error> {
    let mut tx = db.begin().await?;
    sqlx::query(
        "INSERT INTO desk_preferences (user_id, accent, wallpaper, wallpaper_fit, background, updated_at) VALUES (?, ?, ?, ?, ?, ?) \
         ON CONFLICT(user_id) DO UPDATE SET accent = excluded.accent, wallpaper = excluded.wallpaper, \
         wallpaper_fit = excluded.wallpaper_fit, background = excluded.background, updated_at = excluded.updated_at",
    )
    .bind(user)
    .bind(&p.accent)
    .bind(&p.wallpaper)
    .bind(&p.wallpaper_fit)
    .bind(p.background)
    .bind(chrono::Utc::now().to_rfc3339())
    .execute(&mut *tx)
    .await?;
    sqlx::query("DELETE FROM desk_dock WHERE user_id = ?").bind(user).execute(&mut *tx).await?;
    for (position, app) in p.dock.iter().enumerate() {
        sqlx::query("INSERT INTO desk_dock (user_id, position, app_id) VALUES (?, ?, ?)")
            .bind(user)
            .bind(position as i64)
            .bind(app)
            .execute(&mut *tx)
            .await?;
    }
    sqlx::query("DELETE FROM desk_background_denied WHERE user_id = ?").bind(user).execute(&mut *tx).await?;
    for app in &p.background_denied {
        sqlx::query("INSERT INTO desk_background_denied (user_id, app_id) VALUES (?, ?)")
            .bind(user)
            .bind(app)
            .execute(&mut *tx)
            .await?;
    }
    sqlx::query("DELETE FROM desk_icon WHERE user_id = ?").bind(user).execute(&mut *tx).await?;
    for (position, icon) in p.icons.iter().enumerate() {
        sqlx::query(
            "INSERT INTO desk_icon (user_id, id, kind, app_id, server_id, path, label, col, row, position) \
             VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?)",
        )
        .bind(user)
        .bind(&icon.id)
        .bind(&icon.kind)
        .bind(&icon.app_id)
        .bind(&icon.server_id)
        .bind(&icon.path)
        .bind(&icon.label)
        .bind(icon.col)
        .bind(icon.row)
        .bind(position as i64)
        .execute(&mut *tx)
        .await?;
    }
    tx.commit().await
}

type WindowRow = (String, String, Option<String>, i64, i64, i64, i64, i64, bool, bool, Option<String>);

async fn load_session(conn: &mut sqlx::SqliteConnection, user: i64, device: &str) -> Result<Session, sqlx::Error> {
    let Some((revision, active_window_id)) = sqlx::query_as::<_, (i64, Option<String>)>(
        "SELECT revision, active_window_id FROM desk_session WHERE user_id = ? AND device_id = ?",
    )
    .bind(user)
    .bind(device)
    .fetch_optional(&mut *conn)
    .await?
    else {
        return Ok(Session {
            revision: 0,
            active_window_id: None,
            windows: Vec::new(),
        });
    };
    let windows = sqlx::query_as::<_, WindowRow>(
        "SELECT window_id, app_id, server_id, x, y, width, height, z, minimized, maximized, app_state \
         FROM desk_window WHERE user_id = ? AND device_id = ? ORDER BY z",
    )
    .bind(user)
    .bind(device)
    .fetch_all(&mut *conn)
    .await?
    .into_iter()
    .map(|(window_id, app_id, server_id, x, y, width, height, z, minimized, maximized, app_state)| Window {
        window_id,
        app_id,
        server_id,
        x,
        y,
        width,
        height,
        z,
        minimized,
        maximized,
        // Written from a `Value`, so it parses; a row that does not is one
        // this agent did not write, and the window opens without it.
        app_state: app_state.and_then(|s| serde_json::from_str(&s).ok()),
    })
    .collect();
    Ok(Session {
        revision,
        active_window_id,
        windows,
    })
}

enum Stored {
    Written(i64),
    Conflict(Session),
}

/// Compare-and-swap on the revision. The transaction's first statement is
/// the write that checks it, so SQLite's write lock is taken there: a second
/// writer from the same revision waits, then matches nothing and is told
/// what is current.
async fn store_session(db: &SqlitePool, user: i64, write: &SessionWrite) -> Result<Stored, sqlx::Error> {
    let mut tx = db.begin().await?;
    let revision = write.expected_revision + 1;
    let now = chrono::Utc::now().to_rfc3339();
    let swapped = if write.expected_revision == 0 {
        sqlx::query(
            "INSERT OR IGNORE INTO desk_session (user_id, device_id, revision, active_window_id, updated_at) \
             VALUES (?, ?, ?, ?, ?)",
        )
        .bind(user)
        .bind(&write.device)
        .bind(revision)
        .bind(&write.active_window_id)
        .bind(&now)
        .execute(&mut *tx)
        .await?
    } else {
        sqlx::query(
            "UPDATE desk_session SET revision = ?, active_window_id = ?, updated_at = ? \
             WHERE user_id = ? AND device_id = ? AND revision = ?",
        )
        .bind(revision)
        .bind(&write.active_window_id)
        .bind(&now)
        .bind(user)
        .bind(&write.device)
        .bind(write.expected_revision)
        .execute(&mut *tx)
        .await?
    }
    .rows_affected()
        == 1;
    if !swapped {
        let current = load_session(&mut tx, user, &write.device).await?;
        tx.rollback().await?;
        return Ok(Stored::Conflict(current));
    }
    sqlx::query("DELETE FROM desk_window WHERE user_id = ? AND device_id = ?")
        .bind(user)
        .bind(&write.device)
        .execute(&mut *tx)
        .await?;
    for w in &write.windows {
        sqlx::query(
            "INSERT INTO desk_window (user_id, device_id, window_id, app_id, server_id, x, y, width, height, z, \
             minimized, maximized, app_state) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)",
        )
        .bind(user)
        .bind(&write.device)
        .bind(&w.window_id)
        .bind(&w.app_id)
        .bind(&w.server_id)
        .bind(w.x)
        .bind(w.y)
        .bind(w.width)
        .bind(w.height)
        .bind(w.z)
        .bind(w.minimized)
        .bind(w.maximized)
        .bind(w.app_state.as_ref().map(|v| v.to_string()))
        .execute(&mut *tx)
        .await?;
    }
    tx.commit().await?;
    Ok(Stored::Written(revision))
}

fn hex(bytes: &[u8]) -> String {
    bytes.iter().map(|b| format!("{b:02x}")).collect()
}

#[cfg(test)]
mod tests {
    use super::*;

    fn prefs() -> Preferences {
        Preferences {
            accent: Some("#8B2252".into()),
            wallpaper: "preset:dusk".into(),
            wallpaper_fit: "cover".into(),
            background: false,
            background_denied: vec!["status".into()],
            dock: vec!["files".into(), "terminal".into()],
            icons: vec![Icon {
                id: "i1".into(),
                kind: "path".into(),
                app_id: "files".into(),
                server_id: Some("local".into()),
                path: Some("/etc".into()),
                label: " etc ".into(),
                col: Some(0),
                row: None,
            }],
        }
    }

    #[test]
    fn preferences_are_normalised() {
        let p = check_preferences(prefs()).unwrap();
        assert_eq!(p.accent.as_deref(), Some("#8b2252"));
        assert_eq!(p.icons[0].label, "etc");
    }

    #[test]
    fn preferences_refusals() {
        type Edit = fn(&mut Preferences);
        let cases: Vec<(Edit, &str)> = vec![
            (|p| p.accent = Some("red".into()), "invalidAccent"),
            (|p| p.wallpaper = "preset:nope".into(), "invalidWallpaper"),
            (|p| p.wallpaper = "https://x/y.png".into(), "invalidWallpaper"),
            (|p| p.wallpaper_fit = "tile".into(), "invalidWallpaperFit"),
            (|p| p.dock.push("files".into()), "duplicateApp"),
            (|p| p.dock.push("Files".into()), "invalidAppId"),
            (|p| p.background_denied.push("Status".into()), "invalidBackgroundApp"),
            (|p| p.background_denied.push("status".into()), "duplicateBackgroundApp"),
            (|p| p.icons[0].path = None, "invalidIcon"),
            (|p| p.icons[0].server_id = None, "invalidIcon"),
            (|p| p.icons[0].kind = "app".into(), "invalidIcon"),
            (|p| p.icons[0].label = "\u{7}".into(), "invalidLabel"),
            (|p| p.icons[0].col = Some(-1), "invalidIcon"),
            (|p| p.icons.push(p.icons[0].clone()), "duplicateId"),
        ];
        for (edit, code) in cases {
            let mut p = prefs();
            edit(&mut p);
            assert_eq!(check_preferences(p).unwrap_err().error, code);
        }
    }

    fn window(id: &str) -> Window {
        Window {
            window_id: id.into(),
            app_id: "files".into(),
            server_id: None,
            x: 10,
            y: 10,
            width: 800,
            height: 600,
            z: 1,
            minimized: false,
            maximized: false,
            app_state: Some(serde_json::json!({ "path": "/" })),
        }
    }

    fn write(windows: Vec<Window>) -> SessionWrite {
        SessionWrite {
            device: "dev-1".into(),
            expected_revision: 0,
            active_window_id: windows.first().map(|w| w.window_id.clone()),
            windows,
        }
    }

    #[test]
    fn session_refusals() {
        assert!(check_session(&write(vec![window("a"), window("b")])).is_ok());
        assert_eq!(check_session(&write(vec![window("a"), window("a")])).unwrap_err().error, "duplicateId");
        let mut w = window("a");
        w.width = 0;
        assert_eq!(check_session(&write(vec![w])).unwrap_err().error, "invalidGeometry");
        let mut w = window("a");
        w.app_state = Some(serde_json::json!("x".repeat(MAX_APP_STATE)));
        assert_eq!(check_session(&write(vec![w])).unwrap_err().error, "appStateTooLarge");
        let mut s = write(vec![window("a")]);
        s.active_window_id = Some("b".into());
        assert_eq!(check_session(&s).unwrap_err().error, "invalidActiveWindow");
        let mut s = write(vec![]);
        s.device = "a b".into();
        assert_eq!(check_session(&s).unwrap_err().error, "invalidDevice");
        let too_many: Vec<Window> = (0..=MAX_WINDOWS).map(|i| window(&format!("w{i}"))).collect();
        assert_eq!(check_session(&write(too_many)).unwrap_err().error, "tooMany");
    }

    #[test]
    fn images_are_sniffed() {
        assert_eq!(sniff_image(b"\x89PNG\r\n\x1a\nrest"), Some("image/png"));
        assert_eq!(sniff_image(&[0xff, 0xd8, 0xff, 0xe0]), Some("image/jpeg"));
        assert_eq!(sniff_image(b"RIFF\0\0\0\0WEBPVP8 "), Some("image/webp"));
        assert_eq!(sniff_image(b"<svg xmlns=\"http://www.w3.org/2000/svg\"/>"), None);
        assert_eq!(sniff_image(b"GIF89a"), None);
    }
}
