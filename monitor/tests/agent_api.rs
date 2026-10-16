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
    model_judging(script, "Title")
}

/// [model], answering the auto mode judge with [judge].
fn model_judging(script: Vec<Say>, judge: &'static str) -> String {
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
                let judging = req["messages"].as_array().is_some_and(|m| m.iter().any(|m| m["content"].as_str().is_some_and(|c| c.contains("You review one shell command"))));
                let say = if judging {
                    Say::Text(judge)
                } else if req.get("tools").is_none() {
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
        true,
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
    let (status, body) = call(srv, true, Method::POST, "/api/v1/agent/flows", Some(json!({ "prompt": prompt }))).await;
    assert_eq!(status, 201, "{body}");
    body["id"].as_str().unwrap().to_string()
}

/// Polls the task until [done] says so.
async fn until(srv: &TestServer, id: &str, done: impl Fn(&Value) -> bool) -> Value {
    for _ in 0..200 {
        let (status, body) = call(srv, true, Method::GET, &format!("/api/v1/agent/flows/{id}"), None).await;
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

/// What the model asks Agent mode to run, in the shell it runs commands in:
/// `sh`, and Windows PowerShell on Windows.
#[cfg(not(windows))]
mod sh {
    use std::path::Path;

    pub fn touch(p: &Path) -> String {
        format!("touch {}", p.display())
    }
    /// An allow rule for [touch] of anything in [dir].
    pub fn touch_in(dir: &Path) -> String {
        format!("touch {}/*", dir.display())
    }
    pub fn remove(p: &Path) -> String {
        format!("rm -rf {}", p.display())
    }
    pub fn remove_file(p: &Path) -> String {
        format!("rm -f {}", p.display())
    }
    /// Lists `/` one name a line, which has these.
    pub const LIST_ROOT: &str = "ls /";
    pub const ROOT_HAS: [&str; 2] = ["tmp", "usr"];
    pub const READ_FILE: &str = "cat /etc/hostname";
    /// A read, and the rule for it.
    pub const SYSTEM: &str = "uname -s";
    pub const SYSTEM_RULE: &str = "uname *";
    /// A change, never run, and the rule for it.
    pub const STOP_SERVICE: &str = "systemctl stop sbm-bypass-never";
    pub const STOP_RULE: &str = "systemctl stop *";
    pub const REMOVE_RULE: &str = "rm *";
}

#[cfg(windows)]
mod sh {
    use std::path::Path;

    pub fn touch(p: &Path) -> String {
        format!("New-Item -ItemType File -Force -Path {}", p.display())
    }
    pub fn touch_in(dir: &Path) -> String {
        format!("New-Item -ItemType File -Force -Path {}\\*", dir.display())
    }
    pub fn remove(p: &Path) -> String {
        format!("Remove-Item -Recurse -Force {}", p.display())
    }
    pub fn remove_file(p: &Path) -> String {
        format!("Remove-Item -Force {}", p.display())
    }
    pub const LIST_ROOT: &str = "Get-ChildItem -Name C:\\";
    pub const ROOT_HAS: [&str; 2] = ["Windows", "Users"];
    pub const READ_FILE: &str = "Get-Content C:\\Windows\\win.ini";
    pub const SYSTEM: &str = "Get-Date -Format o";
    pub const SYSTEM_RULE: &str = "Get-Date *";
    pub const STOP_SERVICE: &str = "Stop-Service sbm-bypass-never";
    pub const STOP_RULE: &str = "Stop-Service *";
    pub const REMOVE_RULE: &str = "Remove-Item *";
}

/// A path that is never there, under the temporary directory.
fn never(name: &str) -> PathBuf {
    std::env::temp_dir().join(name)
}

#[ntex::test]
async fn nothing_runs_until_it_is_configured() {
    let (srv, _) = server().await;
    let (s, body) = call(&srv, true, Method::POST, "/api/v1/agent/flows", Some(json!({ "prompt": "hi" }))).await;
    assert_eq!((s, body["error"].as_str()), (409, Some("notConfigured")));
    let (s, _) = call(&srv, false, Method::GET, "/api/v1/agent/flows", None).await;
    assert_eq!(s, 401);
    let (s, body) = call(
        &srv,
        true,
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
        Say::Tool("run_command", json!({ "command": sh::LIST_ROOT, "title": "List", "area": "files", "effect": "read" })),
        Say::Text("Listed."),
    ]);
    configure(&srv, &url).await;
    let id = start(&srv, "what is in /").await;
    let v = until(&srv, &id, |v| v["flow"]["status"] == "done").await;
    let r = results(&v);
    assert_eq!(r.len(), 1, "{v}");
    assert_eq!(r[0]["details"]["exitCode"], 0);
    let lines = r[0]["details"]["lines"].as_array().unwrap();
    assert!(lines.iter().any(|l| sh::ROOT_HAS.iter().any(|n| l[1] == *n)), "{lines:?}");
    assert_eq!(v["flow"]["areas"], json!(["files"]));
    assert_eq!(v["flow"]["line"], "Listed.");

    // Somebody else's task is not there for them.
}

#[ntex::test]
async fn a_plan_once_approved_runs_its_commands_without_asking_again() {
    let (srv, _) = server().await;
    let dir = scratch("plan");
    let made = dir.join("made");
    let touch = sh::touch(&made);
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
    let (s, _) = call(&srv, true, Method::POST, &format!("/api/v1/agent/flows/{id}/answer"), Some(json!({ "id": "nope", "action": "run" }))).await;
    assert_eq!(s, 409);
    let pid = v["pending"]["id"].as_str().unwrap();
    let (s, _) = call(&srv, true, Method::POST, &format!("/api/v1/agent/flows/{id}/answer"), Some(json!({ "id": pid, "action": "run" }))).await;
    assert_eq!(s, 204);
    let v = until(&srv, &id, |v| v["flow"]["status"] == "done").await;
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
        json!({ "command": sh::touch(&made), "title": "Create", "area": "files", "effect": "read" }),
    )]);
    configure(&srv, &url).await;
    let id = start(&srv, "make a file").await;
    let v = until(&srv, &id, |v| status(v) == "waiting").await;
    assert_eq!(v["pending"]["kind"], "confirm");
    assert_eq!(v["flow"]["waiting"], "confirm");
    let (s, _) = call(&srv, true, Method::POST, &format!("/api/v1/agent/flows/{id}/stop"), None).await;
    assert_eq!(s, 204);
    until(&srv, &id, |v| status(v) == "cancelled").await;
    assert!(!made.exists());
    let (s, _) = call(&srv, true, Method::DELETE, &format!("/api/v1/agent/flows/{id}"), None).await;
    assert_eq!(s, 204);
    let (s, _) = call(&srv, true, Method::GET, &format!("/api/v1/agent/flows/{id}"), None).await;
    assert_eq!(s, 404);
    let _ = std::fs::remove_dir_all(dir);
}

