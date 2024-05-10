import 'package:toolbox/data/res/logger.dart';

final class SensorAdaptor {
  final String raw;

  const SensorAdaptor(this.raw);

  static const acpiRaw = 'ACPI interface';
  static const pciRaw = 'PCI adapter';
  static const virtualRaw = 'Virtual device';
  static const isaRaw = 'ISA adapter';
  static const acpi = SensorAdaptor(acpiRaw);
  static const pci = SensorAdaptor(pciRaw);
  static const virtual = SensorAdaptor(virtualRaw);
  static const isa = SensorAdaptor(isaRaw);

  static SensorAdaptor parse(String raw) => switch (raw) {
        acpiRaw => acpi,
        pciRaw => pci,
        virtualRaw => virtual,
        isaRaw => isa,
        _ => SensorAdaptor(raw),
      };
}

final class SensorItem {
  final String device;
  final SensorAdaptor adapter;
  final String val;

  const SensorItem({
    required this.device,
    required this.adapter,
    required this.val,
  });

  static List<SensorItem> parse(String raw) {
    final eachSensorLines = <List<String>>[[]];
    final lines = raw.split('\n');
    var emptyLinesCount = 0;
    for (var i = 0; i < lines.length; i++) {
      final line = lines[i];
      if (line.isEmpty) {
        eachSensorLines.add([]);
        emptyLinesCount++;
        continue;
      }
      eachSensorLines.last.add(line);
    }

    if (emptyLinesCount + 1 != eachSensorLines.length) {
      Loggers.app.warning('Empty lines count not match');
    }

    final sensors = <SensorItem>[];
    for (final sensorLines in eachSensorLines) {
      // At least 3 lines: [device, adapter, temp]
      final len = sensorLines.length;
      if (len < 3) continue;
      final device = sensorLines.first;
      final adapter =
          SensorAdaptor.parse(sensorLines[1].split(':').last.trim());
      final line = sensorLines[2];
      final parts = line.split(':');
      if (parts.length < 2) {
        continue;
      }
      final val = parts[1].trim();
      sensors.add(SensorItem(device: device, adapter: adapter, val: val));
    }

    return sensors;
  }
}
