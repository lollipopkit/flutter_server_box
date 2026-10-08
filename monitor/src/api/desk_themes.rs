//! `/api/v1/desk/themes*` — theme packages (`.fsbt`) an account installs for
//! its desk, read and checked by `sbm_theme` with the app's own rules.
//!
//! - `GET /desk/themes`: what this account installed, each package as
//!   `sbm_theme` read it (one theme, or one per variant).
//! - `POST /desk/themes`: the body is a `.fsbt`. Installing a theme again (the
//!   same manifest `id`) replaces the earlier installation, and a desk drawn
//!   with that one moves to the new one, variant kept.
//! - `DELETE /desk/themes/{installation}`: a desk drawn with it goes back to
//!   the panel's own.
//! - `GET /desk/themes/{installation}/background?variant=`: the image a theme
//!   draws behind the desk.
//! - `GET /desk/themes/store[?refresh=1]`: the theme store, read by the agent
//!   (the catalog the app reads, then every repository it lists), kept for an
//!   hour.
//! - `POST /desk/themes/store/install` `{repo, id, version}`: installs one
//!   version the store offers, checked against its SHA-256.
//!
//! # Privilege and reach
//!
//! Any signed-in account, as the rest of the desk. The store is the one place
//! the agent fetches from the internet on a client's behalf, so a client
//! never names what is fetched: only the catalog's address (compiled in), the
//! repositories it lists, and the versions those list, all HTTPS, are read.

use std::collections::HashMap;
use std::future::Future;
use std::pin::Pin;
use std::sync::Arc;
use std::time::{Duration, Instant};

use futures::StreamExt;
use ntex::web::{self, HttpRequest, HttpResponse};
use serde::{Deserialize, Serialize};
use sqlx::SqlitePool;
use tokio::sync::Mutex;

use super::desk::{DeskEvent, account, internal_error, refused};
use super::server::AppState;
use sbm_theme::repo::{self, Catalog, Index, Listing, Release};

/// Themes one account may keep.
pub const MAX_THEMES: i64 = 32;
/// What one account's themes may weigh in all (their backgrounds).
pub const MAX_ACCOUNT_BYTES: i64 = 128 << 20;
/// How long a read of the store is kept.
const STORE_TTL: Duration = Duration::from_secs(3600);
/// The catalog this build ships, read when the catalog's address does not
/// answer.
const BUNDLED_CATALOG: &str = include_str!("../../../assets/catalog/repos.toml");

macro_rules! require {
    ($result:expr) => {{
        match $result {
            Ok(value) => value,
            Err(response) => return Ok(response),
        }
    }};
}

// -----------------------------------------------------------------------------
// Installing
// -----------------------------------------------------------------------------

/// One installed package, as the panel draws it.
#[derive(Serialize)]
#[serde(rename_all = "camelCase")]
pub struct Installed {
    pub installation_id: String,
    pub id: String,
    pub name: String,
    pub installed_at: String,
    /// `sbm_theme::Package`, JSON.
    pub package: serde_json::Value,
}

/// A theme value in the preferences: `<installation>` or
/// `<installation>#<variant>`.
pub fn split_theme(value: &str) -> (&str, Option<&str>) {
    match value.split_once('#') {
        Some((id, variant)) => (id, Some(variant)),
        None => (value, None),
    }
}

pub fn valid_theme_value(value: &str) -> bool {
    let (id, variant) = split_theme(value);
    id.len() == 64
        && id.bytes().all(|b| b.is_ascii_digit() || (b'a'..=b'f').contains(&b))
        && variant.is_none_or(sbm_theme::package::is_variant_key)
}

/// Whether [value] names a theme [user] has: the installation, and the
/// variant when it names one (a package with variants answers without one
/// with its first).
pub async fn theme_exists(db: &SqlitePool, user: i64, value: &str) -> Result<bool, sqlx::Error> {
    let (id, variant) = split_theme(value);
    let Some(summary) =
        sqlx::query_scalar::<_, String>("SELECT summary FROM desk_theme WHERE user_id = ? AND installation_id = ?")
            .bind(user)
            .bind(id)
            .fetch_optional(db)
            .await?
    else {
        return Ok(false);
    };
    let Some(variant) = variant else { return Ok(true) };
    let package: serde_json::Value = serde_json::from_str(&summary).unwrap_or_default();
    Ok(package["themes"]
        .as_array()
        .is_some_and(|themes| themes.iter().any(|t| t["variant"]["key"] == variant)))
}

