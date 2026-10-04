//! `sbm_virt::libvirt::hardware`: a domain's two definitions read as one
//! [`Hardware`], a [`Change`] as the [`VirtHwChange`] that makes it (made
//! from the read it names by revision, checked by the rules first), a
//! seed's cloud-init as the Settings view edits it, and the host's devices.
//!
//! Against the captures in `tests/fixtures/libvirt/` (libvirt 11.3).
//! Ported from the app's `test/unit/virt/libvirt_backend_test.dart` (the
//! hardware group); `changeJson`'s maps are the [`VirtHwChange`] values
//! here. Unlike the app, a change the rules refuse (a rename while running,
//! a TPM the host cannot back, a device not there) is refused here too.

use std::path::Path;

use sbm_virt::create::{CloudInit, VolumeRef};
use sbm_virt::error::{Detail, ErrorKind};
use sbm_virt::hardware::*;
use sbm_virt::libvirt::cloud_init::{self as ci, VirtCiIpv4, VirtCiNetwork, VirtCloudInit, VirtSeedRead};
use sbm_virt::libvirt::hardware::*;
use sbm_virt::libvirt::{
    self as virt, FirmwareDescriptor, VirtHardwareInfo, VirtHostDevices, VirtHostUsb, VirtHwChange, VirtHwHostdev, VirtHwNewDevice,
};
use sbm_virt::resource::{Network, Pool, Volume};

fn fixture(name: &str) -> String {
    let path = Path::new(env!("CARGO_MANIFEST_DIR")).join("tests/fixtures/libvirt").join(name);
    std::fs::read_to_string(&path).unwrap_or_else(|e| panic!("{name}: {e}"))
}

fn info(name: &str) -> VirtHardwareInfo {
    virt::parse_hardware(&fixture(name)).unwrap()
}

/// `sbhw-test`, captured running with 3 of 4 vCPUs online and 2 in the
/// persistent definition: the one change waiting for the next start.
fn running() -> VirtHardwareInfo {
    info("script_hardware_running.txt")
}

/// `sbhwb-test`: a q35 domain on a host with OVMF but no swtpm, a QEMU
/// without SPICE.
fn caps_stopped() -> VirtHardwareInfo {
    info("script_hardware_caps_stopped.txt")
}

struct Host {
    pools: Vec<Pool>,
    networks: Vec<Network>,
    volumes: Vec<Volume>,
}

impl Host {
    fn new() -> Self {
        Host {
            pools: vec![
                Pool { id: "images".into(), name: "images".into(), pool_type: "dir".into(), active: true, ..Pool::default() },
                Pool { id: "vg".into(), name: "vg".into(), pool_type: "logical".into(), active: true, ..Pool::default() },
            ],
            networks: vec![
                Network { id: "isolated".into(), name: "isolated".into(), mode: "isolated".into(), ..Network::default() },
                Network { id: "default".into(), name: "default".into(), mode: "nat".into(), ..Network::default() },
            ],
            volumes: vec![
                Volume { id: "a.iso".into(), name: "a.iso".into(), path: Some("/iso/a.iso".into()), format: Some("iso".into()), ..Volume::default() },
                // Listed without a path: nothing to put in a drive.
                Volume { id: "b.iso".into(), name: "b.iso".into(), format: Some("iso".into()), ..Volume::default() },
                Volume {
                    id: "data.qcow2".into(),
                    name: "data.qcow2".into(),
                    path: Some("/var/lib/libvirt/images/data.qcow2".into()),
                    format: Some("qcow2".into()),
                    ..Volume::default()
                },
                Volume { id: "raw.img".into(), name: "raw.img".into(), path: Some("/var/lib/libvirt/images/raw.img".into()), format: Some("unknown".into()), ..Volume::default() },
            ],
        }
    }

    fn list(&self) -> Listing<'_> {
        Listing { pools: &self.pools, networks: &self.networks, volumes: &self.volumes }
    }
}

fn r(volume: &str) -> VolumeRef {
    VolumeRef { pool: "images".into(), volume: volume.into() }
}

/// `change` made to `info` from its own read.
fn change(info: &VirtHardwareInfo, name: &str, c: Change) -> Result<VirtHwChange, sbm_virt::error::Error> {
    change_of(info, name, Some(&revision_of(info)), &c, Host::new().list())
}

fn made(info: &VirtHardwareInfo, name: &str, c: Change) -> VirtHwChange {
    change(info, name, c.clone()).unwrap_or_else(|e| panic!("{c:?}: {e:?}"))
}

fn refused(info: &VirtHardwareInfo, name: &str, c: Change) -> Option<Issue> {
    let e = change(info, name, c).expect_err("refused");
    assert_eq!(e.kind, ErrorKind::Unsupported, "{e:?}");
    match e.detail.as_deref() {
        Some(Detail::HardwareRefused { issue }) => Some(*issue),
        _ => None,
    }
}

// ---------------------------------------------------------------------------
// The read
// ---------------------------------------------------------------------------

