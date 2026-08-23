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
      // A sensor that is present but has nothing to say reports null or a
      // sentinel — see [_reading]. A reading of 0 °C would be a lie rather
      // than a gap, so neither is turned into one.
      final value = _reading(
        entry['ReadingCelsius'],
        min: _tempMin,
        max: _tempMax,
      );
      if (value == null) continue;
      temps.add(
        BmcReading(name: _name(entry), value: value, unit: 'Cel'),
      );
    }

    for (final entry in _list(thermal?['Fans'])) {
      // `Reading` is current; `ReadingRPM` is what older services called it
      final value =
          _reading(entry['Reading'], min: 0, max: _fanMax) ??
          _reading(entry['ReadingRPM'], min: 0, max: _fanMax);
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
      watts ??= _reading(
        entry['PowerConsumedWatts'],
        min: 0,
        max: _wattsMax,
      );
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
      final name = _name(s);
      final unit = s['ReadingUnits'] as String?;
      // The bound depends on what is being measured, so the reading is taken
      // per type rather than once up front.
      final raw = s['Reading'];
      switch (s['ReadingType']) {
        case 'Temperature':
          final value = _reading(raw, min: _tempMin, max: _tempMax);
          if (value == null) continue;
          temps.add(BmcReading(name: name, value: value, unit: unit ?? 'Cel'));
        case 'Rotational':
        case 'Percent' when name.toLowerCase().contains('fan'):
          final value = _reading(raw, min: 0, max: _fanMax);
          if (value == null) continue;
          fans.add(BmcReading(name: name, value: value, unit: unit ?? 'RPM'));
        case 'Power':
          final value = _reading(raw, min: 0, max: _wattsMax);
          if (value == null) continue;
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

  /// A reading, or null when the service is saying it has none.
  ///
  /// `null` is what the specification suggests for a sensor with nothing to
  /// report, and some firmware does that. Others send a sentinel: an H3C
  /// R5350 G6 reports `4294967295` — `0xFFFFFFFF`, unsigned -1 — for every
  /// temperature it cannot read, which was 18 of its 20. Taken at face value
  /// that reaches the detail card as `4294967295 Cel`.
  ///
  /// Filtered by plausibility rather than by matching known sentinels: the
  /// next vendor's is `65535` or `-1` or `127`, and a list of them is a list
  /// that is always one short. Nothing real falls in these gaps — a chassis
  /// sensor below absolute zero or above a thousand degrees is not a reading,
  /// and neither is a fan at four billion RPM.
  static double? _reading(Object? raw, {required double min, required double max}) {
    final value = _num(raw);
    if (value == null) return null;
    if (value.isNaN || value.isInfinite) return null;
    if (value < min || value > max) return null;
    return value;
  }

  /// Colder than absolute zero, or hotter than anything that would still be a
  /// chassis.
  static const _tempMin = -273.15;
  static const _tempMax = 1000.0;

  /// A fan reading is RPM or a percentage; neither is ever negative, and no
  /// fan in a server turns this fast.
  static const _fanMax = 100000.0;

  /// A chassis drawing more than this is not one.
  static const _wattsMax = 100000.0;

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
