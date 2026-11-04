//! libvirt's reads and the steps made of them (`sbm_virt::libvirt`), mirrored:
//! what the app reads off them, and what it hands from one call to the next.

use flutter_rust_bridge::frb;
pub use sbm_virt::libvirt::{VirtVersion, VirtHostProbe, VirtDisk, VirtNic, VirtGraphics, VirtDomainXml, VirtDisplay, VirtVncConsoleInfo, VirtDomainDetail, VirtVolumeRef, VirtPool, VirtDiskUse, VirtStorage, VirtCreateHost, VirtCreateSpec, VirtCreateVolumes, VirtCreated, VirtCloneDisk, VirtCloneSpec, VirtHwCpu, VirtHwDisk, VirtHwGraphics, VirtHwTpm, VirtHwHostdev, VirtHwNic, VirtHwConfig, VirtHwCaps, VirtHardwareInfo, FirmwareDescriptor, VirtHostUsb, VirtHostPci, VirtHostDevices, VirtHwChange, VirtHwNewDevice, VirtHwOutcome};
pub use sbm_virt::libvirt::cloud_init::{VirtCiIpv4, VirtCiNetwork, VirtCloudInit, VirtSeedRead};
pub use sbm_virt::libvirt::manage::{VirtNetIpv4, VirtResourceOp};
pub use super::virt_model::NetHost;

#[frb(mirror(VirtVersion))]
pub struct _VirtVersion {
    pub libvirt: Option<String>,
    pub hypervisor: Option<String>,
    pub hypervisor_version: Option<String>,
}

#[frb(mirror(VirtHostProbe))]
pub struct _VirtHostProbe {
    pub pve: Option<String>,
    pub container: Option<String>,
    pub libvirt: Option<VirtVersion>,
}

#[frb(mirror(VirtDisk))]
pub struct _VirtDisk {
    pub device: String,
    pub source_type: Option<String>,
    pub source: Option<String>,
    pub target: Option<String>,
    pub bus: Option<String>,
    pub format: Option<String>,
    pub readonly: bool,
}

#[frb(mirror(VirtNic))]
pub struct _VirtNic {
    pub kind: String,
    pub mac: Option<String>,
    pub source: Option<String>,
    pub model: Option<String>,
    pub target: Option<String>,
}

#[frb(mirror(VirtGraphics))]
pub struct _VirtGraphics {
    pub kind: String,
    pub port: Option<u16>,
    pub tls_port: Option<u16>,
    pub autoport: bool,
    pub listen: Option<String>,
    pub socket: Option<String>,
}

#[frb(mirror(VirtDomainXml))]
pub struct _VirtDomainXml {
    pub name: Option<String>,
    pub uuid: Option<String>,
    pub title: Option<String>,
    pub description: Option<String>,
    pub arch: Option<String>,
    pub machine: Option<String>,
    pub disks: Vec<VirtDisk>,
    pub nics: Vec<VirtNic>,
    pub graphics: Vec<VirtGraphics>,
    pub has_serial_console: bool,
    pub seed: Option<String>,
}

#[frb(mirror(VirtDisplay))]
pub struct _VirtDisplay {
    pub uri: String,
    pub protocol: String,
    pub host: Option<String>,
    pub port: Option<u16>,
    pub tls_port: Option<u16>,
    pub socket: Option<String>,
}

#[frb(mirror(VirtVncConsoleInfo))]
pub struct _VirtVncConsoleInfo {
    pub display: Option<VirtDisplay>,
    pub password: Option<String>,
    pub password_known: bool,
}

#[frb(mirror(VirtDomainDetail))]
pub struct _VirtDomainDetail {
    pub display: Option<VirtDisplay>,
    pub xml: VirtDomainXml,
}

#[frb(mirror(VirtVolumeRef))]
pub struct _VirtVolumeRef {
    pub name: String,
    pub path: Option<String>,
}

