//! `GET/PUT /api/v1/snippets` and `POST /api/v1/snippets/plan` — the snippet
//! library saved on this agent.
//!
//! A snippet is a script the operator wrote once to run again, with `${…}`
//! macros that are filled in at the moment it runs. The library lives here
//! rather than in the panel's `localStorage` because it is a record of what to
//! run *on this machine*: the panel is a browser that can be opened anywhere,
//! and a library in it would be lost with its storage and invisible from a
//! second browser. The app keeps its own set over SSH; this is the agent's, and
//! what the two agree on is `sbm_parser::snippet`.
//!
//! The library is not the implementation. `/plan` expands a script into the
//! keystrokes a terminal is fed, and that expansion is the same Rust function
//! the app would call through FFI — the point of the shared crate, and the
//! reason a macro means one thing in both clients.
//!
//! # Privilege
//!
//! Both the read and the write need only the panel login, for `api::desktop`'s
//! reason: a snippet is not a grant. It executes nothing — `/plan` returns a
//! description of what a client should type and types none of it — and it
//! becomes usable only through a terminal, which is a session with its own
//! credentials. Someone who may save a snippet but may not open a shell cannot
//! run it, and someone who may open a shell can type it by hand. So the
//! response does not claim an `editable` it would then have to keep true.
//!
//! `TODO`: a future "run this on a schedule" would change that answer, the way
//! it would for a desktop route — a schedule runs with nobody watching, which
//! is a different thing from a person pressing Run.

use std::collections::HashSet;
use std::sync::Arc;

use ntex::web::{self, HttpRequest, HttpResponse};
use serde::{Deserialize, Serialize};
use sqlx::SqlitePool;

use super::server::AppState;
use super::server::verify_auth;
use super::ws::audit::{Action, Event, Kind, Outcome, peer_ip};
use sbm_parser::snippet::{self, SnippetContext, Step};

/// The largest request body accepted: the whole library at once, since a write
/// replaces it. Bounded so one caller cannot make the agent buffer whatever it
/// likes, and generous next to what a set of shell scripts is.
pub const MAX_REQUEST: usize = 1024 * 1024;

/// A snippet as a client sends and receives it.
///
/// No `auto_run_on`: that field names *app* servers, and its values are ids of
/// records the app holds. See migration 012.
#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize)]
pub struct Snippet {
    /// The identity, and the caller's to mint — the app makes one for a record
    /// that arrives without it, and a name is a label rather than a key (the
    /// app's own snippet table was once keyed by its name, and a rename
    /// detached everything pointing at it).
    pub id: String,
    pub name: String,
    /// As written, `${…}` macros included. Expanded when it runs, never here.
    pub script: String,
    #[serde(default)]
    pub note: String,
    #[serde(default)]
    pub tags: Vec<String>,
}

#[derive(Serialize)]
struct ListResponse {
    snippets: Vec<Snippet>,
}

#[derive(Deserialize)]
pub struct ReplaceRequest {
    /// The whole library, in the order it should be shown and run in. A replace
    /// rather than a per-snippet edit: the order is part of what is stored, and
    /// expressing a move as a patch would mean renumbering on both sides.
    snippets: Vec<Snippet>,
}

/// A refusal the caller could have avoided, as a stable code naming the row it
/// is about. `index` is a position in the set the caller *sent*, which is the
/// list the caller still has on screen.
///
/// A code rather than a sentence, so the panel phrases it in the viewer's
/// language — the same convention as `/desktop`'s refusals.
#[derive(Debug, Clone, Copy, PartialEq, Eq, Serialize)]
#[serde(tag = "error", rename_all = "snake_case")]
pub enum Refusal {
    /// An entry with no id. Nothing can be stored under it and nothing can be
    /// looked up by it.
    InvalidId { index: usize },
    /// Two entries claiming one id. The second one would overwrite the first.
    DuplicateId { index: usize },
    /// An entry whose name is empty or only whitespace: a row with nothing to
    /// click. The name is stored as written; only its emptiness is refused.
    InvalidName { index: usize },
    DuplicateName { index: usize },
    /// A tag that is empty or only whitespace.
    InvalidTag { index: usize },
    /// Two identical tags on one snippet.
    DuplicateTag { index: usize },
}

#[derive(Deserialize)]
pub struct PlanRequest {
    /// The script to expand. Its text rather than a stored id, because the
    /// expansion is a pure function of it: the editor previews a snippet it has
    /// not saved, and the runner sends what it is about to run. Nothing is
    /// executed either way.
    script: String,
    /// What the caller can answer. An omitted key is a value this caller does
    /// not have, which is not the same as an empty one — a script asking for it
    /// is refused rather than run with a hole in it. See `snippet::PlanError`.
    #[serde(default)]
    context: SnippetContext,
}

