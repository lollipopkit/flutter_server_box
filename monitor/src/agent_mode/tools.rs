//! What the model may call: `run_command`, `propose_plan`, `ask_user`. Each
//! one that needs the account waits for it through [`AgentMode::ask`]; what
//! runs without asking is decided here.

use std::sync::Arc;
use std::time::Duration;

use fl_pi_llm::host::{BoxFuture, Cancel, Tool, ToolCall, ToolDef, ToolResult};
use sbm_parser::command_risk::{self, CommandRisk};
use serde::{Deserialize, Serialize};
use serde_json::{Value, json};
use tokio::sync::mpsc;

use super::command::{self, Stream};
use super::permissions::{self, AutoMode, Judgment, Mode};
use super::{Answer, Flow, MAX_PROMPT, PendingView, first_line, prompt};
use sbm_parser::command_rules::RuleVerdict;
use crate::api::authz;
use crate::api::server::AppState;
use crate::api::ws::audit::{Action, Event, Kind, Outcome};
use crate::core::permissions::Grant;

/// The output a page keeps of the running command, newest lines.
pub const LIVE_LINES: usize = 2000;
/// What a finished command keeps in its session entry: the first and the
/// last lines, the middle counted.
const KEEP_HEAD: usize = 2000;
const KEEP_TAIL: usize = 8000;
/// What the model is shown of the output, at most, in characters: the end.
const MODEL_CHARS: usize = 12_000;
const MAX_COMMAND: usize = 16 << 10;
const DEFAULT_TIMEOUT_MINUTES: u64 = 10;
const MAX_TIMEOUT_MINUTES: u64 = 120;
const SUDO_TRIES: usize = 3;
const AREAS: &[&str] = &["status", "process", "service", "container", "files", "system"];

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct PlanStep {
    pub text: String,
    #[serde(default, skip_serializing_if = "Option::is_none")]
    pub command: Option<String>,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct Choice {
    pub label: String,
    #[serde(default, skip_serializing_if = "Option::is_none")]
    pub hint: Option<String>,
}

/// The tools of a task; [flow] is `None` for a session opened only to be
/// read, whose tools refuse to run.
pub(super) fn all(state: Arc<AppState>, flow: Option<Arc<Flow>>) -> Vec<Arc<dyn Tool>> {
    vec![
        Arc::new(RunCommand { state: state.clone(), flow: flow.clone() }),
        Arc::new(ProposePlan { state: state.clone(), flow: flow.clone() }),
        Arc::new(AskUser { state, flow }),
    ]
}

/// Whether [answer] is one [view] can take.
pub(super) fn check_answer(view: &PendingView, answer: &Answer) -> Result<(), &'static str> {
    let text_ok = || answer.text.as_deref().is_some_and(|t| !t.trim().is_empty() && t.len() <= MAX_PROMPT);
    let ok = match (view.kind, answer.action.as_str()) {
        (_, "cancel") => true,
        ("confirm", "run") => true,
        ("confirm" | "danger", "edit") | ("clarify", "text") => {
            if !text_ok() {
                return Err("emptyText");
            }
            true
        }
        ("danger", "run") => {
            if answer.confirm.as_deref().map(str::trim) != view.confirm_text.as_deref() {
                return Err("confirmMismatch");
            }
            true
        }
        ("danger", "alternative") => {
            if !answer.index.is_some_and(|i| i < view.alternatives.len()) {
                return Err("invalidIndex");
            }
            true
        }
        ("clarify", "pick") => {
            if !answer.index.is_some_and(|i| i < view.options.len()) {
                return Err("invalidIndex");
            }
            true
        }
        ("sudo", "password") => {
            let p = answer.password.as_deref().unwrap_or("");
            if p.is_empty() || p.len() > 1024 || p.contains(['\n', '\r', '\0']) {
                return Err("invalidPassword");
            }
            true
        }
        _ => false,
    };
    if ok { Ok(()) } else { Err("invalidAction") }
}

fn pending(kind: &'static str, call: &ToolCall, title: String) -> PendingView {
    PendingView {
        id: String::new(),
        kind,
        tool_call_id: call.id.clone(),
        title,
        summary: String::new(),
        steps: Vec::new(),
        command: None,
        options: Vec::new(),
        alternatives: Vec::new(),
        confirm_text: None,
        user: None,
        error: None,
    }
}

