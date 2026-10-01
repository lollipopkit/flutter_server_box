//! `/api/v1/process`, against the real route table.
//!
//! The read is asserted against the process that asked — this test binary is
//! in the table of whatever machine runs the suite, and nothing else about the
//! table is portable. The stop is asserted at its refusals, at a PID no
//! process holds, and at one process **this suite started itself**: nothing
//! here signals anything it did not start, so the suite can run twice.
//!
//! BSD has no stop implemented, so the cases that need one are skipped there
//! rather than asserting a refusal that says nothing about the Linux path.

mod common;

use ntex::http::Method;
use ntex::web::test::TestServer;
use serde_json::{Value, json};

use common::machine::{audit, call, server};

/// Above every platform's PID maximum, so nothing holds it: the one stop that
/// is safe to ask for and still runs the script.
const NO_SUCH_PID: i64 = 4_000_000_000;

async fn list(srv: &TestServer, query: &str) -> Value {
    let (status, body) = call(srv, Some("admin"), Method::GET, &format!("/api/v1/process{query}"), None).await;
    assert_eq!(status, 200, "{body}");
    body
}

async fn stop(srv: &TestServer, user: &str, body: Value) -> (u16, Value) {
    call(srv, Some(user), Method::POST, "/api/v1/process", Some(body)).await
}

fn signals_available() -> bool {
    !sbm_parser::proc::signals_for(server_box_monitor::monitoring::system_type()).is_empty()
}

fn sorts(body: &Value) -> Vec<&str> {
    body["sorts"].as_array().unwrap().iter().map(|m| m.as_str().unwrap()).collect()
}

#[ntex::test]
async fn both_halves_need_the_shell_grant() {
    let (srv, db) = server().await;
    let (status, _) = call(&srv, None, Method::GET, "/api/v1/process", None).await;
    assert_eq!(status, 401);

    // A command line is where an argument-borne secret shows up, so reading
    // the table is not `read`.
    let (status, body) = call(&srv, Some("viewer"), Method::GET, "/api/v1/process", None).await;
    assert_eq!((status, body["error"].as_str()), (403, Some("forbidden")));
    let (status, _) = stop(&srv, "viewer", json!({"pid": 42, "start_id": "1", "signal": "kill"})).await;
    assert_eq!(status, 403);

    // Both refusals are on file, by account; nothing ran.
    let rows = audit(&db).await;
    assert_eq!(rows.len(), 2, "{rows:?}");
    assert!(rows.iter().all(|(action, result, subject, _)| action == "denied"
        && result == "denied"
        && subject.as_deref() == Some("viewer")));
    assert_eq!(rows[1].3.as_deref(), Some("process stop KILL 42: shell not_granted"));
}

/// The table is the machine's, and the machine is running this test.
#[ntex::test]
async fn the_table_holds_the_process_that_asked() {
    let (srv, _) = server().await;
    let body = list(&srv, "").await;

    assert_eq!(body["available"], true, "no table: {body}");
    let ours = body["procs"]
        .as_array()
        .unwrap()
        .iter()
        .find(|proc| proc["pid"] == std::process::id())
        .unwrap_or_else(|| panic!("this test's own process is not in the table: {body}"));
    assert!(!ours["name"].as_str().unwrap().is_empty());
    assert!(!ours["command"].as_str().unwrap().is_empty());
    // What a stop is checked against. Without it no row could be stopped.
    assert!(ours["start_id"].is_string(), "no start identity: {ours}");
}

/// The page draws its order chips from the answer rather than deciding.
#[ntex::test]
async fn the_response_says_which_orders_this_table_can_answer() {
    let (srv, _) = server().await;
    let body = list(&srv, "").await;
    let sorts = sorts(&body);

    assert!(sorts.contains(&"pid"), "{sorts:?}");
    for mode in &sorts {
        assert!(
            ["cpu", "mem", "rss", "read", "write", "pid", "user", "name"].contains(mode),
            "unknown order {mode}"
        );
    }
    // An order whose column is empty would sort by nulls, so it is not offered.
    assert_eq!(sorts.contains(&"cpu"), body["columns"]["cpu"].as_bool().unwrap());
    assert_eq!(sorts.contains(&"rss"), body["columns"]["rss"].as_bool().unwrap());
    // A first reading has nothing to difference speeds against.
    assert!(!sorts.contains(&"read") && !sorts.contains(&"write"), "{sorts:?}");
}

