// ignore_for_file: avoid_print

import 'package:flutter_test/flutter_test.dart';
import 'package:server_box/data/model/server/disk.dart';

// Parsing tests migrated to crates/sbm_parser/tests/dart_compat.rs (see doc/adr/0001)
void main() {
  group('DiskUsage', () {
    test('DiskUsage does not double-count parent and child filesystems', () {
      final usage = DiskUsage.parse([
        Disk(
          path: '/dev/sda1',
          mount: '/',
          usedPercent: 50,
          used: BigInt.from(100),
          size: BigInt.from(200),
          avail: BigInt.from(100),
          children: [
            Disk(
              path: '/dev/sda1-child',
              mount: '/child',
              usedPercent: 50,
              used: BigInt.from(1000),
              size: BigInt.from(2000),
              avail: BigInt.from(1000),
            ),
          ],
        ),
      ]);

      expect(usage.used, BigInt.from(100));
      expect(usage.size, BigInt.from(200));
    });

    test('DiskUsage handles zero size correctly', () {
      final usage = DiskUsage(used: BigInt.from(1000), size: BigInt.zero);
      expect(usage.usedPercent, 0); // Should return 0 instead of throwing
    });

    test('DiskUsage handles null kname', () {
      final disks = [
        Disk(
          path: '/dev/sda1',
          mount: '/mnt',
          usedPercent: 50,
          used: BigInt.from(5000),
          size: BigInt.from(10000),
          avail: BigInt.from(5000),
          kname: null, // Explicitly null kname
        ),
      ];

      final usage = DiskUsage.parse(disks);
      expect(usage.used, BigInt.from(5000));
      expect(usage.size, BigInt.from(10000));
      expect(usage.usedPercent, 50);
      // This would use the "unknown" fallback for kname
    });

  });
}
