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
//! # Reverting a chain (verified on libvirt 11.3, Debian 13)
//!
//! `snapshot-revert` on an external snapshot does **not** put the guest back
//! on the file the snapshot recorded, and commits nothing:
//!
//! 1. libvirt deletes the file the guest was writing to (the top overlay),
//!    and with it whatever was written since the snapshot.
//! 2. It starts the guest on a **new** overlay of the file the snapshot
//!    kept, named after that file with its extension replaced by a
//!    timestamp (`ov1.qcow2` → `ov1.1790504997`), and records it as the
//!    snapshot's layer. The chain is as deep as before: reverting the
//!    newest of two snapshots leaves `ov1.<ts>` → `ov1.qcow2` → the base.
//! 3. Reverting to a snapshot that has a child failed on this host: QEMU
//!    was refused the base image (`Could not open '<base>': Permission
//!    denied`, AppArmor's `virt-aa-helper` having been denied the new
//!    `<base>.<ts>` file). The guest is left shut off on that new file, and
//!    the overlay it was running on is gone.
//!
//! So a revert is offered only on the newest snapshot (a leaf) and is
//! refused on any snapshot that has a child. The app enforces it before the
//! host is asked (`VirtGuestSnapshot.hasChildren`, Dart).
//!
//! # Deleting (AppArmor hosts)
//!
//! Deleting an external snapshot is a `block-commit` of its overlay into the
//! file below. On a host whose libvirt confines QEMU with AppArmor (Debian;
//! Debian bug #932456, libvirt issue #806) `virt-aa-helper` writes `deny
//! "<file>" w` for every file that was already a backing file when QEMU
//! started, so a commit into one is refused (`block-commit: Could not open
//! '<file>': Permission denied`), running or shut off. What still commits is
//! the newest snapshot taken while the guest ran, into the overlay the
//! previous one left. A refused delete leaves `<snapshotDeleteInProgress/>`
//! in the snapshot below, whose delete libvirt then refuses (`snapshot disk
//! 'vda' was target of not completed snapshot delete`). So the app asks
//! first: [`snap_delete_refusal`].

use crate::script::{self, shell_quote_unix};
use crate::virt::{
    CONNECT_URI, RC_PREFIX, VirtError, child, domain_arg, parse_xml_doc, prelude, sections, take,
};
use serde::{Deserialize, Serialize};

/// The chain of every writable disk of a domain: what the running guest
/// writes to, then its backing file, down to the base image.
#[derive(Debug, Clone, Default, PartialEq, Eq, Serialize, Deserialize)]
pub struct VirtSnapChain {
    /// One entry per disk, by its target (`vda`).
    pub disks: Vec<VirtSnapChainDisk>,
}

#[derive(Debug, Clone, Default, PartialEq, Eq, Serialize, Deserialize)]
pub struct VirtSnapChainDisk {
    /// `vda`
    pub target: String,
    /// Topmost first; the first entry is the file the guest writes to now.
    pub files: Vec<VirtSnapChainFile>,
    /// Why `qemu-img` could not read the disk, in its own words (a lock, a
    /// permission, the tool missing). `files` is then the definition's file
    /// alone, with no format.
    pub error: Option<String>,
}

#[derive(Debug, Clone, Default, PartialEq, Eq, Serialize, Deserialize)]
pub struct VirtSnapChainFile {
    pub path: String,
    /// `qcow2`, `raw`, `file`, ...
    pub format: Option<String>,
    /// The file it sits on, when it is an overlay.
    pub backing: Option<String>,
    /// The format the overlay's header records for `backing`; `None` on an
    /// overlay means QEMU probes the layer below.
    pub backing_format: Option<String>,
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
    let mut s = prelude();
    s.push_str(&chain_sections(&domain_arg(domain)));
    s
}

