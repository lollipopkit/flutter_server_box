//! libvirt external snapshots: the chain a guest's disks are on, what an
//! external snapshot of them is safe on, and the scripts that take one.
//!
//! An **external** snapshot leaves a qcow2 overlay on the file the guest was
//! already writing to and keeps nothing of the disk inside the snapshot. That
//! is what makes one possible while the guest runs: QEMU never has to write
//! the whole disk into the image. It is also what makes the chain something
//! the app has to read back — see [`VirtSnapChain`] and
//! [`external_snapshot_refusal`].
//!
//! # What this app writes, and why
//!
//! `snapshot-create-as --disk-only --atomic`, **with** metadata (no
//! `--no-metadata`), and `--diskspec <target>,file=<path>,snapshot=external`
//! for each writable disk so the overlay lands in a pool the user picked.
//!
//! - **With metadata.** `snapshot-list` then shows the layer like any other
//!   snapshot, `snapshot-dumpxml` names the file it was left on, and a revert
//!   can be asked for through libvirt. `--no-metadata` leaves a guest whose
//!   disks no longer match its definition and nothing recording the previous
//!   file; the app writes no such thing (the host does not either:
//!   `virsh snapshot-create-as --no-metadata` refuses while the domain is
//!   active and only allows it while shut off on some versions).
//! - **`--disk-only`.** The whole point of an external snapshot for a running
//!   guest is that it does not stop it: memory is not saved, and the guest
//!   keeps running on the overlay.
//! - **`--atomic`.** libvirt makes every disk's overlay first and, if any one
//!   of them fails (a read-only file, a raw disk, no space), removes the ones
//!   it made. Without it a guest can be left with one disk overlaid and
//!   another not.
//!
//! The guest is left on a chain: the previous file is now the overlay's
//! backing store and a **new** file (`<disk>.<snapshot>`) is what the guest
//! writes. On this app's watch, the old file is never modified again, so the
//! snapshot is the old file exactly as it was at that moment.
//!
//! # Reverting a chain (verified on libvirt 11.3)
//!
//! `snapshot-revert` on an external snapshot does **not** put the guest back
//! on the file the snapshot recorded:
//!
//! 1. libvirt commits the running overlay into its backing file — the base
//!    image becomes the current disk contents — and deletes the overlay.
//! 2. It then starts the guest on a **new** file in the directory the base
//!    image is in, named `<domain>.<timestamp>`. That file is owned by
//!    **root**, not by the QEMU user, because libvirt makes it as the daemon.
//! 3. Every snapshot *after* the one reverted to is left pointing at a file
//!    that is now gone. A later revert to one of them fails inside QEMU, and
//!    so does a later delete of any layer, with
//!    `block-commit: Could not open '<file>': Permission denied` — the
//!    profile that lets QEMU write where libvirt put it is not written.
//! 4. The chain is flattened: the file the guest ends up on backs the base
//!    image directly, and the layers in between are gone from disk.
//!
//! So a revert is safe only on the newest snapshot (a leaf: nothing sits on
//! it, and the collapse replaces the overlay it was already running on) and
//! is refused on any snapshot that has a child. That is the rule
//! [`revert_refusal`] states, and it is enforced before the host is asked.

use crate::script::{self, shell_quote_unix};
use crate::virt::{
    CONNECT_URI, RC_PREFIX, VirtError, child, domain_arg, parse_xml_doc, prelude, sections, take,
    text_of,
};
use serde::{Deserialize, Serialize};

/// The chain of every writable disk of a domain: what the running guest
/// writes to, then its backing file, down to the base image.
#[derive(Debug, Clone, Default, PartialEq, Eq, Serialize, Deserialize)]
pub struct VirtSnapChain {
    /// One entry per disk, by its target (`vda`).
    pub disks: Vec<VirtSnapChainDisk>,
    /// A disk QEMU would not open, as the host says it: no external snapshot
    /// of this guest can be taken.
    pub blocked: Option<String>,
}

#[derive(Debug, Clone, Default, PartialEq, Eq, Serialize, Deserialize)]
pub struct VirtSnapChainDisk {
    /// `vda`
    pub target: String,
    /// Topmost first; the first entry is the file the guest writes to now.
    pub files: Vec<VirtSnapChainFile>,
    /// The pool the topmost file was found in, when it is in one.
    pub pool: Option<String>,
}

