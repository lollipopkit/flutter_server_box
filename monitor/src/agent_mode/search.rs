//! The desk's search, answered by the agent: what was typed is sorted by the
//! model into a lookup, a question or a change; then a session of its own
//! that only reads finds the things, answers the question, or drafts the
//! change as a plan, which runs only once the account carries it into a task
//! (`adopt`). Nothing a search runs changes the machine: every command must
//! read, by the model's word and by `command_risk::classify`.
//!
//! A search is a pi session with no `agent_flow` row; one not carried into a
//! task is deleted when the account searches again or after
//! [`KEEP_UNADOPTED`], and at start by `recover` like any session without a
//! row.

use std::sync::atomic::{AtomicUsize, Ordering};
use std::sync::Arc;
use std::time::{Duration, Instant};

use fl_pi_llm::host::{BoxFuture, Cancel, OpenSession, Tool, ToolCall, ToolDef, ToolResult};
use sbm_parser::command_risk::{self, CommandRisk};
use sbm_parser::command_rules::RuleVerdict;
use serde::Serialize;
use serde_json::{Value, json};
use tokio::sync::mpsc;

use super::command::{self, Stream};
use super::{AgentMode, FlowError, FlowView, PlanStep, config, first_line, prompt, uuid_v4};
use crate::api::authz;
use crate::api::server::AppState;
use crate::api::ws::audit::{Action, Event, Kind, Outcome};
use crate::core::permissions::Grant;

/// What a search was taken for.
#[derive(Debug, Clone, Copy, PartialEq, Eq, Serialize)]
#[serde(rename_all = "lowercase")]
pub enum SearchKind {
    /// A name or a term: find the things it names.
    Keyword,
    /// About the machine's state: answer it.
    Question,
    /// Asks for a change: draft it as a plan.
    Change,
}

impl SearchKind {
    pub fn parse(s: &str) -> Option<SearchKind> {
        match s.trim().to_ascii_lowercase().trim_matches(|c: char| !c.is_ascii_alphabetic()) {
            "keyword" => Some(SearchKind::Keyword),
            "question" => Some(SearchKind::Question),
            "change" => Some(SearchKind::Change),
            _ => None,
        }
    }
}

/// A search not carried into a task is deleted after this.
const KEEP_UNADOPTED: Duration = Duration::from_secs(60 * 60);
/// What one search command may take.
const COMMAND_TIMEOUT: Duration = Duration::from_secs(60);
/// Of a command's output, what the model is shown: the end.
const MODEL_CHARS: usize = 8000;
const MAX_ITEMS: usize = 12;
const MAX_FOLLOWUPS: usize = 3;
const MAX_COMMAND: usize = 4 << 10;

pub(super) struct SearchEntry {
    user: i64,
    query: String,
    created: Instant,
}

/// What a search sends its page, as it happens.
pub type SearchSink = mpsc::UnboundedSender<Value>;