/// [`snap_chain_script`] without its prelude, for scripts that read the
/// chain among other things.
fn chain_sections(d: &str) -> String {
    let mut s = String::new();
    s.push_str(&format!(
        "echo '{}'\nV dumpxml {d}\n",
        script::cmd_marker(crate::virt::KEY_XML),
    ));
    // One section per device: its path on the first line, then the chain.
    // `domblklist --details` prints `Type Device Target Source`; only a
    // regular file is a candidate for an external snapshot, and only a disk
    // (a CD-ROM is read-only). `read` leaves the rest of the line in `src`,
    // so a path with spaces stays one word and is never globbed. `qemu-img
    // info` is run through `L`, which adds the exit status, so a refusal is
    // told from an answer.
    s.push_str(&format!(
        "L() {{ qemu-img info -U --backing-chain --output=json \"$@\" </dev/null 2>&1; \
         printf '\\n{rc}%s\\n' \"$?\"; }}\n\
         virsh --connect {CONNECT_URI} -q domblklist {d} --details </dev/null 2>/dev/null | \
         while read -r type device target src; do\n\
         [ \"$type\" = file ] || continue\n\
         [ \"$device\" = disk ] || continue\n\
         echo '{key}'\n\
         printf '%s\\n' \"$src\"\n\
         L \"$src\"\n\
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
    /// `backing-filename` resolved the way QEMU opens it: the header may
    /// record a path relative to the overlay's directory.
    #[serde(rename = "full-backing-filename")]
    full_backing_filename: Option<String>,
    #[serde(rename = "backing-filename-format")]
    backing_format: Option<String>,
}

/// [`snap_chain_script`]'s output.
///
/// A disk `qemu-img` could not read keeps the host's words in
/// [`VirtSnapChainDisk::error`] rather than being dropped: nothing is known
/// about its format, so no external snapshot is taken of it.
pub fn parse_snap_chain(raw: &str) -> Result<VirtSnapChain, VirtError> {
    read_snap_chain(raw).map(|(chain, _)| chain)
}

/// [`parse_snap_chain`], and whether the chain is **complete**: the
/// definition was read, it has a disk, and QEMU answered with a whole chain
/// for every disk it has (a CD-ROM aside). A failed `dumpxml` or
/// `domblklist` (whose status the script does not keep), a disk that is not
/// a regular file (`domblklist` is not asked about it), and a refusal from
/// `qemu-img` all leave it incomplete: some layer the guest uses may then be
/// missing from the answer.
fn read_snap_chain(raw: &str) -> Result<(VirtSnapChain, bool), VirtError> {
    let secs = sections(raw)?;
    let mut out = VirtSnapChain::default();
    // The disks the definition has, in its order, so the view lists them the
    // way the Hardware view does. A CD-ROM is not one of them.
    let mut defined: Vec<(String, Option<String>)> = Vec::new();
    let mut complete = false;
    if let Ok(xml) = take(&secs, crate::virt::KEY_XML, raw).and_then(|s| s.ok())
        && let Ok(doc) = parse_xml_doc(xml, "domain", "dumpxml") {
            complete = true;
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
                    // A disk this cannot name is one whose chain is unknown.
                    complete = false;
                    continue;
                };
                let file = child(disk, "source")
                    .and_then(|s| s.attribute("file"))
                    .map(str::to_string);
                defined.push((target.to_string(), file));
            }
        }
    // What QEMU answered, by the path each was asked about: the chain, or why
    // it would not open the file.
    let mut answers: Vec<(String, Result<Vec<VirtSnapChainFile>, String>)> = Vec::new();
    for sec in secs
        .iter()
        .filter(|(k, _)| k == KEY_SNAP_CHAIN)
        .map(|(_, s)| s)
    {
        let (path, rest) = sec.body.split_once('\n').unwrap_or((&sec.body, ""));
        let path = path.trim();
        if path.is_empty() {
            continue;
        }
        let rest = rest.trim();
        let answer = match (sec.rc, qemu_img_chain(rest)) {
            (Some(0), Some(files)) if !files.is_empty() => Ok(files),
            // A refusal (a lock, a permission, `qemu-img` missing) or output
            // that is not the chain: the host's words, or what little there is.
            (_, _) if !rest.is_empty() => Err(rest.to_string()),
            _ => Err("qemu-img gave no answer".to_string()),
        };
        answers.push((path.to_string(), answer));
    }
    for (target, defined_file) in defined {
        // The device's chain is the one QEMU answered for the path the
        // definition names, or — after an external snapshot, which moves the
        // guest onto an overlay the definition does not name yet — for a
        // chain whose base is that file.
        let found = answers
            .iter()
            .position(|(path, _)| Some(path.as_str()) == defined_file.as_deref())
            .or_else(|| {
                answers.iter().position(|(_, a)| {
                    a.as_ref().is_ok_and(|files| {
                        files
                            .last()
                            .is_some_and(|base| Some(base.path.as_str()) == defined_file.as_deref())
                    })
                })
            });
        // Where nothing was read, the definition's own file is kept as the
        // single layer with no format, so a disk still shows as what it is.
        let lone = |path: Option<String>| {
            path.map(|p| {
                vec![VirtSnapChainFile {
                    path: p,
                    ..Default::default()
                }]
            })
            .unwrap_or_default()
        };
        let (files, error) = match found.map(|i| answers.remove(i)) {
            Some((_, Ok(files))) => {
                complete &= files.last().is_some_and(|base| base.backing.is_none());
                (files, None)
            }
            Some((path, Err(e))) => {
                complete = false;
                (lone(Some(path)), Some(e))
            }
            None => {
                complete = false;
                (lone(defined_file), None)
            }
        };
        out.disks.push(VirtSnapChainDisk {
            target,
            files,
            error,
        });
    }
    // An answer for a path no disk claimed (a definition that changed under
    // the read): kept, so it is not silently lost.
    complete &= !out.disks.is_empty();
    for (path, answer) in answers {
        let (files, error) = match answer {
            Ok(files) => (files, None),
            Err(e) => (Vec::new(), Some(e)),
        };
        out.disks.push(VirtSnapChainDisk {
            target: path,
            files,
            error,
        });
    }
    Ok((out, complete))
}

