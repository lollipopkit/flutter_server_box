import 'dart:io';

import 'package:archive/archive.dart';
import 'package:fl_lib/fl_lib.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:server_box/core/utils/linux_seed.dart';
import 'package:server_box/core/utils/rootfs_unpack.dart';
import 'package:server_box/data/model/app/linux_distro.dart';
import 'package:server_box/data/model/app/rootfs_manifest.dart';

void main() {
  const source = RootfsSource(
    url: 'https://example.test/rootfs.tar.gz',
    sha256: '',
    sizeBytes: 1,
    layout: LinuxRootfsLayout.plain,
    compression: LinuxRootfsCompression.gzip,
    followsMirror: false,
  );

  late Directory temp;
  late Directory root;
  late Directory outside;

  setUp(() async {
    temp = await Directory.systemTemp.createTemp('rootfs-tar-safety-');
    root = Directory('${temp.path}/root')..createSync();
    outside = Directory('${temp.path}/outside')..createSync();
  });

  tearDown(() async {
    if (await temp.exists()) await temp.delete(recursive: true);
  });

  Future<File> archiveOf(String name, Archive archive) async {
    final plain = TarEncoder().encodeBytes(archive);
    final file = File('${temp.path}/$name.tar.gz');
    await file.writeAsBytes(GZipEncoder().encodeBytes(plain));
    return file;
  }

  test(
    'a layer cannot write through a symlink from an earlier layer',
    () async {
      final links = Archive()..add(ArchiveFile.symlink('escape', outside.path));
      await RootfsUnpack.extract(
        await archiveOf('links', links),
        root,
        source: source,
      );

      final payload = Archive()
        ..add(ArchiveFile.string('escape/payload', 'outside'));
      await expectLater(
        RootfsUnpack.extract(
          await archiveOf('payload', payload),
          root,
          source: source,
        ),
        throwsA(isA<StateError>()),
      );
      expect(File('${outside.path}/payload').existsSync(), isFalse);
    },
  );

  test('a layer rejects a file below its own symlink', () async {
    final archive = Archive()
      ..add(ArchiveFile.symlink('escape', outside.path))
      ..add(ArchiveFile.string('escape/payload', 'inside only'));

    await expectLater(
      RootfsUnpack.extract(
        await archiveOf('same-layer', archive),
        root,
        source: source,
      ),
      throwsA(
        isA<StateError>().having(
          (error) => error.message,
          'message',
          allOf(
            contains(libL10n.invalid),
            contains(libL10n.path),
            contains('escape/payload'),
          ),
        ),
      ),
    );

    expect(File('${outside.path}/payload').existsSync(), isFalse);
  });

  test('a layer rejects traversal instead of skipping it', () async {
    final archive = Archive()
      ..add(ArchiveFile.string('../outside/payload', 'outside'));

    await expectLater(
      RootfsUnpack.extract(
        await archiveOf('traversal', archive),
        root,
        source: source,
      ),
      throwsA(
        isA<StateError>().having(
          (error) => error.message,
          'message',
          allOf(
            contains(libL10n.invalid),
            contains(libL10n.path),
            contains('../outside/payload'),
          ),
        ),
      ),
    );

    expect(File('${outside.path}/payload').existsSync(), isFalse);
  });

  test('post-install seeds refuse a final symlink outside the root', () async {
    final outsideFile = File('${outside.path}/resolv.conf')
      ..writeAsStringSync('outside');
    final archive = Archive()
      ..add(ArchiveFile.symlink('etc/resolv.conf', outsideFile.path));

    await RootfsUnpack.extract(
      await archiveOf('final-link', archive),
      root,
      source: source,
    );
    await expectLater(
      seedResolvConf(
        root.path,
        nameservers: const ['1.1.1.1'],
        overwrite: true,
      ),
      throwsA(
        isA<StateError>().having(
          (error) => error.message,
          'message',
          allOf(contains(libL10n.invalid), contains(libL10n.path)),
        ),
      ),
    );

    expect(await outsideFile.readAsString(), 'outside');
  });

  test('post-install seeds localize an unresolved final symlink', () async {
    await Directory('${root.path}/etc').create();
    await Link('${root.path}/etc/resolv.conf').create('../missing/resolv.conf');

    await expectLater(
      seedResolvConf(
        root.path,
        nameservers: const ['1.1.1.1'],
        overwrite: true,
      ),
      throwsA(
        isA<StateError>().having(
          (error) => error.message,
          'message',
          allOf(contains(libL10n.fail), contains(libL10n.path)),
        ),
      ),
    );
  });

  test('a read-only directory is still filled', () async {
    // Rocky's `ca-trust/extracted/pem/directory-hash/` is `0555` and holds
    // symlinks: written with its recorded mode before its contents, nothing
    // could be put in it (#1697).
    final readOnly = Archive()
      ..add(ArchiveFile.directory('ro')..mode = 0x16d) // 0555
      ..add(ArchiveFile.symlink('ro/hash.0', 'cert.pem'))
      ..add(ArchiveFile.string('ro/cert.pem', 'pem'));
    await RootfsUnpack.extract(
      await archiveOf('read-only', readOnly),
      root,
      source: source,
    );

    expect(await Link('${root.path}/ro/hash.0').target(), 'cert.pem');
    expect(File('${root.path}/ro/cert.pem').readAsStringSync(), 'pem');
  });
}
