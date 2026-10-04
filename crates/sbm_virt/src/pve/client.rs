//! One PVE host's session, and what it answers in [`crate::model`] terms.
//!
//! **Auth.** A token goes in every request; a password logs in for a ticket
//! and a `CSRFPreventionToken`, and an account with TOTP stops at
//! [`ErrorKind::NeedTfa`] until [`Client::submit_tfa`].
//!
//! **Sessions.** One login at a time. [`Client::reset`] (and a 401, or a
//! transport failure) moves to a new generation; a login still running for an
//! older one finishes, finds itself stale and discards what it made, and the
//! next call logs in again only after it has — so two logins never overlap
//! and a stale one never becomes the session.
//!
//! **Ticket lifetime.** PVE refuses a ticket, and a TFA challenge, two hours
//! after issuing it. A password session renews its ticket once it is an hour
//! old, by sending the ticket as the password — what PVE's own web UI does,
//! asking no second factor. A ticket refused anyway (the client slept past
//! the lifetime) is replaced by one new login and the request repeated.
//!
//! **403 never ends a session.** PVE answers 403 only after it accepted the
//! ticket or token, from its permission check: the account lacks a privilege
//! on that path. On a guest action it is [`ErrorKind::ActionFailed`] with
//! PVE's text; elsewhere [`ErrorKind::AuthFailed`].

use std::collections::{BTreeMap, HashMap};
use std::sync::{Arc, Mutex};
use std::time::Duration;

use sbm_redfish::cert::CertInfo;
use serde_json::{Map, Value};

use super::http::{Body, Connector, Http, Method, Request, Response, Stream, TransportError, Upgrade};
use super::resources;
use super::{Auth, Config, form, seg, version_less_than};
use crate::error::{Detail, Error, ErrorKind, Result};
use crate::model::{Capabilities, ConsoleKind, Guest, GuestDetail, GuestKind, HistoryWindow, Host, HostKind, HostView, PowerAction, Stats};
use crate::rates::RateTracker;

mod backup;
mod create;
mod hardware;
mod storage;

pub use create::IMPORT_CONTENT_SINCE;

/// How long PVE accepts a ticket or a TFA challenge (`$ticket_lifetime` in
/// `PVE::AccessControl`, 2 hours on PVE 9.2).
pub const TICKET_LIFETIME_MS: i64 = 2 * 3600 * 1000;

/// When a password session renews its ticket. PVE's web UI renews every 15
/// minutes; an hour leaves as much margin while a view refreshes every few
/// seconds.
pub const RENEW_AFTER_MS: i64 = 3600 * 1000;

/// Treated as expired this long before the lifetime, for the time a request
/// spends in flight and clocks that drift.
const LIFETIME_MARGIN_MS: i64 = 5 * 60 * 1000;

/// How long a state read right after an action overrides the listing — see
/// [`State::fresh`].
pub const FRESH_STATUS_FOR_MS: i64 = 30 * 1000;

/// How long a reboot's guest may read as not running once its task has
/// ended, before that is believed.
pub const REBOOT_RESTART_TIMEOUT_MS: i64 = 30 * 1000;

/// The first release whose `status/stop` takes `overrule-shutdown`. Sent only
/// to a release known to have it: an older one refuses the request for a
/// parameter it does not know.
pub const OVERRULE_SHUTDOWN_SINCE: [u32; 2] = [8, 1];

const API: &str = "/api2/json";

/// Wall time, injected so the session's clock can be driven in tests.
pub trait Clock: Send + Sync {
    /// Unix milliseconds.
    fn now_ms(&self) -> i64;
}

pub struct SystemClock;

impl Clock for SystemClock {
    fn now_ms(&self) -> i64 {
        std::time::SystemTime::now()
            .duration_since(std::time::UNIX_EPOCH)
            .map(|d| d.as_millis() as i64)
            .unwrap_or(0)
    }
}

pub struct Options {
    /// How often a task is asked whether it has finished, and for how long.
    pub task_poll: Duration,
    pub task_timeout: Duration,
    pub clock: Arc<dyn Clock>,
}

impl Default for Options {
    fn default() -> Self {
        Self {
            task_poll: Duration::from_secs(1),
            task_timeout: Duration::from_secs(600),
            clock: Arc::new(SystemClock),
        }
    }
}

enum SessionAuth {
    /// The `Authorization` header's value.
    Token(String),
    Ticket { ticket: String, csrf: Option<String>, issued_at: i64 },
}

struct Session {
    generation: u64,
    http: Arc<dyn Http>,
    /// The account it was opened for, which a renewal names.
    user: Vec<(&'static str, String)>,
    auth: Mutex<SessionAuth>,
    /// Held by the one renewal in flight, which every caller waits for.
    renewing: tokio::sync::Mutex<()>,
}

impl Session {
    fn headers(&self) -> Vec<(String, String)> {
        match &*self.auth.lock().unwrap() {
            SessionAuth::Token(header) => vec![("Authorization".into(), header.clone())],
            SessionAuth::Ticket { ticket, csrf, .. } => {
                let mut h = vec![("Cookie".into(), format!("PVEAuthCookie={ticket}"))];
                if let Some(csrf) = csrf {
                    h.push(("CSRFPreventionToken".into(), csrf.clone()));
                }
                h
            }
        }
    }

    fn ticket(&self) -> Option<(String, i64)> {
        match &*self.auth.lock().unwrap() {
            SessionAuth::Ticket { ticket, issued_at, .. } => Some((ticket.clone(), *issued_at)),
            SessionAuth::Token(_) => None,
        }
    }
}

/// A password login waiting for its TOTP code, and the account it is for.
struct Challenge {
    generation: u64,
    http: Arc<dyn Http>,
    ticket: String,
    issued_at: i64,
    user: Vec<(&'static str, String)>,
}

/// A guest's state read from `status/current` right after an action.
struct Fresh {
    status: String,
    uptime: Option<i64>,
    at: i64,
}

struct State {
    config: Config,
    /// For [`State::config`]; made on first use.
    http: Option<Arc<dyn Http>>,
    generation: u64,
    session: Option<Arc<Session>>,
    tfa: Option<Challenge>,
    release: Option<String>,
    /// The certificate the last refused handshake presented — what
    /// [`Client::confirm_cert`] may pin.
    presented: Option<CertInfo>,
    rates: RateTracker,
    /// Guest states read from `status/current` right after an action, laid
    /// over `/cluster/resources` until that agrees — the same status, and no
    /// longer an uptime from before a reboot — or [`FRESH_STATUS_FOR_MS`] has
    /// passed. The listing is what `pvestatd` last broadcast, which lags by
    /// up to its ~10 s cycle: on PVE 9.2 a container still read `running`
    /// there 8 s after its `stop` task had ended.
    fresh: HashMap<String, Fresh>,
    closed: bool,
}

pub struct Client {
    connector: Arc<dyn Connector>,
    opts: Options,
    state: Mutex<State>,
    /// Held by the login in flight.
    login: tokio::sync::Mutex<()>,
    /// Each node's network changes, one at a time — see [`Client::manage`].
    net_changes: Mutex<HashMap<String, Arc<tokio::sync::Mutex<()>>>>,
}

impl Client {
    pub fn new(config: Config, connector: Arc<dyn Connector>, opts: Options) -> Self {
        Self {
            connector,
            opts,
            state: Mutex::new(State {
                config,
                http: None,
                generation: 0,
                session: None,
                tfa: None,
                release: None,
                presented: None,
                rates: RateTracker::new(true),
                fresh: HashMap::new(),
                closed: false,
            }),
            login: tokio::sync::Mutex::new(()),
            net_changes: Mutex::new(HashMap::new()),
        }
    }