/// Why an install was refused.
pub enum InstallError {
    /// The package itself, in `sbm_theme`'s words.
    Invalid(String),
    TooMany,
    TooLarge,
    Db(sqlx::Error),
}

impl From<sqlx::Error> for InstallError {
    fn from(e: sqlx::Error) -> Self {
        Self::Db(e)
    }
}

impl InstallError {
    fn response(self) -> HttpResponse {
        match self {
            Self::Invalid(reason) => {
                HttpResponse::BadRequest().json(&serde_json::json!({ "error": "invalidTheme", "reason": reason }))
            }
            Self::TooMany => HttpResponse::Conflict().json(&refused("tooMany", None)),
            Self::TooLarge => HttpResponse::PayloadTooLarge().json(&refused("tooLarge", None)),
            Self::Db(e) => internal_error(&e),
        }
    }
}

/// Reads [bytes] as a package and keeps it for [user], replacing an earlier
/// installation of the same theme.
pub async fn install(db: &SqlitePool, user: i64, bytes: Vec<u8>) -> Result<Installed, InstallError> {
    // Reading a package is CPU work (inflating up to 16 MiB): off the reactor.
    let package = tokio::task::spawn_blocking(move || sbm_theme::install(&bytes))
        .await
        .map_err(|e| InstallError::Invalid(e.to_string()))?
        .map_err(|e| InstallError::Invalid(e.0))?;
    let summary = serde_json::to_value(&package).expect("a package serializes");
    let installed_at = chrono::Utc::now().to_rfc3339();
    let backgrounds: Vec<(String, &'static str, &[u8])> = package
        .themes
        .iter()
        .filter_map(|t| {
            let bytes = t.files.background.as_deref()?;
            let mime = super::desk::sniff_image(bytes)?;
            Some((t.variant.as_ref().map(|v| v.key.clone()).unwrap_or_default(), mime, bytes))
        })
        .collect();
    let weight: i64 = backgrounds.iter().map(|(_, _, b)| b.len() as i64).sum();

    let mut tx = db.begin().await?;
    let earlier = sqlx::query_scalar::<_, String>(
        "SELECT installation_id FROM desk_theme WHERE user_id = ? AND theme_id = ? AND installation_id != ?",
    )
    .bind(user)
    .bind(&package.id)
    .bind(&package.installation_id)
    .fetch_optional(&mut *tx)
    .await?;
    let already = sqlx::query_scalar::<_, i64>("SELECT 1 FROM desk_theme WHERE user_id = ? AND installation_id = ?")
        .bind(user)
        .bind(&package.installation_id)
        .fetch_optional(&mut *tx)
        .await?
        .is_some();
    if !already {
        let (count, used): (i64, i64) = sqlx::query_as(
            "SELECT (SELECT COUNT(*) FROM desk_theme WHERE user_id = ?1 AND installation_id IS NOT ?2), \
             (SELECT COALESCE(SUM(LENGTH(bytes)), 0) FROM desk_theme_background WHERE user_id = ?1 AND installation_id IS NOT ?2)",
        )
        .bind(user)
        .bind(earlier.as_deref())
        .fetch_one(&mut *tx)
        .await?;
        if count >= MAX_THEMES {
            return Err(InstallError::TooMany);
        }
        if used + weight > MAX_ACCOUNT_BYTES {
            return Err(InstallError::TooLarge);
        }
        if let Some(earlier) = &earlier {
            sqlx::query("DELETE FROM desk_theme WHERE user_id = ? AND installation_id = ?")
                .bind(user)
                .bind(earlier)
                .execute(&mut *tx)
                .await?;
            // A desk drawn with the earlier version moves to this one, its
            // variant kept when this version still has it.
            let selected = sqlx::query_scalar::<_, Option<String>>("SELECT theme FROM desk_preferences WHERE user_id = ?")
                .bind(user)
                .fetch_optional(&mut *tx)
                .await?
                .flatten();
            if let Some(selected) = selected
                && split_theme(&selected).0 == earlier
            {
                let variant = split_theme(&selected).1;
                let kept = variant.filter(|v| {
                    package.themes.iter().any(|t| t.variant.as_ref().is_some_and(|tv| tv.key == *v))
                });
                let next = match kept {
                    Some(v) => format!("{}#{v}", package.installation_id),
                    None => package.installation_id.clone(),
                };
                sqlx::query("UPDATE desk_preferences SET theme = ? WHERE user_id = ?")
                    .bind(next)
                    .bind(user)
                    .execute(&mut *tx)
                    .await?;
            }
        }
        sqlx::query(
            "INSERT INTO desk_theme (user_id, installation_id, theme_id, name, summary, installed_at) VALUES (?, ?, ?, ?, ?, ?)",
        )
        .bind(user)
        .bind(&package.installation_id)
        .bind(&package.id)
        .bind(&package.name)
        .bind(summary.to_string())
        .bind(&installed_at)
        .execute(&mut *tx)
        .await?;
        for (variant, mime, bytes) in &backgrounds {
            sqlx::query(
                "INSERT INTO desk_theme_background (user_id, installation_id, variant, mime, bytes) VALUES (?, ?, ?, ?, ?)",
            )
            .bind(user)
            .bind(&package.installation_id)
            .bind(variant)
            .bind(*mime)
            .bind(*bytes)
            .execute(&mut *tx)
            .await?;
        }
    }
    tx.commit().await?;
    Ok(Installed {
        installation_id: package.installation_id.clone(),
        id: package.id.clone(),
        name: package.name.clone(),
        installed_at,
        package: summary,
    })
}

// -----------------------------------------------------------------------------
// Handlers
// -----------------------------------------------------------------------------

pub async fn list(req: HttpRequest, state: web::types::State<Arc<AppState>>) -> Result<HttpResponse, web::Error> {
    let (_, user) = require!(account(&req, &state).await);
    let rows = sqlx::query_as::<_, (String, String, String, String, String)>(
        "SELECT installation_id, theme_id, name, summary, installed_at FROM desk_theme WHERE user_id = ? ORDER BY name",
    )
    .bind(user)
    .fetch_all(&state.db)
    .await;
    match rows {
        Ok(rows) => Ok(HttpResponse::Ok().json(
            &rows
                .into_iter()
                .map(|(installation_id, id, name, summary, installed_at)| Installed {
                    installation_id,
                    id,
                    name,
                    installed_at,
                    package: serde_json::from_str(&summary).unwrap_or_default(),
                })
                .collect::<Vec<_>>(),
        )),
        Err(e) => Ok(internal_error(&e)),
    }
}

/// The package is the whole body; read in full before anything is written.
pub async fn upload(
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
        if data.len() + chunk.len() > sbm_theme::package::MAX_PACKAGE_BYTES {
            return Ok(HttpResponse::PayloadTooLarge().json(&refused("tooLarge", None)));
        }
        data.extend_from_slice(&chunk);
    }
    match install(&state.db, user, data).await {
        Ok(installed) => {
            state.desk.send(DeskEvent::Preferences { user });
            Ok(HttpResponse::Ok().json(&installed))
        }
        Err(e) => Ok(e.response()),
    }
}

