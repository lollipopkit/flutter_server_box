//! `POST /api/v1/mcp` (#1681): an MCP client's way in, behind an API token.
//!
//! Streamable HTTP in its stateless JSON shape: every POST carries a whole
//! JSON-RPC message and is answered with one `application/json` body (a
//! notification by `202 Accepted`), no session is issued and none is
//! required; `GET` and `DELETE` answer `405 Method Not Allowed` per spec.
//!
//! Permissions default open — every scope enabled and `allow_all` commands —
//! and narrow by intersecting three layers: `config.toml` (`[mcp]`), the
//! UI-managed global policy (`mcp_policy`), and each token's own scopes and
//! command rules (`api_tokens`). `tools/list` shows only what that
//! intersection allows, and `tools/call` runs nothing outside it.

use std::net::SocketAddr;
use std::sync::Arc;
use std::sync::atomic::{AtomicBool, Ordering};

use async_trait::async_trait;
use base64::Engine;
use ntex::http::StatusCode;
use ntex::http::header::{ACCEPT, ALLOW, CONTENT_TYPE, HeaderValue};
use ntex::web::{self, HttpRequest, HttpResponse};
use serde_json::{Value, json};

use sbm_mcp::{Answer, CallToolResult, Host, Tool, structured, tool_error};

use super::containers::{self, ContainerPart};
use super::cron::{self, CronEdit};
use super::firewall;
use super::fs;
use super::json;
use super::process;
use super::server::{self, AppState};
use super::service::{self, ServicePart};
use super::stacks;
use super::storage;
use super::system_users::{self, UserPart};
use super::tmux;
use super::virt;
use super::ws::audit::{Action, Event, Kind, Outcome};
use super::ws::origin_allowed;
use crate::api::authz::{self, Caller, TokenCaller};
use crate::api::respond::error;
use crate::db::api_tokens::{self, CommandPolicy, Scope};

/// Large enough to carry a file written through `fs_write` (base64 or text),
/// bounded up front before a byte is read.
const MAX_BODY: usize = 4 * 1024 * 1024;

// TODO: a per-IP limiter before the token is looked up, and a per-token one
// after, once `ntex-ratelimiter` 0.4 keys on something other than an address.

struct TokenHost {
    state: Arc<AppState>,
    caller: Caller,
    token_name: String,
    peer: Option<SocketAddr>,
    remote_ip: Option<String>,
    scopes: Vec<Scope>,
    config_commands: CommandPolicy,
    global_commands: CommandPolicy,
    token_commands: CommandPolicy,
    audited_before_run: AtomicBool,
}

fn no_args(name: &'static str, description: &'static str) -> Tool {
    sbm_mcp::tool(
        name,
        description,
        json!({ "type": "object", "properties": {}, "additionalProperties": false }),
    )
}

fn tool(name: &'static str, description: &'static str, schema: Value) -> Tool {
    sbm_mcp::tool(name, description, schema)
}

impl TokenHost {
    fn read_tools() -> Vec<Tool> {
        vec![
            no_args(
                "machine_status",
                "Current summary readings of this machine: CPU, memory, disk, network and temperature.",
            ),
            no_args(
                "machine_metrics",
                "Detailed current metrics: per-core CPU, memory, disks, network interfaces and disk I/O.",
            ),
            no_args(
                "machine_capabilities",
                "Platform, Monitor version, collected metrics, retention policy and active features.",
            ),
            tool(
                "processes",
                "Process table of this machine: PID, start_id, parent, user, state, CPU, memory and command line.",
                json!({
                    "type": "object",
                    "properties": {
                        "sort": { "type": "string", "enum": ["cpu", "mem", "rss", "read", "write", "pid", "user", "name"] },
                        "ascending": { "type": "boolean" }
                    },
                    "additionalProperties": false
                }),
            ),
            tool(
                "services",
                "Service units of the machine's service manager, or one unit's logs, status or definition.",
                json!({
                    "type": "object",
                    "properties": {
                        "part": { "type": "string", "enum": ["list", "logs", "definition", "status"] },
                        "key": { "type": "string", "description": "Unit key from `list` (required when `part` is not `list`)." }
                    },
                    "additionalProperties": false
                }),
            ),
            tool(
                "containers",
                "Docker or Podman containers, images, disk usage, or bounded tail logs of one container.",
                json!({
                    "type": "object",
                    "properties": {
                        "part": { "type": "string", "enum": ["containers", "images", "usage", "logs"] },
                        "id": { "type": "string", "description": "Container ID or name when `part` is `logs`." }
                    },
                    "additionalProperties": false
                }),
            ),
            no_args("cron", "Crontab jobs and preserved lines of the account the Monitor runs as."),
            no_args("tmux", "Active tmux sessions on this machine."),
            tool(
                "firewall",
                "Firewall state and rules (ufw or firewalld) and how this Monitor and SSH reach the machine.",
                json!({
                    "type": "object",
                    "properties": {
                        "kind": { "type": "string", "enum": ["ufw", "firewalld"] }
                    },
                    "additionalProperties": false
                }),
            ),
            no_args("storage", "Block devices, filesystems, mounts, RAID arrays, ZFS pools and disk health."),
            no_args("virt", "Virtualization host (Proxmox VE or libvirt) and its virtual machines and containers."),
            no_args("stacks", "Catalog and deployed web app stacks managed by this Monitor."),
            tool(
                "system_users",
                "System users and groups on Linux, or detailed records of one account.",
                json!({
                    "type": "object",
                    "properties": {
                        "part": { "type": "string", "enum": ["list", "detail"] },
                        "name": { "type": "string", "description": "Account name when `part` is `detail`." }
                    },
                    "additionalProperties": false
                }),
            ),
        ]
    }

