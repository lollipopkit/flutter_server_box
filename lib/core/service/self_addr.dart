import 'dart:io';

import 'package:server_box/core/utils/private_address.dart';

/// Which of a machine's own addresses places it.
///
/// The globe can place a server it reaches at a public address, and cannot
/// place one it reaches at `192.168.1.10` — a LAN address is in no database and
/// never will be. But the machine is somewhere, and its own interfaces carry
/// whatever public address it has.
///
/// **Read, not asked.** An earlier design had the server fetch its egress
/// address from an outside service, which makes an external request on the
/// user's server, about the user's server, and would have needed consent of its
/// own. Reading the interfaces asks nobody: a VPS has its public address bound
/// directly, and a machine behind NAT has only private ones, which is an answer
/// too.
///
/// **Collected by the status script, not by a command of its own.** `ip` is a
/// key in `sbm_parser`'s manifest, on the extended cadence. That is what makes
/// one answer serve both transports, so a monitor-only server needs no
/// `full_access` grant to be placed — going through `/exec` would have asked
/// for "run anything" to answer "where are you".
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
  /// it throws away is why the loose parse is safe: a netmask is reserved
  /// space, a broadcast address is in the same network as its own address, and
  /// a loopback address is loopback.
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
  /// IPv4 first when there is a choice, so a dual-stack machine resolves to its
  /// v4 address consistently. Otherwise the first address the machine reported,
  /// in the order it reported them — nothing here sorts, so the answer follows
  /// that order rather than being independent of it.
  static InternetAddress? pick(List<String> reported) {
    final found = publicIn(reported);
    // Through `unwrapV4Mapped`, because `::ffff:a.b.c.d` has `type` IPv6 and
    // is a v4 address.
    for (final addr in found) {
      if (unwrapV4Mapped(addr).type == InternetAddressType.IPv4) return addr;
    }
    return found.firstOrNull;
  }
}
