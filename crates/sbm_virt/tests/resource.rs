//! Storage and networks: the rules a change is checked by (both backends),
//! and which PVE interfaces carry a node's management traffic. Ported from
//! the app's `test/unit/virt/virt_manage_test.dart`.

use std::collections::BTreeSet;

use sbm_virt::model::HostKind;
use sbm_virt::pve::net::{LIVE_NET_SCRIPT, diff_ifaces, management_ifaces, managed_iface, parse_live_net};
use sbm_virt::resource::{
    Change, GuestRef, Issue, Listing, NetHost, Network, Pool, Volume, issue, pool_takes_media, pve_volume_vmid,
    upload_issue, volume_file_name,
};

fn pool(id: &str, ty: &str) -> Pool {
    Pool { id: id.into(), name: id.rsplit('/').next().unwrap().into(), pool_type: ty.into(), active: true, ..Default::default() }
}

fn dir() -> Pool {
    Pool { path: Some("/var/lib/libvirt/images".into()), available: Some(10 << 30), ..pool("images", "dir") }
}

fn pve_dir() -> Pool {
    Pool {
        node: Some("pve".into()),
        content: vec!["iso".into(), "vztmpl".into(), "images".into()],
        ..pool("pve/local", "dir")
    }
}

fn net(id: &str, mode: &str) -> Network {
    Network { id: id.into(), name: id.rsplit('/').next().unwrap().into(), mode: mode.into(), active: true, management_editable: true, ..Default::default() }
}

fn pve_net(name: &str, mode: &str) -> Network {
    Network { node: Some("pve".into()), ..net(&format!("pve/{name}"), mode) }
}

fn set(items: &[&str]) -> BTreeSet<String> {
    items.iter().map(|s| (*s).to_owned()).collect()
}

fn create_net(name: &str, mode: &str) -> Change {
    Change::NetworkCreate {
        name: name.into(),
        mode: mode.into(),
        node: None,
        bridge: None,
        cidr: None,
        dhcp_start: None,
        dhcp_end: None,
        vlan_aware: false,
        autostart: true,
    }
}

fn with(change: Change, edit: impl FnOnce(&mut Change)) -> Change {
    let mut c = change;
    edit(&mut c);
    c
}

type Opt<'a> = &'a mut Option<String>;

/// A new network's node, bridge, CIDR and DHCP range.
fn net_fields(c: &mut Change) -> (Opt<'_>, Opt<'_>, Opt<'_>, Opt<'_>, Opt<'_>) {
    match c {
        Change::NetworkCreate { node, bridge, cidr, dhcp_start, dhcp_end, .. } => (node, bridge, cidr, dhcp_start, dhcp_end),
        _ => unreachable!(),
    }
}

fn s(v: &str) -> Option<String> {
    Some(v.to_owned())
}

