import 'dart:io';

import 'package:server_box/core/utils/private_address.dart';

/// Which of a machine's own addresses places it.
///
/// The globe can place a server it reaches at a public address, and cannot
/// place one it reaches at `192.168.1.10` — a LAN address is in no database
/// and never will be. But the machine is somewhere, and its own interfaces
/// carry whatever public address it has.
///
/// **Read, not asked.** An earlier design had the server fetch its egress
/// address from an outside service (`curl ifconfig.me` and the like). That
/// makes an external request on the user's server, about the user's server,
/// which is exactly what the shard protocol was shaped to avoid — and it would
/// have needed consent of its own. Reading the interfaces asks nobody: a VPS
/// has its public address bound directly, and a machine behind NAT has only
/// private ones, which is an answer too.
///
/// **Collected by the status script, not by a command of its own.** `ip` is a
/// key in `sbm_parser`'s manifest, on the extended cadence beside SMART and
/// AMD. That is what makes one answer serve both transports: SSH runs the
/// shared script, and a monitor agent reports the same field from its own
/// `/metrics` — so a monitor-only server needs no `full_access` grant to be
/// placed. "Where are you" deserved far less authority than "run anything",
/// and going through `/exec` would have asked for the second to get the first.
///
/// So this cannot place a home server behind a router. Nothing local can. What
/// it does place is the far commoner case of a VPS reached over a VPN or by an
/// internal name, where the machine is on the public internet and only the
/// route to it is private.
abstract final class SelfAddr {
  /// Those of [reported] that something outside the machine's own network
  /// could reach, in the order the machine listed them.
  ///
  /// The parser upstream is deliberately format-blind — it keeps anything that
  /// parses as an address out of three unrelated command outputs — so **this
  /// filter is what makes the answer meaningful**, and it is the app's one
  /// table of private ranges rather than a second copy on the Rust side. What
  /// it throws away is why the loose parse is safe: a netmask reads as
  /// `255.255.255.0` and is reserved space, a loopback address is loopback,
  /// and a broadcast address is in the same network as the address it belongs
  /// to and so answers the same place anyway.
  static List<InternetAddress> publicIn(List<String> reported) {
    final found = <InternetAddress>[];
    final seen = <String>{};
    for (final text in reported) {
      final addr = InternetAddress.tryParse(text);
      if (addr == null) continue;
      if (isPrivateAddress(addr)) continue;
      if (!seen.add(addr.address)) continue;
      found.add(addr);
    }
    return found;
  }

  /// The one address to place a server by, or null when it has none.
  ///
  /// IPv4 first when there is a choice, for the reason `IpGeo` prefers it in a
  /// resolver's answer: it is a tie-break rather than a coverage argument, and
  /// what it buys is that a dual-stack machine is placed the same way every
  /// time. Otherwise the first one, which makes the answer stable across
  /// samples rather than dependent on the order the kernel listed interfaces.
  static InternetAddress? pick(List<String> reported) {
    final found = publicIn(reported);
    // Through `unwrapV4Mapped`, because `::ffff:a.b.c.d` has `type` IPv6 and
    // is a v4 address — a machine reporting one alongside a real v6 address
    // would otherwise be placed by whichever it happened to list first.
    for (final addr in found) {
      if (unwrapV4Mapped(addr).type == InternetAddressType.IPv4) return addr;
    }
    return found.firstOrNull;
  }
}
