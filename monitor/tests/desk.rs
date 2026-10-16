//! `/api/v1/desk*`: what the panel's desk keeps on the agent, whose it is,
//! and the revision that keeps two tabs from overwriting each other.

mod common;

use std::sync::Arc;

use ntex::http::Method;
use ntex::web::test::{self as web_test, TestServer};
use ntex::web::{self, App};
use server_box_monitor::api::auth::generate_token;
use server_box_monitor::api::desk::{self, DeskEvent, Level, Source};
use server_box_monitor::api::desk_storage;
use server_box_monitor::api::server::AppState;
use server_box_monitor::core::config::Config;
use server_box_monitor::monitoring::rules::Firing;

const SECRET: &str = "test-secret-that-is-long-enough-32ch";

async fn state() -> Arc<AppState> {
    state_over(common::database().await).await
}

async fn state_over(db: sqlx::SqlitePool) -> Arc<AppState> {
    let _ = rustls::crypto::ring::default_provider().install_default();
    let config = Config {
        jwt_secret: Some(SECRET.to_string()),
        ..Default::default()
    };
    common::add_owner(&db).await;
    AppState::new(Arc::new(config), db)
}

async fn server(state: Arc<AppState>) -> TestServer {
    web_test::server(move || {
        let state = state.clone();
        async move {
            App::new().state(state).service(
                web::scope("/api/v1")
                    .route("/desk", web::get().to(desk::get))
                    .route("/alerts", web::get().to(desk::alerts))
                    .route("/desk/preferences", web::put().to(desk::put_preferences))
                    .service(
                        web::resource("/desk/onboarding")
                            .route(web::put().to(desk::put_onboarding))
                            .route(web::delete().to(desk::delete_onboarding)),
                    )
                    .service(
                        web::resource("/desk/wallpaper")
                            .route(web::get().to(desk::get_wallpaper))
                            .route(web::put().to(desk::put_wallpaper))
                            .route(web::delete().to(desk::delete_wallpaper)),
                    )
                    .service(
                        web::resource("/desk/session")
                            .route(web::get().to(desk::get_session))
                            .route(web::put().to(desk::put_session)),
                    )
                    .route("/desk/notifications", web::get().to(desk::notifications))
                    .route("/desk/notifications/read", web::post().to(desk::mark_read))
                    .route("/desk/events", web::get().to(desk::events))
                    .service(
                        web::resource("/desk/apps/{app}/storage")
                            .state(web::types::JsonConfig::default().limit(desk_storage::MAX_BODY))
                            .route(web::get().to(desk_storage::list))
                            .route(web::put().to(desk_storage::put))
                            .route(web::delete().to(desk_storage::remove)),
                    ),
            )
        }
    })
    .await
}

/// One request as [user], and its status and body (JSON, or the raw bytes as
/// a JSON string of their length when they are not JSON).
async fn call(
    srv: &TestServer,
    signed: bool,
    method: Method,
    path: &str,
    body: Option<Vec<u8>>,
) -> (u16, serde_json::Value, Vec<u8>) {
    let mut req = srv
        .request(method, srv.url(path))
        .timeout(std::time::Duration::from_secs(30));
    if signed {
        req = req.header(
            "Authorization",
            format!("Bearer {}", generate_token(SECRET).unwrap()),
        );
    }
    let resp = match body {
        Some(body) => req
            .header("content-type", "application/json")
            .send_body(body)
            .await
            .unwrap(),
        None => req.send().await.unwrap(),
    };
    let status = resp.status().as_u16();
    let bytes = resp.body().limit(16 << 20).await.unwrap_or_default().to_vec();
    let json = serde_json::from_slice(&bytes).unwrap_or(serde_json::Value::Null);
    (status, json, bytes)
}

fn json(value: serde_json::Value) -> Option<Vec<u8>> {
    Some(value.to_string().into_bytes())
}

