//! `libvirt::create`: what a new domain can be given, a spec as the
//! scripts', its cloud-init, what goes with a deleted domain, and a copy's
//! disks — from captured libvirt 11.3 output. Ported from the app's
//! `test/unit/virt/libvirt_backend_test.dart` (create, delete, clone).

use std::path::PathBuf;

use sbm_virt::create::{CloneRequest, CloudInit, CreateSpec, Issue, VolumeRef};
use sbm_virt::error::{Detail, ErrorKind};
use sbm_virt::libvirt::create::{
    CreateHost, DeleteInputs, clone_disks, clone_spec_of, cloud_init_of, created_of, delete_needs_chain, delete_plan,
    options_of, spec_of, with_volumes,
};
use sbm_virt::libvirt::snapshot::parse_snap_chain;
use sbm_virt::libvirt::{self as virt, FirmwareDescriptor, host};
use sbm_virt::model::{Guest, GuestKind, GuestState};
use sbm_virt::resource::{Network, Volume};

const ODD: &str = "1438b9e3-f647-47ee-8ed2-6dbc3adccd68";

fn fixture(name: &str) -> String {
    let path: PathBuf = [env!("CARGO_MANIFEST_DIR"), "tests", "fixtures", "libvirt", name].iter().collect();
    std::fs::read_to_string(path).unwrap()
}

fn guest(id: &str, name: &str, state: GuestState) -> Guest {
    Guest {
        id: id.into(),
        name: name.into(),
        kind: GuestKind::Qemu,
        state,
        state_reason: None,
        vmid: None,
        node: None,
        vcpu: None,
        mem_bytes: None,
        uptime: None,
        tags: Vec::new(),
        template: false,
        autostart: None,
        actions: Default::default(),
    }
}

fn refused(e: &sbm_virt::error::Error) -> Option<Issue> {
    match e.detail.as_deref() {
        Some(Detail::CreateRefused { issue }) => Some(*issue),
        _ => None,
    }
}

#[test]
fn options_what_the_machine_offers_and_the_seed_tool() {
    let full = virt::parse_create_host(&fixture("script_create_host_full.txt")).unwrap();
    let o = options_of(&full, &[]);
    // q35 has no IDE; OVMF is there, swtpm is not.
    assert_eq!(o.buses, ["virtio", "scsi", "sata"]);
    assert_eq!(o.nic_models[0], "virtio");
    assert_eq!((o.uefi, o.tpm, o.cloud_images, o.cloud_init), (true, false, true, true));
    assert_eq!(o.cloud_init_missing, None);
    // Secure Boot needs a firmware with the keys enrolled, whatever the
    // loader says.
    let sb = |secure_boot, enrolled_keys| FirmwareDescriptor { secure_boot, enrolled_keys, ..Default::default() };
    let caps_sb = full.caps.as_ref().is_some_and(|c| c.secure_boot);
    assert!(!options_of(&full, &[sb(true, false)]).secure_boot);
    assert_eq!(options_of(&full, &[sb(true, true)]).secure_boot, caps_sb);
    // The trimmed capture asked for no tool: none, and which to install.
    let old = virt::parse_create_host(&fixture("script_create_host.txt")).unwrap();
    let o2 = options_of(&old, &[]);
    assert!(!o2.cloud_init);
    assert!(o2.cloud_init_missing.unwrap().contains("genisoimage"));
}

