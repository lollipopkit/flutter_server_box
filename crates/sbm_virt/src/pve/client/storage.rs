//! A PVE host's storages and network interfaces: listing them, and the
//! changes [`crate::resource::Change`] names.
//!
//! A storage is cluster configuration (`/storage`), limited to the node it
//! was made on; a volume and a bridge are a node's. Network changes wait in
//! the node's `interfaces.new` until [`Change::NetworkApply`].
//!
//! **What carries the node's management traffic is never changed.** The
//! API does not say which interface a client is connected through, so the
//! caller passes what the node itself said ([`LiveNet`], from
//! [`super::super::net::LIVE_NET_SCRIPT`] run on it); without that, every
//! interface with an address is protected.

use std::collections::{BTreeMap, BTreeSet};

use futures_util::StreamExt;
use serde_json::Value;

use super::{Client, guest_path};
use crate::error::{Detail, Error, ErrorKind, Result};
use crate::model::HostKind;
use crate::pve::http::{Body, Method};
use crate::pve::net::{self, LiveNet};
use crate::pve::{form, resources, seg};
use crate::resource::{self, Change, GuestRef, Issue, Listing, Network, NetworkChanges, Pool, Volume};

/// How many requests a listing keeps in flight: import images sized, guest
/// configurations read for their NICs.
const CONCURRENCY: usize = 4;

impl Client {
    /// The online nodes, by name.
    async fn online_nodes(&self) -> Result<Vec<String>> {
        let data = self.call(Method::Get, "/nodes", None, false).await?;
        let mut nodes: Vec<String> = data
            .as_array()
            .map(|list| {
                list.iter()
                    .filter(|n| n.get("status").and_then(Value::as_str) == Some("online"))
                    .filter_map(|n| resources::str_of(n.get("node")))
                    .collect()
            })
            .unwrap_or_default();
        nodes.sort();
        Ok(nodes)
    }

    /// Every online node's storages. Where each is comes from the cluster's
    /// configuration, which needs `Datastore.Audit` on `/storage`: without
    /// it the list is still there, only without paths.
    pub async fn storage_pools(&self) -> Result<Vec<Pool>> {
        let config = match self.call(Method::Get, "/storage", None, false).await {
            Ok(Value::Array(c)) => c,
            Ok(_) => Vec::new(),
            Err(e) if e.kind == ErrorKind::AuthFailed && e.status == Some(403) => Vec::new(),
            Err(e) => return Err(e),
        };
        let mut out = Vec::new();
        for node in self.online_nodes().await? {
            if let Value::Array(list) = self.call(Method::Get, &format!("/nodes/{}/storage", seg(&node)), None, false).await? {
                out.extend(resources::parse_storages(&node, &list, &config));
            }
        }
        Ok(out)
    }

    /// The volumes on `pool`, each with the guest that owns it where that
    /// guest exists, and the virtual size of each import image
    /// whose listing gives only its file's
    /// ([`resources::image_size_unknown`]) — what a new disk made from it
    /// must hold at least. One PVE will not size stays unknown.
    pub async fn volumes(&self, pool: &Pool) -> Result<Vec<Volume>> {
        if !pool.active {
            return Ok(Vec::new());
        }
        let path = storage_path(pool)?;
        let Value::Array(list) = self.call(Method::Get, &format!("{path}/content"), None, false).await? else {
            return Err(Error::detail(ErrorKind::InvalidResponse, Detail::InvalidData));
        };
        let mut volumes = resources::parse_content(&list);
        // The listing names each volume's owner by VMID, whether or not that
        // guest still exists: one that does not is an orphan, used by
        // nothing, and deleting it is how it goes.
        let guests = match self.call(Method::Get, "/cluster/resources?type=vm", None, false).await? {
            Value::Array(list) => resources::parse(&list, self.now()).guests,
            _ => Vec::new(),
        };
        resources::owned_by(&mut volumes, &guests);
        let node = pool.node.clone().unwrap_or_default();
        let todo: Vec<usize> = (0..volumes.len())
            .filter(|&i| resources::image_size_unknown(volumes[i].content.as_deref(), volumes[i].format.as_deref()))
            .collect();
        let sizes: Vec<(usize, Option<u64>)> = futures_util::stream::iter(todo)
            .map(|i| {
                let id = volumes[i].id.clone();
                let node = node.clone();
                async move {
                    let storage = id.split(':').next().unwrap_or_default().to_owned();
                    let at = format!("/nodes/{}/storage/{}/content/{}", seg(&node), seg(&storage), seg(&id));
                    let size = self.call(Method::Get, &at, None, false).await.ok().and_then(|info| resources::uint(info.get("size")));
                    (i, size)
                }
            })
            .buffer_unordered(CONCURRENCY)
            .collect()
            .await;
        for (i, size) in sizes {
            if size.is_some() {
                volumes[i].capacity = size;
            }
        }
        Ok(volumes)
    }