fn prefs() -> serde_json::Value {
    serde_json::json!({
        "accent": "#2563EB",
        "wallpaper": "preset:dusk",
        "wallpaper_fit": "cover",
        "dock": ["serverbox.status", "serverbox.files", "serverbox.terminal"],
        "icons": [
            { "id": "a", "kind": "app", "app_id": "serverbox.settings", "label": "" },
            { "id": "b", "kind": "path", "app_id": "serverbox.files", "server_id": "local", "path": "/etc", "label": "etc", "col": 0, "row": 1 }
        ]
    })
}

fn session(expected: i64, windows: usize) -> serde_json::Value {
    let windows: Vec<serde_json::Value> = (0..windows)
        .map(|i| {
            serde_json::json!({
                "window_id": format!("w{i}"),
                "app_id": "serverbox.files",
                "x": 10 * i, "y": 20, "width": 800, "height": 600, "z": i,
                "minimized": false, "maximized": i == 0,
                "app_state": { "path": "/root" }
            })
        })
        .collect();
    serde_json::json!({
        "device": "dev-1",
        "expected_revision": expected,
        "active_window_id": if windows.is_empty() { None } else { Some("w0") },
        "windows": windows,
    })
}

#[ntex::test]
async fn nothing_without_a_token() {
    let srv = server(state().await).await;
    for path in ["/api/v1/desk", "/api/v1/desk/session?device=d", "/api/v1/desk/notifications", "/api/v1/desk/events"] {
        let (status, _, _) = call(&srv, false, Method::GET, path, None).await;
        assert_eq!(status, 401, "{path}");
    }
}

#[ntex::test]
async fn preferences_round_trip() {
    let srv = server(state().await).await;
    let (status, body, _) = call(&srv, true, Method::GET, "/api/v1/desk", None).await;
    assert_eq!(status, 200);
    assert!(body["preferences"].is_null());
    assert!(body["presets"].as_array().unwrap().iter().any(|p| p == "bloom"));

    let (status, saved, _) = call(&srv, true, Method::PUT, "/api/v1/desk/preferences", json(prefs())).await;
    assert_eq!(status, 200, "{saved}");
    assert_eq!(saved["accent"], "#2563eb");

    let (_, body, _) = call(&srv, true, Method::GET, "/api/v1/desk", None).await;
    assert_eq!(body["preferences"], saved);
    assert_eq!(body["preferences"]["dock"], serde_json::json!(["serverbox.status", "serverbox.files", "serverbox.terminal"]));
    assert_eq!(body["preferences"]["icons"][1]["path"], "/etc");
    // A client older than background running leaves it out: on.
    assert_eq!(body["preferences"]["background"], true);

    assert_eq!(body["preferences"]["background_denied"], serde_json::json!([]));

    let mut off = prefs();
    off["background"] = serde_json::json!(false);
    off["background_denied"] = serde_json::json!(["serverbox.status", "serverbox.files"]);
    let (status, _, _) = call(&srv, true, Method::PUT, "/api/v1/desk/preferences", json(off)).await;
    assert_eq!(status, 200);
    let (_, body, _) = call(&srv, true, Method::GET, "/api/v1/desk", None).await;
    assert_eq!(body["preferences"]["background"], false);
    assert_eq!(body["preferences"]["background_denied"], serde_json::json!(["serverbox.files", "serverbox.status"]));

}

/// The first-run guide: shown until the account is done with it, kept apart
/// from the preferences so saving those never brings it back.
#[ntex::test]
async fn the_first_run_guide_is_done_once_and_offered_again() {
    let srv = server(state().await).await;
    let (_, body, _) = call(&srv, true, Method::GET, "/api/v1/desk", None).await;
    assert!(body["onboarded_at"].is_null());

    let (status, _, _) = call(&srv, true, Method::PUT, "/api/v1/desk/onboarding", None).await;
    assert_eq!(status, 204);
    let (_, body, _) = call(&srv, true, Method::GET, "/api/v1/desk", None).await;
    let first = body["onboarded_at"].as_str().expect("marked").to_string();

    // Again: the first time stands. Preferences saved: still done.
    let (status, _, _) = call(&srv, true, Method::PUT, "/api/v1/desk/onboarding", None).await;
    assert_eq!(status, 204);
    let (status, _, _) = call(&srv, true, Method::PUT, "/api/v1/desk/preferences", json(prefs())).await;
    assert_eq!(status, 200);
    let (_, body, _) = call(&srv, true, Method::GET, "/api/v1/desk", None).await;
    assert_eq!(body["onboarded_at"], first.as_str());

    let (status, _, _) = call(&srv, true, Method::DELETE, "/api/v1/desk/onboarding", None).await;
    assert_eq!(status, 204);
    let (_, body, _) = call(&srv, true, Method::GET, "/api/v1/desk", None).await;
    assert!(body["onboarded_at"].is_null());

    let (status, _, _) = call(&srv, false, Method::PUT, "/api/v1/desk/onboarding", None).await;
    assert_eq!(status, 401);
}

