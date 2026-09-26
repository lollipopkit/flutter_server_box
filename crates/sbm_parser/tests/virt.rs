//! `sbm_parser::virt` against the fixtures in `tests/fixtures/virt/` (see the
//! README there: mostly captured from a libvirt 11.3.0 host, the rest
//! hand-written and labelled as such), plus the generated scripts run by a
//! real `sh` against a stub `virsh`.
//!
//! `overview.expected.json` / `detail_*.expected.json` are also what the
//! Dart FFI test compares against. Regenerate them with
//! `SBM_UPDATE_VIRT_FIXTURES=1 cargo test -p sbm_parser --test virt`, and
//! review the diff: they are the contract, not a snapshot to accept blindly.

use sbm_parser::script;
use sbm_parser::virt::{self, VirtAction, VirtError, VirtState};
use std::path::PathBuf;
use std::process::{Command, Stdio};

fn dir() -> PathBuf {
    PathBuf::from(env!("CARGO_MANIFEST_DIR")).join("tests/fixtures/virt")
}

fn fixture(name: &str) -> String {
    std::fs::read_to_string(dir().join(name)).unwrap_or_else(|e| panic!("{name}: {e}"))
}

/// What a script prints for one `virsh` call: marker, output, status line.
fn section(key: &str, body: &str, rc: i32) -> String {
    format!("{}\n{body}\n{}{rc}\n", script::cmd_marker(key), virt::RC_PREFIX)
}

fn overview_output(list_fixture: &str) -> String {
    [
        section(virt::KEY_VERSION, &fixture("version_libvirt11.txt"), 0),
        section(virt::KEY_LIST, &fixture(list_fixture), 0),
        section(virt::KEY_AUTOSTART, &fixture("list_autostart.txt"), 0),
        section(virt::KEY_PERSISTENT, &fixture("list_persistent.txt"), 0),
        section(virt::KEY_STATS, &fixture("domstats.txt"), 0),
    ]
    .concat()
}

fn detail_output(display: (&str, i32), xml: &str) -> String {
    section(virt::KEY_DISPLAY, &fixture(display.0), display.1)
        + &section(virt::KEY_XML, &fixture(xml), 0)
}

/// Compare against (or with the env var set, rewrite) an expected JSON file.
fn assert_expected<T: serde::Serialize>(value: &T, name: &str) {
    let path = dir().join(name);
    let json = serde_json::to_string_pretty(value).unwrap() + "\n";
    if std::env::var_os("SBM_UPDATE_VIRT_FIXTURES").is_some() {
        std::fs::write(&path, &json).unwrap();
        return;
    }
    let expected: serde_json::Value =
        serde_json::from_str(&fixture(name)).unwrap_or_else(|e| panic!("{name}: {e}"));
    assert_eq!(serde_json::to_value(value).unwrap(), expected, "{name}");
}

#[test]
fn version() {
    let v = virt::parse_version(&fixture("version_libvirt11.txt")).unwrap();
    assert_eq!(v.libvirt.as_deref(), Some("11.3.0"));
    assert_eq!(v.hypervisor.as_deref(), Some("QEMU"));
    assert_eq!(v.hypervisor_version.as_deref(), Some("10.0.13"));
    let v = virt::parse_version(&fixture("version_libvirt12.txt")).unwrap();
    assert_eq!(v.libvirt.as_deref(), Some("12.0.0"));
    assert_eq!(v.hypervisor_version.as_deref(), Some("10.2.1"));
    assert!(virt::parse_version("").is_none());
    assert!(virt::parse_version("garbage\n").is_none());
}

#[test]
fn uuid_names_both_formats() {
    let new = virt::parse_uuid_names(&fixture("list_uuid_name.txt"));
    assert_eq!(new.len(), 3);
    assert_eq!(new[1].1, "cirros-paused");
    assert_eq!(new[2].1, "it's-\"odd\"");
    let old = virt::parse_uuid_names(&fixture("list_uuid_name_libvirt6.txt"));
    assert_eq!(old.len(), 3);
    assert_eq!(old[1].1.trim_end(), "cirros-paused");
    for ((u1, n1), (u2, n2)) in new.iter().zip(&old) {
        assert_eq!(u1, u2);
        assert_eq!(n1, n2.trim_end());
    }
}

#[test]
fn domstats_records() {
    // Captured: libvirt prints domains in its own order, not `list`'s
    let recs = virt::parse_domstats(&fixture("domstats.txt"));
    let names: Vec<&str> = recs.iter().map(|r| r.name.as_str()).collect();
    assert_eq!(names, ["cirros-paused", "cirros-run", "it's-\"odd\""]);

    let paused = &recs[0];
    assert_eq!((paused.state_code, paused.reason_code), (Some(3), Some(1)));
    assert_eq!(paused.counters.balloon_available_kib, Some(189780));
    assert_eq!(paused.counters.balloon_unused_kib, Some(143512));

    let run = &recs[1];
    assert_eq!((run.state_code, run.reason_code), (Some(1), Some(1)));
    assert_eq!(run.counters.cpu_time_ns, Some(7550532000));
    assert_eq!((run.vcpu_current, run.vcpu_max), (Some(2), Some(2)));
    assert_eq!(run.mem_max_kib, Some(262144));
    assert_eq!(run.counters.balloon_rss_kib, Some(285628));
    // Two vCPUs' worth of `vcpu.N.*.sum` lines do not create anything
    assert_eq!(run.counters.nets.len(), 2);
    assert_eq!(run.counters.nets[1].name, "vnet1");
    assert_eq!(run.counters.nets[1].rx_bytes, Some(12948));
    assert_eq!(run.counters.blocks.len(), 2);
    assert_eq!(run.counters.blocks[1].name, "vdb");
    assert_eq!(run.counters.blocks[1].capacity, Some(1073741824));

    // Shut off: libvirt 11.3 still reports the CPU time of the last run and
    // the block sizes, but no I/O counters and no nets
    let odd = &recs[2];
    // Reason 6 (`failed`): its last start was refused (see
    // `error_apparmor_start.txt`)
    assert_eq!((odd.state_code, odd.reason_code), (Some(5), Some(6)));
    assert_eq!(odd.counters.cpu_time_ns, Some(610000000));
    assert_eq!(odd.mem_current_kib, Some(262144));
    assert!(odd.counters.nets.is_empty());
    assert_eq!(odd.counters.blocks[0].rd_bytes, None);
    assert_eq!(
        odd.counters.blocks[0].path.as_deref(),
        Some("/var/lib/libvirt/images/off1.qcow2")
    );
}

/// Shapes the test host does not have (hand-written, see the README):
/// vCPUs below the maximum, an empty cdrom, macvtap, a domain in shutdown.
#[test]
fn domstats_synthetic_records() {
    let recs = virt::parse_domstats(&fixture("domstats_synthetic.txt"));
    let win = &recs[0];
    assert_eq!((win.vcpu_current, win.vcpu_max), (Some(4), Some(8)));
    assert_eq!(win.counters.blocks.len(), 3);
    assert_eq!(win.counters.blocks[1].wr_bytes, Some(180224000));
    // An empty cdrom has no path
    assert_eq!(win.counters.blocks[2].path, None);
    assert_eq!(win.counters.nets[1].name, "macvtap0");
    assert_eq!(win.counters.nets[1].tx_bytes, Some(2048));
    let ci = &recs[1];
    assert_eq!(VirtState::from_libvirt(ci.state_code.unwrap(), ci.reason_code.unwrap()), VirtState::Stopping);
}

#[test]
fn overview() {
    let o = virt::parse_overview(&overview_output("list_uuid_name.txt")).unwrap();
    assert_eq!(o.version.as_ref().unwrap().libvirt.as_deref(), Some("11.3.0"));
    // `list` order, whatever order domstats printed
    let names: Vec<&str> = o.domains.iter().map(|d| d.name.as_str()).collect();
    assert_eq!(names, ["cirros-run", "cirros-paused", "it's-\"odd\""]);
    let by_name = |n: &str| o.domains.iter().find(|d| d.name == n).unwrap();

    let run = by_name("cirros-run");
    assert_eq!(run.state, VirtState::Running);
    assert_eq!(run.reason, "booted");
    assert!(run.autostart && run.persistent);
    assert_eq!(run.vcpu_current, Some(2));

    let paused = by_name("cirros-paused");
    assert_eq!(paused.state, VirtState::Paused);
    assert_eq!(paused.reason, "user");
    assert!(!paused.autostart && paused.persistent);

    let odd = by_name("it's-\"odd\"");
    assert_eq!(odd.uuid, "1438b9e3-f647-47ee-8ed2-6dbc3adccd68");
    assert_eq!(odd.state, VirtState::Stopped);
    assert_eq!(odd.reason, "failed");
    assert_eq!(odd.mem_max_kib, Some(262144));

    assert_expected(&o, "overview.expected.json");

    // libvirt < 7.0's padded list joins to the same result
    let old = virt::parse_overview(&overview_output("list_uuid_name_libvirt6.txt")).unwrap();
    assert_eq!(old, o);
}

#[test]
fn overview_domain_missing_from_stats() {
    // Defined between `list` and `domstats`: listed, no numbers
    let raw = [
        section(virt::KEY_LIST, "11111111-2222-4333-8444-555555555555 new-one", 0),
        section(virt::KEY_AUTOSTART, "", 0),
        section(virt::KEY_PERSISTENT, "", 0),
        section(virt::KEY_STATS, "", 0),
    ]
    .concat();
    let o = virt::parse_overview(&raw).unwrap();
    assert_eq!(o.version, None);
    assert_eq!(o.domains[0].name, "new-one");
    assert_eq!(o.domains[0].state, VirtState::Unknown);
    assert_eq!(o.domains[0].state_code, -1);
}

#[test]
fn overview_errors() {
    let failing = |file: &str| {
        [
            virt::KEY_VERSION,
            virt::KEY_LIST,
            virt::KEY_AUTOSTART,
            virt::KEY_PERSISTENT,
            virt::KEY_STATS,
        ]
        .iter()
        .map(|k| section(k, &fixture(file), 1))
        .collect::<String>()
    };
    match virt::parse_overview(&failing("error_permission.txt")) {
        Err(VirtError::PermissionDenied { message }) => {
            assert!(message.contains("libvirt-sock': Permission denied"), "{message}");
            assert!(!message.contains("error:"));
        }
        other => panic!("{other:?}"),
    }
    assert!(matches!(
        virt::parse_overview(&failing("error_polkit.txt")),
        Err(VirtError::PermissionDenied { .. })
    ));
    assert!(matches!(
        virt::parse_probe(&failing("error_polkit.txt")),
        Err(VirtError::PermissionDenied { .. })
    ));
    assert!(matches!(
        virt::parse_overview(&failing("error_no_daemon.txt")),
        Err(VirtError::ConnectFailed { .. })
    ));
    // Cut off mid-stats: no status line
    let mut cut = overview_output("list_uuid_name.txt");
    cut.truncate(cut.rfind(virt::RC_PREFIX).unwrap());
    assert!(matches!(
        virt::parse_overview(&cut),
        Err(VirtError::Malformed { .. })
    ));
}

#[test]
fn detail_running_vnc() {
    let d = virt::parse_domain_detail(&detail_output(
        ("domdisplay_cirros_run.txt", 0),
        "dumpxml_cirros_run.xml",
    ))
    .unwrap();
    let display = d.display.as_ref().unwrap();
    assert_eq!(display.protocol, "vnc");
    assert_eq!(display.host.as_deref(), Some("127.0.0.1"));
    assert_eq!(display.port, Some(5900));
    let x = &d.xml;
    assert_eq!(x.name.as_deref(), Some("cirros-run"));
    assert_eq!(x.title, None);
    assert_eq!(x.arch.as_deref(), Some("x86_64"));
    assert_eq!(x.machine.as_deref(), Some("pc-i440fx-10.0"));
    // The backing chain's `<source>` is not a second disk
    let sources: Vec<Option<&str>> = x.disks.iter().map(|d| d.source.as_deref()).collect();
    assert_eq!(
        sources,
        [
            Some("/var/lib/libvirt/images/run1.qcow2"),
            Some("/var/lib/libvirt/images/extra.qcow2"),
        ]
    );
    assert_eq!(x.disks[0].format.as_deref(), Some("qcow2"));
    assert_eq!(x.disks[1].target.as_deref(), Some("vdb"));
    assert_eq!(x.nics.len(), 2);
    assert_eq!(x.nics[0].source.as_deref(), Some("default"));
    assert_eq!(x.nics[1].target.as_deref(), Some("vnet1"));
    assert_eq!(x.graphics[0].port, Some(5900));
    assert_eq!(x.graphics[0].listen.as_deref(), Some("127.0.0.1"));
    assert!(x.has_serial_console);
    assert_expected(&d, "detail_cirros_run.expected.json");
}

