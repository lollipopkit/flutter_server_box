//! Local inference: which engine runs a language model on this machine, the
//! models that fit it, and the engines themselves. What decides and every
//! command are `sbm_parser::inference`'s; this module runs them.
//!
//! - The machine is read by [`sbm_parser::inference::probe_command`] (GPUs,
//!   memory, Docker's GPU support), kept for half a minute.
//! - Models are llmfit's (`llmfit`): its release for this platform, fetched
//!   once into `<database dir>/inference/` and checked against the SHA-256
//!   compiled in, run with the GPU memory the probe read.
//! - Ollama, llama.cpp, vLLM and SGLang are stacks (`stacks`, the packages
//!   `stacks::builtin::parts`): deployed, set up and removed like any app,
//!   shown in Local inference's window. MLX runs natively on Apple Silicon
//!   ([`mlx`]). Ollama's models are pulled through its API ([`ollama`]).
//! - Every model server found joins Agent mode as a provider ([`providers`]).

pub mod llmfit;
pub mod mlx;
pub mod ollama;

use std::collections::BTreeMap;
use std::path::{Path, PathBuf};
use std::sync::{Arc, Mutex};
use std::time::{Duration, Instant};

use sbm_parser::inference::{self as model, Engine, Hardware};

use crate::agent_mode::config::{AppProvider, Provider};
use crate::api::server::AppState;
use crate::stacks::job::Job;
use crate::utils::lock::LockExt;

/// How long a reading of the machine is kept.
const PROBE_TTL: Duration = Duration::from_secs(30);

pub struct Inference {
    /// `<database dir>/inference`: llmfit and MLX's environment. A protected
    /// tree: what is run from it cannot be replaced through `/fs`.
    dir: PathBuf,
    probe: tokio::sync::Mutex<Option<(Instant, Hardware)>>,
    pub llmfit: llmfit::Llmfit,
    /// MLX's installation, the one job of this module's.
    job: Mutex<Option<Arc<Job>>>,
    pub ollama: Arc<ollama::Ollama>,
}

impl Inference {
    pub fn dir_beside(db: &Path) -> PathBuf {
        db.parent().unwrap_or_else(|| Path::new(".")).join("inference")
    }

    pub fn new(db_file: Option<&Path>) -> Self {
        let dir = match db_file {
            Some(f) => std::path::absolute(Self::dir_beside(f)).unwrap_or_else(|_| Self::dir_beside(f)),
            None => std::env::temp_dir().join(format!("sbm-inference-{}", std::process::id())),
        };
        Self {
            llmfit: llmfit::Llmfit::new(dir.join(format!("llmfit-{}", model::LLMFIT_VERSION))),
            dir,
            probe: tokio::sync::Mutex::new(None),
            job: Mutex::new(None),
            ollama: Arc::default(),
        }
    }

    pub fn mlx_dir(&self) -> PathBuf {
        self.dir.join("mlx")
    }

    /// The machine as the probe reads it, at most [PROBE_TTL] old.
    pub async fn hardware(&self, state: &AppState) -> Hardware {
        let mut probe = self.probe.lock().await;
        if let Some((at, hw)) = probe.as_ref()
            && at.elapsed() < PROBE_TTL
        {
            return hw.clone();
        }
        let limits = crate::api::machine::at_least(&state.remote_access.exec, 1 << 20);
        let hw = match crate::api::machine::as_self(model::probe_command(), &limits).await {
            Ok(out) => model::parse_probe(&out.stdout),
            Err(e) => {
                tracing::warn!("inference: reading the machine: {e}");
                Hardware::default()
            }
        };
        *probe = Some((Instant::now(), hw.clone()));
        hw
    }

    pub fn job(&self) -> Option<Arc<Job>> {
        self.job.locked().clone()
    }

    /// Starts [job] unless one runs.
    fn begin(&self, job: Job) -> Result<Arc<Job>, &'static str> {
        let mut slot = self.job.locked();
        if slot.as_ref().is_some_and(|j| j.running()) {
            return Err("busy");
        }
        let job = Arc::new(job);
        *slot = Some(job.clone());
        Ok(job)
    }
}

/// The address of a deployed engine's API on this machine, when it is set up.
pub fn stack_api(row: &crate::stacks::store::StackRow, llm: &crate::stacks::manifest::Llm) -> Option<String> {
    let port = row.settings.get(&llm.port)?.as_u64()?;
    Some(format!("http://127.0.0.1:{port}{}", llm.path))
}

/// Every model server on this machine, as Agent mode's providers: each
/// deployed app with an `[llm]`, the MLX server, and an Ollama of the
/// machine's own.
pub async fn providers(state: &AppState) -> Vec<AppProvider> {
    let mut out = Vec::new();
    let rows = crate::stacks::store::all(&state.db).await.unwrap_or_default();
    for row in rows.iter().filter(|r| r.state == "installed" && !r.stopped) {
        let Some(package) = state.stacks.package(&row.id) else { continue };
        let m = &package.manifest;
        let Some(llm) = &m.llm else { continue };
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
    if let Some(svc) = mlx::service(state).await
        && let Some(port) = svc.port
        && svc.running
    {
        out.push(app_provider("app.mlx", "MLX (this machine)", format!("http://127.0.0.1:{port}/v1"), KEYLESS.into()));
    }
    if let Some(url) = ollama::native(state, &rows).await {
        out.push(app_provider("app.ollama", "Ollama (this machine)", format!("{url}/v1"), KEYLESS.into()));
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
/// background, so a slow server holds up nothing.
pub fn refresh_providers(state: &Arc<AppState>) {
    let state = state.clone();
    tokio::spawn(async move {
        let apps = providers(&state).await;
        if let Err(e) = state.agent.set_app_providers(apps).await {
            tracing::warn!("inference: offering the model servers to Agent mode: {e:#}");
        }
    });
}

/// Each engine as it fits this machine, with the catalog app that runs it.
pub fn engines(hw: &Hardware) -> Vec<serde_json::Value> {
    model::engines(hw)
        .into_iter()
        .map(|f| {
            serde_json::json!({
                "engine": f.engine,
                "backend": f.backend,
                "blocked": f.blocked,
                "cpuBecause": f.cpu_because,
                "app": f.engine.app(),
            })
        })
        .collect()
}

/// The engines that run here, best first.
pub fn runnable(hw: &Hardware) -> Vec<Engine> {
    model::engines(hw).into_iter().filter(|f| f.blocked.is_none()).map(|f| f.engine).collect()
}

/// Candidates per runnable engine for [query], best engine first.
pub async fn recommend(
    state: &AppState,
    query: &model::RecommendQuery,
    all_publishers: bool,
    limit: usize,
) -> Result<(Hardware, BTreeMap<String, Vec<model::Candidate>>), String> {
    let inference = &state.inference;
    let hw = inference.hardware(state).await;
    let models = inference.llmfit.recommend(&hw, query).await?;
    let mut out = BTreeMap::new();
    for f in model::engines(&hw).into_iter().filter(|f| f.blocked.is_none()) {
        let engine = f.engine;
        let found = model::candidates(engine, f.backend, &hw, &models, all_publishers, limit);
        out.insert(serde_json::to_value(engine).ok().and_then(|v| v.as_str().map(String::from)).unwrap_or_default(), found);
    }
    Ok((hw, out))
}
