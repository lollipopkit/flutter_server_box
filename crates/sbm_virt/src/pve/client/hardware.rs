//! A PVE guest's hardware, settings, cloud-init and the host devices it can
//! be given.
//!
//! Every change is `.../config` with the `digest` the caller's read carries,
//! so PVE refuses one made from a configuration someone changed since
//! ("checksum mismatch", [`crate::error::ErrorKind::Conflict`]), except a
//! disk's growth, which is `.../resize` with the same digest. A VM's
//! configuration is set with `POST` (a task: adding a disk allocates it), a
//! container's with `PUT`. What the running guest cannot take PVE puts in
//! `pending`: a change returns once the request has, and the next read
//! shows it.

use futures_util::future::join;
use serde_json::{Map, Value};

use super::{Client, guest_path};
use crate::create::VolumeRef;
use crate::error::{Detail, Error, ErrorKind, Result};
use crate::hardware::{self, Change, CloudInitEdit, CloudInitState, DeviceKind, DiskKind, Hardware, HostDevices, Issue, Limits, Listing, Outcome, UsbNaming};
use crate::model::{Guest, GuestKind, HostKind};
use crate::pve::hardware::{bus_slots, cloud_init_fields, free_key, host_devices, on_bus, parse_cloud_init, parse_hardware, size_arg, with_cpu_type, with_nic_hardware, with_options};
use crate::pve::http::{Body, Method};
use crate::pve::resources::{options, volume_of};
use crate::pve::{Auth, form, seg};
use crate::resource::{Pool, Volume};

impl Client {
    async fn config_map(&self, path: &str) -> Result<Map<String, Value>> {
        match self.call(Method::Get, &format!("{path}/config"), None, false).await? {
            Value::Object(m) => Ok(m),
            _ => Err(Error::detail(ErrorKind::InvalidResponse, Detail::InvalidData)),
        }
    }

    /// A node figure the hardware view shows beside the guest's: a token
    /// without `Sys.Audit` on the node still edits the guest.
    async fn node_extra(&self, path: &str) -> Option<Value> {
        self.call(Method::Get, path, None, false).await.ok()
    }

    /// `guest`'s hardware as it stands, read with the guest's state now.
    pub async fn hardware(&self, guest: &Guest) -> Result<Hardware> {
        let (guest, _, _) = self.fresh(guest).await?;
        self.hardware_of(&guest).await
    }

    async fn hardware_of(&self, guest: &Guest) -> Result<Hardware> {
        let path = guest_path(guest)?;
        let node = seg(guest.node.as_deref().unwrap_or_default());
        let config = self.config_map(&path).await?;
        let Value::Array(pending) = self.call(Method::Get, &format!("{path}/pending"), None, false).await? else {
            return Err(Error::detail(ErrorKind::InvalidResponse, Detail::InvalidData));
        };
        let qemu = guest.kind == GuestKind::Qemu;
        let (status, cpus) = join(self.node_extra(&format!("/nodes/{node}/status")), async {
            if qemu { self.node_extra(&format!("/nodes/{node}/capabilities/qemu/cpu")).await } else { None }
        })
        .await;
        let figure = |section: &str, key: &str| status.as_ref().and_then(|s| s.get(section)).and_then(|s| s.get(key)).and_then(Value::as_u64);
        let mut cpu_types: Vec<String> = cpus
            .as_ref()
            .and_then(Value::as_array)
            .map(|l| l.iter().filter_map(|c| c.get("name").and_then(Value::as_str).map(str::to_owned)).collect())
            .unwrap_or_default();
        cpu_types.sort();
        let limits = Limits { host_cpus: figure("cpuinfo", "cpus").map(|c| c as u32), host_memory_bytes: figure("memory", "total") };
        Ok(parse_hardware(&config, &pending, guest.kind, guest.state.is_active(), limits, cpu_types))
    }

