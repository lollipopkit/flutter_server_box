//! `/api/v1/ai/*` — the Agent: a conversation with a model that can run things
//! on this machine.
//!
//! # Why the loop runs here and not in the browser
//!
//! A tool call is a command run as the agent's account, and the model's key is
//! the agent's. Both would have to be handed to a browser for it to drive the
//! loop: the key would sit in page memory for the length of a conversation, and
//! every command would be a request a client composed. Here the key never leaves
//! the machine it is stored on, and the panel sends a sentence — it never composes
//! a command, never sees the tool schema, and cannot ask for a call that the
//! classifier did not classify. `openai` holds the client, `tools` the three
//! tools and their risk, `turn` the loop.
//!
//! # Authority
//!
//! Reading needs only the panel login: a conversation is a record of what this
//! agent did, like a benchmark's history or a crontab. Sending, approving,
//! declining, renaming, removing and saving the settings need `full_access`, the
//! same grant the shell, `/exec` and `/power` need — an approved call runs a
//! command, and a `shell` tool call is a shell.
//!
//! **`stop` is the one action answered before that gate.** It starts nothing and
//! ends something, and the case it must survive is an operator revoking
//! `full_access` while a turn is running: the revocation is a decision that the
//! agent's account should not be running anything, and a stop that the revocation
//! itself made unreachable would leave the turn going.
//!
//! # The awaiting-review state is derived, never stored
//!
//! A `function_call` item with no `function_output` answering its `call_id` is
//! what the panel draws buttons for. `turn::waiting` is that question, and
//! `turn::unanswered` is the same one over an item list; the actions use the
//! second, the follow stream and the detail response use the first. Nothing
//! records a turn's state, so a restart cannot leave a conversation claiming to
//! be mid-turn.
//!
//! # The wire
//!
//! `GET /ai/conversations` reads the list or, with `?conversation=`, one
//! conversation with all its items. `POST /ai/conversations` is one action —
//! `chat`, `approve`, `decline`, `stop`, `rename`. `DELETE` removes one.
//! `GET /ai/follow` is NDJSON, one frame per line, so a follower sees items and
//! streaming text as they happen without polling:
//!
//! - `{"type":"item","item":{…}}` — an item that was stored, after the caller's
//!   `?after=`.
//! - `{"type":"delta","step":N,"content":"…","reasoning":"…"}` — text that is
//!   not an item yet. `step` is the ordinal it will get, which is what lets a
//!   client drop its provisional text exactly when the item supersedes it.
//! - `{"type":"state","running":bool,"phase":…,"error":…,"waiting":[ids]}` —
//!   sent when any of those changes, and once at the start.
//! - `{"type":"ping"}` — a heartbeat, so a proxy does not close an idle stream.
//!
//! A refusal is a stable code, phrased by the client in the viewer's language:
//! `invalid_base_url`, `empty_message`, `message_too_long`, `invalid_title`,
//! `not_configured`, `busy`, `no_such_conversation`, `no_such_call`,
//! `nothing_to_decline`. A failure inside a turn is a `notice` item carrying a
//! code from the same vocabulary (`unreachable`, `auth`, `rate_limited`,
//! `storage`, …).

pub mod openai;
pub mod tools;
pub mod turn;

use std::sync::Arc;
use std::time::Duration;

use ntex::util::Bytes;
use ntex::web::{self, HttpRequest, HttpResponse};
use serde::{Deserialize, Serialize};
use serde_json::{Value, json};

use super::server::AppState;
use super::server::verify_auth;
use super::ws;
use super::ws::audit::{Action, Event, Kind, Outcome, peer_ip};

use self::turn::Item;
use crate::core::config::{AiConfig, Config};
use crate::core::config_file;
use crate::utils::secrets::random_hex;

/// How many conversations the list returns. The app keeps no cap and a
/// conversation is not pruned, so this is the endpoint's own bound on a
/// response.
const HISTORY_LIMIT: i64 = 100;

/// The longest message accepted. Well under ntex's 32 KiB body default, which
/// is what actually bounds the request; this is the number a caller is told.
const MESSAGE_LIMIT: usize = 16 * 1024;

/// The longest title accepted, and what a generated one is cut to.
const TITLE_LIMIT: usize = 120;

/// How often the follow loop looks for something new. A turn's text arrives in
/// tokens; 400 ms is below what anyone reads and is one small query per tick.
const FOLLOW_TICK: Duration = Duration::from_millis(400);

/// How long the follow stream may go quiet before it sends a `ping`. Under the
/// 60 s idle timeouts a reverse proxy commonly applies.
const PING_INTERVAL: Duration = Duration::from_secs(15);

#[derive(Serialize)]
struct ErrorResponse {
    error: String,
}

fn bad_request(error: impl Into<String>) -> HttpResponse {
    HttpResponse::BadRequest().json(&ErrorResponse { error: error.into() })
}

fn conflict(error: impl Into<String>) -> HttpResponse {
    HttpResponse::Conflict().json(&ErrorResponse { error: error.into() })
}

fn not_found(error: impl Into<String>) -> HttpResponse {
    HttpResponse::NotFound().json(&ErrorResponse { error: error.into() })
}