    /// Every online node's interfaces, with the guests whose NICs are on
    /// each bridge — read from each guest's configuration — and which may be
    /// changed at all. `live` is what the node this client is reached
    /// through says it is using; it describes that node only.
    pub async fn networks(&self, live: Option<&LiveNet>) -> Result<Vec<Network>> {
        let guests = match self.call(Method::Get, "/cluster/resources?type=vm", None, false).await? {
            Value::Array(list) => resources::parse(&list, self.now()).guests,
            _ => Vec::new(),
        };
        let mut out = Vec::new();
        for node in self.online_nodes().await? {
            let Value::Array(raw) = self.call(Method::Get, &format!("/nodes/{}/network", seg(&node)), None, false).await? else {
                continue;
            };
            let on_node: Vec<_> = guests.iter().filter(|g| g.node.as_deref() == Some(&node)).collect();
            let users = self.bridge_users(&on_node).await?;
            let management = management(&node, &raw, live, &BTreeSet::new());
            out.extend(resources::parse_networks(&node, &raw, &users, &management));
        }
        Ok(out)
    }

    async fn bridge_users(&self, guests: &[&crate::model::Guest]) -> Result<BTreeMap<String, Vec<GuestRef>>> {
        // Owned: a stream of futures borrowing a `&Guest` each is not `Send`
        // (rust-lang/rust#102211), and the caller's future must be.
        let owned: Vec<crate::model::Guest> = guests.iter().map(|g| (*g).clone()).collect();
        let read: Vec<Result<BTreeMap<String, Vec<GuestRef>>>> = futures_util::stream::iter(owned)
            .map(|guest| async move {
                let guest = &guest;
                let path = guest_path(guest)?;
                match self.call(Method::Get, &format!("{path}/config"), None, false).await {
                    Ok(Value::Object(config)) => Ok(resources::bridge_users(guest, &config)),
                    Ok(_) => Ok(BTreeMap::new()),
                    // One guest this account may not read, or one deleted
                    // since it was listed ("Configuration file ... does not
                    // exist"), leaves only that guest out.
                    Err(e) if matches!(e.kind, ErrorKind::AuthFailed | ErrorKind::InvalidResponse) && e.status != Some(401) => {
                        Ok(BTreeMap::new())
                    }
                    Err(e) => Err(e),
                }
            })
            .buffer_unordered(CONCURRENCY)
            .collect()
            .await;
        let mut users: BTreeMap<String, Vec<GuestRef>> = BTreeMap::new();
        for of in read {
            for (bridge, refs) in of? {
                users.entry(bridge).or_default().extend(refs);
            }
        }
        for list in users.values_mut() {
            list.sort_by_key(|r| r.vmid.unwrap_or(0));
        }
        Ok(users)
    }

    /// Each online node's pending network configuration: the `changes` PVE
    /// puts beside the interfaces it lists.
    pub async fn network_changes(&self) -> Result<Vec<NetworkChanges>> {
        let mut out = Vec::new();
        for node in self.online_nodes().await? {
            let body = self.call_with(Method::Get, &format!("/nodes/{}/network", seg(&node)), None, false, true).await?;
            if let Some(diff) = body.get("changes").and_then(Value::as_str).filter(|d| !d.trim().is_empty()) {
                out.push(NetworkChanges { node, diff: diff.to_owned() });
            }
        }
        Ok(out)
    }

