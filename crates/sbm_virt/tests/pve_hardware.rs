//! A PVE guest's hardware, settings, cloud-init and host devices: the
//! configuration read ([`parse_hardware`], [`parse_cloud_init`]), the option
//! strings a change writes, and `pve::Client`'s requests against a scripted
//! PVE API — each request's form, the `digest` it carries, and what is
//! refused before anything is sent.
//!
//! The `hw_*`, `hardware_*` and `mapping_*` fixtures are PVE 9.2 captures
//! from the app's `test/fixtures/pve/`. Ported from the app's
//! `test/unit/virt/pve_backend_test.dart` (the hardware, cloud-init and
//! devices groups). Unlike the app, a change is checked against the guest
//! as the host has it now: a test that changes the guest changes the
//! configuration the fake answers with.

mod common;

use std::collections::BTreeMap;
use std::sync::atomic::{AtomicBool, Ordering};
use std::sync::Arc;
use std::time::Duration;

use common::*;
use sbm_virt::create::{CloudInit, VolumeRef};
use sbm_virt::error::{Detail, Error, ErrorKind};
use sbm_virt::hardware::*;
use sbm_virt::model::{Guest, GuestKind, GuestState};
use sbm_virt::pve::hardware::*;
use sbm_virt::pve::{Auth, Client, Config, Options};
use serde_json::{Map, Value, json};

fn config(name: &str) -> Map<String, Value> {
    fixture(name).as_object().unwrap().clone()
}

fn guest(id: &str, name: &str, kind: GuestKind, state: GuestState) -> Guest {
    Guest {
        id: id.into(),
        name: name.into(),
        kind,
        state,
        state_reason: None,
        vmid: Some(id.rsplit('/').next().unwrap().parse().unwrap()),
        node: Some("pve".into()),
        vcpu: None,
        mem_bytes: None,
        uptime: None,
        tags: Vec::new(),
        template: false,
        autostart: None,
        actions: Default::default(),
    }
}

fn vm() -> Guest {
    guest("qemu/9901", "sbhw-e2e-vm", GuestKind::Qemu, GuestState::Running)
}

fn ct() -> Guest {
    guest("lxc/9902", "sbhw-e2e-ct", GuestKind::Lxc, GuestState::Running)
}

/// The devices VM: stopped.
fn dev_vm() -> Guest {
    guest("qemu/9921", "sbhwb-probe", GuestKind::Qemu, GuestState::Stopped)
}

fn refused(e: &Error) -> Option<Issue> {
    match e.detail.as_deref() {
        Some(Detail::HardwareRefused { issue }) => Some(*issue),
        _ => None,
    }
}

const VM_DIGEST: &str = "698abb29c27485d3497f5b7a8ca4b6b2789c1cd1";
const DEV_DIGEST: &str = "de66321a9eb5428d8b8f0794d86b566667397191";

// ---------------------------------------------------------------------------
// The configuration read
// ---------------------------------------------------------------------------

/// Captured from PVE 9.2 with cores, memory and the boot order pending, a
/// hot-plugged NIC disconnected behind the firewall, and a CPU model with a
/// flag.
fn vm_hardware() -> Hardware {
    parse_hardware(
        &config("hw_vm_config.json"),
        &list("hw_vm_pending.json"),
        GuestKind::Qemu,
        true,
        Limits { host_cpus: Some(12), host_memory_bytes: Some(16 << 30) },
        Vec::new(),
    )
}

#[test]
fn a_vm_the_next_starts_values_and_what_is_pending() {
    let hw = vm_hardware();
    assert_eq!((hw.cpu.sockets, hw.cpu.cores, hw.cpu.cpu_type.as_deref()), (1, 2, Some("host")));
    assert_eq!(hw.cpu.online, None);
    assert_eq!((hw.memory.mib, hw.memory.min_mib, hw.memory.balloon), (768, Some(256), true));
    let scsi0 = hw.disk("scsi0").unwrap();
    assert_eq!((scsi0.size, scsi0.storage.as_deref(), scsi0.kind), (Some(1 << 30), Some("local-lvm"), DiskKind::Disk));
    assert_eq!(scsi0.source.as_deref(), Some("local-lvm:vm-9901-disk-0"));
    let ide2 = hw.disk("ide2").unwrap();
    assert_eq!((ide2.kind, ide2.source.as_deref(), ide2.cloud_init), (DiskKind::Cdrom, None, false));
    let net1 = hw.nic("net1").unwrap();
    assert_eq!((net1.link_up, net1.firewall, net1.mac.as_deref()), (false, Some(true), Some("BC:24:11:DE:00:BF")));
    assert_eq!(hw.nic("net0").unwrap().firewall, Some(false));
    assert_eq!(hw.boot, Some(vec!["scsi0".into(), "ide2".into(), "net0".into()]));
    assert!(!hw.autostart);
    assert_eq!(hw.name.as_deref(), Some("sbhw-e2e-vm"));
    assert_eq!(hw.protection, Some(false));
    let pending: BTreeMap<&str, &PendingField> = hw.pending.iter().map(|p| (p.key.as_str(), p)).collect();
    assert_eq!(pending["cores"].current.as_deref(), Some("1"));
    assert_eq!(pending["cores"].pending.as_deref(), Some("2"));
    assert!(pending.contains_key("memory") && pending.contains_key("boot") && pending.contains_key("cpu"));
    // Not pending: applied at once (the NIC was hot-plugged).
    assert!(!pending.contains_key("net1"));
    assert!(!pending.contains_key("digest"));
    assert_eq!(hw.revision.as_deref(), Some(VM_DIGEST));
    let text = hw.config_text.as_deref().unwrap();
    assert!(text.contains("cpu: host,flags=+aes"), "{text}");
    assert!(text.contains("onboot: 0"), "{text}");
    assert!(!text.contains("digest"), "{text}");
    assert_eq!(hw.limits.host_cpus, Some(12));
    assert_eq!(hw.firmware, Some(Firmware::default()));
    // No `vga`: PVE's default card.
    assert_eq!(hw.display.as_ref().and_then(|d| d.gpu.as_deref()), Some("std"));
    assert_eq!(hw.support, qemu_support());
}

#[test]
fn a_container_resources_mount_points_a_removal_pending() {
    let hw = parse_hardware(&config("hw_ct_config.json"), &list("hw_ct_pending.json"), GuestKind::Lxc, true, Limits::default(), Vec::new());
    assert_eq!((hw.cpu.cores, hw.memory.mib, hw.memory.swap_mib), (2, 384, Some(128)));
    assert_eq!(hw.boot, None);
    assert_eq!(hw.firmware, None);
    assert_eq!(hw.display, None);
    assert_eq!(hw.disk("rootfs").unwrap().kind, DiskKind::Rootfs);
    let mp0 = hw.disk("mp0").unwrap();
    assert_eq!((mp0.kind, mp0.mount_point.as_deref()), (DiskKind::Mount, Some("/mnt/e2e")));
    let net0 = hw.nic("net0").unwrap();
    assert_eq!((net0.name.as_deref(), net0.mac.as_deref()), (Some("eth0"), Some("BC:24:11:3E:AA:6A")));
    assert_eq!(hw.name.as_deref(), Some("sbhw-e2e-ct"));
    assert!(hw.pending.is_empty());
    assert_eq!(hw.support, lxc_support());

    // `delete=mp0` on a running container: gone from what the next start
    // gets, pending until then.
    let hw = parse_hardware(
        &config("hw_ct_config_mp_delete.json"),
        &list("hw_ct_pending_mp_delete.json"),
        GuestKind::Lxc,
        true,
        Limits::default(),
        Vec::new(),
    );
    assert!(hw.disk("mp0").is_none());
    let [p] = hw.pending.as_slice() else { panic!("{:?}", hw.pending) };
    assert_eq!((p.key.as_str(), p.delete), ("mp0", true));
    assert!(p.current.as_deref().unwrap().contains("vm-9902-disk-1"));
}

#[test]
fn a_container_without_cores_has_the_hosts() {
    let mut c = config("hw_ct_config.json");
    c.remove("cores");
    let hw = parse_hardware(&c, &[], GuestKind::Lxc, false, Limits { host_cpus: Some(12), host_memory_bytes: None }, Vec::new());
    assert_eq!(hw.cpu.cores, 12);
}

#[test]
fn memory_as_a_property_string_and_vcpus_below_the_whole() {
    let mut c = config("hw_vm_config.json");
    // PVE 8.1 and later.
    c.insert("memory".into(), json!("current=2048"));
    c.insert("sockets".into(), json!(2));
    c.insert("vcpus".into(), json!(3));
    c.insert("onboot".into(), json!(1));
    c.insert("protection".into(), json!(1));
    c.insert("description".into(), json!("the web tier\n"));
    let hw = parse_hardware(&c, &[], GuestKind::Qemu, false, Limits::default(), Vec::new());
    assert_eq!(hw.memory.mib, 2048);
    assert_eq!((hw.cpu.sockets, hw.cpu.cores, hw.cpu.online), (2, 2, Some(3)));
    assert!(hw.autostart);
    assert_eq!(hw.protection, Some(true));
    assert_eq!(hw.description.as_deref(), Some("the web tier"));
    // All of them: none to say.
    c.insert("vcpus".into(), json!(4));
    assert_eq!(parse_hardware(&c, &[], GuestKind::Qemu, false, Limits::default(), Vec::new()).cpu.online, None);
}

