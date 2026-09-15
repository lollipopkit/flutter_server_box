//! `GET/PUT /api/v1/push` — the notification channels a fired rule delivers
//! through, the rate that bounds them, and `POST /api/v1/push/test` to send
//! one on demand.
//!
//! Its own endpoint rather than fields of `PUT /settings`, for the reason
//! `/card-order` is one: a save here must not be a read-modify-write of
//! everything the settings page happens to have open. It also keeps the
//! credential handling below in one place instead of threading it through
//! `SettingsPayload`.
//!
//! **A credential is write-only.** These entries hold a ServerChan key, a Bark
//! key, an iOS token, an `Authorization` header — things a panel login could
//! not read before this endpoint existed, and the agent's standing position is
//! that the panel password does not widen what it discloses (`jwt_secret` and
//! `database_url` are absent from `/settings` for the same reason, and
//! `full_access` can only ever be narrowed through the API). So:
//!
//! - a GET answers `null` at every credential key — `null` means "set on the
//!   agent, not disclosed", an absent key means "not set at all";
//! - a PUT sending `null` back means "keep what is on disk";
//! - `null` anywhere else is refused, so a client cannot use the merge to read
//!   a value out through a field that gets transmitted.
//!
//! Which entry "on disk" refers to is [`PushEntry::from_index`], the position
//! the entry was loaded from, echoed back. Matching by name would lose the
//! credential of a renamed entry; matching by position in the submitted list
//! would lose it on a reorder.
//!
//! The webhook `url` is deliberately *not* a credential here even though a
//! Slack or Discord one is. It is the entry's identity in an editor, and
//! hiding it would mean retyping the whole endpoint to change one header. The
//! header values beside it are hidden.
//!
//! Saved entries reach the rule engine on the next start: `rules.rs` reads the
//! `Arc<Config>` snapshot `AppState` took at startup, the same as the rules
//! themselves do. `applies_on_restart` says so rather than leaving both
//! editors to assume it.
// TODO: make pushes and rules live, the way `LiveSettings` already does for
// the collection intervals, and drop `applies_on_restart`.

use std::collections::HashSet;
use std::sync::{Arc, OnceLock};
use std::time::Duration;

use ntex::web::{self, HttpRequest, HttpResponse};
use serde::{Deserialize, Serialize};
use serde_json::{Map as JsonMap, Value as JsonValue};

use super::server::AppState;
use super::server::verify_auth;
use super::ws::audit::{Action, Event, Kind, Outcome, peer_ip};
use crate::core::config::{PushConfig, validate_push_rate};
use crate::core::config_file;
use crate::monitoring::push::{PushRateLimiter, send_notification};

/// The largest request body accepted: every channel at once, since a write
/// replaces the whole set. A webhook's `body_template` is a document the user
/// pastes in, so this is well above what ntex allows by default and still
/// bounded.
pub const MAX_REQUEST: usize = 256 * 1024;

/// The longest test message accepted. The text is the caller's so the editors
/// can send it in the user's own language; the cap stops the endpoint being a
/// way to make the agent post something sizeable somewhere.
const TEST_MESSAGE_LIMIT: usize = 500;

/// How often this agent will send a test, across all callers. A test is a
/// request to an address the caller names, so it is the one push path that is
/// not paced by how often a rule fires.
const TEST_RATE: (usize, Duration) = (6, Duration::from_secs(60));

/// Every `push_type` this agent can actually deliver through, in the order the
/// editors offer them. `server_chan` is the Go agent's spelling of the second
/// one: still accepted and still written back as it was found, but not offered
/// for a new channel.
const OFFERED_TYPES: &[&str] = &["webhook", "serverchan", "bark", "ios"];

/// Which sender handles `push_type`, or `None` when nothing does.
///
/// Classification only — the string is never rewritten to what this returns,
/// because rewriting `server_chan` to `serverchan` would be this endpoint
/// editing a field the user did not touch.
fn canonical_type(push_type: &str) -> Option<&'static str> {
    match push_type {
        "webhook" => Some("webhook"),
        // `send_notification` routes both spellings to the same sender.
        "serverchan" | "server_chan" => Some("serverchan"),
        "bark" => Some("bark"),
        "ios" => Some("ios"),
        _ => None,
    }
}

