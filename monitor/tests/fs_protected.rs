//! The agent's own state is out of the file API's reach, whatever the roots.
//!
//! With roles (#1610) a `files` grant is no longer everything a login could
//! do, so the files that would undo the roles — `jwt.secret` signs an admin
//! token, the database holds the role table, `config.toml` and the custom
//! commands are code and configuration the agent runs — must not be reachable
//! through it. These run with the whole filesystem as the root, the widest
//! the roots can be.

mod common;

use std::fs;
use std::path::{Path, PathBuf};

use server_box_monitor::core::fs_roots::{FsDenied, FsRoots, Protected};

struct State {
    _dir: tempfile::TempDir,
    /// The agent's working directory: what is protected in it, and an
    /// ordinary file beside them.
    home: PathBuf,
    /// The custom-commands directory.
    cmds: PathBuf,
    roots: FsRoots,
}

fn state() -> State {
    let dir = tempfile::tempdir().unwrap();
    let base = fs::canonicalize(dir.path()).unwrap();
    let home = base.join("agent");
    let cmds = base.join("cmds");
    fs::create_dir(&home).unwrap();
    fs::create_dir(&cmds).unwrap();
    for name in [
        "serverbox_monitor.db",
        "serverbox_monitor.db-wal",
        "jwt.secret",
        "initial-admin-credentials.txt",
        "config.toml",
        "config.toml.bak-1700000000",
        "key.pem",
        "notes.txt",
    ] {
        fs::write(home.join(name), name).unwrap();
    }
    fs::write(cmds.join("10-uptime"), "uptime").unwrap();

    let mut protected = Protected::default();
    for name in [
        "serverbox_monitor.db",
        "jwt.secret",
        "initial-admin-credentials.txt",
        "config.toml",
        "key.pem",
    ] {
        protected.file(&home.join(name));
    }
    protected.tree(&cmds);
    // The root of the filesystem the temporary directory is on. Not the working
    // directory's: on Windows the two can be different drives, and `D:\` holds
    // nothing of `C:\`.
    let whole = base
        .ancestors()
        .last()
        .unwrap()
        .to_path_buf();
    let roots = FsRoots::from_canonical(vec![fs::canonicalize(whole).unwrap()]).protecting(protected);
    State {
        _dir: dir,
        home,
        cmds,
        roots,
    }
}

fn s(path: &Path) -> String {
    path.to_string_lossy().into_owned()
}

#[test]
fn the_state_files_cannot_be_read() {
    let st = state();
    for name in [
        "serverbox_monitor.db",
        "serverbox_monitor.db-wal",
        "jwt.secret",
        "initial-admin-credentials.txt",
        "config.toml",
        "config.toml.bak-1700000000",
        "key.pem",
    ] {
        assert_eq!(
            st.roots.resolve_existing(&s(&st.home.join(name))),
            Err(FsDenied::OutsideRoots),
            "{name}"
        );
    }
    assert_eq!(
        st.roots.resolve_existing(&s(&st.cmds.join("10-uptime"))),
        Err(FsDenied::OutsideRoots)
    );
}

#[test]
fn nor_written_created_or_taken_by_name() {
    let st = state();
    // Overwriting one, a new backup, a new journal file, a new command.
    for path in [
        st.home.join("jwt.secret"),
        st.home.join("config.toml.bak-1800000000"),
        st.home.join("serverbox_monitor.db-journal"),
        st.cmds.join("20-mine"),
        st.cmds.join("sub").join("deeper"),
    ] {
        assert_eq!(st.roots.resolve_new(&s(&path)), Err(FsDenied::OutsideRoots), "{path:?}");
    }
    // Removed or renamed as an entry.
    for name in ["jwt.secret", "config.toml"] {
        assert_eq!(
            st.roots.resolve_entry(&s(&st.home.join(name))),
            Err(FsDenied::OutsideRoots),
            "{name}"
        );
    }
}

#[test]
fn a_symlink_to_one_is_refused_where_it_resolves() {
    #[cfg(unix)]
    {
        let st = state();
        let link = st.home.join("innocent");
        std::os::unix::fs::symlink(st.home.join("jwt.secret"), &link).unwrap();
        assert_eq!(st.roots.resolve_existing(&s(&link)), Err(FsDenied::OutsideRoots));
        // The link itself is an ordinary entry: removing it removes the link.
        assert!(st.roots.resolve_entry(&s(&link)).is_ok());

        let dir_link = st.home.join("cmds-link");
        std::os::unix::fs::symlink(&st.cmds, &dir_link).unwrap();
        assert_eq!(
            st.roots.resolve_existing(&s(&dir_link.join("10-uptime"))),
            Err(FsDenied::OutsideRoots)
        );
    }
}

#[test]
fn the_directory_they_are_in_stays_where_it_is() {
    // Readable and writable as a directory — it can be somebody's home — but
    // not renamed, removed or chmod-ed: the protected paths were worked out
    // at startup, and a moved directory takes its files out from under them.
    let st = state();
    let home = st.roots.resolve_existing(&s(&st.home)).unwrap();
    assert_eq!(st.roots.check_mutable(&home), Err(FsDenied::OutsideRoots));
    let parent = home.parent().unwrap();
    assert_eq!(st.roots.check_mutable(parent), Err(FsDenied::OutsideRoots));
    assert_eq!(st.roots.check_mutable(&st.cmds), Err(FsDenied::OutsideRoots));
}

