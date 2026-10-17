//! Where the web apps this agent can deploy come from:
//!
//! - the ones it ships (`builtin`), so an agent with no network offers them;
//! - the theme store's repositories (`assets/catalog/repos.toml`): each
//!   repository's `apps/<publisher>.<name>/` folders, fetched at start and
//!   then hourly, and kept in `<stacks>/.catalog/` so an agent that cannot
//!   reach them keeps what it last read;
//! - the operator's own folder (`[stacks] local_apps`), read at start.
//!
//! One id, one package: the local folder's, else the store's, else the
//! shipped one. Local inference's engines (`builtin::parts`) are shipped
//! alone: an id of theirs elsewhere is not read. A store package replaces the shipped one whatever its
//! version: the store is what the catalog's maintainers publish now.

use crate::utils::lock::RwLockExt;
use std::collections::BTreeMap;
use std::path::{Path, PathBuf};
use std::sync::{Arc, RwLock};
use std::time::{Duration, Instant};

use fl_theme::repo;
use serde::Serialize;

use super::builtin;
use super::manifest::Package;
use crate::api::desk_themes::{BUNDLED_CATALOG, CATALOG_URL, Fetch, HttpFetch};

/// How long a read of the store is kept.
const TTL: Duration = Duration::from_secs(3600);
const SOURCE_FILE: &str = "source";
/// Beside the cache: the desk app packages (`apps::catalog`).
pub const DESK_CACHE_DIR: &str = ".desk-catalog";

#[derive(Debug, Clone, Copy, PartialEq, Eq, Serialize)]
#[serde(rename_all = "camelCase")]
pub enum Source {
    /// Shipped inside the agent.
    Bundled,
    /// From a repository of the store (`Entry::repo`).
    Store,
    /// The operator's `[stacks] local_apps` folder.
    Local,
    /// Part of a desk app of the panel's (`builtin::PARTS_OF`): Local
    /// inference's engines. Shipped, never replaced, not in the App Store.
    Part,
}

#[derive(Debug, Clone)]
pub struct Entry {
    pub package: Arc<Package>,
    pub source: Source,
    /// The repository's address, for a store package.
    pub repo: Option<String>,
}

pub struct Catalog {
    /// `<stacks>/.catalog`: the store's packages as last read.
    cache: PathBuf,
    bundled: BTreeMap<String, Arc<Package>>,
    parts: BTreeMap<String, Arc<Package>>,
    store: RwLock<BTreeMap<String, Entry>>,
    local: BTreeMap<String, Arc<Package>>,
    /// When the store was last read, successfully or not; one read at a time.
    read: tokio::sync::Mutex<Option<Instant>>,
    source: RwLock<(String, Arc<dyn Fetch>)>,
    /// The same repositories' desk app packages (`desk/*.fsba`).
    pub desk: Arc<crate::apps::catalog::DeskCatalog>,
}

impl Catalog {
    /// The shipped packages, the store's as cached in [cache], and those in
    /// [local].
    pub fn new(cache: PathBuf, local: Option<&Path>) -> Self {
        let bundled = builtin::packages().iter().map(|p| (p.manifest.id.clone(), Arc::new(p.clone()))).collect();
        let parts = builtin::parts().iter().map(|p| (p.manifest.id.clone(), Arc::new(p.clone()))).collect();
        let store = read_cache(&cache);
        let local = local.map(read_local).unwrap_or_default();
        let desk = Arc::new(crate::apps::catalog::DeskCatalog::new(cache.with_file_name(DESK_CACHE_DIR)));
        Self {
            desk,
            cache,
            bundled,
            parts,
            store: RwLock::new(store),
            local,
            read: tokio::sync::Mutex::new(None),
            source: RwLock::new((CATALOG_URL.to_string(), Arc::new(HttpFetch::default()))),
        }
    }

    /// Where the store is read from, and how: for tests.
    pub fn set_source(&self, catalog_url: &str, fetch: Arc<dyn Fetch>) {
        *self.source.write_locked() = (catalog_url.to_string(), fetch);
    }