#[test]
fn a_legacy_boot_order_read_as_pve_reads_it() {
    let mut c = config("hw_vm_config.json");
    c.insert("boot".into(), json!("cdn"));
    let hw = parse_hardware(&c, &[], GuestKind::Qemu, false, Limits::default(), Vec::new());
    assert_eq!(hw.boot, Some(vec!["scsi0".into(), "ide2".into(), "net0".into()]));
    c.insert("bootdisk".into(), json!("scsi1"));
    c.insert("boot".into(), json!("legacy=nc"));
    let hw = parse_hardware(&c, &[], GuestKind::Qemu, false, Limits::default(), Vec::new());
    assert_eq!(hw.boot, Some(vec!["net0".into(), "scsi1".into()]));
    c.remove("boot");
    assert_eq!(parse_hardware(&c, &[], GuestKind::Qemu, false, Limits::default(), Vec::new()).boot, Some(Vec::new()));
}

#[test]
fn a_cloud_init_drive_is_told_apart_from_install_media() {
    let mut c = config("hw_vm_config.json");
    c.insert("ide2".into(), json!("local-lvm:vm-9901-cloudinit,media=cdrom"));
    c.insert("ide0".into(), json!("local:9901/vm-9901-cloudinit.qcow2,media=cdrom"));
    c.insert("ide3".into(), json!("local:iso/vm-1-cloudinit.iso,media=cdrom"));
    let hw = parse_hardware(&c, &[], GuestKind::Qemu, false, Limits::default(), Vec::new());
    assert!(hw.disk("ide2").unwrap().cloud_init);
    assert!(hw.disk("ide0").unwrap().cloud_init);
    // An ISO that happens to be named so is media.
    assert!(!hw.disk("ide3").unwrap().cloud_init);
}

#[test]
fn devices_firmware_card_and_cache_modes() {
    let hw = parse_hardware(&config("hw_vm_devices_config.json"), &[], GuestKind::Qemu, false, Limits::default(), Vec::new());
    let devices: Vec<(&str, DeviceKind, Option<&str>, bool)> =
        hw.devices.iter().map(|d| (d.key.as_str(), d.kind, d.detail.as_deref(), d.mapping)).collect();
    assert_eq!(
        devices,
        vec![
            ("hostpci0", DeviceKind::Pci, Some("sbhwb-xhci"), true),
            ("tpmstate0", DeviceKind::Tpm, Some("TPM v2.0"), false),
            ("usb0", DeviceKind::Usb, Some("sbhwb-bt"), true),
            ("usb1", DeviceKind::Usb, Some("0bda:b023"), false),
        ]
    );
    assert!(hw.has_tpm());
    assert_eq!(hw.firmware, Some(Firmware { uefi: true, secure_boot: true, vars_storage: Some("local-lvm".into()) }));
    assert_eq!(hw.display.as_ref().and_then(|d| d.gpu.as_deref()), Some("virtio"));
    let caches: BTreeMap<&str, Option<&str>> = hw.disks.iter().map(|d| (d.key.as_str(), d.cache.as_deref())).collect();
    assert_eq!(caches, BTreeMap::from([("scsi1", Some("writethrough")), ("virtio0", Some("writeback"))]));
    // The EFI and TPM volumes, and a detached one, are not disks to edit.
    assert!(hw.disks.iter().all(|d| !d.key.starts_with("efidisk") && !d.key.starts_with("unused") && !d.key.starts_with("tpm")));
    assert_eq!(hw.support, qemu_support());
}

#[test]
fn a_device_by_address_and_by_pci_id() {
    let mut c = config("hw_vm_devices_config.json");
    c.insert("usb2".into(), json!("host=1-1.2,usb3=1"));
    c.insert("usb3".into(), json!("spice"));
    c.insert("hostpci1".into(), json!("0000:01:00.0,pcie=1"));
    c.insert("hostpci2".into(), json!("host=02:00,x-vga=1"));
    let hw = parse_hardware(&c, &[], GuestKind::Qemu, false, Limits::default(), Vec::new());
    let detail = |k: &str| hw.devices.iter().find(|d| d.key == k).and_then(|d| d.detail.clone());
    assert_eq!(detail("usb2").as_deref(), Some("1-1.2"));
    assert_eq!(detail("usb3").as_deref(), Some("spice"));
    assert_eq!(detail("hostpci1").as_deref(), Some("0000:01:00.0"));
    assert_eq!(detail("hostpci2").as_deref(), Some("02:00"));
}

#[test]
fn option_strings_what_is_not_set_stays_in_its_place() {
    let net = "virtio=BC:24:11:DE:00:BF,bridge=vmbr0,firewall=1,link_down=1";
    assert_eq!(
        with_options(net, &[("bridge", Some("vmbr1".into())), ("link_down", None)]),
        "virtio=BC:24:11:DE:00:BF,bridge=vmbr1,firewall=1"
    );
    assert_eq!(with_options("virtio=AA,bridge=vmbr0", &[("link_down", Some("1".into()))]), "virtio=AA,bridge=vmbr0,link_down=1");
    // Dropping what is not there is nothing.
    assert_eq!(with_options("local-lvm:vm-1-disk-0,size=1G", &[("cache", None)]), "local-lvm:vm-1-disk-0,size=1G");
    assert_eq!(with_cpu_type(Some("host,flags=+aes"), "x86-64-v3"), "x86-64-v3,flags=+aes");
    assert_eq!(with_cpu_type(Some("cputype=kvm64,hidden=1"), "host"), "host,hidden=1");
    assert_eq!(with_cpu_type(None, "host"), "host");
    assert_eq!(size_arg(2 << 30), "2G");
    assert_eq!(size_arg((1 << 30) + 1), "1048577K");
    assert_eq!(size_arg((1 << 30) + 1024), "1048577K");
}

#[test]
fn a_disk_on_another_bus_without_what_that_bus_lacks() {
    let raw = "local-lvm:vm-1-disk-0,iothread=1,ro=1,ssd=1,cache=none,size=1G";
    assert_eq!(on_bus(raw, "sata"), "local-lvm:vm-1-disk-0,ssd=1,cache=none,size=1G");
    assert_eq!(on_bus(raw, "scsi"), raw);
    assert_eq!(on_bus(raw, "virtio"), "local-lvm:vm-1-disk-0,iothread=1,ro=1,cache=none,size=1G");
    assert_eq!(on_bus("x:1,model=QEMU,size=1G", "ide"), "x:1,model=QEMU,size=1G");
    assert_eq!(on_bus("x:1,model=QEMU,size=1G", "sata"), "x:1,size=1G");
}

#[test]
fn a_nics_model_and_mac_the_rest_as_written() {
    let raw = "e1000=BC:24:11:00:00:01,bridge=vmbr0,firewall=1";
    assert_eq!(with_nic_hardware(raw, false, Some("virtio"), Some("bc:24:11:00:00:09")), "virtio=BC:24:11:00:00:09,bridge=vmbr0,firewall=1");
    assert_eq!(with_nic_hardware(raw, false, Some("virtio"), None), "virtio=BC:24:11:00:00:01,bridge=vmbr0,firewall=1");
    assert_eq!(with_nic_hardware(raw, false, None, Some("bc:24:11:00:00:09")), "e1000=BC:24:11:00:00:09,bridge=vmbr0,firewall=1");
    let ct = "name=eth0,bridge=vmbr0,hwaddr=BC:24:11:3E:AA:6A,ip=dhcp";
    assert_eq!(with_nic_hardware(ct, true, None, Some("bc:24:11:00:00:09")), "name=eth0,bridge=vmbr0,hwaddr=BC:24:11:00:00:09,ip=dhcp");
    assert_eq!(with_nic_hardware(ct, true, Some("virtio"), None), ct);
}

#[test]
fn the_first_free_slot() {
    let c = config("hw_vm_config.json");
    assert_eq!(free_key(&c, "scsi", bus_slots("scsi")).as_deref(), Some("scsi1"));
    assert_eq!(free_key(&c, "net", 32).as_deref(), Some("net2"));
    assert_eq!(free_key(&c, "virtio", bus_slots("virtio")).as_deref(), Some("virtio0"));
    let full: Map<String, Value> = (0..4).map(|i| (format!("ide{i}"), json!("none,media=cdrom"))).collect();
    assert_eq!(free_key(&full, "ide", bus_slots("ide")), None);
    assert_eq!((bus_slots("sata"), bus_slots("scsi"), bus_slots("virtio")), (6, 31, 16));
}

// ---------------------------------------------------------------------------
// Cloud-init
// ---------------------------------------------------------------------------

