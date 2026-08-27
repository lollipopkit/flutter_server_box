import 'dart:io';

import 'package:archive/archive.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:server_box/core/utils/ios_rootfs.dart';
import 'package:server_box/data/model/app/linux_distro.dart';
import 'package:server_box/data/model/app/rootfs_manifest.dart';

/// What mode a directory lands with, which is two requirements at once.
///
/// `realfs` hands the host's mode straight to the guest, and the host process
/// is this app rather than root — so uid 0 in the guest buys nothing, and a
/// directory the archive ships at 0555 is one a package manager cannot create
/// its temp files in. Rocky ships 17 of those. Owner rwx therefore has to be
/// forced on whatever the archive says.
///
/// The other requirement is everything else the mode carries. `/tmp` is 1777
/// in every distribution, and a rootfs whose directory modes are all 0755 is
/// one `rpm --verify` and `dpkg --verify` report as altered — the same
/// complaint stripping locales would cause, and the reason `shellbox-rootfs`
/// does not strip them.
void main() {
  late Directory dir;

  setUp(() async {
    dir = await Directory.systemTemp.createTemp('sbm-modes-');
  });

  tearDown(() async {
    if (await dir.exists()) await dir.delete(recursive: true);
  });

  const source = RootfsSource(
    url: 'https://example.test/rootfs.tar.gz',
    sha256: '0000000000000000000000000000000000000000000000000000000000000000',
    sizeBytes: 1,
    layout: LinuxRootfsLayout.plain,
    compression: LinuxRootfsCompression.gzip,
    followsMirror: false,
  );

  /// Unpacks a plain rootfs of directories at the modes given.
  Future<Directory> unpack(Map<String, int> directories) async {
    final archive = Archive();
    for (final entry in directories.entries) {
      archive.add(ArchiveFile.directory(entry.key)..mode = entry.value);
    }
    // A file inside one of them, so the tree is not only directories.
    archive.add(ArchiveFile.string('etc/hostname', 'box')..mode = 0x1a4);

    final file = File('${dir.path}/rootfs.tar.gz');
    await file.writeAsBytes(
      GZipEncoder().encodeBytes(TarEncoder().encodeBytes(archive)),
    );

    final into = Directory('${dir.path}/root')..createSync(recursive: true);
    await IosRootfs.extract(file, into, source: source);
    return into;
  }

  int modeOf(Directory into, String path) =>
      Directory('${into.path}/$path').statSync().mode & 0xfff;

  test('a directory the archive ships read-only becomes writable', () {
    // The failure this whole rule exists for: `rpm` reports it as
    // `cpio: open failed`, which reads as a broken download.
    return unpack({'usr': 0x1ed, 'usr/bin': 0x16d}).then((into) {
      expect(modeOf(into, 'usr/bin') & 0x1c0, 0x1c0, reason: 'owner rwx');
      // And nothing else was added: 0555 becomes 0755, not 0777.
      expect(modeOf(into, 'usr/bin'), 0x1ed);
    });
  }, skip: Platform.isWindows ? 'requires POSIX file modes' : null);

  test('and keeps the bits that were not in the way', () async {
    // 1777 for /tmp, 2755 for a setgid directory. Neither stops this app
    // writing there, so neither is something to drop — and both are what a
    // package manager's --verify compares against.
    final into = await unpack({
      'tmp': 0x3ff, // 1777
      'var': 0x1ed,
      'var/log': 0x5ed, // 2755
    });

    expect(modeOf(into, 'tmp') & 0x200, 0x200, reason: 'sticky');
    expect(modeOf(into, 'tmp') & 0x1ff, 0x1ff, reason: '777');
    expect(modeOf(into, 'var/log') & 0x400, 0x400, reason: 'setgid');
  }, skip: Platform.isWindows ? 'requires POSIX file modes' : null);

  test('an ordinary directory is left exactly as the archive had it', () async {
    final into = await unpack({'etc': 0x1ed});

    expect(modeOf(into, 'etc'), 0x1ed);
  }, skip: Platform.isWindows ? 'requires POSIX file modes' : null);

  test('a directory only named as a parent is still usable', () async {
    // `usr/lib/x` with no entry of its own for `usr/lib`, which is what
    // `create(recursive: true)` fills in. It gets the host default rather than
    // an archive mode, and the requirement is only that things can be written
    // into it.
    final into = await unpack({'usr/lib/x': 0x1ed});

    expect(modeOf(into, 'usr/lib') & 0x1c0, 0x1c0, reason: 'owner rwx');
  }, skip: Platform.isWindows ? 'requires POSIX file modes' : null);
}
