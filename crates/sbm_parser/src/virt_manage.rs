//! Managing libvirt storage and networks: scripts that create, start, stop and
//! delete pools, volumes and networks, and upload a file into a volume.
//!
//! The same contract as [`crate::virt`]: pure, no I/O, POSIX `sh` fed to `sh`
//! on stdin, every value quoted with [`shell_quote_unix`] or escaped into the
//! XML a `define` reads from a temporary file. Each change is one round trip
//! of steps; the first step that fails ends the script, and what a create had
//! already made is taken back ([`KEY_RES_ROLLBACK`]), so a refused pool or
//! network leaves no definition behind.
//!
//! # Uploads
//!
//! `virsh vol-upload` reads the file on the host. The bytes reach it on the
//! command's stdin (`--file /dev/stdin`) through an exec channel that carries
//! raw bytes — an SSH session, or a local process — so they are written by
//! libvirt into any kind of pool (a directory, an LVM volume group, an NFS
//! mount) with libvirt's own ownership and labels, once, without a staging
//! copy on the host and without the SSH account needing write access to the
//! pool. See [`vol_upload_command`] for how that shares stdin with a sudo
//! password.

use crate::script::{self, shell_quote_unix};
use crate::virt::{
    CONNECT_URI, RC_PREFIX, VirtError, prelude, run_fn, sections, take, xml_escape,
};
use serde::{Deserialize, Serialize};

/// A step a change stands or falls by.
pub const KEY_RES_STEP: &str = "virt.res.step";
/// Undoing a create after a later step failed.
pub const KEY_RES_ROLLBACK: &str = "virt.res.rollback";
/// The upload itself: `vol-upload`'s output and status.
pub const KEY_UPLOAD: &str = "virt.upload";
/// The upload script read something other than [`UPLOAD_GO`] first.
pub const KEY_UPLOAD_REFUSED: &str = "virt.upload.refused";

/// The line the caller sends before the file's bytes: see
/// [`vol_upload_command`].
pub const UPLOAD_GO: &str = "SbVirtUploadGo";
/// What the upload script prints once it has read [`UPLOAD_GO`]: the bytes
/// may follow.
pub const UPLOAD_READY: &str = "SbVirtUploadReady";

/// IPv4 of a new network: the host's address on it and, optionally, what
/// dnsmasq hands out.
#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize)]
pub struct VirtNetIpv4 {
    /// The host's address, e.g. `192.168.150.1`
    pub address: String,
    pub prefix: u8,
    /// First and last address of the DHCP range; none for no DHCP
    pub dhcp_start: Option<String>,
    pub dhcp_end: Option<String>,
}

/// One change to a host's storage or networks.
#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize)]
#[serde(tag = "op", rename_all = "snake_case")]
pub enum VirtResourceOp {
    /// Defines a pool, builds it where that only makes a directory (`dir`,
    /// `netfs`: never `logical`, whose build would format devices — an
    /// existing volume group is used as it is), starts it and, when asked,
    /// marks it autostart.
    PoolCreate {
        name: String,
        /// `dir`, `netfs` or `logical`
        pool_type: String,
        /// `dir`: the directory; `netfs`: the mount point
        target: Option<String>,
        /// `netfs`: `host:/export`; `logical`: the volume group
        source: Option<String>,
        autostart: bool,
    },
    PoolStart { name: String },
    /// `pool-destroy`: stops using the pool; its volumes stay where they are
    PoolStop { name: String },
    PoolAutostart { name: String, on: bool },
    PoolRefresh { name: String },
    /// Stops the pool when `active`, deletes what it is on when
    /// `delete_storage` (`pool-delete`: an empty directory, the mount point),
    /// and undefines it
    PoolDelete {
        name: String,
        active: bool,
        delete_storage: bool,
    },
    VolCreate {
        pool: String,
        name: String,
        bytes: u64,
        /// `qcow2` or `raw`
        format: String,
    },
    VolDelete { pool: String, name: String },
    /// Grows a volume to `bytes` (`vol-resize` refuses to shrink without
    /// being told to, and is not told)
    VolResize { pool: String, name: String, bytes: u64 },
    VolClone {
        pool: String,
        name: String,
        new_name: String,
    },
    /// Defines a network, starts it, and marks it autostart when asked. A
    /// start the host refuses (an address range already in use) undefines it
    /// again.
    NetCreate {
        name: String,
        /// `nat`, `route`, `isolated` or `bridge`
        mode: String,
        /// `bridge` mode: the host bridge guests are handed to
        bridge: Option<String>,
        ipv4: Option<VirtNetIpv4>,
        autostart: bool,
    },
    NetStart { name: String },
    /// `net-destroy`: the guests on it lose their link until it starts again
    NetStop { name: String },
    NetAutostart { name: String, on: bool },
    NetDelete { name: String, active: bool },
}