#[test]
fn networks_names_modes_subnets_and_dhcp() {
    let existing = [Network { cidrs: vec!["192.168.122.1/24".into()], ..net("default", "nat") }];
    let lv = |c: &Change| issue(c, HostKind::Libvirt, Listing { networks: &existing, ..Default::default() });
    let lab = with(create_net("lab", "nat"), |c| {
        let (_, _, cidr, a, b) = net_fields(c);
        (*cidr, *a, *b) = (s("192.168.150.1/24"), s("192.168.150.100"), s("192.168.150.200"));
    });
    assert_eq!(lv(&lab), None);
    assert_eq!(lv(&create_net("", "nat")), Some(Issue::NameEmpty));
    assert_eq!(lv(&create_net("a b", "isolated")), Some(Issue::NameInvalid));
    assert_eq!(lv(&create_net("default", "isolated")), Some(Issue::NameTaken));
    // NAT and routed need an address; isolated does not.
    assert_eq!(lv(&create_net("n", "nat")), Some(Issue::CidrInvalid));
    assert_eq!(lv(&create_net("n", "isolated")), None);
    // ... but a DHCP range needs a subnet to be served on, on a new network
    // and an edited one alike.
    let iso_dhcp = with(create_net("n", "isolated"), |c| {
        let (_, _, _, a, b) = net_fields(c);
        (*a, *b) = (s("10.0.0.2"), s("10.0.0.9"));
    });
    assert_eq!(lv(&iso_dhcp), Some(Issue::DhcpInvalid));
    let iso = [net("iso", "isolated")];
    let edit = |dhcp: bool| Change::NetworkEdit {
        network: "iso".into(),
        mode: "isolated".into(),
        bridge: None,
        address: None,
        prefix: None,
        dhcp_start: dhcp.then(|| "10.0.0.2".into()),
        dhcp_end: dhcp.then(|| "10.0.0.9".into()),
        hosts: vec![],
        restart: false,
        base_xml: None,
    };
    let on_iso = |c: &Change| issue(c, HostKind::Libvirt, Listing { networks: &iso, ..Default::default() });
    assert_eq!(on_iso(&edit(true)), Some(Issue::DhcpInvalid));
    assert_eq!(on_iso(&edit(false)), None);
    let routed = with(create_net("n", "route"), |c| *net_fields(c).2 = s("192.168.122.9/25"));
    assert_eq!(lv(&routed), Some(Issue::SubnetTaken));
    for (start, end) in [("192.168.150.1", "192.168.150.9"), ("192.168.151.2", "192.168.151.9")] {
        let c = with(create_net("n", "nat"), |c| {
            let (_, _, cidr, a, b) = net_fields(c);
            (*cidr, *a, *b) = (s("192.168.150.1/24"), s(start), s(end));
        });
        assert_eq!(lv(&c), Some(Issue::DhcpInvalid), "{start}-{end}");
    }
    // Bridge mode names a host bridge and takes no address.
    assert_eq!(lv(&with(create_net("n", "bridge"), |c| *net_fields(c).1 = s("br0"))), None);
    assert_eq!(lv(&with(create_net("n", "bridge"), |c| *net_fields(c).1 = s("br0; id"))), Some(Issue::BridgeInvalid));

    // PVE: a Linux bridge name, ports that are interfaces, per node.
    let vmbr0 = [pve_net("vmbr0", "bridge")];
    let pve = |name: &str, node: &str, ports: Option<&str>| {
        let c = with(create_net(name, "bridge"), |c| {
            let (n, b, ..) = net_fields(c);
            (*n, *b) = (s(node), ports.map(str::to_owned));
        });
        issue(&c, HostKind::Pve, Listing { networks: &vmbr0, ..Default::default() })
    };
    assert_eq!(pve("vmbr1", "pve", None), None);
    assert_eq!(pve("vmbr0", "pve", None), Some(Issue::NameTaken));
    assert_eq!(pve("vmbr0", "pve2", None), None);
    assert_eq!(pve("vm-br", "pve", None), Some(Issue::NameInvalid));
    assert_eq!(pve("vmbr1", "pve", Some("eno1 eno2")), None);
    assert_eq!(pve("vmbr1", "pve", Some("eno1 $(id)")), Some(Issue::BridgeInvalid));
}

