//! MCP servers the operator added for Agent mode (migration 031): each task gets
//! their tools beside its own, through the same permissions as a command.
//!
//! A server is an address (Streamable HTTP) and the headers sent with every
//! request, a token most often. Like a provider's key, a header's value goes
//! in and never comes back out: a read names the headers that are set.
//! Connections are kept between tasks and made again when the server's
//! settings change or a call finds it gone. Deployed apps' servers
//! (`stacks::mcp`) join them on their own.

use crate::utils::lock::LockExt;
use std::collections::{BTreeMap, HashMap};
use std::sync::Arc;
use std::time::Duration;

use fl_pi_llm::host::mcp::{self as pi_mcp, McpClient, McpServerConfig, McpTool};
use fl_pi_llm::mcp as shared_mcp;
use fl_pi_llm::host::{BoxFuture, Cancel, Tool, ToolCall, ToolDef, ToolResult};
use serde::{Deserialize, Serialize};
use serde_json::{Value, json};
use sqlx::SqlitePool;

use super::permissions::{self, Judgment, Mode};
use super::{Flow, first_line};
use crate::api::server::AppState;
use crate::api::ws::audit::Outcome;

pub const MAX_SERVERS: usize = 16;
const MAX_NAME: usize = 64;
const MAX_URL: usize = 2048;
const MAX_HEADERS: usize = 8;
const MAX_HEADER_VALUE: usize = 8192;
/// How long a server may take to answer `initialize` and `tools/list`.
const CONNECT_TIMEOUT: Duration = Duration::from_secs(20);
/// What a confirmation shows of the arguments.
const MAX_SHOWN_ARGS: usize = 2000;

/// A server as stored and as a read shows it.
#[derive(Debug, Clone, Serialize, Deserialize, PartialEq, Eq)]
#[serde(rename_all = "camelCase", deny_unknown_fields)]
pub struct Server {
    /// `pi_mcp::server_id` of the address: the prefix of its tools' names.
    #[serde(default)]
    pub id: String,
    pub name: String,
    pub url: String,
    #[serde(default = "yes")]
    pub enabled: bool,
    /// The headers set, by name; their values are never read back.
    #[serde(default, skip_deserializing)]
    pub headers: Vec<String>,
}

fn yes() -> bool {
    true
}

/// A write: every server, in order. `headers` sets (a string), removes
/// (`null`) or keeps (absent) each header of a server, by its address.
#[derive(Debug, Deserialize)]
#[serde(rename_all = "camelCase", deny_unknown_fields)]
pub struct ServersWrite {
    pub servers: Vec<ServerWrite>,
}

#[derive(Debug, Deserialize)]
#[serde(rename_all = "camelCase", deny_unknown_fields)]
pub struct ServerWrite {
    pub name: String,
    pub url: String,
    #[serde(default = "yes")]
    pub enabled: bool,
    #[serde(default)]
    pub headers: BTreeMap<String, Option<String>>,
}

fn header_name_ok(name: &str) -> bool {
    (1..=64).contains(&name.len()) && name.bytes().all(|b| b.is_ascii_alphanumeric() || b == b'-')
}

pub(crate) fn header_value_ok(value: &str) -> bool {
    !value.is_empty() && value.len() <= MAX_HEADER_VALUE && !value.chars().any(char::is_control)
}

/// Where a server may be: HTTPS, or plain HTTP on this machine (an app
/// deployed here).
pub fn url_ok(url: &str) -> bool {
    url.len() <= MAX_URL && fl_pi_llm::host::fetch_allowed(url, &[]) && url::Url::parse(url).is_ok()
}

