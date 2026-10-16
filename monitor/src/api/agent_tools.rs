//! `/api/v1/agent-tools*`: AI agents on this machine (Codex, Claude Code,
//! pi, opencode, Hermes, OpenClaw) for the agent's own account: found,
//! installed, updated and removed by `sbm_parser::agents`' scripts as a job,
//! pointed at one of Agent mode's providers (the operator's, or a model
//! server of this machine's), and their gateways run.
//!
//! The account's home is where they live: nothing here needs root. Every
//! route takes `machine::gate`; a configuration write puts the provider's
//! key in the tool's own file (0600), never on a command line or in the
//! audit.

use std::path::{Path, PathBuf};
use std::sync::{Arc, Mutex};

use ntex::web::{self, HttpRequest, HttpResponse};
use serde::Deserialize;
use serde_json::{Value, json};

use super::machine;
use super::server::AppState;
use super::ws::audit::{Action, Event, Kind, Outcome};
use crate::stacks::job::{Job, JobKind, JobState};
use crate::utils::lock::LockExt;
use sbm_parser::agents::{self as model, Api, GatewayAction, Tool};

/// The one job of this page's at a time: an install, update or removal.
#[derive(Default)]
pub struct AgentToolsJobs(Mutex<Option<Arc<Job>>>);

impl AgentToolsJobs {
    fn current(&self) -> Option<Arc<Job>> {
        self.0.locked().clone()
    }

    fn begin(&self, kind: JobKind) -> Option<Arc<Job>> {
        let mut slot = self.0.locked();
        if slot.as_ref().is_some_and(|j| j.running()) {
            return None;
        }
        let job = Arc::new(Job::new(kind));
        *slot = Some(job.clone());
        Some(job)
    }
}

fn refused(status: u16, error: &str) -> HttpResponse {
    let status = ntex::http::StatusCode::from_u16(status).unwrap_or(ntex::http::StatusCode::BAD_REQUEST);
    HttpResponse::build(status).json(&json!({ "error": error }))
}

async fn audit(state: &AppState, gated: &machine::Gated, outcome: Outcome, detail: String) {
    Event::new(Kind::Machine, Action::Write, outcome).remote_ip(gated.remote_ip.clone()).detail(detail).record(&state.db).await;
}

fn tool_of(id: &str) -> Result<Tool, HttpResponse> {
    Tool::from_id(id).ok_or_else(|| refused(404, "unknownTool"))
}

fn home() -> Option<PathBuf> {
    std::env::var_os("HOME").filter(|h| !h.is_empty()).map(PathBuf::from)
}

/// Each tool, found or not, and the job running.
pub async fn list(req: HttpRequest, state: web::types::State<Arc<AppState>>) -> Result<HttpResponse, web::Error> {
    if let Err(r) = machine::gate(&req, &state, "agent tools read").await {
        return Ok(r);
    }
    let limits = machine::at_least(&state.remote_access.exec, 1 << 20);
    let found = match machine::as_self(&model::probe_command(), &limits).await {
        Ok(out) => model::parse_probe(&out.stdout),
        Err(e) => return Ok(super::respond::internal(&e)),
    };
    let tools: Vec<Value> = found
        .into_iter()
        .map(|f| {
            json!({
                "tool": f.tool,
                "path": f.path,
                "version": f.version,
                "pinned": f.tool.pinned(),
                "homepage": f.tool.homepage(),
                "gateway": f.tool.has_gateway(),
                "apis": f.tool.apis(),
            })
        })
        .collect();
    Ok(HttpResponse::Ok().json(&json!({ "tools": tools, "job": state.agent_tools.current().map(|j| j.view(u64::MAX)) })))
}

#[derive(Deserialize, Default)]
#[serde(deny_unknown_fields)]
pub struct ChangeBody {
    /// Removal: the tool's configuration, sessions and data too.
    #[serde(default)]
    purge: bool,
}

