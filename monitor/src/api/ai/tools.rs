//! The three tools the Agent may propose, and running one.
//!
//! `lib/data/provider/ai/global_agent_tools.dart` declares five. The other two
//! — `ssh_connect`, `ssh_disconnect` — exist because the app is a client and
//! has to reach a machine it is not on: they open a connection nobody has
//! vetted, and the app's risk model treats reaching one as the most
//! consequential thing the Agent can propose. This agent runs *where the
//! commands run*, so there is no connection to open, and the two definitions
//! would be a way to ask for a credential that is already this process's.
//!
//! Every definition here also drops the `server_id`/`session_id` pair, whose
//! whole job is to say which machine a call is about. Nothing else in a
//! definition changed: a model that has seen this tool set in the app proposes
//! the same calls here.
//!
//! ## What a call is worth, and what may run
//!
//! [`risk_of`] is the app's `intrinsicRisk` with the app's own `_unvettedFloor`
//! left out — that floor exists for a host met in this conversation, and here
//! the machine is the agent's own, at the risk it was configured at. The
//! model's `destructive: true` still floors the verdict, for the app's reason:
//! the classifier matches a shape and knows nothing about the machine, the
//! model is reading a call it has context for, and the cost of asking is a tap.
//!
//! The direction is worth stating because the app's is the other one. It
//! auto-runs on `modelSafeToRun && risk == readOnly`; here the rule is
//! `auto_run_safe_commands && risk == ReadOnly`, and the model's `safe_to_run`
//! is recorded but not required. One reader may lower nothing and raise
//! everything: a model that says "this is fine" about `rm -rf /` must not be
//! able to talk the agent out of the classifier, while a model that says
//! "this destroys data" about `ls` is believed.
//!
//! ## Credentials
//!
//! A read-only command may be run without asking (`cat config.toml` is one),
//! and this agent's own config holds its `jwt_secret`, its model provider's API
//! key and every push credential. None of those were given to whoever operates
//! the model endpoint, so every string a tool call produces goes through
//! [`Redactor`] before it becomes what the model is told. See
//! `api::push::credential_values` for what that is and what it is not.

use std::sync::Arc;

use serde_json::{Value, json};
use sbm_parser::ai_risk::{CommandRisk, classify};
use tokio::io::{AsyncReadExt, AsyncWriteExt};
use tokio::sync::Notify;

use crate::api::exec::{self, ExecResponse};
use crate::api::fs::{commit_staging, staging_path};
use crate::api::push::credential_values;
use crate::api::server::AppState;

/// How much of a file `read_file` may put in front of a model.
///
/// The app's `_maxReadBytes`, the same number for the same reason: what a model
/// asked for is usually a config file, and a log it asked for by mistake should
/// cost a request rather than a context window.
const MAX_READ_BYTES: usize = 128 * 1024;

/// How large a file `write_file` may put.
///
/// The app's `_maxWriteBytes`. A call over it is **refused rather than
/// truncated**: a half-written file is a corrupted one, and the model that
/// proposed it is the only party that can say what it meant.
const MAX_WRITE_BYTES: usize = 512 * 1024;

