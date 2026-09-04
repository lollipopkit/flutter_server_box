import 'package:server_box/data/model/server/geo.dart';

/// Where a server's coordinate came from.
///
/// Kept alongside the coordinate rather than discarded, because the sources
/// differ by more than precision. A manual coordinate is a statement about a
/// machine; the other two are guesses about an address, and a guess that is
/// wrong looks exactly like one that is right unless the globe can say which
/// it is looking at.
///
/// **The case order is the chain's order, and nothing compares it.** It used to
/// carry a `beats` method, which decided whether a newly arrived answer could
/// overwrite a stored one — a question that only existed while answers were
/// stored. `IpGeo.locate` asks each link in turn and stops at the first that
/// answers, so precedence is control flow now and cannot disagree with itself.
enum GeoSource {
  /// The user typed it. Nothing overrides this.
  manual,

  /// The server reported a public interface address, and that was looked up.
  ///
  /// Ahead of [city] because it answers a different question: for a machine
  /// behind NAT, the address the app connects to and the address the world
  /// sees are not the same, and only the machine knows the second one.
  selfReported,

  /// The city-level data, downloaded with consent.
  ///
  /// The last link, and the only one that needs anything installed. There was a
  /// `country` case under it, answered by a database bundled in the app; both
  /// went when the download replaced them, and the case went with the database
  /// rather than being kept as a value nothing can produce.
  city,
}

/// Why nothing could place a server.
///
/// Kept because "unknown" on its own is a dead end: the globe cannot say
/// whether the address is one no database will ever have, or one that simply
/// is not in the data this build has — and those read the same on screen while
/// meaning entirely different things about what to do next. A whole tab of
/// servers in the unplaced strip is the ordinary state of a LAN-only install,
/// and nothing said so.
enum GeoMiss {
  /// A LAN, loopback, link-local or documentation address, or a name that only
  /// resolves on the network the device is already on.
  ///
  /// Not looked up, and no lookup could answer it — see `isPrivateHost`. A
  /// coordinate typed into the server editor is the only thing that places
  /// such a machine, which is what the chip offering the editor is for.
  private,

  /// Everything else: a name that would not resolve from here, an address the
  /// databases have no record of, and a server whose only address is not one a
  /// host can be taken from.
  ///
  /// One case rather than three because the remedy is the same for all of
  /// them, and a strip along the bottom of a globe is not the place to explain
  /// the difference between a DNS failure and a gap in a table.
  noData,
}

/// A coordinate and the reason to believe it.
///
/// **Never persisted, so it has no JSON.** It carried a `toJson` and a
/// `tryFromJson` for the store that held where each host was; that store is
/// gone, and a serialiser kept for nothing is the kind that stops matching the
/// class it serialises without anything noticing. What is written to disk is
/// the address a server reported — see [SelfAddrStore] — and the coordinate is
/// worked out again from it each time.
final class ResolvedGeo {
  const ResolvedGeo({required this.coord, required this.source});

  final GeoCoord coord;
  final GeoSource source;

  @override
  bool operator ==(Object other) =>
      other is ResolvedGeo && other.coord == coord && other.source == source;

  @override
  int get hashCode => Object.hash(coord, source);

  @override
  String toString() => 'ResolvedGeo(${coord.text}, ${source.name})';
}
