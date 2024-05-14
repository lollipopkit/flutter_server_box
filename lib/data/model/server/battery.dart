import 'package:fl_lib/fl_lib.dart';

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
  final String? tech;

  const Battery({
    required this.status,
    this.percent,
    this.name,
    this.cycle,
    this.tech,
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

    var name = map['POWER_SUPPLY_MODEL_NAME'];
    name ??= map['POWER_SUPPLY_NAME'];

    return Battery(
      percent: capacity == null ? null : int.tryParse(capacity),
      status: BatteryStatus.parse(map['POWER_SUPPLY_STATUS']),
      name: name,
      cycle: cycle == null ? null : int.tryParse(cycle),
      tech: map['POWER_SUPPLY_TECHNOLOGY'],
    );
  }

  @override
  String toString() {
    return 'Battery{$percent, $status, $name, $cycle}';
  }

  bool get isLiPoly => tech == 'Li-poly';
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
  static List<Battery> parse(String raw, [bool onlyLiPoly = false]) {
    final lines = raw.split('\n');
    final batteries = <Battery>[];
    final oneBatLines = <String>[];
    for (final line in lines) {
      if (line.isEmpty) {
        try {
          final bat = Battery.fromRaw(oneBatLines.join('\n'));
          if (onlyLiPoly && !bat.isLiPoly) continue;
          batteries.add(bat);
        } catch (e, s) {
          Loggers.app.warning(e, s);
        }
        oneBatLines.clear();
      } else {
        oneBatLines.add(line);
      }
    }
    return batteries;
  }
}