/// `--backing-chain --output=json` prints an array, one object per layer,
/// newest first, each naming the file it sits on in `backing-filename`. A
/// layer without one ends the chain. `None` when the output is not that
/// array, or a layer in it names no file.
///
/// The backing file is the absolute path QEMU opens (`full-backing-filename`),
/// never a header's relative one: it is compared with absolute paths (the
/// AppArmor profile's, the other layers').
fn qemu_img_chain(json: &str) -> Option<Vec<VirtSnapChainFile>> {
    let infos: Vec<QemuImgInfo> = serde_json::from_str(json).ok()?;
    let mut out = Vec::new();
    for info in infos {
        let path = info.filename?;
        let backing = info.full_backing_filename.or_else(|| {
            let b = info.backing_filename?;
            Some(match path.rsplit_once('/') {
                Some((dir, _)) if !b.starts_with('/') && !b.contains(':') => format!("{dir}/{b}"),
                _ => b,
            })
        });
        let last = backing.is_none();
        out.push(VirtSnapChainFile {
            path,
            format: info.format,
            backing,
            backing_format: info.backing_format,
            allocation: info.actual_size,
            capacity: info.virtual_size,
        });
        if last {
            break;
        }
    }
    Some(out)
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
    if let Some(why) = snapshot_refusal(chain) {
        return Some(why);
    }
    if chain.disks_iter().next().is_none() {
        return Some("the guest has no disk to snapshot".into());
    }
    for disk in chain.disks_iter() {
        if let Some(e) = &disk.error {
            return Some(format!("disk {}: {e}", disk.target));
        }
        let Some(top) = disk.files.first() else {
            return Some(format!(
                "disk {} is not an image libvirt can overlay",
                disk.target
            ));
        };
        if top.format.is_none() {
            return Some(format!(
                "disk {} has no format QEMU could open",
                disk.target
            ));
        }
        // A layer whose backing format is not recorded cannot be read back
        // without QEMU guessing: the layer below would be opened as the wrong
        // format on a host that does not probe.
        if disk
            .files
            .iter()
            .any(|f| f.backing.is_some() && f.backing_format.is_none())
        {
            return Some(format!(
                "disk {} is an overlay with no backing format recorded",
                disk.target
            ));
        }
    }
    None
}

/// Why no snapshot at all — internal or external — can be taken, or `None`
/// when one may be.
///
/// Only what is known refuses: a disk QEMU opened as something other than
/// qcow2 (both forms need one). A disk whose format could not be read (the
/// tool missing, a permission) refuses the external form only, through
/// [`external_snapshot_refusal`]; `virsh snapshot-create-as` does not need
/// `qemu-img` and is left to answer for itself.
pub fn snapshot_refusal(chain: &VirtSnapChain) -> Option<String> {
    chain.disks_iter().find_map(|disk| {
        match disk.files.first()?.format.as_deref()? {
            "qcow2" => None,
            other => Some(format!(
                "disk {} is {other}: a snapshot needs a qcow2 image",
                disk.target
            )),
        }
    })
}

