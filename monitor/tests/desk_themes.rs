//! `/api/v1/desk/themes*`: theme packages an account installs, whose they
//! are, what selecting and replacing one does to the desk, and the store —
//! read through a fetcher answering from memory, which also shows what the
//! agent asks the internet for.

mod common;

use std::collections::HashMap;
use std::future::Future;
use std::io::{Cursor, Write};
use std::path::Path;
use std::pin::Pin;
use std::sync::{Arc, Mutex};

use ntex::http::Method;
use ntex::web::test::{self as web_test, TestServer};
use ntex::web::{self, App};
use serde_json::{Value, json};
use server_box_monitor::api::auth::generate_token;
use server_box_monitor::api::desk::{self};
use server_box_monitor::api::desk_themes::{self, Fetch};
use server_box_monitor::api::server::AppState;
use server_box_monitor::core::config::Config;

const SECRET: &str = "test-secret-that-is-long-enough-32ch";

fn repo_root() -> &'static Path {
    Path::new(concat!(env!("CARGO_MANIFEST_DIR"), "/.."))
}

fn piggy() -> Vec<u8> {
    std::fs::read(repo_root().join("assets/store_themes/serverbox.piggy.fsbt")).unwrap()
}

/// A source folder zipped; [salt] changes the bytes and not the theme.
fn zip_dir(dir: &Path, salt: &str) -> Vec<u8> {
    fn walk(base: &Path, dir: &Path, out: &mut Vec<(String, Vec<u8>)>) {
        let mut entries: Vec<_> = std::fs::read_dir(dir).unwrap().map(|e| e.unwrap().path()).collect();
        entries.sort();
        for path in entries {
            if path.is_dir() {
                walk(base, &path, out);
            } else {
                let name = path.strip_prefix(base).unwrap().to_string_lossy().replace('\\', "/");
                out.push((name, std::fs::read(&path).unwrap()));
            }
        }
    }
    let mut files = Vec::new();
    walk(dir, dir, &mut files);
    let mut zip = zip::ZipWriter::new(Cursor::new(Vec::new()));
    zip.set_comment(salt).unwrap();
    for (name, bytes) in files {
        zip.start_file(name, zip::write::SimpleFileOptions::default()).unwrap();
        zip.write_all(&bytes).unwrap();
    }
    zip.finish().unwrap().into_inner()
}

fn pride(salt: &str) -> Vec<u8> {
    zip_dir(&repo_root().join("store/themes/serverbox.pride"), salt)
}

async fn state() -> Arc<AppState> {
    let _ = rustls::crypto::ring::default_provider().install_default();
    let db = common::database().await;
    let config = Config { jwt_secret: Some(SECRET.to_string()), ..Default::default() };
    common::seed_as_upgrade(&db, &config).await;
    AppState::new(Arc::new(config), db)
}

async fn server(state: Arc<AppState>) -> TestServer {
    web_test::server(move || {
        let state = state.clone();
        async move {
            App::new().state(state).service(
                web::scope("/api/v1")
                    .route("/desk", web::get().to(desk::get))
                    .route("/desk/preferences", web::put().to(desk::put_preferences))
                    .service(
                        web::resource("/desk/themes")
                            .route(web::get().to(desk_themes::list))
                            .route(web::post().to(desk_themes::upload)),
                    )
                    .route("/desk/themes/store", web::get().to(desk_themes::store))
                    .route("/desk/themes/store/install", web::post().to(desk_themes::store_install))
                    .route("/desk/themes/{installation}", web::delete().to(desk_themes::remove))
                    .route("/desk/themes/{installation}/background", web::get().to(desk_themes::background)),
            )
        }
    })
    .await
}

async fn call(srv: &TestServer, user: &str, method: Method, path: &str, body: Option<Vec<u8>>) -> (u16, Value, Vec<u8>) {
    let req = srv
        .request(method, srv.url(path))
        .timeout(std::time::Duration::from_secs(30))
        .header("Authorization", format!("Bearer {}", generate_token(user, SECRET).unwrap()));
    let json = body.as_ref().is_some_and(|b| b.first() == Some(&b'{'));
    let req = if json { req.header("content-type", "application/json") } else { req };
    let resp = match body {
        Some(body) => req.send_body(body).await.unwrap(),
        None => req.send().await.unwrap(),
    };
    let status = resp.status().as_u16();
    let bytes = resp.body().limit(32 << 20).await.unwrap_or_default().to_vec();
    (status, serde_json::from_slice(&bytes).unwrap_or(Value::Null), bytes)
}

fn prefs(theme: Option<&str>, wallpaper: &str) -> Option<Vec<u8>> {
    Some(
        json!({
            "wallpaper": wallpaper,
            "wallpaper_fit": "cover",
            "dock": ["files"],
            "icons": [],
            "theme": theme,
        })
        .to_string()
        .into_bytes(),
    )
}

