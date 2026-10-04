//! Which of a PVE node's interfaces carry its management traffic, and so
//! must not be edited or have a pending configuration applied over them:
//! applying it would cut the host off, and there is nobody at the console to
//! fix it.
//!
//! The API does not say which interface a client reaches the node through,
//! so the node is asked directly ([`LIVE_NET_SCRIPT`], run on the node by
//! the caller's own transport: the agent runs it locally, the app over its
//! SSH or agent exec); without its answer every interface with an address is
//! protected.
//!
//! Ported from the app's `lib/data/model/virt/virt_manage.dart`.

use std::collections::{BTreeMap, BTreeSet};

use crate::resource::Network;

/// What [`parse_live_net`] reads: what the node itself says of the
/// interfaces it is using right now — addresses, default routes, the local
/// address of every established TCP connection, which device sits on which
/// (`/sys/class/net/*/lower_*`: a VLAN on its parent, a bridge on its ports,
/// a bond on its slaves), and the interfaces file as it is (what a pending
/// diff's line numbers count in). All of it readable without root.
///
/// `@end` only when every command that decides what is protected succeeded:
/// an empty `ss` or `ip` answer from a failed command would read as "no
/// connection, no route" and protect nothing. The IPv6 route is the one
/// allowed to fail (a kernel without IPv6).
pub const LIVE_NET_SCRIPT: &str = r#"ok=1
echo "@host $(hostname)"
echo '@addr'; ip -o addr show 2>/dev/null || ok=
echo '@route'; ip -o route show default 2>/dev/null || ok=; ip -o -6 route show default 2>/dev/null
echo '@conn'; ss -Htn state established 2>/dev/null || ok=
echo '@lower'; for d in /sys/class/net/*; do n=${d##*/}; for l in "$d"/lower_*; do [ -e "$l" ] && printf '%s %s\n' "$n" "${l##*/lower_}"; done; done
echo '@file'; cat /etc/network/interfaces 2>/dev/null || ok=
[ -n "$ok" ] && echo '@end'
"#;

/// What [`LIVE_NET_SCRIPT`] printed.
#[derive(Debug, Clone, Default, PartialEq, Eq, serde::Serialize, serde::Deserialize)]
pub struct LiveNet {
    /// The node it was read on (`hostname`, which is a PVE node's name): the
    /// only node this says anything about.
    pub host: String,
    /// The devices a default route (IPv4 or IPv6) goes through.
    pub routed: BTreeSet<String>,
    /// The devices carrying the local address of an established TCP
    /// connection — the client's among them, whatever it came through (SSH,
    /// the agent, a NAT in front of the node).
    pub connected: BTreeSet<String>,
    /// Each device's lower devices.
    pub lower: BTreeMap<String, BTreeSet<String>>,
    /// `/etc/network/interfaces` as it is now (not the pending `.new`).
    pub interfaces: String,
}

/// [`LIVE_NET_SCRIPT`]'s output; None when it did not run to the end or a
/// command it needs failed — `@end` is then not its last line.
pub fn parse_live_net(out: &str) -> Option<LiveNet> {
    if out.trim_end().lines().last().map(str::trim) != Some("@end") {
        return None;
    }
    let mut section = "";
    let mut host = String::new();
    let mut addrs: BTreeMap<String, String> = BTreeMap::new();
    let mut routed = BTreeSet::new();
    let mut local = BTreeSet::new();
    let mut lower: BTreeMap<String, BTreeSet<String>> = BTreeMap::new();
    let mut file = Vec::new();
    let dev = |name: &str| name.split('@').next().unwrap_or(name).to_owned();
    // `[::ffff:10.0.0.1]:22`, `10.0.0.1:22`, `[fe80::1%vmbr0]:22`
    let bare = |addr: &str| {
        let mut a = addr.trim();
        if let Some(port) = a.rfind(':').filter(|&p| p > 0) {
            a = &a[..port];
        }
        let mut a = a.replace(['[', ']'], "");
        if let Some(zone) = a.find('%') {
            a.truncate(zone);
        }
        if a.starts_with("::ffff:") && a.contains('.') {
            a = a[7..].to_owned();
        }
        a.to_ascii_lowercase()
    };
    for line in out.split('\n') {
        let t = line.trim();
        if section == "@file" && t != "@end" {
            file.push(line);
            continue;
        }
        if let Some(h) = t.strip_prefix("@host ") {
            host = h.trim().to_owned();
            continue;
        }
        if t.starts_with('@') {
            section = match t {
                "@addr" => "@addr",
                "@route" => "@route",
                "@conn" => "@conn",
                "@lower" => "@lower",
                "@file" => "@file",
                _ => "",
            };
            continue;
        }
        if t.is_empty() {
            continue;
        }
        let w: Vec<&str> = t.split_whitespace().collect();
        match section {
            "@addr" if w.len() >= 4 && (w[2] == "inet" || w[2] == "inet6") => {
                let address = w[3].split('/').next().unwrap_or_default().to_ascii_lowercase();
                addrs.insert(address, dev(w[1]));
            }
            "@route" => {
                if let Some(at) = w.iter().position(|x| *x == "dev")
                    && let Some(d) = w.get(at + 1)
                {
                    routed.insert(dev(d));
                }
            }
            "@conn" if w.len() >= 3 => {
                local.insert(bare(w[2]));
            }
            "@lower" if w.len() == 2 => {
                lower.entry(w[0].to_owned()).or_default().insert(w[1].to_owned());
            }
            _ => {}
        }
    }
    if host.is_empty() {
        return None;
    }
    let connected = local.iter().filter_map(|a| addrs.get(a)).filter(|d| *d != "lo").cloned().collect();
    routed.remove("lo");
    Some(LiveNet { host, routed, connected, lower, interfaces: file.join("\n") })
}