/// A pool, network or bridge name: letters, digits, `.`, `_`, `-`, not
/// starting with a dot or a dash. libvirt allows more, but these names also
/// end up as directory, interface and file names.
fn is_name(s: &str) -> bool {
    !s.is_empty()
        && s.len() <= 64
        && !s.starts_with(['.', '-'])
        && s.chars().all(|c| c.is_ascii_alphanumeric() || "._-".contains(c))
}

/// A volume name: a file name in a directory pool, so no `/`; `+` as well,
/// which install images carry.
fn is_vol_name(s: &str) -> bool {
    !s.is_empty()
        && s.len() <= 200
        && !s.starts_with(['.', '-'])
        && s.chars().all(|c| c.is_ascii_alphanumeric() || "._+-".contains(c))
}

/// A Linux interface name (`IFNAMSIZ` - 1).
fn is_ifname(s: &str) -> bool {
    !s.is_empty()
        && s.len() <= 15
        && !s.starts_with('-')
        && s.chars().all(|c| c.is_ascii_alphanumeric() || "._-".contains(c))
}

/// An absolute path that is not `/` and does not climb.
fn is_dir_path(p: &str) -> bool {
    p.starts_with('/')
        && p.len() > 1
        && p.len() <= 4096
        && !p.chars().any(char::is_control)
        && !p.split('/').any(|seg| seg == "..")
}

/// `host:/export`, as `mount -t nfs` takes it.
fn split_netfs(source: &str) -> Option<(&str, &str)> {
    let (host, dir) = source.split_once(":/")?;
    let host = host.trim_start_matches('[').trim_end_matches(']');
    let host_ok = !host.is_empty()
        && host.len() <= 253
        && host.chars().all(|c| c.is_ascii_alphanumeric() || ".-:".contains(c));
    let dir = &source[source.len() - dir.len() - 1..];
    (host_ok && is_dir_path(dir)).then_some((host, dir))
}

fn ipv4(s: &str) -> Option<u32> {
    s.parse::<std::net::Ipv4Addr>().ok().map(u32::from)
}

impl VirtNetIpv4 {
    fn check(&self) -> bool {
        let Some(addr) = ipv4(&self.address) else {
            return false;
        };
        if !(8..=30).contains(&self.prefix) {
            return false;
        }
        let mask = u32::MAX << (32 - self.prefix);
        let net = addr & mask;
        let broadcast = net | !mask;
        if addr == net || addr == broadcast {
            return false;
        }
        match (&self.dhcp_start, &self.dhcp_end) {
            (None, None) => true,
            (Some(s), Some(e)) => {
                let (Some(s), Some(e)) = (ipv4(s), ipv4(e)) else {
                    return false;
                };
                s <= e
                    && s & mask == net
                    && e & mask == net
                    && s != net
                    && e != broadcast
                    && !(s..=e).contains(&addr)
            }
            _ => false,
        }
    }
}

