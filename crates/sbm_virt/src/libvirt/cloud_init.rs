//! cloud-init for a libvirt domain: the NoCloud seed (`user-data`,
//! `meta-data`, `network-config`), the script fragment that makes it an ISO
//! on the host and a volume in a pool, the SHA-512 crypt that keeps a
//! password out of it, and — to edit it after creation — the seed read back
//! from its volume (an ISO 9660 reader and the subset of YAML the seed's
//! files are written in) and written anew in place.
//!
//! Pure, as the rest of the crate. Every value reaches the seed as a JSON
//! string — JSON is YAML — so nothing typed can become a key of its own, and
//! is checked besides ([`VirtCloudInit::check`]).
//!
//! # The password
//!
//! Only a SHA-512 crypt hash (`$6$…`) is ever in the seed: the caller hashes
//! the password in-process with [`sha512_crypt`] and a salt of its own
//! drawing, so the plain text never reaches the host, a command line, a
//! script or a file. The seed's files are written by `printf` (a shell
//! builtin: no process, no argv) into a `mktemp -d` directory (0700, files
//! 0600), which the script removes on every way out.

use sbm_parser::script::{self, shell_quote_unix};
use crate::libvirt::{CONNECT_URI, RC_PREFIX, VirtError};
use serde::{Deserialize, Serialize};
use sha2::{Digest, Sha512};

/// The ISO was written: the tool's output and status.
pub const KEY_SEED_ISO: &str = "virt.seed.iso";
/// No ISO tool on the host.
pub const KEY_SEED_NO_TOOL: &str = "virt.seed.no_tool";
/// The seed's volume created, filled and its path read.
pub const KEY_SEED_VOL: &str = "virt.seed.vol";
pub const KEY_SEED_UPLOAD: &str = "virt.seed.upload";
pub const KEY_SEED_PATH: &str = "virt.seed.path";
/// Which ISO tool the host has ([`seed_tool_probe`]).
pub const KEY_SEED_TOOL: &str = "virt.seed.tool";

/// The ISO tools tried, in order: `genisoimage` (Debian, Ubuntu), `xorriso`
/// (its `-as mkisofs` mode), `mkisofs` (often one of the two by another
/// name), and `cloud-localds` (cloud-image-utils, itself a wrapper of one of
/// them).
pub const SEED_TOOLS: &[&str] = &["genisoimage", "xorriso", "mkisofs", "cloud-localds"];

/// The domain metadata element naming a domain's own seed volume, so that
/// deleting the domain deletes it and nothing else
/// ([`crate::libvirt::VirtDomainXml::seed`]).
pub const SEED_METADATA_NS: &str = "https://serverbox.app/xmlns/libvirt/cloud-init/1";
pub const SEED_METADATA_ELEMENT: &str = "cloud-init";

/// Static IPv4 of the one NIC; none is DHCP.
#[derive(Debug, Clone, Default, PartialEq, Eq, Serialize, Deserialize)]
pub struct VirtCiIpv4 {
    /// `10.0.0.5/24`
    pub address: String,
    pub gateway: Option<String>,
}

/// One NIC's configuration, matched by its MAC.
///
/// A seed may describe more than one (`network-config`'s `ethernets`), which
/// is how a guest with two interfaces is given an address on both. The
/// first is the one the form edits; the rest are kept as they are, and the
/// file is written with all of them.
#[derive(Debug, Clone, Default, PartialEq, Eq, Serialize, Deserialize)]
pub struct VirtCiNetwork {
    pub mac: String,
    /// None: DHCP
    pub ipv4: Option<VirtCiIpv4>,
    #[serde(default)]
    pub dns: Vec<String>,
    /// The search domains, in order. cloud-init takes a list; `resolv.conf`
    /// keeps the first few.
    #[serde(default)]
    pub search: Vec<String>,
}

/// What a new domain's cloud-init is told.
#[derive(Clone, Default, PartialEq, Eq, Serialize, Deserialize)]
pub struct VirtCloudInit {
    /// The account made, with sudo and no password asked for it
    pub user: String,
    /// A SHA-512 crypt hash ([`sha512_crypt`]); none leaves the account
    /// without a password (keys only)
    pub password_hash: Option<String>,
    #[serde(default)]
    pub ssh_keys: Vec<String>,
    pub hostname: String,
    /// New per domain, so cloud-init runs its first boot for it
    pub instance_id: String,
    /// None: no NIC, no network-config
    pub network: Option<VirtCiNetwork>,
    /// The NICs after the first: written to the seed's `network-config` and
    /// not edited by the form. Empty for the common one-NIC guest.
    #[serde(default)]
    pub extra_networks: Vec<VirtCiNetwork>,
    /// The account's password expires, so the first login has to change it
    /// (cloud-init's `chpasswd: expire:`). PVE always writes `expire: false`
    /// and has no option for it, so this is libvirt's own.
    #[serde(default)]
    pub password_expire: bool,
}

/// Leaves the hash out: this is printed in test failures and logs.
impl std::fmt::Debug for VirtCloudInit {
    fn fmt(&self, f: &mut std::fmt::Formatter<'_>) -> std::fmt::Result {
        f.debug_struct("VirtCloudInit")
            .field("user", &self.user)
            .field("password_hash", &self.password_hash.as_ref().map(|_| "[redacted]"))
            .field("ssh_keys", &self.ssh_keys)
            .field("hostname", &self.hostname)
            .field("instance_id", &self.instance_id)
            .field("network", &self.network)
            .finish()
    }
}

/// A DNS name: labels of letters, digits and inner `-`, dot-separated.
pub fn is_dns_name(s: &str) -> bool {
    !s.is_empty()
        && s.len() <= 253
        && s.split('.').all(|l| {
            !l.is_empty()
                && l.len() <= 63
                && l.chars().all(|c| c.is_ascii_alphanumeric() || c == '-')
                && !l.starts_with('-')
                && !l.ends_with('-')
        })
}

/// A Linux account name as `useradd` takes it by default.
pub fn is_user_name(s: &str) -> bool {
    let mut chars = s.chars();
    s.len() <= 32
        && chars.next().is_some_and(|c| c.is_ascii_lowercase() || c == '_')
        && chars.all(|c| c.is_ascii_lowercase() || c.is_ascii_digit() || c == '_' || c == '-')
}

fn is_ipv4(s: &str) -> bool {
    s.parse::<std::net::Ipv4Addr>().is_ok()
}

fn is_cidr4(s: &str) -> bool {
    s.split_once('/')
        .is_some_and(|(a, p)| is_ipv4(a) && p.parse::<u8>().is_ok_and(|p| (1..=32).contains(&p)))
}

fn is_crypt_hash(s: &str) -> bool {
    let Some(rest) = s.strip_prefix("$6$") else {
        return false;
    };
    let Some((salt, hash)) = rest.split_once('$') else {
        return false;
    };
    let b64 = |x: &str| x.bytes().all(|b| ITOA64.contains(&b));
    (1..=16).contains(&salt.len()) && b64(salt) && hash.len() == 86 && b64(hash)
}

impl VirtCloudInit {
    /// Refuses a value no seed should carry. The app checks what is typed
    /// first; this is the last line before a host.
    pub fn check(&self) -> Result<(), VirtError> {
        let bad = |what: &str| {
            Err(VirtError::Malformed {
                message: format!("invalid cloud-init: {what}"),
            })
        };
        if !is_user_name(&self.user) || self.user.is_empty() {
            return bad("user");
        }
        if self.password_hash.as_deref().is_some_and(|h| !is_crypt_hash(h)) {
            return bad("password hash");
        }
        if self
            .ssh_keys
            .iter()
            .any(|k| k.trim().is_empty() || k.len() > 16 << 10 || k.chars().any(char::is_control))
        {
            return bad("ssh key");
        }
        if !is_dns_name(&self.hostname) {
            return bad("hostname");
        }
        if self.instance_id.is_empty()
            || self.instance_id.len() > 128
            || !self.instance_id.chars().all(|c| c.is_ascii_alphanumeric() || "._-".contains(c))
        {
            return bad("instance id");
        }
        let mut macs = std::collections::HashSet::new();
        for n in self.networks() {
            let mac_ok = n.mac.split(':').count() == 6
                && n.mac.split(':').all(|p| p.len() == 2 && p.chars().all(|c| c.is_ascii_hexdigit()));
            if !mac_ok || !macs.insert(n.mac.to_ascii_lowercase()) {
                return bad("mac");
            }
            if let Some(ip) = &n.ipv4
                && (!is_cidr4(&ip.address) || ip.gateway.as_deref().is_some_and(|g| !is_ipv4(g)))
            {
                return bad("ipv4");
            }
            if n.dns.iter().any(|d| d.parse::<std::net::IpAddr>().is_err()) {
                return bad("dns");
            }
            if n.search.iter().any(|d| !is_dns_name(d)) {
                return bad("search domain");
            }
        }
        Ok(())
    }

