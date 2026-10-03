//! Editing an existing libvirt network (phase 10).
//!
//! A network is changed either by writing its definition again
//! (`net-define`) or, for the parts libvirt applies on the fly, with
//! `net-update`. Which one each field takes is decided here, once:
//!
//! | Field | How | Why |
//! | --- | --- | --- |
//! | mode, IPv4 address and prefix, DHCP range, host bridge | `net-define`, with the network restarted to apply | `net-update` has no command for the mode or the address, and its `ip-dhcp-range` is checked against the *running* network's subnet — which is the old one until the network is restarted |
//! | the static DHCP hosts | `net-update add/delete ip-dhcp-host` | libvirt applies it live and writes it into the definition, and it is checked against the definition |
//!
//! `net-define` on an active network replaces the definition only: the
//! running network keeps its address, its bridge and its dnsmasq until it is
//! restarted, and a restart cuts every guest on it off. So the restart is
//! asked for, never assumed. A restart writes the new definition *before*
//! stopping anything (a definition the host refuses leaves the running
//! network as it was), keeps the running network's own XML, and a network
//! that then fails to start is started again from that XML (`net-create`,
//! which libvirt 11.3 takes for a persistent network that is down: verified,
//! the network running exactly as before and still persistent) with the old
//! definition put back ([`KEY_NET_ROLLBACK`]).
//!
//! The definition edited is the one `net-dumpxml` printed, with only the
//! elements this app writes replaced: everything else in it (an IPv6
//! address, a `<dns>`, a `<domain>`, the `<forward>` of another mode) is
//! kept exactly as the host wrote it.

use sbm_parser::script::{self, shell_quote_unix};
use crate::libvirt::{
    CONNECT_URI, RC_PREFIX, VirtError, prelude, run_fn, sections, take, xml_escape,
};
use serde::{Deserialize, Serialize};

/// A step: its failure ends the script.
pub const KEY_NET_STEP: &str = "virt.net.step";
/// The definition changed since it was read.
pub const KEY_NET_CONFLICT: &str = "virt.net.conflict";
/// The network did not start on the new definition; the old one is back.
pub const KEY_NET_ROLLBACK: &str = "virt.net.rollback";
/// The network was started again as it ran before.
pub const KEY_NET_RESTORED: &str = "virt.net.restored";
/// The old definition could not be put back: the new one stays.
pub const KEY_NET_DEF_KEPT: &str = "virt.net.def_kept";

/// A static DHCP host entry: one address handed to one MAC.
#[derive(Debug, Clone, Default, PartialEq, Eq, Serialize, Deserialize)]
pub struct VirtNetHost {
    /// Lowercase `52:54:00:…`
    pub mac: String,
    pub ip: String,
    /// The name dnsmasq is told, where one is given.
    #[serde(default)]
    pub name: Option<String>,
}

/// What a network is edited to. `mode` is one of `nat`, `route`, `isolated`
/// and `bridge`; the address and the DHCP range apply to every mode but
/// `bridge`, whose addressing is the host bridge's own.
#[derive(Debug, Clone, Default, PartialEq, Eq, Serialize, Deserialize)]
pub struct VirtNetEdit {
    pub mode: String,
    /// `bridge` mode: the host bridge guests are handed to.
    #[serde(default)]
    pub bridge: Option<String>,
    /// The host's address on the network, without its prefix; none for a
    /// network without one (an isolated one).
    #[serde(default)]
    pub address: Option<String>,
    #[serde(default)]
    pub prefix: Option<u8>,
    #[serde(default)]
    pub dhcp_start: Option<String>,
    #[serde(default)]
    pub dhcp_end: Option<String>,
    /// The static hosts the network ends up with.
    #[serde(default)]
    pub hosts: Vec<VirtNetHost>,
}

/// The parts of a `<network>` this module reads back.
#[derive(Debug, Clone, Default, PartialEq, Eq, Serialize, Deserialize)]
pub struct VirtNetSection {
    pub mode: String,
    #[serde(default)]
    pub bridge: Option<String>,
    /// The first IPv4 `<ip>`, without its prefix.
    #[serde(default)]
    pub address: Option<String>,
    #[serde(default)]
    pub prefix: Option<u8>,
    /// The first DHCP range of that `<ip>`.
    #[serde(default)]
    pub dhcp_start: Option<String>,
    #[serde(default)]
    pub dhcp_end: Option<String>,
    /// Every static host the network hands out.
    #[serde(default)]
    pub hosts: Vec<VirtNetHost>,
}

/// One change to an existing libvirt network.
#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize)]
#[serde(tag = "op", rename_all = "snake_case")]
pub enum VirtNetOp {
    /// Writes `edit` into the network's definition. With `restart` an active
    /// network is stopped and started on it, so the running one applies it
    /// too — the guests on it lose their link meanwhile.
    Edit {
        name: String,
        edit: VirtNetEdit,
        /// The definition as read; a change since is refused.
        base_xml: String,
        /// The network is active: only then is `restart` worth asking for.
        active: bool,
        restart: bool,
        /// Restart the network even where `edit` asks for nothing that
        /// needs it. What a plain restart is (`VirtNetworkRestart`): the
        /// definition already has the change and the running network is to
        /// be put on it.
        #[serde(default)]
        force_restart: bool,
    },
    /// Stops and starts `name` with no definition written either way: the
    /// change is already in the definition, and the running network is to be
    /// put on it. A `net-destroy` and a `net-start` and nothing else.
    Restart {
        name: String,
        /// The definition as read, for what the view said would happen.
        #[serde(default)]
        base_xml: String,
    },
}

fn is_ipv4(s: &str) -> bool {
    s.parse::<std::net::Ipv4Addr>().is_ok()
}

fn is_mac(s: &str) -> bool {
    let parts: Vec<&str> = s.split(':').collect();
    parts.len() == 6 && parts.iter().all(|p| p.len() == 2 && p.chars().all(|c| c.is_ascii_hexdigit()))
}

/// A dnsmasq host name, as libvirt writes it into the `name` attribute.
fn is_host_name(s: &str) -> bool {
    !s.is_empty()
        && s.len() <= 63
        && !s.starts_with('-')
        && !s.ends_with('-')
        && s.chars().all(|c| c.is_ascii_alphanumeric() || c == '-' || c == '_')
}

/// A Linux interface name (`IFNAMSIZ` - 1).
fn is_ifname(s: &str) -> bool {
    !s.is_empty()
        && s.len() <= 15
        && !s.starts_with('-')
        && s.chars().all(|c| c.is_ascii_alphanumeric() || "._-".contains(c))
}

/// A network name libvirt named: whatever it is, one line.
fn is_net_name(s: &str) -> bool {
    !s.is_empty() && !s.chars().any(char::is_control)
}