    /// What a change to `guest` on its node is checked against: the node's
    /// storages and bridges, and the volumes `change` names.
    async fn hw_listing(&self, guest: &Guest, change: &Change) -> Result<(Vec<Pool>, Vec<crate::resource::Network>, Vec<Volume>)> {
        let node = guest.node.clone().unwrap_or_default();
        let pools: Vec<Pool> = self.storage_pools().await?.into_iter().filter(|p| p.node.as_deref() == Some(node.as_str())).collect();
        let networks = match change {
            Change::AddNic { .. } | Change::UpdateNic { .. } => self.node_networks(&node).await?,
            _ => Vec::new(),
        };
        let named: Option<&VolumeRef> = match change {
            Change::AttachVolume { volume, .. } => Some(volume),
            Change::AddCdrom { media } | Change::SetMedia { media, .. } => media.as_ref(),
            _ => None,
        };
        let volumes = match named {
            Some(r) => self.volume_at(&pools, r).await?.into_iter().collect(),
            None => Vec::new(),
        };
        Ok((pools, networks, volumes))
    }

    /// Makes `change` to `guest`, from the read whose digest is `revision`,
    /// checked first against the guest and its node as they are now
    /// ([`hardware::issue`]).
    pub async fn change_hardware(&self, guest: &Guest, revision: Option<&str>, change: &Change) -> Result<Outcome> {
        let (guest, _, _) = self.fresh(guest).await?;
        let base = self.hardware_of(&guest).await?;
        let (pools, networks, volumes) = self.hw_listing(&guest, change).await?;
        let list = Listing { pools: &pools, networks: &networks, volumes: &volumes };
        if let Some(issue) = hardware::issue(&base, change, HostKind::Pve, list) {
            return Err(hardware::refusal(issue));
        }
        self.change_now(&guest, &base, revision, change, list).await.map_err(|e| self.manage_err(e))
    }

