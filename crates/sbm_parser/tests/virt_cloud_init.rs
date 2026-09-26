//! Creating a libvirt domain from a cloud image with cloud-init, and the
//! create form's other options (phase 7): the scripts run by a real `sh`
//! against a stub `virsh` and a stub ISO tool, with hostile values, and the
//! XML they define.

use sbm_parser::virt::{self, VirtError};
use sbm_parser::virt_cloud_init::{self as ci, VirtCiIpv4, VirtCiNetwork, VirtCloudInit};
use std::path::{Path, PathBuf};
use std::process::{Command, Stdio};

const NAME: &str = "it's \"odd\"; touch pwned $(id) `id`";
const MAC: &str = "52:54:00:12:34:56";

fn host() -> virt::VirtCreateHost {
    let raw = std::fs::read_to_string(
        Path::new(env!("CARGO_MANIFEST_DIR")).join("tests/fixtures/virt/script_create_host_full.txt"),
    )
    .unwrap();
    virt::parse_create_host(&raw).unwrap()
}

fn cloud_init() -> VirtCloudInit {
    VirtCloudInit {
        user: "debian".into(),
        password_hash: Some(ci::sha512_crypt("correct horse", "0123456789abcdef").unwrap()),
        ssh_keys: vec![
            "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIGx0 it's \"me\" $(touch pwned) `id`".into(),
        ],
        hostname: "sbx-web".into(),
        instance_id: "iid-sbx-web-9f".into(),
        network: Some(VirtCiNetwork {
            mac: MAC.into(),
            ipv4: Some(VirtCiIpv4 {
                address: "10.231.80.5/24".into(),
                gateway: Some("10.231.80.1".into()),
            }),
            dns: vec!["10.231.80.1".into()],
            search: vec!["lab.example".into()],
        }),
    }
}

fn spec() -> virt::VirtCreateSpec {
    virt::VirtCreateSpec {
        name: NAME.into(),
        vcpus: 2,
        memory_mib: 1024,
        host: host(),
        disk_pool: "my pool".into(),
        disk_gib: 8,
        disk_format: "qcow2".into(),
        base_image: Some("/var/lib/libvirt/images/debian 13's.qcow2".into()),
        disk_bus: Some("scsi".into()),
        network: Some("default".into()),
        nic_model: Some("e1000e".into()),
        mac: Some(MAC.into()),
        efi: true,
        tpm: false,
        cloud_init: Some(cloud_init()),
        start: true,
        ..Default::default()
    }
}

/// A directory to use as PATH: the stubs, and only the host tools the
/// scripts use — so a host that has a real ISO tool does not run it.
#[cfg(unix)]
fn bin_dir(tag: &str, iso_tool: Option<&str>) -> PathBuf {
    let d = std::env::temp_dir().join(format!("sbm_virt_ci_{tag}_{}", std::process::id()));
    let _ = std::fs::remove_dir_all(&d);
    std::fs::create_dir_all(&d).unwrap();
    for tool in ["mktemp", "rm", "wc", "tr", "cat", "cp", "ls", "dirname", "chmod", "sh"] {
        let found = ["/usr/bin", "/bin"]
            .iter()
            .map(|p| Path::new(p).join(tool))
            .find(|p| p.exists())
            .unwrap_or_else(|| panic!("no {tool}"));
        std::os::unix::fs::symlink(found, d.join(tool)).unwrap();
    }
    // virsh: logs its arguments, keeps what it is given, fails what the
    // test asks it to (a file `fail_<command>`).
    let virsh = r#"#!/bin/sh
dir="$(dirname "$0")"
for a in "$@"; do printf '%s\n' "$a" >> "$dir/log"; done
echo --- >> "$dir/log"
cat >> "$dir/stdin"
shift 3
[ -f "$dir/fail_$1" ] && { echo "error: $1 refused" >&2; exit 1; }
case "$1" in
  domuuid) [ -f "$dir/defined.xml" ] || { echo "error: failed to get domain" >&2; exit 1; }
           echo be27edda-481c-401d-88df-57e7b8756364 ;;
  vol-create-from) cp "$5" "$dir/vol.xml" ;;
  vol-upload) cp "$7" "$dir/uploaded.iso" ;;
  vol-path) echo "/pool/$5" ;;
  define) cp "$3" "$dir/defined.xml" ;;
  *) ;;
