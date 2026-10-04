//! Making, copying and deleting PVE guests.
//!
//! Each request is checked first against what the host lists at that
//! moment ([`crate::create`]'s rules), so a refusal is said before a task
//! is started rather than in its log.

use std::collections::{BTreeMap, BTreeSet};

use serde_json::Value;

use super::{Client, guest_path};
use crate::create::{self, CloneListing, CloneRequest, CreateListing, CreateOptions, CreateSpec, Created, Issue};
use crate::error::{Detail, Error, ErrorKind, Result};
use crate::model::{Guest, GuestKind, HostKind, Node};
use crate::pve::create::{Resolved, create_body, disk_key};
use crate::pve::http::{Body, Method};
use crate::pve::{form, resources, seg, version_less_than};
use crate::resource::{Network, Pool, Volume};

/// The first release with the `import` content type, where a cloud image is
/// kept for `import-from`.
pub const IMPORT_CONTENT_SINCE: [u32; 2] = [8, 2];

impl Client {
    /// The cluster's next free VMID (`/cluster/nextid`).
    pub async fn next_vmid(&self) -> Result<u32> {
        match self.call(Method::Get, "/cluster/nextid", None, false).await? {
            Value::Number(n) => n.as_u64().and_then(|n| u32::try_from(n).ok()),
            Value::String(s) => s.parse().ok(),
            _ => None,
        }
        .ok_or_else(|| Error::detail(ErrorKind::InvalidResponse, Detail::InvalidData))
    }

    /// PVE's fixed set: OVMF and swtpm ship with it, cloud-init is its own
    /// drive. Cloud images wait for a release with `import` content (an
    /// unknown release is given the benefit of the doubt: its storages say
    /// whether they hold any).
    pub fn create_options(&self) -> CreateOptions {
        let owned = |l: &[&str]| l.iter().map(|s| (*s).to_owned()).collect();
        CreateOptions {
            buses: owned(create::PVE_BUSES),
            nic_models: owned(create::NIC_MODELS),
            uefi: true,
            // Every 4m EFI disk runs PVE's `OVMF_CODE_4M.secboot.fd`; what
            // turns Secure Boot on is the variables template with the keys
            // enrolled (`pre-enrolled-keys=1`, `PVE::QemuServer::OVMF`,
            // 9.2.2).
            secure_boot: true,
            tpm: true,
            cloud_images: self.release().is_none_or(|r| !version_less_than(&r, &IMPORT_CONTENT_SINCE)),
            cloud_init: true,
            cloud_init_missing: None,
        }
    }

    /// `guest` as the host lists it now: what a delete, a template or a
    /// clone is checked against, rather than the caller's copy of it.
    pub(super) async fn fresh(&self, guest: &Guest) -> Result<(Guest, Vec<Guest>, Vec<Node>)> {
        let (guests, nodes) = self.guests_and_nodes().await?;
        let now = guests.iter().find(|g| g.id == guest.id).cloned().ok_or_else(|| create::refusal(Issue::NotFound))?;
        Ok((now, guests, nodes))
    }

    /// The guests and nodes, each guest's name, state and template flag as
    /// its node says them now. `/cluster/resources` is the cluster's cache:
    /// for a few seconds after a clone it lists the copy as `VM <vmid>`,
    /// which a name check made then would let a second copy of one name
    /// through. Each online node's own listing (`/nodes/{node}/qemu`,
    /// `/lxc`) reads the configurations; one that fails fails the read,
    /// rather than leaving the cache to be checked against.
    async fn guests_and_nodes(&self) -> Result<(Vec<Guest>, Vec<Node>)> {
        let Value::Array(list) = self.call(Method::Get, "/cluster/resources", None, false).await? else {
            return Err(Error::detail(ErrorKind::InvalidResponse, Detail::InvalidData));
        };
        let parsed = resources::parse(&list, self.now());
        let mut guests = parsed.guests;
        for node in parsed.nodes.iter().filter(|n| n.online) {
            for kind in [GuestKind::Qemu, GuestKind::Lxc] {
                let path = format!("/nodes/{}/{}", seg(&node.name), kind.as_str());
                let Value::Array(own) = self.call(Method::Get, &path, None, false).await? else { continue };
                for e in own.iter().filter_map(Value::as_object) {
                    let Some(vmid) = resources::uint(e.get("vmid")).and_then(|v| u32::try_from(v).ok()) else { continue };
                    let Some(g) = guests.iter_mut().find(|g| g.vmid == Some(vmid) && g.kind == kind) else { continue };
                    if let Some(name) = resources::str_of(e.get("name")) {
                        g.name = name;
                    }
                    if let Some(status) = e.get("status").and_then(Value::as_str) {
                        g.state = resources::state_of(Some(status), e.get("lock").and_then(Value::as_str));
                    }
                    g.template = resources::uint(e.get("template")) == Some(1);
                }
            }
        }
        Ok((guests, parsed.nodes))
    }

