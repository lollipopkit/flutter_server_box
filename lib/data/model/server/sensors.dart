import 'package:fl_lib/fl_lib.dart';

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
  final Map<String, String> details;

  const SensorItem({
    required this.device,
    required this.adapter,
    required this.details,
  });

  String get toMarkdown {
    final sb = StringBuffer();
    sb.writeln('| ${libL10n.name} | ${libL10n.content} |');
    sb.writeln('| --- | --- |');
    for (final entry in details.entries) {
      sb.writeln('| ${entry.key} | ${entry.value} |');
    }
    return sb.toString();
  }

  String? get summary {
    return details.values.firstOrNull;
  }

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

      final details = <String, String>{};
      for (var idx = 2; idx < len; idx++) {
        final part = sensorLines[idx];
        final detailParts = part.split(':');
        if (detailParts.length < 2) continue;
        final key = detailParts[0].trim();
        final value = detailParts[1].trim();
        details[key] = value;
      }
      sensors.add(SensorItem(
        device: device,
        adapter: adapter,
        details: details,
      ));
    }

    return sensors;
  }
}
