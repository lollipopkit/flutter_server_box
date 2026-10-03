//! Proxmox VE FFI (sbm_virt::pve)
//!
//! The session the monitor agent keeps too: login, TOTP, ticket renewal,
//! certificate pinning, the host's guests and their power. The app reaches
//! the API over whichever transport the server has by giving this an
//! authenticated loopback port of its `ServerTcpDialer` (the port and the
//! token every connection presents first); the address's host is resolved on
//! the far end of that tunnel.
//!
//! A host view crosses as `sbm_virt::model::HostView` JSON, the agent's wire
//! format, which the app reads into its own models. A failure crosses as
//! [`PveError`], whose `kind` the app branches on and whose `detail_json`
//! (`sbm_virt::error::Detail`) carries what it phrases itself.

use std::sync::{Arc, RwLock};

use sbm_virt::error::{Error, ErrorKind};
use sbm_virt::model::{Guest, PowerAction};
use sbm_virt::pve::http::{Body, BoxFuture, Dial, LoopbackDial, Method, Stream, TlsConnector};
use sbm_virt::pve::{self, Auth, Client};

use super::bmc::CertInfo;
use super::virt::VirtActionKind;

/// Why a host could not be read or an action did not happen (mirrors
/// sbm_virt::error::ErrorKind).
#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum VirtFailure {
    Unreachable,
    NotConfigured,
    AuthFailed,
    NeedTfa,
    CertUnconfirmed,
    CertChanged,
    PermissionDenied,
    InvalidResponse,
    ActionFailed,
    Unsupported,
    Exists,
    Conflict,
    NotInstalled,
    SudoPasswordRequired,
    SudoPasswordRejected,
    Closed,
    Unknown,
}

impl From<ErrorKind> for VirtFailure {
    fn from(k: ErrorKind) -> Self {
        use ErrorKind as K;
        match k {
            K::Unreachable => Self::Unreachable,
            K::NotConfigured => Self::NotConfigured,
            K::AuthFailed => Self::AuthFailed,
            K::NeedTfa => Self::NeedTfa,
            K::CertUnconfirmed => Self::CertUnconfirmed,
            K::CertChanged => Self::CertChanged,
            K::PermissionDenied => Self::PermissionDenied,
            K::InvalidResponse => Self::InvalidResponse,
            K::ActionFailed => Self::ActionFailed,
            K::Unsupported => Self::Unsupported,
            K::Exists => Self::Exists,
            K::Conflict => Self::Conflict,
            K::NotInstalled => Self::NotInstalled,
            K::SudoPasswordRequired => Self::SudoPasswordRequired,
            K::SudoPasswordRejected => Self::SudoPasswordRejected,
            K::Closed => Self::Closed,
            K::Unknown => Self::Unknown,
        }
    }
}

/// A PVE failure (mirrors sbm_virt::error::Error). `message` is the host's or
/// the transport's words, never a credential.
#[derive(Debug, Clone)]
pub struct PveError {
    pub kind: VirtFailure,
    pub message: Option<String>,
    /// `sbm_virt::error::Detail` as JSON (`{"code": ..., ...}`).
    pub detail_json: Option<String>,
    pub cert: Option<Box<CertInfo>>,
    pub previous_fingerprint: Option<String>,
    /// The HTTP status the host answered with, when it was one.
    pub status: Option<u16>,
}

impl From<Error> for PveError {
    fn from(e: Error) -> Self {
        Self {
            kind: e.kind.into(),
            message: e.message,
            detail_json: e.detail.and_then(|d| serde_json::to_string(&d).ok()),
            cert: e.cert.map(|c| Box::new((*c).into())),
            previous_fingerprint: e.previous_fingerprint,
            status: e.status,
        }
    }
}

impl std::fmt::Display for PveError {
    fn fmt(&self, f: &mut std::fmt::Formatter<'_>) -> std::fmt::Result {
        write!(f, "{:?}", self.kind)?;
        if let Some(m) = &self.message {
            write!(f, ": {m}")?;
        }
        Ok(())
    }
}

/// How a session logs in (mirrors sbm_virt::pve::Config). `token` picks the
/// API token; otherwise `user` and `password` log in, `password` being what
/// the app's `PveConfig.loginPassword` chose.
pub struct PveLogin {
    pub addr: String,
    pub token: bool,
    pub user: String,
    pub password: String,
    pub token_id: String,
    pub token_secret: String,
    pub cert_sha256: Option<String>,
}

impl From<PveLogin> for pve::Config {
    fn from(l: PveLogin) -> Self {
        let auth = if l.token {
            Auth::Token { id: l.token_id, secret: l.token_secret }
        } else {
            Auth::Password { user: l.user, password: l.password }
        };
        pve::Config { addr: l.addr, auth, cert_sha256: l.cert_sha256 }
    }
}

