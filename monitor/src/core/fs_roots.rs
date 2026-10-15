//! Where `/api/v1/fs/*` resolves a path, and what it never reaches.
//!
//! The file API reads and writes as the system account the agent runs as,
//! like its shell: what that account may reach is the boundary, and the
//! operating system enforces it. Two things are this module's:
//!
//! 1. A request path is resolved to a **canonical** path — every symlink
//!    followed, every `..` refused — before anything is done with it, so
//!    what is checked is where the path really lands.
//! 2. The agent's own state — its database, `jwt.secret`, `config.toml`, its
//!    TLS key, the custom-commands directory — is never reached, whatever the
//!    path. Each of those is a way past the password: the JWT secret signs a
//!    token, a custom command runs on every status cycle. See [`Protected`].
//!
//! ## What this does not defend against
//!
//! Resolution and use are two steps, so a symlink swapped in between them
//! would be followed — the classic TOCTOU. Closing that needs `openat` with
//! `O_NOFOLLOW` at every component, which is not portable across the platforms
//! monitor runs on. It matters only for the protected state: anything else a
//! swapped link reaches, the account could reach anyway.

use crate::utils::lock::RwLockExt;
use std::ffi::OsString;
use std::path::{Component, Path, PathBuf};

/// Why a path was refused. Kept apart from "the operation failed" so the API
/// can answer 403 for the first and 404/500 for the second — a client that
/// cannot tell them apart cannot tell "not allowed" from "not there".
#[derive(Debug, Clone, PartialEq, Eq)]
pub enum FsDenied {
    /// Not absolute. Relative paths have no meaning here: there is no working
    /// directory a client and this agent would agree on.
    NotAbsolute,
    /// Resolved to nothing reachable: absent, or the agent's own state.
    OutsideRoots,
    /// A `..` that no root could absorb, or one in a path that does not exist
    /// yet and so cannot be canonicalised.
    Traversal,
}

impl std::fmt::Display for FsDenied {
    fn fmt(&self, f: &mut std::fmt::Formatter<'_>) -> std::fmt::Result {
        match self {
            Self::NotAbsolute => write!(f, "path must be absolute"),
            Self::OutsideRoots => write!(f, "path is not reachable"),
            Self::Traversal => write!(f, "path escapes its root"),
        }
    }
}

/// The filesystem's roots (`/`, or each drive on Windows), and the agent's
/// own state, which no path reaches.
#[derive(Debug, Clone, Default)]
pub struct FsRoots {
    roots: Vec<PathBuf>,
    protected: Protected,
}

/// What the file API never reaches, inside the roots or not: the agent's own
/// state.
///
/// Per file rather than per directory, because the database usually sits in
/// the agent's working directory and that can be somebody's home: refusing
/// the whole directory would refuse the operator's own files there. What is
/// refused instead:
///
/// - a protected file itself, by its canonical path — so a symlink to it is
///   refused too, since it resolves there;
/// - in a protected file's directory, any name that starts with its name:
///   `serverbox_monitor.db` covers `-wal`, `-shm` and `-journal`, and
///   `config.toml` the `config.toml.bak-*` backups and the temporary file a
///   save is written through;
/// - everything under a protected tree (the custom-commands directory, whose
///   every file the status script runs);
/// - changing any directory one of those sits in — renaming, removing or
///   chmod-ing it. The paths are worked out at startup, and a renamed
///   directory would carry the files out from under them.
#[derive(Debug, Clone, Default)]
pub struct Protected {
    trees: Vec<PathBuf>,
    named: Vec<(PathBuf, OsString)>,
    /// A name in every subdirectory of a directory (`stacks/*/.env`).
    each: Vec<(PathBuf, OsString)>,
}

impl Protected {
    /// Protects [file] and every name in its directory that begins with its
    /// name. Relative paths are taken against the working directory, as the
    /// agent opens them.
    pub fn file(&mut self, file: &Path) {
        let path = settled(file);
        if let (Some(dir), Some(name)) = (path.parent(), path.file_name()) {
            self.named.push((dir.to_path_buf(), name.to_os_string()));
        }
    }

    /// Protects everything under [dir].
    pub fn tree(&mut self, dir: &Path) {
        self.trees.push(settled(dir));
    }

    /// Protects [name] (and names beginning with it) in every subdirectory of
    /// [dir], those made later included: one per deployed web app.
    pub fn in_each(&mut self, dir: &Path, name: &str) {
        self.each.push((settled(dir), OsString::from(name)));
    }

