//! cloud-init for a new libvirt domain: the NoCloud seed (`user-data`,
//! `meta-data`, `network-config`), the script fragment that makes it an ISO
//! on the host and a volume in a pool, and the SHA-512 crypt that keeps a
//! password out of it.
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

use crate::script::{self, shell_quote_unix};
use crate::virt::{CONNECT_URI, RC_PREFIX, VirtError};
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
/// ([`crate::virt::VirtDomainXml::seed`]).
pub const SEED_METADATA_NS: &str = "https://serverbox.app/xmlns/libvirt/cloud-init/1";
pub const SEED_METADATA_ELEMENT: &str = "cloud-init";

/// Static IPv4 of the one NIC; none is DHCP.
#[derive(Debug, Clone, Default, PartialEq, Eq, Serialize, Deserialize)]
pub struct VirtCiIpv4 {
    /// `10.0.0.5/24`
    pub address: String,
    pub gateway: Option<String>,
}

/// The one NIC's configuration, matched by its MAC.
#[derive(Debug, Clone, Default, PartialEq, Eq, Serialize, Deserialize)]
pub struct VirtCiNetwork {
    pub mac: String,
    /// None: DHCP
    pub ipv4: Option<VirtCiIpv4>,
    #[serde(default)]
    pub dns: Vec<String>,
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
        if let Some(n) = &self.network {
            let mac_ok = n.mac.split(':').count() == 6
                && n.mac.split(':').all(|p| p.len() == 2 && p.chars().all(|c| c.is_ascii_hexdigit()));
            if !mac_ok {
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

    /// `user-data`: the account, its password hash and keys, the hostname.
    /// One account of its own rather than the image's default user, so the
    /// name asked for is the name there on every distribution.
    pub fn user_data(&self) -> String {
        let j = json;
        let mut s = String::from("#cloud-config\n");
        s.push_str(&format!("hostname: {}\n", j(&self.hostname)));
        s.push_str("manage_etc_hosts: true\n");
        s.push_str("users:\n");
        s.push_str(&format!("  - name: {}\n", j(&self.user)));
        s.push_str("    sudo: \"ALL=(ALL) NOPASSWD:ALL\"\n");
        s.push_str("    shell: /bin/bash\n");
        match &self.password_hash {
            Some(h) => {
                s.push_str("    lock_passwd: false\n");
                s.push_str(&format!("    hashed_passwd: {}\n", j(h)));
            }
            None => s.push_str("    lock_passwd: true\n"),
        }
        let keys: Vec<&str> = self.ssh_keys.iter().map(|k| k.trim()).filter(|k| !k.is_empty()).collect();
        if !keys.is_empty() {
            s.push_str("    ssh_authorized_keys:\n");
            for k in keys {
                s.push_str(&format!("      - {}\n", j(k)));
            }
        }
        // A password is for logging in with; images ship with SSH password
        // logins off.
        s.push_str(&format!("ssh_pwauth: {}\n", self.password_hash.is_some()));
        s
    }

    pub fn meta_data(&self) -> String {
        format!(
            "instance-id: {}\nlocal-hostname: {}\n",
            json(&self.instance_id),
            json(&self.hostname)
        )
    }

    /// Network config version 2 for the one NIC, found by its MAC; none
    /// without a NIC.
    pub fn network_config(&self) -> Option<String> {
        let n = self.network.as_ref()?;
        let j = json;
        let mut s = String::from("version: 2\nethernets:\n  nic0:\n");
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

/// The seed as an ISO on the host, then a raw volume `volume` of `pool`
/// holding it (`vol-create-as` of its size, `vol-upload`), then its path in
/// `$seed`. Written for [`crate::virt::create_volume_script`], after the
/// disk was made: `rollback` is the shell that takes the disk back, run when
/// any step here fails, and the seed's volume is deleted as well once made.
/// `R` is the script's virsh wrapper (status in `$r`).
pub fn seed_script(ci: &VirtCloudInit, pool: &str, volume: &str, rollback: &str) -> Result<String, VirtError> {
    ci.check()?;
    let q = shell_quote_unix;
    let m = script::cmd_marker;
    let (pool, vol) = (q(pool), q(volume));
    let files = {
        let mut f = format!(
            "printf '%s' {} >\"$d/user-data\"\nprintf '%s' {} >\"$d/meta-data\"\n",
            q(&ci.user_data()),
            q(&ci.meta_data())
        );
        if let Some(n) = ci.network_config() {
            f.push_str(&format!("printf '%s' {} >\"$d/network-config\"\n", q(&n)));
        }
        f
    };
    let net = if ci.network.is_some() { " network-config" } else { "" };
    let net_ld = if ci.network.is_some() { "-N network-config " } else { "" };
    let mkisofs = format!("-output seed.iso -volid cidata -joliet -rock user-data meta-data{net}");
    let del_seed = format!("virsh --connect {CONNECT_URI} -q vol-delete --pool {pool} --vol {vol} </dev/null >/dev/null 2>&1");
    let mut s = String::new();
    // The staging directory: 0700 from mktemp, files 0600 by the umask, and
    // removed however the script ends.
    s.push_str(&format!(
        "echo '{iso}'\nd=$(umask 077; mktemp -d 2>&1) || {{ printf '%s\\n{RC_PREFIX}1\\n' \"$d\"; d=; {rollback}exit 0; }}\n\
         trap 'rm -rf -- \"$d\"' EXIT\ntrap 'rm -rf -- \"$d\"; exit 1' HUP INT TERM\n\
         (umask 077\n{files})\n\
         if command -v genisoimage >/dev/null 2>&1; then out=$(cd \"$d\" && genisoimage -quiet {mkisofs} 2>&1); r=$?\n\
         elif command -v xorriso >/dev/null 2>&1; then out=$(cd \"$d\" && xorriso -as mkisofs -quiet {mkisofs} 2>&1); r=$?\n\
         elif command -v mkisofs >/dev/null 2>&1; then out=$(cd \"$d\" && mkisofs -quiet {mkisofs} 2>&1); r=$?\n\
         elif command -v cloud-localds >/dev/null 2>&1; then out=$(cd \"$d\" && cloud-localds {net_ld}seed.iso user-data meta-data 2>&1); r=$?\n\
         else echo '{no_tool}'; {rollback}exit 0; fi\n\
         printf '%s\\n{RC_PREFIX}%s\\n' \"$out\" \"$r\"\n\
         if [ \"$r\" != 0 ]; then {rollback}exit 0; fi\n",
        iso = m(KEY_SEED_ISO),
        no_tool = m(KEY_SEED_NO_TOOL),
    ));
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
// SHA-512 crypt
// ---------------------------------------------------------------------------

const ITOA64: &[u8] = b"./0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz";

/// Whether `salt` can be a crypt salt: up to 16 of the crypt alphabet.
pub fn is_crypt_salt(salt: &str) -> bool {
    (1..=16).contains(&salt.len()) && salt.bytes().all(|b| ITOA64.contains(&b))
}

/// `$6$<salt>$<hash>`: SHA-512 crypt (Ulrich Drepper's specification, the
/// `crypt(3)` glibc and cloud-init's `hashed_passwd` read) with the default
/// 5000 rounds. `salt` is the caller's, drawn from a secure source.
pub fn sha512_crypt(password: &str, salt: &str) -> Result<String, VirtError> {
    if !is_crypt_salt(salt) {
        return Err(VirtError::Malformed {
            message: "invalid crypt salt".into(),
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
        }
    }

    #[test]
    fn seed_files() {
        let c = ci();
        c.check().unwrap();
        let ud = c.user_data();
        assert!(ud.starts_with("#cloud-config\n"), "{ud}");
        assert!(ud.contains("  - name: \"debian\"\n"), "{ud}");
        assert!(ud.contains("    hashed_passwd: \"$6$Nq1nJ8n4tqQzq3ra$"), "{ud}");
        assert!(!ud.contains("hunter2"));
        assert!(ud.contains("      - \"ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIB0 me@host\"\n"), "{ud}");
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
        assert!(c.user_data().contains("      - \"ssh-ed25519 AAAA \\\"quoted\\\" #: comment\"\n"));
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