    async fn change_now(&self, guest: &Guest, base: &Hardware, digest: Option<&str>, change: &Change, list: Listing<'_>) -> Result<Outcome> {
        let path = guest_path(guest)?;
        let lxc = guest.kind == GuestKind::Lxc;
        let config = self.config_map(&path).await?;
        let raw = |k: &str| config.get(k).and_then(Value::as_str).map(str::to_owned);
        let gone = |k: &str| Error::msg(ErrorKind::Conflict, format!("{k} is gone"));
        let first_bus = || base.disks.iter().find(|d| d.kind == DiskKind::Disk).and_then(|d| d.bus.clone()).unwrap_or_else(|| "scsi".to_owned());
        let slot = |prefix: &str, slots: u32| free_key(&config, prefix, slots).ok_or_else(|| Error::msg(ErrorKind::Unsupported, format!("No free {prefix} slot")));
        let set = |fields: Vec<(String, String)>, delete: Vec<String>| self.set_config(guest, fields, delete, digest);
        let kv = |k: &str, v: String| vec![(k.to_owned(), v)];
        match change {
            Change::SetCpu { sockets, cores, online, cpu_type } => {
                if lxc {
                    set(kv("cores", cores.to_string()), Vec::new()).await?;
                } else {
                    let mut f = vec![("sockets".to_owned(), sockets.to_string()), ("cores".to_owned(), cores.to_string())];
                    if let Some(o) = online {
                        f.push(("vcpus".to_owned(), o.to_string()));
                    }
                    if let Some(t) = cpu_type.as_ref().filter(|t| base.cpu.cpu_type.as_ref() != Some(*t)) {
                        f.push(("cpu".to_owned(), with_cpu_type(raw("cpu").as_deref(), t)));
                    }
                    let delete = if online.is_none() && base.cpu.online.is_some() { vec!["vcpus".to_owned()] } else { Vec::new() };
                    set(f, delete).await?;
                }
            }
            Change::SetMemory { mib, min_mib, swap_mib } => {
                let mut f = kv("memory", mib.to_string());
                let mut delete = Vec::new();
                if lxc {
                    if let Some(s) = swap_mib {
                        f.push(("swap".to_owned(), s.to_string()));
                    }
                } else if let Some(m) = min_mib {
                    f.push(("balloon".to_owned(), m.to_string()));
                } else if base.memory.min_mib.is_some() {
                    delete.push("balloon".to_owned());
                }
                set(f, delete).await?;
            }
            Change::GrowDisk { key, bytes } => {
                let mut f = vec![("disk", key.clone()), ("size", size_arg(*bytes))];
                if let Some(d) = digest {
                    f.push(("digest", d.to_owned()));
                }
                let pairs: Vec<(&str, &str)> = f.iter().map(|(k, v)| (*k, v.as_str())).collect();
                self.task(guest, Method::Put, &format!("{path}/resize"), Some(Body::form(form(&pairs)))).await?;
            }
            Change::AddDisk { pool, gib, mount_point } => {
                let storage = &list.pool(pool).expect("checked").name;
                let (key, value) = if lxc {
                    (slot("mp", 256)?, format!("{storage}:{gib},mp={}", mount_point.as_deref().unwrap_or_default()))
                } else {
                    // On the bus the guest's first disk is on: the controller
                    // it has, and the drivers its OS loads already.
                    let bus = first_bus();
                    (slot(&bus, bus_slots(&bus))?, format!("{storage}:{gib}"))
                };
                set(kv(&key, value), Vec::new()).await?;
            }
            Change::AttachVolume { volume, mount_point } => {
                let id = &list.volume(volume).expect("checked").id;
                let (key, value) = if lxc {
                    (slot("mp", 256)?, format!("{id},mp={}", mount_point.as_deref().unwrap_or_default()))
                } else {
                    let bus = first_bus();
                    (slot(&bus, bus_slots(&bus))?, id.clone())
                };
                set(kv(&key, value), Vec::new()).await?;
            }
            Change::RemoveDisk { key, delete_volume } => {
                // A CD-ROM's image is somebody's media (and never becomes
                // `unusedN`): the drive goes, the image stays, as on libvirt.
                let media = base.disk(key).is_some_and(|d| d.kind == DiskKind::Cdrom);
                if !delete_volume || media {
                    set(Vec::new(), vec![key.clone()]).await?;
                } else if self.drop_volume(guest, key, digest).await? {
                    return Ok(Outcome { volume_kept: true, ..Outcome::default() });
                }
            }
            Change::AddCdrom { media } => {
                // IDE's secondary master first, as PVE's own create puts one;
                // then the rest of IDE, then SATA.
                let key = ["ide2", "ide0", "ide1", "ide3", "sata0", "sata1", "sata2", "sata3", "sata4", "sata5"]
                    .into_iter()
                    .find(|k| !config.contains_key(*k))
                    .ok_or_else(|| Error::msg(ErrorKind::Unsupported, "No free IDE or SATA slot for a CD-ROM"))?;
                set(kv(key, cdrom(media, list)), Vec::new()).await?;
            }
            Change::SetMedia { key, media } => set(kv(key, cdrom(media, list)), Vec::new()).await?,
            Change::AddNic { network, model } => {
                let bridge = &list.network(network).expect("checked").name;
                let key = slot("net", 32)?;
                let value = if lxc {
                    let names: Vec<&str> = base.nics.iter().filter_map(|n| n.name.as_deref()).collect();
                    let i = (0..).find(|i| !names.contains(&format!("eth{i}").as_str())).unwrap_or(0);
                    format!("name=eth{i},bridge={bridge},ip=dhcp")
                } else {
                    format!("{},bridge={bridge}", model.as_deref().unwrap_or("virtio"))
                };
                set(kv(&key, value), Vec::new()).await?;
            }
            Change::RemoveNic { key } => set(Vec::new(), vec![key.clone()]).await?,
            Change::UpdateNic { key, network, link_up, firewall } => {
                let current = raw(key).ok_or_else(|| gone(key))?;
                let mut opts = vec![("link_down", (!link_up).then(|| "1".to_owned()))];
                if let Some(n) = network {
                    opts.push(("bridge", Some(list.network(n).expect("checked").name.clone())));
                }
                if let Some(f) = firewall {
                    opts.push(("firewall", f.then(|| "1".to_owned())));
                }
                set(kv(key, with_options(&current, &opts)), Vec::new()).await?;
            }
            Change::SetBoot { order } => set(kv("boot", format!("order={}", order.join(";"))), Vec::new()).await?,
            Change::SetAutostart { on } => set(kv("onboot", u8::from(*on).to_string()), Vec::new()).await?,
            Change::SetName { name } => set(kv(if lxc { "hostname" } else { "name" }, name.clone()), Vec::new()).await?,
            Change::SetDescription { text } => {
                if text.is_empty() {
                    set(Vec::new(), vec!["description".to_owned()]).await?;
                } else {
                    set(kv("description", text.clone()), Vec::new()).await?;
                }
            }
            Change::SetProtection { on } => set(kv("protection", u8::from(*on).to_string()), Vec::new()).await?,
            Change::Revert { keys } => set(kv("revert", keys.join(",")), Vec::new()).await?,
            Change::UpdateDisk { key, bus, cache } => {
                let current = raw(key).ok_or_else(|| gone(key))?;
                let value = match cache {
                    Some(c) => with_options(&current, &[("cache", (c != "default").then(|| c.clone()))]),
                    None => current,
                };
                match bus.as_ref().filter(|b| !key.starts_with(b.as_str())) {
                    None => set(kv(key, value), Vec::new()).await?,
                    Some(bus) => {
                        // Another bus is another option for the same volume,
                        // set in the request that drops the old one, less what
                        // that bus does not take. PVE drops the old one from
                        // the boot order too; the new one goes in its place.
                        let to = slot(bus, bus_slots(bus))?;
                        let mut f = kv(&to, on_bus(&value, bus));
                        if let Some(order) = base.boot.as_ref().filter(|o| o.contains(key)) {
                            let order: Vec<&str> = order.iter().map(|k| if k == key { to.as_str() } else { k.as_str() }).collect();
                            f.push(("boot".to_owned(), format!("order={}", order.join(";"))));
                        }
                        set(f, vec![key.clone()]).await?;
                    }
                }
            }
            Change::SetNicHardware { key, model, mac } => {
                let current = raw(key).ok_or_else(|| gone(key))?;
                set(kv(key, with_nic_hardware(&current, lxc, model.as_deref(), mac.as_deref())), Vec::new()).await?;
            }
            Change::SetFirmware { uefi, secure_boot, storage } => {
                if !uefi {
                    // The EFI variables disk stays: switching back finds them.
                    set(kv("bios", "seabios".to_owned()), Vec::new()).await?;
                } else {
                    let efi = raw("efidisk0");
                    let keys = efi.as_deref().is_some_and(|e| options(e).contains(&("pre-enrolled-keys", "1")));
                    if efi.is_some() && keys == *secure_boot {
                        set(kv("bios", "ovmf".to_owned()), Vec::new()).await?;
                    } else {
                        // Keys are enrolled when the variables disk is made:
                        // turning Secure Boot on or off is a new one, and the
                        // old one goes.
                        let on = match storage {
                            Some(id) => list.pool(id).expect("checked").name.clone(),
                            None => efi
                                .as_deref()
                                .and_then(volume_of)
                                .and_then(|v| v.split_once(':').map(|(s, _)| s.to_owned()))
                                .ok_or_else(|| hardware::refusal(Issue::StorageMissing))?,
                        };
                        let mut at = digest;
                        if efi.is_some() {
                            self.drop_volume(guest, "efidisk0", at).await?;
                            at = None;
                        }
                        let f = vec![
                            ("bios".to_owned(), "ovmf".to_owned()),
                            ("efidisk0".to_owned(), format!("{on}:1,efitype=4m,pre-enrolled-keys={}", u8::from(*secure_boot))),
                        ];
                        self.set_config(guest, f, Vec::new(), at).await?;
                    }
                }
            }
            Change::SetDisplay { gpu, .. } => {
                if let Some(gpu) = gpu {
                    let memory = raw("vga").and_then(|v| options(&v).into_iter().find(|(k, _)| *k == "memory").map(|(_, m)| m.to_owned()));
                    let value = match memory.filter(|_| gpu != "none") {
                        Some(m) => format!("{gpu},memory={m}"),
                        None => gpu.clone(),
                    };
                    set(kv("vga", value), Vec::new()).await?;
                }
            }
            Change::AddDevice { kind, host, storage, usb_naming } => match kind {
                DeviceKind::Tpm => {
                    let on = &list.pool(storage.as_deref().unwrap_or_default()).expect("checked").name;
                    set(kv("tpmstate0", format!("{on}:1,version=v2.0")), Vec::new()).await?;
                }
                DeviceKind::Usb => {
                    let h = host.as_ref().expect("checked");
                    // By vendor and product, or by where it sits: PVE's own
                    // form of the address is `bus-port` (`host=1-1.2`), what
                    // its web UI writes and its mapping uses.
                    let value = if h.mapping {
                        format!("mapping={}", h.id)
                    } else if *usb_naming == UsbNaming::Address {
                        format!("host={}", h.usb_address(HostKind::Pve).expect("checked"))
                    } else {
                        format!("host={}", h.id)
                    };
                    set(kv(&slot("usb", 14)?, value), Vec::new()).await?;
                }
                DeviceKind::Pci => {
                    let h = host.as_ref().expect("checked");
                    let value = if h.mapping { format!("mapping={}", h.id) } else { h.id.clone() };
                    set(kv(&slot("hostpci", 16)?, value), Vec::new()).await?;
                }
            },
            Change::RemoveDevice { key } => {
                if key.starts_with("tpmstate") {
                    // The state is the TPM: removing it removes what it held.
                    self.drop_volume(guest, key, digest).await?;
                } else {
                    set(Vec::new(), vec![key.clone()]).await?;
                }
            }
        }
        Ok(Outcome::default())
    }

