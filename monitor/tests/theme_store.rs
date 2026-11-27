//! This repository's own theme content, read by the agent's theme reader
//! (`fl_theme`, in the fl_lib submodule): the bundled packages, the official
//! store tree and the catalog the agent embeds. The reader's own rules are
//! tested beside it, in fl_lib.

use std::collections::HashSet;
use std::path::Path;

use fl_theme::repo::{Catalog, Index, archive_url_of, https_url};
use indexmap::IndexMap;
use toml::{Table, Value};

fn root() -> &'static Path {
    Path::new(concat!(env!("CARGO_MANIFEST_DIR"), "/.."))
}

/// A directory's files by their path inside it.
fn tree(dir: &Path) -> IndexMap<String, Vec<u8>> {
    fn walk(base: &Path, dir: &Path, out: &mut IndexMap<String, Vec<u8>>) {
        let mut entries: Vec<_> = std::fs::read_dir(dir).unwrap().map(|e| e.unwrap().path()).collect();
        entries.sort();
        for path in entries {
            if path.is_dir() {
                walk(base, &path, out);
            } else {
                out.insert(path.strip_prefix(base).unwrap().to_string_lossy().replace('\\', "/"), std::fs::read(&path).unwrap());
            }
        }
    }
    let mut out = IndexMap::new();
    walk(dir, dir, &mut out);
    out
}

#[test]
fn every_store_theme_in_this_repository_installs() {
    for dir in ["store/themes/serverbox.piggy", "store/themes/serverbox.pride", "store/themes/serverbox.one-dark-pro", "docs/examples/aurora"] {
        let p = fl_theme::install_files(tree(&root().join(dir))).unwrap_or_else(|e| panic!("{dir}: {e}"));
        assert!(!p.themes.is_empty(), "{dir}");
    }
}

#[test]
fn the_shipped_catalog_reads() {
    let bytes = std::fs::read(root().join("assets/catalog/repos.toml")).unwrap();
    let c = Catalog::parse(&bytes, None).unwrap();
    let raw: Table = std::str::from_utf8(&bytes).unwrap().parse().unwrap();
    let raw_repos = raw.get("repo").and_then(Value::as_array).unwrap();
    assert_eq!(c.repos.len(), raw_repos.len(), "duplicate repository entries in assets/catalog/repos.toml");

    // Official store must stay first: stacks and desk catalogs resolve ID collisions first-seen-wins.
    let official = "https://serverbox.lollipopkit.com/store.tar.gz";
    assert_eq!(c.repos.first().map(String::as_str), Some(official));
    assert_eq!(archive_url_of(official), official);

    let mut archives = HashSet::new();
    for url in &c.repos {
        let archive = archive_url_of(url);
        let parsed = https_url(&archive).unwrap_or_else(|e| panic!("{url} -> {archive}: {e}"));
        assert!(parsed.query().is_none(), "{url} must not carry a query string: {archive}");
        let path = parsed.path().to_ascii_lowercase();
        assert!(path.ends_with(".tar.gz") || path.ends_with(".tgz"), "{url} -> {archive}");
        assert!(archives.insert(archive.clone()), "duplicate archive target in assets/catalog/repos.toml: {url} -> {archive}");
    }
}

#[test]
fn the_official_store_tree_reads() {
    let index = Index::from_files(&tree(&root().join("store"))).unwrap();
    assert!(index.listings.iter().any(|t| t.kind == fl_theme::repo::Kind::Theme && t.id == "serverbox.piggy"));
    assert!(index.listings.iter().all(|t| t.installable().is_some()), "{:?}", index.listings);
}
