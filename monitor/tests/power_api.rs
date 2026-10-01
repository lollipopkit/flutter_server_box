//! `POST /api/v1/power`, against the real route table.
//!
//! The refusals and what is recorded, and **not** the action itself: all three
//! actions take down the machine this suite runs on. That each action runs the
//! status script's own function is the unit test in `api::power`; running a
//! function of that script is what every monitoring cycle does.

mod common;

use ntex::http::Method;
use serde_json::json;

use common::machine::{audit, call, server};

#[ntex::test]
async fn power_needs_an_account_and_the_shell_grant() {
    let (srv, db) = server().await;
    let body = || Some(json!({ "action": "reboot" }));

    let (status, _) = call(&srv, None, Method::POST, "/api/v1/power", body()).await;
    assert_eq!(status, 401);

    let (status, resp) = call(&srv, Some("viewer"), Method::POST, "/api/v1/power", body()).await;
    assert_eq!((status, resp["error"].as_str()), (403, Some("forbidden")));
    assert_eq!(resp["message"], "not_granted");

    // The refusal is written down, by account and by what was asked, and
    // nothing ran: there is no `open` row.
    let rows = audit(&db).await;
    assert_eq!(rows.len(), 1, "{rows:?}");
    let (action, result, subject, detail) = &rows[0];
    assert_eq!((action.as_str(), result.as_str()), ("denied", "denied"));
    assert_eq!(subject.as_deref(), Some("viewer"));
    assert_eq!(detail.as_deref(), Some("power reboot: shell not_granted"));
}

#[ntex::test]
async fn only_the_three_actions_are_accepted() {
    let (srv, db) = server().await;
    for body in [json!({ "action": "halt" }), json!({}), json!({ "action": "Reboot" })] {
        let (status, _) = call(&srv, Some("admin"), Method::POST, "/api/v1/power", Some(body)).await;
        assert_eq!(status, 400);
    }
    assert!(audit(&db).await.is_empty());
}

#[ntex::test]
async fn capabilities_list_power_as_a_feature() {
    let (srv, _) = server().await;
    let (status, caps) = call(&srv, Some("viewer"), Method::GET, "/api/v1/capabilities", None).await;
    assert_eq!(status, 200);
    let features: Vec<&str> = caps["features"]
        .as_array()
        .unwrap()
        .iter()
        .filter_map(|f| f.as_str())
        .collect();
    assert!(features.contains(&"power"), "{features:?}");
}
