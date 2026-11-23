//! The app's MCP server: [`sbm_mcp`]'s protocol, tokens, scopes and machine
//! tools, served for every server the app reaches.
//!
//! The listener, the registry file, the servers and their connections are
//! the app's; the request — its credential, its headers, what it asks and
//! the answer — is decided here. A command reaches a server through `run`,
//! the app's own way there (`ServerNotifier`'s exec, or this device); the
//! app's preferences through `settings`.
//!
//! # The registry
//!
//! One JSON file: an optional `policy` ceiling and the `tokens`, each held by
//! its BLAKE3 digest with its own `scopes` and `commands`. An absent `scopes`
//! is every scope, including any a newer build adds. Read again on every
//! request, so an edit or a revocation applies to the next call.

use std::collections::{HashMap, HashSet};
use std::sync::Mutex;
use std::sync::atomic::{AtomicBool, Ordering};

use async_trait::async_trait;
use flutter_rust_bridge::DartFnFuture;
use serde::{Deserialize, Serialize};
use serde_json::{Value, json};

use sbm_mcp::access::{CommandPolicy, Scope};
use sbm_mcp::machine::{Audit, Machine, Ran, Run, Stage};
use sbm_mcp::{Answer, CallToolResult, Host, Tool, catalog, structured, tool_error};
use sbm_parser::SystemType;
use sbm_parser::sudo::SudoEntry;

use super::script::ShellFuncKind;

/// The longest body read, and the longest `run_command`.
pub const APP_MCP_MAX_BODY: usize = 64 * 1024;

#[flutter_rust_bridge::frb(ignore)]
#[derive(Debug, Default, Serialize, Deserialize)]
#[serde(deny_unknown_fields)]
struct Registry {
    #[serde(default)]
    policy: Policy,
    #[serde(default)]
    tokens: Vec<TokenEntry>,
}

#[flutter_rust_bridge::frb(ignore)]
#[derive(Debug, Default, Serialize, Deserialize)]
#[serde(deny_unknown_fields)]
struct Policy {
    #[serde(default, skip_serializing_if = "Option::is_none")]
    scopes: Option<Vec<Scope>>,
    #[serde(default)]
    commands: CommandPolicy,
}

#[flutter_rust_bridge::frb(ignore)]
#[derive(Debug, Serialize, Deserialize)]
#[serde(deny_unknown_fields)]
struct TokenEntry {
    /// [`sbm_mcp::token::hash`] of the token.
    id: String,
    name: String,
    #[serde(default, skip_serializing_if = "Option::is_none")]
    scopes: Option<Vec<Scope>>,
    #[serde(default)]
    commands: CommandPolicy,
    created_at: i64,
}

impl Registry {
    fn parse(text: &str) -> Result<Self, String> {
        let registry: Registry = if text.trim().is_empty() {
            Registry::default()
        } else {
            serde_json::from_str(text).map_err(|e| e.to_string())?
        };
        registry.check()?;
        Ok(registry)
    }

    fn check(&self) -> Result<(), String> {
        let app = |scopes: &Option<Vec<Scope>>| match scopes {
            Some(list) => match list.iter().find(|s| !Scope::APP.contains(s)) {
                Some(s) => Err(format!("`{}` is not a scope of the app", s.as_str())),
                None => Ok(()),
            },
            None => Ok(()),
        };
        app(&self.policy.scopes)?;
        self.policy.commands.validate().map_err(|e| format!("policy: {e}"))?;
        let mut seen = HashSet::new();
        for token in &self.tokens {
            if !sbm_mcp::token::is_hash(&token.id) {
                return Err(format!("token `{}`: id is not a token digest", token.name));
            }
            if !seen.insert(&token.id) {
                return Err(format!("token `{}`: listed twice", token.name));
            }
            if token.name.trim().is_empty() {
                return Err("a token has no name".into());
            }
            app(&token.scopes).map_err(|e| format!("token `{}`: {e}", token.name))?;
            token.commands.validate().map_err(|e| format!("token `{}`: {e}", token.name))?;
        }
        Ok(())
    }

    fn text(&self) -> String {
        serde_json::to_string_pretty(self).unwrap_or_default()
    }