#[frb(mirror(VirtPool))]
pub struct _VirtPool {
    pub name: String,
    pub uuid: Option<String>,
    pub pool_type: Option<String>,
    pub active: bool,
    pub autostart: bool,
    pub capacity: Option<u64>,
    pub allocation: Option<u64>,
    pub available: Option<u64>,
    pub target: Option<String>,
    pub source: Option<String>,
    pub volumes: Option<Vec<VirtVolumeRef>>,
}

#[frb(mirror(VirtDiskUse))]
pub struct _VirtDiskUse {
    pub domain: String,
    pub kind: String,
    pub device: String,
    pub target: String,
    pub source: Option<String>,
}

#[frb(mirror(VirtStorage))]
pub struct _VirtStorage {
    pub pools: Vec<VirtPool>,
    pub disks: Vec<VirtDiskUse>,
}

#[frb(mirror(VirtCreateHost))]
pub struct _VirtCreateHost {
    pub domain_type: String,
    pub machine: String,
    pub arch: String,
    pub max_vcpus: Option<u32>,
    pub caps: Option<VirtHwCaps>,
    pub seed_tool: Option<String>,
}

#[frb(mirror(VirtCreateSpec))]
pub struct _VirtCreateSpec {
    pub name: String,
    pub vcpus: u32,
    pub memory_mib: u64,
    pub host: VirtCreateHost,
    pub disk_pool: String,
    pub disk_gib: u64,
    pub disk_format: String,
    pub disk_path: Option<String>,
    pub base_image: Option<String>,
    pub disk_bus: Option<String>,
    pub cdrom: Option<String>,
    pub network: Option<String>,
    pub nic_model: Option<String>,
    pub mac: Option<String>,
    pub efi: bool,
    pub secure_boot: bool,
    pub tpm: bool,
    pub cloud_init: Option<VirtCloudInit>,
    pub seed_path: Option<String>,
    pub seed_tools: Option<Vec<String>>,
    pub start: bool,
}

#[frb(mirror(VirtCreateVolumes))]
pub struct _VirtCreateVolumes {
    pub disk_path: String,
    pub seed_path: Option<String>,
    pub copied_bytes: Option<u64>,
}

#[frb(mirror(VirtCreated))]
pub struct _VirtCreated {
    pub uuid: Option<String>,
    pub start_error: Option<String>,
}

#[frb(mirror(VirtCloneDisk))]
pub struct _VirtCloneDisk {
    pub target: String,
    pub source: String,
    pub format: Option<String>,
}

#[frb(mirror(VirtCloneSpec))]
pub struct _VirtCloneSpec {
    pub source: String,
    pub name: String,
    pub full: bool,
    pub disks: Vec<VirtCloneDisk>,
    pub target_pool: Option<String>,
    pub target_block: bool,
}

#[frb(mirror(VirtHwCpu))]
pub struct _VirtHwCpu {
    pub sockets: u32,
    pub dies: u32,
    pub clusters: u32,
    pub cores: u32,
    pub threads: u32,
    pub max: u32,
    pub current: u32,
    pub topology: bool,
}

#[frb(mirror(VirtHwDisk))]
pub struct _VirtHwDisk {
    pub target: String,
    pub device: String,
    pub bus: Option<String>,
    pub source_type: Option<String>,
    pub source: Option<String>,
    pub format: Option<String>,
    pub readonly: bool,
    pub capacity: Option<u64>,
    pub boot_order: Option<u32>,
    pub cache: Option<String>,
}

#[frb(mirror(VirtHwGraphics))]
pub struct _VirtHwGraphics {
    pub kind: String,
    pub listen: Option<String>,
    pub port: Option<i32>,
}

#[frb(mirror(VirtHwTpm))]
pub struct _VirtHwTpm {
    pub model: String,
    pub backend: String,
    pub version: Option<String>,
}

