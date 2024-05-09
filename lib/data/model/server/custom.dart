import 'package:hive_flutter/adapters.dart';

part 'custom.g.dart';

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

  const ServerCustom({
    //this.temperature,
    this.pveAddr,
    this.pveIgnoreCert = false,
    this.cmds,
    this.preferTempDev,
    this.logoUrl,
  });

  static ServerCustom fromJson(Map<String, dynamic> json) {
    //final temperature = json["temperature"] as String?;
    final pveAddr = json["pveAddr"] as String?;
    final pveIgnoreCert = json["pveIgnoreCert"] as bool;
    final cmds = json["cmds"] as Map<String, dynamic>?;
    final preferTempDev = json["preferTempDev"] as String?;
    final logoUrl = json["logoUrl"] as String?;
    return ServerCustom(
      //temperature: temperature,
      pveAddr: pveAddr,
      pveIgnoreCert: pveIgnoreCert,
      cmds: cmds?.cast<String, String>(),
      preferTempDev: preferTempDev,
      logoUrl: logoUrl,
    );
  }

  Map<String, dynamic> toJson() {
    final json = <String, dynamic>{};
    // if (temperature != null) {
    //   json["temperature"] = temperature;
    // }
    if (pveAddr != null) {
      json["pveAddr"] = pveAddr;
    }
    json["pveIgnoreCert"] = pveIgnoreCert;

    if (cmds != null) {
      json["cmds"] = cmds;
    }
    if (preferTempDev != null) {
      json["preferTempDev"] = preferTempDev;
    }
    if (logoUrl != null) {
      json["logoUrl"] = logoUrl;
    }
    return json;
  }

  @override
  String toString() {
    return toJson().toString();
  }

  @override
  bool operator ==(Object other) {
    return other is ServerCustom &&
        //other.temperature == temperature &&
        other.pveAddr == pveAddr &&
        other.pveIgnoreCert == pveIgnoreCert &&
        other.cmds == cmds &&
        other.preferTempDev == preferTempDev &&
        other.logoUrl == logoUrl;
  }

  @override
  int get hashCode =>
      //temperature.hashCode ^
      pveAddr.hashCode ^
      pveIgnoreCert.hashCode ^
      cmds.hashCode ^
      preferTempDev.hashCode ^
      logoUrl.hashCode;
}
