import 'dart:convert';

import 'package:fl_lib/fl_lib.dart';

class DiskSmart {
  final String device;
  final bool? healthy;
  final double? temperature;

  const DiskSmart({required this.device, this.healthy, this.temperature});

  static List<DiskSmart> parse(String raw) {
    final results = <DiskSmart>[];
    for (final line in raw.split('\n')) {
      final jsonStr = line.trim();
      if (jsonStr.isEmpty) continue;
      try {
        final data = json.decode(jsonStr) as Map<String, dynamic>;
        final device = data['device']?['name']?.toString() ?? '';
        final healthy = data['smart_status']?['passed'] as bool?;
        final tempVal = data['temperature']?['current'];
        final double? temp = tempVal is num
            ? tempVal.toDouble()
            : double.tryParse('$tempVal');
        results.add(
          DiskSmart(device: device, healthy: healthy, temperature: temp),
        );
      } catch (e, s) {
        Loggers.app.warning('DiskSmart parse', e, s);
      }
    }
    return results;
  }
}
