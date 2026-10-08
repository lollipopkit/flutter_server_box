//! fl_lib's `test/theme/repo_test.dart`: the catalog, a repository's tree, the
//! listings in it and which version installs.

use std::cmp::Ordering;
use std::io::Write;

use indexmap::IndexMap;
use sbm_theme::repo::{
    Catalog, Index, Listing, MAX_ENTRY_BYTES, MAX_TAR_BYTES, Text, archive_url_of, compare_versions, read_archive,
};

fn catalog_toml(schema: &str, repos: &str) -> String {
    format!("schema = {schema}\nname = \"ServerBox themes\"\n{repos}")
}

fn repo_entry(url: &str) -> String {
    format!("[[repo]]\nurl = \"{url}\"\n")
}

fn theme_toml(id: &str, versions: &str) -> String {
    format!("id = \"{id}\"\nname = \"Aurora\"\ndescription = \"Green\"\n{versions}")
}

#[derive(Clone)]
struct V {
    version: &'static str,
    min: i64,
    max: i64,
    url: Option<&'static str>,
    path: Option<&'static str>,
    sha256: Option<&'static str>,
}

impl Default for V {
    fn default() -> Self {
        Self {
            version: "1.0.0",
            min: 1,
            max: 1,
            url: Some("https://example.org/aurora-1.0.0.fsbt"),
            path: None,
            sha256: None,
        }
    }
}

fn version(v: V) -> String {
    let mut out = format!(
        "[[version]]\nversion = \"{}\"\nschema_min = {}\nschema_max = {}\n",
        v.version, v.min, v.max
    );
    if let Some(url) = v.url {
        out += &format!("url = \"{url}\"\n");
    }
    if let Some(path) = v.path {
        out += &format!("path = \"{path}\"\n");
    }
    out += &format!("sha256 = \"{}\"\n", v.sha256.map(str::to_string).unwrap_or_else(|| "a".repeat(64)));
    out
}

fn files(repo: Option<&str>, themes: &[(&str, String)], extra: &[(&str, &str)]) -> IndexMap<String, Vec<u8>> {
    let mut out = IndexMap::new();
    if let Some(repo) = repo {
        out.insert("repo.toml".to_string(), repo.as_bytes().to_vec());
    }
    for (path, text) in themes {
        out.insert(path.to_string(), text.as_bytes().to_vec());
    }
    for (path, text) in extra {
        out.insert(path.to_string(), text.as_bytes().to_vec());
    }
    out
}

const REPO: &str = "schema = 1\nname = \"A test repository\"\n";

fn aurora() -> (&'static str, String) {
    ("themes/aurora.toml", theme_toml("aurora", &version(V::default())))
}

fn tar_gz(entries: &[(&str, Vec<u8>)], top: Option<&str>) -> Vec<u8> {
    let mut builder = tar::Builder::new(Vec::new());
    for (name, bytes) in entries {
        let path = match top {
            Some(top) => format!("{top}/{name}"),
            None => name.to_string(),
        };
        let mut header = tar::Header::new_gnu();
        header.set_size(bytes.len() as u64);
        header.set_mode(0o644);
        header.set_entry_type(tar::EntryType::Regular);
        // `set_path` refuses `..`; a hostile archive writes it anyway.
        let field = &mut header.as_old_mut().name;
        field[..path.len()].copy_from_slice(path.as_bytes());
        header.set_cksum();
        builder.append(&header, bytes.as_slice()).unwrap();
    }
    let tar = builder.into_inner().unwrap();
    let mut gz = flate2::write::GzEncoder::new(Vec::new(), flate2::Compression::fast());
    gz.write_all(&tar).unwrap();
    gz.finish().unwrap()
}

fn description(toml: &str) -> Text {
    let text = theme_toml("aurora", &version(V::default())).replacen("description = \"Green\"\n", toml, 1);
    Listing::parse(&text, "themes/aurora.toml").unwrap().description
}

#[test]
fn a_description_is_a_string_or_a_table_of_languages() {
    assert_eq!(description("description = \"Green\"\n"), Text::Plain("Green".into()));
    let Text::Languages(table) = description("[description]\nen = \"Green\"\nzh = \"绿色\"\nzh_TW = \"綠色\"\npt-BR = \"Verde\"\n")
    else {
        panic!()
    };
    assert_eq!(table["zh-tw"], "綠色");
    assert_eq!(table["pt-br"], "Verde");
    assert_eq!(description("description = 3\n"), Text::Languages(IndexMap::new()));
}