/// The tools, in the Chat Completions request shape.
///
/// The schema objects are the app's, minus the two fields named above. They are
/// copied rather than shared because the two runtimes share no code — the
/// monorepo's Rust side has no Dart FFI for a JSON schema, and inventing one for
/// three literals would cost more than it holds.
pub fn definitions() -> Vec<Value> {
    json!([
        {
            "type": "function",
            "function": {
                "name": "run_shell_command",
                "description": "Run one complete, non-interactive shell command on \
                                this server.",
                "parameters": {
                    "type": "object",
                    "additionalProperties": false,
                    "required": ["command", "description", "safe_to_run", "destructive"],
                    "properties": {
                        "command": {
                            "type": "string",
                            "description": "A complete, non-interactive shell command."
                        },
                        "description": {
                            "type": "string",
                            "description": "A concise explanation of the action and its risk."
                        },
                        "safe_to_run": {
                            "type": "boolean",
                            "description": "True only for clearly read-only, idempotent, \
                                            non-destructive commands."
                        },
                        "destructive": {
                            "type": "boolean",
                            "description": "True when running this could lose data or take a \
                                            service down: deleting, overwriting, formatting, \
                                            killing, rebooting, or anything else that cannot \
                                            simply be undone. The agent has its own list of \
                                            such commands and asks when either of you says so, \
                                            so say so for what a list cannot see — a path that \
                                            matters, a script whose name says nothing about \
                                            what it does."
                        }
                    }
                }
            }
        },
        {
            "type": "function",
            "function": {
                "name": "read_file",
                "description": "Read a UTF-8 text file from this server.",
                "parameters": {
                    "type": "object",
                    "additionalProperties": false,
                    "required": ["path", "description", "safe_to_run"],
                    "properties": {
                        "path": {
                            "type": "string",
                            "description": "The absolute file path to read."
                        },
                        "description": {
                            "type": "string",
                            "description": "Why this file is needed."
                        },
                        "safe_to_run": {
                            "type": "boolean",
                            "description": "True because this tool only reads an existing file."
                        }
                    }
                }
            }
        },
        {
            "type": "function",
            "function": {
                "name": "write_file",
                "description": "Replace a UTF-8 text file after user review.",
                "parameters": {
                    "type": "object",
                    "additionalProperties": false,
                    "required": ["path", "content", "description", "safe_to_run"],
                    "properties": {
                        "path": {
                            "type": "string",
                            "description": "The absolute file path to create or replace."
                        },
                        "content": {
                            "type": "string",
                            "description": "The complete UTF-8 content to write."
                        },
                        "description": {
                            "type": "string",
                            "description": "What is being changed and why."
                        },
                        "safe_to_run": {
                            "type": "boolean",
                            "description": "Always false because this tool changes a file."
                        }
                    }
                }
            }
        }
    ])
    .as_array()
    .cloned()
    .expect("a literal array")
}

/// What a call would be worth on this machine, before anyone has said anything
/// about it.
///
/// A tool this build does not implement answers [`CommandRisk::Caution`]: it
/// never auto-runs, and [`execute`] refuses it, so the value only has to be one
/// that keeps a call waiting for a person.
pub fn risk_of(tool: &str, arguments: &Value) -> CommandRisk {
    let intrinsic = match tool {
        // Reading a file is not a command, and the app does not review it
        // either. Its boundary is the fs roots, not a per-call prompt.
        "read_file" => CommandRisk::ReadOnly,
        // Replaces a file's whole contents. The app's `caution`, and never
        // auto-run whatever the model says about it.
        "write_file" => CommandRisk::Caution,
        "run_shell_command" => classify(arg_str(arguments, "command").unwrap_or("")),
        _ => CommandRisk::Caution,
    };
    // A claim may only raise a verdict. `destructive` absent is not a claim of
    // safety — the classifier's own reading stands on its own.
    if arguments
        .get("destructive")
        .and_then(Value::as_bool)
        .unwrap_or(false)
    {
        CommandRisk::Destructive
    } else {
        intrinsic
    }
}

/// Takes this agent's own credentials back out of what a tool call produces.
#[derive(Debug, Clone)]
pub struct Redactor {
    values: Vec<String>,
}

impl Redactor {
    pub fn new(state: &AppState) -> Self {
        Self {
            values: credential_values(&state.config),
        }
    }

    /// Replaces every stored credential value with a marker.
    ///
    /// The marker names what was removed rather than blanking the text, so a
    /// model that sees it can say "the agent withheld a credential here"
    /// instead of concluding the file was empty.
    fn redact(&self, text: &str) -> String {
        let mut out = text.to_string();
        for value in &self.values {
            if out.contains(value.as_str()) {
                out = out.replace(value.as_str(), "[redacted by the agent]");
            }
        }
        out
    }

    /// Every string, at any depth — a command's output is a string, and a
    /// result envelope is an object of them.
    fn redact_value(&self, value: &mut Value) {
        match value {
            Value::String(text) => *text = self.redact(text),
            Value::Array(items) => items.iter_mut().for_each(|v| self.redact_value(v)),
            Value::Object(entries) => entries.values_mut().for_each(|v| self.redact_value(v)),
            _ => {}
        }
    }
}

/// One tool call's result: the exact string stored as the `function_output`
/// item and sent back to the model.
pub struct Outcome {
    pub message: String,
    /// Whether the call did what it said it would. Not the same as whether the
    /// command exited 0 — a shell command that fails is a result the model
    /// asked for, not a failed call.
    pub ok: bool,
}

