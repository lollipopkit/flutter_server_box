import 'package:flutter_test/flutter_test.dart';
import 'package:toolbox/data/model/server/sensors.dart';

void main() {
  test('parse sensors', () {
    const sensorsRaw = '''
{
   "coretemp-isa-0000":{
      "Adapter": "ISA adapter",
      "Package id 0":{
         "temp1_input": 51.000,
         "temp1_max": 105.000,
         "temp1_crit": 105.000,
         "temp1_crit_alarm": 0.000
      },
      "Core 0":{
         "temp2_input": 40.000,
         "temp2_max": 105.000,
         "temp2_crit": 105.000,
         "temp2_crit_alarm": 0.000
      },
      "Core 1":{
         "temp3_input": 40.000,
         "temp3_max": 105.000,
         "temp3_crit": 105.000,
         "temp3_crit_alarm": 0.000
      },
      "Core 2":{
         "temp4_input": 40.000,
         "temp4_max": 105.000,
         "temp4_crit": 105.000,
         "temp4_crit_alarm": 0.000
      },
      "Core 3":{
         "temp5_input": 40.000,
         "temp5_max": 105.000,
         "temp5_crit": 105.000,
         "temp5_crit_alarm": 0.000
      }
   },
   "acpitz-acpi-0":{
      "Adapter": "ACPI interface",
      "temp1":{
         "temp1_input": 27.800,
         "temp1_crit": 119.000
      }
   },
   "iwlwifi_1-virtual-0":{
      "Adapter": "Virtual device",
      "temp1":{
ERROR: Can't get value of subfeature temp1_input: Can't read

      }
   },
   "nvme-pci-0400":{
      "Adapter": "PCI adapter",
      "Composite":{
         "temp1_input": 35.850,
         "temp1_max": 83.850,
         "temp1_min": -273.150,
         "temp1_crit": 84.850,
         "temp1_alarm": 0.000
      },
      "Sensor 1":{
         "temp2_input": 35.850,
         "temp2_max": 65261.850,
         "temp2_min": -273.150
      },
      "Sensor 2":{
         "temp3_input": 37.850,
         "temp3_max": 65261.850,
         "temp3_min": -273.150
      }
   }
}
''';
    final sensors = SensorItem.parse(sensorsRaw);
    expect(sensors.map((e) => e.device), [
      'coretemp-isa-0000',
      'acpitz-acpi-0',
      'iwlwifi_1-virtual-0',
      'nvme-pci-0400',
    ]);
    expect(sensors.map((e) => e.adapter), [
      SensorAdaptor.isa,
      SensorAdaptor.acpi,
      SensorAdaptor.virtual,
      SensorAdaptor.pci,
    ]);
    expect(
      sensors.map((e) => e.props),
      [
        {
          'Package id 0': const SensorTemp(current: 51, max: 105),
          'Core 0': const SensorTemp(current: 40, max: 105),
          'Core 1': const SensorTemp(current: 40, max: 105),
          'Core 2': const SensorTemp(current: 40, max: 105),
          'Core 3': const SensorTemp(current: 40, max: 105),
        },
        {
          'temp1': const SensorTemp(current: 27.8, max: 119),
        },
        {},
        {
          'Composite':
              const SensorTemp(current: 35.85, max: 83.85, min: -273.15),
          'Sensor 1':
              const SensorTemp(current: 35.85, max: 65261.85, min: -273.15),
          'Sensor 2':
              const SensorTemp(current: 37.85, max: 65261.85, min: -273.15),
        },
      ],
    );
  });
}