#[ntex::test]
async fn a_requested_order_is_the_order_that_comes_back() {
    let (srv, _) = server().await;
    let body = list(&srv, "?sort=pid&ascending=false").await;

    assert_eq!((body["sort"].as_str(), body["ascending"].as_bool()), (Some("pid"), Some(false)));
    let pids: Vec<i64> = body["procs"].as_array().unwrap().iter().map(|p| p["pid"].as_i64().unwrap()).collect();
    assert!(!pids.is_empty());
    assert!(pids.windows(2).all(|pair| pair[0] >= pair[1]), "not descending: {pids:?}");

    // One the table cannot answer falls back, and says to what.
    let body = list(&srv, "?sort=read&ascending=false").await;
    assert_ne!(body["sort"], "read");
    assert!(sorts(&body).contains(&body["sort"].as_str().unwrap()), "{body}");
}

/// A reorder is answered from the reading it already has, rather than a second
/// one a few milliseconds later whose speeds would be spikes.
#[ntex::test]
async fn a_reading_is_reused_inside_the_window() {
    let (srv, _) = server().await;
    let first = list(&srv, "").await;
    let second = list(&srv, "?sort=pid").await;
    assert_eq!(first["sampled_at_millis"], second["sampled_at_millis"]);
}

/// The identity is what the script checks the number against; without it the
/// signal would go to whatever holds that number now.
#[ntex::test]
async fn a_signal_without_the_process_identity_is_refused() {
    let (srv, db) = server().await;
    let (status, _) = stop(&srv, "admin", json!({"pid": 1, "signal": "term"})).await;
    assert_eq!(status, 400);
    let rows = audit(&db).await;
    assert_eq!(rows.len(), 1, "{rows:?}");
    assert_eq!((rows[0].0.as_str(), rows[0].1.as_str()), ("denied", "denied"));
}

/// The one stop that changes nothing, and its record says so.
#[ntex::test]
async fn a_pid_no_process_holds_reports_a_changed_target() {
    if !signals_available() {
        return;
    }
    let (srv, db) = server().await;
    let (status, body) = stop(&srv, "admin", json!({"pid": NO_SUCH_PID, "start_id": "1", "signal": "kill"})).await;
    assert_eq!(status, 200, "{body}");
    assert_eq!(body["outcome"], "target_changed", "{body}");
    assert_eq!(body["sudo_rejected"], false);

    let rows = audit(&db).await;
    let close = rows.last().unwrap();
    assert_eq!((close.0.as_str(), close.1.as_str()), ("close", "error"));
    assert_eq!(close.3.as_deref(), Some(format!("process stop KILL {NO_SUCH_PID}: target changed").as_str()));
}

#[ntex::test]
async fn a_signal_stops_the_process_it_names() {
    if !signals_available() {
        return;
    }
    // Something that waits and is safe to stop. Windows has no `sleep` of its
    // own (CI's comes with Git); `ping` is in every install.
    let mut child = if cfg!(windows) {
        std::process::Command::new("ping")
            .args(["-n", "301", "127.0.0.1"])
            .stdout(std::process::Stdio::null())
            .spawn()
            .expect("ping")
    } else {
        std::process::Command::new("sleep").arg("300").spawn().expect("sleep")
    };
    let (srv, _) = server().await;
    let body = list(&srv, "").await;
    let row = body["procs"]
        .as_array()
        .unwrap()
        .iter()
        .find(|proc| proc["pid"] == child.id())
        .cloned()
        .unwrap_or_else(|| panic!("the process this test started is not in the table"));
    assert_eq!(row["killable"], true, "{row}");

    // The platform's own first signal: Windows offers only `kill`, and a
    // `term` there is refused before anything runs.
    let signal = body["signals"][0].clone();
    let (_, answer) = stop(
        &srv,
        "admin",
        json!({"pid": child.id(), "start_id": row["start_id"], "signal": signal}),
    )
    .await;
    if answer["outcome"] != "succeeded" {
        let _ = child.kill();
    }
    let _ = child.wait();
    assert_eq!(answer["outcome"], "succeeded", "{answer}");
}

#[ntex::test]
async fn capabilities_list_the_process_page() {
    let (srv, _) = server().await;
    let (_, caps) = call(&srv, Some("viewer"), Method::GET, "/api/v1/capabilities", None).await;
    assert!(caps["features"].as_array().unwrap().iter().any(|f| f == "process"), "{caps}");
}