impl ServersWrite {
    /// Why it cannot be stored: the field and what is wrong.
    pub fn check(&self) -> Result<(), String> {
        if self.servers.len() > MAX_SERVERS {
            return Err(format!("servers: at most {MAX_SERVERS}"));
        }
        let mut seen = std::collections::BTreeSet::new();
        for (i, s) in self.servers.iter().enumerate() {
            if !(1..=MAX_NAME).contains(&s.name.trim().chars().count()) {
                return Err(format!("servers[{i}].name: 1 to {MAX_NAME} characters"));
            }
            if !url_ok(&s.url) {
                return Err(format!("servers[{i}].url: https://, or http:// on this machine"));
            }
            if !seen.insert(pi_mcp::server_id(&s.url)) {
                return Err(format!("servers[{i}].url: listed twice"));
            }
            if s.headers.len() > MAX_HEADERS {
                return Err(format!("servers[{i}].headers: at most {MAX_HEADERS}"));
            }
            for (name, value) in &s.headers {
                if !header_name_ok(name) || value.as_deref().is_some_and(|v| !header_value_ok(v)) {
                    return Err(format!("servers[{i}].headers.{name}: not a header"));
                }
            }
        }
        Ok(())
    }
}

/// A deployed app's server as a read shows it: what the app says, and its id.
#[derive(Debug, Clone, Serialize)]
#[serde(rename_all = "camelCase")]
pub struct AppServer {
    pub id: String,
    #[serde(flatten)]
    pub app: crate::stacks::mcp::AppMcp,
}

/// The deployed apps' servers, an address an admin added left to theirs.
pub async fn app_servers(state: &AppState) -> Vec<AppServer> {
    let own: Vec<String> = load(&state.db).await.unwrap_or_default().into_iter().map(|s| s.id).collect();
    crate::stacks::mcp::servers(state)
        .await
        .into_iter()
        .map(|app| AppServer { id: pi_mcp::server_id(&app.url), app })
        .filter(|s| !own.contains(&s.id))
        .collect()
}

/// Every server, in order, its headers named.
pub async fn load(db: &SqlitePool) -> Result<Vec<Server>, sqlx::Error> {
    let rows = sqlx::query_as::<_, (String, String, String, bool, String)>(
        "SELECT id, name, url, enabled, headers FROM agent_mcp_server ORDER BY position",
    )
    .fetch_all(db)
    .await?;
    Ok(rows
        .into_iter()
        .map(|(id, name, url, enabled, headers)| {
            let headers: BTreeMap<String, String> = serde_json::from_str(&headers).unwrap_or_default();
            Server { id, name, url, enabled, headers: headers.into_keys().collect() }
        })
        .collect())
}

/// The enabled servers as a connection needs them, headers with values.
async fn configs(db: &SqlitePool) -> Result<Vec<(Server, McpServerConfig)>, sqlx::Error> {
    let rows = sqlx::query_as::<_, (String, String, String, String)>(
        "SELECT id, name, url, headers FROM agent_mcp_server WHERE enabled = 1 ORDER BY position",
    )
    .fetch_all(db)
    .await?;
    Ok(rows
        .into_iter()
        .map(|(id, name, url, headers)| {
            let headers: BTreeMap<String, String> = serde_json::from_str(&headers).unwrap_or_default();
            let server = Server { id, name, url: url.clone(), enabled: true, headers: headers.keys().cloned().collect() };
            (server, McpServerConfig { url, headers: headers.into_iter().collect() })
        })
        .collect())
}

/// Replaces every server, keeping the headers a write leaves out.
pub async fn store(db: &SqlitePool, w: &ServersWrite) -> Result<(), sqlx::Error> {
    let now = chrono::Utc::now().to_rfc3339();
    let mut tx = db.begin().await?;
    let old: HashMap<String, String> = sqlx::query_as::<_, (String, String)>("SELECT url, headers FROM agent_mcp_server")
        .fetch_all(&mut *tx)
        .await?
        .into_iter()
        .collect();
    sqlx::query("DELETE FROM agent_mcp_server").execute(&mut *tx).await?;
    for (position, s) in w.servers.iter().enumerate() {
        let mut headers: BTreeMap<String, String> =
            old.get(&s.url).and_then(|h| serde_json::from_str(h).ok()).unwrap_or_default();
        for (name, value) in &s.headers {
            match value {
                Some(v) => headers.insert(name.clone(), v.clone()),
                None => headers.remove(name),
            };
        }
        sqlx::query(
            "INSERT INTO agent_mcp_server (id, position, name, url, enabled, headers, updated_at) VALUES (?, ?, ?, ?, ?, ?, ?)",
        )
        .bind(pi_mcp::server_id(&s.url))
        .bind(position as i64)
        .bind(s.name.trim())
        .bind(&s.url)
        .bind(s.enabled)
        .bind(serde_json::to_string(&headers).expect("headers serialise"))
        .bind(&now)
        .execute(&mut *tx)
        .await?;
    }
    tx.commit().await
}