fn str_arg(args: &Value, key: &str) -> String {
    args[key].as_str().unwrap_or_default().trim().to_string()
}

/// The account behind [flow] may still run commands here.
async fn may_run(state: &AppState, flow: &Flow) -> Result<(), String> {
    let caller = authz::caller_named(state, &flow.username).await.ok_or("the account is gone")?;
    caller
        .check(Grant::Shell, state, flow.secure())
        .map_err(|why| format!("not permitted to run commands here ({})", why.as_str()))
}

/// Where the task last worked: an `ask_user` step is about that.
fn flow_area(flow: &Flow) -> String {
    flow.steps.lock().unwrap().last().map(|s| s.area.clone()).unwrap_or_else(|| "system".into())
}

fn cancelled() -> Result<ToolResult, String> {
    Err("The task was stopped.".into())
}

// -----------------------------------------------------------------------------

struct RunCommand {
    state: Arc<AppState>,
    flow: Option<Arc<Flow>>,
}

#[derive(Debug, Clone, Copy, PartialEq, Eq, PartialOrd, Ord)]
enum Effect {
    Read,
    Change,
    Danger,
}

impl Effect {
    fn parse(s: &str) -> Effect {
        match s {
            "read" => Effect::Read,
            "danger" => Effect::Danger,
            // Anything else is not a claim of a read.
            _ => Effect::Change,
        }
    }

    fn of(risk: CommandRisk) -> Effect {
        match risk {
            CommandRisk::ReadOnly => Effect::Read,
            CommandRisk::Unknown | CommandRisk::Caution => Effect::Change,
            CommandRisk::Destructive => Effect::Danger,
        }
    }

    fn as_str(self) -> &'static str {
        match self {
            Effect::Read => "read",
            Effect::Change => "change",
            Effect::Danger => "danger",
        }
    }
}

impl Tool for RunCommand {
    fn def(&self) -> ToolDef {
        ToolDef {
            name: "run_command".into(),
            label: Some("Run a command".into()),
            description: "Run one non-interactive shell command on this machine and get its output. A command that \
                changes anything runs only after the person confirms it, unless a plan they approved lists it word for word."
                .into(),
            parameters: json!({
                "type": "object",
                "additionalProperties": false,
                "required": ["command", "title", "area", "effect"],
                "properties": {
                    "command": { "type": "string", "description": "The complete shell command, without a leading sudo." },
                    "title": { "type": "string", "description": "What this step does, in a few words, in the person's language." },
                    "area": { "type": "string", "enum": AREAS, "description": "What it is about: status (resources, health), process, service (systemd units), container, files, system (packages, users, network, configuration)." },
                    "effect": { "type": "string", "enum": ["read", "change", "danger"], "description": "read: changes nothing. change: changes the system. danger: loses something that cannot be got back." },
                    "sudo": { "type": "boolean", "description": "Run as root through sudo." },
                    "reason": { "type": "string", "description": "For a danger command: what would be lost, in one sentence." },
                    "alternatives": { "type": "array", "items": { "type": "string" }, "maxItems": 3, "description": "For a danger command: safer ways out to offer, such as backing up first." },
                    "timeout_minutes": { "type": "integer", "minimum": 1, "maximum": MAX_TIMEOUT_MINUTES, "description": "How long it may take; 10 when left out." }
                }
            }),
            sequential: true,
        }
    }

    fn execute(&self, call: ToolCall, cancel: Cancel) -> BoxFuture<'_, Result<ToolResult, String>> {
        Box::pin(async move {
            let Some(flow) = self.flow.clone() else { return Err("not running".into()) };
            let state = &self.state;
            let hub = &state.agent;
            let args = &call.args;
            let command = str_arg(args, "command");
            if command.is_empty() || command.len() > MAX_COMMAND {
                return Err("command must be 1 to 16384 bytes".into());
            }
            let title = first_line(&str_arg(args, "title"), 80);
            let title = if title.is_empty() { first_line(&command, 80) } else { title };
            let area = str_arg(args, "area");
            let area = if AREAS.contains(&area.as_str()) { area } else { "system".into() };
            let sudo = args["sudo"].as_bool().unwrap_or(false) && !prompt::is_root();
            let timeout = Duration::from_secs(60 * args["timeout_minutes"].as_u64().unwrap_or(DEFAULT_TIMEOUT_MINUTES).clamp(1, MAX_TIMEOUT_MINUTES));

            may_run(state, &flow).await?;
            hub.note_area(&flow, &area, &title);
            hub.step_begin(&flow, &call.id, &title, &area);
            hub.persist(&flow).await;
            let r = self.decide_and_run(&flow, &call, &cancel, command, title, area, sudo, timeout).await;
            let state = match &r {
                Ok(r) if r.details["declined"] == true => "cancelled",
                Ok(r) if r.details["cancelled"] == true => "cancelled",
                Ok(r) if r.details["exitCode"] == 0 => "done",
                _ => "failed",
            };
            hub.step_state(&flow, &call.id, state);
            r
        })
    }
}