impl VirtResourceOp {
    /// Refuses a value that would land somewhere it should not. The app
    /// checks the user's input first, so reaching here is a caller's bug and
    /// the message is for the log.
    fn check(&self) -> Result<(), VirtError> {
        let bad = |what: &str| {
            Err(VirtError::Malformed {
                message: format!("invalid storage or network change: {what}"),
            })
        };
        match self {
            VirtResourceOp::PoolCreate { name, pool_type, target, source, .. } => {
                if !is_name(name) {
                    return bad("name");
                }
                let ok = match pool_type.as_str() {
                    "dir" => target.as_deref().is_some_and(is_dir_path) && source.is_none(),
                    "netfs" => {
                        target.as_deref().is_some_and(is_dir_path)
                            && source.as_deref().and_then(split_netfs).is_some()
                    }
                    "logical" => target.is_none() && source.as_deref().is_some_and(is_name),
                    _ => false,
                };
                if !ok {
                    return bad("pool");
                }
            }
            VirtResourceOp::PoolStart { name }
            | VirtResourceOp::PoolStop { name }
            | VirtResourceOp::PoolAutostart { name, .. }
            | VirtResourceOp::PoolRefresh { name }
            | VirtResourceOp::PoolDelete { name, .. }
            | VirtResourceOp::NetStart { name }
            | VirtResourceOp::NetStop { name }
            | VirtResourceOp::NetAutostart { name, .. }
            | VirtResourceOp::NetDelete { name, .. } => {
                // Existing objects: whatever libvirt named them, one line.
                if name.is_empty() || name.chars().any(char::is_control) {
                    return bad("name");
                }
            }
            VirtResourceOp::VolCreate { pool, name, bytes, format } => {
                if pool.is_empty() || pool.chars().any(char::is_control) || !is_vol_name(name) {
                    return bad("volume");
                }
                if *bytes == 0 || *bytes > 1 << 50 || !matches!(format.as_str(), "qcow2" | "raw") {
                    return bad("size or format");
                }
            }
            VirtResourceOp::VolDelete { pool, name } | VirtResourceOp::VolResize { pool, name, .. } => {
                if pool.is_empty() || name.is_empty() || format!("{pool}{name}").chars().any(char::is_control) {
                    return bad("volume");
                }
                if let VirtResourceOp::VolResize { bytes, .. } = self
                    && (*bytes == 0 || *bytes > 1 << 50)
                {
                    return bad("size");
                }
            }
            VirtResourceOp::VolClone { pool, name, new_name } => {
                if pool.is_empty() || name.is_empty() || format!("{pool}{name}").chars().any(char::is_control) {
                    return bad("volume");
                }
                if !is_vol_name(new_name) {
                    return bad("new name");
                }
            }
            VirtResourceOp::NetCreate { name, mode, bridge, ipv4, .. } => {
                if !is_name(name) {
                    return bad("name");
                }
                let ok = match mode.as_str() {
                    "bridge" => bridge.as_deref().is_some_and(is_ifname) && ipv4.is_none(),
                    "nat" | "route" => bridge.is_none() && ipv4.as_ref().is_some_and(VirtNetIpv4::check),
                    "isolated" => bridge.is_none() && ipv4.as_ref().is_none_or(VirtNetIpv4::check),
                    _ => false,
                };
                if !ok {
                    return bad("network");
                }
            }
        }
        Ok(())
    }
}

/// The pool XML [`VirtResourceOp::PoolCreate`] defines.
pub fn pool_xml(name: &str, pool_type: &str, target: Option<&str>, source: Option<&str>) -> String {
    let e = xml_escape;
    let mut x = format!("<pool type='{}'>\n  <name>{}</name>\n", e(pool_type), e(name));
    match pool_type {
        "netfs" => {
            let (host, dir) = source.and_then(split_netfs).unwrap_or_default();
            x.push_str(&format!(
                "  <source>\n    <host name='{}'/>\n    <dir path='{}'/>\n    <format type='nfs'/>\n  </source>\n",
                e(host),
                e(dir)
            ));
        }
        "logical" => {
            let vg = source.unwrap_or_default();
            x.push_str(&format!(
                "  <source>\n    <name>{}</name>\n    <format type='lvm2'/>\n  </source>\n",
                e(vg)
            ));
        }
        _ => {}
    }
    let path = match pool_type {
        "logical" => format!("/dev/{}", source.unwrap_or_default()),
        _ => target.unwrap_or_default().to_string(),
    };
    x.push_str(&format!("  <target>\n    <path>{}</path>\n  </target>\n</pool>\n", e(&path)));
    x
}