#[test]
fn both_definitions_the_next_starts_and_what_differs_now() {
    let i = running();
    let hw = hardware_of(&i, Some("sbhw-test"));
    assert!(hw.running);
    assert_eq!(hw.kind, sbm_virt::model::GuestKind::Qemu);
    // No `<topology>`: libvirt gives each vCPU a socket of its own.
    assert_eq!((hw.cpu.sockets, hw.cpu.cores, hw.cpu.threads, hw.cpu.online), (4, 1, 1, Some(2)));
    assert_eq!((hw.memory.mib, hw.memory.min_mib, hw.memory.balloon), (512, Some(384), true));
    let vda = hw.disk("vda").unwrap();
    assert_eq!((vda.kind, vda.bus.as_deref(), vda.size), (DiskKind::Disk, Some("virtio"), Some(117_440_512)));
    assert_eq!(vda.source.as_deref(), Some("/var/lib/libvirt/images/sbhw-root.qcow2"));
    assert!(vda.resizable && disk_growable(vda));
    let cd = hw.disk("hdc").unwrap();
    assert_eq!((cd.kind, cd.source.as_deref(), cd.cloud_init), (DiskKind::Cdrom, None, false));
    let [nic] = hw.nics.as_slice() else { panic!("{:?}", hw.nics) };
    assert_eq!(
        (nic.key.as_str(), nic.nic_type.as_deref(), nic.source.as_deref(), nic.link_up),
        ("52:54:00:b9:34:c3", Some("network"), Some("default"), true)
    );
    assert_eq!(nic.firewall, None);
    assert_eq!(hw.boot, Some(vec!["vda".into()]));
    assert_eq!(hw.limits.host_cpus, Some(4));
    assert_eq!(hw.limits.host_memory_bytes, Some(4_016_000 * 1024));
    // What an edit is made from: a digest of the definition, never the
    // definition itself.
    let rev = hw.revision.as_deref().unwrap();
    assert_eq!(rev.len(), 64);
    assert!(rev.bytes().all(|b| b.is_ascii_hexdigit()));
    assert_eq!(rev, revision_of(&i));
    // Online vCPUs differ; the balloon's current size moves by itself and
    // is not a change.
    let [p] = hw.pending.as_slice() else { panic!("{:?}", hw.pending) };
    assert_eq!((p.key.as_str(), p.current.as_deref(), p.pending.as_deref(), p.delete), ("cpu", Some("3/4 (4×1×1)"), Some("2/4 (4×1×1)"), false));
}

#[test]
fn a_revision_follows_the_definition() {
    let i = running();
    let mut other = i.clone();
    other.config_xml.push(' ');
    assert_ne!(revision_of(&i), revision_of(&other));
    // The running definition is not what an edit is made from.
    let mut live = i.clone();
    live.live_xml.push(' ');
    assert_eq!(revision_of(&i), revision_of(&live));
}

#[test]
fn shut_off_one_definition_nothing_pending() {
    let hw = hardware_of(&info("script_hardware_stopped.txt"), None);
    assert!(!hw.running);
    assert!(hw.pending.is_empty());
    assert_eq!(hw.name, None);
}

#[test]
fn settings_as_read_the_domains_name_its_note_no_protection_a_rename_that_waits() {
    let i = VirtHardwareInfo { description: Some("the web tier".into()), ..running() };
    let hw = hardware_of(&i, Some("sbhw-test"));
    assert_eq!((hw.name.as_deref(), hw.description.as_deref(), hw.protection), (Some("sbhw-test"), Some("the web tier"), None));
    assert!(!hw.rename_running);
    assert!(!hw.autostart);
}

#[test]
fn the_definition_shown_carries_no_display_password() {
    // `dumpxml --security-info`, as the read makes it: the password is in
    // the definition a change is made from, never in what is shown.
    let raw = fixture("script_hardware_running.txt").replace("<graphics type='vnc' port='-1'", "<graphics type='vnc' passwd='s3cret' port='-1'");
    let i = virt::parse_hardware(&raw).unwrap();
    assert!(i.config_xml.contains("passwd='s3cret'"));
    let hw = hardware_of(&i, None);
    let text = hw.config_text.as_deref().unwrap();
    assert!(!text.contains("passwd="), "{text}");
    assert!(!text.contains("s3cret"));
    assert!(text.contains("<graphics type='vnc' port='-1'"));
    assert!(!hw.revision.as_deref().unwrap().contains("s3cret"));
    assert!(!format!("{hw:?}").contains("s3cret"));
    assert!(!serde_json::to_string(&hw).unwrap().contains("s3cret"));
}

#[test]
fn what_the_host_offers_comes_from_its_domcapabilities() {
    let hw = hardware_of(&caps_stopped(), None);
    let s = &hw.support;
    assert_eq!(s.buses, vec!["virtio", "scsi", "sata"]);
    assert_eq!(s.protocols, vec!["vnc"]);
    assert_eq!(s.gpus, vec!["virtio", "vga", "cirrus", "bochs", "none"]);
    // A secure loader but no descriptor with enrolled keys: a domain with
    // Secure Boot on would not start, so it is not offered.
    assert_eq!((s.uefi, s.secure_boot, s.tpm, s.usb, s.pci, s.listen, s.mac), (true, false, false, true, true, true, true));
    assert_eq!(hw.firmware, Some(Firmware { uefi: false, secure_boot: false, vars_storage: None }));
    let enrolled = VirtHardwareInfo {
        firmware: vec![
            FirmwareDescriptor { name: "60-edk2-x86_64-secure.json".into(), secure_boot: true, enrolled_keys: false },
            FirmwareDescriptor { name: "40-edk2-x86_64-secure-enrolled.json".into(), secure_boot: true, enrolled_keys: true },
        ],
        ..caps_stopped()
    };
    assert!(hardware_of(&enrolled, None).support.secure_boot);
    let d = hw.display.as_ref().unwrap();
    assert_eq!((d.protocol.as_deref(), d.listen.as_deref(), d.gpu.as_deref()), (Some("vnc"), Some("127.0.0.1"), Some("virtio")));
    // Without them: the common ground, and nothing the host may lack.
    let bare = support_of(None, &[], false);
    assert_eq!((bare.uefi, bare.secure_boot, bare.tpm, bare.usb, bare.pci), (false, false, false, false, false));
    assert_eq!(bare.buses, vec!["virtio", "scsi", "sata", "ide"]);
    assert_eq!(bare.protocols, vec!["vnc", "spice"]);
    // Secure Boot on already: it can be turned off whatever the host has.
    assert!(support_of(None, &[], true).secure_boot);
}