impl RunCommand {
    #[allow(clippy::too_many_arguments)]
    async fn decide_and_run(
        &self,
        flow: &Arc<Flow>,
        call: &ToolCall,
        cancel: &Cancel,
        command: String,
        title: String,
        area: String,
        sudo: bool,
        timeout: Duration,
    ) -> Result<ToolResult, String> {
        {
            let state = &self.state;
            let hub = &state.agent;
            let args = &call.args;
            let flow = flow.clone();

            // Both readers: the model's claim and the command's shape. The
            // higher one counts.
            let claimed = Effect::parse(args["effect"].as_str().unwrap_or("change"));
            let effect = claimed.max(Effect::of(command_risk::classify(&command)));
            // Then the operator's rules and mode (`permissions`).
            let perms = permissions::load(&state.db).await.map_err(|e| format!("reading the permissions: {e}"))?;
            let verdict = perms.rules.verdict(&command);
            if let RuleVerdict::Deny(rule) = &verdict {
                record(state, &flow.username, &format!("denied by rule `{rule}`: {}", first_line(&command, 200)), Outcome::Denied).await;
                return Err(format!("Refused: this machine's rule `{rule}` forbids it. Nothing was run; do not run it another way."));
            }
            let mode = perms.mode_for(flow.view.lock().unwrap().mode);
            let ask_rule = matches!(verdict, RuleVerdict::Ask(_));
            let confirm = match mode {
                // Bypass: only the operator's ask rules stop it.
                Mode::Bypass => {
                    if !ask_rule && effect != Effect::Read {
                        record(state, &flow.username, &format!("bypass: ran {}", first_line(&command, 200)), Outcome::Ok).await;
                    }
                    ask_rule
                }
                _ if effect == Effect::Danger || ask_rule => true,
                _ if verdict != RuleVerdict::None || effect != Effect::Change || hub.approved(&flow, &command) => false,
                Mode::Manual => true,
                Mode::Auto => match judge(state, &flow, &command, &title, claimed.as_str(), sudo, &perms.auto_mode).await {
                    Some(Judgment::Allow) => {
                        record(state, &flow.username, &format!("auto: allowed {}", first_line(&command, 200)), Outcome::Ok).await;
                        false
                    }
                    Some(Judgment::Block { rule, reason }) => {
                        record(state, &flow.username, &format!("auto: blocked [{rule}] {}", first_line(&command, 200)), Outcome::Denied).await;
                        let label = if rule.is_empty() { String::new() } else { format!(" [{rule}]") };
                        return Err(format!(
                            "Blocked by auto mode{label}: {reason} Nothing was run. Do not try to reach the same end another way; \
                             if it is needed, tell the person, who can ask for it in their own words or change the rules."
                        ));
                    }
                    // No verdict: the person decides.
                    None => true,
                },
            };
            let ask = match effect {
                _ if !confirm => None,
                Effect::Read | Effect::Change => Some({
                    let mut v = pending("confirm", call, title.clone());
                    v.steps = vec![super::PlanStep { text: title.clone(), command: Some(command.clone()) }];
                    v.command = Some(command.clone());
                    v
                }),
                Effect::Danger => Some({
                    let mut v = pending("danger", call, title.clone());
                    v.summary = first_line(&str_arg(args, "reason"), 300);
                    v.command = Some(command.clone());
                    v.alternatives = args["alternatives"]
                        .as_array()
                        .into_iter()
                        .flatten()
                        .filter_map(|a| a.as_str())
                        .map(|a| first_line(a, 60))
                        .filter(|a| !a.is_empty())
                        .take(3)
                        .collect();
                    v.confirm_text = Some(hub.hostname().to_string());
                    v
                }),
            };
            if let Some(view) = ask {
                let alternatives = view.alternatives.clone();
                let Some(answer) = hub.ask(&flow, view).await else { return cancelled() };
                match answer.action.as_str() {
                    "run" => {}
                    "edit" => {
                        return Ok(ToolResult::text(format!("Not run. The person said: {}", answer.text.unwrap_or_default()))
                            .with_details(json!({ "declined": true })));
                    }
                    "alternative" => {
                        let pick = answer.index.and_then(|i| alternatives.get(i)).cloned().unwrap_or_default();
                        return Ok(ToolResult::text(format!("Not run. The person chose instead: {pick}"))
                            .with_details(json!({ "declined": true, "alternative": pick })));
                    }
                    _ => {
                        return Ok(ToolResult::text("The person declined. Nothing was run; change nothing else for this step.")
                            .with_details(json!({ "declined": true })));
                    }
                }
                // Asked and answered: the grant is checked again, now.
                may_run(state, &flow).await?;
            }

            let mut error = None;
            for _ in 0..SUDO_TRIES {
                let password = if sudo {
                    match hub.sudo_password(flow.user_id) {
                        Some(p) => Some(p),
                        None => {
                            let mut v = pending("sudo", call, title.clone());
                            v.command = Some(command.clone());
                            v.user = Some(prompt::system_user());
                            v.error = error.take();
                            let Some(answer) = hub.ask(&flow, v).await else { return cancelled() };
                            if answer.action != "password" {
                                return Ok(ToolResult::text("The person did not give the sudo password. Nothing was run.")
                                    .with_details(json!({ "declined": true })));
                            }
                            may_run(state, &flow).await?;
                            let p = answer.password.unwrap_or_default();
                            if answer.remember {
                                hub.remember_sudo(flow.user_id, &flow.username, Some(p.clone()));
                            }
                            Some(p)
                        }
                    }
                } else {
                    None
                };
                let ran = self.run(&flow, call, &command, password.as_deref(), timeout, cancel).await?;
                if sudo && ran.refused {
                    hub.remember_sudo(flow.user_id, &flow.username, None);
                    error = Some("wrongPassword".into());
                    continue;
                }
                return Ok(ran.result(&command, &title, &area, effect, sudo));
            }
            Ok(ToolResult::text("sudo refused the password three times. Nothing was run.").with_details(json!({ "declined": true })))
        }
    }
}