    pub fn config(&self) -> Config {
        self.state.lock().unwrap().config.clone()
    }

    /// PVE's release, once a session has read it.
    pub fn release(&self) -> Option<String> {
        self.state.lock().unwrap().release.clone()
    }

    /// Replaces the configuration. Starts a new session when it changed.
    pub fn update_config(&self, config: Config) {
        let mut st = self.state.lock().unwrap();
        if st.config == config {
            return;
        }
        st.config = config;
        st.http = None;
        Self::reset_locked(&mut st);
    }

    /// Drops any session, so the next call logs in again. Keeps what the
    /// user confirmed or typed: the pinned certificate, the credentials.
    pub fn reset(&self) {
        Self::reset_locked(&mut self.state.lock().unwrap());
    }

    fn reset_locked(st: &mut State) {
        st.generation += 1;
        st.session = None;
        st.tfa = None;
        st.rates.clear();
    }

    /// Releases everything. The client answers [`ErrorKind::Closed`] after.
    pub fn close(&self) {
        let mut st = self.state.lock().unwrap();
        Self::reset_locked(&mut st);
        st.http = None;
        st.closed = true;
    }

    /// Pins `fingerprint`, which must be the certificate the last refused
    /// connection presented ([`Error::cert`]), and starts over. Answers the
    /// pin as stored, for the caller to keep with the configuration.
    pub fn confirm_cert(&self, fingerprint: &str) -> Result<String> {
        let mut st = self.state.lock().unwrap();
        let presented = st.presented.as_ref().map(|c| c.fingerprint.to_ascii_lowercase());
        let pin = fingerprint.trim().to_ascii_lowercase();
        if presented.as_deref() != Some(pin.as_str()) {
            return Err(Error::detail(ErrorKind::CertUnconfirmed, Detail::CertNotPresented));
        }
        st.config.cert_sha256 = Some(pin.clone());
        st.presented = None;
        st.http = None;
        Self::reset_locked(&mut st);
        Ok(pin)
    }

    // -----------------------------------------------------------------------
    // What the host answers
    // -----------------------------------------------------------------------

    /// Host, guests and their current usage. Logs in first when needed. Rates
    /// come from the difference to the previous load, so the first has none.
    pub async fn load(&self) -> Result<HostView> {
        let data = self.call(Method::Get, "/cluster/resources", None, false).await?;
        let Value::Array(list) = data else {
            return Err(Error::detail(ErrorKind::InvalidResponse, Detail::InvalidData));
        };
        let at = self.now();
        let list = self.with_fresh_status(list, at);
        let parsed = resources::parse(&list, at);
        // PVE lists only what this account may see, and says nothing about
        // the rest: a token with privilege separation and no ACL of its own
        // gets its nodes' bare names and no guests (PVE 9.2). Asked only
        // then — a host with no guests is rare, and it is one request.
        if parsed.guests.is_empty() {
            self.ensure_auditable().await?;
        }
        let mut st = self.state.lock().unwrap();
        let mut stats = BTreeMap::new();
        for (id, sample) in parsed.samples {
            let rate = st.rates.add(&id, sample);
            stats.insert(id, rate);
        }
        let ids: Vec<&str> = stats.keys().map(String::as_str).collect();
        st.rates.retain(ids);
        let mut nodes = parsed.nodes;
        nodes.sort_by(|a, b| a.name.cmp(&b.name));
        let cluster = nodes.len() > 1;
        Ok(HostView {
            host: Host { kind: HostKind::Pve, version: st.release.clone(), hypervisor: None, nodes },
            guests: parsed.guests,
            stats,
            capabilities: capabilities(cluster),
        })
    }

    /// Runs `action` on `guest` and returns once PVE has finished it (its
    /// task has stopped), then reads the guest's state again so the next
    /// [`Client::load`] shows it before `/cluster/resources` catches up.
    pub async fn power(&self, guest: &Guest, action: PowerAction) -> Result<()> {
        if !guest.actions.contains(&action) {
            return Err(Error::detail(ErrorKind::Unsupported, Detail::NotOffered));
        }
        let path = guest_path(guest)?;
        let verb = match action {
            PowerAction::Start => "start",
            PowerAction::Shutdown => "shutdown",
            PowerAction::Reboot => "reboot",
            PowerAction::ForceStop => "stop",
            PowerAction::Suspend => "suspend",
            PowerAction::Resume => "resume",
        };
        // A shutdown the guest ignores holds the guest until it times out,
        // and a plain stop queues behind it; this aborts it instead.
        let overrule = action == PowerAction::ForceStop
            && self.release().is_some_and(|r| !version_less_than(&r, &OVERRULE_SHUTDOWN_SINCE));
        let body = if overrule { form(&[("overrule-shutdown", "1")]) } else { String::new() };
        let upid = self.call(Method::Post, &format!("{path}/status/{verb}"), Some(Body::form(body)), true).await?;
        if let Some(upid) = upid.as_str().filter(|u| u.starts_with("UPID:")) {
            self.wait_task(guest.node.as_deref().unwrap_or_default(), upid).await?;
        }
        if action == PowerAction::Reboot {
            self.read_status_after_reboot(guest, &path).await;
        } else {
            self.read_status(guest, &path).await;
        }
        Ok(())
    }

    /// Disks, NICs, display and the consoles `guest` opens.
    pub async fn detail(&self, guest: &Guest) -> Result<GuestDetail> {
        Ok(resources::parse_config(&self.config_of(guest).await?, guest.kind))
    }

    async fn config_of(&self, guest: &Guest) -> Result<serde_json::Map<String, Value>> {
        let path = guest_path(guest)?;
        match self.call(Method::Get, &format!("{path}/config"), None, false).await? {
            Value::Object(config) => Ok(config),
            _ => Err(Error::detail(ErrorKind::InvalidResponse, Detail::InvalidData)),
        }
    }