// ---------------------------------------------------------------------------
// Deleting and reverting an external snapshot on an AppArmor host
// ---------------------------------------------------------------------------

pub const KEY_DEL_SNAP: &str = "virt.snap.del.snap";
pub const KEY_DEL_INFO: &str = "virt.snap.del.info";
pub const KEY_DEL_SECMODEL: &str = "virt.snap.del.secmodel";
pub const KEY_DEL_DENY: &str = "virt.snap.del.deny";

/// What deciding [`snap_delete_refusal`] and [`snap_revert_refusal`] needs,
/// in one round trip: the snapshot's layers, the chain (as
/// [`snap_chain_script`]), `dominfo` (state and the running domain's
/// security model), the host's `<secmodel>`s from `capabilities`, and the
/// `deny` lines of the domain's AppArmor profile. Only those lines are
/// printed: a profile file names every path the guest may touch, and none of
/// the rest is needed.
pub fn snap_check_script(domain: &str, name: &str) -> String {
    let d = domain_arg(domain);
    let mut s = prelude();
    s.push_str(&format!(
        "echo '{}'\nV snapshot-dumpxml {d} --snapshotname {}\n",
        script::cmd_marker(KEY_DEL_SNAP),
        shell_quote_unix(name),
    ));
    s.push_str(&chain_sections(&d));
    s.push_str(&format!(
        // The profile is named by the UUID, taken from `dominfo`: `domuuid`
        // refuses a UUID as its argument, and the app names domains by one.
        "echo '{info}'\n\
         i=$(virsh --connect {CONNECT_URI} -q dominfo {d} </dev/null 2>&1); r=$?\n\
         printf '%s\\n\\n{rc}%s\\n' \"$i\" \"$r\"\n\
         u=$(printf '%s\\n' \"$i\" | sed -n 's/^UUID: *//p')\n\
         echo '{secmodel}'\n\
         c=$(virsh --connect {CONNECT_URI} -q capabilities </dev/null 2>&1); r=$?\n\
         printf '%s\\n' \"$c\" | sed -n '/<secmodel>/,/<\\/secmodel>/p'\n\
         printf '\\n{rc}%s\\n' \"$r\"\n\
         f=\"/etc/apparmor.d/libvirt/libvirt-$u.files\"\n\
         echo '{deny}'\n\
         if [ -n \"$u\" ] && [ -r \"$f\" ]; then grep -F 'deny \"' \"$f\"; printf '\\n{rc}0\\n'; \
         else printf 'no profile\\n\\n{rc}1\\n'; fi\n",
        info = script::cmd_marker(KEY_DEL_INFO),
        secmodel = script::cmd_marker(KEY_DEL_SECMODEL),
        deny = script::cmd_marker(KEY_DEL_DENY),
        rc = RC_PREFIX,
    ));
    s
}

/// What [`snap_check_script`] printed, as both refusals read it.
struct SnapCheck {
    /// For each of the snapshot's external layers on the current chain, the
    /// file below it: what a delete commits into, and what a revert puts a
    /// new overlay on.
    kept: Vec<String>,
    running: bool,
    /// libvirt confines this domain with AppArmor.
    apparmor: bool,
    /// The running domain's profile's `deny … w` files; none when it is not
    /// running or the profile could not be read.
    denied: Vec<String>,
}