    /// Drops every pending change, item by item: PVE keeps no "write it
    /// all back".
    pub async fn revert_pending(&self, guest: &Guest, revision: Option<&str>) -> Result<()> {
        let (guest, _, _) = self.fresh(guest).await?;
        let base = self.hardware_of(&guest).await?;
        let keys: Vec<String> = base.pending.iter().map(|p| p.key.clone()).collect();
        if keys.is_empty() {
            return Ok(());
        }
        self.set_config(&guest, vec![("revert".to_owned(), keys.join(","))], Vec::new(), revision).await.map_err(|e| self.manage_err(e))
    }

    async fn set_config(&self, guest: &Guest, fields: Vec<(String, String)>, delete: Vec<String>, digest: Option<&str>) -> Result<()> {
        let mut pairs: Vec<(&str, &str)> = fields.iter().map(|(k, v)| (k.as_str(), v.as_str())).collect();
        let joined = delete.join(",");
        if !delete.is_empty() {
            pairs.push(("delete", &joined));
        }
        if let Some(d) = digest {
            pairs.push(("digest", d));
        }
        let path = format!("{}/config", guest_path(guest)?);
        let method = if guest.kind == GuestKind::Lxc { Method::Put } else { Method::Post };
        self.task(guest, method, &path, Some(Body::form(form(&pairs)))).await
    }