/// Where a channel's credential sits inside its free-form config.
enum Secret {
    /// A key whose value is the credential.
    Key(&'static str),
    /// Every value of a table, the key names staying visible. `headers` is one
    /// table with `Content-Type` and `Authorization` in it, and only one of
    /// those is worth hiding — but hiding the value of each is what keeps the
    /// rule simple enough to be obviously right.
    TableValues(&'static str),
}

fn secrets(push_type: &str) -> &'static [Secret] {
    match canonical_type(push_type) {
        Some("webhook") => &[Secret::TableValues("headers")],
        // Both spellings: `send_serverchan_notification` reads `sc_key` and
        // falls back to `sckey`, so a file may hold either.
        Some("serverchan") => &[Secret::Key("sc_key"), Secret::Key("sckey")],
        Some("bark") => &[Secret::Key("key")],
        Some("ios") => &[Secret::Key("token")],
        _ => &[],
    }
}

/// The keys one of which must hold a value for the channel to deliver
/// anything. Checked on save so clearing a field is reported then, rather than
/// leaving a channel that looks configured and silently sends nothing.
fn required_any_of(push_type: &str) -> &'static [&'static str] {
    match canonical_type(push_type) {
        Some("webhook") => &["url"],
        Some("serverchan") => &["sc_key", "sckey"],
        Some("bark") => &["key"],
        Some("ios") => &["token"],
        _ => &[],
    }
}

#[derive(Serialize)]
struct PushView {
    name: String,
    push_type: String,
    /// The channel's settings with every credential replaced by `null`. Unknown
    /// keys are passed through untouched — `legacy_go_format`, a webhook's
    /// `expected_http_status` — and an editor must send them back rather than
    /// rebuilding this object out of the fields it knows.
    config: JsonMap<String, JsonValue>,
    /// False when this agent has no sender for `push_type`, which also means it
    /// cannot know which of the entry's keys are credentials. Such an entry is
    /// listed by name and type only, and can be deleted but not edited here.
    editable: bool,
}

#[derive(Serialize)]
struct ListResponse {
    pushes: Vec<PushView>,
    /// `null` = the built-in default, one notification per minute.
    push_rate: Option<String>,
    push_types: &'static [&'static str],
    /// Always true today — see this module's header.
    applies_on_restart: bool,
}

#[derive(Deserialize)]
pub struct PushEntry {
    name: String,
    push_type: String,
    #[serde(default)]
    config: JsonMap<String, JsonValue>,
    /// The index this entry was loaded from, or `null` for one being added.
    /// The only thing a `null` credential can be resolved against.
    #[serde(default)]
    from_index: Option<usize>,
}

#[derive(Deserialize)]
pub struct ReplaceRequest {
    /// The whole set, in order. A replace rather than a per-entry edit, like
    /// `/custom-cmds`: the order is what is stored.
    pushes: Vec<PushEntry>,
    #[serde(default)]
    push_rate: Option<String>,
}

#[derive(Deserialize)]
pub struct TestRequest {
    push: PushEntry,
    /// What to send. `None` uses a fixed English sentence; the editors pass
    /// their own so the message arrives in the user's language.
    #[serde(default)]
    message: Option<String>,
}

#[derive(Serialize)]
struct TestResponse {
    /// Whether the channel accepted it. A delivery failure is a 200 with
    /// `ok: false` — the request itself succeeded, and the reason belongs in
    /// front of the user editing the channel.
    ok: bool,
    #[serde(skip_serializing_if = "Option::is_none")]
    error: Option<String>,
}

#[derive(Serialize)]
struct ErrorResponse {
    error: String,
}

fn bad_request(error: impl Into<String>) -> HttpResponse {
    HttpResponse::BadRequest().json(&ErrorResponse { error: error.into() })
}

fn internal_error(error: impl Into<String>) -> HttpResponse {
    HttpResponse::InternalServerError().json(&ErrorResponse { error: error.into() })
}