    /// Usage over `window` as PVE stored it (`rrddata`), oldest first.
    pub async fn history(&self, guest: &Guest, window: HistoryWindow) -> Result<Vec<Stats>> {
        let path = guest_path(guest)?;
        let query = format!("{path}/rrddata?timeframe={}&cf=AVERAGE", window.as_str());
        match self.call(Method::Get, &query, None, false).await? {
            Value::Array(list) => Ok(resources::parse_rrd(&list)),
            _ => Err(Error::detail(ErrorKind::InvalidResponse, Detail::InvalidData)),
        }
    }

    /// A fresh ticket for `kind` of console on `guest`. Fetch right before
    /// connecting: a ticket is good for a short while and one use.
    pub async fn console(&self, guest: &Guest, kind: ConsoleKind) -> Result<PveConsole> {
        let path = guest_path(guest)?;
        let vnc = kind == ConsoleKind::Vnc;
        if vnc && guest.kind == GuestKind::Lxc {
            return Err(Error::msg(ErrorKind::Unsupported, "Containers have a text console only"));
        }
        let serial = if !vnc && guest.kind == GuestKind::Qemu {
            Some(resources::serial_device(&self.config_of(guest).await?))
        } else {
            None
        };
        let request = |generate_password: bool| {
            let mut fields: Vec<(&str, &str)> = Vec::new();
            if vnc {
                fields.push(("websocket", "1"));
            }
            // A VNC password of its own rather than the ticket: QEMU checks
            // only the first 8 bytes of one, and a bare ticket's first 8 are
            // `PVEVNC:` and one more character. PVE 9.2 generates one for any
            // `websocket=1` request anyway and answers it as `password`.
            if vnc && generate_password {
                fields.push(("generate-password", "1"));
            }
            if let Some(serial) = &serial {
                fields.push(("serial", serial));
            }
            let body = Body::form(form(&fields));
            let endpoint = format!("{path}/{}", if vnc { "vncproxy" } else { "termproxy" });
            async move { self.call(Method::Post, &endpoint, Some(body), true).await }
        };
        let data = match request(vnc).await {
            // `generate-password` is PVE 7.2 and later; an older API refuses
            // the parameter by name.
            Err(e) if vnc && e.status == Some(400) && e.message.as_deref().is_some_and(|m| m.contains("generate-password")) => {
                request(false).await?
            }
            other => other?,
        };
        let port = resources::int(data.get("port")).and_then(|p| u16::try_from(p).ok());
        let ticket = resources::str_of(data.get("ticket"));
        let (Some(port), Some(ticket)) = (port, ticket) else {
            return Err(Error::detail(ErrorKind::InvalidResponse, Detail::InvalidData));
        };
        let user = data.get("user").and_then(Value::as_str).unwrap_or_default().to_owned();
        let password = vnc.then(|| resources::str_of(data.get("password")).unwrap_or_else(|| ticket.clone()));
        Ok(PveConsole {
            node: guest.node.clone().unwrap_or_default(),
            guest_kind: guest.kind,
            vmid: guest.vmid.unwrap_or_default(),
            kind,
            port,
            ticket,
            user,
            password,
        })
    }

    // -----------------------------------------------------------------------
    // Snapshots
    // -----------------------------------------------------------------------

    pub async fn snapshots(&self, guest: &Guest) -> Result<Vec<crate::snapshot::Snapshot>> {
        let path = guest_path(guest)?;
        match self.call(Method::Get, &format!("{path}/snapshot"), None, false).await? {
            Value::Array(list) => Ok(resources::parse_snapshots(&list)),
            _ => Err(Error::detail(ErrorKind::InvalidResponse, Detail::InvalidData)),
        }
    }

    /// Whether every disk of `guest` is on a storage that snapshots: PVE's
    /// own answer (`feature?feature=snapshot`), what its web UI asks before
    /// it offers the button. None where it cannot say (an older PVE).
    pub async fn snapshot_supported(&self, guest: &Guest) -> Option<bool> {
        let path = guest_path(guest).ok()?;
        let data = self.call(Method::Get, &format!("{path}/feature?feature=snapshot"), None, false).await.ok()?;
        data.as_object().map(|d| resources::int(d.get("hasFeature")) == Some(1))
    }

    /// Why a snapshot of `guest` cannot be taken, naming its storages, or
    /// None when it can.
    pub async fn snapshot_refusal(&self, guest: &Guest) -> Option<String> {
        if self.snapshot_supported(guest).await != Some(false) {
            return None;
        }
        let storages = match self.config_of(guest).await {
            Ok(config) => resources::guest_storages(&resources::parse_config(&config, guest.kind)),
            Err(_) => Vec::new(),
        };
        Some(if storages.is_empty() {
            "snapshot feature is not available".to_owned()
        } else {
            format!("snapshot feature is not available: {}", storages.join(", "))
        })
    }

    /// What differs between snapshot `name`'s configuration and the guest's
    /// now (the pending changes applied: what a rollback would produce).
    pub async fn snapshot_diff(&self, guest: &Guest, name: &str) -> Result<Vec<crate::snapshot::Diff>> {
        let path = guest_path(guest)?;
        let snap = self.call(Method::Get, &format!("{path}/snapshot/{}/config", seg(name)), None, false).await?;
        let current = self.call(Method::Get, &format!("{path}/config"), None, false).await?;
        match (snap.as_object(), current.as_object()) {
            (Some(b), Some(a)) => Ok(resources::snapshot_diff(b, a)),
            _ => Err(Error::detail(ErrorKind::InvalidResponse, Detail::InvalidData)),
        }
    }

    /// Takes snapshot `name` and returns once its task has finished. Refused
    /// before the task starts where the guest's storage cannot (PVE's own
    /// answer). `memory` is a VM's `vmstate`; a container has none.
    pub async fn create_snapshot(&self, guest: &Guest, name: &str, description: Option<&str>, memory: bool) -> Result<()> {
        if !crate::snapshot::valid_name(name) {
            return Err(Error::msg(ErrorKind::Unsupported, format!("Not a snapshot name: {name}")));
        }
        if let Some(why) = self.snapshot_refusal(guest).await {
            return Err(Error::msg(ErrorKind::Unsupported, why));
        }
        let mut fields = vec![("snapname", name)];
        let desc = description.map(str::trim).filter(|d| !d.is_empty());
        if let Some(d) = desc {
            fields.push(("description", d));
        }
        if memory && guest.kind == GuestKind::Qemu {
            fields.push(("vmstate", "1"));
        }
        let path = guest_path(guest)?;
        self.task(guest, Method::Post, &format!("{path}/snapshot"), Some(Body::form(form(&fields)))).await
    }

    /// `rollback`, with `start` to start the guest again after it (a
    /// snapshot without memory stops a running guest). That start is a task
    /// of its own, holding the guest's lock until done (45 s for a container
    /// on PVE 9.2): it is waited for too.
    pub async fn revert_snapshot(&self, guest: &Guest, name: &str, start: bool) -> Result<()> {
        let path = guest_path(guest)?;
        let body = Body::form(if start { form(&[("start", "1")]) } else { String::new() });
        self.task(guest, Method::Post, &format!("{path}/snapshot/{}/rollback", seg(name)), Some(body)).await?;
        if start {
            self.wait_start_task(guest).await?;
        }
        self.read_status(guest, &path).await;
        Ok(())
    }

