//! The theme store (fl_lib `repo.dart`): the catalog of repositories, one
//! repository's tree, the listing of each theme in it with its versions, and
//! which version an app reading [SUPPORTED_SCHEMA_MIN]..[SUPPORTED_SCHEMA_MAX]
//! installs. Reading only; fetching is the caller's.

use std::cmp::Ordering;
use std::io::Read;

use indexmap::IndexMap;
use serde::Serialize;
use toml::{Table, Value};
use url::Url;

use crate::error::{Result, ThemeError, fail};
use crate::package::{SUPPORTED_SCHEMA_MAX, SUPPORTED_SCHEMA_MIN, is_id};

/// The catalog and repository schema this reads.
pub const CATALOG_SCHEMA: i64 = 1;
pub const MAX_REPOS: usize = 100;
pub const MAX_CATALOG_BYTES: usize = 1024 * 1024;
pub const MAX_ARCHIVE_BYTES: usize = 16 * 1024 * 1024;
pub const MAX_UNPACKED_BYTES: usize = 64 * 1024 * 1024;
pub const MAX_ENTRY_BYTES: usize = 8 * 1024 * 1024;
/// A bound on the decompressed tar, which stops a gzip bomb before the
/// content limit can be applied; above it by tar's own framing.
pub const MAX_TAR_BYTES: usize = MAX_UNPACKED_BYTES + 8 * 1024 * 1024;

/// The catalog the app reads (`Urls.themeCatalog`).
pub const CATALOG_URL: &str = "https://raw.githubusercontent.com/lollipopkit/flutter_server_box/main/assets/catalog/repos.toml";

/// An HTTPS address without credentials or a fragment, or a refusal.
pub fn https_url(input: &str) -> Result<Url> {
    match Url::parse(input.trim()) {
        Ok(url)
            if url.scheme() == "https"
                && url.host_str().is_some_and(|h| !h.is_empty())
                && url.username().is_empty()
                && url.password().is_none()
                && url.fragment().is_none() =>
        {
            Ok(url)
        }
        _ => fail("Use an HTTPS URL without credentials"),
    }
}

fn parse_toml(bytes: &[u8], what: &str) -> Result<Table> {
    let text = std::str::from_utf8(bytes).map_err(|e| ThemeError::new(format!("{what} is not readable TOML: {e}")))?;
    text.parse().map_err(|e| ThemeError::new(format!("{what} is not readable TOML: {e}")))
}

/// What a repository is called before it answers: `owner/repo`.
pub fn label_of(url: &Url) -> String {
    let segments: Vec<String> = url
        .path_segments()
        .map(|s| s.filter(|s| !s.is_empty()).map(|s| s.trim_end_matches(".git").to_string()).collect())
        .unwrap_or_default();
    let host = url.host_str().unwrap_or_default();
    match segments.len() {
        0 => host.to_string(),
        1 => format!("{host}/{}", segments[0]),
        n => format!("{}/{}", segments[n - 2], segments[n - 1]),
    }
}

/// Which repositories the store offers.
#[derive(Debug, Clone, PartialEq, Serialize)]
pub struct Catalog {
    pub name: Option<String>,
    pub repos: Vec<String>,
}

impl Catalog {
    /// [base] resolves a relative `url`.
    pub fn parse(bytes: &[u8], base: Option<&Url>) -> Result<Self> {
        if bytes.len() > MAX_CATALOG_BYTES {
            return fail("the catalog is larger than this app reads");
        }
        let raw = parse_toml(bytes, "the catalog")?;
        let Some(Value::Integer(announced)) = raw.get("schema") else {
            return fail("the catalog names no schema version");
        };
        if *announced > CATALOG_SCHEMA {
            return fail(format!("this catalog is schema v{announced} and this app reads v{CATALOG_SCHEMA}"));
        }
        let Some(Value::Array(rows)) = raw.get("repo") else {
            return fail("the catalog lists no readable repository");
        };
        if rows.len() > MAX_REPOS {
            return fail("the catalog lists no readable repository");
        }
        let mut repos: Vec<String> = Vec::new();
        for row in rows {
            let Value::Table(row) = row else { return fail("Invalid catalog entry") };
            let url = match row.get("url") {
                Some(Value::String(u)) if !u.trim().is_empty() => u.trim(),
                _ => return fail("a catalog entry names no url"),
            };
            let joined = match base {
                Some(base) => base.join(url).map(|u| u.to_string()).unwrap_or_default(),
                None => url.to_string(),
            };
            let resolved = https_url(&joined).map_err(|e| ThemeError::new(format!("{e}: {url}")))?;
            let resolved = resolved.to_string();
            // Listed twice is harmless and reading it twice is not free.
            if !repos.contains(&resolved) {
                repos.push(resolved);
            }
        }
        Ok(Self {
            name: match raw.get("name") {
                Some(Value::String(n)) => Some(n.clone()),
                _ => None,
            },
            repos,
        })
    }
}

