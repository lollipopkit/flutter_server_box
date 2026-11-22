//! [`crate::catalog::shell`]'s tools, answered on one [`Machine`].

use serde::de::DeserializeOwned;
use serde_json::{Value, json};

use super::containers::{self, ContainerPart};
use super::processes::{self, KillRequest, StopRefused};
use super::services::{self, ServiceActRequest, ServicePart, ServiceRefused};
use super::{Audit, Machine, Run, Stage, tmux};
use crate::access::{CommandPolicy, evaluate_layers};
use crate::{CallToolResult, structured, tool_error};

/// Answers [name] on [m]; `None` for a tool that is not one of
/// [`crate::catalog::shell`]'s, or is `run_command` (see [`run_command`]).
pub async fn call(m: &dyn Machine, name: &str, arguments: &Value) -> Option<CallToolResult> {
    Some(match name {
        "processes" => {
            let sort = match optional(arguments, "sort") {
                Ok(sort) => sort,
                Err(e) => return Some(tool_error(format!("invalid sort: {e}"))),
            };
            let ascending = match arguments.get("ascending") {
                None => None,
                Some(v) => match v.as_bool() {
                    Some(b) => Some(b),
                    None => return Some(tool_error("ascending must be a boolean")),
                },
            };
            to_result(&processes::table(m, sort, ascending).await)
        }
        "services" => {
            let part: ServicePart = match optional(arguments, "part") {
                Ok(part) => part.unwrap_or_default(),
                Err(e) => return Some(tool_error(format!("invalid part: {e}"))),
            };
            let key = arguments.get("key").and_then(Value::as_str);
            to_result(&services::listing(m, part, key).await)
        }
        "containers" => {
            let part: ContainerPart = match optional(arguments, "part") {
                Ok(part) => part.unwrap_or_default(),
                Err(e) => return Some(tool_error(format!("invalid part: {e}"))),
            };
            let id = arguments.get("id").and_then(Value::as_str);
            match containers::listing(m, part, id).await {
                Ok(response) => to_result(&response),
                Err(issue) => tool_error(format!("invalid container id: {} ({})", issue, issue.code())),
            }
        }
        "tmux" => structured(tmux::sessions(m).await),
        "kill_process" => {
            // The tool's `signal` defaults to TERM; the route's is required.
            let mut arguments = arguments.clone();
            if let Some(args) = arguments.as_object_mut() {
                args.entry("signal").or_insert_with(|| json!("term"));
            }
            let mut request: KillRequest = match parse(&arguments) {
                Ok(r) => r,
                Err(e) => return Some(tool_error(e)),
            };
            if request.start_id.is_none() {
                return Some(tool_error("invalid arguments: missing field `start_id`"));
            }
            request.password = None;
            match processes::stop(m, request).await {
                Ok(response) => to_result(&response),
                Err(StopRefused::Unsafe) => tool_error(
                    "this PID cannot be signalled safely: the listing reported no start identity to check it against",
                ),
            }
        }
        "service_action" => {
            let mut request: ServiceActRequest = match parse(arguments) {
                Ok(r) => r,
                Err(e) => return Some(tool_error(e)),
            };
            request.password = None;
            match services::perform(m, request).await {
                Ok(response) => to_result(&response),
                Err(ServiceRefused::Unsupported) => tool_error("this machine has no service manager that is talked to"),
                Err(ServiceRefused::NoSuchUnit) => tool_error("no such unit in the current listing"),
            }
        }
        "container_action" => {
            // Both the flat tagged object (`{ "action": "stop", "id": "…" }`)
            // and a nested `{ "action": { "action": "stop", … } }` envelope.
            let raw = match arguments.get("action") {
                Some(inner) if inner.is_object() => inner,
                _ => arguments,
            };
            let action = match serde_json::from_value(raw.clone()) {
                Ok(action) => action,
                Err(e) => return Some(tool_error(format!("invalid action: {e}"))),
            };
            match containers::apply(m, action).await {
                Ok(response) => structured(response),
                Err(issue) => tool_error(format!("refused: {} ({})", issue, issue.code())),
            }
        }
        _ => return None,
    })
}