    /// Detaches `key` and deletes its volume: detached it is `unusedN`, and
    /// deleting that entry deletes it. True when the volume was kept: a
    /// running guest that cannot let go of it until it stops keeps it
    /// attached, and nothing is deleted.
    ///
    /// The entry is deleted with the digest of the configuration it was
    /// found in: another administrator reattaching the volume in between
    /// may reuse the slot for another volume, which is then refused.
    async fn drop_volume(&self, guest: &Guest, key: &str, digest: Option<&str>) -> Result<bool> {
        let path = guest_path(guest)?;
        let volume = self.config_map(&path).await?.get(key).and_then(Value::as_str).and_then(volume_of);
        self.set_config(guest, Vec::new(), vec![key.to_owned()], digest).await?;
        let Some(volume) = volume.filter(|v| v != "none") else { return Ok(false) };
        let after = self.config_map(&path).await?;
        let unused = after.iter().find(|(k, v)| k.starts_with("unused") && v.as_str().and_then(volume_of).as_deref() == Some(volume.as_str()));
        let Some((unused, _)) = unused else { return Ok(true) };
        let at = after.get("digest").and_then(Value::as_str);
        self.set_config(guest, Vec::new(), vec![unused.clone()], at).await?;
        Ok(false)
    }

    /// A VM's cloud-init options.
    pub async fn cloud_init(&self, guest: &Guest) -> Result<CloudInitState> {
        Ok(parse_cloud_init(&self.config_map(&guest_path(guest)?).await?))
    }

