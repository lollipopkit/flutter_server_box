//! What can go to free space on a Linux machine, measured and removed:
//! the package cache and packages nothing needs any more (apt), the journal
//! beyond [`JOURNAL_KEEP`], rotated logs, crash reports and core dumps, old
//! snap revisions; for the agent's account its trash, each folder in
//! `~/.cache` (each application's) and the package managers' download
//! caches ([`DEV_CACHES`]); and data a removed web app left (its folder, the
//! caller's to name). What Docker could reclaim is measured for the
//! Containers page, which prunes it.
//!
//! [`scan_script`] is root's (system logs and caches are not world-readable)
//! and lists every [`Item`]; [`clean_script`] removes the chosen ones, each
//! found by a fresh scan first ([`check`]): nothing is removed by a name a
//! page sent unless the scan found it.

use serde::{Deserialize, Serialize};

use crate::script::shell_quote_unix as q;

/// What `journalctl --vacuum-size` leaves.
pub const JOURNAL_KEEP: u64 = 64 << 20;
/// A folder in `~/.cache` smaller than this is not listed.
pub const CACHE_MIN: u64 = 1 << 20;

/// The package managers' download caches outside `~/.cache`: id and the
/// path under the home folder. pip, Go and yarn keep theirs in `~/.cache`.
pub const DEV_CACHES: &[(&str, &str)] = &[("npm", ".npm/_cacache"), ("cargo", ".cargo/registry/cache"), ("gradle", ".gradle/caches"), ("maven", ".m2/repository")];

const LOGS_FIND: &str = r"/var/log -type f \( -name '*.gz' -o -name '*.xz' -o -name '*.zst' -o -name '*.[0-9]' -o -name '*.old' \)";

#[derive(Debug, Clone, Copy, PartialEq, Eq, Serialize, Deserialize)]
#[serde(rename_all = "camelCase")]
pub enum Group {
    System,
    /// The agent's account: trash, application caches, package managers'.
    Account,
    /// Folders removed web apps left.
    Apps,
    /// What Docker could reclaim; pruned on the Containers page.
    Containers,
}

#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct Item {
    /// `apt-cache`, `cache:<folder>`, `dev:npm`, `leftover:<app>`, `docker:Images`…
    pub id: String,
    pub group: Group,
    /// What removing it frees, as measured.
    pub bytes: u64,
    /// Files, packages or revisions, where that is what it holds.
    pub count: Option<u64>,
    /// Packages, a path: what it is, for the page to show.
    pub detail: Option<String>,
    /// [`clean_script`] removes it here; Docker's are pruned elsewhere.
    pub cleanable: bool,
}

/// A folder name in `~/.cache` this may remove: no path, nothing hidden
/// behind a control character.
fn folder_ok(name: &str) -> bool {
    !name.is_empty() && name != "." && name != ".." && !name.contains('/') && !name.chars().any(char::is_control) && name.len() <= 255
}

/// An app id as stacks name them (`<publisher>.<name>`).
fn app_ok(id: &str) -> bool {
    !id.is_empty() && id.len() <= 128 && id.bytes().all(|b| b.is_ascii_alphanumeric() || b"._-".contains(&b)) && !id.starts_with('.')
}

