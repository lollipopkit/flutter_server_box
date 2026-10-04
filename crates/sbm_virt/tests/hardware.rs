//! `sbm_virt::hardware`: what a change to a guest's hardware or settings is
//! refused for before anything is sent ([`issue`]), the helpers those rules
//! are made of, and the wire shape of a change.
//!
//! Ported from the app's `test/unit/virt/virt_hardware_test.dart`. Unlike
//! the Dart rules these also refuse what the host does not offer
//! (`NotOffered`) and what names a disk, NIC, pool, volume or network that
//! is not there (`NotFound`), so the guest below offers what each case
//! asks for, and the listing has what it names.

use sbm_virt::create::VolumeRef;
use sbm_virt::hardware::*;
use sbm_virt::model::{GuestKind, HostKind};
use sbm_virt::resource::{GuestRef, Network, Pool, Volume};
use serde_json::json;

/// A running VM with a 1 GiB disk `vda`, a NIC `n`, an empty CD-ROM `hdc`,
/// two threads per core, on a host of 8 CPUs and 4 GiB.
fn vm() -> Hardware {
    Hardware {
        kind: GuestKind::Qemu,
        running: true,
        cpu: Cpu { sockets: 1, cores: 2, threads: 2, online: None, cpu_type: None },
        memory: Memory { mib: 1024, min_mib: Some(512), balloon: true, swap_mib: None },
        disks: vec![
            HwDisk {
                key: "vda".into(),
                kind: DiskKind::Disk,
                source: Some("/var/lib/libvirt/images/a.qcow2".into()),
                size: Some(1 << 30),
                storage: None,
                mount_point: None,
                bus: Some("virtio".into()),
                format: Some("qcow2".into()),
                readonly: false,
                cache: None,
                cloud_init: false,
                resizable: true,
            },
            HwDisk {
                key: "hdc".into(),
                kind: DiskKind::Cdrom,
                source: None,
                size: None,
                storage: None,
                mount_point: None,
                bus: Some("ide".into()),
                format: None,
                readonly: true,
                cache: None,
                cloud_init: false,
                resizable: false,
            },
        ],
        nics: vec![HwNic { key: "n".into(), mac: Some("52:54:00:00:00:01".into()), ..HwNic::default() }],
        boot: Some(vec!["vda".into()]),
        autostart: false,
        name: Some("web".into()),
        description: None,
        protection: None,
        rename_running: true,
        pending: Vec::new(),
        revision: Some("<graphics type='vnc' passwd='s3cret'/>".into()),
        limits: Limits { host_cpus: Some(8), host_memory_bytes: Some(4 << 30) },
        cpu_types: Vec::new(),
        config_text: Some("<graphics type='vnc' passwd='s3cret'/>".into()),
        firmware: Some(Firmware::default()),
        display: Some(Display::default()),
        devices: Vec::new(),
        support: Support {
            buses: vec!["virtio".into(), "sata".into()],
            caches: vec!["default".into(), "none".into()],
            nic_models: vec!["virtio".into(), "e1000".into()],
            mac: true,
            protocols: vec!["vnc".into()],
            listen: true,
            gpus: vec!["virtio".into(), "qxl".into()],
            uefi: true,
            secure_boot: true,
            tpm: true,
            usb: true,
            pci: true,
        },
    }
}

fn ct() -> Hardware {
    Hardware { kind: GuestKind::Lxc, ..vm() }
}

fn stopped() -> Hardware {
    Hardware { running: false, ..vm() }
}

fn pool() -> Pool {
    Pool {
        id: "images".into(),
        name: "images".into(),
        pool_type: "dir".into(),
        available: Some(10 << 30),
        active: true,
        ..Pool::default()
    }
}

fn pve_pool() -> Pool {
    Pool {
        id: "pve/local-lvm".into(),
        name: "local-lvm".into(),
        node: Some("pve".into()),
        pool_type: "lvmthin".into(),
        active: true,
        content: vec!["images".into(), "rootdir".into()],
        ..Pool::default()
    }
}

fn network() -> Network {
    Network { id: "default".into(), name: "default".into(), mode: "nat".into(), ..Network::default() }
}

fn iso() -> Volume {
    Volume { id: "a.iso".into(), name: "a.iso".into(), path: Some("/iso/a.iso".into()), format: Some("raw".into()), ..Volume::default() }
}

fn disk_volume() -> Volume {
    Volume { id: "data.qcow2".into(), name: "data.qcow2".into(), format: Some("qcow2".into()), ..Volume::default() }
}

struct Host {
    pools: Vec<Pool>,
    networks: Vec<Network>,
    volumes: Vec<Volume>,
}

