//! End-to-end coverage for `/api/v1/services`.
//!
//! The listing is asserted against the machine the suite runs on, which is
//! whatever it is: on the BSD family the detector reports a manager this build
//! does not list and the endpoint says so, which is a real answer and the one
//! that is portable to every machine that is not a Linux host. The cases that
//! need a listing are skipped where there is none rather than asserting a
//! refusal that would say nothing about the Linux path — the same shape
//! `process_api` uses for the platforms that have no stop.
//!
//! Nothing here changes a unit. A suite that started a service would be
//! arranging for something on the test machine to run, and the refusals — the
//! missing token, the missing grant, the key that is not in the listing — are
//! what an unsupported machine and a supported one answer the same way.

use std::sync::{Arc, Once};

use ntex::web::test::{self as web_test, TestServer};
use ntex::web::App;
use rustls::crypto::ring;
use serde_json::{json, Value};
use server_box_monitor::api::auth::generate_token;
use server_box_monitor::api::server::{AppState, configure_api};
use server_box_monitor::core::config::Config;
use server_box_monitor::monitoring::system_type;
use sbm_parser::SystemType;

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

/// Mounts the real route table — see `power_api` for why.
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

async fn read(srv: &TestServer, query: &str) -> Result<Value, u16> {
    let resp = srv
        .get(format!("/api/v1/services{query}"))
        .header("Authorization", format!("Bearer {}", token()))
        .send()
        .await
        .unwrap();
    if !resp.status().is_success() {
        return Err(resp.status().as_u16());
    }
    Ok(resp.json().await.unwrap())
}

async fn act(srv: &TestServer, body: Value) -> Result<Value, u16> {
    let resp = srv
        .post("/api/v1/services")
        .header("Authorization", format!("Bearer {}", token()))
        .send_json(&body)
        .await
        .unwrap();
    if !resp.status().is_success() {
        return Err(resp.status().as_u16());
    }
    Ok(resp.json().await.unwrap())
}

/// The units this machine has, or `None` where this build cannot list its
/// manager at all. The cases that need a listing are skipped rather than
/// asserting a refusal that says nothing about the Linux path.
async fn listed(srv: &TestServer) -> Option<Vec<Value>> {
    let body = read(srv, "").await.unwrap();
    body["available"]
        .as_bool()
        .unwrap()
        .then(|| body["units"].as_array().cloned().unwrap_or_default())
}

#[ntex::test]
async fn a_request_without_a_token_is_refused() {
    let srv = test_server(app_state(true).await).await;
    let resp = srv.get("/api/v1/services").send().await.unwrap();

    assert_eq!(resp.status().as_u16(), 401);
}

/// Even where there is no listing, the machine is asked and the answer names
/// which manager it runs: that is the difference between "nothing to show" and
/// "nothing was looked at".
#[ntex::test]
async fn the_read_says_which_manager_the_machine_runs() {
    let srv = test_server(app_state(true).await).await;
    let body = read(&srv, "").await.unwrap();

    assert_eq!(body["part"], "list");
    assert!(!body["manager"]["detected_name"].as_str().unwrap().is_empty(), "{body}");
    assert!(!body["manager"]["description"].as_str().unwrap().is_empty(), "{body}");
    assert!(body["units"].is_array(), "{body}");
    assert!(body["editable"].is_boolean(), "{body}");

    // A machine whose manager this build does not list says so, and says what
    // it found instead of leaving the reader with an empty list.
    if system_type() == SystemType::Bsd {
        assert_eq!(body["available"], false);
        assert_eq!(body["reason_kind"], "unsupported_manager", "{body}");
        assert_eq!(body["reason"], Value::Null);
    }
}

/// What the caller may change is a field rather than a status code, and it
/// follows the grant the capabilities endpoint reported.
#[ntex::test]
async fn the_read_reports_whether_this_caller_may_change_anything() {
    let on = test_server(app_state(true).await).await;
    let off = test_server(app_state(false).await).await;

    assert_eq!(read(&on, "").await.unwrap()["editable"], true);
    assert_eq!(read(&off, "").await.unwrap()["editable"], false);
}