    fn token(&self, authorization: Option<&str>) -> Option<&TokenEntry> {
        let id = sbm_mcp::token::bearer(authorization?)?;
        self.tokens.iter().find(|t| t.id == id)
    }

    /// What [token] may do: its scopes within the policy's.
    fn scopes(&self, token: &TokenEntry) -> Vec<Scope> {
        let within = |list: &Option<Vec<Scope>>, s: &Scope| list.as_ref().is_none_or(|l| l.contains(s));
        Scope::APP.iter().copied().filter(|s| within(&token.scopes, s) && within(&self.policy.scopes, s)).collect()
    }
}

fn scope_names(scopes: &Option<Vec<Scope>>) -> Option<Vec<String>> {
    scopes.as_ref().map(|l| l.iter().map(|s| s.as_str().to_owned()).collect())
}

fn parse_scopes(names: Option<Vec<String>>) -> Result<Option<Vec<Scope>>, String> {
    names
        .map(|names| {
            names
                .iter()
                .map(|n| Scope::parse(Scope::APP, n).ok_or_else(|| format!("`{n}` is not a scope of the app")))
                .collect()
        })
        .transpose()
}

/// One token as the settings list it: never the token itself.
pub struct AppMcpToken {
    pub id: String,
    pub name: String,
    /// `None` is every scope.
    pub scopes: Option<Vec<String>>,
    pub created_at: i64,
}

pub struct AppMcpRegistry {
    /// The policy's scopes; `None` is every scope.
    pub scopes: Option<Vec<String>>,
    pub tokens: Vec<AppMcpToken>,
}

/// Every scope the app serves, in the order a list shows them.
#[flutter_rust_bridge::frb(sync)]
pub fn app_mcp_scopes() -> Vec<String> {
    Scope::APP.iter().map(|s| s.as_str().to_owned()).collect()
}

/// The registry in [text], or why it cannot be read.
#[flutter_rust_bridge::frb(sync)]
pub fn app_mcp_registry(text: String) -> Result<AppMcpRegistry, String> {
    let registry = Registry::parse(&text)?;
    Ok(AppMcpRegistry {
        scopes: scope_names(&registry.policy.scopes),
        tokens: registry
            .tokens
            .iter()
            .map(|t| AppMcpToken {
                id: t.id.clone(),
                name: t.name.clone(),
                scopes: scope_names(&t.scopes),
                created_at: t.created_at,
            })
            .collect(),
    })
}

pub struct AppMcpMinted {
    /// The registry to write, with the new token's digest in it.
    pub registry: String,
    /// The token, shown once and never stored.
    pub token: String,
}

/// [text] with a new token named [name] holding [scopes] (`None`: every
/// scope).
#[flutter_rust_bridge::frb(sync)]
pub fn app_mcp_mint(
    text: String,
    name: String,
    scopes: Option<Vec<String>>,
    now_millis: i64,
) -> Result<AppMcpMinted, String> {
    let mut registry = Registry::parse(&text)?;
    let name = name.trim();
    if name.is_empty() {
        return Err("a token needs a name".into());
    }
    let token = sbm_mcp::token::mint()?;
    registry.tokens.push(TokenEntry {
        id: sbm_mcp::token::hash(&token),
        name: name.to_owned(),
        scopes: parse_scopes(scopes)?,
        commands: CommandPolicy::default(),
        created_at: now_millis,
    });
    registry.check()?;
    Ok(AppMcpMinted { registry: registry.text(), token })
}

/// [text] without the token [id].
#[flutter_rust_bridge::frb(sync)]
pub fn app_mcp_revoke(text: String, id: String) -> Result<String, String> {
    let mut registry = Registry::parse(&text)?;
    registry.tokens.retain(|t| t.id != id);
    Ok(registry.text())
}

/// What [`app_mcp_authorized`] found.
#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum AppMcpAuth {
    Authorized,
    Unauthorized,
    /// The registry cannot be read: no token can be checked, and none is at
    /// fault.
    Unreadable,
}

/// Whether [authorization] carries a token [text] lists: asked before a body
/// is read, so a caller without one costs nothing more.
#[flutter_rust_bridge::frb(sync)]
pub fn app_mcp_authorized(text: String, authorization: Option<String>) -> AppMcpAuth {
    match Registry::parse(&text) {
        Err(_) => AppMcpAuth::Unreadable,
        Ok(r) if r.token(authorization.as_deref()).is_some() => AppMcpAuth::Authorized,
        Ok(_) => AppMcpAuth::Unauthorized,
    }
}