#[test]
fn detail_spice_many_devices() {
    let d = virt::parse_domain_detail(&detail_output(
        ("domdisplay_win11.txt", 0),
        "dumpxml_win11.xml",
    ))
    .unwrap();
    let display = d.display.as_ref().unwrap();
    assert_eq!((display.port, display.tls_port), (Some(5901), Some(5902)));
    let x = &d.xml;
    assert_eq!(x.description.as_deref(), Some("Windows 11 test box\nsecond line"));
    let sources: Vec<Option<&str>> = x.disks.iter().map(|d| d.source.as_deref()).collect();
    assert_eq!(
        sources,
        [
            Some("/var/lib/libvirt/images/win11.qcow2"),
            Some("/srv/vm/win11-data.raw"),
            None,
            Some("rbd:vms/win11-scratch"),
            Some("fast/win11-swap.qcow2"),
        ]
    );
    assert_eq!(x.disks[2].device, "cdrom");
    assert!(x.disks[2].readonly);
    assert_eq!(x.nics[0].kind, "bridge");
    assert_eq!(x.nics[0].source.as_deref(), Some("br0"));
    assert_eq!(x.nics[0].model.as_deref(), Some("e1000e"));
    assert_eq!(x.nics[1].source.as_deref(), Some("enp3s0"));
    assert_eq!(x.graphics[0].kind, "spice");
    assert_eq!(x.graphics[0].tls_port, Some(5902));
    assert!(!x.has_serial_console);
    assert_expected(&d, "detail_win11.expected.json");
}

#[test]
fn detail_stopped_without_graphics() {
    let d = virt::parse_domain_detail(&detail_output(
        ("error_display_not_running.txt", 1),
        "dumpxml_odd.xml",
    ))
    .unwrap();
    assert_eq!(d.display, None);
    assert_eq!(d.xml.name.as_deref(), Some("it's-\"odd\""));
    assert_eq!(d.xml.arch.as_deref(), Some("x86_64"));
    assert!(d.xml.graphics.is_empty());
    assert!(d.xml.has_serial_console);
    assert_eq!(d.xml.nics[0].target, None);

    let d = virt::parse_domain_detail(&detail_output(
        ("error_display_no_graphics.txt", 1),
        "dumpxml_odd.xml",
    ))
    .unwrap();
    assert_eq!(d.display, None);
}

#[test]
fn detail_inactive_vnc() {
    // Captured: the running domain's inactive definition, as a shut-off
    // domain with VNC prints it
    let x = virt::parse_domain_xml(&fixture("dumpxml_cirros_run_inactive.xml")).unwrap();
    assert_eq!(x.graphics.len(), 1);
    assert_eq!(x.graphics[0].port, None);
    assert!(x.graphics[0].autoport);
    assert_eq!(x.graphics[0].listen.as_deref(), Some("127.0.0.1"));
    assert!(x.nics.iter().all(|n| n.target.is_none()));

    // Hand-written: a socket listener
    let x = virt::parse_domain_xml(&fixture("dumpxml_inactive_vnc.xml")).unwrap();
    assert_eq!(x.graphics.len(), 2);
    assert_eq!(x.graphics[0].port, None);
    assert!(x.graphics[0].autoport);
    assert_eq!(x.graphics[1].socket.as_deref(), Some("/run/libvirt/qemu/web-01.vnc"));
    assert!(!x.has_serial_console);
}

#[test]
fn detail_errors() {
    let raw = section(virt::KEY_DISPLAY, "error: failed to get domain 'x'", 1)
        + &section(virt::KEY_XML, "error: failed to get domain 'x'", 1);
    assert!(matches!(
        virt::parse_domain_detail(&raw),
        Err(VirtError::DomainNotFound { .. })
    ));
    let raw = section(virt::KEY_DISPLAY, "", 0) + &section(virt::KEY_XML, "<domain><name>", 0);
    assert!(matches!(
        virt::parse_domain_detail(&raw),
        Err(VirtError::Malformed { .. })
    ));
}

#[test]
fn actions() {
    let ok = section(
        virt::KEY_ACTION,
        "Domain '3b1f0c4e-9a57-4d4e-8f0e-2d6c1a9b7e10' started",
        0,
    );
    assert_eq!(virt::parse_action(&ok), Ok(()));
    for (file, kind) in [
        ("error_already_running.txt", "invalid_state"),
        ("error_already_active.txt", "invalid_state"),
        ("error_not_running.txt", "invalid_state"),
        ("error_not_found.txt", "domain_not_found"),
        ("error_apparmor_start.txt", "command"),
    ] {
        let err = virt::parse_action(&section(virt::KEY_ACTION, &fixture(file), 1)).unwrap_err();
        assert_eq!(serde_json::to_value(&err).unwrap()["kind"], kind, "{file}: {err:?}");
        assert!(!err.message().lines().any(|l| l.starts_with("error:")), "{file}");
    }
    assert!(matches!(
        virt::parse_action(&section(virt::KEY_ACTION, &fixture("error_permission.txt"), 1)),
        Err(VirtError::PermissionDenied { .. })
    ));

    for (action, cmd) in [
        (VirtAction::Start, "start"),
        (VirtAction::Shutdown, "shutdown"),
        (VirtAction::Reboot, "reboot"),
        (VirtAction::ForceStop, "destroy"),
        (VirtAction::Suspend, "suspend"),
        (VirtAction::Resume, "resume"),
    ] {
        let s = virt::action_script(action, "3b1f0c4e-9a57-4d4e-8f0e-2d6c1a9b7e10");
        assert!(
            s.contains(&format!("V {cmd} --domain '3b1f0c4e-9a57-4d4e-8f0e-2d6c1a9b7e10'\n")),
            "{s}"
        );
    }
}

#[test]
fn error_json_shape() {
    let e = VirtError::PermissionDenied {
        message: "m".into(),
    };
    assert_eq!(
        serde_json::to_value(&e).unwrap(),
        serde_json::json!({"kind": "permission_denied", "message": "m"})
    );
    assert_eq!(
        serde_json::to_value(VirtError::NotInstalled).unwrap(),
        serde_json::json!({"kind": "not_installed"})
    );
}

// ---------------------------------------------------------------------------
// The scripts under a real sh, against a stub virsh
// ---------------------------------------------------------------------------

/// A directory holding a `virsh` that answers from the fixtures, logs its
/// argv (one argument per line) and whatever it finds on stdin.
fn stub_dir(tag: &str) -> PathBuf {
    let d = std::env::temp_dir().join(format!("sbm_virt_stub_{tag}_{}", std::process::id()));
    let _ = std::fs::remove_dir_all(&d);
    std::fs::create_dir_all(&d).unwrap();
    let f = dir();
    let f = f.display();
    let stub = format!(
        r#"#!/bin/sh
log="$(dirname "$0")/log"
for a in "$@"; do printf '%s\n' "$a" >> "$log"; done
echo --- >> "$log"
cat >> "$(dirname "$0")/stdin"
[ "$1 $2 $3" = "--connect qemu:///system -q" ] || {{ echo "error: bad prefix" >&2; exit 9; }}
shift 3
case "$*" in
  version) cat '{f}/version_libvirt11.txt' ;;
  "list --all --uuid --name") cat '{f}/list_uuid_name.txt' ;;
  "list --all --uuid --autostart") cat '{f}/list_autostart.txt' ;;
  "list --all --uuid --persistent") cat '{f}/list_persistent.txt' ;;
  domstats*) cat '{f}/domstats.txt' ;;
  "domdisplay --domain "*) cat '{f}/error_display_not_running.txt' >&2; exit 1 ;;
  "dumpxml --domain "*) cat '{f}/dumpxml_odd.xml' ;;
  "start --domain "*) echo "Domain '$3' started" ;;
  *) echo "error: unexpected $*" >&2; exit 1 ;;
esac
"#
    );
    let path = d.join("virsh");
    std::fs::write(&path, stub).unwrap();
    Command::new("chmod").arg("+x").arg(&path).status().unwrap();
    d
}

/// Feed `script` to `sh` on stdin, as the app does, with `path` as PATH.
fn run_sh(script: &str, path: &str) -> String {
    use std::io::Write;
    let mut child = Command::new("/bin/sh")
        .env("PATH", path)
        .stdin(Stdio::piped())
        .stdout(Stdio::piped())
        .stderr(Stdio::piped())
        .spawn()
        .unwrap();
    child.stdin.take().unwrap().write_all(script.as_bytes()).unwrap();
    let out = child.wait_with_output().unwrap();
    String::from_utf8(out.stdout).unwrap()
}

#[cfg(unix)]
#[test]
fn scripts_under_sh() {
    let d = stub_dir("ok");
    let path = format!("{}:/usr/bin:/bin", d.display());

    let o = virt::parse_overview(&run_sh(&virt::overview_script(), &path)).unwrap();
    let expected = virt::parse_overview(&overview_output("list_uuid_name.txt")).unwrap();
    assert_eq!(o, expected);

    // The name reaches virsh as one argument, untouched
    let name = "it's \"odd\"; touch pwned $(id) `id`";
    let detail = virt::parse_domain_detail(&run_sh(&virt::domain_detail_script(name), &path))
        .unwrap();
    assert_eq!(detail.display, None);
    assert_eq!(detail.xml.name.as_deref(), Some("it's-\"odd\""));
    assert_eq!(
        virt::parse_action(&run_sh(&virt::action_script(VirtAction::Start, name), &path)),
        Ok(())
    );
    let log = std::fs::read_to_string(d.join("log")).unwrap();
    assert!(log.contains(&format!("--domain\n{name}\n---\n")), "{log}");
    assert!(!d.join("pwned").exists() && !std::path::Path::new("pwned").exists());
    // virsh never saw the script, which sh is reading from the same stdin
    assert_eq!(std::fs::read_to_string(d.join("stdin")).unwrap(), "");

    // A failing call's stderr lands in its section
    let bad = run_sh(
        &virt::action_script(VirtAction::Resume, "x"),
        &path,
    );
    assert!(matches!(virt::parse_action(&bad), Err(VirtError::Command { .. })));
    let _ = std::fs::remove_dir_all(&d);
}

#[cfg(unix)]
#[test]
fn scripts_without_virsh() {
    let empty = std::env::temp_dir().join(format!("sbm_virt_empty_{}", std::process::id()));
    std::fs::create_dir_all(&empty).unwrap();
    let raw = run_sh(&virt::overview_script(), &empty.display().to_string());
    assert_eq!(virt::parse_overview(&raw), Err(VirtError::NotInstalled));
    let probe = virt::parse_probe(&run_sh(&virt::probe_script(), &empty.display().to_string()));
    assert_eq!(probe, Ok(virt::VirtHostProbe::default()));
    let _ = std::fs::remove_dir_all(&empty);
}

// ---------------------------------------------------------------------------
// Snapshots, storage and networks: whole script outputs, captured
// ---------------------------------------------------------------------------

#[test]
fn snapshots_tree_current_and_memory() {
    let snaps = virt::parse_snapshots(&fixture("script_snapshots_cirros_run.txt")).unwrap();
    assert_eq!(
        snaps.iter().map(|s| s.name.as_str()).collect::<Vec<_>>(),
        ["sbx-a", "sbx-b", "sbx-off"]
    );
    let a = &snaps[0];
    assert!(a.current && a.memory && !a.external);
    assert_eq!(a.parent, None);
    assert_eq!(a.description.as_deref(), Some("first one"));
    assert_eq!(a.state.as_deref(), Some("running"));
    assert_eq!(a.creation_time, Some(1790335495));
    let off = &snaps[2];
    // Taken while shut off: disks only
    assert!(!off.memory && !off.current);
    assert_eq!(off.state.as_deref(), Some("shutoff"));
    assert_eq!(off.parent.as_deref(), Some("sbx-a"));
    assert_eq!(snaps[1].parent.as_deref(), Some("sbx-off"));
    assert_expected(&snaps, "snapshots_cirros_run.expected.json");

    // No snapshots: `snapshot-current` fails, and that is "none"
    assert_eq!(virt::parse_snapshots(&fixture("script_snapshots_none.txt")), Ok(vec![]));
}

#[test]
fn snapshot_xml_without_memory_element() {
    // libvirt < 1.0.1 had no <memory>: an active domain's snapshot held it
    let x = virt::parse_snapshot_xml(
        "<domainsnapshot><name>old</name><state>running</state>\
         <creationTime>1</creationTime></domainsnapshot>",
    )
    .unwrap();
    assert!(x.memory);
    let x = virt::parse_snapshot_xml(
        "<domainsnapshot><name>ext</name><state>disk-snapshot</state>\
         <memory snapshot='no'/><disks><disk name='vda' snapshot='external'/></disks>\
         </domainsnapshot>",
    )
    .unwrap();
    assert!(!x.memory && x.external);
    assert!(virt::parse_snapshot_xml("<domainsnapshot/>").is_err());
}

#[test]
fn snapshot_actions() {
    let s = virt::snapshot_create_script("it's", "snap-1", Some("two\nlines"));
    assert!(
        s.contains("V snapshot-create-as --domain 'it'\\''s' --name 'snap-1' --description 'two\nlines'\n"),
        "{s}"
    );
    assert!(!virt::snapshot_create_script("d", "n", Some("  ")).contains("--description"));
    assert!(
        virt::snapshot_revert_script("d", "n", true)
            .contains("V snapshot-revert --domain 'd' --snapshotname 'n' --running\n")
    );
    assert!(virt::snapshot_delete_script("d", "-n").contains("V snapshot-delete --domain 'd' --snapshotname '-n'\n"));

    // Captured refusals: all "the host said no", with its words
    for (file, needle) in [
        ("script_snapshot_error_raw.txt", "unsupported for storage type raw"),
        ("script_snapshot_error_exists.txt", "sbx-a already exists"),
        ("script_snapshot_error_not_found.txt", "no domain snapshot with matching name"),
        ("script_snapshot_error_delete_not_found.txt", "no domain snapshot with matching name"),
    ] {
        match virt::parse_action(&fixture(file)) {
            // A name taken is told apart from the rest, with the same words.
            Err(VirtError::Command { message } | VirtError::Exists { message }) => {
                assert!(message.contains(needle), "{file}: {message}")
            }
            other => panic!("{file}: {other:?}"),
        }
    }
    assert!(matches!(
        virt::parse_action(&fixture("script_snapshot_error_exists.txt")),
        Err(VirtError::Exists { .. })
    ));
}

