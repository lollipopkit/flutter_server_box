//! Accounts, roles, and what each role reaches (issue #1610), against the real
//! route table — `configure_api`, which is what the shipped binary mounts.

mod common;

use std::sync::{Arc, Once};

use ntex::http::Method;
use ntex::web::App;
use ntex::web::test::{self as web_test, TestServer};
use rustls::crypto::ring;
use serde_json::{Value, json};
use server_box_monitor::api::auth::generate_token;
use server_box_monitor::api::server::{AppState, configure_api};
use server_box_monitor::core::config::Config;
use server_box_monitor::core::permissions::{
    ConnectGrant, FilesGrant, FilesMode, Grants, ListenGrant, Role,
};

const SECRET: &str = "test-secret-that-is-long-enough-32ch";

fn ensure_crypto_provider() {
    static ONCE: Once = Once::new();
    ONCE.call_once(|| {
        let _ = ring::default_provider().install_default();
    });
}

/// Out of the crate's directory before any server starts, as
/// `watch_token_scope.rs` explains: nothing here should touch the
/// developer's own `config.toml`, and with no file in this directory the
/// config-editing routes fail reading it rather than writing it.
fn leave_the_crate() {
    static ONCE: Once = Once::new();
    ONCE.call_once(|| {
        let dir = std::env::temp_dir().join(format!(
            "sbm-permissions-api-{}",
            std::process::id()
        ));
        std::fs::create_dir_all(&dir).unwrap();
        std::env::set_current_dir(&dir).unwrap();
    });
}

/// An agent whose file API serves [root], with `admin` and `intruder` as
/// admins holding everything, plus a `viewer` account, a `desktop` role
/// (`connect` to one address) held by `ops`, and a `reader` role (`files`
/// read-only) held by `clerk`.
async fn state(root: &str) -> Arc<AppState> {
    leave_the_crate();
    ensure_crypto_provider();
    let mut config = Config {
        jwt_secret: Some(SECRET.to_string()),
        ..Default::default()
    };
    let mut remote = config.get_remote_access();
    remote.fs.roots = vec![root.to_string()];
    config.remote_access = Some(remote);

    let db = common::database().await;
    for name in common::ACCOUNTS {
        common::add_account(&db, name, "admin").await;
    }
    // A fresh install's grants for the admin role: everything.
    server_box_monitor::db::bootstrap::ensure_roles(
        &db,
        &Config::default(),
        server_box_monitor::core::permissions::InitPermissions::Full,
    )
    .await
    .unwrap();
    common::set_grants(&db, "admin", &Grants::all()).await;
    common::add_account(&db, "viewer", "viewer").await;
    common::add_role(
        &db,
        &Role {
            name: "desktop".into(),
            admin: false,
            builtin: false,
            grants: Grants {
                connect: Some(ConnectGrant {
                    allow: vec!["127.0.0.1:3389".into()],
                }),
                ..Grants::none()
            },
        },
    )
    .await;
    common::add_account(&db, "ops", "desktop").await;
    common::add_role(
        &db,
        &Role {
            name: "reader".into(),
            admin: false,
            builtin: false,
            grants: Grants {
                files: Some(FilesGrant {
                    mode: FilesMode::Read,
                }),
                ..Grants::none()
            },
        },
    )
    .await;
    common::add_account(&db, "clerk", "reader").await;
    AppState::new(Arc::new(config), db)
}

async fn server(state: Arc<AppState>) -> TestServer {
    web_test::server(move || {
        let state = state.clone();
        async move {
            let limit = state.remote_access.exec.max_request_bytes;
            App::new().state(state).configure(configure_api(limit))
        }
    })
    .await
}

fn jwt(user: &str) -> String {
    generate_token(user, SECRET).unwrap()
}