pub async fn remove(
    req: HttpRequest,
    path: web::types::Path<String>,
    state: web::types::State<Arc<AppState>>,
) -> Result<HttpResponse, web::Error> {
    let (_, user) = require!(account(&req, &state).await);
    let installation = path.into_inner();
    let done = async {
        let mut tx = state.db.begin().await?;
        let gone = sqlx::query("DELETE FROM desk_theme WHERE user_id = ? AND installation_id = ?")
            .bind(user)
            .bind(&installation)
            .execute(&mut *tx)
            .await?
            .rows_affected();
        // A desk drawn with it, and with its background, goes back to the
        // panel's own.
        sqlx::query(
            "UPDATE desk_preferences SET theme = NULL, \
             wallpaper = CASE WHEN wallpaper = 'theme' THEN ? ELSE wallpaper END \
             WHERE user_id = ? AND (theme = ? OR theme LIKE ? || '#%')",
        )
        .bind(super::desk::DEFAULT_WALLPAPER)
        .bind(user)
        .bind(&installation)
        .bind(&installation)
        .execute(&mut *tx)
        .await?;
        tx.commit().await?;
        Ok::<_, sqlx::Error>(gone)
    }
    .await;
    match done {
        Ok(0) => Ok(HttpResponse::NotFound().json(&refused("notFound", None))),
        Ok(_) => {
            state.desk.send(DeskEvent::Preferences { user });
            Ok(HttpResponse::NoContent().finish())
        }
        Err(e) => Ok(internal_error(&e)),
    }
}

