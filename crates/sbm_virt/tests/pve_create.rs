//! `pve::Client` making, copying and deleting guests against a scripted PVE
//! API: each request's parameters, the order of the steps, the refusals
//! said before anything is sent, and the host's own words where it refuses.
//!
//! Ported from the app's `test/unit/virt/pve_backend_test.dart`.

mod common;

use common::*;
use sbm_virt::create::{CloneRequest, CloudInit, CreateSpec, Issue, VolumeRef};
use sbm_virt::error::{Detail, Error, ErrorKind};
use sbm_virt::model::{Guest, GuestKind, GuestState};
use sbm_virt::pve::http::Response;
use serde_json::{Value, json};

fn refused(e: &Error) -> Option<Issue> {
    match e.detail.as_deref() {
        Some(Detail::CreateRefused { issue }) => Some(*issue),
        _ => None,
    }
}

/// A node `pve` with VM 100, its storages (`local` for media and images,
/// `local-lvm` for disks) and bridge `vmbr0`.
fn host() -> Fake {
    let fake = Fake::new();
    fake.route("GET /cluster/resources", |_| {
        ok(json!([
            {"id": "node/pve", "type": "node", "node": "pve", "status": "online", "maxcpu": 8},
            {"id": "qemu/100", "type": "qemu", "vmid": 100, "node": "pve", "status": "running", "name": "debian-libvirt"},
        ]))
    });
    fake.route("GET /storage", |_| ok(json!([])));
    fake.route("GET /nodes/pve/storage", |_| {
        ok(json!([
            {"storage": "local", "type": "dir", "active": 1, "enabled": 1, "content": "iso,vztmpl,import,backup"},
            {"storage": "local-lvm", "type": "lvmthin", "active": 1, "enabled": 1, "content": "images,rootdir"},
        ]))
    });
    fake.route("GET /nodes/pve/storage/local/content", |_| {
        ok(json!([
            {"volid": "local:iso/debian-13.iso", "content": "iso", "format": "iso", "size": 1000},
            {"volid": "local:vztmpl/alpine-3.22.tar.xz", "content": "vztmpl", "format": "txz", "size": 1000},
            {"volid": "local:import/debian-13.qcow2", "content": "import", "format": "qcow2", "size": 300},
            {"volid": "local:import/x.raw", "content": "import", "format": "raw", "size": 300},
        ]))
    });
    // The virtual size of each import image.
    fake.route("GET /nodes/pve/storage/local/content/local%3Aimport%2Fdebian-13.qcow2", |_| ok(json!({"size": 3u64 << 30})));
    fake.route("GET /nodes/pve/storage/local/content/local%3Aimport%2Fx.raw", |_| ok(json!({})));
    fake.route("GET /nodes/pve/network", |_| ok(json!([{"iface": "vmbr0", "type": "bridge", "active": 1}])));
    fake
}

/// The host's guests: VM 100 and these.
fn listing(fake: &Fake, guests: Vec<Value>) {
    let mut all = vec![
        json!({"id": "node/pve", "type": "node", "node": "pve", "status": "online", "maxcpu": 8}),
        json!({"id": "qemu/100", "type": "qemu", "vmid": 100, "node": "pve", "status": "running", "name": "debian-libvirt"}),
    ];
    all.extend(guests);
    fake.route("GET /cluster/resources", move |_| ok(Value::Array(all.clone())));
}

fn listed(g: &Guest) -> Value {
    json!({
        "id": g.id, "type": g.kind.as_str(), "vmid": g.vmid, "node": "pve", "name": g.name,
        "status": if g.state == GuestState::Stopped { "stopped" } else { "running" },
        "template": u8::from(g.template),
    })
}

fn vm(name: &str, vmid: u32) -> CreateSpec {
    CreateSpec {
        kind: GuestKind::Qemu,
        name: name.into(),
        node: Some("pve".into()),
        vmid: Some(vmid),
        cores: 2,
        memory_mib: 2048,
        storage: "pve/local-lvm".into(),
        disk_gib: 32,
        media: None,
        image: None,
        network: None,
        password: None,
        ssh_keys: Vec::new(),
        unprivileged: true,
        bus: None,
        nic_model: None,
        uefi: false,
        secure_boot: false,
        tpm: false,
        cloud_init: None,
        start: false,
    }
}