impl AgentMode {
    /// Runs a search of [query] for [user], telling [sink] as it goes, until
    /// it is answered or [cancel] fires. [kind] skips the sorting.
    #[allow(clippy::too_many_arguments)]
    pub async fn search(
        self: &Arc<Self>,
        state: &Arc<AppState>,
        user: i64,
        username: &str,
        secure: bool,
        query: String,
        kind: Option<SearchKind>,
        sink: SearchSink,
        cancel: Cancel,
    ) -> Result<(), FlowError> {
        let started = Instant::now();
        let settings = config::load(&self.db).await?;
        let Some(model) = settings.model else { return Err(FlowError::NotConfigured) };
        let rt = self.runtime().await?;
        // One search at a time per account: a new one ends the last.
        let seq = self.search_seq.fetch_add(1, Ordering::Relaxed);
        if let Some((_, old)) = self.search_runs.lock().unwrap().insert(user, (seq, cancel.clone())) {
            old.cancel();
        }
        self.forget_searches(Some(user)).await;

        let kind = match kind {
            Some(k) => k,
            None => {
                let messages = json!([{ "role": "user", "content": [{ "type": "text", "text": query }], "timestamp": 0 }]);
                let reply = tokio::select! {
                    r = rt.complete(json!(model), messages, Some(prompt::SEARCH_KIND.into()), None) => r?,
                    _ = cancel.cancelled() => return Ok(()),
                };
                let text: String = reply["content"].as_array().into_iter().flatten().filter_map(|c| c["text"].as_str()).collect();
                SearchKind::parse(text.split_whitespace().next().unwrap_or("")).unwrap_or(SearchKind::Keyword)
            }
        };
        let _ = sink.send(json!({ "type": "kind", "kind": kind }));

        let id = uuid_v4();
        self.searches.lock().unwrap().insert(id.clone(), SearchEntry { user, query: query.clone(), created: Instant::now() });
        let run = Arc::new(Run { state: state.clone(), username: username.to_string(), secure, sink: sink.clone(), steps: AtomicUsize::new(0), cancel: cancel.clone() });
        let mut tools: Vec<Arc<dyn Tool>> = vec![Arc::new(ReadCommand(run.clone())), Arc::new(Report(run.clone()))];
        if kind == SearchKind::Change {
            tools.push(Arc::new(DraftPlan(run.clone())));
        }
        let mut system_prompt = prompt::search(kind, self.hostname(), username);
        if let Ok(Some(m)) = self.memory(user).prompt(false).await {
            system_prompt = format!("{system_prompt}\n\n{m}");
        }
        let session = {
            let _open = self.opening.lock().await;
            let (session, events) = rt
                .open_session(OpenSession {
                    id: id.clone(),
                    model: json!(model),
                    system_prompt,
                    tools,
                    approver: None,
                    thinking_level: Some("off".into()),
                    compaction: None,
                })
                .await?;
            forward(events, sink.clone());
            session
        };
        let outcome = tokio::select! {
            r = session.prompt(&query, None) => Some(r),
            _ = cancel.cancelled() => None,
        };
        if outcome.is_none() {
            let _ = session.abort().await;
        }
        let entries = session.entries().await.unwrap_or_default();
        {
            let _open = self.opening.lock().await;
            let _ = session.close().await;
        }
        if cancel.is_cancelled() {
            return Ok(());
        }
        match outcome {
            Some(Ok(r)) if r["status"] == "failed" => {
                let why = r["error"]["message"].as_str().unwrap_or("failed").to_string();
                let _ = sink.send(json!({ "type": "error", "message": why }));
            }
            Some(Err(e)) => {
                let _ = sink.send(json!({ "type": "error", "message": e.to_string() }));
            }
            _ => {
                let answer = entries
                    .iter()
                    .rev()
                    .find(|e| e["message"]["role"] == "assistant")
                    .map(|e| text_of(&e["message"]["content"]))
                    .unwrap_or_default();
                let _ = sink.send(json!({
                    "type": "done",
                    "id": id,
                    "answer": answer.trim(),
                    "steps": run.steps.load(Ordering::Relaxed),
                    "ms": started.elapsed().as_millis() as u64,
                }));
            }
        }
        let mut runs = self.search_runs.lock().unwrap();
        if runs.get(&user).is_some_and(|(s, _)| *s == seq) {
            runs.remove(&user);
        }
        Ok(())
    }

    /// Makes the search [id] of [user] a task, its conversation kept; then,
    /// with [text], runs it on in that task as a reply would.
    pub async fn adopt(
        self: &Arc<Self>,
        state: &Arc<AppState>,
        user: i64,
        username: &str,
        secure: bool,
        id: &str,
        text: Option<String>,
    ) -> Result<FlowView, FlowError> {
        let query = {
            let mut searches = self.searches.lock().unwrap();
            match searches.get(id) {
                Some(s) if s.user == user => searches.remove(id).map(|s| s.query).unwrap_or_default(),
                _ => return Err(FlowError::NotFound),
            }
        };
        let now = chrono::Utc::now().to_rfc3339();
        let title = first_line(&query, 80);
        let mode = super::permissions::load(&self.db).await?.default_mode;
        sqlx::query(
            "INSERT INTO agent_flow (id, user_id, title, status, line, areas, mode, created_at, updated_at, finished_at) \
             VALUES (?, ?, ?, 'done', '', '[]', ?, ?, ?, ?)",
        )
        .bind(id)
        .bind(user)
        .bind(&title)
        .bind(mode.as_str())
        .bind(&now)
        .bind(&now)
        .bind(&now)
        .execute(&self.db)
        .await?;
        let Some(view) = self.row(user, id).await? else { return Err(FlowError::NotFound) };
        self.emit(user, json!({ "type": "flow", "flow": view }));
        match text {
            Some(t) => self.reply(state, user, username, secure, id, t, Vec::new()).await,
            None => Ok(view),
        }
    }