#[test]
fn a_cache_mode_changed_while_running_is_pending() {
    let hw = hardware_of(&info("script_hardware_caps_running.txt"), None);
    assert_eq!(hw.firmware, Some(Firmware { uefi: true, secure_boot: true, vars_storage: None }));
    let p = hw.pending.iter().find(|p| p.key == "sda").unwrap();
    assert_eq!((p.current.as_deref(), p.pending.as_deref()), (Some("sata writeback"), Some("sata none")));
    assert_eq!(hw.disk("sda").unwrap().cache.as_deref(), Some("none"));
}

#[test]
fn pending_what_each_definition_has_that_the_other_does_not() {
    let i = running();
    let mut config = i.config.clone();
    let live = i.live.clone().unwrap();
    // The next start: one disk fewer, a NIC down, another firmware and a
    // TPM.
    config.disks.retain(|d| d.target != "hdc");
    config.nics[0].link_up = false;
    config.efi = true;
    config.tpm = Some(virt::VirtHwTpm { model: "tpm-crb".into(), backend: "emulator".into(), version: Some("2.0".into()) });
    config.memory_kib = 1024 * 1024;
    config.boot = vec!["vda".into(), "52:54:00:b9:34:c3".into()];
    let pending = pending_of(&config, Some(&live));
    let by = |k: &str| pending.iter().find(|p| p.key == k).unwrap_or_else(|| panic!("{k}: {pending:?}"));
    assert!(by("hdc").delete);
    assert_eq!(by("hdc").current.as_deref(), Some("cdrom"));
    assert_eq!(by("52:54:00:b9:34:c3").pending.as_deref(), Some("network default virtio link down"));
    assert_eq!((by("firmware").current.as_deref(), by("firmware").pending.as_deref()), (Some("BIOS"), Some("UEFI")));
    assert_eq!(by("tpm").pending.as_deref(), Some("tpm"));
    assert_eq!(by("memory").pending.as_deref(), Some("1024 MiB"));
    assert_eq!(by("boot").pending.as_deref(), Some("vda, 52:54:00:b9:34:c3"));
    // Not running: nothing differs.
    assert!(pending_of(&config, None).is_empty());
}

// ---------------------------------------------------------------------------
// Changes
// ---------------------------------------------------------------------------

