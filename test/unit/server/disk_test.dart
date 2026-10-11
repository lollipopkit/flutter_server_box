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
    Disk apfs(String path, String mount, int used, {String? fs = 'apfs'}) =>
        Disk(
      path: path,
      fsTyp: fs,
      mount: mount,
      usedPercent: 0,
      used: BigInt.from(used),
      size: BigInt.from(1000),
      avail: BigInt.from(50),
    );

    test('macOS system volumes and images are not storage', () {
      for (final mount in [
        '/System/Volumes/VM',
        '/System/Volumes/Preboot',
        '/Volumes/Recovery',
        '/private/var/run/com.apple.security.cryptexd/mnt/x',
        '/private/var/folders/xx/yy/X/APPID',
      ]) {
        expect(apfs('/dev/disk3s2', mount, 1).isStorage, isFalse, reason: mount);
      }
      expect(apfs('/dev/disk3s5', '/System/Volumes/Data', 1).isStorage, isTrue);
      expect(apfs('/dev/disk3s1s1', '/', 1).isStorage, isTrue);
    });

    test('DiskUsage handles zero size correctly', () {
      final usage = DiskUsage(used: BigInt.from(1000), size: BigInt.zero);
      expect(usage.usedPercent, 0); // Should return 0 instead of throwing
    });

    // The parser drops all of these; a Disk that reached the app another way —
    // a monitor agent older than the rule — is dropped by the same rule
    Disk full(String path, String fsTyp, String mount, int size) => Disk(
      path: path,
      fsTyp: fsTyp,
      mount: mount,
      usedPercent: 100,
      used: BigInt.from(size),
      size: BigInt.from(size),
      avail: BigInt.zero,
    );

    void expectNoneStorage(List<Disk> disks) {
      for (final disk in disks) {
        expect(disk.isStorage, isFalse, reason: disk.path);
      }
    }

    test('isStorage drops read-only images', () {
      expectNoneStorage([
        full('/dev/loop0', 'squashfs', '/snap/copilot-cli/57', 296960),
        full('snapfuse', 'fuse.snapfuse', '/snap/lxd/31333', 129024),
        full('/dev/loop6', '', '/var/lib/snapd/snap/core24/1587', 66944),
        full('/dev/sr0', 'iso9660', '/media/cdrom', 4718592),
      ]);
    });

    test('isStorage drops swap areas', () {
      expectNoneStorage([
        full('/dev/vda2', 'swap', '[SWAP]', 0),
        full('/dev/zram0', 'swap', '[SWAP]', 0),
      ]);
    });

    test('isStorage drops container layers', () {
      expectNoneStorage([
        full('overlay', '', '/var/lib/docker/overlay2/9c1f/merged', 51343636),
        full(
          'fuse-overlayfs',
          '',
          '/home/u/.local/share/containers/storage/overlay/7a2e/merged',
          51343636,
        ),
      ]);
    });

    test('isStorage keeps storage named like a virtual filesystem', () {
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
    });

    test('isStorage keeps sources named like filesystem types', () {
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
    });

    test('isStorage keeps a loop device carrying a writable filesystem', () {
      expect(
        Disk(
          path: '/dev/loop7',
          fsTyp: 'ext4',
          mount: '/mnt/image',
          usedPercent: 50,
          used: BigInt.from(515072),
          size: BigInt.from(1032256),
          avail: BigInt.from(517184),
        ).isStorage,
        isTrue,
      );
    });
  });
}