    /// Deletes the searches nobody carried into a task: [user]'s, and
    /// everybody's older than [`KEEP_UNADOPTED`].
    async fn forget_searches(&self, user: Option<i64>) {
        let gone: Vec<String> = {
            let mut searches = self.searches.lock().unwrap();
            let ids: Vec<String> = searches
                .iter()
                .filter(|(_, s)| Some(s.user) == user || s.created.elapsed() > KEEP_UNADOPTED)
                .map(|(id, _)| id.clone())
                .collect();
            for id in &ids {
                searches.remove(id);
            }
            ids
        };
        if gone.is_empty() {
            return;
        }
        let Ok(rt) = self.runtime().await else { return };
        let _open = self.opening.lock().await;
        for id in gone {
            if let Err(e) = rt.delete_session(&id).await {
                tracing::debug!("agent mode: deleting the search {id}: {e}");
            }
        }
    }
}

fn text_of(content: &Value) -> String {
    content.as_array().into_iter().flatten().filter(|c| c["type"] == "text").filter_map(|c| c["text"].as_str()).collect()
}

/// The model's words as it writes them.
fn forward(mut events: mpsc::UnboundedReceiver<Value>, sink: SearchSink) {
    tokio::spawn(async move {
        while let Some(e) = events.recv().await {
            if e["type"] == "message_update" && e["event"]["type"] == "text_delta" {
                let _ = sink.send(json!({ "type": "delta", "text": e["event"]["delta"] }));
            } else if e["type"] == "message_start" && e["message"]["role"] == "assistant" {
                let _ = sink.send(json!({ "type": "said" }));
            }
        }
    });
}

/// What a search's tools share.
struct Run {
    state: Arc<AppState>,
    username: String,
    secure: bool,
    sink: SearchSink,
    steps: AtomicUsize,
    cancel: Cancel,
}

impl Run {
    async fn may_run(&self) -> Result<(), String> {
        let caller = authz::caller_named(&self.state, &self.username).await.ok_or("the account is gone")?;
        caller
            .check(Grant::Shell, &self.state, self.secure)
            .map_err(|why| format!("not permitted to run commands here ({})", why.as_str()))
    }
}

fn str_arg(args: &Value, key: &str) -> String {
    args[key].as_str().unwrap_or_default().trim().to_string()
}

/// `run_command`, reading only.
struct ReadCommand(Arc<Run>);

impl Tool for ReadCommand {
    fn def(&self) -> ToolDef {
        ToolDef {
            name: "run_command".into(),
            label: Some("Run a command".into()),
            description: "Run one non-interactive shell command that only reads (lists, shows, searches) and get its output. \
                Anything that would change the machine is refused here."
                .into(),
            parameters: json!({
                "type": "object",
                "additionalProperties": false,
                "required": ["command", "title"],
                "properties": {
                    "command": { "type": "string", "description": "The complete shell command; it must change nothing. No sudo." },
                    "title": { "type": "string", "description": "What this step looks at, in a few words, in the person's language." }
                }
            }),
            sequential: true,
        }
    }

