//! End-to-end coverage for `/api/v1/process`.
//!
//! The read is asserted against the process that asked — this test binary is
//! in the table of whatever machine runs the suite, and nothing else about the
//! table is portable. The stop is asserted at its refusals, at one signal that
//! cannot change anything (a PID no process holds), and at one that stops a
//! process **this suite started itself**. Nothing here signals anything it did
//! not start, which is what makes the suite runnable twice.
//!
//! BSD has no stop implemented, so the cases that need one are skipped rather
//! than asserting a refusal: a green run on macOS says nothing about the Linux
//! path, and CI is where that path runs.

use std::sync::{Arc, Once};

use ntex::web::test::{self as web_test, TestServer};
use ntex::web::App;
use rustls::crypto::ring;
use serde_json::{json, Value};
use server_box_monitor::api::auth::generate_token;
use server_box_monitor::api::server::{AppState, configure_api};
use server_box_monitor::core::config::Config;

const SECRET: &str = "test-secret-that-is-long-enough-32ch";

/// A PID above every platform's maximum, so nothing holds it. Signalling it is
/// the one stop that is safe to ask for and still exercises the script.
const NO_SUCH_PID: i64 = 4_000_000_000;

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

async fn list(srv: &TestServer, query: &str) -> Result<Value, u16> {
    let resp = srv
        .get(format!("/api/v1/process{query}"))
        .header("Authorization", format!("Bearer {}", token()))
        .send()
        .await
        .unwrap();
    if !resp.status().is_success() {
        return Err(resp.status().as_u16());
    }
    // The test client reads a response body up to 64 KiB by default, and this
    // response is the machine's whole process table — several hundred KB on a
    // developer's machine, which the default reports as an overflow rather
    // than as too large a body. The endpoint caps what it *reads* at 8 MiB of
    // `ps` output; the JSON is a multiple of that, so the bound here is sized
    // to the JSON.
    Ok(resp.json::<Value>().limit(64 * 1024 * 1024).await.unwrap())
}

async fn signal(srv: &TestServer, body: Value) -> Result<Value, u16> {
    let resp = srv
        .post("/api/v1/process")
        .header("Authorization", format!("Bearer {}", token()))
        .send_json(&body)
        .await
        .unwrap();
    if !resp.status().is_success() {
        return Err(resp.status().as_u16());
    }
    Ok(resp.json().await.unwrap())
}

fn token() -> String {
    generate_token("admin", SECRET).unwrap()
}

/// Whether this platform has a stop implemented at all. BSD does not, and the
/// suite runs on macOS — the cases below that need one are skipped rather than
/// asserting a refusal that says nothing about the Linux path.
fn signals_available() -> bool {
    !sbm_parser::proc::signals_for(server_box_monitor::monitoring::system_type()).is_empty()
}

#[ntex::test]
async fn a_request_without_a_token_is_refused() {
    let srv = test_server(app_state(true).await).await;
    let resp = srv.get("/api/v1/process").send().await.unwrap();

    assert_eq!(resp.status().as_u16(), 401);
}

/// The table is the machine's, and the machine is running this test.
#[ntex::test]
async fn the_table_holds_the_process_that_asked() {
    let srv = test_server(app_state(true).await).await;
    let body = list(&srv, "").await.unwrap();

    assert_eq!(body["available"], true, "no table: {body}");
    let ours = body["procs"]
        .as_array()
        .unwrap()
        .iter()
        .find(|proc| proc["pid"] == std::process::id())
        .unwrap_or_else(|| panic!("this test's own process is not in the table: {body}"));

    assert!(!ours["name"].as_str().unwrap().is_empty());
    assert!(!ours["command"].as_str().unwrap().is_empty());
    // The identity a stop is checked against. Without it on this row the page
    // could never offer to stop anything, which is a silent failure — see the
    // module docs on `Proc::start_id`.
    assert!(
        ours["start_id"].is_string(),
        "this platform reported no start identity: {ours}"
    );
}

