import 'package:flutter_test/flutter_test.dart';
import 'package:toolbox/data/model/server/sensors.dart';

const _sensorsRaw = '''
coretemp-isa-0000
Adapter: ISA adapter
Package id 0:  +56.0°C  (high = +105.0°C, crit = +105.0°C)
Core 0:        +45.0°C  (high = +105.0°C, crit = +105.0°C)
Core 1:        +45.0°C  (high = +105.0°C, crit = +105.0°C)
Core 2:        +45.0°C  (high = +105.0°C, crit = +105.0°C)
Core 3:        +44.0°C  (high = +105.0°C, crit = +105.0°C)

acpitz-acpi-0
Adapter: ACPI interface
temp1:        +27.8°C  (crit = +119.0°C)

iwlwifi_1-virtual-0
Adapter: Virtual device
temp1:        +56.0°C  

nvme-pci-0400
Adapter: PCI adapter
Composite:    +45.9°C  (low  = -273.1°C, high = +83.8°C)
                       (crit = +84.8°C)
Sensor 1:     +45.9°C  (low  = -273.1°C, high = +65261.8°C)
Sensor 2:     +47.9°C  (low  = -273.1°C, high = +65261.8°C)
''';

void main() {
  test('parse sensors', () {
    final sensors = SensorItem.parse(_sensorsRaw);
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
      sensors.map((e) => e.val),
      [
        '+56.0°C  (high = +105.0°C, crit = +105.0°C)',
        '+27.8°C  (crit = +119.0°C)',
        '+56.0°C',
        '+45.9°C  (low  = -273.1°C, high = +83.8°C)',
      ],
    );
  });
}