    fn execute(&self, call: ToolCall, cancel: Cancel) -> BoxFuture<'_, Result<ToolResult, String>> {
        Box::pin(async move {
            let run = &self.0;
            let command = str_arg(&call.args, "command");
            if command.is_empty() || command.len() > MAX_COMMAND {
                return Err("command must be 1 to 4096 bytes".into());
            }
            // The operator's deny and ask rules hold here too; a search never asks.
            let perms = super::permissions::load(&run.state.db).await.map_err(|e| format!("reading the permissions: {e}"))?;
            match perms.rules.verdict(&command) {
                RuleVerdict::Deny(rule) => return Err(format!("Refused: this machine's rule `{rule}` forbids it.")),
                RuleVerdict::Ask(rule) => {
                    return Err(format!("Refused: this machine's rule `{rule}` asks the person first, and a search does not ask."));
                }
                _ => {}
            }
            if command_risk::classify(&command) != CommandRisk::ReadOnly {
                return Err("Search only reads, and this command is not known to only read. Leave it out; if it is needed, \
                    it belongs in the plan the person confirms in Agent mode."
                    .into());
            }
            run.may_run().await?;
            run.steps.fetch_add(1, Ordering::Relaxed);
            let _ = run.sink.send(json!({ "type": "step", "id": call.id, "command": command, "state": "running" }));
            Event::new(Kind::Agent, Action::Open, Outcome::Ok)
                .subject(&run.username)
                .detail(format!("search: run {}", first_line(&command, 200)))
                .record(&run.state.db)
                .await;
            let stop = Cancel::new();
            let (a, b, s) = (cancel.clone(), run.cancel.clone(), stop.clone());
            let watcher = tokio::spawn(async move {
                tokio::select! {
                    _ = a.cancelled() => {}
                    _ = b.cancelled() => {}
                }
                s.cancel();
            });
            let (tx, mut rx) = mpsc::unbounded_channel::<(Stream, String)>();
            let collect = tokio::spawn(async move {
                let mut out = Vec::new();
                let mut size = 0usize;
                while let Some((stream, text)) = rx.recv().await {
                    let line = if stream == Stream::Err { format!("[stderr] {text}") } else { text };
                    size += line.len() + 1;
                    out.push(line);
                    // The end is what the model is shown; keep a little more.
                    while size > MODEL_CHARS * 2 && out.len() > 1 {
                        size -= out.remove(0).len() + 1;
                    }
                }
                out
            });
            let finished = command::run(command::Spec { command: &command, sudo_password: None, timeout: COMMAND_TIMEOUT }, tx, &stop).await;
            watcher.abort();
            let lines = collect.await.map_err(|e| e.to_string())?;
            let finished = finished.map_err(|e| format!("could not start the command: {e}"))?;
            let ok = finished.exit_code == Some(0);
            let _ = run.sink.send(json!({ "type": "step", "id": call.id, "command": command, "state": if ok { "done" } else { "failed" } }));
            let mut text = match (finished.exit_code, finished.timed_out, finished.cancelled) {
                (_, true, _) => "Timed out; the command was stopped.\n".to_string(),
                (_, _, true) => "Stopped.\n".to_string(),
                (Some(c), _, _) => format!("exit code {c}\n"),
                (None, _, _) => "Killed by a signal.\n".to_string(),
            };
            let mut shown = Vec::new();
            let mut size = 0;
            for l in lines.iter().rev() {
                size += l.len() + 1;
                if size > MODEL_CHARS {
                    break;
                }
                shown.push(l.as_str());
            }
            shown.reverse();
            text.push_str(if shown.is_empty() { "(no output)" } else { "" });
            text.push_str(&shown.join("\n"));
            Ok(ToolResult::text(text).with_details(json!({ "command": command, "exitCode": finished.exit_code })))
        })
    }
}

/// `report_results`: the things found, and what the person might do next.
struct Report(Arc<Run>);

impl Tool for Report {
    fn def(&self) -> ToolDef {
        ToolDef {
            name: "report_results".into(),
            label: Some("Report what was found".into()),
            description: "Show the person what you found: the services, processes, files and containers concerned, and \
                at most three changes they might want next. Call it once, before your answer."
                .into(),
            parameters: json!({
                "type": "object",
                "additionalProperties": false,
                "required": ["items"],
                "properties": {
                    "items": {
                        "type": "array",
                        "maxItems": MAX_ITEMS,
                        "items": {
                            "type": "object",
                            "additionalProperties": false,
                            "required": ["kind", "title", "ref"],
                            "properties": {
                                "kind": { "type": "string", "enum": ["service", "process", "file", "container"] },
                                "title": { "type": "string", "description": "Its name as the person knows it." },
                                "sub": { "type": "string", "description": "One short line of facts: state, PID, size, image." },
                                "ref": { "type": "string", "description": "What identifies it: the unit name, the PID, the absolute path, the container name." }
                            }
                        }
                    },
                    "followups": {
                        "type": "array",
                        "maxItems": MAX_FOLLOWUPS,
                        "items": {
                            "type": "object",
                            "additionalProperties": false,
                            "required": ["label", "request"],
                            "properties": {
                                "label": { "type": "string", "description": "A button's words, two to four, in the person's language." },
                                "request": { "type": "string", "description": "The change, as the person would ask for it." }
                            }
                        }
                    }
                }
            }),
            sequential: false,
        }
    }