/// One request as [user], and its status and body (`null` for none).
async fn call(
    srv: &TestServer,
    user: &str,
    method: Method,
    path: &str,
    body: Option<Value>,
) -> (u16, Value) {
    // Generous: a password change is two bcrypt rounds at the real cost, and a
    // debug build on a shared Windows runner took longer than the default.
    let req = srv
        .request(method, srv.url(path))
        .timeout(std::time::Duration::from_secs(30))
        .header("Authorization", format!("Bearer {}", jwt(user)));
    let resp = match body {
        Some(body) => req.send_json(&body).await.unwrap(),
        None => req.send().await.unwrap(),
    };
    let status = resp.status().as_u16();
    let bytes = resp.body().await.unwrap_or_default();
    let body = serde_json::from_slice(&bytes).unwrap_or(Value::Null);
    (status, body)
}

fn temp_root() -> tempfile::TempDir {
    let dir = tempfile::tempdir().unwrap();
    std::fs::write(dir.path().join("note.txt"), "hello").unwrap();
    dir
}

#[ntex::test]
async fn each_role_reaches_what_it_holds_and_nothing_else() {
    let root = temp_root();
    let srv = server(state(root.path().to_str().unwrap()).await).await;
    let list = format!("/api/v1/fs/list?path={}", root.path().display());
    let ticket = |purpose: &str| Some(json!({ "purpose": purpose }));

    // (account, method, path, body, reaches)
    let cases: Vec<(&str, Method, String, Option<Value>, bool)> = vec![
        // Reading the numbers: everyone.
        ("viewer", Method::GET, "/api/v1/metrics/history".into(), None, true),
        ("ops", Method::GET, "/api/v1/capabilities".into(), None, true),
        // The agent's configuration: admins only.
        ("viewer", Method::GET, "/api/v1/settings".into(), None, false),
        ("ops", Method::GET, "/api/v1/push".into(), None, false),
        ("viewer", Method::PUT, "/api/v1/card-order".into(), Some(json!({ "card_order": [] })), false),
        ("viewer", Method::GET, "/api/v1/users".into(), None, false),
        ("admin", Method::GET, "/api/v1/users".into(), None, true),
        // `shell`.
        ("admin", Method::POST, "/api/v1/exec".into(), Some(json!({ "cmd": "true" })), true),
        ("ops", Method::POST, "/api/v1/exec".into(), Some(json!({ "cmd": "true" })), false),
        ("viewer", Method::POST, "/api/v1/ws-ticket".into(), ticket("terminal"), false),
        ("admin", Method::POST, "/api/v1/ws-ticket".into(), ticket("terminal"), true),
        // `connect` and `listen`.
        ("ops", Method::POST, "/api/v1/ws-ticket".into(), ticket("stream"), true),
        ("ops", Method::POST, "/api/v1/ws-ticket".into(), ticket("listen"), false),
        ("ops", Method::POST, "/api/v1/ws-ticket".into(), ticket("terminal"), false),
        ("clerk", Method::POST, "/api/v1/ws-ticket".into(), ticket("stream"), false),
        // `files`, read and write.
        ("clerk", Method::GET, list.clone(), None, true),
        ("viewer", Method::GET, list.clone(), None, false),
        ("ops", Method::GET, list, None, false),
    ];
    for (user, method, path, body, reaches) in cases {
        let (status, body) = call(&srv, user, method.clone(), &path, body).await;
        let refused = status == 401 || status == 403;
        assert_eq!(
            !refused, reaches,
            "{user} {method} {path} answered {status} {body}"
        );
    }
}

#[ntex::test]
async fn read_only_files_refuse_every_write() {
    let root = temp_root();
    let base = root.path().display().to_string();
    let srv = server(state(&base).await).await;

    let (status, _) = call(
        &srv,
        "clerk",
        Method::GET,
        &format!("/api/v1/fs/read?path={base}/note.txt"),
        None,
    )
    .await;
    assert_eq!(status, 200);

    for (method, path, body) in [
        (Method::POST, "/api/v1/fs/mkdir", json!({ "path": format!("{base}/d") })),
        (Method::POST, "/api/v1/fs/chmod", json!({ "path": format!("{base}/note.txt"), "mode": 420 })),
        (
            Method::POST,
            "/api/v1/fs/rename",
            json!({ "from": format!("{base}/note.txt"), "to": format!("{base}/n2.txt") }),
        ),
        (Method::DELETE, "/api/v1/fs/remove", json!({ "path": format!("{base}/note.txt") })),
    ] {
        let (status, _) = call(&srv, "clerk", method.clone(), path, Some(body)).await;
        assert_eq!(status, 403, "{method} {path} for a read-only role");
    }
    // The admin, with write, may.
    let (status, _) = call(
        &srv,
        "admin",
        Method::POST,
        "/api/v1/fs/mkdir",
        Some(json!({ "path": format!("{base}/d") })),
    )
    .await;
    assert!(status < 300, "admin mkdir answered {status}");
    assert!(root.path().join("note.txt").exists());
}

