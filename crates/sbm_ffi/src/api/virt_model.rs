//! The models a virtualization change is made of (`sbm_virt::{create,
//! hardware, backup, resource}`), mirrored. Their names repeat across those
//! modules (`Issue`, `Change`, …) and FRB wants one name per type, so a
//! repeated one is mirrored under an alias.

use flutter_rust_bridge::frb;
pub use sbm_virt::create::{VolumeRef, CloudInit, CreateSpec, CreateOptions, Created, CloneRequest, Issue as CreateIssue};
pub use sbm_virt::hardware::{Hardware, Cpu, Memory as HwMemory, DiskKind, HwDisk, HwNic, PendingField, Firmware, Display as HwDisplay, DeviceKind, HwDevice, Support, Limits, UsbNaming, HostDevice, HostDevices, Change as HwChange, Outcome, Issue as HwIssue, CloudInitState, CloudInitEdit};
pub use sbm_virt::backup::{Backup, BackupJob, BackupJobEdit, BackupRequest, BackupEdit, ScheduleCheck, Issue as BackupIssue};
pub use sbm_virt::resource::{Pool as ResourcePool, GuestRef, Volume, Network, NetworkChanges, Change as ResourceChange, Issue as ResourceIssue};
pub use sbm_virt::resource::NetHost;
pub use sbm_virt::error::Detail;
pub use super::virt_view::GuestKind;

#[frb(mirror(VolumeRef))]
pub struct _VolumeRef {
    pub pool: String,
    pub volume: String,
}

#[frb(mirror(CloudInit))]
pub struct _CloudInit {
    pub user: String,
    pub password: Option<String>,
    pub ssh_keys: Vec<String>,
    pub hostname: Option<String>,
    pub address: Option<String>,
    pub gateway: Option<String>,
    pub dns: Vec<String>,
    pub search_domains: Vec<String>,
}

#[frb(mirror(CreateSpec))]
pub struct _CreateSpec {
    pub kind: GuestKind,
    pub name: String,
    pub node: Option<String>,
    pub vmid: Option<u32>,
    pub cores: u32,
    pub memory_mib: u64,
    pub storage: String,
    pub disk_gib: u64,
    pub media: Option<VolumeRef>,
    pub image: Option<VolumeRef>,
    pub network: Option<String>,
    pub password: Option<String>,
    pub ssh_keys: Vec<String>,
    pub unprivileged: bool,
    pub bus: Option<String>,
    pub nic_model: Option<String>,
    pub uefi: bool,
    pub secure_boot: bool,
    pub tpm: bool,
    pub cloud_init: Option<CloudInit>,
    pub start: bool,
}

#[frb(mirror(CreateOptions))]
pub struct _CreateOptions {
    pub buses: Vec<String>,
    pub nic_models: Vec<String>,
    pub uefi: bool,
    pub tpm: bool,
    pub secure_boot: bool,
    pub cloud_images: bool,
    pub cloud_init: bool,
    pub cloud_init_missing: Option<String>,
}

#[frb(mirror(Created))]
pub struct _Created {
    pub id: String,
    pub start_error: Option<String>,
    pub disk_kept_bytes: Option<u64>,
}

#[frb(mirror(CloneRequest))]
pub struct _CloneRequest {
    pub name: String,
    pub full: bool,
    pub vmid: Option<u32>,
    pub storage: Option<String>,
    pub target_node: Option<String>,
    pub target_pool: Option<String>,
}

#[frb(mirror(CreateIssue))]
pub enum _CreateIssue {
    NameEmpty,
    NameInvalid,
    NameTaken,
    VmidInvalid,
    VmidTaken,
    Node,
    Cores,
    Memory,
    Storage,
    DiskSize,
    Template,
    Media,
    Credentials,
    Password,
    SshKeys,
    Image,
    ImageSize,
    Network,
    SecureBoot,
    NotOffered,
    CiUser,
    CiCredentials,
    CiHostname,
    CiAddress,
    CiGateway,
    CiDns,
    CiSearch,
    CloneLinkedTarget,
    CloneStorage,
    CloneStorageContent,
    CloneStorageShared,
    CloneNodeUnknown,
    NotStopped,
    IsTemplate,
    NotFound,
    Unsupported,
}

