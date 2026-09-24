//! Coverage for `/api/v1/ai/*`.
//!
//! The model on the other end is a `TcpListener` this test owns, answering each
//! request with the next scripted SSE body — the shape `tests/rdp_ws.rs` gives
//! its fake RDP server. A whole turn therefore runs against the real handler:
//! the request, the stream, the items stored, the call parked, the approval that
//! runs it, and the turn resumed. What is asserted is what a person would have
//! seen, plus the two things only a test can see — the audit rows and the file
//! an approved command changed.
//!
//! Nothing here reaches a real endpoint, and no key of anyone's is written: the
//! model endpoint is a listener on loopback, and the key is a literal this file
//! owns, asserted to be absent from the bytes the agent sends back.
//!
//! `config_file::CONFIG_PATH` is relative to the process working directory on
//! purpose, so this file chdirs into a temp directory — once, since cargo gives
//! each integration test file its own process — and serialises its tests, which
//! all write the same `config.toml`.

use std::path::PathBuf;
use std::sync::{Arc, Once, OnceLock};
use std::time::Duration;

use ntex::web::App;
use ntex::web::test::{self as web_test, TestServer};
use rustls::crypto::ring;
use serde_json::{Value, json};
use server_box_monitor::api::ai::turn;
use server_box_monitor::api::auth::generate_token;
use server_box_monitor::api::server::{AppState, configure_api};
use server_box_monitor::core::config::Config;
use tokio::io::{AsyncReadExt, AsyncWriteExt};
use tokio::net::{TcpListener, TcpStream};
use tokio::sync::{Mutex, MutexGuard};

const SECRET: &str = "test-secret-that-is-long-enough-32ch";
/// A key no real endpoint ever issued, so that finding it on the wire is the
/// assertion rather than a coincidence.
const MODEL_KEY: &str = "model-key-not-to-be-disclosed";

fn ensure_crypto_provider() {
    static ONCE: Once = Once::new();
    ONCE.call_once(|| {
        let _ = ring::default_provider().install_default();
    });
}

/// Moves the process into a directory of its own, once, and hands out the lock
/// that keeps these tests from writing each other's `config.toml`.
///
/// `tokio::sync::Mutex` rather than the one in `std`: every test below holds
/// this across the `await` that starts its server, which is what
/// `clippy::await_holding_lock` refuses. The lock is contended for the whole
/// length of a test by design, so "drop it before the await" is not available.
async fn workspace() -> MutexGuard<'static, PathBuf> {
    static DIR: OnceLock<Mutex<PathBuf>> = OnceLock::new();
    let dir = DIR.get_or_init(|| {
        let dir = std::env::temp_dir().join(format!("sbm-ai-api-{}", std::process::id()));
        std::fs::create_dir_all(&dir).unwrap();
        std::env::set_current_dir(&dir).unwrap();
        Mutex::new(dir)
    });
    dir.lock().await
}

/// The config the agent reads fresh for every turn.
///
/// Written by the test rather than by `PUT /ai/settings` alone, because the
/// first read has to succeed before anything can be saved: `config_file::read`
/// reports a missing file rather than answering with defaults.
fn write_config() {
    std::fs::write("config.toml", format!("jwt_secret = \"{SECRET}\"\n")).unwrap();
}

fn jwt() -> String {
    generate_token("admin", SECRET).unwrap()
}

async fn app_state(full_access: bool) -> Arc<AppState> {
    ensure_crypto_provider();
    let mut config = Config {
        jwt_secret: Some(SECRET.to_string()),
        ..Default::default()
    };
    let mut remote = config.get_remote_access();
    // What `full_access_allowed` requires to answer yes at all.
    remote.terminal.enabled = true;
    remote.full_access = Some(full_access);
    config.remote_access = Some(remote);

    let db = sqlx::SqlitePool::connect("sqlite::memory:").await.unwrap();
    sqlx::migrate!("./migrations").run(&db).await.unwrap();
    AppState::new(Arc::new(config), db)
}

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

// ------------------------------------------------------------ a fake model

/// A listener answering each request with the next scripted SSE body.
struct Model;

impl Model {
    /// Starts one on loopback and answers the base URL to configure.
    ///
    /// Anything past the script is answered with an empty stream, so an
    /// unexpected extra request ends a turn rather than hanging the test.
    async fn start(script: Vec<String>) -> String {
        let listener = TcpListener::bind("127.0.0.1:0").await.unwrap();
        let addr = listener.local_addr().unwrap();
        tokio::spawn(async move {
            let mut script = script.into_iter();
            loop {
                let Ok((mut socket, _)) = listener.accept().await else {
                    break;
                };
                let body = script.next().unwrap_or_else(|| sse(&[]));
                read_request(&mut socket).await;
                let head = format!(
                    "HTTP/1.1 200 OK\r\ncontent-type: text/event-stream\r\n\
                     content-length: {}\r\nconnection: close\r\n\r\n",
                    body.len()
                );
                let _ = socket.write_all(head.as_bytes()).await;
                let _ = socket.write_all(body.as_bytes()).await;
                let _ = socket.shutdown().await;
            }
        });
        format!("http://{addr}/v1")
    }
}

