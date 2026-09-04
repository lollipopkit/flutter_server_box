import 'package:json_annotation/json_annotation.dart';
import 'package:server_box/data/model/server/geo.dart';

part 'custom.g.dart';

@JsonSerializable(includeIfNull: false)
final class ServerCustom {
  final String? pveAddr;

  final bool pveIgnoreCert;

  final String? pvePwd;

  /// {"title": "cmd"}
  ///
  /// No longer where custom commands live: they are files in a directory on
  /// the server, which is what the status script reads and what the editor
  /// writes. This holds only what an older version of the app stored, until
  /// the first connection moves it there.
  // TODO(migration): delete this field, [withoutCmds], and
  // `IndividualServerNotifier._migrateCustomCmds` once enough releases have
  // passed for every install to have connected once.
  final Map<String, String>? cmds;

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

  const ServerCustom({
    this.pveAddr,
    this.pveIgnoreCert = false,
    this.pvePwd,
    this.cmds,
    this.preferTempDev,
    this.tempIsCelsius = false,
    this.logoUrl,
    this.netDev,
    this.scriptDir,
    this.geo,
  });

  /// This, with [cmds] dropped — what the app records once those commands are
  /// on the server, so it never sends them twice.
  // TODO(migration): delete with [cmds].
  ServerCustom withoutCmds() => ServerCustom(
    pveAddr: pveAddr,
    pveIgnoreCert: pveIgnoreCert,
    pvePwd: pvePwd,
    preferTempDev: preferTempDev,
    tempIsCelsius: tempIsCelsius,
    logoUrl: logoUrl,
    netDev: netDev,
    scriptDir: scriptDir,
    geo: geo,
  );

  factory ServerCustom.fromJson(Map<String, dynamic> json) =>
      _$ServerCustomFromJson(json);

  Map<String, dynamic> toJson() => _$ServerCustomToJson(this);

  @override
  bool operator ==(Object other) {
    return other is ServerCustom &&
        other.pveAddr == pveAddr &&
        other.pveIgnoreCert == pveIgnoreCert &&
        other.pvePwd == pvePwd &&
        other.cmds == cmds &&
        other.preferTempDev == preferTempDev &&
        other.tempIsCelsius == tempIsCelsius &&
        other.logoUrl == logoUrl &&
        other.netDev == netDev &&
        other.scriptDir == scriptDir &&
        other.geo == geo;
  }

  @override
  int get hashCode =>
      pveAddr.hashCode ^
      pveIgnoreCert.hashCode ^
      pvePwd.hashCode ^
      cmds.hashCode ^
      preferTempDev.hashCode ^
      tempIsCelsius.hashCode ^
      logoUrl.hashCode ^
      netDev.hashCode ^
      scriptDir.hashCode ^
      geo.hashCode;
}