/// An agent upgraded under an account that has used the desk does not greet
/// it: migration 035 marks an account with stored preferences or a session.
#[ntex::test]
async fn the_migration_marks_an_account_that_already_used_the_desk() {
    let db = common::database().await;
    common::add_owner(&db).await;
    let owner: i64 = sqlx::query_scalar("SELECT id FROM users LIMIT 1").fetch_one(&db).await.unwrap();
    sqlx::query("INSERT INTO desk_session (user_id, device_id, revision, updated_at) VALUES (?, 'd', 1, '2026-01-01T00:00:00+00:00')")
        .bind(owner)
        .execute(&db)
        .await
        .unwrap();
    sqlx::query("DROP TABLE desk_onboarding").execute(&db).await.unwrap();
    sqlx::query("DELETE FROM _sqlx_migrations WHERE version = 35").execute(&db).await.unwrap();
    sqlx::migrate!("./migrations").run(&db).await.unwrap();

    let marked: Vec<i64> = sqlx::query_scalar("SELECT user_id FROM desk_onboarding").fetch_all(&db).await.unwrap();
    assert_eq!(marked, [owner]);
    // Nothing else is written for it: its desk keeps the panel's defaults.
    let rows: i64 = sqlx::query_scalar("SELECT COUNT(*) FROM desk_preferences").fetch_one(&db).await.unwrap();
    assert_eq!(rows, 0);
}

#[ntex::test]
async fn a_refused_preference_names_why_and_stores_nothing() {
    let srv = server(state().await).await;
    let mut bad = prefs();
    bad["icons"][1]["path"] = serde_json::Value::Null;
    let (status, body, _) = call(&srv, true, Method::PUT, "/api/v1/desk/preferences", json(bad)).await;
    assert_eq!(status, 400);
    assert_eq!(body, serde_json::json!({ "error": "invalidIcon", "index": 1 }));
    let mut unknown = prefs();
    unknown["extra"] = serde_json::json!(1);
    let (status, _, _) = call(&srv, true, Method::PUT, "/api/v1/desk/preferences", json(unknown)).await;
    assert_eq!(status, 400);
    let (_, body, _) = call(&srv, true, Method::GET, "/api/v1/desk", None).await;
    assert!(body["preferences"].is_null());
}