    /// The `ci*` options set with the digest `edit` was read with, then the
    /// cloud-init drive written again at once (`PUT .../cloudinit`): PVE
    /// otherwise writes it only when it starts the VM, so a reboot from
    /// inside would read the old one. The system takes it at its next boot:
    /// PVE's instance ID is a hash of the user and network data.
    pub async fn set_cloud_init(&self, guest: &Guest, edit: &CloudInitEdit) -> Result<()> {
        let path = guest_path(guest)?;
        let config = self.config_map(&path).await?;
        let state = parse_cloud_init(&config);
        if let Some(issue) = hardware::cloud_init_edit_issue(&state, edit, HostKind::Pve) {
            return Err(crate::create::refusal(issue));
        }
        let (fields, delete) = cloud_init_fields(edit, state.network, &config);
        let fields = fields.into_iter().map(|(k, v)| (k.to_owned(), v)).collect();
        let delete = delete.into_iter().map(str::to_owned).collect();
        let digest = Some(edit.revision.as_str()).filter(|r| !r.is_empty());
        let run = async {
            self.set_config(guest, fields, delete, digest).await?;
            self.call(Method::Put, &format!("{path}/cloudinit"), Some(Body::form(String::new())), true).await?;
            Ok(())
        };
        run.await.map_err(|e| self.manage_err(e))
    }

    /// Resource mappings, which any account with `Mapping.Use` can give a
    /// guest, and — for root@pam logged in with its password, the only one
    /// PVE lets set a raw device ("only root can set 'usb0' config for real
    /// devices") — the node's own devices.
    pub async fn host_devices(&self, guest: &Guest) -> Result<HostDevices> {
        let node = guest.node.clone().unwrap_or_default();
        let root = matches!(&self.config().auth, Auth::Password { user, .. } if user == "root" || user == "root@pam");
        let list = |path: String| async move {
            match self.call(Method::Get, &path, None, false).await {
                Ok(Value::Array(l)) => l,
                _ => Vec::new(),
            }
        };
        let n = seg(&node);
        let usb_maps = list("/cluster/mapping/usb".to_owned()).await;
        let pci_maps = list("/cluster/mapping/pci".to_owned()).await;
        let pci = list(format!("/nodes/{n}/hardware/pci")).await;
        let usb = if root { list(format!("/nodes/{n}/hardware/usb")).await } else { Vec::new() };
        Ok(host_devices(&node, &usb_maps, &pci_maps, &pci, &usb, root))
    }
}

/// A CD-ROM option holding `media`, or none.
fn cdrom(media: &Option<VolumeRef>, list: Listing<'_>) -> String {
    let id = media.as_ref().and_then(|r| list.volume(r)).map_or("none", |v| v.id.as_str());
    format!("{id},media=cdrom")
}
