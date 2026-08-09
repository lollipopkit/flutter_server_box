//! Append-only record of remote-access activity.
//!
//! Shell access reached through an HTTP API is exactly the kind of thing
//! someone needs to reconstruct after the fact — who connected, from where,
//! as which system user, and whether it was refused. `tracing` alone isn't
//! enough: log files rotate away and are usually not what an operator still
//! has weeks later, whereas the database is already being retained and
//! cleaned on a schedule.
//!
//! Nothing here ever touches a credential. `ssh_user` is an account name; the
//! password, key and passphrase that authenticated it never leave the
//! terminal handler's memory.
//!
//! Writes are best-effort: failing to record an event must not tear down a
//! working session, so errors are logged and swallowed. That makes the log a
//! diagnostic aid rather than a tamper-evident audit trail, which is the
//! right trade for a single-agent monitoring tool.

use ntex::web::HttpRequest;
use sqlx::SqlitePool;

/// Which subsystem the event came from.
#[derive(Debug, Clone, Copy)]
pub enum Kind {
    /// Issuing a WebSocket ticket
    Ticket,
    Tunnel,
    Terminal,
}

impl Kind {
    fn as_str(self) -> &'static str {
        match self {
            Kind::Ticket => "ticket",
            Kind::Tunnel => "tunnel",
            Kind::Terminal => "terminal",
        }
    }
}

/// What happened. `Attach`/`Detach` only apply to terminals, where a session
/// outlives the connection driving it.
#[derive(Debug, Clone, Copy)]
pub enum Action {
    Open,
    Attach,
    Detach,
    Close,
    Denied,
}

impl Action {
    fn as_str(self) -> &'static str {
        match self {
            Action::Open => "open",
            Action::Attach => "attach",
            Action::Detach => "detach",
            Action::Close => "close",
            Action::Denied => "denied",
        }
    }
}

#[derive(Debug, Clone, Copy)]
pub enum Outcome {
    Ok,
    Denied,
    Error,
}

impl Outcome {
    fn as_str(self) -> &'static str {
        match self {
            Outcome::Ok => "ok",
            Outcome::Denied => "denied",
            Outcome::Error => "error",
        }
    }
}

/// One row to be written. Built with the fluent setters so call sites only
/// mention the fields that apply to them — a tunnel has no `ssh_user`, a
/// denied ticket has no `subject`.
pub struct Event {
    kind: Kind,
    action: Action,
    outcome: Outcome,
    subject: Option<String>,
    remote_ip: Option<String>,
    ssh_user: Option<String>,
    detail: Option<String>,
}

impl Event {
    pub fn new(kind: Kind, action: Action, outcome: Outcome) -> Self {
        Self {
            kind,
            action,
            outcome,
            subject: None,
            remote_ip: None,
            ssh_user: None,
            detail: None,
        }
    }

    pub fn subject(mut self, subject: impl Into<String>) -> Self {
        self.subject = Some(subject.into());
        self
    }

    pub fn remote_ip(mut self, ip: Option<String>) -> Self {
        self.remote_ip = ip;
        self
    }

    pub fn ssh_user(mut self, user: impl Into<String>) -> Self {
        self.ssh_user = Some(user.into());
        self
    }

    /// Free-text context — a refusal reason, a close code. Must never carry
    /// anything secret; callers pass error categories, not raw error strings
    /// that might quote a credential back.
    pub fn detail(mut self, detail: impl Into<String>) -> Self {
        self.detail = Some(detail.into());
        self
    }

    pub async fn record(self, pool: &SqlitePool) {
        let kind = self.kind.as_str();
        let action = self.action.as_str();
        let result = self.outcome.as_str();
        let write = sqlx::query(
            "INSERT INTO access_log (kind, action, subject, remote_ip, ssh_user, result, detail) \
             VALUES (?, ?, ?, ?, ?, ?, ?)",
        )
        .bind(kind)
        .bind(action)
        .bind(&self.subject)
        .bind(&self.remote_ip)
        .bind(&self.ssh_user)
        .bind(result)
        .bind(&self.detail)
        .execute(pool)
        .await;

        if let Err(e) = write {
            tracing::warn!("Failed to record {kind}/{action} in access_log: {e}");
        }
    }
}

/// The peer address as a string, for [`Event::remote_ip`].
///
/// The port is dropped: it identifies one connection, not a client, and
/// keeping it would only make the column harder to group by.
pub fn peer_ip(req: &HttpRequest) -> Option<String> {
    req.peer_addr().map(|addr| addr.ip().to_string())
}
