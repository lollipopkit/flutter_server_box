//! The machine's Linux kernels on Debian and Ubuntu (dpkg, apt, GRUB): the
//! one running, the ones installed, the series this machine follows (a
//! metapackage such as `linux-image-generic`, which brings each new
//! kernel), what the archive offers, and which one GRUB boots.
//!
//! Changing them is root's, one at a time ([`Action`], checked against a
//! fresh [`parse`] by [`check`], run as [`script`]): install a package the
//! archive offers, remove a kernel (never the one running, the one booted
//! by default or the last one, nor one a followed series still needs), and
//! boot one by default or once (`GRUB_DEFAULT=saved` in a file of ServerBox's,
//! [`GRUB_DROP_IN`], and `grub-set-default` / `grub-reboot`), or the newest
//! again. A new kernel runs after a restart, which is the caller's.

use std::cmp::Ordering;

use serde::{Deserialize, Serialize};

/// ServerBox's GRUB setting, sourced after `/etc/default/grub`.
pub const GRUB_DROP_IN: &str = "/etc/default/grub.d/99-serverbox.cfg";

/// What [`parse`] reads, by `### <name>` sections. Not root's: GRUB's
/// settings are sourced as `update-grub` sources them.
pub const READ_COMMAND: &str = r####"echo '### running'; uname -r
echo '### os'; ( . /etc/os-release 2>/dev/null; echo "$ID"; echo "$ID_LIKE" )
echo '### tools'; for t in apt-get dpkg-query update-grub grub-set-default grub-reboot grub-editenv; do command -v $t >/dev/null && echo $t; done
echo '### packages'; dpkg-query -W -f='${Package}\t${Version}\t${db:Status-Abbrev}\t${Depends}\n' 'linux-image-*' 2>/dev/null
echo '### archive'; apt list 'linux-image-*' 2>/dev/null
echo '### grubDefault'; ( . /etc/default/grub; for f in /etc/default/grub.d/*.cfg; do [ -f "$f" ] && . "$f"; done; echo "$GRUB_DEFAULT" ) 2>/dev/null
echo '### grubenv'; grub-editenv list 2>/dev/null
echo '### rebootRequired'; [ -f /var/run/reboot-required ] && echo yes
true"####;

#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct Kernel {
    /// `uname -r`'s form: `7.0.0-34-generic`.
    pub release: String,
    pub package: String,
    pub version: String,
    pub running: bool,
    /// GRUB boots it unless told otherwise.
    pub default: bool,
    /// GRUB boots it next time only (`grub-reboot`).
    pub next: bool,
    /// A followed series that depends on it: removing it would remove that.
    pub needed_by: Option<String>,
}

/// A metapackage: a series of kernels (`linux-image-generic`,
/// `linux-image-generic-hwe-26.04`, `linux-image-amd64`).
#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct Series {
    pub package: String,
    /// The archive's newest.
    pub version: String,
    /// What is installed, when it is.
    pub installed: Option<String>,
}

#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct Offered {
    pub package: String,
    pub release: String,
    pub version: String,
}

#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct KernelView {
    /// Debian or Ubuntu with GRUB: what this can change.
    pub supported: bool,
    pub running: String,
    /// Newest first.
    pub installed: Vec<Kernel>,
    /// What GRUB boots: `None` is the newest.
    pub pinned: Option<String>,
    /// The series the archive has, the installed ones first.
    pub series: Vec<Series>,
    /// Other versions of the running kernel's flavour, newest first.
    pub versions: Vec<Offered>,
    /// The machine says it wants a restart (a new kernel, a library).
    pub reboot_required: bool,
}

fn sections(out: &str) -> std::collections::HashMap<&str, Vec<&str>> {
    let mut map: std::collections::HashMap<&str, Vec<&str>> = std::collections::HashMap::new();
    let mut current = "";
    for line in out.lines() {
        if let Some(name) = line.strip_prefix("### ") {
            current = name.trim();
            map.entry(current).or_default();
        } else if !line.trim().is_empty() {
            map.entry(current).or_default().push(line.trim_end());
        }
    }
    map
}

/// Version order of releases and package versions: digit runs as numbers,
/// the rest as text, `~` before anything.
pub fn compare_versions(a: &str, b: &str) -> Ordering {
    fn chunks(s: &str) -> Vec<(bool, &str)> {
        let mut out = Vec::new();
        let mut start = 0;
        let bytes = s.as_bytes();
        for i in 1..=bytes.len() {
            if i == bytes.len() || bytes[i].is_ascii_digit() != bytes[start].is_ascii_digit() {
                out.push((bytes[start].is_ascii_digit(), &s[start..i]));
                start = i;
            }
        }
        out
    }
    let (ca, cb) = (chunks(a), chunks(b));
    for i in 0..ca.len().max(cb.len()) {
        let ord = match (ca.get(i), cb.get(i)) {
            (Some((true, x)), Some((true, y))) => {
                let (x, y) = (x.trim_start_matches('0'), y.trim_start_matches('0'));
                x.len().cmp(&y.len()).then_with(|| x.cmp(y))
            }
            (Some((_, x)), Some((_, y))) => {
                let tilde = |s: &str| s.starts_with('~');
                tilde(y).cmp(&tilde(x)).then_with(|| x.cmp(y))
            }
            (Some((_, x)), None) => if x.starts_with('~') { Ordering::Less } else { Ordering::Greater },
            (None, Some((_, y))) => if y.starts_with('~') { Ordering::Greater } else { Ordering::Less },
            (None, None) => Ordering::Equal,
        };
        if ord != Ordering::Equal {
            return ord;
        }
    }
    Ordering::Equal
}

/// `linux-image-7.0.0-34-generic` (and `linux-image-unsigned-…`) → the
/// release; a metapackage has none.
fn release_of(package: &str) -> Option<&str> {
    let rest = package.strip_prefix("linux-image-")?;
    let rest = rest.strip_prefix("unsigned-").unwrap_or(rest);
    rest.starts_with(|c: char| c.is_ascii_digit()).then_some(rest)
}

/// A kernel's flavour: what follows its version (`generic`, `amd64`,
/// `cloud-amd64`, `realtime`).
fn flavour(release: &str) -> &str {
    // Ubuntu `7.0.0-34-generic`, Debian `6.12.48+deb13-amd64`: the version
    // ends at the first part after a `-` that starts with a letter.
    let mut at = 0;
    for (i, part) in release.split('-').enumerate() {
        if i > 0 && part.starts_with(|c: char| c.is_ascii_alphabetic()) {
            return &release[at..];
        }
        at += part.len() + 1;
    }
    ""
}

/// Metapackages worth offering: no Ubuntu Core images, no `extra`
/// add-ons, no debug symbols.
fn is_series(package: &str) -> bool {
    package.starts_with("linux-image-")
        && release_of(package).is_none()
        && !package.starts_with("linux-image-uc-")
        && !package.starts_with("linux-image-extra-")
        && !package.ends_with("-dbg")
        && !package.contains("-dbgsym")
}

/// What kind of kernel a series brings: its name without the prefix, an
/// enablement stack (`-hwe-26.04`, `-edge`, `-lts-…`) or a pinned line
/// (`-7.0`): `generic`, `virtual`, `aws`, `cloud-amd64`.
fn series_kind(package: &str) -> &str {
    let mut kind = package.strip_prefix("linux-image-").unwrap_or(package);
    for cut in ["-hwe-", "-lts-", "-edge"] {
        if let Some(i) = kind.find(cut) {
            kind = &kind[..i];
        }
    }
    match kind.rsplit_once('-') {
        Some((head, tail)) if tail.starts_with(|c: char| c.is_ascii_digit()) && tail.chars().all(|c| c.is_ascii_digit() || c == '.') => head,
        _ => kind,
    }
}

/// A series worth offering on a machine running [flavour]: its own kind,
/// the general ones, and on Debian every kind for its architecture; not a
/// cloud's or a vendor's own.
fn series_fits(package: &str, flavour: &str) -> bool {
    let kind = series_kind(package);
    kind == flavour || ["generic", "virtual", "lowlatency", "realtime"].contains(&kind) || (!flavour.is_empty() && kind.ends_with(&format!("-{flavour}")))
}

/// The release a GRUB entry (an id path or a title path) boots.
fn release_in_entry(entry: &str) -> Option<String> {
    let last = entry.rsplit('>').next()?;
    if let Some(rest) = last.strip_prefix("gnulinux-")
        && let Some(i) = rest.find("-advanced-").or_else(|| rest.find("-recovery-"))
    {
        return Some(rest[..i].to_string());
    }
    last.split("with Linux ").nth(1).map(|r| r.split_whitespace().next().unwrap_or("").to_string()).filter(|r| !r.is_empty())
}

/// [`READ_COMMAND`]'s output.
pub fn parse(out: &str) -> KernelView {
    let s = sections(out);
    let get = |k: &str| s.get(k).cloned().unwrap_or_default();
    let running = get("running").first().map(|r| r.trim().to_string()).unwrap_or_default();
    let os = get("os");
    let debian = os.iter().any(|l| l.split_whitespace().any(|w| w == "debian" || w == "ubuntu"));
    let tools = get("tools");
    let has = |t: &str| tools.iter().any(|l| l.trim() == t);
    let supported = debian && ["apt-get", "dpkg-query", "update-grub", "grub-set-default", "grub-reboot", "grub-editenv"].iter().all(|t| has(t));

    // Installed packages: kernels and series.
    let mut kernels: Vec<Kernel> = Vec::new();
    let mut installed_series: Vec<(String, String, String)> = Vec::new();
    for line in get("packages") {
        let f: Vec<&str> = line.split('\t').collect();
        if f.len() < 3 || !f[2].trim().starts_with("ii") {
            continue;
        }
        let (package, version, depends) = (f[0].trim(), f[1].trim(), f.get(3).copied().unwrap_or(""));
        match release_of(package) {
            Some(release) => kernels.push(Kernel {
                release: release.to_string(),
                package: package.to_string(),
                version: version.to_string(),
                running: release == running,
                default: false,
                next: false,
                needed_by: None,
            }),
            None => installed_series.push((package.to_string(), version.to_string(), depends.to_string())),
        }
    }
    for k in &mut kernels {
        k.needed_by = installed_series
            .iter()
            .find(|(_, _, deps)| deps.split([',', '|']).any(|d| d.split_whitespace().next() == Some(k.package.as_str())))
            .map(|(p, _, _)| p.clone());
    }
    kernels.sort_by(|a, b| compare_versions(&b.release, &a.release));

    // GRUB: `saved` follows the saved entry; a number other than 0 or an
    // entry names one; 0 (or nothing) is the first entry, the newest.
    let grub_default = get("grubDefault").first().map(|v| v.trim().trim_matches('"').to_string()).unwrap_or_default();
    let env: Vec<(String, String)> = get("grubenv").iter().filter_map(|l| l.split_once('=')).map(|(k, v)| (k.trim().to_string(), v.trim().to_string())).collect();
    let env_get = |k: &str| env.iter().find(|(key, _)| key == k).map(|(_, v)| v.clone()).filter(|v| !v.is_empty());
    let pinned = match grub_default.as_str() {
        "saved" => env_get("saved_entry").and_then(|e| release_in_entry(&e)),
        "" | "0" => None,
        other => release_in_entry(other),
    };
    let next = env_get("next_entry").and_then(|e| release_in_entry(&e));
    let boots = pinned.clone().filter(|p| kernels.iter().any(|k| &k.release == p)).or_else(|| kernels.first().map(|k| k.release.clone()));
    for k in &mut kernels {
        k.default = boots.as_deref() == Some(k.release.as_str());
        k.next = next.as_deref() == Some(k.release.as_str());
    }

    // The archive: `name/suites version arch [installed…]`.
    let mut series: Vec<Series> = Vec::new();
    let mut versions: Vec<Offered> = Vec::new();
    let flavour_now = flavour(&running);
    for line in get("archive") {
        let Some((name, rest)) = line.split_once('/') else { continue };
        let Some(version) = rest.split_whitespace().nth(1) else { continue };
        if is_series(name) {
            let installed = installed_series.iter().find(|(p, _, _)| p == name).map(|(_, v, _)| v.clone());
            if installed.is_some() || series_fits(name, flavour_now) {
                series.push(Series { package: name.to_string(), version: version.to_string(), installed });
            }
        } else if let Some(release) = release_of(name).filter(|_| !name.starts_with("linux-image-unsigned-") && !name.ends_with("-dbg"))
            && !flavour_now.is_empty()
            && flavour(release) == flavour_now
            && !kernels.iter().any(|k| k.release == release)
        {
            versions.push(Offered { package: name.to_string(), release: release.to_string(), version: version.to_string() });
        }
    }
    series.sort_by(|a, b| b.installed.is_some().cmp(&a.installed.is_some()).then_with(|| a.package.cmp(&b.package)));
    versions.sort_by(|a, b| compare_versions(&b.release, &a.release));

    KernelView {
        supported,
        running,
        installed: kernels,
        pinned,
        series,
        versions,
        reboot_required: !get("rebootRequired").is_empty(),
    }
}

#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize)]
#[serde(tag = "action", rename_all = "camelCase")]
pub enum Action {
    /// A package the archive offers: a series or one version.
    Install { package: String },
    Remove { release: String },
    /// GRUB boots [release] from now on, or the next time only.
    Boot {
        release: String,
        #[serde(default)]
        once: bool,
    },
    /// GRUB boots the newest kernel again.
    BootNewest,
}

fn plain(s: &str) -> bool {
    !s.is_empty() && s.len() <= 128 && s.bytes().all(|b| b.is_ascii_alphanumeric() || b"._+-~".contains(&b))
}

/// Whether [a] may run on the machine [v] describes; the refusal's code.
pub fn check(v: &KernelView, a: &Action) -> Result<(), &'static str> {
    if !v.supported {
        return Err("unsupported");
    }
    match a {
        Action::Install { package } => {
            if !plain(package) {
                return Err("invalidPackage");
            }
            let offered = v.series.iter().any(|s| &s.package == package) || v.versions.iter().any(|o| &o.package == package);
            if !offered {
                return Err("notOffered");
            }
            if v.installed.iter().any(|k| &k.package == package) || v.series.iter().any(|s| &s.package == package && s.installed.as_deref() == Some(s.version.as_str())) {
                return Err("installed");
            }
        }
        Action::Remove { release } => {
            let k = v.installed.iter().find(|k| &k.release == release).ok_or("unknownKernel")?;
            if k.running {
                return Err("running");
            }
            if k.default || k.next {
                return Err("booted");
            }
            if v.installed.len() < 2 {
                return Err("lastKernel");
            }
            if k.needed_by.is_some() {
                return Err("neededBySeries");
            }
        }
        Action::Boot { release, .. } => {
            if !v.installed.iter().any(|k| &k.release == release) {
                return Err("unknownKernel");
            }
        }
        Action::BootNewest => {}
    }
    Ok(())
}

/// Exit codes of [`script`].
pub const EXIT_WOULD_REMOVE_MORE: i32 = 5;
pub const EXIT_NO_ENTRY: i32 = 6;

fn quote(s: &str) -> String {
    crate::script::shell_quote_unix(s)
}

/// Root's script for [a], after [`check`].
pub fn script(a: &Action) -> String {
    let apt = "export DEBIAN_FRONTEND=noninteractive";
    match a {
        Action::Install { package } => format!("set -e\n{apt}\napt-get update -q\napt-get install -y {}", quote(package)),
        Action::Remove { release } => format!(
            r#"set -e
{apt}
rel={rel}
pkgs=$(dpkg-query -W -f='${{Package}} ${{db:Status-Abbrev}}\n' "linux-*-$rel" 2>/dev/null | awk '$2 ~ /^i/ {{print $1}}' | tr '\n' ' ')
[ -n "$pkgs" ] || {{ echo "no package holds $rel" >&2; exit 1; }}
more=$(apt-get -s purge $pkgs | sed -n 's/^\(Purg\|Remv\) \([^ ]*\).*/\2/p' | while read -r p; do case " $pkgs " in *" $p "*) ;; *) echo "$p" ;; esac; done)
if [ -n "$more" ]; then echo "removing $rel would also remove: $more" >&2; exit {EXIT_WOULD_REMOVE_MORE}; fi
echo "purging $pkgs"
apt-get purge -y $pkgs"#,
            rel = quote(release)
        ),
        Action::Boot { release, once } => {
            let set = if *once { "grub-reboot" } else { "grub-set-default" };
            format!(
                r#"set -e
rel={rel}
mkdir -p /etc/default/grub.d
printf '# Written by ServerBox: GRUB boots the kernel it was told to.\nGRUB_DEFAULT=saved\n' > {GRUB_DROP_IN}
update-grub
cfg=/boot/grub/grub.cfg
sub=$(sed -n "s/^submenu .* \$menuentry_id_option '\([^']*\)'.*/\1/p" "$cfg" | head -n 1)
entry=
for id in $(grep -o "'gnulinux-[^']*-advanced-[^']*'" "$cfg" | tr -d "'"); do
  case $id in "gnulinux-$rel-advanced-"*) entry=$id; break ;; esac
done
[ -n "$entry" ] || {{ echo "GRUB has no entry for $rel" >&2; exit {EXIT_NO_ENTRY}; }}
{target}
echo "GRUB boots $rel{when}""#,
                rel = quote(release),
                target = if *once {
                    // The default stays what it was: the first entry when nothing was saved.
                    format!("grub-editenv list | grep -q '^saved_entry=' || grub-set-default 0\n{set} \"${{sub:+$sub>}}$entry\"")
                } else {
                    format!("{set} \"${{sub:+$sub>}}$entry\"\ngrub-editenv - unset next_entry")
                },
                when = if *once { " next time" } else { "" },
            )
        }
        Action::BootNewest => format!(
            "set -e\nrm -f {GRUB_DROP_IN}\nupdate-grub\ngrub-editenv - unset saved_entry\ngrub-editenv - unset next_entry\necho 'GRUB boots the newest kernel'"
        ),
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    fn ubuntu(grub_default: &str, grubenv: &str) -> String {
        format!(
            "### running\n7.0.0-34-generic\n### os\nubuntu\ndebian\n### tools\napt-get\ndpkg-query\nupdate-grub\ngrub-set-default\ngrub-reboot\ngrub-editenv\n\
             ### packages\nlinux-image-7.0.0-31-generic\t7.0.0-31.31\tii \t\nlinux-image-7.0.0-34-generic\t7.0.0-34.34\tii \t\n\
             linux-image-unsigned-7.0.0-34-generic\t\tun \t\nlinux-image-virtual\t7.0.0-34.34\tii \tlinux-image-7.0.0-34-generic\n\
             ### archive\nListing...\nlinux-image-7.0.0-14-generic/resolute 7.0.0-14.14 amd64\nlinux-image-7.0.0-14-realtime/resolute 7.0.0-14.14.1 amd64\n\
             linux-image-7.0.0-31-generic/resolute-updates,resolute-security 7.0.0-31.31 amd64 [installed]\n\
             linux-image-7.0.0-38-generic/resolute-updates,resolute-security 7.0.0-38.38 amd64\n\
             linux-image-unsigned-7.0.0-38-generic/resolute-updates 7.0.0-38.38 amd64\n\
             linux-image-generic/resolute-updates 7.0.0-38.38 amd64\nlinux-image-uc-generic/resolute-updates 7.0.0-38.38 amd64\n\
             linux-image-aws/resolute-updates 7.0.0-1014.14 amd64\nlinux-image-generic-hwe-26.04/resolute-updates 7.0.0-38.38 amd64\n\
             linux-image-extra-virtual/resolute-updates 7.0.0-38.38 amd64\n\
             linux-image-virtual/resolute-updates,resolute-security 7.0.0-38.38 amd64 [upgradable from: 7.0.0-34.34]\n\
             ### grubDefault\n{grub_default}\n### grubenv\n{grubenv}\n### rebootRequired\nyes\n"
        )
    }

    #[test]
    fn reads_kernels_series_and_the_default() {
        let v = parse(&ubuntu("0", ""));
        assert!(v.supported && v.reboot_required);
        assert_eq!(v.installed.iter().map(|k| k.release.as_str()).collect::<Vec<_>>(), ["7.0.0-34-generic", "7.0.0-31-generic"]);
        let newest = &v.installed[0];
        assert!(newest.running && newest.default && newest.needed_by.as_deref() == Some("linux-image-virtual"));
        assert!(!v.installed[1].default && v.installed[1].needed_by.is_none());
        assert_eq!(v.pinned, None);
        assert_eq!(v.series.iter().map(|s| s.package.as_str()).collect::<Vec<_>>(), ["linux-image-virtual", "linux-image-generic", "linux-image-generic-hwe-26.04"]);
        assert_eq!(v.series[0].installed.as_deref(), Some("7.0.0-34.34"));
        // Other versions of `generic` not installed, newest first; no realtime, no unsigned.
        assert_eq!(v.versions.iter().map(|o| o.release.as_str()).collect::<Vec<_>>(), ["7.0.0-38-generic", "7.0.0-14-generic"]);

        let saved = "saved_entry=gnulinux-advanced-7476>gnulinux-7.0.0-31-generic-advanced-7476\nnext_entry=";
        let v = parse(&ubuntu("saved", saved));
        assert_eq!(v.pinned.as_deref(), Some("7.0.0-31-generic"));
        assert!(v.installed[1].default && !v.installed[0].default);
        let once = "saved_entry=0\nnext_entry=Advanced options for Ubuntu>Ubuntu, with Linux 7.0.0-31-generic";
        let v = parse(&ubuntu("saved", once));
        assert!(v.installed[0].default && v.installed[1].next);
    }

    #[test]
    fn refuses_what_would_break_booting() {
        let v = parse(&ubuntu("0", ""));
        let remove = |r: &str| check(&v, &Action::Remove { release: r.into() });
        assert_eq!(remove("7.0.0-34-generic"), Err("running"));
        assert_eq!(remove("7.0.0-1-generic"), Err("unknownKernel"));
        assert_eq!(remove("7.0.0-31-generic"), Ok(()));
        let v2 = parse(&ubuntu("saved", "saved_entry=gnulinux-advanced-x>gnulinux-7.0.0-31-generic-advanced-x"));
        assert_eq!(check(&v2, &Action::Remove { release: "7.0.0-31-generic".into() }), Err("booted"));
        let install = |p: &str| check(&v, &Action::Install { package: p.into() });
        assert_eq!(install("linux-image-7.0.0-38-generic"), Ok(()));
        assert_eq!(install("linux-image-virtual"), Ok(()), "an upgrade of a followed series");
        assert_eq!(install("linux-image-generic"), Ok(()));
        assert_eq!(install("linux-image-uc-generic"), Err("notOffered"));
        assert_eq!(install("linux-image-generic; reboot"), Err("invalidPackage"));
        assert_eq!(check(&v, &Action::Boot { release: "7.0.0-31-generic".into(), once: false }), Ok(()));
        let mut debian = v.clone();
        debian.supported = false;
        assert_eq!(check(&debian, &Action::BootNewest), Err("unsupported"));
    }

    #[test]
    fn orders_versions_and_flavours() {
        assert_eq!(compare_versions("7.0.0-38-generic", "7.0.0-4-generic"), Ordering::Greater);
        assert_eq!(compare_versions("6.12.48+deb13-amd64", "6.12.9+deb13-amd64"), Ordering::Greater);
        assert_eq!(compare_versions("1.0~rc1", "1.0"), Ordering::Less);
        assert_eq!(flavour("7.0.0-34-generic"), "generic");
        assert_eq!(flavour("6.12.48+deb13-cloud-amd64"), "cloud-amd64");
        assert_eq!(flavour("7.0.0-1005-oem"), "oem");
        assert_eq!(series_kind("linux-image-generic-hwe-26.04-edge"), "generic");
        assert_eq!(series_kind("linux-image-realtime-7.0"), "realtime");
        assert_eq!(series_kind("linux-image-azure-fde-lts-26.04"), "azure-fde");
        assert!(series_fits("linux-image-cloud-amd64", "amd64") && series_fits("linux-image-aws", "aws") && !series_fits("linux-image-aws", "generic"));
        assert_eq!(release_in_entry("gnulinux-advanced-u>gnulinux-6.12.48+deb13-amd64-advanced-u").as_deref(), Some("6.12.48+deb13-amd64"));
    }

    #[test]
    fn scripts_name_what_they_change() {
        let s = script(&Action::Boot { release: "7.0.0-31-generic".into(), once: false });
        assert!(s.contains(GRUB_DROP_IN) && s.contains("grub-set-default \"${sub:+$sub>}$entry\"") && s.contains("'7.0.0-31-generic'"));
        assert!(script(&Action::Boot { release: "7.0.0-31-generic".into(), once: true }).contains("grub-reboot"));
        assert!(script(&Action::Remove { release: "7.0.0-31-generic".into() }).contains("apt-get -s purge"));
        assert!(script(&Action::BootNewest).contains(&format!("rm -f {GRUB_DROP_IN}")));
    }
}
