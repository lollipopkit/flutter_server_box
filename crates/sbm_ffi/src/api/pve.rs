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
//! [`PveError`], whose `kind` the app branches on and whose `detail`
//! (`sbm_virt::error::Detail`) carries what it phrases itself.

use std::sync::{Arc, RwLock};

use sbm_virt::error::{Error, ErrorKind};
use sbm_virt::model::{Guest, PowerAction};
use sbm_virt::pve::http::{BoxFuture, Dial, LoopbackDial, Stream, TlsConnector};
use sbm_virt::pve::{self, Auth, Client};

use super::bmc::CertInfo;
use super::virt::VirtActionKind;
use super::virt_model::{
    Backup, BackupEdit, BackupJob, BackupJobEdit, BackupRequest, CloneRequest, CloudInitEdit, CloudInitState, CreateOptions, CreateSpec, Created, Detail,
    Hardware, HostDevices, HwChange, Network, NetworkChanges, Outcome, ResourceChange, ResourcePool, ScheduleCheck, Volume,
};
use super::virt_view::{Diff, Snapshot, Stats, VirtGuestDetailReport, VirtHostReport};

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
    /// What the app phrases itself, in its own language, when no host text
    /// says it (`sbm_virt::error::Detail`).
    pub detail: Option<Box<Detail>>,
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
            detail: e.detail,
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

pub struct PveHeader {
    pub name: String,
    pub value: String,
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
}

impl From<PveConsoleTicket> for pve::client::PveConsole {
    fn from(t: PveConsoleTicket) -> Self {
        use sbm_virt::model::{ConsoleKind, GuestKind};
        Self {
            node: t.node,
            guest_kind: if t.lxc { GuestKind::Lxc } else { GuestKind::Qemu },
            vmid: t.vmid,
            kind: if t.vnc { ConsoleKind::Vnc } else { ConsoleKind::Text },
            port: t.port,
            ticket: t.ticket,
            user: t.user,
            password: t.password,
        }
    }
}

/// An open console (sbm_virt::pve::console::Console): terminal bytes and a
/// size for a text console, the RFB stream for a graphical one. termproxy's
/// login, framing and keep-alive are its own.
///
/// One `recv` at a time; the app calls `send` and `resize` in order, one
/// after the other.
#[flutter_rust_bridge::frb(opaque)]
pub struct PveConsoleChannel(pve::console::Console);

impl PveConsoleChannel {
    /// The next bytes, or `None` once the console has ended.
    pub async fn recv(&self) -> Option<Vec<u8>> {
        self.0.recv().await
    }

    pub async fn send(&self, data: Vec<u8>) -> Result<(), PveError> {
        Ok(self.0.send(&data).await?)
    }

    /// A text console's new size; nothing for a graphical one.
    pub async fn resize(&self, cols: u16, rows: u16) -> Result<(), PveError> {
        Ok(self.0.resize(cols, rows).await?)
    }

    pub async fn close(&self) {
        self.0.close().await
    }
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

    pub async fn load(&self) -> Result<VirtHostReport, PveError> {
        Ok(self.client.load().await?.into())
    }

    /// Runs `action` on `guest` and returns once PVE has finished it.
    pub async fn power(&self, guest: PveGuestRef, action: VirtActionKind) -> Result<(), PveError> {
        Ok(self.client.power(&guest.into(), power_action(action)).await?)
    }

    pub async fn submit_tfa(&self, code: String) -> Result<(), PveError> {
        Ok(self.client.submit_tfa(&code).await?)
    }

    pub async fn detail(&self, guest: PveGuestRef) -> Result<VirtGuestDetailReport, PveError> {
        let guest: Guest = guest.into();
        Ok(self.client.detail(&guest).await?.into())
    }

