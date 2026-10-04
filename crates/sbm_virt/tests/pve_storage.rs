//! `pve::Client`'s storages and networks against a scripted PVE API: the
//! listings, each change's request, the refusals made before anything is
//! sent, the management interface kept out of an edit and an apply, and a
//! node's network changes made one at a time.
//!
//! Ported from the app's `test/unit/virt/pve_backend_test.dart`.

mod common;

use std::collections::{BTreeMap, BTreeSet};
use std::sync::{Arc, Mutex};
use std::time::Duration;

use common::*;
use sbm_virt::error::{Detail, Error, ErrorKind};
use sbm_virt::model::{Guest, GuestKind, GuestState};
use sbm_virt::pve::net::parse_live_net;
use sbm_virt::pve::resources;
use sbm_virt::resource::{Change, GuestRef, Issue};
use serde_json::{Value, json};
use tokio::sync::Notify;

fn refused(e: &Error) -> Option<Issue> {
    match e.detail.as_deref() {
        Some(Detail::Refused { issue }) => Some(*issue),
        _ => None,
    }
}

// ---------------------------------------------------------------------------
// Reading
// ---------------------------------------------------------------------------

#[test]
fn storage_node_figures_with_the_cluster_configuration() {
    let pools = resources::parse_storages("pve", &list("node_storage.json"), &list("storage_config.json"));
    assert_eq!(pools.iter().map(|p| p.id.as_str()).collect::<Vec<_>>(), ["pve/local", "pve/local-lvm"]);
    let local = &pools[0];
    assert_eq!(local.pool_type, "dir");
    assert_eq!(local.path.as_deref(), Some("/var/lib/vz"));
    assert_eq!(local.content, ["backup", "import", "iso", "vztmpl"]);
    assert_eq!(local.capacity, Some(105089261568));
    assert_eq!(local.shared, Some(false));
    let lvm = &pools[1];
    assert_eq!(lvm.path.as_deref(), Some("pve/data"));
    assert_eq!(lvm.used, Some(4176431231));
    assert_eq!(lvm.available, Some(848156473217));
    // Without the configuration (no Datastore.Audit on /storage): no path.
    assert_eq!(resources::parse_storages("pve", &list("node_storage.json"), &[])[0].path, None);
    // A network storage says where it comes from.
    let nfs = resources::parse_storages(
        "pve",
        &[json!({"storage": "nas", "type": "nfs", "active": 0, "content": "backup"})],
        &[json!({"storage": "nas", "type": "nfs", "server": "10.0.0.5", "export": "/export/pve", "path": "/mnt/pve/nas"})],
    );
    assert_eq!(nfs[0].source.as_deref(), Some("10.0.0.5:/export/pve"));
    assert!(!nfs[0].active);
    assert_eq!(nfs[0].capacity, None);
}

#[test]
fn content_names_kinds_and_owners() {
    let vols = resources::parse_content(&list("content_local_lvm.json"));
    assert_eq!(
        vols.iter().map(|v| v.name.as_str()).collect::<Vec<_>>(),
        ["vm-100-cloudinit", "vm-100-disk-0", "vm-101-cloudinit", "vm-101-disk-0", "vm-101-state-sbx-mem", "vm-200-disk-0"]
    );
    let disk = &vols[1];
    assert_eq!(disk.id, "local-lvm:vm-100-disk-0");
    assert_eq!(disk.capacity, Some(21474836480));
    assert_eq!(disk.users, [GuestRef { vmid: Some(100), ..Default::default() }]);
    // `ctime` arrives as a string for some storages.
    assert!(disk.created_at.is_some());
    let tmpl = &resources::parse_content(&list("content_local.json"))[0];
    assert_eq!(tmpl.name, "alpine-3.24-default_20260714_amd64.tar.xz");
    assert_eq!(tmpl.content.as_deref(), Some("vztmpl"));
    assert!(tmpl.users.is_empty());
    // An import image's size is its file's: unknown until asked.
    let import = resources::parse_content(&[json!({"volid": "local:import/x.qcow2", "content": "import", "format": "qcow2", "size": 5})]);
    assert_eq!((import[0].capacity, import[0].allocation), (None, Some(5)));
}

