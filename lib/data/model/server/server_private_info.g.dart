// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'server_private_info.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class SpiAdapter extends TypeAdapter<Spi> {
  @override
  final int typeId = 3;

  @override
  Spi read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return Spi(
      name: fields[0] as String,
      ip: fields[1] as String,
      port: fields[2] as int,
      user: fields[3] as String,
      pwd: fields[4] as String?,
      keyId: fields[5] as String?,
      tags: (fields[6] as List?)?.cast<String>(),
      alterUrl: fields[7] as String?,
      autoConnect: fields[8] == null ? true : fields[8] as bool,
      jumpId: fields[9] as String?,
      custom: fields[10] as ServerCustom?,
      wolCfg: fields[11] as WakeOnLanCfg?,
      envs: (fields[12] as Map?)?.cast<String, String>(),
    );
  }

  @override
  void write(BinaryWriter writer, Spi obj) {
    writer
      ..writeByte(13)
      ..writeByte(0)
      ..write(obj.name)
      ..writeByte(1)
      ..write(obj.ip)
      ..writeByte(2)
      ..write(obj.port)
      ..writeByte(3)
      ..write(obj.user)
      ..writeByte(4)
      ..write(obj.pwd)
      ..writeByte(5)
      ..write(obj.keyId)
      ..writeByte(6)
      ..write(obj.tags)
      ..writeByte(7)
      ..write(obj.alterUrl)
      ..writeByte(8)
      ..write(obj.autoConnect)
      ..writeByte(9)
      ..write(obj.jumpId)
      ..writeByte(10)
      ..write(obj.custom)
      ..writeByte(11)
      ..write(obj.wolCfg)
      ..writeByte(12)
      ..write(obj.envs);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is SpiAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

Spi _$SpiFromJson(Map<String, dynamic> json) => Spi(
      name: json['name'] as String,
      ip: json['ip'] as String,
      port: (json['port'] as num).toInt(),
      user: json['user'] as String,
      pwd: json['pwd'] as String?,
      keyId: json['pubKeyId'] as String?,
      tags: (json['tags'] as List<dynamic>?)?.map((e) => e as String).toList(),
      alterUrl: json['alterUrl'] as String?,
      autoConnect: json['autoConnect'] as bool? ?? true,
      jumpId: json['jumpId'] as String?,
      custom: json['custom'] == null
          ? null
          : ServerCustom.fromJson(json['custom'] as Map<String, dynamic>),
      wolCfg: json['wolCfg'] == null
          ? null
          : WakeOnLanCfg.fromJson(json['wolCfg'] as Map<String, dynamic>),
      envs: (json['envs'] as Map<String, dynamic>?)?.map(
        (k, e) => MapEntry(k, e as String),
      ),
    );

Map<String, dynamic> _$SpiToJson(Spi instance) => <String, dynamic>{
      'name': instance.name,
      'ip': instance.ip,
      'port': instance.port,
      'user': instance.user,
      'pwd': instance.pwd,
      'pubKeyId': instance.keyId,
      'tags': instance.tags,
      'alterUrl': instance.alterUrl,
      'autoConnect': instance.autoConnect,
      'jumpId': instance.jumpId,
      'custom': instance.custom,
      'wolCfg': instance.wolCfg,
      'envs': instance.envs,
    };
