//! MLX on Apple Silicon: mlx-lm in a virtual environment of the agent's
//! (`<inference>/mlx/venv`), its server a launchd job of the agent's account
//! (`sbm_parser::inference::MLX_LABEL`) serving one model on loopback.
//! Nothing is stored: the job's plist says what it serves.

use std::sync::Arc;

use sbm_parser::inference::{self as model, MlxService};

use crate::api::server::AppState;
use crate::stacks::job::{Job, JobKind, JobState};

/// mlx-lm's server, when this is a Mac.
pub async fn service(state: &AppState) -> Option<MlxService> {
    if !cfg!(target_os = "macos") {
        return None;
    }
    let limits = crate::api::machine::at_least(&state.remote_access.exec, 1 << 20);
    let out = crate::api::machine::as_self(&model::mlx_status_command(), &limits).await.ok()?;
    Some(model::parse_mlx_status(&out.stdout))
}

pub fn installed(state: &AppState) -> bool {
    state.inference.mlx_dir().join("venv/bin/mlx_lm.server").is_file()
}

/// Installs mlx-lm, as a job.
pub fn install(state: &Arc<AppState>) -> Result<Arc<Job>, &'static str> {
    if !cfg!(target_os = "macos") {
        return Err("needsAppleSilicon");
    }
    let job = state.inference.begin(Job::new(JobKind::Install))?;
    let script = model::mlx_install_script(&state.inference.mlx_dir().to_string_lossy());
    let job2 = job.clone();
    tokio::spawn(async move {
        match job2.run_steps(&[script]).await {
            Ok(()) => job2.finish(JobState::Succeeded, None),
            Err(e) => {
                job2.push(format!("✕ {e}"));
                job2.finish(if e == "cancelled" { JobState::Cancelled } else { JobState::Failed }, Some(e));
            }
        }
    });
    Ok(job)
}

/// The models' folder mlx-lm downloads into: the Hugging Face cache vLLM and
/// SGLang share (`{shared}/models/huggingface`).
fn hf_home(state: &AppState) -> String {
    state.stacks.shared().join("models/huggingface").to_string_lossy().into_owned()
}

/// Serves [model] on [port], replacing what the job served.
pub async fn start(state: &Arc<AppState>, model_ref: &str, port: u16) -> Result<(), String> {
    if !model::valid_model(model_ref) || model_ref.contains(':') {
        return Err("invalidModel".into());
    }
    if !installed(state) {
        return Err("notInstalled".into());
    }
    let dir = state.inference.mlx_dir().to_string_lossy().into_owned();
    let home = hf_home(state);
    tokio::fs::create_dir_all(&home).await.map_err(|e| e.to_string())?;
    let plist = model::mlx_plist(&dir, model_ref, port, &home);
    let limits = crate::api::machine::at_least(&state.remote_access.exec, 1 << 20);
    let out = crate::api::machine::as_self(&model::mlx_start_script(&plist), &limits).await.map_err(|e| e.to_string())?;
    if out.exit_code != Some(0) {
        return Err(format!("launchctl: {}", out.stderr.trim()));
    }
    super::refresh_providers(state);
    Ok(())
}

pub async fn stop(state: &Arc<AppState>) -> Result<(), String> {
    let limits = crate::api::machine::at_least(&state.remote_access.exec, 1 << 20);
    crate::api::machine::as_self(&model::mlx_stop_script(), &limits).await.map_err(|e| e.to_string())?;
    super::refresh_providers(state);
    Ok(())
}