#[derive(Debug, Clone, Default, PartialEq, Eq, Serialize, Deserialize)]
pub struct VirtSnapChainFile {
    pub path: String,
    /// `qcow2`, `raw`, `file`, ...
    pub format: Option<String>,
    /// The file it sits on, when it is an overlay.
    pub backing: Option<String>,
    /// Bytes the file takes on the host.
    pub allocation: Option<u64>,
    /// Bytes the guest sees through it.
    pub capacity: Option<u64>,
}

impl VirtSnapChain {
    /// Every disk that can be snapshotted (a CD-ROM is not).
    pub fn disks_iter(&self) -> impl Iterator<Item = &VirtSnapChainDisk> {
        self.disks.iter().filter(|d| !d.target.is_empty())
    }

    /// How many layers the deepest disk's chain has: 1 is a plain image.
    pub fn depth(&self) -> usize {
        self.disks_iter().map(|d| d.files.len()).max().unwrap_or(0)
    }

    /// Some disk is on an overlay: the guest is on a chain.
    pub fn has_overlays(&self) -> bool {
        self.disks_iter().any(|d| d.files.len() > 1)
    }
}

pub const KEY_SNAP_CHAIN: &str = "virt.snap.chain";

/// The disk chain of a domain, in one round trip: the definition, the paths
/// the devices are on now, and each one's chain as QEMU resolves it.
///
/// `dumpxml` carries the whole `<backingStore>` chain the definition was
/// written with; `domblklist --details` says which file the *running* guest
/// is on, which after an external snapshot is the overlay, not the file the
/// definition names. `qemu-img info --backing-chain --output=json -U` reads
/// the chain with QEMU's own code (`-U` skips the lock a running guest
/// holds), so what it prints is what QEMU would open, not what the XML
/// claims.
pub fn snap_chain_script(domain: &str) -> String {
    let d = domain_arg(domain);
    let mut s = prelude();
    s.push_str(&format!(
        "echo '{}'\nV dumpxml {d}\n",
        script::cmd_marker(crate::virt::KEY_XML),
    ));
    // One section per device: its path on the first line, then the chain.
    // `domblklist --details` prints `Type Device Target Source`; only a
    // regular file is a candidate for an external snapshot, and only a disk
    // (a CD-ROM is read-only). `qemu-img info` is run through `L`, which
    // adds the exit status, so a refusal is told from an empty answer.
    s.push_str(&format!(
        "L() {{ qemu-img info -U --backing-chain --output=json \"$@\" </dev/null 2>&1; \
         printf '\\n{rc}%s\\n' \"$?\"; }}\n\
         virsh --connect {CONNECT_URI} -q domblklist {d} --details </dev/null 2>/dev/null | \
         while IFS= read -r line; do\n\
         set -- $line\n\
         [ \"$1\" = file ] || continue\n\
         [ \"$2\" = disk ] || continue\n\
         echo '{key}'\n\
         printf '%s\\n' \"$4\"\n\
         L \"$4\"\n\
         done\n",
        rc = RC_PREFIX,
        key = script::cmd_marker(KEY_SNAP_CHAIN),
    ));
    s
}

/// `qemu-img info --output=json` for one layer.
#[derive(Deserialize)]
struct QemuImgInfo {
    filename: Option<String>,
    format: Option<String>,
    #[serde(rename = "virtual-size")]
    virtual_size: Option<u64>,
    #[serde(rename = "actual-size")]
    actual_size: Option<u64>,
    #[serde(rename = "backing-filename")]
    backing_filename: Option<String>,
}

