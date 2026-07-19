
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
  unknown;

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

// Parsing implementation migrated to the shared Rust library sbm_parser (see doc/adr/0001)