    fn fs_read_tools() -> Vec<Tool> {
        vec![
            no_args("fs_roots", "Home directory and filesystem roots accessible through the Monitor."),
            tool(
                "fs_list",
                "Lists entries in a directory.",
                json!({
                    "type": "object",
                    "properties": { "path": { "type": "string" } },
                    "required": ["path"],
                    "additionalProperties": false
                }),
            ),
            tool(
                "fs_stat",
                "Metadata and optimistic-concurrency version token of one file, directory or symlink.",
                json!({
                    "type": "object",
                    "properties": { "path": { "type": "string" } },
                    "required": ["path"],
                    "additionalProperties": false
                }),
            ),
            tool(
                "fs_read",
                "Reads a file (UTF-8 text, or base64 when binary), returning its `version` token.",
                json!({
                    "type": "object",
                    "properties": {
                        "path": { "type": "string" },
                        "offset": { "type": "integer", "minimum": 0 },
                        "max_bytes": { "type": "integer", "minimum": 1, "maximum": 4194304 }
                    },
                    "required": ["path"],
                    "additionalProperties": false
                }),
            ),
        ]
    }

    fn fs_write_tools() -> Vec<Tool> {
        vec![
            tool(
                "fs_write",
                "Writes a file atomically, preserving existing permissions. Optional `if_version` guards against concurrent edits.",
                json!({
                    "type": "object",
                    "properties": {
                        "path": { "type": "string" },
                        "content": { "type": "string" },
                        "encoding": { "type": "string", "enum": ["utf8", "base64"], "description": "Defaults to utf8." },
                        "if_version": { "type": "string", "description": "Version token from `fs_read` or `fs_stat`." }
                    },
                    "required": ["path", "content"],
                    "additionalProperties": false
                }),
            ),
            tool(
                "fs_mkdir",
                "Creates a directory and any missing parents.",
                json!({
                    "type": "object",
                    "properties": { "path": { "type": "string" } },
                    "required": ["path"],
                    "additionalProperties": false
                }),
            ),
            tool(
                "fs_rename",
                "Moves or renames a file, symlink or directory.",
                json!({
                    "type": "object",
                    "properties": {
                        "from": { "type": "string" },
                        "to": { "type": "string" }
                    },
                    "required": ["from", "to"],
                    "additionalProperties": false
                }),
            ),
            tool(
                "fs_chmod",
                "Sets POSIX permission bits on a path (for example 493 for 0o755, or 384 for 0o600).",
                json!({
                    "type": "object",
                    "properties": {
                        "path": { "type": "string" },
                        "mode": { "type": "integer", "minimum": 0, "maximum": 4095 }
                    },
                    "required": ["path", "mode"],
                    "additionalProperties": false
                }),
            ),
            tool(
                "fs_remove",
                "Removes a file, symlink or directory.",
                json!({
                    "type": "object",
                    "properties": {
                        "path": { "type": "string" },
                        "recursive": { "type": "boolean" }
                    },
                    "required": ["path"],
                    "additionalProperties": false
                }),
            ),
        ]
    }

    fn exec_tools() -> Vec<Tool> {
        vec![tool(
            "run_command",
            "Runs a shell command as the Monitor's account within the configured timeout, output cap and command policy.",
            json!({
                "type": "object",
                "properties": {
                    "command": {
                        "type": "string",
                        "description": "Shell command line (pipelines and multi-line scripts supported)."
                    }
                },
                "required": ["command"],
                "additionalProperties": false
            }),
        )]
    }