/// [`snap_chain_script`]'s output.
///
/// A disk QEMU refuses to open (`qemu-img`'s own error text, no JSON) is
/// recorded as [`VirtSnapChain::blocked`] rather than dropped: a guest with a
/// disk nothing can read is a guest no external snapshot is taken of.
pub fn parse_snap_chain(raw: &str) -> Result<VirtSnapChain, VirtError> {
    let secs = sections(raw)?;
    let mut out = VirtSnapChain::default();
    // The disks the definition has, in its order, so the view lists them the
    // way the Hardware view does. A CD-ROM is not one of them.
    let mut defined: Vec<(String, Option<String>)> = Vec::new();
    if let Ok(xml) = take(&secs, crate::virt::KEY_XML, raw) {
        if let Ok(doc) = parse_xml_doc(&xml.body, "domain", "dumpxml") {
            for disk in doc
                .root_element()
                .descendants()
                .filter(|n| n.is_element() && n.tag_name().name() == "disk")
            {
                if disk.attribute("device") == Some("cdrom") {
                    continue;
                }
                let Some(target) = child(disk, "target").and_then(|t| t.attribute("dev"))
                else {
                    continue;
                };
                let file = child(disk, "source")
                    .and_then(|s| s.attribute("file"))
                    .map(str::to_string);
                defined.push((target.to_string(), file));
            }
        }
    }
    // The chains QEMU answered, by the path each was asked about.
    let mut chains: Vec<(String, Vec<VirtSnapChainFile>)> = Vec::new();
    for sec in secs
        .iter()
        .filter(|(k, _)| k == KEY_SNAP_CHAIN)
        .map(|(_, s)| s)
    {
        let Ok(body) = sec.ok() else { continue };
        let Some((path, json)) = body.split_once('\n') else {
            continue;
        };
        let path = path.trim().to_string();
        if path.is_empty() {
            continue;
        }
        let json = json.trim();
        let files = qemu_img_chain(json);
        if files.is_empty() {
            // Not JSON: `qemu-img`'s refusal (a raw disk, a lock it cannot
            // take). The first one is what the view shows.
            if !json.is_empty() && !json.starts_with('{') && out.blocked.is_none() {
                out.blocked = Some(json.to_string());
            }
            continue;
        }
        chains.push((path, files));
    }
    for (target, defined_file) in defined {
        // The device's chain is the one QEMU answered for the path the
        // definition names, or — after an external snapshot, which moves the
        // guest onto an overlay the definition does not name yet — for a
        // chain whose topmost file sits where that disk is. Where nothing
        // matched (a disk QEMU would not open), the definition's own file is
        // kept as the single layer, so a raw disk still shows as what it is.
        let found = chains
            .iter()
            .position(|(path, _)| Some(path.as_str()) == defined_file.as_deref())
            .or_else(|| {
                // The definition names a file the read did not answer for:
                // the guest is on an overlay the definition does not name yet
                // (a snapshot taken under it), so the chain whose *base* is
                // that file is this disk's.
                chains.iter().position(|(_, files)| {
                    files
                        .last()
                        .is_some_and(|base| Some(base.path.as_str()) == defined_file.as_deref())
                })
            });
        let files = match found {
            Some(i) => chains.remove(i).1,
            None => defined_file
                .map(|p| {
                    vec![VirtSnapChainFile {
                        path: p,
                        ..Default::default()
                    }]
                })
                .unwrap_or_default(),
        };
        let pool = files.first().and_then(|f| pool_of(&f.path));
        out.disks.push(VirtSnapChainDisk {
            target,
            files,
            pool,
        });
    }
    // A chain QEMU answered for a path no disk claimed (a definition that
    // changed under the read): kept, so it is not silently lost.
    for (path, files) in chains {
        out.disks.push(VirtSnapChainDisk {
            target: path,
            pool: files.first().and_then(|f| pool_of(&f.path)),
            files,
        });
    }
    Ok(out)
}

/// The pool a file is in, by name, for the common `images`-style directory:
/// the app does not read the host's pool list here, so this only names the
/// directory the file sits in, which is what the view shows.
fn pool_of(path: &str) -> Option<String> {
    let dir = path.rsplit_once('/')?.0;
    Some(dir.rsplit_once('/')?.1.to_string())
}