/// Runs one call.
///
/// Never answers `Err`. A failure the model can act on — a path outside the
/// roots, a command that could not be started — is a result with
/// `local_failure: true` and an English summary, the app's convention: the
/// model reads the summary, and a client draws its own line for the case.
pub async fn execute(
    state: &Arc<AppState>,
    tool: &str,
    arguments: &Value,
    redactor: &Redactor,
    stop: &Notify,
) -> Outcome {
    let started = std::time::Instant::now();
    let envelope = tokio::select! {
        // A turn that is stopped drops this future, and `exec`'s child is
        // `kill_on_drop` — the same thing `/exec`'s own timeout relies on.
        // Answering with an envelope rather than aborting the task outright is
        // what keeps the call answered: a `function_call` with no
        // `function_output` is this agent's awaiting-review state, and a
        // stopped call is not waiting for anyone.
        biased;
        _ = stop.notified() => envelope(
            tool,
            false,
            "The user stopped this call.",
            json!({}),
            started.elapsed().as_millis() as u64,
            true,
            false,
            false,
        ),
        result = run(state, tool, arguments) => match result {
            Ok((summary, data, ok, truncated)) => envelope(
                tool,
                ok,
                &summary,
                data,
                started.elapsed().as_millis() as u64,
                false,
                truncated,
                false,
            ),
            Err(refusal) => envelope(
                tool,
                false,
                &refusal.summary,
                refusal.data,
                started.elapsed().as_millis() as u64,
                false,
                false,
                true,
            ),
        },
    };
    let ok = envelope["ok"].as_bool().unwrap_or(false);
    let mut envelope = envelope;
    redactor.redact_value(&mut envelope);
    Outcome {
        message: envelope.to_string(),
        ok,
    }
}

/// A call that could not be carried out, in the model's language.
struct Refusal {
    summary: String,
    data: Value,
}

impl Refusal {
    fn new(summary: impl Into<String>) -> Self {
        Self {
            summary: summary.into(),
            data: Value::Object(Default::default()),
        }
    }

    fn at(mut self, path: &str) -> Self {
        self.data = json!({ "path": path });
        self
    }
}

type Ran = Result<(String, Value, bool, bool), Refusal>;

async fn run(state: &Arc<AppState>, tool: &str, arguments: &Value) -> Ran {
    match tool {
        "run_shell_command" => run_shell(state, arguments).await,
        "read_file" => read_file(state, arguments).await,
        "write_file" => write_file(state, arguments).await,
        other => Err(Refusal::new(format!(
            "The agent does not implement the tool {other:?}."
        ))),
    }
}

async fn run_shell(state: &Arc<AppState>, arguments: &Value) -> Ran {
    let Some(command) = arg_str(arguments, "command") else {
        return Err(Refusal::new("The call carried no command."));
    };
    if command.trim().is_empty() {
        return Err(Refusal::new("The call carried an empty command."));
    }

    let ExecResponse {
        exit_code,
        stdout,
        stderr,
        truncated,
        timed_out,
    } = exec::run(command, None, None, &state.remote_access.exec)
        .await
        .map_err(|e| Refusal::new(format!("The command could not be started: {e}")))?;

    let ok = exit_code == Some(0) && !timed_out;
    let summary = if timed_out {
        "Command timed out.".to_string()
    } else {
        format!("Command exited with code {}.", exit_code.unwrap_or(-1))
    };
    Ok((
        summary,
        json!({
            "command": command,
            "exit_code": exit_code,
            "stdout": stdout,
            "stderr": stderr,
            "timed_out": timed_out,
        }),
        ok,
        truncated,
    ))
}