    fn process_tools() -> Vec<Tool> {
        vec![tool(
            "kill_process",
            "Sends TERM or KILL to one process, verified against its `start_id` from `processes`.",
            json!({
                "type": "object",
                "properties": {
                    "pid": { "type": "integer", "description": "PID from `processes`." },
                    "start_id": { "type": "string", "description": "Matching `start_id` from `processes`." },
                    "signal": { "type": "string", "enum": ["term", "kill"], "description": "Defaults to term." }
                },
                "required": ["pid", "start_id"],
                "additionalProperties": false
            }),
        )]
    }

    fn service_tools() -> Vec<Tool> {
        vec![tool(
            "service_action",
            "Starts, stops, restarts, enables or disables a service unit.",
            json!({
                "type": "object",
                "properties": {
                    "key": { "type": "string", "description": "Unit key from `services`." },
                    "action": { "type": "string", "enum": ["start", "stop", "restart", "enable", "disable"] }
                },
                "required": ["key", "action"],
                "additionalProperties": false
            }),
        )]
    }

    fn container_tools() -> Vec<Tool> {
        vec![tool(
            "container_action",
            "Performs a Docker or Podman action and returns the refreshed listing.",
            json!({
                "type": "object",
                "properties": {
                    "action": {
                        "type": "string",
                        "enum": [
                            "start",
                            "stop",
                            "restart",
                            "remove",
                            "prune_containers",
                            "prune_volumes",
                            "remove_image",
                            "pull_image",
                            "prune_images",
                            "prune_system",
                            "run"
                        ]
                    },
                    "id": { "type": "string", "description": "Container or image ID/name for start, stop, restart, remove, remove_image." },
                    "force": { "type": "boolean", "description": "Force removal of a running container (for `remove`)." },
                    "reference": { "type": "string", "description": "Image reference `repo:tag` (for `pull_image`)." },
                    "all_unused": { "type": "boolean", "description": "Remove all unused images rather than dangling only (for `prune_images`)." },
                    "all_unused_images": { "type": "boolean", "description": "Include unused images in `prune_system`." },
                    "include_volumes": { "type": "boolean", "description": "Include volumes in `prune_system`." },
                    "image": { "type": "string", "description": "Image to start (for `run`)." },
                    "name": { "type": "string", "description": "Container name (for `run`, optional empty string)." },
                    "args": { "type": "string", "description": "Extra CLI flags for `run`, shell-quoted." }
                },
                "required": ["action"],
                "additionalProperties": false
            }),
        )]
    }

    fn cron_tools() -> Vec<Tool> {
        vec![tool(
            "cron_edit",
            "Creates, updates, enables/disables or removes a job in the Monitor account's crontab.",
            json!({
                "type": "object",
                "properties": {
                    "op": { "type": "string", "enum": ["upsert", "remove", "set_enabled"] },
                    "line_index": { "type": "integer", "minimum": 0, "description": "Job line_index from `cron`; omit on `upsert` to append." },
                    "schedule": { "type": "string", "description": "5-field cron expression or `@reboot` / `@daily` (for `upsert`)." },
                    "command": { "type": "string", "description": "Command to schedule (for `upsert`)." },
                    "enabled": { "type": "boolean", "description": "Whether the job is active (for `upsert` and `set_enabled`)." }
                },
                "required": ["op"],
                "additionalProperties": false
            }),
        )]
    }

    fn virt_tools() -> Vec<Tool> {
        vec![tool(
            "virt_power",
            "Starts, shuts down, reboots, force-stops, suspends or resumes a VM or LXC guest.",
            json!({
                "type": "object",
                "properties": {
                    "guest": { "type": "string", "description": "Guest ID from `virt`." },
                    "action": { "type": "string", "enum": ["start", "shutdown", "reboot", "force_stop", "suspend", "resume"] }
                },
                "required": ["guest", "action"],
                "additionalProperties": false
            }),
        )]
    }

    fn stacks_tools() -> Vec<Tool> {
        vec![tool(
            "stack_action",
            "Starts, stops, restarts or updates a deployed web app stack.",
            json!({
                "type": "object",
                "properties": {
                    "id": { "type": "string", "description": "Stack ID from `stacks`." },
                    "action": { "type": "string", "enum": ["start", "stop", "restart", "update"] }
                },
                "required": ["id", "action"],
                "additionalProperties": false
            }),
        )]
    }

    fn power_tools() -> Vec<Tool> {
        vec![tool(
            "power",
            "Shuts down, reboots or suspends this machine.",
            json!({
                "type": "object",
                "properties": {
                    "action": { "type": "string", "enum": ["shutdown", "reboot", "suspend"] }
                },
                "required": ["action"],
                "additionalProperties": false
            }),
        )]
    }
}

#[async_trait]
impl Host for TokenHost {
    fn server_info(&self) -> (&'static str, &'static str) {
        ("serverbox-monitor", env!("CARGO_PKG_VERSION"))
    }

