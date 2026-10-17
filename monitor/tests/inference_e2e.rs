//! Local inference on this machine, for real: its hardware read, llmfit's
//! models for it, each engine deployed or started with a small model, asked
//! through its OpenAI-compatible API, and run as Agent mode's model for a
//! task. Opt-in: it downloads llmfit, engines and models.
//!
//!     SBM_E2E_INFERENCE=1 cargo test -p server_box_monitor --test inference_e2e -- --ignored --nocapture
//!
//! - MLX (macOS on Apple Silicon): `SBM_E2E_MLX=1` too.
//! - The engines in containers (Linux with Docker): `SBM_E2E_DOCKER=1`, and
//!   `SBM_E2E_ENGINES=ollama.ollama,ggml.llama_cpp` (the default; `vllm.vllm`
//!   and `sglang.sglang` need an NVIDIA GPU Docker can hand them;
//!   `SBM_E2E_GPU_MEMORY=0.1` keeps them to that share of a GPU others use;
//!   `SBM_E2E_MODELS_DIR` is a Hugging Face cache already holding the model,
//!   for a machine that cannot reach Hugging Face).
//!
//! An engine is deployed under its own id, so this refuses to run where one
//! of the same id is already deployed (`docker ps` names its project).

mod common;

use std::sync::Arc;
use std::time::{Duration, Instant};

use ntex::http::Method;
use ntex::web::test::TestServer;
use serde_json::{Value, json};
use server_box_monitor::api::server::AppState;
use server_box_monitor::core::config::Config;

async fn call(srv: &TestServer, method: Method, path: &str, body: Option<Value>) -> (u16, Value) {
    common::machine::call(srv, true, method, path, body).await
}

fn opted_in(var: &str) -> bool {
    let on = std::env::var(var).is_ok();
    if !on {
        eprintln!("{var} is not set");
    }
    on
}

/// A small model for each engine.
fn small_model(id: &str) -> &'static str {
    match id {
        "ggml.llama_cpp" => "unsloth/Qwen3-0.6B-GGUF:Q4_K_M",
        "ollama.ollama" => "qwen3:0.6b",
        _ => "Qwen/Qwen3-0.6B",
    }
}

/// The app provider for [id] once Agent mode has it.
async fn provider(state: &Arc<AppState>, id: &str) -> server_box_monitor::agent_mode::config::AppProvider {
    let deadline = Instant::now() + Duration::from_secs(60);
    loop {
        if let Some(p) = state.agent.app_providers().into_iter().find(|p| p.provider.id == id) {
            return p;
        }
        assert!(Instant::now() < deadline, "{id} never joined Agent mode: {:?}", state.agent.app_providers());
        server_box_monitor::inference::refresh_providers(state);
        tokio::time::sleep(Duration::from_secs(2)).await;
    }
}

async fn server() -> (TestServer, Arc<AppState>) {
    common::machine::server_with(Config::default()).await
}

/// Waits until [base]`/models` answers with the key, up to [limit].
async fn serving(base: &str, key: &str, limit: Duration) -> Value {
    let client = reqwest::Client::builder().no_proxy().build().unwrap();
    let deadline = Instant::now() + limit;
    loop {
        if let Ok(res) = client.get(format!("{base}/models")).bearer_auth(key).timeout(Duration::from_secs(10)).send().await
            && res.status().is_success()
            && let Ok(v) = res.json::<Value>().await
            && v["data"].as_array().is_some_and(|d| !d.is_empty())
        {
            return v;
        }
        assert!(Instant::now() < deadline, "{base} never served a model");
        tokio::time::sleep(Duration::from_secs(5)).await;
    }
}

/// One chat turn through [base]'s OpenAI-compatible API.
async fn chat(base: &str, key: &str, model: &str) -> String {
    let client = reqwest::Client::builder().no_proxy().build().unwrap();
    let res = client
        .post(format!("{base}/chat/completions"))
        .bearer_auth(key)
        .json(&json!({ "model": model, "messages": [{ "role": "user", "content": "Say hello in one word. /no_think" }], "max_tokens": 256 }))
        .timeout(Duration::from_secs(300))
        .send()
        .await
        .unwrap();
    let status = res.status();
    let body: Value = res.json().await.unwrap_or_default();
    assert!(status.is_success(), "{base}: HTTP {status} {body}");
    let text = body["choices"][0]["message"]["content"].as_str().unwrap_or_default().to_string();
    // A thinking model's words before its answer: vLLM's and SGLang's
    // `reasoning_content`, Ollama's `reasoning`.
    let message = &body["choices"][0]["message"];
    let reasoning = message["reasoning_content"].as_str().or(message["reasoning"].as_str()).unwrap_or_default();
    assert!(!(text.trim().is_empty() && reasoning.trim().is_empty()), "{base}: an empty answer: {body}");
    text
}