esac
"#;
    write_exec(&d.join("virsh"), virsh);
    if let Some(tool) = iso_tool {
        // Records where it ran and the modes of what it found there, then
        // writes the "ISO": the files, concatenated.
        let stub = format!(
            r#"#!/bin/sh
dir="{d}"
pwd >> "$dir/staging"
ls -ld . >> "$dir/modes"
ls -l user-data meta-data >> "$dir/modes"
for a in "$@"; do printf '%s\n' "$a" >> "$dir/iso_args"; done
[ -f "$dir/fail_iso" ] && {{ echo "no space left" >&2; exit 1; }}
cat user-data meta-data network-config > seed.iso 2>/dev/null || cat user-data meta-data > seed.iso
"#,
            d = d.display()
        );
        write_exec(&d.join(tool), &stub);
    }
    d
}

#[cfg(unix)]
fn write_exec(path: &Path, content: &str) {
    std::fs::write(path, content).unwrap();
    Command::new("/bin/chmod").arg("+x").arg(path).status().unwrap();
}

/// Feed `script` to `sh` on stdin, as the app does, with only `path` as PATH.
#[cfg(unix)]
fn run_sh(script: &str, path: &Path) -> String {
    use std::io::Write;
    let mut child = Command::new("/bin/sh")
        .env("PATH", path)
        .current_dir(path)
        .stdin(Stdio::piped())
        .stdout(Stdio::piped())
        .stderr(Stdio::piped())
        .spawn()
        .unwrap();
    child.stdin.take().unwrap().write_all(script.as_bytes()).unwrap();
    let out = child.wait_with_output().unwrap();
    String::from_utf8(out.stdout).unwrap()
}

fn read(d: &Path, f: &str) -> String {
    std::fs::read_to_string(d.join(f)).unwrap_or_default()
}