    fn tools(&self) -> Vec<Tool> {
        let mut tools = Vec::new();
        for scope in &self.scopes {
            match scope {
                Scope::Read => tools.extend(Self::read_tools()),
                Scope::FsRead => tools.extend(Self::fs_read_tools()),
                Scope::FsWrite => tools.extend(Self::fs_write_tools()),
                Scope::Exec => tools.extend(Self::exec_tools()),
                Scope::Process => tools.extend(Self::process_tools()),
                Scope::Service => tools.extend(Self::service_tools()),
                Scope::Container => tools.extend(Self::container_tools()),
                Scope::Cron => tools.extend(Self::cron_tools()),
                Scope::Virt => tools.extend(Self::virt_tools()),
                Scope::Stacks => tools.extend(Self::stacks_tools()),
                Scope::Power => tools.extend(Self::power_tools()),
            }
        }
        tools
    }

    async fn call(&self, name: &str, arguments: Value) -> CallToolResult {
        let state = &self.state;
        match name {
            "machine_status" => {
                server::metrics::touch_viewer_heartbeat(state).await;
                let metrics = state.current_metrics.read().await;
                match metrics.as_ref() {
                    Some(m) => structured(serde_json::to_value(server::metrics::status_view(m)).unwrap_or(Value::Null)),
                    None => tool_error("metrics are not available yet"),
                }
            }
            "machine_metrics" => {
                server::metrics::touch_viewer_heartbeat(state).await;
                let metrics = state.current_metrics.read().await;
                match metrics.as_ref() {
                    Some(m) => structured(server::metrics::metrics_json(m).unwrap_or(Value::Null)),
                    None => tool_error("metrics are not available yet"),
                }
            }
            "machine_capabilities" => {
                let secure = state.tls_active || self.peer.is_some_and(|p| p.ip().is_loopback());
                structured(server::capabilities_view(state, Some(&self.caller), secure).await)
            }
            "processes" => {
                let sort = match arguments.get("sort") {
                    None => None,
                    Some(v) => match serde_json::from_value(v.clone()) {
                        Ok(s) => Some(s),
                        Err(e) => return tool_error(format!("invalid sort: {e}")),
                    },
                };
                let ascending = match arguments.get("ascending") {
                    None => None,
                    Some(v) => match v.as_bool() {
                        Some(b) => Some(b),
                        None => return tool_error("ascending must be a boolean"),
                    },
                };
                structured(serde_json::to_value(process::table(state, sort, ascending).await).unwrap_or(Value::Null))
            }
            "services" => {
                let part: ServicePart = match arguments.get("part") {
                    None => ServicePart::default(),
                    Some(v) => match serde_json::from_value(v.clone()) {
                        Ok(p) => p,
                        Err(e) => return tool_error(format!("invalid part: {e}")),
                    },
                };
                let key = arguments.get("key").and_then(Value::as_str);
                structured(serde_json::to_value(service::listing(state, part, key).await).unwrap_or(Value::Null))
            }
            "containers" => {
                let part: ContainerPart = match arguments.get("part") {
                    None => ContainerPart::default(),
                    Some(v) => match serde_json::from_value(v.clone()) {
                        Ok(p) => p,
                        Err(e) => return tool_error(format!("invalid part: {e}")),
                    },
                };
                let id = arguments.get("id").and_then(Value::as_str);
                match containers::listing(state, part, id).await {
                    Ok(resp) => structured(serde_json::to_value(resp).unwrap_or(Value::Null)),
                    Err(issue) => tool_error(format!("invalid container id: {} ({})", issue, issue.code())),
                }
            }
            "cron" => structured(
                serde_json::to_value(cron::read_crontab(&state.remote_access.exec).await).unwrap_or(Value::Null),
            ),
            "tmux" => structured(tmux::sessions(state).await),
            "firewall" => {
                let kind = match arguments.get("kind") {
                    None => None,
                    Some(v) => match serde_json::from_value(v.clone()) {
                        Ok(k) => Some(k),
                        Err(e) => return tool_error(format!("invalid firewall kind: {e}")),
                    },
                };
                structured(serde_json::to_value(firewall::read_view(state, self.peer, kind, None).await).unwrap_or(Value::Null))
            }
            "storage" => match storage::view_body(state).await {
                Ok(body) => structured(body),
                Err(code) => tool_error(format!("storage unavailable: {code}")),
            },
            "virt" => match virt::load_view(state, None).await {
                Ok(body) => structured(body),
                Err(e) => tool_error(format!("virtualization load failed: {e}")),
            },
            "stacks" => match stacks::list_apps(state).await {
                Ok(body) => structured(body),
                Err(e) => tool_error(format!("stacks unavailable: {e}")),
            },
            "system_users" => {
                let part: UserPart = match arguments.get("part") {
                    None => UserPart::default(),
                    Some(v) => match serde_json::from_value(v.clone()) {
                        Ok(p) => p,
                        Err(e) => return tool_error(format!("invalid part: {e}")),
                    },
                };
                let name = arguments.get("name").and_then(Value::as_str);
                structured(system_users::listing(state, part, name).await)
            }
            "fs_roots" => structured(fs::mcp_ops::roots(state, self.remote_ip.clone()).await),
            "fs_list" => {
                let Some(path) = arguments.get("path").and_then(Value::as_str) else {
                    return tool_error("path is required");
                };
                match fs::mcp_ops::list(state, path, self.remote_ip.clone()).await {
                    Ok(v) => structured(v),
                    Err(e) => tool_error(e),
                }
            }
            "fs_stat" => {
                let Some(path) = arguments.get("path").and_then(Value::as_str) else {
                    return tool_error("path is required");
                };
                match fs::mcp_ops::stat(state, path, self.remote_ip.clone()).await {
                    Ok(v) => structured(v),
                    Err(e) => tool_error(e),
                }
            }
            "fs_read" => {
                let Some(path) = arguments.get("path").and_then(Value::as_str) else {
                    return tool_error("path is required");
                };
                let offset = match arguments.get("offset") {
                    None => 0,
                    Some(v) => match v.as_u64() {
                        Some(n) => n,
                        None => return tool_error("offset must be a non-negative integer"),
                    },
                };
                let max_bytes = match arguments.get("max_bytes") {
                    None => None,
                    Some(v) => match v.as_u64().filter(|&n| (1..=4_194_304).contains(&n)) {
                        Some(n) => Some(n as usize),
                        None => return tool_error("max_bytes must be an integer in 1..=4194304"),
                    },
                };
                match fs::mcp_ops::read(state, path, offset, max_bytes, self.remote_ip.clone()).await {
                    Ok(v) => structured(v),
                    Err(e) => tool_error(e),
                }
            }
            "fs_write" => self.fs_write(arguments).await,
            "fs_mkdir" => {
                let Some(path) = arguments.get("path").and_then(Value::as_str) else {
                    return tool_error("path is required");
                };
                match fs::mcp_ops::mkdir(state, path, self.remote_ip.clone()).await {
                    Ok(v) => structured(v),
                    Err(e) => tool_error(e),
                }
            }
            "fs_rename" => {
                let Some(from) = arguments.get("from").and_then(Value::as_str) else {
                    return tool_error("from is required");
                };
                let Some(to) = arguments.get("to").and_then(Value::as_str) else {
                    return tool_error("to is required");
                };
                match fs::mcp_ops::rename(state, from, to, self.remote_ip.clone()).await {
                    Ok(v) => structured(v),
                    Err(e) => tool_error(e),
                }
            }
            "fs_chmod" => {
                let Some(path) = arguments.get("path").and_then(Value::as_str) else {
                    return tool_error("path is required");
                };
                let Some(mode) = arguments
                    .get("mode")
                    .and_then(Value::as_u64)
                    .filter(|&m| m <= 0o7777)
                    .map(|m| m as u32)
                else {
                    return tool_error("mode is required (integer 0..=4095)");
                };
                match fs::mcp_ops::chmod(state, path, mode, self.remote_ip.clone()).await {
                    Ok(v) => structured(v),
                    Err(e) => tool_error(e),
                }
            }
            "fs_remove" => {
                let Some(path) = arguments.get("path").and_then(Value::as_str) else {
                    return tool_error("path is required");
                };
                let recursive = arguments.get("recursive").and_then(Value::as_bool).unwrap_or(false);
                match fs::mcp_ops::remove(state, path, recursive, self.remote_ip.clone()).await {
                    Ok(v) => structured(v),
                    Err(e) => tool_error(e),
                }
            }
            "run_command" => self.run_command(arguments).await,
            "kill_process" => self.kill_process(arguments).await,
            "service_action" => self.service_action(arguments).await,
            "container_action" => self.container_action(arguments).await,
            "cron_edit" => self.cron_edit(arguments).await,
            "virt_power" => self.virt_power(arguments).await,
            "stack_action" => self.stack_action(arguments).await,
            "power" => self.power(arguments).await,
            _ => tool_error(format!("unknown tool: {name}")),
        }
    }
}

