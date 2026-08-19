/// Sensor readings, out of whichever of the two models a service presents.
///
/// Redfish 2020.4 replaced `Thermal` and `Power` with `ThermalSubsystem`,
/// `PowerSubsystem` and one `Sensors` collection. Firmware follows unevenly and
/// transitional firmware carries both, so both are read here and neither is
/// inferred from the vendor's name — see `docs/principles/bmc.md`.
///
/// Pure, like the rest under the transport: these are the shapes, not the
/// fetching.
library;

import 'package:server_box/data/model/server/bmc/redfish.dart';

/// One thing a BMC measured.
class BmcReading {
  const BmcReading({required this.name, required this.value, this.unit});

  final String name;
  final double value;

  /// As the service labelled it, or null where the model implies it. Kept
  /// rather than normalised: a fan reported in `Percent` and one in `RPM` are
  /// different numbers, and rewriting either into the other would invent data.
  final String? unit;

  @override
  bool operator ==(Object other) =>
      other is BmcReading &&
      name == other.name &&
      value == other.value &&
      unit == other.unit;

  @override
  int get hashCode => Object.hash(name, value, unit);

  @override
  String toString() => 'BmcReading($name, $value${unit ?? ''})';
}

/// What a chassis had to say about itself.
class BmcSensors {
  const BmcSensors({
    this.temperatures = const [],
    this.fans = const [],
    this.watts,
  });

  final List<BmcReading> temperatures;
  final List<BmcReading> fans;

  /// Input power for the whole chassis, where the service reports one.
  final double? watts;

  bool get isEmpty =>
      temperatures.isEmpty && fans.isEmpty && watts == null;

  /// The deprecated pair: `Chassis/{id}/Thermal` and `/Power`.
  ///
  /// Either may be absent — they are separate resources and separate
  /// permissions — so both are optional and what is missing is simply missing.
  factory BmcSensors.fromLegacy({
    Map<String, dynamic>? thermal,
    Map<String, dynamic>? power,
  }) {
    final temps = <BmcReading>[];
    final fans = <BmcReading>[];
    double? watts;

    for (final entry in _list(thermal?['Temperatures'])) {
      final value = _num(entry['ReadingCelsius']);
      // A sensor that is present but has nothing to say reports null, and a
      // reading of 0 °C would be a lie rather than a gap
      if (value == null) continue;
      temps.add(
        BmcReading(name: _name(entry), value: value, unit: 'Cel'),
      );
    }

    for (final entry in _list(thermal?['Fans'])) {
      // `Reading` is current; `ReadingRPM` is what older services called it
      final value = _num(entry['Reading']) ?? _num(entry['ReadingRPM']);
      if (value == null) continue;
      fans.add(
        BmcReading(
          name: _name(entry),
          value: value,
          unit: entry['ReadingUnits'] as String? ?? 'RPM',
        ),
      );
    }

    for (final entry in _list(power?['PowerControl'])) {
      watts ??= _num(entry['PowerConsumedWatts']);
    }

    return BmcSensors(temperatures: temps, fans: fans, watts: watts);
  }

  /// The current model: one `Sensors` collection, each member typed.
  ///
  /// Takes the members already fetched rather than a collection to walk,
  /// because how many of them to fetch is a decision about a slow device and
  /// belongs to the caller, not to a parser.
  factory BmcSensors.fromSensors(List<Map<String, dynamic>> sensors) {
    final temps = <BmcReading>[];
    final fans = <BmcReading>[];
    double? watts;

    for (final s in sensors) {
      final value = _num(s['Reading']);
      if (value == null) continue;
      final name = _name(s);
      final unit = s['ReadingUnits'] as String?;
      switch (s['ReadingType']) {
        case 'Temperature':
          temps.add(BmcReading(name: name, value: value, unit: unit ?? 'Cel'));
        case 'Rotational':
        case 'Percent' when name.toLowerCase().contains('fan'):
          fans.add(BmcReading(name: name, value: value, unit: unit ?? 'RPM'));
        case 'Power':
          // The chassis total, not every rail: a service reports several, and
          // the largest is the one that is about the whole machine
          if (watts == null || value > watts) watts = value;
      }
    }

    return BmcSensors(temperatures: temps, fans: fans, watts: watts);
  }

  static List<Map<String, dynamic>> _list(Object? raw) {
    if (raw is! List) return const [];
    return [
      for (final e in raw)
        if (e is Map<String, dynamic>) e,
    ];
  }

  static double? _num(Object? raw) => switch (raw) {
    final int i => i.toDouble(),
    final double d => d,
    _ => null,
  };

  static String _name(Map<String, dynamic> entry) =>
      entry['Name'] as String? ?? entry['MemberId'] as String? ?? '?';
}

/// Which resources to fetch for a chassis, given what it linked.
///
/// Returned as paths rather than fetched, so the decision is testable and the
/// fetching stays in one place.
List<String> sensorPathsFor(RedfishChassis chassis) => switch (chassis.model) {
  SensorModel.modern => [?chassis.sensors],
  SensorModel.legacy => [
    ?chassis.thermal,
    ?chassis.power,
  ],
  SensorModel.none => const [],
};
