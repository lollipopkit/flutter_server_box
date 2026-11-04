//! Disks, RAID arrays, ZFS pools FFI (sbm_parser::storage)
//!
//! The command layer the monitor agent's Storage app runs, so the app reads
//! and changes a machine's storage by the same rules: the view and every
//! check (what is in use, the system's mounts) are decided in Rust, and the
//! app only runs the scripts. Reading needs no root; a change goes through
//! `PrivilegedExec` (scripts are POSIX `sh`, sent on stdin, so the LUKS
//! passphrase [`storage_action_script`] writes into one is on no command
//! line). The models are `sbm_parser::storage`'s own, mirrored.

use std::collections::HashMap;

use flutter_rust_bridge::frb;
use sbm_parser::storage as st;
pub use sbm_parser::storage::{
    BlockDevice, DiskHealth, HealthVerdict, MdArray, MdMember, MdSync, Pool, PoolLayoutChoice, RaidLevelChoice, Refusal, SelfTest, SmartAttribute,
    StorageAction, StorageError, StorageView, Vdev, VdevActions,
};

// --- Mirrors -----------------------------------------------------------------

#[frb(mirror(BlockDevice))]
pub struct _BlockDevice {
    pub name: String,
    pub path: String,
    pub kind: String,
    pub size: u64,
    pub model: Option<String>,
    pub serial: Option<String>,
    pub rotational: bool,
    pub transport: Option<String>,
    pub removable: bool,
    pub read_only: bool,
    pub part_type: Option<String>,
    pub fstype: Option<String>,
    pub label: Option<String>,
    pub uuid: Option<String>,
    pub mountpoints: Vec<String>,
    pub mounted: bool,
    pub mountable: bool,
    pub expandable: bool,
    pub fs_size: Option<u64>,
    pub available: Option<u64>,
    pub used: Option<u64>,
    pub children: Vec<BlockDevice>,
}

#[frb(mirror(MdArray))]
pub struct _MdArray {
    pub name: String,
    pub state: String,
    pub level: Option<String>,
    pub members: Vec<MdMember>,
    pub raid_disks: Option<u32>,
    pub working_disks: Option<u32>,
    pub sync: Option<MdSync>,
    pub growable: bool,
}

#[frb(mirror(MdMember))]
pub struct _MdMember {
    pub name: String,
    pub faulty: bool,
    pub spare: bool,
}

#[frb(mirror(MdSync))]
pub struct _MdSync {
    pub action: String,
    pub permille: u32,
    pub finish: Option<String>,
}

#[frb(mirror(Pool))]
pub struct _Pool {
    pub name: String,
    pub size: u64,
    pub allocated: u64,
    pub free: u64,
    pub health: String,
    pub scan: Option<String>,
    pub scanning: bool,
    pub vdevs: Vec<Vdev>,
}

#[frb(mirror(Vdev))]
pub struct _Vdev {
    pub name: String,
    pub state: String,
    pub depth: u32,
    pub errors: u64,
    pub section: Option<String>,
    pub actions: VdevActions,
}

#[frb(mirror(VdevActions))]
pub struct _VdevActions {
    pub replace: bool,
    pub attach: bool,
    pub remove: bool,
    pub online: bool,
}

#[frb(mirror(RaidLevelChoice))]
pub struct _RaidLevelChoice {
    pub value: u8,
    pub minimum: u32,
}

#[frb(mirror(PoolLayoutChoice))]
pub struct _PoolLayoutChoice {
    pub value: String,
    pub minimum: u32,
}

#[frb(mirror(StorageView))]
pub struct _StorageView {
    pub disks: Vec<BlockDevice>,
    pub busy: HashMap<String, String>,
    pub system: Vec<String>,
    pub free: Vec<String>,
    pub overlaps: HashMap<String, Vec<String>>,
    pub growable_partitions: Vec<String>,
    pub next_md: String,
    pub raid_levels: Vec<RaidLevelChoice>,
    pub pool_layouts: Vec<PoolLayoutChoice>,
    pub arrays: Vec<MdArray>,
    pub pools: Vec<Pool>,
    pub tools: Vec<String>,
}

#[frb(mirror(HealthVerdict))]
pub enum _HealthVerdict {
    Healthy,
    Wearing,
    Failing,
    Unsupported,
    Asleep,
}

#[frb(mirror(DiskHealth))]
pub struct _DiskHealth {
    pub device: String,
    pub supported: bool,
    pub asleep: bool,
    pub passed: Option<bool>,
    pub temperature: Option<f64>,
    pub power_on_hours: Option<i64>,
    pub bad_sectors: Option<i64>,
    pub testing: Option<u8>,
    pub last_test: Option<SelfTest>,
    pub attributes: Vec<SmartAttribute>,
    pub tests: Vec<SelfTest>,
    pub verdict: HealthVerdict,
}