/// Reads one request off the socket, headers and body.
///
/// The request is consumed rather than ignored because a client still writing
/// when the connection closes reads as a send failure, and the turn would
/// report `unreachable` instead of the scripted answer.
async fn read_request(socket: &mut TcpStream) {
    let mut seen = Vec::new();
    let mut buf = [0u8; 8192];
    loop {
        match socket.read(&mut buf).await {
            Ok(0) | Err(_) => return,
            Ok(n) => seen.extend_from_slice(&buf[..n]),
        }
        let Some(end) = find(&seen, b"\r\n\r\n") else {
            continue;
        };
        let head = String::from_utf8_lossy(&seen[..end]).to_lowercase();
        let want: usize = head
            .lines()
            .find_map(|line| line.strip_prefix("content-length:"))
            .and_then(|value| value.trim().parse().ok())
            .unwrap_or(0);
        if seen.len() >= end + 4 + want {
            return;
        }
    }
}

fn find(haystack: &[u8], needle: &[u8]) -> Option<usize> {
    haystack
        .windows(needle.len())
        .position(|window| window == needle)
}

/// One SSE body: each object as a `data:` frame, then the terminator.
fn sse(frames: &[Value]) -> String {
    let mut body = String::new();
    for frame in frames {
        body.push_str("data: ");
        body.push_str(&frame.to_string());
        body.push_str("\n\n");
    }
    body.push_str("data: [DONE]\n\n");
    body
}

/// An endpoint answering with a sentence and no call.
fn text_step(text: &str) -> String {
    sse(&[
        json!({"choices": [{"index": 0, "delta": {"content": text}}]}),
        json!({"choices": [{"index": 0, "delta": {}, "finish_reason": "stop"}]}),
    ])
}

/// An endpoint proposing calls, one as `(id, tool, arguments)`.
fn call_step(calls: &[(&str, &str, Value)]) -> String {
    let proposed: Vec<Value> = calls
        .iter()
        .enumerate()
        .map(|(index, (id, name, arguments))| {
            json!({
                "index": index,
                "id": id,
                "type": "function",
                "function": {"name": name, "arguments": arguments.to_string()},
            })
        })
        .collect();
    sse(&[
        json!({"choices": [{"index": 0, "delta": {"content": "Let me check."}}]}),
        json!({"choices": [
            {"index": 0, "delta": {"tool_calls": proposed}, "finish_reason": "tool_calls"}
        ]}),
    ])
}

/// A `run_shell_command` call in the shape the schema asks a model for: every
/// field, so what is parked is what a real proposal would park.
fn shell_call(command: &str) -> Value {
    json!({
        "command": command,
        "description": "Test command.",
        "safe_to_run": false,
        "destructive": false,
    })
}

/// A path under the temp directory, named after the running test.
fn marker(name: &str) -> PathBuf {
    std::env::temp_dir().join(format!("sbm-ai-{name}-{}", std::process::id()))
}

// ------------------------------------------------------------- the client

/// Saves an endpoint, switching auto-run as asked. `api_key` is a `Value`
/// rather than an `Option` so a `null` — keep what is stored — can be sent.
async fn save_settings(
    srv: &TestServer,
    base_url: &str,
    auto_run: bool,
    api_key: Value,
) -> (u16, Value) {
    let resp = srv
        .put("/api/v1/ai/settings")
        .header("Authorization", format!("Bearer {}", jwt()))
        .send_json(&json!({
            "base_url": base_url,
            "model": "test-model",
            "api_key": api_key,
            "auto_run_safe_commands": auto_run,
        }))
        .await
        .unwrap();
    let status = resp.status().as_u16();
    (status, resp.json().await.unwrap_or(Value::Null))
}

async fn get_raw(srv: &TestServer, path: &str) -> String {
    let resp = srv
        .get(path)
        .header("Authorization", format!("Bearer {}", jwt()))
        .send()
        .await
        .unwrap();
    assert_eq!(resp.status().as_u16(), 200, "{path} was refused");
    String::from_utf8(resp.body().await.unwrap().to_vec()).unwrap()
}

async fn post_action(srv: &TestServer, body: Value) -> (u16, Value) {
    let resp = srv
        .post("/api/v1/ai/conversations")
        .header("Authorization", format!("Bearer {}", jwt()))
        .send_json(&body)
        .await
        .unwrap();
    let status = resp.status().as_u16();
    (status, resp.json().await.unwrap_or(Value::Null))
}