fn ci_config() -> Value {
    json!({
        "ciuser": "sbxe",
        "cipassword": "**********",
        "sshkeys": "ssh-ed25519%20AAAA%20one%0Assh-ed25519%20BBBB%20two%0A",
        "ipconfig0": "ip=10.0.0.5/24,gw=10.0.0.1,ip6=auto",
        "nameserver": "1.1.1.1 9.9.9.9",
        "searchdomain": "lab.example",
        "net0": "virtio=BC:24:11:00:00:01,bridge=vmbr0",
        "scsi1": "local-lvm:vm-950-cloudinit,media=cdrom",
        "digest": "d1",
    })
}

fn ci_vm() -> Guest {
    guest("qemu/950", "ci", GuestKind::Qemu, GuestState::Running)
}

#[test]
fn cloud_init_read_the_password_only_as_set() {
    let ci = parse_cloud_init(ci_config().as_object().unwrap());
    assert_eq!(ci.user, "sbxe");
    assert_eq!(ci.ssh_keys, vec!["ssh-ed25519 AAAA one", "ssh-ed25519 BBBB two"]);
    assert_eq!((ci.address.as_deref(), ci.gateway.as_deref()), (Some("10.0.0.5/24"), Some("10.0.0.1")));
    assert_eq!(ci.dns, vec!["1.1.1.1", "9.9.9.9"]);
    assert_eq!(ci.search_domains, vec!["lab.example"]);
    assert_eq!((ci.password_set, ci.network, ci.hostname.as_deref(), ci.nics), (true, true, None, 1));
    assert_eq!(ci.revision, "d1");
    assert!(!format!("{ci:?}").contains("**"));

    let dhcp = parse_cloud_init(json!({"ipconfig0": "ip=dhcp", "digest": "x"}).as_object().unwrap());
    assert_eq!((dhcp.address, dhcp.password_set, dhcp.network, dhcp.user.as_str()), (None, false, false, ""));
    // Keys as written by hand: not URL-encoded, read as they are.
    let plain = parse_cloud_init(json!({"sshkeys": "ssh-ed25519 AAAA one %zz"}).as_object().unwrap());
    assert_eq!(plain.ssh_keys, vec!["ssh-ed25519 AAAA one %zz"]);
    // Several search domains are one space-separated option.
    let domains = parse_cloud_init(json!({"searchdomain": "a.example b.example"}).as_object().unwrap());
    assert_eq!(domains.search_domains, vec!["a.example", "b.example"]);
    // A gateway without an address is DHCP's own.
    let gw = parse_cloud_init(json!({"ipconfig0": "ip=dhcp,gw=10.0.0.1"}).as_object().unwrap());
    assert_eq!(gw.gateway, None);
}

fn edit(values: CloudInit, remove_password: bool, revision: &str) -> CloudInitEdit {
    CloudInitEdit { values, remove_password, password_expires: false, revision: revision.into() }
}

fn ci_api() -> Fake {
    let fake = Fake::new();
    fake.route("GET /nodes/pve/qemu/950/config", |_| ok(ci_config()));
    fake.route("POST /nodes/pve/qemu/950/config", |_| ok(json!(UPID)));
    fake.route("PUT /nodes/pve/qemu/950/cloudinit", |_| ok(Value::Null));
    fake
}

#[tokio::test]
async fn cloud_init_write_the_options_with_the_digest_then_the_drive_written_again() {
    let fake = ci_api();
    let client = fake.client();
    let base = client.cloud_init(&ci_vm()).await.unwrap();
    assert_eq!(base.user, "sbxe");
    let keys_only = CloudInit { user: "ops".into(), ssh_keys: vec!["ssh-ed25519 CCCC three".into()], ..CloudInit::default() };
    client.set_cloud_init(&ci_vm(), &edit(keys_only, true, &base.revision)).await.unwrap();
    let paths = fake.paths();
    let i = paths.iter().position(|p| p == "POST /nodes/pve/qemu/950/config").unwrap();
    let want: BTreeMap<String, String> = [
        ("ciuser", "ops"),
        ("sshkeys", "ssh-ed25519%20CCCC%20three%0A"),
        // The IPv6 setting kept.
        ("ipconfig0", "ip=dhcp,ip6=auto"),
        ("delete", "cipassword,nameserver,searchdomain"),
        ("digest", "d1"),
    ]
    .into_iter()
    .map(|(k, v)| (k.to_owned(), v.to_owned()))
    .collect();
    assert_eq!(fake.form("POST /nodes/pve/qemu/950/config"), want);
    let j = paths.iter().position(|p| p == "PUT /nodes/pve/qemu/950/cloudinit").unwrap();
    assert!(j > i, "{paths:?}");

    // A new password and a static address; the password is kept where none
    // is typed and it is not removed.
    let static_ip = CloudInit {
        user: "ops".into(),
        password: Some("n e&w".into()),
        address: Some("10.0.0.9/24".into()),
        gateway: Some("10.0.0.254".into()),
        dns: vec!["8.8.8.8".into()],
        ..CloudInit::default()
    };
    client.set_cloud_init(&ci_vm(), &edit(static_ip, false, &base.revision)).await.unwrap();
    let want: BTreeMap<String, String> = [
        ("ciuser", "ops"),
        ("cipassword", "n e&w"),
        ("ipconfig0", "ip=10.0.0.9/24,gw=10.0.0.254,ip6=auto"),
        ("nameserver", "8.8.8.8"),
        ("delete", "sshkeys,searchdomain"),
        ("digest", "d1"),
    ]
    .into_iter()
    .map(|(k, v)| (k.to_owned(), v.to_owned()))
    .collect();
    assert_eq!(fake.form("POST /nodes/pve/qemu/950/config"), want);

    // Neither typed nor removed: the one set stays, unsent.
    let keep = CloudInit { user: "ops".into(), search_domains: vec!["a.example".into(), "b.example".into()], ..CloudInit::default() };
    client.set_cloud_init(&ci_vm(), &edit(keep, false, &base.revision)).await.unwrap();
    let form = fake.form("POST /nodes/pve/qemu/950/config");
    assert!(!form.contains_key("cipassword"), "{form:?}");
    assert_eq!(form["delete"], "sshkeys,nameserver");
    assert_eq!(form["searchdomain"], "a.example b.example");
}

#[tokio::test]
async fn cloud_init_without_a_nic_leaves_the_address_alone() {
    let fake = Fake::new();
    fake.route("GET /nodes/pve/qemu/950/config", |_| ok(json!({"ciuser": "ops", "cipassword": "**", "digest": "d1"})));
    fake.route("POST /nodes/pve/qemu/950/config", |_| ok(json!(UPID)));
    fake.route("PUT /nodes/pve/qemu/950/cloudinit", |_| ok(Value::Null));
    let ci = CloudInit { user: "ops".into(), address: Some("10.0.0.9/24".into()), ..CloudInit::default() };
    fake.client().set_cloud_init(&ci_vm(), &edit(ci, false, "d1")).await.unwrap();
    assert!(!fake.form("POST /nodes/pve/qemu/950/config").contains_key("ipconfig0"));
}

#[tokio::test]
async fn cloud_init_refused_before_anything_is_sent() {
    let fake = ci_api();
    // The password removed and no key: no way in.
    let e = err(fake.client().set_cloud_init(&ci_vm(), &edit(CloudInit { user: "ops".into(), ..CloudInit::default() }, true, "d1"))).await;
    assert!(matches!(e.detail.as_deref(), Some(Detail::CreateRefused { issue: sbm_virt::create::Issue::CiCredentials })), "{e:?}");
    let bad_user = CloudInit { user: "Bad User".into(), password: Some("x".into()), ..CloudInit::default() };
    let e = err(fake.client().set_cloud_init(&ci_vm(), &edit(bad_user, false, "d1"))).await;
    assert!(matches!(e.detail.as_deref(), Some(Detail::CreateRefused { issue: sbm_virt::create::Issue::CiUser })), "{e:?}");
    assert!(fake.paths().iter().all(|p| p.starts_with("GET ")), "{:?}", fake.paths());
}

#[tokio::test]
async fn cloud_init_from_a_stale_read_is_a_conflict() {
    let fake = ci_api();
    fake.route("POST /nodes/pve/qemu/950/config", |_| status(500, "checksum mismatch (file change by other user?)"));
    let client = fake.client();
    let base = client.cloud_init(&ci_vm()).await.unwrap();
    let ci = CloudInit { user: "x".into(), password: Some("y".into()), ..CloudInit::default() };
    let e = err(client.set_cloud_init(&ci_vm(), &edit(ci, false, &base.revision))).await;
    assert_eq!(e.kind, ErrorKind::Conflict);
    assert!(fake.paths().iter().all(|p| !p.ends_with("/cloudinit")), "{:?}", fake.paths());
}

// ---------------------------------------------------------------------------
// Changes
// ---------------------------------------------------------------------------