impl Host {
    fn new() -> Self {
        Host { pools: vec![pool(), pve_pool()], networks: vec![network()], volumes: vec![iso(), disk_volume()] }
    }

    fn list(&self) -> Listing<'_> {
        Listing { pools: &self.pools, networks: &self.networks, volumes: &self.volumes }
    }
}

fn check(hw: &Hardware, change: Change) -> Option<Issue> {
    issue(hw, &change, HostKind::Libvirt, Host::new().list())
}

fn check_on(hw: &Hardware, change: Change, host: HostKind) -> Option<Issue> {
    issue(hw, &change, host, Host::new().list())
}

fn cpu(sockets: u32, cores: u32, online: Option<u32>) -> Change {
    Change::SetCpu { sockets, cores, online, cpu_type: None }
}

fn mem(mib: u64, min_mib: Option<u64>, swap_mib: Option<u64>) -> Change {
    Change::SetMemory { mib, min_mib, swap_mib }
}

fn add_disk(pool: &str, gib: u64, mount_point: Option<&str>) -> Change {
    Change::AddDisk { pool: pool.into(), gib, mount_point: mount_point.map(Into::into) }
}

fn r(pool: &str, volume: &str) -> VolumeRef {
    VolumeRef { pool: pool.into(), volume: volume.into() }
}

#[test]
fn cpus_at_least_one_no_more_than_the_host_has() {
    let hw = vm();
    assert_eq!(check(&hw, cpu(2, 2, None)), None);
    // Threads are kept: 2 × 3 × 2 = 12 > 8.
    assert_eq!(check(&hw, cpu(2, 3, None)), Some(Issue::CpuCount));
    assert_eq!(check(&hw, cpu(0, 2, None)), Some(Issue::CpuCount));
    assert_eq!(check(&hw, cpu(1, 0, None)), Some(Issue::CpuCount));
    assert_eq!(check(&hw, cpu(1, 2, Some(5))), Some(Issue::CpuOnline));
    assert_eq!(check(&hw, cpu(1, 2, Some(0))), Some(Issue::CpuOnline));
    assert_eq!(check(&hw, cpu(1, 2, Some(4))), None);
    // The host's CPUs unknown: no upper limit but a sane one.
    let unknown = Hardware { limits: Limits::default(), ..vm() };
    assert_eq!(check(&unknown, cpu(4, 16, None)), None);
    assert_eq!(check(&unknown, cpu(64, 64, None)), Some(Issue::CpuCount));
    // Past what a u32 holds: refused, not wrapped round to a small count.
    assert_eq!(check(&unknown, cpu(65536, 65536, None)), Some(Issue::CpuCount));
}

#[test]
fn a_cpu_model_is_pves_and_one_the_node_offers() {
    let typed = |t: &str| Change::SetCpu { sockets: 1, cores: 2, online: None, cpu_type: Some(t.into()) };
    let hw = Hardware { cpu_types: vec!["host".into(), "x86-64-v3".into()], ..vm() };
    assert_eq!(check_on(&hw, typed("host"), HostKind::Pve), None);
    assert_eq!(check_on(&hw, typed("kvm32"), HostKind::Pve), Some(Issue::NotOffered));
    // The node would not say: whatever is asked goes to PVE to judge.
    assert_eq!(check_on(&vm(), typed("kvm32"), HostKind::Pve), None);
    assert_eq!(check_on(&hw, typed("host"), HostKind::Libvirt), Some(Issue::NotOffered));
}

#[test]
fn memory_within_the_host_a_floor_under_it_swap_a_containers() {
    let hw = vm();
    assert_eq!(check(&hw, mem(2048, Some(1024), None)), None);
    assert_eq!(check(&hw, mem(8, Some(4), None)), Some(Issue::Memory));
    assert_eq!(check(&hw, mem(MIN_MEMORY_MIB, None, None)), None);
    assert_eq!(check(&hw, mem(5000, None, None)), Some(Issue::Memory));
    assert_eq!(check(&hw, mem(4096, None, None)), None);
    // Bytes that do not fit a u64 are more than the host has, not fewer.
    assert_eq!(check(&hw, mem(1 << 44, None, None)), Some(Issue::Memory));
    assert_eq!(check(&hw, mem(u64::MAX, None, None)), Some(Issue::Memory));
    assert_eq!(check(&hw, mem(1024, Some(2048), None)), Some(Issue::MemoryMin));
    // Swap is a container's; a negative one cannot be said at all.
    assert_eq!(check(&hw, mem(1024, None, Some(0))), Some(Issue::Unsupported));
    assert_eq!(check(&ct(), mem(1024, None, Some(0))), None);
}

