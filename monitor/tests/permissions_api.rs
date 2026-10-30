//! The agent's one account against the real route table — `configure_api`,
//! which is what the shipped binary mounts: who gets in (the password, a
//! token issued since it was set, a watch token that only reads) and what
//! the account reaches (everything the system account may).

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
        let dir = std::env::temp_dir().join(format!("sbm-permissions-api-{}", std::process::id()));
        std::fs::create_dir_all(&dir).unwrap();
        std::env::set_current_dir(&dir).unwrap();
    });
}

async fn state() -> Arc<AppState> {
    leave_the_crate();
    ensure_crypto_provider();
    common::owned_state(Config {
        jwt_secret: Some(SECRET.to_string()),
        ..Default::default()
    })
    .await
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

fn jwt() -> String {
    generate_token(SECRET).unwrap()
}

/// One request with [token] (`None` for none), and its status and body.
async fn call(
    srv: &TestServer,
    token: Option<&str>,
    method: Method,
    path: &str,
    body: Option<Value>,
) -> (u16, Value) {
    // Generous: a password change is two bcrypt rounds at the real cost, and a
    // debug build on a shared Windows runner took longer than the default.
    // A current client, which names its protocol (a first-protocol one is
    // `protocol_api.rs`'s).
    let mut req = srv
        .request(method, srv.url(path))
        .header(sbm_parser::protocol::HEADER, sbm_parser::protocol::PROTOCOL.to_string())
        .timeout(std::time::Duration::from_secs(30));
    if let Some(token) = token {
        req = req.header("Authorization", format!("Bearer {token}"));
    }
    let resp = match body {
        Some(body) => req.send_json(&body).await.unwrap(),
        None => req.send().await.unwrap(),
    };
    let status = resp.status().as_u16();
    let bytes = resp.body().await.unwrap_or_default();
    (status, serde_json::from_slice(&bytes).unwrap_or(Value::Null))
}

#[ntex::test]
async fn the_account_reaches_everything_and_nothing_without_a_token() {
    let dir = tempfile::tempdir().unwrap();
    std::fs::write(dir.path().join("note.txt"), "hello").unwrap();
    let srv = server(state().await).await;
    let token = jwt();
    let ticket = |purpose: &str| Some(json!({ "purpose": purpose }));

    let cases: Vec<(Method, String, Option<Value>)> = vec![
        (Method::GET, "/api/v1/metrics/history".into(), None),
        (Method::GET, "/api/v1/capabilities".into(), None),
        (Method::GET, "/api/v1/push".into(), None),
        (Method::POST, "/api/v1/exec".into(), Some(json!({ "cmd": "true" }))),
        (Method::POST, "/api/v1/ws-ticket".into(), ticket("terminal")),
        (Method::POST, "/api/v1/ws-ticket".into(), ticket("stream")),
        (Method::POST, "/api/v1/ws-ticket".into(), ticket("listen")),
        (Method::GET, format!("/api/v1/fs/list?path={}", dir.path().display()), None),
        (Method::POST, "/api/v1/fs/mkdir".into(), Some(json!({ "path": dir.path().join("d") }))),
    ];
    for (method, path, body) in cases {
        let (status, seen) = call(&srv, Some(&token), method.clone(), &path, body.clone()).await;
        assert!(status != 401 && status != 403, "{method} {path} answered {status} {seen}");
        let (status, _) = call(&srv, None, method.clone(), &path, body).await;
        assert_eq!(status, 401, "no token: {method} {path}");
    }
    assert!(dir.path().join("d").is_dir());
}

#[ntex::test]
async fn capabilities_say_whether_the_machine_may_be_acted_on() {
    let srv = server(state().await).await;
    let (_, caps) = call(&srv, Some(&jwt()), Method::GET, "/api/v1/capabilities", None).await;
    // The test client is a loopback peer, which counts as secure.
    assert_eq!(caps["access"], json!({ "ok": true }));
    for gone in ["grants", "me", "remote_access"] {
        assert!(caps.get(gone).is_none(), "{gone}");
    }
}

#[ntex::test]
async fn there_are_no_accounts_or_roles_to_manage() {
    let srv = server(state().await).await;
    let token = jwt();
    for path in ["/api/v1/me", "/api/v1/users", "/api/v1/roles", "/api/v1/remote-access/full-access"] {
        for method in [Method::GET, Method::POST, Method::DELETE] {
            let (status, body) = call(&srv, Some(&token), method.clone(), path, Some(json!({}))).await;
            // The API's own 404, so the panel's page behind it never answers.
            assert_eq!((status, &body["error"]), (404, &json!("not_found")), "{method} {path}");
        }
    }
}

#[ntex::test]
async fn the_password_alone_signs_in() {
    let srv = server(state().await).await;
    let login = |body: Value| {
        let srv = &srv;
        async move { call(srv, None, Method::POST, "/api/v1/login", Some(body)).await }
    };
    let (status, body) = login(json!({ "password": common::PASSWORD })).await;
    assert_eq!(status, 200);
    let token = body["token"].as_str().unwrap().to_string();
    let (status, _) = call(&srv, Some(&token), Method::GET, "/api/v1/agent/flows", None).await;
    assert_eq!(status, 200);

    // What an older client sends: the name is not read.
    let (status, _) = login(json!({ "username": "whoever", "password": common::PASSWORD })).await;
    assert_eq!(status, 200);

    let (status, _) = login(json!({ "password": "not-the-password" })).await;
    assert_eq!(status, 401);
}

/// Every sign-in is in the audit log, let in or refused, with where it came
/// from and never the password; `/audit` reads it back newest first, a page
/// at a time, by kind and by result.
#[ntex::test]
async fn sign_ins_are_audited_and_read_back() {
    let srv = server(state().await).await;
    let login = |body: Value| {
        let srv = &srv;
        async move { call(srv, None, Method::POST, "/api/v1/login", Some(body)).await }
    };
    let (_, body) = login(json!({ "password": common::PASSWORD })).await;
    let device = body["device"].as_str().unwrap().to_string();
    login(json!({ "password": "not-the-password" })).await;
    login(json!({ "password": common::PASSWORD, "device": device })).await;

    let token = jwt();
    let (status, page) = call(&srv, Some(&token), Method::GET, "/api/v1/audit?kind=login", None).await;
    assert_eq!(status, 200);
    let seen: Vec<(String, String)> = page["entries"]
        .as_array()
        .unwrap()
        .iter()
        .map(|e| (e["result"].as_str().unwrap().into(), e["detail"].as_str().unwrap().into()))
        .collect();
    assert_eq!(
        seen,
        [
            ("ok".into(), "device known".into()),
            ("denied".into(), "wrong password".into()),
            ("ok".into(), "new device".into()),
        ],
    );
    assert_eq!(page["entries"][0]["remote_ip"], "127.0.0.1");
    assert!(page["next"].is_null());
    let whole = page.to_string();
    assert!(!whole.contains(common::PASSWORD) && !whole.contains("not-the-password") && !whole.contains(&device));

    let (_, refused) = call(&srv, Some(&token), Method::GET, "/api/v1/audit?kind=login&result=denied", None).await;
    assert_eq!(refused["entries"].as_array().unwrap().len(), 1);

    let (_, first) = call(&srv, Some(&token), Method::GET, "/api/v1/audit?kind=login&limit=2", None).await;
    assert_eq!(first["entries"].as_array().unwrap().len(), 2);
    let next = first["next"].as_i64().unwrap();
    let (_, rest) = call(&srv, Some(&token), Method::GET, &format!("/api/v1/audit?kind=login&limit=2&before={next}"), None).await;
    assert_eq!(rest["entries"][0]["detail"], "new device");
    assert!(rest["next"].is_null());

    for bad in ["kind=nope", "result=maybe"] {
        let (status, body) = call(&srv, Some(&token), Method::GET, &format!("/api/v1/audit?{bad}"), None).await;
        assert_eq!((status, &body["error"]), (400, &json!("invalid_input")), "{bad}");
    }
    let (status, _) = call(&srv, None, Method::GET, "/api/v1/audit", None).await;
    assert_eq!(status, 401);
}

/// `GET /live`: the devices that signed in (by the name they gave, never a
/// token) and the watch tokens; a device forgotten is gone from the list and
/// signs in as a new one; ending what is not there is a 404.
#[ntex::test]
async fn devices_and_watch_tokens_are_listed_and_a_device_forgotten() {
    let srv = server(state().await).await;
    let (_, signed) = call(
        &srv,
        None,
        Method::POST,
        "/api/v1/login",
        Some(json!({ "password": common::PASSWORD, "name": "  ServerBox\non   macOS " })),
    )
    .await;
    let device = signed["device"].as_str().unwrap().to_string();
    let token = jwt();
    let (status, _) = call(&srv, Some(&token), Method::POST, "/api/v1/watch-token", Some(json!({ "client_id": "widget:test" }))).await;
    assert_eq!(status, 200);

    let (status, live) = call(&srv, Some(&token), Method::GET, "/api/v1/live", None).await;
    assert_eq!(status, 200);
    assert_eq!(live["sessions"], json!([]));
    assert_eq!(live["connections"], json!([]));
    assert_eq!(live["watch_tokens"][0]["client_id"], "widget:test");
    let listed = &live["devices"][0];
    assert_eq!(listed["label"], "ServerBox on macOS");
    assert_eq!(listed["last_ip"], "127.0.0.1");
    assert!(!live.to_string().contains(&device));

    let id = listed["id"].as_i64().unwrap();
    let path = format!("/api/v1/live/devices/{id}");
    let (status, _) = call(&srv, Some(&token), Method::DELETE, &path, None).await;
    assert_eq!(status, 204);
    let (status, _) = call(&srv, Some(&token), Method::DELETE, &path, None).await;
    assert_eq!(status, 404);
    let (_, live) = call(&srv, Some(&token), Method::GET, "/api/v1/live", None).await;
    assert_eq!(live["devices"], json!([]));

    // Its token is no longer a known device's: a new one is handed out.
    let (_, again) = call(&srv, None, Method::POST, "/api/v1/login", Some(json!({ "password": common::PASSWORD, "device": device }))).await;
    assert!(again["device"].as_str().is_some_and(|d| d != device));

    for gone in ["/api/v1/live/sessions/nope", "/api/v1/live/connections/7"] {
        let (status, _) = call(&srv, Some(&token), Method::DELETE, gone, None).await;
        assert_eq!(status, 404, "{gone}");
    }
    let (status, _) = call(&srv, None, Method::GET, "/api/v1/live", None).await;
    assert_eq!(status, 401);
}

#[ntex::test]
async fn a_watch_token_only_reads() {
    let srv = server(state().await).await;
    let (_, body) = call(
        &srv,
        Some(&jwt()),
        Method::POST,
        "/api/v1/watch-token",
        Some(json!({ "client_id": "widget:test" })),
    )
    .await;
    let token = body["token"].as_str().unwrap().to_string();
    let (status, _) = call(&srv, Some(&token), Method::GET, "/api/v1/metrics/history", None).await;
    assert_eq!(status, 200);
    let (status, _) = call(&srv, Some(&token), Method::POST, "/api/v1/exec", Some(json!({ "cmd": "true" }))).await;
    assert_eq!(status, 401);
}

/// A panel token as if issued [ago] seconds back — what someone holding a
/// stolen one has.
fn jwt_issued_ago(ago: i64) -> String {
    let now = chrono::Utc::now().timestamp();
    let claims = server_box_monitor::api::auth::Claims {
        sub: server_box_monitor::api::auth::SUBJECT.to_string(),
        exp: (now + 3600) as usize,
        iat: (now - ago) as usize,
    };
    server_box_monitor::api::auth::sign_token(&claims, SECRET).unwrap()
}

#[ntex::test]
async fn a_password_change_ends_what_the_old_one_paid_for() {
    let state = state().await;
    let srv = server(state.clone()).await;
    // The password has been set a while: a token from ten seconds ago is a
    // good one.
    sqlx::query("UPDATE users SET password_changed_ms = 0")
        .execute(&state.db)
        .await
        .unwrap();
    let stolen = jwt_issued_ago(10);
    let (status, _) = call(&srv, Some(&stolen), Method::GET, "/api/v1/agent/flows", None).await;
    assert_eq!(status, 200);
    let (status, body) = call(
        &srv,
        Some(&stolen),
        Method::POST,
        "/api/v1/watch-token",
        Some(json!({ "client_id": "widget:owner" })),
    )
    .await;
    assert_eq!(status, 200);
    let paired = body["token"].as_str().unwrap().to_string();

    // A wrong current password changes nothing.
    let (status, body) = call(
        &srv,
        Some(&jwt()),
        Method::PUT,
        "/api/v1/me/password",
        Some(json!({ "current_password": "wrong", "new_password": "a-new-password" })),
    )
    .await;
    assert_eq!((status, body["error"].as_str()), (403, Some("reauth")));

    let (status, _) = call(
        &srv,
        Some(&jwt()),
        Method::PUT,
        "/api/v1/me/password",
        Some(json!({ "current_password": common::PASSWORD, "new_password": "a-new-password" })),
    )
    .await;
    assert_eq!(status, 204);
    let (status, _) = call(&srv, Some(&stolen), Method::GET, "/api/v1/agent/flows", None).await;
    assert_eq!(status, 401);
    let (status, _) = call(&srv, Some(&paired), Method::GET, "/api/v1/metrics/history", None).await;
    assert_eq!(status, 401, "a watch token paired under the old password goes with it");
    // A token issued now — signing in with the new password — works at once.
    let (status, _) = call(&srv, Some(&jwt()), Method::GET, "/api/v1/agent/flows", None).await;
    assert_eq!(status, 200);
    let (status, _) =
        call(&srv, None, Method::POST, "/api/v1/login", Some(json!({ "password": "a-new-password" }))).await;
    assert_eq!(status, 200);
}

/// Over a plaintext link from another machine, with no `allow_insecure`:
/// the numbers are served, and nothing that changes or configures the
/// machine or the agent is — the routes that were an admin's included.
#[ntex::test]
async fn a_plaintext_link_only_reads() {
    use ntex::web::test::{TestRequest, call_service, init_service};

    let state = state().await;
    let limit = state.remote_access.exec.max_request_bytes;
    let app = init_service(App::new().state(state).configure(configure_api(limit))).await;
    let token = jwt();
    let remote: std::net::SocketAddr = "203.0.113.7:40000".parse().unwrap();
    let request = |method: Method, path: &str, body: Option<Value>| {
        let req = TestRequest::with_uri(path)
            .method(method)
            .peer_addr(remote)
            .header("Authorization", format!("Bearer {token}"));
        match body {
            Some(body) => req.set_json(&body).to_request(),
            None => req.to_request(),
        }
    };

    let resp = call_service(&app, request(Method::GET, "/api/v1/metrics/history", None)).await;
    assert_eq!(resp.status().as_u16(), 200);

    let cases: Vec<(Method, &str, Option<Value>)> = vec![
        (Method::POST, "/api/v1/exec", Some(json!({ "cmd": "true" }))),
        (Method::GET, "/api/v1/fs/roots", None),
        (Method::GET, "/api/v1/settings", None),
        (Method::GET, "/api/v1/audit", None),
        (Method::GET, "/api/v1/live", None),
        (Method::DELETE, "/api/v1/live/devices/1", None),
        (Method::GET, "/api/v1/push", None),
        (Method::GET, "/api/v1/backup", None),
        (Method::GET, "/api/v1/storage", None),
        (Method::GET, "/api/v1/shares", None),
        (Method::POST, "/api/v1/stacks/refresh", None),
        (Method::PUT, "/api/v1/bmc", Some(json!({ "targets": [] }))),
        (Method::DELETE, "/api/v1/virt/pve", None),
        (Method::GET, "/api/v1/agent/permissions", None),
        (Method::PUT, "/api/v1/agent/permissions", Some(json!({}))),
        (Method::GET, "/api/v1/agent/mcp", None),
        (Method::GET, "/api/v1/container-backups", None),
        (Method::DELETE, "/api/v1/container-backups/schedules/x", None),
        (Method::GET, "/api/v1/monitor-backup", None),
        (Method::POST, "/api/v1/monitor-backup/test", Some(json!({ "url": "https://dav.example.com/" }))),
        (Method::POST, "/api/v1/monitor-backup/run", None),
        (Method::GET, "/api/v1/monitor-backup/list", None),
        (Method::PUT, "/api/v1/monitor-backup", Some(json!({ "url": "https://dav.example.com/", "current_password": common::PASSWORD }))),
        (Method::DELETE, "/api/v1/monitor-backup", Some(json!({ "current_password": common::PASSWORD }))),
        (Method::PUT, "/api/v1/monitor-backup/key", Some(json!({ "passphrase": "a long enough passphrase", "current_password": common::PASSWORD }))),
        (Method::POST, "/api/v1/monitor-backup/restore", Some(json!({ "name": "x", "passphrase": "a long enough passphrase", "current_password": common::PASSWORD }))),
        (Method::GET, "/api/v1/lkc", None),
        (Method::DELETE, "/api/v1/lkc", None),
        (Method::POST, "/api/v1/lkc/sign-in", None),
        (Method::DELETE, "/api/v1/lkc/sign-in", None),
        (Method::PUT, "/api/v1/me/password", Some(json!({ "current_password": common::PASSWORD, "new_password": "a-new-password" }))),
    ];
    for (method, path, body) in cases {
        let resp = call_service(&app, request(method.clone(), path, body)).await;
        assert_eq!(resp.status().as_u16(), 403, "{method} {path}");
    }
}

/// `test/fixtures/monitor/capabilities_insecure.json`, which the app's and
/// the panel's tests read as this answer, against the answer itself: the same
/// fields of the same kinds, the same `access` and `features`. What depends
/// on the machine (its readings, platform, version, retention) is only
/// checked to be what the agent could have said.
#[ntex::test]
async fn the_clients_capabilities_fixture_is_what_a_plaintext_link_gets() {
    use ntex::web::test::{TestRequest, call_service, init_service, read_body};
    use server_box_monitor::api::machine::FEATURES;

    let state = state().await;
    let limit = state.remote_access.exec.max_request_bytes;
    let app = init_service(App::new().state(state).configure(configure_api(limit))).await;
    let req = TestRequest::with_uri("/api/v1/capabilities")
        .peer_addr("203.0.113.7:40000".parse().unwrap())
        .header("Authorization", format!("Bearer {}", jwt()))
        .header(sbm_parser::protocol::HEADER, sbm_parser::protocol::PROTOCOL.to_string())
        .to_request();
    let resp = call_service(&app, req).await;
    assert_eq!(resp.status().as_u16(), 200);
    let real: Value = serde_json::from_slice(&read_body(resp).await).unwrap();

    let path = concat!(env!("CARGO_MANIFEST_DIR"), "/../test/fixtures/monitor/capabilities_insecure.json");
    let fixture: Value = serde_json::from_str(&std::fs::read_to_string(path).unwrap()).unwrap();
    let (real, fixture) = (real.as_object().unwrap(), fixture.as_object().unwrap());

    fn kind(v: &Value) -> &'static str {
        match v {
            Value::Null => "null",
            Value::Bool(_) => "bool",
            Value::Number(_) => "number",
            Value::String(_) => "string",
            Value::Array(_) => "array",
            Value::Object(_) => "object",
        }
    }
    for (key, value) in real {
        let Some(theirs) = fixture.get(key) else { panic!("the fixture has no `{key}`") };
        assert_eq!(kind(theirs), kind(value), "`{key}`");
    }
    for key in fixture.keys() {
        // Absent on an agent with no readings yet, as this one is.
        assert!(real.contains_key(key) || key == "oldest_sample", "the agent has no `{key}`");
    }
    assert_eq!(fixture["access"], real["access"]);
    assert_eq!(fixture["features"], json!(FEATURES));

    let whole = Value::Object(fixture.clone());
    serde_json::from_value::<sbm_parser::capabilities::Capabilities>(whole).expect("the readings");
    serde_json::from_value::<sbm_parser::SystemType>(fixture["platform"].clone()).expect("platform");
    for stack in fixture["stacks"].as_array().unwrap() {
        assert!(stack["id"].is_string(), "{stack}");
        assert!(["installing", "installed", "failed"].contains(&stack["state"].as_str().unwrap()), "{stack}");
    }
}