impl VirtNetEdit {
    /// Refuses a value that would land in an XML document. The app checks
    /// what the user typed first; this is the last line before a host.
    pub fn check(&self) -> Result<(), VirtError> {
        let bad = |what: &str| {
            Err(VirtError::Malformed {
                message: format!("invalid network edit: {what}"),
            })
        };
        match self.mode.as_str() {
            "bridge" => {
                if self.bridge.as_deref().is_none_or(|b| !is_ifname(b)) {
                    return bad("bridge");
                }
                if self.address.is_some()
                    || self.prefix.is_some()
                    || self.dhcp_start.is_some()
                    || self.dhcp_end.is_some()
                    || !self.hosts.is_empty()
                {
                    return bad("bridge addressing");
                }
            }
            "nat" | "route" | "isolated" => {
                if self.bridge.is_some() {
                    return bad("bridge");
                }
                match (&self.address, self.prefix) {
                    (Some(address), Some(prefix)) => {
                        let Ok(addr) = address.parse::<std::net::Ipv4Addr>() else {
                            return bad("address");
                        };
                        let addr = u32::from(addr);
                        if !(8..=30).contains(&prefix) {
                            return bad("prefix");
                        }
                        let mask = u32::MAX << (32 - prefix);
                        let net = addr & mask;
                        let broadcast = net | !mask;
                        if addr == net || addr == broadcast {
                            return bad("address");
                        }
                        // A static host is handed out on this subnet: one
                        // outside it, or on the network's own addresses,
                        // is one dnsmasq never serves.
                        for h in &self.hosts {
                            let Ok(ip) = h.ip.parse::<std::net::Ipv4Addr>() else {
                                return bad("static host");
                            };
                            let ip = u32::from(ip);
                            if ip & mask != net || ip == net || ip == broadcast || ip == addr {
                                return bad("static host outside the subnet");
                            }
                        }
                        match (&self.dhcp_start, &self.dhcp_end) {
                            (None, None) => {}
                            (Some(s), Some(e)) => {
                                let (Ok(s), Ok(e)) =
                                    (s.parse::<std::net::Ipv4Addr>(), e.parse::<std::net::Ipv4Addr>())
                                else {
                                    return bad("dhcp range");
                                };
                                let (s, e) = (u32::from(s), u32::from(e));
                                if s > e
                                    || s & mask != net
                                    || e & mask != net
                                    || s == net
                                    || e == broadcast
                                    || (s..=e).contains(&addr)
                                {
                                    return bad("dhcp range");
                                }
                            }
                            _ => return bad("dhcp range"),
                        }
                    }
                    (None, None) => {
                        // A range and a static host need an address to be
                        // served on: without one they would be dropped.
                        if self.dhcp_start.is_some() || self.dhcp_end.is_some() {
                            return bad("dhcp range");
                        }
                        if !self.hosts.is_empty() {
                            return bad("static host without an address");
                        }
                        if self.mode == "nat" || self.mode == "route" {
                            return bad("address");
                        }
                    }
                    _ => return bad("address"),
                }
            }
            _ => return bad("mode"),
        }
        for (i, h) in self.hosts.iter().enumerate() {
            if !is_mac(&h.mac) || !is_ipv4(&h.ip) || h.name.as_deref().is_some_and(|n| !is_host_name(n)) {
                return bad("static host");
            }
            // libvirt refuses a second entry for a MAC or an address.
            if self.hosts[..i]
                .iter()
                .any(|o| o.mac.eq_ignore_ascii_case(&h.mac) || o.ip == h.ip)
            {
                return bad("duplicate static host");
            }
        }
        Ok(())
    }

    /// Whether the running network has to be restarted for this edit to
    /// apply. Only the static hosts do not: `net-update` takes them live.
    ///
    /// The bridge is compared only in `bridge` mode: every other mode has
    /// the device libvirt chose itself (`virbr1`), which this app does not
    /// write and which is not a change.
    pub fn needs_restart(&self, base: &VirtNetSection) -> bool {
        self.mode != base.mode
            || self.address != base.address
            || self.prefix != base.prefix
            || self.dhcp_start != base.dhcp_start
            || self.dhcp_end != base.dhcp_end
            || (self.mode == "bridge" && self.bridge != base.bridge)
    }
}

fn prefix_of_netmask(mask: &str) -> Option<u8> {
    let octets: Vec<u8> = mask.split('.').map(|o| o.parse().ok()).collect::<Option<_>>()?;
    if octets.len() != 4 {
        return None;
    }
    let n = u32::from_be_bytes([octets[0], octets[1], octets[2], octets[3]]);
    (n.leading_ones() + n.trailing_zeros() == 32).then_some(n.leading_ones() as u8)
}

/// `net-dumpxml` as [`VirtNetSection`]: the fields an edit is compared
/// against, and the ones the view shows.
pub fn parse_net_section(raw: &str) -> Result<VirtNetSection, VirtError> {
    let doc = roxmltree::Document::parse(raw.trim()).map_err(|e| VirtError::Malformed {
        message: format!("net-dumpxml: {e}"),
    })?;
    let root = doc.root_element();
    let child = |name: &str| root.children().find(|n| n.is_element() && n.tag_name().name() == name);
    let mode = match child("forward").and_then(|f| f.attribute("mode")) {
        Some(m) => m.to_string(),
        None => "isolated".to_string(),
    };
    let ip = root
        .children()
        .find(|n| n.is_element() && n.tag_name().name() == "ip" && n.attribute("family") != Some("ipv6"));
    let (address, prefix, dhcp_start, dhcp_end, hosts) = match ip {
        Some(ip) => {
            let dhcp = ip.children().find(|n| n.is_element() && n.tag_name().name() == "dhcp");
            let range = dhcp.and_then(|d| d.children().find(|n| n.is_element() && n.tag_name().name() == "range"));
            let hosts = dhcp
                .map(|d| {
                    d.children()
                        .filter(|n| n.is_element() && n.tag_name().name() == "host")
                        .filter_map(host_of)
                        .collect()
                })
                .unwrap_or_default();
            (
                ip.attribute("address").map(str::to_string),
                ip.attribute("prefix")
                    .and_then(|p| p.parse().ok())
                    .or_else(|| ip.attribute("netmask").and_then(prefix_of_netmask)),
                range.and_then(|r| r.attribute("start")).map(str::to_string),
                range.and_then(|r| r.attribute("end")).map(str::to_string),
                hosts,
            )
        }
        None => (None, None, None, None, Vec::new()),
    };
    Ok(VirtNetSection {
        mode,
        bridge: child("bridge").and_then(|b| b.attribute("name")).map(str::to_string),
        address,
        prefix,
        dhcp_start,
        dhcp_end,
        hosts,
    })
}

/// `xml` with the attribute `name` of `node` cut out, as the host wrote the
/// rest: namespace declarations (`xmlns:dnsmasq`) included, which
/// roxmltree does not list as attributes.
fn without_attribute(xml: &str, node: roxmltree::Node<'_, '_>, name: &str) -> Option<String> {
    let a = node.attributes().find(|a| a.name() == name && a.namespace().is_none())?;
    let r = a.range();
    // The whitespace before it goes with it.
    let start = xml[..r.start].trim_end().len();
    Some(format!("{}{}", &xml[..start], &xml[r.end..]))
}