#[test]
fn cloud_init_the_hostname_from_the_name_the_nic_by_its_mac() {
    let ci = |c: CloudInit, mac: Option<&str>, keep: Option<&str>| {
        cloud_init_of(&c, "web.01", mac, keep.map(str::to_owned), Vec::new(), false).unwrap()
    };
    let dhcp = ci(
        CloudInit { user: "u".into(), ssh_keys: vec![" ssh-ed25519 AAAA a ".into(), "".into()], ..Default::default() },
        Some("52:54:00:00:00:02"),
        None,
    );
    assert_eq!(dhcp.password_hash, None);
    assert_eq!(dhcp.ssh_keys, ["ssh-ed25519 AAAA a"]);
    assert_eq!(dhcp.hostname, "web.01");
    let id = dhcp.instance_id.strip_prefix("iid-web.01-").unwrap();
    assert!(id.len() == 8 && id.bytes().all(|b| b.is_ascii_hexdigit()), "{}", dhcp.instance_id);
    let n = dhcp.network.unwrap();
    assert_eq!((n.mac.as_str(), n.ipv4, n.dns.len(), n.search.len()), ("52:54:00:00:00:02", None, 0, 0));
    let fixed = ci(
        CloudInit {
            user: "u".into(),
            password: Some("pw".into()),
            hostname: Some("web-01".into()),
            address: Some("10.0.0.5/24".into()),
            gateway: Some("10.0.0.1".into()),
            dns: vec!["1.1.1.1".into()],
            search_domains: vec!["lab".into()],
            ..Default::default()
        },
        Some("52:54:00:00:00:02"),
        None,
    );
    assert!(fixed.password_hash.as_deref().unwrap().starts_with("$6$"));
    assert_eq!(fixed.hostname, "web-01");
    let n = fixed.network.unwrap();
    let ip = n.ipv4.unwrap();
    assert_eq!((ip.address.as_str(), ip.gateway.as_deref()), ("10.0.0.5/24", Some("10.0.0.1")));
    assert_eq!(n.search, ["lab"]);
    // No NIC: no network config.
    assert!(ci(CloudInit { user: "u".into(), ..Default::default() }, None, None).network.is_none());
    // An edit keeps the seed's hash where no new password was typed, and
    // replaces it where one was; each save is a new instance.
    let kept = "$6$0123456789abcdef$lDHzA5IdO41viXIs6llkDKq4Uh2VG9JXIYJ.taq2zlNFqBnKQ0/fOUW0Zoz49ZnOpe2ACY.PoF6wosL.jL3Af0";
    let keep = ci(CloudInit { user: "u".into(), ..Default::default() }, None, Some(kept));
    assert_eq!(keep.password_hash.as_deref(), Some(kept));
    let replaced = ci(CloudInit { user: "u".into(), password: Some("new one".into()), ..Default::default() }, None, Some(kept));
    let hash = replaced.password_hash.unwrap();
    assert!(hash.starts_with("$6$") && hash != kept);
    assert_ne!(replaced.instance_id, keep.instance_id);
}

fn images() -> sbm_virt::resource::Pool {
    sbm_virt::resource::Pool {
        id: "images".into(),
        name: "images".into(),
        pool_type: "dir".into(),
        path: Some("/var/lib/libvirt/images".into()),
        active: true,
        ..Default::default()
    }
}

fn default_net() -> Network {
    Network { id: "default".into(), name: "default".into(), mode: "nat".into(), active: true, ..Default::default() }
}

fn spec(name: &str) -> CreateSpec {
    CreateSpec {
        kind: GuestKind::Qemu,
        name: name.into(),
        node: None,
        vmid: None,
        cores: 1,
        memory_mib: 256,
        storage: "images".into(),
        disk_gib: 1,
        media: None,
        image: None,
        network: Some("default".into()),
        password: None,
        ssh_keys: Vec::new(),
        unprivileged: true,
        bus: None,
        nic_model: None,
        uefi: false,
        secure_boot: false,
        tpm: false,
        cloud_init: None,
        start: true,
    }
}