async fn read_file(state: &Arc<AppState>, arguments: &Value) -> Ran {
    let path = required_path(arguments)?;
    let resolved = state
        .remote_access
        .fs
        .roots
        .resolve_existing(path)
        .map_err(|e| Refusal::new(format!("Cannot read {path}: {e}")).at(path))?;

    let file = tokio::fs::File::open(&resolved).await.map_err(|e| {
        Refusal::new(format!("Cannot read {path}: {e}")).at(path)
    })?;
    let size = file.metadata().await.ok().map(|m| m.len());

    // One byte past the cap is enough to know it was exceeded, and stopping
    // there is what keeps a log file the model asked for from being pulled
    // across in full before being thrown away.
    let mut bytes = Vec::new();
    let mut limited = file.take(MAX_READ_BYTES as u64 + 1);
    limited
        .read_to_end(&mut bytes)
        .await
        .map_err(|e| Refusal::new(format!("Cannot read {path}: {e}")).at(path))?;
    let truncated = bytes.len() > MAX_READ_BYTES;
    bytes.truncate(MAX_READ_BYTES);

    let summary = if truncated {
        format!("Read the first {MAX_READ_BYTES} bytes of {path}.")
    } else {
        format!("Read {path}.")
    };
    Ok((
        summary,
        json!({
            "path": path,
            "size_bytes": size,
            "content": String::from_utf8_lossy(&bytes),
        }),
        true,
        truncated,
    ))
}

async fn write_file(state: &Arc<AppState>, arguments: &Value) -> Ran {
    let path = required_path(arguments)?;
    let Some(content) = arg_str(arguments, "content") else {
        return Err(Refusal::new("The call carried no content.").at(path));
    };
    if content.len() > MAX_WRITE_BYTES {
        return Err(Refusal::new(format!(
            "The content is {} bytes, over the {MAX_WRITE_BYTES} byte limit for one write.",
            content.len()
        ))
        .at(path));
    }

    let resolved = state
        .remote_access
        .fs
        .roots
        .resolve_new(path)
        .map_err(|e| Refusal::new(format!("Cannot write {path}: {e}")).at(path))?;

    // Beside the destination, then renamed — `api::fs`'s own contract, through
    // its own helpers so the mode-carry cannot be missing from one of them.
    let staging = staging_path(&resolved);
    let staged = async {
        let mut file = tokio::fs::OpenOptions::new()
            .write(true)
            .create_new(true)
            .open(&staging)
            .await?;
        file.write_all(content.as_bytes()).await?;
        file.flush().await
    }
    .await;
    if let Err(e) = staged {
        let _ = tokio::fs::remove_file(&staging).await;
        return Err(Refusal::new(format!("Cannot write {path}: {e}")).at(path));
    }
    if let Err(e) = commit_staging(&staging, &resolved).await {
        return Err(Refusal::new(format!("Cannot write {path}: {e}")).at(path));
    }

    Ok((
        format!("Wrote {} bytes to {path}.", content.len()),
        json!({ "path": path, "bytes_written": content.len() }),
        true,
        false,
    ))
}

/// The envelope the model reads, in `AgentToolExecutionResult.toToolMessage()`'s
/// shape minus `server_id` — this agent is the server, and a field that always
/// carries the same value is one a model learns nothing from.
///
/// `summary` is English because the model reads it; a client draws its own line
/// for the cases it knows, off `local_failure` and the tool's own data.
#[allow(clippy::too_many_arguments)]
fn envelope(
    tool: &str,
    ok: bool,
    summary: &str,
    data: Value,
    duration_ms: u64,
    cancelled: bool,
    truncated: bool,
    local_failure: bool,
) -> Value {
    json!({
        "server_box_tool_result": true,
        "tool": tool,
        "ok": ok,
        "summary": summary,
        "data": data,
        "duration_ms": duration_ms,
        "cancelled": cancelled,
        "truncated": truncated,
        "local_failure": local_failure,
    })
}

fn required_path(arguments: &Value) -> Result<&str, Refusal> {
    match arg_str(arguments, "path") {
        Some(path) if !path.is_empty() => Ok(path),
        _ => Err(Refusal::new("The call carried no path.")),
    }
}