/// `base_xml` — the definition `net-dumpxml` printed — with what [edit] sets
/// replaced: `<forward>`, `<bridge>`, the first IPv4 `<ip>` with its DHCP
/// range and static hosts. Every other line stays as the host wrote it,
/// byte for byte.
///
/// Worked out on the definition's lines rather than on byte ranges: each
/// element this app writes is a whole line of libvirt's own printing, and a
/// byte-range insertion lands inside the line a removal ends.
pub fn edit_network_xml(base_xml: &str, edit: &VirtNetEdit) -> Result<String, VirtError> {
    edit.check()?;
    let start = base_xml.find("<network").ok_or_else(|| VirtError::Malformed {
        message: "no <network> element".into(),
    })?;
    let xml = base_xml[start..].trim_end();
    let doc = roxmltree::Document::parse(xml).map_err(|e| VirtError::Malformed {
        message: format!("net-dumpxml: {e}"),
    })?;
    let root = doc.root_element();
    let child = |name: &str| root.children().find(|n| n.is_element() && n.tag_name().name() == name);
    let base_mode = match child("forward").and_then(|f| f.attribute("mode")) {
        Some(m) => m.to_string(),
        None => "isolated".to_string(),
    };
    let e = xml_escape;
    // The first and last line an element occupies.
    let first_line = |n: roxmltree::Node<'_, '_>| xml[..n.range().start].matches('\n').count();
    let last_line = |n: roxmltree::Node<'_, '_>| xml[..n.range().end].matches('\n').count();
    // What each line of the definition becomes; `None` drops it.
    let mut out: Vec<Option<String>> = xml.lines().map(|l| Some(l.to_string())).collect();
    // Writes the lines an element occupies: a replacement on its first
    // line, and the rest of the element dropped — an element of libvirt's
    // own printing can span several (`<forward mode='nat'>` with its
    // `<nat>`).
    fn set_element(
        out: &mut [Option<String>],
        xml: &str,
        n: roxmltree::Node<'_, '_>,
        text: Option<String>,
    ) {
        let first = xml[..n.range().start].matches('\n').count();
        let last = xml[..n.range().end].matches('\n').count();
        // The indentation of the line it replaces.
        let before = out[first].clone().unwrap_or_default();
        let indent = before.len() - before.trim_start().len();
        for line in out.iter_mut().take(last + 1).skip(first) {
            *line = None;
        }
        if let Some(text) = text {
            out[first] = Some(format!("{}{text}", " ".repeat(indent)));
        }
    }
    // The lines to add, after `<name>` — where libvirt writes the rest:
    // name, uuid, forward, bridge, mac, ip.
    let mut added: Vec<String> = Vec::new();
    let after_name = child("name").map(|n| first_line(n) + 1).unwrap_or(1);

    // `connections=` counts the live interfaces and belongs to no
    // definition: the one `net-dumpxml` printed would be written as a
    // number that never changes. (An `--inactive` read, which is what the
    // app edits, has none.)
    if let Some(cut) = without_attribute(xml, root, "connections") {
        // `xml` starts at `<network`, whose start tag is libvirt's first line.
        out[0] = cut.lines().next().map(str::to_string);
    }

    // <forward>: the mode. A network of its own gets none. An unchanged
    // mode keeps the element as the host wrote it: its `dev=`, its `<nat>`
    // addresses and port range are not the form's to drop.
    let forward_xml = match edit.mode.as_str() {
        "nat" => "<forward mode='nat'/>",
        "route" => "<forward mode='route'/>",
        "isolated" => "",
        _ => "<forward mode='bridge'/>",
    };
    match (child("forward"), forward_xml.is_empty()) {
        (Some(_), _) if edit.mode == base_mode => {}
        (Some(f), true) => set_element(&mut out, xml, f, None),
        (Some(f), false) => set_element(&mut out, xml, f, Some(forward_xml.to_string())),
        (None, false) => added.push(format!("  {forward_xml}")),
        (None, true) => {}
    }

    // <bridge name>: a bridge-mode network names the host bridge; every
    // other mode has libvirt's own device, kept as it is — except when the
    // mode was `bridge`, whose element would keep the network tied to the
    // host's bridge.
    let bridge_xml = match (edit.mode.as_str(), edit.bridge.as_deref()) {
        ("bridge", Some(b)) => Some(format!("<bridge name='{}'/>", e(b))),
        _ => None,
    };
    match (child("bridge"), bridge_xml) {
        (Some(b), Some(x)) => set_element(&mut out, xml, b, Some(x)),
        (Some(b), None) if base_mode == "bridge" => set_element(&mut out, xml, b, None),
        (Some(_), None) => {}
        (None, Some(x)) => added.push(format!("  {x}")),
        (None, None) => {}
    }
    if edit.mode == "bridge" {
        // A host bridge has the host's own addressing. libvirt refuses an
        // `<ip>` (IPv6 too), a `<dns>`, a `<domain>` and a `<mac>` on a
        // bridge-mode network (`virNetworkDefParseXML`: "Unsupported <…>
        // element in network … with forward mode='bridge'"), so they go
        // with the mode.
        for n in root.children().filter(|n| {
            n.is_element() && matches!(n.tag_name().name(), "ip" | "dns" | "domain" | "mac")
        }) {
            set_element(&mut out, xml, n, None);
        }
    } else {
        // The first IPv4 <ip>: the address, the first range and the static
        // hosts. A second subnet and every IPv6 address are kept.
        let first4 = root.children().find(|n| {
            n.is_element() && n.tag_name().name() == "ip" && n.attribute("family") != Some("ipv6")
        });
        match (first4, edit.address.as_deref()) {
            (Some(ip), Some(address)) => {
                let (first, last) = (first_line(ip), last_line(ip));
                let mut body: Vec<Option<String>> =
                    ip_element(xml, Some(ip), edit, address).into_iter().map(Some).collect();
                // The lines it took, padded so later line numbers still hold.
                body.resize(body.len().max(last + 1 - first), None);
                out.splice(first..=last, body);
            }
            (Some(ip), None) => set_element(&mut out, xml, ip, None),
            (None, Some(address)) => added.extend(ip_element(xml, None, edit, address)),
            (None, None) => {}
        }
    }

    let mut lines: Vec<&str> = out.iter().filter_map(|l| l.as_deref()).collect();
    if !added.is_empty() {
        let at = after_name.min(lines.len());
        lines.splice(at..at, added.iter().map(String::as_str));
    }
    let mut text = lines.join("\n");
    text.push('\n');
    roxmltree::Document::parse(&text).map_err(|e| VirtError::Malformed {
        message: format!("edited network XML: {e}"),
    })?;
    Ok(text)
}

/// The lines the first IPv4 `<ip>` is written as: the address, the prefix,
/// the first DHCP range and the static hosts from `edit`. Of the element it
/// replaces (`base`), everything else is kept as the host wrote it — its
/// other attributes (`localPtr=`), a second range, a range's `<lease>`,
/// `<tftp>`, `<bootp>`. A kept range outside the new subnet is the host's to
/// refuse; the definition is written before the network is stopped, so a
/// refusal leaves it running as it was.
fn ip_element<'a, 'i>(
    xml: &str,
    base: Option<roxmltree::Node<'a, 'i>>,
    edit: &VirtNetEdit,
    address: &str,
) -> Vec<String> {
    fn elements<'a, 'i>(n: roxmltree::Node<'a, 'i>) -> Vec<roxmltree::Node<'a, 'i>> {
        n.children().filter(|c| c.is_element()).collect()
    }
    let e = xml_escape;
    let prefix = edit.prefix.unwrap_or(24);
    let src = |n: roxmltree::Node<'_, '_>| xml[n.range()].to_string();
    let mut attrs = String::new();
    for a in base.iter().flat_map(|b| b.attributes()) {
        if !matches!(a.name(), "address" | "prefix" | "netmask") {
            attrs.push_str(&format!(" {}='{}'", a.name(), e(a.value())));
        }
    }
    let mut body = vec![format!("  <ip address='{}' prefix='{prefix}'{attrs}>", e(address))];

    let dhcp = base.and_then(|b| elements(b).into_iter().find(|c| c.tag_name().name() == "dhcp"));
    let old_ranges: Vec<_> = dhcp
        .map(|d| elements(d).into_iter().filter(|c| c.tag_name().name() == "range").collect())
        .unwrap_or_default();
    let mut dhcp_lines: Vec<String> = Vec::new();
    if let (Some(s), Some(end)) = (&edit.dhcp_start, &edit.dhcp_end) {
        let bounds = format!("start='{}' end='{}'", e(s), e(end));
        // The first range keeps what is under it (a `<lease>`).
        match old_ranges.first().filter(|r| r.has_children()) {
            Some(r) => {
                let inner = &xml[r.first_child().unwrap().range().start..r.last_child().unwrap().range().end];
                dhcp_lines.push(format!("<range {bounds}>{inner}</range>"));
            }
            None => dhcp_lines.push(format!("<range {bounds}/>")),
        }
    }
    dhcp_lines.extend(old_ranges.iter().skip(1).map(|r| src(*r)));
    // The static hosts: an entry the edit leaves as it was keeps the host's
    // own text (a `<lease>` under it, attributes the form does not show), and
    // one the form never saw — no MAC, or no address (`id=`, a name alone) —
    // is kept whole. Only a changed entry is rewritten, in its place; a
    // removed one goes, and a new one is added after them.
    let mut written = vec![false; edit.hosts.len()];
    for h in dhcp
        .map(elements)
        .unwrap_or_default()
        .into_iter()
        .filter(|c| c.tag_name().name() == "host")
    {
        let Some(old) = host_of(h) else {
            dhcp_lines.push(src(h));
            continue;
        };
        let Some(i) = edit.hosts.iter().position(|n| n.mac.eq_ignore_ascii_case(&old.mac)) else {
            continue;
        };
        written[i] = true;
        dhcp_lines.push(if same_host(&old, &edit.hosts[i]) {
            src(h)
        } else {
            host_xml(&edit.hosts[i], false)
        });
    }
    dhcp_lines.extend(
        edit.hosts
            .iter()
            .zip(&written)
            .filter(|(_, w)| !**w)
            .map(|(h, _)| host_xml(h, false)),
    );
    // Anything else under <dhcp> (`<bootp>`).
    if let Some(d) = dhcp {
        dhcp_lines.extend(
            elements(d)
                .into_iter()
                .filter(|c| !matches!(c.tag_name().name(), "range" | "host"))
                .map(src),
        );
    }
    let mut children: Vec<String> = Vec::new();
    if !dhcp_lines.is_empty() {
        children.push("<dhcp>".to_string());
        children.extend(dhcp_lines.into_iter().map(|l| format!("  {l}")));
        children.push("</dhcp>".to_string());
    }
    // Anything else under <ip> (`<tftp>`).
    if let Some(b) = base {
        children.extend(elements(b).into_iter().filter(|c| c.tag_name().name() != "dhcp").map(src));
    }
    body.extend(children.into_iter().map(|c| format!("    {c}")));
    body.push("  </ip>".to_string());
    body
}