#[cfg(unix)]
#[test]
fn cloud_image_and_seed_under_sh_with_hostile_values() {
    let d = bin_dir("ok", Some("genisoimage"));
    let mut spec = spec();
    let script = virt::create_volume_script(&spec).unwrap();
    // The password itself is nowhere; only its hash is.
    assert!(!script.contains("correct horse"));
    let made = virt::parse_create_volumes(&run_sh(&script, &d)).unwrap();
    assert_eq!(made.disk_path, format!("/pool/{NAME}.qcow2"));
    assert_eq!(made.seed_path.as_deref(), Some(format!("/pool/{NAME}-cidata.iso").as_str()));
    let log = read(&d, "log");
    // A copy of the image in the pool's format, grown to the size asked for.
    assert!(
        log.contains("vol-create-from\n--pool\nmy pool\n--file\n")
            && log.contains("--vol\n/var/lib/libvirt/images/debian 13's.qcow2\n"),
        "{log}"
    );
    let vol_xml = read(&d, "vol.xml");
    let doc = roxmltree::Document::parse(&vol_xml).unwrap();
    let el = |n: &str| doc.descendants().find(|x| x.has_tag_name(n)).unwrap();
    assert_eq!(el("name").text(), Some(format!("{NAME}.qcow2").as_str()));
    assert_eq!(el("format").attribute("type"), Some("qcow2"));
    assert!(log.contains(&format!("vol-resize\n--pool\nmy pool\n--vol\n{NAME}.qcow2\n--capacity\n8G\n")), "{log}");
    // The seed: an ISO made in a private staging directory, then a raw
    // volume of its size filled from it.
    assert!(log.contains(&format!("vol-create-as\n--pool\nmy pool\n--name\n{NAME}-cidata.iso\n--capacity\n")), "{log}");
    assert!(log.contains(&format!("vol-upload\n--pool\nmy pool\n--vol\n{NAME}-cidata.iso\n--file\n")), "{log}");
    assert_eq!(
        read(&d, "iso_args"),
        "-quiet\n-output\nseed.iso\n-volid\ncidata\n-joliet\n-rock\nuser-data\nmeta-data\nnetwork-config\n"
    );
    let modes = read(&d, "modes");
    let lines: Vec<&str> = modes.lines().collect();
    assert!(lines[0].starts_with("drwx------"), "{modes}");
    assert!(lines[1..].iter().all(|l| l.starts_with("-rw-------")), "{modes}");
    // Staging is gone once done.
    let staging = read(&d, "staging");
    assert!(!Path::new(staging.trim()).exists(), "{staging}");
    // What the guest reads: every hostile value one string, as written.
    let c = cloud_init();
    let iso = read(&d, "uploaded.iso");
    assert_eq!(iso, [c.user_data(), c.meta_data(), c.network_config().unwrap()].concat());
    assert!(iso.contains("$6$0123456789abcdef$"), "{iso}");
    assert!(iso.contains(r#"      - "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIGx0 it's \"me\" $(touch pwned) `id`"
"#));
    assert!(!d.join("pwned").exists());
    assert_eq!(read(&d, "stdin"), "");

    // Defined on both, the seed named as the domain's own.
    spec.disk_path = Some(made.disk_path);
    spec.seed_path = made.seed_path;
    let created = virt::parse_create(&run_sh(&virt::define_script(&spec).unwrap(), &d)).unwrap();
    assert_eq!(created.start_error, None);
    let defined = read(&d, "defined.xml");
    assert_eq!(defined, virt::domain_xml(&spec));
    let back = virt::parse_domain_xml(&defined).unwrap();
    assert_eq!(back.seed.as_deref(), Some(format!("/pool/{NAME}-cidata.iso").as_str()));
    assert!(!d.join("pwned").exists());
    let _ = std::fs::remove_dir_all(&d);
}

#[cfg(unix)]
#[test]
fn every_tool_makes_the_seed_its_own_way() {
    for (tool, args) in [
        ("xorriso", "-as\nmkisofs\n-quiet\n-output\nseed.iso\n-volid\ncidata\n-joliet\n-rock\nuser-data\nmeta-data\nnetwork-config\n"),
        ("mkisofs", "-quiet\n-output\nseed.iso\n-volid\ncidata\n-joliet\n-rock\nuser-data\nmeta-data\nnetwork-config\n"),
        ("cloud-localds", "-N\nnetwork-config\nseed.iso\nuser-data\nmeta-data\n"),
    ] {
        let d = bin_dir(tool, Some(tool));
        let made = virt::parse_create_volumes(&run_sh(&virt::create_volume_script(&spec()).unwrap(), &d));
        assert!(made.unwrap().seed_path.is_some(), "{tool}");
        assert_eq!(read(&d, "iso_args"), args, "{tool}");
        let _ = std::fs::remove_dir_all(&d);
    }
}

#[cfg(unix)]
#[test]
fn a_seed_that_fails_takes_the_disk_back() {
    // No ISO tool: said so, naming them, and the disk deleted again.
    let d = bin_dir("none", None);
    let raw = run_sh(&virt::create_volume_script(&spec()).unwrap(), &d);
    match virt::parse_create_volumes(&raw) {
        Err(VirtError::Command { message }) => {
            assert!(message.contains("genisoimage, xorriso, mkisofs, cloud-localds"), "{message}")
        }
        other => panic!("{other:?}"),
    }
    let log = read(&d, "log");
    assert!(log.contains(&format!("vol-delete\n--pool\nmy pool\n--vol\n{NAME}.qcow2\n")), "{log}");
    assert!(!log.contains("cidata"), "{log}");
    let _ = std::fs::remove_dir_all(&d);

    // The tool fails.
    let d = bin_dir("isofail", Some("genisoimage"));
    std::fs::write(d.join("fail_iso"), "").unwrap();
    let raw = run_sh(&virt::create_volume_script(&spec()).unwrap(), &d);
    assert!(matches!(virt::parse_create_volumes(&raw), Err(VirtError::Command { .. })), "{raw}");
    assert!(read(&d, "log").contains(&format!("vol-delete\n--pool\nmy pool\n--vol\n{NAME}.qcow2\n")));
    assert!(!Path::new(read(&d, "staging").trim()).exists());
    let _ = std::fs::remove_dir_all(&d);

    // The upload fails: the seed's volume goes too.
    let d = bin_dir("upfail", Some("genisoimage"));
    std::fs::write(d.join("fail_vol-upload"), "").unwrap();
    let raw = run_sh(&virt::create_volume_script(&spec()).unwrap(), &d);
    match virt::parse_create_volumes(&raw) {
        Err(VirtError::Command { message }) => assert!(message.contains("vol-upload refused"), "{message}"),
        other => panic!("{other:?}"),
    }
    let log = read(&d, "log");
    assert!(log.contains(&format!("vol-delete\n--pool\nmy pool\n--vol\n{NAME}-cidata.iso\n")), "{log}");
    assert!(log.contains(&format!("vol-delete\n--pool\nmy pool\n--vol\n{NAME}.qcow2\n")), "{log}");
    assert!(!Path::new(read(&d, "staging").trim()).exists());
    let _ = std::fs::remove_dir_all(&d);

    // The copy cannot be grown: deleted.
    let d = bin_dir("resize", Some("genisoimage"));
    std::fs::write(d.join("fail_vol-resize"), "").unwrap();
    let raw = run_sh(&virt::create_volume_script(&spec()).unwrap(), &d);
    assert!(virt::parse_create_volumes(&raw).is_err());
    let log = read(&d, "log");
    assert!(log.contains(&format!("vol-delete\n--pool\nmy pool\n--vol\n{NAME}.qcow2\n")), "{log}");
    assert!(!log.contains("vol-upload"), "{log}");
    let _ = std::fs::remove_dir_all(&d);

    // A define refused deletes both volumes.
    let d = bin_dir("define", Some("genisoimage"));
    std::fs::write(d.join("fail_define"), "").unwrap();
    let mut s = spec();
    s.disk_path = Some(format!("/pool/{NAME}.qcow2"));
    s.seed_path = Some(format!("/pool/{NAME}-cidata.iso"));
    assert!(virt::parse_create(&run_sh(&virt::define_script(&s).unwrap(), &d)).is_err());
    let log = read(&d, "log");
    assert!(log.contains(&format!("vol-delete\n--pool\nmy pool\n--vol\n{NAME}-cidata.iso\n")), "{log}");
    assert!(log.contains(&format!("vol-delete\n--pool\nmy pool\n--vol\n{NAME}.qcow2\n")), "{log}");
    let _ = std::fs::remove_dir_all(&d);
}

#[test]
fn the_domain_the_create_options_make() {
    let mut s = spec();
    s.disk_path = Some("/pool/vm.qcow2".into());
    s.seed_path = Some("/pool/vm-cidata.iso".into());
    s.tpm = true;
    let xml = virt::domain_xml(&s);
    let back = virt::parse_domain_xml(&xml).unwrap();
    assert_eq!(back.disks[0].bus.as_deref(), Some("scsi"));
    assert_eq!(back.disks[0].target.as_deref(), Some("sda"));
    // The seed beside the SCSI disk, where its kernel has a driver; not
    // booted from.
    assert_eq!(back.disks[1].device, "cdrom");
    assert_eq!(back.disks[1].bus.as_deref(), Some("scsi"));
    assert_eq!(back.disks[1].target.as_deref(), Some("sdb"));
    assert_eq!(back.disks[1].source.as_deref(), Some("/pool/vm-cidata.iso"));
    assert_eq!(back.nics[0].mac.as_deref(), Some(MAC));
    assert_eq!(back.nics[0].model.as_deref(), Some("e1000e"));
    assert_eq!(back.seed.as_deref(), Some("/pool/vm-cidata.iso"));
    assert!(xml.contains("<controller type='scsi' model='virtio-scsi'/>"), "{xml}");
    assert!(!xml.contains("<boot dev='cdrom'/>"), "{xml}");
    let hw = virt::parse_hw_xml(&xml, &[]).unwrap();
    assert!(hw.efi && !hw.secure_boot, "{hw:?}");
    assert_eq!(hw.tpm.as_ref().map(|t| t.model.as_str()), Some("tpm-crb"));
    assert_eq!(hw.boot, ["sda"]);
    assert_eq!(hw.seed.as_deref(), Some("/pool/vm-cidata.iso"));

    // BIOS, virtio, install media: booted from, after the disk.
    let mut s = spec();
    s.cloud_init = None;
    s.base_image = None;
    s.disk_bus = None;
    s.efi = false;
    s.mac = None;
    s.nic_model = None;
    s.disk_path = Some("/pool/vm.qcow2".into());
    s.cdrom = Some("/iso/debian.iso".into());
    let xml = virt::domain_xml(&s);
    let back = virt::parse_domain_xml(&xml).unwrap();
    assert_eq!(back.disks[0].target.as_deref(), Some("vda"));
    assert_eq!(back.disks[1].target.as_deref(), Some("sda"));
    assert_eq!(back.nics[0].model.as_deref(), Some("virtio"));
    assert!(back.nics[0].mac.is_none());
    assert_eq!(back.seed, None);
    assert!(!virt::parse_hw_xml(&xml, &[]).unwrap().efi);
    assert!(xml.contains("<boot dev='cdrom'/>"));

    // A seed with a virtio disk: SATA on q35, SCSI (with its controller) on
    // `pc`, never IDE.
    let mut seeded = spec();
    seeded.disk_bus = None;
    seeded.disk_path = Some("/pool/vm.qcow2".into());
    seeded.seed_path = Some("/pool/vm-cidata.iso".into());
    let back = virt::parse_domain_xml(&virt::domain_xml(&seeded)).unwrap();
    assert_eq!((back.disks[1].bus.as_deref(), back.disks[1].target.as_deref()), (Some("sata"), Some("sda")));
    seeded.host.machine = "pc-i440fx-10.0".into();
    let xml = virt::domain_xml(&seeded);
    let back = virt::parse_domain_xml(&xml).unwrap();
    assert_eq!((back.disks[1].bus.as_deref(), back.disks[1].target.as_deref()), (Some("scsi"), Some("sda")));
    assert!(xml.contains("<controller type='scsi' model='virtio-scsi'/>"), "{xml}");

    // IDE on `pc`: the disk and the CD-ROM on two channels.
    s.host.machine = "pc-i440fx-10.0".into();
    s.disk_bus = Some("ide".into());
    let back = virt::parse_domain_xml(&virt::domain_xml(&s)).unwrap();
    assert_eq!(back.disks[0].target.as_deref(), Some("hda"));
    assert_eq!(back.disks[1].target.as_deref(), Some("hdc"));
}

#[test]
fn create_options_refused_before_running() {
    let bad = |f: &dyn Fn(&mut virt::VirtCreateSpec)| {
        let mut s = spec();
        f(&mut s);
        assert!(
            matches!(virt::create_volume_script(&s), Err(VirtError::Malformed { .. })),
            "{s:?}"
        );
    };
    bad(&|s| s.disk_bus = Some("usb".into()));
    bad(&|s| s.disk_bus = Some("ide".into())); // q35
    bad(&|s| s.nic_model = Some("virtio'/>".into()));
    bad(&|s| s.mac = Some("52:54:00:12:34".into()));
    bad(&|s| s.base_image = Some("relative.qcow2".into()));
    bad(&|s| s.cdrom = Some("/iso/x.iso".into())); // and a seed
    bad(&|s| s.mac = Some("52:54:00:00:00:01".into())); // not the seed's NIC
    bad(&|s| s.network = None); // a seed's network with no NIC
    bad(&|s| s.cloud_init.as_mut().unwrap().user = "Root".into());
    bad(&|s| s.cloud_init.as_mut().unwrap().password_hash = Some("plain".into()));
    // A seed path without cloud-init, or cloud-init without a seed.
    let mut s = spec();
    s.disk_path = Some("/pool/x.qcow2".into());
    assert!(virt::define_script(&s).is_err());
    s.cloud_init = None;
    s.seed_path = Some("/pool/x.iso".into());
    assert!(virt::define_script(&s).is_err());
}

#[test]
fn only_the_apps_own_seed_element_is_read() {
    let with = |md: &str| {
        format!("<domain type='kvm'><name>x</name><metadata>{md}</metadata><devices/></domain>")
    };
    let ns = ci::SEED_METADATA_NS;
    let seed = |md: &str| virt::parse_domain_xml(&with(md)).unwrap().seed;
    assert_eq!(seed(&format!("<a:cloud-init xmlns:a='{ns}' seed='/p/x-cidata.iso'/>")).as_deref(), Some("/p/x-cidata.iso"));
    // Another namespace, not an ISO, a relative or a climbing path: none.
    assert_eq!(seed("<a:cloud-init xmlns:a='urn:other' seed='/p/x.iso'/>"), None);
    assert_eq!(seed(&format!("<a:cloud-init xmlns:a='{ns}' seed='/p/disk.qcow2'/>")), None);
    assert_eq!(seed(&format!("<a:cloud-init xmlns:a='{ns}' seed='p/x.iso'/>")), None);
    assert_eq!(seed(&format!("<a:cloud-init xmlns:a='{ns}' seed='/p/../etc/x.iso'/>")), None);

    // A clone does not take the seed as its own.
    let base = format!(
        "<domain type='kvm'><name>src</name><metadata><a:cloud-init xmlns:a='{ns}' seed='/p/src-cidata.iso'/></metadata>\
         <devices><disk type='file' device='disk'><source file='/p/src.qcow2'/><target dev='vda' bus='virtio'/></disk>\
         <disk type='file' device='cdrom'><source file='/p/src-cidata.iso'/><target dev='sda' bus='sata'/><readonly/></disk></devices></domain>"
    );
    let clone = virt::clone_domain_xml(&base, "copy", &[("vda".into(), "/p/copy.qcow2".into())]).unwrap();
    let back = virt::parse_domain_xml(&clone).unwrap();
    assert_eq!(back.seed, None);
    assert_eq!(back.disks[1].source.as_deref(), Some("/p/src-cidata.iso"));
}

#[cfg(unix)]
#[test]
fn deleting_a_domain_deletes_its_seed_and_nothing_else() {
    let d = bin_dir("undefine", None);
    let seed = format!("/pool/{NAME}-cidata.iso");
    let script = virt::undefine_script(NAME, &["sda".into()], Some(&seed)).unwrap();
    assert_eq!(virt::parse_undefine(&run_sh(&script, &d)), Ok(()));
    let log = read(&d, "log");
    assert!(log.contains(&format!("undefine\n--domain\n{NAME}\n")), "{log}");
    assert!(log.ends_with(&format!("vol-delete\n--vol\n{seed}\n---\n")), "{log}");

    // Refused: the seed stays.
    let _ = std::fs::remove_file(d.join("log"));
    std::fs::write(d.join("fail_undefine"), "").unwrap();
    assert!(virt::parse_undefine(&run_sh(&script, &d)).is_err());
    assert!(!read(&d, "log").contains("vol-delete"));
    assert!(!d.join("pwned").exists());
    let _ = std::fs::remove_dir_all(&d);

    // The domain gone, its seed gone already or refused.
    let m = sbm_parser::script::cmd_marker;
    let rc = virt::RC_PREFIX;
    let out = |seed: &str| format!("{}\n\n{rc}0\n{}\n{seed}\n", m(virt::KEY_ACTION), m(virt::KEY_SEED_DELETE));
    assert_eq!(
        virt::parse_undefine(&out(&format!(
            "error: failed to get vol '/p/x.iso'\nerror: Storage volume not found: no storage vol with matching path\n{rc}1"
        ))),
        Ok(())
    );
    match virt::parse_undefine(&out(&format!("error: cannot unlink file '/p/x.iso': Permission denied\n{rc}1"))) {
        Err(VirtError::Command { message }) => assert!(message.contains("seed was not"), "{message}"),
        other => panic!("{other:?}"),
    }
}

#[cfg(unix)]
#[test]
fn a_cdrom_drive_added_under_sh() {
    use virt::VirtHwChange as C;
    let d = bin_dir("cdrom", None);
    let add = |source: Option<&str>| C::AddCdrom {
        target: "sdb".into(),
        bus: "sata".into(),
        source: source.map(str::to_string),
    };
    // Written to the persistent definition only, running or not.
    let script = virt::hardware_change_script(NAME, true, None, &add(Some("/iso/it's \"odd\".iso"))).unwrap();
    let out = virt::parse_hardware_change(&run_sh(&script, &d)).unwrap();
    assert_eq!(out.live_error, None);
    let log = read(&d, "log");
    assert!(log.contains(&format!("attach-device\n--domain\n{NAME}\n--file\n")), "{log}");
    assert!(log.contains("--config\n") && !log.contains("--live"), "{log}");
    assert!(!d.join("pwned").exists());
    let script = virt::hardware_change_script(NAME, false, None, &add(None)).unwrap();
    assert!(script.contains(r"<target dev='\''sdb'\'' bus='\''sata'\''/><readonly/>"), "{script}");
    assert!(!script.contains("<source"), "{script}");
    let bad = [
        C::AddCdrom { target: "sd b".into(), bus: "sata".into(), source: None },
        C::AddCdrom { target: "sdb".into(), bus: "virtio".into(), source: None },
        C::AddCdrom { target: "sdb".into(), bus: "sata".into(), source: Some("x.iso".into()) },
    ];
    for c in bad {
        assert!(virt::hardware_change_script("vm", false, None, &c).is_err(), "{c:?}");
    }
    let _ = std::fs::remove_dir_all(&d);
}