fn internal_error(error: impl Into<String>) -> HttpResponse {
    HttpResponse::InternalServerError().json(&ErrorResponse { error: error.into() })
}

// --- Settings ---

#[derive(Serialize)]
struct SettingsView {
    /// An endpoint and a model. What a client checks before offering to send.
    configured: bool,
    base_url: String,
    model: String,
    /// Always `null`. The key is write-only: this field exists so that a client
    /// round-tripping this view hands back a `null` that means "keep what is
    /// stored" rather than omitting a field it never saw.
    api_key: Option<String>,
    /// Whether one is stored. A boolean rather than the value, and the one bit
    /// that separates "leave this blank to keep it" from "there is none".
    api_key_set: bool,
    auto_run_safe_commands: bool,
    /// Whether this caller may save. Reading is the panel login; saving is
    /// `full_access`.
    editable: bool,
}

impl SettingsView {
    fn of(ai: &AiConfig, editable: bool) -> Self {
        Self {
            configured: ai.is_configured(),
            base_url: ai.base_url.clone(),
            model: ai.model.clone(),
            api_key: None,
            api_key_set: ai.api_key.as_deref().is_some_and(|key| !key.is_empty()),
            auto_run_safe_commands: ai.auto_run_safe_commands,
            editable,
        }
    }
}

/// A base URL a request can actually be sent to.
///
/// A URL rather than "not empty": an operator who mistypes a scheme would
/// otherwise get a conversation that fails on every message with the same
/// `unreachable`, a minute after the mistake instead of at the save.
fn validate_base_url(value: &str) -> Result<(), &'static str> {
    let Ok(url) = reqwest::Url::parse(value) else {
        return Err("invalid_base_url");
    };
    if !matches!(url.scheme(), "http" | "https") {
        return Err("invalid_base_url");
    }
    if url.host_str().is_none_or(str::is_empty) {
        return Err("invalid_base_url");
    }
    Ok(())
}

/// The saved settings.
///
/// Off disk rather than off `AppState.config`, which is a startup snapshot —
/// `GET /push`'s reason: a GET right after a save must show what was saved.
async fn read_settings() -> Result<Config, HttpResponse> {
    match config_file::read() {
        Ok(config) => Ok(config),
        Err(e) => {
            tracing::warn!("ai: could not read the config: {e}");
            Err(internal_error("config_unavailable"))
        }
    }
}

pub async fn get_settings(
    req: HttpRequest,
    app_state: web::types::State<Arc<AppState>>,
) -> Result<HttpResponse, web::Error> {
    if verify_auth(&req, &app_state.config.get_jwt_secret()).is_err() {
        return Ok(HttpResponse::Unauthorized().finish());
    }
    let secure = ws::is_secure_transport(&req, app_state.tls_active);
    let editable = app_state.full_access_allowed(secure);
    match read_settings().await {
        Ok(config) => Ok(HttpResponse::Ok().json(&SettingsView::of(&config.get_ai(), editable))),
        Err(response) => Ok(response),
    }
}

#[derive(Deserialize)]
pub struct ReplaceRequest {
    base_url: String,
    model: String,
    /// `null` (or absent) keeps what is stored, an empty string clears it,
    /// anything else replaces it — the push convention, one field wide.
    #[serde(default)]
    api_key: Option<String>,
    #[serde(default)]
    auto_run_safe_commands: bool,
}

pub async fn replace_settings(
    req: HttpRequest,
    body: web::types::Json<ReplaceRequest>,
    app_state: web::types::State<Arc<AppState>>,
) -> Result<HttpResponse, web::Error> {
    if verify_auth(&req, &app_state.config.get_jwt_secret()).is_err() {
        return Ok(HttpResponse::Unauthorized().finish());
    }
    let remote_ip = peer_ip(&req);
    let secure = ws::is_secure_transport(&req, app_state.tls_active);
    if !app_state.full_access_allowed(secure) {
        Event::new(Kind::Ai, Action::Denied, Outcome::Denied)
            .remote_ip(remote_ip)
            .detail("full access disabled")
            .record(&app_state.db)
            .await;
        return Ok(HttpResponse::Forbidden().finish());
    }

    let ReplaceRequest {
        base_url,
        model,
        api_key,
        auto_run_safe_commands,
    } = body.into_inner();
    if let Err(code) = validate_base_url(&base_url) {
        return Ok(bad_request(code));
    }

    // The file's own lock, not the turn one: this reads and rewrites
    // `config.toml`, which `/settings`, `/push` and `/desktop` also do.
    let _config_guard = app_state.config_write.lock().await;
    let mut config = match read_settings().await {
        Ok(config) => config,
        Err(response) => return Ok(response),
    };
    let stored = config.get_ai();
    let api_key = match api_key {
        // Absent or `null`: keep. Matching push's rule, which exists so that a
        // client that cannot read a credential cannot clear it by accident.
        None => stored.api_key.clone(),
        Some(key) if key.is_empty() => None,
        Some(key) => Some(key),
    };
    let ai = AiConfig {
        base_url: base_url.trim().to_string(),
        model: model.trim().to_string(),
        api_key,
        auto_run_safe_commands,
    };
    config.ai = Some(ai.clone());
    if let Err(e) = config_file::write(&config) {
        tracing::warn!("ai: could not write the config: {e}");
        return Ok(internal_error("config_unavailable"));
    }

    // The key itself is never in the row, and neither is the model: the subject
    // is what kind of change this was.
    Event::new(Kind::Ai, Action::Write, Outcome::Ok)
        .remote_ip(remote_ip)
        .subject("settings")
        .detail(format!(
            "auto_run_safe_commands={} api_key={}",
            ai.auto_run_safe_commands,
            if ai.api_key.is_some() { "set" } else { "none" }
        ))
        .record(&app_state.db)
        .await;

    Ok(HttpResponse::Ok().json(&SettingsView::of(&ai, true)))
}