pub enum PveMethod {
    Get,
    Post,
    Put,
    Delete,
}

impl From<PveMethod> for Method {
    fn from(m: PveMethod) -> Self {
        match m {
            PveMethod::Get => Method::Get,
            PveMethod::Post => Method::Post,
            PveMethod::Put => Method::Put,
            PveMethod::Delete => Method::Delete,
        }
    }
}

pub struct PveHeader {
    pub name: String,
    pub value: String,
}

/// What [`PveSession::raw`] answered: the host's status and body as sent.
pub struct PveRawResponse {
    pub status: u16,
    pub body: Vec<u8>,
}

/// How long a task is waited for, and how often it is asked about; `None`
/// keeps sbm_virt's defaults (1 s, 10 min).
pub struct PveTiming {
    pub task_poll_ms: Option<u64>,
    pub task_timeout_ms: Option<u64>,
}

/// Which console (mirrors sbm_virt::model::ConsoleKind).
pub enum PveConsoleKind {
    Text,
    Vnc,
}

/// How far back stored usage reaches (mirrors sbm_virt::model::HistoryWindow).
pub enum PveHistoryWindow {
    Hour,
    Day,
    Week,
}

/// A PVE console ticket (mirrors sbm_virt::pve::client::PveConsole): fetch
/// right before connecting, a ticket is good for a short while and one use.
pub struct PveConsoleTicket {
    pub node: String,
    pub lxc: bool,
    pub vmid: u32,
    pub vnc: bool,
    pub port: u16,
    /// Never logged.
    pub ticket: String,
    pub user: String,
    /// VNC: the password QEMU was given for this connection. Never logged.
    pub password: Option<String>,
    /// `vncwebsocket`'s path and query, under the API's origin.
    pub websocket_path: String,
}

/// A guest's configuration (`/nodes/../config` JSON) read into
/// `sbm_virt::model::GuestDetail` JSON.
#[flutter_rust_bridge::frb(sync)]
pub fn pve_guest_detail(config_json: String, lxc: bool) -> Result<String, PveError> {
    let config: serde_json::Map<String, serde_json::Value> = serde_json::from_str(&config_json)
        .map_err(|e| Error::msg(ErrorKind::InvalidResponse, e.to_string()))?;
    let kind = if lxc { sbm_virt::model::GuestKind::Lxc } else { sbm_virt::model::GuestKind::Qemu };
    let detail = sbm_virt::pve::resources::parse_config(&config, kind);
    serde_json::to_string(&detail).map_err(|e| Error::msg(ErrorKind::InvalidResponse, e.to_string()).into())
}

/// A guest as the app holds it, from the last load (mirrors the fields of
/// sbm_virt::model::Guest that a call on one guest reads).
pub struct PveGuestRef {
    pub id: String,
    pub name: String,
    pub node: Option<String>,
    pub vmid: Option<u32>,
    pub lxc: bool,
    /// What it offered at that load; an action not among these is refused.
    pub actions: Vec<VirtActionKind>,
}

impl From<PveGuestRef> for Guest {
    fn from(g: PveGuestRef) -> Self {
        use sbm_virt::model::{GuestKind, GuestState};
        Guest {
            id: g.id,
            name: g.name,
            kind: if g.lxc { GuestKind::Lxc } else { GuestKind::Qemu },
            state: GuestState::Unknown,
            state_reason: None,
            vmid: g.vmid,
            node: g.node,
            vcpu: None,
            mem_bytes: None,
            uptime: None,
            tags: Vec::new(),
            template: false,
            autostart: None,
            actions: g.actions.into_iter().map(power_action).collect(),
        }
    }
}

/// The loopback tunnel a session's connections go to, swapped when the app
/// opens a new one (the old one ended with its SSH connection).
struct Loopback(RwLock<LoopbackDial>);

impl Dial for Loopback {
    fn dial(&self, host: String, port: u16) -> BoxFuture<'static, std::io::Result<Box<dyn Stream>>> {
        self.0.read().unwrap().dial(host, port)
    }
}

/// One PVE host's session.
#[flutter_rust_bridge::frb(opaque)]
pub struct PveSession {
    client: Client,
    loopback: Arc<Loopback>,
}

