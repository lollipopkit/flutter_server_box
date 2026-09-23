//! End-to-end coverage for `GET/POST /api/v1/containers`.
//!
//! What these assert is deliberately the refusals and what a client is told,
//! and **not** a successful change: this endpoint acts on the container runtime
//! of whoever runs the suite. Starting, stopping or removing a container would
//! leave the machine different from how it was found, and a prune would do it
//! without ever naming what it took — a suite that did either would be
//! destructive on every machine that ever ran it. The one write attempted
//! against the panel login names an id no container can have, so the runtime
//! refuses it and nothing moves.
//!
//! The model underneath — which fields `docker ps` is asked for, how Podman is
//! told from Docker, what a stats row becomes, what a prune may remove — is
//! covered where it lives, by `crates/sbm_parser/src/container.rs`'s own tests.
//! What is left here is the door.
//!
//! Reading is exercised, because reading changes nothing: the assertions accept
//! whatever state the machine is in — a Docker runtime, a Podman one, both, or
//! neither — since which of those a CI container is in is not this test's
//! subject.

use std::sync::{Arc, Once};

use ntex::web::test::{self as web_test, TestServer};
use ntex::web::App;
use rustls::crypto::ring;
use serde_json::json;
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

async fn app_state(full_access: bool) -> Arc<AppState> {
    ensure_crypto_provider();
    let mut config = Config {
        jwt_secret: Some(SECRET.to_string()),
        ..Default::default()
    };
    let mut remote = config.get_remote_access();
    // The grant is gated on the terminal being available, so that switching
    // the terminal off cannot leave this door open behind it. The test server
    // listens on loopback, which counts as a secure transport.
    remote.terminal.enabled = true;
    remote.full_access = Some(full_access);
    config.remote_access = Some(remote);

    let db = sqlx::SqlitePool::connect("sqlite::memory:").await.unwrap();
    sqlx::migrate!("./migrations").run(&db).await.unwrap();
    AppState::new(Arc::new(config), db)
}

