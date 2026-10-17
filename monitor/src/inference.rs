//! The model servers on this machine as Agent mode's providers: each
//! deployed stack with an `[llm]` (the engines Local inference sets up:
//! `monitor/inference/engines`), the MLX server a launchd job of the
//! account serves, and an Ollama of the machine's own. Worked out at start,
//! after a stack's job, when the Local inference package says they changed
//! (`agent.models-changed`) and when Agent mode lists its providers; never
//! stored. What runs them is the Local inference package's
//! (`monitor/apps/inference`).

use std::path::{Path, PathBuf};
use std::sync::Arc;
use std::sync::atomic::Ordering;
use std::time::Duration;

use sbm_parser::inference as model;

use crate::agent_mode::config::{AppProvider, Provider};
use crate::api::server::AppState;

/// `<database dir>/inference`: what the built-in Local inference kept
/// (llmfit, MLX's environment, which a running MLX job may still use).
/// TODO: remove once no agent from before the package has it.
pub fn legacy_dir_beside(db: &Path) -> PathBuf {
    db.parent().unwrap_or_else(|| Path::new(".")).join("inference")
}

/// The deployed Ollama engine's stack.
const OLLAMA_STACK: &str = "ollama.ollama";
/// Where Ollama's own install listens.
const NATIVE_OLLAMA: &str = "http://127.0.0.1:11434";

/// The address of a deployed engine's API on this machine, when it is set up.
pub fn stack_api(row: &crate::stacks::store::StackRow, llm: &crate::stacks::manifest::Llm) -> Option<String> {
    let port = row.settings.get(&llm.port)?.as_u64()?;
    Some(format!("http://127.0.0.1:{port}{}", llm.path))
}

/// mlx-lm's server, when this is a Mac and its job is set up.
async fn mlx(state: &AppState) -> Option<model::MlxService> {
    if !cfg!(target_os = "macos") {
        return None;
    }
    let limits = crate::api::machine::at_least(&state.remote_access.exec, 1 << 20);
    let out = crate::api::machine::as_self(&model::mlx_status_command(), &limits).await.ok()?;
    Some(model::parse_mlx_status(&out.stdout))
}

/// Whether an Ollama of the machine's own answers on its default port.
async fn native_ollama() -> bool {
    let _ = rustls::crypto::ring::default_provider().install_default();
    let Ok(client) = reqwest::Client::builder().no_proxy().redirect(reqwest::redirect::Policy::none()).timeout(Duration::from_secs(3)).build() else {
        return false;
    };
    client.get(format!("{NATIVE_OLLAMA}/api/version")).send().await.is_ok_and(|r| r.status().is_success())
}

/// Every model server on this machine, as Agent mode's providers: each
/// deployed app with an `[llm]`, the MLX server, and an Ollama of the
/// machine's own.
pub async fn providers(state: &AppState) -> Vec<AppProvider> {
    let mut out = Vec::new();
    let rows = crate::stacks::store::all(&state.db).await.unwrap_or_default();
    let mut deployed_ollama = None;
    for row in rows.iter().filter(|r| r.state == "installed" && !r.stopped) {
        let Some(package) = state.stacks.package(&row.id) else { continue };
        let m = &package.manifest;
        let Some(llm) = &m.llm else { continue };
        if row.id == OLLAMA_STACK {
            deployed_ollama = row.settings.get(&llm.port).and_then(|p| p.as_u64()).map(|p| format!("http://127.0.0.1:{p}"));
        }
        // A model server that answers no tool call cannot run a task.
        if llm.tools.is_some() && llm.tool_parser(&row.settings).is_none() {
            continue;
        }
        let Some(base_url) = stack_api(row, llm) else { continue };
        let key = match &llm.key {
            Some(env) => {
                let text = tokio::fs::read_to_string(state.stacks.dir(&row.id).join(crate::stacks::ENV_FILE)).await.unwrap_or_default();
                match crate::stacks::read_env(&text, &[env.as_str()]).remove(env) {
                    Some(k) => k,
                    None => continue,
                }
            }
            None => KEYLESS.into(),
        };
        let name = m.title.get("en").cloned().unwrap_or_else(|| m.project.clone());
        out.push(app_provider(&format!("app.{}", row.id), &format!("{name} (this machine)"), base_url, key));
    }
    if let Some(svc) = mlx(state).await
        && let Some(port) = svc.port
        && svc.running
    {
        out.push(app_provider("app.mlx", "MLX (this machine)", format!("http://127.0.0.1:{port}/v1"), KEYLESS.into()));
    }
    if deployed_ollama.as_deref() != Some(NATIVE_OLLAMA) && native_ollama().await {
        out.push(app_provider("app.ollama", "Ollama (this machine)", format!("{NATIVE_OLLAMA}/v1"), KEYLESS.into()));
    }
    out
}

/// What a server that asks for no key is sent: pi counts a provider with no
/// credential as unusable.
const KEYLESS: &str = "local";

fn app_provider(id: &str, name: &str, base_url: String, key: String) -> AppProvider {
    AppProvider {
        provider: Provider {
            id: id.into(),
            name: name.into(),
            api: "openai-completions".into(),
            base_url,
            allow_insecure: true,
            models: Vec::new(),
        },
        key,
    }
}

/// Works out [providers] again and hands them to Agent mode; in the
/// background, so a slow server holds up nothing. One at a time, so an older
/// answer never lands after a newer one; asks made meanwhile are one more.
pub fn refresh_providers(state: &Arc<AppState>) {
    state.agent.app_refresh_asked.store(true, Ordering::SeqCst);
    let state = state.clone();
    tokio::spawn(async move {
        let _one = state.agent.app_refresh.lock().await;
        if !state.agent.app_refresh_asked.swap(false, Ordering::SeqCst) {
            return;
        }
        let apps = providers(&state).await;
        if let Err(e) = state.agent.set_app_providers(apps).await {
            tracing::warn!("inference: offering the model servers to Agent mode: {e:#}");
        }
    });
}