/// The network XML [`VirtResourceOp::NetCreate`] defines. libvirt picks the
/// bridge device (`virbrN`) and its MAC for a network of its own.
pub fn network_xml(name: &str, mode: &str, bridge: Option<&str>, ipv4: Option<&VirtNetIpv4>) -> String {
    let e = xml_escape;
    let mut x = format!("<network>\n  <name>{}</name>\n", e(name));
    match mode {
        "nat" => x.push_str("  <forward mode='nat'/>\n"),
        "route" => x.push_str("  <forward mode='route'/>\n"),
        "bridge" => {
            x.push_str("  <forward mode='bridge'/>\n");
            x.push_str(&format!("  <bridge name='{}'/>\n", e(bridge.unwrap_or_default())));
        }
        _ => {}
    }
    if let Some(ip) = ipv4 {
        x.push_str(&format!("  <ip address='{}' prefix='{}'>\n", e(&ip.address), ip.prefix));
        if let (Some(s), Some(end)) = (&ip.dhcp_start, &ip.dhcp_end) {
            x.push_str(&format!(
                "    <dhcp>\n      <range start='{}' end='{}'/>\n    </dhcp>\n",
                e(s),
                e(end)
            ));
        }
        x.push_str("  </ip>\n");
    }
    x.push_str("</network>\n");
    x
}

/// A step: its failure ends the script. With `undo`, the failure first runs
/// that as the rollback.
fn step(args: &str, undo: Option<&str>) -> String {
    let mut s = format!("echo '{}'\nR {args}\n", script::cmd_marker(KEY_RES_STEP));
    match undo {
        Some(u) => s.push_str(&format!(
            "if [ \"$r\" != 0 ]; then echo '{}'; R {u}; exit 0; fi\n",
            script::cmd_marker(KEY_RES_ROLLBACK)
        )),
        None => s.push_str("[ \"$r\" = 0 ] || exit 0\n"),
    }
    s
}

/// `define --file` of `xml` through a temporary file, as a step: the script
/// is on `sh`'s stdin, which no command here may read.
fn define_step(xml: &str, command: &str) -> String {
    format!(
        "echo '{}'\nf=$(mktemp 2>&1) || {{ printf '%s\\n{RC_PREFIX}1\\n' \"$f\"; f=; r=1; }}\n\
         if [ -n \"$f\" ]; then printf '%s' {} >\"$f\"; R {command} --file \"$f\"; rm -f \"$f\"; fi\n\
         [ \"$r\" = 0 ] || exit 0\n",
        script::cmd_marker(KEY_RES_STEP),
        shell_quote_unix(xml),
    )
}

/// The script making `op`. Parse with [`parse_resource`].
pub fn resource_script(op: &VirtResourceOp) -> Result<String, VirtError> {
    op.check()?;
    let q = shell_quote_unix;
    let mut s = prelude();
    s.push_str(&run_fn());
    match op {
        VirtResourceOp::PoolCreate { name, pool_type, target, source, autostart } => {
            let p = q(name);
            let undefine = format!("pool-undefine --pool {p}");
            s.push_str(&define_step(
                &pool_xml(name, pool_type, target.as_deref(), source.as_deref()),
                "pool-define",
            ));
            if pool_type != "logical" {
                s.push_str(&step(&format!("pool-build --pool {p}"), Some(&undefine)));
            }
            s.push_str(&step(&format!("pool-start --pool {p}"), Some(&undefine)));
            if *autostart {
                s.push_str(&step(&format!("pool-autostart --pool {p}"), None));
            }
        }
        VirtResourceOp::PoolStart { name } => s.push_str(&step(&format!("pool-start --pool {}", q(name)), None)),
        VirtResourceOp::PoolStop { name } => s.push_str(&step(&format!("pool-destroy --pool {}", q(name)), None)),
        VirtResourceOp::PoolAutostart { name, on } => {
            let disable = if *on { "" } else { " --disable" };
            s.push_str(&step(&format!("pool-autostart --pool {}{disable}", q(name)), None));
        }
        VirtResourceOp::PoolRefresh { name } => s.push_str(&step(&format!("pool-refresh --pool {}", q(name)), None)),
        VirtResourceOp::PoolDelete { name, active, delete_storage } => {
            let p = q(name);
            if *active {
                s.push_str(&step(&format!("pool-destroy --pool {p}"), None));
            }
            if *delete_storage {
                s.push_str(&step(&format!("pool-delete --pool {p}"), None));
            }
            s.push_str(&step(&format!("pool-undefine --pool {p}"), None));
        }
        VirtResourceOp::VolCreate { pool, name, bytes, format } => {
            s.push_str(&step(
                &format!(
                    "vol-create-as --pool {} --name {} --capacity {bytes}B --format {format}",
                    q(pool),
                    q(name)
                ),
                None,
            ));
        }
        VirtResourceOp::VolDelete { pool, name } => {
            s.push_str(&step(&format!("vol-delete --pool {} --vol {}", q(pool), q(name)), None));
        }
        VirtResourceOp::VolResize { pool, name, bytes } => {
            s.push_str(&step(
                &format!("vol-resize --pool {} --vol {} --capacity {bytes}B", q(pool), q(name)),
                None,
            ));
        }
        VirtResourceOp::VolClone { pool, name, new_name } => {
            s.push_str(&step(
                &format!("vol-clone --pool {} --vol {} --newname {}", q(pool), q(name), q(new_name)),
                None,
            ));
        }
        VirtResourceOp::NetCreate { name, mode, bridge, ipv4, autostart } => {
            let n = q(name);
            s.push_str(&define_step(
                &network_xml(name, mode, bridge.as_deref(), ipv4.as_ref()),
                "net-define",
            ));
            s.push_str(&step(&format!("net-start --network {n}"), Some(&format!("net-undefine --network {n}"))));
            if *autostart {
                s.push_str(&step(&format!("net-autostart --network {n}"), None));
            }
        }
        VirtResourceOp::NetStart { name } => s.push_str(&step(&format!("net-start --network {}", q(name)), None)),
        VirtResourceOp::NetStop { name } => s.push_str(&step(&format!("net-destroy --network {}", q(name)), None)),
        VirtResourceOp::NetAutostart { name, on } => {
            let disable = if *on { "" } else { " --disable" };
            s.push_str(&step(&format!("net-autostart --network {}{disable}", q(name)), None));
        }
        VirtResourceOp::NetDelete { name, active } => {
            let n = q(name);
            if *active {
                s.push_str(&step(&format!("net-destroy --network {n}"), None));
            }
            s.push_str(&step(&format!("net-undefine --network {n}"), None));
        }
    }
    Ok(s)
}

