//! Proxmox VE's cluster resources, and the requests that act on them.
//!
//! The app reaches a PVE node by forwarding a local socket through SSH and
//! speaking the REST API itself (`lib/data/provider/pve.dart`); an agent
//! reaches it directly, because it runs on the machine that can. Both read the
//! same API, so the reading is here and the transport is the caller's.
//!
//! PVE's own names are kept: `type` tags a resource, `id` is what PVE calls it,
//! and an action is addressed by PVE's own path
//! (`/api2/json/nodes/{node}/{kind}/{vmid}/status/{action}`) rather than by a
//! spelling of ours that would have to be translated back.
//!
//! **Units are PVE's, not this crate's.** Memory and disk are bytes here, where
//! the command parsers in this crate report KiB; `cpu` is a fraction of one
//! core rather than a cumulative tick count. They are passed through unchanged,
//! since the client that draws them is the one that knows the format.

use serde::{Deserialize, Serialize, Deserializer};
use serde_json::Value;

/// The longest a node name may be. PVE's own limit is the shorter of what a
/// hostname and a cluster node name allow; 64 is the DNS label limit it
/// effectively follows.
pub const MAX_NODE: usize = 64;

/// The range of ids PVE assigns a guest.
pub const MIN_VMID: u32 = 100;
pub const MAX_VMID: u32 = 999_999_999;

/// One entry of `GET /api2/json/cluster/resources`.
///
/// Tagged and serialized by PVE's own `type`, so what this crate parses is what
/// a client is sent: one shape, written down once.
#[derive(Debug, Clone, PartialEq, Serialize, Deserialize)]
#[serde(tag = "type", rename_all = "lowercase")]
pub enum PveResource {
    Node(PveNode),
    Qemu(PveGuest),
    Lxc(PveGuest),
    Storage(PveStorage),
    Sdn(PveSdn),
}

/// A node of the cluster: the machine PVE itself runs on.
#[derive(Debug, Clone, PartialEq, Serialize, Deserialize)]
pub struct PveNode {
    pub id: String,
    /// The node's name, which is also what a guest's `node` field holds.
    pub node: String,
    pub status: String,
    #[serde(default)]
    pub uptime: u64,
    #[serde(default)]
    pub mem: u64,
    #[serde(default)]
    pub maxmem: u64,
    #[serde(default)]
    pub cpu: f64,
    #[serde(default)]
    pub maxcpu: u32,
    #[serde(default)]
    pub disk: u64,
    #[serde(default)]
    pub maxdisk: u64,
}

/// One VM or one container.
///
/// The two are separate cases of [`PveResource`] with the same fields, because
/// that is the API's shape: PVE reports them side by side from one endpoint and
/// every field below has the same meaning in both. What differs is which
/// endpoints address them, which is [`PveGuestKind`]'s job.
#[derive(Debug, Clone, PartialEq, Serialize, Deserialize)]
pub struct PveGuest {
    /// PVE's own identity for the resource, e.g. `qemu/101`.
    pub id: String,
    pub node: String,
    pub vmid: u32,
    /// Empty for a guest that was never named; a client drawing one falls back
    /// to [`Self::vmid`], which is the other thing an operator knows it by.
    #[serde(default)]
    pub name: String,
    pub status: String,
    #[serde(default)]
    pub uptime: u64,
    #[serde(default)]
    pub mem: u64,
    #[serde(default)]
    pub maxmem: u64,
    #[serde(default)]
    pub cpu: f64,
    #[serde(default)]
    pub maxcpu: u32,
    #[serde(default)]
    pub disk: u64,
    #[serde(default)]
    pub maxdisk: u64,
    #[serde(default)]
    pub diskread: u64,
    #[serde(default)]
    pub diskwrite: u64,
    #[serde(default)]
    pub netin: u64,
    #[serde(default)]
    pub netout: u64,
}

/// One storage a node offers.
#[derive(Debug, Clone, PartialEq, Serialize, Deserialize)]
pub struct PveStorage {
    pub id: String,
    pub node: String,
    pub storage: String,
    pub status: String,
    #[serde(default)]
    pub plugintype: String,
    /// The content types this storage holds, sorted — see [`sorted_content`].
    #[serde(default, deserialize_with = "sorted_content")]
    pub content: String,
    #[serde(default)]
    pub shared: u32,
    #[serde(default)]
    pub disk: u64,
    #[serde(default)]
    pub maxdisk: u64,
}