/// A server connected, and what it listed.
struct Connection {
    /// What it was connected with: a change connects again.
    config: (String, Vec<(String, String)>),
    client: Arc<McpClient>,
    tools: Vec<McpTool>,
}

/// How a server is doing, for the settings page.
#[derive(Debug, Clone, Serialize)]
#[serde(rename_all = "camelCase")]
pub struct Status {
    pub id: String,
    pub connected: bool,
    /// What the server calls itself, once connected.
    #[serde(skip_serializing_if = "Option::is_none")]
    pub label: Option<String>,
    pub tools: Vec<ToolView>,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub error: Option<String>,
}

#[derive(Debug, Clone, Serialize)]
#[serde(rename_all = "camelCase")]
pub struct ToolView {
    pub name: String,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub title: Option<String>,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub description: Option<String>,
    pub read_only: bool,
}

/// The connections, by server id, and the last failure of each.
#[derive(Default)]
pub struct Hub {
    connections: tokio::sync::Mutex<HashMap<String, Connection>>,
    errors: std::sync::Mutex<HashMap<String, String>>,
}

impl Hub {
    /// Connects to every enabled server not connected yet (or connected with
    /// other settings), and forgets the rest; answers each one's state.
    pub async fn refresh(&self, state: &AppState) -> Vec<Status> {
        let fetch = state.agent.fetch();
        let mut configs = configs(&state.db).await.unwrap_or_default();
        let apps = app_servers(state).await;
        for s in apps.iter().filter(|s| s.app.ready()) {
            let server = Server {
                id: s.id.clone(),
                name: s.app.title.clone(),
                url: s.app.url.clone(),
                enabled: true,
                headers: s.app.header.iter().map(|(name, _)| name.clone()).collect(),
            };
            configs.push((server, McpServerConfig { url: s.app.url.clone(), headers: s.app.header.clone().into_iter().collect() }));
        }
        let mut connections = self.connections.lock().await;
        connections.retain(|id, _| configs.iter().any(|(s, _)| &s.id == id));
        let wanted: Vec<_> = configs
            .iter()
            .filter(|(s, c)| connections.get(&s.id).is_none_or(|k| k.config != (c.url.clone(), c.headers.clone())))
            .cloned()
            .collect();
        // Each server on its own: a slow one does not hold the others.
        let tries = wanted.into_iter().map(|(server, config)| {
            let fetch = fetch.clone();
            async move {
                let key = (config.url.clone(), config.headers.clone());
                let connected = tokio::time::timeout(CONNECT_TIMEOUT, async {
                    let client = McpClient::connect(fetch, config).await?;
                    let tools = client.list_tools().await?;
                    Ok::<_, String>((client, tools))
                })
                .await
                .unwrap_or_else(|_| Err(format!("no answer in {}s", CONNECT_TIMEOUT.as_secs())));
                (server.id, key, connected)
            }
        });
        for (id, config, connected) in futures::future::join_all(tries).await {
            match connected {
                Ok((client, tools)) => {
                    self.errors.locked().remove(&id);
                    connections.insert(id, Connection { config, client: Arc::new(client), tools });
                }
                Err(e) => {
                    tracing::warn!("MCP server {id}: {e}");
                    self.errors.locked().insert(id.clone(), e);
                    connections.remove(&id);
                }
            }
        }
        let errors = self.errors.locked();
        let waiting = apps.iter().filter(|s| s.app.enabled && !s.app.ready()).map(|s| Status {
            id: s.id.clone(),
            connected: false,
            label: None,
            tools: Vec::new(),
            error: Some(match s.app.credential {
                crate::stacks::mcp::Credential::Asked { .. } => "needsToken".into(),
                crate::stacks::mcp::Credential::OAuth => "needsSignIn".into(),
                _ => "noCredential".into(),
            }),
        });
        configs
            .iter()
            .map(|(s, _)| match connections.get(&s.id) {
                Some(c) => Status {
                    id: s.id.clone(),
                    connected: true,
                    label: Some(c.client.name.clone()),
                    tools: c
                        .tools
                        .iter()
                        .map(|t| ToolView { name: t.name.clone(), title: t.title.clone(), description: t.description.clone(), read_only: t.read_only })
                        .collect(),
                    error: None,
                },
                None => Status { id: s.id.clone(), connected: false, label: None, tools: Vec::new(), error: errors.get(&s.id).cloned() },
            })
            .chain(waiting)
            .collect()
    }