#[ntex::test]
async fn capabilities_answer_for_the_caller() {
    let root = temp_root();
    let srv = server(state(root.path().to_str().unwrap()).await).await;

    let (_, caps) = call(&srv, "ops", Method::GET, "/api/v1/capabilities", None).await;
    assert_eq!(caps["me"], json!({ "username": "ops", "role": "desktop", "admin": false }));
    assert_eq!(caps["grants"]["connect"]["ok"], true);
    assert_eq!(caps["grants"]["connect"]["allow"], json!(["127.0.0.1:3389"]));
    assert_eq!(caps["grants"]["shell"], json!({ "ok": false, "why": "not_granted" }));
    // The answer older apps read, derived.
    assert_eq!(caps["remote_access"]["stream"], true);
    assert_eq!(caps["remote_access"]["full_access"], false);
    assert_eq!(caps["remote_access"]["listen"], false);

    let (_, caps) = call(&srv, "clerk", Method::GET, "/api/v1/capabilities", None).await;
    assert_eq!(caps["grants"]["files"], json!({ "ok": true, "mode": "read" }));

    let (_, caps) = call(&srv, "admin", Method::GET, "/api/v1/capabilities", None).await;
    assert_eq!(caps["me"]["admin"], true);
    assert_eq!(
        caps["grants"]["listen"],
        json!({ "ok": true, "public": false, "ports": null })
    );
    assert_eq!(caps["remote_access"]["terminal"], true);
}

#[ntex::test]
async fn files_without_roots_are_not_configured() {
    leave_the_crate();
    ensure_crypto_provider();
    let config = Config {
        jwt_secret: Some(SECRET.to_string()),
        ..Default::default()
    };
    let db = common::database().await;
    common::add_account(&db, "admin", "admin").await;
    server_box_monitor::db::bootstrap::ensure_roles(
        &db,
        &config,
        server_box_monitor::core::permissions::InitPermissions::Full,
    )
    .await
    .unwrap();
    common::set_grants(&db, "admin", &Grants::all()).await;
    let srv = server(AppState::new(Arc::new(config), db)).await;

    let (_, caps) = call(&srv, "admin", Method::GET, "/api/v1/capabilities", None).await;
    assert_eq!(caps["grants"]["files"]["why"], "not_configured");
}

#[ntex::test]
async fn an_account_that_no_longer_exists_is_signed_out() {
    let root = temp_root();
    let srv = server(state(root.path().to_str().unwrap()).await).await;
    let (status, _) = call(&srv, "nobody", Method::GET, "/api/v1/metrics/history", None).await;
    assert_eq!(status, 401, "a token for a deleted account must not keep reading");
}