/// One server the app reaches, as a call names it.
pub struct AppMcpHost {
    /// The app's own id; what a call names is its digest.
    pub id: String,
    pub name: String,
    pub online: bool,
    /// `ssh`, `monitor`, `local`.
    pub transports: Vec<String>,
    /// What it runs, when the app already knows.
    pub system: Option<SystemType>,
    /// Whether the app keeps its status script there; without one, a script
    /// function is run from the script itself, read on stdin.
    pub script: bool,
}

pub struct AppMcpRequest {
    /// The registry file as it is now.
    pub registry: String,
    pub authorization: Option<String>,
    pub protocol_version: Option<String>,
    pub accept: Vec<String>,
    pub content_type: Option<String>,
    pub body: Vec<u8>,
    pub hosts: Vec<AppMcpHost>,
    /// `app_setting_set`'s input schema.
    pub settings_schema: String,
}

/// What reached a server: a tool, by which token (its digest's first
/// characters) and about which host (its id on the wire).
pub struct AppMcpCall {
    pub tool: String,
    pub token: String,
    pub host: Option<String>,
}

pub struct AppMcpResponse {
    pub status: u16,
    /// The JSON body; `None` for an empty one.
    pub body: Option<String>,
    pub call: Option<AppMcpCall>,
}

/// What `run` is asked to do on one server.
pub enum AppMcpRun {
    /// [script] handed to the server's shell, or to [entry] on its stdin after
    /// [stdin] — `CommandExec.run`'s own shape.
    Command {
        host: String,
        script: String,
        entry: Option<String>,
        stdin: Option<String>,
        /// At least this many bytes of output are kept.
        room: u64,
    },
    /// One function of the status script the app keeps on the server.
    Script { host: String, func: ShellFuncKind, room: u64 },
}

/// Why `run` did not reach the server.
#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum AppMcpFailure {
    /// The connection needs the person first: a key's passphrase, a host key
    /// or a Monitor's certificate to confirm.
    NeedsUser,
    /// The server was edited or reconnected while the call ran.
    HostChanged,
    /// No way to run commands there now.
    Unavailable,
    /// It was run and did not come back.
    Failed,
}

impl AppMcpFailure {
    fn message(self) -> &'static str {
        match self {
            Self::NeedsUser => {
                "this server needs the person at ServerBox first (a key passphrase, a host key or a certificate to confirm); connect to it there, then call again"
            }
            Self::HostChanged => "the server changed in ServerBox while the call ran; call again",
            Self::Unavailable => "commands cannot be run on this server now",
            Self::Failed => "the command could not be run",
        }
    }
}

pub struct AppMcpRan {
    pub stdout: String,
    pub stderr: String,
    pub exit_code: Option<i32>,
    pub truncated: bool,
    pub timed_out: bool,
    pub failure: Option<AppMcpFailure>,
}