pub async fn list(
    req: HttpRequest,
    app_state: web::types::State<Arc<AppState>>,
) -> Result<HttpResponse, web::Error> {
    if verify_auth(&req, &app_state.config.get_jwt_secret()).is_err() {
        return Ok(HttpResponse::Unauthorized().finish());
    }

    // Off disk rather than off `AppState.config`, which is a startup snapshot:
    // a GET right after a save must show what was saved.
    let config = match config_file::read() {
        Ok(config) => config,
        Err(e) => return Ok(internal_error(e.to_string())),
    };

    Ok(HttpResponse::Ok().json(&ListResponse {
        pushes: config.get_push().iter().map(view).collect(),
        push_rate: config.get_monitoring().push_rate,
        push_types: OFFERED_TYPES,
        applies_on_restart: true,
    }))
}

pub async fn replace(
    req: HttpRequest,
    body: web::types::Json<ReplaceRequest>,
    app_state: web::types::State<Arc<AppState>>,
) -> Result<HttpResponse, web::Error> {
    if verify_auth(&req, &app_state.config.get_jwt_secret()).is_err() {
        return Ok(HttpResponse::Unauthorized().finish());
    }
    let remote_ip = peer_ip(&req);
    let ReplaceRequest { pushes, push_rate } = body.into_inner();

    if let Some(rate) = &push_rate
        && let Err(e) = validate_push_rate(rate)
    {
        return Ok(bad_request(e));
    }

    // Held across the whole read-modify-write: `config_file::write` is atomic,
    // but two handlers each reading the same starting state would still lose
    // one of the two changes.
    let _config_guard = app_state.config_write.lock().await;

    let mut config = match config_file::read() {
        Ok(config) => config,
        Err(e) => return Ok(internal_error(e.to_string())),
    };
    let existing = config.get_push();

    let resolved = match resolve_all(pushes, &existing) {
        Ok(resolved) => resolved,
        Err(e) => {
            Event::new(Kind::Push, Action::Close, Outcome::Error)
                .remote_ip(remote_ip)
                .detail(e.clone())
                .record(&app_state.db)
                .await;
            return Ok(bad_request(e));
        }
    };

    // Names and types, never the configs: a `body_template` is whatever the
    // user pasted and a header value is a credential.
    let subject = resolved
        .iter()
        .map(|push| format!("{} ({})", push.name, push.push_type))
        .collect::<Vec<_>>()
        .join(", ");

    config.push = Some(resolved);
    let mut monitoring = config.get_monitoring();
    monitoring.push_rate = push_rate.clone();
    config.monitoring = Some(monitoring);

    if let Err(e) = config_file::write(&config) {
        Event::new(Kind::Push, Action::Close, Outcome::Error)
            .remote_ip(remote_ip)
            .detail(e.to_string())
            .record(&app_state.db)
            .await;
        return Ok(internal_error(e.to_string()));
    }

    Event::new(Kind::Push, Action::Open, Outcome::Ok)
        .remote_ip(remote_ip)
        .subject(subject)
        .record(&app_state.db)
        .await;
    tracing::info!("Push channels saved via PUT /api/v1/push");

    // Read back rather than echoing what was sent: the response has to carry
    // the `from_index` positions the editor will send next time, and after a
    // reorder those are the new ones.
    Ok(HttpResponse::Ok().json(&ListResponse {
        pushes: config.get_push().iter().map(view).collect(),
        push_rate,
        push_types: OFFERED_TYPES,
        applies_on_restart: true,
    }))
}

