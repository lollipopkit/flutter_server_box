//! `GET/PUT /api/v1/snippets` and `POST /api/v1/snippets/plan` — the snippet
//! library saved on this agent, and what one of its scripts types.
//!
//! A snippet is a script the operator wrote once to run again, with `${…}`
//! macros filled in when it runs. The library is the agent's (migration 013);
//! the macro language is [`sbm_parser::snippet`], which the app calls through
//! FFI, so a script means the same thing in both clients. `/plan` returns the
//! steps a terminal is fed and executes none of them: the panel types them
//! into its own terminal session.
//!
//! # Privilege
//!
//! The `shell` grant for all three (`api::machine::gate`). Running a snippet is
//! typing into a shell, and saving one is preparing what will be typed; a
//! script can also carry a password, so reading the library needs the grant
//! too, for the reason `/process` does.

use std::collections::HashSet;
use std::sync::Arc;

use ntex::web::{self, HttpRequest, HttpResponse};
use serde::{Deserialize, Serialize};
use sqlx::SqlitePool;

use sbm_parser::snippet::{self, SnippetContext, Step};

use super::machine;
use super::server::AppState;
use super::ws::audit::{Action, Event, Kind, Outcome};
use crate::core::permissions::Grant;

/// The largest request body accepted: the whole library at once, since a write
/// replaces it. Bounded so one caller cannot make the agent buffer whatever it
/// likes, and generous next to what a set of shell scripts is.
pub const MAX_REQUEST: usize = 1024 * 1024;

/// A snippet as a client sends and receives it.
#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize)]
pub struct Snippet {
    /// Minted by the client, as the app does. A name is a label, not a key.
    pub id: String,
    pub name: String,
    /// As written, `${…}` macros included.
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
    /// The whole library, in the order it is shown. A replace rather than a
    /// per-snippet edit: the order is part of what is stored.
    snippets: Vec<Snippet>,
}

/// A library refused before it was stored: a stable code for the panel to
/// phrase, and `index`, the position in the set the caller sent.
#[derive(Debug, Clone, Copy, PartialEq, Eq, Serialize)]
#[serde(tag = "error", rename_all = "camelCase")]
pub enum Refusal {
    /// Empty or only whitespace.
    InvalidId { index: usize },
    /// The second entry with one id would overwrite the first.
    DuplicateId { index: usize },
    /// Empty or only whitespace: a row with nothing to click.
    InvalidName { index: usize },
    DuplicateName { index: usize },
    /// Empty or only whitespace.
    InvalidTag { index: usize },
    /// The same tag twice on one snippet.
    DuplicateTag { index: usize },
}

#[derive(Deserialize)]
pub struct PlanRequest {
    /// The text rather than a stored id: the expansion is a function of it,
    /// and the runner sends what it is about to run.
    script: String,
    /// What the caller can answer. An omitted key is a value it does not have,
    /// and a script asking for one is refused (`{"error":"unanswerable",
    /// "key":…}`) rather than run with a hole in it.
    #[serde(default)]
    context: SnippetContext,
}

#[derive(Serialize)]
struct PlanResponse {
    steps: Vec<Step>,
}

pub async fn list(
    req: HttpRequest,
    state: web::types::State<Arc<AppState>>,
) -> Result<HttpResponse, web::Error> {
    if let Err(refused) = machine::gate(&req, &state, Grant::Shell, "snippets list").await {
        return Ok(refused);
    }
    match load(&state.db).await {
        Ok(snippets) => Ok(HttpResponse::Ok().json(&ListResponse { snippets })),
        Err(e) => Ok(internal_error(&e)),
    }
}

pub async fn replace(
    req: HttpRequest,
    body: web::types::Json<ReplaceRequest>,
    state: web::types::State<Arc<AppState>>,
) -> Result<HttpResponse, web::Error> {
    let gated = match machine::gate(&req, &state, Grant::Shell, "snippets replace").await {
        Ok(gated) => gated,
        Err(refused) => return Ok(refused),
    };
    let snippets = body.into_inner().snippets;
    if let Err(refusal) = validate(&snippets) {
        return Ok(HttpResponse::BadRequest().json(&refusal));
    }

    // Names, never scripts: a script is the operator's text and may hold
    // anything, and the access log is not a place to keep it.
    let names = snippets
        .iter()
        .map(|s| s.name.as_str())
        .collect::<Vec<_>>()
        .join(", ");
    let what = format!("snippets replace: {names}");
    match store(&state.db, &snippets).await {
        Ok(()) => {
            Event::new(Kind::Machine, Action::Open, Outcome::Ok)
                .subject(&gated.caller.username)
                .remote_ip(gated.remote_ip)
                .detail(&what)
                .record(&state.db)
                .await;
            Ok(HttpResponse::Ok().json(&ListResponse { snippets }))
        }
        Err(e) => {
            Event::new(Kind::Machine, Action::Close, Outcome::Error)
                .subject(&gated.caller.username)
                .remote_ip(gated.remote_ip)
                .detail(format!("{what}: write failed"))
                .record(&state.db)
                .await;
            Ok(internal_error(&e))
        }
    }
}