    /// Deletes snapshot `name`; its children move up to its parent.
    pub async fn delete_snapshot(&self, guest: &Guest, name: &str) -> Result<()> {
        let path = guest_path(guest)?;
        self.task(guest, Method::Delete, &format!("{path}/snapshot/{}", seg(name)), None).await
    }

    /// A request answering a UPID, and its task waited for. PVE answers a
    /// request bound to fail (a name taken) with a task all the same, and the
    /// task's exit status says why.
    async fn task(&self, guest: &Guest, method: Method, path: &str, body: Option<Body>) -> Result<()> {
        let upid = self.call(method, path, body, true).await?;
        if let Some(upid) = upid.as_str().filter(|u| u.starts_with("UPID:")) {
            self.wait_task(guest.node.as_deref().unwrap_or_default(), upid).await?;
        }
        Ok(())
    }

    /// The guest's running start task (`qmstart` / `vzstart`), waited for if
    /// one appears within 5 s.
    async fn wait_start_task(&self, guest: &Guest) -> Result<()> {
        let node = guest.node.clone().unwrap_or_default();
        let deadline = self.now() + 5_000;
        let path = format!("/nodes/{}/tasks?vmid={}&source=active", seg(&node), guest.vmid.unwrap_or_default());
        loop {
            let data = self.call(Method::Get, &path, None, true).await?;
            let Value::Array(tasks) = data else {
                return Err(Error::detail(ErrorKind::InvalidResponse, Detail::InvalidData));
            };
            let start = tasks.iter().find(|t| matches!(t.get("type").and_then(Value::as_str), Some("qmstart" | "vzstart")));
            if let Some(task) = start {
                // A start running that cannot be waited for is not one that
                // is over.
                let upid = task.get("upid").and_then(Value::as_str)
                    .ok_or_else(|| Error::detail(ErrorKind::InvalidResponse, Detail::InvalidData))?;
                return self.wait_task(&node, upid).await;
            }
            if self.now() > deadline {
                return Ok(());
            }
            tokio::time::sleep(self.opts.task_poll).await;
        }
    }

    /// Opens `console`'s `vncwebsocket` with the session's credentials, over
    /// the same connection rules and certificate decision as the API calls.
    /// A text console has been logged in to termproxy (its ticket sent, `OK`
    /// read) when this returns; the caller frames what it sends
    /// ([`super::termproxy`]).
    pub async fn open_console(&self, console: &PveConsole) -> Result<ConsoleSocket> {
        use futures_util::{SinkExt, StreamExt};
        use tokio_tungstenite::tungstenite::Message;
        let session = self.session_now().await?;
        let req = Request { method: Method::Get, path: console.websocket_path(), headers: session.headers(), body: None };
        let stream = match session.http.upgrade(req).await {
            Ok(Upgrade::Switched(stream)) => stream,
            Ok(Upgrade::Refused(resp)) => return Err(self.status_err(&resp, true)),
            Err(e) => return Err(self.transport_err(e)),
        };
        let mut socket = tokio_tungstenite::WebSocketStream::from_raw_socket(
            stream,
            tokio_tungstenite::tungstenite::protocol::Role::Client,
            None,
        )
        .await;
        if console.kind == ConsoleKind::Text {
            let refused = || Error::msg(ErrorKind::ActionFailed, "termproxy did not accept the ticket");
            socket
                .send(Message::Binary(super::termproxy::auth(&console.user, &console.ticket).into()))
                .await
                .map_err(|e| Error::msg(ErrorKind::Unreachable, e.to_string()))?;
            // A refused ticket gets no answer: the socket ends before `OK`.
            loop {
                match tokio::time::timeout(Duration::from_secs(15), socket.next()).await {
                    Ok(Some(Ok(Message::Binary(b)))) if b.as_ref() == super::termproxy::ACCEPTED => break,
                    Ok(Some(Ok(Message::Text(t)))) if t.as_bytes() == super::termproxy::ACCEPTED => break,
                    Ok(Some(Ok(Message::Ping(_) | Message::Pong(_)))) => continue,
                    _ => return Err(refused()),
                }
            }
        }
        Ok(socket)
    }

    /// Waits for the task `upid` on `node` to stop. Its exit status other
    /// than `OK` (or `WARNINGS: n`, a task that completed and logged
    /// warnings) is [`ErrorKind::ActionFailed`] with PVE's text.
    ///
    /// A task still running at the deadline is neither: it goes on on the
    /// host. It is not reported as done, so nothing that needs its result runs
    /// against a guest it still locks.
    pub async fn wait_task(&self, node: &str, upid: &str) -> Result<()> {
        let deadline = self.now() + self.opts.task_timeout.as_millis() as i64;
        let path = format!("/nodes/{}/tasks/{}/status", seg(node), seg(upid));
        loop {
            let data = self.call(Method::Get, &path, None, true).await?;
            if data.get("status").and_then(Value::as_str) == Some("stopped") {
                let exit = match data.get("exitstatus") {
                    Some(Value::String(s)) => s.clone(),
                    Some(Value::Null) | None => String::new(),
                    Some(v) => v.to_string(),
                };
                if exit == "OK" || exit.starts_with("WARNINGS") {
                    return Ok(());
                }
                return Err(Error::msg(ErrorKind::ActionFailed, if exit.is_empty() { upid.to_owned() } else { exit }));
            }
            if self.now() > deadline {
                let mut e = Error::detail(
                    ErrorKind::ActionFailed,
                    Detail::TaskStillRunning {
                        node: node.to_owned(),
                        upid: upid.to_owned(),
                        minutes: self.opts.task_timeout.as_secs() / 60,
                    },
                );
                e.message = Some(upid.to_owned());
                return Err(e);
            }
            tokio::time::sleep(self.opts.task_poll).await;
        }
    }

    /// The headers that authenticate a request in the current session,
    /// logging in first if needed: for a connection made outside this client
    /// (a console's websocket). They carry the ticket or the token.
    pub async fn auth_headers(&self) -> Result<Vec<(String, String)>> {
        Ok(self.session_now().await?.headers())
    }

    // -----------------------------------------------------------------------
    // What the user answers
    // -----------------------------------------------------------------------

