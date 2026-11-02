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
async fn only_the_three_actions_are_accepted() {
    let (srv, db) = server().await;
    for body in [json!({ "action": "halt" }), json!({}), json!({ "action": "Reboot" })] {
        let (status, _) = call(&srv, true, Method::POST, "/api/v1/power", Some(body)).await;
        assert_eq!(status, 400);
    }
    assert!(audit(&db).await.is_empty());
}

#[ntex::test]
async fn capabilities_list_power_as_a_feature() {
    let (srv, _) = server().await;
    let (status, caps) = call(&srv, true, Method::GET, "/api/v1/capabilities", None).await;
    assert_eq!(status, 200);
    let features: Vec<&str> = caps["features"]
        .as_array()
        .unwrap()
        .iter()
        .filter_map(|f| f.as_str())
        .collect();
    assert!(features.contains(&"power"), "{features:?}");
}