    /// Whether [path] — canonical — is protected state.
    pub fn covers(&self, path: &Path) -> bool {
        if self.trees.iter().any(|tree| path.starts_with(tree)) || runtime_trees().iter().any(|tree| path.starts_with(tree)) {
            return true;
        }
        let (Some(dir), Some(name)) = (path.parent(), path.file_name()) else {
            return false;
        };
        let name = name.as_encoded_bytes();
        self.named.iter().any(|(protected_dir, prefix)| {
            dir == protected_dir && name.starts_with(prefix.as_encoded_bytes())
        }) || self.each.iter().any(|(parent, prefix)| {
            dir.parent() == Some(parent.as_path()) && name.starts_with(prefix.as_encoded_bytes())
        })
    }

    /// Whether changing [path] — canonical — would move or remove protected
    /// state: it is protected, or a directory something protected is in.
    pub fn holds(&self, path: &Path) -> bool {
        self.covers(path)
            || self.trees.iter().any(|tree| tree.starts_with(path))
            || runtime_trees().iter().any(|tree| tree.starts_with(path))
            || self.named.iter().any(|(dir, _)| dir.starts_with(path))
            || self.each.iter().any(|(dir, _)| dir.starts_with(path) || path.parent() == Some(dir.as_path()))
    }
}

/// Trees that become the agent's state while it runs (a backup folder the
/// operator chose on a backup disk), protected as [`Protected::tree`] is.
static RUNTIME_TREES: std::sync::RwLock<Vec<PathBuf>> = std::sync::RwLock::new(Vec::new());

fn runtime_trees() -> std::sync::RwLockReadGuard<'static, Vec<PathBuf>> {
    RUNTIME_TREES.read_locked()
}

/// Protects everything under [dir] from now on; [previous] (the folder it
/// replaces, if any) no longer.
pub fn protect_at_runtime(dir: &Path, previous: Option<&Path>) {
    let mut trees = RUNTIME_TREES.write_locked();
    if let Some(previous) = previous {
        let previous = settled(previous);
        trees.retain(|t| *t != previous);
    }
    let dir = settled(dir);
    if !trees.contains(&dir) {
        trees.push(dir);
    }
}

/// [path] made absolute against the working directory and canonicalised as
/// far as it exists: a protected file may not be there yet (the first backup,
/// a database about to be created), and its directory is what must match.
fn settled(path: &Path) -> PathBuf {
    let absolute = if path.is_absolute() {
        path.to_path_buf()
    } else {
        std::env::current_dir()
            .map(|cwd| cwd.join(path))
            .unwrap_or_else(|_| path.to_path_buf())
    };
    let mut tail = Vec::new();
    let mut cursor = absolute.as_path();
    loop {
        if let Ok(canonical) = std::fs::canonicalize(cursor) {
            let mut settled = canonical;
            for name in tail.into_iter().rev() {
                settled.push(name);
            }
            return settled;
        }
        match (cursor.file_name(), cursor.parent()) {
            (Some(name), Some(parent)) => {
                tail.push(name.to_os_string());
                cursor = parent;
            }
            _ => return absolute,
        }
    }
}

impl FsRoots {
    /// Every root the filesystem has: `/`, or each drive on Windows.
    pub fn whole_filesystem() -> Self {
        #[cfg(windows)]
        let roots = (b'A'..=b'Z')
            .map(|drive| PathBuf::from(format!("{}:\\", drive as char)))
            .filter_map(|drive| std::fs::canonicalize(&drive).ok())
            .collect();
        #[cfg(not(windows))]
        let roots = vec![PathBuf::from("/")];
        Self {
            roots,
            protected: Protected::default(),
        }
    }

    /// For tests and for callers that already hold canonical paths.
    pub fn from_canonical(roots: Vec<PathBuf>) -> Self {
        Self {
            roots,
            protected: Protected::default(),
        }
    }

    /// These roots, never reaching [protected] — see [`Protected`].
    pub fn protecting(mut self, protected: Protected) -> Self {
        self.protected = protected;
        self
    }

    /// Whether a directory listing should leave out [path] — an entry of a
    /// directory already resolved, so canonical but for its own name.
    pub fn hides(&self, path: &Path) -> bool {
        self.protected.covers(path)
    }

    /// Refuses [path] — already resolved — when renaming, removing or
    /// chmod-ing it would move or remove the agent's own state.
    pub fn check_mutable(&self, path: &Path) -> Result<(), FsDenied> {
        if self.protected.holds(path) {
            Err(FsDenied::OutsideRoots)
        } else {
            Ok(())
        }
    }