#[test]
fn a_spec_the_disk_in_its_pool_the_iso_by_its_path_then_the_domain_on_them() {
    let host = virt::parse_create_host(&fixture("script_create_host.txt")).unwrap();
    let pools = [images()];
    let nets = [default_net()];
    let iso = Volume { id: "sbm-test.iso".into(), name: "sbm-test.iso".into(), path: Some("/var/lib/libvirt/images/sbm-test.iso".into()), ..Default::default() };
    let on = CreateHost { host: &host, firmware: &[], guests: &[], pools: &pools, networks: &nets, media: Some(&iso), image: None };
    let s = CreateSpec { media: Some(VolumeRef { pool: "images".into(), volume: "sbm-test.iso".into() }), ..spec("sbm-create-test") };
    let lv = spec_of(&s, on, None).unwrap();
    assert_eq!((lv.disk_pool.as_str(), lv.disk_format.as_str()), ("images", "qcow2"));
    assert_eq!(lv.cdrom.as_deref(), Some("/var/lib/libvirt/images/sbm-test.iso"));
    assert_eq!(lv.network.as_deref(), Some("default"));
    assert_eq!(lv.mac, None, "libvirt's own without cloud-init");
    let volume = virt::create_volume_script(&lv).unwrap();
    assert!(volume.contains("--name 'sbm-create-test.qcow2' --capacity 1G --format qcow2"), "{volume}");
    let made = virt::parse_create_volumes(&fixture("script_create_volume.txt")).unwrap();
    let lv = with_volumes(lv, &made);
    let define = virt::define_script(&lv).unwrap();
    assert!(define.contains("/var/lib/libvirt/images/sbm-create-test.qcow2"));
    assert!(define.contains("R start --domain 'sbm-create-test'"));
    let created = created_of(&lv, &made, virt::parse_create(&fixture("script_define_ok.txt")).unwrap());
    assert_eq!(created.id, "be27edda-481c-401d-88df-57e7b8756364");
    assert_eq!((created.start_error, created.disk_kept_bytes), (None, None));

    // Media without a path: refused before the host is asked.
    let pathless = Volume { path: None, ..iso.clone() };
    let e = spec_of(&s, CreateHost { media: Some(&pathless), ..on }, None).unwrap_err();
    assert_eq!(e.kind, ErrorKind::InvalidResponse);
    // A name taken, and media that is not on offer.
    let taken = [guest(ODD, "sbm-create-test", GuestState::Stopped)];
    assert_eq!(refused(&spec_of(&s, CreateHost { guests: &taken, ..on }, None).unwrap_err()), Some(Issue::NameTaken));
    assert_eq!(refused(&spec_of(&s, CreateHost { media: None, ..on }, None).unwrap_err()), Some(Issue::Media));
}

#[test]
fn a_cloud_image_a_copy_a_seed_only_a_hash_and_the_nic_by_its_mac() {
    let host = virt::parse_create_host(&fixture("script_create_host_full.txt")).unwrap();
    let pools = [images()];
    let nets = [default_net()];
    let image = Volume {
        id: "noble.img".into(),
        name: "noble.img".into(),
        format: Some("qcow2".into()),
        path: Some("/var/lib/libvirt/images/noble.img".into()),
        ..Default::default()
    };
    let on = CreateHost { host: &host, firmware: &[], guests: &[], pools: &pools, networks: &nets, media: None, image: Some(&image) };
    let password = "correct horse battery";
    let s = CreateSpec {
        memory_mib: 1024,
        disk_gib: 8,
        image: Some(VolumeRef { pool: "images".into(), volume: "noble.img".into() }),
        bus: Some("scsi".into()),
        nic_model: Some("e1000e".into()),
        uefi: true,
        cloud_init: Some(CloudInit {
            user: "admin".into(),
            password: Some(password.into()),
            ssh_keys: vec!["ssh-ed25519 AAAAC3NzaC1lZDI1NTE5 me@x".into()],
            ..Default::default()
        }),
        start: false,
        ..spec("ci-01")
    };
    let lv = spec_of(&s, on, None).unwrap();
    assert_eq!(lv.base_image.as_deref(), Some("/var/lib/libvirt/images/noble.img"));
    let volume = virt::create_volume_script(&lv).unwrap();
    assert!(volume.contains("--vol '/var/lib/libvirt/images/noble.img'"));
    assert!(volume.contains("hashed_passwd: \"$6$"));
    assert!(!volume.contains(password), "only the hash");
    let mac = lv.mac.clone().unwrap();
    assert!(mac.starts_with("52:54:00:") && volume.contains(&mac));
    let lv = with_volumes(lv, &virt::VirtCreateVolumes {
        disk_path: "/var/lib/libvirt/images/ci-01.qcow2".into(),
        seed_path: Some("/var/lib/libvirt/images/ci-01-cidata.iso".into()),
        copied_bytes: Some(3758096384),
    });
    let define = virt::define_script(&lv).unwrap();
    assert!(define.contains("/var/lib/libvirt/images/ci-01-cidata.iso"));
    assert!(define.contains("https://serverbox.app/xmlns/libvirt/cloud-init/1"));
    assert!(define.contains("firmware="));
    assert!(define.contains(&mac), "the NIC cloud-init finds by its MAC is the one defined with it");
    assert!(!define.contains(password));

    // A copy bigger than the disk asked for keeps its size.
    let made = |bytes: u64| virt::VirtCreateVolumes { disk_path: "/d".into(), seed_path: None, copied_bytes: Some(bytes) };
    let created = virt::VirtCreated { uuid: None, start_error: None };
    assert_eq!(created_of(&lv, &made(10 << 30), created.clone()).disk_kept_bytes, Some(10 << 30));
    assert_eq!(created_of(&lv, &made(3 << 30), created.clone()).disk_kept_bytes, None);
    assert_eq!(created_of(&lv, &made(3 << 30), created).id, "ci-01", "by name where domuuid did not answer");
}