pub async fn test(
    req: HttpRequest,
    body: web::types::Json<TestRequest>,
    app_state: web::types::State<Arc<AppState>>,
) -> Result<HttpResponse, web::Error> {
    if verify_auth(&req, &app_state.config.get_jwt_secret()).is_err() {
        return Ok(HttpResponse::Unauthorized().finish());
    }
    let remote_ip = peer_ip(&req);
    let TestRequest { push, message } = body.into_inner();

    let message = match message {
        Some(message) if message.chars().count() > TEST_MESSAGE_LIMIT => {
            return Ok(bad_request(format!(
                "A test message may be at most {TEST_MESSAGE_LIMIT} characters"
            )));
        }
        Some(message) => message,
        None => "ServerBox Monitor test notification".to_string(),
    };

    // Read only — a test never writes the config, so no `config_write` guard.
    // It still has to read the file, because the credential being tested is
    // usually the one the editor was not given.
    let existing = match config_file::read() {
        Ok(config) => config.get_push(),
        Err(e) => return Ok(internal_error(e.to_string())),
    };

    let resolved = match resolve_all(vec![push], &existing) {
        Ok(mut resolved) => resolved.remove(0),
        Err(e) => return Ok(bad_request(e)),
    };

    if !test_limiter().check(TEST_RATE.0, TEST_RATE.1) {
        Event::new(Kind::Push, Action::Denied, Outcome::Denied)
            .remote_ip(remote_ip)
            .subject(test_subject(&resolved))
            .detail("test rate limit reached")
            .record(&app_state.db)
            .await;
        return Ok(HttpResponse::TooManyRequests().json(&ErrorResponse {
            error: format!(
                "At most {} test notifications every {} seconds",
                TEST_RATE.0,
                TEST_RATE.1.as_secs()
            ),
        }));
    }
    test_limiter().acquire();

    // The whole point is reaching an address the caller named, so it is worth
    // a row naming where it went. The host only: the rest of a webhook URL is
    // as often as not the credential.
    let subject = test_subject(&resolved);
    let result = send_notification(&app_state.config, &resolved, &message).await;
    let (ok, error) = match result {
        Ok(()) => (true, None),
        Err(e) => (false, Some(e.to_string())),
    };

    Event::new(
        Kind::Push,
        Action::Open,
        if ok { Outcome::Ok } else { Outcome::Error },
    )
    .remote_ip(remote_ip)
    .subject(subject)
    .record(&app_state.db)
    .await;

    Ok(HttpResponse::Ok().json(&TestResponse { ok, error }))
}

/// `name (type)` for a known channel, plus the host for a webhook — the one
/// case where where it went is not implied by the type.
fn test_subject(push: &PushConfig) -> String {
    let base = format!("test {} ({})", push.name, push.push_type);
    let Some(url) = push.config.get("url").and_then(|v| v.as_str()) else {
        return base;
    };
    // Between "//" and the first "/", "?" or "#" — enough to say which host
    // without carrying a path that may be the credential. Deliberately not a
    // URL parser: this is a log line, and a string that does not parse is
    // exactly the one worth recording as it was.
    let host = url
        .split_once("//")
        .map(|(_, rest)| rest)
        .unwrap_or(url)
        .split(['/', '?', '#'])
        .next()
        .unwrap_or_default();
    if host.is_empty() { base } else { format!("{base} -> {host}") }
}

/// Paces `POST /push/test` across every caller.
///
/// Its own limiter rather than a reserved name in `PushRateLimiter::global()`,
/// whose keys are user-chosen channel names and so cannot be reserved.
struct TestLimiter(PushRateLimiter);

impl TestLimiter {
    const KEY: &'static str = "test";

    fn check(&self, times: usize, window: Duration) -> bool {
        self.0.check(Self::KEY, times, window)
    }

    fn acquire(&self) {
        self.0.acquire(Self::KEY);
    }
}

fn test_limiter() -> &'static TestLimiter {
    static LIMITER: OnceLock<TestLimiter> = OnceLock::new();
    LIMITER.get_or_init(|| TestLimiter(PushRateLimiter::new()))
}

/// Validates every entry, fills the credentials a GET withheld, and converts
/// to what the config file holds. All or nothing: a set with one bad entry is
/// refused whole, since a partial save would leave the editor showing a list
/// the agent does not have.
fn resolve_all(
    entries: Vec<PushEntry>,
    existing: &[PushConfig],
) -> Result<Vec<PushConfig>, String> {
    let mut names = HashSet::new();
    let mut resolved = Vec::with_capacity(entries.len());

    for mut entry in entries {
        entry.name = entry.name.trim().to_string();
        if entry.name.is_empty() {
            return Err("Every push channel needs a name".to_string());
        }
        // `PushRateLimiter` keys by name, so two channels sharing one would
        // share a single quota — one of them silently swallowing the other's.
        if !names.insert(entry.name.clone()) {
            return Err(format!("Two push channels are both named '{}'", entry.name));
        }
        if canonical_type(&entry.push_type).is_none() {
            return Err(format!(
                "'{}' has push type '{}', which this agent cannot send through",
                entry.name, entry.push_type
            ));
        }

        keep_withheld(&mut entry, existing)?;
        check_required(&entry)?;
        resolved.push(into_push_config(entry)?);
    }

    Ok(resolved)
}