// --- Conversations, reading ---

/// A conversation as a list row. No items: the list is what identifies one.
#[derive(Serialize)]
struct ConversationView {
    id: String,
    title: String,
    model: String,
    created_at: String,
    updated_at: String,
    prompt_tokens: i64,
    completion_tokens: i64,
    /// A call nobody has answered — what the row shows instead of a status.
    awaiting_review: bool,
    /// A turn is running in this conversation right now.
    running: bool,
}

/// An item as the panel draws it.
///
/// `arguments` is the model's JSON **as the text it produced**, never a
/// re-serialisation of the fields parsed out of it: the same bytes the tool was
/// handed and the same bytes a reviewer reads. A client that wants to draw
/// `arguments.command` parses for display, and nothing it sends back is built
/// from the parse.
#[derive(Serialize)]
struct ItemView {
    ordinal: i64,
    created_at: String,
    kind: String,
    role: String,
    content: String,
    reasoning: String,
    call_id: Option<String>,
    tool: Option<String>,
    arguments: Option<String>,
    /// [`sbm_parser::ai_risk::CommandRisk`] as it was decided when the call was
    /// created — what the reviewer was shown and what decided whether it ran
    /// unreviewed.
    risk: Option<String>,
}

impl ItemView {
    fn of(item: &Item) -> Self {
        Self {
            ordinal: item.ordinal,
            created_at: item.created_at.clone(),
            kind: item.kind.clone(),
            role: item.role.clone(),
            content: item.content.clone(),
            reasoning: item.reasoning.clone(),
            call_id: item.call_id.clone(),
            tool: item.tool.clone(),
            // Verbatim. Another read from the database, since `Item` is moved
            // into the response below — the alternative is cloning the whole
            // item to borrow one field.
            arguments: item.arguments.clone(),
            risk: item.risk.clone(),
        }
    }
}

#[derive(Serialize)]
struct LiveView {
    /// The ordinal the text on screen will become an item with. `null` once the
    /// step has been stored: the text is an item now, and this one no longer
    /// names anything.
    step: Option<i64>,
    content: String,
    reasoning: String,
    phase: &'static str,
    /// A stable code, never a sentence.
    error: Option<String>,
}

#[derive(Deserialize)]
pub struct GetQuery {
    /// One conversation in full. Absent asks for the list.
    #[serde(default)]
    conversation: Option<String>,
}

#[derive(Serialize)]
struct ListResponse {
    conversations: Vec<ConversationView>,
    editable: bool,
}

#[derive(Serialize)]
struct DetailResponse {
    conversation: ConversationView,
    items: Vec<ItemView>,
    /// What is streaming right now, if anything. Read from memory rather than
    /// from the items: a turn's own state is not stored anywhere.
    live: Option<LiveView>,
    /// The call ids this conversation is waiting on. The same list the follow
    /// stream's `state` frame carries — see this module's header.
    waiting: Vec<String>,
    editable: bool,
}

pub async fn get_conversations(
    req: HttpRequest,
    query: web::types::Query<GetQuery>,
    app_state: web::types::State<Arc<AppState>>,
) -> Result<HttpResponse, web::Error> {
    if verify_auth(&req, &app_state.config.get_jwt_secret()).is_err() {
        return Ok(HttpResponse::Unauthorized().finish());
    }
    let secure = ws::is_secure_transport(&req, app_state.tls_active);
    let editable = app_state.full_access_allowed(secure);
    match query.conversation.as_deref().filter(|id| !id.is_empty()) {
        Some(id) => detail(&app_state, id, editable).await,
        None => list(&app_state, editable).await,
    }
}