/// Root's scan. [home] is the agent's account's home folder; [leftovers]
/// are removed web apps' folders (`app id`, path) to measure.
pub fn scan_script(home: &str, leftovers: &[(String, String)]) -> String {
    let mut s = format!(
        r#"home={home}
item() {{ printf 'ITEM\t%s\t%s\t%s\t%s\n' "$1" "${{2:-0}}" "${{3:-}}" "${{4:-}}"; }}
size() {{ du -sb -- "$@" 2>/dev/null | awk '{{s+=$1}} END {{printf "%.0f", s}}'; }}
files() {{ find "$@" -printf '%s\n' 2>/dev/null | awk '{{s+=$1; n++}} END {{printf "%.0f\t%d", s, n}}'; }}
if [ -d /var/cache/apt/archives ]; then
  f=$(files /var/cache/apt/archives -maxdepth 2 -type f -name '*.deb'); item apt-cache "${{f%%	*}}" "${{f#*	}}"
fi
if command -v apt-get >/dev/null; then
  p=$(apt-get -s autoremove --purge 2>/dev/null | sed -n 's/^\(Purg\|Remv\) \([^ ]*\).*/\2/p' | tr '\n' ' ')
  kb=0; [ -n "$p" ] && kb=$(dpkg-query -W -f='${{Installed-Size}}\n' $p 2>/dev/null | awk '{{s+=$1}} END {{printf "%.0f", s}}')
  item autoremove "$((kb * 1024))" "$(printf '%s\n' $p | grep -c .)" "$p"
fi
[ -d /var/log/journal ] && item journal "$(size /var/log/journal)"
f=$(files {LOGS_FIND}); item rotated-logs "${{f%%	*}}" "${{f#*	}}"
[ -d /var/crash ] && {{ f=$(files /var/crash -mindepth 1 -maxdepth 1 -type f); item crash-reports "${{f%%	*}}" "${{f#*	}}"; }}
[ -d /var/lib/systemd/coredump ] && {{ f=$(files /var/lib/systemd/coredump -mindepth 1 -maxdepth 1 -type f); item core-dumps "${{f%%	*}}" "${{f#*	}}"; }}
if command -v snap >/dev/null; then
  r=$(snap list --all 2>/dev/null | awk 'NR > 1 && $NF ~ /disabled/ {{print $1 "_" $3}}' | tr '\n' ' ')
  b=0; for x in $r; do b=$((b + $(stat -c %s "/var/lib/snapd/snaps/$x.snap" 2>/dev/null || echo 0))); done
  item snap-revisions "$b" "$(printf '%s\n' $r | grep -c .)" "$r"
fi
[ -d "$home/.local/share/Trash" ] && item trash "$(size "$home/.local/share/Trash")" "$(find "$home/.local/share/Trash/files" -mindepth 1 -maxdepth 1 2>/dev/null | wc -l)"
if [ -d "$home/.cache" ]; then
  for d in "$home"/.cache/* "$home"/.cache/.[!.]*; do
    [ -e "$d" ] && [ ! -L "$d" ] || continue
    printf 'CACHE\t%s\t%s\n' "${{d##*/}}" "$(size "$d")"
  done
fi
"#,
        home = q(home)
    );
    for (id, path) in DEV_CACHES {
        s.push_str(&format!("[ -d \"$home/{path}\" ] && item dev:{id} \"$(size \"$home/{path}\")\" '' \"$home/{path}\"\n"));
    }
    for (id, path) in leftovers.iter().filter(|(id, _)| app_ok(id)) {
        s.push_str(&format!("[ -d {p} ] && item leftover:{id} \"$(size {p})\" '' {p}\n", p = q(path)));
    }
    s.push_str("command -v docker >/dev/null && docker system df --format '{{.Type}}\t{{.Reclaimable}}' 2>/dev/null | sed 's/^/DOCKER\t/'\ntrue\n");
    s
}

/// `1.2GB (50%)` → bytes (Docker's units are powers of 1000).
fn docker_bytes(s: &str) -> u64 {
    let n = s.split_whitespace().next().unwrap_or("");
    let at = n.find(|c: char| c.is_ascii_alphabetic()).unwrap_or(n.len());
    let (num, unit) = n.split_at(at);
    let mult = match unit.to_ascii_uppercase().as_str() {
        "B" | "" => 1.0,
        "KB" | "K" => 1e3,
        "MB" | "M" => 1e6,
        "GB" | "G" => 1e9,
        "TB" | "T" => 1e12,
        _ => return 0,
    };
    num.parse::<f64>().map(|v| (v * mult) as u64).unwrap_or(0)
}