/// One SDN zone.
#[derive(Debug, Clone, PartialEq, Serialize, Deserialize)]
pub struct PveSdn {
    pub id: String,
    pub node: String,
    pub sdn: String,
    pub status: String,
}

/// PVE lists a storage's content types in the order it read the plugin's
/// configuration, so the same storage answers differently between calls. Sorted
/// here for that reason, which is also what the app does with the same field.
///
/// An empty part is dropped: `iso,,backup` is a spelling of two content types,
/// not three.
fn sorted_content<'de, D: Deserializer<'de>>(deserializer: D) -> Result<String, D::Error> {
    let raw = String::deserialize(deserializer)?;
    let mut parts: Vec<&str> = raw
        .split(',')
        .map(str::trim)
        .filter(|part| !part.is_empty())
        .collect();
    parts.sort_unstable();
    Ok(parts.join(","))
}

/// Which of PVE's resource types an entry is.
///
/// This crate's own label rather than a second wire shape: [`PveResource`] is
/// what a request answers with, and this is what a caller switches on when it
/// does not want to destructure the enum — sorting, and the guest check the
/// control endpoint makes.
#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum PveKind {
    Node,
    Qemu,
    Lxc,
    Storage,
    Sdn,
}

impl PveKind {
    pub fn as_str(self) -> &'static str {
        match self {
            Self::Node => "node",
            Self::Qemu => "qemu",
            Self::Lxc => "lxc",
            Self::Storage => "storage",
            Self::Sdn => "sdn",
        }
    }

    pub fn parse(value: &str) -> Option<Self> {
        match value {
            "node" => Some(Self::Node),
            "qemu" => Some(Self::Qemu),
            "lxc" => Some(Self::Lxc),
            "storage" => Some(Self::Storage),
            "sdn" => Some(Self::Sdn),
            _ => None,
        }
    }

    /// Where this kind sits in the listing. Nodes first — they are what every
    /// other resource belongs to — then the guests, then what holds their disks
    /// and what connects them.
    fn rank(self) -> u8 {
        match self {
            Self::Node => 0,
            Self::Qemu => 1,
            Self::Lxc => 2,
            Self::Storage => 3,
            Self::Sdn => 4,
        }
    }
}

/// The two kinds of resource an action can be sent to.
///
/// A node and a storage have no status endpoint, so a request naming one is
/// refused rather than answered with a path that would only ever 501.
#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum PveGuestKind {
    Qemu,
    Lxc,
}

impl PveGuestKind {
    pub fn as_str(self) -> &'static str {
        match self {
            Self::Qemu => "qemu",
            Self::Lxc => "lxc",
        }
    }

    pub fn parse(value: &str) -> Option<Self> {
        match value {
            "qemu" => Some(Self::Qemu),
            "lxc" => Some(Self::Lxc),
            _ => None,
        }
    }
}

/// What may be asked of a guest.
///
/// PVE's own four, spelled as PVE spells them: `stop` is a hard power-off and
/// `shutdown` asks the guest's own init to stop, which is a distinction the
/// client has to show and cannot recover from a single "stop".
#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum PveAction {
    Start,
    Stop,
    Shutdown,
    Reboot,
}

impl PveAction {
    pub fn as_str(self) -> &'static str {
        match self {
            Self::Start => "start",
            Self::Stop => "stop",
            Self::Shutdown => "shutdown",
            Self::Reboot => "reboot",
        }
    }

    pub fn parse(value: &str) -> Option<Self> {
        match value {
            "start" => Some(Self::Start),
            "stop" => Some(Self::Stop),
            "shutdown" => Some(Self::Shutdown),
            "reboot" => Some(Self::Reboot),
            _ => None,
        }
    }
}

/// A request this crate will not compose. The codes are the stable names a
/// client phrases, so changing one is a break in the contract.
#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum PveError {
    /// The response was not the document it should have been.
    InvalidResponse,
    /// Not a name PVE would accept as a node, or one this agent will not put
    /// into a URL path.
    InvalidNode,
    /// Outside the range PVE assigns.
    InvalidVmid,
}