struct Read {
    storage: virt::VirtStorage,
    volumes: Vec<(String, Vec<Volume>)>,
    xml: virt::VirtDomainXml,
}

fn read(storage: &str) -> Read {
    let storage = virt::parse_storage(storage).unwrap();
    let volumes = [("images", "script_volumes_images.txt"), ("sbx-iso", "script_volumes_sbx_iso.txt")]
        .iter()
        .map(|(pool, file)| {
            let read = virt::parse_volumes(&fixture(file)).unwrap();
            ((*pool).to_owned(), read.iter().map(|v| host::volume_of(v, pool, &storage.disks)).collect())
        })
        .collect();
    let xml = virt::parse_domain_xml(&fixture("dumpxml_win11.xml")).unwrap();
    Read { storage, volumes, xml }
}

fn plan(r: &Read, snapshots: &[sbm_virt::snapshot::Snapshot], chain: Option<&virt::snapshot::VirtSnapChain>) -> sbm_virt::libvirt::create::DeletePlan {
    delete_plan(DeleteInputs {
        id: ODD,
        name: "it's-\"odd\"",
        xml: &r.xml,
        disks: &r.storage.disks,
        pools: &r.storage.pools,
        volumes: &r.volumes,
        snapshots,
        chain,
    })
}

#[test]
fn delete_the_writable_disks_only_and_the_seed_the_domain_names() {
    let mut r = read(&fixture("script_storage.txt"));
    let p = plan(&r, &[], None);
    // Not the CD-ROM.
    assert_eq!(p.targets, ["sda", "sdb", "vdb", "vdc"]);
    assert_eq!(p.seed, None);
    assert!(p.files.is_empty() && p.pools.is_empty() && p.kept.is_empty());
    let script = virt::undefine_script(ODD, &p.targets, p.seed.as_deref(), &p.pools, &p.files).unwrap();
    assert!(script.contains("--nvram --storage sda,sdb,vdb,vdc"));
    r.xml.seed = Some("/var/lib/libvirt/images/it-cidata.iso".into());
    assert_eq!(plan(&r, &[], None).seed.as_deref(), Some("/var/lib/libvirt/images/it-cidata.iso"));
}

#[test]
fn delete_a_volume_another_guest_has_or_is_made_on_stays() {
    // it's-"odd"'s sda is the file cirros-run's vdb is on; its sdb is the
    // base image cirros-run's and others' disks are made on.
    let storage = fixture("script_storage.txt").replacen(
        " file   disk    vda   /var/lib/libvirt/images/off1.qcow2",
        " file   disk    sda   /var/lib/libvirt/images/extra.qcow2\n file   disk    sdb   /var/lib/libvirt/images/cirros.img\n file   disk    vdc   /var/lib/libvirt/images/off1.qcow2",
        1,
    );
    let p = plan(&read(&storage), &[], None);
    // off1.qcow2 is its own and made on cirros.img, which stays: only what
    // nothing else needs goes.
    assert_eq!(p.targets, ["vdb", "vdc"]);
    assert_eq!(p.kept.len(), 2, "{:?}", p.kept);
}

