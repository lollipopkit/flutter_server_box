//! Snapshots, for either backend: what one is, the chain an external one
//! leaves a disk on, how a snapshot differs from the guest now, and the rules
//! a client checks before it asks (a name, the memory).
//!
//! Ported from the app's `lib/data/model/virt/virt_resources.dart`.

use serde::{Deserialize, Serialize};

use crate::model::{Capabilities, Guest, GuestKind, GuestState};

/// One snapshot of a guest.
#[derive(Debug, Clone, Default, PartialEq, Eq, Serialize, Deserialize)]
pub struct Snapshot {
    pub name: String,
    /// The snapshot this one was taken on top of; None for a root.
    pub parent: Option<String>,
    pub description: Option<String>,
    /// Unix seconds.
    pub created_at: Option<i64>,
    /// What the guest's disks were last created from or reverted to: the
    /// parent a new snapshot would have.
    pub current: bool,
    /// Holds the guest's memory: reverting resumes it where it was.
    pub with_memory: bool,
    /// Kept outside the disk image: the guest was left on a qcow2 overlay.
    pub external: bool,
    /// Which file each disk was left on, for an external one.
    pub layers: Vec<SnapshotLayer>,
}

#[derive(Debug, Clone, Default, PartialEq, Eq, Serialize, Deserialize)]
pub struct SnapshotLayer {
    pub target: String,
    pub file: Option<String>,
    pub external: bool,
}

/// One file in the chain a disk is on, topmost first.
#[derive(Debug, Clone, Default, PartialEq, Eq, Serialize, Deserialize)]
pub struct ChainFile {
    pub path: String,
    pub format: Option<String>,
    /// Bytes it takes on the host.
    pub allocation: Option<u64>,
    /// The layer below it; None for the base image.
    pub backing: Option<String>,
    /// The snapshot this layer belongs to, where one does.
    pub snap: Option<String>,
    /// The file the guest is on now.
    pub active: bool,
}

#[derive(Debug, Clone, Default, PartialEq, Eq, Serialize, Deserialize)]
pub struct ChainDisk {
    pub target: String,
    pub files: Vec<ChainFile>,
    /// The pool whose directory holds the topmost file, where one does.
    pub pool: Option<String>,
    /// Why the host could not read the disk's chain, in its words.
    pub error: Option<String>,
}

/// The chain every disk of a guest is on.
#[derive(Debug, Clone, Default, PartialEq, Eq, Serialize, Deserialize)]
pub struct Chain {
    pub disks: Vec<ChainDisk>,
    /// Why no snapshot at all can be taken (a disk known not to be qcow2).
    pub refusal: Option<String>,
    /// Why an external snapshot cannot be taken.
    pub external_refusal: Option<String>,
    /// The pools an overlay can be placed in, by name.
    pub pools: Vec<String>,
}

/// The part of a guest a difference is about.
#[derive(Debug, Clone, Copy, PartialEq, Eq, Serialize, Deserialize)]
#[serde(rename_all = "snake_case")]
pub enum DiffGroup {
    Cpu,
    Memory,
    Disks,
    Nics,
    Firmware,
    Boot,
    Other,
}

impl DiffGroup {
    /// The group of a PVE configuration key (`cores`, `scsi0`, `net0`).
    pub fn of_pve_key(key: &str) -> DiffGroup {
        match key {
            "cores" | "sockets" | "vcpus" | "cpu" | "cpuunits" | "cpulimit" => DiffGroup::Cpu,
            "memory" | "balloon" | "swap" | "shares" => DiffGroup::Memory,
            "boot" | "bootdisk" | "startup" => DiffGroup::Boot,
            "bios" | "efidisk0" | "tpmstate0" | "machine" => DiffGroup::Firmware,
            "rootfs" => DiffGroup::Disks,
            k if ["scsi", "virtio", "ide", "sata", "mp", "unused"].iter().any(|p| k.starts_with(p)) => {
                DiffGroup::Disks
            }
            k if ["net", "ipconfig", "nameserver", "searchdomain"].iter().any(|p| k.starts_with(p)) => DiffGroup::Nics,
            _ => DiffGroup::Other,
        }
    }

    /// The group of a libvirt difference (`sbm_virt::libvirt::snapshot`).
    pub fn of_libvirt(group: &str) -> DiffGroup {
        match group {
            "cpu" => DiffGroup::Cpu,
            "memory" => DiffGroup::Memory,
            "disks" => DiffGroup::Disks,
            "interfaces" => DiffGroup::Nics,
            "firmware" => DiffGroup::Firmware,
            "boot" => DiffGroup::Boot,
            _ => DiffGroup::Other,
        }
    }
}