#[test]
fn storage_pools_volumes_and_users() {
    let st = virt::parse_storage(&fixture("script_storage.txt")).unwrap();
    let names: Vec<&str> = st.pools.iter().map(|p| p.name.as_str()).collect();
    assert_eq!(names, ["images", "sbx-iso", "sbx-off"]);
    let images = &st.pools[0];
    assert!(images.active && images.autostart);
    assert_eq!(images.pool_type.as_deref(), Some("dir"));
    assert_eq!(images.capacity, Some(20922114048));
    assert_eq!(images.target.as_deref(), Some("/var/lib/libvirt/images"));
    assert_eq!(images.volumes.as_ref().unwrap().len(), 6);
    let iso = &st.pools[1];
    assert!(iso.active && !iso.autostart);
    // A name with a space, split from its path by the header's column
    assert_eq!(
        iso.volumes.as_ref().unwrap()[0],
        virt::VirtVolumeRef {
            name: "my disk.qcow2".into(),
            path: Some("/var/lib/libvirt/sbx-iso/my disk.qcow2".into()),
        }
    );
    // Inactive: the volumes cannot be listed
    let off = &st.pools[2];
    assert!(!off.active && off.volumes.is_none());
    // Every domain's disks, shut-off ones and cdroms included
    assert_eq!(st.disks.len(), 5);
    let cdrom = st.disks.iter().find(|d| d.device == "cdrom").unwrap();
    assert_eq!(cdrom.domain, "1438b9e3-f647-47ee-8ed2-6dbc3adccd68");
    assert_eq!(cdrom.source.as_deref(), Some("/var/lib/libvirt/sbx-iso/tiny.iso"));
    assert_expected(&st, "storage.expected.json");

    let vols = virt::parse_volumes(&fixture("script_volumes_images.txt")).unwrap();
    // `gone.qcow2` was asked for and does not exist: left out
    assert_eq!(vols.len(), 6);
    let run1 = vols.iter().find(|v| v.name == "run1.qcow2").unwrap();
    assert_eq!(run1.format.as_deref(), Some("qcow2"));
    assert_eq!(run1.capacity, Some(117440512));
    assert_eq!(run1.backing.as_deref(), Some("/var/lib/libvirt/images/cirros.img"));
    let vols = virt::parse_volumes(&fixture("script_volumes_sbx_iso.txt")).unwrap();
    assert_eq!(vols[0].path.as_deref(), Some("/var/lib/libvirt/sbx-iso/my disk.qcow2"));
    assert_eq!(vols[1].format.as_deref(), Some("raw"));
    assert_expected(&vols, "volumes_sbx_iso.expected.json");
}

#[test]
fn vol_list_columns() {
    let raw = " Name                 Path\n\
               -------------------------------------------\n \
               a b  c.qcow2         /p/a b  c.qcow2\n \
               x                    /p/x\n \
               noname-path          -\n";
    let v = virt::parse_vol_list(raw);
    assert_eq!(v[0].name, "a b  c.qcow2");
    assert_eq!(v[0].path.as_deref(), Some("/p/a b  c.qcow2"));
    assert_eq!(v[1].name, "x");
    assert_eq!(v[2].path, None);
    assert!(virt::parse_vol_list("").is_empty());
}

#[test]
fn blk_and_if_lists() {
    let d = virt::parse_blklist(
        "u",
        " file   disk    vda   /var/a b.qcow2\n file   cdrom   hdc   -\n network disk sda rbd/img\n",
    );
    assert_eq!(d[0].source.as_deref(), Some("/var/a b.qcow2"));
    assert_eq!(d[1].source, None);
    assert_eq!((d[2].kind.as_str(), d[2].target.as_str()), ("network", "sda"));
    let i = virt::parse_iflist(
        "u",
        " vnet0  bridge  br 0  virtio  52:54:00:AA:00:01\n -  user  -  e1000  52:54:00:aa:00:02\n",
    );
    assert_eq!(i[0].source.as_deref(), Some("br 0"));
    assert_eq!(i[0].mac.as_deref(), Some("52:54:00:aa:00:01"));
    assert_eq!((i[1].interface.as_deref(), i[1].source.as_deref()), (None, None));
}

#[test]
fn networks_modes_ips_leases() {
    let n = virt::parse_networks(&fixture("script_networks.txt")).unwrap();
    let by = |name: &str| n.networks.iter().find(|x| x.name == name).unwrap();
    let def = by("default");
    assert!(def.active && def.autostart);
    assert_eq!((def.mode.as_str(), def.bridge.as_deref()), ("nat", Some("virbr0")));
    assert_eq!(def.ips[0].cidr, "192.168.122.1/24");
    assert_eq!(def.ips[0].dhcp_ranges, ["192.168.122.2-192.168.122.254"]);
    assert_eq!(def.connections, Some(3));
    let iso = by("sbx-isolated");
    assert_eq!(iso.mode, "isolated");
    assert_eq!(iso.ips.len(), 2);
    assert_eq!((iso.ips[1].family.as_str(), iso.ips[1].cidr.as_str()), ("ipv6", "fd00:99::1/64"));
    let br = by("sbx-bridge");
    assert!(!br.active);
    assert_eq!((br.mode.as_str(), br.bridge.as_deref()), ("bridge", Some("br-sbx")));
    // Inactive domains list their interfaces too, without a host device
    let odd: Vec<_> = n
        .ifaces
        .iter()
        .filter(|i| i.domain == "1438b9e3-f647-47ee-8ed2-6dbc3adccd68")
        .collect();
    assert_eq!(odd.len(), 2);
    assert!(odd.iter().all(|i| i.interface.is_none()));
    assert_eq!(odd[1].source.as_deref(), Some("sbx-isolated"));
    assert_eq!(n.leases.len(), 2);
    assert_eq!(n.leases[0].ip, "192.168.122.202/24");
    assert_expected(&n, "networks.expected.json");
}

#[test]
fn resource_scripts_errors() {
    let raw = format!("{}\n", script::cmd_marker(virt::KEY_MISSING));
    assert_eq!(virt::parse_storage(&raw), Err(VirtError::NotInstalled));
    assert_eq!(virt::parse_networks(&raw), Err(VirtError::NotInstalled));
    assert_eq!(virt::parse_snapshots(&raw), Err(VirtError::NotInstalled));
    assert_eq!(virt::parse_volumes(&raw), Err(VirtError::NotInstalled));
    let polkit = section(virt::KEY_POOLS, &fixture("error_polkit.txt"), 1);
    assert!(matches!(virt::parse_storage(&polkit), Err(VirtError::PermissionDenied { .. })));
    let polkit = section(virt::KEY_SNAP_LIST, &fixture("error_polkit.txt"), 1);
    assert!(matches!(virt::parse_snapshots(&polkit), Err(VirtError::PermissionDenied { .. })));
    assert!(matches!(
        virt::parse_volumes("sudo: a password is required"),
        Err(VirtError::Malformed { .. })
    ));
    // Nothing asked, nothing answered
    assert_eq!(virt::parse_volumes(""), Ok(vec![]));
}

/// A `virsh` for the resource scripts: lists with hostile names, and every
/// per-item call logged so the test can see the names arrive intact.
#[cfg(unix)]
fn resource_stub(tag: &str) -> PathBuf {
    let d = std::env::temp_dir().join(format!("sbm_virt_res_{tag}_{}", std::process::id()));
    let _ = std::fs::remove_dir_all(&d);
    std::fs::create_dir_all(&d).unwrap();
    let stub = r#"#!/bin/sh
log="$(dirname "$0")/log"
for a in "$@"; do printf '%s\n' "$a" >> "$log"; done
echo --- >> "$log"
cat >> "$(dirname "$0")/stdin"
[ "$1 $2" = "--connect qemu:///system" ] || exit 9
shift 2
[ "$1" = "-q" ] && shift
evil='it'"'"'s "odd" $(touch pwned) `touch pwned`'
case "$1" in
  pool-list|net-list|snapshot-list) printf '%s\n%s\n' plain "$evil" ;;
  list) echo 11111111-2222-4333-8444-555555555555 ;;
  pool-dumpxml) echo "<pool type='dir'><name>x</name></pool>" ;;
  vol-list) printf ' Name   Path\n----------\n v      /v\n' ;;
  net-dumpxml) echo "<network><name>x</name></network>" ;;
  snapshot-dumpxml) printf "<domainsnapshot><name>%s</name></domainsnapshot>\n" "$5" ;;
  snapshot-current) printf plain ;;
  *) : ;;
esac
"#;
    let path = d.join("virsh");
    std::fs::write(&path, stub).unwrap();
    Command::new("chmod").arg("+x").arg(&path).status().unwrap();
    d
}

#[cfg(unix)]
#[test]
fn resource_scripts_under_sh() {
    let d = resource_stub("ok");
    let path = format!("{}:/usr/bin:/bin", d.display());
    let evil = "it's \"odd\" $(touch pwned) `touch pwned`";

    let st = virt::parse_storage(&run_sh(&virt::storage_script(), &path)).unwrap();
    assert_eq!(st.pools.len(), 2);
    assert_eq!(st.pools[1].name, evil);
    assert_eq!(st.pools[1].volumes.as_ref().unwrap()[0].name, "v");
    let n = virt::parse_networks(&run_sh(&virt::networks_script(), &path)).unwrap();
    assert_eq!(n.networks[1].name, evil);
    let s = virt::parse_snapshots(&run_sh(&virt::snapshots_script(evil), &path)).unwrap();
    assert_eq!(s.iter().map(|s| s.name.as_str()).collect::<Vec<_>>(), ["plain", evil]);
    assert!(s[0].current);
    let v = run_sh(&virt::volumes_script(evil, &[evil.to_string()]), &path);
    assert_eq!(virt::parse_volumes(&v), Ok(vec![]));

    let log = std::fs::read_to_string(d.join("log")).unwrap();
    // Each loop hands the name over as one argument, untouched
    assert!(log.contains(&format!("pool-dumpxml\n--pool\n{evil}\n---\n")), "{log}");
    assert!(log.contains(&format!("vol-list\n--pool\n{evil}\n---\n")), "{log}");
    assert!(log.contains(&format!("net-dumpxml\n--network\n{evil}\n---\n")), "{log}");
    assert!(log.contains(&format!("--domain\n{evil}\n--snapshotname\n{evil}\n---\n")), "{log}");
    assert!(log.contains(&format!("vol-dumpxml\n--pool\n{evil}\n--vol\n{evil}\n---\n")), "{log}");
    assert!(log.contains("domblklist\n--details\n--domain\n11111111-2222-4333-8444-555555555555\n"));
    assert!(!d.join("pwned").exists() && !std::path::Path::new("pwned").exists());
    assert_eq!(std::fs::read_to_string(d.join("stdin")).unwrap(), "");
    let _ = std::fs::remove_dir_all(&d);
}

#[cfg(unix)]
#[test]
fn probe_finds_pve_and_containers() {
    let d = std::env::temp_dir().join(format!("sbm_virt_probe_{}", std::process::id()));
    let _ = std::fs::remove_dir_all(&d);
    std::fs::create_dir_all(&d).unwrap();
    let stub = |name: &str, body: &str| {
        use std::os::unix::fs::PermissionsExt;
        let p = d.join(name);
        std::fs::write(&p, format!("#!/bin/sh\n{body}\n")).unwrap();
        std::fs::set_permissions(&p, std::fs::Permissions::from_mode(0o755)).unwrap();
    };
    let path = format!("{}:/usr/bin:/bin", d.display());

    // Alpine in a PVE container: no systemd, `openrc --sys` says LXC. A
    // hypervisor name before it is not a container.
    stub("systemd-detect-virt", "echo none; exit 1");
    stub("openrc", "echo LXC");
    let p = virt::parse_probe(&run_sh(&virt::probe_script(), &path)).unwrap();
    assert_eq!(p.container.as_deref(), Some("lxc"));
    assert_eq!((p.pve, p.libvirt), (None, None));

    // PVE: its line, and nothing else asked (the virsh stub is not run)
    stub(
        "pveversion",
        "echo 'pve-manager/9.2.2/b9984c6d90a4bd80 (running kernel: 7.0.2-6-pve)'",
    );
    stub("virsh", "touch \"$0.ran\"; echo 'Using library: libvirt 11.3.0'");
    let p = virt::parse_probe(&run_sh(&virt::probe_script(), &path)).unwrap();
    assert_eq!(
        p.pve.as_deref(),
        Some("pve-manager/9.2.2/b9984c6d90a4bd80 (running kernel: 7.0.2-6-pve)")
    );
    assert_eq!((p.container, p.libvirt), (None, None));
    assert!(!d.join("virsh.ran").exists());
    let _ = std::fs::remove_dir_all(&d);
}