#[frb(mirror(Hardware))]
pub struct _Hardware {
    pub kind: GuestKind,
    pub running: bool,
    pub cpu: Cpu,
    pub memory: HwMemory,
    pub disks: Vec<HwDisk>,
    pub nics: Vec<HwNic>,
    pub boot: Option<Vec<String>>,
    pub autostart: bool,
    pub name: Option<String>,
    pub description: Option<String>,
    pub protection: Option<bool>,
    pub rename_running: bool,
    pub pending: Vec<PendingField>,
    pub revision: Option<String>,
    pub limits: Limits,
    pub cpu_types: Vec<String>,
    pub config_text: Option<String>,
    pub firmware: Option<Firmware>,
    pub display: Option<HwDisplay>,
    pub devices: Vec<HwDevice>,
    pub support: Support,
}

#[frb(mirror(Cpu))]
pub struct _Cpu {
    pub sockets: u32,
    pub cores: u32,
    pub threads: u32,
    pub online: Option<u32>,
    pub cpu_type: Option<String>,
}

#[frb(mirror(HwMemory))]
pub struct _HwMemory {
    pub mib: u64,
    pub min_mib: Option<u64>,
    pub balloon: bool,
    pub swap_mib: Option<u64>,
}

#[frb(mirror(DiskKind))]
pub enum _DiskKind {
    Disk,
    Cdrom,
    Rootfs,
    Mount,
}

#[frb(mirror(HwDisk))]
pub struct _HwDisk {
    pub key: String,
    pub kind: DiskKind,
    pub source: Option<String>,
    pub size: Option<u64>,
    pub storage: Option<String>,
    pub mount_point: Option<String>,
    pub bus: Option<String>,
    pub format: Option<String>,
    pub readonly: bool,
    pub cache: Option<String>,
    pub cloud_init: bool,
    pub resizable: bool,
}

#[frb(mirror(HwNic))]
pub struct _HwNic {
    pub key: String,
    pub mac: Option<String>,
    pub nic_type: Option<String>,
    pub source: Option<String>,
    pub model: Option<String>,
    pub link_up: bool,
    pub firewall: Option<bool>,
    pub name: Option<String>,
}

#[frb(mirror(PendingField))]
pub struct _PendingField {
    pub key: String,
    pub current: Option<String>,
    pub pending: Option<String>,
    pub delete: bool,
}

#[frb(mirror(Firmware))]
pub struct _Firmware {
    pub uefi: bool,
    pub secure_boot: bool,
    pub vars_storage: Option<String>,
}

#[frb(mirror(HwDisplay))]
pub struct _HwDisplay {
    pub protocol: Option<String>,
    pub listen: Option<String>,
    pub gpu: Option<String>,
    pub port: Option<i32>,
}

#[frb(mirror(DeviceKind))]
pub enum _DeviceKind {
    Usb,
    Pci,
    Tpm,
}

#[frb(mirror(HwDevice))]
pub struct _HwDevice {
    pub key: String,
    pub kind: DeviceKind,
    pub detail: Option<String>,
    pub mapping: bool,
}

#[frb(mirror(Support))]
pub struct _Support {
    pub buses: Vec<String>,
    pub caches: Vec<String>,
    pub nic_models: Vec<String>,
    pub mac: bool,
    pub protocols: Vec<String>,
    pub listen: bool,
    pub gpus: Vec<String>,
    pub uefi: bool,
    pub secure_boot: bool,
    pub tpm: bool,
    pub usb: bool,
    pub pci: bool,
}

#[frb(mirror(Limits))]
pub struct _Limits {
    pub host_cpus: Option<u32>,
    pub host_memory_bytes: Option<u64>,
}