/// The static-host entries [edit] adds and removes against [base], as
/// `net-update` takes them, one change per entry.
///
/// A host is the same host when its MAC is: that is what dnsmasq keys on and
/// what libvirt refuses a duplicate of. An entry rewritten under the same
/// MAC is a delete and an add.
pub fn host_changes(base: &VirtNetSection, edit: &VirtNetEdit) -> (Vec<VirtNetHost>, Vec<VirtNetHost>) {
    let find = |list: &[VirtNetHost], mac: &str| list.iter().find(|h| h.mac.eq_ignore_ascii_case(mac)).cloned();
    let mut add = Vec::new();
    let mut delete = Vec::new();
    for h in &edit.hosts {
        match find(&base.hosts, &h.mac) {
            Some(old) if same_host(&old, h) => {}
            Some(old) => {
                delete.push(old);
                add.push(h.clone());
            }
            None => add.push(h.clone()),
        }
    }
    for h in &base.hosts {
        if find(&edit.hosts, &h.mac).is_none() {
            delete.push(h.clone());
        }
    }
    (add, delete)
}

/// The same host, whatever the case it was written in: a MAC is read
/// without one, and libvirt writes it lowercase.
fn same_host(a: &VirtNetHost, b: &VirtNetHost) -> bool {
    a.mac.eq_ignore_ascii_case(&b.mac) && a.ip == b.ip && a.name == b.name
}

/// A `<dhcp>` `<host>` as [`VirtNetHost`]: `None` for an entry the form
/// cannot show (no MAC, or no address).
fn host_of(h: roxmltree::Node<'_, '_>) -> Option<VirtNetHost> {
    Some(VirtNetHost {
        mac: h.attribute("mac")?.to_ascii_lowercase(),
        ip: h.attribute("ip")?.to_string(),
        name: h.attribute("name").map(str::to_string),
    })
}

/// The `<host>` element `net-update` takes. A delete matches on the MAC
/// alone — libvirt's own comparison, which every other attribute must not
/// take part in — so an entry rewritten under the same MAC is always found.
fn host_xml(host: &VirtNetHost, for_delete: bool) -> String {
    let e = xml_escape;
    let mut x = format!("<host mac='{}'", e(&host.mac.to_ascii_lowercase()));
    if !for_delete
        && let Some(name) = &host.name
        && !name.is_empty()
    {
        x.push_str(&format!(" name='{}'", e(name)));
    }
    x.push_str(&format!(" ip='{}'/>", e(&host.ip)));
    x
}

/// `define --file` of `xml` through a temporary file, as a step: the script
/// is on `sh`'s stdin, which no command here may read. Its failure ends the
/// script; see [`define_try`] for one that does not.
fn define_step(xml: &str) -> String {
    format!("{}[ \"$r\" = 0 ] || exit 0\n", define_try(xml))
}

/// [`define_step`] whose failure is left in `$r` for the caller.
fn define_try(xml: &str) -> String {
    format!(
        "echo '{}'\nf=$(mktemp 2>&1) || {{ printf '%s\\n{RC_PREFIX}1\\n' \"$f\"; f=; r=1; }}\n\
         if [ -n \"$f\" ]; then printf '%s' {} >\"$f\"; R net-define \"$f\"; rm -f \"$f\"; fi\n",
        script::cmd_marker(KEY_NET_STEP),
        shell_quote_unix(xml),
    )
}

/// The running network's own XML, kept in `$live` (removed when the script
/// ends) to start it again from if a restart fails. A step.
fn save_live(n: &str) -> String {
    format!(
        "echo '{}'\nlive=$(mktemp 2>&1); r=$?\n\
         if [ \"$r\" = 0 ]; then trap 'rm -f \"$live\"' EXIT; \
         virsh --connect {CONNECT_URI} -q net-dumpxml --network {n} </dev/null >\"$live\" 2>&1; r=$?; \
         [ \"$r\" = 0 ] || cat \"$live\"; else printf '%s\\n' \"$live\"; fi\n\
         printf '\\n{RC_PREFIX}%s\\n' \"$r\"\n[ \"$r\" = 0 ] || exit 0\n",
        script::cmd_marker(KEY_NET_STEP),
    )
}

/// The network stopped and started again; a start that fails is answered by
/// `restore` (the definition put back, for an edit) and a `net-create` of
/// the XML [`save_live`] kept. Ends the script.
fn restart_steps(n: &str, restore: Option<&str>) -> String {
    let mut s = step(&format!("net-destroy --network {n}"));
    s.push_str(&format!(
        "echo '{}'\nR net-start --network {n}\nif [ \"$r\" = 0 ]; then exit 0; fi\n",
        script::cmd_marker(KEY_NET_STEP)
    ));
    s.push_str(&format!("echo '{}'\n", script::cmd_marker(KEY_NET_ROLLBACK)));
    if let Some(xml) = restore {
        s.push_str(&define_try(xml));
        s.push_str(&format!(
            "[ \"$r\" = 0 ] || echo '{}'\n",
            script::cmd_marker(KEY_NET_DEF_KEPT)
        ));
    }
    s.push_str(&format!(
        "echo '{}'\nR net-create \"$live\"\n[ \"$r\" = 0 ] && echo '{}'\nexit 0\n",
        script::cmd_marker(KEY_NET_STEP),
        script::cmd_marker(KEY_NET_RESTORED),
    ));
    s
}

/// The definition a change was made from, read again: a change made
/// meanwhile is refused rather than undone.
///
/// `--inactive`, because that is what the caller was given
/// ([`crate::libvirt::networks_script`] reads it for the edit): a running
/// network's own XML carries what libvirt writes at start — a NAT `<port>`
/// range, a `portid=` on an interface — which the definition does not have,
/// and comparing the two would refuse every edit.
fn guard(name: &str, base_xml: &str) -> String {
    format!(
        "echo '{step}'\ncur=$(virsh --connect {CONNECT_URI} -q net-dumpxml --inactive --network {n} </dev/null 2>&1); r=$?\n\
         if [ \"$r\" != 0 ]; then printf '%s\\n{RC_PREFIX}%s\\n' \"$cur\" \"$r\"; exit 0; fi\n\
         printf '\\n{RC_PREFIX}0\\n'\n\
         if [ \"$cur\" != {prev} ]; then echo '{conflict}'; exit 0; fi\n",
        step = script::cmd_marker(KEY_NET_STEP),
        n = shell_quote_unix(name),
        prev = shell_quote_unix(base_xml.trim_end_matches(['\n', '\r'])),
        conflict = script::cmd_marker(KEY_NET_CONFLICT),
    )
}