#[test]
fn ordinary_files_beside_them_still_work() {
    let st = state();
    let notes = st.home.join("notes.txt");
    assert!(st.roots.resolve_existing(&s(&notes)).is_ok());
    assert!(st.roots.resolve_new(&s(&st.home.join("new.txt"))).is_ok());
    let entry = st.roots.resolve_entry(&s(&notes)).unwrap();
    assert!(st.roots.check_mutable(&entry).is_ok());
    // A name that only shares a prefix with a protected one's directory is
    // nobody's state.
    assert!(!st.roots.hides(&st.home.join("config.txt")));
    assert!(st.roots.hides(&st.home.join("config.toml.bak-1")));
    assert!(st.roots.hides(&st.home.join("jwt.secret")));
    assert!(!st.roots.hides(&notes));
}

mod over_http {
    //! The same, through the routes, with the protected paths worked out the
    //! way the agent does it: from its own configuration.

    use std::sync::{Arc, Once};

    use ntex::web::test::{self as web_test, TestServer};
    use ntex::web::App;
    use server_box_monitor::api::auth::generate_token;
    use server_box_monitor::api::server::{AppState, configure_api};
    use server_box_monitor::core::config::{Config, ServerConfig, TlsConfig};

    use super::common;

    const SECRET: &str = "test-secret-that-is-long-enough-32ch";

    fn ensure_crypto_provider() {
        static ONCE: Once = Once::new();
        ONCE.call_once(|| {
            let _ = rustls::crypto::ring::default_provider().install_default();
        });
    }

    async fn server(home: &std::path::Path) -> TestServer {
        ensure_crypto_provider();
        let mut config = Config {
            jwt_secret: Some(SECRET.to_string()),
            // Without Windows' verbatim `\\?\` prefix, which a canonical path
            // has there: in a URL its `?` starts the query, as sqlx reads it.
            database_url: Some(format!(
                "sqlite:{}",
                home.join("serverbox_monitor.db")
                    .to_string_lossy()
                    .trim_start_matches(r"\\?\")
            )),
            server: Some(ServerConfig {
                tls: Some(TlsConfig {
                    cert_path: home.join("cert.pem").to_string_lossy().into_owned(),
                    key_path: home.join("key.pem").to_string_lossy().into_owned(),
                }),
                ..Default::default()
            }),
            ..Default::default()
        };
        let mut remote = config.get_remote_access();
        remote.fs.enabled = Some(true);
        // The root of the filesystem [home] is on — on Windows a drive, and not
        // necessarily the one `/` means to this process.
        let whole = home.ancestors().last().unwrap().to_string_lossy().into_owned();
        remote.fs.roots = vec![whole];
        // Plaintext from the test client, which is loopback anyway.
        remote.allow_insecure = true;
        config.remote_access = Some(remote);
        let state: Arc<AppState> = common::upgraded_state(config).await;
        web_test::server(move || {
            let state = state.clone();
            async move {
                let limit = state.remote_access.exec.max_request_bytes;
                App::new().state(state).configure(configure_api(limit))
            }
        })
        .await
    }

    fn token() -> String {
        generate_token("admin", SECRET).unwrap()
    }

    /// Percent-encodes a path for a query string.
    fn encode(raw: &str) -> String {
        raw.bytes()
            .map(|b| match b {
                b'A'..=b'Z' | b'a'..=b'z' | b'0'..=b'9' | b'-' | b'_' | b'.' | b'~' => {
                    (b as char).to_string()
                }
                _ => format!("%{b:02X}"),
            })
            .collect()
    }

    #[ntex::test]
    async fn an_admin_with_the_whole_filesystem_still_cannot_reach_it() {
        let dir = tempfile::tempdir().unwrap();
        let home = std::fs::canonicalize(dir.path()).unwrap();
        for name in ["serverbox_monitor.db", "jwt.secret", "key.pem", "notes.txt"] {
            std::fs::write(home.join(name), name).unwrap();
        }
        let srv = server(&home).await;
        let auth = format!("Bearer {}", token());

        for name in ["serverbox_monitor.db", "jwt.secret", "key.pem"] {
            let path = home.join(name).to_string_lossy().into_owned();
            let status = srv
                .get(format!("/api/v1/fs/read?path={}", encode(&path)))
                .header("Authorization", &auth)
                .send()
                .await
                .unwrap()
                .status();
            assert_eq!(status.as_u16(), 403, "{name}");
        }

        // Listed without them.
        let path = home.to_string_lossy().into_owned();
        let resp = srv
            .get(format!("/api/v1/fs/list?path={}", encode(&path)))
            .header("Authorization", &auth)
            .send()
            .await
            .unwrap();
        assert!(resp.status().is_success());
        let names: Vec<String> = resp
            .json::<Vec<serde_json::Value>>()
            .await
            .unwrap()
            .iter()
            .map(|e| e["name"].as_str().unwrap().to_string())
            .collect();
        assert_eq!(names, ["notes.txt"]);

        // A file is not listed as a folder: a request mistake, not a fault.
        let file = home.join("notes.txt").to_string_lossy().into_owned();
        let resp = srv
            .get(format!("/api/v1/fs/list?path={}", encode(&file)))
            .header("Authorization", &auth)
            .send()
            .await
            .unwrap();
        assert_eq!(resp.status().as_u16(), 400);
        let mut resp = resp;
        let body: serde_json::Value = resp.json().await.unwrap();
        assert_eq!(body["error"], "not_a_directory");

        // The directory they are in is not moved, removed or opened up.
        let status = srv
            .post("/api/v1/fs/rename")
            .header("Authorization", &auth)
            .send_json(&serde_json::json!({
                "from": path,
                "to": format!("{path}-moved"),
            }))
            .await
            .unwrap()
            .status();
        assert_eq!(status.as_u16(), 403);
        let status = srv
            .post("/api/v1/fs/chmod")
            .header("Authorization", &auth)
            .send_json(&serde_json::json!({ "path": path, "mode": 0o777 }))
            .await
            .unwrap()
            .status();
        assert_eq!(status.as_u16(), 403);
    }
}