    /// The TOTP code for the challenge [`ErrorKind::NeedTfa`] announced. Then
    /// [`Client::load`] again.
    ///
    /// A challenge that is gone (a reset since) or past its lifetime is
    /// replaced by a new login first, and the code answers that one: the code
    /// belongs to the account, not to a challenge. PVE answers an expired
    /// challenge exactly as it answers a wrong code.
    pub async fn submit_tfa(&self, code: &str) -> Result<()> {
        let otp = code.trim();
        if otp.is_empty() {
            return Err(Error::detail(ErrorKind::NeedTfa, Detail::OtpEmpty));
        }
        let usable = {
            let st = self.state.lock().unwrap();
            st.tfa.as_ref().filter(|c| self.challenge_usable(&st, c)).map(|c| {
                (c.generation, c.http.clone(), c.ticket.clone(), c.user.clone())
            })
        };
        let (generation, http, challenge, user) = match usable {
            Some(c) => c,
            None => match self.new_challenge().await? {
                Some(c) => c,
                // The login needed no second factor after all.
                None => return Ok(()),
            },
        };
        // The account the challenge was issued to, never the configuration's
        // now: a change since moved to a new generation, and the code is
        // not sent for it.
        if !self.is_current_challenge(generation, &challenge) {
            return Ok(());
        }
        let mut fields: Vec<(&str, &str)> = user.iter().map(|(k, v)| (*k, v.as_str())).collect();
        let password = format!("totp:{otp}");
        fields.extend([("password", password.as_str()), ("tfa-challenge", challenge.as_str()), ("new-format", "1")]);
        let resp = self.post_ticket(&http, &fields).await?;
        if resp.status == 401 {
            // A wrong code, or one already used. The challenge stays: PVE lets
            // it be answered again until it expires.
            return Err(Error::detail(ErrorKind::NeedTfa, Detail::OtpRejected).with_status(401));
        }
        let (ticket, csrf) = ticket_of(&resp)?;
        let auth = SessionAuth::Ticket { ticket, csrf, issued_at: self.now() };
        let session = Arc::new(Session { generation, http: http.clone(), user, auth: Mutex::new(auth), renewing: Default::default() });
        if !self.is_current_challenge(generation, &challenge) {
            return Ok(());
        }
        let release = self.fetch_release(&session).await?;
        let mut st = self.state.lock().unwrap();
        if st.generation != generation || st.tfa.as_ref().map(|c| c.ticket.as_str()) != Some(challenge.as_str()) {
            return Ok(());
        }
        st.tfa = None;
        if release.is_some() {
            st.release = release;
        }
        st.session = Some(session);
        Ok(())
    }

    fn challenge_usable(&self, st: &State, c: &Challenge) -> bool {
        c.generation == st.generation && self.now() - c.issued_at < TICKET_LIFETIME_MS - LIFETIME_MARGIN_MS
    }

    fn is_current_challenge(&self, generation: u64, ticket: &str) -> bool {
        let st = self.state.lock().unwrap();
        st.generation == generation && st.tfa.as_ref().map(|c| c.ticket.as_str()) == Some(ticket)
    }

