//! `/api/v1/benchmark`, against the real route table.
//!
//! Never starts a run: on a Linux machine that would be ten to twenty minutes
//! of fio and iperf3 on whoever runs the suite. What is asserted is the door,
//! the read, the estimate (which changes nothing) and the refusals that come
//! before anything is launched. The command layer is `sbm_parser::bench`'s
//! own tests, which run its fragments against `/bin/sh` with a stand-in yabs.

mod common;

use ntex::http::Method;
use serde_json::json;

use common::machine::{audit, call, server};

#[ntex::test]
async fn everything_needs_the_shell_grant() {
    let (srv, db) = server().await;
    let (status, _) = call(&srv, None, Method::GET, "/api/v1/benchmark", None).await;
    assert_eq!(status, 401);

    for (method, path, body) in [
        (Method::GET, "/api/v1/benchmark", None),
        (Method::POST, "/api/v1/benchmark", Some(json!({ "action": "start" }))),
        (Method::POST, "/api/v1/benchmark", Some(json!({ "action": "estimate" }))),
        (Method::DELETE, "/api/v1/benchmark?run=bench_x", None),
    ] {
        let (status, answer) = call(&srv, Some("viewer"), method.clone(), path, body).await;
        assert_eq!((status, answer["error"].as_str()), (403, Some("forbidden")), "{method} {path}");
    }
    let rows = audit(&db).await;
    assert_eq!(rows.len(), 4, "{rows:?}");
    assert!(rows.iter().all(|(action, _, subject, _)| action == "denied" && subject.as_deref() == Some("viewer")));
    assert_eq!(rows[1].3.as_deref(), Some("benchmark start: shell not_granted"));
}

/// The history, and whether this machine can run one at all.
#[ntex::test]
async fn the_read_lists_runs_and_says_whether_one_can_run_here() {
    let (srv, db) = server().await;
    let (status, body) = call(&srv, Some("admin"), Method::GET, "/api/v1/benchmark", None).await;
    assert_eq!(status, 200, "{body}");
    assert_eq!(body["runs"], json!([]));
    assert_eq!(
        body["supported"],
        server_box_monitor::monitoring::system_type() == sbm_parser::SystemType::Linux
    );
    assert!(body.get("live").is_none(), "{body}");
    assert!(audit(&db).await.is_empty());

    let (status, body) = call(&srv, Some("admin"), Method::GET, "/api/v1/benchmark?run=bench_nope", None).await;
    assert_eq!((status, body["error"].as_str()), (404, Some("no_such_run")));
}

/// What a set of options would cost, before anyone commits to it.
#[ntex::test]
async fn an_estimate_is_answered_and_changes_nothing() {
    let (srv, db) = server().await;
    let (status, body) = call(
        &srv,
        Some("admin"),
        Method::POST,
        "/api/v1/benchmark",
        Some(json!({ "action": "estimate" })),
    )
    .await;
    assert_eq!(status, 200, "{body}");
    assert!(body["estimate"].is_object(), "{body}");
    assert!(body["system_info_only"].is_boolean(), "{body}");
    assert!(audit(&db).await.is_empty());
}

/// Refused before anything is written or launched: a working directory too
/// long to be a path, and a start on a machine yabs does not run on.
#[ntex::test]
async fn a_start_that_cannot_happen_is_refused_before_it_is_launched() {
    let (srv, db) = server().await;
    let (status, body) = call(
        &srv,
        Some("admin"),
        Method::POST,
        "/api/v1/benchmark",
        Some(json!({ "action": "start", "options": { "work_dir": "x".repeat(5000) } })),
    )
    .await;
    assert_eq!(status, 400, "{body}");
    let expected = if server_box_monitor::monitoring::system_type() == sbm_parser::SystemType::Linux {
        "work_dir_too_long"
    } else {
        "unsupported_platform"
    };
    assert_eq!(body["error"], expected);
    assert!(audit(&db).await.is_empty(), "nothing was launched, so nothing was recorded");
}

/// A cancel with nothing running is an answer, not an error; a removal of a
/// run that does not exist is a 404.
#[ntex::test]
async fn cancelling_or_removing_what_is_not_there() {
    let (srv, _) = server().await;
    let (status, body) = call(&srv, Some("admin"), Method::POST, "/api/v1/benchmark", Some(json!({ "action": "cancel" }))).await;
    assert_eq!((status, &body["cancelled"]), (200, &json!(false)), "{body}");
    let (status, body) = call(&srv, Some("admin"), Method::DELETE, "/api/v1/benchmark?run=bench_nope", None).await;
    assert_eq!((status, body["error"].as_str()), (404, Some("no_such_run")));
}

#[ntex::test]
async fn capabilities_list_the_benchmark_page() {
    let (srv, _) = server().await;
    let (_, caps) = call(&srv, Some("viewer"), Method::GET, "/api/v1/capabilities", None).await;
    assert!(caps["features"].as_array().unwrap().iter().any(|f| f == "benchmark"), "{caps}");
}