#[test]
fn network_edit_static_hosts() {
    let lab = [Network { cidrs: vec!["192.168.150.1/24".into()], ..net("lab", "nat") }];
    let edit = |hosts: Vec<NetHost>, mode: &str| Change::NetworkEdit {
        network: "lab".into(),
        mode: mode.into(),
        bridge: (mode == "bridge").then(|| "br0".into()),
        address: s("192.168.150.1"),
        prefix: Some(24),
        dhcp_start: None,
        dhcp_end: None,
        hosts,
        restart: false,
        base_xml: None,
    };
    let host = |mac: &str, ip: &str, name: Option<&str>| NetHost { mac: mac.into(), ip: ip.into(), name: name.map(str::to_owned) };
    let check = |c: &Change| issue(c, HostKind::Libvirt, Listing { networks: &lab, ..Default::default() });
    assert_eq!(check(&edit(vec![host("52:54:00:aa:bb:01", "192.168.150.10", Some("h1"))], "nat")), None);
    for bad in [
        vec![host("52:54:00:aa:bb", "192.168.150.10", None)],
        vec![host("52:54:00:aa:bb:01", "192.168.151.10", None)],
        vec![host("52:54:00:aa:bb:01", "192.168.150.1", None)],
        vec![host("52:54:00:aa:bb:01", "192.168.150.10", Some("bad name"))],
        vec![host("52:54:00:aa:bb:01", "192.168.150.10", None), host("52:54:00:AA:BB:01", "192.168.150.11", None)],
        vec![host("52:54:00:aa:bb:01", "192.168.150.10", None), host("52:54:00:aa:bb:02", "192.168.150.10", None)],
    ] {
        assert_eq!(check(&edit(bad.clone(), "nat")), Some(Issue::HostInvalid), "{bad:?}");
    }
    // A bridge serves no DHCP of its own.
    assert_eq!(check(&edit(vec![host("52:54:00:aa:bb:01", "192.168.150.10", None)], "bridge")), Some(Issue::HostInvalid));
    // Its own subnet is not somebody else's.
    assert_eq!(check(&edit(vec![], "nat")), None);
}

fn create_pool(name: &str, ty: &str, source: &str, target: Option<&str>) -> Change {
    Change::PoolCreate {
        name: name.into(),
        pool_type: ty.into(),
        source: source.into(),
        target: target.map(str::to_owned),
        node: None,
        content: vec![],
        autostart: true,
    }
}

#[test]
fn pools_names_per_host_sources_per_type() {
    let pools = [dir()];
    let lv = |c: Change| issue(&c, HostKind::Libvirt, Listing { pools: &pools, ..Default::default() });
    assert_eq!(lv(create_pool("p", "dir", "/srv/p", None)), None);
    assert_eq!(lv(create_pool("images", "dir", "/srv/p", None)), Some(Issue::NameTaken));
    assert_eq!(lv(create_pool("p", "dir", "srv/p", None)), Some(Issue::SourceInvalid));
    assert_eq!(lv(create_pool("p", "dir", "/srv/../etc", None)), Some(Issue::SourceInvalid));
    assert_eq!(lv(create_pool("p", "netfs", "nas.lan:/export/vm", Some("/mnt/p"))), None);
    assert_eq!(lv(create_pool("p", "netfs", "nas.lan:/export/vm", None)), Some(Issue::TargetInvalid));
    assert_eq!(lv(create_pool("p", "netfs", "nas.lan/export", None)), Some(Issue::SourceInvalid));
    assert_eq!(lv(create_pool("p", "logical", "vg_data", None)), None);
    // PVE storage ids: lowercase, no trailing dash.
    let pve = |c: Change| issue(&c, HostKind::Pve, Listing::default());
    assert_eq!(pve(create_pool("nfs-2", "nfs", "10.0.0.5:/e", None)), None);
    assert_eq!(pve(create_pool("Nfs", "nfs", "10.0.0.5:/e", None)), Some(Issue::NameInvalid));
    assert_eq!(pve(create_pool("thin", "lvmthin", "pve/data", None)), None);
    assert_eq!(pve(create_pool("thin", "lvmthin", "pve", None)), Some(Issue::SourceInvalid));
    assert_eq!(pve(create_pool("zp", "zfspool", "rpool/data", None)), None);
    assert_eq!(pve(create_pool("z", "zfspool", "rpool/data", None)), Some(Issue::NameInvalid));
    assert_eq!(pve(create_pool("v6", "nfs", "[fd00::5]:/e", None)), None);
}