/// [`resource_script`]'s output: `Ok` when every step ran, the first failed
/// step's error otherwise — with the rollback's own failure after it, since
/// then something is left behind that the user has to know about.
pub fn parse_resource(raw: &str) -> Result<(), VirtError> {
    let secs = sections(raw)?;
    let steps: Vec<_> = secs.iter().filter(|(k, _)| k == KEY_RES_STEP).collect();
    if steps.is_empty() {
        take(&secs, KEY_RES_STEP, raw)?;
    }
    for (_, sec) in steps {
        if let Err(e) = sec.ok() {
            let rollback = secs
                .iter()
                .find(|(k, _)| k == KEY_RES_ROLLBACK)
                .and_then(|(_, s)| s.ok().err());
            return Err(match rollback {
                Some(r) if !matches!(e, VirtError::PermissionDenied { .. }) => VirtError::Command {
                    message: format!("{}\n{}", e.message(), r.message()),
                },
                _ => e,
            });
        }
    }
    Ok(())
}

// ---------------------------------------------------------------------------
// Uploading into a volume
// ---------------------------------------------------------------------------

/// The volume an upload goes into: raw, exactly the file's size. Parse with
/// [`parse_resource`]; a name taken is `Exists`.
pub fn vol_upload_prepare_script(pool: &str, name: &str, bytes: u64) -> Result<String, VirtError> {
    resource_script(&VirtResourceOp::VolCreate {
        pool: pool.to_string(),
        name: name.to_string(),
        bytes,
        format: "raw".to_string(),
    })
}

/// How the upload command reaches the daemon: as this account, or through
/// sudo with or without a password, as `PrivilegedExec` decided for the
/// other scripts.
#[derive(Debug, Clone, Copy, PartialEq, Eq, Serialize, Deserialize)]
#[serde(rename_all = "snake_case")]
pub enum VirtUploadEntry {
    Direct,
    SudoNoPassword,
    SudoPassword,
}