#[test]
fn disks_only_grow_and_fit_the_storage() {
    let hw = vm();
    let grow = |key: &str, bytes: u64| Change::GrowDisk { key: key.into(), bytes };
    assert_eq!(check(&hw, grow("vda", 2 << 30)), None);
    assert_eq!(check(&hw, grow("vda", 1 << 30)), Some(Issue::DiskShrink));
    assert_eq!(check(&hw, grow("vdz", 2 << 30)), Some(Issue::DiskSize));
    assert_eq!(check(&hw, grow("vda", (1 << 50) + 1)), Some(Issue::DiskSize));
    assert_eq!(check(&hw, add_disk("images", 10, None)), None);
    assert_eq!(check(&hw, add_disk("images", 11, None)), Some(Issue::StorageSpace));
    assert_eq!(check(&hw, add_disk("images", 0, None)), Some(Issue::DiskSize));
    assert_eq!(check(&hw, add_disk("images", 65537, None)), Some(Issue::DiskSize));
    assert_eq!(check(&hw, add_disk("gone", 1, None)), Some(Issue::NotFound));
}

#[test]
fn a_disk_on_a_block_device_or_without_a_way_to_grow_is_not_grown() {
    let mut hw = vm();
    assert!(disk_growable(&hw.disks[0]));
    hw.disks[0].source = Some("/dev/vg0/root".into());
    assert!(!disk_growable(&hw.disks[0]));
    assert_eq!(check(&hw, Change::GrowDisk { key: "vda".into(), bytes: 2 << 30 }), Some(Issue::DiskSize));
    let mut hw = vm();
    hw.disks[0].resizable = false;
    assert!(!disk_growable(&hw.disks[0]));
}

#[test]
fn a_new_disk_goes_where_the_host_makes_disks() {
    let hw = vm();
    // PVE: on the guest's node, with the content its kind needs.
    assert_eq!(check_on(&hw, add_disk("pve/local-lvm", 1, None), HostKind::Pve), None);
    let mut host = Host::new();
    host.pools[1].content = vec!["iso".into()];
    let list = host.list();
    assert_eq!(issue(&hw, &add_disk("pve/local-lvm", 1, None), HostKind::Pve, list), Some(Issue::NotOffered));
    // libvirt: an active pool of a kind that makes volumes.
    let mut host = Host::new();
    host.pools[0].active = false;
    assert_eq!(issue(&hw, &add_disk("images", 1, None), HostKind::Libvirt, host.list()), Some(Issue::NotOffered));
}

#[test]
fn a_mount_point_absolute_nothing_pve_would_read_as_another_option() {
    let ct = ct();
    let mp = |path: Option<&str>| check_on(&ct, add_disk("pve/local-lvm", 1, path), HostKind::Pve);
    assert_eq!(mp(Some("/srv/data")), None);
    for bad in [None, Some(""), Some("/"), Some("srv"), Some("/srv/"), Some("/a,backup=1"), Some("/a=b"), Some("/a b"), Some("//")] {
        assert_eq!(mp(bad), Some(Issue::MountPoint), "{bad:?}");
    }
    // A VM's disk has none.
    assert_eq!(check(&vm(), add_disk("images", 1, None)), None);
    assert!(mount_point_ok("/a"));
    assert!(!mount_point_ok("/a\tb"));
}

#[test]
fn an_attached_volume_is_one_nothing_else_uses() {
    let hw = vm();
    let attach = |v: &str| Change::AttachVolume { volume: r("images", v), mount_point: None };
    assert_eq!(check(&hw, attach("data.qcow2")), None);
    assert_eq!(check(&hw, attach("gone.qcow2")), Some(Issue::NotFound));
    let mut host = Host::new();
    host.volumes[1].users.push(GuestRef { guest_id: Some("other".into()), ..GuestRef::default() });
    assert_eq!(issue(&hw, &attach("data.qcow2"), HostKind::Libvirt, host.list()), Some(Issue::VolumeInUse));
    // A base image another volume is made on.
    let mut host = Host::new();
    host.volumes[1].backs.push("/var/lib/libvirt/images/overlay.qcow2".into());
    assert_eq!(issue(&hw, &attach("data.qcow2"), HostKind::Libvirt, host.list()), Some(Issue::VolumeInUse));
    // One the guest has already: a second disk on the same volume.
    let mut host = Host::new();
    host.volumes[1].path = hw.disks[0].source.clone();
    assert_eq!(issue(&hw, &attach("data.qcow2"), HostKind::Libvirt, host.list()), Some(Issue::VolumeInUse));
    // A container's needs a mount point.
    let ct_attach = Change::AttachVolume { volume: r("images", "data.qcow2"), mount_point: None };
    assert_eq!(check(&ct(), ct_attach), Some(Issue::MountPoint));
}