    /// Logs in again for a challenge to answer. None when the login needed
    /// no second factor after all: the session is there.
    async fn new_challenge(&self) -> Result<Option<(u64, Arc<dyn Http>, String, Vec<(&'static str, String)>)>> {
        self.state.lock().unwrap().tfa = None;
        match self.ensure_session().await {
            Ok(_) => Ok(None),
            Err(e) if e.kind == ErrorKind::NeedTfa => {
                let st = self.state.lock().unwrap();
                match &st.tfa {
                    Some(c) => Ok(Some((c.generation, c.http.clone(), c.ticket.clone(), c.user.clone()))),
                    None => Err(e),
                }
            }
            Err(e) => Err(e),
        }
    }

    // -----------------------------------------------------------------------
    // Sessions
    // -----------------------------------------------------------------------

    fn now(&self) -> i64 {
        self.opts.clock.now_ms()
    }

    async fn ensure_session(&self) -> Result<Arc<Session>> {
        loop {
            let current = {
                let st = self.state.lock().unwrap();
                if st.closed {
                    return Err(Error::new(ErrorKind::Closed));
                }
                st.session.clone().filter(|s| s.generation == st.generation)
            };
            if let Some(session) = current {
                if !self.renew_due(&session) {
                    return Ok(session);
                }
                self.renew(&session).await;
                // Dropped when PVE refused the renewal: log in again.
                if self.is_current(&session) {
                    return Ok(session);
                }
                continue;
            }
            let _login = self.login.lock().await;
            let (generation, config, http) = {
                let mut st = self.state.lock().unwrap();
                if st.session.as_ref().is_some_and(|s| s.generation == st.generation) {
                    continue;
                }
                let http = match &st.http {
                    Some(http) => http.clone(),
                    None => {
                        let http = self.connector.http(&st.config)?;
                        st.http = Some(http.clone());
                        http
                    }
                };
                (st.generation, st.config.clone(), http)
            };
            match self.open(generation, &config, http).await {
                Ok(()) => continue,
                // A stale attempt's failure is not this caller's: go round
                // again and log in for the current generation.
                Err(e) if self.state.lock().unwrap().generation == generation => return Err(e),
                Err(_) => continue,
            }
        }
    }

    /// The session a request goes out in: current when it is handed back,
    /// with no await between that and the request's headers being taken. A
    /// reset while [`Client::ensure_session`] was renewing or logging in
    /// leaves the session it returns behind, and its credentials are not
    /// sent again.
    async fn session_now(&self) -> Result<Arc<Session>> {
        loop {
            let session = self.ensure_session().await?;
            if self.is_current(&session) {
                return Ok(session);
            }
        }
    }

    fn is_current(&self, session: &Arc<Session>) -> bool {
        self.state.lock().unwrap().session.as_ref().is_some_and(|s| Arc::ptr_eq(s, session))
    }

    fn renew_due(&self, session: &Session) -> bool {
        session.ticket().is_some_and(|(_, issued)| self.now() - issued >= RENEW_AFTER_MS)
    }

    /// Renews `session`'s ticket, once however many callers ask. Drops the
    /// session when PVE refuses the old ticket, or when it is too old to be
    /// worth asking; keeps it as it is on any other failure, which the
    /// request that follows reports.
    async fn renew(&self, session: &Arc<Session>) {
        let _renewing = session.renewing.lock().await;
        if !self.renew_due(session) {
            return;
        }
        let Some((ticket, issued)) = session.ticket() else { return };
        if self.now() - issued >= TICKET_LIFETIME_MS - LIFETIME_MARGIN_MS {
            self.drop_session(session);
            return;
        }
        // A session a reset has dropped is not renewed: its ticket goes to
        // nobody, under nobody else's name.
        if !self.is_current(session) {
            return;
        }
        let mut fields: Vec<(&str, &str)> = session.user.iter().map(|(k, v)| (*k, v.as_str())).collect();
        fields.extend([("password", ticket.as_str()), ("new-format", "1")]);
        let Ok(resp) = self.post_ticket(&session.http, &fields).await else { return };
        if resp.status == 401 {
            self.drop_session(session);
            return;
        }
        if let Ok((ticket, csrf)) = ticket_of(&resp)
            && self.is_current(session)
        {
            *session.auth.lock().unwrap() = SessionAuth::Ticket { ticket, csrf, issued_at: self.now() };
        }
    }

    /// Logs in for `generation`. A result for a generation that has moved
    /// on is discarded, never installed.
    async fn open(&self, generation: u64, config: &Config, http: Arc<dyn Http>) -> Result<()> {
        config.check()?;
        let user = user_fields(config);
        let auth = match &config.auth {
            Auth::Token { id, secret } => SessionAuth::Token(format!("PVEAPIToken={id}={secret}")),
            Auth::Password { password, .. } => {
                let mut fields: Vec<(&str, &str)> = user.iter().map(|(k, v)| (*k, v.as_str())).collect();
                // Sent as stored, spaces included: PAM compares it byte for
                // byte, and the SSH login this may be borrowed from sends it
                // untrimmed too.
                fields.extend([("password", password.as_str()), ("new-format", "1")]);
                let resp = self.post_ticket(&http, &fields).await?;
                if resp.status == 401 {
                    // PVE's own words or none: a client titles this itself, in
                    // its user's language.
                    let mut e = Error::new(ErrorKind::AuthFailed).with_status(401);
                    e.message = pve_message(&resp);
                    return Err(e);
                }
                let data = ticket_data(&resp)?;
                let need_tfa = data.get("NeedTFA").and_then(Value::as_i64) == Some(1)
                    || data.get("TFA").is_some_and(|v| !v.is_null());
                if need_tfa {
                    let ticket = resources::str_of(data.get("ticket"))
                        .ok_or_else(|| Error::detail(ErrorKind::InvalidResponse, Detail::InvalidData))?;
                    let mut st = self.state.lock().unwrap();
                    if st.generation == generation {
                        st.tfa = Some(Challenge { generation, http: http.clone(), ticket, issued_at: self.now(), user: user.clone() });
                    }
                    return Err(Error::detail(ErrorKind::NeedTfa, Detail::OtpRequired));
                }
                let (ticket, csrf) = ticket_of(&resp)?;
                SessionAuth::Ticket { ticket, csrf, issued_at: self.now() }
            }
        };
        let session = Arc::new(Session { generation, http, user, auth: Mutex::new(auth), renewing: Default::default() });
        // Stale (the configuration changed during the login): nothing more
        // is sent with its credentials.
        if self.state.lock().unwrap().generation != generation {
            return Ok(());
        }
        let release = self.fetch_release(&session).await?;
        let mut st = self.state.lock().unwrap();
        if st.generation != generation {
            return Ok(());
        }
        if release.is_some() {
            st.release = release;
        }
        st.session = Some(session);
        Ok(())
    }

    async fn post_ticket(&self, http: &Arc<dyn Http>, fields: &[(&str, &str)]) -> Result<Response> {
        let req = Request {
            method: Method::Post,
            path: format!("{API}/access/ticket"),
            headers: Vec::new(),
            body: Some(Body::form(form(fields))),
        };
        let resp = http.send(req).await.map_err(|e| self.transport_err(e))?;
        if resp.status == 401 || (200..300).contains(&resp.status) {
            return Ok(resp);
        }
        let mut e = Error::new(ErrorKind::InvalidResponse).with_status(resp.status);
        e.message = Some(pve_message(&resp).unwrap_or_else(|| format!("HTTP {}", resp.status)));
        Err(e)
    }

    /// PVE's release. Only an auth or transport failure is fatal here: a
    /// version is nice to show, not needed.
    async fn fetch_release(&self, session: &Session) -> Result<Option<String>> {
        let req = Request {
            method: Method::Get,
            path: format!("{API}/version"),
            headers: session.headers(),
            body: None,
        };
        let resp = session.http.send(req).await.map_err(|e| self.transport_err(e))?;
        if resp.status == 401 || resp.status == 403 {
            return Err(self.status_err(&resp, false));
        }
        let body: Option<Value> = serde_json::from_slice(&resp.body).ok();
        let data = body.as_ref().and_then(|b| b.get("data"));
        Ok(data
            .and_then(|d| d.get("version").or_else(|| d.get("release")))
            .and_then(|v| resources::str_of(Some(v))))
    }

    async fn call(&self, method: Method, path: &str, body: Option<Body>, action: bool) -> Result<Value> {
        self.call_with(method, path, body, action, false).await
    }

    /// Runs one request in the current session.
    ///
    /// **A 401 on a password session this call did not log in** is retried
    /// once, after a new login: PVE refused the ticket (it expired while the
    /// client slept through the renewal), and nothing ran. A second refusal,
    /// the login's own, or a 401 on a token is reported as it is.
    async fn call_with(&self, method: Method, path: &str, body: Option<Body>, action: bool, whole: bool) -> Result<Value> {
        let before = {
            let st = self.state.lock().unwrap();
            st.session.clone().filter(|s| s.generation == st.generation)
        };
        let session = self.session_now().await?;
        let req = Request { method, path: format!("{API}{path}"), headers: Vec::new(), body };
        match self.send(&session, req.clone(), action, whole).await {
            Err(e)
                if e.kind == ErrorKind::AuthFailed
                    && e.status == Some(401)
                    && session.ticket().is_some()
                    && before.as_ref().is_some_and(|b| Arc::ptr_eq(b, &session)) =>
            {
                let session = self.session_now().await?;
                self.send(&session, req, action, whole).await
            }
            result => result,
        }
    }

    /// One request with the session's headers. A transport failure or a 401
    /// ends the session.
    async fn send_raw(&self, session: &Arc<Session>, mut req: Request) -> Result<Response> {
        req.headers.extend(session.headers());
        let resp = match session.http.send(req).await {
            Ok(resp) => resp,
            Err(e) => {
                let err = self.transport_err(e);
                self.drop_session(session);
                return Err(err);
            }
        };
        if resp.status == 401 {
            self.drop_session(session);
        }
        Ok(resp)
    }

    async fn send(&self, session: &Arc<Session>, req: Request, action: bool, whole: bool) -> Result<Value> {
        let resp = self.send_raw(session, req).await?;
        if !(200..300).contains(&resp.status) {
            return Err(self.status_err(&resp, action));
        }
        let body: Value = serde_json::from_slice(&resp.body)
            .ok()
            .filter(Value::is_object)
            .ok_or_else(|| Error::detail(ErrorKind::InvalidResponse, Detail::InvalidBody))?;
        Ok(if whole { body } else { body.get("data").cloned().unwrap_or(Value::Null) })
    }

    /// An answer that is not a success, as an error. An action's refusal is
    /// the action refused, in PVE's words; a 401 or 403 elsewhere is the
    /// account's, named by PVE's text, the token id (never its secret) or the
    /// status.
    fn status_err(&self, resp: &Response, action: bool) -> Error {
        let text = pve_message(resp);
        let code = resp.status;
        let kind = match code {
            401 => ErrorKind::AuthFailed,
            _ if action => ErrorKind::ActionFailed,
            403 => ErrorKind::AuthFailed,
            _ => ErrorKind::InvalidResponse,
        };
        let message = match (kind, text) {
            (_, Some(t)) => t,
            (ErrorKind::AuthFailed, None) => match &self.state.lock().unwrap().config.auth {
                Auth::Token { id, .. } => id.clone(),
                Auth::Password { .. } => format!("HTTP {code}"),
            },
            (_, None) => format!("HTTP {code}"),
        };
        Error::msg(kind, message).with_status(code)
    }

    fn transport_err(&self, e: TransportError) -> Error {
        match e {
            TransportError::Unreachable(message) => Error::msg(ErrorKind::Unreachable, message),
            TransportError::Cert { cert, pinned } => {
                let mut err = Error::new(match pinned.as_deref() {
                    Some(p) if !p.is_empty() => ErrorKind::CertChanged,
                    _ => ErrorKind::CertUnconfirmed,
                });
                err.message = Some(cert.pretty_fingerprint());
                err.previous_fingerprint = pinned.filter(|p| !p.is_empty());
                self.state.lock().unwrap().presented = Some(cert.clone());
                err.cert = Some(Box::new(cert));
                err
            }
        }
    }

    fn drop_session(&self, session: &Arc<Session>) {
        let mut st = self.state.lock().unwrap();
        if st.session.as_ref().is_some_and(|s| Arc::ptr_eq(s, session)) {
            Self::reset_locked(&mut st);
        }
    }

    // -----------------------------------------------------------------------
    // After an action
    // -----------------------------------------------------------------------

    /// Fails with [`ErrorKind::PermissionDenied`] when this account may audit
    /// nothing at all (`VM.Audit` and `Sys.Audit` nowhere), with the ACL that
    /// fixes it; returns when the empty list is the host's real answer.
    async fn ensure_auditable(&self) -> Result<()> {
        let perms = self.call(Method::Get, "/access/permissions", None, false).await?;
        let Some(perms) = perms.as_object() else { return Ok(()) };
        let granted = |p: &str| {
            perms.values().any(|privs| {
                privs.get(p).is_some_and(|v| !v.is_null() && v.as_i64() != Some(0))
            })
        };
        if granted("VM.Audit") || granted("Sys.Audit") {
            return Ok(());
        }
        let (token, account) = self.config().account();
        let command = format!("pveum acl modify / {} --roles PVEAuditor,PVEVMAdmin", acl_who(token, &account));
        Err(Error::detail(ErrorKind::PermissionDenied, Detail::NoPrivileges { token, account, command }))
    }

    /// Records `guest`'s state as `status/current` has it now — see
    /// [`State::fresh`] — and answers it; None when it could not be read.
    /// Best effort: the action itself has succeeded either way.
    async fn read_status(&self, guest: &Guest, path: &str) -> Option<String> {
        let data = self.call(Method::Get, &format!("{path}/status/current"), None, true).await.ok()?;
        // What `pvestatd` puts in `/cluster/resources`: the QEMU run state
        // where there is one (`paused`, ...), else `running` or `stopped`.
        // PVE 9.2 answers a paused VM as `status: running` and `qmpstatus:
        // paused` here, and as `status: paused` in the listing.
        let status = data
            .get("qmpstatus")
            .or_else(|| data.get("status"))
            .and_then(Value::as_str)
            .filter(|s| !s.is_empty())?
            .to_owned();
        let uptime = resources::int(data.get("uptime"));
        let at = self.now();
        self.state
            .lock()
            .unwrap()
            .fresh
            .insert(guest.id.clone(), Fresh { status: status.clone(), uptime, at });
        Some(status)
    }

    /// [`Client::read_status`] until the guest runs again, for at most
    /// [`REBOOT_RESTART_TIMEOUT_MS`].
    ///
    /// A QEMU reboot's task (`qmreboot`) ends once the guest has shut down;
    /// `qmeventd` then starts it again in a task of its own. On PVE 9.2 the
    /// guest read `stopped` right after the reboot task and ran again about a
    /// second later. Recording that first reading would show a rebooting VM
    /// as stopped and offer `start`, which PVE then refuses.
    async fn read_status_after_reboot(&self, guest: &Guest, path: &str) {
        let deadline = self.now() + REBOOT_RESTART_TIMEOUT_MS;
        loop {
            match self.read_status(guest, path).await {
                None => return,
                Some(s) if s == "running" => return,
                Some(_) => {}
            }
            if self.now() > deadline {
                return;
            }
            tokio::time::sleep(self.opts.task_poll).await;
        }
    }

    /// `raw` with each guest that has a fresh state showing it, until the
    /// listing reports the same status itself or the state is too old to
    /// trust.
    fn with_fresh_status(&self, raw: Vec<Value>, now: i64) -> Vec<Value> {
        let mut st = self.state.lock().unwrap();
        if st.fresh.is_empty() {
            return raw;
        }
        let mut listed = std::collections::HashSet::new();
        let mut out = Vec::with_capacity(raw.len());
        for item in raw {
            let Some(id) = item.get("id").and_then(Value::as_str).map(str::to_owned) else {
                out.push(item);
                continue;
            };
            let Some(fresh) = st.fresh.get(&id) else {
                out.push(item);
                continue;
            };
            listed.insert(id.clone());
            let elapsed = now - fresh.at;
            // Uptime as of now, going by the fresh reading. A guest read in
            // its first second after a start or a reboot reports 0 and is
            // running all the same, so it counts up too; only a guest that
            // is not running stays at 0.
            let uptime = fresh.uptime.map(|u| {
                if u > 0 || fresh.status == "running" { u + elapsed / 1000 } else { u }
            });
            let listed_uptime = resources::int(item.get("uptime"));
            // The same status is not enough after a reboot, which keeps it: an
            // uptime longer than the guest has been up since is from before.
            let caught_up = item.get("status").and_then(Value::as_str) == Some(fresh.status.as_str())
                && match (uptime, listed_uptime) {
                    (Some(u), Some(l)) => l <= u + 2,
                    _ => true,
                };
            if caught_up || elapsed > FRESH_STATUS_FOR_MS {
                st.fresh.remove(&id);
                out.push(item);
                continue;
            }
            let mut patched: Map<String, Value> = item.as_object().cloned().unwrap_or_default();
            patched.insert("status".into(), Value::String(fresh.status.clone()));
            if let Some(u) = uptime {
                patched.insert("uptime".into(), Value::from(u));
            }
            out.push(Value::Object(patched));
        }
        st.fresh.retain(|id, _| listed.contains(id));
        out
    }
}

/// A console's websocket, once open.
pub type ConsoleSocket = tokio_tungstenite::WebSocketStream<Box<dyn Stream>>;

/// A PVE console: `termproxy` or `vncproxy`, reached through the node's
/// `vncwebsocket` with the session's credentials. Never printed: the ticket
/// and the password are secrets.
#[derive(Clone, PartialEq, Eq)]
pub struct PveConsole {
    pub node: String,
    pub guest_kind: GuestKind,
    pub vmid: u32,
    pub kind: ConsoleKind,
    /// The proxy's port on the node, passed back to `vncwebsocket`.
    pub port: u16,
    pub ticket: String,
    /// The PVE user the ticket was issued to.
    pub user: String,
    /// VNC only: the password QEMU was given for this connection — the one
    /// `generate-password` made, or before PVE 7.2 the ticket itself.
    pub password: Option<String>,
}

impl std::fmt::Debug for PveConsole {
    fn fmt(&self, f: &mut std::fmt::Formatter<'_>) -> std::fmt::Result {
        write!(f, "PveConsole({}/{}/{}, {:?}, port {})", self.node, self.guest_kind.as_str(), self.vmid, self.kind, self.port)
    }
}

impl PveConsole {
    /// `vncwebsocket`'s path and query, under the API's origin.
    pub fn websocket_path(&self) -> String {
        let ticket: String = url_query(&self.ticket);
        format!(
            "{API}/nodes/{}/{}/{}/vncwebsocket?port={}&vncticket={ticket}",
            seg(&self.node),
            self.guest_kind.as_str(),
            self.vmid,
            self.port
        )
    }

