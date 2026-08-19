/// Readings out of both sensor models, as the two present them.
///
/// The old pair and the new collection describe the same fans and the same
/// temperatures in different shapes, and firmware in the middle of the
/// migration carries both. Everything here is a case where reading the wrong
/// field, or reading a missing one as zero, would put a wrong number on screen
/// rather than fail — which is the kind of bug nobody reports.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:server_box/data/model/server/bmc/redfish.dart';
import 'package:server_box/data/model/server/bmc/redfish_sensors.dart';

void main() {
  group('the deprecated Thermal/Power pair', () {
    test('reads temperatures, fans and chassis watts', () {
      final sensors = BmcSensors.fromLegacy(
        thermal: {
          'Temperatures': [
            {'Name': 'CPU1 Temp', 'ReadingCelsius': 47},
            {'Name': 'Inlet Temp', 'ReadingCelsius': 21.5},
          ],
          'Fans': [
            {'Name': 'FAN1', 'Reading': 4800, 'ReadingUnits': 'RPM'},
          ],
        },
        power: {
          'PowerControl': [
            {'PowerConsumedWatts': 210},
          ],
        },
      );

      expect(sensors.temperatures, [
        const BmcReading(name: 'CPU1 Temp', value: 47, unit: 'Cel'),
        const BmcReading(name: 'Inlet Temp', value: 21.5, unit: 'Cel'),
      ]);
      expect(sensors.fans.single.value, 4800);
      expect(sensors.watts, 210);
    });

    test('a sensor with nothing to say is absent, not zero', () {
      // Present-but-null is how a BMC reports a sensor it cannot read right
      // now. 0 °C would be a lie, and a lie that looks like data.
      final sensors = BmcSensors.fromLegacy(
        thermal: {
          'Temperatures': [
            {'Name': 'CPU2 Temp', 'ReadingCelsius': null},
            {'Name': 'CPU1 Temp', 'ReadingCelsius': 40},
          ],
        },
      );
      expect(sensors.temperatures.single.name, 'CPU1 Temp');
    });

    test('an older service calling it ReadingRPM is still read', () {
      final sensors = BmcSensors.fromLegacy(
        thermal: {
          'Fans': [
            {'Name': 'FAN1', 'ReadingRPM': 3000},
          ],
        },
      );
      expect(sensors.fans.single.value, 3000);
    });

    test('the unit is kept rather than normalised', () {
      // A fan reported in Percent and one in RPM are different numbers, and
      // rewriting either into the other would invent data
      final sensors = BmcSensors.fromLegacy(
        thermal: {
          'Fans': [
            {'Name': 'FAN1', 'Reading': 38, 'ReadingUnits': 'Percent'},
          ],
        },
      );
      expect(sensors.fans.single.unit, 'Percent');
    });

    test('either resource may be missing on its own', () {
      // They are separate resources with separate permissions
      final noPower = BmcSensors.fromLegacy(
        thermal: {
          'Temperatures': [
            {'Name': 'T', 'ReadingCelsius': 30},
          ],
        },
      );
      expect(noPower.watts, isNull);
      expect(noPower.temperatures, hasLength(1));

      expect(BmcSensors.fromLegacy().isEmpty, isTrue);
    });
  });

  group('the Sensors collection', () {
    test('sorts members by their reading type', () {
      final sensors = BmcSensors.fromSensors([
        {'Name': 'CPU', 'ReadingType': 'Temperature', 'Reading': 52.0},
        {
          'Name': 'FAN0',
          'ReadingType': 'Rotational',
          'Reading': 5200,
          'ReadingUnits': 'RPM',
        },
        {'Name': 'Total Power', 'ReadingType': 'Power', 'Reading': 180},
      ]);

      expect(sensors.temperatures.single.name, 'CPU');
      expect(sensors.fans.single.value, 5200);
      expect(sensors.watts, 180);
    });

    test('the largest power reading is the one about the whole machine', () {
      // Services report several rails; the chassis total is what a card shows
      final sensors = BmcSensors.fromSensors([
        {'Name': 'PSU1 Input', 'ReadingType': 'Power', 'Reading': 90},
        {'Name': 'Chassis Total', 'ReadingType': 'Power', 'Reading': 175},
        {'Name': 'PSU2 Input', 'ReadingType': 'Power', 'Reading': 85},
      ]);
      expect(sensors.watts, 175);
    });

    test('a fan reported as a percentage is still a fan', () {
      final sensors = BmcSensors.fromSensors([
        {
          'Name': 'Fan 1 PWM',
          'ReadingType': 'Percent',
          'Reading': 42,
          'ReadingUnits': 'Percent',
        },
        {'Name': 'CPU Utilisation', 'ReadingType': 'Percent', 'Reading': 12},
      ]);
      // The second is a percentage of something else entirely, and belongs on
      // no fan row
      expect(sensors.fans.single.name, 'Fan 1 PWM');
    });

    test('a member with no reading is skipped', () {
      final sensors = BmcSensors.fromSensors([
        {'Name': 'CPU', 'ReadingType': 'Temperature', 'Reading': null},
      ]);
      expect(sensors.isEmpty, isTrue);
    });

    test('an unfamiliar reading type is ignored rather than guessed at', () {
      final sensors = BmcSensors.fromSensors([
        {'Name': 'Airflow', 'ReadingType': 'AirFlowCFM', 'Reading': 30},
      ]);
      expect(sensors.isEmpty, isTrue);
    });
  });

  group('which resources to fetch', () {
    test('the new model needs only the Sensors collection', () {
      final chassis = RedfishChassis.fromJson({
        'ThermalSubsystem': {'@odata.id': '/ts'},
        'PowerSubsystem': {'@odata.id': '/ps'},
        'Sensors': {'@odata.id': '/s'},
      });
      expect(sensorPathsFor(chassis), ['/s']);
    });

    test('the old model needs both halves', () {
      final chassis = RedfishChassis.fromJson({
        'Thermal': {'@odata.id': '/t'},
        'Power': {'@odata.id': '/p'},
      });
      expect(sensorPathsFor(chassis), ['/t', '/p']);
    });

    test('a chassis with one half of the old model asks for that half', () {
      final chassis = RedfishChassis.fromJson({
        'Thermal': {'@odata.id': '/t'},
      });
      expect(sensorPathsFor(chassis), ['/t']);
    });

    test('both models present means the new one, and one request', () {
      final chassis = RedfishChassis.fromJson({
        'Thermal': {'@odata.id': '/t'},
        'Power': {'@odata.id': '/p'},
        'ThermalSubsystem': {'@odata.id': '/ts'},
        'Sensors': {'@odata.id': '/s'},
      });
      expect(sensorPathsFor(chassis), ['/s']);
    });

    test('a chassis with neither asks for nothing', () {
      expect(sensorPathsFor(RedfishChassis.fromJson({})), isEmpty);
    });
  });
}