impl TokenHost {
    async fn fs_write(&self, arguments: Value) -> CallToolResult {
        let Some(path) = arguments.get("path").and_then(Value::as_str) else {
            return tool_error("path is required");
        };
        let Some(content) = arguments.get("content").and_then(Value::as_str) else {
            return tool_error("content is required");
        };
        let encoding = arguments.get("encoding").and_then(Value::as_str).unwrap_or("utf8");
        let bytes = match encoding {
            "utf8" => content.as_bytes().to_vec(),
            "base64" => match base64::engine::general_purpose::STANDARD.decode(content) {
                Ok(bytes) => bytes,
                Err(e) => return tool_error(format!("invalid base64 content: {e}")),
            },
            other => return tool_error(format!("unsupported encoding `{other}` (expected utf8 or base64)")),
        };
        let if_version = match arguments.get("if_version") {
            None | Some(Value::Null) => None,
            Some(Value::String(s)) => Some(s.as_str()),
            Some(_) => return tool_error("if_version must be a string"),
        };
        match fs::mcp_ops::write(&self.state, path, &bytes, if_version, self.remote_ip.clone()).await {
            Ok(v) => structured(v),
            Err(e) => tool_error(e),
        }
    }

    async fn run_command(&self, arguments: Value) -> CallToolResult {
        let Some(command) = arguments.get("command").and_then(Value::as_str) else {
            return tool_error("command is required");
        };
        if command.trim().is_empty() {
            return tool_error("command must not be empty");
        }
        let max_req = self.state.remote_access.exec.max_request_bytes;
        if command.len() > max_req {
            return tool_error(format!("command exceeds the {max_req} byte limit"));
        }
        for (layer, policy) in [
            ("config.toml [mcp.commands]", &self.config_commands),
            ("global MCP policy", &self.global_commands),
            ("token command policy", &self.token_commands),
        ] {
            if let Err(why) = policy.evaluate(command) {
                return tool_error(format!("refused by {layer}: {why}"));
            }
        }

        // Recorded before it runs, with the first line of the command just as
        // `POST /exec` records it: a command that hangs or reboots the machine
        // still has to appear in `access_log`.
        let summary = super::exec::first_line(command);
        Event::new(Kind::Mcp, Action::Open, Outcome::Ok)
            .subject(format!("api token '{}'", self.token_name))
            .remote_ip(self.remote_ip.clone())
            .detail(format!("tool run_command: {summary}"))
            .record(&self.state.db)
            .await;
        self.audited_before_run.store(true, Ordering::Relaxed);

        match super::exec::run(command, None, None, &self.state.remote_access.exec).await {
            Ok(out) => structured(json!({
                "exit_code": out.exit_code,
                "stdout": out.stdout,
                "stderr": out.stderr,
                "truncated": out.truncated,
                "timed_out": out.timed_out,
            })),
            Err(e) => {
                Event::new(Kind::Mcp, Action::Close, Outcome::Error)
                    .subject(format!("api token '{}'", self.token_name))
                    .remote_ip(self.remote_ip.clone())
                    .detail(format!("tool run_command: {e}"))
                    .record(&self.state.db)
                    .await;
                tool_error(format!("the command could not be run: {e}"))
            }
        }
    }

