import 'dart:io';

import 'package:fl_lib/fl_lib.dart';
import 'package:flutter/foundation.dart' show visibleForTesting;
import 'package:server_box/core/service/geo_data.dart';
import 'package:server_box/core/utils/private_address.dart';
import 'package:server_box/data/model/server/geo.dart';
import 'package:server_box/data/model/server/geo_source.dart';
import 'package:server_box/data/model/server/server_private_info.dart';
import 'package:server_box/data/res/store.dart';

/// Where each server is, resolved in one place and in one order.
///
/// **Two gates, then the chain**, and they are different kinds of thing — a
/// gate decides whether to ask at all, a link answers. Listing them as one
/// numbered sequence read as though the second gate were a source that the
/// third entry could follow, which is the opposite of what it does.
///
/// Gate one: [SettingStore.globeEnabled]. Nothing here runs with the globe
/// off — no file is opened, no name is resolved. Checked first and separately
/// from whether the data is installed, so off is a real off.
///
/// Gate two: a private address. No lookup is attempted, and none could answer
/// one — see `isPrivateHost`. The chain stops with no coordinate and
/// [GeoMiss.private], which is the ordinary state of an install whose servers
/// are all on a LAN. Phase two is what will fill this: the machine can read
/// its own interfaces and hand back a public address if it has one, which is
/// then fed to the links below in place of the private one — see [SelfAddr].
/// A machine that has only private addresses of its own stays here, because
/// nothing local can say where such a machine is.
///
/// The chain, highest first. Each link is asked only if every link above it
/// had no answer, so a manual coordinate is never second-guessed and an
/// address the machine reported for itself is never overruled by the one this
/// app happens to connect at:
///
/// 1. what the user typed, on the server itself — [GeoSource.manual]
/// 2. an address the server reported for itself — [GeoSource.selfReported]
/// 3. the city-level data, once it has been downloaded — [GeoSource.city]
///
/// That order is [GeoSource]'s own case order, which is what `beats` compares.
abstract final class IpGeo {
  /// The coordinate for [spi], or null if nothing can place it.
  ///
  /// **Nothing is cached, and that is a decision rather than an omission.**
  /// A lookup is about fourteen reads of eight bytes from a file this device
  /// already holds open — see `GeoBundle` — so a row read and a JSON decode in
  /// front of it would cost more than the answer they stand in for. The store
  /// that used to sit here dates from when a lookup meant fetching a shard over
  /// the network, and it outlived that reason twice over: keyed by a host
  /// string it could not notice a name resolving somewhere new, and it answered
  /// from itself rather than from the installed month, so a coordinate never
  /// changed after a data update.
  static Future<ResolvedGeo?> resolve(Spi spi) async =>
      (await locate(spi)).geo;

  /// [resolve] for a bare host, which is what the tests use.
  static Future<ResolvedGeo?> resolveHost(String host) async =>
      (await locateHost(host)).geo;

  /// [resolve], and why there is no coordinate when there is none.
  ///
  /// Both halves in one pass because the reason is only knowable from inside
  /// the chain: by the time a caller has a null it can no longer tell a
  /// private address from an address no database covers, and asking again from
  /// outside would repeat the name lookup to reach an answer this already had.
  ///
  /// [GeoMiss] is null when the globe is switched off, which is neither an
  /// answer nor a failure — nothing was asked.
  static Future<({ResolvedGeo? geo, GeoMiss? miss})> locate(Spi spi) async {
    // Ahead of the switch, because it is not a lookup. A coordinate the user
    // typed is theirs, stored on the record, and showing it involves nothing
    // outside this device.
    final manual = spi.custom?.geo;
    if (manual != null) {
      return (
        geo: ResolvedGeo(coord: manual, source: GeoSource.manual),
        miss: null,
      );
    }

    if (!Stores.setting.globeEnabled.fetch()) return (geo: null, miss: null);

    final host = geoHostOf(spi);
    // A server with no host to take an address from — a monitor address that
    // is not a URL. Nothing to look up, which is [GeoMiss.noData]'s third case.
    if (host == null) return (geo: null, miss: GeoMiss.noData);

    final found = await locateHost(host);
    // The address this app connects at is not one anything can place. What the
    // machine said about *itself* might be — see [SelfAddr]. Only for this
    // miss: a server reached at a public address is already being placed by
    // the address the world sees it at, so there is nothing to improve on.
    if (found.miss != GeoMiss.private) return found;
    return await _fromSelfAddr(spi.id) ?? found;
  }

  /// Where the machine put itself, if it has been asked and had an answer.
  ///
  /// Null when there is nothing recorded or nothing places it, so the caller
  /// keeps the [GeoMiss.private] it already had.
  ///
  /// [SelfAddrStore] holds the *address*, not the coordinate, and that split is
  /// the point: the address is a fact about the server that only the server
  /// knows, so it is worth keeping across launches; the coordinate is a lookup
  /// this can redo for nothing. Keeping the coordinate would also have to key
  /// it somewhere, and neither key works — under the server it duplicates the
  /// address, and under the public address it would label that host
  /// `selfReported` for every other server reached at it.
  static Future<({ResolvedGeo? geo, GeoMiss? miss})?> _fromSelfAddr(
    String id,
  ) async {
    final addr = Stores.selfAddr.addrOf(id);
    if (addr == null) return null;
    // The same lookup [locateHost] makes, but the source names how the address
    // was found rather than which file answered — so this cannot share that
    // code without also sharing the label.
    final coord = _cityOf(addr);
    if (coord == null) return null;
    return (
      geo: ResolvedGeo(coord: coord, source: GeoSource.selfReported),
      miss: null,
    );
  }