/// `run_command`: [arguments]' command under every policy layer, no longer
/// than [max_bytes], as a command line of the account's own shell.
///
/// Recorded before it runs ([`Audit::Command`]), with its first line: a
/// command that hangs or reboots the machine still has to be on file.
pub async fn run_command(
    m: &dyn Machine,
    arguments: &Value,
    layers: &[(&str, &CommandPolicy)],
    max_bytes: usize,
) -> CallToolResult {
    let Some(command) = arguments.get("command").and_then(Value::as_str) else {
        return tool_error("command is required");
    };
    if command.trim().is_empty() {
        return tool_error("command must not be empty");
    }
    if command.len() > max_bytes {
        return tool_error(format!("command exceeds the {max_bytes} byte limit"));
    }
    if let Err(why) = evaluate_layers(command, layers) {
        return tool_error(why);
    }
    m.record(Audit::Command { stage: Stage::Started, line: &first_line(command) }).await;
    match m.run(Run::Line(command), 0).await {
        Ok(out) => structured(json!({
            "exit_code": out.exit_code,
            "stdout": out.stdout,
            "stderr": out.stderr,
            "truncated": out.truncated,
            "timed_out": out.timed_out,
        })),
        Err(e) => {
            m.record(Audit::Command { stage: Stage::Failed, line: &e }).await;
            tool_error(format!("the command could not be run: {e}"))
        }
    }
}

/// The first line, capped — an audit row records which command ran, not a
/// script's entire body.
pub fn first_line(cmd: &str) -> String {
    let line = cmd.lines().next().unwrap_or("").trim();
    if line.len() <= 200 {
        return line.to_string();
    }
    let mut end = 200;
    while !line.is_char_boundary(end) {
        end -= 1;
    }
    format!("{}…", &line[..end])
}

fn optional<T: DeserializeOwned>(arguments: &Value, key: &str) -> Result<Option<T>, serde_json::Error> {
    arguments.get(key).map(|v| serde_json::from_value(v.clone())).transpose()
}

fn parse<T: DeserializeOwned>(arguments: &Value) -> Result<T, String> {
    serde_json::from_value(arguments.clone()).map_err(|e| format!("invalid arguments: {e}"))
}

fn to_result(value: &impl serde::Serialize) -> CallToolResult {
    structured(serde_json::to_value(value).unwrap_or(Value::Null))
}

#[cfg(test)]
mod tests {
    use super::super::fake::{Fake, ok};
    use super::*;
    use crate::access::CommandMode;
    use sbm_parser::SystemType;

    #[tokio::test]
    async fn a_command_is_held_to_every_layer_and_recorded_before_it_runs() {
        let m = Fake::new(SystemType::Linux, vec![("echo", ok("hi\n"))]);
        let open = CommandPolicy::default();
        let strict = CommandPolicy { mode: CommandMode::Allowlist, ..Default::default() };

        let refused = run_command(&m, &json!({ "command": "echo hi" }), &[("token", &strict)], 1024).await;
        assert_eq!(refused.is_error, Some(true));
        assert!(m.asked.lock().unwrap().is_empty());

        let ran = run_command(&m, &json!({ "command": "echo hi" }), &[("token", &open)], 1024).await;
        assert_eq!(ran.structured_content.unwrap()["stdout"], "hi\n");
        assert_eq!(m.audits.lock().unwrap().len(), 1);

        let long = run_command(&m, &json!({ "command": "echo hi" }), &[], 3).await;
        assert_eq!(long.is_error, Some(true));
    }

    #[tokio::test]
    async fn a_tool_that_is_not_the_shells_is_not_answered() {
        let m = Fake::new(SystemType::Linux, vec![]);
        assert!(call(&m, "fs_read", &json!({})).await.is_none());
        assert!(call(&m, "run_command", &json!({})).await.is_none());
        let refused = call(&m, "kill_process", &json!({ "pid": 1 })).await.unwrap();
        assert_eq!(refused.is_error, Some(true));
    }
}