    /// Every NIC the seed describes, the edited one first.
    pub fn networks(&self) -> impl Iterator<Item = &VirtCiNetwork> {
        self.network.iter().chain(self.extra_networks.iter())
    }

    /// `user-data`: the account, its password hash and keys, the hostname.
    ///
    /// The account is the image's default user under the name asked for
    /// (`user:`, as PVE's own cloud-init writes it), so its shell, groups
    /// and sudo or doas are what the distribution gives that user: a
    /// `users:` entry of the app's own with `shell: /bin/bash` made an
    /// account sshd refused on Alpine, which has no bash (verified,
    /// Alpine 3.23). Passwordless sudo is asked for all the same, as every
    /// default user here has it.
    pub fn user_data(&self) -> String {
        let j = json;
        let mut s = String::from("#cloud-config\n");
        s.push_str(&format!("hostname: {}\n", j(&self.hostname)));
        s.push_str("manage_etc_hosts: true\n");
        s.push_str("user:\n");
        s.push_str(&format!("  name: {}\n", j(&self.user)));
        s.push_str("  sudo: \"ALL=(ALL) NOPASSWD:ALL\"\n");
        match &self.password_hash {
            Some(h) => {
                s.push_str("  lock_passwd: false\n");
                s.push_str(&format!("  hashed_passwd: {}\n", j(h)));
            }
            None => s.push_str("  lock_passwd: true\n"),
        }
        let keys: Vec<&str> = self.ssh_keys.iter().map(|k| k.trim()).filter(|k| !k.is_empty()).collect();
        if !keys.is_empty() {
            s.push_str("  ssh_authorized_keys:\n");
            for k in keys {
                s.push_str(&format!("    - {}\n", j(k)));
            }
        }
        // A password is for logging in with; images ship with SSH password
        // logins off.
        s.push_str(&format!("ssh_pwauth: {}\n", self.password_hash.is_some()));
        // The first login with the password has to set a new one.
        // cloud-init's `chpasswd: expire:` expires only the passwords
        // `chpasswd` itself set (`cc_set_passwords`), not a `hashed_passwd`,
        // so the same hash is set there too, for this account. A cloud-init
        // older than `chpasswd: users:` (22.3) ignores it and still has the
        // password from `hashed_passwd`, unexpired.
        if let Some(h) = &self.password_hash
            && self.password_expire
        {
            s.push_str("chpasswd:\n  expire: true\n  users:\n");
            s.push_str(&format!("    - name: {}\n", j(&self.user)));
            s.push_str(&format!("      password: {}\n", j(h)));
            s.push_str("      type: hash\n");
        }
        s
    }

    pub fn meta_data(&self) -> String {
        format!(
            "instance-id: {}\nlocal-hostname: {}\n",
            json(&self.instance_id),
            json(&self.hostname)
        )
    }

    /// Network config version 2 for the NICs, each found by its MAC; none
    /// without a NIC.
    ///
    /// `nic0`, `nic1`, … by order. The one-NIC output is byte for byte what
    /// it always was: the name and the indentation of the first entry do not
    /// change when a second appears.
    pub fn network_config(&self) -> Option<String> {
        self.network.as_ref()?;
        let j = json;
        let mut s = String::from("version: 2\nethernets:\n");
        for (i, n) in self.networks().enumerate() {
            s.push_str(&format!("  nic{i}:\n"));
            s.push_str(&format!("    match:\n      macaddress: {}\n", j(&n.mac.to_ascii_lowercase())));
            match &n.ipv4 {
                None => s.push_str("    dhcp4: true\n"),
                Some(ip) => {
                    s.push_str("    dhcp4: false\n");
                    s.push_str(&format!("    addresses: [{}]\n", j(&ip.address)));
                    if let Some(gw) = &ip.gateway {
                        // `to: default` needs a newer cloud-init than this.
                        s.push_str(&format!("    routes:\n      - to: \"0.0.0.0/0\"\n        via: {}\n", j(gw)));
                    }
                }
            }
            if !n.dns.is_empty() || !n.search.is_empty() {
                let list = |v: &[String]| v.iter().map(|x| j(x)).collect::<Vec<_>>().join(", ");
                s.push_str("    nameservers:\n");
                if !n.dns.is_empty() {
                    s.push_str(&format!("      addresses: [{}]\n", list(&n.dns)));
                }
                if !n.search.is_empty() {
                    s.push_str(&format!("      search: [{}]\n", list(&n.search)));
                }
            }
        }
        Some(s)
    }
}

fn json(s: &str) -> String {
    serde_json::Value::String(s.to_string()).to_string()
}

/// Prints which of [`SEED_TOOLS`] the host has, the first found, in a
/// section of its own; parse with [`parse_seed_tool`].
pub fn seed_tool_probe() -> String {
    format!(
        "echo '{}'\nfor t in {}; do if command -v \"$t\" >/dev/null 2>&1; then echo \"$t\"; break; fi; done\n",
        script::cmd_marker(KEY_SEED_TOOL),
        SEED_TOOLS.join(" ")
    )
}

/// [`seed_tool_probe`]'s section: the tool, or none.
pub fn parse_seed_tool(segments: &[(String, String)]) -> Option<String> {
    let body = segments.iter().find(|(k, _)| k == KEY_SEED_TOOL)?.1.trim();
    SEED_TOOLS.contains(&body).then(|| body.to_string())
}

/// Whether `tools` is a usable ISO tool order: some of [`SEED_TOOLS`], none
/// twice. The order is [`SEED_TOOLS`]' unless a caller narrows it (the
/// end-to-end tests make a seed with each tool in turn).
pub fn check_tools<S: AsRef<str>>(tools: &[S]) -> Result<(), VirtError> {
    let known = tools.iter().all(|t| SEED_TOOLS.contains(&t.as_ref()));
    let unique = tools.iter().enumerate().all(|(i, t)| !tools[..i].iter().any(|u| u.as_ref() == t.as_ref()));
    if tools.is_empty() || !known || !unique {
        return Err(VirtError::Malformed {
            message: "invalid cloud-init seed tools".into(),
        });
    }
    Ok(())
}

/// The staging directory `$d`: 0700 from `mktemp`, the files in it 0600 by
/// the umask, and removed however the script ends. A `mktemp` that fails is
/// the current section's error; `fail` runs before the script stops.
fn staging(fail: &str) -> String {
    format!(
        "d=$(umask 077; mktemp -d 2>&1) || {{ printf '%s\\n{RC_PREFIX}1\\n' \"$d\"; d=; {fail}exit 0; }}\n\
         trap 'rm -rf -- \"$d\"' EXIT\ntrap 'rm -rf -- \"$d\"; exit 1' HUP INT TERM\n"
    )
}

/// The seed's files in `$d` ([`staging`]), and `$d/seed.iso` made of them by
/// the first of `tools` the host has, its output and status the current
/// section's. `fail` runs before the script stops: when a file cannot be
/// written whole (a full disk: an ISO of a cut-short `user-data` would
/// replace a good seed), when the tool fails, or when there is none (a
/// [`KEY_SEED_NO_TOOL`] section then). `tools` is checked ([`check_tools`]).
fn iso_script(ci: &VirtCloudInit, tools: &[&str], fail: &str) -> String {
    let q = shell_quote_unix;
    let mut files = format!(
        "umask 077 && printf '%s' {} >\"$d/user-data\" && printf '%s' {} >\"$d/meta-data\"",
        q(&ci.user_data()),
        q(&ci.meta_data())
    );
    if let Some(n) = ci.network_config() {
        files.push_str(&format!(" && printf '%s' {} >\"$d/network-config\"", q(&n)));
    }
    let mut s = format!(
        "out=$( ({files}) 2>&1) || {{ printf '%s\\n{RC_PREFIX}1\\n' \"${{out:-writing the seed files failed}}\"; {fail}exit 0; }}\n"
    );
    let net = if ci.network.is_some() { " network-config" } else { "" };
    let net_ld = if ci.network.is_some() { "-N network-config " } else { "" };
    let mkisofs = format!("-output seed.iso -volid cidata -joliet -rock user-data meta-data{net}");
    for (i, tool) in tools.iter().enumerate() {
        let run = match *tool {
            "genisoimage" => format!("genisoimage -quiet {mkisofs}"),
            "xorriso" => format!("xorriso -as mkisofs -quiet {mkisofs}"),
            "mkisofs" => format!("mkisofs -quiet {mkisofs}"),
            _ => format!("cloud-localds {net_ld}seed.iso user-data meta-data"),
        };
        s.push_str(&format!(
            "{} command -v {tool} >/dev/null 2>&1; then out=$(cd \"$d\" && {run} 2>&1); r=$?\n",
            if i == 0 { "if" } else { "elif" }
        ));
    }
    s.push_str(&format!(
        "else echo '{}'; {fail}exit 0; fi\nprintf '%s\\n{RC_PREFIX}%s\\n' \"$out\" \"$r\"\n\
         if [ \"$r\" != 0 ]; then {fail}exit 0; fi\n",
        script::cmd_marker(KEY_SEED_NO_TOOL)
    ));
    s
}

