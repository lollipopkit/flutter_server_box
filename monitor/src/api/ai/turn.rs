//! Driving one turn: the model call, the calls it proposes, and who runs them.
//!
//! # A turn is a task, not a row
//!
//! Migration 011 says why: what a turn is *doing* cannot survive this process,
//! so nothing here is persisted except the items it produces. The registry
//! ([`AiTurns`]) holds the live turns so a second request can be refused —
//! enforced in memory rather than by a database constraint, which is the
//! opposite of migration 010's rule for benchmark runs, for the same reason:
//! a run is an `setsid` process that outlives the agent, a turn is a task that
//! cannot.
//!
//! # The awaiting-review state is derived, never stored
//!
//! A `function_call` with no `function_output` answering its `call_id` **is**
//! the state. Nothing here records "waiting for a person"; the page reads it
//! off the items, the agent reads it off the items, and the two cannot
//! disagree. What follows from it:
//!
//! - A turn **parks** when a call may not run unreviewed: it stores the calls
//!   and ends. The conversation is left with an unanswered call, which is the
//!   whole of what "awaiting review" means.
//! - Approving one call of a batch is not enough to resume. The model is
//!   handed a turn again only once *every* call in it has an answer — a
//!   request carrying a call with no result is one the API refuses, which is
//!   the app's rule and the reason this one exists.
//! - Declining answers the whole batch, because the batch is one proposal made
//!   in several parts and the user said no once.
//!
//! # What may run without being asked
//!
//! `auto_run_safe_commands && risk == ReadOnly`, at most [`MAX_AUTO_RUNS`]
//! times per turn. The classifier is `sbm_parser::ai_risk` and it is the whole
//! of the decision (`api::ai::tools` says why the model's own `safe_to_run` is
//! recorded and not consulted). The cap is what keeps a model that only ever
//! proposes read-only commands from looping unattended: at the fourth it parks
//! and waits for a person, and a person answering restarts the count — which is
//! the shape of the app's per-message cap, arrived at from the other side.

use std::collections::HashMap;
use std::sync::atomic::{AtomicBool, Ordering};
use std::sync::{Arc, Mutex as StdMutex};

use serde_json::{Value, json};
use sqlx::{Row, SqlitePool};
use tokio::sync::{Mutex, Notify};

use crate::api::ai::openai::{Chunk, Client, Step};
use crate::api::ai::tools::{self, Redactor};
use crate::api::exec::first_line;
use crate::api::server::AppState;
use crate::api::ws::audit::{Action, Event, Kind, Outcome};
use crate::core::config_file;

/// How many commands one turn may run without being asked about.
pub const MAX_AUTO_RUNS: u32 = 3;

/// The code a conversation's items are read from, and written to.
///
/// `arguments` is the model's JSON object verbatim — never re-serialised from
/// the fields parsed out of it, so what a reviewer is shown, what the tool is
/// handed and what the next request sends back are the same bytes.
#[derive(Debug, Clone)]
pub struct Item {
    pub ordinal: i64,
    pub created_at: String,
    pub kind: String,
    pub role: String,
    pub content: String,
    pub reasoning: String,
    pub call_id: Option<String>,
    pub tool: Option<String>,
    pub arguments: Option<String>,
    pub risk: Option<String>,
}

impl Item {
    /// A protocol item. `arguments` is a JSON object or nothing.
    pub fn new(kind: &str, role: &str, content: &str) -> Self {
        Self {
            ordinal: 0,
            created_at: String::new(),
            kind: kind.to_string(),
            role: role.to_string(),
            content: content.to_string(),
            reasoning: String::new(),
            call_id: None,
            tool: None,
            arguments: None,
            risk: None,
        }
    }

    pub fn reasoning(mut self, reasoning: &str) -> Self {
        self.reasoning = reasoning.to_string();
        self
    }

    pub fn risk(mut self, risk: &str) -> Self {
        self.risk = Some(risk.to_string());
        self
    }

    /// What this agent did with a call instead of running it, in the app's own
    /// envelope: `lib/data/model/ai/agent_conversation_replay.dart` writes the
    /// same object, and the sentence inside it is protocol — the model reads it
    /// as the call's result.
    pub fn action(kind: &str, call_id: &str, message: &str) -> Self {
        let mut item = Self::new("function_output", "", &json!({
            "server_box_action": kind,
            "message": message,
        })
        .to_string());
        item.call_id = Some(call_id.to_string());
        item
    }