fn at(pool: &str, volume: &str) -> Option<VolumeRef> {
    Some(VolumeRef { pool: pool.into(), volume: volume.into() })
}

fn index(fake: &Fake, key: &str) -> usize {
    fake.paths().iter().position(|p| p == key).unwrap_or_else(|| panic!("no {key} in {:?}", fake.paths()))
}

#[tokio::test]
async fn next_vmid() {
    let fake = host();
    fake.route("GET /cluster/nextid", |_| ok(json!("105")));
    assert_eq!(fake.client().next_vmid().await.unwrap(), 105);
}

#[tokio::test]
async fn a_vm_its_configuration_the_task_then_start_on_its_own() {
    let fake = host();
    fake.route("POST /nodes/pve/qemu", |_| ok(json!(UPID)));
    fake.route("POST /nodes/pve/qemu/105/status/start", |_| ok(json!(UPID)));
    let spec = CreateSpec {
        media: at("pve/local", "local:iso/debian-13.iso"),
        network: Some("pve/vmbr0".into()),
        start: true,
        ..vm("web-02", 105)
    };
    let created = fake.client().create(&spec).await.unwrap();
    assert_eq!(created.id, "qemu/105");
    assert_eq!(created.start_error, None);
    let form = fake.form("POST /nodes/pve/qemu");
    let want: Vec<(&str, &str)> = vec![
        ("vmid", "105"),
        ("name", "web-02"),
        ("cores", "2"),
        ("memory", "2048"),
        ("ostype", "l26"),
        ("scsihw", "virtio-scsi-single"),
        ("scsi0", "local-lvm:32,iothread=1"),
        ("ide2", "local:iso/debian-13.iso,media=cdrom"),
        ("net0", "virtio,bridge=vmbr0"),
        ("serial0", "socket"),
        ("boot", "order=scsi0;ide2"),
    ];
    assert_eq!(form, want.into_iter().map(|(k, v)| (k.to_owned(), v.to_owned())).collect());
    // Created (its task waited for) before it is started.
    let i = index(&fake, "POST /nodes/pve/qemu");
    let start = index(&fake, "POST /nodes/pve/qemu/105/status/start");
    let task = fake.paths().iter().position(|p| p.contains("/tasks/")).unwrap();
    assert!(i < task && task < start);
}