// ---------------------------------------------------------------------------
// Creating and deleting domains
// ---------------------------------------------------------------------------

fn create_spec(name: &str) -> virt::VirtCreateSpec {
    virt::VirtCreateSpec {
        name: name.to_string(),
        vcpus: 2,
        memory_mib: 1024,
        host: virt::parse_create_host(&fixture("script_create_host.txt")).unwrap(),
        disk_pool: "images".to_string(),
        disk_gib: 8,
        disk_format: "qcow2".to_string(),
        disk_path: Some(format!("/var/lib/libvirt/images/{name}.qcow2")),
        cdrom: Some("/var/lib/libvirt/images/sbm-test.iso".to_string()),
        network: Some("default".to_string()),
        start: true,
        ..Default::default()
    }
}

#[test]
fn create_host_prefers_kvm_and_q35() {
    let host = virt::parse_create_host(&fixture("script_create_host.txt")).unwrap();
    assert_eq!(
        (host.domain_type.as_str(), host.machine.as_str(), host.arch.as_str(), host.max_vcpus),
        ("kvm", "pc-q35-10.0", "x86_64", Some(4096))
    );
    // Captured before the seed tool was asked for, and trimmed: none.
    assert_eq!(host.seed_tool, None);
    // The whole answer (2026-09-26, with the seed tool): what the machine
    // offers besides, from the same `domcapabilities` — UEFI with Secure
    // Boot, no IDE on q35, a TPM only by passthrough (no swtpm there).
    let full = virt::parse_create_host(&fixture("script_create_host_full.txt")).unwrap();
    assert_eq!(full.machine, "pc-q35-10.0");
    assert_eq!(full.seed_tool.as_deref(), Some("genisoimage"));
    let caps = full.caps.unwrap();
    assert!(caps.efi && caps.secure_boot && !caps.tpm_emulator, "{caps:?}");
    assert_eq!(caps.disk_buses, ["fdc", "scsi", "virtio", "usb", "sata"]);
    // A host without KVM: the first sections fail, emulation answers.
    let raw = fixture("script_create_host.txt");
    let no_kvm = raw.replacen(
        "kvm\n<domainCapabilities>",
        "kvm\nerror: unsupported configuration: KVM is not supported\n<!--",
        2,
    );
    let no_kvm = no_kvm.replacen("</domainCapabilities>\n\nSbVirtRc=0", "-->\nSbVirtRc=1", 2);
    let host = virt::parse_create_host(&no_kvm).unwrap();
    assert_eq!((host.domain_type.as_str(), host.machine.as_str()), ("qemu", "pc-q35-10.0"));
}

#[test]
fn create_volume_and_define_captured() {
    assert_eq!(
        virt::parse_create_volumes(&fixture("script_create_volume.txt")).unwrap(),
        virt::VirtCreateVolumes {
            disk_path: "/var/lib/libvirt/images/sbm-create-test.qcow2".into(),
            seed_path: None,
            copied_bytes: None,
        }
    );
    // The name was defined already: nothing ran.
    assert_eq!(
        virt::parse_create_volumes(&fixture("script_create_volume_exists.txt")),
        Err(VirtError::Exists { message: String::new() })
    );
    assert_eq!(
        virt::parse_create(&fixture("script_define_ok.txt")).unwrap(),
        virt::VirtCreated {
            uuid: Some("be27edda-481c-401d-88df-57e7b8756364".into()),
            start_error: None,
        }
    );
    // Refused by the host, and the volume taken back (its section is ok).
    match virt::parse_create(&fixture("script_define_rollback.txt")) {
        Err(VirtError::Command { message }) => {
            assert!(message.contains("No PCI buses available"), "{message}");
        }
        other => panic!("{other:?}"),
    }
    assert_eq!(virt::parse_action(&fixture("script_undefine.txt")), Ok(()));
    assert_eq!(virt::parse_undefine(&fixture("script_undefine.txt")), Ok(()));
}

#[test]
fn create_start_failure_and_leftover_volume() {
    let m = script::cmd_marker;
    let ok = |key: &str, body: &str| format!("{}\n{body}\n{}0\n", m(key), virt::RC_PREFIX);
    let fail = |key: &str, body: &str| format!("{}\n{body}\n{}1\n", m(key), virt::RC_PREFIX);
    // Defined, then refused to start: created all the same, with why.
    let raw = [
        ok(virt::KEY_DEFINE, ""),
        ok(virt::KEY_UUID, "be27edda-481c-401d-88df-57e7b8756364"),
        fail(virt::KEY_START, "error: Failed to start domain 'x'\nerror: Permission denied"),
    ]
    .concat();
    let created = virt::parse_create(&raw).unwrap();
    assert_eq!(
        created.start_error.as_deref(),
        Some("Failed to start domain 'x'\nPermission denied")
    );
    // Define refused and the volume could not be removed: both said.
    let raw = [
        fail(virt::KEY_DEFINE, "error: XML error: bad"),
        fail(virt::KEY_ROLLBACK, "error: Failed to delete vol x.qcow2"),
    ]
    .concat();
    match virt::parse_create(&raw) {
        Err(VirtError::Command { message }) => {
            assert_eq!(message, "XML error: bad\nFailed to delete vol x.qcow2");
        }
        other => panic!("{other:?}"),
    }
    // Refused as this user: kept as such, so the caller retries with sudo.
    let raw = [
        fail(virt::KEY_DEFINE, "error: Permission denied"),
        fail(virt::KEY_ROLLBACK, "error: Permission denied"),
    ]
    .concat();
    assert!(matches!(
        virt::parse_create(&raw),
        Err(VirtError::PermissionDenied { .. })
    ));
}

#[test]
fn domain_xml_escapes_and_reads_back() {
    let spec = create_spec("it's \"odd\" <b>&amp;");
    let xml = virt::domain_xml(&spec);
    let back = virt::parse_domain_xml(&xml).unwrap();
    assert_eq!(back.name.as_deref(), Some(spec.name.as_str()));
    assert_eq!(back.machine.as_deref(), Some("pc-q35-10.0"));
    assert!(back.has_serial_console);
    assert_eq!(back.disks.len(), 2);
    assert_eq!(back.disks[0].source, spec.disk_path);
    assert_eq!(back.disks[0].target.as_deref(), Some("vda"));
    assert_eq!(back.disks[1].device, "cdrom");
    assert!(back.disks[1].readonly);
    assert_eq!(back.disks[1].bus.as_deref(), Some("sata"));
    assert_eq!(back.nics[0].source.as_deref(), Some("default"));
    assert_eq!(back.graphics[0].listen.as_deref(), Some("127.0.0.1"));

    // `pc` has no SATA; no media, no NIC.
    let mut spec = create_spec("plain");
    spec.host.machine = "pc-i440fx-10.0".into();
    spec.network = None;
    let back = virt::parse_domain_xml(&virt::domain_xml(&spec)).unwrap();
    assert_eq!(back.disks[1].bus.as_deref(), Some("ide"));
    assert!(back.nics.is_empty());
    spec.cdrom = None;
    assert_eq!(virt::parse_domain_xml(&virt::domain_xml(&spec)).unwrap().disks.len(), 1);
}

#[test]
fn create_specs_refused_before_running() {
    let bad = |f: &dyn Fn(&mut virt::VirtCreateSpec)| {
        let mut spec = create_spec("vm");
        f(&mut spec);
        assert!(
            matches!(virt::create_volume_script(&spec), Err(VirtError::Malformed { .. })),
            "{spec:?}"
        );
    };
    bad(&|s| s.name = String::new());
    bad(&|s| s.name = "a/b".into());
    bad(&|s| s.name = "a\nb".into());
    bad(&|s| s.name = "-rf".into());
    bad(&|s| s.name = ".hidden".into());
    bad(&|s| s.vcpus = 0);
    bad(&|s| s.disk_gib = 0);
    bad(&|s| s.disk_format = "vmdk".into());
    bad(&|s| s.host.domain_type = "xen".into());
    bad(&|s| s.host.machine = "q35'; rm".into());
    bad(&|s| s.disk_path = Some("relative.qcow2".into()));
    let mut spec = create_spec("vm");
    spec.disk_path = None;
    assert!(virt::create_volume_script(&spec).is_ok());
    assert!(matches!(virt::define_script(&spec), Err(VirtError::Malformed { .. })));

    assert!(virt::undefine_script("vm", &["vda,sda".into()], None).is_err());
    assert!(virt::undefine_script("vm", &["".into()], None).is_err());
    assert!(virt::undefine_script("vm", &[], Some("seed.iso")).is_err());
    let keep = virt::undefine_script("vm", &[], None).unwrap();
    assert!(keep.contains("--keep-nvram") && !keep.contains("--storage"), "{keep}");
    assert!(!keep.contains("vol-delete"), "{keep}");
    let all = virt::undefine_script("vm", &["vda".into(), "vdb".into()], None).unwrap();
    assert!(all.contains("--nvram --storage vda,vdb"), "{all}");
}

/// A fake virsh for the create scripts: logs its arguments one per line,
/// keeps what `define --file` was given, and knows a domain once defined.
#[cfg(unix)]
fn create_stub(tag: &str) -> PathBuf {
    let d = std::env::temp_dir().join(format!("sbm_virt_create_{tag}_{}", std::process::id()));
    let _ = std::fs::remove_dir_all(&d);
    std::fs::create_dir_all(&d).unwrap();
    let stub = r#"#!/bin/sh
dir="$(dirname "$0")"
for a in "$@"; do printf '%s\n' "$a" >> "$dir/log"; done
echo --- >> "$dir/log"
cat >> "$dir/stdin"
shift 3
case "$1" in
  domuuid) [ -f "$dir/defined.xml" ] || { echo "error: failed to get domain" >&2; exit 1; }
           echo be27edda-481c-401d-88df-57e7b8756364 ;;
  vol-create-as) ;;
  vol-path) echo "/pool/$5" ;;
  define) cp "$3" "$dir/defined.xml" ;;
  start|vol-delete|undefine) ;;
  *) echo "error: unexpected $*" >&2; exit 1 ;;
esac
"#;
    let path = d.join("virsh");
    std::fs::write(&path, stub).unwrap();
    Command::new("chmod").arg("+x").arg(&path).status().unwrap();
    d
}

#[cfg(unix)]
#[test]
fn create_scripts_under_sh_with_a_hostile_name() {
    let d = create_stub("hostile");
    let path = format!("{}:/usr/bin:/bin", d.display());
    let name = "it's \"odd\"; touch pwned $(id) `id`";
    let mut spec = create_spec(name);
    spec.disk_path = None;

    let vol = virt::parse_create_volumes(&run_sh(&virt::create_volume_script(&spec).unwrap(), &path))
        .unwrap()
        .disk_path;
    assert_eq!(vol, format!("/pool/{name}.qcow2"));
    let log = std::fs::read_to_string(d.join("log")).unwrap();
    assert!(log.contains(&format!("--name\n{name}.qcow2\n--capacity\n8G\n")), "{log}");

    spec.disk_path = Some(vol);
    let created = virt::parse_create(&run_sh(&virt::define_script(&spec).unwrap(), &path)).unwrap();
    assert_eq!(created.uuid.as_deref(), Some("be27edda-481c-401d-88df-57e7b8756364"));
    assert_eq!(created.start_error, None);
    // The file virsh was given is the XML, byte for byte.
    assert_eq!(
        std::fs::read_to_string(d.join("defined.xml")).unwrap(),
        virt::domain_xml(&spec)
    );
    let log = std::fs::read_to_string(d.join("log")).unwrap();
    assert!(log.contains(&format!("start\n--domain\n{name}\n")), "{log}");
    assert!(!d.join("pwned").exists() && !std::path::Path::new("pwned").exists());
    assert_eq!(std::fs::read_to_string(d.join("stdin")).unwrap(), "");

    // Defined already: stops before creating anything.
    std::fs::remove_file(d.join("log")).unwrap();
    assert_eq!(
        virt::parse_create_volumes(&run_sh(&virt::create_volume_script(&spec).unwrap(), &path)),
        Err(VirtError::Exists { message: String::new() })
    );
    let log = std::fs::read_to_string(d.join("log")).unwrap();
    assert!(!log.contains("vol-create-as"), "{log}");

    let undefine = virt::undefine_script(name, &["vda".into()], None).unwrap();
    assert_eq!(virt::parse_undefine(&run_sh(&undefine, &path)), Ok(()));
    let log = std::fs::read_to_string(d.join("log")).unwrap();
    assert!(log.contains(&format!("undefine\n--domain\n{name}\n--managed-save\n")), "{log}");
    let _ = std::fs::remove_dir_all(&d);
}

// ---------------------------------------------------------------------------
// VNC console: display and password
// ---------------------------------------------------------------------------

/// Captured from libvirt 11.3 for a throwaway domain whose VNC password is a
/// made-up one, `fakepw12`.
#[test]
fn vnc_console_password_from_a_secure_dump() {
    let info = virt::parse_vnc_console(&fixture("script_vnc_console_password.txt")).unwrap();
    let display = info.display.clone().unwrap();
    assert_eq!(display.protocol, "vnc");
    assert_eq!(display.port, Some(5901));
    assert_eq!(info.password.as_deref(), Some("fakepw12"));
    assert!(info.password_known);
    // Debug output is what reaches a log or a failed assertion.
    assert!(!format!("{info:?}").contains("fakepw12"));
}