/// What the caller may order by is the machine's column set, and the answer
/// says which — the page draws its chips from here rather than deciding.
#[ntex::test]
async fn the_response_says_which_orders_this_table_can_answer() {
    let srv = test_server(app_state(true).await).await;
    let body = list(&srv, "").await.unwrap();
    let sorts: Vec<&str> = body["sorts"]
        .as_array()
        .unwrap()
        .iter()
        .map(|mode| mode.as_str().unwrap())
        .collect();

    // Always answerable, on every platform.
    assert!(sorts.contains(&"pid"), "{sorts:?}");
    for mode in &sorts {
        assert!(
            ["cpu", "mem", "rss", "read", "write", "pid", "user", "name"].contains(mode),
            "unknown order {mode}"
        );
    }
    // An order whose column the machine did not fill is not offered, since it
    // would order the whole table by nulls.
    assert_eq!(
        sorts.contains(&"cpu"),
        body["columns"]["cpu"].as_bool().unwrap()
    );
    assert_eq!(
        sorts.contains(&"rss"),
        body["columns"]["rss"].as_bool().unwrap()
    );
}

/// The first reading has no interval behind it, so no speed can be differenced
/// and the two orders that need one are not offered.
#[ntex::test]
async fn a_first_reading_offers_no_speed_order() {
    let srv = test_server(app_state(true).await).await;
    let body = list(&srv, "").await.unwrap();
    let sorts: Vec<&str> = body["sorts"]
        .as_array()
        .unwrap()
        .iter()
        .map(|mode| mode.as_str().unwrap())
        .collect();

    assert!(!sorts.contains(&"read"), "{sorts:?}");
    assert!(!sorts.contains(&"write"), "{sorts:?}");
}

/// What was asked for is what comes back, and it is the order the table is in
/// — PID is the one column every platform prints.
#[ntex::test]
async fn a_requested_order_is_the_order_that_comes_back() {
    let srv = test_server(app_state(true).await).await;
    // One read first: the endpoint runs the command each time, and the test
    // process is trying to stay inside its own timeout.
    list(&srv, "").await.unwrap();
    let body = list(&srv, "?sort=pid&ascending=false").await.unwrap();

    assert_eq!(body["sort"], "pid");
    assert_eq!(body["ascending"], false);
    let pids: Vec<i64> = body["procs"]
        .as_array()
        .unwrap()
        .iter()
        .map(|proc| proc["pid"].as_i64().unwrap())
        .collect();
    assert!(!pids.is_empty());
    assert!(
        pids.windows(2).all(|pair| pair[0] >= pair[1]),
        "not descending: {pids:?}"
    );
}

/// An order this table cannot answer is answered with the default instead of a
/// table in no order at all, and the response says which one that was.
#[ntex::test]
async fn an_order_this_table_cannot_answer_falls_back() {
    let srv = test_server(app_state(true).await).await;
    let body = list(&srv, "?sort=read&ascending=false").await.unwrap();
    let sorts: Vec<&str> = body["sorts"]
        .as_array()
        .unwrap()
        .iter()
        .map(|mode| mode.as_str().unwrap())
        .collect();

    assert_ne!(body["sort"], "read");
    assert!(sorts.contains(&body["sort"].as_str().unwrap()), "{body}");
}

/// The reading is kept for as long as the speed difference means something, so
/// a caller that reorders the table is answered with the reading it already
/// has rather than a second one a few milliseconds later.
#[ntex::test]
async fn a_reading_is_reused_inside_the_window() {
    let srv = test_server(app_state(true).await).await;
    let first = list(&srv, "").await.unwrap();
    let second = list(&srv, "?sort=pid").await.unwrap();

    assert_eq!(first["sampled_at_millis"], second["sampled_at_millis"]);
    assert_eq!(first["procs"].as_array().unwrap().len(), second["procs"].as_array().unwrap().len());
}

/// A PID with no identity beside it is refused before anything runs: the
/// identity is what the script checks the number against, and without it the
/// signal would go to whatever holds that number now.
#[ntex::test]
async fn a_signal_without_the_process_identity_is_refused() {
    let srv = test_server(app_state(true).await).await;
    assert_eq!(
        signal(&srv, json!({"pid": 1, "signal": "term"}))
            .await
            .unwrap_err(),
        400
    );
}

/// The grant is re-read per request, so what the client was told earlier about
/// capabilities decides nothing.
#[ntex::test]
async fn the_signal_is_refused_when_full_access_is_off() {
    let srv = test_server(app_state(false).await).await;
    assert_eq!(
        signal(
            &srv,
            json!({"pid": 1, "start_id": "1", "signal": "term"})
        )
        .await
        .unwrap_err(),
        403
    );
}