    /// The password as RFB's VNC authentication uses it: DES keyed with the
    /// first 8 bytes, which is also all QEMU keeps of a longer one.
    pub fn rfb_password(&self) -> Option<String> {
        self.password.as_ref().map(|p| p.chars().take(8).collect())
    }

    /// The first thing a termproxy client sends: `<user>:<ticket>\n`.
    pub fn termproxy_login(&self) -> String {
        format!("{}:{}\n", self.user, self.ticket)
    }
}

/// `Uri.encodeQueryComponent`: a space as `+`, the rest percent-encoded
/// beyond `A-Za-z0-9-._~*`.
fn url_query(s: &str) -> String {
    let mut out = String::with_capacity(s.len());
    for b in s.bytes() {
        match b {
            b' ' => out.push('+'),
            b if b.is_ascii_alphanumeric() || b"-._~*".contains(&b) => out.push(b as char),
            b => out.push_str(&format!("%{b:02X}")),
        }
    }
    out
}

/// What this build does with a PVE host.
pub fn capabilities(cluster: bool) -> Capabilities {
    Capabilities {
        lxc: true,
        pause: true,
        snapshots: true,
        snapshot_supported: true,
        storage: true,
        network: true,
        cluster,
        vnc_console: true,
        term_console: true,
        stored_history: true,
        create: true,
        hardware: true,
        hardware_revert: true,
        clone: true,
        linked_clone: true,
        template: true,
        clone_target: true,
        backup: true,
        backup_jobs: true,
        storage_edit: true,
        pool_types: ["dir", "lvmthin", "nfs", "zfspool"].map(str::to_owned).to_vec(),
        upload: true,
        network_edit: true,
        network_modes: vec!["bridge".to_owned()],
        network_apply: true,
        // A bridge's ports, address, VLAN awareness and autostart, written
        // into the pending configuration.
        network_edit_existing: true,
        ..Capabilities::default()
    }
}

/// The account fields of an `/access/ticket` request for `config`.
fn user_fields(config: &Config) -> Vec<(&'static str, String)> {
    let user = match &config.auth {
        Auth::Password { user, .. } => user.trim().to_owned(),
        Auth::Token { .. } => String::new(),
    };
    // `root@pam` already names its realm.
    if user.contains('@') {
        vec![("username", user)]
    } else {
        vec![("username", user), ("realm", "pam".to_owned())]
    }
}

/// `--tokens '<account>'` or `--users '<account>'`, quoted for the shell the
/// command is pasted into: an account name may hold a quote.
fn acl_who(token: bool, account: &str) -> String {
    format!("--{} {}", if token { "tokens" } else { "users" }, sbm_parser::script::shell_quote_unix(account))
}

/// An ACL path as one shell word: bare where it is only what PVE's paths are
/// made of, quoted otherwise — it comes from the host's answer.
fn acl_path_arg(path: &str) -> String {
    if path.bytes().all(|b| b.is_ascii_alphanumeric() || matches!(b, b'/' | b'.' | b'_' | b'-' | b':')) {
        path.to_owned()
    } else {
        sbm_parser::script::shell_quote_unix(path)
    }
}

/// `/nodes/{node}/{qemu|lxc}/{vmid}`.
pub fn guest_path(guest: &Guest) -> Result<String> {
    match (&guest.node, guest.vmid) {
        (Some(node), Some(vmid)) => Ok(format!("/nodes/{}/{}/{vmid}", seg(node), guest.kind.as_str())),
        _ => Err(Error::msg(ErrorKind::InvalidResponse, format!("No node or VMID for {}", guest.name))),
    }
}

/// PVE's own words for a failed request: `message`, and which parameter in
/// `errors` (a 400 says "Parameter verification failed." and the rest only
/// there), or the reason phrase.
fn pve_message(resp: &Response) -> Option<String> {
    if let Ok(Value::Object(body)) = serde_json::from_slice::<Value>(&resp.body) {
        let mut lines = Vec::new();
        if let Some(m) = body.get("message").and_then(Value::as_str).map(str::trim).filter(|m| !m.is_empty()) {
            lines.push(m.to_owned());
        }
        if let Some(Value::Object(errors)) = body.get("errors") {
            for (k, v) in errors {
                let v = v.as_str().map(str::to_owned).unwrap_or_else(|| v.to_string());
                lines.push(format!("{k}: {}", v.trim()));
            }
        }
        if !lines.is_empty() {
            return Some(lines.join("\n"));
        }
    }
    resp.reason.as_deref().map(str::trim).filter(|r| !r.is_empty()).map(str::to_owned)
}

fn ticket_data(resp: &Response) -> Result<Map<String, Value>> {
    let body: Value = serde_json::from_slice(&resp.body)
        .ok()
        .filter(Value::is_object)
        .ok_or_else(|| Error::detail(ErrorKind::InvalidResponse, Detail::InvalidBody))?;
    match body.get("data") {
        Some(Value::Object(data)) => Ok(data.clone()),
        _ => Err(Error::detail(ErrorKind::InvalidResponse, Detail::InvalidData)),
    }
}

/// The ticket and CSRF token of a successful `/access/ticket`.
fn ticket_of(resp: &Response) -> Result<(String, Option<String>)> {
    let data = ticket_data(resp)?;
    let ticket = resources::str_of(data.get("ticket"))
        .ok_or_else(|| Error::detail(ErrorKind::AuthFailed, Detail::MissingTicket))?;
    Ok((ticket, resources::str_of(data.get("CSRFPreventionToken"))))
}