impl SnapCheck {
    /// `None` where there is nothing the refusals could say: an internal
    /// snapshot, a layer not on the chain, a state that could not be read.
    fn read(raw: &str) -> Result<Option<SnapCheck>, VirtError> {
        let secs = sections(raw)?;
        let snap = take(&secs, KEY_DEL_SNAP, raw)?.ok()?;
        let doc = parse_xml_doc(snap, "domainsnapshot", "snapshot-dumpxml")?;
        let root = doc.root_element();
        let files: Vec<String> = layers_of(root, "disks")
            .into_iter()
            .chain(layers_of(root, "revertDisks"))
            .filter(|l| l.snapshot.as_deref() == Some("external"))
            .filter_map(|l| l.file)
            .collect();
        if files.is_empty() {
            return Ok(None);
        }
        let chain = parse_snap_chain(raw)?;
        let kept: Vec<String> = chain
            .disks_iter()
            .flat_map(|d| d.files.iter())
            .filter(|f| files.contains(&f.path))
            .filter_map(|f| f.backing.clone())
            .collect();
        if kept.is_empty() {
            return Ok(None);
        }
        let Ok(info) = take(&secs, KEY_DEL_INFO, raw).and_then(|s| s.ok()) else {
            return Ok(None);
        };
        let field = |key: &str| {
            info.lines()
                .find_map(|l| l.split_once(':').filter(|(k, _)| k.trim() == key))
                .map(|(_, v)| v.trim())
        };
        let running = field("State") == Some("running");
        let apparmor = if running {
            field("Security model") == Some("apparmor")
        } else {
            // Shut off, `dominfo` names no model: the host's first one is
            // what the domain gets, unless it opted out.
            let caps = take(&secs, KEY_DEL_SECMODEL, raw)
                .and_then(|s| s.ok())
                .map(|c| format!("<caps>{c}</caps>"))
                .unwrap_or_default();
            let model = roxmltree::Document::parse(&caps).ok().and_then(|d| {
                d.descendants()
                    .find(|n| n.has_tag_name("secmodel"))
                    .and_then(|m| child(m, "model"))
                    .and_then(|m| m.text().map(str::to_string))
            });
            model.as_deref() == Some("apparmor") && !chain_domain_unconfined(raw)
        };
        let denied = match take(&secs, KEY_DEL_DENY, raw).and_then(|s| s.ok()) {
            Ok(deny) if running => deny
                .lines()
                .filter_map(|l| l.trim().strip_prefix("deny \"")?.strip_suffix("\" w,"))
                .map(str::to_string)
                .collect(),
            _ => Vec::new(),
        };
        Ok(Some(SnapCheck { kept, running, apparmor, denied }))
    }
}

/// Why deleting the snapshot [`snap_check_script`] was run for would be
/// refused by the host, or `None` when it may be asked.
///
/// A delete commits each external layer into the file below it. libvirt's
/// AppArmor helper denies QEMU writing every file that was already a backing
/// file when QEMU started (`deny "<file>" w`; Debian bug #932456), so such a
/// commit fails with `Permission denied` and leaves the snapshot below
/// marked `snapshotDeleteInProgress`, refusing its own delete afterwards.
/// Refused here, before that happens:
///
/// - running, confined by AppArmor: a layer whose commit target the
///   profile denies writing;
/// - shut off, on a host whose driver is AppArmor and a domain not opted out
///   (`<seclabel type='none'>`): any external layer, since libvirt starts
///   QEMU for the commit with the whole chain already below.
///
/// An internal snapshot, a layer not on the current chain, or anything this
/// could not read is left to the host.
pub fn snap_delete_refusal(raw: &str) -> Result<Option<String>, VirtError> {
    let Some(c) = SnapCheck::read(raw)? else {
        return Ok(None);
    };
    const WHY: &str = "libvirt's AppArmor profile denies QEMU writing \
                       (Debian bug #932456): the host would refuse the delete, \
                       and every later delete on that disk after it";
    if !c.apparmor {
        return Ok(None);
    }
    if c.running {
        return Ok(c.kept.iter().find(|t| c.denied.contains(t)).map(|t| {
            format!("Deleting it writes into {t}, which {WHY}")
        }));
    }
    Ok(Some(format!(
        "Deleting it while the guest is shut off writes into {}, which {WHY}",
        c.kept[0]
    )))
}

/// Where the AppArmor profile of libvirt's `virt-aa-helper` (Debian 13's
/// and Ubuntu's `usr.lib.libvirt.virt-aa-helper`) lets it read a file of
/// any name: `/var/lib/libvirt/images/**`, `@{HOME}/**`,
/// `/{media,mnt,opt,srv}/**`. Elsewhere only a known extension is read
/// (`.qcow2`, `.img`, `.raw`, …) or a file named `disk`.
fn aa_helper_reads(path: &str) -> bool {
    const ANY_NAME: &[&str] = &["/var/lib/libvirt/images/", "/root/", "/media/", "/mnt/", "/opt/", "/srv/"];
    ANY_NAME.iter().any(|p| path.starts_with(p))
        || path.strip_prefix("/home/").is_some_and(|rest| rest.contains('/'))
        || path.rsplit('/').next().is_some_and(|name| name == "disk" || name.starts_with("disk."))
}