    fn execute(&self, call: ToolCall, _cancel: Cancel) -> BoxFuture<'_, Result<ToolResult, String>> {
        Box::pin(async move {
            let items: Vec<Value> = call.args["items"]
                .as_array()
                .into_iter()
                .flatten()
                .filter(|i| ["service", "process", "file", "container"].contains(&i["kind"].as_str().unwrap_or("")))
                .take(MAX_ITEMS)
                .map(|i| {
                    json!({
                        "kind": i["kind"],
                        "title": first_line(i["title"].as_str().unwrap_or(""), 120),
                        "sub": first_line(i["sub"].as_str().unwrap_or(""), 160),
                        "ref": first_line(i["ref"].as_str().unwrap_or(""), 500),
                    })
                })
                .collect();
            let followups: Vec<Value> = call.args["followups"]
                .as_array()
                .into_iter()
                .flatten()
                .take(MAX_FOLLOWUPS)
                .filter_map(|f| {
                    let label = first_line(f["label"].as_str()?, 40);
                    let request = first_line(f["request"].as_str()?, 500);
                    (!label.is_empty() && !request.is_empty()).then(|| json!({ "label": label, "request": request }))
                })
                .collect();
            let _ = self.0.sink.send(json!({ "type": "items", "items": items, "followups": followups }));
            Ok(ToolResult::text("Shown."))
        })
    }
}

/// `draft_plan`: a change, written down and not run.
struct DraftPlan(Arc<Run>);

impl Tool for DraftPlan {
    fn def(&self) -> ToolDef {
        ToolDef {
            name: "draft_plan".into(),
            label: Some("Draft the change".into()),
            description: "Write down the change the person asked for as numbered steps, each with its exact command when \
                there is one. Nothing is run: the person carries it into Agent mode to confirm it."
                .into(),
            parameters: json!({
                "type": "object",
                "additionalProperties": false,
                "required": ["steps"],
                "properties": {
                    "steps": {
                        "type": "array",
                        "minItems": 1,
                        "maxItems": 12,
                        "items": {
                            "type": "object",
                            "additionalProperties": false,
                            "required": ["text", "effect"],
                            "properties": {
                                "text": { "type": "string", "description": "The step, short: a command or what changes (`rotate 14 → rotate 7`)." },
                                "command": { "type": "string" },
                                "effect": { "type": "string", "enum": ["read", "change", "danger"] }
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
            let steps: Vec<Value> = call.args["steps"]
                .as_array()
                .into_iter()
                .flatten()
                .take(12)
                .filter_map(|s| {
                    let text = first_line(s["text"].as_str()?, 200);
                    if text.is_empty() {
                        return None;
                    }
                    let command = s["command"].as_str().map(|c| first_line(c, 2000)).filter(|c| !c.is_empty());
                    // The higher of the model's word and the command's shape.
                    let claimed = s["effect"].as_str().unwrap_or("change");
                    let shape = command.as_deref().map(command_risk::classify);
                    let effect = match (claimed, shape) {
                        (_, Some(CommandRisk::Destructive)) | ("danger", _) => "danger",
                        ("read", Some(CommandRisk::ReadOnly)) | ("read", None) => "read",
                        _ => "change",
                    };
                    let step = PlanStep { text, command };
                    Some(json!({ "text": step.text, "command": step.command, "effect": effect }))
                })
                .collect();
            if steps.is_empty() {
                return Err("steps is empty".into());
            }
            let _ = self.0.sink.send(json!({ "type": "plan", "steps": steps }));
            let mut r = ToolResult::text("Shown to the person. Nothing was run; they confirm it in Agent mode.");
            r.terminate = true;
            Ok(r)
        })
    }
}