#[derive(Deserialize)]
pub struct VariantQuery {
    #[serde(default)]
    variant: Option<String>,
}

pub async fn background(
    req: HttpRequest,
    path: web::types::Path<String>,
    query: web::types::Query<VariantQuery>,
    state: web::types::State<Arc<AppState>>,
) -> Result<HttpResponse, web::Error> {
    let (_, user) = require!(account(&req, &state).await);
    let installation = path.into_inner();
    let variant = query.into_inner().variant.unwrap_or_default();
    let row = sqlx::query_as::<_, (String, Vec<u8>)>(
        "SELECT mime, bytes FROM desk_theme_background WHERE user_id = ? AND installation_id = ? AND variant = ?",
    )
    .bind(user)
    .bind(&installation)
    .bind(&variant)
    .fetch_optional(&state.db)
    .await;
    match row {
        // The bytes of one installation never change: it is named by them.
        Ok(Some((mime, bytes))) => Ok(HttpResponse::Ok()
            .content_type(mime)
            .header("cache-control", "private, max-age=31536000, immutable")
            .header("x-content-type-options", "nosniff")
            .body(bytes)),
        Ok(None) => Ok(HttpResponse::NotFound().json(&refused("notFound", None))),
        Err(e) => Ok(internal_error(&e)),
    }
}

// -----------------------------------------------------------------------------
// The store
// -----------------------------------------------------------------------------

/// How the agent reads an HTTPS address: at most [max] bytes, or why not.
pub trait Fetch: Send + Sync {
    fn get<'a>(&'a self, url: &'a str, max: usize) -> Pin<Box<dyn Future<Output = Result<Vec<u8>, String>> + Send + 'a>>;
}

/// HTTPS only, credentials refused, at most three redirects, each to HTTPS
/// again (fl_lib `ThemePackages.download`).
pub struct HttpFetch {
    client: reqwest::Client,
}

impl Default for HttpFetch {
    fn default() -> Self {
        // reqwest has no crypto provider of its own: see `monitoring::push`.
        let _ = rustls::crypto::ring::default_provider().install_default();
        Self {
            client: reqwest::Client::builder()
                .connect_timeout(Duration::from_secs(15))
                .timeout(Duration::from_secs(90))
                .redirect(reqwest::redirect::Policy::none())
                .build()
                .expect("valid theme store HTTP client configuration"),
        }
    }
}

impl Fetch for HttpFetch {
    fn get<'a>(&'a self, url: &'a str, max: usize) -> Pin<Box<dyn Future<Output = Result<Vec<u8>, String>> + Send + 'a>> {
        Box::pin(async move {
            let mut url = repo::https_url(url).map_err(|e| e.0)?;
            for _ in 0..4 {
                let res = self.client.get(url.clone()).send().await.map_err(|e| e.to_string())?;
                let status = res.status();
                if status.is_redirection() {
                    let location = res
                        .headers()
                        .get(reqwest::header::LOCATION)
                        .and_then(|v| v.to_str().ok())
                        .ok_or("Missing redirect URL")?;
                    let next = url.join(location).map_err(|e| e.to_string())?;
                    url = repo::https_url(next.as_str()).map_err(|e| e.0)?;
                    continue;
                }
                if !status.is_success() {
                    return Err(format!("HTTP {}", status.as_u16()));
                }
                if res.content_length().is_some_and(|n| n as usize > max) {
                    return Err("Download exceeds size limit".into());
                }
                let mut bytes = Vec::new();
                let mut stream = res.bytes_stream();
                while let Some(chunk) = stream.next().await {
                    let chunk = chunk.map_err(|e| e.to_string())?;
                    if bytes.len() + chunk.len() > max {
                        return Err("Download exceeds size limit".into());
                    }
                    bytes.extend_from_slice(&chunk);
                }
                return Ok(bytes);
            }
            Err("Too many redirects".into())
        })
    }
}