/// Why reverting to the snapshot [`snap_check_script`] was run for would
/// fail on the host, or `None` when it may be asked.
///
/// A revert starts the guest on a new overlay of the file the snapshot
/// kept, named after it with its extension replaced by a timestamp
/// (`web.qcow2` → `web.1790504997`), in that file's directory. On a host
/// that confines QEMU with AppArmor, libvirt's `virt-aa-helper` has to read
/// that file to write the guest's profile, and outside the directories its
/// own profile opens to any name ([`aa_helper_reads`]) a name without a
/// known extension is refused to it. The guest then cannot open the kept
/// file (`Could not open '<file>': Permission denied`): the revert fails,
/// leaving the guest shut off with the overlay it was running on deleted,
/// and it does not start again (libvirt 11.3, Debian 13: verified in a pool
/// outside `/var/lib/libvirt/images`, and not in one inside it).
pub fn snap_revert_refusal(raw: &str) -> Result<Option<String>, VirtError> {
    let Some(c) = SnapCheck::read(raw)? else {
        return Ok(None);
    };
    if !c.apparmor {
        return Ok(None);
    }
    Ok(c.kept.iter().find(|k| {
        let dir = k.rsplit_once('/').map(|(d, _)| d).unwrap_or("");
        !aa_helper_reads(&format!("{dir}/x"))
    }).map(|k| {
        format!(
            "Reverting it puts the guest on a new file beside {k}, where libvirt's \
             AppArmor helper cannot read a file of that name: the guest would not \
             start, and what it wrote since the snapshot would be lost. A disk in \
             /var/lib/libvirt/images (or /srv, /opt, /mnt, /media, a home \
             directory) does not have this."
        )
    }))
}

/// The files deleting the snapshot [`snap_check_script`] was run for would
/// leave behind: its external layers' files that are on no disk's current
/// chain. That is a snapshot on a branch the guest left — a revert to an
/// internal snapshot taken before it, or to another branch — and libvirt
/// (11.3, verified) deletes it without them: its metadata goes, and the
/// overlay the branch was written to stays, which nothing names afterwards.
/// libvirt refuses such a snapshot while it has children ("deletion of
/// non-leaf external snapshot that is not in active chain"), so only a
/// leaf's are named, and no other snapshot has them as a backing file.
///
/// Empty unless the chain is complete (see [`read_snap_chain`]): these
/// files are deleted, and a layer missing from an incomplete answer — a
/// failed read, a disk that is not a file, a refusal from `qemu-img` — would
/// look off the chain while the guest still uses it.
pub fn snap_delete_leftovers(raw: &str) -> Result<Vec<String>, VirtError> {
    let secs = sections(raw)?;
    let snap = take(&secs, KEY_DEL_SNAP, raw)?.ok()?;
    let doc = parse_xml_doc(snap, "domainsnapshot", "snapshot-dumpxml")?;
    let root = doc.root_element();
    let (chain, complete) = read_snap_chain(raw)?;
    if !complete || chain.disks_iter().any(|d| d.error.is_some()) {
        return Ok(Vec::new());
    }
    let on_chain: Vec<&str> = chain
        .disks_iter()
        .flat_map(|d| d.files.iter())
        .flat_map(|f| std::iter::once(f.path.as_str()).chain(f.backing.as_deref()))
        .collect();
    let mut out: Vec<String> = Vec::new();
    for f in layers_of(root, "disks")
        .into_iter()
        .chain(layers_of(root, "revertDisks"))
        .filter(|l| l.snapshot.as_deref() == Some("external"))
        .filter_map(|l| l.file)
    {
        if !on_chain.contains(&f.as_str()) && !out.contains(&f) {
            out.push(f);
        }
    }
    Ok(out)
}

