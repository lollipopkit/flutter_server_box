// ignore_for_file: avoid_print

import 'package:flutter_test/flutter_test.dart';
import 'package:server_box/data/model/server/disk.dart';

// Parsing tests migrated to crates/sbm_parser/tests/dart_compat.rs
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

    // The parser drops all of these; a Disk that reached the app another way —
    // a monitor agent older than the rule — must not reach the total either
    Disk full(String path, String fsTyp, String mount, int size) => Disk(
      path: path,
      fsTyp: fsTyp,
      mount: mount,
      usedPercent: 100,
      used: BigInt.from(size),
      size: BigInt.from(size),
      avail: BigInt.zero,
    );

    final root = Disk(
      path: '/dev/vda1',
      fsTyp: 'ext4',
      mount: '/',
      usedPercent: 25,
      used: BigInt.from(12057216),
      size: BigInt.from(51343636),
      avail: BigInt.from(36648004),
    );

    void expectOnlyRoot(List<Disk> disks) {
      final usage = DiskUsage.parse([root, ...disks]);
      expect(usage.used, BigInt.from(12057216));
      expect(usage.size, BigInt.from(51343636));
    }

    test('DiskUsage skips read-only images', () {
      expectOnlyRoot([
        full('/dev/loop0', 'squashfs', '/snap/copilot-cli/57', 296960),
        full('snapfuse', 'fuse.snapfuse', '/snap/lxd/31333', 129024),
        full('/dev/loop6', '', '/var/lib/snapd/snap/core24/1587', 66944),
        full('/dev/sr0', 'iso9660', '/media/cdrom', 4718592),
      ]);
    });

    test('DiskUsage skips swap areas', () {
      expectOnlyRoot([
        full('/dev/vda2', 'swap', '[SWAP]', 0),
        full('/dev/zram0', 'swap', '[SWAP]', 0),
      ]);
    });

    test('DiskUsage skips container layers', () {
      expectOnlyRoot([
        full('overlay', '', '/var/lib/docker/overlay2/9c1f/merged', 51343636),
        full(
          'fuse-overlayfs',
          '',
          '/home/u/.local/share/containers/storage/overlay/7a2e/merged',
          51343636,
        ),
      ]);
    });

    test('DiskUsage keeps a loop device carrying a writable filesystem', () {
      final usage = DiskUsage.parse([
        Disk(
          path: '/dev/loop7',
          fsTyp: 'ext4',
          mount: '/mnt/image',
          usedPercent: 50,
          used: BigInt.from(515072),
          size: BigInt.from(1032256),
          avail: BigInt.from(517184),
        ),
      ]);

      expect(usage.used, BigInt.from(515072));
      expect(usage.size, BigInt.from(1032256));
    });
  });
}