#[frb(mirror(VirtHwHostdev))]
pub struct _VirtHwHostdev {
    pub key: String,
    pub kind: String,
    pub vendor: Option<String>,
    pub product: Option<String>,
    pub address: Option<String>,
}

#[frb(mirror(VirtHwNic))]
pub struct _VirtHwNic {
    pub mac: String,
    pub kind: String,
    pub source: Option<String>,
    pub model: Option<String>,
    pub link_up: bool,
    pub boot_order: Option<u32>,
}

#[frb(mirror(VirtHwConfig))]
pub struct _VirtHwConfig {
    pub cpu: VirtHwCpu,
    pub memory_kib: u64,
    pub current_memory_kib: u64,
    pub disks: Vec<VirtHwDisk>,
    pub nics: Vec<VirtHwNic>,
    pub boot: Vec<String>,
    pub balloon: bool,
    pub efi: bool,
    pub secure_boot: bool,
    pub machine: Option<String>,
    pub graphics: Option<VirtHwGraphics>,
    pub video: Option<String>,
    pub tpm: Option<VirtHwTpm>,
    pub hostdevs: Vec<VirtHwHostdev>,
    pub seed: Option<String>,
}

#[frb(mirror(VirtHwCaps))]
pub struct _VirtHwCaps {
    pub efi: bool,
    pub secure_boot: bool,
    pub tpm_emulator: bool,
    pub graphics: Vec<String>,
    pub video: Vec<String>,
    pub disk_buses: Vec<String>,
    pub hostdev: bool,
}

#[frb(mirror(VirtHardwareInfo))]
pub struct _VirtHardwareInfo {
    pub firmware: Vec<FirmwareDescriptor>,
    pub config: VirtHwConfig,
    pub live: Option<VirtHwConfig>,
    pub config_xml: String,
    pub config_text: String,
    pub live_xml: String,
    pub autostart: bool,
    pub description: Option<String>,
    pub host_cpus: Option<u32>,
    pub host_memory_kib: Option<u64>,
    pub caps: Option<VirtHwCaps>,
}

#[frb(mirror(FirmwareDescriptor))]
pub struct _FirmwareDescriptor {
    pub name: String,
    pub secure_boot: bool,
    pub enrolled_keys: bool,
}

#[frb(mirror(VirtHostUsb))]
pub struct _VirtHostUsb {
    pub vendor: String,
    pub product: String,
    pub vendor_name: Option<String>,
    pub product_name: Option<String>,
    pub bus: Option<u32>,
    pub device: Option<u32>,
    pub port: Option<String>,
}

#[frb(mirror(VirtHostPci))]
pub struct _VirtHostPci {
    pub address: String,
    pub vendor: Option<String>,
    pub product: Option<String>,
    pub vendor_name: Option<String>,
    pub product_name: Option<String>,
    pub class: Option<String>,
    pub iommu_group: Option<u32>,
    pub group_size: u32,
}

#[frb(mirror(VirtHostDevices))]
pub struct _VirtHostDevices {
    pub usb: Vec<VirtHostUsb>,
    pub pci: Vec<VirtHostPci>,
    pub iommu: bool,
}