    pub fn is_empty(&self) -> bool {
        self.roots.is_empty()
    }

    pub fn as_slice(&self) -> &[PathBuf] {
        &self.roots
    }

    /// Resolves a path that must already exist.
    ///
    /// Every symlink is followed first, so what is checked is where the path
    /// really lands rather than what it was spelled as.
    pub fn resolve_existing(&self, requested: &str) -> Result<PathBuf, FsDenied> {
        let path = Self::check_absolute(requested)?;
        let canonical = std::fs::canonicalize(&path).map_err(|_| {
            // Deliberately not distinguishing "not there" from "cannot be
            // reached": saying which would let a caller outside the roots map
            // the filesystem one 404 at a time.
            FsDenied::OutsideRoots
        })?;
        self.check_within(canonical)
    }

    /// Resolves an existing directory entry without following its final
    /// symlink. This is for operations such as remove and rename, which must
    /// mutate the link itself while still resolving and confining its parent.
    pub fn resolve_entry(&self, requested: &str) -> Result<PathBuf, FsDenied> {
        let path = Self::check_absolute(requested)?;
        let Some(parent) = path.parent() else {
            return self.resolve_existing(requested);
        };
        let Some(name) = path.file_name() else {
            return self.resolve_existing(requested);
        };
        let parent = std::fs::canonicalize(parent).map_err(|_| FsDenied::OutsideRoots)?;
        let mut resolved = self.check_within(parent)?;
        resolved.push(name);
        if self.protected.covers(&resolved) {
            return Err(FsDenied::OutsideRoots);
        }
        std::fs::symlink_metadata(&resolved).map_err(|_| FsDenied::OutsideRoots)?;
        Ok(resolved)
    }

    /// Resolves a path that may not exist yet — a file about to be written, a
    /// directory about to be made, the far end of a rename.
    ///
    /// The deepest existing ancestor is canonicalised and the rest appended,
    /// which is the only way to check something that cannot be resolved yet.
    /// The appended tail must be plain names: a `..` in it would undo the
    /// resolution that was just done.
    pub fn resolve_new(&self, requested: &str) -> Result<PathBuf, FsDenied> {
        let path = Self::check_absolute(requested)?;

        let mut tail = Vec::new();
        let mut cursor = path.as_path();
        let anchor = loop {
            if let Ok(canonical) = std::fs::canonicalize(cursor) {
                break canonical;
            }
            match (cursor.file_name(), cursor.parent()) {
                (Some(name), Some(parent)) => {
                    tail.push(name.to_os_string());
                    cursor = parent;
                }
                // Walked off the top without finding anything real. Only
                // reachable when even `/` cannot be canonicalised.
                _ => return Err(FsDenied::OutsideRoots),
            }
        };

        // Built from the anchor outwards, so nothing in the tail can climb
        // back out of it.
        let mut resolved = self.check_within(anchor)?;
        for name in tail.into_iter().rev() {
            if name == ".." || name == "." {
                return Err(FsDenied::Traversal);
            }
            resolved.push(name);
        }
        // The new name too: writing `jwt.secret` or a `config.toml.bak-*` is
        // writing the agent's state as surely as overwriting it is.
        if self.protected.covers(&resolved) {
            return Err(FsDenied::OutsideRoots);
        }
        Ok(resolved)
    }

    fn check_absolute(requested: &str) -> Result<PathBuf, FsDenied> {
        let path = PathBuf::from(requested);
        if !path.is_absolute() {
            return Err(FsDenied::NotAbsolute);
        }
        // A `..` anywhere is refused up front rather than resolved. It is
        // never necessary — a client that knows where it wants to go can say
        // so — and refusing it keeps the two resolvers from having to agree
        // about what a partly-resolvable `..` means.
        if path.components().any(|c| matches!(c, Component::ParentDir)) {
            return Err(FsDenied::Traversal);
        }
        Ok(path)
    }

    /// Component-wise, not by string prefix: `/var/logs` is not inside
    /// `/var/log`, and a prefix comparison would say it is.
    ///
    /// The agent's own state is refused here too, with the same answer as
    /// anything outside the roots: which of the two it was is nothing a
    /// caller needs to learn.
    fn check_within(&self, path: PathBuf) -> Result<PathBuf, FsDenied> {
        if self.protected.covers(&path) {
            return Err(FsDenied::OutsideRoots);
        }
        if self.roots.iter().any(|root| path.starts_with(root)) {
            Ok(path)
        } else {
            Err(FsDenied::OutsideRoots)
        }
    }
}