#[test]
fn media_is_install_media_in_a_cdrom_drive() {
    let hw = vm();
    let set = |key: &str, media: Option<VolumeRef>| Change::SetMedia { key: key.into(), media };
    assert_eq!(check(&hw, set("hdc", Some(r("images", "a.iso")))), None);
    assert_eq!(check(&hw, set("hdc", None)), None);
    // A disk is not a drive for media; a drive not there is not one.
    assert_eq!(check(&hw, set("vda", None)), Some(Issue::NotFound));
    assert_eq!(check(&hw, set("hdd", None)), Some(Issue::NotFound));
    assert_eq!(check(&hw, set("hdc", Some(r("images", "data.qcow2")))), Some(Issue::Media));
    assert_eq!(check(&hw, set("hdc", Some(r("images", "gone.iso")))), Some(Issue::NotFound));
    // The cloud-init drive holds the guest's settings, not media.
    let mut seeded = vm();
    seeded.disks[1].cloud_init = true;
    assert_eq!(check(&seeded, set("hdc", None)), Some(Issue::NotFound));
    assert_eq!(check(&hw, Change::AddCdrom { media: None }), None);
    assert_eq!(check(&hw, Change::AddCdrom { media: Some(r("images", "data.qcow2")) }), Some(Issue::Media));
    assert_eq!(check(&ct(), Change::AddCdrom { media: None }), Some(Issue::Unsupported));
}

#[test]
fn nics_and_disks_named_are_there() {
    let hw = vm();
    assert_eq!(check(&hw, Change::RemoveDisk { key: "vda".into(), delete_volume: true }), None);
    assert_eq!(check(&hw, Change::RemoveDisk { key: "vdz".into(), delete_volume: false }), Some(Issue::NotFound));
    assert_eq!(check(&hw, Change::RemoveNic { key: "n".into() }), None);
    assert_eq!(check(&hw, Change::RemoveNic { key: "m".into() }), Some(Issue::NotFound));
    assert_eq!(check(&hw, Change::AddNic { network: "default".into(), model: None }), None);
    assert_eq!(check(&hw, Change::AddNic { network: "default".into(), model: Some("e1000".into()) }), None);
    assert_eq!(check(&hw, Change::AddNic { network: "default".into(), model: Some("pcnet".into()) }), Some(Issue::NotOffered));
    assert_eq!(check(&hw, Change::AddNic { network: "gone".into(), model: None }), Some(Issue::NotFound));
    let update = |key: &str, network: Option<&str>, firewall: Option<bool>| Change::UpdateNic {
        key: key.into(),
        network: network.map(Into::into),
        link_up: true,
        firewall,
    };
    assert_eq!(check(&hw, update("n", Some("default"), None)), None);
    assert_eq!(check(&hw, update("n", Some("gone"), None)), Some(Issue::NotFound));
    assert_eq!(check(&hw, update("m", None, None)), Some(Issue::NotFound));
    // A firewall per interface is PVE's.
    assert_eq!(check(&hw, update("n", None, Some(true))), Some(Issue::Unsupported));
    assert_eq!(check_on(&hw, update("n", None, Some(true)), HostKind::Pve), None);
}

#[test]
fn a_name_the_host_takes_libvirt_renames_only_a_stopped_guest() {
    let hw = vm();
    let name = |n: &str| Change::SetName { name: n.into() };
    assert_eq!(check_on(&hw, name("web-02"), HostKind::Pve), None);
    // An underscore: libvirt's, not a DNS name.
    assert_eq!(check_on(&hw, name("web_02"), HostKind::Pve), Some(Issue::NameInvalid));
    let libvirt = Hardware { rename_running: false, ..vm() };
    assert_eq!(check_on(&libvirt, name("web_02"), HostKind::Libvirt), Some(Issue::NameRunning));
    let off = Hardware { running: false, ..libvirt };
    assert_eq!(check_on(&off, name("web_02"), HostKind::Libvirt), None);
    assert_eq!(check_on(&hw, name("-x"), HostKind::Libvirt), Some(Issue::NameInvalid));
}