#[frb(mirror(UsbNaming))]
pub enum _UsbNaming {
    VendorProduct,
    Address,
}

#[frb(mirror(HostDevice))]
pub struct _HostDevice {
    pub id: String,
    pub label: String,
    pub detail: Option<String>,
    pub mapping: bool,
    pub usb_bus: Option<u32>,
    pub usb_port: Option<String>,
    pub usb_device: Option<u32>,
    pub iommu_group: Option<u32>,
    pub group_size: u32,
}

#[frb(mirror(HostDevices))]
pub struct _HostDevices {
    pub usb: Vec<HostDevice>,
    pub pci: Vec<HostDevice>,
    pub iommu: bool,
    pub mappings_only: bool,
}

#[frb(mirror(HwChange))]
pub enum _HwChange {
    SetCpu {
        sockets: u32,
        cores: u32,
        online: Option<u32>,
        cpu_type: Option<String>,
    },
    SetMemory {
        mib: u64,
        min_mib: Option<u64>,
        swap_mib: Option<u64>,
    },
    GrowDisk { key: String, bytes: u64 },
    AddDisk {
        pool: String,
        gib: u64,
        mount_point: Option<String>,
    },
    AttachVolume {
        volume: VolumeRef,
        mount_point: Option<String>,
    },
    RemoveDisk {
        key: String,
        delete_volume: bool,
    },
    AddCdrom {
        media: Option<VolumeRef>,
    },
    SetMedia {
        key: String,
        media: Option<VolumeRef>,
    },
    AddNic {
        network: String,
        model: Option<String>,
    },
    RemoveNic { key: String },
    UpdateNic {
        key: String,
        network: Option<String>,
        link_up: bool,
        firewall: Option<bool>,
    },
    SetBoot { order: Vec<String> },
    SetAutostart { on: bool },
    SetName { name: String },
    SetDescription { text: String },
    SetProtection { on: bool },
    UpdateDisk {
        key: String,
        bus: Option<String>,
        cache: Option<String>,
    },
    SetNicHardware {
        key: String,
        model: Option<String>,
        mac: Option<String>,
    },
    SetFirmware {
        uefi: bool,
        secure_boot: bool,
        storage: Option<String>,
    },
    SetDisplay {
        protocol: Option<String>,
        listen: Option<String>,
        gpu: Option<String>,
    },
    AddDevice {
        kind: DeviceKind,
        host: Option<HostDevice>,
        storage: Option<String>,
        usb_naming: UsbNaming,
    },
    RemoveDevice { key: String },
    Revert { keys: Vec<String> },
}

#[frb(mirror(Outcome))]
pub struct _Outcome {
    pub live_error: Option<String>,
    pub volume_kept: bool,
}

#[frb(mirror(HwIssue))]
pub enum _HwIssue {
    CpuCount,
    CpuOnline,
    Memory,
    MemoryMin,
    DiskShrink,
    DiskSize,
    StorageSpace,
    MountPoint,
    BootEmpty,
    NameInvalid,
    NameRunning,
    Description,
    Mac,
    StopFirst,
    StorageMissing,
    Device,
    VolumeInUse,
    Media,
    NotOffered,
    NotFound,
    Unsupported,
}

#[frb(mirror(CloudInitState))]
pub struct _CloudInitState {
    pub user: String,
    pub ssh_keys: Vec<String>,
    pub hostname: Option<String>,
    pub address: Option<String>,
    pub gateway: Option<String>,
    pub dns: Vec<String>,
    pub search_domains: Vec<String>,
    pub nics: u32,
    pub password_set: bool,
    pub password_expires: bool,
    pub network: bool,
    pub foreign: bool,
    pub revision: String,
}

#[frb(mirror(CloudInitEdit))]
pub struct _CloudInitEdit {
    pub values: CloudInit,
    pub remove_password: bool,
    pub password_expires: bool,
    pub revision: String,
}