/// Node `pve` with the hardware VM and container running and the devices
/// VM stopped; storages `local` (media) and `local-lvm` (disks), bridges
/// `vmbr0` and `vmbr1`.
fn hw_api() -> Fake {
    let fake = Fake::new();
    fake.route("GET /cluster/resources", |_| {
        ok(json!([
            {"id": "node/pve", "type": "node", "node": "pve", "status": "online", "maxcpu": 12},
            {"id": "qemu/9901", "type": "qemu", "vmid": 9901, "node": "pve", "status": "running", "name": "sbhw-e2e-vm"},
            {"id": "lxc/9902", "type": "lxc", "vmid": 9902, "node": "pve", "status": "running", "name": "sbhw-e2e-ct"},
            {"id": "qemu/9921", "type": "qemu", "vmid": 9921, "node": "pve", "status": "stopped", "name": "sbhwb-probe"},
        ]))
    });
    fake.route("GET /nodes/pve/qemu/9901/config", |_| ok(fixture("hw_vm_config.json")));
    fake.route("GET /nodes/pve/qemu/9901/pending", |_| ok(fixture("hw_vm_pending.json")));
    fake.route("GET /nodes/pve/lxc/9902/config", |_| ok(fixture("hw_ct_config.json")));
    fake.route("GET /nodes/pve/lxc/9902/pending", |_| ok(fixture("hw_ct_pending.json")));
    fake.route("GET /nodes/pve/qemu/9921/config", |_| ok(fixture("hw_vm_devices_config.json")));
    fake.route("GET /nodes/pve/qemu/9921/pending", |_| ok(json!([])));
    fake.route("GET /nodes/pve/status", |_| ok(json!({"cpuinfo": {"cpus": 12}, "memory": {"total": 16627777536u64}})));
    fake.route("GET /nodes/pve/capabilities/qemu/cpu", |_| ok(json!([{"name": "x86-64-v3", "custom": 0}, {"name": "host", "custom": 0}])));
    fake.route("POST /nodes/pve/qemu/9901/config", |_| ok(json!(UPID)));
    fake.route("POST /nodes/pve/qemu/9921/config", |_| ok(json!(UPID)));
    fake.route("PUT /nodes/pve/lxc/9902/config", |_| ok(Value::Null));
    fake.route("PUT /nodes/pve/qemu/9901/resize", |_| ok(json!(UPID)));
    fake.route("GET /storage", |_| ok(json!([])));
    fake.route("GET /nodes/pve/storage", |_| {
        ok(json!([
            {"storage": "local", "type": "dir", "active": 1, "enabled": 1, "content": "iso,vztmpl,import,backup", "avail": 100u64 << 30, "total": 200u64 << 30},
            {"storage": "local-lvm", "type": "lvmthin", "active": 1, "enabled": 1, "content": "images,rootdir", "avail": 100u64 << 30, "total": 200u64 << 30},
        ]))
    });
    fake.route("GET /nodes/pve/storage/local/content", |_| {
        ok(json!([
            {"volid": "local:iso/a.iso", "content": "iso", "format": "iso", "size": 1000},
            {"volid": "local:vztmpl/alpine.tar.xz", "content": "vztmpl", "format": "txz", "size": 1000},
        ]))
    });
    fake.route("GET /nodes/pve/storage/local-lvm/content", |_| {
        ok(json!([{"volid": "local-lvm:vm-9999-disk-0", "content": "images", "format": "raw", "size": 1u64 << 30}]))
    });
    fake.route("GET /nodes/pve/network", |_| {
        ok(json!([
            {"iface": "vmbr0", "type": "bridge", "active": 1},
            {"iface": "vmbr1", "type": "bridge", "active": 1},
        ]))
    });
    fake
}

fn form(pairs: &[(&str, &str)]) -> BTreeMap<String, String> {
    pairs.iter().map(|(k, v)| ((*k).to_owned(), (*v).to_owned())).collect()
}

fn iso(volume: &str) -> Option<VolumeRef> {
    Some(VolumeRef { pool: "pve/local".into(), volume: volume.into() })
}

/// The forms of every request to `key`, in order.
fn bodies(fake: &Fake, key: &str) -> Vec<BTreeMap<String, String>> {
    fake.forms(key)
}

const VM_CONFIG: &str = "POST /nodes/pve/qemu/9901/config";
const DEV_CONFIG: &str = "POST /nodes/pve/qemu/9921/config";
const CT_CONFIG: &str = "PUT /nodes/pve/lxc/9902/config";

#[tokio::test]
async fn read_the_nodes_limits_and_cpu_models_sorted() {
    let fake = hw_api();
    let hw = fake.client().hardware(&vm()).await.unwrap();
    assert_eq!(hw.limits.host_cpus, Some(12));
    assert_eq!(hw.limits.host_memory_bytes, Some(16627777536));
    assert_eq!(hw.cpu_types, vec!["host", "x86-64-v3"]);
    // Read with the guest's state now, whatever the caller's copy says.
    let off = Guest { state: GuestState::Stopped, ..vm() };
    assert!(fake.client().hardware(&off).await.unwrap().running);
}

#[tokio::test]
async fn read_a_token_without_sys_audit_on_the_node_still_reads_the_guest() {
    let fake = hw_api();
    fake.route("GET /nodes/pve/status", |_| status(403, "Permission check failed (/nodes/pve, Sys.Audit)"));
    fake.route("GET /nodes/pve/capabilities/qemu/cpu", |_| status(403, "Permission check failed"));
    let hw = fake.client().hardware(&vm()).await.unwrap();
    assert_eq!(hw.limits.host_cpus, None);
    assert!(hw.cpu_types.is_empty());
    assert_eq!(hw.cpu.cores, 2);
}

#[tokio::test]
async fn a_guest_gone_from_the_host_is_not_found() {
    let fake = hw_api();
    let gone = guest("qemu/9999", "gone", GuestKind::Qemu, GuestState::Running);
    let e = err(fake.client().hardware(&gone)).await;
    assert_eq!(e.kind, ErrorKind::Unsupported, "{e:?}");
    let e = err(fake.client().change_hardware(&gone, Some(VM_DIGEST), &Change::SetAutostart { on: true })).await;
    assert!(fake.paths().iter().all(|p| p.starts_with("GET ")), "{e:?}");
}

#[tokio::test]
async fn every_change_carries_the_digest_it_was_made_from() {
    let fake = hw_api();
    let client = fake.client();
    let hw = client.hardware(&vm()).await.unwrap();
    let at = hw.revision.as_deref();
    assert_eq!(at, Some(VM_DIGEST));
    client.change_hardware(&vm(), at, &Change::SetCpu { sockets: 2, cores: 2, online: None, cpu_type: Some("x86-64-v3".into()) }).await.unwrap();
    assert_eq!(
        fake.form(VM_CONFIG),
        // The model changes, its flag stays.
        form(&[("sockets", "2"), ("cores", "2"), ("cpu", "x86-64-v3,flags=+aes"), ("digest", VM_DIGEST)])
    );
    // The model it has already: not sent; some vCPUs online.
    client.change_hardware(&vm(), at, &Change::SetCpu { sockets: 2, cores: 2, online: Some(3), cpu_type: Some("host".into()) }).await.unwrap();
    assert_eq!(fake.form(VM_CONFIG), form(&[("sockets", "2"), ("cores", "2"), ("vcpus", "3"), ("digest", VM_DIGEST)]));
    client.change_hardware(&vm(), at, &Change::SetMemory { mib: 1024, min_mib: None, swap_mib: None }).await.unwrap();
    // No floor any more: the default, the whole memory.
    assert_eq!(fake.form(VM_CONFIG), form(&[("memory", "1024"), ("delete", "balloon"), ("digest", VM_DIGEST)]));
    client.change_hardware(&vm(), at, &Change::SetMemory { mib: 1024, min_mib: Some(512), swap_mib: None }).await.unwrap();
    assert_eq!(fake.form(VM_CONFIG), form(&[("memory", "1024"), ("balloon", "512"), ("digest", VM_DIGEST)]));
    client
        .change_hardware(&vm(), at, &Change::UpdateNic { key: "net1".into(), network: Some("pve/vmbr1".into()), link_up: true, firewall: None })
        .await
        .unwrap();
    assert_eq!(fake.form(VM_CONFIG)["net1"], "virtio=BC:24:11:DE:00:BF,bridge=vmbr1,firewall=1");
    client
        .change_hardware(&vm(), at, &Change::UpdateNic { key: "net0".into(), network: None, link_up: false, firewall: Some(true) })
        .await
        .unwrap();
    assert_eq!(fake.form(VM_CONFIG)["net0"], "virtio=BC:24:11:F6:3B:A5,bridge=vmbr0,link_down=1,firewall=1");
    client.change_hardware(&vm(), at, &Change::SetBoot { order: vec!["ide2".into(), "scsi0".into()] }).await.unwrap();
    assert_eq!(fake.form(VM_CONFIG)["boot"], "order=ide2;scsi0");
    client.change_hardware(&vm(), at, &Change::Revert { keys: vec!["cores".into(), "memory".into()] }).await.unwrap();
    assert_eq!(fake.form(VM_CONFIG)["revert"], "cores,memory");
    client.change_hardware(&vm(), at, &Change::SetAutostart { on: true }).await.unwrap();
    assert_eq!(fake.form(VM_CONFIG), form(&[("onboot", "1"), ("digest", VM_DIGEST)]));
    client.change_hardware(&vm(), at, &Change::GrowDisk { key: "scsi0".into(), bytes: 3 << 30 }).await.unwrap();
    assert_eq!(fake.form("PUT /nodes/pve/qemu/9901/resize"), form(&[("disk", "scsi0"), ("size", "3G"), ("digest", VM_DIGEST)]));
    // A task each, waited for.
    assert!(fake.paths().last().unwrap().contains("/tasks/"), "{:?}", fake.paths());
    // No digest: none sent.
    client.change_hardware(&vm(), None, &Change::SetAutostart { on: false }).await.unwrap();
    assert_eq!(fake.form(VM_CONFIG), form(&[("onboot", "0")]));
}

