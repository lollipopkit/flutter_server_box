import 'package:flutter_test/flutter_test.dart';
import 'package:server_box/data/model/server/sensors.dart';

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

const _sensorsRaw2 = '''
asusec-isa-0000
Adapter: ISA adapter
CPU Core:      1.26 V
Chipset:     2473 RPM
Chipset:      +60.0°C
CPU:          +36.0°C
Motherboard:  +34.0°C
T_Sensor:     -40.0°C
VRM:          +20.0°C
CPU:          35.00 A

nct6798-isa-0290
Adapter: ISA adapter
in0:                        1.19 V  (min =  +0.00 V, max =  +1.74 V)
in1:                      1000.00 mV (min =  +0.00 V, max =  +0.00 V)  ALARM
in2:                        3.34 V  (min =  +0.00 V, max =  +0.00 V)  ALARM
in3:                        3.28 V  (min =  +0.00 V, max =  +0.00 V)  ALARM
in4:                      1000.00 mV (min =  +0.00 V, max =  +0.00 V)  ALARM
in5:                      856.00 mV (min =  +0.00 V, max =  +0.00 V)
in6:                      232.00 mV (min =  +0.00 V, max =  +0.00 V)  ALARM
in7:                        3.34 V  (min =  +0.00 V, max =  +0.00 V)  ALARM
in8:                        3.23 V  (min =  +0.00 V, max =  +0.00 V)  ALARM
in9:                        1.78 V  (min =  +0.00 V, max =  +0.00 V)  ALARM
in10:                     848.00 mV (min =  +0.00 V, max =  +0.00 V)  ALARM
in11:                     880.00 mV (min =  +0.00 V, max =  +0.00 V)  ALARM
in12:                       1.03 V  (min =  +0.00 V, max =  +0.00 V)  ALARM
in13:                     320.00 mV (min =  +0.00 V, max =  +0.00 V)  ALARM
in14:                     240.00 mV (min =  +0.00 V, max =  +0.00 V)  ALARM
fan1:                        0 RPM  (min =    0 RPM)
fan2:                     1764 RPM  (min =    0 RPM)
fan3:                        0 RPM  (min =    0 RPM)
fan4:                        0 RPM  (min =    0 RPM)
fan5:                        0 RPM  (min =    0 RPM)
fan6:                        0 RPM  (min =    0 RPM)
SYSTIN:                    +34.0°C  (high = +80.0°C, hyst = +75.0°C)
                                    (crit = +125.0°C)  sensor = thermistor
CPUTIN:                    +35.0°C  (high = +80.0°C, hyst = +75.0°C)
                                    (crit = +125.0°C)  sensor = thermistor
AUXTIN0:                   +90.0°C  (high = +80.0°C, hyst = +75.0°C)  ALARM
                                    (crit = +125.0°C)  sensor = thermistor
AUXTIN1:                   +34.0°C  (high = +80.0°C, hyst = +75.0°C)
                                    (crit = +125.0°C)  sensor = thermistor
AUXTIN2:                   +33.0°C  (high = +80.0°C, hyst = +75.0°C)
                                    (crit = +100.0°C)  sensor = thermistor
AUXTIN3:                   +95.0°C  (high = +80.0°C, hyst = +75.0°C)  ALARM
                                    (crit = +100.0°C)  sensor = thermistor
AUXTIN4:                   +34.0°C  (high = +80.0°C, hyst = +75.0°C)
                                    (crit = +100.0°C)
PECI Agent 0 Calibration:  +36.0°C  (high = +80.0°C, hyst = +75.0°C)
PCH_CHIP_CPU_MAX_TEMP:      +0.0°C
PCH_CHIP_TEMP:              +0.0°C
PCH_CPU_TEMP:               +0.0°C
PCH_MCH_TEMP:               +0.0°C
TSI0_TEMP:                 +44.6°C
TSI1_TEMP:                 +60.0°C
intrusion0:               ALARM
intrusion1:               ALARM
beep_enable:              disabled

nvme-pci-0400
Adapter: PCI adapter
Composite:    +45.9°C  (low  = -273.1°C, high = +69.8°C)
                       (crit = +79.8°C)

k10temp-pci-00c3
Adapter: PCI adapter
Tctl:         +44.9°C
Tccd1:        +41.0°C
Tccd2:        +38.5°C
''';

void main() {
  test('parse sensors1', () {
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
      sensors.map((e) => e.summary),
      [
        '+56.0°C  (high = +105.0°C, crit = +105.0°C)',
        '+27.8°C  (crit = +119.0°C)',
        '+56.0°C',
        '+45.9°C  (low  = -273.1°C, high = +83.8°C)',
      ],
    );
  });

  test('parse sensors2', () {
    final sensors = SensorItem.parse(_sensorsRaw2);
    expect(sensors.map((e) => e.device), [
      'asusec-isa-0000',
      'nct6798-isa-0290',
      'nvme-pci-0400',
      'k10temp-pci-00c3',
    ]);
    expect(sensors.map((e) => e.adapter), [
      SensorAdaptor.isa,
      SensorAdaptor.isa,
      SensorAdaptor.pci,
      SensorAdaptor.pci,
    ]);
    expect(
      sensors.map((e) => e.summary),
      [
        '1.26 V',
        '1.19 V  (min =  +0.00 V, max =  +1.74 V)',
        '+45.9°C  (low  = -273.1°C, high = +69.8°C)',
        '+44.9°C',
      ],
    );
  });
}