/// A step: its failure ends the script.
fn step(args: &str) -> String {
    format!(
        "echo '{}'\nR {args}\n[ \"$r\" = 0 ] || exit 0\n",
        script::cmd_marker(KEY_NET_STEP)
    )
}

/// The script making `op`. Parse with [`parse_net_change`].
pub fn net_change_script(op: &VirtNetOp) -> Result<String, VirtError> {
    // A restart of its own: no definition is written, because what is to be
    // restarted onto is already in it.
    if let VirtNetOp::Restart { name, base_xml } = op {
        if !is_net_name(name) {
            return Err(VirtError::Malformed {
                message: "invalid network name".into(),
            });
        }
        let q = shell_quote_unix;
        let n = q(name);
        let mut s = prelude();
        s.push_str(&run_fn());
        if !base_xml.is_empty() {
            // The same guard as an edit: a network redefined to something
            // else since this was read is not restarted onto it blind.
            s.push_str(&guard(name, base_xml));
        }
        s.push_str(&save_live(&n));
        s.push_str(&restart_steps(&n, None));
        return Ok(s);
    }
    let VirtNetOp::Edit { name, edit, base_xml, active, restart, force_restart } = op else {
        return Err(VirtError::Malformed {
            message: "invalid network change".into(),
        });
    };
    edit.check()?;
    if !is_net_name(name) {
        return Err(VirtError::Malformed {
            message: "invalid network name".into(),
        });
    }
    let base = parse_net_section(base_xml)?;
    let edited = edit_network_xml(base_xml, edit)?;
    let q = shell_quote_unix;
    let n = q(name);
    let mut s = prelude();
    s.push_str(&run_fn());
    s.push_str(&guard(name, base_xml));
    // The static hosts go through `net-update`, which applies them at once
    // and writes them into the definition. On a network whose address
    // changes in the same edit they are written into the new definition
    // instead: `net-update` checks a range against the definition, which
    // still has the old address, and would refuse an address outside it.
    let restarts = *force_restart || edit.needs_restart(&base);
    let (add, delete) = if restarts { (Vec::new(), Vec::new()) } else { host_changes(&base, edit) };
    // `--live --config`: the running network takes it now, *and* the
    // definition keeps it — which is what makes this a change and not a
    // thing the next start forgets. On an inactive network `--live` is
    // refused ("network is not running"), so only the definition is
    // written.
    let flags = if *active { " --live --config" } else { " --config" };
    for h in &delete {
        s.push_str(&step(&format!(
            "net-update --network {n} delete ip-dhcp-host {}{flags}",
            q(&host_xml(h, true))
        )));
    }
    for h in &add {
        s.push_str(&step(&format!(
            "net-update --network {n} add ip-dhcp-host {}{flags}",
            q(&host_xml(h, false))
        )));
    }
    if !restarts {
        return Ok(s);
    }
    if !(*restart && *active) {
        // The definition, not the running network: what is on is applied at
        // its next start, and restarted by hand meanwhile if it is wanted
        // now. The view says so.
        s.push_str(&define_step(&edited));
        return Ok(s);
    }
    // The network is running and is to take the change now. Its own XML
    // kept and the new definition written while it still runs — a
    // definition the host refuses stops the script with nothing stopped —
    // then stopped and started. A start that fails puts the old definition
    // back and starts the network again as it ran.
    s.push_str(&save_live(&n));
    s.push_str(&define_step(&edited));
    s.push_str(&restart_steps(&n, Some(base_xml)));
    Ok(s)
}