    /// This agent saying why a turn stopped. **Never sent to the model**, which
    /// is why the content is a code and not a sentence: a client phrases it in
    /// the viewer's language.
    pub fn notice(code: &str) -> Self {
        Self::new("notice", "", code)
    }
}

/// The message a declined call carries back to the model.
///
/// The app's string, verbatim. It is a result the model reads, and a model told
/// only "no" tends to propose the same thing again.
pub const DECLINED_MESSAGE: &str =
    "The user declined this command. Do not assume it was executed.";

/// The notice code for a turn a person stopped.
pub const INTERRUPTED: &str = "interrupted";

/// The notice code that answers a call declined by a person.
pub const DECLINED: &str = "declined";

/// What a turn ended as.
enum Ended {
    /// A call is waiting for a person. The turn is over; the conversation is
    /// not.
    Parked,
    /// The model answered without asking for anything.
    Finished,
    Stopped,
    Failed(String),
}

/// What a follower reads while a turn is live.
#[derive(Debug, Clone, Default)]
pub struct Live {
    /// The ordinal the next stored item will get. Deltas are keyed by it, which
    /// is what lets a client drop its provisional text exactly when the stored
    /// item that supersedes it arrives.
    pub step: i64,
    pub content: String,
    pub reasoning: String,
    pub phase: Phase,
    /// A stable code, never a sentence.
    pub error: Option<String>,
}

impl Live {
    pub fn working(&self) -> bool {
        matches!(self.phase, Phase::Streaming | Phase::Executing)
    }
}

#[derive(Debug, Clone, Copy, Default, PartialEq, Eq)]
pub enum Phase {
    /// Nothing is running: either the turn is parked, or it is over. Which of
    /// the two is read off the items, not from here.
    #[default]
    Idle,
    Streaming,
    Executing,
}

impl Phase {
    pub fn as_str(self) -> &'static str {
        match self {
            Phase::Idle => "idle",
            Phase::Streaming => "streaming",
            Phase::Executing => "executing",
        }
    }
}

/// One live turn.
pub struct Turn {
    pub conversation: String,
    /// The caller who started it, for every audit row it writes.
    pub remote_ip: Option<String>,
    live: Mutex<Live>,
    stops: Notify,
    stopped: AtomicBool,
}

impl Turn {
    fn new(conversation: String, remote_ip: Option<String>) -> Self {
        Self {
            conversation,
            remote_ip,
            live: Mutex::new(Live::default()),
            stops: Notify::new(),
            stopped: AtomicBool::new(false),
        }
    }

    pub async fn snapshot(&self) -> Live {
        self.live.lock().await.clone()
    }

    /// Stops whatever this turn is doing. The turn answers the call it is in
    /// the middle of and then ends, rather than being killed: a task dropped
    /// mid-write would leave the conversation with a call that nothing can
    /// answer.
    pub fn stop(&self) {
        self.stopped.store(true, Ordering::SeqCst);
        self.stops.notify_one();
    }

    fn is_stopped(&self) -> bool {
        self.stopped.load(Ordering::SeqCst)
    }

    /// Starts a step: what streams from here belongs to `step`, which is the
    /// ordinal the item it becomes will carry.
    async fn begin(&self, step: i64) {
        let mut live = self.live.lock().await;
        live.step = step;
        live.content.clear();
        live.reasoning.clear();
        live.error = None;
        live.phase = Phase::Streaming;
    }

    /// Drops the streaming buffer once the step it holds has been stored.
    ///
    /// Without this a follower that connects between the store and the next
    /// `begin` — a window that includes a tool call, so seconds — is sent the
    /// same text twice: once as the stored item and once as the live buffer it
    /// is still looking at. The step goes to -1 rather than staying put because
    /// a follower keys its cursor by the step: an ordinal that no longer
    /// describes anything must not compare equal to one that does.
    async fn retire(&self) {
        let mut live = self.live.lock().await;
        live.step = -1;
        live.content.clear();
        live.reasoning.clear();
    }

    async fn phase(&self, phase: Phase) {
        self.live.lock().await.phase = phase;
    }

    async fn push(&self, chunk: &Chunk) {
        let mut live = self.live.lock().await;
        match chunk {
            Chunk::Content(text) => live.content.push_str(text),
            Chunk::Reasoning(text) => live.reasoning.push_str(text),
            _ => {}
        }
    }