async fn detail(srv: &TestServer, conversation: &str) -> Value {
    let raw = get_raw(
        srv,
        &format!("/api/v1/ai/conversations?conversation={conversation}"),
    )
    .await;
    serde_json::from_str(&raw).unwrap()
}

/// Sends a message and answers the envelope the action replied with.
async fn chat(srv: &TestServer, conversation: Option<&str>, message: &str) -> Value {
    let body = match conversation {
        Some(id) => json!({"action": "chat", "conversation": id, "message": message}),
        None => json!({"action": "chat", "message": message}),
    };
    let (status, body) = post_action(srv, body).await;
    assert_eq!(status, 200, "the message was refused: {body}");
    body
}

/// The conversation a message started, which is what the rest of a test needs.
async fn start(srv: &TestServer, message: &str) -> String {
    let started = chat(srv, None, message).await;
    assert_eq!(started["running"], true);
    started["conversation"].as_str().unwrap().to_string()
}

/// Asks the detail endpoint until the conversation reads as the test expects.
///
/// A turn runs in a task of its own, so what a test can wait for is a state the
/// conversation reaches, not a call returning.
async fn detail_until(srv: &TestServer, id: &str, done: impl Fn(&Value) -> bool) -> Value {
    let mut last = Value::Null;
    for _ in 0..200 {
        last = detail(srv, id).await;
        if done(&last) {
            return last;
        }
        tokio::time::sleep(Duration::from_millis(25)).await;
    }
    panic!("the conversation never reached the state the test waited for: {last}");
}

/// Parked, and with no turn left running behind it — which is what the next
/// action needs: `approve` and `decline` both answer `busy` while one is.
fn parked(detail: &Value) -> bool {
    !detail["waiting"].as_array().unwrap().is_empty()
        && detail["conversation"]["running"] == json!(false)
}

/// The turn is over and nothing is waiting on anyone.
fn settled(detail: &Value) -> bool {
    detail["waiting"] == json!([]) && detail["conversation"]["running"] == json!(false)
}

/// Every item's kind, in order.
fn kinds(detail: &Value) -> Vec<String> {
    detail["items"]
        .as_array()
        .unwrap()
        .iter()
        .map(|item| item["kind"].as_str().unwrap_or_default().to_string())
        .collect()
}

fn items(detail: &Value) -> &Vec<Value> {
    detail["items"].as_array().unwrap()
}

fn item<'a>(detail: &'a Value, kind: &str, call_id: &str) -> &'a Value {
    items(detail)
        .iter()
        .find(|item| item["kind"] == kind && item["call_id"] == json!(call_id))
        .unwrap_or_else(|| panic!("no {kind} item for {call_id} in {detail}"))
}

/// The envelope a stored `function_output` holds, parsed.
fn envelope(item: &Value) -> Value {
    serde_json::from_str(item["content"].as_str().unwrap_or_default()).unwrap()
}

/// Appends one item at the next position, the way a turn does.
async fn insert_item(
    db: &sqlx::SqlitePool,
    conversation: &str,
    item: turn::Item,
    ordinal: &mut i64,
) {
    turn::insert(db, conversation, &item, *ordinal).await.unwrap();
    *ordinal += 1;
}

/// Every Agent audit row, as `(subject, detail)`.
async fn audit_rows(state: &AppState) -> Vec<(String, String)> {
    use sqlx::Row;
    let rows = sqlx::query("SELECT subject, detail FROM access_log WHERE kind = 'ai' ORDER BY id")
        .fetch_all(&state.db)
        .await
        .unwrap();
    rows.iter()
        .map(|row| {
            (
                row.get::<Option<String>, _>("subject").unwrap_or_default(),
                row.get::<Option<String>, _>("detail").unwrap_or_default(),
            )
        })
        .collect()
}

// ------------------------------------------------------------------ tests

