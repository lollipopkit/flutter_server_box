import 'dart:convert';

import 'package:toolbox/core/extension/listx.dart';
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

final class SensorTemp {
  final double? current;
  final double? max;
  final double? min;

  const SensorTemp({this.current, this.max, this.min});

  @override
  String toString() {
    return 'SensorTemp{current: $current, max: $max, min: $min}';
  }

  @override
  operator ==(Object other) {
    if (identical(this, other)) return true;

    return other is SensorTemp &&
        other.current == current &&
        other.max == max &&
        other.min == min;
  }

  @override
  int get hashCode => current.hashCode ^ max.hashCode ^ min.hashCode;
}

final class SensorItem {
  final String device;
  final SensorAdaptor adapter;
  final Map<String, SensorTemp> props;

  const SensorItem({
    required this.device,
    required this.adapter,
    required this.props,
  });

  static List<SensorItem> parse(String raw) {
    final rmErrRaw = raw.split('\n')
      ..removeWhere((element) => element.contains('ERROR:'));
    final map = json.decode(rmErrRaw.join('\n')) as Map<String, dynamic>;
    final items = <SensorItem>[];
    for (final key in map.keys) {
      try {
        final adapter = SensorAdaptor.parse(map[key]['Adapter'] as String);
        final props = <String, SensorTemp>{};
        for (final subKey in map[key].keys) {
          if (subKey == 'Adapter') {
            continue;
          }
          final subMap = map[key][subKey] as Map<String, dynamic>;
          final currentKey =
              subMap.keys.toList().firstWhereOrNull((e) => e.endsWith('input'));
          final current = subMap[currentKey] as double?;
          final maxKey = subMap.keys
              .toList()
              .firstWhereOrNull((e) => e.endsWith('max') || e.endsWith('crit'));
          final max = subMap[maxKey] as double?;
          final minKey =
              subMap.keys.toList().firstWhereOrNull((e) => e.endsWith('min'));
          final min = subMap[minKey] as double?;
          if (current == null && max == null && min == null) {
            continue;
          }
          props[subKey] = SensorTemp(current: current, max: max, min: min);
        }
        items.add(SensorItem(device: key, adapter: adapter, props: props));
      } catch (e, s) {
        Loggers.parse.warning(e, s);
        continue;
      }
    }
    return items;
  }
}