/// A JSON string, and nothing else — a number or a nested object where a string
/// belongs is not something to coerce.
fn arg_str<'a>(arguments: &'a Value, key: &str) -> Option<&'a str> {
    arguments.get(key).and_then(Value::as_str)
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn a_definition_declares_the_fields_a_model_must_supply() {
        let definitions = definitions();
        let names: Vec<&str> = definitions
            .iter()
            .map(|d| d["function"]["name"].as_str().unwrap())
            .collect();
        assert_eq!(names, ["run_shell_command", "read_file", "write_file"]);

        // Neither tool that exists only because the app is a client, and no
        // `server_id`/`session_id` anywhere: both would be a way to ask this
        // agent which machine, when the answer is itself.
        let text = Value::Array(definitions.clone()).to_string();
        for absent in ["ssh_connect", "ssh_disconnect", "server_id", "session_id"] {
            assert!(!text.contains(absent), "{absent} is in the schema");
        }

        for definition in &definitions {
            let parameters = &definition["function"]["parameters"];
            assert_eq!(parameters["additionalProperties"], false);
            assert!(
                parameters["required"].as_array().is_some_and(|r| !r.is_empty()),
                "a tool with no required field is one a model can call empty"
            );
            for required in parameters["required"].as_array().unwrap() {
                let key = required.as_str().unwrap();
                assert!(
                    parameters["properties"].get(key).is_some(),
                    "required names {key}, which is not declared"
                );
            }
        }
    }

    #[test]
    fn a_claim_of_destruction_raises_a_verdict_and_never_lowers_one() {
        // The classifier's own reading, unopposed.
        assert_eq!(risk_of("run_shell_command", &json!({"command": "df -h"})), CommandRisk::ReadOnly);
        assert_eq!(
            risk_of("run_shell_command", &json!({"command": "rm -rf /"})),
            CommandRisk::Destructive
        );

        // A model saying "this is safe" changes nothing — `safe_to_run` is not
        // an input to this function at all.
        assert_eq!(
            risk_of(
                "run_shell_command",
                &json!({"command": "rm -rf /", "safe_to_run": true})
            ),
            CommandRisk::Destructive
        );
        assert_eq!(
            risk_of(
                "run_shell_command",
                &json!({"command": "df -h", "safe_to_run": true})
            ),
            CommandRisk::ReadOnly
        );

        // A model saying "this destroys data" is believed over the classifier.
        assert_eq!(
            risk_of(
                "run_shell_command",
                &json!({"command": "df -h", "destructive": true})
            ),
            CommandRisk::Destructive
        );

        assert_eq!(risk_of("read_file", &json!({"path": "/etc/hosts"})), CommandRisk::ReadOnly);
        assert_eq!(risk_of("write_file", &json!({"path": "/etc/hosts"})), CommandRisk::Caution);

        // A tool this build does not implement, and a call with no command at
        // all: both wait for a person rather than running.
        assert_eq!(risk_of("pivot_root", &json!({})), CommandRisk::Caution);
        assert_eq!(risk_of("run_shell_command", &json!({})), CommandRisk::Caution);
        assert_eq!(risk_of("run_shell_command", &json!({"command": 7})), CommandRisk::Caution);
    }

    #[test]
    fn a_stored_credential_does_not_survive_into_a_tool_result() {
        let redactor = Redactor {
            values: vec!["hunter2-the-jwt-secret".to_string(), "sk-live-0123456789".to_string()],
        };
        let mut value = json!({
            "summary": "Command exited with code 0.",
            "data": {
                "command": "cat config.toml",
                "stdout": "jwt_secret = \"hunter2-the-jwt-secret\"\n[ai]\napi_key = \"sk-live-0123456789\"",
                "stderr": "",
                "exit_code": 0,
            },
            "duration_ms": 12,
        });
        redactor.redact_value(&mut value);

        let text = value.to_string();
        assert!(!text.contains("hunter2"), "{text}");
        assert!(!text.contains("sk-live"), "{text}");
        // Everything else is untouched, including the numbers.
        assert_eq!(value["duration_ms"], 12);
        assert_eq!(value["data"]["exit_code"], 0);
        assert_eq!(text.matches("[redacted by the agent]").count(), 2);
    }

    #[test]
    fn the_redactor_substitutes_whatever_value_it_is_given() {
        // Two characters would otherwise replace every occurrence of that text
        // in every tool result, so short values are dropped — by
        // `credential_values`, which is where the minimum length belongs and
        // where it is tested. This holds the other half of the pair: that the
        // filter is not here, so there is one place to look for it.
        let redactor = Redactor {
            values: vec!["abc".to_string()],
        };
        let mut value = json!("abcabc");
        redactor.redact_value(&mut value);
        assert_eq!(value, "[redacted by the agent][redacted by the agent]");
    }
}