/// Replaces each `null` credential with the value the entry was loaded with.
fn keep_withheld(entry: &mut PushEntry, existing: &[PushConfig]) -> Result<(), String> {
    // A credential can only be kept for the same kind of channel. `from_index`
    // pointing at another type would mean copying, say, a Bark key into an iOS
    // token — which is not "unchanged" in any sense, and is the shape an
    // attempt to read one back out through a channel they control would take.
    let source = entry
        .from_index
        .and_then(|index| existing.get(index))
        .filter(|source| canonical_type(&source.push_type) == canonical_type(&entry.push_type));

    for secret in secrets(&entry.push_type) {
        match secret {
            Secret::Key(key) => {
                if entry.config.get(*key).is_some_and(JsonValue::is_null) {
                    let kept = source
                        .and_then(|source| source.config.get(*key))
                        .and_then(to_json)
                        .ok_or_else(|| withheld_error(&entry.name, key))?;
                    entry.config.insert((*key).to_string(), kept);
                }
            }
            Secret::TableValues(table) => {
                let Some(JsonValue::Object(submitted)) = entry.config.get(*table) else {
                    continue;
                };
                let withheld: Vec<String> = submitted
                    .iter()
                    .filter(|(_, value)| value.is_null())
                    .map(|(key, _)| key.clone())
                    .collect();
                if withheld.is_empty() {
                    continue;
                }
                let stored = source
                    .and_then(|source| source.config.get(*table))
                    .and_then(|value| value.as_table());
                let mut kept = JsonMap::new();
                for key in withheld {
                    let value = stored
                        .and_then(|stored| stored.get(&key))
                        .and_then(to_json)
                        .ok_or_else(|| {
                            withheld_error(&entry.name, &format!("{table}.{key}"))
                        })?;
                    kept.insert(key, value);
                }
                let Some(JsonValue::Object(submitted)) = entry.config.get_mut(*table) else {
                    unreachable!("the same key was an object a few lines above");
                };
                submitted.extend(kept);
            }
        }
    }

    // Everything else: a `null` the merge above did not account for is either a
    // client sending one where this agent never wrote one, or an attempt to
    // pull a stored value out through a field that gets transmitted. Neither is
    // something to guess at.
    if let Some(key) = first_null(&entry.config) {
        return Err(format!(
            "'{}' sent null for '{key}', which only a withheld credential may be",
            entry.name
        ));
    }
    Ok(())
}

fn withheld_error(name: &str, key: &str) -> String {
    format!("'{name}' has no stored '{key}' to keep; send the value")
}

/// The first `null`, by dotted path, anywhere in one level of nesting — as
/// deep as a push config goes.
fn first_null(config: &JsonMap<String, JsonValue>) -> Option<String> {
    for (key, value) in config {
        match value {
            JsonValue::Null => return Some(key.clone()),
            JsonValue::Object(table) => {
                if let Some(inner) = table
                    .iter()
                    .find(|(_, value)| value.is_null())
                    .map(|(inner, _)| inner)
                {
                    return Some(format!("{key}.{inner}"));
                }
            }
            _ => {}
        }
    }
    None
}

/// Whether a key holds something worth sending. A blank string is the shape a
/// cleared field arrives in and is not a credential.
fn has_value(value: &JsonValue) -> bool {
    match value {
        JsonValue::Null => false,
        JsonValue::String(text) => !text.trim().is_empty(),
        _ => true,
    }
}

fn check_required(entry: &PushEntry) -> Result<(), String> {
    let required = required_any_of(&entry.push_type);
    if required.is_empty() {
        return Ok(());
    }
    let present = required
        .iter()
        .any(|key| entry.config.get(*key).is_some_and(has_value));
    if !present {
        return Err(format!(
            "'{}' needs {} before it can send anything",
            entry.name,
            required.join(" or ")
        ));
    }

    // Scheme only, not a parse: this is about not saving a webhook that can
    // never be requested, and reqwest is the thing that decides the rest.
    if canonical_type(&entry.push_type) == Some("webhook")
        && let Some(url) = entry.config.get("url").and_then(JsonValue::as_str)
        && !(url.starts_with("http://") || url.starts_with("https://"))
    {
        return Err(format!("'{}' has a url that is not http(s)", entry.name));
    }
    Ok(())
}