#[derive(Serialize)]
struct PlanResponse {
    steps: Vec<Step>,
}

pub async fn list(
    req: HttpRequest,
    app_state: web::types::State<Arc<AppState>>,
) -> Result<HttpResponse, web::Error> {
    if verify_auth(&req, &app_state.config.get_jwt_secret()).is_err() {
        return Ok(HttpResponse::Unauthorized().finish());
    }

    match load(&app_state.db).await {
        Ok(snippets) => Ok(HttpResponse::Ok().json(&ListResponse { snippets })),
        Err(e) => Ok(internal_error(e.to_string())),
    }
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
    let snippets = body.into_inner().snippets;

    if let Err(refusal) = validate(&snippets) {
        // Recorded as a write that was attempted, like `api::desktop`'s: what
        // the row is for is knowing that someone tried to change the library.
        Event::new(Kind::Snippet, Action::Write, Outcome::Error)
            .remote_ip(remote_ip)
            .detail(refusal_code(&refusal))
            .record(&app_state.db)
            .await;
        return Ok(HttpResponse::BadRequest().json(&refusal));
    }

    match store(&app_state.db, &snippets).await {
        Ok(()) => {
            // Names, never scripts: a script is what the user wrote and may hold
            // anything, and the access log is not a place to keep it.
            let subject = snippets
                .iter()
                .map(|s| s.name.as_str())
                .collect::<Vec<_>>()
                .join(", ");
            Event::new(Kind::Snippet, Action::Write, Outcome::Ok)
                .remote_ip(remote_ip)
                .subject(subject)
                .record(&app_state.db)
                .await;
            Ok(HttpResponse::Ok().json(&ListResponse { snippets }))
        }
        Err(e) => {
            Event::new(Kind::Snippet, Action::Write, Outcome::Error)
                .remote_ip(remote_ip)
                .detail(e.to_string())
                .record(&app_state.db)
                .await;
            Ok(internal_error(e.to_string()))
        }
    }
}

/// Expands one script into what a client should type.
///
/// Reads nothing and writes nothing, and the grant it needs is the one the read
/// needs. The refusal is [`sbm_parser::snippet::PlanError`]'s own shape
/// (`{code, key}`) rather than this module's `{error, index}`: what was refused
/// is the script, not a row of a set, and the two cannot be confused for one
/// another.
pub async fn plan(
    req: HttpRequest,
    body: web::types::Json<PlanRequest>,
    app_state: web::types::State<Arc<AppState>>,
) -> Result<HttpResponse, web::Error> {
    if verify_auth(&req, &app_state.config.get_jwt_secret()).is_err() {
        return Ok(HttpResponse::Unauthorized().finish());
    }
    let PlanRequest { script, context } = body.into_inner();

    match snippet::plan(&script, &context) {
        Ok(steps) => Ok(HttpResponse::Ok().json(&PlanResponse { steps })),
        Err(e) => Ok(HttpResponse::BadRequest().json(&e)),
    }
}

/// The first problem in the set, in the order the caller sent it.
///
/// One pass rather than a pass per rule, so which refusal a set with two
/// problems gets depends on which row comes first and nothing else.
fn validate(snippets: &[Snippet]) -> Result<(), Refusal> {
    let mut ids: HashSet<&str> = HashSet::new();
    let mut names: HashSet<&str> = HashSet::new();
    for (index, snippet) in snippets.iter().enumerate() {
        if snippet.id.trim().is_empty() {
            return Err(Refusal::InvalidId { index });
        }
        if !ids.insert(&snippet.id) {
            return Err(Refusal::DuplicateId { index });
        }
        if snippet.name.trim().is_empty() {
            return Err(Refusal::InvalidName { index });
        }
        if !names.insert(&snippet.name) {
            return Err(Refusal::DuplicateName { index });
        }
        let mut tags: HashSet<&str> = HashSet::new();
        for tag in &snippet.tags {
            if tag.trim().is_empty() {
                return Err(Refusal::InvalidTag { index });
            }
            if !tags.insert(tag) {
                return Err(Refusal::DuplicateTag { index });
            }
        }
    }
    Ok(())
}

/// The code alone, for the access log's `detail` — a row that names a position
/// in a list the log does not hold would be a number with nothing to read it
/// against.
fn refusal_code(refusal: &Refusal) -> String {
    serde_json::to_value(refusal)
        .ok()
        .and_then(|v| v.get("error").and_then(|e| e.as_str()).map(str::to_string))
        .unwrap_or_else(|| "refused".to_string())
}