#[test]
fn vnc_console_without_a_password_or_refused_one() {
    // No `passwd`: known to have none.
    let open = fixture("script_vnc_console_password.txt").replace(" passwd='fakepw12'", "");
    let info = virt::parse_vnc_console(&open).unwrap();
    assert_eq!(info.password, None);
    assert!(info.password_known);

    // `--security-info` refused (the text libvirt 11.3 prints on a read-only
    // connection): the display is still there, the password unknown.
    let raw = fixture("script_vnc_console_password.txt");
    let marker = format!("{}\n", sbm_parser::script::cmd_marker(virt::KEY_SECURE_XML));
    let head = &raw[..raw.find(&marker).unwrap() + marker.len()];
    let refused = format!(
        "{head}error: operation forbidden: virDomainGetXMLDesc with secure flag\n\n{}1\n",
        virt::RC_PREFIX
    );
    let info = virt::parse_vnc_console(&refused).unwrap();
    assert_eq!(info.display.and_then(|d| d.port), Some(5901));
    assert_eq!(info.password, None);
    assert!(!info.password_known);

    // A secure dump that does not parse is an error without its text.
    let broken = raw.replace("<domain ", "<domain <");
    match virt::parse_vnc_console(&broken) {
        Err(VirtError::Malformed { message }) => {
            assert!(!message.contains("fakepw12"), "{message}");
            assert!(!message.contains("<devices"), "{message}");
        }
        other => panic!("{other:?}"),
    }
}

// ---------------------------------------------------------------------------
// Hardware: reading and editing
// ---------------------------------------------------------------------------

/// Captured from libvirt 11.3 for a throwaway domain, running with a vCPU
/// hot-plugged and the balloon moved, so the two definitions differ.
#[test]
fn hardware_running_has_both_definitions() {
    let hw = virt::parse_hardware(&fixture("script_hardware_running.txt")).unwrap();
    let config = &hw.config;
    let live = hw.live.as_ref().expect("running");
    assert_eq!((config.cpu.max, config.cpu.current), (4, 2));
    assert_eq!((live.cpu.max, live.cpu.current), (4, 3));
    // No topology: one socket per vCPU, as libvirt gives the guest.
    assert_eq!((config.cpu.sockets, config.cpu.cores, config.cpu.topology), (4, 1, false));
    assert_eq!(config.memory_kib, 512 * 1024);
    assert_eq!(config.current_memory_kib, 384 * 1024);
    assert!(config.balloon);
    let vda = &config.disks[0];
    assert_eq!((vda.target.as_str(), vda.device.as_str()), ("vda", "disk"));
    assert_eq!(vda.capacity, Some(117_440_512));
    // An empty CD-ROM: listed, with no source and no size.
    let cd = &config.disks[1];
    assert_eq!((cd.target.as_str(), cd.device.as_str(), cd.source.as_deref(), cd.capacity), ("hdc", "cdrom", None, None));
    assert!(cd.readonly);
    let nic = &config.nics[0];
    assert_eq!((nic.mac.as_str(), nic.kind.as_str(), nic.source.as_deref()), ("52:54:00:b9:34:c3", "network", Some("default")));
    assert!(nic.link_up);
    // `<os><boot dev='hd'/>` is the first disk.
    assert_eq!(config.boot, vec!["vda"]);
    assert!(!hw.autostart);
    assert_eq!((hw.host_cpus, hw.host_memory_kib), (Some(4), Some(4_016_000)));
    assert!(hw.config_xml.starts_with("<domain type='kvm'>"), "{}", &hw.config_xml[..40]);
}

#[test]
fn hardware_stopped_has_no_running_definition() {
    let hw = virt::parse_hardware(&fixture("script_hardware_stopped.txt")).unwrap();
    assert!(hw.live.is_none());
    assert_eq!(hw.config.disks[0].capacity, Some(117_440_512));
    assert_eq!(hw.description, None);

    // The persistent definition's note, as `virsh desc` wrote it: escaped
    // in the XML, read back as typed.
    let raw = fixture("script_hardware_stopped.txt").replacen(
        "<name>it&apos;s-&quot;odd&quot;</name>",
        "<name>it&apos;s-&quot;odd&quot;</name>\n  <description>web &amp; &lt;db&gt;\nsecond</description>",
        1,
    );
    assert_eq!(virt::parse_hardware(&raw).unwrap().description.as_deref(), Some("web & <db>\nsecond"));
}

fn base_xml() -> String {
    virt::parse_hardware(&fixture("script_hardware_running.txt")).unwrap().config_xml
}

fn hw_of(xml: &str) -> virt::VirtHwConfig {
    virt::parse_hw_xml(xml, &[]).unwrap()
}

#[test]
fn cpu_edits_keep_the_rest_as_written() {
    let base = base_xml();
    // One socket of four cores, two online: a topology added inside the
    // self-closing `<cpu mode='host-passthrough' …/>`, which keeps its mode.
    let xml = virt::edit_cpu_xml(&base, 1, 4, Some(2)).unwrap();
    let cpu = hw_of(&xml).cpu;
    assert_eq!((cpu.sockets, cpu.cores, cpu.threads, cpu.max, cpu.current), (1, 4, 1, 4, 2));
    assert!(xml.contains("<cpu mode='host-passthrough' check='none' migratable='on'><topology sockets='1' cores='4' threads='1'/></cpu>"), "{xml}");
    assert!(xml.contains("<vcpu placement='static' current='2'>4</vcpu>"), "{xml}");
    // Everything else is byte for byte what it was.
    let strip = |s: &str| {
        s.lines()
            .filter(|l| !l.contains("<vcpu") && !l.contains("<cpu"))
            .collect::<Vec<_>>()
            .join("\n")
    };
    assert_eq!(strip(&xml), strip(&base));

    // An existing topology is edited in place, dies and threads kept, and
    // the maximum follows it; all online drops `current`.
    let xml = virt::edit_cpu_xml(&xml.replace("threads='1'", "threads='2' dies='1'"), 2, 3, None).unwrap();
    let cpu = hw_of(&xml).cpu;
    assert_eq!((cpu.sockets, cpu.cores, cpu.threads, cpu.max, cpu.current), (2, 3, 2, 12, 12));
    assert!(xml.contains("<vcpu placement='static'>12</vcpu>"), "{xml}");

    // The default shape needs no topology: none is added.
    let xml = virt::edit_cpu_xml(&base, 6, 1, None).unwrap();
    assert!(!xml.contains("<topology"), "{xml}");
    assert_eq!(hw_of(&xml).cpu.max, 6);

    // No `<cpu>` at all: one is added after `<vcpu>`.
    let bare = base.replace("<cpu mode='host-passthrough' check='none' migratable='on'/>", "");
    let xml = virt::edit_cpu_xml(&bare, 2, 2, None).unwrap();
    assert!(xml.contains("<vcpu placement='static'>4</vcpu>\n  <cpu><topology sockets='2' cores='2' threads='1'/></cpu>"), "{xml}");

    // A per-vCPU list names every vCPU: it goes when the maximum changes.
    let listed = base.replace(
        "</vcpu>",
        "</vcpu>\n  <vcpus><vcpu id='0' enabled='yes' hotpluggable='no'/></vcpus>",
    );
    assert!(virt::edit_cpu_xml(&listed, 4, 1, Some(2)).unwrap().contains("<vcpus>"));
    assert!(!virt::edit_cpu_xml(&listed, 8, 1, None).unwrap().contains("<vcpus>"));

    // Online more than there are, or a topology past what QEMU takes.
    assert!(virt::edit_cpu_xml(&base, 1, 2, Some(3)).is_err());
    assert!(virt::edit_cpu_xml(&base, 64, 128, None).is_err());
}

#[test]
fn boot_edits_move_to_per_device_order() {
    let base = base_xml();
    let xml = virt::edit_boot_xml(&base, &["hdc".into(), "vda".into(), "52:54:00:B9:34:C3".into()]).unwrap();
    assert!(!xml.contains("<boot dev="), "{xml}");
    let hw = hw_of(&xml);
    assert_eq!(hw.boot, vec!["hdc", "vda", "52:54:00:b9:34:c3"]);
    assert_eq!(hw.disks.iter().map(|d| d.boot_order).collect::<Vec<_>>(), vec![Some(2), Some(1)]);

    // Again, from a definition that already has orders: none are left over.
    let again = virt::edit_boot_xml(&xml, &["vda".into()]).unwrap();
    assert_eq!(hw_of(&again).boot, vec!["vda"]);
    assert_eq!(again.matches("<boot ").count(), 1, "{again}");

    assert!(virt::edit_boot_xml(&base, &["vdz".into()]).is_err());
    assert!(virt::edit_boot_xml(&base, &["vda".into(), "vda".into()]).is_err());
}

/// Every change, captured from libvirt 11.3 on a throwaway running domain.
#[test]
fn hardware_changes_as_captured() {
    for name in [
        "cpu",
        "cpu_stopped",
        "memory",
        "add_disk",
        "grow_disk",
        "grow_disk_stopped",
        "remove_disk",
        "set_media",
        "add_nic",
        "update_nic",
        "update_nic_with_boot",
        "boot",
        "remove_nic",
        "autostart",
    ] {
        let out = virt::parse_hardware_change(&fixture(&format!("script_hw_{name}.txt")));
        assert_eq!(out, Ok(virt::VirtHwOutcome::default()), "{name}");
    }
    // An IDE disk: the definition takes it, the running domain cannot.
    let out = virt::parse_hardware_change(&fixture("script_hw_add_disk_ide_live_refused.txt")).unwrap();
    assert!(out.live_error.unwrap().contains("cannot be hotplugged"));
    // …and cannot let it go either: the volume is kept, not deleted.
    let out = virt::parse_hardware_change(&fixture("script_hw_remove_disk_kept.txt")).unwrap();
    assert!(out.volume_kept);
    assert!(out.live_error.unwrap().contains("cannot be hot unplugged"));

    assert!(matches!(
        virt::parse_hardware_change(&fixture("script_hw_add_disk_exists.txt")),
        Err(VirtError::Exists { .. })
    ));
    assert!(matches!(
        virt::parse_hardware_change(&fixture("script_hw_conflict.txt")),
        Err(VirtError::Conflict { .. })
    ));
    // The definition could not be read (no sudo yet): that, not a conflict.
    assert!(matches!(
        virt::parse_hardware_change(&fixture("script_hw_guard_refused.txt")),
        Err(VirtError::PermissionDenied { .. })
    ));
}

#[test]
fn hardware_changes_refuse_what_must_not_reach_a_shell() {
    use virt::VirtHwChange as C;
    let script = |c: &C| virt::hardware_change_script("vm", true, Some(&base_xml()), c);
    assert!(script(&C::GrowDisk { target: "vda; rm".into(), bytes: 1, path: None, live: true }).is_err());
    assert!(script(&C::GrowDisk { target: "vda".into(), bytes: 1, path: Some("rel".into()), live: false }).is_err());
    assert!(script(&C::AddNic {
        kind: "direct".into(),
        source: "eth0".into(),
        model: "virtio".into(),
        mac: "52:54:00:00:00:01".into(),
    })
    .is_err());
    assert!(script(&C::AddNic {
        kind: "network".into(),
        source: "default".into(),
        model: "virtio".into(),
        mac: "52:54:00:00:00".into(),
    })
    .is_err());
    assert!(script(&C::AddDisk {
        pool: "images".into(),
        volume: "../etc".into(),
        gib: 1,
        format: "qcow2".into(),
        target: "vdb".into(),
        bus: "virtio".into(),
    })
    .is_err());
    assert!(script(&C::Memory { memory_mib: 512, current_mib: Some(1024) }).is_err());
    assert!(script(&C::Boot { order: vec![] }).is_err());
    // Rewriting the definition needs the one it is made from.
    assert!(virt::hardware_change_script("vm", false, None, &C::Cpu { sockets: 1, cores: 1, current: None }).is_err());
    // A stopped domain's disk grows by its file, and so does one only the
    // persistent definition has.
    assert!(virt::hardware_change_script(
        "vm",
        true,
        None,
        &C::GrowDisk { target: "vdb".into(), bytes: 1, path: None, live: false }
    )
    .is_err());
    assert!(virt::hardware_change_script(
        "vm",
        false,
        None,
        &C::GrowDisk { target: "vda".into(), bytes: 1, path: None, live: false }
    )
    .is_err());
}

/// A `virsh` for the change scripts: logs its arguments, keeps the files it
/// is given, prints `base.xml` for `dumpxml --inactive`, fails what the test
/// asks it to.
#[cfg(unix)]
fn hardware_stub(tag: &str, base: &str) -> PathBuf {
    let d = std::env::temp_dir().join(format!("sbm_virt_hw_{tag}_{}", std::process::id()));
    let _ = std::fs::remove_dir_all(&d);
    std::fs::create_dir_all(&d).unwrap();
    std::fs::write(d.join("base.xml"), base).unwrap();
    let stub = r#"#!/bin/sh
dir="$(dirname "$0")"
for a in "$@"; do printf '%s\n' "$a" >> "$dir/log"; done
echo --- >> "$dir/log"
cat >> "$dir/stdin"
shift 3
[ -f "$dir/fail_$1" ] && { echo "error: $1 refused" >&2; exit 1; }
case "$1" in
  dumpxml) cat "$dir/base.xml" ;;
  define) cp "$3" "$dir/given_define.xml" ;;
  update-device) cp "$5" "$dir/given_update-device.xml" ;;
  vol-path) echo "/pool/$5" ;;
  domblklist) [ -f "$dir/still" ] && echo " vdb /pool/x" ;;
  *) ;;