async fn list(app_state: &AppState, editable: bool) -> Result<HttpResponse, web::Error> {
    let rows = match sqlx::query(
        "SELECT c.id, c.title, c.model, c.created_at, c.updated_at, c.prompt_tokens, \
                c.completion_tokens, \
                EXISTS ( \
                    SELECT 1 FROM ai_message m WHERE m.conversation_id = c.id \
                    AND m.kind = 'function_call' AND NOT EXISTS ( \
                        SELECT 1 FROM ai_message o WHERE o.conversation_id = c.id \
                        AND o.kind = 'function_output' AND o.call_id = m.call_id \
                    ) \
                ) AS awaiting_review \
         FROM ai_conversation c ORDER BY c.updated_at DESC LIMIT ?",
    )
    .bind(HISTORY_LIMIT)
    .fetch_all(&app_state.db)
    .await
    {
        Ok(rows) => rows,
        Err(e) => {
            tracing::warn!("ai: could not read the conversations: {e}");
            return Ok(internal_error("storage"));
        }
    };

    use sqlx::Row;
    Ok(HttpResponse::Ok().json(&ListResponse {
        conversations: rows
            .iter()
            .map(|row| {
                let id: String = row.get("id");
                ConversationView {
                    running: app_state.ai_turns.is_running(&id),
                    awaiting_review: row.get::<i64, _>("awaiting_review") != 0,
                    id,
                    title: row.get("title"),
                    model: row.get("model"),
                    created_at: row.get("created_at"),
                    updated_at: row.get("updated_at"),
                    prompt_tokens: row.get("prompt_tokens"),
                    completion_tokens: row.get("completion_tokens"),
                }
            })
            .collect(),
        editable,
    }))
}

async fn conversation_row(app_state: &AppState, id: &str) -> Option<ConversationView> {
    use sqlx::Row;
    let row = sqlx::query(
        "SELECT id, title, model, created_at, updated_at, prompt_tokens, completion_tokens \
         FROM ai_conversation WHERE id = ?",
    )
    .bind(id)
    .fetch_optional(&app_state.db)
    .await
    .ok()
    .flatten()?;
    Some(ConversationView {
        running: app_state.ai_turns.is_running(id),
        awaiting_review: false,
        id: row.get("id"),
        title: row.get("title"),
        model: row.get("model"),
        created_at: row.get("created_at"),
        updated_at: row.get("updated_at"),
        prompt_tokens: row.get("prompt_tokens"),
        completion_tokens: row.get("completion_tokens"),
    })
}

async fn detail(
    app_state: &AppState,
    id: &str,
    editable: bool,
) -> Result<HttpResponse, web::Error> {
    let Some(mut conversation) = conversation_row(app_state, id).await else {
        return Ok(not_found("no_such_conversation"));
    };
    let items = match turn::items(&app_state.db, id).await {
        Ok(items) => items,
        Err(e) => {
            tracing::warn!("ai: could not read a conversation: {e}");
            return Ok(internal_error("storage"));
        }
    };
    let waiting = match turn::waiting(&app_state.db, id).await {
        Ok(waiting) => waiting,
        Err(e) => {
            tracing::warn!("ai: could not read what a conversation is waiting on: {e}");
            return Ok(internal_error("storage"));
        }
    };
    conversation.awaiting_review = !waiting.is_empty();
    let live = match app_state.ai_turns.live(id) {
        Some(turn) => {
            let live = turn.snapshot().await;
            Some(LiveView {
                step: (live.step >= 0).then_some(live.step),
                content: live.content,
                reasoning: live.reasoning,
                phase: live.phase.as_str(),
                error: live.error,
            })
        }
        None => None,
    };

    Ok(HttpResponse::Ok().json(&DetailResponse {
        conversation,
        items: items.iter().map(ItemView::of).collect(),
        live,
        waiting,
        editable,
    }))
}

// --- Conversations, writing ---

#[derive(Deserialize)]
#[serde(tag = "action", rename_all = "snake_case")]
pub enum AiAction {
    /// A message and, unless it names one, a new conversation.
    Chat {
        #[serde(default)]
        conversation: Option<String>,
        message: String,
    },
    /// Runs the call a person approved. The whole batch is not approved at
    /// once: each call is answered on its own, so a reviewer who approves the
    /// first of three is shown the second next.
    Approve { conversation: String, call_id: String },
    /// Answers every call this conversation is waiting on with a refusal the
    /// model reads, then resumes.
    Decline { conversation: String },
    Stop { conversation: String },
    Rename { conversation: String, title: String },
}

#[derive(Serialize)]
struct ActResponse {
    /// The conversation the action applied to. For a `chat` that started one,
    /// the id it was created with.
    conversation: String,
    /// Whether a turn is running now, which is what the caller draws from: a
    /// `stop` that found nothing, or an approval that answered the last call of
    /// a batch and resumed, both answer here.
    running: bool,
    /// What an `approve` did, for the caller that wants to say so before the
    /// model answers. Absent for every other action.
    #[serde(skip_serializing_if = "Option::is_none")]
    result: Option<CallResult>,
}

#[derive(Serialize)]
struct CallResult {
    ok: bool,
    summary: String,
}

pub async fn act(
    req: HttpRequest,
    body: web::types::Json<AiAction>,
    app_state: web::types::State<Arc<AppState>>,
) -> Result<HttpResponse, web::Error> {
    if verify_auth(&req, &app_state.config.get_jwt_secret()).is_err() {
        return Ok(HttpResponse::Unauthorized().finish());
    }
    let action = body.into_inner();
    let remote_ip = peer_ip(&req);
    let state = Arc::clone(&app_state);

    // Answered before the gate, and for the reason this module's header gives:
    // a revocation that made the stop unreachable would leave the turn running.
    if let AiAction::Stop { conversation } = &action {
        return Ok(stop(&state, conversation));
    }

    let secure = ws::is_secure_transport(&req, app_state.tls_active);
    if !app_state.full_access_allowed(secure) {
        Event::new(Kind::Ai, Action::Denied, Outcome::Denied)
            .remote_ip(remote_ip)
            .detail("full access disabled")
            .record(&app_state.db)
            .await;
        return Ok(HttpResponse::Forbidden().finish());
    }

    match action {
        AiAction::Chat {
            conversation,
            message,
        } => chat(&state, conversation, message, remote_ip).await,
        AiAction::Approve {
            conversation,
            call_id,
        } => approve(&state, &conversation, &call_id, remote_ip).await,
        AiAction::Decline { conversation } => decline(&state, &conversation, remote_ip).await,
        AiAction::Rename { conversation, title } => rename(&state, &conversation, title).await,
        AiAction::Stop { conversation } => Ok(stop(&state, &conversation)),
    }
}