async fn load(db: &SqlitePool) -> Result<Vec<Snippet>, sqlx::Error> {
    let rows = sqlx::query_as::<_, (String, String, String, String)>(
        "SELECT id, name, script, note FROM snippet ORDER BY position",
    )
    .fetch_all(db)
    .await?;

    // Every tag in one query and grouped here rather than one query per
    // snippet: the library is read whole, and a page of twenty would otherwise
    // be twenty-one round trips.
    let tag_rows = sqlx::query_as::<_, (String, String)>(
        "SELECT snippet_id, tag FROM snippet_tag ORDER BY snippet_id, position",
    )
    .fetch_all(db)
    .await?;

    Ok(rows
        .into_iter()
        .map(|(id, name, script, note)| {
            let tags = tag_rows
                .iter()
                .filter(|(snippet_id, _)| snippet_id == &id)
                .map(|(_, tag)| tag.clone())
                .collect();
            Snippet {
                id,
                name,
                script,
                note,
                tags,
            }
        })
        .collect())
}

/// Replaces the whole library, or none of it.
///
/// One transaction, so a failure partway through leaves the set that was there
/// rather than a prefix of the new one — a library half-written is one the
/// operator cannot tell from a deliberate edit.
async fn store(db: &SqlitePool, snippets: &[Snippet]) -> Result<(), sqlx::Error> {
    let mut tx = db.begin().await?;
    // The tags go with them: `snippet_tag` is `ON DELETE CASCADE` and
    // `foreign_keys` is on, which sqlx sets on every connection.
    sqlx::query("DELETE FROM snippet").execute(&mut *tx).await?;

    let now = chrono::Utc::now();
    for (position, snippet) in snippets.iter().enumerate() {
        sqlx::query(
            "INSERT INTO snippet (id, name, script, note, position, updated_at) \
             VALUES (?, ?, ?, ?, ?, ?)",
        )
        .bind(&snippet.id)
        .bind(&snippet.name)
        .bind(&snippet.script)
        .bind(&snippet.note)
        .bind(position as i64)
        .bind(now)
        .execute(&mut *tx)
        .await?;

        for (tag_position, tag) in snippet.tags.iter().enumerate() {
            sqlx::query("INSERT INTO snippet_tag (snippet_id, tag, position) VALUES (?, ?, ?)")
                .bind(&snippet.id)
                .bind(tag)
                .bind(tag_position as i64)
                .execute(&mut *tx)
                .await?;
        }
    }
    tx.commit().await?;
    Ok(())
}

fn internal_error(message: String) -> HttpResponse {
    HttpResponse::InternalServerError().json(&serde_json::json!({ "error": message }))
}

#[cfg(test)]
mod tests {
    use super::*;

    fn snippet(id: &str, name: &str) -> Snippet {
        Snippet {
            id: id.to_string(),
            name: name.to_string(),
            script: "ls".to_string(),
            note: String::new(),
            tags: Vec::new(),
        }
    }

    #[test]
    fn a_well_formed_set_is_accepted() {
        assert_eq!(
            validate(&[snippet("a", "one"), snippet("b", "two")]),
            Ok(())
        );
        // The same tag on two snippets is not a collision: tags are shared
        // vocabulary, and filing two scripts under one word is the point.
        let mut first = snippet("a", "one");
        first.tags = vec!["ops".to_string()];
        let mut second = snippet("b", "two");
        second.tags = vec!["ops".to_string()];
        assert_eq!(validate(&[first, second]), Ok(()));
    }

    #[test]
    fn the_first_problem_in_the_set_is_the_one_reported() {
        // Both entries are wrong; the one that comes first is the answer.
        assert_eq!(
            validate(&[snippet("", "one"), snippet("b", "")]),
            Err(Refusal::InvalidId { index: 0 })
        );
        // Whitespace is not a name.
        assert_eq!(
            validate(&[snippet("a", "  ")]),
            Err(Refusal::InvalidName { index: 0 })
        );
    }

    #[test]
    fn a_repeat_is_reported_at_the_second_sighting() {
        assert_eq!(
            validate(&[snippet("a", "one"), snippet("a", "two")]),
            Err(Refusal::DuplicateId { index: 1 })
        );
        assert_eq!(
            validate(&[snippet("a", "one"), snippet("b", "one")]),
            Err(Refusal::DuplicateName { index: 1 })
        );
        let mut first = snippet("a", "one");
        first.tags = vec!["ops".to_string(), "ops".to_string()];
        assert_eq!(validate(&[first]), Err(Refusal::DuplicateTag { index: 0 }));
    }

    /// The code the log gets is the code the caller got, without the position.
    #[test]
    fn the_logged_detail_is_the_code_alone() {
        assert_eq!(refusal_code(&Refusal::DuplicateName { index: 3 }), "duplicate_name");
        assert_eq!(refusal_code(&Refusal::InvalidTag { index: 0 }), "invalid_tag");
    }
}
