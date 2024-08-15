// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'wol_cfg.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class WakeOnLanCfgAdapter extends TypeAdapter<WakeOnLanCfg> {
  @override
  final int typeId = 8;

  @override
  WakeOnLanCfg read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return WakeOnLanCfg(
      mac: fields[0] as String,
      ip: fields[1] as String,
      pwd: fields[2] as String?,
    );
  }

  @override
  void write(BinaryWriter writer, WakeOnLanCfg obj) {
    writer
      ..writeByte(3)
      ..writeByte(0)
      ..write(obj.mac)
      ..writeByte(1)
      ..write(obj.ip)
      ..writeByte(2)
      ..write(obj.pwd);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is WakeOnLanCfgAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

WakeOnLanCfg _$WakeOnLanCfgFromJson(Map<String, dynamic> json) => WakeOnLanCfg(
      mac: json['mac'] as String,
      ip: json['ip'] as String,
      pwd: json['pwd'] as String?,
    );

Map<String, dynamic> _$WakeOnLanCfgToJson(WakeOnLanCfg instance) =>
    <String, dynamic>{
      'mac': instance.mac,
      'ip': instance.ip,
      'pwd': instance.pwd,
    };
