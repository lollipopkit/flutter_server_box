//! This repository's own theme content, read by the agent's theme reader
//! (`fl_theme`, in the fl_lib submodule): the bundled packages, the official
//! store tree and the catalog the agent embeds. The reader's own rules are
//! tested beside it, in fl_lib.

use std::path::Path;

use fl_theme::repo::{Catalog, Index};
use indexmap::IndexMap;

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
    let bundled = std::fs::read(root().join("assets/store_themes/serverbox.piggy.fsbt")).unwrap();
    assert_eq!(fl_theme::install(&bundled).unwrap().id, "serverbox.piggy");
    for dir in ["store/themes/serverbox.pride", "store/themes/serverbox.one-dark-pro", "docs/examples/aurora"] {
        let p = fl_theme::install_files(tree(&root().join(dir))).unwrap_or_else(|e| panic!("{dir}: {e}"));
        assert!(!p.themes.is_empty(), "{dir}");
    }
}

#[test]
fn the_shipped_catalog_reads() {
    let c = Catalog::parse(&std::fs::read(root().join("assets/catalog/repos.toml")).unwrap(), None).unwrap();
    assert_eq!(c.repos, ["https://serverbox.lollipopkit.com/store.tar.gz"]);
}

#[test]
fn the_official_store_tree_reads() {
    let index = Index::from_files(&tree(&root().join("store"))).unwrap();
    assert!(index.themes.iter().any(|t| t.id == "serverbox.piggy"));
    assert!(index.themes.iter().all(|t| t.installable().is_some()), "{:?}", index.themes);
}