#[ntex::test]
async fn wallpaper_is_an_image_and_cached_by_its_hash() {
    let state = state().await;
    let blobs = state.blobs.clone();
    let srv = server(state).await;
    let svg = b"<svg xmlns='http://www.w3.org/2000/svg'><script>alert(1)</script></svg>".to_vec();
    let (status, body, _) = call(&srv, true, Method::PUT, "/api/v1/desk/wallpaper", Some(svg)).await;
    assert_eq!(status, 415);
    assert_eq!(body["error"], "notAnImage");

    let mut png = b"\x89PNG\r\n\x1a\n".to_vec();
    png.extend_from_slice(&[7u8; 64]);
    let (status, body, _) = call(&srv, true, Method::PUT, "/api/v1/desk/wallpaper", Some(png.clone())).await;
    assert_eq!(status, 200);
    let sha = body["sha256"].as_str().unwrap().to_owned();
    assert_eq!(sha.len(), 64);
    // A file beside the database, named by its digest; not a row's bytes.
    let file = blobs.dir().join(&sha[..2]).join(&sha);
    assert_eq!(std::fs::read(&file).unwrap(), png);

    let resp = srv
        .get("/api/v1/desk/wallpaper")
        .header("Authorization", format!("Bearer {}", generate_token(SECRET).unwrap()))
        .send()
        .await
        .unwrap();
    assert_eq!(resp.status().as_u16(), 200);
    assert_eq!(resp.headers().get("content-type").unwrap(), "image/png");
    assert_eq!(resp.headers().get("etag").unwrap().to_str().unwrap(), format!("\"{sha}\""));
    let resp = srv
        .get("/api/v1/desk/wallpaper")
        .header("Authorization", format!("Bearer {}", generate_token(SECRET).unwrap()))
        .header("If-None-Match", format!("\"{sha}\""))
        .send()
        .await
        .unwrap();
    assert_eq!(resp.status().as_u16(), 304);

    // Too large is refused before it is stored.
    let mut big = b"\x89PNG\r\n\x1a\n".to_vec();
    big.resize(desk::MAX_WALLPAPER_BYTES + 1, 0);
    let (status, _, _) = call(&srv, true, Method::PUT, "/api/v1/desk/wallpaper", Some(big)).await;
    assert_eq!(status, 413);

    // Removing it takes a desk that showed it back to the default.
    let mut custom = prefs();
    custom["wallpaper"] = serde_json::json!("custom");
    call(&srv, true, Method::PUT, "/api/v1/desk/preferences", json(custom)).await;
    let (status, _, _) = call(&srv, true, Method::DELETE, "/api/v1/desk/wallpaper", None).await;
    assert_eq!(status, 204);
    let (_, body, _) = call(&srv, true, Method::GET, "/api/v1/desk", None).await;
    assert_eq!(body["preferences"]["wallpaper"], desk::DEFAULT_WALLPAPER);
    assert!(body["wallpaper_sha256"].is_null());
    // And its file goes once nothing names it.
    for _ in 0..50 {
        if !file.exists() {
            break;
        }
        tokio::time::sleep(std::time::Duration::from_millis(20)).await;
    }
    assert!(!file.exists());
}

#[ntex::test]
async fn session_moves_by_revision() {
    let srv = server(state().await).await;
    let (_, empty, _) = call(&srv, true, Method::GET, "/api/v1/desk/session?device=dev-1", None).await;
    assert_eq!(empty, serde_json::json!({ "revision": 0, "active_window_id": null, "windows": [] }));

    let (status, body, _) = call(&srv, true, Method::PUT, "/api/v1/desk/session", json(session(0, 2))).await;
    assert_eq!(status, 200, "{body}");
    assert_eq!(body["revision"], 1);

    // A tab still at 0 is told what is current rather than overwriting it.
    let (status, body, _) = call(&srv, true, Method::PUT, "/api/v1/desk/session", json(session(0, 1))).await;
    assert_eq!(status, 409);
    assert_eq!(body["error"], "conflict");
    assert_eq!(body["current"]["revision"], 1);
    assert_eq!(body["current"]["windows"].as_array().unwrap().len(), 2);
    assert_eq!(body["current"]["windows"][0]["app_state"]["path"], "/root");

    let (status, body, _) = call(&srv, true, Method::PUT, "/api/v1/desk/session", json(session(1, 1))).await;
    assert_eq!(status, 200);
    assert_eq!(body["revision"], 2);
    let (_, now, _) = call(&srv, true, Method::GET, "/api/v1/desk/session?device=dev-1", None).await;
    assert_eq!(now["windows"].as_array().unwrap().len(), 1);
    assert_eq!(now["active_window_id"], "w0");

    // Per device.
    let (_, phone, _) = call(&srv, true, Method::GET, "/api/v1/desk/session?device=dev-2", None).await;
    assert_eq!(phone["revision"], 0);
}

