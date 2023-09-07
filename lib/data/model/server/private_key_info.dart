import 'package:hive_flutter/hive_flutter.dart';

part 'private_key_info.g.dart';

@HiveType(typeId: 1)
class PrivateKeyInfo {
  @HiveField(0)
  final String id;
  @HiveField(1)
  final String key;

  const PrivateKeyInfo({
    required this.id,
    required this.key,
  });

  String? get type {
    final lines = key.split('\n');
    if (lines.length < 2) {
      return null;
    }
    final firstLine = lines[0];
    final splited = firstLine.split(RegExp(r'\s+'));
    if (splited.length < 2) {
      return null;
    }
    return splited[1];
  }

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