fn into_push_config(entry: PushEntry) -> Result<PushConfig, String> {
    let config = serde_json::from_value::<toml::Table>(JsonValue::Object(entry.config))
        .map_err(|e| format!("'{}' has a setting the config file cannot hold: {e}", entry.name))?;
    Ok(PushConfig {
        name: entry.name,
        push_type: entry.push_type,
        config,
    })
}

fn view(push: &PushConfig) -> PushView {
    let editable = canonical_type(&push.push_type).is_some();
    let mut config = match serde_json::to_value(&push.config) {
        Ok(JsonValue::Object(config)) => config,
        _ => JsonMap::new(),
    };

    if !editable {
        // Nothing this agent can send through is nothing whose credential keys
        // it knows, so the whole config stays here. The entry is still listed,
        // so it can be seen and removed rather than being invisible to one
        // editor and present in the file.
        return PushView {
            name: push.name.clone(),
            push_type: push.push_type.clone(),
            config: JsonMap::new(),
            editable: false,
        };
    }

    for secret in secrets(&push.push_type) {
        match secret {
            Secret::Key(key) => {
                if config.contains_key(*key) {
                    config.insert((*key).to_string(), JsonValue::Null);
                }
            }
            Secret::TableValues(table) => {
                if let Some(JsonValue::Object(values)) = config.get_mut(*table) {
                    for value in values.values_mut() {
                        *value = JsonValue::Null;
                    }
                }
            }
        }
    }

    PushView {
        name: push.name.clone(),
        push_type: push.push_type.clone(),
        config,
        editable,
    }
}

fn to_json(value: &toml::Value) -> Option<JsonValue> {
    serde_json::to_value(value).ok()
}

#[cfg(test)]
mod tests {
    use super::*;

    fn stored(name: &str, push_type: &str, config: &str) -> PushConfig {
        PushConfig {
            name: name.to_string(),
            push_type: push_type.to_string(),
            config: toml::from_str(config).expect("test config parses"),
        }
    }

    fn entry(name: &str, push_type: &str, config: JsonValue, from_index: Option<usize>) -> PushEntry {
        let JsonValue::Object(config) = config else {
            panic!("a push config is an object")
        };
        PushEntry {
            name: name.to_string(),
            push_type: push_type.to_string(),
            config,
            from_index,
        }
    }

    #[test]
    fn a_get_withholds_the_credential_and_keeps_everything_else() {
        let view = view(&stored("bark", "bark", "key = \"secret\"\nserver = \"https://api.day.app\""));
        assert_eq!(view.config["key"], JsonValue::Null);
        assert_eq!(view.config["server"], "https://api.day.app");
        assert!(view.editable);
    }

    #[test]
    fn a_get_withholds_header_values_but_not_their_names() {
        let view = view(&stored(
            "hook",
            "webhook",
            "url = \"https://example.invalid/x\"\n[headers]\nAuthorization = \"Bearer t\"",
        ));
        // The URL is the entry's identity in an editor, deliberately not hidden.
        assert_eq!(view.config["url"], "https://example.invalid/x");
        assert_eq!(view.config["headers"]["Authorization"], JsonValue::Null);
    }

    #[test]
    fn an_unknown_type_discloses_nothing() {
        let view = view(&stored("odd", "telegram", "bot_token = \"secret\""));
        assert!(!view.editable);
        assert!(view.config.is_empty(), "no key of an unknown type is known to be safe");
    }

    #[test]
    fn a_null_credential_is_kept_from_the_entry_it_was_loaded_from() {
        let existing = vec![stored("bark", "bark", "key = \"secret\"")];
        let resolved = resolve_all(
            vec![entry(
                "renamed",
                "bark",
                serde_json::json!({ "key": null, "title": "new" }),
                Some(0),
            )],
            &existing,
        )
        .expect("a rename keeps the credential");
        assert_eq!(resolved[0].config["key"].as_str(), Some("secret"));
        assert_eq!(resolved[0].name, "renamed");
    }

    #[test]
    fn a_null_credential_with_nothing_behind_it_is_refused() {
        let error = resolve_all(
            vec![entry("bark", "bark", serde_json::json!({ "key": null }), None)],
            &[],
        )
        .expect_err("a new channel has nothing to keep");
        assert!(error.contains("no stored 'key'"), "{error}");
    }