    async fn settle(&self, error: Option<String>) {
        let mut live = self.live.lock().await;
        live.phase = Phase::Idle;
        live.content.clear();
        live.reasoning.clear();
        live.error = error;
    }
}

/// The turns this process has live, one per conversation.
#[derive(Default)]
pub struct AiTurns {
    inner: StdMutex<HashMap<String, Arc<Turn>>>,
}

impl AiTurns {
    /// Registers a turn and starts it. `false` means one is already live in
    /// this conversation, which the caller answers as `busy`.
    pub fn try_spawn(
        self: &Arc<Self>,
        state: Arc<AppState>,
        conversation: String,
        remote_ip: Option<String>,
    ) -> bool {
        let turn = {
            let mut inner = self.inner.lock().expect("turns lock");
            if inner.contains_key(&conversation) {
                return false;
            }
            let turn = Arc::new(Turn::new(conversation.clone(), remote_ip));
            inner.insert(conversation.clone(), turn.clone());
            turn
        };

        let turns = self.clone();
        tokio::spawn(async move {
            let ended = drive(&state, &turn).await;
            let notice = match &ended {
                Ended::Parked | Ended::Finished => None,
                Ended::Stopped => Some(INTERRUPTED.to_string()),
                Ended::Failed(code) => Some(code.clone()),
            };
            if let Some(code) = notice
                && let Err(e) = insert(&state.db, &conversation, &Item::notice(&code), 0).await
            {
                tracing::warn!("Could not record why a turn ended: {e}");
            }
            let error = match &ended {
                Ended::Failed(code) => Some(code.clone()),
                _ => None,
            };
            turn.settle(error).await;
            let mut inner = turns.inner.lock().expect("turns lock");
            // Identity, not the key: a turn that ended after a later one
            // started must not remove the later one.
            if inner.get(&conversation).is_some_and(|t| Arc::ptr_eq(t, &turn)) {
                inner.remove(&conversation);
            }
        });
        true
    }

    pub fn live(&self, conversation: &str) -> Option<Arc<Turn>> {
        self.inner.lock().expect("turns lock").get(conversation).cloned()
    }

    pub fn is_running(&self, conversation: &str) -> bool {
        self.inner.lock().expect("turns lock").contains_key(conversation)
    }
}

/// Reads a conversation's items, oldest first.
pub async fn items(db: &SqlitePool, conversation: &str) -> sqlx::Result<Vec<Item>> {
    let rows = sqlx::query(
        "SELECT ordinal, created_at, kind, role, content, reasoning, call_id, tool, \
                arguments, risk \
         FROM ai_message WHERE conversation_id = ? ORDER BY ordinal",
    )
    .bind(conversation)
    .fetch_all(db)
    .await?;
    Ok(rows.iter().map(row_to_item).collect())
}

/// Reads the items after a position, which is what the follow stream asks for.
pub async fn items_after(db: &SqlitePool, conversation: &str, after: i64) -> sqlx::Result<Vec<Item>> {
    let rows = sqlx::query(
        "SELECT ordinal, created_at, kind, role, content, reasoning, call_id, tool, \
                arguments, risk \
         FROM ai_message WHERE conversation_id = ? AND ordinal > ? ORDER BY ordinal",
    )
    .bind(conversation)
    .bind(after)
    .fetch_all(db)
    .await?;
    Ok(rows.iter().map(row_to_item).collect())
}

fn row_to_item(row: &sqlx::sqlite::SqliteRow) -> Item {
    Item {
        ordinal: row.get("ordinal"),
        created_at: row.get("created_at"),
        kind: row.get("kind"),
        role: row.get("role"),
        content: row.get("content"),
        reasoning: row.get("reasoning"),
        call_id: row.get("call_id"),
        tool: row.get("tool"),
        arguments: row.get("arguments"),
        risk: row.get("risk"),
    }
}

/// The ordinal the next item will get.
pub async fn next_ordinal(db: &SqlitePool, conversation: &str) -> sqlx::Result<i64> {
    let max: Option<i64> =
        sqlx::query_scalar("SELECT max(ordinal) FROM ai_message WHERE conversation_id = ?")
            .bind(conversation)
            .fetch_one(db)
            .await?;
    Ok(max.map_or(0, |m| m + 1))
}