#[frb(mirror(Backup))]
pub struct _Backup {
    pub id: String,
    pub storage: String,
    pub node: String,
    pub vmid: Option<u32>,
    pub created_at: Option<i64>,
    pub size: Option<u64>,
    pub format: Option<String>,
    pub notes: Option<String>,
    pub protected: bool,
    pub verification: Option<String>,
    pub kind: Option<GuestKind>,
}

#[frb(mirror(BackupJob))]
pub struct _BackupJob {
    pub id: String,
    pub schedule: Option<String>,
    pub storage: Option<String>,
    pub mode: Option<String>,
    pub compress: Option<String>,
    pub enabled: bool,
    pub all: bool,
    pub vmids: Vec<u32>,
    pub exclude: Vec<u32>,
    pub pool: Option<String>,
    pub node: Option<String>,
    pub comment: Option<String>,
    pub notes_template: Option<String>,
    pub mail_notification: Option<String>,
    pub prune: Option<String>,
}

#[frb(mirror(BackupJobEdit))]
pub struct _BackupJobEdit {
    pub id: Option<String>,
    pub is_new: bool,
    pub node: Option<String>,
    pub storage: String,
    pub schedule: String,
    pub mode: String,
    pub compress: String,
    pub enabled: bool,
    pub all: bool,
    pub vmids: Vec<u32>,
    pub exclude: Vec<u32>,
    pub pool: Option<String>,
    pub comment: Option<String>,
    pub notes_template: Option<String>,
    pub mail_notification: Option<String>,
    pub prune: Option<String>,
}

#[frb(mirror(BackupRequest))]
pub struct _BackupRequest {
    pub storage: String,
    pub mode: String,
    pub compress: String,
    pub notes: Option<String>,
    pub protected: bool,
    pub prune: Option<String>,
}

#[frb(mirror(BackupEdit))]
pub struct _BackupEdit {
    pub notes: String,
    pub protected: bool,
}

#[frb(mirror(ScheduleCheck))]
pub struct _ScheduleCheck {
    pub error: Option<String>,
    pub next: Vec<i64>,
}

#[frb(mirror(BackupIssue))]
pub enum _BackupIssue {
    ScheduleEmpty,
    ScheduleInvalid,
    Storage,
    Mode,
    Compress,
    Guests,
    NodeOffline,
    NotStopped,
    NotFound,
    Unsupported,
}

#[frb(mirror(ResourcePool))]
pub struct _ResourcePool {
    pub id: String,
    pub name: String,
    pub node: Option<String>,
    pub pool_type: String,
    pub path: Option<String>,
    pub source: Option<String>,
    pub capacity: Option<u64>,
    pub used: Option<u64>,
    pub available: Option<u64>,
    pub active: bool,
    pub autostart: Option<bool>,
    pub enabled: Option<bool>,
    pub shared: Option<bool>,
    pub content: Vec<String>,
    pub volume_count: Option<u64>,
}

#[frb(mirror(GuestRef))]
pub struct _GuestRef {
    pub guest_id: Option<String>,
    pub vmid: Option<u32>,
    pub device: Option<String>,
    pub mac: Option<String>,
    pub ip: Option<String>,
}

#[frb(mirror(Volume))]
pub struct _Volume {
    pub id: String,
    pub name: String,
    pub path: Option<String>,
    pub format: Option<String>,
    pub content: Option<String>,
    pub capacity: Option<u64>,
    pub allocation: Option<u64>,
    pub backing: Option<String>,
    pub created_at: Option<i64>,
    pub users: Vec<GuestRef>,
    pub backs: Vec<String>,
}