/// The endpoint and the key are two different things to a client, and only one
/// of them comes back.
#[ntex::test]
async fn saving_an_endpoint_keeps_a_key_the_client_never_saw() {
    let _dir = workspace().await;
    write_config();
    let srv = test_server(app_state(true).await).await;

    let (status, view) = save_settings(&srv, "http://127.0.0.1:1/v1", false, json!(MODEL_KEY)).await;
    assert_eq!(status, 200);
    assert_eq!(view["configured"], true);
    assert_eq!(view["base_url"], "http://127.0.0.1:1/v1");
    assert_eq!(view["model"], "test-model");
    assert_eq!(view["api_key"], Value::Null, "the key came back");
    assert_eq!(view["api_key_set"], true);
    assert_eq!(view["editable"], true);

    // The bytes, not a parsed field: the property is that the key is not on the
    // wire, and a field dropped from the view later would still have to pass.
    let raw = get_raw(&srv, "/api/v1/ai/settings").await;
    assert!(!raw.contains(MODEL_KEY), "the model key was on the wire: {raw}");

    // What an editor does with the view it was given: change something else and
    // hand back the `null`.
    let (status, view) = save_settings(&srv, "http://127.0.0.1:2/v1", true, Value::Null).await;
    assert_eq!(status, 200);
    assert_eq!(view["auto_run_safe_commands"], true);
    assert_eq!(view["base_url"], "http://127.0.0.1:2/v1");
    assert_eq!(view["api_key_set"], true, "the null cleared the stored key");

    // An empty string is how a client says it meant to clear it.
    let (status, view) = save_settings(&srv, "http://127.0.0.1:2/v1", true, json!("")).await;
    assert_eq!(status, 200);
    assert_eq!(view["api_key_set"], false);

    // The save is in force for the next message: the README the agent reads is
    // the file, not the startup snapshot.
    let (_, view) = save_settings(&srv, "http://127.0.0.1:3/v1", true, json!(MODEL_KEY)).await;
    assert_eq!(view["base_url"], "http://127.0.0.1:3/v1");
}

/// A mistyped endpoint is refused where it is written, rather than once per
/// message a minute later.
#[ntex::test]
async fn an_endpoint_that_is_not_a_url_is_refused_at_the_save() {
    let _dir = workspace().await;
    write_config();
    let srv = test_server(app_state(true).await).await;

    for value in [
        "not a url",
        // A scheme nothing serves a completion request over.
        "ftp://example.invalid",
        "file:///tmp/model.sock",
        "http://",
    ] {
        let (status, body) = save_settings(&srv, value, false, Value::Null).await;
        assert_eq!(status, 400, "{value:?} was accepted: {body}");
        assert_eq!(body["error"], "invalid_base_url");
    }
}

/// Reading is the panel login; sending, approving, removing and saving are the
/// grant that means "a shell as this agent's user". Anyone who can approve a
/// call can run anything in it.
#[ntex::test]
async fn reading_needs_the_panel_login_and_acting_needs_full_access() {
    let _dir = workspace().await;
    write_config();
    let state = app_state(false).await;
    let srv = test_server(state.clone()).await;

    let no_token = srv.get("/api/v1/ai/settings").send().await.unwrap();
    assert_eq!(no_token.status().as_u16(), 401);
    let no_token = srv.get("/api/v1/ai/conversations").send().await.unwrap();
    assert_eq!(no_token.status().as_u16(), 401);

    let listing: Value =
        serde_json::from_str(&get_raw(&srv, "/api/v1/ai/conversations").await).unwrap();
    assert_eq!(listing["editable"], false);
    assert_eq!(listing["conversations"], json!([]));

    let settings: Value =
        serde_json::from_str(&get_raw(&srv, "/api/v1/ai/settings").await).unwrap();
    assert_eq!(settings["editable"], false, "the editor cannot save");

    let (status, _) = save_settings(&srv, "http://127.0.0.1:1/v1", false, Value::Null).await;
    assert_eq!(status, 403);
    for body in [
        json!({"action": "chat", "message": "hello"}),
        json!({"action": "approve", "conversation": "x", "call_id": "c1"}),
        json!({"action": "decline", "conversation": "x"}),
        json!({"action": "rename", "conversation": "x", "title": "hi"}),
    ] {
        assert_eq!(post_action(&srv, body.clone()).await.0, 403, "{body}");
    }

    let removed = srv
        .delete("/api/v1/ai/conversations?conversation=x")
        .header("Authorization", format!("Bearer {}", jwt()))
        .send()
        .await
        .unwrap();
    assert_eq!(removed.status().as_u16(), 403);

    // One row per refusal, and none of them carries a reason in the caller's
    // own words.
    let rows = audit_rows(&state).await;
    assert_eq!(rows.len(), 6, "{rows:?}");
    assert!(rows.iter().all(|(_, detail)| detail == "full access disabled"));
}