/// Whether the domain opts out of confinement: a `<seclabel type='none'>`
/// for AppArmor, or for every driver (no `model`).
fn chain_domain_unconfined(raw: &str) -> bool {
    let Ok(secs) = sections(raw) else { return false };
    let Ok(xml) = take(&secs, crate::virt::KEY_XML, raw) else {
        return false;
    };
    let Ok(doc) = parse_xml_doc(&xml.body, "domain", "dumpxml") else {
        return false;
    };
    doc.root_element()
        .children()
        .filter(|n| n.has_tag_name("seclabel"))
        .any(|n| {
            n.attribute("type") == Some("none")
                && n.attribute("model").is_none_or(|m| m == "apparmor")
        })
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
    // `--diskspec` is a comma-separated list to virsh (`vshStringToArray`),
    // where a literal comma is written twice.
    let spec = |v: &str| v.replace(',', ",,");
    for (target, file) in overlays {
        args.push_str(&format!(
            " --diskspec {}",
            shell_quote_unix(&format!("{},file={},snapshot=external", spec(target), spec(file)))
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

/// The processor as one line: a custom CPU by its model, any other mode
/// (`host-passthrough`, `host-model`, `maximum`) by the mode and the model
/// it names, if any — those modes usually name none, and two of them must
/// still read as different.
fn cpu_of(root: roxmltree::Node<'_, '_>) -> Option<String> {
    let cpu = child(root, "cpu")?;
    let model = child(cpu, "model").map(|m| match m.attribute("fallback") {
        Some(f) => format!("{} ({f})", m.text().unwrap_or("").trim()),
        None => m.text().unwrap_or("").trim().to_string(),
    });
    match cpu.attribute("mode").unwrap_or("custom") {
        "custom" => model,
        mode => Some(match model.filter(|m| !m.is_empty()) {
            Some(m) => format!("{mode} {m}"),
            None => mode.to_string(),
        }),
    }
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
///
/// Several devices share a `tag:name` (every `<controller type='pci'>`, two
/// `<hostdev>`s): a controller is told apart by its `index`, which is its
/// identity in the definition, and anything else by its place among its
/// namesakes (`#2`, `#3`), so an added or removed one is never folded into
/// another.
fn other_devices(
    devices: Option<roxmltree::Node<'_, '_>>,
) -> std::collections::BTreeMap<String, String> {
    let mut out = std::collections::BTreeMap::new();
    let mut seen = std::collections::HashMap::<String, usize>::new();
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
        let mut key = match dev.attribute("index") {
            Some(index) => format!("{tag}:{name}:{index}"),
            None => format!("{tag}:{name}"),
        };
        let n = seen.entry(key.clone()).or_insert(0);
        *n += 1;
        if *n > 1 {
            key = format!("{key}#{n}");
        }
        out.insert(key, describe(dev, tag));
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
///
/// Every device also says the model it is (`model=` on the element, as a
/// controller or a watchdog writes it, or a `<model>` child's attributes, as
/// a video card does) and its `<backend>` (a TPM's, an RNG's); a passed-
/// through host device says which one: its vendor and product where the
/// definition names it by those (a running guest's USB device also carries
/// the bus address it was found at, which is not the configuration), its
/// address otherwise.
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
    if let Some(src) = child(dev, "source")
        && src.attribute("file").is_none() && src.attribute("dev").is_none() {
            for attr in ["volume", "pool", "dir", "name"] {
                if let Some(v) = src.attribute(attr) {
                    parts.push(v.to_string());
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
    let attrs = |n: roxmltree::Node<'_, '_>| {
        n.attributes()
            .map(|a| format!("{}={}", a.name(), a.value()))
            .collect::<Vec<_>>()
            .join(" ")
    };
    if let Some(model) = dev.attribute("model") {
        parts.push(format!("model={model}"));
    }
    if let Some(model) = child(dev, "model").filter(|m| m.attributes().len() > 0) {
        parts.push(format!("model({})", attrs(model)));
    }
    if let Some(backend) = child(dev, "backend") {
        let text = backend.text().map(str::trim).filter(|t| !t.is_empty());
        parts.push(format!("backend({}{})", attrs(backend), text.map(|t| format!(" {t}")).unwrap_or_default()));
    }
    if tag == "hostdev"
        && let Some(src) = child(dev, "source")
    {
        let named = child(src, "vendor").is_some() || child(src, "product").is_some();
        for n in src.descendants().filter(|n| n.is_element() && *n != src) {
            let name = n.tag_name().name();
            if named && name == "address" {
                continue;
            }
            parts.push(format!("{name}({})", attrs(n)));
        }
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