impl PveError {
    pub fn as_str(self) -> &'static str {
        match self {
            Self::InvalidResponse => "invalidResponse",
            Self::InvalidNode => "invalidNode",
            Self::InvalidVmid => "invalidVmid",
        }
    }
}

impl std::fmt::Display for PveError {
    fn fmt(&self, f: &mut std::fmt::Formatter<'_>) -> std::fmt::Result {
        f.write_str(self.as_str())
    }
}

impl std::error::Error for PveError {}

/// Whether PVE would accept this as a node name.
///
/// PVE's own rule, `^[a-zA-Z0-9]([a-zA-Z0-9._-]*[a-zA-Z0-9])?$`, bounded at
/// [`MAX_NODE`]. Checked here because the caller's node is composed into a URL
/// path this agent sends with its own credential: a value that could close the
/// segment, or introduce a query, would address something other than the node
/// the caller named.
pub fn is_node_name(value: &str) -> bool {
    if value.is_empty() || value.len() > MAX_NODE {
        return false;
    }
    let mut chars = value.chars();
    let first = chars.next().expect("checked non-empty above");
    if !first.is_ascii_alphanumeric() {
        return false;
    }
    let rest: Vec<char> = chars.collect();
    let Some(last) = rest.last() else {
        return true;
    };
    if !last.is_ascii_alphanumeric() {
        return false;
    }
    rest.iter().all(|c| c.is_ascii_alphanumeric() || matches!(c, '.' | '_' | '-'))
}

/// The path an action on one guest is sent to, below the cluster's base URL.
///
/// Every piece is validated or typed: the node against [`is_node_name`], the
/// vmid against PVE's range. Nothing a caller sent reaches the path unchecked,
/// which is the whole reason this is a function here rather than a `format!` in
/// the endpoint.
pub fn control_path(
    node: &str,
    kind: PveGuestKind,
    vmid: u32,
    action: PveAction,
) -> Result<String, PveError> {
    if !is_node_name(node) {
        return Err(PveError::InvalidNode);
    }
    if !(MIN_VMID..=MAX_VMID).contains(&vmid) {
        return Err(PveError::InvalidVmid);
    }
    Ok(format!(
        "/api2/json/nodes/{node}/{}/{vmid}/status/{}",
        kind.as_str(),
        action.as_str()
    ))
}

/// PVE's ticket endpoint: where a password credential logs in.
pub const TICKET_PATH: &str = "/api2/json/access/ticket";

/// The cluster's version, whose `release` is the string a client shows as which
/// PVE this is.
pub const VERSION_PATH: &str = "/api2/json/version";

/// Every resource in the cluster, which is what both clients draw.
pub const RESOURCES_PATH: &str = "/api2/json/cluster/resources";

/// The cookie a ticket is presented as.
pub const AUTH_COOKIE: &str = "PVEAuthCookie";

/// The header PVE requires beside that cookie on anything that changes state.
pub const CSRF_HEADER: &str = "CSRFPreventionToken";

/// The `Authorization` value an API token is presented as.
///
/// PVE's own format, `PVEAPIToken=USER@REALM!TOKENID=SECRET`, and the reason a
/// token is worth supporting at all: it authenticates without a ticket, so it
/// survives an account that has two-factor authentication enabled — which is
/// the default advice for `root@pam`, and something a stored password cannot
/// satisfy.
pub fn token_header(username: &str, realm: &str, token_id: &str, secret: &str) -> String {
    format!("PVEAPIToken={username}@{realm}!{token_id}={secret}")
}

/// What `GET /api2/json/cluster/resources` answered, as resources.
///
/// Lenient per entry and strict about the document: an entry whose type this
/// build does not know, or that is missing what it takes to draw it, is
/// skipped rather than failing the listing — PVE answers about every kind of
/// resource in a cluster, and one unreadable entry is not a reason to answer
/// nothing. A body that is not the documented envelope at all is
/// [`PveError::InvalidResponse`].
pub fn parse_cluster_resources(body: &Value) -> Result<Vec<PveResource>, PveError> {
    let entries = body
        .get("data")
        .and_then(Value::as_array)
        .ok_or(PveError::InvalidResponse)?;

    let mut resources: Vec<PveResource> = Vec::with_capacity(entries.len());
    for entry in entries {
        if let Ok(resource) = serde_json::from_value::<PveResource>(entry.clone()) {
            resources.push(resource);
        }
    }
    resources.sort_by(|a, b| a.sort_key().cmp(&b.sort_key()));
    Ok(resources)
}