/// A listing's description: one string, or one per language tag.
#[derive(Debug, Clone, PartialEq, Serialize)]
#[serde(untagged)]
pub enum Text {
    Plain(String),
    /// By normalized tag (`zh-tw`, `zh`, `en`).
    Languages(IndexMap<String, String>),
}

impl Text {
    fn parse(raw: Option<&Value>) -> Self {
        match raw {
            Some(Value::String(s)) => Text::Plain(s.clone()),
            Some(Value::Table(t)) => Text::Languages(
                t.iter()
                    .filter_map(|(k, v)| match v {
                        Value::String(s) if !k.trim().is_empty() => {
                            Some((k.trim().replace('_', "-").to_lowercase(), s.clone()))
                        }
                        _ => None,
                    })
                    .collect(),
            ),
            _ => Text::Languages(IndexMap::new()),
        }
    }
}

/// One version of one theme.
#[derive(Debug, Clone, PartialEq, Serialize)]
#[serde(rename_all = "camelCase")]
pub struct Release {
    pub version: String,
    pub schema_min: i64,
    pub schema_max: i64,
    /// Where the `.fsbt` is served; exactly one of this and [path].
    pub url: Option<String>,
    /// Where it is inside the repository's tree.
    pub path: Option<String>,
    /// SHA-256 of the package, lowercase hex.
    pub sha256: Option<String>,
    pub size: Option<i64>,
    pub notes: Option<String>,
}

impl Release {
    pub fn verifiable(&self) -> bool {
        self.sha256.as_deref().is_some_and(|d| d.len() == 64)
    }

    pub fn runs_on(&self, min: u32, max: u32) -> bool {
        self.schema_max >= i64::from(min) && self.schema_min <= i64::from(max)
    }

    /// One `[[version]]` table, or None when it is not usable: one bad
    /// version costs that version, not the theme.
    fn from_toml(raw: &Value) -> Option<Self> {
        let Value::Table(raw) = raw else { return None };
        let version = match raw.get("version") {
            Some(Value::String(v)) if !v.trim().is_empty() => v.trim().to_string(),
            _ => return None,
        };
        let (Some(Value::Integer(min)), Some(Value::Integer(max))) = (raw.get("schema_min"), raw.get("schema_max")) else {
            return None;
        };
        if min > max {
            return None;
        }
        let text = |key: &str| match raw.get(key) {
            Some(Value::String(s)) if !s.is_empty() => Some(s.clone()),
            _ => None,
        };
        let url = text("url");
        let path = text("path");
        // Exactly one: the two could disagree about which bytes this is.
        if url.is_some() == path.is_some() {
            return None;
        }
        if let Some(path) = &path
            && (path.starts_with('/') || path.split('/').any(|p| p == ".."))
        {
            return None;
        }
        Some(Self {
            version,
            schema_min: *min,
            schema_max: *max,
            url,
            path,
            sha256: text("sha256").map(|d| d.to_lowercase()),
            size: match raw.get("size") {
                Some(Value::Integer(s)) => Some(*s),
                _ => None,
            },
            notes: match raw.get("notes") {
                Some(Value::String(s)) => Some(s.clone()),
                _ => None,
            },
        })
    }
}

/// One theme in a repository, with every version it offers.
#[derive(Debug, Clone, PartialEq, Serialize)]
pub struct Listing {
    pub id: String,
    pub name: String,
    pub description: Text,
    pub homepage: Option<String>,
    pub license: Option<String>,
    pub releases: Vec<Release>,
}