/// A sign-in hands the device a token it sends next time, which keeps it out
/// of the account-wide throttle (`api::ratelimit`); a password change forgets
/// every device.
#[ntex::test]
async fn a_device_that_signed_in_is_remembered_until_the_password_changes() {
    let state = state().await;
    let srv = server(state.clone()).await;
    let login = |body: Value| {
        let srv = &srv;
        async move { call(srv, None, Method::POST, "/api/v1/login", Some(body)).await }
    };

    let (status, body) = login(json!({ "password": common::PASSWORD })).await;
    assert_eq!(status, 200);
    let device = body["device"].as_str().expect("a first sign-in gets a device token").to_string();
    assert!(device.starts_with("sbd_"), "{device}");
    let stored: Vec<String> = sqlx::query_scalar("SELECT token_hash FROM login_device")
        .fetch_all(&state.db)
        .await
        .unwrap();
    assert_eq!(stored.len(), 1);
    assert_ne!(stored[0], device, "only the digest is kept");

    let (status, body) = login(json!({ "password": common::PASSWORD, "device": device })).await;
    assert_eq!(status, 200);
    assert!(body.get("device").is_none(), "a known device keeps its token: {body}");

    // An unknown token is a stranger, and gets one of its own.
    let (_, body) = login(json!({ "password": common::PASSWORD, "device": "sbd_forged" })).await;
    assert!(body["device"].is_string(), "{body}");

    let (status, _) = call(
        &srv,
        Some(&jwt()),
        Method::PUT,
        "/api/v1/me/password",
        Some(json!({ "current_password": common::PASSWORD, "new_password": "a-new-password" })),
    )
    .await;
    assert_eq!(status, 204);
    let (status, body) = login(json!({ "password": "a-new-password", "device": device })).await;
    assert_eq!(status, 200);
    assert!(body["device"].is_string(), "the old device token is forgotten: {body}");
}