    /// Oldest first.
    pub async fn history(&self, guest: PveGuestRef, window: PveHistoryWindow) -> Result<Vec<Stats>, PveError> {
        let guest: Guest = guest.into();
        let window = match window {
            PveHistoryWindow::Hour => sbm_virt::model::HistoryWindow::Hour,
            PveHistoryWindow::Day => sbm_virt::model::HistoryWindow::Day,
            PveHistoryWindow::Week => sbm_virt::model::HistoryWindow::Week,
        };
        Ok(self.client.history(&guest, window).await?)
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


    /// Opens `console`'s websocket over the session's transport, login and
    /// certificate decision; a text console is logged in to termproxy.
    pub async fn open_console(&self, console: PveConsoleTicket) -> Result<PveConsoleChannel, PveError> {
        Ok(PveConsoleChannel(self.client.open_console(&console.into()).await?))
    }

    pub async fn snapshots(&self, guest: PveGuestRef) -> Result<Vec<Snapshot>, PveError> {
        Ok(self.client.snapshots(&guest.into()).await?)
    }

    /// PVE's own answer whether every disk snapshots; None where it cannot say.
    pub async fn snapshot_supported(&self, guest: PveGuestRef) -> Option<bool> {
        self.client.snapshot_supported(&guest.into()).await
    }

    pub async fn snapshot_refusal(&self, guest: PveGuestRef) -> Option<String> {
        self.client.snapshot_refusal(&guest.into()).await
    }

    pub async fn snapshot_diff(&self, guest: PveGuestRef, name: String) -> Result<Vec<Diff>, PveError> {
        Ok(self.client.snapshot_diff(&guest.into(), &name).await?)
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

    /// Waits for the task `upid` on `node` to stop; its error is
    /// `actionFailed` with PVE's text.
    pub async fn wait_task(&self, node: String, upid: String) -> Result<(), PveError> {
        Ok(self.client.wait_task(&node, &upid).await?)
    }

    // --- Storage and networks (sbm_virt::resource) ---

    /// Every online node's storages.
    pub async fn storage_pools(&self) -> Result<Vec<ResourcePool>, PveError> {
        Ok(self.client.storage_pools().await?)
    }

    /// The volumes on `pool`.
    pub async fn volumes(&self, pool: ResourcePool) -> Result<Vec<Volume>, PveError> {
        Ok(self.client.volumes(&pool).await?)
    }

    /// Every online node's interfaces. `live` is what
    /// [`super::resource::virt_pve_live_net_script`] printed on the server
    /// this session reaches PVE through; None protects every interface with
    /// an address.
    pub async fn networks(&self, live: Option<String>) -> Result<Vec<Network>, PveError> {
        let live = live.as_deref().and_then(sbm_virt::pve::net::parse_live_net);
        Ok(self.client.networks(live.as_ref()).await?)
    }

    /// Each online node's pending network configuration.
    pub async fn network_changes(&self) -> Result<Vec<NetworkChanges>, PveError> {
        Ok(self.client.network_changes().await?)
    }

    /// Makes `change`, checked first against what the host lists now; `live`
    /// as for [`PveSession::networks`].
    pub async fn manage(&self, change: ResourceChange, live: Option<String>) -> Result<(), PveError> {
        let live = live.as_deref().and_then(sbm_virt::pve::net::parse_live_net);
        Ok(self.client.manage(&change, live.as_ref()).await?)
    }

    // --- Making, copying and deleting (sbm_virt::create) ---

    /// The cluster's next free VMID.
    pub async fn next_vmid(&self) -> Result<u32, PveError> {
        Ok(self.client.next_vmid().await?)
    }

    /// What a new VM can be given.
    #[flutter_rust_bridge::frb(sync)]
    pub fn create_options(&self) -> CreateOptions {
        self.client.create_options()
    }

    /// Creates `spec`, checked first against what the host lists now.
    pub async fn create(&self, spec: CreateSpec) -> Result<Created, PveError> {
        Ok(self.client.create(&spec).await?)
    }

    /// Deletes a stopped guest with its disks, waited for.
    pub async fn delete(&self, guest: PveGuestRef) -> Result<(), PveError> {
        Ok(self.client.delete(&guest.into()).await?)
    }

    /// Turns a stopped guest into a template, waited for.
    pub async fn make_template(&self, guest: PveGuestRef) -> Result<(), PveError> {
        Ok(self.client.make_template(&guest.into()).await?)
    }

    /// Copies `guest` as `request` asks, waited for; the copy's id.
    pub async fn clone_guest(&self, guest: PveGuestRef, request: CloneRequest) -> Result<String, PveError> {
        Ok(self.client.clone_guest(&guest.into(), &request).await?)
    }

    // --- Hardware, settings, cloud-init (sbm_virt::hardware) ---

    /// `guest`'s hardware as it stands.
    pub async fn hardware(&self, guest: PveGuestRef) -> Result<Hardware, PveError> {
        Ok(self.client.hardware(&guest.into()).await?)
    }

    /// Makes `change` from the read whose digest is `revision`, checked first
    /// against the guest as it is now.
    pub async fn change_hardware(&self, guest: PveGuestRef, revision: Option<String>, change: HwChange) -> Result<Outcome, PveError> {
        Ok(self.client.change_hardware(&guest.into(), revision.as_deref(), &change).await?)
    }

    /// Drops every pending change.
    pub async fn revert_pending(&self, guest: PveGuestRef, revision: Option<String>) -> Result<(), PveError> {
        Ok(self.client.revert_pending(&guest.into(), revision.as_deref()).await?)
    }

    /// A VM's cloud-init settings.
    pub async fn cloud_init(&self, guest: PveGuestRef) -> Result<CloudInitState, PveError> {
        Ok(self.client.cloud_init(&guest.into()).await?)
    }

    /// Writes `edit`, and the drive at once.
    pub async fn set_cloud_init(&self, guest: PveGuestRef, edit: CloudInitEdit) -> Result<(), PveError> {
        Ok(self.client.set_cloud_init(&guest.into(), &edit).await?)
    }

    /// The devices `guest` can be given.
    pub async fn host_devices(&self, guest: PveGuestRef) -> Result<HostDevices, PveError> {
        Ok(self.client.host_devices(&guest.into()).await?)
    }

    /// A refusal met on a connection of the app's own (an upload, which
    /// streams), in PVE's words, said as a change's is: a name taken, a
    /// stale digest, a missing privilege and how to grant it.
    #[flutter_rust_bridge::frb(sync)]
    pub fn refusal(&self, message: String, status: Option<u16>) -> PveError {
        self.client.refusal(&message, status).into()
    }

    // --- Backups and backup jobs (sbm_virt::backup) ---

    /// `guest`'s backups on its node's backup storages.
    pub async fn backups(&self, guest: PveGuestRef) -> Result<Vec<Backup>, PveError> {
        Ok(self.client.backups(&guest.into()).await?)
    }

    /// `node`'s storages that hold backups.
    pub async fn backup_storages(&self, node: String) -> Result<Vec<ResourcePool>, PveError> {
        Ok(self.client.backup_storages(&node).await?)
    }

    /// Every online node's backup storages.
    pub async fn all_backup_storages(&self) -> Result<Vec<ResourcePool>, PveError> {
        Ok(self.client.all_backup_storages().await?)
    }

    /// The jobs that take `guest`.
    pub async fn backup_jobs(&self, guest: PveGuestRef) -> Result<Vec<BackupJob>, PveError> {
        Ok(self.client.backup_jobs(&guest.into()).await?)
    }

    /// The datacenter's jobs.
    pub async fn all_backup_jobs(&self) -> Result<Vec<BackupJob>, PveError> {
        Ok(self.client.all_backup_jobs().await?)
    }

    /// Makes, edits or (`remove`) removes `edit`, checked first.
    pub async fn edit_backup_job(&self, edit: BackupJobEdit, remove: bool) -> Result<(), PveError> {
        Ok(self.client.edit_backup_job(&edit, remove).await?)
    }

    /// What the host makes of `schedule`.
    pub async fn check_schedule(&self, schedule: String) -> Result<ScheduleCheck, PveError> {
        Ok(self.client.check_schedule(&schedule).await?)
    }

    /// A backup of `guest` now, as `request` asks, waited for.
    pub async fn backup(&self, guest: PveGuestRef, request: BackupRequest) -> Result<(), PveError> {
        Ok(self.client.backup(&guest.into(), &request).await?)
    }

    /// A job's "Run now", on its node or every online one, waited for.
    pub async fn run_backup_job(&self, id: String) -> Result<(), PveError> {
        Ok(self.client.run_backup_job(&id).await?)
    }

    /// `backup_id` restored over `guest` (stopped) or as `vmid`; `storage`
    /// where its disks land.
    pub async fn restore_backup(&self, guest: PveGuestRef, backup_id: String, vmid: Option<u32>, storage: Option<String>) -> Result<(), PveError> {
        Ok(self.client.restore_backup(&guest.into(), &backup_id, vmid, storage.as_deref()).await?)
    }

    /// `backup`'s notes and protection, as `edit` sets them.
    pub async fn edit_backup(&self, backup: Backup, edit: BackupEdit) -> Result<(), PveError> {
        Ok(self.client.edit_backup(&backup, &edit).await?)
    }

    /// Deletes `backup`, waited for.
    pub async fn delete_backup(&self, backup: Backup) -> Result<(), PveError> {
        Ok(self.client.delete_backup(&backup).await?)
    }

    /// The headers that authenticate a connection made outside the session
    /// (an upload), logging in first if needed.
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
