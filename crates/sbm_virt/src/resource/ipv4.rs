//! IPv4 addresses and subnets as a network form takes them: a host address
//! with its prefix, a DHCP range inside it, and whether two subnets overlap.

/// `a.b.c.d`, each part one to three digits (a leading zero is taken, as the
/// host's own tools take it); None otherwise.
pub fn parse_ipv4(s: &str) -> Option<u32> {
    let parts: Vec<&str> = s.trim().split('.').collect();
    if parts.len() != 4 {
        return None;
    }
    let mut out = 0u32;
    for p in parts {
        if p.is_empty() || p.len() > 3 || !p.bytes().all(|b| b.is_ascii_digit()) {
            return None;
        }
        let n: u32 = p.parse().ok()?;
        if n > 255 {
            return None;
        }
        out = (out << 8) | n;
    }
    Some(out)
}

pub fn format_ipv4(a: u32) -> String {
    std::net::Ipv4Addr::from(a).to_string()
}

pub(crate) fn mask(prefix: u8) -> u32 {
    if prefix == 0 { 0 } else { u32::MAX << (32 - u32::from(prefix.min(32))) }
}

fn split(cidr: &str) -> Option<(u32, u8)> {
    let (address, prefix) = cidr.trim().split_once('/')?;
    if prefix.contains('/') {
        return None;
    }
    Some((parse_ipv4(address)?, prefix.trim().parse().ok()?))
}

/// `a.b.c.d/prefix` as the address and the prefix; None when it is not one
/// with a host address that can be used: not the network's own, not its
/// broadcast, prefix 8 to 30.
pub fn parse_cidr(cidr: &str) -> Option<(u32, u8)> {
    let (address, prefix) = split(cidr)?;
    if !(8..=30).contains(&prefix) {
        return None;
    }
    let m = mask(prefix);
    let net = address & m;
    if address == net || address == net | !m {
        return None;
    }
    Some((address, prefix))
}

/// The DHCP range a form offers for `cidr`: .100 to .200 of a /24, and the
/// same share of any other size, clear of the host's own address.
pub fn default_dhcp_range(cidr: &str) -> Option<(String, String)> {
    let (address, prefix) = parse_cidr(cidr)?;
    let m = mask(prefix);
    let net = u64::from(address & m);
    let size = u64::from(!m) + 1;
    let at = |share: u64| net + (size * share / 256).clamp(1, size - 2);
    let (mut start, mut end) = (at(100), at(200));
    let address = u64::from(address);
    if (start..=end).contains(&address) {
        if address - net < size / 2 {
            start = address + 1;
        } else {
            end = address - 1;
        }
    }
    if start > end {
        return None;
    }
    Some((format_ipv4(start as u32), format_ipv4(end as u32)))
}

/// Whether two `a.b.c.d/prefix` subnets overlap; false when either is not
/// one.
pub fn overlaps(a: &str, b: &str) -> bool {
    let (Some((x, px)), Some((y, py))) = (split(a), split(b)) else { return false };
    if px > 32 || py > 32 {
        return false;
    }
    let m = mask(px.min(py));
    x & m == y & m
}

/// Whether `start..=end` is a DHCP range dnsmasq serves on the subnet of the
/// host address `address/prefix`: inside it, in order, off the network's own
/// address and broadcast, and clear of the host's.
pub(crate) fn dhcp_fits(address: u32, prefix: u8, start: Option<&str>, end: Option<&str>) -> bool {
    let m = mask(prefix);
    let net = address & m;
    let broadcast = net | !m;
    let (Some(s), Some(e)) = (start.and_then(parse_ipv4), end.and_then(parse_ipv4)) else { return false };
    s <= e && s & m == net && e & m == net && s != net && e != broadcast && !(s..=e).contains(&address)
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn cidrs() {
        assert!(parse_cidr("192.168.150.1/24").is_some());
        for bad in [
            "192.168.150.0/24",
            "192.168.150.255/24",
            "192.168.150.1",
            "192.168.150.1/31",
            "192.168.150.1/7",
            "300.1.1.1/24",
            "1.2.3/24",
            "01.2.3.4.5/24",
        ] {
            assert!(parse_cidr(bad).is_none(), "{bad}");
        }
    }

    #[test]
    fn dhcp_ranges() {
        let r = |c| default_dhcp_range(c).map(|(a, b)| format!("{a}-{b}"));
        assert_eq!(r("192.168.150.1/24").as_deref(), Some("192.168.150.100-192.168.150.200"));
        // The host's own address is left out of it.
        assert_eq!(r("10.0.0.150/24").as_deref(), Some("10.0.0.100-10.0.0.149"));
        assert_eq!(r("10.8.0.1/16").as_deref(), Some("10.8.100.0-10.8.200.0"));
        assert_eq!(r("bad"), None);
    }

    #[test]
    fn overlap() {
        assert!(overlaps("192.168.122.1/24", "192.168.122.9/25"));
        assert!(!overlaps("192.168.122.1/24", "192.168.123.1/24"));
        assert!(!overlaps("fe80::1/64", "192.168.122.1/24"));
    }
}