    /// Drops [id]'s connection: the next task connects again.
    pub async fn forget(&self, id: &str) {
        self.connections.lock().await.remove(id);
    }

    /// The tools of every connected server for [flow], each through the
    /// task's permissions, and what the servers say about using them.
    pub(crate) async fn tools_for(&self, state: &Arc<AppState>, flow: &Arc<Flow>) -> (Vec<Arc<dyn Tool>>, Option<String>) {
        self.refresh(state).await;
        let connections = self.connections.lock().await;
        let mut handles = Vec::new();
        let mut clients = Vec::new();
        for c in connections.values() {
            clients.push(c.client.clone());
            handles.extend(pi_mcp::McpToolHandle::all(c.client.clone(), c.tools.clone()).into_iter().map(Arc::new));
        }
        let instructions = pi_mcp::instructions(&clients);
        if handles.len() <= shared_mcp::DIRECT_TOOLS_MAX {
            let tools = handles.into_iter().map(|handle| Arc::new(Gated { state: state.clone(), flow: flow.clone(), handle }) as Arc<dyn Tool>);
            return (tools.collect(), instructions);
        }
        // Many: found when needed rather than all in every request.
        let handles = Arc::new(handles);
        let tools: Vec<Arc<dyn Tool>> = vec![
            Arc::new(Search { handles: handles.clone() }),
            Arc::new(Call { state: state.clone(), flow: flow.clone(), handles }),
        ];
        (tools, instructions)
    }
}

/// `mcp_search`: the connected servers' tools that a query asks for.
struct Search {
    handles: Arc<Vec<Arc<pi_mcp::McpToolHandle>>>,
}

impl Tool for Search {
    fn def(&self) -> ToolDef {
        let mut servers: Vec<(String, String)> = Vec::new();
        for h in self.handles.iter() {
            if !servers.iter().any(|(id, _)| id == &h.server_id) {
                servers.push((h.server_id.clone(), h.client.name.clone()));
            }
        }
        let (description, parameters) = shared_mcp::search_def(&servers);
        ToolDef { name: shared_mcp::SEARCH_TOOL.into(), description, parameters, label: Some("MCP".into()), sequential: false }
    }

    fn execute(&self, call: ToolCall, _cancel: Cancel) -> BoxFuture<'_, Result<ToolResult, String>> {
        Box::pin(async move {
            let listed: Vec<shared_mcp::Listed<'_>> =
                self.handles.iter().map(|h| shared_mcp::Listed { server_id: &h.server_id, server: &h.client.name, tool: &h.tool }).collect();
            let found = shared_mcp::search(&listed, call.args["query"].as_str().unwrap_or_default(), call.args["server"].as_str());
            Ok(ToolResult::text(serde_json::to_string_pretty(&found).unwrap_or_default()).with_details(found))
        })
    }
}