#[tokio::test]
async fn refused_before_anything_is_sent_against_the_guest_as_it_is_now() {
    let fake = hw_api();
    let client = fake.client();
    let at = Some(VM_DIGEST);
    let cases = [
        (Change::SetCpu { sockets: 4, cores: 4, online: None, cpu_type: None }, Issue::CpuCount),
        (Change::SetCpu { sockets: 1, cores: 2, online: None, cpu_type: Some("kvm32".into()) }, Issue::NotOffered),
        (Change::GrowDisk { key: "scsi0".into(), bytes: 1 << 29 }, Issue::DiskShrink),
        (Change::SetMedia { key: "scsi0".into(), media: None }, Issue::NotFound),
        (Change::SetMedia { key: "ide2".into(), media: iso("local:vztmpl/alpine.tar.xz") }, Issue::Media),
        (Change::AddNic { network: "pve/vmbr9".into(), model: None }, Issue::NotFound),
        (Change::AddDisk { pool: "pve/local".into(), gib: 1, mount_point: None }, Issue::NotOffered),
        (Change::AddDisk { pool: "pve/local-lvm".into(), gib: 101, mount_point: None }, Issue::StorageSpace),
        // Running: the firmware and a bus wait for a stop.
        (Change::SetFirmware { uefi: true, secure_boot: false, storage: Some("pve/local-lvm".into()) }, Issue::StopFirst),
        (Change::UpdateDisk { key: "scsi0".into(), bus: Some("sata".into()), cache: None }, Issue::StopFirst),
        (Change::RemoveDevice { key: "usb0".into() }, Issue::NotFound),
    ];
    for (change, want) in cases {
        let e = err(client.change_hardware(&vm(), at, &change)).await;
        assert_eq!((e.kind, refused(&e)), (ErrorKind::Unsupported, Some(want)), "{change:?}");
    }
    assert!(fake.paths().iter().all(|p| p.starts_with("GET ")), "{:?}", fake.paths());
}

#[tokio::test]
async fn a_new_disk_and_nic_go_in_the_first_free_slot() {
    let fake = hw_api();
    let client = fake.client();
    let at = Some(VM_DIGEST);
    client.change_hardware(&vm(), at, &Change::AddDisk { pool: "pve/local-lvm".into(), gib: 4, mount_point: None }).await.unwrap();
    assert_eq!(fake.form(VM_CONFIG), form(&[("scsi1", "local-lvm:4"), ("digest", VM_DIGEST)]));
    client.change_hardware(&vm(), at, &Change::AddNic { network: "pve/vmbr0".into(), model: None }).await.unwrap();
    assert_eq!(fake.form(VM_CONFIG)["net2"], "virtio,bridge=vmbr0");
    client.change_hardware(&vm(), at, &Change::AddNic { network: "pve/vmbr1".into(), model: Some("e1000".into()) }).await.unwrap();
    assert_eq!(fake.form(VM_CONFIG)["net2"], "e1000,bridge=vmbr1");
    client.change_hardware(&vm(), at, &Change::SetMedia { key: "ide2".into(), media: iso("local:iso/a.iso") }).await.unwrap();
    assert_eq!(fake.form(VM_CONFIG)["ide2"], "local:iso/a.iso,media=cdrom");
    client.change_hardware(&vm(), at, &Change::SetMedia { key: "ide2".into(), media: None }).await.unwrap();
    assert_eq!(fake.form(VM_CONFIG)["ide2"], "none,media=cdrom");
    // A new drive: the first free IDE slot (ide2 is taken), empty or not.
    client.change_hardware(&vm(), at, &Change::AddCdrom { media: None }).await.unwrap();
    assert_eq!(fake.form(VM_CONFIG)["ide0"], "none,media=cdrom");
    client.change_hardware(&vm(), at, &Change::AddCdrom { media: iso("local:iso/a.iso") }).await.unwrap();
    assert_eq!(fake.form(VM_CONFIG)["ide0"], "local:iso/a.iso,media=cdrom");
    // An existing volume, by its id, on the first disk's bus.
    client
        .change_hardware(&vm(), at, &Change::AttachVolume { volume: VolumeRef { pool: "pve/local-lvm".into(), volume: "local-lvm:vm-9999-disk-0".into() }, mount_point: None })
        .await
        .unwrap();
    assert_eq!(fake.form(VM_CONFIG)["scsi1"], "local-lvm:vm-9999-disk-0");
    client.change_hardware(&vm(), at, &Change::RemoveNic { key: "net1".into() }).await.unwrap();
    assert_eq!(fake.form(VM_CONFIG), form(&[("delete", "net1"), ("digest", VM_DIGEST)]));
    client.change_hardware(&vm(), at, &Change::RemoveDisk { key: "scsi0".into(), delete_volume: false }).await.unwrap();
    assert_eq!(fake.form(VM_CONFIG), form(&[("delete", "scsi0"), ("digest", VM_DIGEST)]));
}

#[tokio::test]
async fn a_guests_own_detached_volume_is_its_to_attach_anothers_is_not() {
    let fake = hw_api();
    fake.route("GET /nodes/pve/storage/local-lvm/content", |_| {
        ok(json!([
            {"volid": "local-lvm:vm-9901-disk-5", "content": "images", "format": "raw", "size": 1u64 << 30, "vmid": 9901},
            {"volid": "local-lvm:vm-9921-disk-0", "content": "images", "format": "raw", "size": 1u64 << 30, "vmid": 9921},
        ]))
    });
    let client = fake.client();
    let attach = |volume: &str| Change::AttachVolume { volume: VolumeRef { pool: "pve/local-lvm".into(), volume: volume.into() }, mount_point: None };
    // Named for it by PVE (`vm-9901-…`): its own, not one in use.
    client.change_hardware(&vm(), Some(VM_DIGEST), &attach("local-lvm:vm-9901-disk-5")).await.unwrap();
    assert_eq!(fake.form(VM_CONFIG)["scsi1"], "local-lvm:vm-9901-disk-5");
    // Another guest's.
    let e = err(client.change_hardware(&vm(), Some(VM_DIGEST), &attach("local-lvm:vm-9921-disk-0"))).await;
    assert_eq!(refused(&e), Some(Issue::VolumeInUse));
}

/// The guest's configuration as the fake keeps it: a POST deleting one of
/// `detach` detaches it, as PVE does with a disk of a stopped guest.
fn detaching(fake: &Fake, path: &str, before: Map<String, Value>, after: Map<String, Value>, detach: &'static [&'static str]) -> Arc<AtomicBool> {
    let detached = Arc::new(AtomicBool::new(false));
    let d = detached.clone();
    let (b, a) = (before.clone(), after.clone());
    fake.route(&format!("GET {path}/config"), move |_| ok(Value::Object(if d.load(Ordering::SeqCst) { a.clone() } else { b.clone() })));
    let d = detached.clone();
    fake.route(&format!("POST {path}/config"), move |body| {
        let f = form_of(body);
        if f.get("delete").is_some_and(|k| k.split(',').any(|k| detach.contains(&k))) {
            d.store(true, Ordering::SeqCst);
        }
        ok(json!(UPID))
    });
    detached
}

#[tokio::test]
async fn a_removed_disks_volume_deleted_as_unused_or_kept_while_in_use() {
    let fake = hw_api();
    let client = fake.client();
    let before = config("hw_vm_config.json");
    let mut after = before.clone();
    after.remove("scsi0");
    after.insert("unused0".into(), json!("local-lvm:vm-9901-disk-0"));
    after.insert("digest".into(), json!("after"));
    // Detached: PVE lists the volume as unused, and deleting that deletes
    // it.
    detaching(&fake, "/nodes/pve/qemu/9901", before.clone(), after, &["scsi0"]);
    let out = client.change_hardware(&vm(), Some(VM_DIGEST), &Change::RemoveDisk { key: "scsi0".into(), delete_volume: true }).await.unwrap();
    assert!(!out.volume_kept);
    assert_eq!(
        bodies(&fake, VM_CONFIG),
        vec![form(&[("delete", "scsi0"), ("digest", VM_DIGEST)]), form(&[("delete", "unused0"), ("digest", "after")])]
    );

    // A CD-ROM: the drive goes, its image stays, and nothing is said kept.
    let fake = hw_api();
    let mut c = config("hw_vm_config.json");
    c.insert("ide2".into(), json!("local:iso/a.iso,media=cdrom"));
    fake.route("GET /nodes/pve/qemu/9901/config", move |_| ok(Value::Object(c.clone())));
    let out = fake.client().change_hardware(&vm(), Some(VM_DIGEST), &Change::RemoveDisk { key: "ide2".into(), delete_volume: true }).await.unwrap();
    assert!(!out.volume_kept);
    assert_eq!(bodies(&fake, VM_CONFIG), vec![form(&[("delete", "ide2"), ("digest", VM_DIGEST)])]);

    // Still attached (pending until the guest stops): kept.
    let fake = hw_api();
    let out = fake.client().change_hardware(&vm(), Some(VM_DIGEST), &Change::RemoveDisk { key: "scsi0".into(), delete_volume: true }).await.unwrap();
    assert!(out.volume_kept);
    assert_eq!(bodies(&fake, VM_CONFIG), vec![form(&[("delete", "scsi0"), ("digest", VM_DIGEST)])]);
}