async fn record(state: &AppState, username: &str, detail: &str, outcome: Outcome) {
    Event::new(Kind::Agent, if matches!(outcome, Outcome::Ok) { Action::Open } else { Action::Denied }, outcome)
        .subject(username)
        .detail(detail.to_string())
        .record(&state.db)
        .await;
}

/// The auto mode judge on [subject] (a command, or a plan's steps); `None`
/// when it gave no verdict.
async fn judge(state: &AppState, flow: &Arc<Flow>, subject: &str, title: &str, claimed: &str, sudo: bool, auto: &AutoMode) -> Option<Judgment> {
    let hub = &state.agent;
    let model = super::config::load(&state.db).await.ok()?.model?;
    let rt = hub.runtime().await.ok()?;
    let session = flow.session.lock().unwrap().clone();
    let entries = match session {
        Some(s) => s.entries().await.unwrap_or_default(),
        None => Vec::new(),
    };
    let system = permissions::judge_prompt(auto, &hub.auto_defaults());
    let input = permissions::judge_input(&entries, subject, title, claimed, sudo);
    let messages = json!([{ "role": "user", "content": [{ "type": "text", "text": input }], "timestamp": 0 }]);
    let reply = tokio::time::timeout(Duration::from_secs(90), rt.complete(json!(model), messages, Some(system), None)).await.ok()?.ok()?;
    let text: String = reply["content"].as_array().into_iter().flatten().filter_map(|c| c["text"].as_str()).collect();
    permissions::parse_judgment(&text)
}

struct Ran {
    finished: command::Finished,
    head: Vec<(u8, String)>,
    tail: std::collections::VecDeque<(u8, String)>,
    omitted: usize,
    /// sudo refused the password; the command did not run.
    refused: bool,
}