#[test]
fn changes_are_addressed_by_what_each_definition_has() {
    let i = running();
    let name = "sbhw-test";
    // A CD-ROM drive: IDE on `pc`, beside the one there is.
    assert_eq!(
        made(&i, name, Change::AddCdrom { media: None }),
        VirtHwChange::AddCdrom { target: "hda".into(), bus: "ide".into(), source: None }
    );
    assert_eq!(
        made(&i, name, Change::AddCdrom { media: Some(r("a.iso")) }),
        VirtHwChange::AddCdrom { target: "hda".into(), bus: "ide".into(), source: Some("/iso/a.iso".into()) }
    );
    // Media with no path to put in the drive.
    let e = change(&i, name, Change::AddCdrom { media: Some(r("b.iso")) }).unwrap_err();
    assert_eq!(e.kind, ErrorKind::Unsupported);
    assert_eq!(
        made(&i, name, Change::AddDisk { pool: "images".into(), gib: 2, mount_point: None }),
        // `hdc` is the CD-ROM's; a new disk takes the first disk's bus.
        VirtHwChange::AddDisk {
            pool: "images".into(),
            volume: "sbhw-test-vdb.qcow2".into(),
            gib: 2,
            format: "qcow2".into(),
            target: "vdb".into(),
            bus: "virtio".into(),
        }
    );
    // A pool of raw volumes only.
    assert!(matches!(
        made(&i, name, Change::AddDisk { pool: "vg".into(), gib: 2, mount_point: None }),
        VirtHwChange::AddDisk { ref volume, ref format, .. } if volume == "sbhw-test-vdb.img" && format == "raw"
    ));
    assert_eq!(
        made(&i, name, Change::AttachVolume { volume: r("data.qcow2"), mount_point: None }),
        VirtHwChange::AttachVolume {
            path: "/var/lib/libvirt/images/data.qcow2".into(),
            format: "qcow2".into(),
            target: "vdb".into(),
            bus: "virtio".into(),
        }
    );
    // What the pool could not tell is raw.
    assert!(matches!(
        made(&i, name, Change::AttachVolume { volume: r("raw.img"), mount_point: None }),
        VirtHwChange::AttachVolume { ref format, .. } if format == "raw"
    ));
    assert_eq!(
        made(&i, name, Change::RemoveDisk { key: "vda".into(), delete_volume: true }),
        VirtHwChange::RemoveDisk {
            target: "vda".into(),
            delete_path: Some("/var/lib/libvirt/images/sbhw-root.qcow2".into()),
            config: true,
            live: true,
        }
    );
    assert!(matches!(made(&i, name, Change::RemoveDisk { key: "vda".into(), delete_volume: false }), VirtHwChange::RemoveDisk { delete_path: None, .. }));
    // A CD-ROM's image is never deleted with it.
    assert!(matches!(made(&i, name, Change::RemoveDisk { key: "hdc".into(), delete_volume: true }), VirtHwChange::RemoveDisk { delete_path: None, .. }));
    // Ejecting an empty drive: nothing to do in either definition.
    assert_eq!(
        made(&i, name, Change::SetMedia { key: "hdc".into(), media: None }),
        VirtHwChange::SetMedia { target: "hdc".into(), source: None, config: false, live: false }
    );
    assert_eq!(
        made(&i, name, Change::SetMedia { key: "hdc".into(), media: Some(r("a.iso")) }),
        VirtHwChange::SetMedia { target: "hdc".into(), source: Some("/iso/a.iso".into()), config: true, live: true }
    );
    assert_eq!(
        made(&i, name, Change::UpdateNic { key: "52:54:00:b9:34:c3".into(), network: Some("isolated".into()), link_up: false, firewall: None }),
        VirtHwChange::UpdateNic {
            mac: "52:54:00:b9:34:c3".into(),
            kind: "network".into(),
            source: "isolated".into(),
            model: Some("virtio".into()),
            link_up: false,
            boot_order: None,
            live_boot_order: None,
            config: true,
            live: true,
        }
    );
    // The network it is on kept.
    assert!(matches!(
        made(&i, name, Change::UpdateNic { key: "52:54:00:b9:34:c3".into(), network: None, link_up: true, firewall: None }),
        VirtHwChange::UpdateNic { ref source, ref kind, .. } if source == "default" && kind == "network"
    ));
    let VirtHwChange::AddNic { kind, source, model, mac } = made(&i, name, Change::AddNic { network: "isolated".into(), model: None }) else {
        panic!("not add_nic")
    };
    assert_eq!((kind.as_str(), source.as_str(), model.as_str()), ("network", "isolated", "virtio"));
    assert!(mac.starts_with("52:54:00:") && is_unicast_mac(&mac), "{mac}");
    assert!(matches!(
        made(&i, name, Change::AddNic { network: "default".into(), model: Some("e1000".into()) }),
        VirtHwChange::AddNic { ref model, .. } if model == "e1000"
    ));
    assert_eq!(
        made(&i, name, Change::RemoveNic { key: "52:54:00:b9:34:c3".into() }),
        VirtHwChange::RemoveNic { mac: "52:54:00:b9:34:c3".into(), kind: Some("network".into()), live_kind: Some("network".into()) }
    );
    assert_eq!(
        made(&i, name, Change::GrowDisk { key: "vda".into(), bytes: 1 << 30 }),
        VirtHwChange::GrowDisk { target: "vda".into(), bytes: 1 << 30, path: Some("/var/lib/libvirt/images/sbhw-root.qcow2".into()), live: true }
    );
    assert_eq!(made(&i, name, Change::SetCpu { sockets: 2, cores: 2, online: Some(3), cpu_type: None }), VirtHwChange::Cpu { sockets: 2, cores: 2, current: Some(3) });
    assert_eq!(made(&i, name, Change::SetMemory { mib: 1024, min_mib: Some(512), swap_mib: None }), VirtHwChange::Memory { memory_mib: 1024, current_mib: Some(512) });
    assert_eq!(made(&i, name, Change::SetBoot { order: vec!["hdc".into(), "vda".into()] }), VirtHwChange::Boot { order: vec!["hdc".into(), "vda".into()] });
    assert_eq!(made(&i, name, Change::SetAutostart { on: true }), VirtHwChange::Autostart { on: true });

    // Settings: the note; libvirt has no protection, and no pending list.
    assert_eq!(made(&i, name, Change::SetDescription { text: "a & b".into() }), VirtHwChange::Description { text: "a & b".into() });
    assert_eq!(refused(&i, name, Change::Revert { keys: vec!["cpu".into()] }), Some(Issue::Unsupported));
    assert_eq!(refused(&i, name, Change::SetProtection { on: true }), Some(Issue::Unsupported));
    // A rename waits for the domain to stop.
    assert_eq!(refused(&i, name, Change::SetName { name: "sbhw-2".into() }), Some(Issue::NameRunning));
    let off = info("script_hardware_stopped.txt");
    assert_eq!(made(&off, "x", Change::SetName { name: "sbhw-2".into() }), VirtHwChange::Rename { name: "sbhw-2".into() });
}

#[test]
fn a_disk_grows_where_it_is_open() {
    let i = running();
    // The definition put another file at vda while it runs: `blockresize`
    // would grow the running, old one. The configured file, offline.
    let mut swapped = i.clone();
    swapped.config.disks.iter_mut().find(|d| d.target == "vda").unwrap().source = Some("/var/lib/libvirt/images/new.qcow2".into());
    assert_eq!(
        made(&swapped, "sbhw-test", Change::GrowDisk { key: "vda".into(), bytes: 1 << 30 }),
        VirtHwChange::GrowDisk { target: "vda".into(), bytes: 1 << 30, path: Some("/var/lib/libvirt/images/new.qcow2".into()), live: false }
    );
    // Stopped: offline, on the file.
    assert!(matches!(
        made(&info("script_hardware_stopped.txt"), "x", Change::GrowDisk { key: "vda".into(), bytes: 1 << 30 }),
        VirtHwChange::GrowDisk { live: false, path: Some(_), .. }
    ));
    // A disk with no file to `vol-resize` is not offered for growing.
    let mut by_ref = i.clone();
    let vda = by_ref.config.disks.iter_mut().find(|d| d.target == "vda").unwrap();
    vda.source_type = Some("volume".into());
    vda.source = Some("images/root".into());
    let hw = hardware_of(&by_ref, None);
    assert!(!disk_growable(hw.disk("vda").unwrap()));
    assert_eq!(refused(&by_ref, "sbhw-test", Change::GrowDisk { key: "vda".into(), bytes: 1 << 40 }), Some(Issue::DiskSize));
    assert_eq!(refused(&i, "sbhw-test", Change::GrowDisk { key: "vda".into(), bytes: 1 << 20 }), Some(Issue::DiskShrink));
}