/// The whole loop: a message becomes a turn, the turn parks on a call, a person
/// approves it, the command runs on this machine, and the turn resumes.
#[ntex::test]
async fn a_call_parks_until_a_person_approves_it_and_the_turn_resumes() {
    let _dir = workspace().await;
    write_config();
    let marker = marker("approved");
    let _ = std::fs::remove_file(&marker);
    let command = format!("touch {}", marker.display());

    let base_url = Model::start(vec![
        call_step(&[("call_1", "run_shell_command", shell_call(&command))]),
        text_step("Created it."),
    ])
    .await;

    let state = app_state(true).await;
    let srv = test_server(state.clone()).await;
    assert_eq!(save_settings(&srv, &base_url, false, json!(MODEL_KEY)).await.0, 200);

    let id = start(&srv, "please create a marker file\nsecond line").await;
    assert!(!marker.exists(), "the command ran before anyone approved it");

    let parked = detail_until(&srv, &id, parked).await;
    assert_eq!(parked["waiting"], json!(["call_1"]));
    assert_eq!(parked["conversation"]["awaiting_review"], true);
    assert_eq!(parked["conversation"]["model"], "test-model");
    // The first line of the message, so both clients read one name for it.
    assert_eq!(parked["conversation"]["title"], "please create a marker file");
    assert_eq!(parked["live"], Value::Null, "nothing is streaming");
    assert_eq!(kinds(&parked), ["message", "message", "function_call"]);

    let call = item(&parked, "function_call", "call_1");
    assert_eq!(call["tool"], "run_shell_command");
    assert_eq!(call["risk"], "caution", "touch is a change to the machine");
    // Verbatim, as the model wrote it: a reviewer reads these bytes and the
    // tool is handed these bytes.
    assert_eq!(
        call["arguments"].as_str().unwrap(),
        shell_call(&command).to_string()
    );

    // The list says the same thing the detail does, without the items.
    let listed: Value =
        serde_json::from_str(&get_raw(&srv, "/api/v1/ai/conversations").await).unwrap();
    assert_eq!(listed["conversations"][0]["awaiting_review"], true);
    assert_eq!(listed["conversations"][0]["running"], false);

    let (status, approved) = post_action(
        &srv,
        json!({"action": "approve", "conversation": id, "call_id": "call_1"}),
    )
    .await;
    assert_eq!(status, 200);
    assert_eq!(
        approved["result"]["ok"], true,
        "the approved command failed: {}",
        approved["result"]["summary"]
    );
    assert_eq!(approved["running"], true, "the turn did not resume");
    assert!(marker.exists(), "the approved command did not run");

    let finished = detail_until(&srv, &id, settled).await;
    assert_eq!(
        kinds(&finished),
        [
            "message",
            "message",
            "function_call",
            "function_output",
            "message"
        ]
    );
    assert_eq!(items(&finished)[4]["content"], "Created it.");
    let result = envelope(item(&finished, "function_output", "call_1"));
    assert_eq!(result["tool"], "run_shell_command");
    assert_eq!(result["ok"], true);
    assert_eq!(result["data"]["exit_code"], json!(0));

    // Two rows: the save, then the call. The save records *that* a key was set
    // and never the key.
    let rows = audit_rows(&state).await;
    assert_eq!(
        rows,
        [
            (
                "settings".to_string(),
                "auto_run_safe_commands=false api_key=set".to_string()
            ),
            (command.clone(), "risk=caution unreviewed=no".to_string()),
        ]
    );
    assert!(
        !format!("{rows:?}").contains(MODEL_KEY),
        "the model key reached the audit log"
    );
}

/// A call that has already been answered is not a call to approve, and the
/// command behind it does not run a second time.
#[ntex::test]
async fn an_answered_call_is_not_approved_twice() {
    let _dir = workspace().await;
    write_config();
    let marker = marker("twice");
    let _ = std::fs::remove_file(&marker);
    // Appends one byte per run, so running twice is visible in the file rather
    // than only in a timestamp.
    let command = format!("printf x >> {}", marker.display());

    let base_url = Model::start(vec![
        call_step(&[("call_1", "run_shell_command", shell_call(&command))]),
        text_step("Done."),
    ])
    .await;
    let srv = test_server(app_state(true).await).await;
    assert_eq!(save_settings(&srv, &base_url, false, Value::Null).await.0, 200);

    let id = start(&srv, "create the marker").await;
    detail_until(&srv, &id, parked).await;

    let approve = json!({"action": "approve", "conversation": id, "call_id": "call_1"});
    assert_eq!(post_action(&srv, approve.clone()).await.0, 200);
    detail_until(&srv, &id, settled).await;

    // The same approval again, which is what a second panel window sends.
    let (status, body) = post_action(&srv, approve).await;
    assert_eq!(status, 404, "a second answer was accepted: {body}");
    assert_eq!(body["error"], "no_such_call");
    // A command run twice is the one mistake here that cannot be undone.
    assert_eq!(std::fs::read_to_string(&marker).unwrap_or_default(), "x");
}

/// `stop` is answered before the grant is checked, because the case it has to
/// survive is an operator revoking it while a turn is running.
#[ntex::test]
async fn stop_is_answered_without_full_access() {
    let _dir = workspace().await;
    write_config();
    let srv = test_server(app_state(false).await).await;
    let (status, body) = post_action(&srv, json!({"action": "stop", "conversation": "x"})).await;
    assert_eq!(status, 200);
    assert_eq!(body["conversation"], "x");
    assert_eq!(body["running"], false, "nothing was running");
}