impl RunCommand {
    async fn run(&self, flow: &Arc<Flow>, call: &ToolCall, command: &str, password: Option<&str>, timeout: Duration, cancel: &Cancel) -> Result<Ran, String> {
        let hub = &self.state.agent;
        Event::new(Kind::Agent, Action::Open, Outcome::Ok)
            .subject(&flow.username)
            .detail(format!("run {}", first_line(command, 200)))
            .record(&self.state.db)
            .await;
        hub.output_started(flow, &call.id);
        let (tx, mut rx) = mpsc::unbounded_channel::<(Stream, String)>();
        // Stopped by the run (pi's cancel) or by the task.
        let stop = Cancel::new();
        let (a, b, s) = (cancel.clone(), flow.cancel_token(), stop.clone());
        let watcher = tokio::spawn(async move {
            tokio::select! {
                _ = a.cancelled() => {}
                _ = b.cancelled() => {}
            }
            s.cancel();
        });
        let collect = {
            let (hub, flow, id) = (hub.clone(), flow.clone(), call.id.clone());
            tokio::spawn(async move {
                let mut head = Vec::new();
                let mut tail = std::collections::VecDeque::new();
                let mut omitted = 0usize;
                let mut batch = Vec::new();
                let mut tick = tokio::time::interval(Duration::from_millis(150));
                loop {
                    tokio::select! {
                        line = rx.recv() => match line {
                            Some((stream, text)) => {
                                let l = (if stream == Stream::Err { 2u8 } else { 1u8 }, text);
                                batch.push(l.clone());
                                if head.len() < KEEP_HEAD {
                                    head.push(l);
                                } else {
                                    tail.push_back(l);
                                    if tail.len() > KEEP_TAIL {
                                        tail.pop_front();
                                        omitted += 1;
                                    }
                                }
                            }
                            None => break,
                        },
                        _ = tick.tick() => hub.output_lines(&flow, &id, std::mem::take(&mut batch)),
                    }
                }
                hub.output_lines(&flow, &id, batch);
                (head, tail, omitted)
            })
        };
        let finished = command::run(command::Spec { command, sudo_password: password, timeout }, tx, &stop).await;
        watcher.abort();
        let (head, tail, omitted) = collect.await.map_err(|e| e.to_string())?;
        hub.output_ended(flow);
        let finished = finished.map_err(|e| format!("could not start the command: {e}"))?;
        let refused = password.is_some() && finished.exit_code == Some(1) && {
            let stderr: String = head.iter().filter(|(s, _)| *s == 2).take(5).map(|(_, t)| format!("{t}\n")).collect();
            sbm_parser::script::sudo_password_rejected(&stderr)
        };
        Ok(Ran { finished, head, tail, omitted, refused })
    }
}

impl Ran {
    fn result(self, command: &str, title: &str, area: &str, effect: Effect, sudo: bool) -> ToolResult {
        let f = &self.finished;
        let mut text = match (f.exit_code, f.timed_out, f.cancelled) {
            (_, true, _) => "Timed out; the command was stopped.\n".to_string(),
            (_, _, true) => "Stopped.\n".to_string(),
            (Some(c), _, _) => format!("exit code {c}\n"),
            (None, _, _) => "Killed by a signal.\n".to_string(),
        };
        // The end of the output, which is where a command says how it went.
        let all: Vec<&(u8, String)> = self.head.iter().chain(self.tail.iter()).collect();
        let mut shown = Vec::new();
        let mut size = 0;
        for (s, t) in all.iter().rev() {
            let line = if *s == 2 { format!("[stderr] {t}") } else { t.clone() };
            size += line.len() + 1;
            if size > MODEL_CHARS {
                break;
            }
            shown.push(line);
        }
        let hidden = all.len() - shown.len() + self.omitted;
        if hidden > 0 {
            text.push_str(&format!("[{hidden} earlier lines not shown]\n"));
        }
        shown.reverse();
        text.push_str(&shown.join("\n"));
        if shown.is_empty() {
            text.push_str("(no output)");
        }
        let head_len = self.head.len();
        let lines: Vec<(u8, String)> = self.head.into_iter().chain(self.tail).collect();
        ToolResult::text(text).with_details(json!({
            "command": command,
            "title": title,
            "area": area,
            "effect": effect.as_str(),
            "sudo": sudo,
            "exitCode": f.exit_code,
            "timedOut": f.timed_out,
            "cancelled": f.cancelled,
            "durationMs": f.duration.as_millis() as u64,
            "lines": lines,
            "omitted": self.omitted,
            "omittedAt": head_len,
        }))
    }
}

