//! `/api/v1/firewall`, against the real route table.
//!
//! Refusals, what is recorded, and the read of the machine the suite runs on —
//! and **never** a change: one here would rewrite the firewall of whatever
//! machine ran the suite, and could take it off the network. What a change
//! plans is `sbm_parser::firewall::change`'s own test
//! (`crates/sbm_parser/tests/firewall_change.rs`).

mod common;

use ntex::http::Method;
use sbm_parser::SystemType;
use serde_json::json;
use server_box_monitor::monitoring::system_type;

use common::machine::{audit, call, server};

/// A firewall on Linux where there is one, and a reason everywhere else. A read
/// is not audited.
#[ntex::test]
async fn the_read_answers_the_machine_or_says_why_not() {
    let (srv, db) = server().await;
    let (status, body) = call(&srv, true, Method::POST, "/api/v1/firewall", Some(json!({}))).await;
    assert_eq!(status, 200, "{body}");
    if system_type() != SystemType::Linux {
        assert_eq!(body["available"], false);
        assert_eq!(body["reason_kind"], "unsupported_platform", "{body}");
    } else if body["available"] == true {
        assert!(body["kind"].is_string(), "{body}");
        // The suite connects over loopback, which no rule here decides: the
        // machine's SSH port is the one way in judged.
        assert_eq!(body["proxied"], true);
        assert_eq!(body["accesses"][0]["via"], "ssh", "{body}");
    }
    assert!(audit(&db).await.is_empty());
}

/// A change this machine cannot plan is refused before anything runs as root,
/// and recorded under its code.
#[ntex::test]
async fn a_change_that_cannot_be_planned_is_refused_and_recorded() {
    let (srv, db) = server().await;
    let bad = json!({"kind": "ufw", "change": {"type": "add_rule", "draft": {
        "action": "allow", "direction": "incoming", "routed": false, "protocol": null, "port": "", "source_port": "",
        "app": null, "from": "", "to": "", "interface_in": "", "interface_out": "", "log": null, "comment": "", "prepend": false
    }}});
    let (status, body) = call(&srv, true, Method::POST, "/api/v1/firewall/act", Some(bad)).await;
    // `notInstalled` where the machine has no ufw (and off Linux), otherwise
    // the draft's own issue — or `sudoRequired`, answered without a refusal.
    match body["error"].as_str() {
        Some("notInstalled") => assert_eq!(status, 400),
        Some("invalidRule") => assert_eq!(body["issue"]["issue"], "nothing_matched", "{body}"),
        Some("unreadable") => assert_eq!(status, 502),
        _ => assert_eq!(body["sudo_rejected"], true, "{body}"),
    }
    let rows = audit(&db).await;
    assert!(rows.iter().all(|(action, _, _, _)| action == "denied"), "{rows:?}");
}

#[ntex::test]
async fn a_change_the_panel_did_not_name_properly_is_a_bad_request() {
    let (srv, _) = server().await;
    let (status, _) = call(&srv, true, Method::POST, "/api/v1/firewall/plan", Some(json!({"kind": "ufw", "change": {"type": "format_disk"}}))).await;
    assert_eq!(status, 400);
}