/// A task run with [provider]'s [model] as Agent mode's model, to its end.
async fn agent_task(srv: &TestServer, provider: &str, model: &str) {
    let (status, body) = call(
        srv,
        Method::PUT,
        "/api/v1/agent/settings",
        Some(json!({ "model": { "provider": provider, "id": model }, "thinkingLevel": "off", "maxRunning": 1, "providers": [], "credentials": {} })),
    )
    .await;
    assert_eq!(status, 200, "{body}");
    // Its models are listed in the background.
    let deadline = Instant::now() + Duration::from_secs(60);
    loop {
        let (_, choices) = call(srv, Method::GET, "/api/v1/agent/choices", None).await;
        if choices["models"].as_array().is_some_and(|m| m.iter().any(|m| m["provider"] == provider && m["id"] == model)) {
            break;
        }
        assert!(Instant::now() < deadline, "{provider}/{model} is not a choice: {choices}");
        tokio::time::sleep(Duration::from_secs(2)).await;
    }
    let (status, body) = call(srv, Method::POST, "/api/v1/agent/flows", Some(json!({ "prompt": "Reply with the single word: ready. Do not run any command." }))).await;
    assert_eq!(status, 201, "{body}");
    let id = body["id"].as_str().unwrap().to_string();
    let deadline = Instant::now() + Duration::from_secs(600);
    let flow = loop {
        let (_, v) = call(srv, Method::GET, &format!("/api/v1/agent/flows/{id}"), None).await;
        let s = v["flow"]["status"].as_str().unwrap_or_default().to_string();
        if !matches!(s.as_str(), "running" | "queued" | "") {
            break v;
        }
        assert!(Instant::now() < deadline, "the task did not end: {v}");
        tokio::time::sleep(Duration::from_secs(2)).await;
    };
    assert_eq!(flow["flow"]["status"], "done", "{flow}");
    let said: Vec<&Value> = flow["entries"].as_array().unwrap().iter().filter(|e| e["message"]["role"] == "assistant").collect();
    assert!(!said.is_empty(), "the model said nothing: {flow}");
    eprintln!("Agent mode with {provider}/{model}: {}", said.last().unwrap()["message"]["content"]);
    let _ = call(srv, Method::DELETE, &format!("/api/v1/agent/flows/{id}"), None).await;
}

#[ntex::test]
#[ignore = "downloads llmfit: SBM_E2E_INFERENCE=1"]
async fn this_machine_is_read_and_models_fit_it() {
    if !opted_in("SBM_E2E_INFERENCE") {
        return;
    }
    let (srv, _state) = server().await;
    let (status, view) = call(&srv, Method::GET, "/api/v1/inference", None).await;
    assert_eq!(status, 200, "{view}");
    eprintln!("hardware: {}", view["hardware"]);
    assert!(!view["hardware"]["os"].as_str().unwrap_or_default().is_empty(), "{view}");
    assert_eq!(view["engines"].as_array().unwrap().len(), 5);
    let (status, rec) = call(&srv, Method::POST, "/api/v1/inference/recommend", Some(json!({ "limit": 5 }))).await;
    assert_eq!(status, 200, "{rec}");
    let best = rec["engines"][0].as_str().expect("an engine runs here").to_string();
    let found = rec["candidates"][&best].as_array().unwrap();
    assert!(!found.is_empty(), "nothing fits {best}: {rec}");
    for c in found.iter().take(3) {
        eprintln!("{best}: {} {} ({} GiB, {:?} tok/s)", c["name"], c["model"], c["memoryGib"], c["tokensPerSecond"]);
    }
    // A coding use case narrows llmfit's list; an unknown one is refused.
    let (status, _) = call(&srv, Method::POST, "/api/v1/inference/recommend", Some(json!({ "useCase": "coding" }))).await;
    assert_eq!(status, 200);
    let (status, _) = call(&srv, Method::POST, "/api/v1/inference/recommend", Some(json!({ "useCase": "x;y" }))).await;
    assert_eq!(status, 400);
}