#[frb(mirror(VirtHwChange))]
pub enum _VirtHwChange {
    Cpu {
        sockets: u32,
        cores: u32,
        current: Option<u32>,
    },
    Memory {
        memory_mib: u64,
        current_mib: Option<u64>,
    },
    GrowDisk {
        target: String,
        bytes: u64,
        path: Option<String>,
        live: bool,
    },
    AddDisk {
        pool: String,
        volume: String,
        gib: u64,
        format: String,
        target: String,
        bus: String,
    },
    AttachVolume {
        path: String,
        format: String,
        target: String,
        bus: String,
    },
    RemoveDisk {
        target: String,
        delete_path: Option<String>,
        config: bool,
        live: bool,
    },
    AddCdrom {
        target: String,
        bus: String,
        source: Option<String>,
    },
    SetMedia {
        target: String,
        source: Option<String>,
        config: bool,
        live: bool,
    },
    AddNic {
        kind: String,
        source: String,
        model: String,
        mac: String,
    },
    RemoveNic {
        mac: String,
        kind: Option<String>,
        live_kind: Option<String>,
    },
    UpdateNic {
        mac: String,
        kind: String,
        source: String,
        model: Option<String>,
        link_up: bool,
        boot_order: Option<u32>,
        live_boot_order: Option<u32>,
        config: bool,
        live: bool,
    },
    Boot { order: Vec<String> },
    Autostart { on: bool },
    Description { text: String },
    Rename { name: String },
    UpdateDisk {
        target: String,
        new_target: Option<String>,
        bus: Option<String>,
        cache: Option<String>,
    },
    UpdateNicHardware {
        mac: String,
        new_mac: Option<String>,
        model: Option<String>,
    },
    Firmware { efi: bool, secure_boot: bool },
    Display {
        graphics: Option<String>,
        listen: Option<String>,
        video: Option<String>,
    },
    AddDevice { device: VirtHwNewDevice },
    RemoveDevice { key: String },
    RevertLive {
        live_xml: String,
    },
}

#[frb(mirror(VirtHwNewDevice))]
pub enum _VirtHwNewDevice {
    Tpm { model: String },
    Usb {
        vendor: Option<String>,
        product: Option<String>,
        bus: Option<u32>,
        device: Option<u32>,
    },
    Pci { address: String },
}

#[frb(mirror(VirtHwOutcome))]
pub struct _VirtHwOutcome {
    pub live_error: Option<String>,
    pub volume_kept: bool,
}

#[frb(mirror(VirtCiIpv4))]
pub struct _VirtCiIpv4 {
    pub address: String,
    pub gateway: Option<String>,
}

#[frb(mirror(VirtCiNetwork))]
pub struct _VirtCiNetwork {
    pub mac: String,
    pub ipv4: Option<VirtCiIpv4>,
    pub dns: Vec<String>,
    pub search: Vec<String>,
}

#[frb(mirror(VirtCloudInit))]
pub struct _VirtCloudInit {
    pub user: String,
    pub password_hash: Option<String>,
    pub ssh_keys: Vec<String>,
    pub hostname: String,
    pub instance_id: String,
    pub network: Option<VirtCiNetwork>,
    pub extra_networks: Vec<VirtCiNetwork>,
    pub password_expire: bool,
}

#[frb(mirror(VirtSeedRead))]
pub struct _VirtSeedRead {
    pub cloud_init: VirtCloudInit,
    pub foreign: bool,
    pub revision: String,
}

#[frb(mirror(VirtNetIpv4))]
pub struct _VirtNetIpv4 {
    pub address: String,
    pub prefix: u8,
    pub dhcp_start: Option<String>,
    pub dhcp_end: Option<String>,
}

#[frb(mirror(VirtResourceOp))]
pub enum _VirtResourceOp {
    PoolCreate {
        name: String,
        pool_type: String,
        target: Option<String>,
        source: Option<String>,
        autostart: bool,
    },
    PoolStart { name: String },
    PoolStop { name: String },
    PoolAutostart { name: String, on: bool },
    PoolRefresh { name: String },
    PoolDelete {
        name: String,
        active: bool,
        delete_storage: bool,
    },
    VolCreate {
        pool: String,
        name: String,
        bytes: u64,
        format: String,
    },
    VolDelete { pool: String, name: String },
    VolResize { pool: String, name: String, bytes: u64 },
    VolClone {
        pool: String,
        name: String,
        new_name: String,
    },
    NetCreate {
        name: String,
        mode: String,
        bridge: Option<String>,
        ipv4: Option<VirtNetIpv4>,
        autostart: bool,
    },
    NetStart { name: String },
    NetStop { name: String },
    NetAutostart { name: String, on: bool },
    NetDelete { name: String },
}