/// Expands one script into what a client should type. Reads and writes
/// nothing; the steps are `sbm_parser::snippet::Step`'s wire shape.
pub async fn plan(
    req: HttpRequest,
    body: web::types::Json<PlanRequest>,
    state: web::types::State<Arc<AppState>>,
) -> Result<HttpResponse, web::Error> {
    if let Err(refused) = machine::gate(&req, &state, Grant::Shell, "snippets plan").await {
        return Ok(refused);
    }
    let PlanRequest { script, context } = body.into_inner();
    match snippet::plan(&script, &context) {
        Ok(steps) => Ok(HttpResponse::Ok().json(&PlanResponse { steps })),
        Err(e) => Ok(HttpResponse::BadRequest().json(&e)),
    }
}

/// The first problem in the set, in the order the caller sent it.
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

async fn load(db: &SqlitePool) -> Result<Vec<Snippet>, sqlx::Error> {
    let rows = sqlx::query_as::<_, (String, String, String, String)>(
        "SELECT id, name, script, note FROM snippet ORDER BY position",
    )
    .fetch_all(db)
    .await?;
    let tag_rows = sqlx::query_as::<_, (String, String)>(
        "SELECT snippet_id, tag FROM snippet_tag ORDER BY snippet_id, position",
    )
    .fetch_all(db)
    .await?;

    let mut tags: std::collections::HashMap<String, Vec<String>> = Default::default();
    for (snippet_id, tag) in tag_rows {
        tags.entry(snippet_id).or_default().push(tag);
    }
    Ok(rows
        .into_iter()
        .map(|(id, name, script, note)| Snippet {
            tags: tags.remove(&id).unwrap_or_default(),
            id,
            name,
            script,
            note,
        })
        .collect())
}

/// Replaces the whole library in one transaction, so a failure partway leaves
/// the set that was there rather than a prefix of the new one.
async fn store(db: &SqlitePool, snippets: &[Snippet]) -> Result<(), sqlx::Error> {
    let mut tx = db.begin().await?;
    // Explicitly, rather than through the cascade: what is removed should not
    // depend on a connection pragma.
    sqlx::query("DELETE FROM snippet_tag").execute(&mut *tx).await?;
    sqlx::query("DELETE FROM snippet").execute(&mut *tx).await?;

    let now = chrono::Utc::now().to_rfc3339();
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
        .bind(&now)
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
    tx.commit().await
}

fn internal_error(e: &sqlx::Error) -> HttpResponse {
    tracing::error!("snippets: {e}");
    HttpResponse::InternalServerError().json(&serde_json::json!({ "error": "internal" }))
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
        assert_eq!(validate(&[snippet("a", "one"), snippet("b", "two")]), Ok(()));
        // One tag on two snippets is the point of a tag.
        let mut first = snippet("a", "one");
        first.tags = vec!["ops".to_string()];
        let mut second = snippet("b", "two");
        second.tags = vec!["ops".to_string()];
        assert_eq!(validate(&[first, second]), Ok(()));
    }

    #[test]
    fn the_first_problem_in_the_set_is_the_one_reported() {
        assert_eq!(
            validate(&[snippet("", "one"), snippet("b", "")]),
            Err(Refusal::InvalidId { index: 0 })
        );
        assert_eq!(validate(&[snippet("a", "  ")]), Err(Refusal::InvalidName { index: 0 }));
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

    #[test]
    fn a_refusal_is_a_code_and_the_row() {
        assert_eq!(
            serde_json::to_value(Refusal::DuplicateName { index: 3 }).unwrap(),
            serde_json::json!({"error": "duplicateName", "index": 3})
        );
    }
}
