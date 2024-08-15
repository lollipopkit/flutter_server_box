import 'package:hive_flutter/hive_flutter.dart';
import 'package:json_annotation/json_annotation.dart';

part 'private_key_info.g.dart';

@JsonSerializable()
@HiveType(typeId: 1)
class PrivateKeyInfo {
  @HiveField(0)
  final String id;
  @JsonKey(name: 'private_key')
  @HiveField(1)
  final String key;

  const PrivateKeyInfo({
    required this.id,
    required this.key,
  });

  factory PrivateKeyInfo.fromJson(Map<String, dynamic> json) =>
      _$PrivateKeyInfoFromJson(json);

  Map<String, dynamic> toJson() => _$PrivateKeyInfoToJson(this);

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
}