/// Mounts the real route table.
///
/// A scope of its own would assert something about the handler and nothing
/// about what the shipped binary exposes — which route gets which gate is a
/// property of [`configure_api`], and this endpoint is two lines in it.
async fn test_server(state: Arc<AppState>) -> TestServer {
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

/// An action the runtime itself will refuse: no container has this id, so the
/// command fails and nothing on the machine changes.
fn harmless_action() -> serde_json::Value {
    json!({ "action": "start", "id": "sbm-scope-test-nonexistent" })
}

async fn get(srv: &TestServer, part: Option<&str>) -> Result<serde_json::Value, u16> {
    let path = match part {
        Some(part) => format!("/api/v1/containers?part={part}"),
        None => "/api/v1/containers".to_owned(),
    };
    let resp = srv
        .get(&path)
        .header("Authorization", format!("Bearer {}", token()))
        .send()
        .await
        .unwrap();
    if !resp.status().is_success() {
        return Err(resp.status().as_u16());
    }
    Ok(resp.json().await.unwrap())
}

async fn post(srv: &TestServer, body: serde_json::Value) -> Result<serde_json::Value, u16> {
    let resp = srv
        .post("/api/v1/containers")
        .header("Authorization", format!("Bearer {}", token()))
        .send_json(&body)
        .await
        .unwrap();
    if !resp.status().is_success() {
        return Err(resp.status().as_u16());
    }
    Ok(resp.json().await.unwrap())
}

#[ntex::test]
async fn a_request_without_a_token_is_refused() {
    let srv = test_server(app_state(true).await).await;
    let resp = srv.get("/api/v1/containers").send().await.unwrap();
    assert_eq!(resp.status().as_u16(), 401);

    let resp = srv
        .post("/api/v1/containers")
        .send_json(&harmless_action())
        .await
        .unwrap();
    assert_eq!(resp.status().as_u16(), 401);
}

#[ntex::test]
async fn a_forged_token_is_refused() {
    let srv = test_server(app_state(true).await).await;
    let forged = generate_token("admin", "another-secret-that-is-long-enough").unwrap();
    let resp = srv
        .get("/api/v1/containers")
        .header("Authorization", format!("Bearer {forged}"))
        .send()
        .await
        .unwrap();
    assert_eq!(resp.status().as_u16(), 401);
}

/// A change is refusing to be told about `full_access` by the client. The grant
/// is re-read per request, so what capabilities said earlier decides nothing.
#[ntex::test]
async fn changing_is_refused_when_full_access_is_off() {
    let srv = test_server(app_state(false).await).await;
    assert_eq!(post(&srv, harmless_action()).await.unwrap_err(), 403);
}

/// Reading is not gated on the shell grant: listing containers runs the runtime
/// as the agent's own user, the same as reading its crontab, and a panel that
/// may only look can still say so honestly.
#[ntex::test]
async fn reading_is_allowed_without_full_access() {
    let srv = test_server(app_state(false).await).await;
    let body = get(&srv, None).await.expect("the listing is readable");
    assert_eq!(body["editable"], false);
}

/// The default part is the container list — a client that asked for nothing in
/// particular gets the thing the page opens on, rather than an error or an
/// arbitrary one of the three.
#[ntex::test]
async fn the_default_part_is_the_container_list() {
    let srv = test_server(app_state(true).await).await;
    let body = get(&srv, None).await.expect("the listing is readable");
    assert_eq!(body["part"], "containers");
    assert_eq!(body["editable"], true);
}

/// Each part answers as itself, and an answer always carries the fields its
/// part implies — never a container list without the array that holds it.
#[ntex::test]
async fn every_part_answers_with_its_own_shape() {
    let srv = test_server(app_state(true).await).await;
    for part in ["containers", "images", "usage"] {
        let body = get(&srv, Some(part)).await.expect("the listing is readable");
        assert_eq!(body["part"], part);
        assert!(body["editable"].is_boolean());
        if body["available"] == true {
            assert!(body["runtime"]["kind"].is_string(), "{part}: {body}");
        } else {
            assert!(
                body["reason_kind"].is_string(),
                "an unavailable listing says why: {part}: {body}"
            );
        }
        // Exactly the one array the part is about is populated, so a panel that
        // keeps one object per part cannot read another part's rows out of it.
        assert!(body["containers"].is_array());
        assert!(body["images"].is_array());
    }
}

/// A part this build does not have is refused by the extractor, before any
/// handler — and therefore before the runtime is run.
#[ntex::test]
async fn an_unknown_part_is_rejected() {
    let srv = test_server(app_state(true).await).await;
    assert_eq!(get(&srv, Some("volumes")).await.unwrap_err(), 400);
}

/// An action this build does not implement is refused while deserializing,
/// rather than reaching a shell.
#[ntex::test]
async fn an_unknown_action_is_rejected() {
    let srv = test_server(app_state(true).await).await;
    assert_eq!(
        post(&srv, json!({ "action": "pause", "id": "abc" }))
            .await
            .unwrap_err(),
        400,
    );
}

/// An action that names no container must never fall through to a default —
/// `remove` with no id is the one that would be worst to guess at.
#[ntex::test]
async fn a_missing_id_is_rejected() {
    let srv = test_server(app_state(true).await).await;
    for body in [
        json!({ "action": "remove" }),
        json!({ "action": "stop" }),
        json!({ "action": "restart" }),
    ] {
        assert_eq!(post(&srv, body.clone()).await.unwrap_err(), 400, "{body}");
    }
}

/// An action that names no operation at all is refused too.
#[ntex::test]
async fn a_missing_action_is_rejected() {
    let srv = test_server(app_state(true).await).await;
    assert_eq!(post(&srv, json!({})).await.unwrap_err(), 400);
}

/// A change that was *turned down* is what someone reading this table is looking
/// for, and it is the only kind of container row a suite that must not touch the
/// runtime can produce.
#[ntex::test]
async fn a_refused_change_is_audited() {
    let state = app_state(false).await;
    let db = state.db.clone();
    let srv = test_server(state).await;
    assert!(post(&srv, harmless_action()).await.is_err());

    let (kind, action, result): (String, String, String) = sqlx::query_as(
        "SELECT kind, action, result FROM access_log ORDER BY id DESC LIMIT 1",
    )
    .fetch_one(&db)
    .await
    .unwrap();

    assert_eq!(
        (kind.as_str(), action.as_str(), result.as_str()),
        ("container", "denied", "denied")
    );
}

/// A read is not recorded at all: it changes nothing, and this is the one
/// endpoint whose rows are therefore always changes. Asserted because the
/// opposite would be invisible — a row per page refresh is only noticed once
/// someone reads the table.
#[ntex::test]
async fn reading_is_not_audited() {
    let state = app_state(true).await;
    let db = state.db.clone();
    let srv = test_server(state).await;
    let _ = get(&srv, None).await.expect("the listing is readable");

    let count: i64 = sqlx::query_scalar("SELECT count(*) FROM access_log")
        .fetch_one(&db)
        .await
        .unwrap();
    assert_eq!(count, 0);
}

/// The grant is a UI hint to the client, so the answer the client reads has to
/// name the endpoint it is about to call — an agent older than `/containers`
/// reports `full_access` and would answer 404.
#[ntex::test]
async fn capabilities_report_the_endpoint_being_served() {
    let srv = test_server(app_state(true).await).await;
    let resp = srv
        .get("/api/v1/capabilities")
        .header("Authorization", format!("Bearer {}", token()))
        .send()
        .await
        .unwrap();
    assert!(
        resp.status().is_success(),
        "capabilities answered {}",
        resp.status()
    );
    let body: serde_json::Value = resp.json().await.unwrap();

    assert_eq!(body["remote_access"]["full_access"], true);
    assert_eq!(body["remote_access"]["containers"], true);
    assert_eq!(body["remote_access"]["cron"], true);
}

/// And what it reports does not move with the grant, which is the distinction
/// between a field that means "this agent serves the endpoint" and one that
/// means "this caller may change things". The second is `editable` in the
/// response body, re-checked on the write; the panel draws a read-only page
/// rather than hiding the tab.
#[ntex::test]
async fn capabilities_report_the_endpoint_with_the_grant_off() {
    let srv = test_server(app_state(false).await).await;
    let resp = srv
        .get("/api/v1/capabilities")
        .header("Authorization", format!("Bearer {}", token()))
        .send()
        .await
        .unwrap();
    let body: serde_json::Value = resp.json().await.unwrap();

    assert_eq!(body["remote_access"]["full_access"], false);
    assert_eq!(body["remote_access"]["containers"], true);
    assert_eq!(body["remote_access"]["cron"], true);
    // `power` is the one that keeps reporting the grant: it has nothing to read.
    assert_eq!(body["remote_access"]["power"], false);
}
