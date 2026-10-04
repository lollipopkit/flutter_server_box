//! Making and copying guests: the rules a new guest and a clone are checked
//! by, on either backend, and what a form offers. Ported from the app's
//! `test/unit/virt/virt_create_test.dart` and the clone target tests of
//! `virt_backup_job_test.dart`.

use sbm_virt::create::{
    CloneListing, CloneRequest, CloudInit, CreateListing, CreateOptions, CreateSpec, Issue, VolumeRef, clone_issue,
    clone_node_issue, clone_storage_issue, cloud_init_issue, create_form, create_issue, create_networks,
    delete_issue, disk_storages, form_pools, image_storages, is_cloud_image, is_media, libvirt_disk_format,
    media_storages, template_issue,
};
use sbm_virt::model::{Guest, GuestKind, GuestState, HostKind, Node};
use sbm_virt::resource::{GuestRef, Network, Pool, Volume};

fn pool(id: &str, ty: &str) -> Pool {
    Pool { id: id.into(), name: id.rsplit('/').next().unwrap().into(), pool_type: ty.into(), active: true, ..Default::default() }
}

fn pve_pool(id: &str, ty: &str, content: &[&str]) -> Pool {
    Pool {
        node: Some(id.split('/').next().unwrap().into()),
        content: content.iter().map(|c| (*c).to_owned()).collect(),
        ..pool(id, ty)
    }
}

fn vol(id: &str, name: &str) -> Volume {
    Volume { id: id.into(), name: name.into(), ..Default::default() }
}

