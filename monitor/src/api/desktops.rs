//! `GET/PUT /api/v1/desktops` — the remote desktops the panel opens through
//! this agent, as saved routes.
//!
//! A route is where a desktop is as seen from this machine and how to open
//! it; nothing here dials anything. A session is `/api/v1/stream/ws`, which
//! relays one TCP connection, and the panel runs the protocol client (noVNC)
//! over it. The agent understands neither the route's protocol nor the bytes.
//!
//! **No password is stored** (migration 014): it is typed in the browser that
//! runs the session and reaches the desktop only.
//!
//! What a route may hold is `sbm_parser::desktop`'s, the rules the app's
//! profile editor applies too; this module adds only what a set has (unique
//! ids and names).
//!
//! # Privilege
//!
//! The `connect` grant for both halves (`docs/dev/monitor-permissions.md`):
//! a route is only worth anything through the relay, which checks the same
//! grant and its `allow` list again when the socket opens. A route outside the
//! list can be saved; opening it is refused there.

use std::collections::HashSet;
use std::sync::Arc;

use ntex::web::{self, HttpRequest, HttpResponse};
use serde::{Deserialize, Serialize};
use sqlx::SqlitePool;

use sbm_parser::desktop::{self, ProfileInput};

use super::machine;
use super::server::AppState;
use super::ws::audit::{Action, Event, Kind, Outcome};
use crate::core::permissions::Grant;


/// One route as the panel sends and receives it.
#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize)]
pub struct Desktop {
    /// Minted by the client. A name is a label, not a key.
    pub id: String,
    pub name: String,
    pub protocol: String,
    /// Dialled by this agent: `127.0.0.1` is this machine.
    pub host: String,
    pub port: u16,
    #[serde(default)]
    pub username: Option<String>,
    #[serde(default)]
    pub domain: Option<String>,
    #[serde(default)]
    pub view_only: bool,
    #[serde(default = "shared_default")]
    pub shared: bool,
}

fn shared_default() -> bool {
    true
}

#[derive(Serialize)]
struct ProtocolView {
    id: &'static str,
    default_port: u16,
}

#[derive(Serialize)]
struct ListResponse {
    desktops: Vec<Desktop>,
    /// Sent rather than hard-coded in the panel, so a protocol added here
    /// reaches every client.
    protocols: Vec<ProtocolView>,
}

#[derive(Deserialize)]
pub struct ReplaceRequest {
    /// The whole set, in order. A replace rather than a per-route edit: the
    /// order is part of what is stored.
    desktops: Vec<Desktop>,
}

/// A set refused before it was stored: a stable code for the panel to
/// phrase, and `index`, the position in the set the caller sent. The codes
/// are `sbm_parser::desktop::ProfileError`'s plus the set's own.
#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum Refusal {
    InvalidId { index: usize },
    DuplicateId { index: usize },
    DuplicateName { index: usize },
    Profile { index: usize, error: desktop::ProfileError },
}

impl Serialize for Refusal {
    fn serialize<S: serde::Serializer>(&self, serializer: S) -> Result<S::Ok, S::Error> {
        let (code, index) = match self {
            Refusal::InvalidId { index } => ("invalidId", index),
            Refusal::DuplicateId { index } => ("duplicateId", index),
            Refusal::DuplicateName { index } => ("duplicateName", index),
            Refusal::Profile { index, error } => (error.as_str(), index),
        };
        serde_json::json!({ "error": code, "index": index }).serialize(serializer)
    }
}

pub async fn list(
    req: HttpRequest,
    state: web::types::State<Arc<AppState>>,
) -> Result<HttpResponse, web::Error> {
    if let Err(refused) = machine::gate(&req, &state, Grant::Connect, "desktops list").await {
        return Ok(refused);
    }
    match load(&state.db).await {
        Ok(desktops) => Ok(HttpResponse::Ok().json(&response(desktops))),
        Err(e) => Ok(internal_error(&e)),
    }
}