#[test]
fn a_note_lines_and_tabs_no_other_control_characters_bounded() {
    let hw = vm();
    let note = |t: String| check(&hw, Change::SetDescription { text: t });
    assert_eq!(note("a\n\tb".into()), None);
    assert_eq!(note(String::new()), None);
    assert_eq!(note("a\u{7}b".into()), Some(Issue::Description));
    assert_eq!(note("x".repeat(DESCRIPTION_MAX + 1)), Some(Issue::Description));
    assert_eq!(note("x".repeat(DESCRIPTION_MAX)), None);
    // UTF-8 bytes: 2731 CJK characters are 8193 bytes; 2730 are 8190.
    assert_eq!(note("注".repeat(2731)), Some(Issue::Description));
    assert_eq!(note("注".repeat(2730)), None);
    // DEL and C1 controls.
    for c in ['\u{7f}', '\u{80}', '\u{9f}'] {
        assert_eq!(note(format!("a{c}b")), Some(Issue::Description), "{:x}", c as u32);
    }
    assert_eq!(note("a\u{a0}é~b".into()), None);
    assert!(!description_ok("a\r\n"));
}

#[test]
fn a_boot_order_needs_a_device_this_guest_has() {
    let hw = vm();
    let boot = |o: &[&str]| Change::SetBoot { order: o.iter().map(|s| (*s).to_owned()).collect() };
    assert_eq!(check(&hw, boot(&[])), Some(Issue::BootEmpty));
    assert_eq!(check(&hw, boot(&["vda"])), None);
    assert_eq!(check(&hw, boot(&["hdc", "vda", "n"])), None);
    assert_eq!(check(&hw, boot(&["vdz"])), Some(Issue::NotFound));
    // A container has no order to set.
    let ct = Hardware { boot: None, ..ct() };
    assert_eq!(check(&ct, boot(&["vda"])), Some(Issue::Unsupported));
}

#[test]
fn a_mac_unicast_six_octets_not_all_zero() {
    let hw = vm();
    let mac = |m: &str| check(&hw, Change::SetNicHardware { key: "n".into(), model: None, mac: Some(m.into()) });
    assert_eq!(mac("52:54:00:12:34:56"), None);
    assert_eq!(mac("BC:24:11:AA:BB:CC"), None);
    assert_eq!(mac("01:00:5e:00:00:01"), Some(Issue::Mac), "multicast");
    assert_eq!(mac("00:00:00:00:00:00"), Some(Issue::Mac));
    assert_eq!(mac("52:54:00:12:34"), Some(Issue::Mac));
    assert_eq!(mac("52-54-00-12-34-56"), Some(Issue::Mac));
    assert_eq!(mac("52:54:00:12:34:5g"), Some(Issue::Mac));
    assert_eq!(mac("52:54:00:12:34:567"), Some(Issue::Mac));
    assert_eq!(check(&hw, Change::SetNicHardware { key: "n".into(), model: Some("e1000".into()), mac: None }), None);
    assert_eq!(check(&hw, Change::SetNicHardware { key: "n".into(), model: Some("pcnet".into()), mac: None }), Some(Issue::NotOffered));
    assert_eq!(check(&hw, Change::SetNicHardware { key: "m".into(), model: None, mac: None }), Some(Issue::NotFound));
    assert!(is_unicast_mac("02:00:00:00:00:00"));
    assert!(!is_unicast_mac("03:00:00:00:00:00"));
    assert!(!is_unicast_mac(""));
}

#[test]
fn a_bus_and_the_firmware_change_only_while_stopped() {
    let bus = Change::UpdateDisk { key: "vda".into(), bus: Some("sata".into()), cache: None };
    assert_eq!(check(&vm(), bus.clone()), Some(Issue::StopFirst));
    assert_eq!(check(&stopped(), bus), None);
    // The bus it is on already is no move.
    assert_eq!(check(&vm(), Change::UpdateDisk { key: "vda".into(), bus: Some("virtio".into()), cache: None }), None);
    // A cache mode waits for a restart instead: it is not refused.
    assert_eq!(check(&vm(), Change::UpdateDisk { key: "vda".into(), bus: None, cache: Some("none".into()) }), None);
    // What the host does not offer, and a disk not there.
    assert_eq!(check(&stopped(), Change::UpdateDisk { key: "vda".into(), bus: Some("ide".into()), cache: None }), Some(Issue::NotOffered));
    assert_eq!(check(&vm(), Change::UpdateDisk { key: "vda".into(), bus: None, cache: Some("unsafe".into()) }), Some(Issue::NotOffered));
    assert_eq!(check(&vm(), Change::UpdateDisk { key: "vdz".into(), bus: None, cache: None }), Some(Issue::NotFound));

    let uefi = Change::SetFirmware { uefi: true, secure_boot: false, storage: None };
    assert_eq!(check(&vm(), uefi.clone()), Some(Issue::StopFirst));
    assert_eq!(check_on(&stopped(), uefi.clone(), HostKind::Libvirt), None);
    // PVE puts the variables on a storage: one is needed, unless the guest
    // has one already.
    assert_eq!(check_on(&stopped(), uefi.clone(), HostKind::Pve), Some(Issue::StorageMissing));
    let on = |s: &str| Change::SetFirmware { uefi: true, secure_boot: false, storage: Some(s.into()) };
    assert_eq!(check_on(&stopped(), on("pve/local-lvm"), HostKind::Pve), None);
    assert_eq!(check_on(&stopped(), on("pve/gone"), HostKind::Pve), Some(Issue::NotFound));
    let has_vars = Hardware {
        firmware: Some(Firmware { uefi: true, secure_boot: false, vars_storage: Some("local-lvm".into()) }),
        ..stopped()
    };
    assert_eq!(check_on(&has_vars, uefi, HostKind::Pve), None);
    // BIOS needs no storage.
    assert_eq!(check_on(&stopped(), Change::SetFirmware { uefi: false, secure_boot: false, storage: None }, HostKind::Pve), None);
}

