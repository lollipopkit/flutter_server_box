import 'package:hive_flutter/adapters.dart';
import 'package:json_annotation/json_annotation.dart';

part 'custom.g.dart';

@JsonSerializable()
@HiveType(typeId: 7)
final class ServerCustom {
  // @HiveField(0)
  // final String? temperature;
  @HiveField(1)
  final String? pveAddr;
  @HiveField(2, defaultValue: false)
  final bool pveIgnoreCert;

  /// {"title": "cmd"}
  @HiveField(3)
  final Map<String, String>? cmds;
  @HiveField(4)
  final String? preferTempDev;
  @HiveField(5)
  final String? logoUrl;

  /// The device name of the network interface displayed in the home server card.
  @HiveField(6)
  final String? netDev;

  /// The directory where the script is stored.
  @HiveField(7)
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

  factory ServerCustom.fromJson(Map<String, dynamic> json) =>
      _$ServerCustomFromJson(json);

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