/// [`scan_script`]'s output.
pub fn parse_scan(out: &str) -> Vec<Item> {
    let mut items = Vec::new();
    for line in out.lines() {
        let f: Vec<&str> = line.split('\t').collect();
        let num = |i: usize| f.get(i).and_then(|v| v.trim().parse::<u64>().ok());
        let text = |i: usize| f.get(i).map(|v| v.trim()).filter(|v| !v.is_empty()).map(str::to_string);
        match f.first().copied() {
            Some("ITEM") if f.len() >= 3 => {
                let id = f[1].to_string();
                let group = if id.starts_with("dev:") || id == "trash" {
                    Group::Account
                } else if id.starts_with("leftover:") {
                    Group::Apps
                } else {
                    Group::System
                };
                let mut bytes = num(2).unwrap_or(0);
                if id == "journal" {
                    bytes = bytes.saturating_sub(JOURNAL_KEEP);
                }
                items.push(Item { id, group, bytes, count: num(3), detail: text(4), cleanable: true });
            }
            Some("CACHE") if f.len() >= 3 && folder_ok(f[1]) => {
                let bytes = num(2).unwrap_or(0);
                if bytes >= CACHE_MIN {
                    items.push(Item { id: format!("cache:{}", f[1]), group: Group::Account, bytes, count: None, detail: None, cleanable: true });
                }
            }
            Some("DOCKER") if f.len() >= 3 => {
                items.push(Item { id: format!("docker:{}", f[1].trim()), group: Group::Containers, bytes: docker_bytes(f[2]), count: None, detail: None, cleanable: false });
            }
            _ => {}
        }
    }
    items
}

/// Whether [ids] may be cleaned: each found by [scan], cleanable here.
pub fn check(scan: &[Item], ids: &[String]) -> Result<(), &'static str> {
    if ids.is_empty() {
        return Err("nothingChosen");
    }
    for id in ids {
        let item = scan.iter().find(|i| &i.id == id).ok_or("unknownItem")?;
        if !item.cleanable {
            return Err("notCleanable");
        }
    }
    Ok(())
}

/// Root's script that removes [ids] (after [`check`]) for the account whose
/// home is [home]; a removed web app's folder is the one [leftovers] names
/// for it (as root: its containers' users own some of its files).
pub fn clean_script(home: &str, ids: &[String], leftovers: &[(String, String)]) -> String {
    let mut s = format!("home={}\n", q(home));
    for id in ids {
        let step = match id.as_str() {
            "apt-cache" => "apt-get clean".to_string(),
            "autoremove" => "DEBIAN_FRONTEND=noninteractive apt-get autoremove --purge -y".to_string(),
            "journal" => format!("journalctl --vacuum-size={}M", JOURNAL_KEEP >> 20),
            "rotated-logs" => format!("find {LOGS_FIND} -delete"),
            "crash-reports" => "find /var/crash -mindepth 1 -maxdepth 1 -type f -delete".to_string(),
            "core-dumps" => "find /var/lib/systemd/coredump -mindepth 1 -maxdepth 1 -type f -delete".to_string(),
            "snap-revisions" => "snap list --all | awk 'NR > 1 && $NF ~ /disabled/ {print $1, $3}' | while read -r n r; do snap remove \"$n\" --revision=\"$r\"; done".to_string(),
            "trash" => "find \"$home/.local/share/Trash\" -mindepth 2 -maxdepth 2 -exec rm -rf -- {} +".to_string(),
            other => {
                if let Some(name) = other.strip_prefix("cache:").filter(|n| folder_ok(n)) {
                    format!("rm -rf -- \"$home/.cache/\"{}", q(name))
                } else if let Some((_, path)) = other.strip_prefix("dev:").and_then(|t| DEV_CACHES.iter().find(|(id, _)| *id == t)) {
                    format!("rm -rf -- \"$home/{path}\"")
                } else if let Some((_, path)) = leftover_app(other).and_then(|app| leftovers.iter().find(|(id, _)| id == app)) {
                    format!("rm -rf -- {}", q(path))
                } else {
                    continue;
                }
            }
        };
        s.push_str(&format!("echo '== {id}'\n{step} || echo '{id}: did not finish' >&2\n"));
    }
    s
}

/// The folder in the account's [home] an account item removes: what the
/// caller checks against its own state before offering it.
pub fn account_path(home: &str, id: &str) -> Option<String> {
    let home = home.trim_end_matches('/');
    if id == "trash" {
        return Some(format!("{home}/.local/share/Trash"));
    }
    if let Some(name) = id.strip_prefix("cache:").filter(|n| folder_ok(n)) {
        return Some(format!("{home}/.cache/{name}"));
    }
    let tool = id.strip_prefix("dev:")?;
    DEV_CACHES.iter().find(|(t, _)| *t == tool).map(|(_, path)| format!("{home}/{path}"))
}