#[test]
fn network_bridges_first_ports_and_the_guests_on_each() {
    let mut raw = list("network.json");
    raw.extend([
        json!({"iface": "bond0", "type": "bond", "slaves": "nic1 nic2", "bond_mode": "802.3ad", "active": 1}),
        json!({"iface": "vmbr1", "type": "bridge", "bridge_ports": "bond0", "bridge_vlan_aware": 1, "comments": "lab\n"}),
        json!({"iface": "vmbr1.10", "type": "vlan", "vlan-id": "10", "vlan-raw-device": "vmbr1", "cidr": "10.10.0.2/24"}),
    ]);
    let users = BTreeMap::from([(
        "vmbr0".to_owned(),
        vec![GuestRef { guest_id: Some("qemu/100".into()), vmid: Some(100), ..Default::default() }],
    )]);
    let nets = resources::parse_networks("pve", &raw, &users, &BTreeSet::from(["vmbr0".to_owned()]));
    assert_eq!(
        nets.iter().map(|n| n.name.as_str()).collect::<Vec<_>>(),
        ["vmbr0", "vmbr1", "bond0", "vmbr1.10", "nic0", "nic1", "wlp4s0"]
    );
    let vmbr0 = &nets[0];
    assert_eq!(vmbr0.id, "pve/vmbr0");
    assert_eq!(vmbr0.cidrs, ["192.168.31.20/24"]);
    assert_eq!(vmbr0.gateway.as_deref(), Some("192.168.31.1"));
    assert_eq!(vmbr0.ports, ["nic0"]);
    assert!(vmbr0.active);
    assert_eq!(vmbr0.autostart, Some(true));
    assert_eq!(vmbr0.vlan_aware, None);
    assert_eq!(vmbr0.users[0].vmid, Some(100));
    // The management bridge is not editable; another bridge is; a port never.
    assert!(!vmbr0.management_editable);
    assert!(nets[1].management_editable);
    assert!(!nets[2].management_editable);
    assert_eq!(nets[1].vlan_aware, Some(true));
    assert_eq!(nets[1].comment.as_deref(), Some("lab"));
    assert!(!nets[1].active);
    assert_eq!(nets[2].ports, ["nic1", "nic2"]);
    assert_eq!(nets[2].bond_mode.as_deref(), Some("802.3ad"));
    assert_eq!(nets[3].vlan_id, Some(10));
    assert_eq!(nets[3].vlan_device.as_deref(), Some("vmbr1"));
}

#[test]
fn bridge_users_from_a_guest_configuration() {
    let guest = Guest {
        id: "lxc/200".into(),
        name: "ct".into(),
        kind: GuestKind::Lxc,
        state: GuestState::Running,
        state_reason: None,
        vmid: Some(200),
        node: Some("pve".into()),
        vcpu: None,
        mem_bytes: None,
        uptime: None,
        tags: vec![],
        template: false,
        autostart: None,
        actions: Default::default(),
    };
    let config = json!({
        "net0": "name=eth0,bridge=vmbr0,hwaddr=BC:24:11:30:5B:A7,ip=dhcp,type=veth",
        "net1": "name=eth1,bridge=vmbr1,hwaddr=BC:24:11:30:5B:A8",
        "rootfs": "local-lvm:vm-200-disk-0,size=4G",
    });
    let users = resources::bridge_users(&guest, config.as_object().unwrap());
    assert_eq!(users.keys().collect::<Vec<_>>(), ["vmbr0", "vmbr1"]);
    assert_eq!(
        users["vmbr0"],
        [GuestRef {
            guest_id: Some("lxc/200".into()),
            vmid: Some(200),
            device: Some("net0".into()),
            mac: Some("bc:24:11:30:5b:a7".into()),
            ip: None
        }]
    );
}

#[tokio::test]
async fn a_volume_whose_guest_is_gone_is_used_by_nothing() {
    let fake = Fake::new();
    storages(&fake);
    fake.route("GET /cluster/resources", |_| ok(resources_fixture()));
    fake.route("GET /nodes/pve/storage/local/content", |_| {
        ok(json!([
            {"volid": "local:101/vm-101-disk-0.qcow2", "content": "images", "format": "qcow2", "size": 1, "vmid": 101},
            {"volid": "local:9999/vm-9999-disk-0.qcow2", "content": "images", "format": "qcow2", "size": 1, "vmid": 9999},
        ]))
    });
    fake.route("DELETE /nodes/pve/storage/local/content/local%3A9999%2Fvm-9999-disk-0.qcow2", |_| ok(json!(UPID)));
    let pve = fake.client();
    let pool = pve.storage_pools().await.unwrap().into_iter().find(|p| p.name == "local").unwrap();
    let vols = pve.volumes(&pool).await.unwrap();
    assert_eq!(vols[0].users[0].guest_id.as_deref(), Some("qemu/101"));
    assert!(vols[1].users.is_empty());
    let delete = |v: &str| Change::VolumeDelete { pool: "pve/local".into(), volume: v.into() };
    assert_eq!(refused(&err(pve.manage(&delete("local:101/vm-101-disk-0.qcow2"), None)).await), Some(Issue::InUse));
    pve.manage(&delete("local:9999/vm-9999-disk-0.qcow2"), None).await.unwrap();
}