/// The version `GET /api2/json/version` answered, e.g. `8.2.4`.
///
/// Absent rather than an error when the document is not what it should be: the
/// release is a label on a page that is drawn from the resources either way.
pub fn parse_version(body: &Value) -> Option<String> {
    let release = body.get("data")?.get("release")?.as_str()?;
    (!release.is_empty()).then(|| release.to_string())
}

impl PveResource {
    pub fn kind(&self) -> PveKind {
        match self {
            Self::Node(_) => PveKind::Node,
            Self::Qemu(_) => PveKind::Qemu,
            Self::Lxc(_) => PveKind::Lxc,
            Self::Storage(_) => PveKind::Storage,
            Self::Sdn(_) => PveKind::Sdn,
        }
    }

    pub fn id(&self) -> &str {
        match self {
            Self::Node(node) => &node.id,
            Self::Qemu(guest) | Self::Lxc(guest) => &guest.id,
            Self::Storage(storage) => &storage.id,
            Self::Sdn(sdn) => &sdn.id,
        }
    }

    pub fn node(&self) -> &str {
        match self {
            Self::Node(node) => &node.node,
            Self::Qemu(guest) | Self::Lxc(guest) => &guest.node,
            Self::Storage(storage) => &storage.node,
            Self::Sdn(sdn) => &sdn.node,
        }
    }

    pub fn status(&self) -> &str {
        match self {
            Self::Node(node) => &node.status,
            Self::Qemu(guest) | Self::Lxc(guest) => &guest.status,
            Self::Storage(storage) => &storage.status,
            Self::Sdn(sdn) => &sdn.status,
        }
    }

    /// What PVE names this resource by, which is a different field per type.
    /// Empty for a guest that was never named.
    pub fn name(&self) -> &str {
        match self {
            Self::Node(node) => &node.node,
            Self::Qemu(guest) | Self::Lxc(guest) => &guest.name,
            Self::Storage(storage) => &storage.storage,
            Self::Sdn(sdn) => &sdn.sdn,
        }
    }

    /// The id a guest is controlled by, for the two kinds that have one.
    pub fn guest_kind(&self) -> Option<PveGuestKind> {
        match self.kind() {
            PveKind::Qemu => Some(PveGuestKind::Qemu),
            PveKind::Lxc => Some(PveGuestKind::Lxc),
            _ => None,
        }
    }

    pub fn vmid(&self) -> Option<u32> {
        match self {
            Self::Qemu(guest) | Self::Lxc(guest) => Some(guest.vmid),
            _ => None,
        }
    }

    /// Whether the resource is up, in each type's own word for it: a node is
    /// `online`, a storage `available`, an SDN zone `ok`, and a guest runs.
    ///
    /// Here rather than at each client, because getting it wrong is silent:
    /// every one of the four would otherwise be re-derived, and a client that
    /// asked a node for `running` would draw every node as stopped.
    pub fn is_running(&self) -> bool {
        match self {
            Self::Node(_) => self.status() == "online",
            Self::Qemu(_) | Self::Lxc(_) => self.status() == "running",
            Self::Storage(_) => self.status() == "available",
            Self::Sdn(_) => self.status() == "ok",
        }
    }