/// One person answers the whole batch: the calls were produced together, and a
/// call left unanswered would keep the conversation parked.
#[ntex::test]
async fn declining_answers_every_call_of_the_batch() {
    let _dir = workspace().await;
    write_config();
    let first = marker("declined-a");
    let second = marker("declined-b");
    for path in [&first, &second] {
        let _ = std::fs::remove_file(path);
    }

    let base_url = Model::start(vec![
        call_step(&[
            (
                "c1",
                "run_shell_command",
                shell_call(&format!("touch {}", first.display())),
            ),
            (
                "c2",
                "run_shell_command",
                shell_call(&format!("touch {}", second.display())),
            ),
        ]),
        text_step("Understood."),
    ])
    .await;

    let state = app_state(true).await;
    let srv = test_server(state.clone()).await;
    assert_eq!(save_settings(&srv, &base_url, false, Value::Null).await.0, 200);

    let id = start(&srv, "do both").await;
    let parked = detail_until(&srv, &id, parked).await;
    assert_eq!(parked["waiting"], json!(["c1", "c2"]));

    let (status, body) = post_action(&srv, json!({"action": "decline", "conversation": id})).await;
    assert_eq!(status, 200, "{body}");
    assert_eq!(body["running"], true, "the turn did not resume after the decline");

    let finished = detail_until(&srv, &id, settled).await;
    for call_id in ["c1", "c2"] {
        let answered = envelope(item(&finished, "function_output", call_id));
        assert_eq!(answered["server_box_action"], "declined");
        // The app's sentence, verbatim: it is a result the model reads, and a
        // model told only "no" tends to propose the same thing again.
        assert_eq!(answered["message"], turn::DECLINED_MESSAGE);
    }
    assert!(!first.exists() && !second.exists(), "a declined command ran");

    // The notice, which is this agent saying why the turn stopped. A code
    // rather than a sentence: the panel phrases it in the viewer's language.
    let notice = items(&finished)
        .iter()
        .find(|item| item["kind"] == "notice")
        .expect("no notice was recorded");
    assert_eq!(notice["content"], turn::DECLINED);

    // Declining is not running, and the rows say so rather than claiming a
    // person approved a command that never ran. One row per call, since each
    // was a decision about a different command.
    let rows = audit_rows(&state).await;
    assert_eq!(
        rows,
        [
            (
                "settings".to_string(),
                "auto_run_safe_commands=false api_key=none".to_string()
            ),
            ("declined".to_string(), "risk=unknown unreviewed=no".to_string()),
            ("declined".to_string(), "risk=unknown unreviewed=no".to_string()),
        ]
    );
}

/// A call nobody answered is not a decline: answering one that is not waiting
/// would record a decision about nothing.
#[ntex::test]
async fn declining_with_nothing_to_decline_is_refused() {
    let _dir = workspace().await;
    write_config();
    let base_url = Model::start(vec![text_step("Hi.")]).await;
    let srv = test_server(app_state(true).await).await;
    assert_eq!(save_settings(&srv, &base_url, false, Value::Null).await.0, 200);

    let id = start(&srv, "hello").await;
    detail_until(&srv, &id, settled).await;

    let (status, body) = post_action(&srv, json!({"action": "decline", "conversation": id})).await;
    assert_eq!(status, 400);
    assert_eq!(body["error"], "nothing_to_decline");

    let (status, body) = post_action(
        &srv,
        json!({"action": "approve", "conversation": id, "call_id": "nobody"}),
    )
    .await;
    assert_eq!(status, 404);
    assert_eq!(body["error"], "no_such_call");

    let (status, body) = post_action(&srv, json!({"action": "chat", "conversation": "gone", "message": "hi"})).await;
    assert_eq!(status, 404);
    assert_eq!(body["error"], "no_such_conversation");
}

/// The mode people are wary of turning on, and the row that says it was on.
#[ntex::test]
async fn a_read_only_call_runs_unreviewed_when_the_setting_is_on() {
    let _dir = workspace().await;
    write_config();
    let base_url = Model::start(vec![
        call_step(&[("c1", "run_shell_command", shell_call("df -h"))]),
        text_step("All fine."),
    ])
    .await;

    let state = app_state(true).await;
    let srv = test_server(state.clone()).await;
    assert_eq!(save_settings(&srv, &base_url, true, Value::Null).await.0, 200);

    let id = start(&srv, "check the disk").await;
    // Five items is the turn run through: the question, what it said, the call,
    // what the call produced, and the answer after it.
    let finished = detail_until(&srv, &id, |detail| {
        settled(detail) && items(detail).len() == 5
    })
    .await;

    // Never parked, so nothing waited on a person — and the call is in the log
    // with what it produced either way.
    assert_eq!(finished["waiting"], json!([]));
    let result = envelope(item(&finished, "function_output", "c1"));
    assert_eq!(result["ok"], true);
    assert_eq!(result["data"]["exit_code"], json!(0));
    assert!(
        !result["data"]["stdout"].as_str().unwrap_or_default().is_empty(),
        "df printed nothing: {result}"
    );
    assert_eq!(items(&finished)[4]["content"], "All fine.");

    // The row this whole mode exists to be visible in: the command, and the
    // fact that nobody was asked about it.
    let rows = audit_rows(&state).await;
    assert_eq!(
        rows,
        [
            (
                "settings".to_string(),
                "auto_run_safe_commands=true api_key=none".to_string()
            ),
            ("df -h".to_string(), "risk=read_only unreviewed=yes".to_string()),
        ]
    );
}

