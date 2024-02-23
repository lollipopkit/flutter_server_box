import 'package:flutter_test/flutter_test.dart';
import 'package:toolbox/data/model/server/sensors.dart';

void main() {
  test('parse sensors', () {
    final sensors = SensorItem.parse(SensorItem.sensorsRaw);
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