#[test]
fn firmware_the_host_offers() {
    let no_sb = Hardware { support: Support { secure_boot: false, ..vm().support }, ..stopped() };
    assert_eq!(check(&no_sb, Change::SetFirmware { uefi: true, secure_boot: true, storage: None }), Some(Issue::NotOffered));
    // BIOS asked for: Secure Boot goes with UEFI, whatever the flag says.
    assert_eq!(check(&no_sb, Change::SetFirmware { uefi: false, secure_boot: true, storage: None }), None);
    let no_uefi = Hardware { support: Support { uefi: false, ..vm().support }, ..stopped() };
    assert_eq!(check(&no_uefi, Change::SetFirmware { uefi: true, secure_boot: false, storage: None }), Some(Issue::NotOffered));
    assert_eq!(check(&no_uefi, Change::SetFirmware { uefi: false, secure_boot: false, storage: None }), None);
    // A container has none.
    let ct = Hardware { running: false, ..ct() };
    assert_eq!(check(&ct, Change::SetFirmware { uefi: false, secure_boot: false, storage: None }), Some(Issue::NotOffered));
}

#[test]
fn a_display_the_host_offers() {
    let hw = vm();
    let display = |protocol: Option<&str>, listen: Option<&str>, gpu: Option<&str>| Change::SetDisplay {
        protocol: protocol.map(Into::into),
        listen: listen.map(Into::into),
        gpu: gpu.map(Into::into),
    };
    assert_eq!(check(&hw, display(Some("vnc"), Some("0.0.0.0"), Some("qxl"))), None);
    assert_eq!(check(&hw, display(None, None, None)), None);
    assert_eq!(check(&hw, display(Some("spice"), None, None)), Some(Issue::NotOffered));
    assert_eq!(check(&hw, display(None, None, Some("cirrus"))), Some(Issue::NotOffered));
    let no_listen = Hardware { support: Support { listen: false, ..vm().support }, ..vm() };
    assert_eq!(check(&no_listen, display(None, Some("0.0.0.0"), None)), Some(Issue::NotOffered));
}