#[tokio::test]
async fn a_volume_written_as_file_and_a_tpm_state_are_deleted_with_the_digest_they_were_found_in() {
    let fake = hw_api();
    let client = fake.client();
    let mut before = config("hw_vm_config.json");
    before.insert("scsi0".into(), json!("file=local-lvm:vm-9901-disk-0,size=1G"));
    before.insert("tpmstate0".into(), json!("local-lvm:vm-9901-disk-7,size=4M,version=v2.0"));
    let mut after = before.clone();
    after.remove("scsi0");
    after.remove("tpmstate0");
    after.insert("unused0".into(), json!("local-lvm:vm-9901-disk-0"));
    after.insert("unused1".into(), json!("local-lvm:vm-9901-disk-7"));
    after.insert("digest".into(), json!("after"));
    let detached = detaching(&fake, "/nodes/pve/qemu/9901", before.clone(), after, &["scsi0", "tpmstate0"]);

    let out = client.change_hardware(&vm(), Some(VM_DIGEST), &Change::RemoveDisk { key: "scsi0".into(), delete_volume: true }).await.unwrap();
    assert!(!out.volume_kept);
    assert_eq!(bodies(&fake, VM_CONFIG).last(), Some(&form(&[("delete", "unused0"), ("digest", "after")])));

    detached.store(false, Ordering::SeqCst);
    let out = client.change_hardware(&vm(), Some(VM_DIGEST), &Change::RemoveDevice { key: "tpmstate0".into() }).await.unwrap();
    assert!(!out.volume_kept);
    let all = bodies(&fake, VM_CONFIG);
    assert_eq!(all[all.len() - 2], form(&[("delete", "tpmstate0"), ("digest", VM_DIGEST)]));
    assert_eq!(all[all.len() - 1], form(&[("delete", "unused1"), ("digest", "after")]));

    // Still attached (pending until the guest stops): kept, and said so.
    let fake = hw_api();
    fake.route("GET /nodes/pve/qemu/9901/config", move |_| ok(Value::Object(before.clone())));
    let out = fake.client().change_hardware(&vm(), Some(VM_DIGEST), &Change::RemoveDevice { key: "tpmstate0".into() }).await.unwrap();
    assert!(out.volume_kept);
    assert_eq!(bodies(&fake, VM_CONFIG), vec![form(&[("delete", "tpmstate0"), ("digest", VM_DIGEST)])]);
}

#[tokio::test]
async fn a_container_put_a_mount_point_and_an_interface_named_for_it() {
    let fake = hw_api();
    let client = fake.client();
    let hw = client.hardware(&ct()).await.unwrap();
    assert!(!fake.paths().iter().any(|p| p == "GET /nodes/pve/capabilities/qemu/cpu"));
    let at = hw.revision.as_deref();
    let digest = "6e225a58f2ae4c3ea0bb66d8c901cae2d87ef92d";
    assert_eq!(at, Some(digest));
    client.change_hardware(&ct(), at, &Change::SetMemory { mib: 512, min_mib: None, swap_mib: Some(0) }).await.unwrap();
    assert_eq!(fake.form(CT_CONFIG), form(&[("memory", "512"), ("swap", "0"), ("digest", digest)]));
    client.change_hardware(&ct(), at, &Change::SetCpu { sockets: 1, cores: 4, online: None, cpu_type: None }).await.unwrap();
    assert_eq!(fake.form(CT_CONFIG), form(&[("cores", "4"), ("digest", digest)]));
    client.change_hardware(&ct(), at, &Change::AddDisk { pool: "pve/local-lvm".into(), gib: 2, mount_point: Some("/srv".into()) }).await.unwrap();
    assert_eq!(fake.form(CT_CONFIG)["mp1"], "local-lvm:2,mp=/srv");
    client.change_hardware(&ct(), at, &Change::AddNic { network: "pve/vmbr0".into(), model: None }).await.unwrap();
    assert_eq!(fake.form(CT_CONFIG)["net1"], "name=eth1,bridge=vmbr0,ip=dhcp");
    client.change_hardware(&ct(), at, &Change::SetNicHardware { key: "net0".into(), model: None, mac: Some("bc:24:11:00:00:09".into()) }).await.unwrap();
    assert_eq!(fake.form(CT_CONFIG)["net0"], "name=eth0,bridge=vmbr0,hwaddr=BC:24:11:00:00:09,ip=dhcp,type=veth");
    // A model, a CD-ROM and a mount point outside the rules: refused.
    for change in [
        Change::AddNic { network: "pve/vmbr0".into(), model: Some("e1000".into()) },
        Change::AddCdrom { media: None },
        Change::AddDisk { pool: "pve/local-lvm".into(), gib: 2, mount_point: Some("srv".into()) },
    ] {
        let e = err(client.change_hardware(&ct(), at, &change)).await;
        assert!(refused(&e).is_some(), "{change:?}: {e:?}");
    }
}

#[tokio::test]
async fn settings_name_note_cleared_by_deleting_it_protection() {
    let fake = hw_api();
    let client = fake.client();
    let at = Some(VM_DIGEST);
    client.change_hardware(&vm(), at, &Change::SetName { name: "web-03".into() }).await.unwrap();
    assert_eq!(fake.form(VM_CONFIG), form(&[("name", "web-03"), ("digest", VM_DIGEST)]));
    client.change_hardware(&vm(), at, &Change::SetDescription { text: "a & b".into() }).await.unwrap();
    assert_eq!(fake.form(VM_CONFIG)["description"], "a & b");
    client.change_hardware(&vm(), at, &Change::SetDescription { text: String::new() }).await.unwrap();
    assert_eq!(fake.form(VM_CONFIG), form(&[("delete", "description"), ("digest", VM_DIGEST)]));
    client.change_hardware(&vm(), at, &Change::SetProtection { on: true }).await.unwrap();
    assert_eq!(fake.form(VM_CONFIG)["protection"], "1");
    let e = err(client.change_hardware(&vm(), at, &Change::SetName { name: "web_03".into() })).await;
    assert_eq!(refused(&e), Some(Issue::NameInvalid));

    // A container's name is its hostname.
    fake.route("GET /nodes/pve/lxc/9902/pending", |_| ok(json!([])));
    let hw = client.hardware(&ct()).await.unwrap();
    assert_eq!(hw.name.as_deref(), Some("sbhw-e2e-ct"));
    client.change_hardware(&ct(), hw.revision.as_deref(), &Change::SetName { name: "dns-02".into() }).await.unwrap();
    assert_eq!(fake.form(CT_CONFIG)["hostname"], "dns-02");
}

#[tokio::test]
async fn a_stale_digest_is_a_conflict_a_bad_value_the_hosts_words() {
    let fake = hw_api();
    let client = fake.client();
    fake.route(VM_CONFIG, |_| status(500, "checksum mismatch (file change by other user?)\n"));
    let e = err(client.change_hardware(&vm(), Some("older"), &Change::SetAutostart { on: true })).await;
    assert_eq!(e.kind, ErrorKind::Conflict);
    fake.route(VM_CONFIG, |_| sbm_virt::pve::http::Response {
        status: 400,
        reason: None,
        body: json!({"data": null, "message": "Parameter verification failed.", "errors": {"cores": "value must have a minimum value of 1"}})
            .to_string()
            .into_bytes(),
    });
    let e = err(client.change_hardware(&vm(), Some(VM_DIGEST), &Change::SetCpu { sockets: 1, cores: 1, online: None, cpu_type: None })).await;
    assert_ne!(e.kind, ErrorKind::Conflict);
    assert!(e.message.as_deref().unwrap_or_default().contains("minimum value of 1"), "{e:?}");
}

#[tokio::test]
async fn revert_pending_drops_each_pending_key() {
    let fake = hw_api();
    let client = fake.client();
    client.revert_pending(&vm(), Some(VM_DIGEST)).await.unwrap();
    let f = fake.form(VM_CONFIG);
    let mut keys: Vec<&str> = f["revert"].split(',').collect();
    keys.sort();
    assert_eq!(keys, vec!["boot", "cores", "cpu", "memory"]);
    assert_eq!(f["digest"], VM_DIGEST);
    // Nothing pending: nothing sent.
    let fake = hw_api();
    fake.client().revert_pending(&dev_vm(), Some(DEV_DIGEST)).await.unwrap();
    assert!(fake.paths().iter().all(|p| p.starts_with("GET ")), "{:?}", fake.paths());
}