// -----------------------------------------------------------------------------

struct ProposePlan {
    state: Arc<AppState>,
    flow: Option<Arc<Flow>>,
}

impl Tool for ProposePlan {
    fn def(&self) -> ToolDef {
        ToolDef {
            name: "propose_plan".into(),
            label: Some("Propose a plan".into()),
            description: "Show the person what you are about to change and wait for their answer. Required before any \
                change. Approved commands then run without asking again, exactly as written here."
                .into(),
            parameters: json!({
                "type": "object",
                "additionalProperties": false,
                "required": ["title", "summary", "steps"],
                "properties": {
                    "title": { "type": "string", "description": "What the plan does, in a few words." },
                    "summary": { "type": "string", "description": "Why, and what the person should know before approving, in one to three sentences." },
                    "steps": {
                        "type": "array", "minItems": 1, "maxItems": 12,
                        "items": {
                            "type": "object", "additionalProperties": false, "required": ["text"],
                            "properties": {
                                "text": { "type": "string", "description": "The step in plain words." },
                                "command": { "type": "string", "description": "The exact command it runs, if any, without sudo." }
                            }
                        }
                    }
                }
            }),
            sequential: true,
        }
    }

    fn execute(&self, call: ToolCall, _cancel: Cancel) -> BoxFuture<'_, Result<ToolResult, String>> {
        Box::pin(async move {
            let Some(flow) = self.flow.clone() else { return Err("not running".into()) };
            let hub = &self.state.agent;
            let steps: Vec<PlanStep> = serde_json::from_value::<Vec<PlanStep>>(call.args["steps"].clone())
                .map_err(|e| format!("steps: {e}"))?
                .into_iter()
                .map(|s| PlanStep {
                    text: first_line(&s.text, 300),
                    command: s.command.map(|c| c.trim().to_string()).filter(|c| !c.is_empty() && c.len() <= MAX_COMMAND),
                })
                .filter(|s| !s.text.is_empty())
                .take(12)
                .collect();
            if steps.is_empty() {
                return Err("a plan needs at least one step".into());
            }
            let title = first_line(&str_arg(&call.args, "title"), 80);
            let mut v = pending("confirm", &call, title.clone());
            v.summary = str_arg(&call.args, "summary").chars().take(1000).collect();
            v.steps = steps.clone();
            hub.note_area(&flow, "system", &title);
            hub.step_begin(&flow, &call.id, &title, "system");
            // The operator's rules and mode decide before the person does.
            let state = &self.state;
            let perms = permissions::load(&state.db).await.map_err(|e| format!("reading the permissions: {e}"))?;
            let verdicts: Vec<RuleVerdict> = steps.iter().filter_map(|s| s.command.as_deref()).map(|c| perms.rules.verdict(c)).collect();
            if let Some(RuleVerdict::Deny(rule)) = verdicts.iter().find(|v| matches!(v, RuleVerdict::Deny(_))) {
                hub.step_state(&flow, &call.id, "cancelled");
                return Ok(ToolResult::text(format!("Not approved: this machine's rule `{rule}` forbids a step. Leave it out or propose another way."))
                    .with_details(json!({ "decision": "refused", "rule": rule })));
            }
            let asks = verdicts.iter().any(|v| matches!(v, RuleVerdict::Ask(_)));
            let mode = perms.mode_for(flow.view.lock().unwrap().mode);
            match mode {
                Mode::Bypass if !asks => {
                    record(state, &flow.username, &format!("bypass: approved plan {title}"), Outcome::Ok).await;
                    hub.step_state(&flow, &call.id, "done");
                    hub.approve_commands(&flow, steps.iter().filter_map(|s| s.command.clone()));
                    return Ok(ToolResult::text("Approved (this task runs everything unasked). Carry out the steps now, in order, with exactly these commands.")
                        .with_details(json!({ "decision": "approved", "by": "bypass" })));
                }
                Mode::Auto if !asks => {
                    let subject: String = steps
                        .iter()
                        .enumerate()
                        .map(|(i, s)| format!("\n  {}. {}{}", i + 1, s.text, s.command.as_deref().map(|c| format!(" — `{c}`")).unwrap_or_default()))
                        .collect();
                    match judge(state, &flow, &format!("a plan of {} steps:{subject}", steps.len()), &title, "plan", false, &perms.auto_mode).await {
                        Some(Judgment::Allow) => {
                            record(state, &flow.username, &format!("auto: approved plan {title}"), Outcome::Ok).await;
                            hub.step_state(&flow, &call.id, "done");
                            hub.approve_commands(&flow, steps.iter().filter_map(|s| s.command.clone()));
                            return Ok(ToolResult::text("Approved by auto mode. Carry out the steps now, in order, with exactly these commands.")
                                .with_details(json!({ "decision": "approved", "by": "auto" })));
                        }
                        Some(Judgment::Block { rule, reason }) => {
                            record(state, &flow.username, &format!("auto: blocked plan [{rule}] {title}"), Outcome::Denied).await;
                            hub.step_state(&flow, &call.id, "cancelled");
                            let label = if rule.is_empty() { String::new() } else { format!(" [{rule}]") };
                            return Ok(ToolResult::text(format!(
                                "Not approved by auto mode{label}: {reason} Change nothing for it; tell the person, who can ask for it in their own words."
                            ))
                            .with_details(json!({ "decision": "blocked", "by": "auto", "rule": rule, "reason": reason })));
                        }
                        None => {}
                    }
                }
                _ => {}
            }
            let Some(answer) = hub.ask(&flow, v).await else {
                hub.step_state(&flow, &call.id, "cancelled");
                return cancelled();
            };
            hub.step_state(&flow, &call.id, if answer.action == "cancel" { "cancelled" } else { "done" });
            Ok(match answer.action.as_str() {
                "run" => {
                    hub.approve_commands(&flow, steps.iter().filter_map(|s| s.command.clone()));
                    ToolResult::text("Approved. Carry out the steps now, in order, with exactly these commands.")
                        .with_details(json!({ "decision": "approved" }))
                }
                "edit" => ToolResult::text(format!(
                    "Not approved. The person asks for changes: {}\nPropose a revised plan.",
                    answer.text.unwrap_or_default()
                ))
                .with_details(json!({ "decision": "edit" })),
                _ => ToolResult::text("The person cancelled the plan. Change nothing; say so in one sentence.")
                    .with_details(json!({ "decision": "cancelled" })),
            })
        })
    }
}

