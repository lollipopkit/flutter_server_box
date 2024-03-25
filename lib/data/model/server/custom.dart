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

  const ServerCustom({
    //this.temperature,
    this.pveAddr,
    this.pveIgnoreCert = false,
    this.cmds,
  });

  static ServerCustom fromJson(Map<String, dynamic> json) {
    //final temperature = json["temperature"] as String?;
    final pveAddr = json["pveAddr"] as String?;
    final pveIgnoreCert = json["pveIgnoreCert"] as bool;
    final cmds = json["cmds"] as Map<String, dynamic>?;
    return ServerCustom(
      //temperature: temperature,
      pveAddr: pveAddr,
      pveIgnoreCert: pveIgnoreCert,
      cmds: cmds?.cast<String, String>(),
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
    return json;
  }
}
