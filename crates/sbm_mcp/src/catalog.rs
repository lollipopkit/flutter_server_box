//! Every tool a ServerBox MCP server lists, by the [`Scope`] that grants it.
//!
//! [`shell`] is what any machine reached through a shell serves — the
//! monitor on its own machine and the app on each of its servers, both
//! answered by [`crate::machine`]. [`monitor`] adds what only the monitor
//! has: its own readings, files, cron, virtualization, stacks and power.
//! A server reaching several machines names one with [`with_host`].

use std::sync::Arc;

use serde_json::{Value, json};

use crate::Tool;
use crate::access::Scope;

fn tool(name: &'static str, description: &'static str, schema: Value) -> Tool {
    crate::tool(name, description, schema)
}

fn no_args(name: &'static str, description: &'static str) -> Tool {
    tool(name, description, json!({ "type": "object", "properties": {}, "additionalProperties": false }))
}

/// [tool] with a required `host` naming which of the server's machines it
/// is about: an id from the server's own `list`.
pub fn with_host(mut tool: Tool) -> Tool {
    let mut schema = (*tool.input_schema).clone();
    schema
        .entry("properties")
        .or_insert_with(|| json!({}))
        .as_object_mut()
        .map(|p| p.insert("host".into(), json!({ "type": "string", "description": "Host id from `list`." })));
    let required = schema.entry("required").or_insert_with(|| json!([]));
    if let Some(list) = required.as_array_mut() {
        list.insert(0, json!("host"));
    }
    tool.input_schema = Arc::new(schema);
    tool
}

/// The tools any machine reached through a shell serves under [scope].
pub fn shell(scope: Scope) -> Vec<Tool> {
    match scope {
        Scope::Read => vec![
            tool(
                "processes",
                "Process table: PID, start_id, parent, user, state, CPU, memory and command line.",
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
                "Service units of the service manager, or one unit's logs, status or definition.",
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
            no_args("tmux", "Active tmux sessions."),
        ],
        Scope::Exec => vec![tool(
            "run_command",
            "Runs a shell command as the account the machine is reached as, within the timeout, output cap and command policy.",
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
        )],
        Scope::Process => vec![tool(
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
        )],
        Scope::Service => vec![tool(
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
        )],
        Scope::Container => vec![tool(
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
        )],
        Scope::FsRead | Scope::FsWrite | Scope::Cron | Scope::Virt | Scope::Stacks | Scope::Power | Scope::Settings => {
            Vec::new()
        }
    }
}

/// Every tool the monitor serves under [scope]: its own, then [`shell`]'s.
pub fn monitor(scope: Scope) -> Vec<Tool> {
    let mut tools = match scope {
        Scope::Read => vec![
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
        ],
        _ => Vec::new(),
    };
    tools.extend(shell(scope));
    tools.extend(match scope {
        Scope::Read => vec![
            no_args("cron", "Crontab jobs and preserved lines of the account the Monitor runs as."),
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
        ],
        Scope::FsRead => vec![
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
        ],
        Scope::FsWrite => vec![
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
        ],
        Scope::Cron => vec![tool(
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
        )],
        Scope::Virt => vec![tool(
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
        )],
        Scope::Stacks => vec![tool(
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
        )],
        Scope::Power => vec![tool(
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
        )],
        Scope::Exec | Scope::Process | Scope::Service | Scope::Container | Scope::Settings => Vec::new(),
    });
    tools
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn a_host_is_required_first_and_the_rest_is_kept() {
        let kill = with_host(shell(Scope::Process).remove(0));
        assert_eq!(kill.input_schema["required"], json!(["host", "pid", "start_id"]));
        assert_eq!(kill.input_schema["properties"]["host"]["type"], "string");
        assert_eq!(kill.input_schema["properties"]["pid"]["type"], "integer");
        let tmux = with_host(shell(Scope::Read).pop().unwrap());
        assert_eq!(tmux.input_schema["required"], json!(["host"]));
        assert_eq!(tmux.input_schema["additionalProperties"], false);
    }

    #[test]
    fn every_name_is_listed_once() {
        let mut names: Vec<String> = Scope::MONITOR.iter().flat_map(|s| monitor(*s)).map(|t| t.name.to_string()).collect();
        let total = names.len();
        names.sort();
        names.dedup();
        assert_eq!(names.len(), total);
        assert!(monitor(Scope::Settings).is_empty());
    }
}