/// Ends whatever is running. Idempotent: nothing running is not an error.
fn stop(state: &Arc<AppState>, conversation: &str) -> HttpResponse {
    if let Some(turn) = state.ai_turns.live(conversation) {
        turn.stop();
    }
    HttpResponse::Ok().json(&ActResponse {
        conversation: conversation.to_string(),
        running: state.ai_turns.is_running(conversation),
        result: None,
    })
}

/// The title a conversation gets when nobody names it: the first line of the
/// first message, cut. Both clients then read the same name for the same
/// conversation without either having named it.
fn derived_title(message: &str) -> String {
    let line = message
        .lines()
        .map(str::trim)
        .find(|line| !line.is_empty())
        .unwrap_or("");
    line.chars().take(TITLE_LIMIT).collect()
}

async fn chat(
    state: &Arc<AppState>,
    conversation: Option<String>,
    message: String,
    remote_ip: Option<String>,
) -> Result<HttpResponse, web::Error> {
    let text = message.trim();
    if text.is_empty() {
        return Ok(bad_request("empty_message"));
    }
    if text.len() > MESSAGE_LIMIT {
        return Ok(bad_request("message_too_long"));
    }

    // Held across the whole read-modify-write of the conversation's items: what
    // it protects is the pair "the message is stored" and "a turn answers it",
    // which a second action arriving between them would break — one message
    // would sit in the log with nothing to reply to it. It is also held across
    // a tool call in `approve`, so a second action waits rather than racing.
    let _guard = state.ai_actions.lock().await;

    let ai = turn::live_ai(state);
    if !ai.is_configured() {
        return Ok(bad_request("not_configured"));
    }

    let id = match conversation {
        Some(id) => {
            if conversation_row(state, &id).await.is_none() {
                return Ok(not_found("no_such_conversation"));
            }
            id
        }
        None => {
            let id = match random_hex(16) {
                Ok(id) => id,
                Err(e) => {
                    tracing::warn!("ai: could not generate a conversation id: {e}");
                    return Ok(internal_error("storage"));
                }
            };
            if !create_conversation(state, &id, &derived_title(text)).await {
                return Ok(internal_error("storage"));
            }
            id
        }
    };

    if state.ai_turns.is_running(&id) {
        return Ok(conflict("busy"));
    }

    let ordinal = match turn::next_ordinal(&state.db, &id).await {
        Ok(ordinal) => ordinal,
        Err(e) => {
            tracing::warn!("ai: could not read a conversation's position: {e}");
            return Ok(internal_error("storage"));
        }
    };
    if let Err(e) = turn::insert(&state.db, &id, &Item::new("message", "user", text), ordinal).await
    {
        tracing::warn!("ai: could not store a message: {e}");
        return Ok(internal_error("storage"));
    }
    if let Err(e) = turn::touch(&state.db, &id, None, None).await {
        tracing::warn!("ai: could not update a conversation: {e}");
    }

    // Unreachable while every action that can register a turn holds
    // `ai_actions`, which this one does. Answered rather than unwrapped so a
    // caller that later forgets the lock gets a refusal instead of a message
    // stored with no turn to answer it.
    if !state.ai_turns.try_spawn(state.clone(), id.clone(), remote_ip) {
        return Ok(internal_error("turn_not_started"));
    }

    Ok(HttpResponse::Ok().json(&ActResponse {
        conversation: id,
        running: true,
        result: None,
    }))
}

async fn create_conversation(state: &AppState, id: &str, title: &str) -> bool {
    let now = chrono::Utc::now();
    let write = sqlx::query(
        "INSERT INTO ai_conversation (id, created_at, updated_at, title) VALUES (?, ?, ?, ?)",
    )
    .bind(id)
    .bind(now)
    .bind(now)
    .bind(title)
    .execute(&state.db)
    .await;
    match write {
        Ok(_) => true,
        Err(e) => {
            tracing::warn!("ai: could not create a conversation: {e}");
            false
        }
    }
}