/// Writes one item at a known position.
///
/// The caller holds the ordinal because a turn must know it *before* it
/// streams: a delta is keyed by the item it will become. Only one turn runs per
/// conversation, so nothing else is choosing one at the same time.
pub async fn insert(
    db: &SqlitePool,
    conversation: &str,
    item: &Item,
    ordinal: i64,
) -> sqlx::Result<()> {
    let created_at = chrono::Utc::now();
    sqlx::query(
        "INSERT INTO ai_message \
         (conversation_id, ordinal, created_at, kind, role, content, reasoning, call_id, tool, \
          arguments, risk) \
         VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)",
    )
    .bind(conversation)
    .bind(ordinal)
    .bind(created_at)
    .bind(&item.kind)
    .bind(&item.role)
    .bind(&item.content)
    .bind(&item.reasoning)
    .bind(item.call_id.as_deref())
    .bind(item.tool.as_deref())
    .bind(item.arguments.as_deref())
    .bind(item.risk.as_deref())
    .execute(db)
    .await?;
    Ok(())
}

/// Records that a conversation has moved: the list is ordered by it, and the
/// token counts are what the endpoint reported.
///
/// `model` is `None` for a change that did not come from the model — an
/// approval or a decline moves the conversation without anything having
/// answered, and passing `None` keeps the model that last did.
pub async fn touch(
    db: &SqlitePool,
    conversation: &str,
    model: Option<&str>,
    usage: Option<(u64, u64)>,
) -> sqlx::Result<()> {
    let (prompt, completion) = usage.unwrap_or((0, 0));
    sqlx::query(
        "UPDATE ai_conversation SET updated_at = ?, model = coalesce(?, model), \
         prompt_tokens = prompt_tokens + ?, completion_tokens = completion_tokens + ? \
         WHERE id = ?",
    )
    .bind(chrono::Utc::now())
    .bind(model)
    .bind(prompt as i64)
    .bind(completion as i64)
    .bind(conversation)
    .execute(db)
    .await?;
    Ok(())
}

/// Calls this turn produced that nothing has answered.
pub fn unanswered(items: &[Item]) -> Vec<&Item> {
    items
        .iter()
        .filter(|item| {
            item.kind == "function_call"
                && !items.iter().any(|other| {
                    other.kind == "function_output"
                        && other.call_id.is_some()
                        && other.call_id == item.call_id
                })
        })
        .collect()
}

/// [`unanswered`] asked in SQL: the call ids this conversation is waiting on.
///
/// The same predicate, in the language the follow stream can afford to ask on
/// every tick — it holds no item list to filter. Two expressions of one rule is
/// the shape that drifts, so `waiting_agrees_with_unanswered` asserts they
/// answer the same question over the same items.
pub async fn waiting(db: &SqlitePool, conversation: &str) -> sqlx::Result<Vec<String>> {
    let rows = sqlx::query(
        "SELECT m.call_id FROM ai_message m \
         WHERE m.conversation_id = ? AND m.kind = 'function_call' AND NOT EXISTS ( \
             SELECT 1 FROM ai_message o WHERE o.conversation_id = m.conversation_id \
             AND o.kind = 'function_output' AND o.call_id = m.call_id \
         ) ORDER BY m.ordinal",
    )
    .bind(conversation)
    .fetch_all(db)
    .await?;
    Ok(rows
        .iter()
        .filter_map(|row| row.get::<Option<String>, _>("call_id"))
        .collect())
}

/// The items as the endpoint takes them.
///
/// The app's `_chatMessages` with one absence: nothing here is a summary or a
/// compaction, since this agent keeps no summariser. `reasoning_content` goes
/// back for an assistant message that has one, which is what the app does and
/// what several compatible endpoints expect when it was streamed.
pub fn history(items: &[Item]) -> Vec<Value> {
    let mut messages: Vec<Value> = Vec::new();
    let mut index = 0;
    while index < items.len() {
        let item = &items[index];
        match item.kind.as_str() {
            "message" if item.role == "user" => {
                messages.push(json!({ "role": "user", "content": item.content }));
            }
            "message" => {
                let calls = calls_from(items, index + 1);
                index += calls.len();
                let mut message = json!({
                    "role": "assistant",
                    "content": if item.content.is_empty() { Value::Null } else { json!(item.content) },
                });
                if !item.reasoning.is_empty() {
                    message["reasoning_content"] = json!(item.reasoning);
                }
                if !calls.is_empty() {
                    message["tool_calls"] = json!(calls);
                }
                messages.push(message);
            }
            "function_call" => {
                let calls = calls_from(items, index);
                index += calls.len() - 1;
                messages.push(json!({
                    "role": "assistant",
                    "content": Value::Null,
                    "tool_calls": json!(calls),
                }));
            }
            "function_output" => {
                messages.push(json!({
                    "role": "tool",
                    "tool_call_id": item.call_id.clone().unwrap_or_default(),
                    "content": item.content,
                }));
            }
            // A notice is this agent speaking, never something the model said
            // or is told.
            _ => {}
        }
        index += 1;
    }
    messages
}