#[tokio::test]
async fn a_cloud_image_with_cloud_init_import_from_pves_drive_grown_before_the_start() {
    let fake = host();
    fake.route("POST /nodes/pve/qemu", |_| ok(json!(UPID)));
    // Imported at the image's own size.
    fake.route("GET /nodes/pve/qemu/107/config", |_| ok(json!({"scsi0": "local-lvm:vm-107-disk-1,iothread=1,size=3G"})));
    fake.route("PUT /nodes/pve/qemu/107/resize", |_| ok(json!(UPID)));
    fake.route("POST /nodes/pve/qemu/107/status/start", |_| ok(json!(UPID)));
    let key = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5 me@x";
    let spec = CreateSpec {
        cores: 1,
        memory_mib: 1024,
        disk_gib: 16,
        image: at("pve/local", "local:import/debian-13.qcow2"),
        network: Some("pve/vmbr0".into()),
        nic_model: Some("e1000e".into()),
        uefi: true,
        tpm: true,
        cloud_init: Some(CloudInit {
            user: "admin".into(),
            password: Some("p a&ss=word".into()),
            ssh_keys: vec![key.into(), String::new()],
            address: Some("10.0.0.5/24".into()),
            gateway: Some("10.0.0.1".into()),
            dns: vec!["1.1.1.1".into(), "9.9.9.9".into()],
            search_domains: vec!["lab.example".into()],
            ..Default::default()
        }),
        start: true,
        ..vm("ci-01", 107)
    };
    let client = fake.client();
    let created = client.create(&spec).await.unwrap();
    assert_eq!(created.start_error, None);
    assert_eq!(created.disk_kept_bytes, None);
    let form = fake.form("POST /nodes/pve/qemu");
    let get = |k: &str| form.get(k).map(String::as_str);
    assert_eq!(get("scsi0"), Some("local-lvm:0,import-from=local:import/debian-13.qcow2,iothread=1"));
    // Where a cloud kernel reads it: not IDE.
    assert_eq!(get("scsi1"), Some("local-lvm:cloudinit"));
    assert_eq!(get("ide2"), None);
    assert_eq!(get("net0"), Some("e1000e,bridge=vmbr0"));
    assert_eq!(get("boot"), Some("order=scsi0"));
    assert_eq!(get("bios"), Some("ovmf"));
    assert_eq!(get("efidisk0"), Some("local-lvm:1,efitype=4m,pre-enrolled-keys=0"));
    assert_eq!(get("tpmstate0"), Some("local-lvm:1,version=v2.0"));
    assert_eq!(get("ciuser"), Some("admin"));
    assert_eq!(get("cipassword"), Some("p a&ss=word"));
    // Encoded once more inside the form, as PVE wants it.
    assert_eq!(get("sshkeys"), Some("ssh-ed25519%20AAAAC3NzaC1lZDI1NTE5%20me%40x%0A"));
    assert_eq!(get("ipconfig0"), Some("ip=10.0.0.5/24,gw=10.0.0.1"));
    assert_eq!(get("nameserver"), Some("1.1.1.1 9.9.9.9"));
    assert_eq!(get("searchdomain"), Some("lab.example"));
    // Secure Boot is offered: the EFI disk with the keys enrolled.
    assert!(client.create_options().secure_boot);
    // Grown to the size asked for, then started.
    let resize = fake.form("PUT /nodes/pve/qemu/107/resize");
    assert_eq!(resize.get("disk").map(String::as_str), Some("scsi0"));
    assert_eq!(resize.get("size").map(String::as_str), Some("16G"));
    let (i, r, s) = (
        index(&fake, "POST /nodes/pve/qemu"),
        index(&fake, "PUT /nodes/pve/qemu/107/resize"),
        index(&fake, "POST /nodes/pve/qemu/107/status/start"),
    );
    assert!(i < r && r < s);
    // No password anywhere but the body.
    let a = fake.0.lock().unwrap();
    assert!(!a.queries.join("").contains("ss=word") && !a.paths.join("").contains("ss=word"));
}

#[tokio::test]
async fn an_image_bigger_than_the_disk_keeps_its_size_not_grown_and_not_failed() {
    let fake = host();
    fake.route("POST /nodes/pve/qemu", |_| ok(json!(UPID)));
    fake.route("GET /nodes/pve/qemu/109/config", |_| ok(json!({"scsi0": "local-lvm:vm-109-disk-0,iothread=1,size=3584M"})));
    fake.route("POST /nodes/pve/qemu/109/status/start", |_| ok(json!(UPID)));
    // The listing's size was the file's, and PVE did not say the virtual
    // one: unknown, so the rules let it through.
    let spec = CreateSpec {
        cores: 1,
        memory_mib: 1024,
        disk_gib: 2,
        image: at("pve/local", "local:import/x.raw"),
        cloud_init: Some(CloudInit { user: "u".into(), password: Some("pw".into()), ..Default::default() }),
        start: true,
        ..vm("ci-03", 109)
    };
    let created = fake.client().create(&spec).await.unwrap();
    assert_eq!(created.disk_kept_bytes, Some(3584 << 20));
    assert_eq!(created.start_error, None);
    assert!(!fake.paths().iter().any(|p| p.ends_with("/resize")));
    assert!(fake.paths().contains(&"POST /nodes/pve/qemu/109/status/start".to_owned()));
}