/// `--backing-chain --output=json` prints one document per layer, newest
/// first, each naming the file it sits on in `backing-filename`. All of them
/// are read; a layer without one ends the chain.
fn qemu_img_chain(json: &str) -> Vec<VirtSnapChainFile> {
    let mut out: Vec<VirtSnapChainFile> = Vec::new();
    for doc in json_docs(json) {
        let Ok(info) = serde_json::from_str::<QemuImgInfo>(&doc) else {
            continue;
        };
        let Some(path) = info.filename else { continue };
        out.push(VirtSnapChainFile {
            path,
            format: info.format,
            backing: info.backing_filename.clone(),
            allocation: info.actual_size,
            capacity: info.virtual_size,
        });
        if info.backing_filename.is_none() {
            break;
        }
    }
    out
}

/// Splits concatenated JSON documents (`--backing-chain` prints one per
/// layer, one after another with nothing between them). A brace counter is
/// enough: `qemu-img`'s JSON holds no braces inside strings that are not
/// balanced.
fn json_docs(raw: &str) -> Vec<String> {
    let mut out = Vec::new();
    let mut depth = 0usize;
    let mut start: Option<usize> = None;
    for (i, c) in raw.char_indices() {
        match c {
            '{' => {
                if depth == 0 {
                    start = Some(i);
                }
                depth += 1;
            }
            '}' => {
                depth = depth.saturating_sub(1);
                if depth == 0 {
                    if let Some(s) = start.take() {
                        out.push(raw[s..=i].to_string());
                    }
                }
            }
            _ => {}
        }
    }
    out
}

/// Why an external snapshot of this guest cannot be taken, or `None` when one
/// can.
///
/// The guest must have at least one disk, every disk must be a regular file
/// QEMU opens, and that file must be qcow2: an external snapshot makes a
/// qcow2 overlay on it, which needs a backing store a **qcow2** base can
/// carry. A raw disk is refused here with the reason rather than after the
/// host answers `internal snapshot for disk vda unsupported for storage type
/// raw` (its own words for the same refusal; captured).
///
/// The disk's own `driver type` in the definition is not what is checked —
/// what QEMU opened is (`qemu-img`'s `format`), because that is what the
/// overlay will be made over. A definition without a `<driver type>` on a
/// qcow2 file is a chain QEMU reads as raw (`backing file format: raw`,
/// captured), which is exactly the case whose chain cannot be trusted.
pub fn external_snapshot_refusal(chain: &VirtSnapChain) -> Option<String> {
    if chain.disks_iter().next().is_none() {
        return Some("the guest has no disk to snapshot".into());
    }
    for disk in chain.disks_iter() {
        let Some(top) = disk.files.first() else {
            return Some(format!(
                "disk {} is not an image libvirt can overlay",
                disk.target
            ));
        };
        match top.format.as_deref() {
            Some("qcow2") => {}
            Some(other) => {
                return Some(format!(
                    "disk {} is {other}: an external snapshot needs a qcow2 image",
                    disk.target
                ));
            }
            None => {
                return Some(format!(
                    "disk {} has no format QEMU could open",
                    disk.target
                ));
            }
        }
        // An overlay whose backing format is not recorded cannot be read back
        // without QEMU guessing: the layer below would be opened as the wrong
        // format on a host that does not probe.
        if top.backing.is_some() && top.format.is_none() {
            return Some(format!(
                "disk {} is an overlay with no backing format recorded",
                disk.target
            ));
        }
    }
    chain.blocked.clone()
}

/// Why the guest cannot be reverted to this snapshot, or `None` when it can.
///
/// Only a leaf may be reverted to on a chain: libvirt's revert flattens the
/// chain and leaves every *later* snapshot pointing at a file that is gone —
/// see the module comment. `children` is whether the snapshot has any.
///
/// A snapshot with no external layer at all (an internal one, taken before
/// this app wrote external ones) is reverted to as it always was.
pub fn revert_refusal(external: bool, children: bool) -> Option<RevertRefusal> {
    if external && children {
        return Some(RevertRefusal::HasChildren);
    }
    None
}

/// Why a revert is refused, for the UI to say in the user's language.
#[derive(Debug, Clone, Copy, PartialEq, Eq, Serialize, Deserialize)]
#[serde(rename_all = "snake_case")]
pub enum RevertRefusal {
    /// A later snapshot sits on this one; reverting would leave it (and every
    /// delete after it) unusable.
    HasChildren,
}