/// One theme the store offers.
#[derive(Serialize, Clone)]
#[serde(rename_all = "camelCase")]
pub struct StoreItem {
    /// What the repository calls itself.
    pub repo: String,
    pub repo_url: String,
    pub listing: Listing,
    /// The newest version this agent installs; None when every one needs a
    /// newer schema.
    pub release: Option<Release>,
}

#[derive(Serialize, Clone)]
#[serde(rename_all = "camelCase")]
pub struct StoreView {
    pub catalog: Option<String>,
    pub repos: Vec<String>,
    pub items: Vec<StoreItem>,
    pub fetched_at: String,
}

struct StoreRead {
    at: Instant,
    view: StoreView,
    /// By repository address: the tree, for the packages it carries.
    indexes: HashMap<String, Index>,
}

pub struct ThemeStore {
    fetch: std::sync::RwLock<Arc<dyn Fetch>>,
    catalog_url: std::sync::RwLock<String>,
    read: Mutex<Option<StoreRead>>,
}

impl Default for ThemeStore {
    fn default() -> Self {
        Self {
            fetch: std::sync::RwLock::new(Arc::new(HttpFetch::default())),
            catalog_url: std::sync::RwLock::new(repo::CATALOG_URL.to_string()),
            read: Mutex::new(None),
        }
    }
}

impl ThemeStore {
    /// Where the store is read from, and how: for tests, which hand it a
    /// fetcher answering from memory.
    pub fn set_source(&self, catalog_url: &str, fetch: Arc<dyn Fetch>) {
        *self.catalog_url.write().unwrap() = catalog_url.to_string();
        *self.fetch.write().unwrap() = fetch;
    }

    fn fetcher(&self) -> Arc<dyn Fetch> {
        self.fetch.read().unwrap().clone()
    }

    /// The store, read again when older than an hour or when [refresh].
    pub async fn view(&self, refresh: bool) -> StoreView {
        let mut read = self.read.lock().await;
        if let Some(r) = read.as_ref()
            && !refresh
            && r.at.elapsed() < STORE_TTL
        {
            return r.view.clone();
        }
        let fresh = self.fetch_store().await;
        let view = fresh.view.clone();
        *read = Some(fresh);
        view
    }

    async fn fetch_store(&self) -> StoreRead {
        let fetch = self.fetcher();
        let catalog_url = self.catalog_url.read().unwrap().clone();
        let base = url::Url::parse(&catalog_url).ok();
        let catalog = match fetch.get(&catalog_url, repo::MAX_CATALOG_BYTES).await {
            Ok(bytes) => Catalog::parse(&bytes, base.as_ref()),
            Err(e) => Err(sbm_theme::ThemeError::new(e)),
        };
        let catalog = catalog.unwrap_or_else(|e| {
            tracing::warn!("theme store: reading the catalog: {e}");
            Catalog::parse(BUNDLED_CATALOG.as_bytes(), None).expect("the bundled catalog reads")
        });
        // A few at a time; one that does not answer costs its own themes.
        let reads = futures::stream::iter(catalog.repos.iter().cloned())
            .map(|address| {
                let fetch = fetch.clone();
                async move {
                    let tree = fetch
                        .get(&repo::archive_url_of(&address), repo::MAX_ARCHIVE_BYTES)
                        .await
                        .map_err(sbm_theme::ThemeError::new)
                        .and_then(|bytes| repo::read_archive(&bytes))
                        .and_then(|files| Index::from_files(&files));
                    (address, tree)
                }
            })
            .buffered(4)
            .collect::<Vec<_>>()
            .await;
        let mut items = Vec::new();
        let mut repos = Vec::new();
        let mut indexes = HashMap::new();
        for (address, tree) in reads {
            let index = match tree {
                Ok(index) => index,
                Err(e) => {
                    tracing::warn!("theme store: reading {address}: {e}");
                    continue;
                }
            };
            let label = index
                .name
                .as_deref()
                .map(str::trim)
                .filter(|n| !n.is_empty())
                .map(str::to_string)
                .unwrap_or_else(|| url::Url::parse(&address).map(|u| repo::label_of(&u)).unwrap_or_default());
            repos.push(label.clone());
            for listing in &index.themes {
                items.push(StoreItem {
                    repo: label.clone(),
                    repo_url: address.clone(),
                    release: listing.installable().cloned(),
                    listing: listing.clone(),
                });
            }
            indexes.insert(address, index);
        }
        StoreRead {
            at: Instant::now(),
            view: StoreView {
                catalog: catalog.name,
                repos,
                items,
                fetched_at: chrono::Utc::now().to_rfc3339(),
            },
            indexes,
        }
    }