#[tokio::test]
async fn a_disk_on_sata_has_no_io_thread_a_failed_growth_is_not_started() {
    let fake = host();
    fake.route("POST /nodes/pve/qemu", |_| ok(json!(UPID)));
    fake.route("PUT /nodes/pve/qemu/108/resize", |_| status(500, "resize failed"));
    let spec = CreateSpec {
        cores: 1,
        memory_mib: 1024,
        disk_gib: 8,
        image: at("pve/local", "local:import/x.raw"),
        bus: Some("sata".into()),
        cloud_init: Some(CloudInit { user: "u".into(), password: Some("pw".into()), ..Default::default() }),
        start: true,
        ..vm("ci-02", 108)
    };
    let created = fake.client().create(&spec).await.unwrap();
    let form = fake.form("POST /nodes/pve/qemu");
    assert_eq!(form["sata0"], "local-lvm:0,import-from=local:import/x.raw");
    assert_eq!(form["boot"], "order=sata0");
    assert_eq!(form["sata1"], "local-lvm:cloudinit");
    // No NIC: DHCP all the same (PVE writes it for none), no key.
    assert_eq!(form["ipconfig0"], "ip=dhcp");
    assert!(!form.contains_key("sshkeys"));
    assert!(created.start_error.unwrap().contains("resize failed"));
    assert!(!fake.paths().iter().any(|p| p.contains("status/start")));
}

#[tokio::test]
async fn a_container_template_rootfs_dhcp_and_its_login() {
    let fake = host();
    fake.route("POST /nodes/pve/lxc", |_| ok(json!(UPID)));
    let spec = CreateSpec {
        kind: GuestKind::Lxc,
        cores: 1,
        memory_mib: 512,
        disk_gib: 8,
        media: at("pve/local", "local:vztmpl/alpine-3.22.tar.xz"),
        network: Some("pve/vmbr0".into()),
        password: Some("p4ss word&=".into()),
        ssh_keys: vec!["ssh-ed25519 AAAAC3Nza me@host".into(), String::new()],
        ..vm("ct-01", 201)
    };
    let created = fake.client().create(&spec).await.unwrap();
    assert_eq!(created.id, "lxc/201");
    assert!(!fake.paths().iter().any(|p| p.starts_with("POST /nodes/pve/lxc/201/status")));
    let want: Vec<(&str, &str)> = vec![
        ("vmid", "201"),
        ("hostname", "ct-01"),
        ("ostemplate", "local:vztmpl/alpine-3.22.tar.xz"),
        ("cores", "1"),
        ("memory", "512"),
        ("rootfs", "local-lvm:8"),
        ("unprivileged", "1"),
        ("net0", "name=eth0,bridge=vmbr0,ip=dhcp"),
        // In the body, encoded, as typed.
        ("password", "p4ss word&="),
        ("ssh-public-keys", "ssh-ed25519 AAAAC3Nza me@host"),
    ];
    assert_eq!(fake.form("POST /nodes/pve/lxc"), want.into_iter().map(|(k, v)| (k.to_owned(), v.to_owned())).collect());
    // Nowhere else: not in a path, not in a query.
    assert!(!fake.0.lock().unwrap().queries.join("").contains("p4ss"));
}

#[tokio::test]
async fn refused_before_it_is_sent_a_vmid_taken_a_name_taken_a_storage_for_no_disks() {
    let fake = host();
    let client = fake.client();
    let e = client.create(&vm("x", 100)).await.unwrap_err();
    assert_eq!((e.kind, refused(&e)), (ErrorKind::Exists, Some(Issue::VmidTaken)));
    let e = client.create(&vm("debian-libvirt", 105)).await.unwrap_err();
    assert_eq!((e.kind, refused(&e)), (ErrorKind::Exists, Some(Issue::NameTaken)));
    let e = client.create(&CreateSpec { storage: "pve/local".into(), ..vm("x", 105) }).await.unwrap_err();
    assert_eq!(refused(&e), Some(Issue::Storage));
    let e = client.create(&CreateSpec { cores: 9, ..vm("x", 105) }).await.unwrap_err();
    assert_eq!(refused(&e), Some(Issue::Cores), "more than the node has");
    let e = client.create(&CreateSpec { media: at("pve/local", "local:iso/gone.iso"), ..vm("x", 105) }).await.unwrap_err();
    assert_eq!(refused(&e), Some(Issue::Media));
    // The 3 GiB image does not fit a 2 GiB disk.
    let small = CreateSpec { disk_gib: 2, image: at("pve/local", "local:import/debian-13.qcow2"), ..vm("x", 105) };
    assert_eq!(refused(&client.create(&small).await.unwrap_err()), Some(Issue::ImageSize));
    assert!(!fake.paths().iter().any(|p| p.starts_with("POST")), "{:?}", fake.paths());
}