/// The run of `function_call` items starting at `from`, in the wire shape.
fn calls_from(items: &[Item], from: usize) -> Vec<Value> {
    items[from..]
        .iter()
        .take_while(|item| item.kind == "function_call")
        .map(|item| {
            json!({
                "id": item.call_id.clone().unwrap_or_default(),
                "type": "function",
                "function": {
                    "name": item.tool.clone().unwrap_or_default(),
                    "arguments": item.arguments.clone().unwrap_or_else(|| "{}".to_string()),
                },
            })
        })
        .collect()
}

/// The `[ai]` section as it is on disk now.
///
/// Fresh rather than from `AppState.config`, which is the startup snapshot: an
/// operator who has just saved an endpoint and a key expects the next message
/// to use them, and `GET /settings` reads the file for the same reason. The
/// snapshot is the fallback for a file that cannot be read right now.
/// The Agent's configuration as it is on disk right now.
///
/// Off disk rather than off `AppState.config`, which is a startup snapshot, for
/// `GET /push`'s reason: an endpoint or a key saved a moment ago must be what
/// the next message uses. The snapshot is the fallback for a file that cannot be
/// read at all, which is a state the agent already has an answer for.
pub(super) fn live_ai(state: &AppState) -> crate::core::config::AiConfig {
    config_file::read()
        .map(|config| config.get_ai())
        .unwrap_or_else(|_| state.config.get_ai())
}

/// Runs a turn to its end.
async fn drive(state: &Arc<AppState>, turn: &Arc<Turn>) -> Ended {
    let ai = live_ai(state);
    if !ai.is_configured() {
        return Ended::Failed("not_configured".to_string());
    }
    let client = Client {
        url: ai.endpoint(),
        model: ai.model.clone(),
        api_key: ai.api_key.clone(),
    };
    let redactor = Redactor::new(state);
    let tools = tools::definitions();
    let mut auto_runs: u32 = 0;

    loop {
        if turn.is_stopped() {
            return Ended::Stopped;
        }
        let items = match items(&state.db, &turn.conversation).await {
            Ok(items) => items,
            Err(e) => {
                tracing::warn!("Could not read a conversation: {e}");
                return Ended::Failed("storage".to_string());
            }
        };
        let step_index = items.iter().map(|item| item.ordinal).max().map_or(0, |m| m + 1);
        turn.begin(step_index).await;

        let mut step = Step::default();
        let mut stream = match client.stream(&history(&items), &tools).await {
            Ok(stream) => stream,
            Err(e) => return Ended::Failed(e.as_str().to_string()),
        };
        loop {
            let chunk = tokio::select! {
                biased;
                _ = turn.stops.notified() => return Ended::Stopped,
                next = stream.next() => match next {
                    Some(Ok(chunk)) => chunk,
                    Some(Err(e)) => return Ended::Failed(e.as_str().to_string()),
                    None => break,
                },
            };
            if step.absorb(chunk.clone()) {
                turn.push(&chunk).await;
            }
        }

        if let Err(e) = step.resolve() {
            return Ended::Failed(e.as_str().to_string());
        }
        if let Err(e) = store_step(state, turn, &step, step_index).await {
            tracing::warn!("Could not store a step: {e}");
            return Ended::Failed("storage".to_string());
        }
        // The buffer's text is now an item. Anything streaming from here belongs
        // to the step after it.
        turn.retire().await;
        if let Err(e) = touch(&state.db, &turn.conversation, Some(&client.model), step.usage).await {
            tracing::warn!("Could not update a conversation: {e}");
        }
        if !step.wants_calls() {
            return Ended::Finished;
        }

        for call in &step.calls {
            let arguments: Value =
                serde_json::from_str(&call.arguments).unwrap_or_else(|_| json!({}));
            let risk = tools::risk_of(&call.name, &arguments);
            if !(ai.auto_run_safe_commands && risk.is_read_only() && auto_runs < MAX_AUTO_RUNS) {
                // Parked. Every call left after this one is parked with it, and
                // the whole batch answers to one person.
                return Ended::Parked;
            }
            auto_runs += 1;
            turn.phase(Phase::Executing).await;
            let outcome = tools::execute(state, &call.name, &arguments, &redactor, &turn.stops).await;
            audit(
                state,
                turn.remote_ip.clone(),
                &call.name,
                &call.arguments,
                risk.as_str(),
                true,
            )
            .await;
            let mut item = Item::new("function_output", "", &outcome.message);
            item.call_id = Some(call.id.clone());
            let ordinal = match next_ordinal(&state.db, &turn.conversation).await {
                Ok(ordinal) => ordinal,
                Err(e) => {
                    tracing::warn!("Could not read a conversation's position: {e}");
                    return Ended::Failed("storage".to_string());
                }
            };
            if let Err(e) = insert(&state.db, &turn.conversation, &item, ordinal).await {
                tracing::warn!("Could not store a tool result: {e}");
                return Ended::Failed("storage".to_string());
            }
            if turn.is_stopped() {
                return Ended::Stopped;
            }
            turn.phase(Phase::Streaming).await;
        }
    }
}