impl PveSession {
    /// Nothing is sent until the first call. `port` and `token` are the
    /// app's authenticated loopback tunnel to the API's address.
    #[flutter_rust_bridge::frb(sync)]
    pub fn new(login: PveLogin, port: u16, token: Vec<u8>, timing: PveTiming) -> Result<PveSession, PveError> {
        let config = pve::Config::from(login);
        config.base_uri()?;
        let loopback = Arc::new(Loopback(RwLock::new(LoopbackDial { port, token })));
        let connector = Arc::new(TlsConnector::new(loopback.clone()));
        let mut options = pve::Options::default();
        if let Some(ms) = timing.task_poll_ms {
            options.task_poll = std::time::Duration::from_millis(ms);
        }
        if let Some(ms) = timing.task_timeout_ms {
            options.task_timeout = std::time::Duration::from_millis(ms);
        }
        Ok(PveSession {
            client: Client::new(config, connector, options),
            loopback,
        })
    }

    /// A new tunnel to the same address. Connections still open on the old
    /// one fail and are made again.
    #[flutter_rust_bridge::frb(sync)]
    pub fn set_loopback(&self, port: u16, token: Vec<u8>) {
        *self.loopback.0.write().unwrap() = LoopbackDial { port, token };
    }

    /// Replaces the login (an edit, or a pin confirmed elsewhere). A new
    /// session starts when anything changed. An address change also needs a
    /// new tunnel: [`PveSession::set_loopback`].
    #[flutter_rust_bridge::frb(sync)]
    pub fn update_login(&self, login: PveLogin) {
        self.client.update_config(login.into());
    }

    /// Drops the session; the next call logs in again.
    #[flutter_rust_bridge::frb(sync)]
    pub fn reset(&self) {
        self.client.reset();
    }

    #[flutter_rust_bridge::frb(sync)]
    pub fn close(&self) {
        self.client.close();
    }

    /// PVE's release, once a session has read it.
    #[flutter_rust_bridge::frb(sync)]
    pub fn release(&self) -> Option<String> {
        self.client.release()
    }

    /// Pins the certificate the last refused connection presented; answers
    /// the pin as stored.
    #[flutter_rust_bridge::frb(sync)]
    pub fn confirm_cert(&self, fingerprint: String) -> Result<String, PveError> {
        Ok(self.client.confirm_cert(&fingerprint)?)
    }

    /// `sbm_virt::model::HostView` JSON.
    pub async fn load(&self) -> Result<String, PveError> {
        let view = self.client.load().await?;
        serde_json::to_string(&view).map_err(|e| Error::msg(ErrorKind::InvalidResponse, e.to_string()).into())
    }

    /// Runs `action` on `guest` and returns once PVE has finished it.
    pub async fn power(&self, guest: PveGuestRef, action: VirtActionKind) -> Result<(), PveError> {
        Ok(self.client.power(&guest.into(), power_action(action)).await?)
    }

    pub async fn submit_tfa(&self, code: String) -> Result<(), PveError> {
        Ok(self.client.submit_tfa(&code).await?)
    }

    /// `sbm_virt::model::GuestDetail` JSON.
    pub async fn detail(&self, guest: PveGuestRef) -> Result<String, PveError> {
        let guest: Guest = guest.into();
        let detail = self.client.detail(&guest).await?;
        serde_json::to_string(&detail).map_err(|e| Error::msg(ErrorKind::InvalidResponse, e.to_string()).into())
    }

    /// `sbm_virt::model::Stats` JSON list, oldest first.
    pub async fn history(&self, guest: PveGuestRef, window: PveHistoryWindow) -> Result<String, PveError> {
        let guest: Guest = guest.into();
        let window = match window {
            PveHistoryWindow::Hour => sbm_virt::model::HistoryWindow::Hour,
            PveHistoryWindow::Day => sbm_virt::model::HistoryWindow::Day,
            PveHistoryWindow::Week => sbm_virt::model::HistoryWindow::Week,
        };
        let history = self.client.history(&guest, window).await?;
        serde_json::to_string(&history).map_err(|e| Error::msg(ErrorKind::InvalidResponse, e.to_string()).into())
    }

    /// A fresh console ticket.
    pub async fn console(&self, guest: PveGuestRef, kind: PveConsoleKind) -> Result<PveConsoleTicket, PveError> {
        let guest: Guest = guest.into();
        let kind = match kind {
            PveConsoleKind::Text => sbm_virt::model::ConsoleKind::Text,
            PveConsoleKind::Vnc => sbm_virt::model::ConsoleKind::Vnc,
        };
        let c = self.client.console(&guest, kind).await?;
        Ok(PveConsoleTicket {
            websocket_path: c.websocket_path(),
            node: c.node,
            lxc: c.guest_kind == sbm_virt::model::GuestKind::Lxc,
            vmid: c.vmid,
            vnc: c.kind == sbm_virt::model::ConsoleKind::Vnc,
            port: c.port,
            ticket: c.ticket,
            user: c.user,
            password: c.password,
        })
    }


