//! The pve module against the app's own fixture.
//!
//! `test/fixtures/pve/cluster_resources.json` is what a PVE cluster answered,
//! captured verbatim, and `test/unit/server/pve_test.dart` asserts the Dart
//! model against the same file. This asserts the Rust port against those bytes,
//! so "the two agree" is a claim about one document rather than two copies of
//! it that could drift apart.
//!
//! Read at runtime rather than `include_str!`: `monitor/Dockerfile` builds this
//! crate with `crates/` copied into the image and `monitor/` as the workspace
//! root, where `../../test/` is not there.
//!
//! TODO(migration): move `test/fixtures/pve/` into this crate when the Dart test
//! is deleted, and read it with `include_str!`.

use serde_json::Value;
use sbm_parser::pve::*;

const FIXTURE: &str =
    concat!(env!("CARGO_MANIFEST_DIR"), "/../../test/fixtures/pve/cluster_resources.json");

fn cluster() -> Vec<PveResource> {
    let raw = std::fs::read_to_string(FIXTURE).unwrap_or_else(|e| panic!("{FIXTURE}: {e}"));
    let body: Value = serde_json::from_str(&raw).expect("the fixture is JSON");
    parse_cluster_resources(&body).expect("the fixture is a listing")
}

#[test]
fn every_captured_resource_is_parsed() {
    // The Dart test's own assertion: eight entries, none of them skipped. The
    // fixture has one of each type plus the three storages, and a port that
    // dropped a type would answer fewer.
    assert_eq!(cluster().len(), 8);
}

#[test]
fn each_resource_keeps_what_pve_said_about_it() {
    let resources = cluster();
    let kinds: Vec<&str> = resources.iter().map(|r| r.kind().as_str()).collect();
    assert_eq!(
        kinds,
        vec![
            "node", "qemu", "qemu", "lxc", "storage", "storage", "storage", "sdn"
        ]
    );

    // The node: PVE sends `cgroup-mode` and `level` too, which no client draws.
    let node = &resources[0];
    assert_eq!(node.id(), "node/pve");
    assert_eq!(node.name(), "pve");
    assert!(node.is_running());
    let PveResource::Node(node) = node else {
        panic!("expected a node first");
    };
    assert_eq!(node.maxcpu, 12);
    assert_eq!(node.mem, 11_522_887_680);
    assert_eq!(node.uptime, 1_204_771);
    assert_eq!(node.cpu, 0.0451634094268353);

    // A VM that is stopped, which is the one an action is offered on.
    let stopped = &resources[1];
    assert_eq!(stopped.guest_kind(), Some(PveGuestKind::Qemu));
    assert_eq!(stopped.vmid(), Some(101));
    assert_eq!(stopped.name(), "ubuntu");
    assert!(!stopped.is_running());
    assert_eq!(stopped.status(), "stopped");

    let running = &resources[2];
    assert_eq!(running.id(), "qemu/102");
    assert_eq!(running.name(), "win");
    assert!(running.is_running());

    // A container, the other guest kind, with the counters a page draws.
    let guest = &resources[3];
    assert_eq!(guest.guest_kind(), Some(PveGuestKind::Lxc));
    assert_eq!(guest.vmid(), Some(100));
    assert_eq!(guest.name(), "Jellyfin");
    assert!(guest.is_running());
    let PveResource::Lxc(guest) = guest else {
        panic!("expected the container");
    };
    assert_eq!(guest.netin, 65_412_250_538);
    assert_eq!(guest.diskwrite, 707_866_570_752);
    assert_eq!(guest.maxdisk, 134_145_380_352);
    assert_eq!(guest.maxcpu, 8);
}

#[test]
fn the_storages_are_sorted_by_name_and_their_contents_by_type() {
    let resources = cluster();
    let storages: Vec<&PveResource> = resources
        .iter()
        .filter(|r| r.kind() == PveKind::Storage)
        .collect();
    let names: Vec<&str> = storages.iter().map(|r| r.name()).collect();
    // DSM, hard, local — PVE answered them DSM, hard, local and the sort is by
    // name, so this holds whatever order a later capture arrives in.
    assert_eq!(names, vec!["DSM", "hard", "local"]);

    // Each `content` is a different permutation in the fixture, and all three
    // read the same after sorting. The app sorts this field too.
    for resource in &storages {
        assert!(resource.is_running(), "available");
        let PveResource::Storage(storage) = resource else {
            panic!("filtered to storages");
        };
        assert_eq!(storage.content, "backup,images,iso,rootdir,snippets,vztmpl");
        let expected_plugin = if storage.storage == "DSM" { "cifs" } else { "dir" };
        assert_eq!(storage.plugintype, expected_plugin);
    }
    let PveResource::Storage(dsm) = storages[0] else {
        unreachable!()
    };
    assert_eq!(dsm.shared, 1);
    assert_eq!(dsm.maxdisk, 9_909_187_887_104);
}

#[test]
fn the_sdn_zone_is_parsed() {
    let resources = cluster();
    let sdn = resources.last().expect("one sdn");
    assert_eq!(sdn.kind(), PveKind::Sdn);
    assert_eq!(sdn.id(), "sdn/pve/localnetwork");
    assert_eq!(sdn.name(), "localnetwork");
    assert!(sdn.is_running(), "ok");
    assert_eq!(sdn.guest_kind(), None);
    assert_eq!(sdn.vmid(), None);
}

#[test]
fn the_listing_is_stable_across_refreshes() {
    // PVE's own order varies between calls — the fixture above is not in this
    // order — so the same resources must come back in the same order twice.
    let first: Vec<String> = cluster().iter().map(|r| r.id().to_string()).collect();
    let second: Vec<String> = cluster().iter().map(|r| r.id().to_string()).collect();
    assert_eq!(first, second);
    assert_eq!(
        first,
        vec![
            "node/pve",
            "qemu/101",
            "qemu/102",
            "lxc/100",
            "storage/pve/DSM",
            "storage/pve/hard",
            "storage/pve/local",
            "sdn/pve/localnetwork",
        ]
    );
}

#[test]
fn an_action_is_addressed_at_the_guest_the_page_named() {
    // The path the panel's control request composes from the fixture's own
    // resources: each is PVE's, and every part a caller sent is validated.
    let resources = cluster();
    let jellyfin = &resources[3];
    assert_eq!(
        control_path(
            jellyfin.node(),
            jellyfin.guest_kind().expect("a guest"),
            jellyfin.vmid().expect("a guest has an id"),
            PveAction::Shutdown,
        )
        .unwrap(),
        "/api2/json/nodes/pve/lxc/100/status/shutdown"
    );

    // A resource that is not a guest has no action, and the caller is the one
    // that has to refuse it — this answers `None` rather than a default kind.
    assert_eq!(resources[0].guest_kind(), None);
    assert_eq!(resources.last().unwrap().guest_kind(), None);
}