#[ntex::test]
async fn a_package_installs_lists_and_serves_its_background_to_its_owner_only() {
    let srv = server(state().await).await;
    let (status, installed, _) = call(&srv, "admin", Method::POST, "/api/v1/desk/themes", Some(piggy())).await;
    assert_eq!(status, 200, "{installed}");
    let id = installed["installationId"].as_str().unwrap().to_string();
    assert_eq!(installed["id"], "serverbox.piggy");
    let theme = &installed["package"]["themes"][0];
    assert_eq!(theme["background"]["style"], "image");
    assert!(theme["schemeLight"]["primary"].is_u64());

    let (_, list, _) = call(&srv, "admin", Method::GET, "/api/v1/desk/themes", None).await;
    assert_eq!(list.as_array().unwrap().len(), 1);
    let (status, _, bytes) = call(&srv, "admin", Method::GET, &format!("/api/v1/desk/themes/{id}/background"), None).await;
    assert_eq!(status, 200);
    assert!(bytes.starts_with(b"\x89PNG"));

    // Another account sees nothing of it.
    let (_, list, _) = call(&srv, "intruder", Method::GET, "/api/v1/desk/themes", None).await;
    assert_eq!(list, json!([]));
    let (status, _, _) = call(&srv, "intruder", Method::GET, &format!("/api/v1/desk/themes/{id}/background"), None).await;
    assert_eq!(status, 404);
    let (status, _, _) = call(&srv, "intruder", Method::PUT, "/api/v1/desk/preferences", prefs(Some(&id), "theme")).await;
    assert_eq!(status, 400);
    let (status, _, _) = call(&srv, "intruder", Method::DELETE, &format!("/api/v1/desk/themes/{id}"), None).await;
    assert_eq!(status, 404);
}

#[ntex::test]
async fn a_package_the_app_would_refuse_is_refused_with_its_reason() {
    let srv = server(state().await).await;
    let (status, body, _) = call(&srv, "admin", Method::POST, "/api/v1/desk/themes", Some(b"not a zip".to_vec())).await;
    assert_eq!(status, 400);
    assert_eq!(body, json!({ "error": "invalidTheme", "reason": "Invalid theme ZIP" }));
}

#[ntex::test]
async fn selecting_replacing_and_removing_a_theme() {
    let srv = server(state().await).await;
    let (_, first, _) = call(&srv, "admin", Method::POST, "/api/v1/desk/themes", Some(pride("one"))).await;
    let first = first["installationId"].as_str().unwrap().to_string();

    // Only an installed theme and variant, and the theme wallpaper only with
    // a theme.
    let unknown = "a".repeat(64);
    for (theme, wallpaper) in [
        (Some(unknown.as_str()), "preset:dusk"),
        (Some(&*format!("{first}#nope")), "preset:dusk"),
        (None, "theme"),
        (Some("not-a-digest"), "preset:dusk"),
    ] {
        let (status, body, _) = call(&srv, "admin", Method::PUT, "/api/v1/desk/preferences", prefs(theme, wallpaper)).await;
        assert_eq!(status, 400, "{theme:?} {wallpaper}: {body}");
    }
    let selected = format!("{first}#rainbow");
    let (status, body, _) = call(&srv, "admin", Method::PUT, "/api/v1/desk/preferences", prefs(Some(&selected), "theme")).await;
    assert_eq!(status, 200, "{body}");

    // Another build of the same theme replaces it, and the desk follows, its
    // variant kept.
    let (_, second, _) = call(&srv, "admin", Method::POST, "/api/v1/desk/themes", Some(pride("two"))).await;
    let second = second["installationId"].as_str().unwrap().to_string();
    assert_ne!(first, second);
    let (_, list, _) = call(&srv, "admin", Method::GET, "/api/v1/desk/themes", None).await;
    assert_eq!(list.as_array().unwrap().len(), 1);
    assert_eq!(list[0]["installationId"], second);
    let (_, desk_view, _) = call(&srv, "admin", Method::GET, "/api/v1/desk", None).await;
    assert_eq!(desk_view["preferences"]["theme"], format!("{second}#rainbow"));
    let (status, _, bytes) =
        call(&srv, "admin", Method::GET, &format!("/api/v1/desk/themes/{second}/background?variant=rainbow"), None).await;
    assert_eq!(status, 200);
    assert!(bytes.starts_with(b"\x89PNG"));

    // Removed, the desk goes back to the panel's own.
    let (status, _, _) = call(&srv, "admin", Method::DELETE, &format!("/api/v1/desk/themes/{second}"), None).await;
    assert_eq!(status, 204);
    let (_, desk_view, _) = call(&srv, "admin", Method::GET, "/api/v1/desk", None).await;
    assert_eq!(desk_view["preferences"]["theme"], Value::Null);
    assert_eq!(desk_view["preferences"]["wallpaper"], desk::DEFAULT_WALLPAPER);
}

/// Answers from memory, and remembers what it was asked for.
struct Memory {
    files: HashMap<String, Vec<u8>>,
    asked: Mutex<Vec<String>>,
}