    /// The bytes of one version the store offers, checked against its
    /// digest; a refusal says why.
    pub async fn package(&self, repo_url: &str, id: &str, version: &str) -> Result<Vec<u8>, String> {
        self.view(false).await;
        let (release, carried) = {
            let read = self.read.lock().await;
            let read = read.as_ref().ok_or("the store is not readable")?;
            let item = read
                .view
                .items
                .iter()
                .find(|i| i.repo_url == repo_url && i.listing.id == id)
                .ok_or("the store does not offer that theme")?;
            let release = item
                .listing
                .releases
                .iter()
                .find(|r| r.version == version)
                .ok_or("the store does not offer that version")?
                .clone();
            let carried = release
                .path
                .as_ref()
                .and_then(|p| read.indexes.get(repo_url).and_then(|i| i.packages.get(p)).cloned());
            (release, carried)
        };
        if !release.runs_on(sbm_theme::package::SUPPORTED_SCHEMA_MIN, sbm_theme::package::SUPPORTED_SCHEMA_MAX) {
            return Err("that version needs a newer app".into());
        }
        // A version with no digest is not one anything can be said about.
        if !release.verifiable() {
            return Err(format!("{id} {version} has no sha256"));
        }
        let bytes = match (&release.url, carried) {
            (Some(url), _) => self.fetcher().get(url, sbm_theme::package::MAX_PACKAGE_BYTES).await?,
            (None, Some(bytes)) => bytes,
            (None, None) => return Err(format!("the repository does not carry {}", release.path.unwrap_or_default())),
        };
        use sha2::Digest;
        let digest: String = sha2::Sha256::digest(&bytes).iter().map(|b| format!("{b:02x}")).collect();
        if Some(digest.as_str()) != release.sha256.as_deref() {
            return Err("Theme checksum mismatch".into());
        }
        Ok(bytes)
    }
}

#[derive(Deserialize)]
pub struct StoreQuery {
    #[serde(default)]
    refresh: Option<String>,
}

pub async fn store(
    req: HttpRequest,
    query: web::types::Query<StoreQuery>,
    state: web::types::State<Arc<AppState>>,
) -> Result<HttpResponse, web::Error> {
    require!(account(&req, &state).await);
    let refresh = query.refresh.as_deref().is_some_and(|r| r == "1" || r == "true");
    Ok(HttpResponse::Ok().json(&state.themes.view(refresh).await))
}

#[derive(Deserialize)]
#[serde(deny_unknown_fields)]
pub struct StoreInstall {
    repo: String,
    id: String,
    version: String,
}

pub async fn store_install(
    req: HttpRequest,
    body: web::types::Json<StoreInstall>,
    state: web::types::State<Arc<AppState>>,
) -> Result<HttpResponse, web::Error> {
    let (_, user) = require!(account(&req, &state).await);
    let body = body.into_inner();
    let bytes = match state.themes.package(&body.repo, &body.id, &body.version).await {
        Ok(bytes) => bytes,
        Err(reason) => {
            return Ok(HttpResponse::BadGateway().json(&serde_json::json!({ "error": "store", "reason": reason })));
        }
    };
    match install(&state.db, user, bytes).await {
        Ok(installed) => {
            state.desk.send(DeskEvent::Preferences { user });
            Ok(HttpResponse::Ok().json(&installed))
        }
        Err(e) => Ok(e.response()),
    }
}