/// Refusals are recorded — the row that matters most here is the one naming a
/// process that was *not* signalled.
#[ntex::test]
async fn a_refusal_is_audited() {
    let state = app_state(false).await;
    let db = state.db.clone();
    let srv = test_server(state).await;
    assert!(signal(&srv, json!({"pid": 42, "signal": "kill"}))
        .await
        .is_err());

    let (kind, action, result): (String, String, String) =
        sqlx::query_as("SELECT kind, action, result FROM access_log ORDER BY id DESC LIMIT 1")
            .fetch_one(&db)
            .await
            .unwrap();

    assert_eq!(
        (kind.as_str(), action.as_str(), result.as_str()),
        ("process", "denied", "denied")
    );
}

/// The script's own verdict reaches the caller, and is told apart from an
/// exit status: this is the one stop that changes nothing on the machine.
#[ntex::test]
async fn a_pid_no_process_holds_reports_a_changed_target() {
    if !signals_available() {
        return;
    }
    let srv = test_server(app_state(true).await).await;
    let body = signal(
        &srv,
        json!({"pid": NO_SUCH_PID, "start_id": "1", "signal": "term"}),
    )
    .await
    .unwrap();

    assert_eq!(body["outcome"], "target_changed", "{body}");
    assert_eq!(body["sudo_rejected"], false);
}

/// The script's verdict and what happened on the machine agree.
#[ntex::test]
async fn a_signal_stops_the_process_it_names() {
    if !signals_available() {
        return;
    }
    // The only process this suite signals is one it started itself, for the
    // reason the suite gave for signalling nothing else.
    let mut child = std::process::Command::new("sleep")
        .arg("300")
        .spawn()
        .expect("sleep should be startable");
    let srv = test_server(app_state(true).await).await;
    let body = list(&srv, "").await.unwrap();
    let row = body["procs"]
        .as_array()
        .unwrap()
        .iter()
        .find(|proc| proc["pid"] == child.id())
        .unwrap_or_else(|| panic!("the process this test started is not in the table"));

    assert_eq!(row["killable"], true, "{row}");
    let answer = signal(
        &srv,
        json!({"pid": child.id(), "start_id": row["start_id"], "signal": "term"}),
    )
    .await
    .unwrap();
    if answer["outcome"] != "succeeded" {
        // A failed stop would otherwise leave this waiting 300 seconds for a
        // process that is still running.
        let _ = child.kill();
    }
    let _ = child.wait();

    assert_eq!(answer["outcome"], "succeeded", "{answer}");
}

/// A stop that did nothing is recorded as what it was, not as a success.
#[ntex::test]
async fn a_changed_target_is_audited_as_an_error() {
    if !signals_available() {
        return;
    }
    let state = app_state(true).await;
    let db = state.db.clone();
    let srv = test_server(state).await;
    signal(
        &srv,
        json!({"pid": NO_SUCH_PID, "start_id": "1", "signal": "kill"}),
    )
    .await
    .unwrap();

    let (kind, action, result, subject): (String, String, String, String) = sqlx::query_as(
        "SELECT kind, action, result, subject FROM access_log ORDER BY id DESC LIMIT 1",
    )
    .fetch_one(&db)
    .await
    .unwrap();

    assert_eq!(
        (kind.as_str(), action.as_str(), result.as_str()),
        ("process", "write", "error")
    );
    // The signal and the PID, which is the only record of which process was
    // named — the number may belong to something else by the time this is read.
    assert_eq!(subject, format!("KILL {NO_SUCH_PID}"));
}

/// An agent older than the endpoint answers `full_access` and would 404, so
/// the panel reads this field rather than that one.
#[ntex::test]
async fn capabilities_report_the_process_endpoint() {
    let srv = test_server(app_state(true).await).await;
    let resp = srv
        .get("/api/v1/capabilities")
        .header("Authorization", format!("Bearer {}", token()))
        .send()
        .await
        .unwrap();
    let body: Value = resp.json().await.unwrap();

    assert_eq!(body["remote_access"]["process"], true);
}