#[test]
fn a_catalog_lists_its_repositories_once_each() {
    let c = Catalog::parse(
        catalog_toml(
            "1",
            &(repo_entry("https://github.com/lollipopkit/serverbox-themes") + &repo_entry("https://github.com/someone/themes")),
        )
        .as_bytes(),
        None,
    )
    .unwrap();
    assert_eq!(c.name.as_deref(), Some("ServerBox themes"));
    assert_eq!(c.repos.len(), 2);
    let twice = Catalog::parse(
        catalog_toml("1", &(repo_entry("https://github.com/a/b") + &repo_entry("https://github.com/a/b"))).as_bytes(),
        None,
    )
    .unwrap();
    assert_eq!(twice.repos.len(), 1);
}

#[test]
fn a_catalog_resolves_a_repository_beside_itself() {
    let base = url::Url::parse("https://example.org/store/repos.toml").unwrap();
    let c = Catalog::parse(catalog_toml("1", &repo_entry("./themes")).as_bytes(), Some(&base)).unwrap();
    assert_eq!(c.repos, ["https://example.org/store/themes"]);
}

#[test]
fn a_catalog_refuses_plaintext_and_a_schema_it_cannot_read() {
    assert!(Catalog::parse(catalog_toml("1", &repo_entry("http://github.com/a/b")).as_bytes(), None).is_err());
    assert!(Catalog::parse(catalog_toml("2", &repo_entry("https://a/b")).as_bytes(), None).is_err());
    assert!(Catalog::parse(b"name = \"no schema\"\n", None).is_err());
}

#[test]
fn the_shipped_catalog_reads() {
    let root = std::path::Path::new(env!("CARGO_MANIFEST_DIR")).join("../../assets/catalog/repos.toml");
    let c = Catalog::parse(&std::fs::read(root).unwrap(), None).unwrap();
    assert_eq!(c.repos, ["https://serverbox.lollipopkit.com/store.tar.gz"]);
}

#[test]
fn a_repository_keeps_what_its_tree_carries() {
    let theme = theme_toml(
        "aurora",
        &version(V { version: "1.1.0", url: None, path: Some("packages/a-1.1.0.fsbt"), ..V::default() }),
    );
    let index = Index::from_files(&files(
        Some(REPO),
        &[("themes/aurora.toml", theme)],
        &[("packages/a-1.1.0.fsbt", "bytes")],
    ))
    .unwrap();
    assert_eq!(index.name.as_deref(), Some("A test repository"));
    assert_eq!(index.themes[0].id, "aurora");
    assert_eq!(index.packages.keys().collect::<Vec<_>>(), ["packages/a-1.1.0.fsbt"]);
}

#[test]
fn a_plugins_section_yields_nothing_installable() {
    let plugin = format!(
        "id = \"app.serverbox.diskusage\"\nname = \"Disk usage\"\n[[version]]\nversion = \"1.0.1\"\nabi = 2\nurl = \"https://example.org/x.sbp\"\nsha256 = \"{}\"\n",
        "b".repeat(64)
    );
    let index = Index::from_files(&files(
        Some(REPO),
        &[aurora()],
        &[
            ("plugins/app/serverbox/diskusage.toml", &plugin),
            ("themes/app.serverbox.diskusage.toml", &plugin),
            ("README.md", "# A repository"),
        ],
    ))
    .unwrap();
    assert_eq!(index.themes.iter().map(|t| t.id.as_str()).collect::<Vec<_>>(), ["aurora"]);
}

#[test]
fn one_unreadable_theme_file_costs_that_theme_only() {
    let index = Index::from_files(&files(
        Some(REPO),
        &[
            aurora(),
            ("themes/broken.toml", "id = \"something-else\"\n".into()),
            ("themes/dracula.toml", theme_toml("dracula", &version(V::default()))),
        ],
        &[],
    ))
    .unwrap();
    assert_eq!(index.themes.iter().map(|t| t.id.as_str()).collect::<Vec<_>>(), ["aurora", "dracula"]);
}

#[test]
fn a_tree_that_is_not_a_repository_is_refused() {
    assert!(Index::from_files(&files(None, &[aurora()], &[])).is_err());
    assert!(Index::from_files(&files(Some("schema = 2\nname = \"From the future\"\n"), &[aurora()], &[])).is_err());
    assert!(Listing::parse(&theme_toml("dracula", ""), "themes/aurora.toml").is_err());
}

#[test]
fn the_newest_readable_version_wins() {
    let listing = |versions: String| Listing::parse(&theme_toml("aurora", &versions), "themes/aurora.toml").unwrap();
    let t = listing(version(V { version: "1.9.0", ..V::default() }) + &version(V { version: "1.10.0", ..V::default() }));
    assert_eq!(t.best_for(1, 1).unwrap().version, "1.10.0");
    let t = listing(version(V { version: "2.0.0", min: 2, max: 2, ..V::default() }) + &version(V::default()));
    assert_eq!(t.best_for(1, 1).unwrap().version, "1.0.0");
    let t = listing(version(V { version: "2.0.0", min: 2, max: 2, ..V::default() }));
    assert!(t.best_for(1, 1).is_none());
}