fn create_vol(pool: &str, name: &str, gib: u64, format: &str) -> Change {
    Change::VolumeCreate { pool: pool.into(), name: name.into(), gib, format: format.into() }
}

#[test]
fn volumes_names_formats_space_and_what_a_guest_uses() {
    let lvm = pool("vg", "logical");
    let pools = [dir(), lvm];
    let used = Volume {
        id: "a".into(),
        name: "a".into(),
        capacity: Some(1 << 30),
        users: vec![GuestRef { guest_id: s("u"), device: s("vda"), ..Default::default() }],
        ..Default::default()
    };
    let free = Volume { id: "b".into(), name: "b".into(), capacity: Some(1 << 30), ..Default::default() };
    let lv = |c: Change, volumes: &[Volume]| issue(&c, HostKind::Libvirt, Listing { pools: &pools, volumes, ..Default::default() });
    assert_eq!(lv(create_vol("images", "data.qcow2", 20, "qcow2"), &[]), None);
    assert_eq!(lv(create_vol("vg", "data", 20, "qcow2"), &[]), Some(Issue::Format));
    // A raw volume takes its size now; qcow2 grows into it.
    assert_eq!(lv(create_vol("images", "big.img", 20, "raw"), &[]), Some(Issue::Space));
    let taken = [Volume { id: "a.qcow2".into(), name: "a.qcow2".into(), ..Default::default() }];
    assert_eq!(lv(create_vol("images", "a.qcow2", 1, "qcow2"), &taken), Some(Issue::NameTaken));
    assert_eq!(lv(create_vol("images", "../x", 1, "qcow2"), &[]), Some(Issue::NameInvalid));
    assert_eq!(lv(create_vol("gone", "x", 1, "raw"), &[]), Some(Issue::NotFound));
    let both = [used.clone(), free.clone()];
    let vol = |op: &str, id: &str, bytes: u64| match op {
        "delete" => Change::VolumeDelete { pool: "images".into(), volume: id.into() },
        _ => Change::VolumeResize { pool: "images".into(), volume: id.into(), bytes },
    };
    assert_eq!(lv(vol("delete", "a", 0), &both), Some(Issue::InUse));
    assert_eq!(lv(vol("resize", "a", 2 << 30), &both), Some(Issue::InUse));
    assert_eq!(lv(vol("resize", "b", 1 << 30), &both), Some(Issue::Shrink));
    assert_eq!(lv(vol("resize", "b", 2 << 30), &both), None);
    // A volume a clone is made on is in use too.
    let base = [Volume { backs: vec!["/x/clone.qcow2".into()], ..free.clone() }];
    assert_eq!(lv(vol("delete", "b", 0), &base), Some(Issue::InUse));
    assert_eq!(lv(Change::PoolDelete { pool: "images".into(), delete_storage: false }, std::slice::from_ref(&used)), Some(Issue::InUse));
    assert_eq!(lv(Change::PoolSetActive { pool: "images".into(), active: false }, std::slice::from_ref(&used)), Some(Issue::InUse));
    assert_eq!(lv(Change::PoolSetActive { pool: "images".into(), active: true }, &[used]), None);
    // A logical pool's volumes do not change size.
    let lv_vol = [Volume { id: "lv".into(), name: "lv".into(), capacity: Some(1 << 30), ..Default::default() }];
    assert_eq!(
        lv(Change::VolumeResize { pool: "vg".into(), volume: "lv".into(), bytes: 2 << 30 }, &lv_vol),
        Some(Issue::Unsupported)
    );

    // So does anything in an LVM thin pool, raw as it is.
    let thin = Pool { node: s("pve"), available: Some(10 << 30), ..pool("pve/local-lvm", "lvmthin") };
    let pve_pools = [pve_dir(), thin.clone()];
    let pve = |c: Change| issue(&c, HostKind::Pve, Listing { pools: &pve_pools, ..Default::default() });
    assert_eq!(pve(create_vol("pve/local-lvm", "vm-100-disk-5", 20, "raw")), None);
    // PVE: vm-<VMID>-…, with the format as the extension on a directory.
    assert_eq!(pve(create_vol("pve/local", "vm-105-disk-0", 4, "qcow2")), None);
    assert_eq!(pve(create_vol("pve/local", "data", 4, "qcow2")), Some(Issue::NameInvalid));
    assert_eq!(volume_file_name(&pve_dir(), "vm-105-disk-0", "qcow2"), "vm-105-disk-0.qcow2");
    assert_eq!(volume_file_name(&pve_dir(), "vm-105-disk-0.raw", "raw"), "vm-105-disk-0.raw");
    assert_eq!(volume_file_name(&thin, "vm-105-disk-0", "raw"), "vm-105-disk-0");
    assert_eq!(pve_volume_vmid("vm-105-disk-0.qcow2"), Some(105));
    assert_eq!(pve_volume_vmid("base-9000-disk-1"), Some(9000));
    assert_eq!(pve_volume_vmid("debian.iso"), None);
}