/// The command that writes its stdin into the volume `name` of `pool`, for
/// an exec channel that carries bytes (not a script for `sh` on stdin: stdin
/// is the file). Parse its output with [`parse_vol_upload`].
///
/// The caller writes, in order: the sudo password and a newline (only with
/// [`VirtUploadEntry::SudoPassword`]), [`UPLOAD_GO`] and a newline; waits for
/// [`UPLOAD_READY`] on stdout; then the file's bytes, and closes stdin.
///
/// The go line is what keeps a password out of the volume: `sudo -S` reads
/// its password a byte at a time up to the newline, and the script reads the
/// next line itself (`read` stops at the newline too). When sudo did not ask
/// — cached credentials, `NOPASSWD` — the line it would have taken is the
/// password, the script finds it where the go line should be, and stops
/// before `virsh` runs ([`parse_vol_upload`] answers `Ok(false)`: go again
/// without a password). Nothing is written until the caller has seen
/// [`UPLOAD_READY`].
///
/// The script travels base64-encoded inside single quotes, so the command
/// line holds nothing a login shell reads differently — fish treats `\` and
/// `'` inside single quotes its own way, and names can hold both.
pub fn vol_upload_command(pool: &str, name: &str, entry: VirtUploadEntry) -> Result<String, VirtError> {
    if pool.is_empty() || name.is_empty() || format!("{pool}{name}").chars().any(char::is_control) {
        return Err(VirtError::Malformed {
            message: "invalid upload: volume".into(),
        });
    }
    let (p, v) = (shell_quote_unix(pool), shell_quote_unix(name));
    let virsh = format!("virsh --connect {CONNECT_URI} -q");
    let script = format!(
        "export LC_ALL=C\n\
         IFS= read -r l || exit 97\n\
         if [ \"$l\" != {UPLOAD_GO} ]; then echo '{refused}'; exit 97; fi\n\
         echo {UPLOAD_READY}\n\
         echo '{upload}'\n\
         {virsh} vol-upload --pool {p} --vol {v} --file /dev/stdin 2>&1; r=$?\n\
         printf '\\n{RC_PREFIX}%s\\n' \"$r\"\n\
         [ \"$r\" = 0 ] && {virsh} pool-refresh --pool {p} </dev/null >/dev/null 2>&1\n\
         exit 0\n",
        refused = script::cmd_marker(KEY_UPLOAD_REFUSED),
        upload = script::cmd_marker(KEY_UPLOAD),
    );
    use base64::Engine;
    let b64 = base64::engine::general_purpose::STANDARD.encode(script);
    let body = format!("sh -c 'eval \"$(echo {b64} | base64 -d)\"'");
    Ok(match entry {
        VirtUploadEntry::Direct => body,
        VirtUploadEntry::SudoNoPassword => format!("sudo -n {body}"),
        VirtUploadEntry::SudoPassword => format!("sudo -S -p '' {body}"),
    })
}

/// [`vol_upload_command`]'s output. `Ok(true)` when the volume has the
/// bytes; `Ok(false)` when the script stopped before `virsh` because the
/// first line was not the go line (sudo did not take the password); the
/// upload's error otherwise.
pub fn parse_vol_upload(raw: &str) -> Result<bool, VirtError> {
    let segs = script::parse_script_segments(raw);
    if segs.iter().any(|(k, _)| k == KEY_UPLOAD_REFUSED) {
        return Ok(false);
    }
    let secs = sections(raw)?;
    take(&secs, KEY_UPLOAD, raw)?.ok()?;
    Ok(true)
}

#[cfg(test)]
mod tests {
    use super::*;

    fn ip(address: &str, prefix: u8, range: Option<(&str, &str)>) -> VirtNetIpv4 {
        VirtNetIpv4 {
            address: address.into(),
            prefix,
            dhcp_start: range.map(|r| r.0.into()),
            dhcp_end: range.map(|r| r.1.into()),
        }
    }

    #[test]
    fn ipv4_checks() {
        assert!(ip("192.168.150.1", 24, Some(("192.168.150.100", "192.168.150.200"))).check());
        assert!(ip("10.0.0.1", 8, None).check());
        // The network and broadcast addresses are not the host's
        assert!(!ip("192.168.150.0", 24, None).check());
        assert!(!ip("192.168.150.255", 24, None).check());
        // The range: inside the subnet, in order, without the host's address
        assert!(!ip("192.168.150.1", 24, Some(("192.168.151.2", "192.168.151.9"))).check());
        assert!(!ip("192.168.150.1", 24, Some(("192.168.150.200", "192.168.150.100"))).check());
        assert!(!ip("192.168.150.1", 24, Some(("192.168.150.1", "192.168.150.9"))).check());
        assert!(!ip("192.168.150.1", 24, Some(("192.168.150.2", "192.168.150.255"))).check());
        assert!(!ip("192.168.150.1", 31, None).check());
        assert!(!ip("fe80::1", 64, None).check());
        assert!(!ip("192.168.150.1", 24, Some(("192.168.150.2", "x"))).check());
    }