esac
"#;
    let path = d.join("virsh");
    std::fs::write(&path, stub).unwrap();
    Command::new("chmod").arg("+x").arg(&path).status().unwrap();
    d
}

#[cfg(unix)]
#[test]
fn hardware_change_scripts_under_sh_with_hostile_names() {
    use virt::VirtHwChange as C;
    let name = "it's \"odd\"; touch pwned $(id) `id`";
    let base = base_xml();
    let d = hardware_stub("hostile", &base);
    let path = format!("{}:/usr/bin:/bin", d.display());
    let log = || std::fs::read_to_string(d.join("log")).unwrap_or_default();
    let reset = || {
        let _ = std::fs::remove_file(d.join("log"));
    };
    let run = |running: bool, c: &C| {
        let script = virt::hardware_change_script(name, running, Some(&base), c).unwrap();
        virt::parse_hardware_change(&run_sh(&script, &path))
    };

    // The definition given to `define` is the edit, byte for byte, made
    // only once the one on the host is still the one it was made from.
    reset();
    assert_eq!(run(true, &C::Cpu { sockets: 1, cores: 4, current: Some(2) }), Ok(Default::default()));
    assert_eq!(
        std::fs::read_to_string(d.join("given_define.xml")).unwrap(),
        virt::edit_cpu_xml(&base, 1, 4, Some(2)).unwrap()
    );
    assert!(log().contains(&format!("dumpxml\n--inactive\n--domain\n{name}\n")), "{}", log());
    assert!(log().contains(&format!("setvcpus\n--domain\n{name}\n--count\n2\n--live\n")), "{}", log());
    // …and it is not, when it changed.
    std::fs::write(d.join("base.xml"), base.replace("<on_crash>destroy", "<on_crash>restart")).unwrap();
    reset();
    assert!(matches!(run(true, &C::Boot { order: vec!["vda".into()] }), Err(VirtError::Conflict { .. })));
    assert!(!log().contains("define"), "{}", log());
    std::fs::write(d.join("base.xml"), &base).unwrap();

    // A path with every quote in it reaches virsh as one argument.
    let file = format!("/pool/{name}.iso");
    reset();
    let media = C::SetMedia { target: "hdc".into(), source: Some(file.clone()), config: true, live: true };
    assert_eq!(run(true, &media), Ok(Default::default()));
    assert!(log().contains(&format!("--source\n{file}\n--update\n--config\n")), "{}", log());
    assert!(log().contains(&format!("--source\n{file}\n--update\n--live\n")), "{}", log());

    // The running domain refusing its half is not a failure of the change.
    std::fs::write(d.join("fail_change-media"), "").unwrap();
    let only_live = C::SetMedia { target: "hdc".into(), source: None, config: false, live: true };
    assert_eq!(
        run(true, &only_live).unwrap().live_error.as_deref(),
        Some("change-media refused")
    );
    std::fs::remove_file(d.join("fail_change-media")).unwrap();

    // A disk the definition refuses is deleted again; a new one is attached
    // by the path the pool gave.
    let add = C::AddDisk {
        pool: name.into(),
        volume: "vm-vdb.qcow2".into(),
        gib: 2,
        format: "qcow2".into(),
        target: "vdb".into(),
        bus: "virtio".into(),
    };
    reset();
    assert_eq!(run(true, &add), Ok(Default::default()));
    assert!(log().contains("--source\n/pool/vm-vdb.qcow2\n--target\nvdb\n"), "{}", log());
    std::fs::write(d.join("fail_attach-disk"), "").unwrap();
    reset();
    assert!(run(true, &add).is_err());
    assert!(log().contains(&format!("vol-delete\n--pool\n{name}\n--vol\nvm-vdb.qcow2\n")), "{}", log());
    std::fs::remove_file(d.join("fail_attach-disk")).unwrap();

    // An existing volume is attached by its path in both definitions, and
    // left alone when the attach is refused: it is not this change's to
    // delete.
    let attach = C::AttachVolume {
        path: file.clone(),
        format: "raw".into(),
        target: "vdc".into(),
        bus: "virtio".into(),
    };
    reset();
    assert_eq!(run(true, &attach), Ok(Default::default()));
    assert!(log().contains(&format!("attach-disk\n--domain\n{name}\n--source\n{file}\n--target\nvdc\n--targetbus\nvirtio\n--driver\nqemu\n--subdriver\nraw\n--config\n")), "{}", log());
    assert!(log().contains("--subdriver\nraw\n--live\n"), "{}", log());
    std::fs::write(d.join("fail_attach-disk"), "").unwrap();
    reset();
    assert!(run(false, &attach).is_err());
    assert!(!log().contains("vol-delete") && !log().contains("--live"), "{}", log());
    std::fs::remove_file(d.join("fail_attach-disk")).unwrap();
    assert!(virt::hardware_change_script(
        "vm",
        true,
        None,
        &C::AttachVolume { path: "rel/x".into(), format: "raw".into(), target: "vdc".into(), bus: "virtio".into() }
    )
    .is_err());

    // A disk the running guest still holds is kept.
    let remove = C::RemoveDisk { target: "vdb".into(), delete_path: Some(file.clone()), config: true, live: true };
    std::fs::write(d.join("still"), "").unwrap();
    reset();
    assert!(run(true, &remove).unwrap().volume_kept);
    assert!(!log().contains("vol-delete"), "{}", log());
    std::fs::remove_file(d.join("still")).unwrap();
    reset();
    assert!(!run(true, &remove).unwrap().volume_kept);
    assert!(log().contains(&format!("vol-delete\n--vol\n{file}\n")), "{}", log());

    // An interface's source with quotes lands in the XML escaped, with the
    // link state and each definition's own boot order.
    reset();
    let update = C::UpdateNic {
        mac: "52:54:00:b9:34:c3".into(),
        kind: "network".into(),
        source: name.into(),
        model: Some("virtio".into()),
        link_up: false,
        boot_order: Some(2),
        live_boot_order: None,
        config: true,
        live: false,
    };
    assert_eq!(run(true, &update), Ok(Default::default()));
    assert_eq!(
        std::fs::read_to_string(d.join("given_update-device.xml")).unwrap(),
        "<interface type='network'><mac address='52:54:00:b9:34:c3'/>\
         <source network='it&apos;s &quot;odd&quot;; touch pwned $(id) `id`'/>\
         <model type='virtio'/><link state='down'/><boot order='2'/></interface>"
    );

    // A note with every quote and a leading dash reaches `desc` as one
    // argument, to both definitions of a running domain; a rename is one
    // step with the new name.
    let note = format!("-{name}\nsecond line");
    reset();
    assert_eq!(run(true, &C::Description { text: note.clone() }), Ok(Default::default()));
    assert!(log().contains(&format!("desc\n--domain\n{name}\n--config\n--new-desc\n-{name}\nsecond line\n")), "{}", log());
    assert!(log().contains(&format!("desc\n--domain\n{name}\n--live\n--new-desc\n")), "{}", log());
    reset();
    assert_eq!(run(false, &C::Description { text: String::new() }), Ok(Default::default()));
    assert!(!log().contains("--live"), "{}", log());
    reset();
    assert_eq!(run(false, &C::Rename { name: "web-02".into() }), Ok(Default::default()));
    assert!(log().contains(&format!("domrename\n--domain\n{name}\nweb-02\n")), "{}", log());
    // A name libvirt or AppArmor would trip over is refused before a shell.
    for bad in [name, "-x", ".hidden", "a b", ""] {
        assert!(virt::hardware_change_script(name, false, None, &C::Rename { name: bad.into() }).is_err(), "{bad}");
    }
    assert!(virt::hardware_change_script(name, false, None, &C::Description { text: "a\u{0}b".into() }).is_err());

    assert!(!d.join("pwned").exists() && !std::path::Path::new("pwned").exists());
    assert_eq!(std::fs::read_to_string(d.join("stdin")).unwrap_or_default(), "");
    let _ = std::fs::remove_dir_all(&d);
}

// ---------------------------------------------------------------------------
// Hardware, second part: disk bus and cache, NIC model and MAC, firmware,
// display, host devices. Captured from libvirt 11.3 (QEMU 10.0) on a nested
// Debian host with no IOMMU and no swtpm, on a throwaway q35 domain.
// ---------------------------------------------------------------------------

#[test]
fn hardware_caps_as_captured() {
    let hw = virt::parse_hardware(&fixture("script_hardware_caps_stopped.txt")).unwrap();
    let caps = hw.caps.unwrap();
    // q35: Secure Boot there; no swtpm on this host, so no TPM; no SPICE in
    // this QEMU build.
    assert!(caps.efi && caps.secure_boot && caps.hostdev);
    assert!(!caps.tpm_emulator);
    assert!(caps.graphics.contains(&"vnc".to_string()) && !caps.graphics.contains(&"spice".to_string()));
    assert!(caps.video.contains(&"virtio".to_string()));
    assert_eq!(caps.disk_buses, ["fdc", "scsi", "virtio", "usb", "sata"]);
    let c = hw.config;
    assert_eq!(c.machine.as_deref(), Some("pc-q35-10.0"));
    assert!(!c.efi && !c.secure_boot);
    assert_eq!(
        c.graphics,
        Some(virt::VirtHwGraphics { kind: "vnc".into(), listen: Some("127.0.0.1".into()), port: None })
    );
    assert_eq!(c.video.as_deref(), Some("virtio"));
    assert_eq!(c.disks[0].cache, None);

    // Running with Secure Boot, a cache mode changed in the definition only.
    let hw = virt::parse_hardware(&fixture("script_hardware_caps_running.txt")).unwrap();
    assert!(hw.config.efi && hw.config.secure_boot);
    assert_eq!(hw.config.disks[0].cache.as_deref(), Some("none"));
    assert_eq!(hw.live.unwrap().disks[0].cache.as_deref(), Some("writeback"));
}

#[test]
fn host_devices_as_captured() {
    let d = virt::parse_host_devices(&fixture("script_host_devices.txt")).unwrap();
    assert!(!d.iommu, "no IOMMU in a nested guest");
    assert!(d.usb.is_empty());
    assert_eq!(d.pci.len(), 13);
    let usb = d.pci.iter().find(|p| p.address == "0000:00:01.2").unwrap();
    assert_eq!((usb.vendor.as_deref(), usb.product.as_deref()), (Some("8086"), Some("7020")));
    assert_eq!(usb.iommu_group, None);
}

#[test]
fn hardware_changes_second_part_as_captured() {
    for name in [
        "update_disk_bus",
        "update_disk_cache",
        "cache_running",
        "nic_hardware",
        "firmware_secure",
        "firmware_plain",
        "firmware_bios",
        "firmware_efi",
        "firmware_secure_move",
        "display",
        "add_pci",
        "remove_pci",
    ] {
        let out = virt::parse_hardware_change(&fixture(&format!("script_hw_{name}.txt")));
        assert_eq!(out, Ok(virt::VirtHwOutcome::default()), "{name}");
    }
}

#[test]
fn disk_and_nic_edits() {
    let base = base_xml();
    // Another bus: the name on it, and no controller address left behind.
    let xml = virt::edit_disk_xml(&base, "vda", Some("sda"), Some("sata"), None).unwrap();
    let d = hw_of(&xml).disks.into_iter().find(|d| d.target == "sda").unwrap();
    assert_eq!(d.bus.as_deref(), Some("sata"));
    let disk = &xml[xml.find("<target dev='sda'").unwrap()..];
    assert!(!disk[..disk.find("</disk>").unwrap()].contains("<address"), "{xml}");
    // A cache mode, and back to the default.
    let xml = virt::edit_disk_xml(&base, "vda", None, None, Some("writeback")).unwrap();
    assert_eq!(hw_of(&xml).disks[0].cache.as_deref(), Some("writeback"));
    let xml = virt::edit_disk_xml(&xml, "vda", None, None, Some("default")).unwrap();
    assert_eq!(hw_of(&xml).disks[0].cache, None);
    assert!(virt::edit_disk_xml(&base, "vdz", None, None, Some("none")).is_err());

    let mac = hw_of(&base).nics[0].mac.clone();
    let xml = virt::edit_nic_hardware_xml(&base, &mac, Some("52:54:00:AA:BB:CC"), Some("e1000e")).unwrap();
    let nic = &hw_of(&xml).nics[0];
    assert_eq!((nic.mac.as_str(), nic.model.as_deref()), ("52:54:00:aa:bb:cc", Some("e1000e")));
}