/// The seed as an ISO on the host, then a raw volume `volume` of `pool`
/// holding it (`vol-create-as` of its size, `vol-upload`), then its path in
/// `$seed`. Written for [`crate::libvirt::create_volume_script`], after the
/// disk was made: `rollback` is the shell that takes the disk back, run when
/// any step here fails, and the seed's volume is deleted as well once made.
/// `R` is the script's virsh wrapper (status in `$r`). `tools` is the ISO
/// tools tried, in order ([`check_tools`]).
pub fn seed_script(
    ci: &VirtCloudInit,
    pool: &str,
    volume: &str,
    rollback: &str,
    tools: &[&str],
) -> Result<String, VirtError> {
    ci.check()?;
    check_tools(tools)?;
    let q = shell_quote_unix;
    let m = script::cmd_marker;
    let (pool, vol) = (q(pool), q(volume));
    let del_seed = format!("virsh --connect {CONNECT_URI} -q vol-delete --pool {pool} --vol {vol} </dev/null >/dev/null 2>&1");
    let mut s = format!("echo '{}'\n", m(KEY_SEED_ISO));
    s.push_str(&staging(rollback));
    s.push_str(&iso_script(ci, tools, rollback));
    s.push_str(&format!(
        "echo '{v}'\nsize=$(wc -c <\"$d/seed.iso\" | tr -d ' ')\n\
         R vol-create-as --pool {pool} --name {vol} --capacity \"${{size}}B\" --format raw\n\
         if [ \"$r\" != 0 ]; then {rollback}exit 0; fi\n\
         echo '{u}'\nR vol-upload --pool {pool} --vol {vol} --file \"$d/seed.iso\"\n\
         if [ \"$r\" != 0 ]; then {del_seed}; {rollback}exit 0; fi\n\
         echo '{p}'\nR vol-path --pool {pool} --vol {vol}\n\
         if [ \"$r\" != 0 ]; then {del_seed}; {rollback}exit 0; fi\n\
         rm -rf -- \"$d\"\n",
        v = m(KEY_SEED_VOL),
        u = m(KEY_SEED_UPLOAD),
        p = m(KEY_SEED_PATH),
    ));
    Ok(s)
}

// ---------------------------------------------------------------------------
// Reading a seed back, and writing it anew
// ---------------------------------------------------------------------------

/// The seed volume as the host has it, and its `cksum`.
pub const KEY_SEED_READ: &str = "virt.seed.read";
pub const KEY_SEED_SUM: &str = "virt.seed.sum";
/// The seed's bytes, base64.
pub const KEY_SEED_DATA: &str = "virt.seed.data";
/// The seed as it was before an update, kept to put back.
pub const KEY_SEED_BACKUP: &str = "virt.seed.backup";
/// The seed changed since it was read.
pub const KEY_SEED_CONFLICT: &str = "virt.seed.conflict";
pub const KEY_SEED_INFO: &str = "virt.seed.info";
pub const KEY_SEED_GROW: &str = "virt.seed.grow";
/// A failed upload, and the old seed written back.
pub const KEY_SEED_RESTORE: &str = "virt.seed.restore";

/// Narrows `$size` to the ISO 9660 image at the start of `$d/seed.iso`: its
/// volume space size (the primary volume descriptor at sector 16, bytes
/// 80..84, little-endian) times its logical block size (bytes 128..130). A
/// seed on a block device is the whole device — an LV of a `logical` pool is
/// 4 MiB at the least, the extent size — and the image is only its start;
/// the bytes after it are nothing the system reads. Read byte by byte, so
/// the host's own byte order does not matter. Left as it is where the
/// header says nothing sensible.
const ISO_SIZE_SH: &str = "set -- $(od -An -tu1 -j 32848 -N 4 <\"$d/seed.iso\" 2>/dev/null) \
     $(od -An -tu1 -j 32896 -N 2 <\"$d/seed.iso\" 2>/dev/null)\n\
     if [ $# = 6 ]; then iso=$(( ($1 + $2 * 256 + $3 * 65536 + $4 * 16777216) * ($5 + $6 * 256) )); \
     if [ \"$iso\" -gt 0 ] && [ \"$iso\" -le \"$size\" ]; then size=$iso; fi; fi\n";

/// The largest seed read back. The app's are about 370 KiB (the tools pad
/// an ISO to 150 sectors and more); the cap keeps the base64 (4/3 of it)
/// under the 1 MiB a monitor agent returns at the least.
const SEED_READ_MAX: u64 = 640 << 10;

fn check_seed_path(path: &str) -> Result<(), VirtError> {
    if !path.starts_with('/') || path.contains("/../") || path.chars().any(char::is_control) {
        return Err(VirtError::Malformed {
            message: "invalid seed path".into(),
        });
    }
    Ok(())
}

/// The domain's seed at `seed` (its path, as the domain's metadata names
/// it), downloaded from its volume into a staging directory, its `cksum`
/// and its bytes as base64. Parse with [`parse_seed_read`].
pub fn seed_read_script(seed: &str) -> Result<String, VirtError> {
    check_seed_path(seed)?;
    let m = script::cmd_marker;
    let seed = shell_quote_unix(seed);
    let mut s = crate::libvirt::prelude();
    s.push_str(&crate::libvirt::run_fn());
    s.push_str(&format!("echo '{}'\n", m(KEY_SEED_READ)));
    s.push_str(&staging(""));
    s.push_str(&format!(
        "R vol-download --vol {seed} --file \"$d/seed.iso\"\n[ \"$r\" = 0 ] || exit 0\n\
         echo '{sum}'\nout=$(cksum <\"$d/seed.iso\" 2>&1); r=$?; printf '%s\\n{RC_PREFIX}%s\\n' \"$out\" \"$r\"\n\
         [ \"$r\" = 0 ] || exit 0\n\
         echo '{data}'\nsize=$(wc -c <\"$d/seed.iso\" | tr -d ' ')\n\
         {iso_size}         if [ \"$size\" -gt {SEED_READ_MAX} ]; then printf 'seed too large: %s bytes\\n{RC_PREFIX}1\\n' \"$size\"; exit 0; fi\n\
         head -c \"$size\" <\"$d/seed.iso\" | base64; printf '\\n{RC_PREFIX}%s\\n' \"$?\"\n",
        iso_size = ISO_SIZE_SH,
        sum = m(KEY_SEED_SUM),
        data = m(KEY_SEED_DATA),
    ));
    Ok(s)
}

/// A seed as read back ([`seed_read_script`]).
#[derive(Debug, Clone, Default, PartialEq, Eq, Serialize, Deserialize)]
pub struct VirtSeedRead {
    /// What the seed says, in the form the app writes it. What it lacks is
    /// empty: no user, no hostname, no network.
    pub cloud_init: VirtCloudInit,
    /// The seed holds settings the app does not write, or writes otherwise:
    /// a new one replaces them.
    pub foreign: bool,
    /// The seed's `cksum` as read: an update made from it is refused once
    /// the seed has changed ([`seed_update_script`]).
    pub revision: String,
}