    async fn kill_process(&self, arguments: Value) -> CallToolResult {
        #[derive(serde::Deserialize)]
        struct Args {
            pid: i64,
            start_id: String,
            #[serde(default = "default_term")]
            signal: sbm_parser::proc::ProcSignal,
        }
        fn default_term() -> sbm_parser::proc::ProcSignal {
            sbm_parser::proc::ProcSignal::Term
        }
        let args: Args = match serde_json::from_value(arguments) {
            Ok(a) => a,
            Err(e) => return tool_error(format!("invalid arguments: {e}")),
        };
        let request = super::process::KillRequest {
            pid: args.pid,
            start_id: Some(args.start_id),
            signal: args.signal,
            password: None,
        };
        match super::process::stop(&self.state, request, self.remote_ip.clone()).await {
            Ok(response) => structured(serde_json::to_value(response).unwrap_or(Value::Null)),
            Err(super::process::StopRefused::Unsafe) => tool_error(
                "this PID cannot be signalled safely: the listing reported no start identity to check it against",
            ),
        }
    }

    async fn service_action(&self, arguments: Value) -> CallToolResult {
        let mut request: super::service::ServiceActRequest = match serde_json::from_value(arguments) {
            Ok(r) => r,
            Err(e) => return tool_error(format!("invalid arguments: {e}")),
        };
        request.password = None;
        match super::service::perform(&self.state, request, self.remote_ip.clone()).await {
            Ok(response) => structured(serde_json::to_value(response).unwrap_or(Value::Null)),
            Err(super::service::ServiceRefused::Unsupported) => {
                tool_error("this machine has no service manager the Monitor talks to")
            }
            Err(super::service::ServiceRefused::NoSuchUnit) => {
                tool_error("no such unit in the current listing")
            }
        }
    }