/// The removed web app [id] a `leftover:` item names.
pub fn leftover_app(id: &str) -> Option<&str> {
    id.strip_prefix("leftover:").filter(|a| app_ok(a))
}

#[cfg(test)]
mod tests {
    use super::*;

    const SCAN: &str = "ITEM\tapt-cache\t52428800\t12\t\nITEM\tautoremove\t104857600\t2\tlinux-modules-7.0.0-31-generic linux-image-7.0.0-31-generic \n\
        ITEM\tjournal\t134217728\t\t\nITEM\trotated-logs\t2048\t3\t\nITEM\ttrash\t4096\t1\t\n\
        CACHE\tpip\t20971520\nCACHE\ttiny\t100\nCACHE\t../etc\t99999999\nITEM\tdev:npm\t3145728\t\t/home/sbm/.npm/_cacache\n\
        ITEM\tleftover:futo.immich\t1073741824\t\t/srv/stacks/futo.immich\nDOCKER\tImages\t1.5GB (40%)\nDOCKER\tBuild Cache\t0B\n";

    #[test]
    fn reads_a_scan() {
        let items = parse_scan(SCAN);
        let get = |id: &str| items.iter().find(|i| i.id == id).unwrap_or_else(|| panic!("{id}"));
        assert_eq!((get("apt-cache").bytes, get("apt-cache").count), (52428800, Some(12)));
        assert_eq!(get("journal").bytes, 64 << 20, "what is past the 64 MiB kept");
        assert!(get("autoremove").detail.as_deref().unwrap().contains("linux-image-7.0.0-31-generic"));
        assert_eq!(get("cache:pip").group, Group::Account);
        assert!(!items.iter().any(|i| i.id == "cache:tiny" || i.id.contains("..")));
        assert_eq!(get("leftover:futo.immich").group, Group::Apps);
        let images = get("docker:Images");
        assert_eq!((images.bytes, images.cleanable, images.group), (1_500_000_000, false, Group::Containers));
        assert_eq!(get("docker:Build Cache").bytes, 0);
    }

    #[test]
    fn cleans_only_what_the_scan_found() {
        let items = parse_scan(SCAN);
        let ids = |v: &[&str]| v.iter().map(|s| s.to_string()).collect::<Vec<_>>();
        assert_eq!(check(&items, &ids(&["apt-cache", "cache:pip"])), Ok(()));
        assert_eq!(check(&items, &ids(&["cache:../etc"])), Err("unknownItem"));
        assert_eq!(check(&items, &ids(&["docker:Images"])), Err("notCleanable"));
        assert_eq!(check(&items, &[]), Err("nothingChosen"));
        let left = [("futo.immich".to_string(), "/srv/stacks/futo.immich".to_string())];
        let s = clean_script("/home/sbm", &ids(&["apt-cache", "journal", "cache:pip", "dev:npm", "cache:../etc", "leftover:futo.immich", "leftover:other.app"]), &left);
        assert!(s.starts_with("home='/home/sbm'\n") && s.contains("apt-get clean") && s.contains("--vacuum-size=64M"));
        assert!(s.contains("rm -rf -- \"$home/.cache/\"'pip'") && s.contains("rm -rf -- \"$home/.npm/_cacache\""));
        assert!(s.contains("rm -rf -- '/srv/stacks/futo.immich'") && !s.contains("../etc") && !s.contains("other.app"));
        assert_eq!(leftover_app("leftover:futo.immich"), Some("futo.immich"));
        assert_eq!(account_path("/home/sbm/", "cache:pip").as_deref(), Some("/home/sbm/.cache/pip"));
        assert_eq!(account_path("/home/sbm", "dev:cargo").as_deref(), Some("/home/sbm/.cargo/registry/cache"));
        assert_eq!(account_path("/home/sbm", "journal"), None);
        assert_eq!(leftover_app("leftover:../x"), None);
        let scan = scan_script("/home/sbm", &[("futo.immich".into(), "/srv/stacks/futo.immich".into()), ("../x".into(), "/etc".into())]);
        assert!(scan.contains("item leftover:futo.immich") && !scan.contains("'/etc'") && scan.contains("dev:cargo"));
    }
}