#[test]
fn the_second_part_of_the_changes() {
    let i = caps_stopped();
    let name = "sbhwb-test";
    // q35: a new CD-ROM drive on SATA.
    assert_eq!(made(&i, name, Change::AddCdrom { media: None }), VirtHwChange::AddCdrom { target: "sda".into(), bus: "sata".into(), source: None });
    // Another bus is another name on it.
    assert_eq!(
        made(&i, name, Change::UpdateDisk { key: "vda".into(), bus: Some("sata".into()), cache: None }),
        VirtHwChange::UpdateDisk { target: "vda".into(), new_target: Some("sda".into()), bus: Some("sata".into()), cache: None }
    );
    // The same bus is no bus change.
    assert_eq!(
        made(&i, name, Change::UpdateDisk { key: "vda".into(), bus: Some("virtio".into()), cache: Some("none".into()) }),
        VirtHwChange::UpdateDisk { target: "vda".into(), new_target: None, bus: None, cache: Some("none".into()) }
    );
    // A bus the machine lacks: q35 has no IDE.
    assert_eq!(refused(&i, name, Change::UpdateDisk { key: "vda".into(), bus: Some("ide".into()), cache: None }), Some(Issue::NotOffered));
    assert_eq!(
        made(&i, name, Change::SetNicHardware { key: "52:54:00:5b:00:01".into(), model: None, mac: Some("BC:24:11:00:00:09".into()) }),
        VirtHwChange::UpdateNicHardware { mac: "52:54:00:5b:00:01".into(), new_mac: Some("bc:24:11:00:00:09".into()), model: None }
    );
    // BIOS asked for with the flag set: BIOS, on a host without Secure Boot.
    assert_eq!(made(&i, name, Change::SetFirmware { uefi: false, secure_boot: true, storage: None }), VirtHwChange::Firmware { efi: false, secure_boot: false });
    assert_eq!(made(&i, name, Change::SetFirmware { uefi: true, secure_boot: false, storage: None }), VirtHwChange::Firmware { efi: true, secure_boot: false });
    assert_eq!(refused(&i, name, Change::SetFirmware { uefi: true, secure_boot: true, storage: None }), Some(Issue::NotOffered));
    assert_eq!(
        made(&i, name, Change::SetDisplay { protocol: Some("vnc".into()), listen: Some("0.0.0.0".into()), gpu: Some("bochs".into()) }),
        VirtHwChange::Display { graphics: Some("vnc".into()), listen: Some("0.0.0.0".into()), video: Some("bochs".into()) }
    );
    assert_eq!(refused(&i, name, Change::SetDisplay { protocol: Some("spice".into()), listen: None, gpu: None }), Some(Issue::NotOffered));
    let bt = HostDevice { id: "0bda:b023".into(), label: "bt".into(), usb_bus: Some(1), usb_device: Some(4), ..HostDevice::default() };
    let usb = |naming: UsbNaming| Change::AddDevice { kind: DeviceKind::Usb, host: Some(bt.clone()), storage: None, usb_naming: naming };
    assert_eq!(
        made(&i, name, usb(UsbNaming::VendorProduct)),
        VirtHwChange::AddDevice { device: VirtHwNewDevice::Usb { vendor: Some("0bda".into()), product: Some("b023".into()), bus: None, device: None } }
    );
    assert_eq!(
        made(&i, name, usb(UsbNaming::Address)),
        VirtHwChange::AddDevice { device: VirtHwNewDevice::Usb { vendor: None, product: None, bus: Some(1), device: Some(4) } }
    );
    let pci = Change::AddDevice {
        kind: DeviceKind::Pci,
        host: Some(HostDevice { id: "0000:00:01.2".into(), ..HostDevice::default() }),
        storage: None,
        usb_naming: UsbNaming::default(),
    };
    assert_eq!(made(&i, name, pci), VirtHwChange::AddDevice { device: VirtHwNewDevice::Pci { address: "0000:00:01.2".into() } });
    // No swtpm on this host: no TPM to add.
    let tpm = Change::AddDevice { kind: DeviceKind::Tpm, host: None, storage: None, usb_naming: UsbNaming::default() };
    assert_eq!(refused(&i, name, tpm.clone()), Some(Issue::NotOffered));
    let mut swtpm = i.clone();
    swtpm.caps.as_mut().unwrap().tpm_emulator = true;
    assert_eq!(made(&swtpm, name, tpm), VirtHwChange::AddDevice { device: VirtHwNewDevice::Tpm { model: "tpm-crb".into() } });
    // A device it has, by its key.
    assert_eq!(refused(&i, name, Change::RemoveDevice { key: "pci:0000:00:01.2".into() }), Some(Issue::NotFound));
    let mut with_pci = i.clone();
    with_pci.config.hostdevs.push(VirtHwHostdev {
        key: "pci:0000:00:01.2".into(),
        kind: "pci".into(),
        address: Some("0000:00:01.2".into()),
        ..VirtHwHostdev::default()
    });
    let hw = hardware_of(&with_pci, None);
    assert_eq!(hw.devices[0].detail.as_deref(), Some("0000:00:01.2"));
    assert_eq!(made(&with_pci, name, Change::RemoveDevice { key: "pci:0000:00:01.2".into() }), VirtHwChange::RemoveDevice { key: "pci:0000:00:01.2".into() });
}