/// An external snapshot: the disks only (the guest keeps running), one
/// overlay per disk, `--atomic`.
///
/// `overlays` is `(target, path)` per disk, the file the user chose; a disk
/// without one gets libvirt's own name (`<disk>.<snapshot>`, beside the disk
/// it backs). Parse with [`crate::virt::parse_action`].
pub fn snapshot_external_script(
    domain: &str,
    name: &str,
    description: Option<&str>,
    overlays: &[(String, String)],
) -> String {
    let mut args = format!(
        "snapshot-create-as {} --name {} --disk-only --atomic",
        domain_arg(domain),
        shell_quote_unix(name)
    );
    if let Some(desc) = description.filter(|d| !d.trim().is_empty()) {
        args.push_str(&format!(" --description {}", shell_quote_unix(desc)));
    }
    for (target, file) in overlays {
        args.push_str(&format!(
            " --diskspec {},file={},snapshot=external",
            shell_quote_unix(target),
            shell_quote_unix(file)
        ));
    }
    let mut s = prelude();
    s.push_str(&format!(
        "echo '{}'\nV {args}\n",
        script::cmd_marker(crate::virt::KEY_ACTION)
    ));
    s
}

/// One layer of a snapshot's own chain, from its `snapshot-dumpxml`.
#[derive(Debug, Clone, Default, PartialEq, Eq, Serialize, Deserialize)]
pub struct VirtSnapLayer {
    /// `vda`
    pub target: String,
    /// The file the snapshot left this disk on (external layers only).
    pub file: Option<String>,
    /// `external`, `internal`, `no`.
    pub snapshot: Option<String>,
}

/// A `<disks>` element of a `snapshot-dumpxml`: which file the snapshot left
/// each disk on. The same reader serves `<revertDisks>`, which libvirt writes
/// into a snapshot already reverted to once and which names the file a
/// *further* revert would put the guest back on — not the one `<disks>` does.
pub(crate) fn layers_of(root: roxmltree::Node<'_, '_>, element: &str) -> Vec<VirtSnapLayer> {
    let Some(disks) = child(root, element) else {
        return Vec::new();
    };
    disks
        .children()
        .filter(|n| n.is_element() && n.tag_name().name() == "disk")
        .map(|disk| VirtSnapLayer {
            target: disk.attribute("name").unwrap_or("").to_string(),
            file: child(disk, "source")
                .and_then(|s| s.attribute("file"))
                .map(str::to_string),
            snapshot: disk.attribute("snapshot").map(str::to_string),
        })
        .collect()
}

/// The pool target directory `pool-dumpxml` names, for placing an overlay in
/// it. `None` for a pool of block devices (LVM, ZFS zvols, RBD), which no
/// overlay can be written into by path.
pub fn parse_pool_target(raw: &str) -> Option<String> {
    let doc = parse_xml_doc(raw, "pool", "pool-dumpxml").ok()?;
    let root = doc.root_element();
    child(root, "target")
        .and_then(|t| text_of(t, "path"))
        .or_else(|| text_of(root, "path"))
}

/// A snapshot's configuration and the guest's current one, in one round
/// trip: `snapshot-dumpxml` (whose `<domain>` is the definition as it was)
/// and `dumpxml --inactive` (the definition as it is). Parse with
/// [`diff_domain_xml`].
pub fn snap_diff_script(domain: &str, name: &str) -> String {
    let d = domain_arg(domain);
    let mut s = prelude();
    s.push_str(&format!(
        "echo '{}'\nV snapshot-dumpxml {d} --snapshotname {}\n",
        script::cmd_marker(KEY_DIFF_SNAP),
        shell_quote_unix(name),
    ));
    s.push_str(&format!(
        "echo '{}'\nV dumpxml {d} --inactive\n",
        script::cmd_marker(KEY_DIFF_CURRENT),
    ));
    s
}

pub const KEY_DIFF_SNAP: &str = "virt.snap.diff.snap";
pub const KEY_DIFF_CURRENT: &str = "virt.snap.diff.current";