#[ntex::test]
async fn admins_manage_accounts_and_roles_with_their_password() {
    let root = temp_root();
    let srv = server(state(root.path().to_str().unwrap()).await).await;
    let pw = common::PASSWORD;

    // A role, refused without the admin's own password, and with a wrong one.
    let role = json!({ "name": "kiosk", "grants": { "connect": { "allow": ["10.0.0.0/8:5900-5910"] } } });
    let (status, body) = call(&srv, "admin", Method::POST, "/api/v1/roles", Some(json!({ "role": role }))).await;
    assert_eq!((status, body["error"].as_str()), (403, Some("reauth")));
    let (status, _) = call(
        &srv,
        "admin",
        Method::POST,
        "/api/v1/roles",
        Some(json!({ "role": role, "current_password": "wrong-one" })),
    )
    .await;
    assert_eq!(status, 403);
    let (status, body) = call(
        &srv,
        "admin",
        Method::POST,
        "/api/v1/roles",
        Some(json!({ "role": role, "current_password": pw })),
    )
    .await;
    assert_eq!(status, 201, "{body}");
    assert_eq!(body["builtin"], false);
    let (status, body) = call(
        &srv,
        "admin",
        Method::POST,
        "/api/v1/roles",
        Some(json!({ "role": role, "current_password": pw })),
    )
    .await;
    assert_eq!((status, body["error"].as_str()), (409, Some("conflict")));

    // What cannot be stored is refused before anything is.
    for bad in [
        json!({ "name": "Kiosk", "grants": {} }),
        json!({ "name": "boss", "admin": true, "grants": {} }),
        json!({ "name": "net", "grants": { "connect": { "allow": ["intranet.lan"] } } }),
        json!({ "name": "net", "grants": { "listen": { "ports": [10, 9] } } }),
        // A misspelt grant is refused rather than quietly left off.
        json!({ "name": "net", "grants": { "shel": true } }),
    ] {
        let (status, body) = call(
            &srv,
            "admin",
            Method::POST,
            "/api/v1/roles",
            Some(json!({ "role": bad, "current_password": pw })),
        )
        .await;
        assert_eq!((status, body["error"].as_str()), (400, Some("bad_request")), "{bad}");
    }

    // An account in it, which can sign in and see itself and nothing else.
    let (status, body) = call(
        &srv,
        "admin",
        Method::POST,
        "/api/v1/users",
        Some(json!({ "username": "kim", "password": "kim-password", "role": "kiosk", "current_password": pw })),
    )
    .await;
    assert_eq!(status, 201, "{body}");
    assert_eq!(body["role"], "kiosk");
    let resp = srv
        .post("/api/v1/login")
        .timeout(std::time::Duration::from_secs(30))
        .send_json(&json!({ "username": "kim", "password": "kim-password" }))
        .await
        .unwrap();
    assert_eq!(resp.status().as_u16(), 200);
    let (_, me) = call(&srv, "kim", Method::GET, "/api/v1/me", None).await;
    assert_eq!(me["role"]["name"], "kiosk");
    assert_eq!(me["role"]["grants"]["connect"]["allow"], json!(["10.0.0.0/8:5900-5910"]));
    let (status, body) = call(&srv, "kim", Method::GET, "/api/v1/roles", None).await;
    assert_eq!((status, body["error"].as_str()), (403, Some("forbidden")));

    // Its own password it may change, and only with the old one.
    let (status, _) = call(
        &srv,
        "kim",
        Method::PUT,
        "/api/v1/me/password",
        Some(json!({ "current_password": "nope", "new_password": "kim-password-2" })),
    )
    .await;
    assert_eq!(status, 403);
    let (status, _) = call(
        &srv,
        "kim",
        Method::PUT,
        "/api/v1/me/password",
        Some(json!({ "current_password": "kim-password", "new_password": "kim-password-2" })),
    )
    .await;
    assert_eq!(status, 204);

    // A role in use cannot go; moved off it, it can. A built-in never can.
    let (status, _) = call(
        &srv,
        "admin",
        Method::DELETE,
        "/api/v1/roles/kiosk",
        Some(json!({ "current_password": pw })),
    )
    .await;
    assert_eq!(status, 409);
    let (status, body) = call(
        &srv,
        "admin",
        Method::PUT,
        "/api/v1/users/kim",
        Some(json!({ "role": "viewer", "current_password": pw })),
    )
    .await;
    assert_eq!((status, body["role"].as_str()), (200, Some("viewer")));
    let (status, _) = call(
        &srv,
        "admin",
        Method::DELETE,
        "/api/v1/roles/kiosk",
        Some(json!({ "current_password": pw })),
    )
    .await;
    assert_eq!(status, 204);
    let (status, body) = call(
        &srv,
        "admin",
        Method::DELETE,
        "/api/v1/roles/viewer",
        Some(json!({ "current_password": pw })),
    )
    .await;
    assert_eq!((status, body["error"].as_str()), (403, Some("forbidden")));

    // A role keeps its name, and whether it administers.
    let (status, _) = call(
        &srv,
        "admin",
        Method::PUT,
        "/api/v1/roles/viewer",
        Some(json!({ "role": { "name": "viewers", "grants": {} }, "current_password": pw })),
    )
    .await;
    assert_eq!(status, 400);
    let (status, _) = call(
        &srv,
        "admin",
        Method::PUT,
        "/api/v1/roles/admin",
        Some(json!({ "role": { "name": "admin", "admin": false, "grants": {} }, "current_password": pw })),
    )
    .await;
    assert_eq!(status, 400);
    // The built-in viewer's grants are the admin's to set.
    let (status, body) = call(
        &srv,
        "admin",
        Method::PUT,
        "/api/v1/roles/viewer",
        Some(json!({ "role": { "name": "viewer", "grants": { "files": { "mode": "read" } } }, "current_password": pw })),
    )
    .await;
    assert_eq!(status, 200, "{body}");
    assert_eq!(body["grants"]["files"]["mode"], "read");

    // Deleting an account takes its watch tokens with it.
    let (status, _) = call(
        &srv,
        "kim",
        Method::POST,
        "/api/v1/watch-token",
        Some(json!({ "client_id": "widget:kim" })),
    )
    .await;
    assert_eq!(status, 200);
    let (status, _) = call(
        &srv,
        "admin",
        Method::DELETE,
        "/api/v1/users/kim",
        Some(json!({ "current_password": pw })),
    )
    .await;
    assert_eq!(status, 204);
    let (_, users) = call(&srv, "admin", Method::GET, "/api/v1/users", None).await;
    assert!(users.as_array().unwrap().iter().all(|u| u["username"] != "kim"));
}