/// [`net_change_script`]'s output: `Ok` when the change is in; `Conflict`
/// when the definition changed since it was read; the host's words
/// otherwise, with what became of the network when a restart failed.
pub fn parse_net_change(raw: &str) -> Result<(), VirtError> {
    let segs = script::parse_script_segments(raw);
    let secs = sections(raw)?;
    let steps: Vec<_> = secs.iter().filter(|(k, _)| k == KEY_NET_STEP).collect();
    if steps.is_empty() {
        take(&secs, KEY_NET_STEP, raw)?;
    }
    if segs.iter().any(|(k, _)| k == KEY_NET_CONFLICT) {
        return Err(VirtError::Conflict {
            message: "The network changed since it was read".into(),
        });
    }
    let failed = steps.iter().find_map(|(_, s)| s.ok().err());
    if let Some(e) = &failed
        && segs.iter().any(|(k, _)| k == KEY_NET_ROLLBACK)
    {
        let has = |key: &str| segs.iter().any(|(k, _)| k == key);
        let mut message = format!(
            "{}\n{}",
            e.message(),
            if has(KEY_NET_RESTORED) {
                "The network did not start; it was started again as it ran before."
            } else {
                "The network did not start, and starting it again as it ran before failed too: it is down."
            }
        );
        if has(KEY_NET_DEF_KEPT) {
            message.push_str(" Its saved configuration is the new one: putting the previous one back failed.");
        }
        return Err(VirtError::Command { message });
    }
    match failed {
        Some(e) => Err(e),
        None => Ok(()),
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    const BASE: &str = "<network connections='1'>\n  <name>lab</name>\n  <uuid>0d1c</uuid>\n  <forward mode='nat'>\n    <nat>\n      <port start='1024' end='65535'/>\n    </nat>\n  </forward>\n  <bridge name='virbr1' stp='on' delay='0'/>\n  <mac address='52:54:00:53:b8:f5'/>\n  <ip address='192.168.150.1' prefix='24'>\n    <dhcp>\n      <range start='192.168.150.100' end='192.168.150.200'/>\n      <host mac='52:54:00:aa:bb:01' name='h1' ip='192.168.150.10'/>\n    </dhcp>\n  </ip>\n  <ip family='ipv6' address='fd00::1' prefix='64'/>\n</network>\n";

    fn edit(mode: &str) -> VirtNetEdit {
        VirtNetEdit { mode: mode.into(), ..Default::default() }
    }

    fn section(raw: &str) -> VirtNetSection {
        parse_net_section(raw).unwrap()
    }

    #[test]
    fn reads_a_definition_back() {
        let s = section(BASE);
        assert_eq!(s.mode, "nat");
        assert_eq!(s.address.as_deref(), Some("192.168.150.1"));
        assert_eq!(s.prefix, Some(24));
        assert_eq!(s.dhcp_start.as_deref(), Some("192.168.150.100"));
        assert_eq!(s.dhcp_end.as_deref(), Some("192.168.150.200"));
        assert_eq!(s.bridge.as_deref(), Some("virbr1"));
        assert_eq!(s.hosts.len(), 1);
        assert_eq!(s.hosts[0].name.as_deref(), Some("h1"));
        let iso = section(
            "<network>\n  <name>i</name>\n  <ip address='10.0.0.1' netmask='255.255.0.0'/>\n</network>\n",
        );
        assert_eq!(iso.mode, "isolated");
        assert_eq!(iso.prefix, Some(16));
        assert!(iso.hosts.is_empty());
        let br = section(
            "<network>\n  <name>b</name>\n  <forward mode='bridge'/>\n  <bridge name='br0'/>\n</network>\n",
        );
        assert_eq!(br.mode, "bridge");
        assert_eq!(br.bridge.as_deref(), Some("br0"));
        assert_eq!(br.address, None);
    }

    #[test]
    fn edits_keep_what_they_do_not_set() {
        let mut e = edit("nat");
        e.address = Some("192.168.151.1".into());
        e.prefix = Some(24);
        e.dhcp_start = Some("192.168.151.100".into());
        e.dhcp_end = Some("192.168.151.200".into());
        e.hosts = vec![VirtNetHost {
            mac: "52:54:00:aa:bb:01".into(),
            ip: "192.168.151.10".into(),
            name: Some("h1".into()),
        }];
        let out = edit_network_xml(BASE, &e).unwrap();
        // The mode is unchanged: the host's `<forward>` stays whole.
        assert!(out.contains("<forward mode='nat'>\n    <nat>\n      <port start='1024' end='65535'/>"), "{out}");
        assert!(out.contains("<bridge name='virbr1' stp='on' delay='0'/>"), "{out}");
        assert!(out.contains("<ip address='192.168.151.1' prefix='24'>"), "{out}");
        assert!(out.contains("<range start='192.168.151.100' end='192.168.151.200'/>"), "{out}");
        assert!(out.contains("<host mac='52:54:00:aa:bb:01' name='h1' ip='192.168.151.10'/>"), "{out}");
        // The IPv6 address and the UUID are somebody else's.
        assert!(out.contains("<ip family='ipv6' address='fd00::1' prefix='64'/>"), "{out}");
        assert!(out.contains("<uuid>0d1c</uuid>"), "{out}");
        // No `connections=` any more: it counts the live interfaces.
        assert!(!out.contains("connections="), "{out}");
        // Readable as XML, and back as the same section.
        let back = section(&out);
        assert_eq!(back.address.as_deref(), Some("192.168.151.1"));
        assert_eq!(back.hosts[0].ip, "192.168.151.10");
    }

    #[test]
    fn mode_changes() {
        let mut route = edit("route");
        route.address = Some("192.168.150.1".into());
        route.prefix = Some(24);
        let out = edit_network_xml(BASE, &route).unwrap();
        assert!(out.contains("<forward mode='route'/>"), "{out}");
        assert!(!out.contains("mode='nat'"), "{out}");

        let mut iso = edit("isolated");
        iso.address = Some("192.168.150.1".into());
        iso.prefix = Some(24);
        let out = edit_network_xml(BASE, &iso).unwrap();
        assert!(!out.contains("<forward"), "{out}");
        assert!(out.contains("<ip address='192.168.150.1' prefix='24'>"), "{out}");

        // A host bridge: the host's own addressing, no <ip> of its own.
        let mut br = edit("bridge");
        br.bridge = Some("br0".into());
        let out = edit_network_xml(BASE, &br).unwrap();
        assert!(out.contains("<forward mode='bridge'/>"), "{out}");
        assert!(out.contains("<bridge name='br0'/>"), "{out}");
        assert!(!out.contains("192.168.150.1"), "{out}");
        // Every <ip>, the <mac>: libvirt refuses them in this mode.
        assert!(!out.contains("<ip"), "{out}");
        assert!(!out.contains("<mac"), "{out}");

        // Out of bridge mode again: libvirt's own device comes back.
        let bridged = "<network>\n  <name>b</name>\n  <forward mode='bridge'/>\n  <bridge name='br0'/>\n  <ip family='ipv6' address='fd00::1' prefix='64'/>\n</network>\n";
        let mut nat = edit("nat");
        nat.address = Some("10.20.0.1".into());
        nat.prefix = Some(24);
        let out = edit_network_xml(bridged, &nat).unwrap();
        assert!(out.contains("<forward mode='nat'/>"), "{out}");
        assert!(!out.contains("br0"), "{out}");

        // An isolated network without an address at all.
        let mut none = edit("isolated");
        none.address = None;
        let out = edit_network_xml(BASE, &none).unwrap();
        assert!(!out.contains("<ip address"), "{out}");
        assert!(out.contains("<ip family='ipv6'"), "{out}");
    }

    /// What the form does not edit stays: a second range, a range's lease,
    /// `<tftp>`, `<bootp>`, `localPtr=`, a namespace declaration, and — in
    /// a mode that allows them — `<dns>` and `<domain>`. A bridge-mode edit
    /// drops the ones libvirt refuses there.
    #[test]
    fn edits_keep_the_rest_of_the_ip() {
        let base = "<network xmlns:dnsmasq='http://libvirt.org/schemas/network/dnsmasq/1.0'>\n  <name>lab</name>\n  <uuid>0d1c</uuid>\n  <forward mode='nat'/>\n  <bridge name='virbr1' stp='on' delay='0'/>\n  <mac address='52:54:00:53:b8:f5'/>\n  <domain name='lab.test' localOnly='yes'/>\n  <dns>\n    <host ip='192.168.150.1'>\n      <hostname>gw</hostname>\n    </host>\n  </dns>\n  <ip address='192.168.150.1' netmask='255.255.255.0' localPtr='yes'>\n    <tftp root='/srv/tftp'/>\n    <dhcp>\n      <range start='192.168.150.100' end='192.168.150.150'>\n        <lease expiry='1' unit='hours'/>\n      </range>\n      <range start='192.168.150.160' end='192.168.150.170'/>\n      <host mac='52:54:00:aa:bb:01' ip='192.168.150.10'/>\n      <bootp file='pxelinux.0'/>\n    </dhcp>\n  </ip>\n  <dnsmasq:options>\n    <dnsmasq:option value='log-queries'/>\n  </dnsmasq:options>\n</network>\n";
        let mut e = edit("nat");
        e.address = Some("192.168.150.1".into());
        e.prefix = Some(24);
        e.dhcp_start = Some("192.168.150.110".into());
        e.dhcp_end = Some("192.168.150.140".into());
        e.hosts = vec![VirtNetHost { mac: "52:54:00:aa:bb:02".into(), ip: "192.168.150.11".into(), name: None }];
        let out = edit_network_xml(base, &e).unwrap();
        for kept in [
            "xmlns:dnsmasq='http://libvirt.org/schemas/network/dnsmasq/1.0'",
            "<dnsmasq:option value='log-queries'/>",
            "localPtr='yes'",
            "<tftp root='/srv/tftp'/>",
            "<lease expiry='1' unit='hours'/>",
            "<range start='192.168.150.160' end='192.168.150.170'/>",
            "<bootp file='pxelinux.0'/>",
            "<domain name='lab.test' localOnly='yes'/>",
            "<hostname>gw</hostname>",
        ] {
            assert!(out.contains(kept), "{kept}\n{out}");
        }
        assert!(out.contains("<range start='192.168.150.110' end='192.168.150.140'>"), "{out}");
        assert!(out.contains("<ip address='192.168.150.1' prefix='24' localPtr='yes'>"), "{out}");
        assert!(!out.contains("netmask="), "{out}");
        // The hosts are the edit's.
        assert!(out.contains("<host mac='52:54:00:aa:bb:02' ip='192.168.150.11'/>"), "{out}");
        assert!(!out.contains("52:54:00:aa:bb:01"), "{out}");
        let back = section(&out);
        assert_eq!(back.dhcp_start.as_deref(), Some("192.168.150.110"));
        assert_eq!(back.prefix, Some(24));

        // To a host bridge: what libvirt refuses there goes.
        let mut br = edit("bridge");
        br.bridge = Some("br0".into());
        let out = edit_network_xml(base, &br).unwrap();
        for gone in ["<ip", "<dns>", "<domain", "<mac", "stp="] {
            assert!(!out.contains(gone), "{gone}\n{out}");
        }
        assert!(out.contains("<dnsmasq:option value='log-queries'/>"), "{out}");
    }

    /// An unchanged mode keeps `<forward>` as written (`dev=`, `<nat>`'s
    /// address and port range); unchanged static hosts keep theirs (a
    /// `<lease>`), and a host the form cannot show (no MAC) is kept.
    #[test]
    fn an_edit_rewrites_only_what_changed() {
        let base = "<network>\n  <name>lab</name>\n  <forward mode='nat' dev='eth1'>\n    <nat>\n      <address start='203.0.113.10' end='203.0.113.20'/>\n      <port start='2000' end='3000'/>\n    </nat>\n  </forward>\n  <ip address='192.168.150.1' prefix='24'>\n    <dhcp>\n      <range start='192.168.150.100' end='192.168.150.200'/>\n      <host mac='52:54:00:aa:bb:01' name='h1' ip='192.168.150.10'>\n        <lease expiry='2' unit='hours'/>\n      </host>\n      <host id='0:1:0:1:2:3:4:5' name='by-id' ip='192.168.150.11'/>\n      <host mac='52:54:00:aa:bb:03' ip='192.168.150.13'/>\n      <host mac='52:54:00:aa:bb:04' ip='192.168.150.14'/>\n    </dhcp>\n  </ip>\n</network>\n";
        let mut e = edit("nat");
        e.address = Some("192.168.150.1".into());
        e.prefix = Some(24);
        e.dhcp_start = Some("192.168.150.120".into());
        e.dhcp_end = Some("192.168.150.180".into());
        let host = |mac: &str, ip: &str, name: Option<&str>| VirtNetHost {
            mac: mac.into(),
            ip: ip.into(),
            name: name.map(str::to_string),
        };
        e.hosts = vec![
            // Unchanged, written in another case.
            host("52:54:00:AA:BB:01", "192.168.150.10", Some("h1")),
            // Changed: .03 → .33. `.04` removed. `.05` new.
            host("52:54:00:aa:bb:03", "192.168.150.33", None),
            host("52:54:00:aa:bb:05", "192.168.150.15", None),
        ];
        let out = edit_network_xml(base, &e).unwrap();
        for kept in [
            "<forward mode='nat' dev='eth1'>",
            "<address start='203.0.113.10' end='203.0.113.20'/>",
            "<port start='2000' end='3000'/>",
            "<lease expiry='2' unit='hours'/>",
            "<host id='0:1:0:1:2:3:4:5' name='by-id' ip='192.168.150.11'/>",
            "<host mac='52:54:00:aa:bb:03' ip='192.168.150.33'/>",
            "<host mac='52:54:00:aa:bb:05' ip='192.168.150.15'/>",
            "<range start='192.168.150.120' end='192.168.150.180'/>",
        ] {
            assert!(out.contains(kept), "{kept}\n{out}");
        }
        assert!(!out.contains("192.168.150.13'"), "{out}");
        assert!(!out.contains("bb:04"), "{out}");
        let back = section(&out);
        assert_eq!(
            back.hosts.iter().map(|h| h.ip.as_str()).collect::<Vec<_>>(),
            ["192.168.150.10", "192.168.150.33", "192.168.150.15"]
        );
        // A mode change writes the new mode's element.
        let mut route = e.clone();
        route.mode = "route".into();
        let out = edit_network_xml(base, &route).unwrap();
        assert!(out.contains("<forward mode='route'/>") && !out.contains("<nat>"), "{out}");
    }

    #[test]
    fn a_bridge_is_defined_where_there_was_none() {
        let base = "<network>\n  <name>i</name>\n  <ip address='10.0.0.1' prefix='24'/>\n</network>\n";
        let mut e = edit("bridge");
        e.bridge = Some("br7".into());
        let out = edit_network_xml(base, &e).unwrap();
        assert!(out.contains("<forward mode='bridge'/>"), "{out}");
        assert!(out.contains("<bridge name='br7'/>"), "{out}");
        // The address goes: a host bridge has the host's.
        assert!(!out.contains("<ip address"), "{out}");
    }

    #[test]
    fn hosts_are_compared_by_mac() {
        let base = section(BASE);
        let mut e = edit("nat");
        e.address = Some("192.168.150.1".into());
        e.prefix = Some(24);
        // The same MAC in another case is the same host: nothing changes.
        e.hosts = vec![
            VirtNetHost { mac: "52:54:00:AA:BB:01".into(), ip: "192.168.150.10".into(), name: Some("h1".into()) },
            VirtNetHost { mac: "52:54:00:aa:bb:02".into(), ip: "192.168.150.11".into(), name: None },
        ];
        let (add, delete) = host_changes(&base, &e);
        assert_eq!(add.len(), 1);
        assert_eq!(add[0].mac, "52:54:00:aa:bb:02");
        assert!(delete.is_empty());

        // The same MAC with another address: a delete and an add.
        e.hosts = vec![VirtNetHost { mac: "52:54:00:aa:bb:01".into(), ip: "192.168.150.12".into(), name: Some("h1".into()) }];
        let (add, delete) = host_changes(&base, &e);
        assert_eq!(add.len(), 1, "{add:?} {delete:?}");
        assert_eq!(add[0].ip, "192.168.150.12");
        assert_eq!(delete.len(), 1);
        assert_eq!(delete[0].ip, "192.168.150.10");

        e.hosts = Vec::new();
        let (add, delete) = host_changes(&base, &e);
        assert!(add.is_empty());
        assert_eq!(delete.len(), 1);

        // A delete carries no name: libvirt matches on the MAC.
        assert_eq!(host_xml(&delete[0], true), "<host mac='52:54:00:aa:bb:01' ip='192.168.150.10'/>");
        assert_eq!(host_xml(&delete[0], false), "<host mac='52:54:00:aa:bb:01' name='h1' ip='192.168.150.10'/>");
    }

    #[test]
    fn checks_refuse_what_would_escape() {
        let mut e = edit("nat");
        e.address = Some("192.168.150.1".into());
        e.prefix = Some(24);
        assert!(e.check().is_ok());
        assert!(e.needs_restart(&section(BASE)));
        // A range outside the subnet, reversed, or over the host's address
        for (s, end) in [
            ("10.0.0.2", "10.0.0.9"),
            ("192.168.150.200", "192.168.150.100"),
            ("192.168.150.1", "192.168.150.9"),
            ("192.168.150.2", "192.168.150.255"),
        ] {
            e.dhcp_start = Some(s.into());
            e.dhcp_end = Some(end.into());
            assert!(e.check().is_err(), "{s}-{end}");
        }
        e.dhcp_start = None;
        e.dhcp_end = None;
        // Half an address, and an address that is not one.
        e.prefix = None;
        assert!(e.check().is_err());
        e.prefix = Some(24);
        e.address = Some("192.168.150.0".into());
        assert!(e.check().is_err());
        e.address = Some("192.168.150.1".into());
        e.prefix = Some(31);
        assert!(e.check().is_err());
        // A bridge mode with its own addressing, and without a bridge.
        let mut br = edit("bridge");
        br.bridge = Some("br0".into());
        br.address = Some("10.0.0.1".into());
        br.prefix = Some(24);
        assert!(br.check().is_err());
        let mut br = edit("bridge");
        assert!(br.check().is_err());
        br.bridge = Some("br0; id".into());
        assert!(br.check().is_err());
        // Static hosts.
        let host = |mac: &str, ip: &str, name: Option<&str>| VirtNetHost {
            mac: mac.into(),
            ip: ip.into(),
            name: name.map(str::to_string),
        };
        let mut h = edit("isolated");
        h.address = Some("10.0.0.1".into());
        h.prefix = Some(24);
        h.hosts = vec![host("nope", "10.0.0.5", None)];
        assert!(h.check().is_err());
        h.hosts = vec![host("52:54:00:aa:bb:01", "10.0.0.5", Some("a b"))];
        assert!(h.check().is_err());
        h.hosts = vec![host("52:54:00:aa:bb:01", "10.0.0.5", Some("h1"))];
        assert!(h.check().is_ok());
        // Outside the subnet, on its own addresses, or twice.
        for ip in ["8.8.8.8", "10.0.0.0", "10.0.0.255", "10.0.0.1"] {
            h.hosts = vec![host("52:54:00:aa:bb:01", ip, None)];
            assert!(h.check().is_err(), "{ip}");
        }
        h.hosts = vec![host("52:54:00:aa:bb:01", "10.0.0.5", None), host("52:54:00:AA:BB:01", "10.0.0.6", None)];
        assert!(h.check().is_err());
        h.hosts = vec![host("52:54:00:aa:bb:01", "10.0.0.5", None), host("52:54:00:aa:bb:02", "10.0.0.5", None)];
        assert!(h.check().is_err());
        // Without an address they would be dropped: refused. So on a bridge.
        h.address = None;
        h.prefix = None;
        h.hosts = vec![host("52:54:00:aa:bb:01", "10.0.0.5", None)];
        assert!(h.check().is_err());
        let mut br = edit("bridge");
        br.bridge = Some("br0".into());
        br.hosts = h.hosts.clone();
        assert!(br.check().is_err());
        // A mode this app does not write, and an address a NAT needs.
        assert!(edit("open").check().is_err());
        let mut nat = edit("nat");
        nat.dhcp_start = Some("10.0.0.2".into());
        nat.dhcp_end = Some("10.0.0.9".into());
        assert!(nat.check().is_err());
    }

    #[test]
    fn the_script_is_quote_safe() {
        let name = "it's \"odd\"";
        let base = format!("<network>\n  <name>{}</name>\n</network>\n", xml_escape(name));
        let mut e = edit("isolated");
        e.address = Some("10.9.9.1".into());
        e.prefix = Some(24);
        e.hosts = vec![VirtNetHost {
            mac: "52:54:00:aa:bb:01".into(),
            ip: "10.9.9.5".into(),
            name: Some("it-s".into()),
        }];
        let s = net_change_script(&VirtNetOp::Edit {
            name: name.into(),
            edit: e,
            base_xml: base,
            active: true,
            restart: true,
            force_restart: false,
        })
        .unwrap();
        // The name reaches virsh as one quoted word; the XML is in a file.
        assert!(
            s.contains("net-dumpxml --inactive --network 'it'\\''s \"odd\"'"),
            "{s}"
        );
        assert!(s.contains("net-destroy --network 'it'\\''s \"odd\"'"), "{s}");
        // A run under `sh` with a stub virsh reads it as the script it is.
        let out = std::process::Command::new("sh")
            .arg("-n")
            .stdin(std::process::Stdio::piped())
            .spawn()
            .and_then(|mut c| {
                use std::io::Write;
                c.stdin.as_mut().unwrap().write_all(s.as_bytes())?;
                c.wait()
            })
            .unwrap();
        assert!(out.success());

        // A network without an address writes no <ip>, and no net-update.
        let mut e = edit("isolated");
        e.hosts = Vec::new();
        let s = net_change_script(&VirtNetOp::Edit {
            name: "lab".into(),
            edit: e,
            base_xml: BASE.into(),
            active: false,
            restart: false,
            force_restart: false,
        })
        .unwrap();
        assert!(s.contains("net-define"), "{s}");
        assert!(!s.contains("net-update"), "{s}");
        assert!(!s.contains("net-destroy"), "{s}");
        assert_eq!(parse_net_change(&format!("{}\n{RC_PREFIX}0\n", script::cmd_marker(KEY_NET_STEP))), Ok(()));
    }

    #[test]
    fn a_restart_writes_no_definition() {
        // Its own op: `net-destroy` and `net-start`, nothing else. A change
        // whose definition is already in place is put on the running
        // network by this, and writing the definition again would only
        // repeat what the host has.
        let s = net_change_script(&VirtNetOp::Restart {
            name: "lab".into(),
            base_xml: BASE.into(),
        })
        .unwrap();
        assert!(s.contains("net-destroy --network 'lab'"), "{s}");
        assert!(s.contains("net-start --network 'lab'"), "{s}");
        assert!(!s.contains("net-define"), "{s}");
        assert!(!s.contains("net-update"), "{s}");
        // The guard is there: a network redefined to something else since
        // the read is not restarted onto it blind.
        assert!(s.contains(&script::cmd_marker(KEY_NET_CONFLICT)), "{s}");
        // No definition given: no guard to read it with.
        let bare = net_change_script(&VirtNetOp::Restart {
            name: "lab".into(),
            base_xml: String::new(),
        })
        .unwrap();
        // (The running network's own XML is still read, to start it again
        // from if the start fails.)
        assert!(!bare.contains("net-dumpxml --inactive"), "{bare}");
        assert!(bare.contains("net-dumpxml --network 'lab'"), "{bare}");
        assert!(bare.contains("net-destroy"), "{bare}");
        assert!(bare.contains("net-create \"$live\""), "{bare}");

        // `force_restart` on an edit whose definition is already what the
        // definition says: it is put on the running network, and the
        // definition is written again to the same thing.
        let mut same = edit("nat");
        same.address = Some("192.168.150.1".into());
        same.prefix = Some(24);
        same.dhcp_start = Some("192.168.150.100".into());
        same.dhcp_end = Some("192.168.150.200".into());
        let op = |force: bool| VirtNetOp::Edit {
            name: "lab".into(),
            edit: same.clone(),
            base_xml: BASE.into(),
            active: true,
            restart: true,
            force_restart: force,
        };
        // Nothing to change but the static host: `net-update`, live, and the
        // running network is already on it.
        let plain = net_change_script(&op(false)).unwrap();
        assert!(plain.contains("net-update"), "{plain}");
        assert!(!plain.contains("net-destroy"), "{plain}");
        // Forced: the definition goes in and the network is restarted onto
        // it, which is what the view's Restart button asks for.
        let forced = net_change_script(&op(true)).unwrap();
        assert!(forced.contains("net-define"), "{forced}");
        assert!(forced.contains("net-destroy"), "{forced}");
        assert!(forced.contains("net-start"), "{forced}");
    }

    #[test]
    fn outcomes() {
        let step = |body: &str, rc: i32| {
            format!("{}\n{body}\n{RC_PREFIX}{rc}\n", script::cmd_marker(KEY_NET_STEP))
        };
        assert_eq!(parse_net_change(&step("", 0)), Ok(()));
        let raw = format!("{}\n{}", step("", 0), script::cmd_marker(KEY_NET_CONFLICT));
        assert!(matches!(parse_net_change(&raw), Err(VirtError::Conflict { .. })));
        // The definition is read back (a step), then a `net-update` the host
        // refused.
        let raw = format!(
            "{}{}",
            step("", 0),
            step(
                "error: Failed to update network lab\nerror: Requested operation is not valid: network is not running",
                1
            )
        );
        // A refusal is classified as its own kind (`InvalidState` here):
        // what the app shows is the host's words either way.
        let e = parse_net_change(&raw).unwrap_err();
        assert!(e.message().contains("network is not running"), "{e:?}");
        // A refused start, rolled back and started again
        let raw = format!(
            "{}{}{}\n{}",
            step("", 0),
            step("error: failed to start network lab", 1),
            script::cmd_marker(KEY_NET_ROLLBACK),
            script::cmd_marker(KEY_NET_RESTORED),
        );
        let e = parse_net_change(&raw).unwrap_err();
        assert!(e.message().contains("failed to start network lab"), "{e:?}");
        assert!(e.message().contains("started again as it ran before"), "{e:?}");
        assert!(!e.message().contains("saved configuration"), "{e:?}");
        // ... with the old definition refused on the way back
        let raw = format!(
            "{}{}{}\n{}\n{}",
            step("", 0),
            step("error: failed to start network lab", 1),
            script::cmd_marker(KEY_NET_ROLLBACK),
            script::cmd_marker(KEY_NET_DEF_KEPT),
            script::cmd_marker(KEY_NET_RESTORED),
        );
        let e = parse_net_change(&raw).unwrap_err();
        assert!(e.message().contains("saved configuration is the new one"), "{e:?}");
        // ... and the rollback itself failed
        let raw = format!(
            "{}{}{}",
            step("", 0),
            step("error: failed to start network lab", 1),
            script::cmd_marker(KEY_NET_ROLLBACK),
        );
        let e = parse_net_change(&raw).unwrap_err();
        assert!(e.message().contains("it is down"), "{e:?}");
    }
}
