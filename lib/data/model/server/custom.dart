import 'package:hive_flutter/adapters.dart';

part 'custom.g.dart';

@HiveType(typeId: 7)
final class ServerCustom {
  @HiveField(0)
  final String? temperature;
  @HiveField(1)
  final String? pveAddr;
  @HiveField(2)
  final bool? pveIgnoreCert;

  const ServerCustom({
    this.temperature,
    this.pveAddr,
    this.pveIgnoreCert,
  });

  static ServerCustom fromJson(Map<String, dynamic> json) {
    final temperature = json["temperature"] as String?;
    final pveAddr = json["pveAddr"] as String?;
    final pveIgnoreCert = json["pveIgnoreCert"] as bool?;
    return ServerCustom(
      temperature: temperature,
      pveAddr: pveAddr,
      pveIgnoreCert: pveIgnoreCert,
    );
  }

  Map<String, dynamic> toJson() {
    final json = <String, dynamic>{};
    if (temperature != null) {
      json["temperature"] = temperature;
    }
    if (pveAddr != null) {
      json["pveAddr"] = pveAddr;
    }
    if (pveIgnoreCert != null) {
      json["pveIgnoreCert"] = pveIgnoreCert;
    }
    return json;
  }
}