/// The two expressions of one rule, over one set of items.
///
/// `turn::unanswered` filters a list this process already holds and
/// `turn::waiting` asks the database; the follow stream can only afford the
/// second, and a stream that disagreed with the page would show a call as
/// answered that the page still asks about.
#[tokio::test]
async fn waiting_agrees_with_unanswered() {
    let db = sqlx::SqlitePool::connect("sqlite::memory:").await.unwrap();
    sqlx::migrate!("./migrations").run(&db).await.unwrap();
    for id in ["a", "b"] {
        let now = chrono::Utc::now();
        sqlx::query(
            "INSERT INTO ai_conversation (id, created_at, updated_at, title) VALUES (?, ?, ?, ?)",
        )
        .bind(id)
        .bind(now)
        .bind(now)
        .bind("test")
        .execute(&db)
        .await
        .unwrap();
    }

    let call = |id: &str| {
        let mut item = turn::Item::new("function_call", "", "");
        item.call_id = Some(id.to_string());
        item.tool = Some("run_shell_command".to_string());
        item.arguments = Some("{}".to_string());
        item
    };
    let output = |id: Option<&str>| {
        let mut item = turn::Item::new("function_output", "", "{}");
        item.call_id = id.map(str::to_string);
        item
    };

    let mut ordinal = 0;
    insert_item(&db, "a", turn::Item::new("message", "user", "go"), &mut ordinal).await;
    // Answered: not waiting.
    insert_item(&db, "a", call("answered"), &mut ordinal).await;
    insert_item(&db, "a", output(Some("answered")), &mut ordinal).await;
    // Never answered: waiting.
    insert_item(&db, "a", call("open"), &mut ordinal).await;
    // An output with no call id answers nothing, so the call above it stays
    // waiting — `null` is the kind having no such field, not an answer to one.
    insert_item(&db, "a", call("open-too"), &mut ordinal).await;
    insert_item(&db, "a", output(None), &mut ordinal).await;
    // Answered here by an output in *another* conversation, which is that
    // conversation's answer and not this one's.
    insert_item(&db, "a", call("elsewhere"), &mut ordinal).await;
    insert_item(&db, "b", call("elsewhere"), &mut ordinal).await;
    insert_item(&db, "b", output(Some("elsewhere")), &mut ordinal).await;
    // An output nobody asked for says nothing about anything.
    insert_item(&db, "a", output(Some("never-asked")), &mut ordinal).await;

    for conversation in ["a", "b"] {
        let stored = turn::items(&db, conversation).await.unwrap();
        let from_rust: Vec<String> = turn::unanswered(&stored)
            .into_iter()
            .filter_map(|item| item.call_id.clone())
            .collect();
        let from_sql = turn::waiting(&db, conversation).await.unwrap();
        assert_eq!(
            from_sql, from_rust,
            "{conversation}: the two disagree over the same items"
        );
    }

    // And they agree on the right answer, not merely on one another's.
    assert_eq!(
        turn::waiting(&db, "a").await.unwrap(),
        ["open", "open-too", "elsewhere"]
    );
    assert_eq!(turn::waiting(&db, "b").await.unwrap(), Vec::<String>::new());
}

