import 'package:flutter_test/flutter_test.dart';
import 'package:server_box/data/model/server/memory.dart';

void main() {
  group('Memory Model Tests', () {
    test('Test Memory.parse', () {
      const raw = '''MemTotal:       32768 kB
MemFree:        16384 kB
MemAvailable:   24576 kB''';
      final result = Memory.parse(raw);
      expect(result.total, 32768);
      expect(result.free, 16384);
      expect(result.avail, 24576);
      expect(result.usedPercent, closeTo(0.25, 0.01));
      expect(result.availPercent, closeTo(0.75, 0.01));
    });

    test('Test parseBsdMemory for macOS', () {
      const raw = 'PhysMem: 32G used (1536M wired), 64G unused.';
      final result = parseBsdMemory(raw);
      expect(result.total, (32 + 64) * 1024 * 1024);
      expect(result.free, 64 * 1024 * 1024);
      expect(result.avail, 64 * 1024 * 1024);
    });

    test('Test parseBsdMemory for FreeBSD', () {
      const raw =
          'Mem: 456M Active, 2918M Inact, 1127M Wired, 187M Cache, 829M Buf, 3535M Free';
      final result = parseBsdMemory(raw);
      expect(result.total, (456 + 2918 + 1127 + 187 + 829 + 3535) * 1024);
      expect(result.free, 3535 * 1024);
      expect(result.avail, 3535 * 1024);
    });
  });
}
