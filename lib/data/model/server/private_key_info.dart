import 'package:hive_flutter/hive_flutter.dart';

part 'private_key_info.g.dart';

@HiveType(typeId: 1)
class PrivateKeyInfo {
  @HiveField(0)
  final String id;
  @HiveField(1)
  final String key;

  PrivateKeyInfo({
    required this.id,
    required this.key,
  });

  PrivateKeyInfo.fromJson(Map<String, dynamic> json)
      : id = json["id"].toString(),
        key = json["private_key"].toString();

  Map<String, dynamic> toJson() {
    final data = <String, String>{};
    data["id"] = id;
    data["private_key"] = key;
    return data;
  }
}