async fn approve(
    state: &Arc<AppState>,
    conversation: &str,
    call_id: &str,
    remote_ip: Option<String>,
) -> Result<HttpResponse, web::Error> {
    let _guard = state.ai_actions.lock().await;
    if state.ai_turns.is_running(conversation) {
        return Ok(conflict("busy"));
    }
    if conversation_row(state, conversation).await.is_none() {
        return Ok(not_found("no_such_conversation"));
    }
    let items = match turn::items(&state.db, conversation).await {
        Ok(items) => items,
        Err(e) => {
            tracing::warn!("ai: could not read a conversation: {e}");
            return Ok(internal_error("storage"));
        }
    };
    // A call that is not waiting for an answer is a state of the conversation
    // rather than a mistake in the request — the users endpoint's reason for
    // answering 404 for a name and 400 for a shape.
    let Some(call) = turn::unanswered(&items)
        .into_iter()
        .find(|item| item.call_id.as_deref() == Some(call_id))
    else {
        return Ok(not_found("no_such_call"));
    };
    let tool = call.tool.clone().unwrap_or_default();
    let arguments_text = call.arguments.clone().unwrap_or_default();
    let risk = call.risk.clone().unwrap_or_else(|| "unknown".to_string());
    let arguments: Value =
        serde_json::from_str(&arguments_text).unwrap_or_else(|_| json!({}));

    // Nothing to stop this with: an approved call runs inside this request,
    // with no turn around it. The command's own timeout bounds it, and the
    // panel's stop answers for a turn only.
    let stop = tokio::sync::Notify::new();
    let outcome =
        tools::execute(state, &tool, &arguments, &tools::Redactor::new(state), &stop).await;
    turn::audit(
        state,
        remote_ip.clone(),
        &tool,
        &arguments_text,
        &risk,
        false,
    )
    .await;

    let mut item = Item::new("function_output", "", &outcome.message);
    item.call_id = Some(call_id.to_string());
    let ordinal = match turn::next_ordinal(&state.db, conversation).await {
        Ok(ordinal) => ordinal,
        Err(e) => {
            tracing::warn!("ai: could not read a conversation's position: {e}");
            return Ok(internal_error("storage"));
        }
    };
    if let Err(e) = turn::insert(&state.db, conversation, &item, ordinal).await {
        // `idx_ai_message_one_output_per_call`, which would have to mean a
        // second action reached this call — impossible while it holds the lock.
        tracing::warn!("ai: could not store a tool result: {e}");
        return Ok(internal_error("storage"));
    }
    if let Err(e) = turn::touch(&state.db, conversation, None, None).await {
        tracing::warn!("ai: could not update a conversation: {e}");
    }

    // One call of a batch answered is not the batch: the rest are still parked,
    // and the turn resumes only when nothing is waiting.
    let resume = resume_if_answered(state, conversation, remote_ip).await;
    Ok(HttpResponse::Ok().json(&ActResponse {
        conversation: conversation.to_string(),
        running: resume,
        result: Some(CallResult {
            ok: outcome.ok,
            summary: summarise(&outcome.message),
        }),
    }))
}

/// The line of an envelope a caller may show. The stored item is the whole
/// envelope — the model reads `data`, a person reads this.
fn summarise(message: &str) -> String {
    serde_json::from_str::<Value>(message)
        .ok()
        .and_then(|value| {
            value
                .get("summary")
                .and_then(Value::as_str)
                .map(str::to_string)
        })
        .unwrap_or_default()
}

async fn decline(
    state: &Arc<AppState>,
    conversation: &str,
    remote_ip: Option<String>,
) -> Result<HttpResponse, web::Error> {
    let _guard = state.ai_actions.lock().await;
    if state.ai_turns.is_running(conversation) {
        return Ok(conflict("busy"));
    }
    if conversation_row(state, conversation).await.is_none() {
        return Ok(not_found("no_such_conversation"));
    }
    let items = match turn::items(&state.db, conversation).await {
        Ok(items) => items,
        Err(e) => {
            tracing::warn!("ai: could not read a conversation: {e}");
            return Ok(internal_error("storage"));
        }
    };
    let waiting: Vec<String> = turn::unanswered(&items)
        .into_iter()
        .filter_map(|item| item.call_id.clone())
        .collect();
    if waiting.is_empty() {
        return Ok(bad_request("nothing_to_decline"));
    }

    // Every call, not the one that was on screen: they were produced together
    // and one person answered them together. A call left unanswered would keep
    // the conversation parked, and the model would be told about neither.
    for call_id in &waiting {
        let item = Item::action("declined", call_id, turn::DECLINED_MESSAGE);
        let ordinal = match turn::next_ordinal(&state.db, conversation).await {
            Ok(ordinal) => ordinal,
            Err(e) => {
                tracing::warn!("ai: could not read a conversation's position: {e}");
                return Ok(internal_error("storage"));
            }
        };
        if let Err(e) = turn::insert(&state.db, conversation, &item, ordinal).await {
            tracing::warn!("ai: could not store a decline: {e}");
            return Ok(internal_error("storage"));
        }
        turn::audit(
            state,
            remote_ip.clone(),
            "declined",
            "{}",
            "unknown",
            false,
        )
        .await;
    }
    let notice = Item::notice(turn::DECLINED);
    if let Ok(ordinal) = turn::next_ordinal(&state.db, conversation).await
        && let Err(e) = turn::insert(&state.db, conversation, &notice, ordinal).await
    {
        tracing::warn!("ai: could not record a decline: {e}");
    }
    if let Err(e) = turn::touch(&state.db, conversation, None, None).await {
        tracing::warn!("ai: could not update a conversation: {e}");
    }

    let running = resume_if_answered(state, conversation, remote_ip).await;
    Ok(HttpResponse::Ok().json(&ActResponse {
        conversation: conversation.to_string(),
        running,
        result: None,
    }))
}