impl Fetch for Memory {
    fn get<'a>(&'a self, url: &'a str, max: usize) -> Pin<Box<dyn Future<Output = Result<Vec<u8>, String>> + Send + 'a>> {
        self.asked.lock().unwrap().push(url.to_string());
        let answer = match self.files.get(url) {
            Some(b) if b.len() <= max => Ok(b.clone()),
            Some(_) => Err("Download exceeds size limit".into()),
            None => Err("HTTP 404".into()),
        };
        Box::pin(async move { answer })
    }
}

fn tar_gz(entries: &[(&str, &[u8])]) -> Vec<u8> {
    let mut builder = tar::Builder::new(Vec::new());
    for (name, bytes) in entries {
        let mut header = tar::Header::new_gnu();
        header.set_size(bytes.len() as u64);
        header.set_mode(0o644);
        header.set_cksum();
        builder.append_data(&mut header, format!("store/{name}"), *bytes).unwrap();
    }
    let mut gz = flate2::write::GzEncoder::new(Vec::new(), flate2::Compression::fast());
    gz.write_all(&builder.into_inner().unwrap()).unwrap();
    gz.finish().unwrap()
}

#[ntex::test]
async fn the_store_installs_only_what_its_catalog_offers_and_checks_the_digest() {
    let state = state().await;
    let piggy = piggy();
    let listing = std::fs::read_to_string(repo_root().join("store/themes/serverbox.piggy.toml")).unwrap();
    let broken = "id = \"serverbox.broken\"\nname = \"Broken\"\n[[version]]\nversion = \"1.0.0\"\nschema_min = 3\nschema_max = 3\nurl = \"https://example.org/broken.fsbt\"\nsha256 = \"".to_string()
        + &"0".repeat(64)
        + "\"\n";
    let release_url = "https://github.com/lollipopkit/flutter_server_box/releases/download/themes/serverbox.piggy-1.0.0.fsbt";
    let memory = Arc::new(Memory {
        files: HashMap::from([
            (
                "https://catalog.example/repos.toml".to_string(),
                b"schema = 1\nname = \"Test catalog\"\n[[repo]]\nurl = \"https://example.org/store.tar.gz\"\n".to_vec(),
            ),
            (
                "https://example.org/store.tar.gz".to_string(),
                tar_gz(&[
                    ("repo.toml", b"schema = 1\nname = \"Official\"\n"),
                    ("themes/serverbox.piggy.toml", listing.as_bytes()),
                    ("themes/serverbox.broken.toml", broken.as_bytes()),
                ]),
            ),
            (release_url.to_string(), piggy.clone()),
            ("https://example.org/broken.fsbt".to_string(), piggy.clone()),
        ]),
        asked: Mutex::new(Vec::new()),
    });
    state.themes.set_source("https://catalog.example/repos.toml", memory.clone());
    let srv = server(state).await;

    let (status, store, _) = call(&srv, "admin", Method::GET, "/api/v1/desk/themes/store", None).await;
    assert_eq!(status, 200);
    assert_eq!(store["catalog"], "Test catalog");
    assert_eq!(store["repos"], json!(["Official"]));
    let item = store["items"].as_array().unwrap().iter().find(|i| i["listing"]["id"] == "serverbox.piggy").unwrap();
    assert_eq!(item["release"]["version"], "1.0.0");
    assert_eq!(item["repoUrl"], "https://example.org/store.tar.gz");

    let install = |repo: &str, id: &str| {
        Some(json!({ "repo": repo, "id": id, "version": "1.0.0" }).to_string().into_bytes())
    };
    let (status, body, _) = call(
        &srv,
        "admin",
        Method::POST,
        "/api/v1/desk/themes/store/install",
        install("https://example.org/store.tar.gz", "serverbox.piggy"),
    )
    .await;
    assert_eq!(status, 200, "{body}");
    assert_eq!(body["id"], "serverbox.piggy");

    // A digest that does not match, a repository the catalog does not list,
    // a theme nobody offers: refused, and nothing fetched beyond the catalog's.
    for (repo, id, reason) in [
        ("https://example.org/store.tar.gz", "serverbox.broken", "Theme checksum mismatch"),
        ("https://evil.example/store.tar.gz", "serverbox.piggy", "the store does not offer that theme"),
        ("https://example.org/store.tar.gz", "serverbox.nope", "the store does not offer that theme"),
    ] {
        let (status, body, _) =
            call(&srv, "admin", Method::POST, "/api/v1/desk/themes/store/install", install(repo, id)).await;
        assert_eq!(status, 502, "{repo} {id}");
        assert_eq!(body["reason"], reason);
    }
    let asked = memory.asked.lock().unwrap().clone();
    assert!(asked.iter().all(|u| !u.contains("evil")), "{asked:?}");
    assert_eq!(asked.iter().filter(|u| u.ends_with("repos.toml")).count(), 1, "kept, not read again: {asked:?}");
}