/// Two tabs writing from the same revision at once: exactly one lands. On a
/// file database, where SQLite's locking is what it is in the agent.
#[ntex::test]
async fn two_writes_from_one_revision_land_once() {
    let dir = tempfile::tempdir().unwrap();
    let url = format!("sqlite://{}?mode=rwc", dir.path().join("desk.db").display());
    let db = sqlx::sqlite::SqlitePoolOptions::new()
        .max_connections(4)
        .connect_with(
            url.parse::<sqlx::sqlite::SqliteConnectOptions>()
                .unwrap()
                .journal_mode(sqlx::sqlite::SqliteJournalMode::Wal)
                .busy_timeout(std::time::Duration::from_secs(5)),
        )
        .await
        .unwrap();
    sqlx::migrate!("./migrations").run(&db).await.unwrap();
    let srv = server(state_over(db).await).await;
    call(&srv, true, Method::PUT, "/api/v1/desk/session", json(session(0, 1))).await;

    for round in 1..=10 {
        let (a, b) = futures::join!(
            call(&srv, true, Method::PUT, "/api/v1/desk/session", json(session(round, 2))),
            call(&srv, true, Method::PUT, "/api/v1/desk/session", json(session(round, 3))),
        );
        let mut statuses = [a.0, b.0];
        statuses.sort_unstable();
        assert_eq!(statuses, [200, 409], "round {round}: {} {}", a.1, b.1);
    }
}

#[ntex::test]
async fn a_refused_session_says_why() {
    let srv = server(state().await).await;
    let mut bad = session(0, 1);
    bad["windows"][0]["app_id"] = serde_json::json!("Files!");
    let (status, body, _) = call(&srv, true, Method::PUT, "/api/v1/desk/session", json(bad)).await;
    assert_eq!(status, 400);
    assert_eq!(body, serde_json::json!({ "error": "invalidAppId", "index": 0 }));
    let (status, _, _) = call(&srv, true, Method::GET, "/api/v1/desk/session?device=../x", None).await;
    assert_eq!(status, 400);
}

#[ntex::test]
async fn notifications_are_marked_read() {
    let state = state().await;
    let srv = server(state.clone()).await;
    for i in 0..3 {
        state
            .desk
            .notify(&state.db, Level::Warning, Source::Alert, "High CPU", &format!("cpu {i}"), None)
            .await
            .unwrap();
    }
    let (_, body, _) = call(&srv, true, Method::GET, "/api/v1/desk/notifications", None).await;
    assert_eq!(body["unread"], 3);
    let list = body["notifications"].as_array().unwrap();
    assert_eq!(list[0]["body"], "cpu 2", "newest first");
    let newest = list[0]["id"].as_i64().unwrap();

    let (status, _, _) = call(
        &srv,
        true,
        Method::POST,
        "/api/v1/desk/notifications/read",
        json(serde_json::json!({ "ids": [newest, 999_999] })),
    )
    .await;
    assert_eq!(status, 204);
    let (_, body, _) = call(&srv, true, Method::GET, "/api/v1/desk/notifications", None).await;
    assert_eq!(body["unread"], 2);
    assert_eq!(body["notifications"][0]["read"], true);

    call(&srv, true, Method::POST, "/api/v1/desk/notifications/read", json(serde_json::json!({ "all": true }))).await;
    let (_, body, _) = call(&srv, true, Method::GET, "/api/v1/desk/notifications", None).await;
    assert_eq!(body["unread"], 0);
}

#[ntex::test]
async fn stack_notification_stores_and_sends_kind_and_params() {
    let state = state().await;
    let srv = server(state.clone()).await;
    let params = serde_json::json!({ "app": "example.web", "titles": { "en": "Example" }, "services": ["web"] });
    let mut events = state.desk.subscribe();
    state
        .desk
        .notify(
            &state.db,
            Level::Warning,
            Source::Stack("example.web".into()),
            "Example is down",
            "Not running: web.",
            Some(("stack.down", &params)),
        )
        .await
        .unwrap();

    let DeskEvent::Notification(notification) = events.recv().await.unwrap() else {
        panic!("expected notification event");
    };
    assert_eq!(notification.kind.as_deref(), Some("stack.down"));
    assert_eq!(notification.params.as_ref(), Some(&params));

    let stored: (Option<String>, Option<String>) =
        sqlx::query_as("SELECT kind, params FROM desk_notification WHERE id = ?")
            .bind(notification.id)
            .fetch_one(&state.db)
            .await
            .unwrap();
    assert_eq!(stored.0.as_deref(), Some("stack.down"));
    assert_eq!(stored.1.as_deref(), Some(params.to_string().as_str()));

    let (_, body, _) = call(&srv, true, Method::GET, "/api/v1/desk/notifications", None).await;
    assert_eq!(body["notifications"][0]["kind"], "stack.down");
    assert_eq!(body["notifications"][0]["params"], params);
}