async fn rename(
    state: &Arc<AppState>,
    conversation: &str,
    title: String,
) -> Result<HttpResponse, web::Error> {
    let title = title.trim();
    if title.is_empty() || title.chars().count() > TITLE_LIMIT {
        return Ok(bad_request("invalid_title"));
    }
    if conversation_row(state, conversation).await.is_none() {
        return Ok(not_found("no_such_conversation"));
    }
    let write = sqlx::query("UPDATE ai_conversation SET title = ? WHERE id = ?")
        .bind(title)
        .bind(conversation)
        .execute(&state.db)
        .await;
    if let Err(e) = write {
        tracing::warn!("ai: could not rename a conversation: {e}");
        return Ok(internal_error("storage"));
    }
    Ok(HttpResponse::Ok().json(&ActResponse {
        conversation: conversation.to_string(),
        running: state.ai_turns.is_running(conversation),
        result: None,
    }))
}

/// Starts a turn if nothing is waiting any more. Answers whether one is running.
async fn resume_if_answered(
    state: &Arc<AppState>,
    conversation: &str,
    remote_ip: Option<String>,
) -> bool {
    if !matches!(turn::waiting(&state.db, conversation).await, Ok(waiting) if waiting.is_empty()) {
        return false;
    }
    state
        .ai_turns
        .try_spawn(state.clone(), conversation.to_string(), remote_ip)
        && state.ai_turns.is_running(conversation)
}

// --- Conversations, removing ---

#[derive(Deserialize)]
pub struct RemoveQuery {
    conversation: String,
}

pub async fn remove(
    req: HttpRequest,
    query: web::types::Query<RemoveQuery>,
    app_state: web::types::State<Arc<AppState>>,
) -> Result<HttpResponse, web::Error> {
    if verify_auth(&req, &app_state.config.get_jwt_secret()).is_err() {
        return Ok(HttpResponse::Unauthorized().finish());
    }
    let remote_ip = peer_ip(&req);
    let secure = ws::is_secure_transport(&req, app_state.tls_active);
    if !app_state.full_access_allowed(secure) {
        Event::new(Kind::Ai, Action::Denied, Outcome::Denied)
            .remote_ip(remote_ip)
            .detail("full access disabled")
            .record(&app_state.db)
            .await;
        return Ok(HttpResponse::Forbidden().finish());
    }
    let state = Arc::clone(&app_state);
    let id = query.conversation.as_str();

    // Refused rather than removed: a turn writes into its conversation, and one
    // whose row is gone fails on every insert — the items cascade away and the
    // turn's own notice has nowhere to go.
    if state.ai_turns.is_running(id) {
        return Ok(conflict("busy"));
    }
    let write = sqlx::query("DELETE FROM ai_conversation WHERE id = ?")
        .bind(id)
        .execute(&state.db)
        .await;
    let removed = match write {
        Ok(result) => result.rows_affected(),
        Err(e) => {
            tracing::warn!("ai: could not remove a conversation: {e}");
            return Ok(internal_error("storage"));
        }
    };
    if removed == 0 {
        return Ok(not_found("no_such_conversation"));
    }

    Event::new(Kind::Ai, Action::Write, Outcome::Ok)
        .remote_ip(remote_ip)
        .subject("conversation")
        .detail("removed")
        .record(&state.db)
        .await;
    Ok(HttpResponse::Ok().finish())
}

// --- Following a conversation ---

#[derive(Deserialize)]
pub struct FollowQuery {
    conversation: String,
    /// The last ordinal the caller already has. Everything after it is sent, so
    /// a reconnect does not re-draw the conversation.
    #[serde(default)]
    after: i64,
}

/// Where a follower has read to.
///
/// `step` is the ordinal the text on screen belongs to; `content` and
/// `reasoning` are byte counts *within that step's buffer*, which is the whole
/// reason `step` is kept beside them: a step change resets the two to 0, and a
/// reconnecting client that has nothing is sent the buffer whole.
#[derive(Default)]
struct Cursor {
    after: i64,
    step: Option<i64>,
    content: usize,
    reasoning: usize,
}