fn guest(id: &str, name: &str, vmid: Option<u32>) -> Guest {
    Guest {
        id: id.into(),
        name: name.into(),
        kind: GuestKind::Qemu,
        state: GuestState::Running,
        state_reason: None,
        vmid,
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

fn node(name: &str, max_cpu: Option<u32>) -> Node {
    Node { name: name.into(), online: true, cpu: None, max_cpu, mem_used: None, mem_total: None, uptime: None }
}

fn net(id: &str, mode: &str) -> Network {
    Network {
        id: id.into(),
        name: id.rsplit('/').next().unwrap().into(),
        node: id.contains('/').then(|| id.split('/').next().unwrap().into()),
        mode: mode.into(),
        active: true,
        ..Default::default()
    }
}

fn options() -> CreateOptions {
    let owned = |l: &[&str]| l.iter().map(|s| (*s).to_owned()).collect();
    CreateOptions {
        buses: owned(&["virtio", "scsi", "sata"]),
        nic_models: owned(&["virtio", "e1000e"]),
        uefi: true,
        secure_boot: true,
        tpm: true,
        cloud_images: true,
        cloud_init: true,
        cloud_init_missing: None,
    }
}

fn spec() -> CreateSpec {
    CreateSpec {
        kind: GuestKind::Qemu,
        name: "web-02".into(),
        node: Some("pve".into()),
        vmid: Some(105),
        cores: 2,
        memory_mib: 2048,
        storage: "images".into(),
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

struct Host {
    guests: Vec<Guest>,
    nodes: Vec<Node>,
    pools: Vec<Pool>,
    networks: Vec<Network>,
    media: Option<Volume>,
    image: Option<Volume>,
    options: CreateOptions,
}

impl Host {
    fn libvirt() -> Self {
        Host {
            guests: vec![guest("qemu/100", "debian-libvirt", Some(100))],
            nodes: Vec::new(),
            pools: vec![pool("images", "dir")],
            networks: vec![net("default", "nat")],
            media: None,
            image: None,
            options: options(),
        }
    }

    fn pve() -> Self {
        Host {
            nodes: vec![node("pve", None)],
            pools: vec![
                pve_pool("pve/images", "lvmthin", &["images", "rootdir"]),
                pve_pool("pve/local", "dir", &["iso", "vztmpl", "import"]),
            ],
            networks: vec![net("pve/vmbr0", "bridge")],
            ..Host::libvirt()
        }
    }

    fn issue(&self, s: &CreateSpec, host: HostKind) -> Option<Issue> {
        let list = CreateListing {
            guests: &self.guests,
            nodes: &self.nodes,
            pools: &self.pools,
            networks: &self.networks,
            media: self.media.as_ref(),
            image: self.image.as_ref(),
            options: &self.options,
        };
        create_issue(s, host, list)
    }
}

fn libvirt(s: CreateSpec) -> Option<Issue> {
    Host::libvirt().issue(&s, HostKind::Libvirt)
}

fn pve(s: CreateSpec) -> Option<Issue> {
    Host::pve().issue(&CreateSpec { storage: "pve/images".into(), ..s }, HostKind::Pve)
}

fn named(name: &str) -> CreateSpec {
    CreateSpec { name: name.into(), ..spec() }
}

#[test]
fn names_what_each_host_takes() {
    assert_eq!(libvirt(spec()), None);
    assert_eq!(libvirt(named("")), Some(Issue::NameEmpty));
    assert_eq!(libvirt(named("debian-libvirt")), Some(Issue::NameTaken));
    assert_eq!(libvirt(named("win_11.test")), None);
    // What AppArmor, vol-create-as's XML or a file name would refuse.
    for bad in ["it's", "a\"b", "a&b", "a<b", "a b", "-rf", ".hidden", "a/b", &"x".repeat(64)] {
        assert_eq!(libvirt(named(bad)), Some(Issue::NameInvalid), "{bad}");
    }
    // PVE: a DNS name.
    assert_eq!(pve(named("web.lan")), None);
    for bad in ["win_11", "a..b", "-a", "a-", &"x".repeat(64)] {
        assert_eq!(pve(named(bad)), Some(Issue::NameInvalid), "{bad}");
    }
}

#[test]
fn vmids_nodes_cores_memory_disk() {
    // None takes the next free one.
    assert_eq!(pve(CreateSpec { vmid: None, ..spec() }), None);
    assert_eq!(pve(CreateSpec { vmid: Some(99), ..spec() }), Some(Issue::VmidInvalid));
    assert_eq!(pve(CreateSpec { vmid: Some(100), ..spec() }), Some(Issue::VmidTaken));
    // libvirt has none to check.
    assert_eq!(libvirt(CreateSpec { vmid: None, ..spec() }), None);
    assert_eq!(pve(CreateSpec { node: Some("gone".into()), ..spec() }), Some(Issue::Node));
    assert_eq!(pve(CreateSpec { node: None, ..spec() }), Some(Issue::Node));
    assert_eq!(pve(CreateSpec { cores: 0, ..spec() }), Some(Issue::Cores));
    let small = Host { nodes: vec![node("pve", Some(12))], ..Host::pve() };
    let on = |cores| small.issue(&CreateSpec { cores, storage: "pve/images".into(), ..spec() }, HostKind::Pve);
    assert_eq!(on(13), Some(Issue::Cores));
    assert_eq!(on(12), None);
    assert_eq!(pve(CreateSpec { memory_mib: 64, ..spec() }), Some(Issue::Memory));
    assert_eq!(pve(CreateSpec { disk_gib: 0, ..spec() }), Some(Issue::DiskSize));
    let off = Host { pools: vec![Pool { active: false, ..pool("images", "dir") }], ..Host::libvirt() };
    assert_eq!(off.issue(&spec(), HostKind::Libvirt), Some(Issue::Storage));
    assert_eq!(libvirt(CreateSpec { storage: "gone".into(), ..spec() }), Some(Issue::Storage));
    // A container is PVE's.
    assert_eq!(libvirt(CreateSpec { kind: GuestKind::Lxc, ..spec() }), Some(Issue::Unsupported));
}

#[test]
fn a_container_a_template_and_a_root_login() {
    let host = Host { media: Some(Volume { content: Some("vztmpl".into()), ..vol("local:vztmpl/a.tar.xz", "a.tar.xz") }), ..Host::pve() };
    let lxc = |media: bool, pw: Option<&str>, keys: &[&str]| {
        host.issue(
            &CreateSpec {
                kind: GuestKind::Lxc,
                storage: "pve/images".into(),
                media: media.then(|| VolumeRef { pool: "pve/local".into(), volume: "local:vztmpl/a.tar.xz".into() }),
                password: pw.map(str::to_owned),
                ssh_keys: keys.iter().map(|k| (*k).to_owned()).collect(),
                memory_mib: 64,
                ..spec()
            },
            HostKind::Pve,
        )
    };
    assert_eq!(lxc(false, Some("secret"), &[]), Some(Issue::Template));
    assert_eq!(lxc(true, None, &[]), Some(Issue::Credentials));
    assert_eq!(lxc(true, Some("abcd"), &[]), Some(Issue::Password));
    assert_eq!(lxc(true, Some("abcde"), &[]), None);
    assert_eq!(lxc(true, None, &["ssh-ed25519 AAAAC3NzaC1 me@host"]), None);
    assert_eq!(lxc(true, None, &["ssh-ed25519 AAAA a", "", "ecdsa-sha2-nistp256 AAAA b"]), None);
    assert_eq!(lxc(true, None, &["not a key"]), Some(Issue::SshKeys));
    assert_eq!(lxc(true, None, &["-----BEGIN OPENSSH PRIVATE KEY-----"]), Some(Issue::SshKeys));
    // An ISO is not a template.
    let iso = Host { media: Some(Volume { content: Some("iso".into()), ..vol("local:iso/a.iso", "a.iso") }), ..Host::pve() };
    let spec = CreateSpec {
        kind: GuestKind::Lxc,
        storage: "pve/images".into(),
        media: Some(VolumeRef { pool: "pve/local".into(), volume: "local:iso/a.iso".into() }),
        password: Some("secret".into()),
        ..spec()
    };
    assert_eq!(iso.issue(&spec, HostKind::Pve), Some(Issue::Template));
}

#[test]
fn what_the_host_offers_and_where_a_nic_goes() {
    assert_eq!(libvirt(CreateSpec { bus: Some("ide".into()), ..spec() }), Some(Issue::NotOffered));
    assert_eq!(libvirt(CreateSpec { bus: Some("sata".into()), ..spec() }), None);
    assert_eq!(libvirt(CreateSpec { nic_model: Some("rtl8139".into()), ..spec() }), Some(Issue::NotOffered));
    assert_eq!(libvirt(CreateSpec { secure_boot: true, ..spec() }), Some(Issue::SecureBoot));
    let bios = Host { options: CreateOptions { uefi: false, tpm: false, ..options() }, ..Host::libvirt() };
    assert_eq!(bios.issue(&CreateSpec { uefi: true, ..spec() }, HostKind::Libvirt), Some(Issue::NotOffered));
    assert_eq!(bios.issue(&CreateSpec { tpm: true, ..spec() }, HostKind::Libvirt), Some(Issue::NotOffered));
    assert_eq!(libvirt(CreateSpec { network: Some("default".into()), ..spec() }), None);
    assert_eq!(libvirt(CreateSpec { network: Some("gone".into()), ..spec() }), Some(Issue::Network));
    // A VM's install media, when one is named, is one.
    let host = Host { media: Some(vol("disk.qcow2", "disk.qcow2")), ..Host::libvirt() };
    let with = CreateSpec { media: Some(VolumeRef { pool: "images".into(), volume: "disk.qcow2".into() }), ..spec() };
    assert_eq!(host.issue(&with, HostKind::Libvirt), Some(Issue::Media));
}

#[test]
fn where_disks_media_and_nics_can_go() {
    let pools = vec![
        pve_pool("pve/local", "dir", &["iso", "vztmpl", "backup"]),
        pve_pool("pve/local-lvm", "lvmthin", &["images", "rootdir"]),
        pve_pool("pve2/local-lvm", "lvmthin", &["images", "rootdir"]),
        Pool { enabled: Some(false), ..pve_pool("pve/off", "dir", &["images"]) },
    ];
    let ids = |l: Vec<&Pool>| l.iter().map(|p| p.id.clone()).collect::<Vec<_>>();
    assert_eq!(ids(disk_storages(&pools, HostKind::Pve, GuestKind::Qemu, Some("pve"))), ["pve/local-lvm"]);
    assert_eq!(ids(media_storages(&pools, HostKind::Pve, GuestKind::Lxc, Some("pve"))), ["pve/local"]);
    let lv = vec![pool("images", "dir"), pool("lun", "iscsi"), Pool { active: false, ..pool("off", "dir") }];
    assert_eq!(ids(disk_storages(&lv, HostKind::Libvirt, GuestKind::Qemu, None)), ["images"]);
    assert_eq!(libvirt_disk_format("dir"), "qcow2");
    assert_eq!(libvirt_disk_format("logical"), "raw");

    assert!(is_media(&vol("a", "Debian.ISO"), GuestKind::Qemu));
    assert!(!is_media(&vol("a", "disk.qcow2"), GuestKind::Qemu));
    assert!(is_media(&Volume { content: Some("vztmpl".into()), ..vol("a", "x") }, GuestKind::Lxc));
    assert!(!is_media(&Volume { content: Some("iso".into()), ..vol("a", "x.iso") }, GuestKind::Lxc));

    let nets = vec![net("pve/vmbr0", "bridge"), net("pve/bond0", "bond"), net("pve2/vmbr0", "bridge")];
    let ids = create_networks(&nets, HostKind::Pve, Some("pve")).iter().map(|n| n.id.clone()).collect::<Vec<_>>();
    assert_eq!(ids, ["pve/vmbr0"]);
}

fn image() -> Volume {
    Volume { format: Some("qcow2".into()), capacity: Some(3758096384), ..vol("noble.img", "noble.img") }
}

fn ok_ci() -> CloudInit {
    CloudInit { user: "debian".into(), password: Some("pw".into()), hostname: Some("ci-01".into()), ..Default::default() }
}

fn with_ci(ci: CloudInit, image: bool, disk_gib: u64) -> CreateSpec {
    CreateSpec {
        name: "ci-01".into(),
        cores: 1,
        memory_mib: 1024,
        disk_gib,
        image: image.then(|| VolumeRef { pool: "images".into(), volume: "noble.img".into() }),
        cloud_init: Some(ci),
        ..spec()
    }
}

fn ci_issue(s: &CreateSpec, host: HostKind) -> Option<Issue> {
    let h = match host {
        HostKind::Libvirt => Host { guests: Vec::new(), image: Some(image()), ..Host::libvirt() },
        HostKind::Pve => Host {
            guests: Vec::new(),
            image: Some(Volume { content: Some("import".into()), ..image() }),
            ..Host::pve()
        },
    };
    let s = match host {
        HostKind::Libvirt => s.clone(),
        HostKind::Pve => CreateSpec {
            storage: "pve/images".into(),
            image: s.image.as_ref().map(|_| VolumeRef { pool: "pve/local".into(), volume: "noble.img".into() }),
            ..s.clone()
        },
    };
    h.issue(&s, host)
}

#[test]
fn a_cloud_image_chosen_and_no_bigger_than_the_disk() {
    let lv = |s| ci_issue(&s, HostKind::Libvirt);
    assert_eq!(lv(with_ci(ok_ci(), true, 8)), None);
    assert_eq!(lv(with_ci(ok_ci(), false, 8)), Some(Issue::Image));
    assert_eq!(lv(with_ci(ok_ci(), true, 3)), Some(Issue::ImageSize));
    assert_eq!(lv(with_ci(ok_ci(), true, 4)), None);
    // Never with install media.
    let both = CreateSpec { media: Some(VolumeRef { pool: "images".into(), volume: "x.iso".into() }), ..with_ci(ok_ci(), true, 8) };
    assert_eq!(lv(both), Some(Issue::Image));
    // A host without the tool makes no seed.
    let h = Host { guests: Vec::new(), image: Some(image()), options: CreateOptions { cloud_init: false, ..options() }, ..Host::libvirt() };
    assert_eq!(h.issue(&with_ci(ok_ci(), true, 8), HostKind::Libvirt), Some(Issue::NotOffered));
}

#[test]
fn cloud_init_the_account_its_way_in_the_hostname_and_the_address() {
    let ci = |c: CloudInit| ci_issue(&with_ci(c, true, 8), HostKind::Libvirt);
    let base = |user: &str| CloudInit { user: user.into(), password: Some("x".into()), hostname: Some("h".into()), ..Default::default() };
    assert_eq!(ci(base("Root")), Some(Issue::CiUser));
    assert_eq!(ci(base("1st")), Some(Issue::CiUser));
    assert_eq!(ci(CloudInit { password: None, ..base("u") }), Some(Issue::CiCredentials));
    assert_eq!(ci(CloudInit { password: None, ssh_keys: vec!["not a key".into()], ..base("u") }), Some(Issue::SshKeys));
    assert_eq!(ci(CloudInit { password: None, ssh_keys: vec!["ssh-ed25519 AAAA me".into(), "".into()], ..base("u") }), None);
    assert_eq!(ci(CloudInit { hostname: Some("ci_01".into()), ..base("u") }), Some(Issue::CiHostname));
    // PVE names the host after the VM: no hostname of its own.
    assert_eq!(ci_issue(&with_ci(CloudInit { hostname: None, ..base("u") }, true, 8), HostKind::Pve), None);
    let net = |address: Option<&str>, gateway: Option<&str>, dns: &[&str], search: &[&str]| CloudInit {
        address: address.map(str::to_owned),
        gateway: gateway.map(str::to_owned),
        dns: dns.iter().map(|s| (*s).to_owned()).collect(),
        search_domains: search.iter().map(|s| (*s).to_owned()).collect(),
        ..base("u")
    };
    assert_eq!(ci(net(Some("10.0.0.5"), None, &[], &[])), Some(Issue::CiAddress));
    assert_eq!(ci(net(Some("10.0.0.256/24"), None, &[], &[])), Some(Issue::CiAddress));
    assert_eq!(ci(net(Some("10.0.0.5/33"), None, &[], &[])), Some(Issue::CiAddress));
    assert_eq!(ci(net(Some("10.0.0.5/24"), Some("gw"), &[], &[])), Some(Issue::CiGateway));
    assert_eq!(ci(net(Some("10.0.0.5/24"), Some("10.0.0.1"), &[], &[])), None);
    assert_eq!(ci(net(None, None, &["1.1.1.1", "2606:4700::1111"], &[])), None);
    assert_eq!(ci(net(None, None, &["one.one"], &[])), Some(Issue::CiDns));
    assert_eq!(ci(net(None, None, &[], &["lab example"])), Some(Issue::CiSearch));
    assert_eq!(ci(net(None, None, &[], &["lab.example", "dev.lab.example"])), None);
    assert_eq!(ci(net(None, None, &[], &["lab.example", "a b"])), Some(Issue::CiSearch));
    // Never printed.
    let shown = format!("{:?}", net(None, None, &[], &[]));
    assert!(!shown.contains("\"x\""), "{shown}");
    assert!(shown.contains("[redacted]"), "{shown}");
}

#[test]
fn editing_cloud_init_the_password_set_is_a_way_in_unless_removed() {
    let ci = CloudInit { user: "sbxe".into(), ..Default::default() };
    assert_eq!(cloud_init_issue(&ci, HostKind::Pve, true), None);
    assert_eq!(cloud_init_issue(&ci, HostKind::Pve, false), Some(Issue::CiCredentials));
    let keyed = CloudInit { ssh_keys: vec!["ssh-ed25519 AAAAC3NzaC1lZDI1NTE5 me".into()], ..ci.clone() };
    assert_eq!(cloud_init_issue(&keyed, HostKind::Pve, false), None);
    let pw = CloudInit { password: Some("x".into()), ..ci.clone() };
    assert_eq!(cloud_init_issue(&pw, HostKind::Pve, false), None);
    assert_eq!(cloud_init_issue(&CloudInit { user: "Root".into(), ..ci.clone() }, HostKind::Pve, true), Some(Issue::CiUser));
    assert_eq!(cloud_init_issue(&CloudInit { hostname: Some("a_b".into()), ..ci.clone() }, HostKind::Libvirt, true), Some(Issue::CiHostname));
    assert_eq!(cloud_init_issue(&CloudInit { hostname: Some("ok".into()), ..ci.clone() }, HostKind::Libvirt, true), None);
    assert_eq!(cloud_init_issue(&CloudInit { address: Some("10.0.0.5".into()), ..ci }, HostKind::Pve, true), Some(Issue::CiAddress));
}

#[test]
fn which_volumes_are_cloud_images_and_where_they_are_looked_for() {
    let lv = |v: &Volume| is_cloud_image(v, HostKind::Libvirt);
    let pv = |v: &Volume| is_cloud_image(v, HostKind::Pve);
    let f = |id: &str, name: &str, format: &str| Volume { format: Some(format.into()), ..vol(id, name) };
    assert!(lv(&image()));
    assert!(lv(&f("a", "a.raw", "raw")));
    assert!(!lv(&f("a", "seed.iso", "raw")));
    assert!(!lv(&f("a", "a.iso", "iso")));
    assert!(!lv(&Volume { users: vec![GuestRef { guest_id: Some("g".into()), ..Default::default() }], ..f("a", "a.qcow2", "qcow2") }));
    let import = |v: Volume, c: &str| Volume { content: Some(c.into()), ..v };
    assert!(pv(&import(f("l:import/a.qcow2", "a.qcow2", "qcow2"), "import")));
    assert!(!pv(&import(f("l:import/a.ova", "a.ova", "ova+vmdk"), "import")));
    assert!(!pv(&import(f("l:iso/a.img", "a.img", "raw"), "iso")));
    let pools = vec![
        pve_pool("pve/local", "dir", &["iso", "import"]),
        pve_pool("pve/nas", "nfs", &["iso"]),
        pve_pool("pve2/local", "dir", &["import"]),
    ];
    let ids: Vec<_> = image_storages(&pools, HostKind::Pve, Some("pve")).iter().map(|p| p.id.clone()).collect();
    assert_eq!(ids, ["pve/local"]);
}

#[test]
fn a_form_offers_what_the_rules_allow() {
    let pools = vec![
        pve_pool("pve/local", "dir", &["iso", "vztmpl", "import"]),
        pve_pool("pve/local-lvm", "lvmthin", &["images", "rootdir"]),
    ];
    let nets = vec![net("pve/vmbr0", "bridge"), net("pve/bond0", "bond")];
    let o = options();
    let read: Vec<_> = form_pools(&pools, HostKind::Pve, GuestKind::Qemu, Some("pve"), &o).iter().map(|p| p.id.clone()).collect();
    assert_eq!(read, ["pve/local"], "one pool for both, listed once");
    let content = |id: &str, name: &str, c: &str, format: Option<&str>| Volume {
        content: Some(c.into()),
        format: format.map(str::to_owned),
        ..vol(id, name)
    };
    let volumes = vec![(
        "pve/local".to_owned(),
        vec![
            content("local:iso/z.iso", "z.iso", "iso", Some("iso")),
            content("local:iso/a.iso", "a.iso", "iso", Some("iso")),
            content("local:vztmpl/alpine.tar.xz", "alpine.tar.xz", "vztmpl", None),
            content("local:import/noble.qcow2", "noble.qcow2", "import", Some("qcow2")),
        ],
    )];
    let form = create_form(GuestKind::Qemu, HostKind::Pve, Some("pve"), o.clone(), Some(105), &pools, &nets, &volumes);
    assert_eq!(form.storages.iter().map(|p| p.id.as_str()).collect::<Vec<_>>(), ["pve/local-lvm"]);
    assert_eq!(form.networks.iter().map(|n| n.id.as_str()).collect::<Vec<_>>(), ["pve/vmbr0"]);
    assert_eq!(form.media.iter().map(|m| m.volume.name.as_str()).collect::<Vec<_>>(), ["a.iso", "z.iso"]);
    assert_eq!(form.images.iter().map(|m| m.volume.name.as_str()).collect::<Vec<_>>(), ["noble.qcow2"]);
    assert_eq!(form.images[0].pool, "pve/local");
    assert_eq!(form.next_vmid, Some(105));
    let ct = create_form(GuestKind::Lxc, HostKind::Pve, Some("pve"), o, None, &pools, &nets, &volumes);
    assert_eq!(ct.media.iter().map(|m| m.volume.name.as_str()).collect::<Vec<_>>(), ["alpine.tar.xz"]);
    assert!(ct.images.is_empty());
}

// ---------------------------------------------------------------------------
// Clone, delete, template
// ---------------------------------------------------------------------------

#[test]
fn a_clone_target_linked_storage_and_node() {
    let local = pve_pool("pve/local", "dir", &["images", "rootdir"]);
    let backup_only = pve_pool("pve/local", "dir", &["backup"]);
    let shared = Pool { shared: Some(true), ..pve_pool("pve/nfs-backup", "nfs", &["images"]) };
    let st = |pools: &[&Pool], storage: Option<&str>, full: bool, kind: GuestKind, target: Option<&str>| {
        clone_storage_issue(pools, storage, full, kind, target)
    };
    // A linked clone cannot name a storage.
    assert_eq!(st(&[&local], Some("local"), false, GuestKind::Qemu, None), Some(Issue::CloneLinkedTarget));
    assert_eq!(st(&[&local], None, false, GuestKind::Qemu, Some("pve2")), None, "no storage named: nothing to refuse here");
    assert_eq!(st(&[&local], Some("gone"), true, GuestKind::Qemu, None), Some(Issue::CloneStorage));
    assert_eq!(st(&[&backup_only], Some("local"), true, GuestKind::Qemu, None), Some(Issue::CloneStorageContent));
    assert_eq!(st(&[], None, true, GuestKind::Qemu, None), None, "no target is the source's own storage");
    // Another node needs a shared storage.
    assert_eq!(st(&[&local], Some("local"), true, GuestKind::Qemu, Some("pve2")), Some(Issue::CloneStorageShared));
    assert_eq!(st(&[&shared], Some("nfs-backup"), true, GuestKind::Qemu, Some("pve2")), None);
    // A container's disks are `rootdir`.
    let ct = pve_pool("pve/ct", "dir", &["rootdir"]);
    assert_eq!(st(&[&ct], Some("ct"), true, GuestKind::Lxc, None), None);
    assert_eq!(st(&[&ct], Some("ct"), true, GuestKind::Qemu, None), Some(Issue::CloneStorageContent));

    let nodes = [node("pve", None), node("pve2", None)];
    assert_eq!(clone_node_issue(&nodes, Some("pve2"), Some("pve")), None);
    assert_eq!(clone_node_issue(&nodes, Some("gone"), Some("pve")), Some(Issue::CloneNodeUnknown));
    assert_eq!(clone_node_issue(&nodes, Some("pve"), Some("pve")), None, "the source's own node");
    assert_eq!(clone_node_issue(&[], Some("x"), Some("pve")), None, "nothing known: the host answers");
}

#[test]
fn a_clone_its_name_vmid_and_what_each_host_needs() {
    let src = Guest { state: GuestState::Stopped, ..guest("qemu/100", "src", Some(100)) };
    let guests = vec![src.clone(), guest("qemu/101", "taken", Some(101))];
    let pools = vec![pve_pool("pve/local-lvm", "lvmthin", &["images"]), pool("images", "dir"), pool("lun", "iscsi")];
    let nodes = vec![node("pve", None)];
    let list = CloneListing { guests: &guests, nodes: &nodes, pools: &pools };
    let req = |name: &str| CloneRequest { name: name.into(), full: true, vmid: None, storage: None, target_node: None, target_pool: None };
    let pve = |g: &Guest, r: CloneRequest| clone_issue(g, &r, HostKind::Pve, list);
    let lv = |g: &Guest, r: CloneRequest| clone_issue(g, &r, HostKind::Libvirt, list);
    assert_eq!(pve(&src, req("copy")), None);
    assert_eq!(pve(&src, req("")), Some(Issue::NameEmpty));
    assert_eq!(pve(&src, req("a_b")), Some(Issue::NameInvalid));
    assert_eq!(pve(&src, req("taken")), Some(Issue::NameTaken));
    assert_eq!(pve(&src, CloneRequest { vmid: Some(101), ..req("copy") }), Some(Issue::VmidTaken));
    assert_eq!(pve(&src, CloneRequest { vmid: Some(7), ..req("copy") }), Some(Issue::VmidInvalid));
    // Not a template: a linked clone is sent as a full one, and may name a
    // storage.
    assert_eq!(pve(&src, CloneRequest { full: false, storage: Some("local-lvm".into()), ..req("copy") }), None);
    let template = Guest { template: true, ..src.clone() };
    assert_eq!(
        pve(&template, CloneRequest { full: false, storage: Some("local-lvm".into()), ..req("copy") }),
        Some(Issue::CloneLinkedTarget)
    );
    assert_eq!(
        pve(&template, CloneRequest { full: false, target_node: Some("pve".into()), ..req("copy") }),
        Some(Issue::CloneLinkedTarget)
    );
    // PVE clones a running guest; libvirt copies a stopped one only.
    let running = guest("qemu/102", "run", Some(102));
    assert_eq!(pve(&running, req("copy")), None);
    assert_eq!(lv(&running, req("copy")), Some(Issue::NotStopped));
    assert_eq!(lv(&src, CloneRequest { target_pool: Some("images".into()), ..req("copy") }), None);
    assert_eq!(lv(&src, CloneRequest { target_pool: Some("lun".into()), ..req("copy") }), Some(Issue::CloneStorage));
}

#[test]
fn delete_and_template_a_stopped_guest() {
    let off = Guest { state: GuestState::Stopped, ..guest("qemu/100", "a", Some(100)) };
    assert_eq!(delete_issue(&off), None);
    assert_eq!(delete_issue(&guest("qemu/100", "a", Some(100))), Some(Issue::NotStopped));
    assert_eq!(template_issue(&off, HostKind::Pve), None);
    assert_eq!(template_issue(&off, HostKind::Libvirt), Some(Issue::Unsupported));
    assert_eq!(template_issue(&Guest { template: true, ..off.clone() }, HostKind::Pve), Some(Issue::IsTemplate));
    assert_eq!(template_issue(&guest("qemu/100", "a", Some(100)), HostKind::Pve), Some(Issue::NotStopped));
}

#[test]
fn specs_and_requests_on_the_wire() {
    let s: CreateSpec = serde_json::from_value(serde_json::json!({
        "kind": "qemu",
        "name": "x",
        "cores": 1,
        "memory_mib": 512,
        "storage": "images",
        "disk_gib": 4,
        "media": {"pool": "images", "volume": "d.iso"},
        "cloud_init": {"user": "u", "password": "pw"},
    }))
    .unwrap();
    assert!(s.unprivileged, "the default");
    assert_eq!(s.media.as_ref().unwrap().volume, "d.iso");
    assert!(!format!("{s:?}").contains("pw\""), "no password in Debug");
    let r: CloneRequest = serde_json::from_value(serde_json::json!({"name": "c"})).unwrap();
    assert!(r.full, "full unless asked");
    assert_eq!(serde_json::to_value(Issue::CloneStorageShared).unwrap(), "clone_storage_shared");
    assert_eq!(serde_json::to_value(Issue::IsTemplate).unwrap(), "is_template");
}
