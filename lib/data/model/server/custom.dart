import 'package:json_annotation/json_annotation.dart';

part 'custom.g.dart';

@JsonSerializable(includeIfNull: false)
final class ServerCustom {
  // @HiveField(0)
  // final String? temperature;

  final String? pveAddr;

  final bool pveIgnoreCert;

  /// {"title": "cmd"}
  final Map<String, String>? cmds;

  final String? preferTempDev;

  final String? logoUrl;

  /// The device name of the network interface displayed in the home server card.
  final String? netDev;

  /// The directory where the script is stored.
  final String? scriptDir;

  const ServerCustom({
    //this.temperature,
    this.pveAddr,
    this.pveIgnoreCert = false,
    this.cmds,
    this.preferTempDev,
    this.logoUrl,
    this.netDev,
    this.scriptDir,
  });

  factory ServerCustom.fromJson(Map<String, dynamic> json) => _$ServerCustomFromJson(json);

  Map<String, dynamic> toJson() => _$ServerCustomToJson(this);

  @override
  bool operator ==(Object other) {
    return other is ServerCustom &&
        //other.temperature == temperature &&
        other.pveAddr == pveAddr &&
        other.pveIgnoreCert == pveIgnoreCert &&
        other.cmds == cmds &&
        other.preferTempDev == preferTempDev &&
        other.logoUrl == logoUrl &&
        other.netDev == netDev &&
        other.scriptDir == scriptDir;
  }

  @override
  int get hashCode =>
      //temperature.hashCode ^
      pveAddr.hashCode ^
      pveIgnoreCert.hashCode ^
      cmds.hashCode ^
      preferTempDev.hashCode ^
      logoUrl.hashCode ^
      netDev.hashCode ^
      scriptDir.hashCode;
}