#[tokio::test]
async fn storage_without_storage_access_still_lists_without_paths() {
    let fake = Fake::new();
    fake.route("GET /cluster/resources", |_| ok(resources_fixture()));
    fake.route("GET /storage", |_| status(403, "Permission check failed (/storage, Datastore.Audit)"));
    fake.route("GET /nodes/pve/storage", |_| ok(fixture("node_storage.json")));
    fake.route("GET /nodes/pve/storage/local-lvm/content", |_| ok(fixture("content_local_lvm.json")));
    let pve = fake.client();
    let pools = pve.storage_pools().await.unwrap();
    assert_eq!(pools.iter().map(|p| p.name.as_str()).collect::<Vec<_>>(), ["local", "local-lvm"]);
    assert_eq!(pools[0].path, None);
    assert_eq!(pve.volumes(&pools[1]).await.unwrap().len(), 6);
}

#[tokio::test]
async fn import_images_are_sized_by_asking() {
    let fake = Fake::new();
    let pool = sbm_virt::resource::Pool {
        id: "pve/local".into(),
        name: "local".into(),
        node: Some("pve".into()),
        pool_type: "dir".into(),
        active: true,
        ..Default::default()
    };
    fake.route("GET /nodes/pve/storage/local/content", |_| {
        ok(json!([
            {"volid": "local:import/a.qcow2", "content": "import", "format": "qcow2", "size": 5},
            {"volid": "local:import/b.vmdk", "content": "import", "format": "vmdk", "size": 6},
        ]))
    });
    fake.route("GET /nodes/pve/storage/local/content/local%3Aimport%2Fa.qcow2", |_| ok(json!({"size": 2147483648u64})));
    let vols = fake.client().volumes(&pool).await.unwrap();
    assert_eq!(vols[0].capacity, Some(2147483648));
    // One PVE will not size stays unknown.
    assert_eq!(vols[1].capacity, None);
}

fn resources_fixture() -> Value {
    json!([
        {"type": "lxc", "node": "pve", "vmid": 100, "id": "lxc/100", "name": "a", "status": "running"},
        {"type": "qemu", "node": "pve", "vmid": 101, "id": "qemu/101", "name": "b", "status": "stopped"},
        {"type": "qemu", "node": "pve", "vmid": 104, "id": "qemu/104", "name": "c", "status": "stopped"},
        {"type": "qemu", "node": "other", "vmid": 300, "id": "qemu/300", "name": "d", "status": "stopped"},
    ])
}

#[tokio::test]
async fn networks_each_guests_configuration_says_which_bridge() {
    let fake = Fake::new();
    fake.route("GET /cluster/resources", |_| ok(resources_fixture()));
    fake.route("GET /nodes/pve/network", |_| ok(fixture("network.json")));
    fake.route("GET /nodes/pve/lxc/100/config", |_| ok(json!({"net0": "name=eth0,bridge=vmbr0,hwaddr=BC:24:11:00:00:01,type=veth"})));
    fake.route("GET /nodes/pve/qemu/101/config", |_| ok(json!({"net0": "virtio=BC:24:11:00:00:02,bridge=vmbr0"})));
    // One guest this account may not read: left out, not a failure.
    fake.route("GET /nodes/pve/qemu/104/config", |_| status(403, "Permission check failed (/vms/104, VM.Audit)"));
    let nets = fake.client().networks(None).await.unwrap();
    let vmbr0 = nets.iter().find(|n| n.name == "vmbr0").unwrap();
    assert_eq!(vmbr0.users.iter().map(|u| u.vmid).collect::<Vec<_>>(), [Some(100), Some(101)]);
    assert!(nets.iter().find(|n| n.name == "nic0").unwrap().users.is_empty());
    // Only that node's guests are read.
    assert!(!fake.paths().iter().any(|p| p.contains("/300/")));
    // Without the node's word, every interface with an address is kept.
    assert!(!vmbr0.management_editable);
}