/// The interfaces that carry a node's management traffic, and every device
/// they sit on — the ones an edit or an apply must not touch.
///
/// Where the node answered (`live`): the devices its default routes go
/// through, and the ones carrying the local address of an established TCP
/// connection. Without it: every interface with an address. Either way,
/// every interface the listing gives a gateway (`gateway`, and `gateway6` in
/// `gateways6`) — the pending configuration's default route.
///
/// Then down to what each sits on: a VLAN's parent (`vmbr0` under
/// `vmbr0.10`, where turning VLAN awareness off would cut it), a bridge's
/// ports, a bond's slaves — from the node's own `lower_*` links and from the
/// listing (`bridge_ports`, `vlan-raw-device`, a `name.N` VLAN).
///
/// `also`: interfaces known to carry it some other way — what the old side
/// of a pending diff gave an address or a gateway ([`diff_ifaces`]), which
/// the listing, being the pending configuration, no longer says.
pub fn management_ifaces(
    networks: &[Network],
    live: Option<&LiveNet>,
    gateways6: &BTreeSet<String>,
    also: &BTreeSet<String>,
) -> BTreeSet<String> {
    let mut seeds: Vec<String> = gateways6.iter().chain(also).cloned().collect();
    seeds.extend(networks.iter().filter(|n| n.gateway.as_deref().is_some_and(|g| !g.is_empty())).map(|n| n.name.clone()));
    match live {
        Some(live) => seeds.extend(live.routed.iter().chain(&live.connected).cloned()),
        None => seeds.extend(networks.iter().filter(|n| !n.cidrs.is_empty()).map(|n| n.name.clone())),
    }
    let mut lower: BTreeMap<String, BTreeSet<String>> = live.map(|l| l.lower.clone()).unwrap_or_default();
    for n in networks {
        let under = lower.entry(n.name.clone()).or_default();
        under.extend(n.ports.iter().cloned());
        if let Some(d) = n.vlan_device.as_deref().filter(|d| !d.is_empty()) {
            under.insert(d.to_owned());
        }
        if let Some(dot) = n.name.rfind('.').filter(|&d| d > 0)
            && n.name[dot + 1..].parse::<u32>().is_ok()
        {
            under.insert(n.name[..dot].to_owned());
        }
    }
    let mut out = BTreeSet::new();
    while let Some(n) = seeds.pop() {
        if out.insert(n.clone())
            && let Some(under) = lower.get(&n)
        {
            seeds.extend(under.iter().cloned());
        }
    }
    out
}

/// Whether `network` may be edited and applied by a client at all: a
/// bridge (a physical interface's own settings are the host's), and not one
/// in `management`.
pub fn managed_iface(network: &Network, management: &BTreeSet<String>) -> bool {
    network.node.is_some() && network.mode == "bridge" && !management.contains(&network.name)
}

/// The interfaces a pending-configuration diff touches — see
/// [`diff_ifaces`].
#[derive(Debug, Clone, Default, PartialEq, Eq)]
pub struct DiffIfaces {
    pub ifaces: BTreeSet<String>,
    /// The diff does not tell whose some changed lines are.
    pub unknown: bool,
    /// Interfaces a removed line gave an address.
    pub old_addressed: BTreeSet<String>,
    /// Interfaces a removed line gave a gateway.
    pub old_gateways: BTreeSet<String>,
}