#[test]
fn uploads_a_file_name_room_and_pools_that_take_one() {
    let d = dir();
    assert_eq!(upload_issue(&d, "debian-13.1.0-amd64-netinst.iso", 1 << 20, &[]), None);
    assert_eq!(upload_issue(&d, "a b.iso", 1, &[]), Some(Issue::NameInvalid));
    assert_eq!(upload_issue(&d, ".hidden.iso", 1, &[]), Some(Issue::NameInvalid));
    assert_eq!(upload_issue(&d, "x.iso", 20 << 30, &[]), Some(Issue::Space));
    let taken = [Volume { id: "x.iso".into(), name: "x.iso".into(), ..Default::default() }];
    assert_eq!(upload_issue(&d, "x.iso", 1, &taken), Some(Issue::NameTaken));
    assert!(pool_takes_media(&d));
    assert!(pool_takes_media(&pool("vg", "logical")));
    assert!(!pool_takes_media(&pool("d", "disk")));
    assert!(pool_takes_media(&pve_dir()));
    let images_only = Pool { node: s("pve"), content: vec!["images".into()], ..pool("pve/lvm", "lvmthin") };
    assert!(!pool_takes_media(&images_only));
}

#[test]
fn pve_changes_libvirt_does_not_make() {
    let lab = [net("lab", "nat")];
    let lv = |c: Change| issue(&c, HostKind::Libvirt, Listing { networks: &lab, ..Default::default() });
    assert_eq!(lv(Change::NetworkApply { node: "pve".into() }), Some(Issue::Unsupported));
    assert_eq!(
        lv(Change::NetworkEditBridge { network: "lab".into(), ports: None, cidr: s("10.0.0.1/24"), gateway: None, vlan_aware: None, autostart: None }),
        Some(Issue::Unsupported)
    );
    // And the other way round.
    let vmbr = [pve_net("vmbr1", "bridge")];
    let pve = |c: Change| issue(&c, HostKind::Pve, Listing { networks: &vmbr, ..Default::default() });
    assert_eq!(pve(Change::NetworkRestart { network: "pve/vmbr1".into(), base_xml: None }), Some(Issue::Unsupported));
    assert_eq!(pve(Change::NetworkApply { node: "pve".into() }), None);
    // The management interface is refused before anything is sent.
    let mgmt = [Network { management_editable: false, ..pve_net("vmbr0", "bridge") }];
    let on_mgmt = |c: Change| issue(&c, HostKind::Pve, Listing { networks: &mgmt, ..Default::default() });
    assert_eq!(on_mgmt(Change::NetworkDelete { network: "pve/vmbr0".into() }), Some(Issue::ManagementIface));
    assert_eq!(
        on_mgmt(Change::NetworkEditBridge { network: "pve/vmbr0".into(), ports: None, cidr: None, gateway: None, vlan_aware: Some(true), autostart: None }),
        Some(Issue::ManagementIface)
    );
}