/// A client older than `virt` saves a role without it. That must not be read
/// as taking it away; only a client that sends `virt` changes it.
#[ntex::test]
async fn saving_a_role_without_virt_keeps_what_it_had() {
    let root = temp_root();
    let srv = server(state(root.path().to_str().unwrap()).await).await;
    let pw = common::PASSWORD;
    let put = |grants: Value| {
        Some(json!({ "role": { "name": "viewer", "grants": grants }, "current_password": pw }))
    };

    let (status, body) = call(&srv, "admin", Method::PUT, "/api/v1/roles/viewer", put(json!({ "virt": true }))).await;
    assert_eq!((status, &body["grants"]["virt"]), (200, &json!(true)), "{body}");

    // What an app from before `virt` sends: every grant it knows, written out.
    let old_client = json!({ "shell": false, "ssh_terminal": false, "files": { "mode": "read" }, "connect": null, "listen": null });
    let (status, body) = call(&srv, "admin", Method::PUT, "/api/v1/roles/viewer", put(old_client)).await;
    assert_eq!(status, 200, "{body}");
    assert_eq!(body["grants"]["virt"], true);
    assert_eq!(body["grants"]["files"]["mode"], "read");

    let (status, body) = call(&srv, "admin", Method::PUT, "/api/v1/roles/viewer", put(json!({ "virt": false }))).await;
    assert_eq!((status, &body["grants"]["virt"]), (200, &json!(false)), "{body}");
}

#[ntex::test]
async fn there_is_always_an_admin() {
    let root = temp_root();
    let srv = server(state(root.path().to_str().unwrap()).await).await;
    let pw = common::PASSWORD;

    // Two admins: one may go.
    let (status, _) = call(
        &srv,
        "admin",
        Method::DELETE,
        "/api/v1/users/intruder",
        Some(json!({ "current_password": pw })),
    )
    .await;
    assert_eq!(status, 204);

    // The last may neither go nor become something else — not even by its
    // own hand.
    let (status, body) = call(
        &srv,
        "admin",
        Method::DELETE,
        "/api/v1/users/admin",
        Some(json!({ "current_password": pw })),
    )
    .await;
    assert_eq!((status, body["error"].as_str()), (409, Some("last_admin")));
    let (status, body) = call(
        &srv,
        "admin",
        Method::PUT,
        "/api/v1/users/admin",
        Some(json!({ "role": "viewer", "current_password": pw })),
    )
    .await;
    assert_eq!((status, body["error"].as_str()), (409, Some("last_admin")));
}