/// Installs, updates or removes a tool, as a job.
pub async fn change(
    req: HttpRequest,
    path: web::types::Path<(String, String)>,
    body: Option<web::types::Json<ChangeBody>>,
    state: web::types::State<Arc<AppState>>,
) -> Result<HttpResponse, web::Error> {
    let gated = match machine::gate(&req, &state, "agent tools change").await {
        Ok(g) => g,
        Err(r) => return Ok(r),
    };
    let (id, verb) = path.into_inner();
    let tool = match tool_of(&id) {
        Ok(t) => t,
        Err(r) => return Ok(r),
    };
    let purge = body.map(|b| b.purge).unwrap_or_default();
    let (kind, script) = match verb.as_str() {
        "install" => (JobKind::Install, model::install_script(tool)),
        "update" => (JobKind::Update, model::update_script(tool)),
        "uninstall" => (JobKind::Remove, model::uninstall_script(tool, purge)),
        _ => return Ok(refused(404, "unknownAction")),
    };
    let Some(job) = state.agent_tools.begin(kind) else { return Ok(refused(409, "busy")) };
    audit(&state, &gated, Outcome::Ok, format!("agent tools: {verb} {id}{}", if purge { " with its data" } else { "" })).await;
    let (job2, st) = (job.clone(), state.get_ref().clone());
    tokio::spawn(async move {
        let result = job2.run_steps(&[script]).await;
        match result {
            Ok(()) => job2.finish(JobState::Succeeded, None),
            Err(e) => {
                job2.push(format!("✕ {e}"));
                job2.finish(if e == "cancelled" { JobState::Cancelled } else { JobState::Failed }, Some(e));
            }
        }
        Event::new(Kind::Machine, Action::Close, if job2.state() == JobState::Succeeded { Outcome::Ok } else { Outcome::Error })
            .detail(format!("agent tools: {verb} {id} ended"))
            .record(&st.db)
            .await;
    });
    Ok(HttpResponse::Accepted().json(&job.view(0)))
}

#[derive(Deserialize)]
pub struct JobQuery {
    #[serde(default)]
    since: u64,
}

pub async fn job(req: HttpRequest, q: web::types::Query<JobQuery>, state: web::types::State<Arc<AppState>>) -> Result<HttpResponse, web::Error> {
    if let Err(r) = machine::gate(&req, &state, "agent tools job").await {
        return Ok(r);
    }
    match state.agent_tools.current() {
        Some(j) => Ok(HttpResponse::Ok().json(&j.view(q.since))),
        None => Ok(refused(404, "noJob")),
    }
}

pub async fn cancel(req: HttpRequest, state: web::types::State<Arc<AppState>>) -> Result<HttpResponse, web::Error> {
    if let Err(r) = machine::gate(&req, &state, "agent tools job cancel").await {
        return Ok(r);
    }
    if let Some(j) = state.agent_tools.current() {
        j.cancel();
    }
    Ok(HttpResponse::NoContent().finish())
}

/// The providers a tool can be pointed at: Agent mode's with an address
/// here (added, or a model server of this machine's), their API and models.
pub async fn providers(req: HttpRequest, state: web::types::State<Arc<AppState>>) -> Result<HttpResponse, web::Error> {
    if let Err(r) = machine::gate(&req, &state, "agent tools providers").await {
        return Ok(r);
    }
    let settings = match crate::agent_mode::config::load(&state.db).await {
        Ok(s) => s,
        Err(e) => return Ok(super::respond::internal(&e)),
    };
    let mut all = settings.providers;
    for a in state.agent.app_providers() {
        if !all.iter().any(|p| p.id == a.provider.id) {
            all.push(a.provider);
        }
    }
    // Their models as pi lists them, when it can.
    let listed = state.agent.available_models().await.unwrap_or(Value::Null);
    let out: Vec<Value> = all
        .into_iter()
        .map(|p| {
            let mut models: Vec<String> = p.models.iter().map(|m| m.id.clone()).collect();
            for m in listed.as_array().into_iter().flatten().filter(|m| m["provider"] == p.id.as_str()) {
                if let Some(id) = m["id"].as_str()
                    && !models.iter().any(|x| x == id)
                {
                    models.push(id.to_string());
                }
            }
            json!({ "id": p.id, "name": p.name, "api": p.api, "baseUrl": p.base_url, "models": models })
        })
        .collect();
    Ok(HttpResponse::Ok().json(&json!({ "providers": out })))
}

#[derive(Deserialize)]
#[serde(rename_all = "camelCase", deny_unknown_fields)]
pub struct ConfigureBody {
    provider: String,
    model: String,
}