    async fn container_action(&self, arguments: Value) -> CallToolResult {
        // Accepts both the flat tagged object (`{ "action": "stop", "id": "…" }`)
        // and a nested `{ "action": { "action": "stop", "id": "…" } }` envelope.
        let raw = match arguments.get("action") {
            Some(inner) if inner.is_object() => inner.clone(),
            _ => arguments,
        };
        let action: sbm_parser::container::ContainerAction = match serde_json::from_value(raw) {
            Ok(action) => action,
            Err(e) => return tool_error(format!("invalid action: {e}")),
        };
        match super::containers::apply(&self.state, action, self.remote_ip.clone()).await {
            Ok(response) => structured(response),
            Err(issue) => tool_error(format!("refused: {} ({})", issue, issue.code())),
        }
    }

    async fn cron_edit(&self, arguments: Value) -> CallToolResult {
        let edit: CronEdit = match serde_json::from_value(arguments) {
            Ok(edit) => edit,
            Err(e) => return tool_error(format!("invalid arguments: {e}")),
        };
        match cron::apply_edit(&self.state, edit, self.remote_ip.clone()).await {
            Ok(response) => structured(serde_json::to_value(response).unwrap_or(Value::Null)),
            Err(e) => tool_error(format!("invalid cron edit: {e}")),
        }
    }

    async fn virt_power(&self, arguments: Value) -> CallToolResult {
        let mut request: virt::PowerRequest = match serde_json::from_value(arguments) {
            Ok(r) => r,
            Err(e) => return tool_error(format!("invalid arguments: {e}")),
        };
        request.password = None;
        match virt::power_guest(&self.state, request, self.remote_ip.clone()).await {
            Ok(resp) => match resp.error {
                None => structured(json!({ "ok": true })),
                Some(err) => tool_error(serde_json::to_string(&err).unwrap_or_else(|_| "virt power failed".into())),
            },
            Err(e) => tool_error(format!("virt power failed: {e}")),
        }
    }

    async fn stack_action(&self, arguments: Value) -> CallToolResult {
        #[derive(serde::Deserialize)]
        struct Args {
            id: String,
            action: crate::stacks::StackAction,
        }
        let args: Args = match serde_json::from_value(arguments) {
            Ok(a) => a,
            Err(e) => return tool_error(format!("invalid arguments: {e}")),
        };
        match crate::stacks::act(&self.state, &args.id, args.action).await {
            Ok(job) => structured(serde_json::to_value(job.view(0)).unwrap_or(Value::Null)),
            Err(r) => tool_error(match r.field {
                Some(field) => format!("{} ({field})", r.error),
                None => r.error.to_string(),
            }),
        }
    }

    async fn power(&self, arguments: Value) -> CallToolResult {
        let mut request: super::power::PowerRequest = match serde_json::from_value(arguments) {
            Ok(r) => r,
            Err(e) => return tool_error(format!("invalid arguments: {e}")),
        };
        request.password = None;
        let action_name = request.action.as_str();
        // Recorded before `perform` runs, since shutdown/reboot may stop the
        // process before `serve` returns.
        Event::new(Kind::Mcp, Action::Open, Outcome::Ok)
            .subject(format!("api token '{}'", self.token_name))
            .remote_ip(self.remote_ip.clone())
            .detail(format!("tool power: {action_name}"))
            .record(&self.state.db)
            .await;
        self.audited_before_run.store(true, Ordering::Relaxed);

        match super::power::perform(&self.state, request, self.remote_ip.clone()).await {
            Ok(response) => structured(serde_json::to_value(response).unwrap_or(Value::Null)),
            Err(super::power::PowerRefused::Script) => {
                tool_error("the power script could not be written")
            }
            Err(super::power::PowerRefused::Failed(e)) => tool_error(e),
        }
    }
}

/// Streamable HTTP spec: `GET` (standalone SSE stream) and `DELETE` (session
/// termination) answer `405 Method Not Allowed` when the server is stateless
/// JSON-only.
pub async fn method_not_allowed() -> HttpResponse {
    HttpResponse::MethodNotAllowed()
        .header(ALLOW, HeaderValue::from_static("POST"))
        .json(&json!({ "error": "method_not_allowed" }))
}