impl Listing {
    /// The newest version an app reading [min]..[max] can run, chosen by
    /// schema rather than by the file's order.
    pub fn best_for(&self, min: u32, max: u32) -> Option<&Release> {
        self.releases
            .iter()
            .filter(|r| r.runs_on(min, max))
            .fold(None, |best: Option<&Release>, r| match best {
                Some(b) if compare_versions(&r.version, &b.version) != Ordering::Greater => Some(b),
                _ => Some(r),
            })
    }

    /// The newest version this build installs.
    pub fn installable(&self) -> Option<&Release> {
        self.best_for(SUPPORTED_SCHEMA_MIN, SUPPORTED_SCHEMA_MAX)
    }

    /// One theme's file; [path] is where it was found, and must agree with
    /// the id inside.
    pub fn parse(text: &str, path: &str) -> Result<Self> {
        let raw: Table = text.parse().map_err(|e| ThemeError::new(format!("{path} is not readable TOML: {e}")))?;
        let id = match raw.get("id") {
            Some(Value::String(id)) if !id.is_empty() => id.clone(),
            _ => return fail(format!("{path} names no id")),
        };
        if let Some(expected) = id_of(path)
            && expected != id
        {
            return fail(format!("{path} says it is {id}, and its path says {expected}"));
        }
        let releases: Vec<Release> = match raw.get("version") {
            Some(Value::Array(versions)) => versions.iter().filter_map(Release::from_toml).collect(),
            _ => Vec::new(),
        };
        if releases.is_empty() {
            return fail(format!("{path} offers no readable version"));
        }
        let text = |key: &str| match raw.get(key) {
            Some(Value::String(s)) => Some(s.clone()),
            _ => None,
        };
        Ok(Self {
            name: text("name").unwrap_or_else(|| id.clone()),
            id,
            description: Text::parse(raw.get("description")),
            homepage: text("homepage"),
            license: text("license"),
            releases,
        })
    }
}

/// The theme a repository path describes: `themes/<id>.toml`.
pub fn id_of(path: &str) -> Option<&str> {
    path.strip_prefix("themes/").and_then(|rest| rest.strip_suffix(".toml")).filter(|id| is_id(id))
}

/// One repository's tree, read.
#[derive(Debug, Clone, PartialEq)]
pub struct Index {
    pub name: Option<String>,
    pub themes: Vec<Listing>,
    /// The `.fsbt` files the tree carried, by path.
    pub packages: IndexMap<String, Vec<u8>>,
}

impl Index {
    /// One bad theme file costs that theme; a bad `repo.toml` costs the
    /// repository. A section that is not `themes/` is skipped.
    pub fn from_files(files: &IndexMap<String, Vec<u8>>) -> Result<Self> {
        let Some(repo) = files.get("repo.toml") else {
            return fail("no repo.toml, so this is not a repository");
        };
        let raw = parse_toml(repo, "repo.toml")?;
        let Some(Value::Integer(announced)) = raw.get("schema") else {
            return fail("repo.toml names no schema version");
        };
        if *announced > CATALOG_SCHEMA {
            return fail(format!(
                "this repository is schema v{announced} and this app reads v{CATALOG_SCHEMA}"
            ));
        }
        let mut paths: Vec<&String> = files.keys().collect();
        paths.sort();
        let themes = paths
            .into_iter()
            .filter(|p| id_of(p).is_some())
            .filter_map(|p| std::str::from_utf8(&files[p]).ok().and_then(|t| Listing::parse(t, p).ok()))
            .collect();
        Ok(Self {
            name: match raw.get("name") {
                Some(Value::String(n)) => Some(n.clone()),
                _ => None,
            },
            themes,
            packages: files
                .iter()
                .filter(|(k, _)| k.starts_with("packages/"))
                .map(|(k, v)| (k.clone(), v.clone()))
                .collect(),
        })
    }
}