/// A device sign-in started under the old password does not outlive it:
/// whoever approved it would have the agent signed in to their account.
#[tokio::test]
async fn a_password_change_ends_a_device_sign_in_waiting() {
    let state = state().await;
    let view = server_box_monitor::lkc::SignInView {
        user_code: "ABCD".into(),
        verification_uri: "https://auth.example/device".into(),
        verification_uri_complete: None,
        expires_at_ms: i64::MAX,
        failed: None,
    };
    let epoch = state.lkc.epoch();
    assert!(state.lkc.begin(view.clone(), "device".into(), epoch));
    assert!(state.lkc.sign_in().is_some());
    server_box_monitor::api::authz::end_account(&state, "password_changed");
    assert!(state.lkc.sign_in().is_none());
    // One asked for before the change is not begun after it.
    assert!(!state.lkc.begin(view, "device".into(), epoch));
}

/// Whoever held the old password may have approved a sign-in with their own
/// LK Cloud account: a password change signs the agent out of it.
#[tokio::test]
async fn a_password_change_signs_out_of_lk_cloud() {
    use server_box_monitor::db::sealed;
    let state = state().await;
    sqlx::query(
        "INSERT INTO lkc_session (id, user, access_token, refresh_token, expires_at, updated_at) VALUES (1, ?, ?, NULL, ?, 0)",
    )
    .bind(r#"{"id":"u1","name":"Ada","group":"user"}"#)
    .bind(state.sealer.seal(sealed::LKC_ACCESS_TOKEN, "access").unwrap())
    .bind(i64::MAX)
    .execute(&state.db)
    .await
    .unwrap();
    assert!(server_box_monitor::lkc::current(&state).await.is_some());
    server_box_monitor::api::authz::end_account(&state, "password_changed");
    for _ in 0..100 {
        if server_box_monitor::lkc::current(&state).await.is_none() {
            return;
        }
        tokio::time::sleep(std::time::Duration::from_millis(20)).await;
    }
    panic!("still signed in to LK Cloud after the password changed");
}

/// A reset from the CLI, which reaches no running agent, signs out of LK
/// Cloud as well.
#[tokio::test]
async fn a_cli_password_reset_signs_out_of_lk_cloud() {
    use server_box_monitor::db::sealed;
    let state = state().await;
    sqlx::query(
        "INSERT INTO lkc_session (id, user, access_token, refresh_token, expires_at, updated_at) VALUES (1, ?, ?, NULL, ?, 0)",
    )
    .bind(r#"{"id":"u1","name":"Ada","group":"user"}"#)
    .bind(state.sealer.seal(sealed::LKC_ACCESS_TOKEN, "access").unwrap())
    .bind(i64::MAX)
    .execute(&state.db)
    .await
    .unwrap();
    server_box_monitor::db::accounts::set_password_hash(&state.db, "hash").await.unwrap();
    assert!(server_box_monitor::lkc::current(&state).await.is_none());
}