// ---------------------------------------------------------------------------
// Devices, firmware, display
// ---------------------------------------------------------------------------

#[tokio::test]
async fn disk_cache_and_a_bus_change_with_the_boot_order_kept() {
    let fake = hw_api();
    let client = fake.client();
    let at = Some(DEV_DIGEST);
    client.change_hardware(&dev_vm(), at, &Change::UpdateDisk { key: "virtio0".into(), bus: None, cache: Some("default".into()) }).await.unwrap();
    assert_eq!(fake.form(DEV_CONFIG), form(&[("virtio0", "local-lvm:vm-9921-disk-0,size=1G"), ("digest", DEV_DIGEST)]));
    client.change_hardware(&dev_vm(), at, &Change::UpdateDisk { key: "virtio0".into(), bus: None, cache: Some("none".into()) }).await.unwrap();
    assert_eq!(fake.form(DEV_CONFIG)["virtio0"], "local-lvm:vm-9921-disk-0,cache=none,size=1G");
    // The boot order names the disk: it moves with it, in its place.
    let mut c = config("hw_vm_devices_config.json");
    c.insert("boot".into(), json!("order=scsi1;net0"));
    fake.route("GET /nodes/pve/qemu/9921/config", move |_| ok(Value::Object(c.clone())));
    client.change_hardware(&dev_vm(), at, &Change::UpdateDisk { key: "scsi1".into(), bus: Some("sata".into()), cache: None }).await.unwrap();
    assert_eq!(
        fake.form(DEV_CONFIG),
        form(&[
            ("sata0", "local-lvm:vm-9921-disk-4,cache=writethrough,size=1G"),
            ("boot", "order=sata0;net0"),
            ("delete", "scsi1"),
            ("digest", DEV_DIGEST),
        ])
    );
    // A disk not in the order: none sent.
    client.change_hardware(&dev_vm(), at, &Change::UpdateDisk { key: "virtio0".into(), bus: Some("scsi".into()), cache: None }).await.unwrap();
    assert_eq!(
        fake.form(DEV_CONFIG),
        form(&[("scsi0", "local-lvm:vm-9921-disk-0,cache=writeback,size=1G"), ("delete", "virtio0"), ("digest", DEV_DIGEST)])
    );
}

#[tokio::test]
async fn a_bus_change_drops_what_the_new_bus_does_not_take() {
    let fake = hw_api();
    let client = fake.client();
    // `virtio0` as a create makes it, with `iothread=1`, which SATA and IDE
    // refuse.
    let mut c = config("hw_vm_devices_config.json");
    c.insert("virtio0".into(), json!("local-lvm:vm-9921-disk-0,iothread=1,ro=1,size=1G"));
    fake.route("GET /nodes/pve/qemu/9921/config", move |_| ok(Value::Object(c.clone())));
    let at = Some(DEV_DIGEST);
    client.change_hardware(&dev_vm(), at, &Change::UpdateDisk { key: "virtio0".into(), bus: Some("sata".into()), cache: None }).await.unwrap();
    assert_eq!(fake.form(DEV_CONFIG)["sata0"], "local-lvm:vm-9921-disk-0,size=1G");
    client.change_hardware(&dev_vm(), at, &Change::UpdateDisk { key: "virtio0".into(), bus: Some("scsi".into()), cache: None }).await.unwrap();
    assert_eq!(fake.form(DEV_CONFIG)["scsi0"], "local-lvm:vm-9921-disk-0,iothread=1,ro=1,size=1G");
}

fn usb(host: HostDevice, naming: UsbNaming) -> Change {
    Change::AddDevice { kind: DeviceKind::Usb, host: Some(host), storage: None, usb_naming: naming }
}

#[tokio::test]
async fn nic_model_and_mac_devices_card() {
    let fake = hw_api();
    let client = fake.client();
    let at = Some(DEV_DIGEST);
    client
        .change_hardware(&dev_vm(), at, &Change::SetNicHardware { key: "net0".into(), model: Some("virtio".into()), mac: Some("bc:24:11:00:00:09".into()) })
        .await
        .unwrap();
    assert_eq!(fake.form(DEV_CONFIG), form(&[("net0", "virtio=BC:24:11:00:00:09,bridge=vmbr0"), ("digest", DEV_DIGEST)]));
    client.change_hardware(&dev_vm(), at, &usb(HostDevice { id: "bt".into(), label: "bt".into(), mapping: true, ..HostDevice::default() }, UsbNaming::Address)).await.unwrap();
    assert_eq!(fake.form(DEV_CONFIG)["usb2"], "mapping=bt");
    // A device by vendor and product (the default), or by where it sits.
    let dongle = HostDevice { id: "0bda:b023".into(), label: "bt".into(), usb_bus: Some(1), usb_port: Some("1.2".into()), ..HostDevice::default() };
    client.change_hardware(&dev_vm(), at, &usb(dongle.clone(), UsbNaming::VendorProduct)).await.unwrap();
    assert_eq!(fake.form(DEV_CONFIG)["usb2"], "host=0bda:b023");
    client.change_hardware(&dev_vm(), at, &usb(dongle, UsbNaming::Address)).await.unwrap();
    assert_eq!(fake.form(DEV_CONFIG)["usb2"], "host=1-1.2");
    // No port from the host: no address to give it by.
    let sent = fake.forms(DEV_CONFIG).len();
    let no_port = HostDevice { id: "0bda:b023".into(), label: "bt".into(), usb_bus: Some(1), ..HostDevice::default() };
    let e = err(client.change_hardware(&dev_vm(), at, &usb(no_port, UsbNaming::Address))).await;
    assert_eq!((e.kind, refused(&e)), (ErrorKind::Unsupported, Some(Issue::Device)));
    assert_eq!(fake.forms(DEV_CONFIG).len(), sent);
    let pci = |id: &str, mapping: bool| Change::AddDevice {
        kind: DeviceKind::Pci,
        host: Some(HostDevice { id: id.into(), label: "xHCI".into(), mapping, ..HostDevice::default() }),
        storage: None,
        usb_naming: UsbNaming::default(),
    };
    client.change_hardware(&dev_vm(), at, &pci("0000:00:14.0", false)).await.unwrap();
    assert_eq!(fake.form(DEV_CONFIG)["hostpci1"], "0000:00:14.0");
    client.change_hardware(&dev_vm(), at, &pci("gpu", true)).await.unwrap();
    assert_eq!(fake.form(DEV_CONFIG)["hostpci1"], "mapping=gpu");
    client.change_hardware(&dev_vm(), at, &Change::RemoveDevice { key: "usb1".into() }).await.unwrap();
    assert_eq!(fake.form(DEV_CONFIG), form(&[("delete", "usb1"), ("digest", DEV_DIGEST)]));
    client.change_hardware(&dev_vm(), at, &Change::SetDisplay { protocol: None, listen: None, gpu: Some("qxl".into()) }).await.unwrap();
    assert_eq!(fake.form(DEV_CONFIG)["vga"], "qxl");
    // A display with nothing to change sends nothing.
    let sent = fake.forms(DEV_CONFIG).len();
    client.change_hardware(&dev_vm(), at, &Change::SetDisplay { protocol: None, listen: None, gpu: None }).await.unwrap();
    assert_eq!(fake.forms(DEV_CONFIG).len(), sent);
}

#[tokio::test]
async fn a_cards_memory_is_kept() {
    let fake = hw_api();
    let mut c = config("hw_vm_devices_config.json");
    c.insert("vga".into(), json!("std,memory=64"));
    fake.route("GET /nodes/pve/qemu/9921/config", move |_| ok(Value::Object(c.clone())));
    let client = fake.client();
    client.change_hardware(&dev_vm(), Some(DEV_DIGEST), &Change::SetDisplay { protocol: None, listen: None, gpu: Some("qxl".into()) }).await.unwrap();
    assert_eq!(fake.form(DEV_CONFIG)["vga"], "qxl,memory=64");
    client.change_hardware(&dev_vm(), Some(DEV_DIGEST), &Change::SetDisplay { protocol: None, listen: None, gpu: Some("none".into()) }).await.unwrap();
    assert_eq!(fake.form(DEV_CONFIG)["vga"], "none");
}

#[tokio::test]
async fn a_tpm_on_a_storage_and_one_only() {
    let fake = hw_api();
    let client = fake.client();
    let tpm = Change::AddDevice { kind: DeviceKind::Tpm, host: None, storage: Some("pve/local-lvm".into()), usb_naming: UsbNaming::default() };
    // The devices VM has one already.
    let e = err(client.change_hardware(&dev_vm(), Some(DEV_DIGEST), &tpm)).await;
    assert_eq!(refused(&e), Some(Issue::Device));
    let mut c = config("hw_vm_devices_config.json");
    c.remove("tpmstate0");
    fake.route("GET /nodes/pve/qemu/9921/config", move |_| ok(Value::Object(c.clone())));
    client.change_hardware(&dev_vm(), Some(DEV_DIGEST), &tpm).await.unwrap();
    assert_eq!(fake.form(DEV_CONFIG), form(&[("tpmstate0", "local-lvm:1,version=v2.0"), ("digest", DEV_DIGEST)]));
    let none = Change::AddDevice { kind: DeviceKind::Tpm, host: None, storage: None, usb_naming: UsbNaming::default() };
    assert_eq!(refused(&err(client.change_hardware(&dev_vm(), Some(DEV_DIGEST), &none)).await), Some(Issue::StorageMissing));
}

