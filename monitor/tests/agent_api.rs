//! `/api/v1/agent/*` against the real route table and the real pi runtime,
//! with a scripted OpenAI-compatible model: what runs unasked, what waits for
//! a confirmation, a plan's commands, a command that cannot be undone, and
//! who may see a task at all.

mod common;

use std::io::{BufRead, BufReader, Read, Write};
use std::net::TcpListener;
use std::path::PathBuf;
use std::time::Duration;

use ntex::http::Method;
use ntex::web::test::TestServer;
use serde_json::{Value, json};

use common::machine::{call, server};

/// One answer of the model: a tool call, or words.
#[derive(Clone)]
enum Say {
    Tool(&'static str, Value),
    Text(&'static str),
}

/// A model that answers a conversation by how many tool results it holds:
/// the script's `n`th entry after `n` results. A request without tools (the
/// task's title) is answered `Title`.
fn model(script: Vec<Say>) -> String {
    let listener = TcpListener::bind("127.0.0.1:0").unwrap();
    let addr = listener.local_addr().unwrap();
    std::thread::spawn(move || {
        for conn in listener.incoming() {
            let Ok(mut conn) = conn else { continue };
            let script = script.clone();
            std::thread::spawn(move || {
                let mut reader = BufReader::new(conn.try_clone().unwrap());
                let mut len = 0usize;
                let mut get = false;
                loop {
                    let mut line = String::new();
                    if reader.read_line(&mut line).unwrap_or(0) == 0 {
                        return;
                    }
                    let l = line.trim_end();
                    if l.is_empty() {
                        break;
                    }
                    if l.starts_with("GET ") {
                        get = true;
                    }
                    if let Some(v) = l.to_ascii_lowercase().strip_prefix("content-length:") {
                        len = v.trim().parse().unwrap();
                    }
                }
                if get {
                    // `GET /models`: what the endpoint lists.
                    let body = json!({ "data": [{ "id": "mock-a" }, { "id": "mock-b" }] }).to_string();
                    let _ = write!(conn, "HTTP/1.1 200 OK\r\ncontent-type: application/json\r\ncontent-length: {}\r\nconnection: close\r\n\r\n{body}", body.len());
                    return;
                }
                let mut body = vec![0u8; len];
                reader.read_exact(&mut body).unwrap();
                let req: Value = serde_json::from_slice(&body).unwrap();
                let results = req["messages"].as_array().unwrap().iter().filter(|m| m["role"] == "tool").count();
                let say = if req.get("tools").is_none() {
                    Say::Text("Title")
                } else {
                    script.get(results).cloned().unwrap_or(Say::Text("Done."))
                };
                write!(conn, "HTTP/1.1 200 OK\r\ncontent-type: text/event-stream\r\nconnection: close\r\n\r\n").unwrap();
                let base = json!({"id":"c1","object":"chat.completion.chunk","created":1,"model":req["model"]});
                let mut send = |delta: Value, finish: Option<&str>| {
                    let mut c = base.clone();
                    c["choices"] = json!([{"index":0,"delta":delta,"finish_reason":finish}]);
                    let _ = write!(conn, "data: {c}\n\n");
                };
                match say {
                    Say::Tool(name, args) => {
                        let id = format!("call_{results}");
                        send(json!({"role":"assistant","tool_calls":[{"index":0,"id":id,"type":"function","function":{"name":name,"arguments":args.to_string()}}]}), None);
                        send(json!({}), Some("tool_calls"));
                    }
                    Say::Text(t) => {
                        send(json!({"role":"assistant","content":t}), None);
                        send(json!({}), Some("stop"));
                    }
                }
                let _ = write!(conn, "data: [DONE]\n\n");
            });
        }
    });
    format!("http://{addr}/v1")
}

async fn configure(srv: &TestServer, url: &str) {
    let (status, body) = call(
        srv,
        Some("admin"),
        Method::PUT,
        "/api/v1/agent/settings",
        Some(json!({
            "model": { "provider": "mock", "id": "mock" },
            "providers": [{ "id": "mock", "name": "Mock", "api": "openai-completions", "baseUrl": url, "models": [{ "id": "mock" }] }],
            "credentials": { "mock": "sk-test" },
        })),
    )
    .await;
    assert_eq!(status, 200, "{body}");
    // Write-only: the key never comes back.
    assert!(!body.to_string().contains("sk-test"), "{body}");
    assert_eq!(body["credentials"], json!(["mock"]));
}

async fn start(srv: &TestServer, prompt: &str) -> String {
    let (status, body) = call(srv, Some("admin"), Method::POST, "/api/v1/agent/flows", Some(json!({ "prompt": prompt }))).await;
    assert_eq!(status, 201, "{body}");
    body["id"].as_str().unwrap().to_string()
}

/// Polls the task until [done] says so.
async fn until(srv: &TestServer, id: &str, done: impl Fn(&Value) -> bool) -> Value {
    for _ in 0..200 {
        let (status, body) = call(srv, Some("admin"), Method::GET, &format!("/api/v1/agent/flows/{id}"), None).await;
        assert_eq!(status, 200, "{body}");
        if done(&body) {
            return body;
        }
        tokio::time::sleep(Duration::from_millis(50)).await;
    }
    panic!("the task never got there");
}

fn status(v: &Value) -> &str {
    v["flow"]["status"].as_str().unwrap_or_default()
}

fn results(v: &Value) -> Vec<Value> {
    v["entries"].as_array().unwrap().iter().filter(|e| e["message"]["role"] == "toolResult").map(|e| e["message"].clone()).collect()
}

fn scratch(name: &str) -> PathBuf {
    let d = std::env::temp_dir().join(format!("sbm-agent-api-{name}-{}", std::process::id()));
    let _ = std::fs::remove_dir_all(&d);
    std::fs::create_dir_all(&d).unwrap();
    d
}

#[ntex::test]
async fn nothing_runs_until_it_is_configured_and_only_with_shell() {
    let (srv, _) = server().await;
    let (s, body) = call(&srv, Some("admin"), Method::POST, "/api/v1/agent/flows", Some(json!({ "prompt": "hi" }))).await;
    assert_eq!((s, body["error"].as_str()), (409, Some("notConfigured")));
    let (s, _) = call(&srv, Some("viewer"), Method::GET, "/api/v1/agent/flows", None).await;
    assert_eq!(s, 403);
    let (s, _) = call(&srv, Some("viewer"), Method::PUT, "/api/v1/agent/settings", Some(json!({ "model": null }))).await;
    assert_eq!(s, 403);
    let (s, _) = call(&srv, None, Method::GET, "/api/v1/agent/flows", None).await;
    assert_eq!(s, 401);
    let (s, body) = call(
        &srv,
        Some("admin"),
        Method::PUT,
        "/api/v1/agent/settings",
        Some(json!({ "model": { "provider": "x", "id": "y" }, "providers": [{ "id": "x", "name": "X", "api": "openai-completions", "baseUrl": "http://10.9.9.9/v1" }] })),
    )
    .await;
    assert_eq!((s, body["error"].as_str()), (400, Some("invalidBaseUrl")));
}

#[ntex::test]
async fn a_read_runs_unasked_and_its_output_is_kept() {
    let (srv, _) = server().await;
    let url = model(vec![
        Say::Tool("run_command", json!({ "command": "ls /", "title": "List", "area": "files", "effect": "read" })),
        Say::Text("Listed."),
    ]);
    configure(&srv, &url).await;
    let id = start(&srv, "what is in /").await;
    let v = until(&srv, &id, |v| status(v) == "done").await;
    let r = results(&v);
    assert_eq!(r.len(), 1, "{v}");
    assert_eq!(r[0]["details"]["exitCode"], 0);
    let lines = r[0]["details"]["lines"].as_array().unwrap();
    assert!(lines.iter().any(|l| l[1] == "tmp" || l[1] == "usr"), "{lines:?}");
    assert_eq!(v["flow"]["areas"], json!(["files"]));
    assert_eq!(v["flow"]["line"], "Listed.");

    // Somebody else's task is not there for them.
    let (s, _) = call(&srv, Some("intruder"), Method::GET, &format!("/api/v1/agent/flows/{id}"), None).await;
    assert_eq!(s, 404);
    let (_, list) = call(&srv, Some("intruder"), Method::GET, "/api/v1/agent/flows", None).await;
    assert_eq!(list["flows"], json!([]));
}

#[ntex::test]
async fn a_plan_once_approved_runs_its_commands_without_asking_again() {
    let (srv, _) = server().await;
    let dir = scratch("plan");
    let made = dir.join("made");
    let touch = format!("touch {}", made.display());
    let url = model(vec![
        Say::Tool("propose_plan", json!({ "title": "Make a file", "summary": "One file.", "steps": [{ "text": "Create it", "command": touch }] })),
        Say::Tool("run_command", json!({ "command": touch, "title": "Create", "area": "files", "effect": "change" })),
        Say::Text("Made."),
    ]);
    configure(&srv, &url).await;
    let id = start(&srv, "make a file").await;
    let v = until(&srv, &id, |v| status(v) == "waiting").await;
    assert_eq!(v["pending"]["kind"], "confirm");
    assert_eq!(v["pending"]["steps"][0]["command"], touch);
    assert!(!made.exists());

    // An answer to something else is refused.
    let (s, _) = call(&srv, Some("admin"), Method::POST, &format!("/api/v1/agent/flows/{id}/answer"), Some(json!({ "id": "nope", "action": "run" }))).await;
    assert_eq!(s, 409);
    let pid = v["pending"]["id"].as_str().unwrap();
    let (s, _) = call(&srv, Some("admin"), Method::POST, &format!("/api/v1/agent/flows/{id}/answer"), Some(json!({ "id": pid, "action": "run" }))).await;
    assert_eq!(s, 204);
    let v = until(&srv, &id, |v| status(v) == "done").await;
    assert!(made.exists(), "{v}");
    assert_eq!(results(&v).len(), 2);
    let _ = std::fs::remove_dir_all(dir);
}

#[ntex::test]
async fn a_change_waits_and_stopping_runs_nothing() {
    let (srv, _) = server().await;
    let dir = scratch("stop");
    let made = dir.join("made");
    let url = model(vec![Say::Tool(
        "run_command",
        // Claimed a read; its shape says otherwise, and the shape counts.
        json!({ "command": format!("touch {}", made.display()), "title": "Create", "area": "files", "effect": "read" }),
    )]);
    configure(&srv, &url).await;
    let id = start(&srv, "make a file").await;
    let v = until(&srv, &id, |v| status(v) == "waiting").await;
    assert_eq!(v["pending"]["kind"], "confirm");
    assert_eq!(v["flow"]["waiting"], "confirm");
    let (s, _) = call(&srv, Some("admin"), Method::POST, &format!("/api/v1/agent/flows/{id}/stop"), None).await;
    assert_eq!(s, 204);
    until(&srv, &id, |v| status(v) == "cancelled").await;
    assert!(!made.exists());
    let (s, _) = call(&srv, Some("admin"), Method::DELETE, &format!("/api/v1/agent/flows/{id}"), None).await;
    assert_eq!(s, 204);
    let (s, _) = call(&srv, Some("admin"), Method::GET, &format!("/api/v1/agent/flows/{id}"), None).await;
    assert_eq!(s, 404);
    let _ = std::fs::remove_dir_all(dir);
}

#[ntex::test]
async fn what_cannot_be_undone_needs_the_machine_named() {
    let (srv, _) = server().await;
    let dir = scratch("danger");
    let keep = dir.join("keep");
    std::fs::write(&keep, b"x").unwrap();
    let rm = format!("rm -f {}", keep.display());
    let url = model(vec![
        Say::Tool("run_command", json!({ "command": rm, "title": "Remove", "area": "files", "effect": "read", "alternatives": ["Back it up first"] })),
        Say::Text("Left it."),
    ]);
    configure(&srv, &url).await;
    let id = start(&srv, "remove the file").await;
    let v = until(&srv, &id, |v| status(v) == "waiting").await;
    assert_eq!(v["pending"]["kind"], "danger");
    assert_eq!(v["pending"]["alternatives"], json!(["Back it up first"]));
    let host = v["pending"]["confirmText"].as_str().unwrap().to_string();
    let pid = v["pending"]["id"].as_str().unwrap();
    let answer = format!("/api/v1/agent/flows/{id}/answer");
    let (s, body) = call(&srv, Some("admin"), Method::POST, &answer, Some(json!({ "id": pid, "action": "run", "confirm": "nope" }))).await;
    assert_eq!((s, body["error"].as_str()), (400, Some("confirmMismatch")));
    let (s, _) = call(&srv, Some("admin"), Method::POST, &answer, Some(json!({ "id": pid, "action": "alternative", "index": 0 }))).await;
    assert_eq!(s, 204);
    let v = until(&srv, &id, |v| status(v) == "done").await;
    assert!(keep.exists(), "{v}");
    assert_eq!(results(&v)[0]["details"]["alternative"], "Back it up first");
    assert!(!host.is_empty());
    let _ = std::fs::remove_dir_all(dir);
}

#[ntex::test]
async fn a_finished_task_takes_a_reply_as_a_new_run() {
    let (srv, _) = server().await;
    let url = model(vec![Say::Text("Hello.")]);
    configure(&srv, &url).await;
    let id = start(&srv, "hi").await;
    until(&srv, &id, |v| status(v) == "done").await;
    let (s, body) = call(&srv, Some("admin"), Method::POST, &format!("/api/v1/agent/flows/{id}/reply"), Some(json!({ "text": "again" }))).await;
    assert_eq!(s, 200, "{body}");
    let v = until(&srv, &id, |v| status(v) == "done" && v["entries"].as_array().unwrap().iter().filter(|e| e["message"]["role"] == "user").count() == 2).await;
    assert_eq!(v["flow"]["title"], "Title");
}

#[ntex::test]
async fn an_endpoint_being_set_up_lists_its_models() {
    let (srv, _) = server().await;
    let url = model(vec![]);
    let probe = "/api/v1/agent/models/probe";
    let (s, body) = call(&srv, Some("admin"), Method::POST, probe, Some(json!({ "api": "openai-completions", "baseUrl": url, "apiKey": "k" }))).await;
    assert_eq!(s, 200, "{body}");
    let ids: Vec<&str> = body.as_array().unwrap().iter().map(|m| m["id"].as_str().unwrap()).collect();
    assert_eq!(ids, ["mock-a", "mock-b"]);

    let (s, body) = call(&srv, Some("admin"), Method::POST, probe, Some(json!({ "api": "openai-completions", "baseUrl": "https://" }))).await;
    assert_eq!((s, body["error"].as_str()), (400, Some("invalidBaseUrl")));
    let (s, body) = call(&srv, Some("admin"), Method::POST, probe, Some(json!({ "api": "openai-completions", "baseUrl": "http://10.9.9.9/v1" }))).await;
    assert_eq!((s, body["error"].as_str()), (400, Some("invalidBaseUrl")));
    let (s, _) = call(&srv, Some("viewer"), Method::POST, probe, Some(json!({ "api": "openai-completions", "baseUrl": url }))).await;
    assert_eq!(s, 403);
}

#[ntex::test]
async fn a_model_the_endpoint_lists_is_usable_without_opening_settings() {
    let (srv, _) = server().await;
    let url = model(vec![Say::Text("Hello.")]);
    // Nothing named by hand: `mock-a` is only what the endpoint lists.
    let (code, body) = call(
        &srv,
        Some("admin"),
        Method::PUT,
        "/api/v1/agent/settings",
        Some(json!({
            "model": { "provider": "mock", "id": "mock-a" },
            "providers": [{ "id": "mock", "name": "Mock", "api": "openai-completions", "baseUrl": url }],
            "credentials": { "mock": "k" },
        })),
    )
    .await;
    assert_eq!(code, 200, "{body}");
    let id = start(&srv, "hi").await;
    let v = until(&srv, &id, |v| status(v) != "running" && status(v) != "queued").await;
    assert_eq!(status(&v), "done", "{v}");
}

#[ntex::test]
async fn the_memory_is_kept_across_tasks_and_is_its_accounts_alone() {
    let (srv, _) = server().await;
    let url = model(vec![
        Say::Tool("memory_write", json!({ "path": "/memories/user.md", "content": "Prefers apt over snap" })),
        Say::Tool("memory_view", json!({ "path": "/memories/user.md" })),
        Say::Text("Noted."),
    ]);
    configure(&srv, &url).await;
    let id = start(&srv, "remember that I prefer apt").await;
    let v = until(&srv, &id, |v| status(v) == "done").await;
    let r = results(&v);
    assert_eq!(r[0]["content"][0]["text"], "Created /memories/user.md", "{v}");
    assert_eq!(r[1]["content"][0]["text"], "     1\tPrefers apt over snap\n", "{v}");

    let (s, list) = call(&srv, Some("admin"), Method::GET, "/api/v1/agent/memory", None).await;
    assert_eq!(s, 200, "{list}");
    assert_eq!(list["files"][0]["path"], "user.md");
    assert_eq!(list["files"][0]["chars"], 21);
    let (s, file) = call(&srv, Some("admin"), Method::GET, "/api/v1/agent/memory/file?path=user.md", None).await;
    assert_eq!(s, 200);
    assert_eq!(file["content"], "Prefers apt over snap");

    // Another account's memory is its own.
    let (_, theirs) = call(&srv, Some("intruder"), Method::GET, "/api/v1/agent/memory", None).await;
    assert_eq!(theirs["files"], json!([]), "{theirs}");
    let (s, _) = call(&srv, Some("intruder"), Method::GET, "/api/v1/agent/memory/file?path=user.md", None).await;
    assert_eq!(s, 404);

    // Edited and removed by the account, within the memory's rules.
    let put = |path: &'static str, content: &'static str| call(&srv, Some("admin"), Method::PUT, "/api/v1/agent/memory/file", Some(json!({ "path": path, "content": content })));
    assert_eq!(put("MEMORY.md", "- [User](user.md) — preferences").await.0, 204);
    let (s, body) = put("../etc/passwd", "x").await;
    assert_eq!((s, body["error"].as_str()), (400, Some("invalidMemory")), "{body}");
    assert_eq!(put("user.md/x", "x").await.0, 400);
    assert_eq!(put("/memories", "x").await.0, 400);
    let (s, _) = call(&srv, Some("admin"), Method::DELETE, "/api/v1/agent/memory/file?path=user.md", None).await;
    assert_eq!(s, 204);
    let (_, list) = call(&srv, Some("admin"), Method::GET, "/api/v1/agent/memory", None).await;
    assert_eq!(list["files"].as_array().unwrap().iter().map(|f| f["path"].clone()).collect::<Vec<_>>(), [json!("MEMORY.md")]);
}