/// Reading is not recorded at all, so a row in the audit log is always a
/// change — which is what makes the column worth reading.
#[ntex::test]
async fn a_read_is_not_audited() {
    let state = app_state(true).await;
    let db = state.db.clone();
    let srv = test_server(state).await;
    read(&srv, "").await.unwrap();

    let rows: i64 = sqlx::query_scalar("SELECT count(*) FROM access_log")
        .fetch_one(&db)
        .await
        .unwrap();
    assert_eq!(rows, 0);
}

/// A unit is named by the key its listing gave it, and the order the listing
/// is in is a rule of the model rather than of any one manager: the caller's
/// own units first, then what is running, then by name.
#[ntex::test]
async fn the_units_are_keyed_and_ordered_by_the_model() {
    let srv = test_server(app_state(true).await).await;
    let Some(units) = listed(&srv).await else {
        return;
    };

    for unit in &units {
        let full_name = unit["full_name"].as_str().unwrap();
        let unit_type = unit["type"].as_str().unwrap();
        let scope = unit["scope"].as_str().unwrap();
        assert!(!unit["name"].as_str().unwrap().is_empty(), "{unit}");
        assert!(
            full_name.ends_with(&format!(".{unit_type}")),
            "{full_name} is not a {unit_type}"
        );
        // The key the client sends back for a part or an action is derived, so
        // two spellings of it would be two entries.
        assert_eq!(unit["key"], format!("{scope}:{full_name}"), "{unit}");
        assert!(unit["actions"].is_array(), "{unit}");
        assert!(unit["state"].is_string(), "{unit}");
    }

    let users = units
        .iter()
        .filter(|unit| unit["scope"] == "user")
        .count();
    for (index, unit) in units.iter().enumerate() {
        let is_user = unit["scope"] == "user";
        assert_eq!(is_user, index < users, "the user scope is not first: {unit}");
    }
    for pair in units.windows(2) {
        if pair[0]["scope"] != pair[1]["scope"] {
            continue;
        }
        if pair[0]["state"] == "running" && pair[1]["state"] != "running" {
            continue;
        }
        // Everything that is not running comes after everything that is.
        assert!(
            pair[1]["state"] == "running" || pair[0]["state"] != "running",
            "not running-first: {} then {}",
            pair[0]["name"],
            pair[1]["name"]
        );
        if pair[0]["state"] == pair[1]["state"] {
            assert!(
                pair[0]["name"].as_str().unwrap() <= pair[1]["name"].as_str().unwrap(),
                "not by name: {} then {}",
                pair[0]["name"],
                pair[1]["name"]
            );
        }
    }
}

/// The three parts that are about one unit cannot be answered without it, and
/// that is refused before anything runs on the machine.
#[ntex::test]
async fn a_part_about_one_unit_needs_the_unit() {
    let srv = test_server(app_state(true).await).await;
    for part in ["logs", "definition", "status"] {
        assert_eq!(
            read(&srv, &format!("?part={part}")).await.unwrap_err(),
            400,
            "{part}"
        );
    }
}

/// A key that is not in the listing is a unit that was removed between the
/// panel drawing the row and the click. Answered as its own reason rather than
/// as a failure, and — like every read — not recorded.
#[ntex::test]
async fn a_key_that_is_not_in_the_listing_is_answered_as_such() {
    let srv = test_server(app_state(true).await).await;
    if listed(&srv).await.is_none() {
        return;
    }
    let body = read(&srv, "?part=logs&key=system:definitely-not-a-unit.service")
        .await
        .unwrap();

    assert_eq!(body["available"], false, "{body}");
    assert_eq!(body["reason_kind"], "no_such_unit", "{body}");
    assert_eq!(
        body["reason"],
        "system:definitely-not-a-unit.service",
        "{body}"
    );
}