/// One difference between a snapshot's configuration and the guest's now.
#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize)]
pub struct Diff {
    pub group: DiffGroup,
    pub key: String,
    /// What the snapshot has.
    pub before: Option<String>,
    /// What the guest has now.
    pub after: Option<String>,
}

/// Where a snapshot may take the guest's memory from.
#[derive(Debug, Clone, Copy, PartialEq, Eq, Serialize, Deserialize)]
#[serde(rename_all = "snake_case")]
pub enum Memory {
    /// Not at all: a container, or a guest that is not running.
    None,
    /// The user chooses (PVE `vmstate`).
    Optional,
    /// Always: libvirt's internal snapshot of an active domain.
    Always,
}

/// Whether a snapshot of `guest` can hold its memory on a host with `caps`.
/// Paused counts: QEMU saves a paused guest's memory as well.
pub fn memory(caps: &Capabilities, guest: &Guest) -> Memory {
    if guest.kind == GuestKind::Lxc || !matches!(guest.state, GuestState::Running | GuestState::Paused) {
        return Memory::None;
    }
    if caps.snapshot_memory_required { Memory::Always } else { Memory::Optional }
}

/// Why a name cannot be a new snapshot's.
#[derive(Debug, Clone, Copy, PartialEq, Eq, Serialize, Deserialize)]
#[serde(rename_all = "snake_case")]
pub enum NameIssue {
    Empty,
    Invalid,
    Taken,
}

/// PVE's own rule (`pve-configid`: a letter, then 1 to 39 letters, digits,
/// `-` and `_`), used for libvirt too so a name never needs quoting to be
/// read back.
pub fn valid_name(name: &str) -> bool {
    let mut chars = name.chars();
    chars.next().is_some_and(|c| c.is_ascii_alphabetic())
        && (2..=40).contains(&name.len())
        && chars.all(|c| c.is_ascii_alphanumeric() || c == '_' || c == '-')
}

/// Why `name` cannot be a new snapshot's among `existing`, or None.
pub fn name_issue<'a>(name: &str, existing: impl IntoIterator<Item = &'a str>) -> Option<NameIssue> {
    if name.is_empty() {
        return Some(NameIssue::Empty);
    }
    if !valid_name(name) {
        return Some(NameIssue::Invalid);
    }
    // PVE reserves `current` for the "you are here" entry of its listing.
    if name == "current" || existing.into_iter().any(|n| n == name) {
        return Some(NameIssue::Taken);
    }
    None
}

/// The file libvirt gives an overlay it makes itself: `<disk>.<snapshot>`,
/// beside the disk, or in `dir` (captured on libvirt 11.3.0).
pub fn overlay_path(disk_path: &str, snapshot: &str, dir: Option<&str>) -> String {
    let file = disk_path.rsplit('/').next().unwrap_or(disk_path);
    let name = format!("{file}.{snapshot}");
    let base = match dir {
        Some(d) => d.to_owned(),
        None => disk_path.rfind('/').map(|at| disk_path[..at].to_owned()).unwrap_or_default(),
    };
    if base.is_empty() { name } else { format!("{}/{name}", base.trim_end_matches('/')) }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn names() {
        assert_eq!(name_issue("", []), Some(NameIssue::Empty));
        assert_eq!(name_issue("1abc", []), Some(NameIssue::Invalid));
        assert_eq!(name_issue("a", []), Some(NameIssue::Invalid), "two at least");
        assert_eq!(name_issue(&"a".repeat(41), []), Some(NameIssue::Invalid));
        assert_eq!(name_issue("with space", []), Some(NameIssue::Invalid));
        assert_eq!(name_issue("current", []), Some(NameIssue::Taken));
        assert_eq!(name_issue("pre-up_1", ["pre-up_1"]), Some(NameIssue::Taken));
        assert_eq!(name_issue("pre-up_1", ["other"]), None);
    }

    #[test]
    fn groups() {
        assert_eq!(DiffGroup::of_pve_key("cores"), DiffGroup::Cpu);
        assert_eq!(DiffGroup::of_pve_key("scsi10"), DiffGroup::Disks);
        assert_eq!(DiffGroup::of_pve_key("ipconfig0"), DiffGroup::Nics);
        assert_eq!(DiffGroup::of_pve_key("efidisk0"), DiffGroup::Firmware);
        assert_eq!(DiffGroup::of_pve_key("ostype"), DiffGroup::Other);
    }

    #[test]
    fn overlays() {
        assert_eq!(overlay_path("/var/lib/libvirt/images/vm.qcow2", "s1", None), "/var/lib/libvirt/images/vm.qcow2.s1");
        assert_eq!(overlay_path("/a/vm.qcow2", "s1", Some("/b/")), "/b/vm.qcow2.s1");
        assert_eq!(overlay_path("vm.qcow2", "s1", None), "vm.qcow2.s1");
    }
}