/// [`seed_read_script`]'s output.
pub fn parse_seed_read(raw: &str) -> Result<VirtSeedRead, VirtError> {
    use base64::Engine;
    let secs = crate::libvirt::sections(raw)?;
    crate::libvirt::take(&secs, KEY_SEED_READ, raw)?.ok()?;
    let revision = crate::libvirt::take(&secs, KEY_SEED_SUM, raw)?.ok()?.trim().to_string();
    let data: String = crate::libvirt::take(&secs, KEY_SEED_DATA, raw)?
        .ok()?
        .chars()
        .filter(|c| !c.is_ascii_whitespace())
        .collect();
    let bytes = base64::engine::general_purpose::STANDARD
        .decode(data)
        .map_err(|e| VirtError::Malformed {
            message: format!("cloud-init seed: {e}"),
        })?;
    let mut read = parse_seed(&iso_root_files(&bytes)?);
    read.revision = revision;
    Ok(read)
}

/// The seed at `seed` rewritten with `ci`, in place: the domain keeps the
/// volume and the path its metadata names. Parse with [`parse_seed_update`].
///
/// Made from the read whose `cksum` is `revision`: a seed changed since is
/// left as it is ([`VirtError::Conflict`]). The old seed is downloaded
/// first; the new ISO is made as at creation ([`seed_script`]), the volume
/// grown when it is bigger (a file would grow by itself, a logical volume
/// would not), then uploaded over it — and a failed upload puts the old one
/// back. A shorter ISO leaves the old one's tail after it, which nothing
/// reads: an ISO 9660 image says its own size.
///
/// All of it — the download, the check, the upload and the one put back —
/// holds a lock on the host for this seed ([`SEED_LOCK_SH`]): two updates
/// of one seed at once would each pass the check against the same read,
/// and the one whose upload failed would put its old seed back over the
/// other's new one.
pub fn seed_update_script(seed: &str, revision: &str, ci: &VirtCloudInit, tools: &[&str]) -> Result<String, VirtError> {
    check_seed_path(seed)?;
    ci.check()?;
    check_tools(tools)?;
    if revision.is_empty() || revision.chars().any(|c| !(c.is_ascii_digit() || c == ' ')) {
        return Err(VirtError::Malformed {
            message: "invalid seed revision".into(),
        });
    }
    let q = shell_quote_unix;
    let m = script::cmd_marker;
    let seed = q(seed);
    let mut s = crate::libvirt::prelude();
    s.push_str(&crate::libvirt::run_fn());
    s.push_str(&format!("echo '{}'\n", m(KEY_SEED_BACKUP)));
    s.push_str(&staging(""));
    s.push_str(&format!(
        "seed={seed}\n{lock}",
        lock = SEED_LOCK_SH.replace("{RC}", RC_PREFIX).replace("{CONFLICT}", &m(KEY_SEED_CONFLICT)),
    ));
    s.push_str(&format!(
        "R vol-download --vol {seed} --file \"$d/old.iso\"\n[ \"$r\" = 0 ] || exit 0\n\
         if [ \"$(cksum <\"$d/old.iso\")\" != {rev} ]; then echo '{conflict}'; exit 0; fi\n\
         echo '{iso}'\n",
        rev = q(revision),
        conflict = m(KEY_SEED_CONFLICT),
        iso = m(KEY_SEED_ISO),
    ));
    s.push_str(&iso_script(ci, tools, ""));
    s.push_str(&format!(
        "echo '{info}'\nsize=$(wc -c <\"$d/seed.iso\" | tr -d ' ')\n\
         out=$(virsh --connect {CONNECT_URI} -q vol-info --bytes --vol {seed} </dev/null 2>&1); r=$?\n\
         printf '%s\\n{RC_PREFIX}%s\\n' \"$out\" \"$r\"\n[ \"$r\" = 0 ] || exit 0\n\
         cap=$(printf '%s\\n' \"$out\" | sed -n 's/^Capacity: *\\([0-9][0-9]*\\) bytes$/\\1/p')\n\
         if [ \"${{cap:-0}}\" -lt \"$size\" ]; then echo '{grow}'; R vol-resize --vol {seed} --capacity \"${{size}}B\"; [ \"$r\" = 0 ] || exit 0; fi\n\
         echo '{upload}'\nR vol-upload --vol {seed} --file \"$d/seed.iso\"\n\
         if [ \"$r\" != 0 ]; then echo '{restore}'; R vol-upload --vol {seed} --file \"$d/old.iso\"; fi\n",
        info = m(KEY_SEED_INFO),
        grow = m(KEY_SEED_GROW),
        upload = m(KEY_SEED_UPLOAD),
        restore = m(KEY_SEED_RESTORE),
    ));
    Ok(s)
}

/// Takes the lock of the seed at `$seed` as fd 9, held until the script
/// ends: `flock(1)` (util-linux, and busybox's) on a file in the temporary
/// directory named by the path's `cksum`. A lock dies with its process, so
/// an update cut short leaves none behind. Waits a minute for an update
/// under way, then reads as a conflict, which by then it is. Updates by
/// different accounts of the host do not see each other's locks (each
/// file is its creator's alone); the app reaches a host as one.
const SEED_LOCK_SH: &str = "lock=\"${TMPDIR:-/tmp}/sbm-seed-$(printf '%s' \"$seed\" | cksum | tr ' ' -).lock\"\n\
     command -v flock >/dev/null 2>&1 || { printf 'flock not found on the host\\n{RC}1\\n'; exit 0; }\n\
     { (umask 077; : >>\"$lock\") && command exec 9>>\"$lock\"; } 2>/dev/null \
     || { printf 'cannot open %s\\n{RC}1\\n' \"$lock\"; exit 0; }\n\
     n=0; until flock -n 9; do n=$((n + 1)); [ \"$n\" -lt 60 ] || { echo '{CONFLICT}'; exit 0; }; sleep 1; done\n";

/// [`seed_update_script`]'s output: `Conflict` when the seed changed since
/// it was read; the host's words for a step that failed, and whether the old
/// seed is back when the upload did.
pub fn parse_seed_update(raw: &str) -> Result<(), VirtError> {
    let segs = script::parse_script_segments(raw);
    let secs = crate::libvirt::sections(raw)?;
    // Before the backup's own status: a lock not had in time is a conflict
    // said before the download ran.
    if segs.iter().any(|(k, _)| k == KEY_SEED_CONFLICT) {
        return Err(VirtError::Conflict {
            message: "The cloud-init seed changed since it was read".into(),
        });
    }
    crate::libvirt::take(&secs, KEY_SEED_BACKUP, raw)?.ok()?;
    if segs.iter().any(|(k, _)| k == KEY_SEED_NO_TOOL) {
        return Err(no_tool_error());
    }
    crate::libvirt::take(&secs, KEY_SEED_ISO, raw)?.ok()?;
    crate::libvirt::take(&secs, KEY_SEED_INFO, raw)?.ok()?;
    if let Some((_, grow)) = secs.iter().find(|(k, _)| k == KEY_SEED_GROW) {
        grow.ok()?;
    }
    let upload = crate::libvirt::take(&secs, KEY_SEED_UPLOAD, raw)?.ok();
    match (upload, secs.iter().find(|(k, _)| k == KEY_SEED_RESTORE)) {
        (Ok(_), _) => Ok(()),
        (Err(e), Some((_, restore))) => Err(VirtError::Command {
            message: match restore.ok() {
                Ok(_) => format!("{}\nThe previous cloud-init seed was put back.", e.message()),
                Err(r) => format!(
                    "{}\nPutting the previous cloud-init seed back failed too: {}",
                    e.message(),
                    r.message()
                ),
            },
        }),
        (Err(e), None) => Err(e),
    }
}

/// A host with none of [`SEED_TOOLS`].
pub(crate) fn no_tool_error() -> VirtError {
    VirtError::Command {
        message: format!(
            "No tool to make a cloud-init seed ISO on the host: install one of {}",
            SEED_TOOLS.join(", ")
        ),
    }
}

// ---------------------------------------------------------------------------
// ISO 9660: the files in a seed's root directory
// ---------------------------------------------------------------------------

const SECTOR: usize = 2048;

fn iso_err(what: &str) -> VirtError {
    VirtError::Malformed {
        message: format!("cloud-init seed: {what}"),
    }
}

fn le32(b: &[u8], at: usize) -> Result<usize, VirtError> {
    b.get(at..at + 4)
        .map(|x| u32::from_le_bytes([x[0], x[1], x[2], x[3]]) as usize)
        .ok_or_else(|| iso_err("truncated"))
}

/// `len` bytes of `iso` from sector `lba`: the fields are the image's own,
/// so the arithmetic is checked — on a 32-bit target `lba * 2048` of a
/// `u32` overflows `usize`, and a wrapped offset would be some other, valid,
/// part of the image.
fn extent<'a>(iso: &'a [u8], lba: usize, len: usize, what: &str) -> Result<&'a [u8], VirtError> {
    lba.checked_mul(SECTOR)
        .and_then(|start| Some(start..start.checked_add(len)?))
        .and_then(|range| iso.get(range))
        .ok_or_else(|| iso_err(&format!("{what} out of range")))
}