/// Answers one request.
pub async fn app_mcp_serve(
    request: AppMcpRequest,
    run: impl Fn(AppMcpRun) -> DartFnFuture<AppMcpRan> + Send + Sync + 'static,
    settings: impl Fn(String, String) -> DartFnFuture<Option<String>> + Send + Sync + 'static,
) -> AppMcpResponse {
    let refuse = |status: u16, error: &str| AppMcpResponse {
        status,
        body: Some(json!({ "error": error }).to_string()),
        call: None,
    };
    let registry = match Registry::parse(&request.registry) {
        Ok(registry) => registry,
        Err(_) => return refuse(503, "registry_unreadable"),
    };
    let Some(token) = registry.token(request.authorization.as_deref()) else {
        return refuse(401, "unauthorized");
    };
    let accept: Vec<&str> = request.accept.iter().map(String::as_str).collect();
    if let Err(refused) =
        sbm_mcp::http::check_post(request.protocol_version.as_deref(), &accept, request.content_type.as_deref())
    {
        return refuse(refused.status, refused.error);
    }
    if request.body.len() > APP_MCP_MAX_BODY {
        return refuse(413, "too_large");
    }
    let Ok(message) = serde_json::from_slice::<Value>(&request.body) else {
        return refuse(400, "bad_request");
    };

    let host = AppHost {
        scopes: registry.scopes(token),
        policy: &registry.policy.commands,
        token: &token.commands,
        hosts: request
            .hosts
            .iter()
            .map(|h| (host_key(&h.id), h))
            .collect(),
        settings_schema: serde_json::from_str(&request.settings_schema).unwrap_or_else(|_| json!({})),
        run: &run,
        settings: &settings,
    };
    // Logged, so only what this server itself names: a tool of its catalog
    // and a host of its list, never the caller's text.
    let call = (message.get("method").and_then(Value::as_str) == Some("tools/call")).then(|| {
        let tool = message.pointer("/params/name").and_then(Value::as_str);
        let host_key = message.pointer("/params/arguments/host").and_then(Value::as_str);
        AppMcpCall {
            tool: tool
                .and_then(|name| host.tools().into_iter().find(|t| t.name == name))
                .map_or_else(|| "rejected".to_owned(), |t| t.name.to_string()),
            token: token.id[..12].to_owned(),
            host: host_key.and_then(|k| host.hosts.get_key_value(k)).map(|(k, _)| k.clone()),
        }
    });
    match sbm_mcp::serve(&host, &message).await {
        Answer::Json(value) => AppMcpResponse { status: 200, body: Some(value.to_string()), call },
        Answer::Accepted => AppMcpResponse { status: 202, body: None, call: None },
    }
}

/// What a call names a server by: not the app's own id, which an older
/// server has as `user@host:port`.
fn host_key(id: &str) -> String {
    blake3::hash(id.as_bytes()).to_hex()[..16].to_owned()
}

type RunFn = dyn Fn(AppMcpRun) -> DartFnFuture<AppMcpRan> + Send + Sync;
type SettingsFn = dyn Fn(String, String) -> DartFnFuture<Option<String>> + Send + Sync;

#[flutter_rust_bridge::frb(ignore)]
struct AppHost<'a> {
    scopes: Vec<Scope>,
    policy: &'a CommandPolicy,
    token: &'a CommandPolicy,
    hosts: HashMap<String, &'a AppMcpHost>,
    settings_schema: Value,
    run: &'a RunFn,
    settings: &'a SettingsFn,
}

fn app_tool(name: &'static str, description: &'static str, schema: Value) -> Tool {
    sbm_mcp::tool(name, description, schema)
}

impl AppHost<'_> {
    fn tools_of(&self, scope: Scope) -> Vec<Tool> {
        let mut tools = Vec::new();
        match scope {
            Scope::Read => {
                tools.push(app_tool(
                    "list",
                    "The servers ServerBox reaches, with the id every other tool names one by.",
                    json!({ "type": "object", "properties": {}, "additionalProperties": false }),
                ));
                tools.push(catalog::with_host(app_tool(
                    "machine_capabilities",
                    "Platform of one server and how ServerBox reaches it.",
                    json!({ "type": "object", "properties": {}, "additionalProperties": false }),
                )));
                tools.push(app_tool(
                    "app_settings",
                    "ServerBox's own preferences and their current values.",
                    json!({ "type": "object", "properties": {}, "additionalProperties": false }),
                ));
            }
            Scope::Settings => tools.push(app_tool(
                "app_setting_set",
                "Changes one ServerBox preference; `app_settings` lists them.",
                self.settings_schema.clone(),
            )),
            _ => {}
        }
        tools.extend(catalog::shell(scope).into_iter().map(catalog::with_host));
        tools
    }

    async fn on_host(&self, name: &str, mut arguments: Value) -> CallToolResult {
        let key = arguments.as_object_mut().and_then(|a| a.remove("host"));
        let Some(host) = key.as_ref().and_then(Value::as_str).and_then(|k| self.hosts.get(k)) else {
            return tool_error("unknown host: name one by its id from `list`");
        };
        let mut machine = AppMachine {
            host,
            system: SystemType::Linux,
            run: self.run,
            failure: Mutex::new(None),
            started: AtomicBool::new(false),
            acted: AtomicBool::new(false),
        };
        if name == "run_command" {
            // A command line needs no platform: the policy is asked first, and
            // a refused command costs the server nothing.
            let layers = [("global MCP policy", self.policy), ("token command policy", self.token)];
            let result = sbm_mcp::machine::run_command(&machine, &arguments, &layers, APP_MCP_MAX_BODY).await;
            return match machine.failure() {
                Some(failure) => tool_error(failure.message()),
                None => result,
            };
        }
        machine.system = match host.system {
            Some(system) => system,
            None => match machine.detect().await {
                Some(system) => system,
                None => {
                    return tool_error(match machine.failure() {
                        Some(failure) => failure.message(),
                        None => "what this server runs could not be told",
                    });
                }
            },
        };
        let result = match name {
            "machine_capabilities" => structured(json!({
                "platform": match machine.system {
                    SystemType::Linux => "linux",
                    SystemType::Bsd => "bsd",
                    SystemType::Windows => "windows",
                },
                "transports": host.transports,
            })),
            _ => match sbm_mcp::machine::call(&machine, name, &arguments).await {
                Some(result) => result,
                None => tool_error(format!("unknown tool: {name}")),
            },
        };
        // A command that never reached the server is the answer, whatever a
        // tool made of the silence: a server switched off is not one without
        // Docker. Once a change has run, though, the answer is the tool's:
        // what came after it (a refreshed listing) says it was not read.
        match machine.failure() {
            Some(failure) if !machine.acted.load(Ordering::Relaxed) => tool_error(failure.message()),
            _ => result,
        }
    }
}

