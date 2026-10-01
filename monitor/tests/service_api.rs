//! `/api/v1/services`, against the real route table.
//!
//! The listing is asserted against the machine the suite runs on, whatever it
//! is: on the BSD family the detector reports a manager this build does not
//! list and the endpoint says so, which is a real answer. The cases that need
//! a listing are skipped where there is none rather than asserting a refusal
//! that says nothing about the Linux path.
//!
//! Nothing here changes a unit: the refusals — no token, no grant, a key not
//! in the listing — are answered the same way on every machine.

mod common;

use ntex::http::Method;
use ntex::web::test::TestServer;
use sbm_parser::SystemType;
use serde_json::{Value, json};
use server_box_monitor::monitoring::system_type;

use common::machine::{audit, call, server};

async fn read(srv: &TestServer, query: &str) -> (u16, Value) {
    call(srv, Some("admin"), Method::GET, &format!("/api/v1/services{query}"), None).await
}

async fn act(srv: &TestServer, user: &str, body: Value) -> (u16, Value) {
    call(srv, Some(user), Method::POST, "/api/v1/services", Some(body)).await
}

/// The units this machine has, or `None` where this build cannot list its
/// manager at all.
async fn listed(srv: &TestServer) -> Option<Vec<Value>> {
    let (_, body) = read(srv, "").await;
    body["available"]
        .as_bool()
        .unwrap()
        .then(|| body["units"].as_array().cloned().unwrap_or_default())
}

#[ntex::test]
async fn both_halves_need_the_shell_grant() {
    let (srv, db) = server().await;
    let (status, _) = call(&srv, None, Method::GET, "/api/v1/services", None).await;
    assert_eq!(status, 401);

    let (status, body) = call(&srv, Some("viewer"), Method::GET, "/api/v1/services", None).await;
    assert_eq!((status, body["error"].as_str()), (403, Some("forbidden")));
    let (status, _) = act(&srv, "viewer", json!({"key": "system:sshd.service", "action": "stop"})).await;
    assert_eq!(status, 403);

    let rows = audit(&db).await;
    assert_eq!(rows.len(), 2, "{rows:?}");
    assert!(rows.iter().all(|(action, _, subject, _)| action == "denied" && subject.as_deref() == Some("viewer")));
    assert_eq!(rows[1].3.as_deref(), Some("service stop system:sshd.service: shell not_granted"));
}

/// Even where there is no listing, the answer names which manager the machine
/// runs: the difference between "nothing to show" and "nothing was looked at".
/// A read is not audited, so a row in the log is always an action.
#[ntex::test]
async fn the_read_says_which_manager_the_machine_runs() {
    let (srv, db) = server().await;
    let (status, body) = read(&srv, "").await;
    assert_eq!(status, 200, "{body}");

    assert_eq!(body["part"], "list");
    assert!(!body["manager"]["detected_name"].as_str().unwrap().is_empty(), "{body}");
    assert!(!body["manager"]["description"].as_str().unwrap().is_empty(), "{body}");
    assert!(body["units"].is_array(), "{body}");
    if system_type() == SystemType::Bsd {
        assert_eq!(body["available"], false);
        assert_eq!(body["reason_kind"], "unsupported_manager", "{body}");
    }
    assert!(audit(&db).await.is_empty());
}

/// The key a client sends back is derived from the listing, and the order is
/// the model's: the caller's own units first, then what is running, then by
/// name.
#[ntex::test]
async fn the_units_are_keyed_and_ordered_by_the_model() {
    let (srv, _) = server().await;
    let Some(units) = listed(&srv).await else {
        return;
    };
    for unit in &units {
        let full_name = unit["full_name"].as_str().unwrap();
        let unit_type = unit["type"].as_str().unwrap();
        let scope = unit["scope"].as_str().unwrap();
        assert!(full_name.ends_with(&format!(".{unit_type}")), "{full_name} is not a {unit_type}");
        assert_eq!(unit["key"], format!("{scope}:{full_name}"), "{unit}");
        assert!(unit["actions"].is_array() && unit["state"].is_string(), "{unit}");
    }
    let users = units.iter().filter(|unit| unit["scope"] == "user").count();
    for (index, unit) in units.iter().enumerate() {
        assert_eq!(unit["scope"] == "user", index < users, "the user scope is not first: {unit}");
    }
    for pair in units.windows(2) {
        if pair[0]["scope"] != pair[1]["scope"] {
            continue;
        }
        assert!(
            pair[1]["state"] == "running" || pair[0]["state"] != "running" || pair[0]["state"] == pair[1]["state"],
            "not running-first: {} then {}",
            pair[0]["name"],
            pair[1]["name"]
        );
    }
}

/// The parts about one unit cannot be answered without it: refused before
/// anything runs.
#[ntex::test]
async fn a_part_about_one_unit_needs_the_unit() {
    let (srv, _) = server().await;
    for part in ["logs", "definition", "status"] {
        assert_eq!(read(&srv, &format!("?part={part}")).await.0, 400, "{part}");
    }
}

/// A key not in the listing is a unit removed between the row being drawn and
/// the click: its own reason for a read, a 404 for an action.
#[ntex::test]
async fn a_key_that_is_not_in_the_listing_is_answered_as_such() {
    let (srv, db) = server().await;
    if listed(&srv).await.is_none() {
        return;
    }
    let (_, body) = read(&srv, "?part=logs&key=system:definitely-not-a-unit.service").await;
    assert_eq!((&body["available"], &body["reason_kind"]), (&json!(false), &json!("no_such_unit")), "{body}");

    let (status, _) = act(&srv, "admin", json!({"key": "system:definitely-not-a-unit.service", "action": "start"})).await;
    assert_eq!(status, 404);
    let rows = audit(&db).await;
    let last = rows.last().unwrap();
    assert_eq!((last.0.as_str(), last.1.as_str()), ("denied", "denied"));
    assert_eq!(last.3.as_deref(), Some("service start system:definitely-not-a-unit.service: no such unit"));
}

/// A unit's own files are read as the listing's unit.
#[ntex::test]
async fn a_unit_can_be_looked_up_by_the_key_its_listing_gave_it() {
    let (srv, _) = server().await;
    let Some(units) = listed(&srv).await else {
        return;
    };
    let Some(unit) = units.first() else {
        return;
    };
    let key = unit["key"].as_str().unwrap();
    let (_, body) = read(&srv, &format!("?part=logs&key={key}")).await;
    // A log, or a manager saying it keeps none — never an empty log standing
    // in for "not available".
    if body["available"].as_bool().unwrap() {
        assert!(body["log"]["lines"].is_array(), "{body}");
    } else {
        assert_eq!(body["reason_kind"], "no_log", "{body}");
    }
    let (_, definition) = read(&srv, &format!("?part=definition&key={key}")).await;
    assert!(definition["text"].is_string(), "{definition}");
}

/// An action this build does not have is refused while deserializing, before
/// it reaches a shell.
#[ntex::test]
async fn an_action_this_build_does_not_have_is_refused() {
    let (srv, db) = server().await;
    let (status, _) = act(&srv, "admin", json!({"key": "system:sshd.service", "action": "reload"})).await;
    assert_eq!(status, 400);
    assert!(audit(&db).await.is_empty());
}

#[ntex::test]
async fn capabilities_list_the_services_page() {
    let (srv, _) = server().await;
    let (_, caps) = call(&srv, Some("viewer"), Method::GET, "/api/v1/capabilities", None).await;
    assert!(caps["features"].as_array().unwrap().iter().any(|f| f == "services"), "{caps}");
}