/// Stores what one assistant step produced: its text, then its calls.
async fn store_step(
    state: &Arc<AppState>,
    turn: &Arc<Turn>,
    step: &Step,
    step_index: i64,
) -> sqlx::Result<()> {
    let mut ordinal = step_index;
    if !step.content.trim().is_empty() || !step.reasoning.trim().is_empty() {
        let item = Item::new("message", "assistant", &step.content).reasoning(&step.reasoning);
        insert(&state.db, &turn.conversation, &item, ordinal).await?;
        ordinal += 1;
    }
    for call in &step.calls {
        let arguments: Value = serde_json::from_str(&call.arguments).unwrap_or_else(|_| json!({}));
        let risk = tools::risk_of(&call.name, &arguments);
        let mut item = Item::new("function_call", "", "");
        item.call_id = Some(call.id.clone());
        item.tool = Some(call.name.clone());
        item.arguments = Some(call.arguments.clone());
        item.risk = Some(risk.as_str().to_string());
        insert(&state.db, &turn.conversation, &item, ordinal).await?;
        ordinal += 1;
    }
    Ok(())
}

/// One audit row per call.
///
/// The subject is the command text, as `Exec`'s is — read off the arguments the
/// model produced, so a row exists for a call that was reviewed and declined
/// too (`unreviewed: false`). Never the conversation, and never a file's
/// contents.
pub(super) async fn audit(
    state: &Arc<AppState>,
    remote_ip: Option<String>,
    tool: &str,
    arguments: &str,
    risk: &str,
    unreviewed: bool,
) {
    let command = serde_json::from_str::<Value>(arguments)
        .ok()
        .and_then(|value| value.get("command").and_then(Value::as_str).map(str::to_string))
        .unwrap_or_else(|| tool.to_string());
    Event::new(Kind::Ai, Action::Open, Outcome::Ok)
        .remote_ip(remote_ip)
        .subject(first_line(&command))
        .detail(format!(
            "risk={risk} unreviewed={}",
            if unreviewed { "yes" } else { "no" }
        ))
        .record(&state.db)
        .await;
}

#[cfg(test)]
mod tests {
    use super::*;

    fn item(kind: &str, role: &str, content: &str, call: Option<&str>) -> Item {
        let mut item = Item::new(kind, role, content);
        item.call_id = call.map(str::to_string);
        item
    }

    fn call(id: &str, tool: &str, arguments: &str) -> Item {
        let mut item = Item::new("function_call", "", "");
        item.call_id = Some(id.to_string());
        item.tool = Some(tool.to_string());
        item.arguments = Some(arguments.to_string());
        item
    }