#[async_trait]
impl Host for AppHost<'_> {
    fn server_info(&self) -> (&'static str, &'static str) {
        ("serverbox", env!("CARGO_PKG_VERSION"))
    }

    fn tools(&self) -> Vec<Tool> {
        self.scopes.iter().flat_map(|scope| self.tools_of(*scope)).collect()
    }

    async fn call(&self, name: &str, arguments: Value) -> CallToolResult {
        match name {
            "list" => {
                let mut hosts: Vec<_> = self
                    .hosts
                    .iter()
                    .map(|(key, h)| json!({ "id": key, "name": h.name, "online": h.online, "transports": h.transports }))
                    .collect();
                hosts.sort_by(|a, b| a["name"].as_str().cmp(&b["name"].as_str()));
                structured(json!({ "hosts": hosts }))
            }
            "app_settings" | "app_setting_set" => match (self.settings)(name.to_owned(), arguments.to_string()).await {
                Some(answer) => structured(serde_json::from_str(&answer).unwrap_or(Value::Null)),
                None => tool_error("invalid preference or value: see the tool's input schema"),
            },
            _ => self.on_host(name, arguments).await,
        }
    }
}

/// One server, as `run` reaches it.
#[flutter_rust_bridge::frb(ignore)]
struct AppMachine<'a> {
    host: &'a AppMcpHost,
    system: SystemType,
    run: &'a RunFn,
    /// The first time `run` did not reach the server.
    failure: Mutex<Option<AppMcpFailure>>,
    /// A change is about to run ([`Audit::Change`] at [`Stage::Started`]).
    started: AtomicBool,
    /// A command ran once the change started: the change itself.
    acted: AtomicBool,
}

impl AppMachine<'_> {
    fn failure(&self) -> Option<AppMcpFailure> {
        *self.failure.lock().unwrap_or_else(|e| e.into_inner())
    }

    /// What the server runs: `uname`, then Windows' `ver`.
    async fn detect(&self) -> Option<SystemType> {
        let out = self.run(Run::Line(sbm_parser::system::UNAME_PROBE), 0).await.ok()?;
        if let Some(system) = sbm_parser::system::from_uname(&out.stdout) {
            return Some(system);
        }
        let out = self.run(Run::Line(sbm_parser::system::VER_PROBE), 0).await.ok()?;
        sbm_parser::system::from_ver(&out.stdout)
    }
}

impl From<sbm_parser::script::ShellFunc> for ShellFuncKind {
    fn from(func: sbm_parser::script::ShellFunc) -> Self {
        use sbm_parser::script::ShellFunc as F;
        match func {
            F::Status => Self::Status,
            F::StatusExt => Self::StatusExt,
            F::Process => Self::Process,
            F::Shutdown => Self::Shutdown,
            F::Reboot => Self::Reboot,
            F::Suspend => Self::Suspend,
        }
    }
}