#[ntex::test]
async fn what_cannot_be_undone_needs_the_machine_named() {
    let (srv, _) = server().await;
    let dir = scratch("danger");
    let keep = dir.join("keep");
    std::fs::write(&keep, b"x").unwrap();
    let rm = sh::remove_file(&keep);
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
    let (s, body) = call(&srv, true, Method::POST, &answer, Some(json!({ "id": pid, "action": "run", "confirm": "nope" }))).await;
    assert_eq!((s, body["error"].as_str()), (400, Some("confirmMismatch")));
    let (s, _) = call(&srv, true, Method::POST, &answer, Some(json!({ "id": pid, "action": "alternative", "index": 0 }))).await;
    assert_eq!(s, 204);
    let v = until(&srv, &id, |v| v["flow"]["status"] == "done").await;
    assert!(keep.exists(), "{v}");
    assert_eq!(results(&v)[0]["details"]["alternative"], "Back it up first");
    assert!(!host.is_empty());
    let _ = std::fs::remove_dir_all(dir);
}

#[ntex::test]
async fn attached_files_go_to_the_task_and_with_it() {
    let (srv, _) = server().await;
    let url = model(vec![Say::Text("Seen."), Say::Text("Seen again.")]);
    configure(&srv, &url).await;
    let (s, log) = common::machine::post_bytes(&srv, "/api/v1/agent/files?name=..%2Fapp.log", "text/plain", b"boom at 12:00\n".to_vec()).await;
    assert_eq!(s, 201, "{log}");
    assert_eq!(log["name"], "app.log");
    let (_, png) = common::machine::post_bytes(&srv, "/api/v1/agent/files?name=shot.png", "image/png", b"\x89PNG fake".to_vec()).await;
    // Another account cannot use or remove them.
    // Files alone start a task, named after the first.
    let (s, body) = call(&srv, true, Method::POST, "/api/v1/agent/flows", Some(json!({ "prompt": "", "files": [log["id"], png["id"]] }))).await;
    assert_eq!(s, 201, "{body}");
    assert_eq!(body["title"], "app.log");
    let id = body["id"].as_str().unwrap().to_string();
    let v = until(&srv, &id, |v| v["flow"]["status"] == "done").await;
    // The prompt's block is served as the message's files, its words alone
    // as the text.
    let message = &v["entries"][0]["message"];
    assert_eq!(message["content"][0]["text"], "", "{v}");
    assert_eq!(message["content"][1]["type"], "image", "{v}");
    let listed = message["attachments"].as_array().unwrap();
    assert_eq!(listed.iter().map(|f| f["name"].as_str().unwrap()).collect::<Vec<_>>(), ["app.log", "shot.png"]);
    let path = listed[0]["path"].as_str().unwrap().to_string();
    assert!(std::path::Path::new(&path).exists(), "{path}");
    // Used once.
    let (s, _) = call(&srv, true, Method::POST, "/api/v1/agent/flows", Some(json!({ "prompt": "again", "files": [log["id"]] }))).await;
    assert_eq!(s, 400);
    // A reply takes files too, beside the ones the task has.
    let (_, more) = common::machine::post_bytes(&srv, "/api/v1/agent/files?name=app.log", "text/plain", b"second\n".to_vec()).await;
    let (s, body) = call(&srv, true, Method::POST, &format!("/api/v1/agent/flows/{id}/reply"), Some(json!({ "text": "and this", "files": [more["id"]] }))).await;
    assert_eq!(s, 200, "{body}");
    let v = until(&srv, &id, |v| status(v) == "done" && v["entries"].as_array().is_some_and(|e| e.len() >= 4)).await;
    let second = v["entries"].as_array().unwrap().iter().filter(|e| e["message"]["role"] == "user").nth(1).unwrap();
    assert_eq!(second["message"]["content"][0]["text"], "and this", "{v}");
    assert_eq!(second["message"]["attachments"][0]["name"], "app (2).log", "{v}");
    let (s, _) = call(&srv, true, Method::DELETE, &format!("/api/v1/agent/flows/{id}"), None).await;
    assert_eq!(s, 204);
    assert!(!std::path::Path::new(&path).exists());
}

#[ntex::test]
async fn a_finished_task_takes_a_reply_as_a_new_run() {
    let (srv, _) = server().await;
    let url = model(vec![Say::Text("Hello.")]);
    configure(&srv, &url).await;
    let id = start(&srv, "hi").await;
    until(&srv, &id, |v| v["flow"]["status"] == "done").await;
    let (s, body) = call(&srv, true, Method::POST, &format!("/api/v1/agent/flows/{id}/reply"), Some(json!({ "text": "again" }))).await;
    assert_eq!(s, 200, "{body}");
    let v = until(&srv, &id, |v| status(v) == "done" && v["entries"].as_array().unwrap().iter().filter(|e| e["message"]["role"] == "user").count() == 2).await;
    assert_eq!(v["flow"]["title"], "Title");
}

#[ntex::test]
async fn an_endpoint_being_set_up_lists_its_models() {
    let (srv, _) = server().await;
    let url = model(vec![]);
    let probe = "/api/v1/agent/models/probe";
    let (s, body) = call(&srv, true, Method::POST, probe, Some(json!({ "api": "openai-completions", "baseUrl": url, "apiKey": "k" }))).await;
    assert_eq!(s, 200, "{body}");
    let ids: Vec<&str> = body.as_array().unwrap().iter().map(|m| m["id"].as_str().unwrap()).collect();
    assert_eq!(ids, ["mock-a", "mock-b"]);

    let (s, body) = call(&srv, true, Method::POST, probe, Some(json!({ "api": "openai-completions", "baseUrl": "https://" }))).await;
    assert_eq!((s, body["error"].as_str()), (400, Some("invalidBaseUrl")));
    let (s, body) = call(&srv, true, Method::POST, probe, Some(json!({ "api": "openai-completions", "baseUrl": "http://10.9.9.9/v1" }))).await;
    assert_eq!((s, body["error"].as_str()), (400, Some("invalidBaseUrl")));
}