/// The interfaces a PVE pending-configuration diff (the network listing's
/// `changes`, a unified diff of `/etc/network/interfaces`) touches: the
/// stanza (`auto`/`iface`/`allow-*` line) each added or removed line is
/// under, and every interface an `auto`/`allow-*` line it adds or removes
/// names (`auto vmbr9 vmbr0` is both). A hunk that starts inside a stanza is
/// placed by its old line number in `interfaces` (the file as it is now);
/// without that, before any stanza, or under a file-wide directive
/// (`source`, `mapping`, ...) whose effect is no one interface's,
/// [`DiffIfaces::unknown`] says the diff does not tell whose lines they are.
///
/// The old side, for what the pending listing no longer says: a management
/// interface the pending configuration strips is still one until it is
/// applied.
pub fn diff_ifaces(diff: &str, interfaces: Option<&str>) -> DiffIfaces {
    let before: Option<Vec<&str>> = interfaces.map(|i| i.split('\n').collect());
    let mut out = DiffIfaces::default();
    let mut current: Option<String> = None;
    let single = |names: &[String]| (names.len() == 1).then(|| names[0].clone());
    for line in diff.split('\n') {
        if line.starts_with("---") || line.starts_with("+++") {
            continue;
        }
        if line.starts_with("@@") {
            current = None;
            // The last stanza line above where the hunk starts in the old
            // file.
            let from = line
                .strip_prefix("@@ -")
                .and_then(|r| r.split(|c: char| !c.is_ascii_digit()).next())
                .and_then(|n| n.parse::<usize>().ok());
            if let (Some(before), Some(from)) = (&before, from) {
                for l in before.iter().take(from.saturating_sub(1).min(before.len())) {
                    if let Some((names, _)) = ifupdown_line(l.trim()) {
                        current = single(&names);
                    }
                }
            }
            continue;
        }
        let Some(mark) = line.chars().next() else { continue };
        let body = line[mark.len_utf8()..].trim();
        let changed = mark == '+' || mark == '-';
        if let Some((names, iface)) = ifupdown_line(body) {
            // `auto a b` starts no stanza of its own: what follows is an
            // `iface` line's, or, before one, no one interface's.
            current = single(&names);
            if changed {
                out.ifaces.extend(names.iter().cloned());
            }
            if mark == '-' && iface && addressed_method(body) {
                out.old_addressed.extend(names);
            }
            continue;
        }
        if global_directive(body) {
            // Not an interface's option: what it does, and to which, is not
            // in the diff.
            current = None;
            if changed {
                out.unknown = true;
            }
            continue;
        }
        if !changed || body.is_empty() {
            continue;
        }
        match &current {
            // A `#` line is the stanza's too: PVE writes an interface's
            // `comments` as the lines after its own.
            Some(c) => {
                out.ifaces.insert(c.clone());
                if mark == '-' {
                    if option(body, "address") {
                        out.old_addressed.insert(c.clone());
                    }
                    if option(body, "gateway") {
                        out.old_gateways.insert(c.clone());
                    }
                }
            }
            // A comment above every stanza is the file's header.
            None if !body.starts_with('#') => out.unknown = true,
            None => {}
        }
    }
    out
}

/// An `auto`/`allow-*` line's interfaces, or an `iface` line's one (and
/// whether it is that); None for any other line.
fn ifupdown_line(line: &str) -> Option<(Vec<String>, bool)> {
    let w: Vec<&str> = line.split_whitespace().collect();
    if w.len() < 2 {
        return None;
    }
    if w[0] == "iface" {
        return Some((vec![w[1].to_owned()], true));
    }
    if w[0] == "auto" || w[0].starts_with("allow-") {
        return Some((w[1..].iter().map(|s| (*s).to_owned()).collect(), false));
    }
    None
}

fn word_at(body: &str, word: &str) -> bool {
    body.strip_prefix(word).is_some_and(|rest| !rest.starts_with(|c: char| c.is_alphanumeric() || c == '_'))
}

/// ifupdown's file-wide directives: not an interface's options.
fn global_directive(body: &str) -> bool {
    ["source", "source-directory", "mapping", "no-auto-down", "no-scripts", "rename"].iter().any(|d| word_at(body, d))
}

/// `address`/`address6`, `gateway`/`gateway6`.
fn option(body: &str, name: &str) -> bool {
    word_at(body, name) || word_at(body, &format!("{name}6"))
}

/// An `iface` line whose method gives the interface an address.
fn addressed_method(body: &str) -> bool {
    let w: Vec<&str> = body.split_whitespace().collect();
    w.windows(2).any(|p| (p[0] == "inet" || p[0] == "inet6") && matches!(p[1], "static" | "dhcp" | "auto"))
}
