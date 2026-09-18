// ignore_for_file: avoid_print

import 'package:flutter_test/flutter_test.dart';
import 'package:server_box/data/model/server/disk.dart';
import 'package:server_box/data/model/server/system.dart';

// Parsing tests migrated to crates/sbm_parser/tests/dart_compat.rs
void main() {
  group('DiskIO', () {
    DiskIOPiece piece(String dev, int read, int write, int time) =>
        DiskIOPiece(
          dev: dev,
          sectorsRead: read,
          sectorsWrite: write,
          time: time,
        );

    test('Windows aggregates logical drives after the second sample', () {
      final io = DiskIO();
      io.updateForSystem(
        [piece('C:', 100, 200, 10), piece('D:', 300, 400, 10)],
        SystemType.windows,
      );
      expect(io.allSpeedBytes, (null, null));

      io.updateForSystem(
        [piece('C:', 104, 206, 12), piece('D:', 310, 408, 12)],
        SystemType.windows,
      );

      expect(io.speedBytes('C:'), (1024.0, 1536.0));
      expect(io.allSpeedBytes, (3584.0, 3584.0));
    });

    test('Linux aggregate still excludes virtual block devices', () {
      final io = DiskIO();
      io.updateForSystem(
        [piece('sda', 10, 20, 1), piece('loop0', 1000, 2000, 1)],
        SystemType.linux,
      );
      io.updateForSystem(
        [piece('sda', 12, 24, 2), piece('loop0', 2000, 4000, 2)],
        SystemType.linux,
      );

      expect(io.allSpeedBytes, (1024.0, 2048.0));
    });

    /// `/proc/diskstats` has a row for the disk and one for each of its
    /// partitions, and they count the same bytes. Summing all of them reported
    /// a machine as writing twice what it wrote.
    test('Linux aggregate counts a disk once, not once per partition', () {
      final io = DiskIO();
      const names = ['sda', 'sda1', 'sda2', 'nvme0n1', 'nvme0n1p1'];
      io.updateForSystem([
        for (final name in names) piece(name, 10, 20, 1),
      ], SystemType.linux);
      io.updateForSystem([
        for (final name in names) piece(name, 12, 24, 2),
      ], SystemType.linux);

      expect(io.devices, ['sda', 'nvme0n1']);
      expect(io.allSpeedBytes, (2048.0, 4096.0));
    });

    test('a partition whose whole disk is absent is the only row it has', () {
      final io = DiskIO();
      io.updateForSystem([piece('vda1', 10, 20, 1)], SystemType.linux);
      io.updateForSystem([piece('vda1', 12, 24, 2)], SystemType.linux);

      expect(io.devices, ['vda1']);
      expect(io.allSpeedBytes, (1024.0, 2048.0));
    });

    test('a Windows drive letter is never read as a partition', () {
      final io = DiskIO();
      io.updateForSystem(
        [piece('C:', 100, 200, 10), piece('D:', 300, 400, 10)],
        SystemType.windows,
      );

      expect(io.devices, ['C:', 'D:']);
    });
  });

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

    test('DiskUsage keeps storage named like a virtual filesystem', () {
      // A source carries user-chosen text. Excluding the virtual filesystems
      // by prefix took every one of these with them.
      Disk storage(String path, String mount) => Disk(
        path: path,
        mount: mount,
        usedPercent: 2,
        used: BigInt.from(12345678),
        size: BigInt.from(961873408),
        avail: BigInt.from(949527730),
      );

      final disks = [
        storage('tmpfspool/data', '/srv/pool'),
        storage('shm-nas:/vol1', '/srv/nfs'),
        storage('overlay-01:/export', '/srv/export'),
        storage('devtmpfs-backup:/snapshots', '/srv/backup'),
      ];
      for (final disk in disks) {
        expect(disk.isStorage, isTrue, reason: disk.path);
      }

      final usage = DiskUsage.parse(disks);
      expect(usage.size, BigInt.from(961873408) * BigInt.from(4));
    });

    test('DiskUsage keeps sources named like filesystem types', () {
      Disk storage(String path) => Disk(
        path: path,
        mount: '/srv/$path',
        usedPercent: 2,
        used: BigInt.from(12345678),
        size: BigInt.from(961873408),
        avail: BigInt.from(949527730),
      );

      final disks = const [
        'squashfs',
        'erofs',
        'iso9660',
        'snapfuse',
        'fuse.snapfuse',
        'swap',
      ].map(storage).toList();
      for (final disk in disks) {
        expect(disk.isStorage, isTrue, reason: disk.path);
      }

      final usage = DiskUsage.parse(disks);
      expect(usage.size, BigInt.from(961873408) * BigInt.from(disks.length));
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