/// The regular files in an ISO 9660 image's root directory, by the names a
/// seed's files have: Joliet's where the image has them, else Rock Ridge's
/// (`NM`). Every seed tool here writes both (`-joliet -rock`); an image with
/// neither has only 8.3 names, which no seed file has.
///
/// The files are borrowed from `iso`, not copied: records may name the same
/// extent any number of times, and a copy each would turn an image under the
/// read cap ([`SEED_READ_MAX`]) into gigabytes.
pub fn iso_root_files(iso: &[u8]) -> Result<Vec<(String, &[u8])>, VirtError> {
    // Volume descriptors from sector 16 to the terminator.
    let mut primary = None;
    let mut joliet = None;
    for n in 16..64 {
        let d = iso.get(n * SECTOR..(n + 1) * SECTOR).ok_or_else(|| iso_err("no volume descriptor"))?;
        if &d[1..6] != b"CD001" {
            return Err(iso_err("not an ISO 9660 image"));
        }
        match d[0] {
            1 => primary = Some(d),
            // A supplementary descriptor with a UCS-2 escape is Joliet.
            2 if matches!(&d[88..91], b"%/@" | b"%/C" | b"%/E") => joliet = Some(d),
            255 => break,
            _ => {}
        }
    }
    let (desc, ucs2) = match (joliet, primary) {
        (Some(j), _) => (j, true),
        (None, Some(p)) => (p, false),
        (None, None) => return Err(iso_err("no primary volume descriptor")),
    };
    let root = &desc[156..190];
    let dir = extent(iso, le32(root, 2)?, le32(root, 10)?, "root directory")?;
    let mut out = Vec::new();
    let mut at = 0;
    while at < dir.len() {
        let rec_len = dir[at] as usize;
        if rec_len == 0 {
            // Records do not cross sectors: the rest of this one is padding.
            at = (at / SECTOR + 1) * SECTOR;
            continue;
        }
        let rec = dir.get(at..at + rec_len).ok_or_else(|| iso_err("directory record out of range"))?;
        at += rec_len;
        if rec.len() < 34 {
            return Err(iso_err("short directory record"));
        }
        let name_len = rec[32] as usize;
        let raw_name = rec.get(33..33 + name_len).ok_or_else(|| iso_err("name out of range"))?;
        // `.` and `..`, and directories.
        if name_len == 1 && raw_name[0] <= 1 || rec[25] & 2 != 0 {
            continue;
        }
        let name = if ucs2 {
            let units: Vec<u16> = raw_name.as_chunks::<2>().0.iter().map(|c| u16::from_be_bytes(*c)).collect();
            Some(String::from_utf16_lossy(&units))
        } else {
            // Rock Ridge: the system use area after the name (and its pad).
            let su = &rec[(33 + name_len + (1 - name_len % 2)).min(rec.len())..];
            rock_ridge_name(su)
        };
        let Some(name) = name else { continue };
        let name = name.split(';').next().unwrap_or_default().to_string();
        out.push((name, extent(iso, le32(rec, 2)?, le32(rec, 10)?, "file")?));
    }
    Ok(out)
}

/// The `NM` entries of a Rock Ridge system use area, joined.
fn rock_ridge_name(mut su: &[u8]) -> Option<String> {
    let mut name = Vec::new();
    while su.len() >= 4 {
        let len = su[2] as usize;
        if len < 4 || len > su.len() {
            break;
        }
        if &su[..2] == b"NM" && len >= 5 {
            name.extend_from_slice(&su[5..len]);
        }
        su = &su[len..];
    }
    (!name.is_empty()).then(|| String::from_utf8_lossy(&name).into_owned())
}

// ---------------------------------------------------------------------------
// The seed's files, read back
// ---------------------------------------------------------------------------

/// A YAML value, as far as the seed files need: block mappings and
/// sequences, flow sequences of scalars, and scalars plain or quoted.
#[derive(Debug, Clone, PartialEq)]
enum Y {
    Map(Vec<(String, Y)>),
    Seq(Vec<Y>),
    Str(String),
    Null,
}

impl Y {
    fn get(&self, key: &str) -> Option<&Y> {
        match self {
            Y::Map(m) => m.iter().find(|(k, _)| k == key).map(|(_, v)| v),
            _ => None,
        }
    }

    fn str(&self) -> Option<&str> {
        match self {
            Y::Str(s) => Some(s),
            _ => None,
        }
    }

    fn keys(&self) -> Vec<&str> {
        match self {
            Y::Map(m) => m.iter().map(|(k, _)| k.as_str()).collect(),
            _ => vec![],
        }
    }

    fn strs(&self) -> Option<Vec<String>> {
        match self {
            Y::Seq(v) => v.iter().map(|x| x.str().map(str::to_string)).collect(),
            _ => None,
        }
    }
}

/// A scalar as YAML reads it: double-quoted (JSON's escapes, which is what
/// the app writes), single-quoted, or plain; `~`/`null` for nothing; or a
/// flow sequence of those. `None` for what the subset does not read: a flow
/// sequence inside another, a flow mapping, and every other construct a
/// plain scalar cannot start with (anchors, aliases, tags, block scalars) —
/// read as text, each would be written back as a string it never was. The
/// flow sequence does not nest, so this does not recurse more than once.
fn yaml_scalar(s: &str) -> Option<Y> {
    yaml_value(s, true)
}

fn yaml_value(s: &str, flow: bool) -> Option<Y> {
    let s = s.trim();
    if s.starts_with('"') {
        return Some(serde_json::from_str::<String>(s).map(Y::Str).unwrap_or_else(|_| Y::Str(s.to_string())));
    }
    if let Some(inner) = s.strip_prefix('\'').and_then(|x| x.strip_suffix('\'')) {
        return Some(Y::Str(inner.replace("''", "'")));
    }
    if flow && let Some(inner) = s.strip_prefix('[').and_then(|x| x.strip_suffix(']')) {
        if let Ok(v) = serde_json::from_str::<Vec<String>>(s) {
            return Some(Y::Seq(v.into_iter().map(Y::Str).collect()));
        }
        return inner
            .split(',')
            .map(str::trim)
            .filter(|x| !x.is_empty())
            .map(|x| yaml_value(x, false))
            .collect::<Option<Vec<_>>>()
            .map(Y::Seq);
    }
    if s.starts_with(['[', ']', '{', '}', '&', '*', '!', '|', '>', '%', '@', '`']) {
        return None;
    }
    // A comment after a plain scalar.
    let s = s.split(" #").next().unwrap_or_default().trim_end();
    Some(match s {
        "" | "~" | "null" => Y::Null,
        _ => Y::Str(s.to_string()),
    })
}

/// `key: rest` of a mapping line, where the key is plain: a colon followed
/// by a space or the end.
fn yaml_key(line: &str) -> Option<(&str, &str)> {
    if line.starts_with('"') || line.starts_with('\'') || line.starts_with('[') {
        return None;
    }
    let at = line.char_indices().find(|&(i, c)| {
        c == ':' && line[i + 1..].chars().next().is_none_or(|n| n == ' ')
    })?;
    Some((line[..at.0].trim(), line[at.0 + 1..].trim()))
}

/// The deepest block nesting read. A seed the app writes is four deep
/// (`ethernets`, a NIC, `routes`, a route); indentation alone bounds the
/// recursion only by the file's size, which is enough lines to overflow the
/// stack.
const YAML_MAX_DEPTH: usize = 16;

struct YLines {
    lines: Vec<(usize, String)>,
    at: usize,
    depth: usize,
    /// Something the subset does not read was met: the document is none.
    bad: bool,
}

impl YLines {
    fn new(text: &str) -> YLines {
        let lines = text
            .lines()
            .filter(|l| {
                let t = l.trim();
                !t.is_empty() && !t.starts_with('#') && t != "---"
            })
            .map(|l| {
                let indent = l.len() - l.trim_start_matches(' ').len();
                (indent, l.trim().to_string())
            })
            .collect();
        YLines {
            lines,
            at: 0,
            depth: 0,
            bad: false,
        }
    }

    fn peek(&self) -> Option<&(usize, String)> {
        self.lines.get(self.at)
    }

