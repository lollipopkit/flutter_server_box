//! The agent's watch over the web apps it deployed: every minute, each
//! installed app's containers (`compose ps`) give its health, which the
//! panel shows; a desk notification says when one goes down or unhealthy,
//! when it is back, and when the catalog has a version newer than the one
//! deployed (once per version).
//!
//! An app the operator stopped is `stopped`, never a notification. A step
//! running (a deploy, a restart) is not judged until it ends.

use std::sync::Arc;
use std::time::Duration;

use sbm_parser::stack::StackService;
use serde::Serialize;

use super::{compose, store, Stacks};
use crate::api::desk::{Level, Source};
use crate::api::server::AppState;

const EVERY: Duration = Duration::from_secs(60);
/// The first look, after the agent has settled.
const FIRST: Duration = Duration::from_secs(20);

#[derive(Debug, Clone, Copy, PartialEq, Eq, Serialize)]
#[serde(rename_all = "camelCase")]
pub enum State {
    Healthy,
    /// Running, its health checks not passed yet.
    Starting,
    /// A container restarting or failing its health check.
    Unhealthy,
    /// A container that should run does not, or none is there.
    Down,
    /// The operator stopped it.
    Stopped,
}

impl State {
    fn bad(self) -> bool {
        matches!(self, State::Unhealthy | State::Down)
    }
}

#[derive(Debug, Clone, Serialize)]
pub struct Health {
    pub state: State,
    /// The services that are not well, by name.
    pub failing: Vec<String>,
    /// RFC 3339.
    pub checked_at: String,
    /// A notification said it was down or unhealthy, and none yet that it is
    /// back (it may come back through `starting`).
    #[serde(skip)]
    alerted: bool,
}

/// What [services] say about their app. One of [jobs] (`[compose] jobs`)
/// exited with 0 has finished, not gone down; any other service not running
/// is down, whatever its exit code (a stopped server exits with 0 too).
pub fn judge(services: &[StackService], jobs: &[String]) -> (State, Vec<String>) {
    if services.is_empty() {
        return (State::Down, Vec::new());
    }
    let down: Vec<String> = services
        .iter()
        .filter(|s| {
            s.state != "running" && s.state != "restarting" && !(jobs.contains(&s.service) && s.state == "exited" && s.exit_code == Some(0))
        })
        .map(|s| s.service.clone())
        .collect();
    if !down.is_empty() {
        return (State::Down, down);
    }
    let unhealthy: Vec<String> = services
        .iter()
        .filter(|s| s.state == "restarting" || s.health.as_deref() == Some("unhealthy"))
        .map(|s| s.service.clone())
        .collect();
    if !unhealthy.is_empty() {
        return (State::Unhealthy, unhealthy);
    }
    if services.iter().any(|s| s.health.as_deref() == Some("starting")) {
        return (State::Starting, Vec::new());
    }
    (State::Healthy, Vec::new())
}

impl Stacks {
    pub fn health(&self, id: &str) -> Option<Health> {
        self.health.lock().unwrap_or_else(|e| e.into_inner()).get(id).cloned()
    }

    /// Records [next] for [id]; the previous one.
    fn record(&self, id: &str, next: Health) -> Option<Health> {
        self.health.lock().unwrap_or_else(|e| e.into_inner()).insert(id.to_string(), next)
    }

    fn forget_others(&self, ids: &[String]) {
        self.health.lock().unwrap_or_else(|e| e.into_inner()).retain(|id, _| ids.contains(id));
    }
}

/// Watches every installed app until the agent stops.
pub async fn watch(state: Arc<AppState>) {
    tokio::time::sleep(FIRST).await;
    let mut tick = tokio::time::interval(EVERY);
    loop {
        tick.tick().await;
        check(&state).await;
    }
}