/// `mcp_call`: one tool a search named, through the task's permissions as
/// the tool itself would be.
struct Call {
    state: Arc<AppState>,
    flow: Arc<Flow>,
    handles: Arc<Vec<Arc<pi_mcp::McpToolHandle>>>,
}

impl Tool for Call {
    fn def(&self) -> ToolDef {
        let (description, parameters) = shared_mcp::call_def();
        ToolDef { name: shared_mcp::CALL_TOOL.into(), description, parameters, label: Some("MCP".into()), sequential: false }
    }

    fn execute(&self, call: ToolCall, cancel: Cancel) -> BoxFuture<'_, Result<ToolResult, String>> {
        Box::pin(async move {
            let (server, tool) = (call.args["server"].as_str().unwrap_or_default(), call.args["tool"].as_str().unwrap_or_default());
            let Some(handle) = self.handles.iter().find(|h| h.server_id == server && h.tool.name == tool) else {
                return Err(format!("No tool {tool} on server {server}: search with {} first.", shared_mcp::SEARCH_TOOL));
            };
            let args = match &call.args["arguments"] {
                Value::Null => json!({}),
                a => a.clone(),
            };
            let inner = ToolCall { args, ..call };
            Gated { state: self.state.clone(), flow: self.flow.clone(), handle: handle.clone() }.execute(inner, cancel).await
        })
    }
}

/// An MCP tool behind the task's permission mode: one that says it changes
/// nothing runs; any other is confirmed (manual), judged (auto) or run and
/// recorded (bypass).
struct Gated {
    state: Arc<AppState>,
    flow: Arc<Flow>,
    handle: Arc<pi_mcp::McpToolHandle>,
}

impl Gated {
    /// The call as the person and the judge read it: `server · tool` and its
    /// arguments.
    fn shown(&self, call: &ToolCall) -> String {
        let args = serde_json::to_string_pretty(&call.args).unwrap_or_default();
        let args = match args.char_indices().nth(MAX_SHOWN_ARGS) {
            Some((at, _)) => format!("{}…", &args[..at]),
            None => args,
        };
        format!("MCP {} {args}", self.handle.label())
    }

    /// Whether [call] may run now; Err for one that is refused, with what to
    /// tell the model.
    async fn allowed(&self, call: &ToolCall) -> Result<bool, String> {
        let state = &self.state;
        let flow = &self.flow;
        if self.handle.tool.read_only {
            return Ok(true);
        }
        let shown = self.shown(call);
        let perms = permissions::load(&state.db).await.map_err(|e| format!("reading the permissions: {e}"))?;
        let picked = flow.view.locked().mode;
        let ask = match perms.mode_for(picked) {
            Mode::Bypass => {
                super::tools::record(state, &format!("bypass: {}", first_line(&shown, 200)), Outcome::Ok).await;
                false
            }
            Mode::Manual => true,
            Mode::Auto => {
                match super::tools::judge(state, flow, &shown, &self.handle.label(), "change", false, &perms.auto_mode).await {
                    Some(Judgment::Allow) => {
                        super::tools::record(state, &format!("auto: allowed {}", first_line(&shown, 200)), Outcome::Ok).await;
                        false
                    }
                    Some(Judgment::Block { rule, reason }) => {
                        super::tools::record(state, &format!("auto: blocked [{rule}] {}", first_line(&shown, 200)), Outcome::Denied)
                            .await;
                        return Err(format!(
                            "Blocked by auto mode: {reason} Nothing was called. Do not try to reach the same end another way; \
                             if it is needed, tell the person."
                        ));
                    }
                    None => true,
                }
            }
        };
        if !ask {
            return Ok(true);
        }
        let mut view = super::tools::pending_view("confirm", call, self.handle.label());
        view.command = Some(shown);
        let Some(answer) = state.agent.ask(flow, view).await else { return Err("The task was stopped.".into()) };
        match answer.action.as_str() {
            "run" | "always" => Ok(true),
            "edit" => Err(format!("Not called. The person said: {}", answer.text.unwrap_or_default())),
            _ => Ok(false),
        }
    }
}