#[tokio::test]
async fn a_bridge_is_not_deleted_while_a_guest_on_its_node_cannot_be_read() {
    let fake = Fake::new();
    fake.route("GET /cluster/resources", |_| ok(resources_fixture()));
    fake.route("GET /nodes/pve/network", |_| {
        let mut list = fixture("network.json");
        list.as_array_mut().unwrap().push(json!({"iface": "vmbr7", "type": "bridge", "active": 1}));
        ok(list)
    });
    fake.route("GET /nodes/pve/lxc/100/config", |_| ok(json!({})));
    fake.route("GET /nodes/pve/qemu/101/config", |_| ok(json!({})));
    // Whether 104 has a NIC on vmbr7 is what this account may not read.
    fake.route("GET /nodes/pve/qemu/104/config", |_| status(403, "Permission check failed (/vms/104, VM.Audit)"));
    fake.route("DELETE /nodes/pve/network/vmbr7", |_| ok(Value::Null));
    let e = fake.client().manage(&Change::NetworkDelete { network: "pve/vmbr7".into() }, None).await.unwrap_err();
    assert_eq!(e.kind, ErrorKind::PermissionDenied, "{e:?}");
    assert!(!fake.paths().iter().any(|p| p.starts_with("DELETE ")));
}

// ---------------------------------------------------------------------------
// Changes
// ---------------------------------------------------------------------------

fn create_pool(name: &str, ty: &str, source: &str) -> Change {
    Change::PoolCreate {
        name: name.into(),
        pool_type: ty.into(),
        source: source.into(),
        target: None,
        node: Some("pve".into()),
        content: vec![],
        autostart: true,
    }
}

fn storages(fake: &Fake) {
    fake.route("GET /storage", |_| ok(fixture("storage_config.json")));
    fake.route("GET /nodes/pve/storage", |_| ok(fixture("node_storage.json")));
}

#[tokio::test]
async fn a_storage_its_types_fields_its_node_the_designs_content() {
    let fake = Fake::new();
    storages(&fake);
    fake.route("POST /storage", |_| ok(json!({"storage": "x"})));
    let pve = fake.client();
    pve.manage(&create_pool("data", "dir", "/srv/data"), None).await.unwrap();
    pve.manage(&create_pool("nas", "nfs", "10.0.0.5:/export/pve"), None).await.unwrap();
    pve.manage(&create_pool("thin", "lvmthin", "pve/data"), None).await.unwrap();
    let sent = fake.forms("POST /storage");
    let f = |pairs: &[(&str, &str)]| pairs.iter().map(|(k, v)| ((*k).to_owned(), (*v).to_owned())).collect::<BTreeMap<_, _>>();
    assert_eq!(sent[0], f(&[("storage", "data"), ("type", "dir"), ("path", "/srv/data"), ("content", "images,rootdir"), ("nodes", "pve")]));
    assert_eq!(sent[1]["server"], "10.0.0.5");
    assert_eq!(sent[1]["export"], "/export/pve");
    assert_eq!(sent[1]["content"], "backup,iso");
    assert_eq!(sent[2]["vgname"], "pve");
    assert_eq!(sent[2]["thinpool"], "data");
    // A name the cluster has is refused before anything is sent.
    let e = err(pve.manage(&create_pool("local", "dir", "/d"), None)).await;
    assert_eq!(e.kind, ErrorKind::Exists);
    assert_eq!(refused(&e), Some(Issue::NameTaken));
    assert_eq!(fake.forms("POST /storage").len(), 3);
}

#[tokio::test]
async fn disabled_and_enabled_removed() {
    let fake = Fake::new();
    storages(&fake);
    fake.route("GET /nodes/pve/storage/local/content", |_| ok(json!([])));
    fake.route("PUT /storage/local", |_| ok(Value::Null));
    fake.route("DELETE /storage/local", |_| ok(Value::Null));
    let pve = fake.client();
    pve.manage(&Change::PoolSetActive { pool: "pve/local".into(), active: false }, None).await.unwrap();
    pve.manage(&Change::PoolSetActive { pool: "pve/local".into(), active: true }, None).await.unwrap();
    pve.manage(&Change::PoolDelete { pool: "pve/local".into(), delete_storage: false }, None).await.unwrap();
    let puts: Vec<String> = fake.forms("PUT /storage/local").into_iter().map(|f| f["disable"].clone()).collect();
    assert_eq!(puts, ["1", "0"]);
    assert!(fake.paths().contains(&"DELETE /storage/local".to_owned()));
    // What PVE has no call for is refused before anything is sent.
    let e = err(pve.manage(&Change::PoolSetAutostart { pool: "pve/local".into(), on: true }, None)).await;
    assert_eq!(e.kind, ErrorKind::Unsupported);
    // A pool whose volumes a guest uses is not disabled.
    fake.route("GET /cluster/resources", |_| ok(resources_fixture()));
    fake.route("GET /nodes/pve/storage/local-lvm/content", |_| ok(fixture("content_local_lvm.json")));
    let e = err(pve.manage(&Change::PoolSetActive { pool: "pve/local-lvm".into(), active: false }, None)).await;
    assert_eq!(refused(&e), Some(Issue::InUse));
    // Nor is one that is not there.
    let e = err(pve.manage(&Change::PoolDelete { pool: "pve/gone".into(), delete_storage: false }, None)).await;
    assert_eq!(refused(&e), Some(Issue::NotFound));
}