#[test]
fn changes_cross_as_the_agent_reads_them() {
    let c: Change = serde_json::from_value(serde_json::json!({
        "op": "pool_create", "name": "p", "type": "dir", "source": "/srv/p"
    }))
    .unwrap();
    assert_eq!(c, create_pool("p", "dir", "/srv/p", None));
    let c: Change = serde_json::from_value(serde_json::json!({ "op": "network_apply", "node": "pve" })).unwrap();
    assert_eq!(c, Change::NetworkApply { node: "pve".into() });
    assert_eq!(serde_json::to_value(Issue::ManagementIface).unwrap(), "management_iface");
}

// ---------------------------------------------------------------------------
// A PVE interface
// ---------------------------------------------------------------------------

/// The listing of the real PVE 9.2.2 host this was written against.
fn nets() -> Vec<Network> {
    vec![
        pve_net("nic0", "eth"),
        Network { active: false, ..pve_net("wlp5s0", "eth") },
        Network { cidrs: vec!["10.77.0.1/24".into()], active: false, ..pve_net("sbxe2e0", "bridge") },
        Network {
            cidrs: vec!["192.168.31.20/24".into()],
            gateway: s("192.168.31.1"),
            ports: vec!["nic0".into()],
            ..pve_net("vmbr0", "bridge")
        },
    ]
}

/// What the node itself printed (captured on PVE 9.2.2, 2026-09-27), with a
/// second connection over a VPN bridge and a VLAN on vmbr0.
const PROBE: &str = r"@host pve
@addr
1: lo    inet 127.0.0.1/8 scope host lo\       valid_lft forever preferred_lft forever
4: vmbr0    inet 192.168.31.20/24 scope global vmbr0\       valid_lft forever preferred_lft forever
4: vmbr0    inet6 fe80::8286:f2ff:fec9:5882/64 scope link proto kernel_ll \       valid_lft forever preferred_lft forever
7: sbxe2e0    inet 10.77.0.1/24 scope global sbxe2e0\       valid_lft forever preferred_lft forever
9: vmbr1    inet 10.8.0.5/24 scope global vmbr1\       valid_lft forever preferred_lft forever
@route
default via 192.168.31.1 dev vmbr0 proto kernel onlink
@conn
0      0      192.168.31.20:22 192.168.31.183:62036
0      0      [::ffff:10.8.0.5]:22 [::ffff:10.8.0.9]:50110
0      0      127.0.0.1:8006 127.0.0.1:41234
@lower
vmbr0 nic0
vmbr0 tap100i0
@end
";

#[test]
fn the_live_probe_routes_connections_and_what_sits_under_them() {
    let live = parse_live_net(PROBE).unwrap();
    assert_eq!(live.host, "pve");
    assert_eq!(live.routed, set(&["vmbr0"]));
    // The loopback relay the API calls come through is not one.
    assert_eq!(live.connected, set(&["vmbr0", "vmbr1"]));
    assert_eq!(live.lower["vmbr0"], set(&["nic0", "tap100i0"]));
    // Cut short: nothing is concluded from it.
    assert_eq!(parse_live_net(&PROBE.replacen("@end", "", 1)), None);
    // `@end` is the last line or nothing: one inside the interfaces file is
    // not the probe's.
    assert_eq!(parse_live_net("@host pve\n@route\n@file\n@end\niface x inet manual\n"), None);
}

