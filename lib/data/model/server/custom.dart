import 'package:json_annotation/json_annotation.dart';
import 'package:server_box/data/model/server/geo.dart';

part 'custom.g.dart';

/// Per-server extras.
///
/// PVE's settings were here as `pveAddr`, `pveIgnoreCert` and `pvePwd`; they
/// are `PveConfig` now, in a table of their own. A record from an older build
/// may still carry them, and this class ignores keys it does not know.
@JsonSerializable(includeIfNull: false)
final class ServerCustom {
  final String? preferTempDev;

  final bool tempIsCelsius;

  final String? logoUrl;

  /// The device name of the network interface displayed in the home server card.
  final String? netDev;

  /// The directory where the script is stored.
  final String? scriptDir;

  /// Where this server is on the globe, said by hand.
  ///
  /// The first link in the chain that answers that question, and the only one
  /// that is a statement rather than a guess: everything else is looked up
  /// from an address, and an address is not a machine.
  ///
  /// [GeoCoord.tryFromJson] rather than the generated decode, so a backup
  /// carrying something unreadable here loses the coordinate instead of the
  /// server.
  @JsonKey(fromJson: GeoCoord.tryFromJson, toJson: GeoCoord.encode)
  final GeoCoord? geo;

  /// Whether NFS, SMB and the like count in the disk total when the status
  /// comes over SSH. Listed either way; their size is another machine's.
  /// Over the monitor agent, the agent's own setting decides (#1669).
  final bool diskCountsNetwork;

  const ServerCustom({
    this.preferTempDev,
    this.tempIsCelsius = false,
    this.logoUrl,
    this.netDev,
    this.scriptDir,
    this.geo,
    this.diskCountsNetwork = false,
  });

  factory ServerCustom.fromJson(Map<String, dynamic> json) =>
      _$ServerCustomFromJson(json);

  Map<String, dynamic> toJson() => _$ServerCustomToJson(this);

  @override
  bool operator ==(Object other) {
    return other is ServerCustom &&
        other.preferTempDev == preferTempDev &&
        other.tempIsCelsius == tempIsCelsius &&
        other.logoUrl == logoUrl &&
        other.netDev == netDev &&
        other.scriptDir == scriptDir &&
        other.geo == geo &&
        other.diskCountsNetwork == diskCountsNetwork;
  }

  @override
  int get hashCode => Object.hash(
    preferTempDev,
    tempIsCelsius,
    logoUrl,
    netDev,
    scriptDir,
    geo,
    diskCountsNetwork,
  );
}
