//! The parameters a new PVE guest is created with
//! (`POST /nodes/{node}/qemu`, `/lxc`), from a [`CreateSpec`] whose pool,
//! volumes and network were resolved against the host's listings.

use crate::create::CreateSpec;
use crate::model::GuestKind;

/// What a spec's ids name on the node: the storage's id, the bridge, the
/// install media's or template's volid, the cloud image's.
#[derive(Debug, Clone, Copy)]
pub struct Resolved<'a> {
    pub storage: &'a str,
    pub bridge: Option<&'a str>,
    pub media: Option<&'a str>,
    pub image: Option<&'a str>,
}

/// The key of a new VM's disk: on the bus asked for ([`crate::create::PVE_BUSES`]),
/// or SCSI.
pub fn disk_key(spec: &CreateSpec) -> &'static str {
    match spec.bus.as_deref() {
        Some("virtio") => "virtio0",
        Some("sata") => "sata0",
        Some("ide") => "ide0",
        _ => "scsi0",
    }
}

/// `Uri.encodeComponent`, which PVE's web UI applies to `sshkeys`.
fn encode_component(s: &str) -> String {
    super::seg(s)
}

/// A container's parameters. Unprivileged unless asked otherwise, with DHCP
/// on its NIC; the password goes in the body only.
pub fn lxc_body(spec: &CreateSpec, vmid: u32, r: Resolved<'_>) -> Vec<(&'static str, String)> {
    let mut out = vec![
        ("vmid", vmid.to_string()),
        ("hostname", spec.name.clone()),
        ("ostemplate", r.media.unwrap_or_default().to_owned()),
        ("cores", spec.cores.to_string()),
        ("memory", spec.memory_mib.to_string()),
        ("rootfs", format!("{}:{}", r.storage, spec.disk_gib)),
        ("unprivileged", if spec.unprivileged { "1" } else { "0" }.to_owned()),
    ];
    if let Some(bridge) = r.bridge {
        out.push(("net0", format!("name=eth0,bridge={bridge},ip=dhcp")));
    }
    if let Some(p) = spec.password.as_deref().filter(|p| !p.is_empty()) {
        out.push(("password", p.to_owned()));
    }
    let keys: Vec<&str> = spec.ssh_keys.iter().map(|k| k.trim()).filter(|k| !k.is_empty()).collect();
    if !keys.is_empty() {
        out.push(("ssh-public-keys", keys.join("\n")));
    }
    out
}

/// A VM's parameters.
///
/// A serial port (`serial0: socket`), so its text console works before it
/// has a network, and the install media after its disk in the boot order. A
/// cloud image is its disk's `import-from` (PVE 8.2+ takes one from
/// `import` or `images` content), grown afterwards to the size asked for,
/// with PVE's own cloud-init drive; PVE stores the password's hash.
pub fn qemu_body(spec: &CreateSpec, vmid: u32, r: Resolved<'_>) -> Vec<(&'static str, String)> {
    let storage = r.storage;
    let disk = disk_key(spec);
    let bus = disk.trim_end_matches('0');
    // An I/O thread is for virtio-blk and virtio-scsi-single only; PVE
    // refuses it on SATA and IDE.
    let iothread = if matches!(bus, "scsi" | "virtio") { ",iothread=1" } else { "" };
    // The cloud-init drive where the image's kernel can read it: Debian's
    // cloud kernel has no IDE driver at all (PVE 9.2: cloud-init never ran
    // from `ide2`, and did from `scsi1`). SCSI beside a SCSI or virtio disk
    // (the virtio-scsi controller is there anyway), SATA beside SATA, IDE
    // only beside IDE.
    let ci_drive = match bus {
        "ide" => "ide2",
        "sata" => "sata1",
        _ => "scsi1",
    };
    let mut out: Vec<(&'static str, String)> = vec![
        ("vmid", vmid.to_string()),
        ("name", spec.name.clone()),
        ("cores", spec.cores.to_string()),
        ("memory", spec.memory_mib.to_string()),
        ("ostype", "l26".into()),
        ("scsihw", "virtio-scsi-single".into()),
    ];
    let disk_value = match r.image {
        Some(image) => format!("{storage}:0,import-from={image}{iothread}"),
        None => format!("{storage}:{}{iothread}", spec.disk_gib),
    };
    out.push((disk, disk_value));
    // The install media, or the cloud-init drive: never both.
    if let Some(iso) = r.media {
        out.push(("ide2", format!("{iso},media=cdrom")));
    } else if spec.cloud_init.is_some() {
        out.push((ci_drive, format!("{storage}:cloudinit")));
    }
    if let Some(bridge) = r.bridge {
        out.push(("net0", format!("{},bridge={bridge}", spec.nic_model.as_deref().unwrap_or("virtio"))));
    }
    out.push(("serial0", "socket".into()));
    let order = if r.media.is_some() { format!("{disk};ide2") } else { disk.to_owned() };
    out.push(("boot", format!("order={order}")));
    if spec.uefi {
        out.push(("bios", "ovmf".into()));
        // Keys are enrolled when the EFI disk is made: Secure Boot is the
        // disk with `pre-enrolled-keys=1`, which is what PVE's own UEFI
        // default writes.
        out.push(("efidisk0", format!("{storage}:1,efitype=4m,pre-enrolled-keys={}", u8::from(spec.secure_boot))));
    }
    if spec.tpm {
        out.push(("tpmstate0", format!("{storage}:1,version=v2.0")));
    }
    if let Some(ci) = &spec.cloud_init {
        out.push(("ciuser", ci.user.clone()));
        if let Some(p) = ci.password.as_deref().filter(|p| !p.is_empty()) {
            out.push(("cipassword", p.to_owned()));
        }
        let keys = ci.keys();
        if !keys.is_empty() {
            // PVE wants the keys URL-encoded, as its web UI sends them
            // (`encodeURIComponent`), inside the form's own encoding.
            out.push(("sshkeys", encode_component(&format!("{}\n", keys.join("\n")))));
        }
        let ip = match &ci.address {
            None => "ip=dhcp".to_owned(),
            Some(a) => match &ci.gateway {
                Some(gw) => format!("ip={a},gw={gw}"),
                None => format!("ip={a}"),
            },
        };
        out.push(("ipconfig0", ip));
        if !ci.dns.is_empty() {
            out.push(("nameserver", ci.dns.join(" ")));
        }
        if !ci.search_domains.is_empty() {
            out.push(("searchdomain", ci.search_domains.join(" ")));
        }
    }
    out
}

/// The parameters for `spec` of either kind.
pub fn create_body(spec: &CreateSpec, vmid: u32, r: Resolved<'_>) -> Vec<(&'static str, String)> {
    match spec.kind {
        GuestKind::Lxc => lxc_body(spec, vmid, r),
        GuestKind::Qemu => qemu_body(spec, vmid, r),
    }
}