#[cfg(unix)]
#[test]
fn the_live_probe_says_nothing_when_a_command_it_needs_failed() {
    use std::os::unix::fs::PermissionsExt;
    let dir = std::env::temp_dir().join(format!("sbm-livenet-{}", std::process::id()));
    std::fs::create_dir_all(&dir).unwrap();
    let run = |ss_fails: bool, ip6_fails: bool| {
        let stubs = [
            ("hostname", "echo pve".to_owned()),
            ("cat", "echo \"iface vmbr0 inet static\"".to_owned()),
            ("ss", if ss_fails { "exit 1".into() } else { "echo \"0 0 10.0.0.2:22 10.0.0.9:5000\"".into() }),
            (
                "ip",
                format!(
                    "case \"$*\" in\n  *-6*) {} ;;\n  *addr*) echo \"4: vmbr0 inet 10.0.0.2/24 scope global vmbr0\" ;;\n  *) echo \"default via 10.0.0.1 dev vmbr0\" ;;\nesac",
                    if ip6_fails { "exit 1" } else { "exit 0" }
                ),
            ),
        ];
        for (name, body) in stubs {
            let f = dir.join(name);
            std::fs::write(&f, format!("#!/bin/sh\n{body}\n")).unwrap();
            std::fs::set_permissions(&f, std::fs::Permissions::from_mode(0o755)).unwrap();
        }
        let out = std::process::Command::new("sh")
            .args(["-c", LIVE_NET_SCRIPT])
            .env("PATH", format!("{}:/usr/bin:/bin", dir.display()))
            .output()
            .unwrap();
        String::from_utf8(out.stdout).unwrap()
    };
    let ok = parse_live_net(&run(false, false)).unwrap();
    assert_eq!(ok.connected, set(&["vmbr0"]));
    assert_eq!(ok.routed, set(&["vmbr0"]));
    // A kernel without IPv6 is not a failure.
    assert!(parse_live_net(&run(false, true)).is_some());
    // No connection list: not "no connections".
    assert_eq!(parse_live_net(&run(true, false)), None);
    std::fs::remove_dir_all(&dir).ok();
}

#[test]
fn pending_diffs_stanzas_directives_and_the_old_side() {
    // `auto vmbr9 vmbr0` removed touches both.
    let both = diff_ifaces("@@ -1,2 +1,1 @@\n-auto vmbr9 vmbr0\n+auto vmbr9\n", None);
    assert_eq!(both.ifaces, set(&["vmbr9", "vmbr0"]));
    assert!(!both.unknown);
    // A `source` line is no interface's, even under one's stanza.
    let source = diff_ifaces("@@ -1,3 +1,4 @@\n iface vmbr9 inet manual\n \tbridge-ports none\n+source /etc/network/more\n", None);
    assert!(source.unknown);
    let after_source = diff_ifaces("@@ -1,3 +1,4 @@\n iface vmbr9 inet manual\n source /etc/x\n+\tmtu 9000\n", None);
    assert!(after_source.unknown);
    // The old side: the address and gateway the pending file drops.
    let stripped = diff_ifaces(
        "@@ -1,4 +1,2 @@\n-iface vmbr0 inet static\n-\taddress 192.168.31.20/24\n-\tgateway 192.168.31.1\n+iface vmbr0 inet manual\n \tbridge-ports nic0\n@@ -9,2 +7,1 @@\n iface vmbr1 inet dhcp\n-\tmtu 9000\n",
        None,
    );
    assert_eq!(stripped.ifaces, set(&["vmbr0", "vmbr1"]));
    assert_eq!(stripped.old_addressed, set(&["vmbr0"]));
    assert_eq!(stripped.old_gateways, set(&["vmbr0"]));
    let dhcp = diff_ifaces("@@ -1,1 +1,1 @@\n-iface vmbr1 inet dhcp\n+iface vmbr1 inet manual\n", None);
    assert_eq!(dhcp.old_addressed, set(&["vmbr1"]));
}