    pub fn get(&self, id: &str) -> Option<Entry> {
        if let Some(p) = self.parts.get(id) {
            return Some(Entry { package: p.clone(), source: Source::Part, repo: None });
        }
        if let Some(p) = self.local.get(id) {
            return Some(Entry { package: p.clone(), source: Source::Local, repo: None });
        }
        if let Some(e) = self.store.read_locked().get(id) {
            return Some(e.clone());
        }
        self.bundled.get(id).map(|p| Entry { package: p.clone(), source: Source::Bundled, repo: None })
    }

    pub fn package(&self, id: &str) -> Option<Arc<Package>> {
        self.get(id).map(|e| e.package)
    }

    /// Every app, by id.
    pub fn all(&self) -> Vec<Entry> {
        let store = self.store.read_locked();
        let mut ids: Vec<&String> = self.parts.keys().chain(self.local.keys()).chain(store.keys()).chain(self.bundled.keys()).collect();
        ids.sort();
        ids.dedup();
        let ids: Vec<String> = ids.into_iter().cloned().collect();
        drop(store);
        ids.iter().filter_map(|id| self.get(id)).collect()
    }

    /// Reads the store again when it was read more than an hour ago (or
    /// never), or when [force].
    pub async fn refresh(&self, force: bool) {
        let mut read = self.read.lock().await;
        if !force && read.is_some_and(|at| at.elapsed() < TTL) {
            return;
        }
        *read = Some(Instant::now());
        let (catalog_url, fetch) = self.source.read_locked().clone();
        let base = url::Url::parse(&catalog_url).ok();
        let catalog = match fetch.get(&catalog_url, repo::MAX_CATALOG_BYTES).await {
            Ok(bytes) => repo::Catalog::parse(&bytes, base.as_ref()).map_err(|e| e.0),
            Err(e) => Err(e),
        };
        let catalog = catalog.unwrap_or_else(|e| {
            tracing::warn!("app catalog: reading the catalog: {e}");
            repo::Catalog::parse(BUNDLED_CATALOG.as_bytes(), None).expect("the bundled catalog reads")
        });
        let previous = self.store.read_locked().clone();
        let mut next: BTreeMap<String, Entry> = BTreeMap::new();
        let mut archives = Vec::new();
        for address in &catalog.repos {
            let files = fetch
                .get(&repo::archive_url_of(address), repo::MAX_ARCHIVE_BYTES)
                .await
                .and_then(|bytes| repo::read_archive(&bytes).map_err(|e| e.0));
            // Only its desk packages, for `desk` below.
            let desk_files = files.as_ref().map(|f| f.iter().filter(|(p, _)| p.starts_with("desk/")).map(|(p, b)| (p.clone(), b.clone())).collect::<Vec<_>>());
            archives.push((address.clone(), desk_files.map_err(|_| ())));
            match files {
                Ok(files) => {
                    for (id, package) in apps_in(&files) {
                        // The first repository listing an id has it.
                        next.entry(id).or_insert(Entry { package: Arc::new(package), source: Source::Store, repo: Some(address.clone()) });
                    }
                }
                Err(e) => {
                    // What it offered before stays.
                    tracing::warn!("app catalog: reading {address}: {e}");
                    for (id, entry) in previous.iter().filter(|(_, e)| e.repo.as_deref() == Some(address)) {
                        next.entry(id.clone()).or_insert_with(|| entry.clone());
                    }
                }
            }
        }
        if let Err(e) = write_cache(&self.cache, &next) {
            tracing::warn!("app catalog: keeping it in {}: {e}", self.cache.display());
        }
        *self.store.write_locked() = next;
        // Inflating and checking every package, and writing them: off the
        // worker.
        let desk = self.desk.clone();
        if let Err(e) = tokio::task::spawn_blocking(move || desk.replace(&archives)).await {
            tracing::warn!("desk app catalog: {e}");
        }
    }
}