#[tokio::test]
async fn a_volume_for_its_vmid_with_the_extension_a_directory_wants_deleted_with_its_task() {
    let fake = Fake::new();
    storages(&fake);
    fake.route("GET /nodes/pve/storage/local/content", |_| {
        ok(json!([{"volid": "local:105/vm-105-disk-0.qcow2", "content": "images", "format": "qcow2", "size": 1}]))
    });
    fake.route("GET /nodes/pve/storage/local-lvm/content", |_| ok(json!([])));
    fake.route("POST /nodes/pve/storage/local/content", |_| ok(json!("local:105/vm-105-disk-1.qcow2")));
    fake.route("POST /nodes/pve/storage/local-lvm/content", |_| ok(json!("local-lvm:vm-105-disk-1")));
    fake.route("DELETE /nodes/pve/storage/local/content/local%3A105%2Fvm-105-disk-0.qcow2", |_| ok(json!(UPID)));
    let pve = fake.client();
    let vol = |pool: &str, name: &str, gib, format: &str| Change::VolumeCreate {
        pool: pool.into(),
        name: name.into(),
        gib,
        format: format.into(),
    };
    pve.manage(&vol("pve/local", "vm-105-disk-1", 4, "qcow2"), None).await.unwrap();
    pve.manage(&vol("pve/local-lvm", "vm-105-disk-1", 8, "raw"), None).await.unwrap();
    let f = fake.form("POST /nodes/pve/storage/local/content");
    assert_eq!(
        f,
        [("vmid", "105"), ("filename", "vm-105-disk-1.qcow2"), ("size", "4G"), ("format", "qcow2")]
            .iter()
            .map(|(k, v)| ((*k).to_owned(), (*v).to_owned()))
            .collect()
    );
    assert_eq!(fake.form("POST /nodes/pve/storage/local-lvm/content")["filename"], "vm-105-disk-1");
    // The name with its extension is taken already.
    let e = err(pve.manage(&vol("pve/local", "vm-105-disk-0", 4, "qcow2"), None)).await;
    assert_eq!(refused(&e), Some(Issue::NameTaken));
    pve.manage(&Change::VolumeDelete { pool: "pve/local".into(), volume: "local:105/vm-105-disk-0.qcow2".into() }, None)
        .await
        .unwrap();
    assert!(fake.paths().last().unwrap().starts_with("GET /nodes/pve/tasks/"));
}