    /// Makes `change`, checked first against what the host lists now
    /// ([`resource::issue`]): a refused one is [`ErrorKind::Unsupported`]
    /// with [`Detail::Refused`], a name taken [`ErrorKind::Exists`].
    ///
    /// A node's network changes run one at a time: they all write the one
    /// pending file, and an apply or a revert running beside an edit would
    /// apply what its safety check never saw, or drop an edit just saved.
    pub async fn manage(&self, change: &Change, live: Option<&LiveNet>) -> Result<()> {
        let node = match change {
            Change::NetworkCreate { node, .. } => node.clone(),
            Change::NetworkApply { node } | Change::NetworkRevert { node } => Some(node.clone()),
            Change::NetworkEditBridge { network, .. } | Change::NetworkDelete { network } => {
                network.split_once('/').map(|(node, _)| node.to_owned())
            }
            _ => None,
        };
        let lock = node.map(|n| self.net_changes.lock().unwrap().entry(n).or_default().clone());
        let _held = match &lock {
            Some(l) => Some(l.lock().await),
            None => None,
        };
        self.manage_now(change, live).await.map_err(|e| self.manage_err(e))
    }

    async fn manage_now(&self, change: &Change, live: Option<&LiveNet>) -> Result<()> {
        let pools = if change.is_network() { Vec::new() } else { self.storage_pools().await? };
        let pool = change.pool().and_then(|id| pools.iter().find(|p| p.id == id));
        let volumes = match (change, pool) {
            (Change::PoolSetActive { .. } | Change::PoolDelete { .. } | Change::VolumeCreate { .. } | Change::VolumeDelete { .. }, Some(p)) => {
                self.volumes(p).await?
            }
            _ => Vec::new(),
        };
        let networks = match change {
            Change::NetworkCreate { .. } | Change::NetworkEditBridge { .. } | Change::NetworkDelete { .. } => {
                self.networks(live).await?
            }
            _ => Vec::new(),
        };
        if let Some(issue) = resource::issue(change, HostKind::Pve, Listing { pools: &pools, networks: &networks, volumes: &volumes }) {
            return Err(resource::refusal(issue));
        }
        let network = change.network().and_then(|id| networks.iter().find(|n| n.id == id));
        match change {
            Change::PoolCreate { name, pool_type, source, node, content, .. } => {
                let mut fields: Vec<(&str, String)> = vec![("storage", name.clone()), ("type", pool_type.clone())];
                match pool_type.as_str() {
                    "dir" => fields.push(("path", source.clone())),
                    "nfs" => {
                        let at = source.find(":/").unwrap_or_default();
                        fields.push(("server", source[..at].to_owned()));
                        fields.push(("export", source[at + 1..].to_owned()));
                    }
                    "lvmthin" => {
                        let (vg, thin) = source.split_once('/').unwrap_or_default();
                        fields.push(("vgname", vg.to_owned()));
                        fields.push(("thinpool", thin.to_owned()));
                    }
                    "zfspool" => fields.push(("pool", source.clone())),
                    _ => return Err(Error::new(ErrorKind::Unsupported)),
                }
                let content = if !content.is_empty() {
                    content.join(",")
                } else if pool_type == "nfs" {
                    "backup,iso".to_owned()
                } else {
                    "images,rootdir".to_owned()
                };
                fields.push(("content", content));
                if let Some(node) = node {
                    fields.push(("nodes", node.clone()));
                }
                self.call(Method::Post, "/storage", Some(body(&fields)), true).await?;
            }
            Change::PoolSetActive { active, .. } => {
                let p = pool.expect("resolved");
                let disable = if *active { "0" } else { "1" };
                self.call(Method::Put, &format!("/storage/{}", seg(&p.name)), Some(body(&[("disable", disable.into())])), true).await?;
            }
            Change::PoolDelete { .. } => {
                let p = pool.expect("resolved");
                self.call(Method::Delete, &format!("/storage/{}", seg(&p.name)), None, true).await?;
            }
            // PVE reads a storage's contents on every listing.
            Change::PoolRefresh { .. } => {}
            Change::VolumeCreate { name, gib, format, .. } => {
                let p = pool.expect("resolved");
                let vmid = resource::pve_volume_vmid(name).unwrap_or_default();
                let fields = [
                    ("vmid", vmid.to_string()),
                    ("filename", resource::volume_file_name(p, name, format)),
                    ("size", format!("{gib}G")),
                    ("format", format.clone()),
                ];
                self.call(Method::Post, &format!("{}/content", storage_path(p)?), Some(body(&fields)), true).await?;
            }
            Change::VolumeDelete { volume, .. } => {
                let p = pool.expect("resolved");
                let path = format!("{}/content/{}", storage_path(p)?, seg(volume));
                self.node_task(p.node.as_deref().unwrap_or_default(), Method::Delete, &path, None).await?;
            }
            Change::NetworkCreate { name, node, bridge, cidr, vlan_aware, autostart, .. } => {
                let node = node.as_deref().unwrap_or_default();
                let mut fields: Vec<(&str, String)> = vec![
                    ("iface", name.clone()),
                    ("type", "bridge".into()),
                    ("autostart", if *autostart { "1" } else { "0" }.into()),
                ];
                if let Some(ports) = bridge.as_deref().map(str::trim).filter(|p| !p.is_empty()) {
                    fields.push(("bridge_ports", ports.to_owned()));
                }
                if let Some(cidr) = cidr.as_deref().map(str::trim).filter(|c| !c.is_empty()) {
                    fields.push(("cidr", cidr.to_owned()));
                }
                if *vlan_aware {
                    fields.push(("bridge_vlan_aware", "1".into()));
                }
                self.call(Method::Post, &format!("/nodes/{}/network", seg(node)), Some(body(&fields)), true).await?;
            }
            Change::NetworkEditBridge { ports, cidr, gateway, vlan_aware, autostart, .. } => {
                let n = network.expect("resolved");
                self.edit_bridge(n, ports.as_deref(), cidr.as_deref(), gateway.as_deref(), *vlan_aware, *autostart).await?;
            }
            Change::NetworkDelete { .. } => {
                let n = network.expect("resolved");
                let node = n.node.as_deref().unwrap_or_default();
                self.call(Method::Delete, &format!("/nodes/{}/network/{}", seg(node), seg(&n.name)), None, true).await?;
            }
            Change::NetworkApply { node } => {
                self.check_apply(node, live).await?;
                self.node_task(node, Method::Put, &format!("/nodes/{}/network", seg(node)), None).await?;
            }
            Change::NetworkRevert { node } => {
                self.call(Method::Delete, &format!("/nodes/{}/network", seg(node)), None, true).await?;
            }
            // Refused by `resource::issue` above: libvirt's.
            Change::PoolSetAutostart { .. }
            | Change::VolumeResize { .. }
            | Change::VolumeClone { .. }
            | Change::NetworkEdit { .. }
            | Change::NetworkRestart { .. }
            | Change::NetworkSetActive { .. }
            | Change::NetworkSetAutostart { .. } => return Err(resource::refusal(Issue::Unsupported)),
        }
        Ok(())
    }