pub async fn replace(
    req: HttpRequest,
    body: web::types::Json<ReplaceRequest>,
    state: web::types::State<Arc<AppState>>,
) -> Result<HttpResponse, web::Error> {
    let gated = match machine::gate(&req, &state, Grant::Connect, "desktops replace").await {
        Ok(gated) => gated,
        Err(refused) => return Ok(refused),
    };
    let desktops = body.into_inner().desktops;
    if let Err(refusal) = validate(&desktops) {
        return Ok(HttpResponse::BadRequest().json(&refusal));
    }

    let names = desktops
        .iter()
        .map(|d| d.name.as_str())
        .collect::<Vec<_>>()
        .join(", ");
    let what = format!("desktops replace: {names}");
    match store(&state.db, &desktops).await {
        Ok(()) => {
            Event::new(Kind::Machine, Action::Open, Outcome::Ok)
                .subject(&gated.caller.username)
                .remote_ip(gated.remote_ip)
                .detail(&what)
                .record(&state.db)
                .await;
            Ok(HttpResponse::Ok().json(&response(desktops)))
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

fn response(desktops: Vec<Desktop>) -> ListResponse {
    ListResponse {
        desktops,
        protocols: desktop::PROTOCOLS
            .iter()
            .map(|(id, default_port)| ProtocolView {
                id,
                default_port: *default_port,
            })
            .collect(),
    }
}

/// The first problem in the set, in the order the caller sent it.
fn validate(desktops: &[Desktop]) -> Result<(), Refusal> {
    let mut ids: HashSet<&str> = HashSet::new();
    let mut names: HashSet<&str> = HashSet::new();
    for (index, d) in desktops.iter().enumerate() {
        if d.id.trim().is_empty() {
            return Err(Refusal::InvalidId { index });
        }
        if !ids.insert(&d.id) {
            return Err(Refusal::DuplicateId { index });
        }
        desktop::validate_profile(&ProfileInput {
            name: d.name.clone(),
            protocol: d.protocol.clone(),
            host: d.host.clone(),
            port: Some(i64::from(d.port)),
            username: d.username.clone(),
            domain: d.domain.clone(),
        })
        .map_err(|error| Refusal::Profile { index, error })?;
        if !names.insert(&d.name) {
            return Err(Refusal::DuplicateName { index });
        }
    }
    Ok(())
}

type Row = (String, String, String, String, i64, Option<String>, Option<String>, bool, bool);

async fn load(db: &SqlitePool) -> Result<Vec<Desktop>, sqlx::Error> {
    let rows = sqlx::query_as::<_, Row>(
        "SELECT id, name, protocol, host, port, username, domain, view_only, shared \
         FROM desktop_profile ORDER BY position",
    )
    .fetch_all(db)
    .await?;
    Ok(rows
        .into_iter()
        .map(
            |(id, name, protocol, host, port, username, domain, view_only, shared)| Desktop {
                id,
                name,
                protocol,
                host,
                // Written from a `u16`, so anything else is a row this agent did
                // not write; 0 is what the form refuses, and says so.
                port: u16::try_from(port).unwrap_or(0),
                username,
                domain,
                view_only,
                shared,
            },
        )
        .collect())
}

/// Replaces the whole set in one transaction.
async fn store(db: &SqlitePool, desktops: &[Desktop]) -> Result<(), sqlx::Error> {
    let mut tx = db.begin().await?;
    sqlx::query("DELETE FROM desktop_profile").execute(&mut *tx).await?;
    let now = chrono::Utc::now().to_rfc3339();
    for (position, d) in desktops.iter().enumerate() {
        sqlx::query(
            "INSERT INTO desktop_profile \
             (id, name, protocol, host, port, username, domain, view_only, shared, position, updated_at) \
             VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)",
        )
        .bind(&d.id)
        .bind(&d.name)
        .bind(&d.protocol)
        .bind(&d.host)
        .bind(i64::from(d.port))
        .bind(&d.username)
        .bind(&d.domain)
        .bind(d.view_only)
        .bind(d.shared)
        .bind(position as i64)
        .bind(&now)
        .execute(&mut *tx)
        .await?;
    }
    tx.commit().await
}

fn internal_error(e: &sqlx::Error) -> HttpResponse {
    tracing::error!("desktops: {e}");
    HttpResponse::InternalServerError().json(&serde_json::json!({ "error": "internal" }))
}

#[cfg(test)]
mod tests {
    use super::*;

    fn desktop(id: &str, name: &str) -> Desktop {
        Desktop {
            id: id.to_string(),
            name: name.to_string(),
            protocol: "vnc".to_string(),
            host: "127.0.0.1".to_string(),
            port: 5900,
            username: None,
            domain: None,
            view_only: false,
            shared: true,
        }
    }

    #[test]
    fn a_well_formed_set_is_accepted() {
        assert_eq!(validate(&[desktop("a", "one"), desktop("b", "two")]), Ok(()));
    }

    #[test]
    fn a_route_is_refused_by_the_shared_rules_at_its_row() {
        use desktop::ProfileError::*;
        let cases: Vec<(Desktop, desktop::ProfileError)> = vec![
            (desktop("b", "  "), NameRequired),
            (Desktop { host: "a b".into(), ..desktop("b", "x") }, InvalidHost),
            (Desktop { port: 0, ..desktop("b", "x") }, InvalidPort),
            (Desktop { protocol: "rdp".into(), port: 3389, ..desktop("b", "x") }, UsernameRequired),
        ];
        for (second, error) in cases {
            assert_eq!(
                validate(&[desktop("a", "one"), second.clone()]),
                Err(Refusal::Profile { index: 1, error }),
                "{second:?}"
            );
        }
        assert_eq!(
            validate(&[desktop("a", "one"), desktop(" ", "x")]),
            Err(Refusal::InvalidId { index: 1 })
        );
    }

    #[test]
    fn a_repeat_is_reported_at_the_second_sighting() {
        assert_eq!(
            validate(&[desktop("a", "one"), desktop("a", "two")]),
            Err(Refusal::DuplicateId { index: 1 })
        );
        assert_eq!(
            validate(&[desktop("a", "one"), desktop("b", "one")]),
            Err(Refusal::DuplicateName { index: 1 })
        );
    }

    #[test]
    fn a_refusal_is_a_code_and_the_row() {
        assert_eq!(
            serde_json::to_value(Refusal::Profile { index: 2, error: desktop::ProfileError::InvalidHost })
                .unwrap(),
            serde_json::json!({"error": "invalidHost", "index": 2})
        );
    }
}