    fn scalar(&mut self, s: &str) -> Y {
        yaml_scalar(s).unwrap_or_else(|| {
            self.bad = true;
            Y::Null
        })
    }

    /// The block at `indent`: a sequence where it starts with `-`, a mapping
    /// otherwise.
    fn block(&mut self, indent: usize) -> Y {
        self.nested(|y| match y.peek() {
            Some((i, l)) if *i == indent && (l == "-" || l.starts_with("- ")) => y.seq(indent),
            Some((i, _)) if *i == indent => y.map(indent, None),
            _ => Y::Null,
        })
    }

    fn seq(&mut self, indent: usize) -> Y {
        let mut items = Vec::new();
        while let Some((i, l)) = self.peek().cloned() {
            if self.bad || i != indent || !(l == "-" || l.starts_with("- ")) {
                break;
            }
            self.at += 1;
            let rest = l[1..].trim();
            if rest.is_empty() {
                let child = self.peek().map(|(ci, _)| *ci).filter(|ci| *ci > indent);
                items.push(child.map_or(Y::Null, |ci| self.block(ci)));
            } else if let Some((k, v)) = yaml_key(rest) {
                // A mapping item: its first key on the dash's line, the rest
                // under it where that key stands.
                items.push(self.nested(|y| y.map(indent + 2, Some((k.to_string(), v.to_string())))));
            } else {
                items.push(self.scalar(rest));
            }
        }
        Y::Seq(items)
    }

    /// `f` one level deeper: past [`YAML_MAX_DEPTH`], the document is none.
    fn nested(&mut self, f: impl FnOnce(&mut YLines) -> Y) -> Y {
        if self.depth >= YAML_MAX_DEPTH {
            self.bad = true;
            return Y::Null;
        }
        self.depth += 1;
        let y = f(self);
        self.depth -= 1;
        y
    }

    fn map(&mut self, indent: usize, first: Option<(String, String)>) -> Y {
        let mut out = Vec::new();
        let mut pending = first;
        while !self.bad {
            let (k, v) = match pending.take() {
                Some(kv) => kv,
                None => match self.peek().cloned() {
                    Some((i, l)) if i == indent && !(l == "-" || l.starts_with("- ")) => {
                        self.at += 1;
                        match yaml_key(&l) {
                            Some((k, v)) => (k.to_string(), v.to_string()),
                            None => (l, String::new()),
                        }
                    }
                    _ => break,
                },
            };
            let value = if v.is_empty() {
                match self.peek().cloned() {
                    Some((ci, _)) if ci > indent => self.block(ci),
                    // `key:` then `- item` at the key's own indent.
                    Some((ci, l)) if ci == indent && (l == "-" || l.starts_with("- ")) => {
                        self.nested(|y| y.seq(ci))
                    }
                    _ => Y::Null,
                }
            } else {
                self.scalar(&v)
            };
            out.push((k, value));
        }
        Y::Map(out)
    }
}

/// The document, or [`Y::Null`] where any of it is outside the subset.
fn yaml(text: &str) -> Y {
    let mut lines = YLines::new(text);
    let first = lines.peek().map(|(i, _)| *i).unwrap_or(0);
    let y = lines.block(first);
    if lines.bad || lines.at < lines.lines.len() {
        // Lines the subset did not take, or a value it does not read.
        return Y::Null;
    }
    y
}

/// One NIC as the seed writes it ([`VirtCloudInit::network_config`]);
/// `None` for anything else, so the read is foreign rather than a save
/// changing what the guest's network does. What is read is exactly what is
/// written: matched by the MAC alone; `dhcp4: true` with nothing else of the
/// address, or `dhcp4: false` with one address and at most the one default
/// route through a gateway; nameservers of addresses and search domains.
fn nic_of(nic: &Y) -> Option<VirtCiNetwork> {
    let only = |y: &Y, keys: &[&str]| matches!(y, Y::Map(_)) && y.keys().iter().all(|k| keys.contains(k));
    if !only(nic, &["match", "dhcp4", "addresses", "routes", "nameservers"]) {
        return None;
    }
    let m = nic.get("match")?;
    if !only(m, &["macaddress"]) {
        return None;
    }
    let mac = m.get("macaddress").and_then(Y::str)?;
    let ipv4 = match (nic.get("dhcp4").and_then(Y::str)?, nic.get("addresses"), nic.get("routes")) {
        ("true", None, None) => None,
        ("false", Some(addresses), routes) => {
            let [address] = addresses.strs()?.try_into().ok()?;
            let gateway = match routes {
                None => None,
                Some(Y::Seq(routes)) => match routes.as_slice() {
                    [route]
                        if only(route, &["to", "via"])
                            && matches!(route.get("to").and_then(Y::str), Some("0.0.0.0/0" | "default")) =>
                    {
                        Some(route.get("via").and_then(Y::str)?.to_string())
                    }
                    _ => return None,
                },
                Some(_) => return None,
            };
            Some(VirtCiIpv4 { address, gateway })
        }
        _ => return None,
    };
    let (dns, search) = match nic.get("nameservers") {
        None => (Vec::new(), Vec::new()),
        Some(ns) => {
            if !only(ns, &["addresses", "search"]) {
                return None;
            }
            let list = |k: &str| ns.get(k).map_or(Some(Vec::new()), Y::strs);
            (list("addresses")?, list("search")?)
        }
    };
    Some(VirtCiNetwork {
        mac: mac.to_string(),
        ipv4,
        dns,
        search,
    })
}

/// What [`VirtCloudInit`] writes, read back from the seed's files. Anything
/// it does not write, or writes otherwise, makes the read `foreign`.
fn parse_seed(files: &[(String, &[u8])]) -> VirtSeedRead {
    let file = |name: &str| {
        files
            .iter()
            .find(|(n, _)| n == name)
            .map(|(_, b)| String::from_utf8_lossy(b).into_owned())
    };
    // Another file, or one of these twice: which of two a guest reads is
    // not this reader's to decide.
    let mut seen = std::collections::HashSet::new();
    let mut foreign = files.iter().any(|(n, _)| {
        !matches!(n.as_str(), "user-data" | "meta-data" | "network-config") || !seen.insert(n)
    });
    let mut ci = VirtCloudInit::default();
    let is = |y: Option<&Y>, want: &str| y.and_then(Y::str) == Some(want);

    match file("user-data") {
        Some(text) if text.starts_with("#cloud-config") => {
            let y = yaml(&text);
            foreign |= y == Y::Null;
            for k in y.keys() {
                foreign |= !matches!(
                    k,
                    "hostname" | "manage_etc_hosts" | "user" | "users" | "ssh_pwauth" | "chpasswd"
                );
            }
            ci.hostname = y.get("hostname").and_then(Y::str).unwrap_or_default().to_string();
            foreign |= !is(y.get("manage_etc_hosts"), "true");
            // The default user renamed (`user:`), or — as the first release
            // of this wrote it — one account of its own (`users:`).
            let account = match (y.get("user"), y.get("users")) {
                (Some(u @ Y::Map(_)), None) => Some((u, false)),
                (None, Some(Y::Seq(users))) if users.len() == 1 && matches!(users[0], Y::Map(_)) => Some((&users[0], true)),
                _ => None,
            };
            match account {
                Some((u, legacy)) => {
                    foreign |= !legacy && u.get("shell").is_some();
                    for k in u.keys() {
                        foreign |= !matches!(
                            k,
                            "name" | "sudo" | "shell" | "lock_passwd" | "hashed_passwd" | "ssh_authorized_keys"
                        );
                    }
                    ci.user = u.get("name").and_then(Y::str).unwrap_or_default().to_string();
                    foreign |= !is(u.get("sudo"), "ALL=(ALL) NOPASSWD:ALL");
                    foreign |= legacy && u.get("shell").is_some_and(|s| s.str() != Some("/bin/bash"));
                    ci.password_hash = u
                        .get("hashed_passwd")
                        .and_then(Y::str)
                        .filter(|h| is_crypt_hash(h))
                        .map(str::to_string);
                    foreign |= u.get("hashed_passwd").is_some() && ci.password_hash.is_none();
                    match u.get("ssh_authorized_keys") {
                        None => {}
                        Some(keys) => match keys.strs() {
                            Some(k) => ci.ssh_keys = k,
                            None => foreign = true,
                        },
                    }
                }
                _ => foreign = true,
            }
            // The password's two switches, as [`VirtCloudInit::user_data`]
            // derives them from the hash: a save writes them so, and must
            // not unlock an account or open SSH to passwords unannounced.
            let hashed = ci.password_hash.is_some();
            foreign |= !account.is_some_and(|(u, _)| is(u.get("lock_passwd"), if hashed { "false" } else { "true" }));
            foreign |= !is(y.get("ssh_pwauth"), if hashed { "true" } else { "false" });
            // The expiry, as [`VirtCloudInit::user_data`] writes it: this
            // account's own hash, set again by `chpasswd` and expired.
            if let Some(c) = y.get("chpasswd") {
                let users = match c.get("users") {
                    Some(Y::Seq(users)) => users.as_slice(),
                    _ => &[],
                };
                let ours = matches!(users, [u] if
                    is(u.get("name"), &ci.user)
                    && ci.password_hash.as_deref().is_some_and(|h| is(u.get("password"), h))
                    && is(u.get("type"), "hash")
                    && u.keys().iter().all(|k| matches!(*k, "name" | "password" | "type")));
                foreign |= !ours
                    || !is(c.get("expire"), "true")
                    || c.keys().iter().any(|k| !matches!(*k, "expire" | "users"));
                ci.password_expire = ours && is(c.get("expire"), "true");
            }
        }
        _ => foreign = true,
    }
    match file("meta-data") {
        Some(text) => {
            let y = yaml(&text);
            foreign |= y == Y::Null;
            for k in y.keys() {
                foreign |= !matches!(k, "instance-id" | "local-hostname");
            }
            ci.instance_id = y.get("instance-id").and_then(Y::str).unwrap_or_default().to_string();
            if ci.hostname.is_empty() {
                ci.hostname = y.get("local-hostname").and_then(Y::str).unwrap_or_default().to_string();
            }
            foreign |= !matches!(y.get("local-hostname").and_then(Y::str), Some(h) if h == ci.hostname);
        }
        None => foreign = true,
    }
    if let Some(text) = file("network-config") {
        let y = yaml(&text);
        let nics = match y.get("ethernets") {
            Some(Y::Map(m)) if !m.is_empty() => m,
            _ => {
                foreign = true;
                &Vec::new()
            }
        };
        foreign |= !is(y.get("version"), "2") || y.keys().len() != 2;
        for (i, (_, nic)) in nics.iter().enumerate() {
            if i > 0 {
                // Every NIC but the first is read and kept, and is not
                // something the app failed to write.
                if let Some(net) = nic_of(nic) {
                    ci.extra_networks.push(net);
                } else {
                    foreign = true;
                }
                continue;
            }
            match nic_of(nic) {
                Some(net) => ci.network = Some(net),
                None => foreign = true,
            }
            // A NIC the seed describes but this app cannot read as one: the
            // rest of the seed is still shown.
            foreign |= ci.network.is_none();
        }
    }
    VirtSeedRead {
        cloud_init: ci,
        foreign,
        revision: String::new(),
    }
}