    /// PVE's `update_network` sets the interface's `method`/`method6` and
    /// its address families from this request alone (`$param->{method} =
    /// $param->{address} ? 'static' : 'manual'`, pve-manager 9.2.2): an
    /// address not sent is an address dropped. So the ones it has now go
    /// back with it — the IPv4 one unless this edit changes it, and the IPv6
    /// one, which the form does not edit. Read fresh: a listing may be a
    /// while old.
    async fn edit_bridge(
        &self,
        network: &Network,
        ports: Option<&str>,
        cidr: Option<&str>,
        gateway: Option<&str>,
        vlan_aware: Option<bool>,
        autostart: Option<bool>,
    ) -> Result<()> {
        let node = network.node.as_deref().unwrap_or_default();
        let path = format!("/nodes/{}/network/{}", seg(node), seg(&network.name));
        let now = self.call(Method::Get, &path, None, false).await?;
        let current = |key: &str| {
            now.get(key)
                .map(|v| v.as_str().map(str::to_owned).unwrap_or_else(|| v.to_string()))
                .map(|t| t.trim().to_owned())
                .filter(|t| !t.is_empty() && t != "null")
        };
        let address = cidr.map(str::trim);
        let cidr4 = address.map(str::to_owned).or_else(|| current("cidr"));
        let cidr6 = current("cidr6");
        let gw = gateway.map(str::trim);
        // Everything else PVE keeps, and a `0` is not sent: turning something
        // off means naming the key in `delete`.
        let mut delete = Vec::new();
        if address == Some("") {
            delete.push("cidr,gateway");
        }
        // VLAN awareness is a pair of properties: PVE's own editor clears
        // the allowed-VLAN list with it (`bridge_vids` is what writes the
        // `bridge-vids` line, and pvesh drops a bare `0`).
        if vlan_aware == Some(false) {
            delete.push("bridge_vlan_aware,bridge_vids");
        }
        let mut fields: Vec<(&str, String)> = vec![("type", network.mode.clone())];
        if let Some(p) = ports {
            fields.push(("bridge_ports", p.trim().to_owned()));
        }
        if let Some(c) = cidr4.filter(|c| !c.is_empty()) {
            fields.push(("cidr", c));
        }
        if let Some(c) = cidr6 {
            fields.push(("cidr6", c));
        }
        if let Some(g) = gw.filter(|g| !g.is_empty()) {
            fields.push(("gateway", g.to_owned()));
        }
        if vlan_aware == Some(true) {
            fields.push(("bridge_vlan_aware", "1".into()));
        }
        if let Some(on) = autostart {
            fields.push(("autostart", if on { "1" } else { "0" }.into()));
        }
        if !delete.is_empty() {
            fields.push(("delete", delete.join(",")));
        }
        self.call(Method::Put, &path, Some(body(&fields)), true).await?;
        Ok(())
    }