#[tokio::test]
async fn a_node_listing_that_failed_is_the_failure_not_the_clusters_cache() {
    // The cluster's cache may still call a new guest `VM <vmid>`: a name
    // check made on it alone would let a second guest of a name through.
    let fake = host();
    fake.route("GET /nodes/pve/qemu", |_| status(500, "got timeout"));
    let e = fake.client().create(&vm("x", 105)).await.unwrap_err();
    assert_ne!(refused(&e), Some(Issue::NameTaken));
    assert_eq!(e.message.as_deref(), Some("got timeout"));
    // Nor one answered as something other than a list.
    fake.route("GET /nodes/pve/qemu", |_| ok(json!({})));
    assert_eq!(fake.client().create(&vm("x", 105)).await.unwrap_err().kind, ErrorKind::InvalidResponse);
    assert!(!fake.paths().iter().any(|p| p.starts_with("POST")), "{:?}", fake.paths());
}

#[tokio::test]
async fn a_vmid_taken_by_then_is_exists_a_bad_parameter_the_hosts_words() {
    let fake = host();
    fake.route("POST /nodes/pve/qemu", |_| status(500, "unable to create VM 105 - VM 105 already exists on node 'pve'\n"));
    let client = fake.client();
    let taken = client.create(&vm("x", 105)).await.unwrap_err();
    assert_eq!(taken.kind, ErrorKind::Exists);
    assert!(taken.message.unwrap().contains("already exists"));
    fake.route("POST /nodes/pve/qemu", |_| {
        let body = json!({"data": null, "message": "Parameter verification failed.\n", "errors": {"memory": "value must have a minimum value of 16\n"}});
        Response { status: 400, ..whole(body) }
    });
    let bad = client.create(&vm("x", 105)).await.unwrap_err();
    assert_eq!(bad.kind, ErrorKind::ActionFailed);
    assert_eq!(bad.message.as_deref(), Some("Parameter verification failed.\nmemory: value must have a minimum value of 16"));
}

#[tokio::test]
async fn created_then_not_started_a_start_error_not_a_failure() {
    let fake = host();
    fake.route("POST /nodes/pve/qemu", |_| ok(json!(UPID)));
    fake.route("POST /nodes/pve/qemu/106/status/start", |_| status(500, "start failed: no memory"));
    let created = fake.client().create(&CreateSpec { start: true, ..vm("x", 106) }).await.unwrap();
    assert_eq!(created.id, "qemu/106");
    assert_eq!(created.start_error.as_deref(), Some("start failed: no memory"));
}

#[tokio::test]
async fn no_vmid_takes_the_next_free_one() {
    let fake = host();
    fake.route("GET /cluster/nextid", |_| ok(json!("117")));
    fake.route("POST /nodes/pve/qemu", |_| ok(json!(UPID)));
    let created = fake.client().create(&CreateSpec { vmid: None, ..vm("x", 0) }).await.unwrap();
    assert_eq!(created.id, "qemu/117");
    assert_eq!(fake.form("POST /nodes/pve/qemu")["vmid"], "117");
}

