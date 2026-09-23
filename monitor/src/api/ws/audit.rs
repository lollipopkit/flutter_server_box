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
    Terminal,
    /// A one-off command run through `api::exec`.
    Exec,
    /// A raw TCP connection relayed through `api::ws::stream` — a remote
    /// desktop session or a forwarded port. The detail is the address, which
    /// is the operator's own network rather than anything a client sent.
    Stream,
    /// A file operation through `api::fs`. The subject is the verb and the
    /// path, never the contents.
    Fs,
    /// A change to the custom commands the status script runs. Recorded like
    /// `Exec` because it amounts to the same thing on the next cycle; the
    /// subject is the names, never the command bodies.
    CustomCmd,
    /// A change to the notification channels, or a test sent through one. The
    /// subject is the channel names and types, plus the host a test webhook
    /// went to — never a key, a token or a header value.
    Push,
    /// A shutdown, reboot or suspend asked of `api::power`. Its own kind rather
    /// than `Exec`, whose subject is the command text: this one is an action
    /// name, and the row that matters most here is the one written *before* the
    /// machine goes down.
    Power,
    /// A change to the account's crontab through `api::cron`. Its own kind for
    /// `Power`'s reason: what it edits is a file the machine acts on later, and
    /// the subject is the operation and the schedule, never the command.
    Cron,
}

impl Kind {
    fn as_str(self) -> &'static str {
        match self {
            Kind::Ticket => "ticket",
            Kind::Terminal => "terminal",
            Kind::Exec => "exec",
            Kind::Stream => "stream",
            Kind::Fs => "fs",
            Kind::CustomCmd => "custom_cmd",
            Kind::Push => "push",
            Kind::Power => "power",
            Kind::Cron => "cron",
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
    /// This endpoint's own verb: a connection to an address the caller named
    /// was made. Its own action rather than `Open`, which for a terminal means
    /// a shell and is answered with a session handle this has none of.
    Connect,
    /// This endpoint's own verb: a change the caller described was applied, or
    /// was attempted and failed. Its own action for `Connect`'s reason —
    /// `Open`/`Close` describe a session's lifecycle, and a single write that
    /// either landed or did not has no lifecycle to record. Recorded once,
    /// after the outcome is known, unlike the power endpoint's row: there the
    /// machine going down *is* the success, so the intent has to be written
    /// down before it can be.
    Write,
}

impl Action {
    fn as_str(self) -> &'static str {
        match self {
            Action::Open => "open",
            Action::Attach => "attach",
            Action::Detach => "detach",
            Action::Close => "close",
            Action::Denied => "denied",
            Action::Connect => "connect",
            Action::Write => "write",
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
/// mention the fields that apply to them — a denied ticket has no `subject`.
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
        // Supplied rather than defaulted. The column used to carry
        // `CURRENT_TIMESTAMP`, whose `YYYY-MM-DD HH:MM:SS` does not compare
        // against the RFC 3339 every other timestamp in this database is
        // written as, and retention compares this one — see migration 009.
        let write = sqlx::query(
            "INSERT INTO access_log \
             (timestamp, kind, action, subject, remote_ip, ssh_user, result, detail) \
             VALUES (?, ?, ?, ?, ?, ?, ?, ?)",
        )
        .bind(chrono::Utc::now())
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