fn cpu_over(value: &str) -> Firing {
    Firing {
        rule: "High CPU".into(),
        monitor_type: "cpu".into(),
        matcher: ">".into(),
        threshold: "90%".into(),
        value: value.into(),
        message: format!("Alert: High CPU - > {value} (threshold: 90%)"),
    }
}

#[ntex::test]
async fn a_rule_notifies_when_it_starts_firing_not_every_cycle() {
    let state = state().await;
    state.desk.rules_checked(&state.db, vec![cpu_over("95.00%")]).await;
    state.desk.rules_checked(&state.db, vec![cpu_over("96.00%")]).await;
    state.desk.rules_checked(&state.db, vec![]).await;
    state.desk.rules_checked(&state.db, vec![cpu_over("97.00%")]).await;
    let count: i64 = sqlx::query_scalar("SELECT COUNT(*) FROM desk_notification")
        .fetch_one(&state.db)
        .await
        .unwrap();
    assert_eq!(count, 2);
}

/// `/alerts`: what fires now, with the last reading and since when it has
/// been firing without a break.
#[ntex::test]
async fn alerts_say_what_fires_now_and_since_when() {
    let state = state().await;
    let srv = server(state.clone()).await;

    let (status, body, _) = call(&srv, true, Method::GET, "/api/v1/alerts", None).await;
    assert_eq!(status, 200);
    assert_eq!(body, serde_json::json!({ "checked_at": null, "alerts": [] }));
    let (status, _, _) = call(&srv, false, Method::GET, "/api/v1/alerts", None).await;
    assert_eq!(status, 401);

    state.desk.rules_checked(&state.db, vec![cpu_over("95.00%")]).await;
    let (_, first, _) = call(&srv, true, Method::GET, "/api/v1/alerts", None).await;
    let since = first["alerts"][0]["since"].clone();
    assert_eq!(first["checked_at"], since);

    state.desk.rules_checked(&state.db, vec![cpu_over("96.00%")]).await;
    let (_, body, _) = call(&srv, true, Method::GET, "/api/v1/alerts", None).await;
    assert_eq!(
        body["alerts"],
        serde_json::json!([{
            "rule": "High CPU",
            "monitor_type": "cpu",
            "matcher": ">",
            "threshold": "90%",
            "value": "96.00%",
            "since": since,
        }]),
    );

    state.desk.rules_checked(&state.db, vec![]).await;
    let (_, body, _) = call(&srv, true, Method::GET, "/api/v1/alerts", None).await;
    assert_eq!(body["alerts"], serde_json::json!([]));
    assert!(body["checked_at"].is_string());
}

#[ntex::test]
async fn old_notifications_make_room() {
    let state = state().await;
    for i in 0..(desk::KEEP_NOTIFICATIONS + 5) {
        state
            .desk
            .notify(&state.db, Level::Info, Source::Alert, "r", &i.to_string(), None)
            .await
            .unwrap();
    }
    let (count, oldest): (i64, String) = sqlx::query_as(
        "SELECT COUNT(*), (SELECT body FROM desk_notification ORDER BY id LIMIT 1) FROM desk_notification",
    )
    .fetch_one(&state.db)
    .await
    .unwrap();
    assert_eq!(count, desk::KEEP_NOTIFICATIONS);
    assert_eq!(oldest, "5");
}