/// The app folders of a repository's tree (`apps/<id>/<file>`), each checked
/// whole; one that is wrong is left out and said so.
fn apps_in<'a>(files: impl IntoIterator<Item = (&'a String, &'a Vec<u8>)>) -> BTreeMap<String, Package> {
    let mut folders: BTreeMap<&str, BTreeMap<String, Vec<u8>>> = BTreeMap::new();
    for (path, bytes) in files {
        let mut parts = path.split('/');
        if let (Some("apps"), Some(folder), Some(name), None) = (parts.next(), parts.next(), parts.next(), parts.next()) {
            folders.entry(folder).or_default().insert(name.to_string(), bytes.clone());
        }
    }
    let mut out = BTreeMap::new();
    for (folder, files) in folders {
        match Package::read(&files) {
            Ok(p) if p.manifest.id == folder => {
                out.insert(folder.to_string(), p);
            }
            Ok(p) => tracing::warn!("app catalog: apps/{folder} names {}", p.manifest.id),
            Err(problems) => tracing::warn!("app catalog: apps/{folder}: {problems:?}"),
        }
    }
    out
}

fn read_cache(cache: &Path) -> BTreeMap<String, Entry> {
    let mut out = BTreeMap::new();
    let Ok(dirs) = std::fs::read_dir(cache) else { return out };
    for dir in dirs.flatten() {
        let path = dir.path();
        if !path.is_dir() {
            continue;
        }
        let repo = std::fs::read_to_string(path.with_extension(SOURCE_FILE)).ok().map(|s| s.trim().to_string());
        match Package::read_dir(&path) {
            Ok(p) => {
                out.insert(p.manifest.id.clone(), Entry { package: Arc::new(p), source: Source::Store, repo });
            }
            Err(problems) => tracing::warn!("app catalog: {}: {problems:?}", path.display()),
        }
    }
    out
}

/// [entries] into [cache]: each app's folder replaced whole, the folders of
/// apps no longer offered removed.
fn write_cache(cache: &Path, entries: &BTreeMap<String, Entry>) -> std::io::Result<()> {
    std::fs::create_dir_all(cache)?;
    for (id, entry) in entries {
        let staged = cache.join(format!(".{id}.part"));
        let _ = std::fs::remove_dir_all(&staged);
        std::fs::create_dir_all(&staged)?;
        std::fs::write(staged.join("manifest.toml"), &entry.package.manifest_text)?;
        for (name, text) in &entry.package.files {
            std::fs::write(staged.join(name), text)?;
        }
        let dir = cache.join(id);
        let _ = std::fs::remove_dir_all(&dir);
        std::fs::rename(&staged, &dir)?;
        std::fs::write(dir.with_extension(SOURCE_FILE), entry.repo.as_deref().unwrap_or_default())?;
    }
    for dir in std::fs::read_dir(cache)?.flatten() {
        let name = dir.file_name().to_string_lossy().into_owned();
        let id = name.strip_suffix(&format!(".{SOURCE_FILE}")).unwrap_or(&name);
        if !entries.contains_key(id) {
            let path = dir.path();
            let _ = if path.is_dir() { std::fs::remove_dir_all(&path) } else { std::fs::remove_file(&path) };
        }
    }
    Ok(())
}

fn read_local(dir: &Path) -> BTreeMap<String, Arc<Package>> {
    let mut out = BTreeMap::new();
    let Ok(entries) = std::fs::read_dir(dir) else {
        tracing::warn!("local apps: {} cannot be read", dir.display());
        return out;
    };
    for entry in entries.flatten() {
        let path = entry.path();
        if !path.is_dir() {
            continue;
        }
        match Package::read_dir(&path) {
            Ok(p) => {
                tracing::info!("local app {} from {}", p.manifest.id, path.display());
                out.insert(p.manifest.id.clone(), Arc::new(p));
            }
            Err(problems) => tracing::warn!("local app {}: {problems:?}", path.display()),
        }
    }
    out
}