    #[test]
    fn checks_refuse_what_would_escape() {
        let pool = |t: &str, target: Option<&str>, source: Option<&str>| VirtResourceOp::PoolCreate {
            name: "p1".into(),
            pool_type: t.into(),
            target: target.map(Into::into),
            source: source.map(Into::into),
            autostart: true,
        };
        assert!(pool("dir", Some("/var/lib/libvirt/p1"), None).check().is_ok());
        assert!(pool("dir", Some("/"), None).check().is_err());
        assert!(pool("dir", Some("/var/../etc"), None).check().is_err());
        assert!(pool("dir", Some("relative"), None).check().is_err());
        assert!(pool("netfs", Some("/mnt/p1"), Some("nas.lan:/export/vm")).check().is_ok());
        assert!(pool("netfs", Some("/mnt/p1"), Some("nas.lan/export")).check().is_err());
        assert!(pool("netfs", Some("/mnt/p1"), Some("nas;id:/x")).check().is_err());
        assert!(pool("logical", None, Some("vg_data")).check().is_ok());
        assert!(pool("logical", None, Some("../x")).check().is_err());
        assert!(pool("disk", Some("/dev"), None).check().is_err());
        let named = |n: &str| VirtResourceOp::NetCreate {
            name: n.into(),
            mode: "isolated".into(),
            bridge: None,
            ipv4: None,
            autostart: false,
        };
        assert!(named("lab-2").check().is_ok());
        for n in ["", "-x", ".x", "a b", "a'b", "a/b"] {
            assert!(named(n).check().is_err(), "{n}");
        }
        let net = |mode: &str, bridge: Option<&str>, ipv4: Option<VirtNetIpv4>| VirtResourceOp::NetCreate {
            name: "n".into(),
            mode: mode.into(),
            bridge: bridge.map(Into::into),
            ipv4,
            autostart: true,
        };
        assert!(net("nat", None, Some(ip("192.168.150.1", 24, None))).check().is_ok());
        assert!(net("nat", None, None).check().is_err());
        assert!(net("bridge", Some("br0"), None).check().is_ok());
        assert!(net("bridge", Some("br0; id"), None).check().is_err());
        assert!(net("bridge", None, None).check().is_err());
        assert!(net("open", None, None).check().is_err());
        let vol = |name: &str, format: &str| VirtResourceOp::VolCreate {
            pool: "p".into(),
            name: name.into(),
            bytes: 1 << 30,
            format: format.into(),
        };
        assert!(vol("data.qcow2", "qcow2").check().is_ok());
        assert!(vol("../x", "qcow2").check().is_err());
        assert!(vol("x", "vmdk").check().is_err());
    }

    #[test]
    fn pool_and_network_xml() {
        assert_eq!(
            pool_xml("p1", "dir", Some("/srv/p & q"), None),
            "<pool type='dir'>\n  <name>p1</name>\n  <target>\n    <path>/srv/p &amp; q</path>\n  </target>\n</pool>\n"
        );
        let nfs = pool_xml("n", "netfs", Some("/mnt/n"), Some("10.0.0.5:/export/iso"));
        assert!(nfs.contains("<host name='10.0.0.5'/>") && nfs.contains("<dir path='/export/iso'/>"), "{nfs}");
        assert!(nfs.contains("<path>/mnt/n</path>"), "{nfs}");
        let lvm = pool_xml("l", "logical", None, Some("vg_nvme"));
        assert!(lvm.contains("<name>vg_nvme</name>") && lvm.contains("<path>/dev/vg_nvme</path>"), "{lvm}");

        let nat = network_xml("lab", "nat", None, Some(&ip("192.168.150.1", 24, Some(("192.168.150.100", "192.168.150.200")))));
        assert_eq!(
            nat,
            "<network>\n  <name>lab</name>\n  <forward mode='nat'/>\n  <ip address='192.168.150.1' prefix='24'>\n    <dhcp>\n      <range start='192.168.150.100' end='192.168.150.200'/>\n    </dhcp>\n  </ip>\n</network>\n"
        );
        let iso = network_xml("i", "isolated", None, Some(&ip("172.16.9.1", 24, None)));
        assert!(!iso.contains("<forward") && !iso.contains("<dhcp>"), "{iso}");
        let br = network_xml("b", "bridge", Some("br0"), None);
        assert!(br.contains("<forward mode='bridge'/>") && br.contains("<bridge name='br0'/>"), "{br}");
        // What the parser reads back from such a definition
        let info = crate::virt::parse_network_xml(&nat).unwrap();
        assert_eq!(info.mode, "nat");
        assert_eq!(info.ips[0].cidr, "192.168.150.1/24");
        assert_eq!(info.ips[0].dhcp_ranges, vec!["192.168.150.100-192.168.150.200"]);
        let pool = crate::virt::parse_pool_xml(&nfs).unwrap();
        assert_eq!(pool.source.as_deref(), Some("10.0.0.5:/export/iso"));
        assert_eq!(pool.target.as_deref(), Some("/mnt/n"));
    }