#[test]
fn devices_one_tpm_and_a_device_picked() {
    let hw = vm();
    let usb = |host: Option<HostDevice>, naming: UsbNaming| Change::AddDevice { kind: DeviceKind::Usb, host, storage: None, usb_naming: naming };
    assert_eq!(check(&hw, usb(None, UsbNaming::VendorProduct)), Some(Issue::Device));
    let bt = HostDevice { id: "0bda:b023".into(), label: "bt".into(), ..HostDevice::default() };
    assert_eq!(check(&hw, usb(Some(bt.clone()), UsbNaming::VendorProduct)), None);
    // By address: the host must have said where it sits, as each backend
    // writes the address.
    assert_eq!(check(&hw, usb(Some(bt.clone()), UsbNaming::Address)), Some(Issue::Device));
    let at = HostDevice { usb_bus: Some(1), usb_device: Some(4), ..bt.clone() };
    assert_eq!(check_on(&hw, usb(Some(at.clone()), UsbNaming::Address), HostKind::Libvirt), None);
    assert_eq!(check_on(&hw, usb(Some(at), UsbNaming::Address), HostKind::Pve), Some(Issue::Device));
    let mapped = HostDevice { id: "bt".into(), label: "bt".into(), mapping: true, ..HostDevice::default() };
    assert_eq!(check_on(&hw, usb(Some(mapped), UsbNaming::Address), HostKind::Pve), None);
    let no_usb = Hardware { support: Support { usb: false, ..vm().support }, ..vm() };
    assert_eq!(check(&no_usb, usb(Some(bt), UsbNaming::VendorProduct)), Some(Issue::NotOffered));
    let pci = Change::AddDevice {
        kind: DeviceKind::Pci,
        host: Some(HostDevice { id: "0000:01:00.0".into(), ..HostDevice::default() }),
        storage: None,
        usb_naming: UsbNaming::default(),
    };
    assert_eq!(check(&hw, pci.clone()), None);
    let no_pci = Hardware { support: Support { pci: false, ..vm().support }, ..vm() };
    assert_eq!(check(&no_pci, pci), Some(Issue::NotOffered));

    let tpm = |storage: Option<&str>| Change::AddDevice { kind: DeviceKind::Tpm, host: None, storage: storage.map(Into::into), usb_naming: UsbNaming::default() };
    assert_eq!(check_on(&hw, tpm(None), HostKind::Libvirt), None);
    assert_eq!(check_on(&hw, tpm(None), HostKind::Pve), Some(Issue::StorageMissing));
    assert_eq!(check_on(&hw, tpm(Some("pve/local-lvm")), HostKind::Pve), None);
    assert_eq!(check_on(&hw, tpm(Some("pve/gone")), HostKind::Pve), Some(Issue::NotFound));
    let with_tpm = Hardware { devices: vec![HwDevice { key: "tpm".into(), kind: DeviceKind::Tpm, detail: None, mapping: false }], ..vm() };
    assert!(with_tpm.has_tpm());
    assert_eq!(check_on(&with_tpm, tpm(None), HostKind::Libvirt), Some(Issue::Device));
    let no_tpm = Hardware { support: Support { tpm: false, ..vm().support }, ..vm() };
    assert_eq!(check_on(&no_tpm, tpm(None), HostKind::Libvirt), Some(Issue::NotOffered));

    assert_eq!(check(&with_tpm, Change::RemoveDevice { key: "tpm".into() }), None);
    assert_eq!(check(&hw, Change::RemoveDevice { key: "tpm".into() }), Some(Issue::NotFound));
}

#[test]
fn protection_and_a_pending_revert_are_pves() {
    let hw = vm();
    assert_eq!(check_on(&hw, Change::SetProtection { on: true }, HostKind::Pve), None);
    assert_eq!(check_on(&hw, Change::SetProtection { on: true }, HostKind::Libvirt), Some(Issue::Unsupported));
    assert_eq!(check_on(&hw, Change::Revert { keys: vec!["cores".into()] }, HostKind::Pve), None);
    assert_eq!(check_on(&hw, Change::Revert { keys: vec!["cores".into()] }, HostKind::Libvirt), Some(Issue::Unsupported));
    assert_eq!(check(&hw, Change::SetAutostart { on: true }), None);
}

#[test]
fn a_usb_address_as_each_backend_writes_it() {
    let d = HostDevice { id: "1a86:7523".into(), usb_bus: Some(2), usb_device: Some(7), usb_port: Some("1.2".into()), ..HostDevice::default() };
    assert!(d.has_address());
    assert_eq!(d.usb_address(HostKind::Libvirt).as_deref(), Some("2:7"));
    assert_eq!(d.usb_address(HostKind::Pve).as_deref(), Some("2-1.2"));
    let bus_only = HostDevice { usb_bus: Some(2), ..HostDevice::default() };
    assert!(!bus_only.has_address());
    assert_eq!(bus_only.usb_address(HostKind::Libvirt), None);
}

#[test]
fn a_refusal_is_unsupported_with_the_rule() {
    let e = refusal(Issue::StopFirst);
    assert_eq!(e.kind, sbm_virt::error::ErrorKind::Unsupported);
    assert_eq!(e.detail.as_deref(), Some(&sbm_virt::error::Detail::HardwareRefused { issue: Issue::StopFirst }));
    assert_eq!(conflict().kind, sbm_virt::error::ErrorKind::Conflict);
}

