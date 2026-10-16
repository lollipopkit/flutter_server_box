//! AI agents installed for real, in a home of their own: each tool installed
//! by its project's installer, found with its version, pointed at a small
//! model (Ollama in a container, which speaks Chat Completions, Responses and
//! Anthropic Messages), asked one question non-interactively, updated, its
//! gateway asked about, and removed with its data.
//!
//!     SBM_E2E_AGENT_TOOLS=1 cargo test -p server_box_monitor --test agent_tools_e2e -- --ignored --nocapture
//!
//! Linux or macOS with Docker and the network. `SBM_E2E_AGENT_TOOLS_PICK=pi,codex`
//! picks the tools. `HOME` is a temporary folder for the whole run, so the
//! account's own tools and settings are never touched.

mod common;

use std::sync::Arc;
use std::time::{Duration, Instant};

use ntex::http::Method;
use ntex::web::test::TestServer;
use serde_json::{Value, json};
use server_box_monitor::api::server::AppState;
use server_box_monitor::core::config::Config;

const OLLAMA: &str = "sbm-e2e-agent-tools-ollama";
const PORT: u16 = 18434;
const MODEL: &str = "qwen3:0.6b";
/// Hermes asks for a 64k-token context; this one has 128k.
const LONG_MODEL: &str = "llama3.2:1b";

async fn call(srv: &TestServer, method: Method, path: &str, body: Option<Value>) -> (u16, Value) {
    common::machine::call(srv, true, method, path, body).await
}

fn sh(cmd: &str) -> std::process::Output {
    std::process::Command::new("sh").arg("-c").arg(cmd).output().unwrap()
}

/// The model server's container goes, however the test ends.
struct Ollama;

impl Drop for Ollama {
    fn drop(&mut self) {
        sh(&format!("docker rm -f {OLLAMA}"));
    }
}

async fn start_ollama() -> Ollama {
    let _ = rustls::crypto::ring::default_provider().install_default();
    sh(&format!("docker rm -f {OLLAMA}"));
    let out = sh(&format!("docker run -d --name {OLLAMA} -p 127.0.0.1:{PORT}:11434 ollama/ollama:0.35.1"));
    assert!(out.status.success(), "{}", String::from_utf8_lossy(&out.stderr));
    let guard = Ollama;
    let client = reqwest::Client::builder().no_proxy().build().unwrap();
    let base = format!("http://127.0.0.1:{PORT}");
    let deadline = Instant::now() + Duration::from_secs(120);
    while client.get(format!("{base}/api/version")).send().await.is_err() {
        assert!(Instant::now() < deadline, "Ollama did not start");
        tokio::time::sleep(Duration::from_secs(1)).await;
    }
    for model in [MODEL, LONG_MODEL] {
        let res = client.post(format!("{base}/api/pull")).json(&json!({ "model": model, "stream": false })).timeout(Duration::from_secs(1800)).send().await.unwrap();
        assert!(res.status().is_success(), "pull {model}: {}", res.status());
    }
    guard
}

/// The job's end state; its lines on failure.
async fn finished(srv: &TestServer) -> String {
    let deadline = Instant::now() + Duration::from_secs(1800);
    loop {
        let (_, job) = call(srv, Method::GET, "/api/v1/agent-tools/job", None).await;
        let state = job["state"].as_str().unwrap_or_default().to_string();
        if state != "running" {
            if state != "succeeded" {
                let lines: Vec<&str> = job["lines"].as_array().into_iter().flatten().filter_map(|l| l["text"].as_str()).collect();
                eprintln!("job {state}:\n{}", lines.join("\n"));
            }
            return state;
        }
        assert!(Instant::now() < deadline, "the job did not end");
        tokio::time::sleep(Duration::from_secs(2)).await;
    }
}

async fn tool(srv: &TestServer, id: &str) -> Value {
    let (status, body) = call(srv, Method::GET, "/api/v1/agent-tools", None).await;
    assert_eq!(status, 200, "{body}");
    body["tools"].as_array().unwrap().iter().find(|t| t["tool"] == id).cloned().unwrap()
}

/// One non-interactive question, as a person would ask it in a terminal.
fn ask(id: &str) -> String {
    let q = "Reply with the single word: ready";
    let run = match id {
        "codex" => format!("codex exec --skip-git-repo-check '{q}'"),
        "claude" => format!("claude -p '{q}'"),
        "pi" => format!("pi -p '{q}'"),
        "opencode" => format!("opencode run '{q}'"),
        "hermes" => format!("hermes chat -q '{q}'"),
        "openclaw" => format!("openclaw agent --local --message '{q}'"),
        _ => unreachable!(),
    };
    format!("{}\ncd \"$(mktemp -d)\" && {run} </dev/null", sbm_parser::agents::PATH_PRELUDE)
}

