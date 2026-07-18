import 'package:fl_lib/fl_lib.dart';

final class SensorAdaptor {
  final String raw;

  const SensorAdaptor(this.raw);

  static const acpiRaw = 'ACPI interface';
  static const pciRaw = 'PCI adapter';
  static const virtualRaw = 'Virtual device';
  static const isaRaw = 'ISA adapter';
  static SensorAdaptor parse(String raw) => switch (raw) {
    acpiRaw => const SensorAdaptor(acpiRaw),
    pciRaw => const SensorAdaptor(pciRaw),
    virtualRaw => const SensorAdaptor(virtualRaw),
    isaRaw => const SensorAdaptor(isaRaw),
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

  // 解析实现已迁移至共享 Rust 库 sbm_parser(见 doc/adr/0001)
}