    #[test]
    fn a_credential_cannot_be_kept_across_a_type_change() {
        let existing = vec![stored("bark", "bark", "key = \"secret\"")];
        let error = resolve_all(
            vec![entry(
                "now ios",
                "ios",
                serde_json::json!({ "token": null }),
                Some(0),
            )],
            &existing,
        )
        .expect_err("a different channel is a different credential");
        assert!(error.contains("no stored 'token'"), "{error}");
    }

    #[test]
    fn a_null_outside_a_credential_is_refused() {
        let existing = vec![stored("hook", "webhook", "url = \"https://example.invalid/\"")];
        let error = resolve_all(
            vec![entry(
                "hook",
                "webhook",
                serde_json::json!({ "url": null }),
                Some(0),
            )],
            &existing,
        )
        .expect_err("only a withheld credential may be null");
        assert!(error.contains("only a withheld credential"), "{error}");
    }

    #[test]
    fn a_header_value_is_kept_while_its_neighbours_are_replaced() {
        let existing = vec![stored(
            "hook",
            "webhook",
            "url = \"https://example.invalid/\"\n[headers]\nAuthorization = \"Bearer t\"\nContent-Type = \"application/json\"",
        )];
        let resolved = resolve_all(
            vec![entry(
                "hook",
                "webhook",
                serde_json::json!({
                    "url": "https://example.invalid/",
                    "headers": { "Authorization": null, "Content-Type": "text/plain" },
                }),
                Some(0),
            )],
            &existing,
        )
        .expect("one header changes, the other is kept");
        let headers = resolved[0].config["headers"].as_table().expect("headers is a table");
        assert_eq!(headers["Authorization"].as_str(), Some("Bearer t"));
        assert_eq!(headers["Content-Type"].as_str(), Some("text/plain"));
    }

    #[test]
    fn an_unknown_type_cannot_be_saved() {
        let error = resolve_all(
            vec![entry("odd", "telegram", serde_json::json!({}), None)],
            &[],
        )
        .expect_err("a type nothing sends through would be silently dead");
        assert!(error.contains("cannot send through"), "{error}");
    }

    #[test]
    fn two_channels_may_not_share_a_name() {
        let error = resolve_all(
            vec![
                entry("same", "bark", serde_json::json!({ "key": "a" }), None),
                entry("same", "bark", serde_json::json!({ "key": "b" }), None),
            ],
            &[],
        )
        .expect_err("the rate limiter keys by name");
        assert!(error.contains("both named"), "{error}");
    }

    #[test]
    fn a_channel_missing_its_credential_is_refused() {
        let error = resolve_all(
            vec![entry("bark", "bark", serde_json::json!({ "key": "  " }), None)],
            &[],
        )
        .expect_err("a blank credential sends nothing");
        assert!(error.contains("needs key"), "{error}");
    }

    #[test]
    fn a_webhook_url_must_be_http() {
        let error = resolve_all(
            vec![entry(
                "hook",
                "webhook",
                serde_json::json!({ "url": "file:///etc/passwd" }),
                None,
            )],
            &[],
        )
        .expect_err("nothing requests a file: url");
        assert!(error.contains("not http(s)"), "{error}");
    }

    #[test]
    fn unknown_keys_survive_a_round_trip() {
        let existing = vec![stored(
            "hook",
            "webhook",
            "url = \"https://example.invalid/\"\nlegacy_go_format = true\nexpected_http_status = 204",
        )];
        let view = view(&existing[0]);
        let resolved = resolve_all(
            vec![entry(
                "hook",
                "webhook",
                JsonValue::Object(view.config),
                Some(0),
            )],
            &existing,
        )
        .expect("what a GET returned is what a PUT accepts");
        assert_eq!(resolved[0].config["legacy_go_format"].as_bool(), Some(true));
        assert_eq!(resolved[0].config["expected_http_status"].as_integer(), Some(204));
    }

    #[test]
    fn a_webhook_host_is_logged_without_its_path() {
        let push = stored(
            "hook",
            "webhook",
            "url = \"https://hooks.slack.com/services/T000/B000/secret\"",
        );
        assert_eq!(test_subject(&push), "test hook (webhook) -> hooks.slack.com");
    }
}