pub async fn post(
    req: HttpRequest,
    mut payload: web::types::Payload,
    state: Arc<AppState>,
) -> HttpResponse {
    let caller: TokenCaller = match authz::token_caller(&req, &state).await {
        Ok(caller) => caller,
        Err(refused) => return refused,
    };
    if let Err(why) = caller.caller.check(&state, authz::is_secure(&req, &state)) {
        Event::new(Kind::Mcp, Action::Denied, Outcome::Denied)
            .subject(format!("api token '{}'", caller.token.name))
            .remote_ip(caller.remote_ip.clone())
            .detail(format!("mcp: {}", why.as_str()))
            .record(&state.db)
            .await;
        return authz::error(StatusCode::FORBIDDEN, "forbidden", why.as_str());
    }

    if !origin_allowed(&req, &state.config.get_server().cors_allowed_origins) {
        return error(StatusCode::FORBIDDEN, "forbidden");
    }

    if let Some(version_hdr) = req.headers().get("mcp-protocol-version") {
        let Ok(version_str) = version_hdr.to_str() else {
            return error(StatusCode::BAD_REQUEST, "unsupported_protocol_version");
        };
        if !sbm_mcp::speaks_version(version_str.trim()) {
            return error(StatusCode::BAD_REQUEST, "unsupported_protocol_version");
        }
    }

    let accepts_json = req
        .headers()
        .get_all(ACCEPT)
        .filter_map(|v| v.to_str().ok())
        .any(|a| a.to_ascii_lowercase().contains("application/json"));
    if !accepts_json {
        return error(StatusCode::NOT_ACCEPTABLE, "not_acceptable");
    }
    let content_type_json = req
        .headers()
        .get(CONTENT_TYPE)
        .and_then(|v| v.to_str().ok())
        .is_some_and(|c| {
            c.split(';')
                .next()
                .unwrap_or("")
                .trim()
                .eq_ignore_ascii_case("application/json")
        });
    if !content_type_json {
        return error(StatusCode::UNSUPPORTED_MEDIA_TYPE, "unsupported_media_type");
    }

    let body = match json::collect(&req, &mut payload.0, MAX_BODY).await {
        Ok(body) => body,
        Err(_) => return error(StatusCode::PAYLOAD_TOO_LARGE, "too_large"),
    };
    let message: Value = match serde_json::from_slice(&body) {
        Ok(value) => value,
        Err(_) => return error(StatusCode::BAD_REQUEST, "bad_request"),
    };

    let is_call = message.get("method").and_then(Value::as_str) == Some("tools/call");
    let tool_name = message
        .get("params")
        .and_then(|p| p.get("name"))
        .and_then(Value::as_str)
        .unwrap_or("");

    // `[remote_access.exec] max_request_bytes` bounds command payloads across
    // every entry point; only `fs_write` uses the larger 4 MiB body envelope.
    if is_call && tool_name == "run_command" && body.len() > state.remote_access.exec.max_request_bytes {
        return error(StatusCode::PAYLOAD_TOO_LARGE, "too_large");
    }

    // Re-verify the account's password generation after reading the body so a
    // password change committed during upload revokes the token before dispatch.
    if !authz::caller(&state)
        .await
        .is_some_and(|current| current.since == caller.caller.since)
    {
        return authz::unauthorized();
    }

    let global_policy = match api_tokens::load_policy(&state.db).await {
        Ok(policy) => policy,
        Err(e) => {
            tracing::warn!("Could not load MCP policy: {e}");
            return error(StatusCode::INTERNAL_SERVER_ERROR, "internal_error");
        }
    };
    let config_mcp = state.config.get_mcp();
    let effective_scopes: Vec<Scope> = Scope::ALL
        .iter()
        .copied()
        .filter(|&s| {
            config_mcp.allows_scope(s)
                && global_policy.scopes.contains(&s)
                && caller.token.scopes.contains(&s)
        })
        .collect();

    let host = TokenHost {
        state: state.clone(),
        caller: caller.caller.clone(),
        token_name: caller.token.name.clone(),
        peer: req.peer_addr(),
        remote_ip: caller.remote_ip.clone(),
        scopes: effective_scopes,
        config_commands: config_mcp.commands,
        global_commands: global_policy.commands,
        token_commands: caller.token.commands.clone(),
        audited_before_run: AtomicBool::new(false),
    };

    let answer = sbm_mcp::serve(&host, &message).await;

    match answer {
        Answer::Json(value) => {
            if is_call && !host.audited_before_run.load(Ordering::Relaxed) {
                let failed = value.get("error").is_some()
                    || value.pointer("/result/isError").and_then(Value::as_bool) == Some(true);
                let detail = if tool_name == "run_command"
                    && let Some(cmd) = message.pointer("/params/arguments/command").and_then(Value::as_str)
                    && !cmd.trim().is_empty()
                {
                    format!("tool run_command: {}", super::exec::first_line(cmd))
                } else {
                    format!("tool {tool_name}")
                };
                Event::new(
                    Kind::Mcp,
                    Action::Open,
                    if failed { Outcome::Error } else { Outcome::Ok },
                )
                .subject(format!("api token '{}'", caller.token.name))
                .remote_ip(caller.remote_ip.clone())
                .detail(detail)
                .record(&state.db)
                .await;
            }
            HttpResponse::Ok()
                .content_type(HeaderValue::from_static("application/json"))
                .json(&value)
        }
        Answer::Accepted => HttpResponse::builder(StatusCode::ACCEPTED).build(),
    }
}