    /// Refuses applying `node`'s pending network configuration when it
    /// touches a management interface — made by a client or anywhere else,
    /// PVE's web UI included — or when the diff does not say whose lines it
    /// changes. Read fresh: an apply is the moment it matters.
    async fn check_apply(&self, node: &str, live: Option<&LiveNet>) -> Result<()> {
        let body = self.call_with(Method::Get, &format!("/nodes/{}/network", seg(node)), None, false, true).await?;
        let Some(diff) = body.get("changes").and_then(Value::as_str).filter(|d| !d.trim().is_empty()) else {
            return Ok(());
        };
        let live = live.filter(|l| l.host == node);
        let touched = net::diff_ifaces(diff, live.map(|l| l.interfaces.as_str()));
        // The listing is the pending configuration: an interface it no longer
        // gives a gateway — or, without the node's own word on what it uses,
        // an address — may be the one the node is managed through until this
        // is applied.
        let mut also = touched.old_gateways.clone();
        if live.is_none() {
            also.extend(touched.old_addressed.iter().cloned());
        }
        let listing = body.get("data").and_then(Value::as_array).cloned().unwrap_or_default();
        let management = management(node, &listing, live, &also);
        let hit: Vec<String> = touched.ifaces.intersection(&management).cloned().collect();
        if !hit.is_empty() {
            return Err(Error::detail(ErrorKind::Unsupported, Detail::ApplyTouchesManagement { ifaces: hit }));
        }
        if touched.unknown {
            return Err(Error::detail(ErrorKind::Unsupported, Detail::ApplyUnreadable));
        }
        Ok(())
    }

    /// `request` on `node`, which answers a UPID or, for a change PVE makes
    /// at once, nothing; the task waited for.
    async fn node_task(&self, node: &str, method: Method, path: &str, body: Option<Body>) -> Result<()> {
        let upid = self.call(method, path, body, true).await?;
        if let Some(upid) = upid.as_str().filter(|u| u.starts_with("UPID:")) {
            self.wait_task(node, upid).await?;
        }
        Ok(())
    }