#[test]
fn a_version_naming_both_sources_or_climbing_out_is_dropped() {
    let listing = |versions: String| Listing::parse(&theme_toml("aurora", &versions), "themes/aurora.toml").unwrap();
    let t = listing(
        version(V { url: Some("https://a/b.fsbt"), path: Some("packages/b.fsbt"), ..V::default() })
            + &version(V { version: "1.0.1", ..V::default() }),
    );
    assert_eq!(t.releases.iter().map(|r| r.version.as_str()).collect::<Vec<_>>(), ["1.0.1"]);
    let t = listing(
        version(V { url: None, path: Some("../packages/b.fsbt"), ..V::default() })
            + &version(V { version: "1.0.1", ..V::default() }),
    );
    assert_eq!(t.releases.len(), 1);
    assert!(Listing::parse("id = \"aurora\"\nname = \"Aurora\"\n", "themes/aurora.toml").is_err());
}

#[test]
fn versions_compare_numerically_and_a_prerelease_is_older() {
    assert_eq!(compare_versions("1.10.0", "1.9.0"), Ordering::Greater);
    assert_eq!(compare_versions("1.0.0", "1.0.0"), Ordering::Equal);
    assert_eq!(compare_versions("1.0.0", "1.0.0-beta"), Ordering::Greater);
    assert_eq!(compare_versions("2.0.0", "1.99.99"), Ordering::Greater);
}

#[test]
fn a_version_without_a_digest_is_not_verifiable() {
    let text = theme_toml("aurora", &version(V::default())).replace(&format!("sha256 = \"{}\"", "a".repeat(64)), "notes = \"no digest\"");
    let t = Listing::parse(&text, "themes/aurora.toml").unwrap();
    assert!(!t.releases[0].verifiable());
}

#[test]
fn a_fetched_tree_is_read_without_its_wrapping_directory() {
    let read = read_archive(&tar_gz(
        &[("repo.toml", REPO.as_bytes().to_vec()), ("themes/aurora.toml", aurora().1.into_bytes())],
        Some("owner-repo-sha"),
    ))
    .unwrap();
    assert!(read.contains_key("repo.toml") && read.contains_key("themes/aurora.toml"));
    assert_eq!(Index::from_files(&read).unwrap().themes[0].id, "aurora");
}

#[test]
fn an_address_becomes_the_tarball_it_is_fetched_from() {
    assert_eq!(archive_url_of("https://github.com/a/b"), "https://github.com/a/b/archive/HEAD.tar.gz");
    assert_eq!(archive_url_of("https://github.com/a/b.git/"), "https://github.com/a/b/archive/HEAD.tar.gz");
    assert_eq!(archive_url_of("https://example.org/a/b.tar.gz"), "https://example.org/a/b.tar.gz");
}

#[test]
fn unsafe_oversized_and_bogus_archives_are_refused() {
    assert!(read_archive(&tar_gz(&[("../evil.toml", b"x".to_vec())], None)).is_err());
    assert!(read_archive(b"not a tarball").is_err());
    assert!(read_archive(&tar_gz(&[("themes/big.toml", vec![b'x'; MAX_ENTRY_BYTES + 1])], Some("t"))).is_err());
    let bomb = read_archive(&tar_gz(&[("themes/big.toml", vec![0; MAX_TAR_BYTES + 1])], Some("t"))).unwrap_err();
    assert!(bomb.0.contains("unpacks to too much"), "{bomb}");
}

#[test]
fn the_official_store_tree_reads() {
    let root = std::path::Path::new(env!("CARGO_MANIFEST_DIR")).join("../../store");
    let mut tree = IndexMap::new();
    fn walk(base: &std::path::Path, dir: &std::path::Path, out: &mut IndexMap<String, Vec<u8>>) {
        for e in std::fs::read_dir(dir).unwrap() {
            let p = e.unwrap().path();
            if p.is_dir() {
                walk(base, &p, out);
            } else {
                out.insert(p.strip_prefix(base).unwrap().to_string_lossy().replace('\\', "/"), std::fs::read(&p).unwrap());
            }
        }
    }
    walk(&root, &root, &mut tree);
    let index = Index::from_files(&tree).unwrap();
    assert!(index.themes.iter().any(|t| t.id == "serverbox.piggy"));
    assert!(index.themes.iter().all(|t| t.installable().is_some()), "{:?}", index.themes);
}