#[frb(mirror(Network))]
pub struct _Network {
    pub id: String,
    pub name: String,
    pub node: Option<String>,
    pub mode: String,
    pub bridge: Option<String>,
    pub cidrs: Vec<String>,
    pub gateway: Option<String>,
    pub dhcp_ranges: Vec<String>,
    pub ports: Vec<String>,
    pub vlan_aware: Option<bool>,
    pub vlan_id: Option<u32>,
    pub vlan_device: Option<String>,
    pub bond_mode: Option<String>,
    pub active: bool,
    pub autostart: Option<bool>,
    pub comment: Option<String>,
    pub hosts: Vec<NetHost>,
    pub xml: String,
    pub pending_restart: bool,
    pub management_editable: bool,
    pub users: Vec<GuestRef>,
}

#[frb(mirror(NetworkChanges))]
pub struct _NetworkChanges {
    pub node: String,
    pub diff: String,
}

#[frb(mirror(ResourceChange))]
pub enum _ResourceChange {
    PoolCreate {
        name: String,
        pool_type: String,
        source: String,
        target: Option<String>,
        node: Option<String>,
        content: Vec<String>,
        autostart: bool,
    },
    PoolSetActive { pool: String, active: bool },
    PoolSetAutostart { pool: String, on: bool },
    PoolRefresh { pool: String },
    PoolDelete {
        pool: String,
        delete_storage: bool,
    },
    VolumeCreate {
        pool: String,
        name: String,
        gib: u64,
        format: String,
    },
    VolumeDelete { pool: String, volume: String },
    VolumeResize { pool: String, volume: String, bytes: u64 },
    VolumeClone { pool: String, volume: String, name: String },
    NetworkCreate {
        name: String,
        mode: String,
        node: Option<String>,
        bridge: Option<String>,
        cidr: Option<String>,
        dhcp_start: Option<String>,
        dhcp_end: Option<String>,
        vlan_aware: bool,
        autostart: bool,
    },
    NetworkEdit {
        network: String,
        mode: String,
        bridge: Option<String>,
        address: Option<String>,
        prefix: Option<u8>,
        dhcp_start: Option<String>,
        dhcp_end: Option<String>,
        hosts: Vec<NetHost>,
        restart: bool,
        base_xml: Option<String>,
    },
    NetworkEditBridge {
        network: String,
        ports: Option<String>,
        cidr: Option<String>,
        gateway: Option<String>,
        vlan_aware: Option<bool>,
        autostart: Option<bool>,
    },
    NetworkRestart {
        network: String,
        base_xml: Option<String>,
    },
    NetworkSetActive { network: String, active: bool },
    NetworkSetAutostart { network: String, on: bool },
    NetworkDelete { network: String },
    NetworkApply { node: String },
    NetworkRevert { node: String },
}

#[frb(mirror(ResourceIssue))]
pub enum _ResourceIssue {
    NameEmpty,
    NameInvalid,
    NameTaken,
    SourceInvalid,
    TargetInvalid,
    CidrInvalid,
    DhcpInvalid,
    SubnetTaken,
    BridgeInvalid,
    Size,
    Space,
    Format,
    InUse,
    Shrink,
    HostInvalid,
    ManagementIface,
    NotFound,
    Unsupported,
}

#[frb(mirror(NetHost))]
pub struct _NetHost {
    pub mac: String,
    pub ip: String,
    pub name: Option<String>,
}

/// What a client phrases itself when no host text says it (mirrors
/// sbm_virt::error::Detail).
#[frb(mirror(Detail))]
pub enum _Detail {
    NoUser,
    PasswordRequired,
    TokenIncomplete,
    OtpRequired,
    OtpEmpty,
    OtpRejected,
    InvalidBody,
    InvalidData,
    MissingTicket,
    NoPrivileges { token: bool, account: String, command: String },
    NotOffered,
    TaskStillRunning { node: String, upid: String, minutes: u64 },
    CertNotPresented,
    NeedsPrivilege { account: String, privilege: String, path: String, command: String },
    Refused { issue: ResourceIssue },
    CreateRefused { issue: CreateIssue },
    HardwareRefused { issue: HwIssue },
    BackupRefused { issue: BackupIssue },
    ApplyTouchesManagement { ifaces: Vec<String> },
    ApplyUnreadable,
}