    /// A name taken as [`ErrorKind::Exists`]; a stale digest as
    /// [`ErrorKind::Conflict`]; PVE's permission refusal as
    /// [`ErrorKind::PermissionDenied`] naming the privilege, where, and the
    /// `pveum` line that grants it — the refusal alone says which, not what
    /// to type.
    fn manage_err(&self, e: Error) -> Error {
        let message = e.message.clone().unwrap_or_default();
        if message.contains("already exists") || message.contains("already defined") {
            return Error { kind: ErrorKind::Exists, ..e };
        }
        if message.contains("checksum mismatch") || message.contains("file change by other user") {
            return Error { kind: ErrorKind::Conflict, ..e };
        }
        let Some((path, privilege)) = permission_check(&message) else { return e };
        let (token, account) = self.config().account();
        let who = format!("--{} '{account}'", if token { "tokens" } else { "users" });
        let command = match privilege_role(&privilege) {
            Some(role) => format!("pveum acl modify {path} {who} --roles {role}"),
            // No built-in role holds it without far more: a role of its own.
            None => {
                let role = format!("ServerBox-{}", privilege.replace('.', ""));
                format!("pveum role add {role} --privs {privilege}\npveum acl modify {path} {who} --roles {role}")
            }
        };
        let mut out = Error::detail(ErrorKind::PermissionDenied, Detail::NeedsPrivilege { account, privilege, path, command });
        out.message = e.message;
        out.status = e.status;
        out
    }
}

fn body(fields: &[(&str, String)]) -> Body {
    let pairs: Vec<(&str, &str)> = fields.iter().map(|(k, v)| (*k, v.as_str())).collect();
    Body::form(form(&pairs))
}

/// `/nodes/{node}/storage/{storage}`.
fn storage_path(pool: &Pool) -> Result<String> {
    match &pool.node {
        Some(node) => Ok(format!("/nodes/{}/storage/{}", seg(node), seg(&pool.name))),
        None => Err(Error::msg(ErrorKind::InvalidResponse, format!("No node for storage {}", pool.name))),
    }
}

/// The interfaces carrying `node`'s management traffic
/// ([`net::management_ifaces`]), from its listing and — when `live` is that
/// node's — what the node itself says it is using.
fn management(node: &str, listing: &[Value], live: Option<&LiveNet>, also: &BTreeSet<String>) -> BTreeSet<String> {
    let networks = resources::parse_networks(node, listing, &BTreeMap::new(), &BTreeSet::new());
    let gateways6: BTreeSet<String> = listing
        .iter()
        .filter_map(Value::as_object)
        .filter(|e| e.get("gateway6").is_some_and(|g| !g.is_null() && g.as_str() != Some("")))
        .filter_map(|e| resources::str_of(e.get("iface")))
        .collect();
    net::management_ifaces(&networks, live.filter(|l| l.host == node), &gateways6, also)
}

/// `Permission check failed (/storage/local, Datastore.Allocate)` as the
/// path and the privilege.
fn permission_check(message: &str) -> Option<(String, String)> {
    let rest = &message[message.find("Permission check failed (")? + "Permission check failed (".len()..];
    let inner = &rest[..rest.find(')')?];
    let (path, privilege) = inner.split_once(", ")?;
    let path = path.trim();
    let ok = !path.is_empty() && !path.contains(['(', ',']) && !privilege.is_empty();
    (ok && privilege.chars().all(|c| c.is_ascii_alphabetic() || c == '.')).then(|| (path.to_owned(), privilege.to_owned()))
}

/// The narrowest built-in PVE role holding `privilege`; None where only
/// `Administrator` does (`Sys.Modify`).
pub fn privilege_role(privilege: &str) -> Option<&'static str> {
    match privilege {
        "Datastore.AllocateSpace" | "Datastore.Audit" => Some("PVEDatastoreUser"),
        "Datastore.Allocate" | "Datastore.AllocateTemplate" => Some("PVEDatastoreAdmin"),
        "Sys.Audit" => Some("PVEAuditor"),
        "SDN.Use" => Some("PVESDNUser"),
        p if p.starts_with("VM.") => Some("PVEVMAdmin"),
        _ => None,
    }
}