#[tokio::test]
async fn a_privilege_missing_which_where_and_the_command_that_grants_it() {
    let fake = Fake::new();
    storages(&fake);
    fake.route("POST /storage", |_| status(403, "Permission check failed (/storage, Datastore.Allocate)\n"));
    fake.route("GET /cluster/resources", |_| ok(json!([])));
    fake.route("GET /nodes/pve/network", |_| ok(json!([])));
    fake.route("POST /nodes/pve/network", |_| status(403, "Permission check failed (/nodes/pve, Sys.Modify)\n"));
    let pve = fake.client();
    let e = err(pve.manage(&create_pool("data2", "dir", "/d"), None)).await;
    assert_eq!(e.kind, ErrorKind::PermissionDenied);
    let Some(Detail::NeedsPrivilege { account, privilege, path, command }) = e.detail.as_deref() else { panic!("{e:?}") };
    assert_eq!((account.as_str(), privilege.as_str(), path.as_str()), ("root@pam!sb", "Datastore.Allocate", "/storage"));
    assert_eq!(command, "pveum acl modify /storage --tokens 'root@pam!sb' --roles PVEDatastoreAdmin");
    assert!(!format!("{e:?}").contains("s3cret"));
    let create = Change::NetworkCreate {
        name: "vmbr9".into(),
        mode: "bridge".into(),
        node: Some("pve".into()),
        bridge: None,
        cidr: None,
        dhcp_start: None,
        dhcp_end: None,
        vlan_aware: false,
        autostart: true,
    };
    let n = err(pve.manage(&create, None)).await;
    let Some(Detail::NeedsPrivilege { command, .. }) = n.detail.as_deref() else { panic!("{n:?}") };
    // Only Administrator holds Sys.Modify among the built-in roles: a role
    // of its own.
    assert!(command.starts_with("pveum role add ServerBox-SysModify --privs Sys.Modify\n"));
    assert!(command.contains("/nodes/pve"));
    // A path is the host's answer: one word to the shell it is pasted in.
    let odd = pve.refusal("Permission check failed (/storage/x'; touch y; echo ', Datastore.Allocate)", Some(403));
    let Some(Detail::NeedsPrivilege { command, .. }) = odd.detail.as_deref() else { panic!("{odd:?}") };
    assert_eq!(command, r#"pveum acl modify '/storage/x'\''; touch y; echo '\''' --tokens 'root@pam!sb' --roles PVEDatastoreAdmin"#);
}

#[tokio::test]
async fn a_name_taken_on_the_host_is_exists() {
    let fake = Fake::new();
    fake.route("GET /storage", |_| ok(json!([])));
    fake.route("GET /nodes/pve/storage", |_| ok(json!([])));
    fake.route("POST /storage", |_| status(500, "create storage failed: storage ID 'local' already defined\n"));
    let e = err(fake.client().manage(&create_pool("local", "dir", "/d"), None)).await;
    assert_eq!(e.kind, ErrorKind::Exists);
}

#[tokio::test]
async fn a_bridge_pending_its_changes_read_applied_with_a_task_reverted() {
    let fake = Fake::new();
    fake.route("GET /cluster/resources", |_| ok(json!([])));
    fake.route("POST /nodes/pve/network", |_| ok(Value::Null));
    fake.route("PUT /nodes/pve/network", |_| ok(json!(UPID)));
    fake.route("DELETE /nodes/pve/network", |_| ok(Value::Null));
    fake.route("DELETE /nodes/pve/network/vmbr9", |_| ok(Value::Null));
    fake.route("GET /nodes/pve/network", |_| {
        whole(json!({
            "data": [{"iface": "vmbr9", "type": "bridge", "autostart": 1}],
            "changes": "--- a\n+++ b\n+auto vmbr9\n+iface vmbr9 inet manual\n",
        }))
    });
    let pve = fake.client();
    let create = Change::NetworkCreate {
        name: "vmbr8".into(),
        mode: "bridge".into(),
        node: Some("pve".into()),
        bridge: None,
        cidr: Some("10.20.0.1/24".into()),
        dhcp_start: None,
        dhcp_end: None,
        vlan_aware: true,
        autostart: true,
    };
    pve.manage(&create, None).await.unwrap();
    let f = fake.form("POST /nodes/pve/network");
    assert_eq!(
        f,
        [("iface", "vmbr8"), ("type", "bridge"), ("autostart", "1"), ("cidr", "10.20.0.1/24"), ("bridge_vlan_aware", "1")]
            .iter()
            .map(|(k, v)| ((*k).to_owned(), (*v).to_owned()))
            .collect()
    );
    let changes = pve.network_changes().await.unwrap();
    assert_eq!(changes[0].node, "pve");
    assert!(changes[0].diff.contains("+iface vmbr9"));
    pve.manage(&Change::NetworkApply { node: "pve".into() }, None).await.unwrap();
    assert!(fake.paths().last().unwrap().starts_with("GET /nodes/pve/tasks/"));
    pve.manage(&Change::NetworkRevert { node: "pve".into() }, None).await.unwrap();
    pve.manage(&Change::NetworkDelete { network: "pve/vmbr9".into() }, None).await.unwrap();
    let paths = fake.paths();
    assert!(paths.contains(&"DELETE /nodes/pve/network".to_owned()));
    assert!(paths.contains(&"DELETE /nodes/pve/network/vmbr9".to_owned()));
}

#[tokio::test]
async fn an_apply_touching_the_management_interface_is_refused() {
    let fake = Fake::new();
    let changes = Arc::new(Mutex::new(String::new()));
    let c = changes.clone();
    fake.route("PUT /nodes/pve/network", |_| ok(json!(UPID)));
    fake.route("GET /nodes/pve/network", move |_| {
        whole(json!({
            "data": [
                {"iface": "vmbr0", "type": "bridge", "cidr": "192.168.31.20/24", "gateway": "192.168.31.1", "bridge_ports": "nic0"},
                {"iface": "vmbr9", "type": "bridge"},
            ],
            "changes": *c.lock().unwrap(),
        }))
    });
    let pve = fake.client();
    let apply = Change::NetworkApply { node: "pve".into() };
    let set = |s: &str| *changes.lock().unwrap() = s.to_owned();
    let touched = |e: &Error| match e.detail.as_deref() {
        Some(Detail::ApplyTouchesManagement { ifaces }) => ifaces.clone(),
        other => panic!("{other:?}"),
    };
    set("--- a\n+++ b\n@@ -1,3 +1,4 @@\n iface vmbr0 inet static\n+\tbridge-vlan-aware yes\n");
    let e = err(pve.manage(&apply, None)).await;
    assert_eq!(e.kind, ErrorKind::Unsupported);
    assert_eq!(touched(&e), ["vmbr0"]);
    assert!(!fake.paths().contains(&"PUT /nodes/pve/network".to_owned()));
    // A change to its port is one to it too.
    set("--- a\n+++ b\n@@ -1,3 +1,3 @@\n iface nic0 inet manual\n-\tmtu 1500\n+\tmtu 9000\n");
    assert_eq!(touched(&err(pve.manage(&apply, None)).await), ["nic0"]);
    // A hunk that does not say whose lines it changes.
    set("--- a\n+++ b\n@@ -3,2 +3,2 @@\n-\tmtu 1500\n+\tmtu 9000\n");
    assert_eq!(err(pve.manage(&apply, None)).await.detail.as_deref(), Some(&Detail::ApplyUnreadable));
    // A comment on it is a change to it too.
    set("--- a\n+++ b\n@@ -1,3 +1,4 @@\n iface vmbr0 inet static\n \tbridge-fd 0\n+#note\n");
    assert_eq!(touched(&err(pve.manage(&apply, None)).await), ["vmbr0"]);
    // Another bridge's change goes through.
    set("--- a\n+++ b\n+auto vmbr9\n+iface vmbr9 inet manual\n");
    pve.manage(&apply, None).await.unwrap();
    assert!(fake.paths().contains(&"PUT /nodes/pve/network".to_owned()));
}

#[tokio::test]
async fn a_pending_change_stripping_the_management_address_is_refused_without_the_nodes_word() {
    // The listing is the pending configuration: vmbr0 has neither its
    // address nor its gateway there any more.
    let fake = Fake::new();
    fake.route("PUT /nodes/pve/network", |_| ok(json!(UPID)));
    fake.route("GET /nodes/pve/network", |_| {
        whole(json!({
            "data": [{"iface": "vmbr0", "type": "bridge", "bridge_ports": "nic0"}, {"iface": "vmbr9", "type": "bridge"}],
            "changes": "--- a\n+++ b\n@@ -1,5 +1,3 @@\n-iface vmbr0 inet static\n-\taddress 192.168.31.20/24\n-\tgateway 192.168.31.1\n+iface vmbr0 inet manual\n \tbridge-ports nic0\n",
        }))
    });
    let e = err(fake.client().manage(&Change::NetworkApply { node: "pve".into() }, None)).await;
    assert_eq!(e.detail.as_deref(), Some(&Detail::ApplyTouchesManagement { ifaces: vec!["vmbr0".into()] }));
    assert!(!fake.paths().contains(&"PUT /nodes/pve/network".to_owned()));
}

fn edit_bridge(network: &str, ports: Option<&str>, cidr: Option<&str>) -> Change {
    Change::NetworkEditBridge {
        network: network.into(),
        ports: ports.map(str::to_owned),
        cidr: cidr.map(str::to_owned),
        gateway: None,
        vlan_aware: None,
        autostart: None,
    }
}

#[tokio::test]
async fn a_nodes_network_changes_run_one_at_a_time() {
    let fake = Fake::new();
    fake.route("GET /cluster/resources", |_| ok(json!([])));
    fake.route("GET /nodes/pve/network", |_| ok(json!([{"iface": "vmbr7", "type": "bridge"}])));
    fake.route("GET /nodes/pve/network/vmbr7", |_| ok(json!({"iface": "vmbr7", "type": "bridge"})));
    fake.route("PUT /nodes/pve/network/vmbr7", |_| ok(Value::Null));
    fake.route("DELETE /nodes/pve/network", |_| ok(Value::Null));
    let saved = Arc::new(Notify::new());
    fake.0.lock().unwrap().gates.insert("PUT /nodes/pve/network/vmbr7".into(), saved.clone());
    let pve = Arc::new(fake.client());
    let edit = tokio::spawn({
        let pve = pve.clone();
        async move { pve.manage(&edit_bridge("pve/vmbr7", Some("nic1"), None), None).await }
    });
    while !fake.paths().contains(&"PUT /nodes/pve/network/vmbr7".to_owned()) {
        tokio::time::sleep(Duration::from_millis(1)).await;
    }
    let revert = tokio::spawn({
        let pve = pve.clone();
        async move { pve.manage(&Change::NetworkRevert { node: "pve".into() }, None).await }
    });
    tokio::time::sleep(Duration::from_millis(30)).await;
    assert!(!fake.paths().contains(&"DELETE /nodes/pve/network".to_owned()), "the revert would drop the edit being saved");
    saved.notify_one();
    edit.await.unwrap().unwrap();
    revert.await.unwrap().unwrap();
    assert_eq!(fake.paths().last().unwrap(), "DELETE /nodes/pve/network");
    // A failed change does not hold the next one up.
    fake.0.lock().unwrap().gates.clear();
    fake.route("PUT /nodes/pve/network/vmbr7", |_| status(500, "boom"));
    err(pve.manage(&edit_bridge("pve/vmbr7", Some("nic1"), None), None)).await;
    pve.manage(&Change::NetworkRevert { node: "pve".into() }, None).await.unwrap();
}

#[tokio::test]
async fn a_bridge_edit_sends_the_addresses_it_has_back() {
    let fake = Fake::new();
    fake.route("GET /cluster/resources", |_| ok(json!([])));
    fake.route("GET /nodes/pve/network", |_| {
        ok(json!([
            {"iface": "vmbr0", "type": "bridge", "cidr": "192.168.31.20/24", "gateway": "192.168.31.1"},
            {"iface": "vmbr7", "type": "bridge", "cidr": "10.7.0.1/24", "cidr6": "fd07::1/64"},
        ]))
    });
    fake.route("GET /nodes/pve/network/vmbr7", |_| {
        ok(json!({"iface": "vmbr7", "type": "bridge", "cidr": "10.7.0.1/24", "cidr6": "fd07::1/64"}))
    });
    fake.route("PUT /nodes/pve/network/vmbr7", |_| ok(Value::Null));
    // The node says it is reached through vmbr0; vmbr7 carries nothing of
    // its own traffic.
    let live = parse_live_net(
        "@host pve\n@addr\n4: vmbr0    inet 192.168.31.20/24 scope global vmbr0\n5: vmbr7    inet 10.7.0.1/24 scope global vmbr7\n@route\ndefault via 192.168.31.1 dev vmbr0\n@conn\n0 0 192.168.31.20:22 192.168.31.183:62036\n@lower\n@end\n",
    )
    .unwrap();
    let pve = fake.client();
    // Only the ports: PVE would drop both addresses from a request without
    // them (`update_network` sets `method` from the request).
    pve.manage(&edit_bridge("pve/vmbr7", Some("nic1"), None), Some(&live)).await.unwrap();
    let f = fake.form("PUT /nodes/pve/network/vmbr7");
    assert_eq!(
        f,
        [("type", "bridge"), ("bridge_ports", "nic1"), ("cidr", "10.7.0.1/24"), ("cidr6", "fd07::1/64")]
            .iter()
            .map(|(k, v)| ((*k).to_owned(), (*v).to_owned()))
            .collect()
    );
    // A new IPv4 address: that one, and the IPv6 one still.
    pve.manage(&edit_bridge("pve/vmbr7", None, Some("10.7.1.1/24")), Some(&live)).await.unwrap();
    let f = fake.form("PUT /nodes/pve/network/vmbr7");
    assert_eq!((f["cidr"].as_str(), f["cidr6"].as_str()), ("10.7.1.1/24", "fd07::1/64"));
    // Cleared: deleted, not sent.
    pve.manage(&edit_bridge("pve/vmbr7", None, Some("")), Some(&live)).await.unwrap();
    let f = fake.form("PUT /nodes/pve/network/vmbr7");
    assert!(!f.contains_key("cidr"));
    assert!(f["delete"].contains("cidr"));
    // The management bridge is refused before anything is sent.
    let e = err(pve.manage(&edit_bridge("pve/vmbr0", Some("nic1"), None), Some(&live))).await;
    assert_eq!(refused(&e), Some(Issue::ManagementIface));
    assert!(!fake.paths().contains(&"PUT /nodes/pve/network/vmbr0".to_owned()));
    // Without the node's word vmbr7 has an address, so it is kept too.
    let e = err(pve.manage(&edit_bridge("pve/vmbr7", Some("nic1"), None), None)).await;
    assert_eq!(refused(&e), Some(Issue::ManagementIface));
}