    #[test]
    fn steps_and_rollbacks() {
        let s = resource_script(&VirtResourceOp::PoolCreate {
            name: "p1".into(),
            pool_type: "logical".into(),
            target: None,
            source: Some("vg".into()),
            autostart: false,
        })
        .unwrap();
        // An existing volume group is started, never built (formatted)
        assert!(!s.contains("pool-build") && s.contains("pool-start --pool 'p1'"), "{s}");
        assert!(!s.contains("pool-autostart"), "{s}");
        let s = resource_script(&VirtResourceOp::PoolDelete {
            name: "p1".into(),
            active: true,
            delete_storage: false,
        })
        .unwrap();
        assert!(s.contains("pool-destroy") && !s.contains("pool-delete") && s.contains("pool-undefine"), "{s}");
    }

    fn sec(key: &str, body: &str, rc: i32) -> String {
        format!("{}\n{body}\n{RC_PREFIX}{rc}\n", script::cmd_marker(key))
    }

    #[test]
    fn parse_outcomes() {
        assert_eq!(parse_resource(&sec(KEY_RES_STEP, "", 0)), Ok(()));
        let taken = sec(KEY_RES_STEP, "error: operation failed: pool 'p1' already exists with uuid 0", 1);
        assert!(matches!(parse_resource(&taken), Err(VirtError::Exists { .. })));
        // A refused start, rolled back
        let raw = [
            sec(KEY_RES_STEP, "", 0),
            sec(KEY_RES_STEP, "error: internal error: Network is already in use by interface virbr0", 1),
            sec(KEY_RES_ROLLBACK, "", 0),
        ]
        .concat();
        let e = parse_resource(&raw).unwrap_err();
        assert!(e.message().contains("already in use"), "{e:?}");
        // The rollback failed too: both said
        let raw = [
            sec(KEY_RES_STEP, "error: start refused", 1),
            sec(KEY_RES_ROLLBACK, "error: undefine refused", 1),
        ]
        .concat();
        let e = parse_resource(&raw).unwrap_err();
        assert!(e.message().contains("start refused") && e.message().contains("undefine refused"));
        // Refused as this user: sudo runs it again
        let raw = sec(KEY_RES_STEP, "error: authentication unavailable: polkit", 1);
        assert!(matches!(parse_resource(&raw), Err(VirtError::PermissionDenied { .. })));
        assert!(parse_resource("").is_err());
    }

    #[test]
    fn upload_command_is_quote_safe() {
        let hostile = "it's \"odd\" \\ $(id)";
        for entry in [VirtUploadEntry::Direct, VirtUploadEntry::SudoNoPassword, VirtUploadEntry::SudoPassword] {
            let c = vol_upload_command(hostile, hostile, entry).unwrap();
            let body = &c[c.find("sh -c '").unwrap() + 7..c.len() - 1];
            assert!(!body.contains('\'') && !body.contains('\\'), "{c}");
        }
        assert!(vol_upload_command("p", "a\nb", VirtUploadEntry::Direct).is_err());
        assert_eq!(parse_vol_upload(&sec(KEY_UPLOAD, "", 0)), Ok(true));
        assert_eq!(
            parse_vol_upload(&format!("{}\n", script::cmd_marker(KEY_UPLOAD_REFUSED))),
            Ok(false)
        );
        let full = sec(KEY_UPLOAD, "error: cannot upload: No space left on device", 1);
        assert!(matches!(parse_vol_upload(&full), Err(VirtError::Command { .. })));
    }
}