// ---------------------------------------------------------------------------
// SHA-512 crypt
// ---------------------------------------------------------------------------

const ITOA64: &[u8] = b"./0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz";

/// Whether `salt` can be a crypt salt: up to 16 of the crypt alphabet.
pub fn is_crypt_salt(salt: &str) -> bool {
    (1..=16).contains(&salt.len()) && salt.bytes().all(|b| ITOA64.contains(&b))
}

/// The longest password [`sha512_crypt`] takes, in bytes. The algorithm
/// hashes the password's length times the password (its `P` sequence),
/// then the password twice in each of the 5000 rounds: a long paste would
/// hold the caller — the app's UI isolate, on a synchronous FFI call — for
/// seconds. 1 KiB is far past any password typed or generated, and is
/// milliseconds.
pub const PASSWORD_MAX: usize = 1024;

/// `$6$<salt>$<hash>`: SHA-512 crypt (Ulrich Drepper's specification, the
/// `crypt(3)` glibc and cloud-init's `hashed_passwd` read) with the default
/// 5000 rounds. `salt` is the caller's, drawn from a secure source; the
/// password is up to [`PASSWORD_MAX`] bytes.
pub fn sha512_crypt(password: &str, salt: &str) -> Result<String, VirtError> {
    if !is_crypt_salt(salt) {
        return Err(VirtError::Malformed {
            message: "invalid crypt salt".into(),
        });
    }
    if password.len() > PASSWORD_MAX {
        return Err(VirtError::Malformed {
            message: format!("password longer than {PASSWORD_MAX} bytes"),
        });
    }
    Ok(sha512_crypt_rounds(password.as_bytes(), salt.as_bytes(), None))
}

fn sha512_crypt_rounds(pw: &[u8], salt: &[u8], rounds: Option<u32>) -> String {
    let salt = &salt[..salt.len().min(16)];
    let n = rounds.map(|r| r.clamp(1000, 999_999_999)).unwrap_or(5000);
    let digest = |parts: &[&[u8]]| -> [u8; 64] {
        let mut h = Sha512::new();
        for p in parts {
            h.update(p);
        }
        h.finalize().into()
    };
    let b = digest(&[pw, salt, pw]);
    let mut a = Sha512::new();
    a.update(pw);
    a.update(salt);
    let mut left = pw.len();
    while left > 64 {
        a.update(b);
        left -= 64;
    }
    a.update(&b[..left]);
    let mut bits = pw.len();
    while bits > 0 {
        if bits & 1 != 0 {
            a.update(b);
        } else {
            a.update(pw);
        }
        bits >>= 1;
    }
    let a: [u8; 64] = a.finalize().into();
    let repeat = |block: &[u8; 64], len: usize| -> Vec<u8> { block.iter().copied().cycle().take(len).collect() };
    let mut dp = Sha512::new();
    for _ in 0..pw.len() {
        dp.update(pw);
    }
    let p = repeat(&dp.finalize().into(), pw.len());
    let mut ds = Sha512::new();
    for _ in 0..16 + a[0] as usize {
        ds.update(salt);
    }
    let s = repeat(&ds.finalize().into(), salt.len());
    let mut c = a;
    for i in 0..n {
        let mut h = Sha512::new();
        if i & 1 != 0 {
            h.update(&p);
        } else {
            h.update(c);
        }
        if i % 3 != 0 {
            h.update(&s);
        }
        if i % 7 != 0 {
            h.update(&p);
        }
        if i & 1 != 0 {
            h.update(c);
        } else {
            h.update(&p);
        }
        c = h.finalize().into();
    }
    const ORDER: [(usize, usize, usize); 21] = [
        (0, 21, 42), (22, 43, 1), (44, 2, 23), (3, 24, 45), (25, 46, 4), (47, 5, 26), (6, 27, 48),
        (28, 49, 7), (50, 8, 29), (9, 30, 51), (31, 52, 10), (53, 11, 32), (12, 33, 54), (34, 55, 13),
        (56, 14, 35), (15, 36, 57), (37, 58, 16), (59, 17, 38), (18, 39, 60), (40, 61, 19), (62, 20, 41),
    ];
    let mut out = String::from("$6$");
    if let Some(r) = rounds {
        out.push_str(&format!("rounds={}$", r.clamp(1000, 999_999_999)));
    }
    out.push_str(std::str::from_utf8(salt).unwrap_or_default());
    out.push('$');
    let mut put = |w: u32, len: usize| {
        let mut w = w;
        for _ in 0..len {
            out.push(ITOA64[(w & 0x3f) as usize] as char);
            w >>= 6;
        }
    };
    for (x, y, z) in ORDER {
        put(((c[x] as u32) << 16) | ((c[y] as u32) << 8) | c[z] as u32, 4);
    }
    put(c[63] as u32, 2);
    out
}

#[cfg(test)]
mod tests {
    use super::*;