fn guest(id: &str, name: &str, kind: GuestKind, state: GuestState) -> Guest {
    let vmid: u32 = id.rsplit('/').next().unwrap().parse().unwrap();
    Guest {
        id: id.into(),
        name: name.into(),
        kind,
        state,
        state_reason: None,
        vmid: Some(vmid),
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

#[tokio::test]
async fn delete_stopped_only_purged_unreferenced_disks_too() {
    let fake = host();
    fake.route("DELETE /nodes/pve/qemu/101", |_| ok(json!(UPID)));
    let client = fake.client();
    let off = guest("qemu/101", "off", GuestKind::Qemu, GuestState::Stopped);
    listing(&fake, vec![listed(&off)]);
    client.delete(&off).await.unwrap();
    let i = index(&fake, "DELETE /nodes/pve/qemu/101");
    assert_eq!(fake.0.lock().unwrap().queries[i], "purge=1&destroy-unreferenced-disks=1");
    assert!(fake.paths().last().unwrap().contains("/tasks/"));
    // As the host has it now, not as the caller had it.
    let running = Guest { state: GuestState::Running, ..off.clone() };
    listing(&fake, vec![listed(&running)]);
    let e = client.delete(&off).await.unwrap_err();
    assert_eq!(refused(&e), Some(Issue::NotStopped));
    listing(&fake, vec![]);
    assert_eq!(refused(&client.delete(&off).await.unwrap_err()), Some(Issue::NotFound));
}

#[tokio::test]
async fn a_template_a_stopped_guest_and_pves_words_where_it_refuses() {
    let fake = host();
    // PVE 9.2.2, answered before any task.
    fake.route("POST /nodes/pve/qemu/9/template", |_| status(500, "unable to create template, because VM contains snapshots"));
    let client = fake.client();
    let vm = guest("qemu/9", "a", GuestKind::Qemu, GuestState::Stopped);
    listing(&fake, vec![listed(&vm)]);
    let e = client.make_template(&vm).await.unwrap_err();
    assert_eq!(e.kind, ErrorKind::ActionFailed);
    assert_eq!(e.message.as_deref(), Some("unable to create template, because VM contains snapshots"));
    fake.route("POST /nodes/pve/qemu/9/template", |_| ok(Value::Null));
    client.make_template(&vm).await.unwrap();
    listing(&fake, vec![listed(&Guest { template: true, ..vm.clone() })]);
    assert_eq!(refused(&client.make_template(&vm).await.unwrap_err()), Some(Issue::IsTemplate));
    listing(&fake, vec![listed(&Guest { state: GuestState::Running, ..vm.clone() })]);
    assert_eq!(refused(&client.make_template(&vm).await.unwrap_err()), Some(Issue::NotStopped));
}

#[tokio::test]
async fn clone_full_unless_a_template_asks_for_linked_a_vmid_taken() {
    let fake = host();
    fake.route("GET /cluster/nextid", |_| ok(json!("120")));
    fake.route("POST /nodes/pve/qemu/9941/clone", |_| ok(json!(UPID)));
    fake.route("POST /nodes/pve/lxc/200/clone", |_| ok(json!(UPID)));
    let client = fake.client();
    let vm = guest("qemu/9941", "sbbk-src", GuestKind::Qemu, GuestState::Stopped);
    let ct = guest("lxc/200", "alpine", GuestKind::Lxc, GuestState::Stopped);
    listing(&fake, vec![listed(&vm), listed(&ct)]);
    let req = |name: &str, full: bool, vmid: Option<u32>| CloneRequest {
        name: name.into(),
        full,
        vmid,
        storage: None,
        target_node: None,
        target_pool: None,
    };
    assert_eq!(client.clone_guest(&vm, &req("copy", false, None)).await.unwrap(), "qemu/120");
    let sent = |f: &[(&str, &str)]| f.iter().map(|(k, v)| ((*k).to_owned(), (*v).to_owned())).collect();
    assert_eq!(fake.form("POST /nodes/pve/qemu/9941/clone"), sent(&[("newid", "120"), ("name", "copy"), ("full", "1")]));
    assert!(fake.paths().last().unwrap().contains("/tasks/"), "waited for");

    let template = Guest { template: true, ..vm.clone() };
    listing(&fake, vec![listed(&template), listed(&ct)]);
    client.clone_guest(&vm, &req("l", false, Some(121))).await.unwrap();
    assert_eq!(fake.form("POST /nodes/pve/qemu/9941/clone"), sent(&[("newid", "121"), ("name", "l"), ("full", "0")]));

    assert_eq!(client.clone_guest(&ct, &req("ct2", true, Some(202))).await.unwrap(), "lxc/202");
    assert_eq!(fake.form("POST /nodes/pve/lxc/200/clone"), sent(&[("newid", "202"), ("hostname", "ct2"), ("full", "1")]));

    // A full clone to a storage of the node's.
    let to = CloneRequest { storage: Some("local-lvm".into()), ..req("moved", true, Some(122)) };
    client.clone_guest(&vm, &to).await.unwrap();
    assert_eq!(fake.form("POST /nodes/pve/qemu/9941/clone")["storage"], "local-lvm");

    // Checked here; and where PVE says it, in its words.
    let e = client.clone_guest(&vm, &req("x", true, Some(100))).await.unwrap_err();
    assert_eq!((e.kind, refused(&e)), (ErrorKind::Exists, Some(Issue::VmidTaken)));
    fake.route("POST /nodes/pve/qemu/9941/clone", |_| status(500, "unable to create VM 123 - VM 123 already exists on node 'pve'"));
    let e = client.clone_guest(&vm, &req("x", true, Some(123))).await.unwrap_err();
    assert_eq!(e.kind, ErrorKind::Exists);
    let e = client.clone_guest(&vm, &CloneRequest { storage: Some("local".into()), ..req("y", true, Some(124)) }).await.unwrap_err();
    assert_eq!(refused(&e), Some(Issue::CloneStorageContent));
}

#[tokio::test]
async fn a_form_for_a_node_what_it_offers() {
    let fake = host();
    fake.route("GET /cluster/nextid", |_| ok(json!("105")));
    let form = fake.client().create_form(GuestKind::Qemu, "pve").await.unwrap();
    assert_eq!(form.next_vmid, Some(105));
    assert_eq!(form.storages.iter().map(|p| p.id.as_str()).collect::<Vec<_>>(), ["pve/local-lvm"]);
    assert_eq!(form.networks.iter().map(|n| n.id.as_str()).collect::<Vec<_>>(), ["pve/vmbr0"]);
    assert_eq!(form.media.iter().map(|o| o.volume.id.as_str()).collect::<Vec<_>>(), ["local:iso/debian-13.iso"]);
    assert_eq!(
        form.images.iter().map(|o| o.volume.id.as_str()).collect::<Vec<_>>(),
        ["local:import/debian-13.qcow2", "local:import/x.raw"]
    );
    assert_eq!(form.images[0].volume.capacity, Some(3 << 30), "the virtual size, asked for");
    let ct = fake.client().create_form(GuestKind::Lxc, "pve").await.unwrap();
    assert_eq!(ct.media.iter().map(|o| o.volume.id.as_str()).collect::<Vec<_>>(), ["local:vztmpl/alpine-3.22.tar.xz"]);
}

#[tokio::test]
async fn names_are_the_nodes_own_not_the_clusters_lagging_cache() {
    let fake = host();
    // Right after a clone PVE's cluster cache lists the copy by its VMID
    // (PVE 9.2.2); the node's own listing has its name already.
    listing(&fake, vec![json!({"id": "qemu/109", "type": "qemu", "vmid": 109, "node": "pve", "name": "VM 109", "status": "stopped"})]);
    fake.route("GET /nodes/pve/qemu", |_| {
        ok(json!([
            {"vmid": 100, "name": "debian-libvirt", "status": "running"},
            {"vmid": 109, "name": "copy", "status": "stopped", "template": 1},
        ]))
    });
    fake.route("GET /nodes/pve/lxc", |_| ok(json!([])));
    let client = fake.client();
    let e = client.create(&vm("copy", 110)).await.unwrap_err();
    assert_eq!(refused(&e), Some(Issue::NameTaken));
    let stale = guest("qemu/109", "VM 109", GuestKind::Qemu, GuestState::Stopped);
    assert_eq!(refused(&client.make_template(&stale).await.unwrap_err()), Some(Issue::IsTemplate));
}