#[test]
fn firmware_edits() {
    let base = base_xml();
    let edit = virt::edit_firmware_xml(&base, true, true).unwrap();
    let hw = hw_of(&edit.xml);
    assert!(hw.efi && hw.secure_boot);
    assert!(edit.xml.contains("<smm state='on'/>"), "{}", edit.xml);
    assert_eq!(edit.drop_vars, None, "BIOS had no variables file");
    let back = virt::edit_firmware_xml(&edit.xml, false, false).unwrap();
    let hw = hw_of(&back.xml);
    assert!(!hw.efi && !hw.secure_boot);
    assert!(!back.xml.contains("<firmware>") && !back.xml.contains("firmware='efi'"), "{}", back.xml);

    // A domain that has run has its variables file: one path, kept.
    const VARS: &str = "/var/lib/libvirt/qemu/nvram/vm_VARS.fd";
    let ran = virt::edit_firmware_xml(&base, true, false).unwrap().xml.replacen(
        "<firmware>",
        &format!("<nvram template='/t.fd'>{VARS}</nvram><firmware>"),
        1,
    );
    // Secure Boot on, and off again: the same path, its file dropped each
    // time so that libvirt makes it from the right template — no second
    // file left behind.
    let on = virt::edit_firmware_xml(&ran, true, true).unwrap();
    assert!(on.xml.contains(&format!("<nvram>{VARS}</nvram>")), "{}", on.xml);
    assert!(!on.xml.contains("-sb.fd") && !on.xml.contains("template="), "{}", on.xml);
    assert_eq!(on.drop_vars.as_deref(), Some(VARS));
    let off = virt::edit_firmware_xml(&on.xml, true, false).unwrap();
    assert!(off.xml.contains(&format!("<nvram>{VARS}</nvram>")), "{}", off.xml);
    assert_eq!(off.drop_vars.as_deref(), Some(VARS));
    // The same setting keeps the file it has.
    let same = virt::edit_firmware_xml(&on.xml, true, true).unwrap();
    assert_eq!(same.drop_vars, None);
    // Leaving UEFI: nothing names the file any more, so it goes.
    let bios = virt::edit_firmware_xml(&ran, false, false).unwrap();
    assert!(!bios.xml.contains("<nvram"), "{}", bios.xml);
    assert_eq!(bios.drop_vars.as_deref(), Some(VARS));

    // Only a file in libvirt's NVRAM directory is ever deleted, whatever
    // the definition says.
    for path in [
        "/etc/passwd",
        "/var/lib/libvirt/qemu/nvram/../../../../etc/x.fd",
        "/var/lib/libvirt/images/disk.fd",
        "relative/libvirt/qemu/nvram/x.fd",
        "/var/lib/libvirt/qemu/nvram/x.fd\n/etc/y.fd",
    ] {
        assert!(!virt::is_libvirt_nvram(path), "{path:?}");
        let odd = ran.replacen(VARS, path, 1);
        if let Ok(edit) = virt::edit_firmware_xml(&odd, false, false) {
            assert_eq!(edit.drop_vars, None, "{path:?}");
        }
    }
    assert!(virt::is_libvirt_nvram(
        "/home/u/.config/libvirt/qemu/nvram/vm_VARS.fd"
    ));

    // The change script deletes it after the definition, quoted.
    let script = virt::hardware_change_script(
        "vm",
        false,
        Some(&ran),
        &virt::VirtHwChange::Firmware { efi: true, secure_boot: true },
    )
    .unwrap();
    let define_at = script.find("define --file").unwrap();
    let rm_at = script.find(&format!("rm -f -- '{VARS}'")).unwrap();
    assert!(define_at < rm_at, "{script}");
}

#[cfg(unix)]
#[test]
fn firmware_change_deletes_the_dropped_variables_file() {
    use virt::VirtHwChange as C;
    let name = "it's \"odd\"; touch pwned $(id) `id`";
    let nvram = std::env::temp_dir()
        .join(format!("sbm_nv_{}", std::process::id()))
        .join("libvirt/qemu/nvram");
    std::fs::create_dir_all(&nvram).unwrap();
    let vars = nvram.join(format!("{name}_VARS.fd"));
    let vars_s = vars.display().to_string();
    // As a domain that has run: UEFI without Secure Boot, and its file.
    let base = virt::edit_firmware_xml(&base_xml(), true, false).unwrap().xml.replacen(
        "<firmware>",
        &format!("<nvram>{}</nvram><firmware>", vars_s.replace('&', "&amp;").replace('<', "&lt;")),
        1,
    );
    let d = hardware_stub("nvram", &base);
    let path = format!("{}:/usr/bin:/bin", d.display());
    let run = || {
        let script = virt::hardware_change_script(name, false, Some(&base), &C::Firmware {
            efi: true,
            secure_boot: true,
        })
        .unwrap();
        virt::parse_hardware_change(&run_sh(&script, &path))
    };

    // A refused definition still names the file: it stays.
    std::fs::write(&vars, "vars").unwrap();
    std::fs::write(d.join("fail_define"), "").unwrap();
    assert!(run().is_err());
    assert!(vars.exists());
    std::fs::remove_file(d.join("fail_define")).unwrap();

    // Defined: gone, and nothing else with it.
    std::fs::write(nvram.join("other_VARS.fd"), "other").unwrap();
    assert_eq!(run(), Ok(Default::default()));
    assert!(!vars.exists());
    assert!(nvram.join("other_VARS.fd").exists());
    assert!(!std::path::Path::new("pwned").exists());
    let _ = std::fs::remove_dir_all(nvram.parent().unwrap().parent().unwrap().parent().unwrap());
    let _ = std::fs::remove_dir_all(&d);
}

#[test]
fn display_and_device_edits() {
    let base = base_xml();
    let with_pw = base.replacen("<graphics type='vnc'", "<graphics type='vnc' passwd='x&amp;y'", 1);
    let xml = virt::edit_display_xml(&with_pw, None, Some("0.0.0.0"), Some("vga")).unwrap();
    let hw = hw_of(&xml);
    assert_eq!(hw.graphics.unwrap().listen.as_deref(), Some("0.0.0.0"));
    assert_eq!(hw.video.as_deref(), Some("vga"));
    // What the console had besides stays: its password among it.
    assert!(xml.contains("passwd='x&amp;y'"), "{xml}");

    let added = virt::VirtHwNewDevice::Pci { address: "0000:01:00.0".into() }.xml();
    let with = base.replacen("</devices>", &format!("{added}</devices>"), 1);
    assert_eq!(hw_of(&with).hostdevs[0].key, "pci:0000:01:00.0");
    let (without, element) = virt::remove_device_xml(&with, "pci:0000:01:00.0").unwrap();
    assert!(hw_of(&without).hostdevs.is_empty());
    assert_eq!(element, added);
    let usb = virt::VirtHwNewDevice::Usb { vendor: "0bda".into(), product: "b023".into() }.xml();
    let with = base.replacen("</devices>", &format!("{usb}</devices>"), 1);
    assert_eq!(hw_of(&with).hostdevs[0].key, "usb:0bda:b023");
    assert!(virt::remove_device_xml(&base, "tpm").is_err());
}

#[test]
fn second_part_changes_refuse_what_must_not_reach_a_shell() {
    use virt::{VirtHwChange as C, VirtHwNewDevice as D};
    let script = |c: &C| virt::hardware_change_script("vm", false, Some(&base_xml()), c);
    let disk = |bus: Option<&str>, cache: Option<&str>| C::UpdateDisk {
        target: "vda".into(),
        new_target: bus.map(|_| "sda".into()),
        bus: bus.map(str::to_string),
        cache: cache.map(str::to_string),
    };
    assert!(script(&disk(Some("sata; rm"), None)).is_err());
    assert!(script(&disk(None, Some("fast"))).is_err());
    assert!(script(&disk(None, None)).is_err());
    let nic = |mac: &str| C::UpdateNicHardware { mac: "52:54:00:b9:34:c3".into(), new_mac: Some(mac.into()), model: None };
    assert!(script(&nic("01:00:00:00:00:01")).is_err(), "multicast");
    assert!(script(&nic("00:00:00:00:00:00")).is_err());
    assert!(script(&nic("52:54:00:00:00:01'")).is_err());
    let display = |l: &str| C::Display { graphics: None, listen: Some(l.into()), video: None };
    assert!(script(&display("0.0.0.0' autoport='no")).is_err());
    assert!(script(&display("::1")).is_ok());
    for bad in [
        D::Pci { address: "0000:01:00.0'/>".into() },
        D::Pci { address: "0000:01:20.0".into() },
        D::Usb { vendor: "0bda".into(), product: "b02".into() },
        D::Tpm { model: "tpm-crb' x='".into() },
    ] {
        assert!(script(&C::AddDevice { device: bad.clone() }).is_err(), "{bad:?}");
    }
    assert!(script(&C::RemoveDevice { key: "pci:0000:01:00.0; x".into() }).is_err());
}

#[cfg(unix)]
#[test]
fn second_part_scripts_under_sh_with_a_hostile_name() {
    use virt::VirtHwChange as C;
    let name = "it's \"odd\"; touch pwned $(id) `id`";
    let base = base_xml();
    let d = hardware_stub("hostile2", &base);
    let path = format!("{}:/usr/bin:/bin", d.display());
    let run = |running: bool, c: &C| {
        let script = virt::hardware_change_script(name, running, Some(&base), c).unwrap();
        virt::parse_hardware_change(&run_sh(&script, &path))
    };
    let log = || std::fs::read_to_string(d.join("log")).unwrap_or_default();

    let change = C::UpdateDisk { target: "vda".into(), new_target: None, bus: None, cache: Some("none".into()) };
    assert_eq!(run(true, &change), Ok(Default::default()));
    assert_eq!(
        std::fs::read_to_string(d.join("given_define.xml")).unwrap(),
        virt::edit_disk_xml(&base, "vda", None, None, Some("none")).unwrap()
    );
    assert!(log().contains(&format!("dumpxml\n--inactive\n--domain\n{name}\n")), "{}", log());

    // A USB device goes to the running guest too; a PCI one does not.
    let usb = C::AddDevice { device: virt::VirtHwNewDevice::Usb { vendor: "0bda".into(), product: "b023".into() } };
    let _ = std::fs::remove_file(d.join("log"));
    assert_eq!(run(true, &usb), Ok(Default::default()));
    assert!(log().contains(&format!("attach-device\n--domain\n{name}\n")), "{}", log());
    assert_eq!(log().matches("attach-device").count(), 2, "{}", log());
    let pci = C::AddDevice { device: virt::VirtHwNewDevice::Pci { address: "0000:01:00.0".into() } };
    let _ = std::fs::remove_file(d.join("log"));
    assert_eq!(run(true, &pci), Ok(Default::default()));
    assert_eq!(log().matches("attach-device").count(), 1, "{}", log());
    assert!(!std::path::Path::new("pwned").exists() && !d.join("pwned").exists());
    let _ = std::fs::remove_dir_all(&d);
}

// ---------------------------------------------------------------------------
// Cloning: captured from libvirt 11.3, and under sh with a stub
// ---------------------------------------------------------------------------

#[test]
fn clone_outputs_from_the_host() {
    let full = virt::parse_clone_volumes(&fixture("script_clone_volumes_full.txt")).unwrap();
    assert_eq!(full, ["/var/lib/libvirt/images/sbcl-full.qcow2"]);
    let empty = virt::parse_clone_volumes(&fixture("script_clone_volumes_empty.txt")).unwrap();
    assert_eq!(empty, ["/var/lib/libvirt/images/sbcl-empty.qcow2"]);
    assert!(matches!(
        virt::parse_clone_volumes(&fixture("script_clone_volumes_exists.txt")),
        Err(VirtError::Exists { .. })
    ));
    assert!(matches!(
        virt::parse_clone_volumes(&fixture("script_clone_volumes_running.txt")),
        Err(VirtError::InvalidState { .. })
    ));
    let made = virt::parse_create(&fixture("script_clone_define.txt")).unwrap();
    assert_eq!(made.uuid.as_deref(), Some("b0352bd8-52ad-4cf7-875c-7ceb45b0d751"));
    // A define refused (the name taken meanwhile) says so, its volume gone.
    assert!(matches!(
        virt::parse_create(&fixture("script_clone_define_rollback.txt")),
        Err(VirtError::Exists { .. })
    ));
}

#[test]
fn clone_xml_is_a_new_domain_on_new_disks() {
    let base = r#"<domain type='kvm'>
  <name>src</name>
  <uuid>8ecccb6b-4f93-4739-afb1-caa17c3f4f91</uuid>
  <os firmware='efi'><type arch='x86_64' machine='q35'>hvm</type>
    <nvram template='/usr/share/OVMF/OVMF_VARS_4M.ms.fd' format='raw'>/var/lib/libvirt/qemu/nvram/src_VARS.fd</nvram>
  </os>
  <devices>
    <disk type='volume' device='disk'><driver name='qemu' type='qcow2'/><source pool='images' volume='src.qcow2'/><target dev='vda' bus='virtio'/></disk>
    <disk type='file' device='disk'><driver name='qemu' type='raw'/><source file='/v/data.img'/><target dev='vdb' bus='virtio'/></disk>
    <disk type='file' device='cdrom'><source file='/iso/cirros.img'/><target dev='sda' bus='sata'/><readonly/></disk>
    <interface type='network'><mac address='52:54:00:df:b2:a4'/><source network='default'/></interface>
  </devices>
</domain>"#;
    let name = "it's <new> & \"odd\"";
    let xml = virt::clone_domain_xml(
        base,
        name,
        &[
            ("vda".into(), "/var/lib/libvirt/images/new.qcow2".into()),
            ("vdb".into(), "/dev/vg0/new-1".into()),
        ],
    )
    .unwrap();
    let doc = roxmltree::Document::parse(&xml).unwrap();
    let root = doc.root_element();
    let el = |name: &str| root.descendants().find(|n| n.has_tag_name(name));
    assert_eq!(el("name").and_then(|n| n.text()), Some(name));
    assert!(el("uuid").is_none(), "libvirt gives it one");
    assert!(el("mac").is_none(), "nor one of the source's MACs");
    let disks: Vec<_> = root.descendants().filter(|n| n.has_tag_name("disk")).collect();
    fn src<'a>(d: roxmltree::Node<'a, 'a>) -> (Option<&'a str>, Option<&'a str>) {
        let s = d.children().find(|n| n.has_tag_name("source")).unwrap();
        (d.attribute("type"), s.attribute("file").or(s.attribute("dev")))
    }
    assert_eq!(src(disks[0]), (Some("file"), Some("/var/lib/libvirt/images/new.qcow2")));
    assert_eq!(src(disks[1]), (Some("block"), Some("/dev/vg0/new-1")));
    assert_eq!(src(disks[2]), (Some("file"), Some("/iso/cirros.img")), "a CD-ROM keeps its image");
    // Its own variables file, made by libvirt from the same template.
    let nvram = el("nvram").unwrap();
    assert_eq!(nvram.attribute("template"), Some("/usr/share/OVMF/OVMF_VARS_4M.ms.fd"));
    assert_eq!(nvram.text(), None);
    assert!(virt::clone_domain_xml(base, "x", &[("vdz".into(), "/p".into())]).is_err());
}