#[test]
fn a_device_given_by_address_or_id_is_shown_by_it() {
    let mut i = caps_stopped();
    i.config.hostdevs.push(VirtHwHostdev { key: "usb:0bda:b023".into(), kind: "usb".into(), vendor: Some("0bda".into()), product: Some("b023".into()), address: None });
    i.config.hostdevs.push(VirtHwHostdev { key: "usb@1.4".into(), kind: "usb".into(), ..VirtHwHostdev::default() });
    i.config.tpm = Some(virt::VirtHwTpm { model: "tpm-crb".into(), backend: "emulator".into(), version: Some("2.0".into()) });
    let hw = hardware_of(&i, None);
    let devices: Vec<(&str, DeviceKind, Option<&str>)> = hw.devices.iter().map(|d| (d.key.as_str(), d.kind, d.detail.as_deref())).collect();
    assert_eq!(
        devices,
        vec![("tpm", DeviceKind::Tpm, Some("tpm-crb · 2.0")), ("usb:0bda:b023", DeviceKind::Usb, Some("0bda:b023")), ("usb@1.4", DeviceKind::Usb, Some("1.4"))]
    );
    // A second TPM is refused.
    let mut swtpm = i.clone();
    swtpm.caps.as_mut().unwrap().tpm_emulator = true;
    let tpm = Change::AddDevice { kind: DeviceKind::Tpm, host: None, storage: None, usb_naming: UsbNaming::default() };
    assert_eq!(refused(&swtpm, "x", tpm), Some(Issue::Device));
}

#[test]
fn a_definition_changed_since_the_read_is_a_conflict() {
    let i = running();
    let c = Change::SetAutostart { on: true };
    for revision in [None, Some("<domain/>"), Some("0".repeat(64)).as_deref()] {
        let e = change_of(&i, "sbhw-test", revision, &c, Host::new().list()).unwrap_err();
        assert_eq!(e.kind, ErrorKind::Conflict, "{revision:?}");
    }
    // Checked before the rules: a stale read says so, whatever it asks.
    let e = change_of(&i, "sbhw-test", Some("stale"), &Change::SetProtection { on: true }, Host::new().list()).unwrap_err();
    assert_eq!(e.kind, ErrorKind::Conflict);
}

#[test]
fn names_that_are_not_there_are_not_found() {
    let i = running();
    for c in [
        Change::AddDisk { pool: "gone".into(), gib: 1, mount_point: None },
        Change::AttachVolume { volume: r("gone.qcow2"), mount_point: None },
        Change::AddNic { network: "gone".into(), model: None },
        Change::RemoveNic { key: "52:54:00:00:00:99".into() },
        Change::SetMedia { key: "hdc".into(), media: Some(r("gone.iso")) },
        Change::SetBoot { order: vec!["vdz".into()] },
    ] {
        assert_eq!(refused(&i, "sbhw-test", c.clone()), Some(Issue::NotFound), "{c:?}");
    }
    // A firewall per interface is PVE's.
    let c = Change::UpdateNic { key: "52:54:00:b9:34:c3".into(), network: None, link_up: true, firewall: Some(true) };
    assert_eq!(refused(&i, "sbhw-test", c), Some(Issue::Unsupported));
}

#[test]
fn discarding_the_pending_changes_writes_the_running_definition_back() {
    let i = running();
    assert_eq!(revert_of(&i, Some(&revision_of(&i))).unwrap(), VirtHwChange::RevertLive { live_xml: i.live_xml.clone() });
    assert!(!i.live_xml.is_empty());
    assert_eq!(revert_of(&i, Some("stale")).unwrap_err().kind, ErrorKind::Conflict);
    assert_eq!(revert_of(&i, None).unwrap_err().kind, ErrorKind::Conflict);
    // Shut off: nothing to revert to.
    let off = info("script_hardware_stopped.txt");
    assert_eq!(revert_of(&off, Some(&revision_of(&off))).unwrap_err().kind, ErrorKind::Unsupported);
}

// ---------------------------------------------------------------------------
// Cloud-init
// ---------------------------------------------------------------------------

const SEED_MAC: &str = "52:54:00:12:34:56";
const DOMAIN_MAC: &str = "52:54:00:90:2c:99";

/// What `seed_genisoimage.iso` says (`tests/cloud_init.rs`'s `captured`).
fn seed() -> VirtSeedRead {
    use base64::Engine;
    let iso = std::fs::read(Path::new(env!("CARGO_MANIFEST_DIR")).join("tests/fixtures/libvirt/seed_genisoimage.iso")).unwrap();
    let m = sbm_parser::script::cmd_marker;
    let raw = format!(
        "{}\n\n{rc}0\n{}\n4155283651 69632\n{rc}0\n{}\n{}\n{rc}0\n",
        m(ci::KEY_SEED_READ),
        m(ci::KEY_SEED_SUM),
        m(ci::KEY_SEED_DATA),
        base64::engine::general_purpose::STANDARD.encode(iso),
        rc = virt::RC_PREFIX,
    );
    ci::parse_seed_read(&raw).unwrap()
}

fn old_hash() -> String {
    ci::sha512_crypt("correct horse", "0123456789abcdef").unwrap()
}