#[ntex::test]
async fn the_panels_legacy_switch_takes_shell_connect_and_listen_from_every_role() {
    let root = temp_root();
    let srv = server(state(root.path().to_str().unwrap()).await).await;

    let (status, _) = call(&srv, "viewer", Method::DELETE, "/api/v1/remote-access/full-access", None).await;
    assert_eq!(status, 403, "only an admin may");
    let (status, _) = call(&srv, "admin", Method::DELETE, "/api/v1/remote-access/full-access", None).await;
    assert_eq!(status, 200);

    let (_, roles) = call(&srv, "admin", Method::GET, "/api/v1/roles", None).await;
    for role in roles.as_array().unwrap() {
        assert_eq!(role["grants"]["shell"], false, "{role}");
        assert_eq!(role["grants"]["connect"], Value::Null, "{role}");
        assert_eq!(role["grants"]["listen"], Value::Null, "{role}");
    }
    // What it does not cover stays.
    let admin = roles.as_array().unwrap().iter().find(|r| r["name"] == "admin").unwrap();
    assert_eq!(admin["grants"]["ssh_terminal"], true);
    assert_eq!(admin["grants"]["files"]["mode"], "write");
    // And the effect is immediate.
    let (status, _) = call(&srv, "admin", Method::POST, "/api/v1/exec", Some(json!({ "cmd": "true" }))).await;
    assert_eq!(status, 403);
}

#[ntex::test]
async fn a_watch_token_cannot_reach_the_account_api() {
    let root = temp_root();
    let srv = server(state(root.path().to_str().unwrap()).await).await;
    let (_, body) = call(
        &srv,
        "admin",
        Method::POST,
        "/api/v1/watch-token",
        Some(json!({ "client_id": "widget:test" })),
    )
    .await;
    let token = body["token"].as_str().unwrap();
    for path in ["/api/v1/me", "/api/v1/users", "/api/v1/roles"] {
        let resp = srv
            .get(path)
            .header("Authorization", format!("Bearer {token}"))
            .send()
            .await
            .unwrap();
        assert_eq!(resp.status().as_u16(), 401, "{path}");
    }
}

#[ntex::test]
async fn a_listen_grant_with_public_lets_a_role_bind_any_address() {
    // The unit half of this is `listen::bind_host`; here it is the role, not
    // the config file, that says so.
    let grants = Grants {
        listen: Some(ListenGrant {
            public: true,
            ports: None,
        }),
        ..Grants::none()
    };
    assert!(grants.validate().is_ok());
    assert!(
        server_box_monitor::api::ws::listen::bind_host("0.0.0.0", grants.listen.unwrap().public)
            .is_some()
    );
}

/// A panel token for [user] as if issued [ago] seconds back — what someone
/// holding a stolen one has.
fn jwt_issued_ago(user: &str, ago: i64) -> String {
    use jsonwebtoken::{EncodingKey, Header, encode};
    let now = chrono::Utc::now().timestamp();
    let claims = server_box_monitor::api::auth::Claims {
        sub: user.to_string(),
        exp: (now + 3600) as usize,
        iat: (now - ago) as usize,
    };
    encode(&Header::default(), &claims, &EncodingKey::from_secret(SECRET.as_ref())).unwrap()
}

async fn status_with(srv: &TestServer, token: &str, path: &str) -> u16 {
    srv.get(path)
        .header("Authorization", format!("Bearer {token}"))
        .send()
        .await
        .unwrap()
        .status()
        .as_u16()
}