/// One look at every installed app.
pub async fn check(state: &Arc<AppState>) {
    let Ok(rows) = store::all(&state.db).await else { return };
    state.stacks.forget_others(&rows.iter().map(|r| r.id.clone()).collect::<Vec<_>>());
    let Some(runtime) = crate::api::containers::detect_runtime(&state.remote_access.exec).await else { return };
    let limits = crate::api::machine::at_least(&state.remote_access.exec, 4 << 20);
    for row in rows.iter().filter(|r| r.state == "installed") {
        let Some(package) = state.stacks.package(&row.id) else { continue };
        if state.stacks.job(&row.id).is_some_and(|j| j.running()) {
            continue;
        }
        let titles = &package.manifest.title;
        let title = titles.get("en").cloned().unwrap_or_else(|| package.manifest.project.clone());
        if package.manifest.version != row.version && row.update_noticed.as_deref() != Some(package.manifest.version.as_str()) {
            let body = format!("{} {} can be installed (now {}).", package.manifest.project, package.manifest.version, row.version);
            notify(
                state,
                Level::Info,
                &row.id,
                &format!("{title}: an update"),
                &body,
                "stack.update",
                serde_json::json!({
                    "app": package.manifest.id,
                    "titles": titles,
                    "project": package.manifest.project,
                    "version": package.manifest.version,
                    "current": row.version,
                }),
            )
            .await;
            let _ = store::set_update_noticed(&state.db, &row.id, &package.manifest.version).await;
        }
        let (judged, failing) = if row.stopped {
            (State::Stopped, Vec::new())
        } else {
            let stack = compose(runtime, &row.id, &state.stacks.dir(&row.id), &package);
            match crate::api::exec::run(&stack.ps(), None, None, &limits).await {
                Ok(out) if out.exit_code == Some(0) => judge(&sbm_parser::stack::parse_ps(&out.stdout), &package.manifest.compose.jobs),
                // Compose itself not answering says nothing about the app.
                _ => continue,
            }
        };
        let previous = state.stacks.health(&row.id);
        let was = previous.as_ref().map(|h| h.state);
        let alerted = previous.is_some_and(|h| h.alerted);
        let mut next = Health { state: judged, failing: failing.clone(), checked_at: chrono::Utc::now().to_rfc3339(), alerted };
        if judged.bad() && was != Some(judged) {
            next.alerted = true;
            let kind = if judged == State::Down { "stack.down" } else { "stack.unhealthy" };
            let (subject, body) = match (judged, failing.is_empty()) {
                (State::Down, true) => (format!("{title} is down"), "None of its containers is running.".to_string()),
                (State::Down, false) => (format!("{title} is down"), format!("Not running: {}.", failing.join(", "))),
                _ => (format!("{title} is unhealthy"), format!("Failing its health check: {}.", failing.join(", "))),
            };
            notify(
                state,
                Level::Warning,
                &row.id,
                &subject,
                &body,
                kind,
                serde_json::json!({ "app": package.manifest.id, "titles": titles, "services": failing }),
            )
            .await;
        } else if alerted && matches!(judged, State::Healthy | State::Stopped) {
            next.alerted = false;
            if judged == State::Healthy {
                notify(
                    state,
                    Level::Info,
                    &row.id,
                    &format!("{title} is running again"),
                    "Every container is up.",
                    "stack.back",
                    serde_json::json!({ "app": package.manifest.id, "titles": titles }),
                )
                .await;
            }
        }
        state.stacks.record(&row.id, next);
    }
}

async fn notify(
    state: &AppState,
    level: Level,
    id: &str,
    subject: &str,
    body: &str,
    kind: &str,
    params: serde_json::Value,
) {
    if let Err(e) = state
        .desk
        .notify(&state.db, level, Source::Stack(id.to_string()), subject, body, Some((kind, &params)))
        .await
    {
        tracing::error!("stack {id}: notifying: {e}");
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    fn service(name: &str, state: &str, health: Option<&str>, exit_code: Option<i64>) -> StackService {
        StackService {
            service: name.into(),
            name: format!("sbm-x-{name}-1"),
            image: "x".into(),
            state: state.into(),
            health: health.map(String::from),
            exit_code,
            status: String::new(),
        }
    }

    #[test]
    fn an_apps_health_is_its_worst_container() {
        let up = service("web", "running", Some("healthy"), Some(0));
        let jobs = ["migrate".to_string()];
        assert_eq!(judge(&[up.clone(), service("redis", "running", None, Some(0))], &[]).0, State::Healthy);
        assert_eq!(judge(&[up.clone(), service("migrate", "exited", None, Some(0))], &jobs).0, State::Healthy);
        assert_eq!(judge(&[up.clone(), service("migrate", "exited", None, Some(2))], &jobs).0, State::Down);
        // A server stopped exits with 0 too.
        assert_eq!(judge(&[service("web", "exited", None, Some(0))], &jobs), (State::Down, vec!["web".to_string()]));
        assert_eq!(judge(&[up.clone(), service("db", "exited", None, Some(1))], &[]), (State::Down, vec!["db".to_string()]));
        assert_eq!(judge(&[up.clone(), service("ml", "restarting", None, Some(1))], &[]), (State::Unhealthy, vec!["ml".to_string()]));
        assert_eq!(judge(&[service("web", "running", Some("unhealthy"), None)], &[]).0, State::Unhealthy);
        assert_eq!(judge(&[service("web", "running", Some("starting"), None)], &[]).0, State::Starting);
        assert_eq!(judge(&[], &[]).0, State::Down);
    }
}