#[test]
fn a_change_on_the_wire() {
    let c = Change::SetCpu { sockets: 1, cores: 2, online: None, cpu_type: Some("host".into()) };
    assert_eq!(serde_json::to_value(&c).unwrap(), json!({"op": "set_cpu", "sockets": 1, "cores": 2, "online": null, "type": "host"}));
    // What a client leaves out is None.
    let read: Change = serde_json::from_value(json!({"op": "set_cpu", "sockets": 2, "cores": 4})).unwrap();
    assert_eq!(read, Change::SetCpu { sockets: 2, cores: 4, online: None, cpu_type: None });
    let read: Change = serde_json::from_value(json!({"op": "remove_disk", "key": "vda"})).unwrap();
    assert_eq!(read, Change::RemoveDisk { key: "vda".into(), delete_volume: false });
    let read: Change = serde_json::from_value(json!({
        "op": "add_device", "kind": "usb", "host": {"id": "0bda:b023", "label": "bt"}, "usb_naming": "address",
    }))
    .unwrap();
    assert!(matches!(read, Change::AddDevice { kind: DeviceKind::Usb, usb_naming: UsbNaming::Address, .. }));
    let read: Change = serde_json::from_value(json!({"op": "set_media", "key": "hdc", "media": {"pool": "p", "volume": "a.iso"}})).unwrap();
    assert_eq!(read, Change::SetMedia { key: "hdc".into(), media: Some(r("p", "a.iso")) });
    assert_eq!(serde_json::to_value(Change::SetAutostart { on: true }).unwrap(), json!({"op": "set_autostart", "on": true}));
    assert_eq!(serde_json::to_value(Issue::StopFirst).unwrap(), json!("stop_first"));
    assert!(serde_json::from_value::<Change>(json!({"op": "format_disk"})).is_err());
    // A line for an audit log: the op and what it names.
    assert_eq!(Change::RemoveNic { key: "net0".into() }.describe(), "remove_nic net0");
    assert_eq!(Change::SetName { name: "web".into() }.describe(), "set_name web");
    assert_eq!(Change::SetAutostart { on: true }.describe(), "set_autostart");
}

#[test]
fn hardware_round_trips_and_defaults_what_a_client_leaves_out() {
    let hw = vm();
    let back: Hardware = serde_json::from_value(serde_json::to_value(&hw).unwrap()).unwrap();
    assert_eq!(back, hw);
    let min: Hardware = serde_json::from_value(json!({
        "kind": "qemu", "running": false,
        "cpu": {"sockets": 1, "cores": 1}, "memory": {"mib": 512},
    }))
    .unwrap();
    assert_eq!(min.cpu.threads, 1);
    assert!(min.rename_running);
    assert!(min.disks.is_empty());
    let disk: HwDisk = serde_json::from_value(json!({"key": "vda", "kind": "disk"})).unwrap();
    assert!(disk.resizable);
    let nic: HwNic = serde_json::from_value(json!({"key": "net0"})).unwrap();
    assert!(nic.link_up);
    let devs: HostDevices = serde_json::from_value(json!({})).unwrap();
    assert!(devs.iommu);
}

#[test]
fn hardware_is_printed_without_the_revision_or_the_configuration() {
    let printed = format!("{:?}", vm());
    assert!(!printed.contains("s3cret"), "{printed}");
    assert!(printed.contains("Qemu"), "{printed}");
}

#[test]
fn the_libvirt_read_is_printed_without_its_definitions() {
    let secret = "<graphics type='vnc' passwd='s3cret'/>";
    let info = sbm_virt::libvirt::VirtHardwareInfo { config_xml: secret.into(), live_xml: secret.into(), ..Default::default() };
    let printed = format!("{info:?}");
    assert!(!printed.contains("s3cret"), "{printed}");
}

#[test]
fn a_cloud_init_edit_needs_a_way_in() {
    use sbm_virt::create::{CloudInit, Issue as CreateIssue};
    let state = CloudInitState { user: "debian".into(), password_set: true, revision: "1 2".into(), ..CloudInitState::default() };
    let edit = |ci: CloudInit, remove: bool| CloudInitEdit { values: ci, remove_password: remove, password_expires: false, revision: "1 2".into() };
    let keep = CloudInit { user: "debian".into(), hostname: Some("web".into()), ..CloudInit::default() };
    // The password set is kept: a way in.
    assert_eq!(cloud_init_edit_issue(&state, &edit(keep.clone(), false), HostKind::Pve), None);
    // Removed, with no key instead: none.
    assert_eq!(cloud_init_edit_issue(&state, &edit(keep.clone(), true), HostKind::Pve), Some(CreateIssue::CiCredentials));
    let keyed = CloudInit { ssh_keys: vec!["ssh-ed25519 AAAA me".into()], ..keep.clone() };
    assert_eq!(cloud_init_edit_issue(&state, &edit(keyed, true), HostKind::Pve), None);
    let no_password = CloudInitState { password_set: false, ..state.clone() };
    assert_eq!(cloud_init_edit_issue(&no_password, &edit(keep.clone(), false), HostKind::Pve), Some(CreateIssue::CiCredentials));
    // libvirt's seed names the host; PVE's uses the VM's name.
    let unnamed = CloudInit { hostname: None, ..keep };
    assert_eq!(cloud_init_edit_issue(&state, &edit(unnamed.clone(), false), HostKind::Libvirt), Some(CreateIssue::CiHostname));
    assert_eq!(cloud_init_edit_issue(&state, &edit(unnamed, false), HostKind::Pve), None);
}