// -----------------------------------------------------------------------------

struct AskUser {
    state: Arc<AppState>,
    flow: Option<Arc<Flow>>,
}

impl Tool for AskUser {
    fn def(&self) -> ToolDef {
        ToolDef {
            name: "ask_user".into(),
            label: Some("Ask".into()),
            description: "Ask the person to choose when the request is ambiguous. They may also answer in their own words.".into(),
            parameters: json!({
                "type": "object",
                "additionalProperties": false,
                "required": ["question", "options"],
                "properties": {
                    "question": { "type": "string" },
                    "options": {
                        "type": "array", "minItems": 1, "maxItems": 6,
                        "items": {
                            "type": "object", "additionalProperties": false, "required": ["label"],
                            "properties": {
                                "label": { "type": "string" },
                                "hint": { "type": "string", "description": "What sets it apart, briefly: its state, its size." }
                            }
                        }
                    }
                }
            }),
            sequential: true,
        }
    }

    fn execute(&self, call: ToolCall, _cancel: Cancel) -> BoxFuture<'_, Result<ToolResult, String>> {
        Box::pin(async move {
            let Some(flow) = self.flow.clone() else { return Err("not running".into()) };
            let hub = &self.state.agent;
            let options: Vec<Choice> = serde_json::from_value::<Vec<Choice>>(call.args["options"].clone())
                .map_err(|e| format!("options: {e}"))?
                .into_iter()
                .map(|c| Choice { label: first_line(&c.label, 120), hint: c.hint.map(|h| first_line(&h, 160)).filter(|h| !h.is_empty()) })
                .filter(|c| !c.label.is_empty())
                .take(6)
                .collect();
            if options.is_empty() {
                return Err("give at least one option".into());
            }
            let question = first_line(&str_arg(&call.args, "question"), 300);
            let mut v = pending("clarify", &call, question.clone());
            v.options = options.clone();
            let area = flow_area(&flow);
            hub.step_begin(&flow, &call.id, &first_line(&question, 80), &area);
            let Some(answer) = hub.ask(&flow, v).await else {
                hub.step_state(&flow, &call.id, "cancelled");
                return cancelled();
            };
            hub.step_state(&flow, &call.id, if answer.action == "cancel" { "cancelled" } else { "done" });
            Ok(match answer.action.as_str() {
                "pick" => {
                    let pick = answer.index.and_then(|i| options.get(i)).map(|c| c.label.clone()).unwrap_or_default();
                    ToolResult::text(format!("The person chose: {pick}")).with_details(json!({ "answer": pick }))
                }
                "text" => {
                    let text = answer.text.unwrap_or_default();
                    ToolResult::text(format!("The person answered: {text}")).with_details(json!({ "answer": text }))
                }
                _ => ToolResult::text("The person did not answer. Stop here.").with_details(json!({ "answer": null })),
            })
        })
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    fn view(kind: &'static str) -> PendingView {
        let mut v = PendingView {
            id: "p".into(),
            kind,
            tool_call_id: "c".into(),
            title: "t".into(),
            summary: String::new(),
            steps: vec![],
            command: None,
            options: vec![Choice { label: "a".into(), hint: None }],
            alternatives: vec!["backup".into()],
            confirm_text: Some("t10".into()),
            user: None,
            error: None,
        };
        if kind != "clarify" {
            v.options.clear();
        }
        v
    }