#[ntex::test]
async fn a_password_change_ends_what_the_old_one_paid_for() {
    let root = temp_root();
    let state = state(root.path().to_str().unwrap()).await;
    let srv = server(state.clone()).await;
    // The account has had its password a while: a token from ten seconds
    // ago is a good one.
    sqlx::query("UPDATE users SET password_changed_ms = 0 WHERE username IN ('clerk', 'ops')")
        .execute(&state.db)
        .await
        .unwrap();
    let stolen = jwt_issued_ago("clerk", 10);
    assert_eq!(status_with(&srv, &stolen, "/api/v1/me").await, 200);
    let (status, body) = call(
        &srv,
        "clerk",
        Method::POST,
        "/api/v1/watch-token",
        Some(json!({ "client_id": "widget:clerk" })),
    )
    .await;
    assert_eq!(status, 200);
    let paired = body["token"].as_str().unwrap().to_string();
    assert_eq!(status_with(&srv, &paired, "/api/v1/metrics/history").await, 200);

    // Changed by its owner.
    let (status, _) = call(
        &srv,
        "clerk",
        Method::PUT,
        "/api/v1/me/password",
        Some(json!({
            "current_password": common::PASSWORD,
            "new_password": "a-new-password",
        })),
    )
    .await;
    assert_eq!(status, 204);
    assert_eq!(status_with(&srv, &stolen, "/api/v1/me").await, 401);
    assert_eq!(
        status_with(&srv, &paired, "/api/v1/metrics/history").await,
        401,
        "a watch token paired under the old password goes with it"
    );
    // A token issued now — signing in with the new password — works at once.
    assert_eq!(status_with(&srv, &jwt("clerk"), "/api/v1/me").await, 200);

    // Reset by an admin: the same.
    let stolen = jwt_issued_ago("ops", 10);
    assert_eq!(status_with(&srv, &stolen, "/api/v1/me").await, 200);
    let (status, _) = call(
        &srv,
        "admin",
        Method::PUT,
        "/api/v1/users/ops",
        Some(json!({ "password": "another-new-one", "current_password": common::PASSWORD })),
    )
    .await;
    assert_eq!(status, 200);
    assert_eq!(status_with(&srv, &stolen, "/api/v1/me").await, 401);
}

#[ntex::test]
async fn a_token_for_a_deleted_account_is_not_one_for_its_successor() {
    let root = temp_root();
    let state = state(root.path().to_str().unwrap()).await;
    let srv = server(state.clone()).await;
    let old = jwt_issued_ago("viewer", 10);
    let (status, _) = call(
        &srv,
        "admin",
        Method::DELETE,
        "/api/v1/users/viewer",
        Some(json!({ "current_password": common::PASSWORD })),
    )
    .await;
    assert_eq!(status, 204);
    let (status, _) = call(
        &srv,
        "admin",
        Method::POST,
        "/api/v1/users",
        Some(json!({
            "username": "viewer",
            "password": "a-fresh-password",
            "role": "admin",
            "current_password": common::PASSWORD,
        })),
    )
    .await;
    assert_eq!(status, 201);
    assert_eq!(status_with(&srv, &old, "/api/v1/me").await, 401);
}

#[tokio::test]
async fn a_password_changed_behind_the_agents_back_ends_its_terminals_at_the_next_sweep() {
    // A CLI reset writes the database and cannot reach the running agent: its
    // open terminal stays until something next sweeps the sessions. That sweep
    // must not keep it just because the role still grants a shell.
    use server_box_monitor::api::authz::{caller_named, revoke_lost};
    use server_box_monitor::api::ws::session::{Session, SessionAuth};
    use server_box_monitor::core::permissions::Grants;
    use server_box_monitor::db::accounts;

    let state = common::upgraded_state(Config::default()).await;
    common::set_grants(&state.db, "admin", &Grants::all()).await;
    let since = caller_named(&state, "admin").await.unwrap().since;
    let (mut session, _input) = Session::new("admin", "admin", SessionAuth::Local, 1024, 8);
    session.since = since;
    state.sessions.insert(session).unwrap().unwrap();

    // Nothing changed yet: the sweep leaves it.
    revoke_lost(&state, "permission_revoked").await;
    assert_eq!(state.sessions.subjects(), ["admin"]);

    let hash = bcrypt::hash("a-new-password", 4).unwrap();
    accounts::set_password_hash(&state.db, "admin", &hash).await.unwrap();
    revoke_lost(&state, "permission_revoked").await;
    assert!(state.sessions.subjects().is_empty());
}