#[test]
fn cloud_init_read_back_from_the_seed() {
    let read = seed();
    assert_eq!(read.cloud_init.password_hash.as_deref(), Some(old_hash().as_str()));
    let st = cloud_init_state_of(&read, &[DOMAIN_MAC.into()]);
    assert_eq!(st.user, "debian");
    assert_eq!(st.hostname.as_deref(), Some("sbx-web"));
    assert_eq!(st.ssh_keys.len(), 2);
    assert_eq!((st.address.as_deref(), st.gateway.as_deref()), (Some("10.231.80.5/24"), Some("10.231.80.1")));
    assert_eq!(st.dns, vec!["10.231.80.1", "2606:4700:4700::1111"]);
    assert_eq!(st.search_domains, vec!["lab.example"]);
    assert_eq!((st.password_set, st.password_expires, st.network, st.foreign, st.nics), (true, false, true, false, 1));
    assert_eq!(st.revision, "4155283651 69632");
    // The hash is not what the view gets.
    assert!(!format!("{st:?}").contains("$6$"));
    assert!(!serde_json::to_string(&st).unwrap().contains("$6$"));
    // A domain without NICs: nothing to give an address.
    assert!(!cloud_init_state_of(&read, &[]).network);
    // DHCP, no network-config at all.
    let mut dhcp = read.clone();
    dhcp.cloud_init.network = None;
    let st = cloud_init_state_of(&dhcp, &[DOMAIN_MAC.into()]);
    assert_eq!((st.address, st.gateway, st.nics), (None, None, 0));
    assert!(st.dns.is_empty());
}

fn edit(values: CloudInit, remove_password: bool) -> CloudInitEdit {
    CloudInitEdit { values, remove_password, password_expires: false, revision: "4155283651 69632".into() }
}

fn keyed(hostname: &str) -> CloudInit {
    CloudInit {
        user: "debian".into(),
        ssh_keys: vec!["ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAINEW new".into()],
        hostname: Some(hostname.into()),
        ..CloudInit::default()
    }
}

#[test]
fn cloud_init_written_anew_the_hash_kept_unless_removed_or_replaced() {
    let read = seed();
    // Saved without a new password: the seed's hash kept, a new hostname
    // and instance, the NIC the domain has (the seed's MAC is gone).
    let out = cloud_init_update(&read, "sbhw-test", &[DOMAIN_MAC.into()], &edit(keyed("sbx-new"), false)).unwrap();
    assert_eq!(out.password_hash.as_deref(), Some(old_hash().as_str()));
    assert_eq!(out.hostname, "sbx-new");
    assert_eq!(out.ssh_keys, vec!["ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAINEW new"]);
    assert_ne!(out.instance_id, read.cloud_init.instance_id);
    assert!(out.instance_id.starts_with("iid-sbhw-test-"), "{}", out.instance_id);
    let net = out.network.as_ref().unwrap();
    assert_eq!(net.mac, DOMAIN_MAC);
    // The form's values: DHCP, no DNS.
    assert_eq!((net.ipv4.as_ref(), net.dns.len()), (None, 0));

    // A new password: hashed here, the old hash gone.
    let new = CloudInit { password: Some("hunter2 new".into()), ..keyed("sbx-new") };
    let out = cloud_init_update(&read, "sbhw-test", &[DOMAIN_MAC.into()], &edit(new, false)).unwrap();
    let hash = out.password_hash.unwrap();
    assert!(hash.starts_with("$6$") && hash != old_hash(), "{hash}");
    assert!(!hash.contains("hunter2"));

    // Removed: keys only, no hash at all.
    let out = cloud_init_update(&read, "sbhw-test", &[DOMAIN_MAC.into()], &edit(keyed("sbx-new"), true)).unwrap();
    assert_eq!(out.password_hash, None);
    // Removed with none to log in with instead: refused.
    let bare = CloudInit { ssh_keys: Vec::new(), ..keyed("sbx-new") };
    let e = cloud_init_update(&read, "sbhw-test", &[DOMAIN_MAC.into()], &edit(bare.clone(), true)).unwrap_err();
    assert!(matches!(e.detail.as_deref(), Some(Detail::CreateRefused { issue: sbm_virt::create::Issue::CiCredentials })), "{e:?}");
    // Kept: a way in still.
    assert!(cloud_init_update(&read, "sbhw-test", &[DOMAIN_MAC.into()], &edit(bare, false)).is_ok());
    // The seed names its host.
    let unnamed = CloudInit { hostname: None, ..keyed("x") };
    assert!(cloud_init_update(&read, "sbhw-test", &[DOMAIN_MAC.into()], &edit(unnamed, false)).is_err());

    // An expiring password, as asked.
    let expiring = CloudInitEdit { password_expires: true, ..edit(keyed("sbx-new"), false) };
    assert!(cloud_init_update(&read, "sbhw-test", &[DOMAIN_MAC.into()], &expiring).unwrap().password_expire);
}

#[test]
fn cloud_init_the_nic_the_seed_names_while_the_domain_has_it() {
    let read = seed();
    let static_ip = CloudInit { address: Some("10.0.0.9/24".into()), gateway: Some("10.0.0.1".into()), dns: vec!["1.1.1.1".into()], ..keyed("web") };
    // The seed's NIC, second on the domain and written in capitals: still it.
    let macs = [DOMAIN_MAC.to_owned(), SEED_MAC.to_ascii_uppercase()];
    let out = cloud_init_update(&read, "web", &macs, &edit(static_ip.clone(), false)).unwrap();
    let net = out.network.unwrap();
    assert_eq!(net.mac, SEED_MAC);
    assert_eq!(net.ipv4, Some(VirtCiIpv4 { address: "10.0.0.9/24".into(), gateway: Some("10.0.0.1".into()) }));
    assert_eq!(net.dns, vec!["1.1.1.1"]);
    // No NIC at all: no network-config.
    let out = cloud_init_update(&read, "web", &[], &edit(static_ip, false)).unwrap();
    assert_eq!(out.network, None);
}

