//! The desk app packages this agent offers to install (`store/desk/*.fsba`):
//! the ones it ships, so an agent with no network offers them, and each
//! repository of the store's, read with the web apps' catalog
//! (`stacks::catalog`) and kept in `<stacks>/.desk-catalog/` so an agent
//! that cannot reach them keeps what it last read. One id, one package: the
//! store's, else the shipped one.
//!
//! Every package is read as an upload is (`api::apps::read_package`:
//! checks and signature); installing one is uploading it, so it waits for
//! approval like any other.

use std::collections::BTreeMap;
use std::path::{Path, PathBuf};
use std::sync::{Arc, LazyLock, RwLock};

use serde::Serialize;

use crate::api::apps::{Package, read_package};
use crate::utils::lock::RwLockExt;

macro_rules! desk {
    ($($id:literal),+ $(,)?) => {
        &[$(($id, include_bytes!(concat!("../../../store/desk/", $id, ".fsba")))),+]
    };
}

/// The shipped packages, by app id. A test holds this list equal to
/// `store/desk/`.
const BUNDLED: &[(&str, &[u8])] = desk!["serverbox.cleanup", "serverbox.kernel", "serverbox.proxy", "serverbox.tailscale", "serverbox.ubuntu_pro"];

#[derive(Debug, Clone, Copy, PartialEq, Eq, Serialize)]
#[serde(rename_all = "camelCase")]
pub enum Source {
    Bundled,
    Store,
}

/// A package on offer.
pub struct Offered {
    pub bytes: Vec<u8>,
    pub package: Package,
    pub source: Source,
    /// The repository's address, for a store package.
    pub repo: Option<String>,
}

static SHIPPED: LazyLock<BTreeMap<String, Arc<Offered>>> = LazyLock::new(|| {
    BUNDLED
        .iter()
        .filter_map(|(id, bytes)| match read_package(bytes) {
            Ok(package) if package.manifest.id() == *id => {
                Some((id.to_string(), Arc::new(Offered { bytes: bytes.to_vec(), package, source: Source::Bundled, repo: None })))
            }
            Ok(p) => {
                tracing::error!("shipped desk app {id} names {}", p.manifest.id());
                None
            }
            Err(e) => {
                tracing::error!("shipped desk app {id}: {}", e.error);
                None
            }
        })
        .collect()
});

/// A repository's address and its `(path, bytes)` files, or `Err` when it
/// could not be read.
pub type RepoFiles<'a> = (String, Result<Vec<(&'a String, &'a Vec<u8>)>, ()>);

pub struct DeskCatalog {
    cache: PathBuf,
    store: RwLock<BTreeMap<String, Arc<Offered>>>,
}

impl DeskCatalog {
    /// The store's packages as cached in [cache].
    pub fn new(cache: PathBuf) -> Self {
        let store = read_cache(&cache);
        Self { cache, store: RwLock::new(store) }
    }

    pub fn get(&self, id: &str) -> Option<Arc<Offered>> {
        self.store.read_locked().get(id).cloned().or_else(|| SHIPPED.get(id).cloned())
    }

    /// Every package on offer, by id.
    pub fn all(&self) -> Vec<Arc<Offered>> {
        let store = self.store.read_locked();
        let mut ids: Vec<&String> = store.keys().chain(SHIPPED.keys()).collect();
        ids.sort();
        ids.dedup();
        ids.into_iter().filter_map(|id| store.get(id).or_else(|| SHIPPED.get(id)).cloned()).collect()
    }