    /// `node`'s interfaces, without who uses them: what a new NIC is checked
    /// against.
    pub(super) async fn node_networks(&self, node: &str) -> Result<Vec<Network>> {
        match self.call(Method::Get, &format!("/nodes/{}/network", seg(node)), None, false).await? {
            Value::Array(raw) => Ok(resources::parse_networks(node, &raw, &BTreeMap::new(), &BTreeSet::new())),
            _ => Ok(Vec::new()),
        }
    }

    /// The volume `r` names, from its pool's listing; None where either is
    /// gone.
    pub(super) async fn volume_at(&self, pools: &[Pool], r: &create::VolumeRef) -> Result<Option<Volume>> {
        let Some(pool) = pools.iter().find(|p| p.id == r.pool) else { return Ok(None) };
        Ok(self.volumes(pool).await?.into_iter().find(|v| v.id == r.volume))
    }

    /// What a form offers a new `kind` guest on `node`.
    pub async fn create_form(&self, kind: GuestKind, node: &str) -> Result<create::CreateForm> {
        let pools = self.storage_pools().await?;
        let networks = self.node_networks(node).await?;
        let options = self.create_options();
        let mut volumes = Vec::new();
        for pool in create::form_pools(&pools, HostKind::Pve, kind, Some(node), &options) {
            volumes.push((pool.id.clone(), self.volumes(pool).await?));
        }
        let next_vmid = self.next_vmid().await.ok();
        Ok(create::create_form(kind, HostKind::Pve, Some(node), options, next_vmid, &pools, &networks, &volumes))
    }

    /// `POST /nodes/{node}/qemu` or `/lxc`, waited for; then `start` as a
    /// request of its own rather than the create's `start=1`, so a guest
    /// that was created and did not start is told apart from one that was
    /// not created.
    ///
    /// A cloud image is imported at its own size, which the configuration
    /// then says (`size=`), and grown to the size asked for before a first
    /// boot lays its filesystem out — and only grown: a request below the
    /// image keeps the image's size, as PVE cannot shrink a disk and cutting
    /// one would cut its system.
    pub async fn create(&self, spec: &CreateSpec) -> Result<Created> {
        self.create_now(spec).await.map_err(|e| self.manage_err(e))
    }

    async fn create_now(&self, spec: &CreateSpec) -> Result<Created> {
        let (guests, nodes) = self.guests_and_nodes().await?;
        let node = spec.node.clone().ok_or_else(|| create::refusal(Issue::Node))?;
        let pools = self.storage_pools().await?;
        let networks = self.node_networks(&node).await?;
        let media = match &spec.media {
            Some(r) => self.volume_at(&pools, r).await?,
            None => None,
        };
        let image = match &spec.image {
            Some(r) => self.volume_at(&pools, r).await?,
            None => None,
        };
        let options = self.create_options();
        let list = CreateListing {
            guests: &guests,
            nodes: &nodes,
            pools: &pools,
            networks: &networks,
            media: media.as_ref(),
            image: image.as_ref(),
            options: &options,
        };
        if let Some(issue) = create::create_issue(spec, HostKind::Pve, list) {
            return Err(create::refusal(issue));
        }
        let vmid = match spec.vmid {
            Some(v) => v,
            None => self.next_vmid().await?,
        };
        let storage = pools.iter().find(|p| p.id == spec.storage).map(|p| p.name.as_str()).unwrap_or_default();
        let bridge = spec.network.as_ref().and_then(|id| networks.iter().find(|n| &n.id == id)).map(|n| n.name.as_str());
        let resolved = Resolved {
            storage,
            bridge,
            media: media.as_ref().map(|v| v.id.as_str()),
            image: image.as_ref().map(|v| v.id.as_str()),
        };
        let fields = create_body(spec, vmid, resolved);
        let kind = spec.kind.as_str();
        let base = format!("/nodes/{}/{kind}", seg(&node));
        self.node_task(&node, Method::Post, &base, Some(body(&fields))).await?;
        let path = format!("{base}/{vmid}");
        let id = format!("{kind}/{vmid}");
        let mut kept = None;
        if spec.image.is_some() {
            let want = spec.disk_gib << 30;
            let disk = disk_key(spec);
            let size = match self.call(Method::Get, &format!("{path}/config"), None, false).await {
                Ok(config) => config.get(disk).and_then(Value::as_str).and_then(resources::option_size),
                Err(_) => None,
            };
            kept = size.filter(|s| *s > want);
            if size.is_none_or(|s| s < want) {
                let resize = body(&[("disk", disk.to_owned()), ("size", format!("{}G", spec.disk_gib))]);
                if let Err(e) = self.node_task(&node, Method::Put, &format!("{path}/resize"), Some(resize)).await {
                    // Created all the same; not started on a disk of the
                    // wrong size.
                    return Ok(Created { id, start_error: Some(start_error(&e)), disk_kept_bytes: kept });
                }
            }
        }
        let mut start = None;
        if spec.start
            && let Err(e) = self.node_task(&node, Method::Post, &format!("{path}/status/start"), Some(Body::form(String::new()))).await
        {
            start = Some(start_error(&e));
        }
        Ok(Created { id, start_error: start, disk_kept_bytes: kept })
    }

