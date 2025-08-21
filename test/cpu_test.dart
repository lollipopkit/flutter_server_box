import 'package:flutter_test/flutter_test.dart';
import 'package:server_box/data/model/server/cpu.dart';

void main() {
  group('CPU Model Tests', () {
    test('Test SingleCpuCore.parse', () {
      const raw = 'cpu  18232538 52837 5772391 334460731 247294 0 134107 0 0 0';

      final result = SingleCpuCore.parse(raw);
      expect(result.length, 1);
      expect(result[0].id, 'cpu');
      expect(result[0].total, 358899898);
    });
    test('Test Cpus calculation', () {
      final pre = SingleCpuCore.parse(
          'cpu 18232538 52837 5772391 334460731 247294 0 134107 0 0 0');
      final now = SingleCpuCore.parse(
          'cpu 18232638 52937 5772491 334460831 247294 0 134107 0 0 0');
      final cpus = Cpus(pre, now);
      cpus.onUpdate();
      expect(cpus.usedPercent(), closeTo(75.0, 0.1));
      expect(cpus.user, closeTo(25.0, 0.1));
      expect(cpus.sys, closeTo(25.0, 0.1));
    });

    test('Test parseBsdCpu for macOS', () {
      const raw = 'CPU usage: 14.70% user, 12.76% sys, 72.52% idle';
      final cpus = parseBsdCpu(raw);
      final status = cpus.now.first;
      expect(status.user, 14);
      expect(status.sys, 12);
      expect(status.idle, 72);
    });

    test('Test parseBsdCpu for FreeBSD', () {
      const raw =
          'CPU: 5.2% user, 0.0% nice, 3.1% system, 0.1% interrupt, 91.6% idle';
      final cpus = parseBsdCpu(raw);
      final status = cpus.now.first;
      expect(status.user, 5);
      expect(status.nice, 0);
      expect(status.sys, 3);
      expect(status.irq, 0);
      expect(status.idle, 91);
    });
  });
}