#[ntex::test]
async fn a_model_the_endpoint_lists_is_usable_without_opening_settings() {
    let (srv, _) = server().await;
    let url = model(vec![Say::Text("Hello.")]);
    // Nothing named by hand: `mock-a` is only what the endpoint lists.
    let (code, body) = call(
        &srv,
        true,
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
async fn the_memory_is_kept_across_tasks() {
    let (srv, _) = server().await;
    let url = model(vec![
        Say::Tool("memory_write", json!({ "path": "/memories/user.md", "content": "Prefers apt over snap" })),
        Say::Tool("memory_view", json!({ "path": "/memories/user.md" })),
        Say::Text("Noted."),
    ]);
    configure(&srv, &url).await;
    let id = start(&srv, "remember that I prefer apt").await;
    let v = until(&srv, &id, |v| v["flow"]["status"] == "done").await;
    let r = results(&v);
    assert_eq!(r[0]["content"][0]["text"], "Created /memories/user.md", "{v}");
    assert_eq!(r[1]["content"][0]["text"], "     1\tPrefers apt over snap\n", "{v}");

    let (s, list) = call(&srv, true, Method::GET, "/api/v1/agent/memory", None).await;
    assert_eq!(s, 200, "{list}");
    assert_eq!(list["files"][0]["path"], "user.md");
    assert_eq!(list["files"][0]["chars"], 21);
    let (s, file) = call(&srv, true, Method::GET, "/api/v1/agent/memory/file?path=user.md", None).await;
    assert_eq!(s, 200);
    assert_eq!(file["content"], "Prefers apt over snap");

    // Another account's memory is its own.

    // Edited and removed by the account, within the memory's rules.
    let put = |path: &'static str, content: &'static str| call(&srv, true, Method::PUT, "/api/v1/agent/memory/file", Some(json!({ "path": path, "content": content })));
    assert_eq!(put("MEMORY.md", "- [User](user.md) — preferences").await.0, 204);
    let (s, body) = put("../etc/passwd", "x").await;
    assert_eq!((s, body["error"].as_str()), (400, Some("invalidMemory")), "{body}");
    assert_eq!(put("user.md/x", "x").await.0, 400);
    assert_eq!(put("/memories", "x").await.0, 400);
    let (s, _) = call(&srv, true, Method::DELETE, "/api/v1/agent/memory/file?path=user.md", None).await;
    assert_eq!(s, 204);
    let (_, list) = call(&srv, true, Method::GET, "/api/v1/agent/memory", None).await;
    assert_eq!(list["files"].as_array().unwrap().iter().map(|f| f["path"].clone()).collect::<Vec<_>>(), [json!("MEMORY.md")]);
}

/// The `data:` events of a stream.
fn events_of(body: &str) -> Vec<Value> {
    body.lines().filter_map(|l| l.strip_prefix("data: ")).filter_map(|j| serde_json::from_str(j).ok()).collect()
}

#[ntex::test]
async fn a_search_only_reads_and_can_be_carried_into_a_task() {
    let (srv, _) = server().await;
    let url = model(vec![
        // Refused: it would change the machine.
        Say::Tool("run_command", json!({ "command": sh::remove(&never("sbm-search-never")), "title": "Remove" })),
        Say::Tool("run_command", json!({ "command": sh::SYSTEM, "title": "System" })),
        Say::Tool("report_results", json!({
            "items": [{ "kind": "process", "title": "sshd", "sub": "PID 1", "ref": "1" }],
            "followups": [{ "label": "Restart", "request": "restart sshd" }],
        })),
        Say::Text("It runs."),
    ]);
    configure(&srv, &url).await;
    let (s, body) = common::machine::post_text(&srv, "/api/v1/agent/search", json!({ "query": "what runs here?", "kind": "question" })).await;
    assert_eq!(s, 200, "{body}");
    let ev = events_of(&body);
    assert_eq!(ev[0], json!({ "type": "kind", "kind": "question" }), "{body}");
    let steps: Vec<&Value> = ev.iter().filter(|e| e["type"] == "step").collect();
    assert!(steps.iter().all(|e| e["command"] == sh::SYSTEM), "the change never ran: {body}");
    assert!(steps.iter().any(|e| e["state"] == "done"), "{body}");
    let items = ev.iter().find(|e| e["type"] == "items").unwrap_or_else(|| panic!("no items: {body}"));
    assert_eq!(items["items"][0]["ref"], "1", "{body}");
    assert_eq!(items["followups"][0]["request"], "restart sshd");
    let done = ev.iter().find(|e| e["type"] == "done").unwrap_or_else(|| panic!("no done: {body}"));
    assert_eq!(done["answer"], "It runs.");
    assert_eq!(done["steps"], 1);
    let id = done["id"].as_str().unwrap().to_string();

    // Not anybody's to adopt but the account's.
    let (s, view) = call(&srv, true, Method::POST, &format!("/api/v1/agent/search/{id}/task"), Some(json!({}))).await;
    assert_eq!(s, 201, "{view}");
    assert_eq!(view["id"], id);
    assert_eq!(view["title"], "what runs here?");
    // The conversation came along.
    let v = until(&srv, &id, |v| v["entries"].as_array().is_some_and(|e| !e.is_empty())).await;
    assert!(results(&v).len() >= 2, "{v}");
    // Once only.
    let (s, _) = call(&srv, true, Method::POST, &format!("/api/v1/agent/search/{id}/task"), Some(json!({}))).await;
    assert_eq!(s, 404);
}

#[ntex::test]
async fn a_change_is_drafted_never_run() {
    let (srv, _) = server().await;
    let url = model(vec![
        Say::Tool("draft_plan", json!({ "steps": [
            { "text": "read a file", "command": sh::READ_FILE, "effect": "read" },
            { "text": "wipe it", "command": sh::remove(&never("sbm-search-never")), "effect": "read" },
        ] })),
        Say::Text("Unreachable."),
    ]);
    configure(&srv, &url).await;
    let (s, body) = common::machine::post_text(&srv, "/api/v1/agent/search", json!({ "query": "clean up", "kind": "change" })).await;
    assert_eq!(s, 200, "{body}");
    let ev = events_of(&body);
    let plan = ev.iter().find(|e| e["type"] == "plan").unwrap_or_else(|| panic!("no plan: {body}"));
    assert_eq!(plan["steps"][0]["effect"], "read");
    // The command's shape outranks the model's word.
    assert_eq!(plan["steps"][1]["effect"], "danger", "{body}");
    assert!(ev.iter().all(|e| e["type"] != "step"), "{body}");
    assert!(ev.iter().any(|e| e["type"] == "done"), "{body}");

    // Without shell, no search.
}

async fn set_permissions(srv: &TestServer, p: Value) {
    let (s, body) = call(srv, true, Method::PUT, "/api/v1/agent/permissions", Some(p)).await;
    assert_eq!(s, 200, "{body}");
}

#[ntex::test]
async fn the_operators_rules_deny_ask_and_allow() {
    let (srv, _) = server().await;
    let dir = scratch("rules");
    let made = dir.join("made");
    let touch = sh::touch(&made);
    let url = model(vec![
        Say::Tool("run_command", json!({ "command": sh::SYSTEM, "title": "System", "area": "system", "effect": "read" })),
        Say::Tool("run_command", json!({ "command": touch.clone(), "title": "Touch", "area": "files", "effect": "change" })),
        Say::Text("Done."),
    ]);
    configure(&srv, &url).await;
    // Only an admin sets them, and a rule allowing anything is refused.
    let (s, body) = call(&srv, true, Method::PUT, "/api/v1/agent/permissions", Some(json!({ "rules": { "allow": ["*"] } }))).await;
    assert_eq!((s, body["error"].as_str()), (400, Some("invalidPermissions")), "{body}");
    set_permissions(&srv, json!({ "rules": { "deny": [sh::SYSTEM_RULE], "allow": [sh::touch_in(&dir)] } })).await;
    let (_, read) = call(&srv, true, Method::GET, "/api/v1/agent/permissions", None).await;
    assert_eq!(read["permissions"]["rules"]["deny"], json!([sh::SYSTEM_RULE]));
    assert!(read["defaults"]["soft_deny"].as_array().is_some_and(|l| !l.is_empty()), "{read}");

    let id = start(&srv, "go").await;
    let v = until(&srv, &id, |v| v["flow"]["status"] == "done").await;
    let r = results(&v);
    // A read the rules deny is refused; a change they allow runs unasked.
    assert_eq!(r[0]["isError"], true, "{v}");
    assert!(r[0]["content"][0]["text"].as_str().unwrap().contains(sh::SYSTEM_RULE), "{v}");
    assert_eq!(r[1]["details"]["exitCode"], 0, "{v}");
    assert!(made.exists());
    let _ = std::fs::remove_dir_all(&dir);
}

/// Starts a task in [mode]; answers the status and body.
async fn start_in(srv: &TestServer, prompt: &str, mode: &str) -> (u16, Value) {
    let (status, body) = call(srv, true, Method::POST, "/api/v1/agent/flows", Some(json!({ "prompt": prompt, "mode": mode }))).await;
    (status, body)
}

#[ntex::test]
async fn always_allow_adds_the_rule_and_runs() {
    let (srv, _) = server().await;
    let dir = scratch("always");
    let one = dir.join("one");
    let url = model(vec![
        Say::Tool("run_command", json!({ "command": sh::touch(&one), "title": "Touch", "area": "files", "effect": "change" })),
        Say::Text("Done."),
    ]);
    configure(&srv, &url).await;
    let id = start(&srv, "go").await;
    let v = until(&srv, &id, |v| !v["pending"].is_null()).await;
    // Word for word: the second word is an option.
    let rule = sh::touch(&one);
    assert_eq!(v["pending"]["allowRule"], rule.as_str(), "{v}");
    let pid = v["pending"]["id"].as_str().unwrap().to_string();
    // A stale prompt adds nothing.
    let (s, _) = call(&srv, true, Method::POST, &format!("/api/v1/agent/flows/{id}/answer"), Some(json!({ "id": "old", "action": "always" }))).await;
    assert_eq!(s, 409);
    let (s, body) = call(&srv, true, Method::POST, &format!("/api/v1/agent/flows/{id}/answer"), Some(json!({ "id": pid, "action": "always" }))).await;
    assert_eq!(s, 204, "{body}");
    until(&srv, &id, |v| v["flow"]["status"] == "done").await;
    assert!(one.exists());
    let (_, read) = call(&srv, true, Method::GET, "/api/v1/agent/permissions", None).await;
    assert_eq!(read["permissions"]["rules"]["allow"], json!([rule]));
    // The same command in another task runs unasked now.
    std::fs::remove_file(&one).unwrap();
    let id = start(&srv, "again").await;
    let v = until(&srv, &id, |v| !v["pending"].is_null() || status(v) == "done").await;
    assert!(v["pending"].is_null(), "{v}");
    assert!(one.exists());
    let _ = std::fs::remove_dir_all(&dir);
}

#[ntex::test]
async fn bypass_runs_destruction_unasked_but_the_rules_still_hold() {
    let (srv, _) = server().await;
    let dir = scratch("bypass");
    let made = dir.join("made");
    let doomed = dir.join("doomed");
    std::fs::write(&doomed, "x").unwrap();
    let url = model(vec![
        Say::Tool("run_command", json!({ "command": sh::touch(&made), "title": "Touch", "area": "files", "effect": "change" })),
        Say::Tool("run_command", json!({ "command": sh::remove(&doomed), "title": "Remove", "area": "files", "effect": "danger" })),
        Say::Tool("run_command", json!({ "command": sh::SYSTEM, "title": "System", "area": "system", "effect": "read" })),
        Say::Tool("run_command", json!({ "command": sh::STOP_SERVICE, "title": "Stop", "area": "system", "effect": "change" })),
        Say::Text("Done."),
    ]);
    configure(&srv, &url).await;
    set_permissions(&srv, json!({ "rules": { "deny": [sh::SYSTEM_RULE], "ask": [sh::STOP_RULE] } })).await;
    let (s, body) = start_in(&srv, "go", "bypass").await;
    assert_eq!(s, 201, "{body}");
    assert_eq!(body["mode"], "bypass");
    let id = body["id"].as_str().unwrap().to_string();
    // The ask rule stops it; everything before ran unasked but the denied read.
    let v = until(&srv, &id, |v| !v["pending"].is_null() || status(v) != "running").await;
    assert_eq!(v["pending"]["kind"], "confirm", "{v}");
    let r = results(&v);
    assert!(made.exists(), "{v}");
    assert!(!doomed.exists(), "{v}");
    assert_eq!(r[2]["isError"], true, "{v}");
    let (s, _) = call(&srv, true, Method::POST, &format!("/api/v1/agent/flows/{id}/stop"), None).await;
    assert_eq!(s, 204);
    let _ = std::fs::remove_dir_all(&dir);
}

#[ntex::test]
async fn bypass_can_be_turned_off() {
    let (srv, _) = server().await;
    let url = model(vec![Say::Text("Done.")]);
    configure(&srv, &url).await;
    let (_, list) = call(&srv, true, Method::GET, "/api/v1/agent/flows", None).await;
    assert_eq!((list["defaultMode"].as_str(), list["bypassAllowed"].as_bool()), (Some("manual"), Some(true)), "{list}");
    // The default cannot be what is turned off.
    let (s, _) = call(&srv, true, Method::PUT, "/api/v1/agent/permissions", Some(json!({ "defaultMode": "bypass", "disableBypass": true }))).await;
    assert_eq!(s, 400);
    set_permissions(&srv, json!({ "defaultMode": "auto", "disableBypass": true })).await;
    let (s, body) = start_in(&srv, "go", "bypass").await;
    assert_eq!((s, body["error"].as_str()), (400, Some("bypassDisabled")), "{body}");
    // Absent is the default.
    let id = start(&srv, "go").await;
    let v = until(&srv, &id, |v| v["flow"]["status"] == "done").await;
    assert_eq!(v["flow"]["mode"], "auto", "{v}");
}

#[ntex::test]
async fn auto_mode_runs_what_the_judge_allows_and_refuses_what_it_blocks() {
    for (judge, runs) in [
        (r#"{"decision":"allow","rule":"","reason":"routine"}"#, true),
        (r#"{"decision":"block","rule":"Data Loss","reason":"not asked for"}"#, false),
    ] {
        let (srv, _) = server().await;
        let dir = scratch(if runs { "auto-allow" } else { "auto-block" });
        let made = dir.join("made");
        let url = model_judging(
            vec![
                Say::Tool("run_command", json!({ "command": sh::touch(&made), "title": "Touch", "area": "files", "effect": "change" })),
                Say::Text("Done."),
            ],
            judge,
        );
        configure(&srv, &url).await;
        set_permissions(&srv, json!({ "defaultMode": "auto" })).await;
        let id = start(&srv, "make the file").await;
        let v = until(&srv, &id, |v| v["flow"]["status"] == "done").await;
        let r = results(&v);
        assert_eq!(made.exists(), runs, "{v}");
        if !runs {
            assert_eq!(r[0]["isError"], true);
            assert!(r[0]["content"][0]["text"].as_str().unwrap().contains("[Data Loss]"), "{v}");
        }
        let _ = std::fs::remove_dir_all(&dir);
    }
}

#[ntex::test]
async fn auto_mode_asks_when_the_judge_says_nothing_usable_and_destruction_always_asks() {
    let (srv, _) = server().await;
    let url = model_judging(
        vec![
            Say::Tool("run_command", json!({ "command": sh::touch(&never("sbm-auto-unsure-never")), "title": "Touch", "area": "files", "effect": "change" })),
            Say::Text("Done."),
        ],
        "I think so.",
    );
    configure(&srv, &url).await;
    set_permissions(&srv, json!({ "defaultMode": "auto", "rules": { "allow": [sh::REMOVE_RULE] } })).await;
    let id = start(&srv, "go").await;
    let v = until(&srv, &id, |v| !v["pending"].is_null()).await;
    assert_eq!(v["pending"]["kind"], "confirm", "{v}");
    let (s, _) = call(&srv, true, Method::POST, &format!("/api/v1/agent/flows/{id}/stop"), None).await;
    assert_eq!(s, 204);

    // Removing is allowed by a rule, yet what cannot be undone still names the machine.
    let url = model_judging(
        vec![
            Say::Tool("run_command", json!({ "command": sh::remove(&never("sbm-auto-rm-never")), "title": "Remove", "area": "files", "effect": "danger" })),
            Say::Text("Done."),
        ],
        r#"{"decision":"allow"}"#,
    );
    configure(&srv, &url).await;
    let id = start(&srv, "go").await;
    let v = until(&srv, &id, |v| !v["pending"].is_null()).await;
    assert_eq!(v["pending"]["kind"], "danger", "{v}");
}

#[ntex::test]
async fn auto_mode_judges_a_plan_and_bypass_approves_one() {
    let (srv, _) = server().await;
    let dir = scratch("auto-plan");
    let made = dir.join("made");
    let touch = sh::touch(&made);
    let script = vec![
        Say::Tool("propose_plan", json!({ "title": "Make it", "summary": "Make the file.", "steps": [{ "text": "Make the file", "command": touch }] })),
        Say::Tool("run_command", json!({ "command": touch, "title": "Touch", "area": "files", "effect": "change" })),
        Say::Text("Done."),
    ];
    let url = model_judging(script.clone(), r#"{"decision":"allow","rule":"","reason":"asked for"}"#);
    configure(&srv, &url).await;
    set_permissions(&srv, json!({ "defaultMode": "auto" })).await;
    let id = start(&srv, "make the file").await;
    let v = until(&srv, &id, |v| v["flow"]["status"] == "done").await;
    let r = results(&v);
    assert_eq!(r[0]["details"]["by"], "auto", "{v}");
    assert!(made.exists(), "{v}");

    let _ = std::fs::remove_file(&made);
    let url = model(script);
    configure(&srv, &url).await;
    let (s, body) = start_in(&srv, "make the file", "bypass").await;
    assert_eq!(s, 201, "{body}");
    let v = until(&srv, body["id"].as_str().unwrap(), |v| status(v) == "done").await;
    assert_eq!(results(&v)[0]["details"]["by"], "bypass", "{v}");
    assert!(made.exists(), "{v}");
    let _ = std::fs::remove_dir_all(&dir);
}

#[ntex::test]
async fn the_copy_for_pi_is_off_until_turned_on_and_kept_by_writes_without_it() {
    let (srv, _) = server().await;
    let url = model(vec![Say::Text("ok")]);
    configure(&srv, &url).await;
    let (_, s) = call(&srv, true, Method::GET, "/api/v1/agent/settings", None).await;
    assert_eq!(s["piSessions"], false, "{s}");
    let write = |pi: Option<bool>| {
        let mut w = json!({ "model": { "provider": "mock", "id": "mock" }, "providers": s["providers"].clone() });
        if let Some(pi) = pi {
            w["piSessions"] = json!(pi);
        }
        w
    };
    let (status, body) = call(&srv, true, Method::PUT, "/api/v1/agent/settings", Some(write(Some(true)))).await;
    assert_eq!((status, body["piSessions"].clone()), (200, json!(true)), "{body}");
    // A panel that does not know the setting leaves it alone.
    let (status, body) = call(&srv, true, Method::PUT, "/api/v1/agent/settings", Some(write(None))).await;
    assert_eq!((status, body["piSessions"].clone()), (200, json!(true)), "{body}");
}

#[ntex::test]
async fn the_list_pages_newest_first_and_searches_titles() {
    let (srv, db) = server().await;
    let user: i64 = sqlx::query_scalar("SELECT id FROM users").fetch_one(&db).await.unwrap();
    // Five tasks, two of them changed at the same moment: the cursor tells them apart by id.
    for (id, title, at) in [
        ("t1", "check disks", "2026-10-01T00:00:00+00:00"),
        ("t2", "restart nginx", "2026-10-02T00:00:00+00:00"),
        ("t3", "disk usage of /var", "2026-10-03T00:00:00+00:00"),
        ("t4", "update packages", "2026-10-03T00:00:00+00:00"),
        ("t5", "100% CPU", "2026-10-04T00:00:00+00:00"),
    ] {
        sqlx::query("INSERT INTO agent_flow (id, user_id, title, status, created_at, updated_at) VALUES (?, ?, ?, 'done', ?, ?)")
            .bind(id)
            .bind(user)
            .bind(title)
            .bind(at)
            .bind(at)
            .execute(&db)
            .await
            .unwrap();
    }
    let ids = |v: &Value| v["flows"].as_array().unwrap().iter().map(|f| f["id"].as_str().unwrap().to_string()).collect::<Vec<_>>();
    let get = |path: String| {
        let srv = &srv;
        async move { call(srv, true, Method::GET, &path, None).await }
    };

    let (status, all) = get("/api/v1/agent/flows".into()).await;
    assert_eq!(status, 200, "{all}");
    assert_eq!(ids(&all), ["t5", "t4", "t3", "t2", "t1"], "every task without a limit");
    assert!(all["next"].is_null());

    let mut seen = Vec::new();
    let mut cursor: Option<String> = None;
    loop {
        let path = match &cursor {
            Some(c) => format!("/api/v1/agent/flows?limit=2&before={}", percent_encoding::utf8_percent_encode(c, percent_encoding::NON_ALPHANUMERIC)),
            None => "/api/v1/agent/flows?limit=2".into(),
        };
        let (status, page) = get(path).await;
        assert_eq!(status, 200, "{page}");
        assert!(page["flows"].as_array().unwrap().len() <= 2);
        seen.extend(ids(&page));
        match page["next"].as_str() {
            Some(c) => cursor = Some(c.to_string()),
            None => break,
        }
    }
    assert_eq!(seen, ["t5", "t4", "t3", "t2", "t1"], "pages neither skip nor repeat");

    let (_, found) = get("/api/v1/agent/flows?q=DISK".into()).await;
    assert_eq!(ids(&found), ["t3", "t1"], "titles, ignoring case");
    // `%` and `_` are what they say, not patterns.
    let (_, found) = get("/api/v1/agent/flows?q=100%25".into()).await;
    assert_eq!(ids(&found), ["t5"]);
    let (_, found) = get("/api/v1/agent/flows?q=_".into()).await;
    assert!(ids(&found).is_empty(), "{found}");
    let (_, found) = get("/api/v1/agent/flows?q=disk&limit=1".into()).await;
    assert_eq!((ids(&found), found["next"].is_string()), (vec!["t3".to_string()], true));
}

#[ntex::test]
async fn a_task_runs_with_the_model_and_thinking_its_account_picked() {
    let (srv, _) = server().await;
    let url = model(vec![Say::Text("one"), Say::Text("two")]);
    configure(&srv, &url).await;

    let (status, c) = call(&srv, true, Method::GET, "/api/v1/agent/choices", None).await;
    assert_eq!(status, 200, "{c}");
    assert!(c["models"].as_array().unwrap().iter().any(|m| m["provider"] == "mock" && m["id"] == "mock"), "{c}");
    assert_eq!(c["model"], json!({ "provider": "mock", "id": "mock" }));
    assert!(c["thinkingLevels"].as_array().unwrap().contains(&json!("high")));
    assert!(!c.to_string().contains("sk-test"), "no key: {c}");

    let start = |extra: Value| {
        let mut body = json!({ "prompt": "hi" });
        for (k, v) in extra.as_object().unwrap() {
            body[k] = v.clone();
        }
        body
    };
    let (status, v) = call(&srv, true, Method::POST, "/api/v1/agent/flows", Some(start(json!({ "model": { "provider": "nope", "id": "x" } })))).await;
    assert_eq!((status, v["error"].as_str()), (400, Some("unknownModel")), "{v}");
    let (status, v) = call(&srv, true, Method::POST, "/api/v1/agent/flows", Some(start(json!({ "thinkingLevel": "max" })))).await;
    assert_eq!((status, v["error"].as_str()), (400, Some("invalidThinkingLevel")), "{v}");

    let (status, v) = call(
        &srv,
        true,
        Method::POST,
        "/api/v1/agent/flows",
        Some(start(json!({ "model": { "provider": "mock", "id": "mock" }, "thinkingLevel": "low" }))),
    )
    .await;
    assert_eq!(status, 201, "{v}");
    assert_eq!((v["model"]["id"].as_str(), v["thinkingLevel"].as_str()), (Some("mock"), Some("low")), "{v}");
    let id = v["id"].as_str().unwrap().to_string();
    until(&srv, &id, |v| v["flow"]["status"] == "done").await;

    // A reply changes it from then on; what it does not name stays.
    let (status, v) = call(&srv, true, Method::POST, &format!("/api/v1/agent/flows/{id}/reply"), Some(json!({ "text": "more", "thinkingLevel": "high" }))).await;
    assert_eq!(status, 200, "{v}");
    let v = until(&srv, &id, |v| v["flow"]["status"] == "done").await;
    assert_eq!((v["flow"]["model"]["id"].as_str(), v["flow"]["thinkingLevel"].as_str()), (Some("mock"), Some("high")), "{v}");
    let (_, list) = call(&srv, true, Method::GET, "/api/v1/agent/flows", None).await;
    assert_eq!(list["flows"][0]["thinkingLevel"], "high", "kept in the row: {list}");
}

/// An MCP server (Streamable HTTP, JSON answers) on loopback: `list_lights`
/// says it changes nothing, `turn_on` does not. Each call and the token it
/// came with (`Authorization` or `X-Api-Key`) is recorded.
fn mcp_server(calls: std::sync::Arc<std::sync::Mutex<Vec<(String, String)>>>) -> String {
    mcp_server_with(calls, 0)
}

/// [mcp_server] with [extra] more tools, `noop_<n>`, each a read.
fn mcp_server_with(calls: std::sync::Arc<std::sync::Mutex<Vec<(String, String)>>>, extra: usize) -> String {
    let listener = TcpListener::bind("127.0.0.1:0").unwrap();
    let addr = listener.local_addr().unwrap();
    std::thread::spawn(move || {
        for conn in listener.incoming() {
            let Ok(mut conn) = conn else { return };
            let calls = calls.clone();
            std::thread::spawn(move || {
                let mut reader = BufReader::new(conn.try_clone().unwrap());
                let (mut len, mut token) = (0usize, String::new());
                loop {
                    let mut line = String::new();
                    if reader.read_line(&mut line).unwrap_or(0) == 0 {
                        return;
                    }
                    let l = line.trim_end();
                    if l.is_empty() {
                        break;
                    }
                    let lower = l.to_ascii_lowercase();
                    if let Some(v) = lower.strip_prefix("content-length:") {
                        len = v.trim().parse().unwrap();
                    }
                    for name in ["authorization:", "x-api-key:"] {
                        if lower.starts_with(name) {
                            token = l[name.len()..].trim().to_string();
                        }
                    }
                }
                let mut body = vec![0u8; len];
                reader.read_exact(&mut body).unwrap();
                let msg: Value = serde_json::from_slice(&body).unwrap();
                let result = match msg["method"].as_str().unwrap_or_default() {
                    "initialize" => json!({ "protocolVersion": "2025-06-18", "capabilities": { "tools": {} }, "serverInfo": { "name": "Lights" } }),
                    "tools/list" => {
                        let mut tools = vec![
                            json!({ "name": "list_lights", "description": "Lists the lights", "inputSchema": { "type": "object" }, "annotations": { "readOnlyHint": true } }),
                            json!({ "name": "turn_on", "description": "Turns a light on", "inputSchema": { "type": "object", "properties": { "id": { "type": "string" } } } }),
                        ];
                        tools.extend((0..extra).map(|n| json!({ "name": format!("noop_{n}"), "description": "Does nothing", "inputSchema": { "type": "object" }, "annotations": { "readOnlyHint": true } })));
                        json!({ "tools": tools })
                    }
                    "tools/call" => {
                        let name = msg["params"]["name"].as_str().unwrap_or_default().to_string();
                        calls.lock().unwrap().push((name.clone(), token));
                        json!({ "content": [{ "type": "text", "text": format!("{name}: {}", msg["params"]["arguments"]) }] })
                    }
                    _ => {
                        let _ = write!(conn, "HTTP/1.1 202 Accepted\r\ncontent-length: 0\r\nconnection: close\r\n\r\n");
                        return;
                    }
                };
                let body = json!({ "jsonrpc": "2.0", "id": msg["id"], "result": result }).to_string();
                let _ = write!(
                    conn,
                    "HTTP/1.1 200 OK\r\ncontent-type: application/json\r\nmcp-session-id: s1\r\ncontent-length: {}\r\nconnection: close\r\n\r\n{body}",
                    body.len()
                );
            });
        }
    });
    format!("http://{addr}/mcp")
}

/// A deployed app's MCP server joins Agent mode on its own: at its port
/// setting's port, once the token it asks for is given; the token never
/// comes back out, and turning it off drops it.
#[ntex::test]
async fn a_deployed_apps_mcp_server_connects_once_its_token_is_given() {
    let calls = std::sync::Arc::new(std::sync::Mutex::new(Vec::new()));
    let mcp = mcp_server(calls.clone());
    let port: u16 = mcp.trim_start_matches("http://127.0.0.1:").trim_end_matches("/mcp").parse().unwrap();
    let apps = scratch("app-mcp");
    let package = apps.join("acme.lights");
    std::fs::create_dir_all(&package).unwrap();
    std::fs::write(
        package.join("manifest.toml"),
        r#"schema = 1
publisher = "acme"
name = "lights"
project = "Lights"
version = "1.0"
homepage = "https://example.com"
source = "https://example.com/src"
glyph = "lightbulb"
tone = "teal"
title = { en = "Lights" }
description = { en = "Lights." }
license = { spdx = "MIT", url = "https://example.com/LICENSE" }
compose = { files = ["compose.yaml"] }
web = { port = "port" }

[[secrets]]
env = "MCP_KEY"

[[settings]]
key = "port"
type = "port"
env = "PORT"
default = 8123
label = { en = "Port" }

[[settings]]
key = "mcp_port"
type = "port"
env = "MCP_PORT"
default = 8124
label = { en = "MCP" }

[[mcp]]
port = "port"
path = "/mcp"
publisher = "builtin"
[mcp.auth]
scheme = "Bearer"
asked = { en = "Make a token in your profile." }

[[mcp]]
port = "mcp_port"
path = "/keyed"
publisher = "official"
service = "mcp"
source = "https://example.com/mcp"
[mcp.auth]
header = "X-Api-Key"
secret = "MCP_KEY"
"#,
    )
    .unwrap();
    let digest = "a".repeat(64);
    std::fs::write(
        package.join("compose.yaml"),
        format!("services:\n  app:\n    image: x\n    ports: ['${{PORT}}:8123']\n  mcp:\n    image: x@sha256:{digest}\n    environment:\n      KEY: ${{MCP_KEY}}\n    ports: ['127.0.0.1:${{MCP_PORT}}:80']\n"),
    )
    .unwrap();
    let config = server_box_monitor::core::config::Config {
        stacks: Some(server_box_monitor::core::config::StacksConfig { local_apps: Some(apps.display().to_string()), ..Default::default() }),
        ..Default::default()
    };
    let (srv, state) = common::machine::server_with(config).await;
    let row = server_box_monitor::stacks::store::StackRow {
        id: "acme.lights".into(),
        version: "1.0".into(),
        settings: [("port".to_string(), json!(port)), ("mcp_port".to_string(), json!(port))].into(),
        proxy_port: 3790,
        state: "installed".into(),
        license: "MIT".into(),
        license_accepted_at: String::new(),
        installed_at: String::new(),
        updated_at: String::new(),
        last_error: None,
        stopped: false,
        update_noticed: None,
    };
    assert!(server_box_monitor::stacks::store::insert(&state.db, &row).await.unwrap());
    server_box_monitor::stacks::store::finish(&state.db, "acme.lights", None).await.unwrap();
    let dir = state.stacks.dir("acme.lights");
    std::fs::create_dir_all(&dir).unwrap();
    std::fs::write(dir.join(".env"), "PORT='1'\nMCP_KEY='key-from-env'\n").unwrap();

    let id = fl_pi_llm::host::mcp::server_id(&mcp);
    let status_of = |body: &Value| body["status"].as_array().unwrap().iter().find(|s| s["id"] == id.as_str()).cloned();
    // Listed, waiting for its token; the one whose key the app's env file
    // holds connects on its own.
    let (s, body) = call(&srv, true, Method::GET, "/api/v1/agent/mcp", None).await;
    assert_eq!(s, 200, "{body}");
    assert!(!body.to_string().contains("key-from-env"), "{body}");
    let keyed = fl_pi_llm::host::mcp::server_id(&format!("http://127.0.0.1:{port}/keyed"));
    let keyed_status = body["status"].as_array().unwrap().iter().find(|s| s["id"] == keyed.as_str()).cloned().unwrap();
    assert_eq!(keyed_status["connected"], true, "{body}");
    assert_eq!(body["apps"][1]["credential"], json!({ "kind": "secret" }));
    assert_eq!(body["apps"][0]["stack"], "acme.lights", "{body}");
    assert_eq!(body["apps"][0]["url"], mcp.as_str());
    assert_eq!(body["apps"][0]["credential"], json!({ "kind": "asked", "hint": { "en": "Make a token in your profile." }, "given": false }));
    assert_eq!(status_of(&body).unwrap()["error"], "needsToken", "{body}");

    // Only an asked credential takes a token; a token with a line break is refused.
    let at = "/api/v1/agent/mcp/apps/acme.lights/0";
    let (s, _) = call(&srv, true, Method::PUT, at, Some(json!({ "token": "a\nb" }))).await;
    assert_eq!(s, 400);
    let (s, _) = call(&srv, true, Method::PUT, "/api/v1/agent/mcp/apps/acme.lights/1", Some(json!({ "token": "x" }))).await;
    assert_eq!(s, 400, "its key is the app's own");
    let (s, _) = call(&srv, true, Method::PUT, "/api/v1/agent/mcp/apps/acme.lights/2", Some(json!({ "token": "x" }))).await;
    assert_eq!(s, 404);
    let (s, body) = call(&srv, true, Method::PUT, at, Some(json!({ "token": "tok-2" }))).await;
    assert_eq!(s, 200, "{body}");
    assert!(!body.to_string().contains("tok-2"), "{body}");
    assert_eq!(body["apps"][0]["credential"]["given"], true);
    let connected = status_of(&body).unwrap();
    assert_eq!(connected["connected"], true, "{body}");
    assert_eq!(connected["tools"].as_array().unwrap().len(), 2);

    // A task uses it with the token, after the scheme.
    let list: &'static str = Box::leak(fl_pi_llm::host::mcp::tool_name(&id, "list_lights").into_boxed_str());
    let keyed_list: &'static str = Box::leak(fl_pi_llm::host::mcp::tool_name(&keyed, "list_lights").into_boxed_str());
    let url = model(vec![Say::Tool(list, json!({})), Say::Tool(keyed_list, json!({})), Say::Text("Listed.")]);
    configure(&srv, &url).await;
    let flow = start(&srv, "which lights are there").await;
    until(&srv, &flow, |v| status(v) == "done").await;
    assert_eq!(calls.lock().unwrap().iter().map(|(_, t)| t.as_str()).collect::<Vec<_>>(), ["Bearer tok-2", "key-from-env"]);

    // Off: not connected, nothing waiting.
    let (_, body) = call(&srv, true, Method::PUT, at, Some(json!({ "enabled": false }))).await;
    assert_eq!(body["apps"][0]["enabled"], false);
    assert!(status_of(&body).is_none(), "{body}");
    // Removed with the app.
    server_box_monitor::stacks::store::delete(&state.db, "acme.lights").await.unwrap();
    let (_, body) = call(&srv, true, Method::GET, "/api/v1/agent/mcp", None).await;
    assert_eq!(body["apps"], json!([]), "{body}");
    let left: i64 = sqlx::query_scalar("SELECT COUNT(*) FROM stack_mcp").fetch_one(&state.db).await.unwrap();
    assert_eq!(left, 0);
    let _ = std::fs::remove_dir_all(&apps);
}

/// Many tools are found when needed: the model has `mcp_search` and
/// `mcp_call`, and a call goes through the task's permissions as the tool
/// itself would.
#[ntex::test]
async fn many_mcp_tools_are_searched_and_called_through_the_permissions() {
    let (srv, _) = server().await;
    let calls = std::sync::Arc::new(std::sync::Mutex::new(Vec::new()));
    let mcp = mcp_server_with(calls.clone(), 30);
    let id = fl_pi_llm::host::mcp::server_id(&mcp);
    let servers = json!({ "servers": [{ "name": "Lights", "url": mcp }] });
    let (s, body) = call(&srv, true, Method::PUT, "/api/v1/agent/mcp", Some(servers)).await;
    assert_eq!(s, 200, "{body}");
    assert_eq!(body["status"][0]["tools"].as_array().unwrap().len(), 32);

    let url = model(vec![
        Say::Tool("mcp_search", json!({ "query": "light on" })),
        Say::Tool("mcp_call", json!({ "server": id, "tool": "turn_on", "arguments": { "id": "hall" } })),
        Say::Text("On."),
    ]);
    configure(&srv, &url).await;
    let flow = start(&srv, "turn the hall light on").await;
    let v = until(&srv, &flow, |v| status(v) == "waiting").await;
    // The search answered the tool with its schema; the call waits for the person.
    let found = &results(&v)[0]["details"]["matches"][0];
    assert_eq!((found["tool"].as_str(), found["server"].as_str()), (Some("turn_on"), Some(id.as_str())), "{v}");
    assert!(v["pending"]["command"].as_str().unwrap().contains("Lights · turn_on"), "{v}");
    assert!(calls.lock().unwrap().is_empty());
    let pid = v["pending"]["id"].as_str().unwrap();
    let (s, _) = call(&srv, true, Method::POST, &format!("/api/v1/agent/flows/{flow}/answer"), Some(json!({ "id": pid, "action": "run" }))).await;
    assert_eq!(s, 204);
    until(&srv, &flow, |v| status(v) == "done").await;
    assert_eq!(calls.lock().unwrap().iter().map(|(n, _)| n.as_str()).collect::<Vec<_>>(), ["turn_on"]);
}

#[ntex::test]
async fn an_mcp_servers_tools_run_through_the_tasks_permissions() {
    let (srv, _) = server().await;
    let calls = std::sync::Arc::new(std::sync::Mutex::new(Vec::new()));
    let mcp = mcp_server(calls.clone());
    let id = fl_pi_llm::host::mcp::server_id(&mcp);
    let list: &'static str = Box::leak(fl_pi_llm::host::mcp::tool_name(&id, "list_lights").into_boxed_str());
    let turn: &'static str = Box::leak(fl_pi_llm::host::mcp::tool_name(&id, "turn_on").into_boxed_str());

    // Only an admin sets servers up; a header's value never comes back.
    let servers = json!({ "servers": [{ "name": "Lights", "url": mcp, "headers": { "Authorization": "Bearer tok-1" } }] });
    let (s, body) = call(&srv, true, Method::PUT, "/api/v1/agent/mcp", Some(servers)).await;
    assert_eq!(s, 200, "{body}");
    assert!(!body.to_string().contains("tok-1"), "{body}");
    assert_eq!(body["servers"][0]["headers"], json!(["Authorization"]));
    assert_eq!(body["status"][0]["connected"], true, "{body}");
    assert_eq!(body["status"][0]["tools"].as_array().unwrap().len(), 2);
    let bad = json!({ "servers": [{ "name": "X", "url": "http://10.9.9.9/mcp" }] });
    let (s, _) = call(&srv, true, Method::PUT, "/api/v1/agent/mcp", Some(bad)).await;
    assert_eq!(s, 400);

    // The read runs unasked; the other waits for the person.
    let url = model(vec![Say::Tool(list, json!({})), Say::Tool(turn, json!({ "id": "hall" })), Say::Text("On.")]);
    configure(&srv, &url).await;
    let flow = start(&srv, "turn the hall light on").await;
    let v = until(&srv, &flow, |v| status(v) == "waiting").await;
    assert_eq!(v["pending"]["kind"], "confirm");
    assert!(v["pending"]["command"].as_str().unwrap().contains("Lights · turn_on"), "{v}");
    assert_eq!(calls.lock().unwrap().iter().map(|(n, _)| n.as_str()).collect::<Vec<_>>(), ["list_lights"]);
    let pid = v["pending"]["id"].as_str().unwrap();
    let (s, _) = call(&srv, true, Method::POST, &format!("/api/v1/agent/flows/{flow}/answer"), Some(json!({ "id": pid, "action": "run" }))).await;
    assert_eq!(s, 204);
    let v = until(&srv, &flow, |v| v["flow"]["status"] == "done").await;
    let r = results(&v);
    assert_eq!(r.len(), 2, "{v}");
    assert_eq!(*calls.lock().unwrap(), [("list_lights".to_string(), "Bearer tok-1".to_string()), ("turn_on".to_string(), "Bearer tok-1".to_string())]);
}

#[ntex::test]
async fn skills_are_listed_and_managed() {
    let (srv, _) = server().await;
    let (s, body) = call(&srv, true, Method::GET, "/api/v1/agent/skills", None).await;
    assert_eq!((s, body["skills"].clone()), (200, json!([])));
    let (s, body) = call(&srv, true, Method::POST, "/api/v1/agent/skills", Some(json!({ "source": "https://gitlab.com/a/b" }))).await;
    assert_eq!((s, body["error"].as_str()), (400, Some("invalidSource")), "{body}");
    let (s, _) = call(&srv, true, Method::PUT, "/api/v1/agent/skills/absent", Some(json!({ "enabled": false }))).await;
    assert_eq!(s, 404);
    let (s, _) = call(&srv, true, Method::DELETE, "/api/v1/agent/skills/absent", None).await;
    assert_eq!(s, 404);
}