async fn verify(srv: &TestServer, id: &str, provider: &str, model: &str) {
    eprintln!("== {id}");
    let (status, body) = call(srv, Method::POST, &format!("/api/v1/agent-tools/{id}/install"), None).await;
    assert_eq!(status, 202, "{body}");
    assert_eq!(finished(srv).await, "succeeded", "{id} installed");
    let found = tool(srv, id).await;
    eprintln!("{id}: {} at {}", found["version"], found["path"]);
    assert!(found["version"].is_string(), "{id}: no version: {found}");
    if let Some(pinned) = found["pinned"].as_str() {
        assert_eq!(found["version"], pinned, "{id}: not the pinned release");
    }

    let (status, body) = call(srv, Method::POST, &format!("/api/v1/agent-tools/{id}/configure"), Some(json!({ "provider": provider, "model": model }))).await;
    assert_eq!(status, 204, "{id}: {body}");
    // Async, so the runtime keeps the server's connections while it thinks.
    let out = tokio::process::Command::new("sh").arg("-c").arg(ask(id)).output().await.unwrap();
    let said = format!("{}{}", String::from_utf8_lossy(&out.stdout), String::from_utf8_lossy(&out.stderr));
    eprintln!("{id} says: {}", said.trim().chars().take(400).collect::<String>());
    assert!(out.status.success(), "{id} could not answer through the model");

    if found["gateway"] == true {
        let (status, body) = call(srv, Method::POST, &format!("/api/v1/agent-tools/{id}/gateway"), Some(json!({ "action": "status" }))).await;
        assert_eq!(status, 200, "{body}");
        eprintln!("{id} gateway: {}", body["output"].as_str().unwrap_or_default().lines().next().unwrap_or_default());
    }

    let (status, _) = call(srv, Method::POST, &format!("/api/v1/agent-tools/{id}/update"), None).await;
    assert_eq!(status, 202);
    assert_eq!(finished(srv).await, "succeeded", "{id} updated");

    let (status, _) = call(srv, Method::POST, &format!("/api/v1/agent-tools/{id}/uninstall"), Some(json!({ "purge": true }))).await;
    assert_eq!(status, 202);
    assert_eq!(finished(srv).await, "succeeded", "{id} removed");
    // Another copy on the machine's own `PATH` may remain; this one is gone.
    assert_ne!(tool(srv, id).await["path"], found["path"], "{id} is still there");
}

#[ntex::test]
#[ignore = "installs six tools from the network: SBM_E2E_AGENT_TOOLS=1"]
async fn agent_tools_install_answer_and_go() {
    if std::env::var("SBM_E2E_AGENT_TOOLS").is_err() {
        eprintln!("SBM_E2E_AGENT_TOOLS is not set");
        return;
    }
    let home = tempfile::tempdir().unwrap();
    // SAFETY: set before the server or any task starts.
    unsafe { std::env::set_var("HOME", home.path()) };
    let _ollama = start_ollama().await;
    let (srv, state): (TestServer, Arc<AppState>) = common::machine::server_with(Config::default()).await;
    let base = format!("http://127.0.0.1:{PORT}");
    let provider = |id: &str, api: &str, url: String| json!({ "id": id, "name": id, "api": api, "baseUrl": url, "models": [{ "id": MODEL }, { "id": LONG_MODEL }] });
    let (status, body) = call(
        &srv,
        Method::PUT,
        "/api/v1/agent/settings",
        Some(json!({
            "thinkingLevel": "off", "maxRunning": 1,
            "providers": [
                provider("chat", "openai-completions", format!("{base}/v1")),
                provider("responses", "openai-responses", format!("{base}/v1")),
                provider("anthropic", "anthropic-messages", base.clone()),
            ],
            "credentials": { "chat": "ollama", "responses": "ollama", "anthropic": "ollama" },
        })),
    )
    .await;
    assert_eq!(status, 200, "{body}");
    let (_, providers) = call(&srv, Method::GET, "/api/v1/agent-tools/providers", None).await;
    assert!(providers["providers"].as_array().unwrap().iter().any(|p| p["id"] == "chat"), "{providers}");

    let picked = std::env::var("SBM_E2E_AGENT_TOOLS_PICK").unwrap_or_else(|_| "pi,opencode,codex,claude,hermes,openclaw".into());
    for id in picked.split(',') {
        let provider = match id {
            "codex" => "responses",
            "claude" => "anthropic",
            _ => "chat",
        };
        let model = if matches!(id, "hermes" | "openclaw") { LONG_MODEL } else { MODEL };
        verify(&srv, id, provider, model).await;
    }
    drop(state);
}
