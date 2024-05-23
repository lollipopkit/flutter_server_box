import 'dart:io';

import 'package:hive_flutter/hive_flutter.dart';
import 'package:wake_on_lan/wake_on_lan.dart';

part 'wol_cfg.g.dart';

@HiveType(typeId: 8)
final class WakeOnLanCfg {
  @HiveField(0)
  final String mac;
  @HiveField(1)
  final String ip;
  @HiveField(2)
  final String? pwd;

  const WakeOnLanCfg({
    required this.mac,
    required this.ip,
    this.pwd,
  });

  (Object?, bool) validate() {
    final macValidation = MACAddress.validate(mac);
    final ipValidation = IPAddress.validate(
      ip,
      type: ip.contains(':')
          ? InternetAddressType.IPv6
          : InternetAddressType.IPv4,
    );
    final pwdValidation = pwd != null
        ? SecureONPassword.validate(pwd)
        : (state: true, error: null);

    final valid =
        macValidation.state && ipValidation.state && pwdValidation.state;
    final err =
        macValidation.error ?? ipValidation.error ?? pwdValidation.error;
    return (err, valid);
  }

  Future<void> wake() {
    if (!validate().$2) {
      throw Exception('Invalid WakeOnLanCfg');
    }

    final ip_ = IPAddress(ip);
    final mac_ = MACAddress(mac);
    final pwd_ = pwd != null ? SecureONPassword(pwd!) : null;
    final obj = WakeOnLAN(ip_, mac_, password: pwd_);
    return obj.wake(
      repeat: 3,
      repeatDelay: const Duration(milliseconds: 500),
    );
  }

  static WakeOnLanCfg fromJson(Map<String, dynamic> json) {
    return WakeOnLanCfg(
      mac: json['mac'] as String,
      ip: json['ip'] as String,
      pwd: json['pwd'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    final map = <String, dynamic>{
      'mac': mac,
      'ip': ip,
    };
    if (pwd != null) {
      map['pwd'] = pwd;
    }
    return map;
  }
}