#[ntex::test]
#[ignore = "installs mlx-lm and downloads a model: SBM_E2E_INFERENCE=1 SBM_E2E_MLX=1"]
async fn mlx_serves_a_model_to_agent_mode() {
    if !opted_in("SBM_E2E_INFERENCE") || !opted_in("SBM_E2E_MLX") {
        return;
    }
    let (srv, _state) = server().await;
    let (status, job) = call(&srv, Method::POST, "/api/v1/inference/mlx/install", None).await;
    assert_eq!(status, 202, "{job}");
    let deadline = Instant::now() + Duration::from_secs(900);
    loop {
        let (_, j) = call(&srv, Method::GET, "/api/v1/inference/job", None).await;
        match j["state"].as_str() {
            Some("running") => {}
            Some("succeeded") => break,
            _ => panic!("installing mlx-lm: {j}"),
        }
        assert!(Instant::now() < deadline, "installing mlx-lm did not end");
        tokio::time::sleep(Duration::from_secs(3)).await;
    }
    let model = "mlx-community/Qwen3-0.6B-4bit";
    let (status, body) = call(&srv, Method::PUT, "/api/v1/inference/mlx", Some(json!({ "model": model, "port": 18585 }))).await;
    assert_eq!(status, 204, "{body}");
    /// The job goes, should the test end early.
    struct Stop;
    impl Drop for Stop {
        fn drop(&mut self) {
            let _ = std::process::Command::new("sh").arg("-c").arg(sbm_parser::inference::mlx_stop_script()).output();
        }
    }
    let _stop = Stop;
    let base = "http://127.0.0.1:18585/v1";
    serving(base, "local", Duration::from_secs(900)).await;
    eprintln!("MLX: {}", chat(base, "local", model).await);
    let (_, view) = call(&srv, Method::GET, "/api/v1/inference", None).await;
    assert_eq!(view["mlx"]["service"]["running"], true, "{view}");
    assert_eq!(view["mlx"]["service"]["model"], model, "{view}");
    agent_task(&srv, "app.mlx", model).await;
    let (status, _) = call(&srv, Method::DELETE, "/api/v1/inference/mlx", None).await;
    assert_eq!(status, 204);
    let (_, view) = call(&srv, Method::GET, "/api/v1/inference", None).await;
    assert_eq!(view["mlx"]["service"]["running"], false, "{view}");
}

/// Waits for engine [id]'s job to end; its state.
async fn finished(srv: &TestServer, id: &str) -> String {
    let deadline = Instant::now() + Duration::from_secs(3600);
    loop {
        let (_, job) = call(srv, Method::GET, &format!("/api/v1/stacks/{id}/job"), None).await;
        let state = job["state"].as_str().unwrap_or_default().to_string();
        if state != "running" {
            if state != "succeeded" {
                let lines: Vec<&str> = job["lines"].as_array().into_iter().flatten().filter_map(|l| l["text"].as_str()).collect();
                eprintln!("job {state}:\n{}", lines.join("\n"));
            }
            return state;
        }
        assert!(Instant::now() < deadline, "the job did not end");
        tokio::time::sleep(Duration::from_secs(3)).await;
    }
}

/// The engine's containers gone, should the test end early.
struct Cleanup(String);

impl Drop for Cleanup {
    fn drop(&mut self) {
        let (publisher, name) = self.0.split_once('.').unwrap();
        let project = format!("sbm-{publisher}-{name}");
        let _ = std::process::Command::new("sh")
            .arg("-c")
            .arg(format!("docker ps -aq --filter label=com.docker.compose.project={project} | xargs -r docker rm -f; docker network rm {project}_default"))
            .output();
    }
}