    #[test]
    fn a_call_is_awaiting_review_until_its_own_output_arrives() {
        let asked = vec![
            item("message", "user", "check the disk", None),
            call("c1", "run_shell_command", r#"{"command":"df -h"}"#),
        ];
        assert_eq!(unanswered(&asked).len(), 1, "a call with no output awaits review");

        // Answering a *different* call is not answering this one — the ids are
        // the only thing that says which output belongs to which call.
        let mut wrong = asked.clone();
        wrong.push(item("function_output", "", "{}", Some("c2")));
        assert_eq!(unanswered(&wrong).len(), 1);

        let mut answered = asked.clone();
        answered.push(item("function_output", "", "{}", Some("c1")));
        assert!(unanswered(&answered).is_empty());

        // A notice answers nothing, whatever it says.
        let mut noticed = asked;
        noticed.push(Item::notice(DECLINED));
        assert_eq!(unanswered(&noticed).len(), 1);
    }

    #[test]
    fn a_batch_of_calls_is_each_awaiting_its_own_answer() {
        let items = vec![
            call("c1", "run_shell_command", "{}"),
            call("c2", "read_file", "{}"),
            call("c3", "read_file", "{}"),
            item("function_output", "", "{}", Some("c2")),
        ];
        let pending: Vec<&str> = unanswered(&items)
            .iter()
            .map(|item| item.call_id.as_deref().unwrap())
            .collect();
        assert_eq!(pending, ["c1", "c3"], "approving one moves to the next");
    }

    #[test]
    fn the_history_is_the_protocols_shape() {
        let items = vec![
            item("message", "user", "check the disk", None),
            Item::new("message", "assistant", "Looking.").reasoning("the disk is full"),
            call("c1", "run_shell_command", r#"{"command":"df -h"}"#),
            item("function_output", "", r#"{"exit_code":0}"#, Some("c1")),
            call("c2", "read_file", r#"{"path":"/etc/hosts"}"#),
            Item::notice(DECLINED),
        ];
        let messages = history(&items);

        assert_eq!(messages[0], json!({"role": "user", "content": "check the disk"}));
        let assistant = &messages[1];
        assert_eq!(assistant["role"], "assistant");
        assert_eq!(assistant["content"], "Looking.");
        assert_eq!(assistant["reasoning_content"], "the disk is full");
        // The text and the call it produced are one message, not two: the
        // protocol reads a call as part of the assistant turn that asked for it.
        assert_eq!(assistant["tool_calls"].as_array().unwrap().len(), 1);
        assert_eq!(assistant["tool_calls"][0]["id"], "c1");
        assert_eq!(assistant["tool_calls"][0]["function"]["name"], "run_shell_command");
        assert_eq!(
            assistant["tool_calls"][0]["function"]["arguments"],
            r#"{"command":"df -h"}"#
        );

        assert_eq!(messages[2]["role"], "tool");
        assert_eq!(messages[2]["tool_call_id"], "c1");
        assert_eq!(messages[2]["content"], r#"{"exit_code":0}"#);

        // A call with no assistant text of its own gets a message that carries
        // no content rather than an empty string.
        assert_eq!(messages[3]["content"], Value::Null);
        assert_eq!(messages[3]["tool_calls"][0]["id"], "c2");

        // The notice is this agent speaking. Four items plus one notice is four
        // messages, and the fifth being absent is the point.
        assert_eq!(messages.len(), 4, "{messages:#?}");
    }

    #[test]
    fn consecutive_calls_are_one_assistant_message() {
        let items = vec![
            call("c1", "read_file", r#"{"path":"/a"}"#),
            call("c2", "read_file", r#"{"path":"/b"}"#),
            item("function_output", "", "{}", Some("c1")),
            item("function_output", "", "{}", Some("c2")),
        ];
        let messages = history(&items);
        assert_eq!(messages.len(), 3, "{messages:#?}");
        assert_eq!(messages[0]["tool_calls"].as_array().unwrap().len(), 2);
        assert_eq!(messages[1]["role"], "tool");
        assert_eq!(messages[2]["role"], "tool");
    }

    #[test]
    fn a_call_with_no_arguments_is_an_object_not_a_missing_field() {
        // `arguments` is a JSON *string* on the wire. An empty column would be
        // sent as `""`, which some endpoints reject; `{}` is what a
        // no-argument call is.
        let mut items = vec![call("c1", "read_file", "")];
        items[0].arguments = None;
        let messages = history(&items);
        assert_eq!(messages[0]["tool_calls"][0]["function"]["arguments"], "{}");
    }
}