/// The event stream carries notifications and session writes.
#[ntex::test]
async fn events_reach_the_reader() {
    use futures::StreamExt;

    let state = state().await;
    let srv = server(state.clone()).await;
    let mut events = srv
        .get("/api/v1/desk/events")
        .header("Authorization", format!("Bearer {}", generate_token(SECRET).unwrap()))
        .send()
        .await
        .unwrap();
    assert_eq!(events.headers().get("content-type").unwrap(), "text/event-stream");

    call(&srv, true, Method::PUT, "/api/v1/desk/session", json(session(0, 1))).await;
    state
        .desk
        .notify(&state.db, Level::Warning, Source::Alert, "High CPU", "cpu 99%", None)
        .await
        .unwrap();

    async fn read_until(resp: &mut ntex::client::ClientResponse, needle: &str) -> String {
        let mut seen = String::new();
        let deadline = tokio::time::Instant::now() + std::time::Duration::from_secs(5);
        while !seen.contains(needle) {
            let chunk = tokio::time::timeout_at(deadline, resp.next())
                .await
                .expect("event in time")
                .expect("stream open")
                .unwrap();
            seen.push_str(&String::from_utf8_lossy(&chunk));
        }
        seen
    }

    let seen = read_until(&mut events, "\"notification\"").await;
    assert!(seen.contains("\"type\":\"session\""), "{seen}");
}

#[ntex::test]
async fn app_storage_is_per_app_and_bounded() {
    let srv = server(state().await).await;
    let base = "/api/v1/desk/apps/acme.notes/storage";
    let (status, _, _) = call(&srv, false, Method::GET, base, None).await;
    assert_eq!(status, 401);

    let (status, _, _) =
        call(&srv, true, Method::PUT, &format!("{base}?key=draft"), json(serde_json::json!({ "text": "hi" }))).await;
    assert_eq!(status, 204);
    let (status, _, _) = call(&srv, true, Method::PUT, &format!("{base}?key=count"), json(serde_json::json!(3))).await;
    assert_eq!(status, 204);
    let (_, body, _) = call(&srv, true, Method::GET, base, None).await;
    assert_eq!(body, serde_json::json!({ "items": { "count": 3, "draft": { "text": "hi" } } }));

    // Another app sees nothing of it.
    let (_, other_app, _) = call(&srv, true, Method::GET, "/api/v1/desk/apps/serverbox.files/storage", None).await;
    assert_eq!(other_app["items"], serde_json::json!({}));

    // Past the app's bound: refused, and nothing of it kept.
    let big = "x".repeat(200 << 10);
    let (status, _, _) = call(&srv, true, Method::PUT, &format!("{base}?key=a"), json(serde_json::json!(big))).await;
    assert_eq!(status, 204);
    let (status, body, _) =
        call(&srv, true, Method::PUT, &format!("{base}?key=b"), json(serde_json::json!("y".repeat(100 << 10)))).await;
    assert_eq!((status, body["error"].as_str()), (413, Some("tooLarge")));
    let (_, body, _) = call(&srv, true, Method::GET, base, None).await;
    assert!(body["items"].get("b").is_none());

    let (status, _, _) = call(&srv, true, Method::DELETE, &format!("{base}?key=a"), None).await;
    assert_eq!(status, 204);
    let (_, body, _) = call(&srv, true, Method::GET, base, None).await;
    assert!(body["items"].get("a").is_none());

    for path in ["/api/v1/desk/apps/acme.Notes/storage", "/api/v1/desk/apps/acme.notes/storage?key="] {
        let (status, _, _) = call(&srv, true, Method::PUT, path, json(serde_json::json!(1))).await;
        assert_eq!(status, 400, "{path}");
    }
}

#[ntex::test]
async fn app_storage_is_bounded_across_apps() {
    let srv = server(state().await).await;
    // Under each app's own bound, past the account's once there are enough apps.
    let value = json(serde_json::json!("x".repeat(250 << 10)));
    let mut refused_at = None;
    for i in 0..20 {
        let path = format!("/api/v1/desk/apps/acme.app{i}/storage?key=k");
        let (status, _, _) = call(&srv, true, Method::PUT, &path, value.clone()).await;
        if status == 413 {
            refused_at = Some(i);
            break;
        }
        assert_eq!(status, 204);
    }
    assert_eq!(refused_at, Some(16));
}
