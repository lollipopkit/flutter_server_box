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
    for tool in [
        "mktemp", "rm", "wc", "tr", "cat", "cp", "ls", "dirname", "chmod", "sh", "sed", "cksum", "base64",
    ] {
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
[ -f "$dir/failonce_$1" ] && { rm "$dir/failonce_$1"; echo "error: $1 refused once" >&2; exit 1; }
file=; prev=
for a; do [ "$prev" = --file ] && file=$a; prev=$a; done
case "$1" in
  domuuid) [ -f "$dir/defined.xml" ] || { echo "error: failed to get domain" >&2; exit 1; }
           echo be27edda-481c-401d-88df-57e7b8756364 ;;
  vol-create-from) cp "$file" "$dir/vol.xml" ;;
  vol-upload) cp "$file" "$dir/uploaded.iso"; cat "$file" >> "$dir/uploads" ;;
  vol-download) cp "$dir/current.iso" "$file" ;;
  vol-info) if [ -f "$dir/capacity" ]; then printf 'Name:           x\nType:           file\nCapacity:       %s bytes\nAllocation:     4096 bytes\n\n' "$(cat "$dir/capacity")"; fi ;;
  vol-path) echo "/pool/$5" ;;
  define) cp "$file" "$dir/defined.xml" ;;
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
    assert!(iso.contains(r#"    - "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIGx0 it's \"me\" $(touch pwned) `id`"
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

// ---------------------------------------------------------------------------
// A cloud image bigger than the disk asked for; the tool order narrowed
// ---------------------------------------------------------------------------

#[cfg(unix)]
#[test]
fn a_copy_is_grown_only_to_a_bigger_disk() {
    // The image is 10 GiB, 8 asked for: kept at 10, not cut, and said so.
    let d = bin_dir("bigimage", Some("genisoimage"));
    std::fs::write(d.join("capacity"), format!("{}", 10u64 << 30)).unwrap();
    let made = virt::parse_create_volumes(&run_sh(&virt::create_volume_script(&spec()).unwrap(), &d)).unwrap();
    assert_eq!(made.copied_bytes, Some(10 << 30));
    let log = read(&d, "log");
    assert!(log.contains(&format!("vol-info\n--bytes\n--pool\nmy pool\n--vol\n{NAME}.qcow2\n")), "{log}");
    assert!(!log.contains("vol-resize"), "{log}");
    assert!(made.seed_path.is_some());
    let _ = std::fs::remove_dir_all(&d);

    // The same size: nothing to grow either.
    let d = bin_dir("sameimage", Some("genisoimage"));
    std::fs::write(d.join("capacity"), format!("{}", 8u64 << 30)).unwrap();
    let made = virt::parse_create_volumes(&run_sh(&virt::create_volume_script(&spec()).unwrap(), &d)).unwrap();
    assert_eq!(made.copied_bytes, Some(8 << 30));
    assert!(!read(&d, "log").contains("vol-resize"));
    let _ = std::fs::remove_dir_all(&d);

    // A 3 GiB image: grown to the 8 asked for.
    let d = bin_dir("smallimage", Some("genisoimage"));
    std::fs::write(d.join("capacity"), format!("{}", 3u64 << 30)).unwrap();
    let made = virt::parse_create_volumes(&run_sh(&virt::create_volume_script(&spec()).unwrap(), &d)).unwrap();
    assert_eq!(made.copied_bytes, Some(3 << 30));
    assert!(read(&d, "log").contains(&format!("vol-resize\n--pool\nmy pool\n--vol\n{NAME}.qcow2\n--capacity\n8G\n")));
    let _ = std::fs::remove_dir_all(&d);

    // `vol-info` refused: the copy goes, nothing else is made.
    let d = bin_dir("infofail", Some("genisoimage"));
    std::fs::write(d.join("fail_vol-info"), "").unwrap();
    let raw = run_sh(&virt::create_volume_script(&spec()).unwrap(), &d);
    assert!(virt::parse_create_volumes(&raw).is_err(), "{raw}");
    let log = read(&d, "log");
    assert!(log.contains(&format!("vol-delete\n--pool\nmy pool\n--vol\n{NAME}.qcow2\n")), "{log}");
    assert!(!log.contains("cidata"), "{log}");
    let _ = std::fs::remove_dir_all(&d);
}

#[cfg(unix)]
#[test]
fn the_tool_order_can_be_narrowed() {
    // genisoimage is there, but only cloud-localds is to be tried.
    let d = bin_dir("narrow", Some("genisoimage"));
    std::fs::copy(d.join("genisoimage"), d.join("cloud-localds")).unwrap();
    let mut s = spec();
    s.seed_tools = Some(vec!["cloud-localds".into()]);
    let made = virt::parse_create_volumes(&run_sh(&virt::create_volume_script(&s).unwrap(), &d)).unwrap();
    assert!(made.seed_path.is_some());
    assert_eq!(read(&d, "iso_args"), "-N\nnetwork-config\nseed.iso\nuser-data\nmeta-data\n");
    let _ = std::fs::remove_dir_all(&d);
    // Only known tools, each once.
    for bad in [vec![], vec!["sh".to_string()], vec!["xorriso".into(), "xorriso".into()]] {
        let mut s = spec();
        s.seed_tools = Some(bad);
        assert!(matches!(virt::create_volume_script(&s), Err(VirtError::Malformed { .. })));
    }
}

// ---------------------------------------------------------------------------
// Reading a seed back
// ---------------------------------------------------------------------------

/// The values the captured seeds (`tests/fixtures/virt/seed_*.iso`) were
/// made from: [`cloud_init`] with a second key, and a second DNS server.
fn captured() -> VirtCloudInit {
    let mut c = cloud_init();
    c.ssh_keys.push("ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABAQ second #: key".into());
    c.network.as_mut().unwrap().dns.push("2606:4700:4700::1111".into());
    c
}

fn fixture_bytes(name: &str) -> Vec<u8> {
    std::fs::read(Path::new(env!("CARGO_MANIFEST_DIR")).join("tests/fixtures/virt").join(name)).unwrap()
}

/// Seeds made on the libvirt host by each tool (genisoimage, `xorriso -as
/// mkisofs`, cloud-localds; and genisoimage with Rock Ridge only), read
/// back: the files by their own names, and what they say. They hold the
/// first release's `user-data` (one account of its own, `users:`), which
/// a seed made then still has.
#[test]
fn seeds_each_tool_made_read_back() {
    let c = captured();
    let legacy = c
        .user_data()
        .replace("user:\n  name:", "users:\n  - name:")
        .replace("  sudo: \"ALL=(ALL) NOPASSWD:ALL\"\n", "    sudo: \"ALL=(ALL) NOPASSWD:ALL\"\n    shell: /bin/bash\n")
        .replace("\n  lock_passwd", "\n    lock_passwd")
        .replace("\n  hashed_passwd", "\n    hashed_passwd")
        .replace("\n  ssh_authorized_keys:", "\n    ssh_authorized_keys:")
        .replace("\n    - \"ssh", "\n      - \"ssh");
    for iso in [
        "seed_genisoimage.iso",
        "seed_xorriso.iso",
        "seed_cloud_localds.iso",
        "seed_rock_ridge.iso",
    ] {
        let files = ci::iso_root_files(&fixture_bytes(iso)).unwrap();
        let get = |n: &str| {
            files
                .iter()
                .find(|(f, _)| f == n)
                .map(|(_, b)| String::from_utf8(b.clone()).unwrap())
                .unwrap_or_else(|| panic!("{iso}: no {n} in {:?}", files.iter().map(|f| &f.0).collect::<Vec<_>>()))
        };
        assert_eq!(get("user-data"), legacy, "{iso}");
        assert_eq!(get("meta-data"), c.meta_data(), "{iso}");
        assert_eq!(get("network-config"), c.network_config().unwrap(), "{iso}");
        assert_eq!(files.len(), 3, "{iso}");
    }
}

/// `seed_read_script`'s output as the host prints it: the cksum, then the
/// seed base64 in wrapped lines.
fn read_output(iso: &[u8], sum: &str) -> String {
    use base64::Engine;
    let m = sbm_parser::script::cmd_marker;
    let b64 = base64::engine::general_purpose::STANDARD.encode(iso);
    let wrapped: Vec<&str> = b64.as_bytes().chunks(76).map(|c| std::str::from_utf8(c).unwrap()).collect();
    format!(
        "{}\n\n{rc}0\n{}\n{sum}\n{rc}0\n{}\n{}\n\n{rc}0\n",
        m(ci::KEY_SEED_READ),
        m(ci::KEY_SEED_SUM),
        m(ci::KEY_SEED_DATA),
        wrapped.join("\n"),
        rc = virt::RC_PREFIX,
    )
}

#[test]
fn a_seed_read_is_what_was_written() {
    let read = ci::parse_seed_read(&read_output(&fixture_bytes("seed_xorriso.iso"), "4155283651 73728")).unwrap();
    assert_eq!(read.cloud_init, captured());
    assert!(!read.foreign);
    assert_eq!(read.revision, "4155283651 73728");
    // The hash is kept to write back; it is never printed.
    assert!(!format!("{read:?}").contains("$6$"));

    // A refused download is the host's words.
    let m = sbm_parser::script::cmd_marker;
    let raw = format!(
        "{}\nerror: Storage volume not found: no storage vol with matching path '/x.iso'\n{}1\n",
        m(ci::KEY_SEED_READ),
        virt::RC_PREFIX
    );
    assert!(matches!(ci::parse_seed_read(&raw), Err(VirtError::Command { .. })));
    // Not an ISO.
    assert!(matches!(
        ci::parse_seed_read(&read_output(b"not an iso at all", "1 17")),
        Err(VirtError::Malformed { .. })
    ));
    assert!(ci::iso_root_files(&[0u8; 40000]).is_err());
    // Cut short after the descriptors: out of range, not a panic.
    assert!(ci::iso_root_files(&fixture_bytes("seed_genisoimage.iso")[..20 * 2048]).is_err());
}

#[cfg(unix)]
#[test]
fn a_seed_is_read_under_sh() {
    let d = bin_dir("read", None);
    std::fs::copy(
        Path::new(env!("CARGO_MANIFEST_DIR")).join("tests/fixtures/virt/seed_genisoimage.iso"),
        d.join("current.iso"),
    )
    .unwrap();
    let path = "/pool/it's \"odd\" $(touch pwned)-cidata.iso";
    let raw = run_sh(&ci::seed_read_script(path).unwrap(), &d);
    let read = ci::parse_seed_read(&raw).unwrap();
    assert_eq!(read.cloud_init, captured());
    let sum = Command::new("/bin/sh")
        .arg("-c")
        .arg("cksum < current.iso")
        .current_dir(&d)
        .output()
        .unwrap();
    assert_eq!(read.revision, String::from_utf8(sum.stdout).unwrap().trim());
    assert!(read_log_has(&d, &["vol-download", "--vol", path]));
    assert!(!d.join("pwned").exists());
    let _ = std::fs::remove_dir_all(&d);

    assert!(ci::seed_read_script("relative.iso").is_err());
    assert!(ci::seed_read_script("/a/../b.iso").is_err());
    assert!(ci::seed_read_script("/a\nb.iso").is_err());
}

fn read_log_has(d: &Path, args: &[&str]) -> bool {
    read(d, "log").contains(&format!("{}\n", args.join("\n")))
}

#[test]
fn what_a_seed_says_that_the_app_does_not_write() {
    let files = |ud: &str, md: &str, nc: Option<&str>| {
        let mut f = vec![
            ("user-data".to_string(), ud.as_bytes().to_vec()),
            ("meta-data".to_string(), md.as_bytes().to_vec()),
        ];
        if let Some(nc) = nc {
            f.push(("network-config".to_string(), nc.as_bytes().to_vec()));
        }
        f
    };
    let c = captured();
    let (ud, md, nc) = (c.user_data(), c.meta_data(), c.network_config().unwrap());
    let read = |f: Vec<(String, Vec<u8>)>| ci::parse_seed_read(&read_output(&iso_of(&f), "1 1")).unwrap();
    assert!(!read(files(&ud, &md, Some(&nc))).foreign);
    // The first release's form (`users:` with one account of its own),
    // plain and single-quoted scalars, comments, another indent: the same.
    let plain = "#cloud-config\n# made by hand\nhostname: sbx-web\nmanage_etc_hosts: true\nusers:\n- name: 'debian'\n  sudo: ALL=(ALL) NOPASSWD:ALL\n  shell: /bin/bash\n  lock_passwd: true\nssh_pwauth: false\n";
    let r = read(files(plain, "instance-id: iid-1\nlocal-hostname: sbx-web\n", None));
    assert!(!r.foreign, "{r:?}");
    assert_eq!((r.cloud_init.user.as_str(), r.cloud_init.hostname.as_str()), ("debian", "sbx-web"));
    assert_eq!(r.cloud_init.password_hash, None);
    assert_eq!(r.cloud_init.network, None);
    // More than the app writes: foreign.
    for extra in [
        format!("{ud}packages: [nginx]\n"),
        ud.replace("NOPASSWD:ALL", "ALL"),
        format!("{ud}users:\n  - default\n"),
        ud.replace("  sudo:", "  shell: /bin/zsh\n  sudo:"),
        format!("{ud}runcmd:\n  - [touch, /x]\n"),
        ud.replace("#cloud-config", "#!/bin/sh"),
    ] {
        assert!(read(files(&extra, &md, Some(&nc))).foreign, "{extra}");
    }
    assert!(read(files(&ud, &format!("{md}public-keys: x\n"), Some(&nc))).foreign);
    let two = nc.replace("ethernets:\n", "ethernets:\n  eth9:\n    dhcp4: true\n");
    assert!(read(files(&ud, &md, Some(&two))).foreign);
    let mut extra_file = files(&ud, &md, Some(&nc));
    extra_file.push(("vendor-data".into(), b"#cloud-config\n".to_vec()));
    assert!(read(extra_file).foreign);
    // A hash that is not SHA-512 crypt is not kept as one.
    let md5 = ud.replace(&c.password_hash.clone().unwrap(), "$1$abc$def");
    let r = read(files(&md5, &md, Some(&nc)));
    assert!(r.foreign && r.cloud_init.password_hash.is_none());
}

/// A minimal ISO 9660 image of `files` with Joliet names, as the reader
/// takes it: system area, primary and Joliet descriptors, terminator, one
/// root directory per descriptor, then the files.
fn iso_of(files: &[(String, Vec<u8>)]) -> Vec<u8> {
    const S: usize = 2048;
    let dir_lba = [20usize, 21];
    let mut next = 22;
    let mut extents = vec![];
    for (_, data) in files {
        extents.push(next);
        next += data.len().div_ceil(S).max(1);
    }
    let mut iso = vec![0u8; next * S];
    let record = |lba: usize, len: usize, name: &[u8], dir: bool| {
        let mut r = vec![0u8; 33 + name.len() + (1 - name.len() % 2)];
        r[0] = r.len() as u8;
        r[2..6].copy_from_slice(&(lba as u32).to_le_bytes());
        r[10..14].copy_from_slice(&(len as u32).to_le_bytes());
        r[25] = if dir { 2 } else { 0 };
        r[32] = name.len() as u8;
        r[33..33 + name.len()].copy_from_slice(name);
        r
    };
    for (i, (kind, lba)) in [(1u8, dir_lba[0]), (2u8, dir_lba[1])].into_iter().enumerate() {
        let d = &mut iso[(16 + i) * S..(17 + i) * S];
        d[0] = kind;
        d[1..6].copy_from_slice(b"CD001");
        if kind == 2 {
            d[88..91].copy_from_slice(b"%/E");
        }
        d[156..190].copy_from_slice(&record(lba, S, &[0], true)[..34]);
        let mut dir = vec![];
        dir.extend(record(lba, S, &[0], true));
        dir.extend(record(lba, S, &[1], true));
        for ((name, data), at) in files.iter().zip(&extents) {
            let n: Vec<u8> = if kind == 2 {
                format!("{name};1").encode_utf16().flat_map(u16::to_be_bytes).collect()
            } else {
                b"X.;1".to_vec()
            };
            dir.extend(record(*at, data.len(), &n, false));
        }
        iso[lba * S..lba * S + dir.len()].copy_from_slice(&dir);
    }
    iso[18 * S] = 255;
    iso[18 * S + 1..18 * S + 6].copy_from_slice(b"CD001");
    for ((_, data), at) in files.iter().zip(&extents) {
        iso[at * S..at * S + data.len()].copy_from_slice(data);
    }
    iso
}

// ---------------------------------------------------------------------------
// Writing a seed anew
// ---------------------------------------------------------------------------

/// A seed update's run: `current.iso` is the seed on the host, of
/// `revision`'s cksum.
#[cfg(unix)]
fn update_dir(tag: &str) -> (PathBuf, String) {
    let d = bin_dir(tag, Some("genisoimage"));
    std::fs::copy(
        Path::new(env!("CARGO_MANIFEST_DIR")).join("tests/fixtures/virt/seed_genisoimage.iso"),
        d.join("current.iso"),
    )
    .unwrap();
    std::fs::write(d.join("capacity"), "376832").unwrap();
    let sum = Command::new("/bin/sh")
        .arg("-c")
        .arg("cksum < current.iso")
        .current_dir(&d)
        .output()
        .unwrap();
    (d, String::from_utf8(sum.stdout).unwrap().trim().to_string())
}

#[cfg(unix)]
#[test]
fn a_seed_is_written_anew_in_place() {
    let seed = "/pool/it's \"odd\" $(touch pwned)-cidata.iso";
    let mut next = cloud_init();
    next.hostname = "sbx-renamed".into();
    next.instance_id = "iid-sbx-web-a0".into();
    let (d, rev) = update_dir("update");
    let script = ci::seed_update_script(seed, &rev, &next, ci::SEED_TOOLS).unwrap();
    assert!(!script.contains("correct horse"));
    let raw = run_sh(&script, &d);
    ci::parse_seed_update(&raw).unwrap();
    // The old seed downloaded, the new one made from the new values and
    // uploaded over the same volume; nothing grown, nothing put back.
    assert!(read_log_has(&d, &["vol-download", "--vol", seed]));
    assert!(read_log_has(&d, &["vol-info", "--bytes", "--vol", seed]));
    assert!(read_log_has(&d, &["vol-upload", "--vol", seed]));
    let log = read(&d, "log");
    assert!(!log.contains("vol-resize") && !log.contains("vol-create") && !log.contains("vol-delete"), "{log}");
    assert_eq!(
        read(&d, "uploads"),
        [next.user_data(), next.meta_data(), next.network_config().unwrap()].concat()
    );
    assert!(!Path::new(read(&d, "staging").trim()).exists());
    assert!(!d.join("pwned").exists());
    let _ = std::fs::remove_dir_all(&d);

    // Bigger than the volume: grown to the ISO's size first.
    let (d, rev) = update_dir("grow");
    std::fs::write(d.join("capacity"), "100").unwrap();
    ci::parse_seed_update(&run_sh(&ci::seed_update_script(seed, &rev, &next, ci::SEED_TOOLS).unwrap(), &d)).unwrap();
    let size = [next.user_data(), next.meta_data(), next.network_config().unwrap()].concat().len();
    assert!(read_log_has(&d, &["vol-resize", "--vol", seed, "--capacity", &format!("{size}B")]));
    let _ = std::fs::remove_dir_all(&d);
}

#[cfg(unix)]
#[test]
fn a_seed_update_that_fails_leaves_the_old_one() {
    let seed = "/pool/vm-cidata.iso";
    let next = cloud_init();

    // Changed since it was read: nothing made, nothing uploaded.
    let (d, _) = update_dir("conflict");
    let raw = run_sh(&ci::seed_update_script(seed, "1 2", &next, ci::SEED_TOOLS).unwrap(), &d);
    assert!(matches!(ci::parse_seed_update(&raw), Err(VirtError::Conflict { .. })), "{raw}");
    assert!(!read(&d, "log").contains("vol-upload"));
    assert_eq!(read(&d, "iso_args"), "");
    let _ = std::fs::remove_dir_all(&d);

    // The upload fails: the old seed is uploaded back, and that is said.
    let (d, rev) = update_dir("restore");
    std::fs::write(d.join("failonce_vol-upload"), "").unwrap();
    let raw = run_sh(&ci::seed_update_script(seed, &rev, &next, ci::SEED_TOOLS).unwrap(), &d);
    match ci::parse_seed_update(&raw) {
        Err(VirtError::Command { message }) => {
            assert!(message.contains("vol-upload refused once"), "{message}");
            assert!(message.contains("previous cloud-init seed was put back"), "{message}");
        }
        other => panic!("{other:?}"),
    }
    assert_eq!(std::fs::read(d.join("uploaded.iso")).unwrap(), std::fs::read(d.join("current.iso")).unwrap());
    let _ = std::fs::remove_dir_all(&d);

    // And the old one cannot go back either: both said.
    let (d, rev) = update_dir("lost");
    std::fs::write(d.join("fail_vol-upload"), "").unwrap();
    match ci::parse_seed_update(&run_sh(&ci::seed_update_script(seed, &rev, &next, ci::SEED_TOOLS).unwrap(), &d)) {
        Err(VirtError::Command { message }) => assert!(message.contains("failed too"), "{message}"),
        other => panic!("{other:?}"),
    }
    let _ = std::fs::remove_dir_all(&d);

    // No tool: named, nothing uploaded.
    let d = bin_dir("update-notool", None);
    std::fs::copy(
        Path::new(env!("CARGO_MANIFEST_DIR")).join("tests/fixtures/virt/seed_genisoimage.iso"),
        d.join("current.iso"),
    )
    .unwrap();
    let sum = Command::new("/bin/sh").arg("-c").arg("cksum < current.iso").current_dir(&d).output().unwrap();
    let rev = String::from_utf8(sum.stdout).unwrap().trim().to_string();
    match ci::parse_seed_update(&run_sh(&ci::seed_update_script(seed, &rev, &next, ci::SEED_TOOLS).unwrap(), &d)) {
        Err(VirtError::Command { message }) => assert!(message.contains("genisoimage, xorriso"), "{message}"),
        other => panic!("{other:?}"),
    }
    assert!(!read(&d, "log").contains("vol-upload"));
    let _ = std::fs::remove_dir_all(&d);

    // Refused before any host: a bad path, revision or value.
    assert!(ci::seed_update_script("x.iso", "1 2", &next, ci::SEED_TOOLS).is_err());
    assert!(ci::seed_update_script(seed, "1 2'; id", &next, ci::SEED_TOOLS).is_err());
    assert!(ci::seed_update_script(seed, "", &next, ci::SEED_TOOLS).is_err());
    let mut bad = cloud_init();
    bad.hostname = "a b".into();
    assert!(ci::seed_update_script(seed, "1 2", &bad, ci::SEED_TOOLS).is_err());
}