#[test]
fn the_one_carrying_the_host_address_is_not_editable() {
    let live = parse_live_net(PROBE).unwrap();
    let mut with_vpn = nets();
    with_vpn.push(Network { cidrs: vec!["10.8.0.5/24".into()], ..pve_net("vmbr1", "bridge") });
    let none = BTreeSet::new();
    let m = management_ifaces(&with_vpn, Some(&live), &none, &none);
    // The default route's, and the VPN bridge a client may be connected
    // through (it has no gateway), with the port under vmbr0.
    assert!(set(&["vmbr0", "vmbr1", "nic0"]).is_subset(&m), "{m:?}");
    assert!(!m.contains("sbxe2e0"));
    // A bridge of the app's own is editable; a physical interface never is.
    for n in &with_vpn {
        assert_eq!(managed_iface(n, &m), n.name == "sbxe2e0", "{}", n.name);
    }
    // The node did not answer: every interface with an address is kept.
    assert!(set(&["vmbr0", "vmbr1", "sbxe2e0"]).is_subset(&management_ifaces(&with_vpn, None, &none, &none)));
    // A VLAN interface carrying the address protects the bridge it is on:
    // turning VLAN awareness off there would cut it.
    let vlan = [
        Network { vlan_aware: Some(true), ports: vec!["nic0".into()], ..pve_net("vmbr0", "bridge") },
        Network { cidrs: vec!["10.10.0.2/24".into()], gateway: s("10.10.0.1"), ..pve_net("vmbr0.10", "vlan") },
    ];
    assert!(set(&["vmbr0.10", "vmbr0", "nic0"]).is_subset(&management_ifaces(&vlan, None, &none, &none)));
    // An IPv6-only node: its `gateway6` counts.
    assert!(management_ifaces(&[pve_net("vmbr2", "bridge")], Some(&live), &set(&["vmbr2"]), &none).contains("vmbr2"));
}

#[test]
fn which_interfaces_a_pending_diff_touches() {
    let diff = "--- /etc/network/interfaces\t2026-09-27\n+++ /etc/network/interfaces.new\t2026-09-27\n@@ -10,6 +10,7 @@\n auto vmbr0\n iface vmbr0 inet static\n \taddress 192.168.31.20/24\n+\tbridge-vlan-aware yes\n \tgateway 192.168.31.1\n@@ -20,3 +21,8 @@\n+\n+auto vmbr9\n+iface vmbr9 inet manual\n+\tbridge-ports none\n";
    let t = diff_ifaces(diff, None);
    assert_eq!(t.ifaces, set(&["vmbr0", "vmbr9"]));
    assert!(!t.unknown);
    // A hunk whose change comes before any stanza line: not known.
    let mid = "@@ -5,3 +5,4 @@\n \tbridge-ports nic0\n \tbridge-stp off\n \tbridge-fd 0\n+\tbridge-vlan-aware yes\n";
    assert!(diff_ifaces(mid, None).unknown);
    // ... unless the file as it is says which stanza line 5 is under.
    let file = "auto lo\niface lo inet loopback\n\niface vmbr0 inet static\n\tbridge-ports nic0\n\tbridge-stp off\n\tbridge-fd 0\n";
    let placed = diff_ifaces(mid, Some(file));
    assert_eq!(placed.ifaces, set(&["vmbr0"]));
    assert!(!placed.unknown);
    // Placed after `lo`'s stanza, a hunk starting on line 3 is still lo's.
    assert_eq!(diff_ifaces("@@ -3,1 +3,2 @@\n \n+# note\n+\tmtu 9000\n", Some(file)).ifaces, set(&["lo"]));
    // A comment is its stanza's: PVE writes `comments` there.
    let comment = diff_ifaces("@@ -5,3 +5,4 @@\n \tbridge-ports nic0\n \tbridge-stp off\n \tbridge-fd 0\n+#note\n", Some(file));
    assert_eq!(comment.ifaces, set(&["vmbr0"]));
    // The probe carries the file.
    assert!(parse_live_net(&format!("@host pve\n@route\n@file\n{file}@end\n")).unwrap().interfaces.contains("iface vmbr0 inet static"));
}