/// [`snap_diff_script`]'s output.
pub fn parse_snap_diff(raw: &str) -> Result<Vec<VirtSnapDiff>, VirtError> {
    let secs = sections(raw)?;
    let before = take(&secs, KEY_DIFF_SNAP, raw)?;
    let after = take(&secs, KEY_DIFF_CURRENT, raw)?;
    // Both are `virsh` failures when either is refused; the parse then has
    // nothing to compare and says so rather than reporting "no differences".
    if before.rc != Some(0) {
        return Err(crate::virt::classify_error(before.body.trim()));
    }
    if after.rc != Some(0) {
        return Err(crate::virt::classify_error(after.body.trim()));
    }
    Ok(diff_domain_xml(&before.body, &after.body))
}

// ---------------------------------------------------------------------------
// The configuration diff
// ---------------------------------------------------------------------------

/// One meaningful difference between a snapshot's configuration and the
/// guest's current one.
#[derive(Debug, Clone, Default, PartialEq, Eq, Serialize, Deserialize)]
pub struct VirtSnapDiff {
    /// The group it belongs to, for the view to head a section with:
    /// `cpu`, `memory`, `disks`, `interfaces`, `firmware`, `boot`, `other`.
    pub group: String,
    /// The key within the group: `vcpu`, `vda`, `mac`, ...
    pub key: String,
    /// What the snapshot has, as the definition writes it.
    pub before: Option<String>,
    /// What the guest has now.
    pub after: Option<String>,
    /// The value left the configuration entirely.
    pub removed: bool,
    /// The value is new since the snapshot.
    pub added: bool,
}

/// Compares two domain definitions and returns only what changed, grouped the
/// way the view shows it: processor, memory, disks, interfaces, firmware,
/// boot and everything else.
///
/// The comparison is over the parsed structure, not the text: libvirt
/// reprints a document with attributes in its own order and with `<alias>`,
/// addresses and the running definition's `index=` attributes added, and a
/// textual diff of two such documents is noise. What is read is what the
/// snapshot's `<domain>` and the guest's `dumpxml --inactive` both carry.
pub fn diff_domain_xml(snapshot_xml: &str, current_xml: &str) -> Vec<VirtSnapDiff> {
    // `snapshot-dumpxml` answers a `<domainsnapshot>` whose `<domain>` is the
    // definition at the time; `dumpxml` answers the `<domain>` itself.
    let Ok(before) = parse_xml_doc(snapshot_xml, "domainsnapshot", "snapshot-dumpxml") else {
        return Vec::new();
    };
    let Ok(after) = parse_xml_doc(current_xml, "domain", "dumpxml") else {
        return Vec::new();
    };
    let Some(b) = child(before.root_element(), "domain") else {
        return Vec::new();
    };
    let a = after.root_element();
    let mut out = Vec::new();

    // Processor
    let b_vcpu = child(b, "vcpu").and_then(|n| n.text()).map(str::trim);
    let a_vcpu = child(a, "vcpu").and_then(|n| n.text()).map(str::trim);
    push(&mut out, "cpu", "vcpu", b_vcpu, a_vcpu);
    let b_cpu = cpu_of(b);
    let a_cpu = cpu_of(a);
    push(&mut out, "cpu", "model", b_cpu.as_deref(), a_cpu.as_deref());

    // Memory
    let kib = |n: roxmltree::Node<'_, '_>, tag: &str| {
        child(n, tag)
            .and_then(|m| crate::virt::bytes_of(Some(m)))
            .map(|v| (v / 1024).to_string())
    };
    push(
        &mut out,
        "memory",
        "memory",
        kib(b, "memory").as_deref(),
        kib(a, "memory").as_deref(),
    );
    push(
        &mut out,
        "memory",
        "currentMemory",
        kib(b, "currentMemory").as_deref(),
        kib(a, "currentMemory").as_deref(),
    );

    // Firmware: the OS element and the loader/nvram it brings
    let b_os = os_of(b);
    let a_os = os_of(a);
    push(&mut out, "firmware", "firmware", b_os.as_deref(), a_os.as_deref());

    // Devices, keyed the way the Hardware view names them
    let b_dev = devices_of(b);
    let a_dev = devices_of(a);
    for (group, tag, key_attr) in [
        ("disks", "disk", "vda"),
        ("interfaces", "interface", "mac"),
    ] {
        let b_map = device_map(b_dev, tag, key_attr);
        let a_map = device_map(a_dev, tag, key_attr);
        for key in keys_of(&b_map, &a_map) {
            let before = b_map.get(&key).map(|s| s.as_str());
            let after = a_map.get(&key).map(|s| s.as_str());
            push(&mut out, group, &key, before, after);
        }
    }
    let b_boot = boot_of(b_dev);
    let a_boot = boot_of(a_dev);
    push(
        &mut out,
        "boot",
        "order",
        b_boot.as_deref(),
        a_boot.as_deref(),
    );

    // Everything else the guest has that is not a disk, NIC, or the elements
    // read above: a controller, a channel, a graphics card, a TPM.
    let b_other = other_devices(b_dev);
    let a_other = other_devices(a_dev);
    for key in keys_of(&b_other, &a_other) {
        push(
            &mut out,
            "other",
            &key,
            b_other.get(&key).map(|s| s.as_str()),
            a_other.get(&key).map(|s| s.as_str()),
        );
    }
    out
}