pub async fn follow(
    req: HttpRequest,
    query: web::types::Query<FollowQuery>,
    app_state: web::types::State<Arc<AppState>>,
) -> Result<HttpResponse, web::Error> {
    if verify_auth(&req, &app_state.config.get_jwt_secret()).is_err() {
        return Ok(HttpResponse::Unauthorized().finish());
    }
    let state = Arc::clone(&app_state);
    let conversation = query.conversation.clone();
    // A stream for a conversation nobody has would sit open until the client
    // gave up, and would never have anything to send.
    if conversation_row(&state, &conversation).await.is_none() {
        return Ok(not_found("no_such_conversation"));
    }

    let mut cursor = Cursor {
        after: query.after,
        ..Cursor::default()
    };
    let stream = async_stream::stream! {
        let mut last: Option<(bool, &'static str, Option<String>, Vec<String>)> = None;
        let mut last_ping = tokio::time::Instant::now();
        loop {
            match turn::items_after(&state.db, &conversation, cursor.after).await {
                Ok(items) => {
                    for item in items {
                        cursor.after = cursor.after.max(item.ordinal);
                        yield line(&json!({
                            "type": "item",
                            "item": ItemView::of(&item),
                        }));
                    }
                }
                Err(e) => {
                    tracing::warn!("ai: could not read a conversation: {e}");
                    yield line(&json!({ "type": "state", "running": false, "phase": "idle",
                                        "error": "storage", "waiting": [] }));
                    break;
                }
            }

            let live = state.ai_turns.live(&conversation);
            let snapshot = match &live {
                Some(turn) => Some(turn.snapshot().await),
                None => None,
            };
            let step = snapshot
                .as_ref()
                .and_then(|live| (live.step >= 0).then_some(live.step));

            if let Some(live) = &snapshot {
                if step != cursor.step {
                    cursor.step = step;
                    cursor.content = 0;
                    cursor.reasoning = 0;
                }
                // A shrink can only mean the buffer was replaced under a cursor
                // that is still keyed to the old step, which the check above
                // makes impossible — reset rather than index, so a mistake here
                // costs one delta instead of a panic that ends the stream.
                if live.content.len() < cursor.content || live.reasoning.len() < cursor.reasoning {
                    cursor.content = 0;
                    cursor.reasoning = 0;
                }
                // Sliced at a byte count that was itself a boundary of this
                // same buffer, and the buffer only appends within one step.
                if let (Some(content), Some(reasoning)) = (
                    live.content.get(cursor.content..),
                    live.reasoning.get(cursor.reasoning..),
                ) {
                    if !content.is_empty() || !reasoning.is_empty() {
                        yield line(&json!({
                            "type": "delta",
                            "step": step,
                            "content": content,
                            "reasoning": reasoning,
                        }));
                    }
                    cursor.content = live.content.len();
                    cursor.reasoning = live.reasoning.len();
                }
            }

            let waiting = match turn::waiting(&state.db, &conversation).await {
                Ok(waiting) => waiting,
                Err(e) => {
                    tracing::warn!("ai: could not read what a conversation is waiting on: {e}");
                    Vec::new()
                }
            };
            let (running, phase, error) = match &snapshot {
                Some(live) => (
                    true,
                    live.phase.as_str(),
                    live.error.clone(),
                ),
                None => (false, "idle", None),
            };
            let current = (running, phase, error, waiting);
            if last.as_ref() != Some(&current) {
                yield line(&json!({
                    "type": "state",
                    "running": current.0,
                    "phase": current.1,
                    "error": current.2,
                    "waiting": current.3,
                }));
                last = Some(current);
            }

            if last_ping.elapsed() >= PING_INTERVAL {
                yield line(&json!({ "type": "ping" }));
                last_ping = tokio::time::Instant::now();
            }

            tokio::time::sleep(FOLLOW_TICK).await;
        }
    };

    // Boxed because an `async_stream` generator holds a self-referential future
    // and so is not `Unpin`, which is what `streaming` asks for — `fs::read`'s
    // reason. No `content-length`: the body has no end until the client leaves.
    Ok(HttpResponse::Ok()
        .content_type("application/x-ndjson")
        .streaming(Box::pin(stream)))
}

/// One NDJSON frame, newline included.
///
/// A `Result` because that is what the body's item type is — `fs::read`'s — and
/// nothing here produces an error: a stream is ended by the client leaving, not
/// by a frame failing to encode.
fn line(value: &Value) -> Result<Bytes, std::io::Error> {
    Ok(Bytes::from(format!("{value}\n")))
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn a_base_url_is_a_url_this_agent_could_send_to() {
        assert!(validate_base_url("https://api.openai.com/v1").is_ok());
        assert!(validate_base_url("http://127.0.0.1:8080/v1").is_ok());
        // A trailing slash is trimmed by `AiConfig::endpoint`, not refused.
        assert!(validate_base_url("https://example.com/v1/").is_ok());

        assert_eq!(validate_base_url(""), Err("invalid_base_url"));
        assert_eq!(validate_base_url("api.openai.com/v1"), Err("invalid_base_url"));
        assert_eq!(validate_base_url("ftp://example.com"), Err("invalid_base_url"));
        assert_eq!(validate_base_url("file:///etc/passwd"), Err("invalid_base_url"));
    }

    #[test]
    fn a_title_is_the_first_line_of_the_message_it_is_made_from() {
        assert_eq!(derived_title("check the disk"), "check the disk");
        assert_eq!(derived_title("\n\n  check\n the disk"), "check");
        assert_eq!(derived_title("   "), "");
        assert_eq!(derived_title(&"x".repeat(500)).chars().count(), TITLE_LIMIT);
    }

    #[test]
    fn a_summary_is_read_out_of_the_envelope_and_never_invented() {
        assert_eq!(
            summarise(r#"{"server_box_tool_result":true,"summary":"Nothing."}"#),
            "Nothing."
        );
        assert_eq!(summarise("not json"), "");
        assert_eq!(summarise(r#"{"ok":true}"#), "");
    }
}