/// The tarball an address is fetched from: `<repo>/archive/HEAD.tar.gz`, or
/// the address itself when it names an archive.
pub fn archive_url_of(address: &str) -> String {
    let trimmed = address.trim();
    let lower = trimmed.to_ascii_lowercase();
    if lower.ends_with(".tar.gz") || lower.ends_with(".tgz") {
        return trimmed.to_string();
    }
    let mut base = trimmed.trim_end_matches('/');
    if base.to_ascii_lowercase().ends_with(".git") {
        base = &base[..base.len() - 4];
    }
    format!("{base}/archive/HEAD.tar.gz")
}

/// A repository's `.tar.gz` unpacked into its files, without the directory a
/// hosting service wraps them in.
pub fn read_archive(bytes: &[u8]) -> Result<IndexMap<String, Vec<u8>>> {
    let mut tar = Vec::new();
    flate2::read::GzDecoder::new(bytes)
        .take(MAX_TAR_BYTES as u64 + 1)
        .read_to_end(&mut tar)
        .map_err(|e| ThemeError::new(format!("the repository is not a readable .tar.gz: {e}")))?;
    if tar.len() > MAX_TAR_BYTES {
        return fail("the repository unpacks to too much");
    }
    let mut archive = tar::Archive::new(tar.as_slice());
    let entries = archive
        .entries()
        .map_err(|e| ThemeError::new(format!("the repository is not a readable .tar.gz: {e}")))?;
    let mut files = IndexMap::new();
    let mut total = 0usize;
    for entry in entries {
        let mut entry = entry.map_err(|e| ThemeError::new(format!("the repository is not a readable .tar.gz: {e}")))?;
        if !entry.header().entry_type().is_file() {
            continue;
        }
        let raw = entry
            .path()
            .map_err(|e| ThemeError::new(format!("the repository is not a readable .tar.gz: {e}")))?
            .to_string_lossy()
            .into_owned();
        let Some(name) = safe_name(&raw) else {
            return fail(format!("unsafe path in the repository: {raw}"));
        };
        let size = entry.size() as usize;
        if size > MAX_ENTRY_BYTES {
            return fail(format!("{name} is larger than {MAX_ENTRY_BYTES} bytes"));
        }
        total += size;
        if total > MAX_UNPACKED_BYTES {
            return fail("the repository unpacks to too much");
        }
        let mut content = Vec::with_capacity(size);
        entry
            .read_to_end(&mut content)
            .map_err(|e| ThemeError::new(format!("the repository is not a readable .tar.gz: {e}")))?;
        files.insert(name, content);
    }
    Ok(strip_top_directory(files))
}

fn safe_name(name: &str) -> Option<String> {
    let parts: Vec<&str> = name.split('/').filter(|p| !p.is_empty()).collect();
    if parts.is_empty() || parts.iter().any(|p| *p == "." || *p == "..") {
        return None;
    }
    Some(parts.join("/"))
}

fn strip_top_directory(files: IndexMap<String, Vec<u8>>) -> IndexMap<String, Vec<u8>> {
    let Some(first) = files.keys().next().map(|k| k.split('/').next().unwrap_or_default().to_string()) else {
        return files;
    };
    let prefix = format!("{first}/");
    if !files.keys().all(|k| k.starts_with(&prefix)) {
        return files;
    }
    files
        .into_iter()
        .filter(|(k, _)| k.len() > prefix.len())
        .map(|(k, v)| (k[prefix.len()..].to_string(), v))
        .collect()
}

/// `1.10.0` against `1.9.0`, field by field; a suffix (`1.0.0-beta`) sorts
/// below the same numbers without one.
pub fn compare_versions(a: &str, b: &str) -> Ordering {
    fn parts(v: &str) -> Vec<i64> {
        v.split('-').next().unwrap_or_default().split('.').map(|p| p.trim().parse().unwrap_or(0)).collect()
    }
    fn suffix(v: &str) -> &str {
        v.find('-').map_or("", |at| &v[at + 1..])
    }
    let (left, right) = (parts(a), parts(b));
    for i in 0..3 {
        let d = left.get(i).copied().unwrap_or(0).cmp(&right.get(i).copied().unwrap_or(0));
        if d != Ordering::Equal {
            return d;
        }
    }
    match (suffix(a), suffix(b)) {
        ("", "") => Ordering::Equal,
        ("", _) => Ordering::Greater,
        (_, "") => Ordering::Less,
        (x, y) => x.cmp(y),
    }
}