fn push(
    out: &mut Vec<VirtSnapDiff>,
    group: &str,
    key: &str,
    before: Option<&str>,
    after: Option<&str>,
) {
    let (b, a) = (before.map(str::trim), after.map(str::trim));
    if b == a {
        return;
    }
    out.push(VirtSnapDiff {
        group: group.to_string(),
        key: key.to_string(),
        before: b.map(str::to_string),
        after: a.map(str::to_string),
        removed: a.is_none() && b.is_some(),
        added: b.is_none() && a.is_some(),
    });
}

fn cpu_of(root: roxmltree::Node<'_, '_>) -> Option<String> {
    let cpu = child(root, "cpu")?;
    if let Some(mode) = cpu.attribute("mode") {
        if mode != "custom" && mode != "host-passthrough" && mode != "host-model" {
            return Some(mode.to_string());
        }
    }
    child(cpu, "model").map(|m| match m.attribute("fallback") {
        Some(f) => format!("{} ({f})", m.text().unwrap_or("").trim()),
        None => m.text().unwrap_or("").trim().to_string(),
    })
}

fn os_of(root: roxmltree::Node<'_, '_>) -> Option<String> {
    let os = child(root, "os")?;
    let firmware = os.attribute("firmware");
    let loader = child(os, "loader").and_then(|l| l.text()).map(str::trim);
    let ty = child(os, "type").map(|t| match t.attribute("machine") {
        Some(m) => format!("{} {m}", t.text().unwrap_or("").trim()),
        None => t.text().unwrap_or("").trim().to_string(),
    });
    let bios = if firmware.is_some() || loader.is_some() {
        format!("uefi ({})", firmware.or(loader).unwrap_or("efi"))
    } else {
        "bios".to_string()
    };
    Some(match ty {
        Some(t) => format!("{bios}, {t}"),
        None => bios,
    })
}

fn devices_of<'a, 'i>(root: roxmltree::Node<'a, 'i>) -> Option<roxmltree::Node<'a, 'i>> {
    child(root, "devices")
}

/// The devices of one tag, by a key the view can name them with: a disk by
/// its target, a NIC by its MAC (the one thing about an interface that does
/// not change by itself), anything else by its own name.
fn device_map(
    devices: Option<roxmltree::Node<'_, '_>>,
    tag: &str,
    kind: &str,
) -> std::collections::BTreeMap<String, String> {
    let mut out = std::collections::BTreeMap::new();
    let Some(devices) = devices else { return out };
    for dev in devices
        .children()
        .filter(|n| n.is_element() && n.tag_name().name() == tag)
    {
        let key = match kind {
            "vda" => child(dev, "target")
                .and_then(|t| t.attribute("dev"))
                .map(str::to_string),
            _ => child(dev, "mac")
                .and_then(|m| m.attribute("address"))
                .map(str::to_string),
        };
        let Some(key) = key else { continue };
        if key.is_empty() {
            continue;
        }
        out.insert(key, describe(dev, tag));
    }
    out
}