/// A follower is sent what it does not have and not what it does, which is what
/// makes a reconnect cost a delta rather than the whole conversation.
#[ntex::test]
async fn following_sends_only_what_the_caller_has_not_seen() {
    use futures::StreamExt;

    let _dir = workspace().await;
    write_config();
    let base_url = Model::start(vec![text_step("Nothing to report.")]).await;
    let srv = test_server(app_state(true).await).await;
    assert_eq!(save_settings(&srv, &base_url, false, Value::Null).await.0, 200);

    let id = start(&srv, "hello").await;
    detail_until(&srv, &id, |detail| kinds(detail).len() == 2).await;

    // Everything after the first item: the question is on screen already, and a
    // follower that re-sent it would draw it twice.
    let resp = srv
        .get(format!("/api/v1/ai/follow?conversation={id}&after=0"))
        .header("Authorization", format!("Bearer {}", jwt()))
        .send()
        .await
        .unwrap();
    assert_eq!(resp.status().as_u16(), 200);
    assert_eq!(
        resp.headers()
            .get("content-type")
            .and_then(|value| value.to_str().ok()),
        Some("application/x-ndjson")
    );

    let mut resp = resp;
    let mut frames: Vec<Value> = Vec::new();
    // Both frame kinds, which is what a client draws a conversation from: the
    // items it is missing, and the state to render them in.
    while !(frames.iter().any(|f| f["type"] == "item") && frames.iter().any(|f| f["type"] == "state"))
    {
        let chunk = tokio::time::timeout(Duration::from_secs(5), resp.next())
            .await
            .expect("the follow stream went quiet")
            .expect("the follow stream ended")
            .expect("the follow stream failed");
        for line in chunk.split(|byte| *byte == b'\n').filter(|l| !l.is_empty()) {
            frames.push(serde_json::from_slice::<Value>(line).unwrap());
        }
    }
    // Dropped before the assertions, so a failure does not leave the stream
    // being polled.
    drop(resp);

    let item = frames.iter().find(|f| f["type"] == "item").unwrap();
    assert_eq!(item["item"]["ordinal"], 1, "the caller was sent what it had");
    assert_eq!(item["item"]["kind"], "message");
    assert_eq!(item["item"]["content"], "Nothing to report.");
    let state = frames.iter().find(|f| f["type"] == "state").unwrap();
    assert_eq!(state["running"], false);
    assert_eq!(state["waiting"], json!([]));
}

/// A conversation nobody has is refused rather than held open by a stream that
/// can never carry anything.
#[ntex::test]
async fn following_a_conversation_that_is_not_there_is_refused() {
    let _dir = workspace().await;
    write_config();
    let srv = test_server(app_state(true).await).await;
    let resp = srv
        .get("/api/v1/ai/follow?conversation=nothing")
        .header("Authorization", format!("Bearer {}", jwt()))
        .send()
        .await
        .unwrap();
    assert_eq!(resp.status().as_u16(), 404);
    assert_eq!(
        resp.json::<Value>().await.unwrap()["error"],
        "no_such_conversation"
    );
}

/// Removing a conversation takes its items with it.
#[ntex::test]
async fn removing_a_conversation_takes_its_items() {
    let _dir = workspace().await;
    write_config();
    let base_url = Model::start(vec![text_step("Hi.")]).await;
    let state = app_state(true).await;
    let srv = test_server(state.clone()).await;
    assert_eq!(save_settings(&srv, &base_url, false, Value::Null).await.0, 200);

    let id = start(&srv, "hello").await;
    detail_until(&srv, &id, settled).await;

    let removed = srv
        .delete(format!("/api/v1/ai/conversations?conversation={id}"))
        .header("Authorization", format!("Bearer {}", jwt()))
        .send()
        .await
        .unwrap();
    assert_eq!(removed.status().as_u16(), 200);

    let left: i64 =
        sqlx::query_scalar("SELECT count(*) FROM ai_message WHERE conversation_id = ?")
            .bind(&id)
            .fetch_one(&state.db)
            .await
            .unwrap();
    assert_eq!(left, 0, "the items outlived the conversation");

    let again = srv
        .delete(format!("/api/v1/ai/conversations?conversation={id}"))
        .header("Authorization", format!("Bearer {}", jwt()))
        .send()
        .await
        .unwrap();
    assert_eq!(again.status().as_u16(), 404);

    // And a title is the client's, refused on its own terms rather than
    // truncated to fit.
    let (status, body) = post_action(
        &srv,
        json!({"action": "rename", "conversation": "gone", "title": "hi"}),
    )
    .await;
    assert_eq!(status, 404, "{body}");
}

/// A message that cannot be sent is refused before a conversation is made for
/// it, so a typo does not leave an empty one in the list.
#[ntex::test]
async fn an_empty_message_does_not_make_a_conversation() {
    let _dir = workspace().await;
    write_config();
    let base_url = Model::start(vec![]).await;
    let srv = test_server(app_state(true).await).await;
    assert_eq!(save_settings(&srv, &base_url, false, Value::Null).await.0, 200);

    let (status, body) = post_action(&srv, json!({"action": "chat", "message": "   \n"})).await;
    assert_eq!(status, 400);
    assert_eq!(body["error"], "empty_message");

    let listing: Value =
        serde_json::from_str(&get_raw(&srv, "/api/v1/ai/conversations").await).unwrap();
    assert_eq!(listing["conversations"], json!([]));

    let (status, body) = post_action(
        &srv,
        json!({"action": "chat", "message": "x".repeat(16 * 1024 + 1)}),
    )
    .await;
    assert_eq!(status, 400);
    assert_eq!(body["error"], "message_too_long");

    // And an endpoint nobody configured is refused as such, rather than failing
    // on every message a minute later.
    write_config();
    let (status, body) = post_action(&srv, json!({"action": "chat", "message": "hello"})).await;
    assert_eq!(status, 400);
    assert_eq!(body["error"], "not_configured");
}