/// Points a tool at a provider's model.
pub async fn configure(
    req: HttpRequest,
    id: web::types::Path<String>,
    body: web::types::Json<ConfigureBody>,
    state: web::types::State<Arc<AppState>>,
) -> Result<HttpResponse, web::Error> {
    let gated = match machine::gate(&req, &state, "agent tools configure").await {
        Ok(g) => g,
        Err(r) => return Ok(r),
    };
    let tool = match tool_of(&id) {
        Ok(t) => t,
        Err(r) => return Ok(r),
    };
    let Some(home) = home() else { return Ok(refused(409, "noHome")) };
    let (provider, key) = match state.agent.endpoint(&body.provider).await {
        Ok(Some(found)) => found,
        Ok(None) => return Ok(refused(404, "unknownProvider")),
        Err(e) => return Ok(HttpResponse::InternalServerError().json(&json!({ "error": e.to_string() }))),
    };
    let Some(api) = Api::from_id(&provider.api) else { return Ok(refused(400, "wrongApi")) };
    let target = model::Target { base_url: provider.base_url.clone(), api, key: key.unwrap_or_default(), model: body.model.clone() };
    let mut existing = Vec::new();
    for rel in model::config_files(tool) {
        existing.push(tokio::fs::read_to_string(home.join(rel)).await.ok());
    }
    let (writes, commands) = match model::configure(tool, &target, &existing) {
        Ok(x) => x,
        Err(e) => return Ok(HttpResponse::BadRequest().json(&e)),
    };
    for w in &writes {
        if let Err(e) = write_private(&home, w.path, &w.content).await {
            audit(&state, &gated, Outcome::Error, format!("agent tools: configure {id}: {}", w.path)).await;
            return Ok(HttpResponse::InternalServerError().json(&json!({ "error": "writeFailed", "reason": e.to_string() })));
        }
    }
    let limits = machine::at_least(&state.remote_access.exec, 1 << 20);
    // OpenClaw's configuration changes only with its gateway stopped: stopped
    // first when it runs, started again after.
    let gateway_ran = tool == Tool::Openclaw
        && machine::as_self(model::OPENCLAW_STATUS, &limits).await.is_ok_and(|o| model::openclaw_gateway_running(&o.stdout));
    if gateway_ran
        && let Some(stop) = model::gateway_script(tool, GatewayAction::Stop)
        && !machine::as_self(&stop, &limits).await.is_ok_and(|o| o.exit_code == Some(0))
    {
        return Ok(HttpResponse::Conflict().json(&json!({ "error": "gatewayWouldNotStop" })));
    }
    let restart = async {
        if gateway_ran && let Some(start) = model::gateway_script(tool, GatewayAction::Start) {
            let _ = machine::as_self(&start, &limits).await;
        }
    };
    for cmd in &commands {
        match machine::as_self(cmd, &limits).await {
            Ok(out) if out.exit_code == Some(0) => {}
            Ok(out) => {
                restart.await;
                audit(&state, &gated, Outcome::Error, format!("agent tools: configure {id}")).await;
                return Ok(HttpResponse::BadGateway().json(&json!({ "error": "commandFailed", "reason": format!("{}{}", out.stdout, out.stderr).trim() })));
            }
            Err(e) => {
                restart.await;
                return Ok(super::respond::internal(&e));
            }
        }
    }
    restart.await;
    audit(&state, &gated, Outcome::Ok, format!("agent tools: {id} uses {}/{}", body.provider, body.model)).await;
    Ok(HttpResponse::NoContent().finish())
}

/// Writes [content] to `<home>/<rel>` (0600, folders 0700), through a staged
/// file, so a reader never sees half of it.
async fn write_private(home: &Path, rel: &str, content: &str) -> std::io::Result<()> {
    let path = home.join(rel);
    let (path, content) = (path.clone(), content.to_string());
    tokio::task::spawn_blocking(move || {
        if let Some(dir) = path.parent() {
            std::fs::create_dir_all(dir)?;
            #[cfg(unix)]
            {
                use std::os::unix::fs::PermissionsExt;
                let _ = std::fs::set_permissions(dir, std::fs::Permissions::from_mode(0o700));
            }
        }
        let part = path.with_extension("sbm-part");
        let mut opts = std::fs::OpenOptions::new();
        opts.write(true).create(true).truncate(true);
        #[cfg(unix)]
        {
            use std::os::unix::fs::OpenOptionsExt;
            opts.mode(0o600);
        }
        {
            use std::io::Write;
            let mut f = opts.open(&part)?;
            f.write_all(content.as_bytes())?;
        }
        std::fs::rename(&part, &path)
    })
    .await
    .map_err(std::io::Error::other)?
}

#[derive(Deserialize)]
#[serde(deny_unknown_fields)]
pub struct GatewayBody {
    action: GatewayAction,
}

/// A tool's gateway: its status, or installed, started or stopped.
pub async fn gateway(
    req: HttpRequest,
    id: web::types::Path<String>,
    body: web::types::Json<GatewayBody>,
    state: web::types::State<Arc<AppState>>,
) -> Result<HttpResponse, web::Error> {
    let gated = match machine::gate(&req, &state, "agent tools gateway").await {
        Ok(g) => g,
        Err(r) => return Ok(r),
    };
    let tool = match tool_of(&id) {
        Ok(t) => t,
        Err(r) => return Ok(r),
    };
    let Some(script) = model::gateway_script(tool, body.action) else { return Ok(refused(404, "noGateway")) };
    let limits = machine::at_least(&state.remote_access.exec, 1 << 20);
    let out = match machine::as_self(&script, &limits).await {
        Ok(o) => o,
        Err(e) => return Ok(super::respond::internal(&e)),
    };
    if body.action != GatewayAction::Status {
        let outcome = if out.exit_code == Some(0) { Outcome::Ok } else { Outcome::Error };
        audit(&state, &gated, outcome, format!("agent tools: {id} gateway {:?}", body.action).to_lowercase()).await;
    }
    Ok(HttpResponse::Ok().json(&json!({ "exitCode": out.exit_code, "output": out.stdout })))
}