impl Tool for Gated {
    fn def(&self) -> ToolDef {
        self.handle.def()
    }

    fn execute(&self, call: ToolCall, cancel: Cancel) -> BoxFuture<'_, Result<ToolResult, String>> {
        Box::pin(async move {
            super::tools::may_run(&self.state, &self.flow).await?;
            let hub = &self.state.agent;
            let title = self.handle.label();
            hub.step_begin(&self.flow, &call.id, &title, "system");
            hub.persist(&self.flow).await;
            let r = match self.allowed(&call).await {
                Ok(true) => {
                    // Asked and answered: the account and the transport rule are checked again, now.
                    super::tools::may_run(&self.state, &self.flow).await?;
                    let r = self.handle.execute(call.clone(), cancel).await;
                    if r.is_err() {
                        // A server that went away is connected again next time.
                        hub.mcp.forget(&self.handle.server_id).await;
                    }
                    r
                }
                Ok(false) => Ok(ToolResult::text("The person declined. Nothing was called; change nothing else for this step.")
                    .with_details(json!({ "declined": true }))),
                Err(e) => Err(e),
            };
            hub.step_state(
                &self.flow,
                &call.id,
                match &r {
                    Ok(r) if r.details["declined"] == true => "cancelled",
                    Ok(_) => "done",
                    Err(_) => "failed",
                },
            );
            r
        })
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    fn write(servers: Vec<ServerWrite>) -> ServersWrite {
        ServersWrite { servers }
    }

    fn server(url: &str, headers: &[(&str, Option<&str>)]) -> ServerWrite {
        ServerWrite {
            name: "Home".into(),
            url: url.into(),
            enabled: true,
            headers: headers.iter().map(|(k, v)| (k.to_string(), v.map(String::from))).collect(),
        }
    }

    #[test]
    fn writes_are_checked() {
        assert!(write(vec![server("https://ha.example/api/mcp", &[("Authorization", Some("Bearer x"))])]).check().is_ok());
        assert!(write(vec![server("http://127.0.0.1:8123/api/mcp", &[])]).check().is_ok(), "an app deployed here");
        assert!(write(vec![server("http://ha.example/api/mcp", &[])]).check().is_err(), "plain HTTP elsewhere");
        assert!(write(vec![server("https://a.example", &[]), server("https://a.example", &[])]).check().is_err());
        assert!(write(vec![server("https://a.example", &[("Bad Header", Some("x"))])]).check().is_err());
        assert!(write(vec![server("https://a.example", &[("X-Token", Some("a\nb"))])]).check().is_err());
    }

    #[tokio::test]
    async fn headers_are_kept_unless_changed_and_never_read_back() {
        let db = SqlitePool::connect("sqlite::memory:").await.unwrap();
        sqlx::migrate!("./migrations").run(&db).await.unwrap();
        let url = "https://ha.example/api/mcp";
        store(&db, &write(vec![server(url, &[("Authorization", Some("Bearer one")), ("X-Extra", Some("1"))])])).await.unwrap();
        // Absent keeps, null removes.
        store(&db, &write(vec![server(url, &[("X-Extra", None)])])).await.unwrap();
        let servers = load(&db).await.unwrap();
        assert_eq!(servers[0].headers, ["Authorization"]);
        assert_eq!(servers[0].id, pi_mcp::server_id(url));
        let shown = serde_json::to_string(&servers).unwrap();
        assert!(!shown.contains("Bearer"), "{shown}");
        let configs = configs(&db).await.unwrap();
        assert_eq!(configs[0].1.headers, [("Authorization".to_string(), "Bearer one".to_string())]);
    }
}