#[test]
fn cloud_init_the_seeds_other_nics_kept() {
    let mut read = seed();
    let second = VirtCiNetwork { mac: "52:54:00:00:00:02".into(), ipv4: None, dns: vec!["9.9.9.9".into()], search: Vec::new() };
    read.cloud_init.extra_networks = vec![second.clone()];
    let st = cloud_init_state_of(&read, &[SEED_MAC.into(), "52:54:00:00:00:02".into()]);
    assert_eq!(st.nics, 2);
    let out = cloud_init_update(&read, "web", &[SEED_MAC.into(), "52:54:00:00:00:02".into()], &edit(keyed("web"), false)).unwrap();
    assert_eq!(out.network.unwrap().mac, SEED_MAC);
    assert_eq!(out.extra_networks, vec![second.clone()]);

    // The seed's first NIC gone, the domain's first one an extra the seed
    // has: the form's settings go to it, written once.
    let out = cloud_init_update(&read, "web", &["52:54:00:00:00:02".into()], &edit(keyed("web"), false)).unwrap();
    assert_eq!(out.network.as_ref().unwrap().mac, "52:54:00:00:00:02");
    assert!(out.extra_networks.is_empty(), "{:?}", out.extra_networks);
}

#[test]
fn cloud_init_from_another_read_is_a_conflict() {
    let read = seed();
    let stale = CloudInitEdit { revision: "1 1".into(), ..edit(keyed("x"), false) };
    let e = cloud_init_update(&read, "web", &[DOMAIN_MAC.into()], &stale).unwrap_err();
    assert_eq!(e.kind, ErrorKind::Conflict);
}

#[test]
fn cloud_init_a_seed_saying_more_than_the_app_writes_is_foreign() {
    let read = VirtSeedRead { foreign: true, ..seed() };
    assert!(cloud_init_state_of(&read, &[]).foreign);
    let _: VirtCloudInit = cloud_init_update(&read, "web", &[], &edit(keyed("web"), false)).unwrap();
}

// ---------------------------------------------------------------------------
// Host devices
// ---------------------------------------------------------------------------

#[test]
fn host_devices_root_hubs_left_out_no_iommu_said() {
    let devs = host_devices_of(&virt::parse_host_devices(&fixture("script_host_devices.txt")).unwrap());
    assert!(!devs.iommu);
    assert!(!devs.mappings_only);
    assert!(devs.usb.is_empty());
    let piix = devs.pci.iter().find(|p| p.id == "0000:00:01.2").unwrap();
    assert!(piix.label.contains("PIIX3 USB"), "{}", piix.label);
    assert_eq!(piix.detail.as_deref(), Some("0000:00:01.2"));
    assert_eq!((piix.iommu_group, piix.group_size), (None, 0));

    let hubs = VirtHostDevices {
        usb: vec![
            VirtHostUsb { vendor: "1d6b".into(), product: "0002".into(), ..VirtHostUsb::default() },
            VirtHostUsb { vendor: "0bda".into(), product: "b023".into(), product_name: Some("Bluetooth Radio".into()), bus: Some(1), device: Some(4), ..VirtHostUsb::default() },
            VirtHostUsb { vendor: "1a86".into(), product: "7523".into(), ..VirtHostUsb::default() },
        ],
        ..VirtHostDevices::default()
    };
    let devs = host_devices_of(&hubs);
    assert_eq!(devs.usb.iter().map(|d| (d.id.as_str(), d.label.as_str())).collect::<Vec<_>>(), vec![("0bda:b023", "Bluetooth Radio"), ("1a86:7523", "1a86:7523")]);
}

#[test]
fn host_devices_a_usb_device_carries_where_it_sits() {
    // `nodedev-dumpxml` of one device, as the host prints it.
    let raw = "SrvBoxSep.b64.dmlydC5ob3N0LnVzYg==
usb_device_1a86_7523_2_1_2
<device>
  <name>usb_device_1a86_7523_2_1_2</name>
  <capability type='usb_device'>
    <bus>2</bus>
    <device>7</device>
    <port>1.2</port>
    <product id='0x7523'>CH340 serial converter</product>
    <vendor id='0x1a86'>QinHeng Electronics</vendor>
  </capability>
</device>

SbVirtRc=0
";
    let devs = host_devices_of(&virt::parse_host_devices(raw).unwrap());
    let [d] = devs.usb.as_slice() else { panic!("{:?}", devs.usb) };
    assert_eq!((d.usb_bus, d.usb_device, d.usb_port.as_deref()), (Some(2), Some(7), Some("1.2")));
    assert_eq!(d.label, "QinHeng Electronics CH340 serial converter");
    // So it is offered by address, as libvirt writes one.
    assert!(d.has_address());
    assert_eq!(d.usb_address(sbm_virt::model::HostKind::Libvirt).as_deref(), Some("2:7"));
}

#[test]
fn a_revision_follows_the_run_too() {
    let read = running();
    let mut restarted = read.clone();
    let id = roxmltree::Document::parse(&read.live_xml).unwrap().root_element().attribute("id").unwrap().to_owned();
    restarted.live_xml = read.live_xml.replacen(&format!("id='{id}'"), "id='9999'", 1);
    assert_ne!(revision_of(&read), revision_of(&restarted), "another run, another revision");
    // A revert shown for one run is refused once the guest started again:
    // its running definition is another's.
    let e = revert_of(&restarted, Some(&revision_of(&read))).unwrap_err();
    assert_eq!(e.kind, ErrorKind::Conflict);
    assert!(revert_of(&restarted, Some(&revision_of(&restarted))).is_ok());
}