    /// The specification's own examples.
    #[test]
    fn sha512_crypt_matches_the_specification() {
        assert_eq!(
            sha512_crypt_rounds(b"Hello world!", b"saltstring", None),
            "$6$saltstring$svn8UoSVapNtMuq1ukKS4tPQd8iKwSMHWjl/O817G3uBnIFNjnQJuesI68u4OTLiBFdcbYEdFCoEOfaS35inz1"
        );
        assert_eq!(
            sha512_crypt_rounds(b"Hello world!", b"saltstringsaltstring", Some(10000)),
            "$6$rounds=10000$saltstringsaltst$OW1/O6BYHV6BcXZu8QVeXbDWra3Oeqh0sbHbbMCVNSnCM/UrjmM0Dp8vOuZeHBy/YTBmSK6H9qs/y3RnOaw5v."
        );
        assert_eq!(
            sha512_crypt_rounds(b"This is just a test", b"toolongsaltstring", Some(5000)),
            "$6$rounds=5000$toolongsaltstrin$lQ8jolhgVRVhY4b5pZKaysCLi0QBxGoNeKQzQ3glMhwllF7oGDZxUhx1yxdYcz/e1JSbq3y6JMxxl8audkUEm0"
        );
        // glibc's crypt(3) on the PVE host (libxcrypt refuses the
        // specification's own rounds=10 example, which clamps to 1000).
        assert_eq!(
            sha512_crypt_rounds(
                b"we have a short salt string but not a short password",
                b"roundstoolow",
                Some(1000)
            ),
            "$6$rounds=1000$roundstoolow$yjTuW7RnC.d35QcVTFIb6uvh/7IQ1.GFtFN3i/.jwmeWEhzjf4uD/OPCb4jRl6atJGYhLst8IyR6YAtTrriMU1"
        );
        // Longer than a block, and empty: glibc's too.
        assert_eq!(
            sha512_crypt(&"x".repeat(200), "abcdefgh").unwrap(),
            "$6$abcdefgh$tpP3/LI4wMLKhgKp8bTwVQweEEM46u1QVpxJ4s7//kd/n92pnKvxNc51RM.csWa9OlZn10Z4pRopwomQmhBXx1"
        );
        assert_eq!(
            sha512_crypt("", "abcdefgh").unwrap(),
            "$6$abcdefgh$v7sYNA18/BerGOYQLppYLyjH4yJilp8kqe/ef3KYMK9hOIdzH1yzcmP74Ay.m51y1jP3QqxM7Jl75S4CxDhBq."
        );
        assert!(sha512_crypt("pw", "bad salt").is_err());
        assert!(sha512_crypt("pw", "").is_err());
    }

    /// A pasted wall of text is refused, not hashed for seconds.
    #[test]
    fn sha512_crypt_bounds_the_password() {
        sha512_crypt(&"x".repeat(PASSWORD_MAX), "abcdefgh").unwrap();
        assert!(sha512_crypt(&"x".repeat(PASSWORD_MAX + 1), "abcdefgh").is_err());
        assert!(sha512_crypt(&"x".repeat(1 << 20), "abcdefgh").is_err());
    }

    /// An extent's fields are the image's: an offset that overflows is out
    /// of range, not a panic nor a wrap to some other part of the image (a
    /// `u32` sector times 2048 overflows a 32-bit `usize`).
    #[test]
    fn an_extent_that_overflows_is_out_of_range() {
        let iso = [0u8; 4096];
        assert_eq!(extent(&iso, 1, 2048, "file").unwrap().len(), 2048);
        assert!(extent(&iso, usize::MAX / SECTOR + 1, 1, "file").is_err());
        assert!(extent(&iso, 1, usize::MAX - 10, "file").is_err());
        assert!(extent(&iso, 2, 1, "file").is_err());
    }

    fn ci() -> VirtCloudInit {
        VirtCloudInit {
            user: "debian".into(),
            password_hash: Some(sha512_crypt("hunter2", "Nq1nJ8n4tqQzq3ra").unwrap()),
            ssh_keys: vec!["ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIB0 me@host".into()],
            hostname: "web-01".into(),
            instance_id: "iid-web-01-1a2b".into(),
            network: Some(VirtCiNetwork {
                mac: "52:54:00:AB:cd:01".into(),
                ipv4: None,
                dns: vec![],
                search: vec![],
            }),
            extra_networks: Vec::new(),
            password_expire: false,
        }
    }

    #[test]
    fn seed_files() {
        let c = ci();
        c.check().unwrap();
        let ud = c.user_data();
        assert!(ud.starts_with("#cloud-config\n"), "{ud}");
        assert!(ud.contains("user:\n  name: \"debian\"\n"), "{ud}");
        assert!(ud.contains("  hashed_passwd: \"$6$Nq1nJ8n4tqQzq3ra$"), "{ud}");
        assert!(!ud.contains("hunter2"));
        // The distribution's own shell: none named.
        assert!(!ud.contains("shell"), "{ud}");
        assert!(ud.contains("    - \"ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIB0 me@host\"\n"), "{ud}");
        assert!(ud.contains("ssh_pwauth: true\n"), "{ud}");
        assert_eq!(c.meta_data(), "instance-id: \"iid-web-01-1a2b\"\nlocal-hostname: \"web-01\"\n");
        assert_eq!(
            c.network_config().unwrap(),
            "version: 2\nethernets:\n  nic0:\n    match:\n      macaddress: \"52:54:00:ab:cd:01\"\n    dhcp4: true\n"
        );

        let mut s = ci();
        s.password_hash = None;
        s.network = Some(VirtCiNetwork {
            mac: "52:54:00:00:00:01".into(),
            ipv4: Some(VirtCiIpv4 {
                address: "10.0.0.5/24".into(),
                gateway: Some("10.0.0.1".into()),
            }),
            dns: vec!["1.1.1.1".into(), "2606:4700:4700::1111".into()],
            search: vec!["lab.example".into()],
        });
        s.check().unwrap();
        let ud = s.user_data();
        assert!(ud.contains("lock_passwd: true\n") && !ud.contains("hashed_passwd"), "{ud}");
        assert!(ud.contains("ssh_pwauth: false\n"), "{ud}");
        assert_eq!(
            s.network_config().unwrap(),
            "version: 2\nethernets:\n  nic0:\n    match:\n      macaddress: \"52:54:00:00:00:01\"\n    dhcp4: false\n    \
             addresses: [\"10.0.0.5/24\"]\n    routes:\n      - to: \"0.0.0.0/0\"\n        via: \"10.0.0.1\"\n    \
             nameservers:\n      addresses: [\"1.1.1.1\", \"2606:4700:4700::1111\"]\n      search: [\"lab.example\"]\n"
        );
        s.network = None;
        assert_eq!(s.network_config(), None);
        // Debug output never carries the hash.
        assert!(!format!("{:?}", ci()).contains("$6$"));
    }

    /// A value that would be a YAML key of its own, or break a line, comes
    /// out as one string or not at all.
    #[test]
    fn seed_values_stay_values() {
        let mut c = ci();
        c.ssh_keys = vec!["ssh-ed25519 AAAA x\" \nroot: yes".into()];
        assert!(c.check().is_err());
        c.ssh_keys = vec!["ssh-ed25519 AAAA \"quoted\" #: comment".into()];
        c.check().unwrap();
        assert!(c.user_data().contains("    - \"ssh-ed25519 AAAA \\\"quoted\\\" #: comment\"\n"));
        let bad = |f: &dyn Fn(&mut VirtCloudInit)| {
            let mut c = ci();
            f(&mut c);
            assert!(c.check().is_err(), "{c:?}");
        };
        bad(&|c| c.user = "Root".into());
        bad(&|c| c.user = String::new());
        bad(&|c| c.user = "a b".into());
        bad(&|c| c.user = "-x".into());
        bad(&|c| c.hostname = "web_01".into());
        bad(&|c| c.hostname = "-web".into());
        bad(&|c| c.instance_id = "a b".into());
        bad(&|c| c.password_hash = Some("hunter2".into()));
        bad(&|c| c.password_hash = Some("$6$salt$short".into()));
        bad(&|c| c.network.as_mut().unwrap().mac = "52:54:00:00:00".into());
        bad(&|c| {
            c.network.as_mut().unwrap().ipv4 = Some(VirtCiIpv4 {
                address: "10.0.0.5".into(),
                gateway: None,
            })
        });
        bad(&|c| {
            c.network.as_mut().unwrap().ipv4 = Some(VirtCiIpv4 {
                address: "10.0.0.5/24".into(),
                gateway: Some("gw".into()),
            })
        });
        bad(&|c| c.network.as_mut().unwrap().dns = vec!["one.one".into()]);
        bad(&|c| c.network.as_mut().unwrap().search = vec!["a b".into()]);
    }

    #[test]
    fn seed_tool_section() {
        let m = script::cmd_marker;
        let segs = script::parse_script_segments(&format!("{}\nxorriso\n", m(KEY_SEED_TOOL)));
        assert_eq!(parse_seed_tool(&segs).as_deref(), Some("xorriso"));
        let segs = script::parse_script_segments(&format!("{}\n", m(KEY_SEED_TOOL)));
        assert_eq!(parse_seed_tool(&segs), None);
        assert!(seed_tool_probe().contains("genisoimage xorriso mkisofs cloud-localds"));
    }
}
