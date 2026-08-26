import 'dart:io';

import 'package:archive/archive.dart';
import 'package:fl_lib/fl_lib.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:server_box/core/utils/android_rootfs.dart';
import 'package:server_box/core/utils/ios_rootfs.dart';
import 'package:server_box/core/utils/linux_seed.dart';
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
    'an iOS layer cannot write through a symlink from an earlier layer',
    () async {
      final links = Archive()..add(ArchiveFile.symlink('escape', outside.path));
      await IosRootfs.extractForTest(
        await archiveOf('links', links),
        root,
        source: source,
      );

      final payload = Archive()
        ..add(ArchiveFile.string('escape/payload', 'outside'));
      await expectLater(
        IosRootfs.extractForTest(
          await archiveOf('payload', payload),
          root,
          source: source,
        ),
        throwsA(isA<StateError>()),
      );
      expect(File('${outside.path}/payload').existsSync(), isFalse);
    },
  );

  test('an iOS layer rejects a file below its own symlink', () async {
    final archive = Archive()
      ..add(ArchiveFile.symlink('escape', outside.path))
      ..add(ArchiveFile.string('escape/payload', 'inside only'));

    await expectLater(
      IosRootfs.extractForTest(
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

  test('an iOS layer rejects traversal instead of skipping it', () async {
    final archive = Archive()
      ..add(ArchiveFile.string('../outside/payload', 'outside'));

    await expectLater(
      IosRootfs.extractForTest(
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

    await IosRootfs.extractForTest(
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

  test(
    'Android validation rejects traversal and symlink-parent writes',
    () async {
      final traversal = Archive()
        ..add(ArchiveFile.string('../outside/payload', 'bad'));
      final traversalFile = File('${temp.path}/traversal.tar')
        ..writeAsBytesSync(TarEncoder().encodeBytes(traversal));
      await expectLater(
        AndroidRootfs.validateTarForTest(traversalFile, root),
        throwsA(isA<StateError>()),
      );

      await Link('${root.path}/escape').create(outside.path);
      final throughLink = Archive()
        ..add(ArchiveFile.string('escape/payload', 'bad'));
      final linkFile = File('${temp.path}/link-parent.tar')
        ..writeAsBytesSync(TarEncoder().encodeBytes(throughLink));
      await expectLater(
        AndroidRootfs.validateTarForTest(linkFile, root),
        throwsA(isA<StateError>()),
      );
      expect(File('${outside.path}/payload').existsSync(), isFalse);
    },
  );

  test('Android validates gzip tar metadata without a temporary tar', () async {
    final traversal = Archive()
      ..add(ArchiveFile.string('../outside/payload', 'bad'));
    final archive = await archiveOf('android-gzip-traversal', traversal);

    await expectLater(
      AndroidRootfs.validateGzipTarForTest(archive, root),
      throwsA(isA<StateError>()),
    );
    expect(File('${archive.path}.validated.tar').existsSync(), isFalse);
  });
}