    /// Where the resource sits in a listing, and what keeps it there.
    ///
    /// PVE returns the cluster's resources in an order that varies between
    /// calls, so sorting here is what makes two refreshes of one page show the
    /// same rows in the same places. The app instead remembers the previous
    /// answer and reorders the new one against it, which needs state on the
    /// client and still moves a resource the moment it is added.
    fn sort_key(&self) -> (u8, &str, u64, &str) {
        let kind = self.kind();
        let node = self.node();
        match self {
            Self::Qemu(guest) | Self::Lxc(guest) => {
                (kind.rank(), node, u64::from(guest.vmid), "")
            }
            Self::Node(node) => (kind.rank(), &node.node, 0, ""),
            Self::Storage(storage) => (kind.rank(), node, 0, &storage.storage),
            Self::Sdn(sdn) => (kind.rank(), node, 0, &sdn.sdn),
        }
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    use serde_json::json;

    /// One well-formed entry per type, in a deliberately scrambled order.
    fn cluster() -> Value {
        json!({"data": [
            {"type": "storage", "id": "storage/pve/local", "node": "pve", "storage": "local",
             "status": "available", "content": "iso,backup", "shared": 0, "disk": 1, "maxdisk": 2},
            {"type": "lxc", "id": "lxc/100", "node": "pve", "vmid": 100, "name": "box",
             "status": "running", "cpu": 0.5, "maxcpu": 2, "mem": 3, "maxmem": 4},
            {"type": "node", "id": "node/pve", "node": "pve", "status": "online", "uptime": 9},
            {"type": "qemu", "id": "qemu/101", "node": "pve", "vmid": 101, "name": "win",
             "status": "stopped"},
            {"type": "sdn", "id": "sdn/pve/z", "node": "pve", "sdn": "z", "status": "ok"},
        ]})
    }

    #[test]
    fn the_listing_is_parsed_by_type() {
        let resources = parse_cluster_resources(&cluster()).unwrap();
        let kinds: Vec<&str> = resources.iter().map(|r| r.kind().as_str()).collect();
        assert_eq!(kinds, vec!["node", "qemu", "lxc", "storage", "sdn"]);
        assert_eq!(resources[0].name(), "pve");
        assert_eq!(resources[1].vmid(), Some(101));
        assert_eq!(resources[2].id(), "lxc/100");
        assert_eq!(resources[4].status(), "ok");
    }

    #[test]
    fn the_order_is_the_listings_own() {
        // Sorted by kind, then node, then the resource's own key — so a page
        // refreshed shows the same rows in the same places whatever order the
        // cluster answered in. The `lxc` is missing from the input above it.
        let body = json!({"data": [
            {"type": "qemu", "id": "qemu/102", "node": "pve", "vmid": 102, "name": "b", "status": "stopped"},
            {"type": "qemu", "id": "qemu/101", "node": "pve", "vmid": 101, "name": "a", "status": "stopped"},
            {"type": "qemu", "id": "qemu/103", "node": "alpha", "vmid": 103, "name": "c", "status": "stopped"},
        ]});
        let resources = parse_cluster_resources(&body).unwrap();
        let vms: Vec<u32> = resources.iter().filter_map(PveResource::vmid).collect();
        // `alpha` before `pve`, and within a node by vmid: a cluster's nodes
        // are not in the order the guests arrive in.
        assert_eq!(vms, vec![103, 101, 102]);
    }

    #[test]
    fn an_entry_that_cannot_be_drawn_is_skipped() {
        // A type this build does not know (PVE adds them), and a guest with no
        // identity — neither is a reason to answer nothing for the other two.
        let body = json!({"data": [
            {"type": "pool", "id": "pool/pve/x", "poolid": "x"},
            {"type": "qemu", "name": "nameless", "status": "running"},
            {"type": "sdn", "id": "sdn/pve/z", "node": "pve", "sdn": "z", "status": "ok"},
        ]});
        let resources = parse_cluster_resources(&body).unwrap();
        assert_eq!(resources.len(), 1);
        assert_eq!(resources[0].id(), "sdn/pve/z");
    }

    #[test]
    fn a_guest_without_a_name_keeps_its_id() {
        let body = json!({"data": [
            {"type": "qemu", "id": "qemu/101", "node": "pve", "vmid": 101, "status": "stopped"},
        ]});
        let resources = parse_cluster_resources(&body).unwrap();
        assert_eq!(resources[0].name(), "");
        assert_eq!(resources[0].vmid(), Some(101));
    }

    #[test]
    fn a_body_that_is_not_a_listing_is_refused() {
        assert_eq!(
            parse_cluster_resources(&json!({"data": null})),
            Err(PveError::InvalidResponse)
        );
        assert_eq!(
            parse_cluster_resources(&json!({})),
            Err(PveError::InvalidResponse)
        );
        // An empty cluster is a listing, not a failure.
        assert_eq!(parse_cluster_resources(&json!({"data": []})).unwrap().len(), 0);
    }

    #[test]
    fn a_storage_content_list_is_sorted() {
        // PVE echoes the plugin's own order and answers differently between
        // calls; the app sorts the same field, so this does too.
        let body = json!({"data": [
            {"type": "storage", "id": "storage/pve/s", "node": "pve", "storage": "s",
             "status": "available", "content": "vztmpl, iso,,backup"},
        ]});
        let resources = parse_cluster_resources(&body).unwrap();
        let PveResource::Storage(storage) = &resources[0] else {
            panic!("expected a storage");
        };
        assert_eq!(storage.content, "backup,iso,vztmpl");
    }

    #[test]
    fn each_type_answers_running_in_its_own_word() {
        let resources = parse_cluster_resources(&cluster()).unwrap();
        // `offline` is not a stopped node's word — PVE says `offline` for one
        // that is down, so the check is equality rather than a denylist.
        assert!(resources[0].is_running(), "online node");
        assert!(!resources[1].is_running(), "stopped guest");
        assert!(resources[2].is_running(), "running guest");
        assert!(resources[3].is_running(), "available storage");
        assert!(resources[4].is_running(), "ok sdn");
    }

    #[test]
    fn only_a_guest_has_a_control_kind() {
        let resources = parse_cluster_resources(&cluster()).unwrap();
        assert_eq!(resources[0].guest_kind(), None);
        assert_eq!(resources[1].guest_kind(), Some(PveGuestKind::Qemu));
        assert_eq!(resources[3].guest_kind(), None);
    }

    #[test]
    fn a_control_path_is_pve_own() {
        assert_eq!(
            control_path("pve", PveGuestKind::Qemu, 101, PveAction::Start).unwrap(),
            "/api2/json/nodes/pve/qemu/101/status/start"
        );
        assert_eq!(
            control_path("node-1.internal", PveGuestKind::Lxc, 999999999, PveAction::Shutdown)
                .unwrap(),
            "/api2/json/nodes/node-1.internal/lxc/999999999/status/shutdown"
        );
    }

    #[test]
    fn a_node_name_is_checked_before_it_reaches_a_path() {
        // The caller's node is composed into a URL this agent sends with its
        // own credential, so anything that could leave the segment is refused.
        for bad in [
            "",
            "pve/../nodes/other",
            "pve?x=1",
            "pve#f",
            "pve x",
            "pve%2f",
            "../etc",
            "-lead",
            ".dotted",
            "trailing-",
            &"n".repeat(MAX_NODE + 1),
        ] {
            assert!(!is_node_name(bad), "{bad:?} should be refused");
            assert_eq!(
                control_path(bad, PveGuestKind::Qemu, 100, PveAction::Start),
                Err(PveError::InvalidNode)
            );
        }
        for good in ["pve", "p", "node-1", "node_2", "a.b.c", "0", "N1"] {
            assert!(is_node_name(good), "{good:?} should be accepted");
        }
    }

    #[test]
    fn a_vmid_outside_pve_range_is_refused() {
        for bad in [0, 1, 99, MAX_VMID + 1] {
            assert_eq!(
                control_path("pve", PveGuestKind::Qemu, bad, PveAction::Start),
                Err(PveError::InvalidVmid)
            );
        }
        assert!(control_path("pve", PveGuestKind::Qemu, MIN_VMID, PveAction::Stop).is_ok());
    }

    #[test]
    fn a_kind_and_an_action_are_read_by_name() {
        // Stored nowhere and sent by a client, but a client that misspells one
        // gets `None` rather than a default that would act on something else.
        assert_eq!(PveGuestKind::parse("lxc"), Some(PveGuestKind::Lxc));
        assert_eq!(PveGuestKind::parse("node"), None);
        assert_eq!(PveGuestKind::parse("QEMU"), None);
        assert_eq!(PveAction::parse("reboot"), Some(PveAction::Reboot));
        assert_eq!(PveAction::parse("restart"), None);
        assert_eq!(PveKind::parse("storage"), Some(PveKind::Storage));
    }

    #[test]
    fn the_version_is_read_or_absent() {
        assert_eq!(
            parse_version(&json!({"data": {"release": "8.2.4", "version": "8.2"}})),
            Some("8.2.4".to_string())
        );
        assert_eq!(parse_version(&json!({"data": {"release": ""}})), None);
        assert_eq!(parse_version(&json!({"data": null})), None);
        assert_eq!(parse_version(&json!({})), None);
    }

    #[test]
    fn a_token_is_presented_the_way_pve_spells_it() {
        assert_eq!(
            token_header("root", "pam", "automation", "secret"),
            "PVEAPIToken=root@pam!automation=secret"
        );
    }
}