#[frb(mirror(SmartAttribute))]
pub struct _SmartAttribute {
    pub id: Option<i64>,
    pub name: String,
    pub value: Option<i64>,
    pub worst: Option<i64>,
    pub thresh: Option<i64>,
    pub raw: String,
    pub failing: bool,
}

#[frb(mirror(SelfTest))]
pub struct _SelfTest {
    pub long: bool,
    pub outcome: String,
    pub hours: Option<i64>,
}

#[frb(mirror(StorageAction))]
pub enum _StorageAction {
    Partition { device: String },
    Format { device: String, fstype: String, label: Option<String>, encrypt: bool },
    Mount { device: String, mountpoint: String, persist: bool, own: bool },
    Unmount { mountpoint: String },
    CreateRaid { name: String, level: u8, devices: Vec<String> },
    AddToRaid { array: String, device: String },
    RemoveFromRaid { array: String, device: String },
    DeleteRaid { array: String },
    CreatePool { name: String, layout: String, devices: Vec<String> },
    ScrubPool { name: String },
    DestroyPool { name: String },
    SmartTest { device: String, long: bool },
    GrowRaid { array: String, device: String },
    ExpandFilesystem { device: String },
    AddToPool { name: String, layout: String, devices: Vec<String> },
    ReplaceInPool { name: String, old: String, new: String },
    AttachToPool { name: String, existing: String, new: String },
    AddSpare { name: String, devices: Vec<String> },
    RemoveFromPool { name: String, device: String },
    OnlineInPool { name: String, device: String },
    GrowPartition { device: String },
    Unlock { device: String },
    Lock { device: String },
}

#[frb(mirror(StorageError))]
pub enum _StorageError {
    InvalidDevice,
    InvalidMountpoint,
    InvalidLabel,
    InvalidFilesystem,
    InvalidName,
    InvalidLevel,
    TooFewDevices,
    KeyRequired,
    InvalidPassphrase,
}

#[frb(mirror(Refusal))]
pub struct _Refusal {
    pub status: u16,
    pub error: String,
    pub device: Option<String>,
    pub why: Option<String>,
}

// --- Functions ---------------------------------------------------------------

/// Everything the Storage page draws, readable without root
#[frb(sync)]
pub fn storage_view_script() -> String {
    st::view_command()
}

/// [`storage_view_script`]'s output; `None` when lsblk answered nothing
pub fn storage_parse_view(raw: String) -> Option<StorageView> {
    st::parse_view(&raw)
}

/// Why `action` is refused on the machine `view` describes, or `None` when
/// it may run. Check against a view read just before, not the one a page
/// drew earlier.
#[frb(sync)]
pub fn storage_check(view: StorageView, action: StorageAction) -> Option<Refusal> {
    st::check(&view, &action).err()
}

/// The root script that makes `action`; `passphrase` for an encrypted format
/// or an unlock (written into a key file the script makes and removes)
#[frb(sync)]
pub fn storage_action_script(action: StorageAction, passphrase: Option<String>) -> Result<String, StorageError> {
    match passphrase {
        Some(p) if action.needs_key() => action.script_with_passphrase(&p),
        _ => action.script(),
    }
}

/// Whether `action` needs a LUKS passphrase
#[frb(sync)]
pub fn storage_action_needs_key(action: StorageAction) -> bool {
    action.needs_key()
}

/// Every disk's SMART, as root (or with a `NOPASSWD` sudoers rule)
#[frb(sync)]
pub fn storage_health_script() -> String {
    st::HEALTH_COMMAND.to_string()
}

/// [`storage_health_script`]'s output
pub fn storage_parse_health(raw: String) -> Vec<DiskHealth> {
    st::parse_health(&raw)
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn a_change_is_checked_and_scripted_by_the_parser() {
        assert!(storage_view_script().contains("lsblk -J"));
        assert!(storage_parse_view("nothing".into()).is_none());
        let unlock = StorageAction::Unlock { device: "/dev/sdb1".into() };
        assert!(storage_action_needs_key(unlock.clone()));
        assert_eq!(storage_action_script(unlock.clone(), None).unwrap_err(), StorageError::KeyRequired);
        assert!(storage_action_script(unlock, Some("a passphrase".into())).unwrap().starts_with("k=$(mktemp)"));
        let refusal = storage_check(StorageView::default(), StorageAction::Partition { device: "/dev/sdz".into() }).unwrap();
        assert_eq!((refusal.error.as_str(), refusal.why.as_deref()), ("inUse", Some("notFound")));
    }
}