#[tokio::test]
async fn firmware_secure_boot_is_a_new_variables_disk_bios_keeps_it() {
    let fake = hw_api();
    let client = fake.client();
    let at = Some(DEV_DIGEST);
    let fw = |uefi: bool, secure_boot: bool, storage: Option<&str>| Change::SetFirmware { uefi, secure_boot, storage: storage.map(Into::into) };
    // UEFI with the keys it has: only the firmware.
    client.change_hardware(&dev_vm(), at, &fw(true, true, None)).await.unwrap();
    assert_eq!(fake.form(DEV_CONFIG), form(&[("bios", "ovmf"), ("digest", DEV_DIGEST)]));
    // Without them: the variables disk made again, on the storage it is on.
    client.change_hardware(&dev_vm(), at, &fw(true, false, None)).await.unwrap();
    let all = bodies(&fake, DEV_CONFIG);
    assert_eq!(
        all[all.len() - 2..],
        [
            form(&[("delete", "efidisk0"), ("digest", DEV_DIGEST)]),
            form(&[("bios", "ovmf"), ("efidisk0", "local-lvm:1,efitype=4m,pre-enrolled-keys=0")]),
        ]
    );
    client.change_hardware(&dev_vm(), at, &fw(false, false, None)).await.unwrap();
    assert_eq!(fake.form(DEV_CONFIG), form(&[("bios", "seabios"), ("digest", DEV_DIGEST)]));
    // BIOS asked for with the Secure Boot flag still set: BIOS.
    client.change_hardware(&dev_vm(), at, &fw(false, true, None)).await.unwrap();
    assert_eq!(fake.form(DEV_CONFIG), form(&[("bios", "seabios"), ("digest", DEV_DIGEST)]));

    // A VM without one: the storage named.
    let mut c = config("hw_vm_devices_config.json");
    c.remove("efidisk0");
    c.insert("bios".into(), json!("seabios"));
    fake.route("GET /nodes/pve/qemu/9921/config", move |_| ok(Value::Object(c.clone())));
    assert_eq!(refused(&err(client.change_hardware(&dev_vm(), at, &fw(true, false, None))).await), Some(Issue::StorageMissing));
    client.change_hardware(&dev_vm(), at, &fw(true, true, Some("pve/local-lvm"))).await.unwrap();
    assert_eq!(
        fake.form(DEV_CONFIG),
        form(&[("bios", "ovmf"), ("efidisk0", "local-lvm:1,efitype=4m,pre-enrolled-keys=1"), ("digest", DEV_DIGEST)])
    );
}

fn password_client(fake: &Fake) -> Client {
    fake.route("POST /access/ticket", |_| ok(json!({"ticket": "PVE:root@pam:T", "CSRFPreventionToken": "C", "username": "root@pam"})));
    let config = Config {
        addr: "https://pve.lan:8006".into(),
        auth: Auth::Password { user: "root".into(), password: "pw".into() },
        cert_sha256: None,
    };
    let opts = Options { task_poll: Duration::from_millis(1), ..Options::default() };
    Client::new(config, Arc::new(fake.clone()), opts)
}

fn device_api() -> Fake {
    let fake = hw_api();
    fake.route("GET /nodes/pve/hardware/pci", |_| ok(fixture("hardware_pci.json")));
    fake.route("GET /nodes/pve/hardware/usb", |_| ok(fixture("hardware_usb.json")));
    fake.route("GET /cluster/mapping/usb", |_| ok(fixture("mapping_usb.json")));
    fake.route("GET /cluster/mapping/pci", |_| ok(fixture("mapping_pci.json")));
    fake
}

#[tokio::test]
async fn host_devices_a_token_gets_mappings_root_pam_the_nodes_too() {
    let fake = device_api();
    let token = fake.client().host_devices(&dev_vm()).await.unwrap();
    assert!(token.mappings_only);
    let ids = |l: &[HostDevice]| l.iter().map(|d| (d.id.clone(), d.mapping)).collect::<Vec<_>>();
    assert_eq!(ids(&token.usb), vec![("sbhwb-bt".to_owned(), true)]);
    assert_eq!(ids(&token.pci), vec![("sbhwb-xhci".to_owned(), true)]);
    assert_eq!(token.usb[0].detail.as_deref(), Some("0bda:b023"));
    assert_eq!(token.pci[0].detail.as_deref(), Some("0000:00:14.0 · 8086:a12f"));
    // No IOMMU group on any device: the host has none on.
    assert!(!token.iommu);
    // A token is never shown the node's own USB devices.
    assert!(!fake.paths().iter().any(|p| p == "GET /nodes/pve/hardware/usb"));

    let fake = device_api();
    let root = password_client(&fake).host_devices(&dev_vm()).await.unwrap();
    assert!(!root.mappings_only);
    // Hubs left out; the Bluetooth radio offered by id, with where it sits.
    assert_eq!(root.usb.iter().map(|d| d.id.as_str()).collect::<Vec<_>>(), vec!["sbhwb-bt", "0bda:b023"]);
    let bt = &root.usb[1];
    assert_eq!((bt.label.as_str(), bt.usb_bus, bt.usb_port.as_deref()), ("Realtek Bluetooth Radio", Some(1), Some("13")));
    assert_eq!(bt.usb_address(sbm_virt::model::HostKind::Pve).as_deref(), Some("1-13"));
    assert_eq!(root.pci.len(), 1 + list("hardware_pci.json").len());
    let last = root.pci.last().unwrap();
    assert_eq!((last.id.as_str(), last.iommu_group, last.group_size), ("0000:05:00.0", None, 0));
    assert_eq!(last.label, "ASM1142 USB 3.1 Host Controller");
}

#[test]
fn iommu_groups_counted_per_group() {
    let pci = vec![
        json!({"id": "0000:01:00.0", "iommugroup": 1, "vendor": "0x10de", "device": "0x1b80"}),
        json!({"id": "0000:01:00.1", "iommugroup": 1, "vendor": "0x10de", "device": "0x10f0"}),
        json!({"id": "0000:02:00.0", "iommugroup": 2, "device_name": "NVMe"}),
    ];
    let usb = vec![json!({"busnum": 3, "class": 0, "vendid": "1a86", "prodid": "7523", "usbpath": "1.2", "manufacturer": " ", "product": ""})];
    let d = host_devices("pve", &[], &[], &pci, &usb, true);
    // Nothing named: its ids.
    assert_eq!((d.usb[0].label.as_str(), d.usb[0].usb_port.as_deref()), ("1a86:7523", Some("1.2")));
    assert!(d.iommu);
    let groups: Vec<(Option<u32>, u32)> = d.pci.iter().map(|p| (p.iommu_group, p.group_size)).collect();
    assert_eq!(groups, vec![(Some(1), 2), (Some(1), 2), (Some(2), 1)]);
    // No device name: the vendor and device ids.
    assert_eq!(d.pci[0].label, "10de:1b80");
    // A node without PCI devices listed is not said to lack an IOMMU.
    assert!(host_devices("pve", &[], &[], &[], &[], true).iommu);
}

#[test]
fn a_mapping_described_by_this_nodes_entry() {
    let maps = vec![json!({"id": "gpu", "map": ["node=other,path=0000:09:00.0,id=1:2", "node=pve,path=0000:01:00.0,id=10de:1b80,iommugroup=3"]})];
    let d = host_devices("pve", &[], &maps, &[], &[], false);
    assert_eq!(d.pci[0].detail.as_deref(), Some("0000:01:00.0 · 10de:1b80"));
    assert_eq!(d.pci[0].iommu_group, Some(3));
    let d = host_devices("third", &[], &maps, &[], &[], false);
    assert_eq!(d.pci[0].detail.as_deref(), Some("0000:09:00.0 · 1:2"));
    // A node's name is matched whole: `pve` is not `pve2`.
    let maps = vec![json!({"id": "gpu", "map": ["node=pve2,path=0000:09:00.0,id=1:2", "node=pve,path=0000:01:00.0,id=10de:1b80"]})];
    let d = host_devices("pve", &[], &maps, &[], &[], false);
    assert_eq!(d.pci[0].detail.as_deref(), Some("0000:01:00.0 · 10de:1b80"));
}

#[test]
fn counts_past_what_a_u32_holds_do_not_panic() {
    let mut config = Map::new();
    config.insert("sockets".into(), json!(2147483648u64));
    config.insert("cores".into(), json!(2));
    config.insert("vcpus".into(), json!(4));
    let hw = parse_hardware(&config, &[], GuestKind::Qemu, false, Limits::default(), Vec::new());
    assert_eq!(hw.cpu.sockets, 2147483648);
    assert_eq!(hw.cpu.online, Some(4));
}