#[test]
fn delete_the_files_external_snapshots_left_down_to_the_disk_the_first_was_taken_of() {
    let r = read(&fixture("script_storage.txt"));
    let snapshots: Vec<_> = virt::parse_snapshots(&fixture("script_snapshots_external.txt")).unwrap().iter().map(host::snapshot_of).collect();
    assert!(delete_needs_chain(&snapshots));
    assert!(!delete_needs_chain(&[]));
    // The overlay's disk is one of the guest's writable ones.
    let chain = parse_snap_chain(&fixture("script_snap_chain_overlay.txt").replace("dev='vda'", "dev='vdb'")).unwrap();
    let p = plan(&r, &snapshots, Some(&chain));
    // The overlay is what vdb is on: `--storage` deletes it. Below it, the
    // disk the snapshot was taken of, in the `images` pool.
    assert_eq!(p.targets, ["sda", "sdb", "vdb", "vdc"]);
    assert_eq!(p.files, ["/var/lib/libvirt/images/sbxe2e-f1.qcow2"]);
    assert_eq!(p.pools, ["images"]);
    let script = virt::undefine_script(ODD, &p.targets, None, &p.pools, &p.files).unwrap();
    assert!(script.contains("pool-refresh --pool 'images'"));
    assert!(script.contains("vol-delete --vol '/var/lib/libvirt/images/sbxe2e-f1.qcow2'"));
    assert!(!script.contains("vol-delete --vol '/var/lib/libvirt/sbxe2e-p8q/sx1.qcow2'"));
}

#[test]
fn clone_disks_copied_from_the_definition_then_the_copy_defined() {
    let info = virt::parse_hardware(&fixture("script_hardware_stopped.txt")).unwrap();
    let storage = virt::parse_storage(&fixture("script_storage.txt")).unwrap();
    let off = guest("hw", "sbhw-test", GuestState::Stopped);
    let req = CloneRequest { name: "sbcl-full".into(), full: true, vmid: None, storage: None, target_node: None, target_pool: None };
    let spec = clone_spec_of(&off, &info.config, &req, std::slice::from_ref(&off), &storage.pools).unwrap();
    assert_eq!(spec.source, "hw");
    assert!(spec.disks.iter().all(|d| d.source.starts_with('/')));
    let vols = virt::clone_volumes_script(&spec).unwrap();
    assert!(vols.contains("--newname 'sbcl-full.qcow2'"), "{vols}");
    let paths = virt::parse_clone_volumes(&fixture("script_clone_volumes_full.txt")).unwrap();
    let define = virt::clone_define_script(&info.config_xml, &req.name, &clone_disks(&spec, &paths)).unwrap();
    // Shell-quoted: each `'` of the XML is `'\''` in the script.
    assert!(define.contains("<source file='\\''/var/lib/libvirt/images/sbcl-full.qcow2'\\''/>"), "{define}");
    assert!(define.contains("<name>sbcl-full</name>"));

    // Running, or a name taken: refused before anything reaches the host.
    let running = Guest { state: GuestState::Running, ..off.clone() };
    let e = clone_spec_of(&running, &info.config, &req, &[], &storage.pools).unwrap_err();
    assert_eq!(refused(&e), Some(Issue::NotStopped));
    let taken = CloneRequest { name: "sbhw-test".into(), ..req.clone() };
    assert_eq!(refused(&clone_spec_of(&off, &info.config, &taken, std::slice::from_ref(&off), &storage.pools).unwrap_err()), Some(Issue::NameTaken));
    // A pool of the host's, and whether it holds files.
    let to = CloneRequest { target_pool: Some("images".into()), ..req };
    let spec = clone_spec_of(&off, &info.config, &to, &[], &storage.pools).unwrap();
    assert_eq!((spec.target_pool.as_deref(), spec.target_block), (Some("images"), false));
}