    /// The repositories' packages as just read: [read] each repository's
    /// address and its files, or `Err` for one that could not be read, whose
    /// packages stay as they were.
    pub fn replace(&self, read: &[RepoFiles<'_>]) {
        let previous = self.store.read_locked().clone();
        let mut next: BTreeMap<String, Arc<Offered>> = BTreeMap::new();
        for (address, files) in read {
            match files {
                Ok(files) => {
                    for (id, offered) in packages_in(address, files) {
                        // The first repository listing an id has it.
                        next.entry(id).or_insert(offered);
                    }
                }
                Err(()) => {
                    for (id, o) in previous.iter().filter(|(_, o)| o.repo.as_deref() == Some(address)) {
                        next.entry(id.clone()).or_insert_with(|| o.clone());
                    }
                }
            }
        }
        if let Err(e) = write_cache(&self.cache, &next) {
            tracing::warn!("desk app catalog: keeping it in {}: {e}", self.cache.display());
        }
        *self.store.write_locked() = next;
    }
}

/// A repository's `desk/<id>.fsba` files, each read whole; one that is
/// wrong is left out and said so.
fn packages_in(address: &str, files: &[(&String, &Vec<u8>)]) -> BTreeMap<String, Arc<Offered>> {
    let mut out = BTreeMap::new();
    for &(path, bytes) in files {
        let Some(id) = path.strip_prefix("desk/").and_then(|n| n.strip_suffix(".fsba")).filter(|n| !n.contains('/')) else { continue };
        match read_package(bytes) {
            Ok(package) if package.manifest.id() == id => {
                out.insert(id.to_string(), Arc::new(Offered { bytes: bytes.clone(), package, source: Source::Store, repo: Some(address.to_string()) }));
            }
            Ok(p) => tracing::warn!("desk app catalog: {path} names {}", p.manifest.id()),
            Err(e) => tracing::warn!("desk app catalog: {path}: {}", e.error),
        }
    }
    out
}

const SOURCE_SUFFIX: &str = ".source";

fn read_cache(cache: &Path) -> BTreeMap<String, Arc<Offered>> {
    let mut out = BTreeMap::new();
    let Ok(entries) = std::fs::read_dir(cache) else { return out };
    for entry in entries.flatten() {
        let path = entry.path();
        let Some(id) = path.file_name().and_then(|n| n.to_str()).and_then(|n| n.strip_suffix(".fsba")).map(str::to_owned) else { continue };
        let repo = std::fs::read_to_string(cache.join(format!("{id}{SOURCE_SUFFIX}"))).ok().map(|s| s.trim().to_string());
        match std::fs::read(&path).map_err(|e| e.to_string()).and_then(|b| read_package(&b).map(|p| (b, p)).map_err(|e| e.error.to_string())) {
            Ok((bytes, package)) if package.manifest.id() == id => {
                out.insert(id, Arc::new(Offered { bytes, package, source: Source::Store, repo }));
            }
            Ok(_) => tracing::warn!("desk app catalog: {} is not {id}", path.display()),
            Err(e) => tracing::warn!("desk app catalog: {}: {e}", path.display()),
        }
    }
    out
}

/// [entries] into [cache], each written aside and renamed; the packages no
/// longer offered removed.
fn write_cache(cache: &Path, entries: &BTreeMap<String, Arc<Offered>>) -> std::io::Result<()> {
    std::fs::create_dir_all(cache)?;
    for (id, o) in entries {
        let staged = cache.join(format!(".{id}.part"));
        std::fs::write(&staged, &o.bytes)?;
        std::fs::rename(&staged, cache.join(format!("{id}.fsba")))?;
        std::fs::write(cache.join(format!("{id}{SOURCE_SUFFIX}")), o.repo.as_deref().unwrap_or_default())?;
    }
    for entry in std::fs::read_dir(cache)?.flatten() {
        let name = entry.file_name().to_string_lossy().into_owned();
        let id = name.strip_suffix(".fsba").or_else(|| name.strip_suffix(SOURCE_SUFFIX)).unwrap_or(&name);
        if !entries.contains_key(id) {
            let _ = std::fs::remove_file(entry.path());
        }
    }
    Ok(())
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn every_shipped_package_is_store_desk_and_reads_signed() {
        let dir = Path::new(env!("CARGO_MANIFEST_DIR")).join("../store/desk");
        let mut files: Vec<String> = std::fs::read_dir(&dir)
            .unwrap()
            .flatten()
            .filter_map(|e| e.file_name().to_str().and_then(|n| n.strip_suffix(".fsba")).map(str::to_owned))
            .collect();
        files.sort();
        let listed: Vec<&str> = BUNDLED.iter().map(|(id, _)| *id).collect();
        assert_eq!(files, listed, "BUNDLED lists store/desk/");
        for (id, _) in BUNDLED {
            let o = SHIPPED.get(*id).unwrap_or_else(|| panic!("{id} reads"));
            assert_eq!(o.package.signed_by, Some("serverbox-2026"), "{id} is signed");
        }
    }
}