#[async_trait]
impl Machine for AppMachine<'_> {
    fn system(&self) -> SystemType {
        self.system
    }

    async fn run(&self, run: Run<'_>, room: usize) -> Result<Ran, String> {
        let host = self.host.id.clone();
        let room = room as u64;
        let command = |script: &str, entry: Option<String>, stdin: Option<String>| AppMcpRun::Command {
            host: host.clone(),
            script: script.to_owned(),
            entry,
            stdin,
            room,
        };
        let asked = match run {
            Run::Line(text) => command(text, None, None),
            Run::Sh(text) => command(text, Some("sh".into()), None),
            Run::Root { text, password: None } => command(text, Some(SudoEntry::SudoNoPassword.wrap("sh")), None),
            Run::Root { text, password: Some(password) } => {
                command(text, Some(SudoEntry::SudoPassword.wrap("sh")), Some(format!("{password}\n")))
            }
            Run::Script(func) if self.host.script => AppMcpRun::Script { host: host.clone(), func: func.into(), room },
            Run::Script(_) if self.system == SystemType::Windows => {
                return Err("no status script is kept on this device".to_owned());
            }
            // `sh -s`: the script read on stdin, its function named as on a
            // copy kept there.
            Run::Script(func) => command(
                &sbm_parser::script::build_script(self.system, &Default::default()),
                Some(format!("sh -s -- -{}", func.flag())),
                None,
            ),
        };
        let ran = (self.run)(asked).await;
        if let Some(failure) = ran.failure {
            self.failure.lock().unwrap_or_else(|e| e.into_inner()).get_or_insert(failure);
            return Err(failure.message().to_owned());
        }
        if self.started.load(Ordering::Relaxed) {
            self.acted.store(true, Ordering::Relaxed);
        }
        Ok(Ran {
            stdout: ran.stdout,
            stderr: ran.stderr,
            exit_code: ran.exit_code,
            truncated: ran.truncated,
            timed_out: ran.timed_out,
        })
    }

    async fn record(&self, audit: Audit<'_>) {
        if let Audit::Change { stage: Stage::Started, .. } = audit {
            self.started.store(true, Ordering::Relaxed);
        }
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    fn ran(stdout: &str) -> AppMcpRan {
        AppMcpRan {
            stdout: stdout.into(),
            stderr: String::new(),
            exit_code: Some(0),
            truncated: false,
            timed_out: false,
            failure: None,
        }
    }

    fn request(registry: &str, token: &str, body: Value) -> AppMcpRequest {
        AppMcpRequest {
            registry: registry.into(),
            authorization: Some(format!("Bearer {token}")),
            protocol_version: None,
            accept: vec!["application/json, text/event-stream".into()],
            content_type: Some("application/json".into()),
            body: body.to_string().into_bytes(),
            hosts: vec![AppMcpHost {
                id: "spi-1".into(),
                name: "pve".into(),
                online: true,
                transports: vec!["ssh".into()],
                system: None,
                script: true,
            }],
            settings_schema: "{}".into(),
        }
    }

    fn no_settings(_: String, _: String) -> DartFnFuture<Option<String>> {
        Box::pin(async { None })
    }

    async fn call(registry: &str, token: &str, body: Value, run: fn(AppMcpRun) -> AppMcpRan) -> Value {
        let response =
            app_mcp_serve(request(registry, token, body), move |r| Box::pin(async move { run(r) }), no_settings).await;
        assert_eq!(response.status, 200);
        serde_json::from_str(&response.body.unwrap()).unwrap()
    }

    fn rpc(method: &str, params: Value) -> Value {
        json!({ "jsonrpc": "2.0", "id": 1, "method": method, "params": params })
    }

    #[test]
    fn a_token_is_minted_listed_and_revoked() {
        let minted = app_mcp_mint(String::new(), " ci ".into(), Some(vec!["read".into()]), 7).unwrap();
        assert!(minted.token.starts_with(sbm_mcp::token::PREFIX));
        assert!(!minted.registry.contains(&minted.token));
        let listed = app_mcp_registry(minted.registry.clone()).unwrap();
        assert_eq!(listed.tokens[0].name, "ci");
        assert_eq!(listed.tokens[0].scopes, Some(vec!["read".into()]));
        let auth = |text: &str, value: &str| app_mcp_authorized(text.into(), Some(value.into()));
        assert_eq!(auth(&minted.registry, &format!("Bearer {}", minted.token)), AppMcpAuth::Authorized);
        assert_eq!(auth(&minted.registry, "Bearer sbt_other"), AppMcpAuth::Unauthorized);
        assert_eq!(auth("{", "Bearer sbt_other"), AppMcpAuth::Unreadable);
        let revoked = app_mcp_revoke(minted.registry, listed.tokens[0].id.clone()).unwrap();
        assert!(app_mcp_registry(revoked).unwrap().tokens.is_empty());
        assert!(app_mcp_mint(String::new(), "x".into(), Some(vec!["power".into()]), 0).is_err());
        assert!(app_mcp_registry("{\"tokens\": {}}".into()).is_err());
    }

    #[tokio::test]
    async fn a_token_lists_only_what_its_scopes_and_the_policy_allow() {
        let minted = app_mcp_mint(String::new(), "ci".into(), Some(vec!["read".into(), "exec".into()]), 0).unwrap();
        let mut registry: Value = serde_json::from_str(&minted.registry).unwrap();
        registry["policy"]["scopes"] = json!(["read", "service"]);
        let listed = call(&registry.to_string(), &minted.token, rpc("tools/list", json!({})), |_| ran("")).await;
        let names: Vec<&str> = listed["result"]["tools"].as_array().unwrap().iter().map(|t| t["name"].as_str().unwrap()).collect();
        assert!(names.contains(&"list") && names.contains(&"services"));
        assert!(!names.contains(&"run_command") && !names.contains(&"service_action"));
    }

    #[tokio::test]
    async fn a_call_names_its_server_by_digest_and_the_system_is_probed_when_unknown() {
        let minted = app_mcp_mint(String::new(), "ci".into(), None, 0).unwrap();
        let listed = call(&minted.registry, &minted.token, rpc("tools/call", json!({ "name": "list" })), |_| ran("")).await;
        let key = listed["result"]["structuredContent"]["hosts"][0]["id"].as_str().unwrap().to_owned();
        assert_ne!(key, "spi-1");

        let params = json!({ "name": "machine_capabilities", "arguments": { "host": key } });
        let caps = call(&minted.registry, &minted.token, rpc("tools/call", params), |r| match r {
            AppMcpRun::Command { script, .. } if script == sbm_parser::system::UNAME_PROBE => ran(""),
            AppMcpRun::Command { .. } => ran("Microsoft Windows [Version 10.0.26100]"),
            AppMcpRun::Script { .. } => ran(""),
        })
        .await;
        assert_eq!(caps["result"]["structuredContent"]["platform"], "windows");

        let unknown = json!({ "name": "tmux", "arguments": { "host": "nope" } });
        let refused = call(&minted.registry, &minted.token, rpc("tools/call", unknown), |_| ran("")).await;
        assert_eq!(refused["result"]["isError"], true);
    }

    #[tokio::test]
    async fn a_command_that_never_reached_the_server_is_the_answer() {
        let minted = app_mcp_mint(String::new(), "ci".into(), None, 0).unwrap();
        for failure in [
            AppMcpFailure::NeedsUser,
            AppMcpFailure::HostChanged,
            AppMcpFailure::Unavailable,
            AppMcpFailure::Failed,
        ] {
            for tool in ["services", "containers", "tmux"] {
                let mut req = request(&minted.registry, &minted.token, json!({}));
                req.hosts[0].system = Some(SystemType::Linux);
                let params = json!({ "name": tool, "arguments": { "host": host_key("spi-1") } });
                req.body = rpc("tools/call", params).to_string().into_bytes();
                let response = app_mcp_serve(
                    req,
                    move |_| Box::pin(async move { AppMcpRan { failure: Some(failure), ..ran("") } }),
                    no_settings,
                )
                .await;
                let body: Value = serde_json::from_str(&response.body.unwrap()).unwrap();
                assert_eq!(body["result"]["isError"], true, "{tool} {failure:?}");
                assert_eq!(body["result"]["content"][0]["text"], failure.message(), "{tool} {failure:?}");
                assert_eq!(response.call.unwrap().tool, tool);
            }
        }
    }

    #[tokio::test]
    async fn the_transport_is_refused_in_its_own_words() {
        let minted = app_mcp_mint(String::new(), "ci".into(), None, 0).unwrap();
        let status = |req: AppMcpRequest| async {
            app_mcp_serve(req, |_| Box::pin(async { ran("") }), no_settings).await.status
        };
        assert_eq!(status(request(&minted.registry, "sbt_wrong", json!({}))).await, 401);
        let mut req = request(&minted.registry, &minted.token, json!({}));
        req.content_type = Some("text/plain".into());
        assert_eq!(status(req).await, 415);
        let mut req = request(&minted.registry, &minted.token, json!({}));
        req.body = b"{".to_vec();
        assert_eq!(status(req).await, 400);
        let note = json!({ "jsonrpc": "2.0", "method": "notifications/initialized" });
        assert_eq!(status(request(&minted.registry, &minted.token, note)).await, 202);
    }

    #[tokio::test]
    async fn a_refused_command_never_reaches_the_server() {
        let minted = app_mcp_mint(String::new(), "ci".into(), None, 0).unwrap();
        let mut registry: Value = serde_json::from_str(&minted.registry).unwrap();
        registry["policy"]["commands"] = json!({ "mode": "allowlist", "allow": ["uptime"] });
        let params = json!({ "name": "run_command", "arguments": { "host": host_key("spi-1"), "command": "rm -rf /" } });
        let refused = call(&registry.to_string(), &minted.token, rpc("tools/call", params), |_| {
            panic!("nothing is run for a refused command, not even a probe")
        })
        .await;
        assert_eq!(refused["result"]["isError"], true);
    }

    #[tokio::test]
    async fn a_change_that_ran_is_answered_though_what_came_after_did_not_reach() {
        let minted = app_mcp_mint(String::new(), "ci".into(), None, 0).unwrap();
        let mut req = request(&minted.registry, &minted.token, json!({}));
        req.hosts[0].system = Some(SystemType::Linux);
        let params = json!({ "name": "container_action", "arguments": { "host": host_key("spi-1"), "action": "stop", "id": "web" } });
        req.body = rpc("tools/call", params).to_string().into_bytes();
        let response = app_mcp_serve(
            req,
            |r| {
                Box::pin(async move {
                    match r {
                        AppMcpRun::Command { script, .. } if script.contains(" stop ") => ran(""),
                        AppMcpRun::Command { script, .. } if script.contains("docker version") && !script.contains("SrvBox") => {
                            ran("{}")
                        }
                        _ => AppMcpRan { failure: Some(AppMcpFailure::HostChanged), ..ran("") },
                    }
                })
            },
            no_settings,
        )
        .await;
        let body: Value = serde_json::from_str(&response.body.unwrap()).unwrap();
        assert_eq!(body["result"]["isError"], false, "{body}");
        assert_eq!(body["result"]["structuredContent"]["exit_code"], 0);
    }

    #[tokio::test]
    async fn a_call_is_logged_by_what_this_server_names() {
        let minted = app_mcp_mint(String::new(), "ci".into(), None, 0).unwrap();
        let params = json!({ "name": "nope\nforged", "arguments": { "host": "x\ny" } });
        let response =
            app_mcp_serve(request(&minted.registry, &minted.token, rpc("tools/call", params)), |_| Box::pin(async { ran("") }), no_settings)
                .await;
        let call = response.call.unwrap();
        assert_eq!(call.tool, "rejected");
        assert_eq!(call.host, None);
    }

    #[tokio::test]
    async fn a_device_without_a_kept_script_reads_it_on_stdin() {
        let minted = app_mcp_mint(String::new(), "ci".into(), None, 0).unwrap();
        let mut req = request(&minted.registry, &minted.token, json!({}));
        req.hosts[0].system = Some(SystemType::Linux);
        req.hosts[0].script = false;
        let params = json!({ "name": "processes", "arguments": { "host": host_key("spi-1") } });
        req.body = rpc("tools/call", params).to_string().into_bytes();
        app_mcp_serve(
            req,
            |r| {
                Box::pin(async move {
                    match r {
                        AppMcpRun::Command { entry: Some(entry), .. } => assert_eq!(entry, "sh -s -- -p"),
                        _ => panic!("no kept script to call"),
                    }
                    ran("")
                })
            },
            no_settings,
        )
        .await;
    }
}