async fn engine(srv: &TestServer, state: &Arc<AppState>, id: &str, accel: Option<&str>) {
    eprintln!("== {id}");
    let (publisher, name) = id.split_once('.').unwrap();
    let project = format!("sbm-{publisher}-{name}");
    let ps = std::process::Command::new("docker").args(["ps", "-aq", "--filter", &format!("label=com.docker.compose.project={project}")]).output().unwrap();
    assert!(ps.stdout.is_empty(), "{project} is deployed on this machine already: not touched");
    // A GPU engine runs only where Docker hands it the NVIDIA GPU: the agent
    // says so before it is deployed.
    if let Some(engine) = match id {
        "vllm.vllm" => Some("vllm"),
        "sglang.sglang" => Some("sglang"),
        _ => None,
    } {
        let (_, view) = call(srv, Method::GET, "/api/v1/inference", None).await;
        let fit = view["engines"].as_array().unwrap().iter().find(|e| e["engine"] == engine).cloned().unwrap_or_default();
        // A card older than the engine's kernels is said so, and not deployed
        // (SGLang on a Turing card).
        if fit["blocked"] == "gpuTooOld" {
            eprintln!("{id}: refused here, the GPU is older than its kernels: {fit}");
            return;
        }
        assert_eq!((fit["blocked"].clone(), fit["backend"].clone()), (Value::Null, json!("cuda")), "{engine} does not run here: {fit}");
    }
    let model = small_model(id);
    let mut given = serde_json::Map::new();
    if id != "ollama.ollama" {
        given.insert("model".into(), json!(model));
    }
    if let Some(a) = accel {
        given.insert("accel".into(), json!(a));
    }
    // A machine that cannot reach Hugging Face: the model's cache put there.
    if let Ok(dir) = std::env::var("SBM_E2E_MODELS_DIR")
        && id != "ollama.ollama"
    {
        given.insert("models".into(), json!(dir));
        if id != "ggml.llama_cpp" {
            given.insert("offline".into(), json!(true));
        }
    }
    // On a GPU others use too: the share of its memory vLLM or SGLang take.
    if let Ok(share) = std::env::var("SBM_E2E_GPU_MEMORY")
        && id != "ollama.ollama"
        && id != "ggml.llama_cpp"
    {
        given.insert("gpu_memory".into(), json!(share));
    }
    let (status, check) = call(srv, Method::POST, &format!("/api/v1/stacks/{id}/check"), Some(json!({ "settings": given }))).await;
    assert_eq!(status, 200, "{check}");
    let (status, body) = call(
        srv,
        Method::POST,
        &format!("/api/v1/stacks/{id}"),
        Some(json!({ "current_password": common::PASSWORD, "settings": check["settings"], "acknowledged": true, "accept_license": true })),
    )
    .await;
    assert_eq!(status, 202, "{body}");
    let _cleanup = Cleanup(id.to_string());
    assert_eq!(finished(srv, id).await, "succeeded", "{id} deployed");

    if id == "ollama.ollama" {
        let (status, body) = call(srv, Method::POST, &format!("/api/v1/inference/ollama/{id}/pull"), Some(json!({ "model": model }))).await;
        assert_eq!(status, 202, "{body}");
        let deadline = Instant::now() + Duration::from_secs(1800);
        loop {
            let (_, view) = call(srv, Method::GET, "/api/v1/inference", None).await;
            let pull = view["pulls"].as_array().unwrap().iter().find(|p| p["model"] == model).cloned().unwrap_or_default();
            if pull["done"] == true {
                assert!(pull["error"].is_null(), "{pull}");
                break;
            }
            assert!(Instant::now() < deadline, "the pull did not end: {pull}");
            tokio::time::sleep(Duration::from_secs(3)).await;
        }
        let (status, models) = call(srv, Method::GET, &format!("/api/v1/inference/ollama/{id}/models"), None).await;
        assert_eq!(status, 200, "{models}");
        assert!(models["models"].as_array().unwrap().iter().any(|m| m["name"] == model), "{models}");
    }

    let p = provider(state, &format!("app.{id}")).await;
    serving(&p.provider.base_url, &p.key, Duration::from_secs(3600)).await;
    eprintln!("{id}: {}", chat(&p.provider.base_url, &p.key, model).await);
    if id != "ollama.ollama" {
        // The key is asked for.
        let res = reqwest::Client::builder().no_proxy().build().unwrap().get(format!("{}/models", p.provider.base_url)).send().await.unwrap();
        assert_eq!(res.status().as_u16(), 401, "{id} answered without its key");
    }
    agent_task(srv, &p.provider.id, model).await;

    if id == "ollama.ollama" {
        let (status, _) = call(srv, Method::POST, &format!("/api/v1/inference/ollama/{id}/delete"), Some(json!({ "model": model }))).await;
        assert_eq!(status, 204);
    }
    let (status, body) = call(srv, Method::DELETE, &format!("/api/v1/stacks/{id}"), Some(json!({ "current_password": common::PASSWORD, "purge": true }))).await;
    assert_eq!(status, 202, "{body}");
    assert_eq!(finished(srv, id).await, "succeeded");
    // Gone from Agent mode with it.
    let deadline = Instant::now() + Duration::from_secs(30);
    while state.agent.app_providers().iter().any(|a| a.provider.id == p.provider.id) {
        assert!(Instant::now() < deadline, "{id} stayed in Agent mode");
        tokio::time::sleep(Duration::from_secs(1)).await;
    }
}

#[ntex::test]
#[ignore = "deploys engines on a real Docker: SBM_E2E_INFERENCE=1 SBM_E2E_DOCKER=1"]
async fn engines_serve_agent_mode() {
    if !opted_in("SBM_E2E_INFERENCE") || !opted_in("SBM_E2E_DOCKER") {
        return;
    }
    let picked = std::env::var("SBM_E2E_ENGINES").unwrap_or_else(|_| "ollama.ollama,ggml.llama_cpp".into());
    let accel = std::env::var("SBM_E2E_ACCEL").ok();
    let (srv, state) = server().await;
    for id in picked.split(',') {
        engine(&srv, &state, id, accel.as_deref()).await;
    }
}