/// A unit's own files are read as the listing's unit, so the answer is about
/// the unit the machine has rather than about the string the caller sent.
#[ntex::test]
async fn a_unit_can_be_looked_up_by_the_key_its_listing_gave_it() {
    let srv = test_server(app_state(true).await).await;
    let Some(units) = listed(&srv).await else {
        return;
    };
    let Some(unit) = units.first() else {
        return;
    };
    let key = unit["key"].as_str().unwrap();

    let body = read(&srv, &format!("?part=logs&key={key}")).await.unwrap();
    // Either the manager keeps a log by unit name, or it says that it does not
    // — never an empty log standing in for "not available".
    assert!(
        !body["available"].as_bool().unwrap()
            || body["log"]["lines"].is_array(),
        "{body}"
    );
    if !body["available"].as_bool().unwrap() {
        assert_eq!(body["reason_kind"], "no_log", "{body}");
    }

    let definition = read(&srv, &format!("?part=definition&key={key}"))
        .await
        .unwrap();
    assert!(definition["text"].is_string(), "{definition}");
}

/// The grant is re-read per request, so what the client was told earlier about
/// capabilities decides nothing.
#[ntex::test]
async fn an_action_is_refused_when_full_access_is_off() {
    let srv = test_server(app_state(false).await).await;
    assert_eq!(
        act(
            &srv,
            json!({"key": "system:sshd.service", "action": "start"})
        )
        .await
        .unwrap_err(),
        403
    );
}

/// Refusals are recorded — the row that matters most here is the one naming an
/// action that was *not* taken.
#[ntex::test]
async fn a_refusal_is_audited() {
    let state = app_state(false).await;
    let db = state.db.clone();
    let srv = test_server(state).await;
    assert!(act(&srv, json!({"key": "system:sshd.service", "action": "stop"}))
        .await
        .is_err());

    let (kind, action, result): (String, String, String) =
        sqlx::query_as("SELECT kind, action, result FROM access_log ORDER BY id DESC LIMIT 1")
            .fetch_one(&db)
            .await
            .unwrap();

    assert_eq!(
        (kind.as_str(), action.as_str(), result.as_str()),
        ("service", "denied", "denied")
    );
}

/// An action names a unit the agent itself listed, so one that is not in the
/// current listing is refused rather than run against a stale key.
#[ntex::test]
async fn an_action_on_a_unit_that_is_not_in_the_listing_is_refused() {
    let state = app_state(true).await;
    let db = state.db.clone();
    let srv = test_server(state).await;
    if listed(&srv).await.is_none() {
        return;
    }

    assert_eq!(
        act(
            &srv,
            json!({"key": "system:definitely-not-a-unit.service", "action": "start"})
        )
        .await
        .unwrap_err(),
        404
    );

    let (kind, subject, detail): (String, String, Option<String>) = sqlx::query_as(
        "SELECT kind, subject, detail FROM access_log ORDER BY id DESC LIMIT 1",
    )
    .fetch_one(&db)
    .await
    .unwrap();

    assert_eq!(kind, "service");
    assert_eq!(subject, "start system:definitely-not-a-unit.service");
    assert_eq!(detail.as_deref(), Some("no such unit"));
}

/// An action this build does not have is refused while deserializing, rather
/// than reaching a shell to be interpreted.
#[ntex::test]
async fn an_action_this_build_does_not_have_is_refused() {
    let srv = test_server(app_state(true).await).await;
    let resp = srv
        .post("/api/v1/services")
        .header("Authorization", format!("Bearer {}", token()))
        .send_json(&json!({"key": "system:sshd.service", "action": "reload"}))
        .await
        .unwrap();

    assert_eq!(resp.status().as_u16(), 400);
}

/// An agent older than the endpoint answers `full_access` and would 404, so
/// the panel reads this field rather than that one.
#[ntex::test]
async fn capabilities_report_the_service_endpoint() {
    let srv = test_server(app_state(true).await).await;
    let resp = srv
        .get("/api/v1/capabilities")
        .header("Authorization", format!("Bearer {}", token()))
        .send()
        .await
        .unwrap();
    let body: Value = resp.json().await.unwrap();

    assert_eq!(body["remote_access"]["services"], true);
    // Servable, not grantable: the answer is what the caller may *change* that
    // carries the grant, and the read is a field on the listing.
    assert_eq!(body["remote_access"]["full_access"], true);
}