    fn answer(action: &str) -> Answer {
        Answer { id: "p".into(), action: action.into(), text: None, index: None, password: None, remember: false, confirm: None }
    }

    #[test]
    fn a_danger_runs_only_with_the_name_typed() {
        assert_eq!(check_answer(&view("danger"), &answer("run")), Err("confirmMismatch"));
        let mut a = answer("run");
        a.confirm = Some("t10 ".into());
        assert_eq!(check_answer(&view("danger"), &a), Ok(()));
        a.confirm = Some("T10".into());
        assert_eq!(check_answer(&view("danger"), &a), Err("confirmMismatch"));
        let mut a = answer("alternative");
        a.index = Some(1);
        assert_eq!(check_answer(&view("danger"), &a), Err("invalidIndex"));
        a.index = Some(0);
        assert_eq!(check_answer(&view("danger"), &a), Ok(()));
    }

    #[test]
    fn an_answer_fits_what_was_asked() {
        assert_eq!(check_answer(&view("confirm"), &answer("run")), Ok(()));
        assert_eq!(check_answer(&view("confirm"), &answer("pick")), Err("invalidAction"));
        assert_eq!(check_answer(&view("confirm"), &answer("edit")), Err("emptyText"));
        assert_eq!(check_answer(&view("sudo"), &answer("run")), Err("invalidAction"));
        let mut a = answer("password");
        a.password = Some("a\nb".into());
        assert_eq!(check_answer(&view("sudo"), &a), Err("invalidPassword"));
        a.password = Some("hunter2".into());
        assert_eq!(check_answer(&view("sudo"), &a), Ok(()));
        let mut a = answer("pick");
        a.index = Some(0);
        assert_eq!(check_answer(&view("clarify"), &a), Ok(()));
        for kind in ["confirm", "danger", "sudo", "clarify"] {
            assert_eq!(check_answer(&view(kind), &answer("cancel")), Ok(()));
        }
    }

    #[test]
    fn the_higher_reading_counts() {
        let effect = |claimed: &str, cmd: &str| Effect::parse(claimed).max(Effect::of(command_risk::classify(cmd)));
        assert_eq!(effect("read", "df -h"), Effect::Read);
        assert_eq!(effect("read", "apt-get -y upgrade"), Effect::Change);
        assert_eq!(effect("read", "docker volume rm x"), Effect::Danger);
        assert_eq!(effect("read", "sleep 1"), Effect::Change);
        assert_eq!(effect("danger", "ls"), Effect::Danger);
        assert_eq!(effect("whatever", "ls"), Effect::Change);
    }
}
