import 'dart:io';

/// Which way of reaching the server an access is.
enum FirewallAccessVia { ssh, monitor }

/// One way this app reaches a server: the TCP port it connects to there, and
/// the addresses of the connection as the server sees them.
///
/// What every firewall change is checked against. A change that refuses it
/// leaves the server unreachable from this app once the connection in use
/// drops — and the connection in use is usually the only way to undo it.
final class FirewallAccess {
  const FirewallAccess({
    required this.via,
    required this.port,
    this.client,
    this.server,
  });

  final FirewallAccessVia via;

  /// The port on the server. From `SSH_CONNECTION` where the server said, so
  /// a NAT that maps another port to it does not mislead.
  final int port;

  /// Where the server sees this device connect from: a NAT's address, or a
  /// jump server's. Null where it could not be asked.
  final InternetAddress? client;

  /// The server's own address the connection arrived on.
  final InternetAddress? server;

  /// Reads `SSH_CONNECTION` — `client_ip client_port server_ip server_port` —
  /// into the SSH access it describes. Null for anything else.
  static FirewallAccess? fromSshConnection(String? value) {
    final fields = value?.trim().split(RegExp(r'\s+')) ?? const <String>[];
    if (fields.length != 4) return null;
    final client = InternetAddress.tryParse(_unscoped(fields[0]));
    final server = InternetAddress.tryParse(_unscoped(fields[2]));
    final port = int.tryParse(fields[3]);
    if (client == null || server == null || port == null) return null;
    if (port < 1 || port > 65535) return null;
    return FirewallAccess(
      via: FirewallAccessVia.ssh,
      port: port,
      client: client,
      server: server,
    );
  }

  /// `fe80::1%eth0` without its zone, which [InternetAddress] will not parse.
  static String _unscoped(String address) => address.split('%').first;
}

/// Whether a new connection like a [FirewallAccess] would get through.
///
/// Ordered from best to worst, which is what [worseThan] compares.
enum FirewallReach {
  open,

  /// Let through, at a rate: ufw's `limit` refuses an address after six
  /// connections in thirty seconds.
  limited,

  /// Turns on what this app cannot know: the address or the interface the
  /// connection comes by, where a rule names one.
  unknown,
  blocked;

  bool get admits => this == open || this == limited;

  /// Whether a change from [before] to this is one to stop and ask about.
  bool worseThan(FirewallReach before) => index > before.index;
}

/// One item of a port specification: a port, or one range in either
/// separator (`6000:6010` is ufw's, `6000-6010` is firewalld's).
final _portItem = RegExp(r'^(\d{1,5})(?:[:-](\d{1,5}))?$');

/// Whether [spec] — `22`, `80,443`, `6000:6010`, or firewalld's `6000-6010`
/// — names [port]. A null [spec] is any port.
///
/// An item that is neither a port nor exactly one range covers nothing. What
/// this answers decides whether a rule is read as letting a way in through, so
/// a spec the host could not have meant must not be read as naming a port it
/// does not describe: `22:23:24` is not the range 22–24, and treating it as
/// one would have a rule that says nothing about 23 — an `allow` among them —
/// classified as admitting it.
bool portSpecCovers(String? spec, int port) {
  if (spec == null) return true;
  for (final part in spec.split(',')) {
    final match = _portItem.firstMatch(part.trim());
    if (match == null) continue;
    final start = int.parse(match.group(1)!);
    final end = int.tryParse(match.group(2) ?? '') ?? start;
    if (port >= start && port <= end) return true;
  }
  return false;
}

/// Whether [network] — an address or a CIDR network — holds [address].
///
/// Null when [network] is neither, and false across families: a v4 network
/// never holds a v6 address, mapped or not, as iptables sees it.
bool? networkContains(String network, InternetAddress address) {
  final slash = network.indexOf('/');
  final base = InternetAddress.tryParse(
    slash < 0 ? network : network.substring(0, slash),
  );
  if (base == null) return null;
  if (base.type != address.type) return false;
  final bits = base.rawAddress.length * 8;
  final prefix = slash < 0 ? bits : int.tryParse(network.substring(slash + 1));
  if (prefix == null || prefix < 0 || prefix > bits) return null;
  final a = base.rawAddress;
  final b = address.rawAddress;
  for (var bit = 0; bit < prefix; bit++) {
    final mask = 0x80 >> (bit % 8);
    if ((a[bit ~/ 8] & mask) != (b[bit ~/ 8] & mask)) return false;
  }
  return true;
}
