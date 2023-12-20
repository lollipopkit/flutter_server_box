import 'package:toolbox/data/res/logger.dart';

/// raw dat from server:
/// ```text
/// POWER_SUPPLY_NAME=hidpp_battery_0
/// POWER_SUPPLY_TYPE=Battery
/// POWER_SUPPLY_ONLINE=1
/// POWER_SUPPLY_STATUS=Discharging
/// POWER_SUPPLY_SCOPE=Device
/// POWER_SUPPLY_MODEL_NAME=MX Anywhere 3
/// POWER_SUPPLY_MANUFACTURER=Logitech
/// POWER_SUPPLY_SERIAL_NUMBER=0f-fc-43-f8
/// POWER_SUPPLY_CAPACITY=35
/// ```
class Battery {
  final int? percent;
  final BatteryStatus status;
  final String? name;
  final int? cycle;
  final int? powerNow;

  const Battery({
    required this.status,
    this.percent,
    this.name,
    this.cycle,
    this.powerNow,
  });

  factory Battery.fromRaw(String raw) {
    final lines = raw.split('\n');
    final map = <String, String>{};
    for (final line in lines) {
      final parts = line.split('=');
      if (parts.length != 2) continue;
      map[parts[0]] = parts[1];
    }

    final capacity = map['POWER_SUPPLY_CAPACITY']; // 30%
    final cycle = map['POWER_SUPPLY_CYCLE_COUNT']; // 30
    final powerNow = map['POWER_SUPPLY_POWER_NOW']; // 30W

    return Battery(
      percent: capacity == null ? null : int.tryParse(capacity),
      status: BatteryStatus.parse(map['POWER_SUPPLY_STATUS']),
      name: map['POWER_SUPPLY_MODEL_NAME'],
      cycle: cycle == null ? null : int.tryParse(cycle),
      powerNow: powerNow == null ? null : int.tryParse(powerNow),
    );
  }
}

enum BatteryStatus {
  charging,
  discharging,
  full,
  unknown,
  ;

  static BatteryStatus parse(String? status) {
    switch (status) {
      case 'Charging':
        return BatteryStatus.charging;
      case 'Discharging':
        return BatteryStatus.discharging;
      case 'Full':
        return BatteryStatus.full;
      default:
        return BatteryStatus.unknown;
    }
  }
}

abstract final class Batteries {
  static List<Battery> parse(String raw) {
    final lines = raw.split('\n');
    final batteries = <Battery>[];
    final oneBatLines = <String>[];
    for (final line in lines) {
      if (line.isEmpty) {
        try {
          batteries.add(Battery.fromRaw(oneBatLines.join('\n')));
        } catch (e, s) {
          Loggers.parse.warning(e, s);
        }
        oneBatLines.clear();
      } else {
        oneBatLines.add(line);
      }
    }
    return batteries;
  }
}