    /// `DELETE` with `purge=1` (out of backup jobs, replication and HA) and
    /// `destroy-unreferenced-disks=1` (volumes of its VMID no configuration
    /// names). PVE deletes a guest's own disks whatever is asked: they
    /// cannot be kept here ([`crate::model::Capabilities::delete_keeps_disks`]).
    pub async fn delete(&self, guest: &Guest) -> Result<()> {
        let (guest, _, _) = self.fresh(guest).await?;
        let guest = &guest;
        if let Some(issue) = create::delete_issue(guest) {
            return Err(create::refusal(issue));
        }
        let path = format!("{}?purge=1&destroy-unreferenced-disks=1", guest_path(guest)?);
        self.task(guest, Method::Delete, &path, None).await.map_err(|e| self.manage_err(e))
    }

    /// `POST .../template` on the guest's node, waited for (`VM.Allocate`
    /// on `/vms/{vmid}`, checked by PVE before the task). A guest with
    /// snapshots cannot become one, and a template cannot become a guest
    /// again: PVE writes `template: 1` and turns every disk into a base
    /// image (`vm-910-disk-0` → `base-910-disk-0` on LVM-thin), which is
    /// what a linked clone then shares.
    pub async fn make_template(&self, guest: &Guest) -> Result<()> {
        let (guest, _, _) = self.fresh(guest).await?;
        let guest = &guest;
        if let Some(issue) = create::template_issue(guest, HostKind::Pve) {
            return Err(create::refusal(issue));
        }
        let path = format!("{}/template", guest_path(guest)?);
        self.task(guest, Method::Post, &path, Some(Body::form(String::new()))).await.map_err(|e| self.manage_err(e))
    }

    /// `POST .../clone` on the guest's node, waited for; the copy's id. A
    /// full clone copies the disks to the storages they are on, or to the
    /// one asked for; a linked one (a template only — PVE refuses it for
    /// anything else) shares them. A clone that moves to another node needs
    /// a cluster and shared storage ([`create::clone_issue`]).
    pub async fn clone_guest(&self, guest: &Guest, request: &CloneRequest) -> Result<String> {
        let (guest, guests, nodes) = self.fresh(guest).await?;
        let guest = &guest;
        let pools = self.storage_pools().await?;
        if let Some(issue) = create::clone_issue(guest, request, HostKind::Pve, CloneListing { guests: &guests, nodes: &nodes, pools: &pools }) {
            return Err(create::refusal(issue));
        }
        let vmid = match request.vmid {
            Some(v) => v,
            None => self.next_vmid().await?,
        };
        let full = create::clone_full(guest, request, HostKind::Pve);
        let mut fields = vec![
            ("newid", vmid.to_string()),
            (if guest.kind == GuestKind::Lxc { "hostname" } else { "name" }, request.name.clone()),
            ("full", if full { "1" } else { "0" }.to_owned()),
        ];
        // PVE refuses either on a linked clone: `parameter 'storage' not
        // allowed for linked clones`.
        if let Some(s) = request.storage.as_ref().filter(|_| full) {
            fields.push(("storage", s.clone()));
        }
        if let Some(n) = &request.target_node {
            fields.push(("target", n.clone()));
        }
        let path = format!("{}/clone", guest_path(guest)?);
        self.task(guest, Method::Post, &path, Some(body(&fields))).await.map_err(|e| self.manage_err(e))?;
        Ok(format!("{}/{vmid}", guest.kind.as_str()))
    }
}

fn body(fields: &[(&str, String)]) -> Body {
    let pairs: Vec<(&str, &str)> = fields.iter().map(|(k, v)| (*k, v.as_str())).collect();
    Body::form(form(&pairs))
}

/// A failed step after the guest was made, in the host's words.
fn start_error(e: &Error) -> String {
    e.message.clone().unwrap_or_else(|| format!("{:?}", e.kind))
}