#[cfg(unix)]
#[test]
fn clone_scripts_under_sh_with_hostile_names() {
    use virt::{VirtCloneDisk, VirtCloneSpec};
    let d = std::env::temp_dir().join(format!("sbm_virt_clone_{}", std::process::id()));
    let _ = std::fs::remove_dir_all(&d);
    std::fs::create_dir_all(&d).unwrap();
    // A virsh that logs its arguments, answers the domain as shut off, and
    // makes volumes as files — refusing the second clone when told to.
    let stub = r#"#!/bin/sh
dir="$(dirname "$0")"
for a in "$@"; do printf '%s\n' "$a" >> "$dir/log"; done
echo --- >> "$dir/log"
shift 3
case "$1" in
  domuuid) exit 1 ;;
  domstate) echo 'shut off' ;;
  vol-pool) echo pool ;;
  vol-clone) [ -f "$dir/fail_second" ] && [ -f "$dir/made" ] && { echo "error: clone refused" >&2; exit 1; }; echo x >> "$dir/made"; echo "Vol cloned" ;;
  vol-info) echo "Capacity:       1073741824 bytes" ;;
  vol-create-as) echo "Vol created" ;;
  vol-path) echo "/pool/$5" ;;
  vol-delete) echo "Vol deleted" ;;
  *) echo "error: unexpected $*" >&2; exit 1 ;;
esac
"#;
    std::fs::write(d.join("virsh"), stub).unwrap();
    Command::new("chmod").arg("+x").arg(d.join("virsh")).status().unwrap();
    let path = format!("{}:/usr/bin:/bin", d.display());
    let log = || std::fs::read_to_string(d.join("log")).unwrap_or_default();
    let name = "it's \"odd\"; touch pwned $(id) `id`";
    let spec = |full: bool| VirtCloneSpec {
        source: name.into(),
        name: format!("{name} copy"),
        full,
        disks: vec![
            VirtCloneDisk { target: "vda".into(), source: format!("/pool/{name}.qcow2"), format: Some("qcow2".into()) },
            VirtCloneDisk { target: "vdb".into(), source: "/pool/data".into(), format: Some("raw".into()) },
        ],
    };

    let raw = run_sh(&virt::clone_volumes_script(&spec(true)).unwrap(), &path);
    let paths = virt::parse_clone_volumes(&raw).unwrap();
    assert_eq!(paths, [format!("/pool/{name} copy.qcow2"), format!("/pool/{name} copy-1")]);
    assert!(log().contains(&format!("vol-clone\n--vol\n/pool/{name}.qcow2\n--newname\n{name} copy.qcow2\n")), "{}", log());
    assert!(!std::path::Path::new("pwned").exists() && !d.join("pwned").exists());

    // Empty copies: the source's size and format.
    let _ = std::fs::remove_file(d.join("log"));
    let raw = run_sh(&virt::clone_volumes_script(&spec(false)).unwrap(), &path);
    assert_eq!(virt::parse_clone_volumes(&raw).unwrap().len(), 2);
    assert!(log().contains("vol-create-as\n--pool\npool\n--name\nit's"), "{}", log());
    assert!(log().contains("--capacity\n1073741824\n--format\nraw\n"), "{}", log());

    // The second disk refused: the first one's volume is deleted again.
    let _ = std::fs::remove_file(d.join("log"));
    let _ = std::fs::remove_file(d.join("made"));
    std::fs::write(d.join("fail_second"), "").unwrap();
    let raw = run_sh(&virt::clone_volumes_script(&spec(true)).unwrap(), &path);
    assert!(matches!(virt::parse_clone_volumes(&raw), Err(VirtError::Command { .. })), "{raw}");
    assert!(log().contains(&format!("vol-delete\n--vol\n/pool/{name} copy.qcow2\n")), "{}", log());
    let _ = std::fs::remove_dir_all(&d);
}

// ---------------------------------------------------------------------------
// Managing storage and networks, and uploading, under a real sh
// ---------------------------------------------------------------------------

/// A fake virsh for the storage and network scripts: logs its arguments one
/// per line, keeps what a `define --file` was given, writes what
/// `vol-upload` reads into `uploaded`, and fails the commands listed in
/// `$dir/fail`.
#[cfg(unix)]
fn manage_stub(tag: &str) -> PathBuf {
    let d = std::env::temp_dir().join(format!("sbm_virt_manage_{tag}_{}", std::process::id()));
    let _ = std::fs::remove_dir_all(&d);
    std::fs::create_dir_all(&d).unwrap();
    let stub = r#"#!/bin/sh
dir="$(dirname "$0")"
for a in "$@"; do printf '%s\n' "$a" >> "$dir/log"; done
echo --- >> "$dir/log"
shift 3
if [ -f "$dir/fail" ] && grep -qx "$1" "$dir/fail"; then echo "error: $1 refused" >&2; exit 1; fi
case "$1" in
  pool-define|net-define) cp "$3" "$dir/defined.xml" ;;
  vol-upload) cat > "$dir/uploaded" ;;
  *) cat >> "$dir/stdin" ;;
esac
"#;
    let path = d.join("virsh");
    std::fs::write(&path, stub).unwrap();
    Command::new("chmod").arg("+x").arg(&path).status().unwrap();
    d
}

#[cfg(unix)]
#[test]
fn manage_scripts_under_sh_with_hostile_names() {
    use sbm_parser::virt_manage::{self as m, VirtResourceOp as Op};
    let d = manage_stub("hostile");
    let path = format!("{}:/usr/bin:/bin", d.display());
    let hostile = "it's \"odd\"; touch pwned $(id) `id`";
    let log = || std::fs::read_to_string(d.join("log")).unwrap_or_default();

    // Existing objects are named by whatever libvirt calls them.
    for op in [
        Op::PoolStart { name: hostile.into() },
        Op::PoolAutostart { name: hostile.into(), on: false },
        Op::VolDelete { pool: hostile.into(), name: hostile.into() },
        Op::VolResize { pool: hostile.into(), name: hostile.into(), bytes: 5 << 30 },
        Op::NetDelete { name: hostile.into(), active: true },
    ] {
        assert_eq!(m::parse_resource(&run_sh(&m::resource_script(&op).unwrap(), &path)), Ok(()), "{op:?}");
    }
    let l = log();
    assert!(l.contains(&format!("pool-start\n--pool\n{hostile}\n---")), "{l}");
    assert!(l.contains(&format!("pool-autostart\n--pool\n{hostile}\n--disable\n---")), "{l}");
    assert!(l.contains(&format!("vol-delete\n--pool\n{hostile}\n--vol\n{hostile}\n---")), "{l}");
    assert!(l.contains("--capacity\n5368709120B\n"), "{l}");
    assert!(l.contains(&format!("net-destroy\n--network\n{hostile}\n---\n")), "{l}");
    assert!(l.contains(&format!("net-undefine\n--network\n{hostile}\n---\n")), "{l}");
    assert!(!d.join("pwned").exists() && !std::path::Path::new("pwned").exists());
    assert_eq!(std::fs::read_to_string(d.join("stdin")).unwrap_or_default(), "");

    // A create: defined from the XML byte for byte, built, started, autostart
    std::fs::remove_file(d.join("log")).unwrap();
    let create = Op::PoolCreate {
        name: "sbxe2e-p".into(),
        pool_type: "dir".into(),
        target: Some("/var/lib/libvirt/sbxe2e-p & q".into()),
        source: None,
        autostart: true,
    };
    assert_eq!(m::parse_resource(&run_sh(&m::resource_script(&create).unwrap(), &path)), Ok(()));
    assert_eq!(
        std::fs::read_to_string(d.join("defined.xml")).unwrap(),
        m::pool_xml("sbxe2e-p", "dir", Some("/var/lib/libvirt/sbxe2e-p & q"), None)
    );
    let l = log();
    let order: Vec<&str> = l
        .lines()
        .filter(|x| x.starts_with("pool-"))
        .collect();
    assert_eq!(order, ["pool-define", "pool-build", "pool-start", "pool-autostart"], "{l}");

    // The start refused: undefined again, and the error is the start's
    std::fs::remove_file(d.join("log")).unwrap();
    std::fs::write(d.join("fail"), "net-start\n").unwrap();
    let net = Op::NetCreate {
        name: "sbxe2e-n".into(),
        mode: "nat".into(),
        bridge: None,
        ipv4: Some(m::VirtNetIpv4 {
            address: "10.231.78.1".into(),
            prefix: 24,
            dhcp_start: Some("10.231.78.100".into()),
            dhcp_end: Some("10.231.78.200".into()),
        }),
        autostart: true,
    };
    let e = m::parse_resource(&run_sh(&m::resource_script(&net).unwrap(), &path)).unwrap_err();
    assert!(e.message().contains("net-start refused"), "{e:?}");
    let l = log();
    assert!(l.contains("net-undefine\n--network\nsbxe2e-n\n") && !l.contains("net-autostart"), "{l}");
    let _ = std::fs::remove_dir_all(&d);
}

/// Runs `command` the way an SSH server does — the login shell's `-c` —
/// with `input` on its stdin.
#[cfg(unix)]
fn run_command(command: &str, path: &str, input: &[u8]) -> String {
    use std::io::Write;
    let mut child = Command::new("/bin/sh")
        .arg("-c")
        .arg(command)
        .env("PATH", path)
        .stdin(Stdio::piped())
        .stdout(Stdio::piped())
        .stderr(Stdio::piped())
        .spawn()
        .unwrap();
    let mut stdin = child.stdin.take().unwrap();
    // The script may stop before reading it all: a closed pipe is its answer.
    let _ = stdin.write_all(input);
    drop(stdin);
    let out = child.wait_with_output().unwrap();
    String::from_utf8(out.stdout).unwrap()
}

#[cfg(unix)]
#[test]
fn upload_streams_stdin_into_the_volume() {
    use sbm_parser::virt_manage::{self as m, VirtUploadEntry};
    let d = manage_stub("upload");
    let path = format!("{}:/usr/bin:/bin", d.display());
    let hostile = "it's \"odd\" \\ $(id) `id`.iso";
    let command = m::vol_upload_command("images", hostile, VirtUploadEntry::Direct).unwrap();

    // Binary content, a line that looks like the go line included
    let mut data: Vec<u8> = (0..=255u8).cycle().take(300_000).collect();
    data.extend_from_slice(format!("\n{}\n", m::UPLOAD_GO).as_bytes());
    let mut input = format!("{}\n", m::UPLOAD_GO).into_bytes();
    input.extend_from_slice(&data);
    let out = run_command(&command, &path, &input);
    assert!(out.contains(m::UPLOAD_READY), "{out}");
    assert_eq!(m::parse_vol_upload(&out), Ok(true), "{out}");
    assert_eq!(std::fs::read(d.join("uploaded")).unwrap(), data);
    let l = std::fs::read_to_string(d.join("log")).unwrap();
    assert!(l.contains(&format!("vol-upload\n--pool\nimages\n--vol\n{hostile}\n--file\n/dev/stdin\n")), "{l}");
    assert!(l.contains("pool-refresh\n--pool\nimages\n"), "{l}");

    // Something else first — a password sudo did not ask for: virsh never
    // runs, and nothing reaches a volume.
    std::fs::remove_file(d.join("uploaded")).unwrap();
    std::fs::remove_file(d.join("log")).unwrap();
    let out = run_command(&command, &path, b"hunter2\nSbVirtUploadGo\nbytes");
    assert_eq!(m::parse_vol_upload(&out), Ok(false), "{out}");
    assert!(!out.contains(m::UPLOAD_READY), "{out}");
    assert!(!d.join("uploaded").exists() && !d.join("log").exists());

    // Refused by the host
    std::fs::write(d.join("fail"), "vol-upload\n").unwrap();
    let out = run_command(&command, &path, &input);
    assert!(matches!(m::parse_vol_upload(&out), Err(VirtError::Command { .. })), "{out}");
    let _ = std::fs::remove_dir_all(&d);
}
