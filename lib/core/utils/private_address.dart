import 'dart:io';
import 'dart:typed_data';

/// Whether an address is one only some particular network can reach.
///
/// The gate in front of every geo lookup, and it runs before anything else —
/// before a name is resolved, before a database is consulted, before a shard
/// is fetched. Three things follow from a host being private, and only the
/// first is about privacy:
///
/// - nothing is sent about it. A LAN address says nothing about where the
///   machine is, so a request naming it buys nothing and is one more request
///   than the user asked for.
/// - it cannot be answered correctly. `192.168.1.10` is not in any geo
///   database, and an address that once was — `100.64.0.0/10` was ordinary
///   public space until 2012 — would answer with wherever it used to be.
/// - a name like `nas` or `printer.local` has no resolver but this machine's,
///   so looking it up is a query that can only fail.
///
/// The classification is by prefix, written out rather than delegated to
/// `InternetAddress.isLoopback` and friends: those cover three of the sixteen
/// ranges here, and mixing the two would leave no single place that says what
/// the whole set is.
bool isPrivateHost(String host) {
  final trimmed = host.trim();
  if (trimmed.isEmpty) return true;

  // Brackets are how a v6 literal appears in a URL, and `Uri.host` keeps them.
  final unwrapped = trimmed.startsWith('[') && trimmed.endsWith(']')
      ? trimmed.substring(1, trimmed.length - 1)
      : trimmed;
  // A zone index — `fe80::1%en0` — is not part of the address, and its
  // presence already says the address is link-local.
  final zone = unwrapped.indexOf('%');
  final bare = zone == -1 ? unwrapped : unwrapped.substring(0, zone);

  final addr = InternetAddress.tryParse(bare);
  if (addr != null) return isPrivateAddress(addr);
  return _isPrivateName(bare);
}

/// An IPv4 address carried inside a v6 one, as the v4 address it is.
///
/// `::ffff:a.b.c.d`. `InternetAddress.lookup` returns these on a dual-stack
/// host, and every question anyone asks about such an address is the v4
/// question: whether it is private, which family's data covers it, and whether
/// it should win a dual-stack tie-break.
///
/// **Public because getting this wrong is silent.** [isPrivateAddress] has
/// always unwrapped, so a LAN server reached over v6 is not called public; the
/// lookup that followed did not, and asked the IPv6 file for a key whose first
/// six bytes are zero — landing in `::/48`, answering nothing, and reporting a
/// perfectly placeable server as having no data.
///
/// Answers [addr] unchanged when it is not one of these.
InternetAddress unwrapV4Mapped(InternetAddress addr) {
  final b = addr.rawAddress;
  if (b.length != 16) return addr;
  const prefix = [0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0xff, 0xff];
  for (var i = 0; i < prefix.length; i++) {
    if (b[i] != prefix[i]) return addr;
  }
  return InternetAddress.fromRawAddress(
    Uint8List.fromList(b.sublist(12)),
    type: InternetAddressType.IPv4,
  );
}

/// [isPrivateHost] for an address that has already been parsed or resolved.
bool isPrivateAddress(InternetAddress addr) {
  final b = unwrapV4Mapped(addr).rawAddress;
  if (b.length == 4) return _isPrivateV4(b[0], b[1], b[2], b[3]);
  if (b.length != 16) return true;

  // Unspecified `::` and loopback `::1`, which differ only in the last byte.
  if (b.take(15).every((byte) => byte == 0) && b[15] <= 1) return true;
  // fc00::/7 unique local, fe80::/10 link-local, ff00::/8 multicast.
  if (b[0] & 0xfe == 0xfc) return true;
  if (b[0] == 0xfe && b[1] & 0xc0 == 0x80) return true;
  if (b[0] == 0xff) return true;
  // 2001:db8::/32, reserved for documentation, so it appears in copied
  // examples and in nothing that is actually reachable.
  if (b[0] == 0x20 && b[1] == 0x01 && b[2] == 0x0d && b[3] == 0xb8) return true;

  return false;
}

bool _isPrivateV4(int a, int b, int c, int d) => switch ((a, b, c, d)) {
  // "This network", which is also what an unset address parses as.
  (0, _, _, _) => true,
  (10, _, _, _) => true,
  (127, _, _, _) => true,
  // Carrier-grade NAT. Public space until RFC 6598 took it in 2012, so a
  // database old enough still places it — in Asia, mostly.
  (100, final x, _, _) when x >= 64 && x <= 127 => true,
  // Link-local: what an interface with no DHCP lease ends up on.
  (169, 254, _, _) => true,
  (172, final x, _, _) when x >= 16 && x <= 31 => true,
  // IETF protocol assignments, including 192.0.0.170 and the DS-Lite range.
  (192, 0, 0, _) => true,
  // The three documentation ranges, TEST-NET-1 through 3.
  (192, 0, 2, _) => true,
  (198, 51, 100, _) => true,
  (203, 0, 113, _) => true,
  (192, 168, _, _) => true,
  // 6to4 relay anycast. Every relay answered on the same address, so it never
  // identified a place; RFC 7526 deprecated the whole scheme in 2015 and
  // reserved the range, and a database old enough still places it.
  (192, 88, 99, _) => true,
  // Benchmarking, 198.18.0.0/15.
  (198, final x, _, _) when x == 18 || x == 19 => true,
  // Multicast 224/4 and reserved 240/4, which takes the broadcast address
  // 255.255.255.255 with it.
  (final x, _, _, _) when x >= 224 => true,
  _ => false,
};

/// The name suffixes that resolve only on the network you are already on.
///
/// `local` and `home.arpa` are reserved by RFC (6762 and 8375); `internal` was
/// reserved by ICANN in 2024; `lan`, `home`, `corp` and `intranet` never were,
/// but are what routers hand out by default and are permanently blocked from
/// delegation for exactly that reason.
const _privateSuffixes = {
  'local',
  'localhost',
  'localdomain',
  'internal',
  'intranet',
  'lan',
  'home',
  'home.arpa',
  'corp',
  'test',
  'invalid',
  'example',
};

bool _isPrivateName(String name) {
  final lower = name.toLowerCase();
  // A trailing dot makes a name fully qualified and is not part of it.
  final host = lower.endsWith('.')
      ? lower.substring(0, lower.length - 1)
      : lower;
  if (host.isEmpty) return true;

  // A single label has no public suffix to resolve against, so whatever
  // answers is on this network: `nas`, `router`, a Tailscale MagicDNS name.
  if (!host.contains('.')) return true;

  for (final suffix in _privateSuffixes) {
    if (host == suffix || host.endsWith('.$suffix')) return true;
  }
  return false;
}