    /// `sbm_virt::snapshot::Snapshot` JSON list.
    pub async fn snapshots(&self, guest: PveGuestRef) -> Result<String, PveError> {
        let list = self.client.snapshots(&guest.into()).await?;
        serde_json::to_string(&list).map_err(|e| Error::msg(ErrorKind::InvalidResponse, e.to_string()).into())
    }

    /// PVE's own answer whether every disk snapshots; None where it cannot say.
    pub async fn snapshot_supported(&self, guest: PveGuestRef) -> Option<bool> {
        self.client.snapshot_supported(&guest.into()).await
    }

    pub async fn snapshot_refusal(&self, guest: PveGuestRef) -> Option<String> {
        self.client.snapshot_refusal(&guest.into()).await
    }

    /// `sbm_virt::snapshot::Diff` JSON list.
    pub async fn snapshot_diff(&self, guest: PveGuestRef, name: String) -> Result<String, PveError> {
        let diff = self.client.snapshot_diff(&guest.into(), &name).await?;
        serde_json::to_string(&diff).map_err(|e| Error::msg(ErrorKind::InvalidResponse, e.to_string()).into())
    }

    pub async fn create_snapshot(
        &self,
        guest: PveGuestRef,
        name: String,
        description: Option<String>,
        memory: bool,
    ) -> Result<(), PveError> {
        Ok(self.client.create_snapshot(&guest.into(), &name, description.as_deref(), memory).await?)
    }

    pub async fn revert_snapshot(&self, guest: PveGuestRef, name: String, start: bool) -> Result<(), PveError> {
        Ok(self.client.revert_snapshot(&guest.into(), &name, start).await?)
    }

    pub async fn delete_snapshot(&self, guest: PveGuestRef, name: String) -> Result<(), PveError> {
        Ok(self.client.delete_snapshot(&guest.into(), &name).await?)
    }

    /// Reads the guest's state again after an action made through
    /// [`PveSession::raw`] (a snapshot revert), so the next load shows it.
    pub async fn refresh_status(&self, guest: PveGuestRef) {
        self.client.refresh_status(&guest.into()).await;
    }


    /// Any API call in this session, `path` under `/api2/json` with its
    /// query: the body's `data` as JSON, or the whole body with `whole`.
    pub async fn request(
        &self,
        method: PveMethod,
        path: String,
        content_type: Option<String>,
        body: Option<Vec<u8>>,
        action: bool,
        whole: bool,
    ) -> Result<String, PveError> {
        let body = body.map(|bytes| Body {
            content_type: content_type.unwrap_or_else(|| "application/x-www-form-urlencoded".into()),
            bytes,
        });
        let value = self.client.request(method.into(), &path, body, action, whole).await?;
        Ok(value.to_string())
    }

    /// A request answered as the host answered it, for the app's calls that
    /// read PVE's answers themselves. `path` is the whole path, API root and
    /// query included. The session still logs in, renews, and replaces a
    /// refused ticket once.
    // TODO(migration): remove with the last of the app's own PVE calls.
    pub async fn raw(
        &self,
        method: PveMethod,
        path: String,
        content_type: Option<String>,
        body: Option<Vec<u8>>,
    ) -> Result<PveRawResponse, PveError> {
        let body = body.map(|bytes| Body {
            content_type: content_type.unwrap_or_else(|| "application/x-www-form-urlencoded".into()),
            bytes,
        });
        let resp = self.client.raw(method.into(), &path, body).await?;
        Ok(PveRawResponse { status: resp.status, body: resp.body })
    }

    /// Waits for the task `upid` on `node` to stop; its error is
    /// `actionFailed` with PVE's text.
    pub async fn wait_task(&self, node: String, upid: String) -> Result<(), PveError> {
        Ok(self.client.wait_task(&node, &upid).await?)
    }

    /// The headers that authenticate a connection made outside the session
    /// (a console's websocket, an upload), logging in first if needed.
    pub async fn auth_headers(&self) -> Result<Vec<PveHeader>, PveError> {
        Ok(self
            .client
            .auth_headers()
            .await?
            .into_iter()
            .map(|(name, value)| PveHeader { name, value })
            .collect())
    }
}

fn power_action(kind: VirtActionKind) -> PowerAction {
    match kind {
        VirtActionKind::Start => PowerAction::Start,
        VirtActionKind::Shutdown => PowerAction::Shutdown,
        VirtActionKind::Reboot => PowerAction::Reboot,
        VirtActionKind::ForceStop => PowerAction::ForceStop,
        VirtActionKind::Suspend => PowerAction::Suspend,
        VirtActionKind::Resume => PowerAction::Resume,
    }
}