/// Every device that is not a disk or an interface, by `tag:name`, so a
/// controller or a TPM is compared too.
fn other_devices(
    devices: Option<roxmltree::Node<'_, '_>>,
) -> std::collections::BTreeMap<String, String> {
    let mut out = std::collections::BTreeMap::new();
    let Some(devices) = devices else { return out };
    for dev in devices.children().filter(|n| n.is_element()) {
        let tag = dev.tag_name().name();
        if matches!(tag, "disk" | "interface" | "address" | "alias") {
            continue;
        }
        let name = child(dev, "target")
            .and_then(|t| t.attribute("dev").or_else(|| t.attribute("name")))
            .map(str::to_string)
            .or_else(|| dev.attribute("type").map(str::to_string))
            .unwrap_or_else(|| tag.to_string());
        out.insert(format!("{tag}:{name}"), describe(dev, tag));
    }
    out
}

/// A device as one line: the configuration that is the definition's, not
/// where it currently points.
///
/// `<alias>` and `<address>` are left out — libvirt gives them out of its own
/// counter and they differ between two reads of the same definition. A disk's
/// **source path** is left out for the same reason: an external snapshot
/// moves the guest onto an overlay, so the path always differs and is never a
/// configuration change (the chain view is what shows the files). What a disk
/// line says is its bus, device kind, driver and read-only flag.
fn describe(dev: roxmltree::Node<'_, '_>, tag: &str) -> String {
    let mut parts: Vec<String> = Vec::new();
    if tag == "interface" {
        if let Some(model) = child(dev, "model").and_then(|m| m.attribute("type")) {
            parts.push(model.to_string());
        }
        if let Some(src) = child(dev, "source") {
            for attr in ["bridge", "network", "dev"] {
                if let Some(v) = src.attribute(attr) {
                    parts.push(format!("{attr}={v}"));
                }
            }
        }
        if let Some(link) = child(dev, "link").and_then(|l| l.attribute("state")) {
            parts.push(format!("link={link}"));
        }
        return parts.join(" · ");
    }
    if let Some(dev_type) = dev.attribute("type") {
        parts.push(dev_type.to_string());
    }
    if let Some(device) = dev.attribute("device") {
        parts.push(device.to_string());
    }
    if let Some(bus) = child(dev, "target").and_then(|t| t.attribute("bus")) {
        parts.push(bus.to_string());
    }
    // A pool volume is named by pool and volume rather than by a path, and
    // neither moves under a snapshot.
    if let Some(src) = child(dev, "source") {
        if src.attribute("file").is_none() && src.attribute("dev").is_none() {
            for attr in ["volume", "pool", "dir", "name"] {
                if let Some(v) = src.attribute(attr) {
                    parts.push(v.to_string());
                }
            }
        }
    }
    if let Some(driver) = child(dev, "driver") {
        let mut d = Vec::new();
        for attr in ["name", "type", "cache"] {
            if let Some(v) = driver.attribute(attr) {
                d.push(v.to_string());
            }
        }
        if !d.is_empty() {
            parts.push(d.join("/"));
        }
    }
    if child(dev, "readonly").is_some() {
        parts.push("read-only".to_string());
    }
    parts.join(" · ")
}

fn boot_of(devices: Option<roxmltree::Node<'_, '_>>) -> Option<String> {
    let devices = devices?;
    let mut boot: Vec<(u32, String)> = Vec::new();
    for dev in devices.children().filter(|n| n.is_element()) {
        let Some(order) = child(dev, "boot").and_then(|b| b.attribute("order")) else {
            continue;
        };
        let Ok(order) = order.parse::<u32>() else { continue };
        let name = match dev.tag_name().name() {
            "disk" => child(dev, "target")
                .and_then(|t| t.attribute("dev"))
                .unwrap_or("disk")
                .to_string(),
            "interface" => child(dev, "mac")
                .and_then(|m| m.attribute("address"))
                .unwrap_or("nic")
                .to_string(),
            other => other.to_string(),
        };
        boot.push((order, name));
    }
    boot.sort();
    Some(boot.into_iter().map(|(_, n)| n).collect::<Vec<_>>().join(" > "))
}

fn keys_of(
    a: &std::collections::BTreeMap<String, String>,
    b: &std::collections::BTreeMap<String, String>,
) -> Vec<String> {
    let mut keys: Vec<String> = a.keys().chain(b.keys()).cloned().collect();
    keys.sort();
    keys.dedup();
    keys
}