  /// [locate] for a bare host.
  static Future<({ResolvedGeo? geo, GeoMiss? miss})> locateHost(
    String host,
  ) async {
    if (!Stores.setting.globeEnabled.fetch()) return (geo: null, miss: null);

    if (isPrivateHost(host)) return (geo: null, miss: GeoMiss.private);

    // A name that will not resolve reads as [GeoMiss.noData], and there is
    // nothing held back to answer it with. That is the one thing lost with the
    // cache: a name-addressed server used to stay on the globe while the device
    // was offline. It costs little — the servers are unreachable in that state
    // anyway — and it is what bought an answer that never went stale.
    final addr = await _addressOf(host);
    if (addr == null) return (geo: null, miss: GeoMiss.noData);

    // The resolved address gets the same test as the name did. A name is not
    // evidence about what it points at: `nas.example.com` is a public name for
    // a machine on the LAN, and split-horizon DNS makes the same name answer
    // differently depending on which network is asking.
    if (isPrivateAddress(addr)) return (geo: null, miss: GeoMiss.private);

    final city = _cityOf(addr);
    if (city == null) return (geo: null, miss: GeoMiss.noData);
    return (
      geo: ResolvedGeo(coord: city, source: GeoSource.city),
      miss: null,
    );
  }

  /// The city-level answer for [addr], from whichever family covers it.
  ///
  /// Null when the data is not installed, which is the ordinary state until
  /// someone accepts the download — there is no longer a bundled fallback
  /// underneath it, so a globe with the feature on and nothing fetched places
  /// nothing and says so.
  static GeoCoord? _cityOf(InternetAddress addr) {
    // Unwrapped first. `::ffff:8.8.8.8` has `type` IPv6, so without this the
    // v6 file is asked for a key whose leading 48 bits are zero — bucket 0,
    // no record, and a placeable server reported as having no data.
    final bare = unwrapV4Mapped(addr);
    final family = bare.type == InternetAddressType.IPv6 ? 6 : 4;
    return GeoData.bundle(family)?.lookup(bare);
  }

  /// Which of a server's addresses to place it by.
  ///
  /// The leading transport's, falling back to the other — the same order
  /// `ServerConnectCredential.fromSpi` uses, so the globe draws the server
  /// where the app would reach it. Null when neither is usable, which for a
  /// monitor address means one that is not a URL.
  static String? geoHostOf(Spi spi) {
    final hosts = spi.transport == ServerTransport.monitorHttp
        ? [_monitorHost(spi), spi.ssh?.ip]
        : [spi.ssh?.ip, _monitorHost(spi)];
    for (final host in hosts) {
      if (host != null && host.trim().isNotEmpty) return host.trim();
    }
    return null;
  }

  static String? _monitorHost(Spi spi) {
    final addr = spi.monitorHttp?.addr;
    if (addr == null) return null;
    final host = Uri.tryParse(addr)?.host;
    return host == null || host.isEmpty ? null : host;
  }

  /// How a name becomes an address.
  ///
  /// A seam, because the alternative is a test suite that asks a real resolver
  /// — which makes the network the thing under test, and makes the answer
  /// depend on which machine is running it. The behaviour worth pinning is
  /// what happens *to* the result: a dual-stack host offers both families and
  /// this has to pick one.
  @visibleForTesting
  static Future<List<InternetAddress>> Function(String host) resolver =
      InternetAddress.lookup;

  /// The address for [host], resolving a name if it is one.
  ///
  /// Only reached for a host that already passed [isPrivateHost], so the
  /// query goes to a public name — the same one the app resolves whenever it
  /// connects to this server.
  static Future<InternetAddress?> _addressOf(String host) async {
    final literal = InternetAddress.tryParse(host);
    if (literal != null) return literal;
    try {
      final found = await resolver(host);
      // IPv4 first when both are offered. It used to be a coverage argument —
      // the bundled database was almost entirely IPv4 — and it is not one any
      // more: the two downloaded files hold 3.5M and 3.8M records. What it is
      // now is a tie-break, and worth keeping as one. A resolver may list a
      // dual-stack host's addresses in either order, so without a rule the
      // globe would place such a server from whichever came first and move it
      // between runs for no reason the user could see.
      // Unwrapped for the test, returned as it came: a v4-mapped answer is a
      // v4 address and should win this, and `_cityOf` unwraps it again.
      for (final addr in found) {
        if (unwrapV4Mapped(addr).type == InternetAddressType.IPv4) return addr;
      }
      return found.firstOrNull;
    } catch (e) {
      // A name that will not resolve is not an error anyone needs told about:
      // the server is either off, or behind something this device is not on.
      Loggers.app.fine('Geo lookup could not resolve a host: $e');
      return null;
    }
  }
}
