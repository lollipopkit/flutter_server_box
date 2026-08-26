import 'dart:io';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:fl_lib/fl_lib.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:server_box/core/utils/ios_rootfs.dart';
import 'package:server_box/core/utils/linux_seed.dart';
import 'package:server_box/data/model/app/linux_distro.dart';
import 'package:server_box/data/model/app/linux_distros.dart';
import 'package:server_box/data/model/app/rootfs_manifest.dart';

/// Hard links in a rootfs tarball.
///
/// The tar reader hands a hard link and a symbolic link to its caller in the
/// same shape: it fills `symbolicLink` from the header's link name for both,
/// because both carry one. Only the type flag separates them, and that lives
/// on the decoder's entries rather than on the archive it builds.
///
/// Read as symbolic, a hard link points nowhere. Its target is a path from the
/// root of the archive; a symbolic link's resolves relative to its own
/// directory. Ubuntu 26.04 ships uutils coreutils as one 10 MB binary with 115
/// hard links to it, so `/usr/bin/ls` — itself a symlink into that directory —
/// ended at a link to nothing, and the shell answered `ls: not found` in a
/// system that had `ls`. Alpine never showed it: busybox uses symbolic links
/// for its applets.
///
/// Android is unaffected and has no equivalent test: it hands the archive to
/// the system `tar`, which has always known the difference.
void main() {
  const source = RootfsSource(
    url: 'https://example.test/rootfs.tar.gz',
    sha256: '',
    sizeBytes: 1,
    layout: LinuxRootfsLayout.plain,
    compression: LinuxRootfsCompression.gzip,
    followsMirror: false,
  );

  TarFile linkEntry(String name, String type, String target) => TarFile()
    ..filename = name
    ..mode = 0x1ed
    ..lastModTime = 0
    ..typeFlag = type
    ..nameOfLinkedFile = target
    ..fileSize = 0;

  Future<File> archiveFile(Directory temp, List<TarFile> entries) async {
    final out = OutputMemoryStream();
    for (final entry in entries) {
      entry.write(out);
    }
    out.writeBytes(Uint8List(1024));
    out.flush();
    final archive = File('${temp.path}/rootfs.tar.gz');
    await archive.writeAsBytes(GZipEncoder().encodeBytes(out.getBytes()));
    return archive;
  }

  test('a hard link is not the same shape as a symbolic one', () {
    // The distinction this rests on, asserted against the reader rather than
    // assumed. If a future version of `archive` stopped setting
    // `nameOfLinkedFile` for hard links, the unpacker's special case would be
    // dead code — and if it stopped exposing the type flag, the special case
    // could not be written at all.
    //
    // Written entry by entry because `TarEncoder` cannot emit a hard link: it
    // knows directories, symbolic links and files, so encoding one through it
    // would produce a symbolic link and this test would be asserting the
    // failure it exists to catch.
    TarFile entry(String name, String type, {String? target}) => TarFile()
      ..filename = name
      ..mode = 0x1ed
      ..lastModTime = 0
      ..typeFlag = type
      ..nameOfLinkedFile = target
      ..fileSize = 0;

    final out = OutputMemoryStream();
    entry('usr/bin/coreutils', TarFile.normalFile).write(out);
    entry(
      'usr/bin/ls',
      TarFile.hardLink,
      target: 'usr/bin/coreutils',
    ).write(out);
    entry('bin', TarFile.symbolicLink, target: 'usr/bin').write(out);
    out.writeBytes(Uint8List(1024)); // the two empty blocks that end a tar
    out.flush();

    final decoder = TarDecoder();
    decoder.decodeBytes(out.getBytes());
    final byName = {for (final f in decoder.files) f.filename: f};

    expect(byName['usr/bin/coreutils']!.typeFlag, TarFile.normalFile);
    // The two link shapes, told apart by the flag and by nothing else: both
    // carry a link name, which is why reading one as the other was possible.
    // A hard link's target is a path from the root of the archive; a symbolic
    // link's resolves against its own directory.
    expect(byName['usr/bin/ls']!.typeFlag, TarFile.hardLink);
    expect(byName['usr/bin/ls']!.nameOfLinkedFile, 'usr/bin/coreutils');
    expect(byName['bin']!.typeFlag, TarFile.symbolicLink);
    expect(byName['bin']!.nameOfLinkedFile, 'usr/bin');
  });

  test('a hard link to a pending symlink preserves the symlink', () async {
    TarFile entry(String name, String type, {String? target}) => TarFile()
      ..filename = name
      ..mode = 0x1ed
      ..lastModTime = 0
      ..typeFlag = type
      ..nameOfLinkedFile = target
      ..fileSize = 0;

    final out = OutputMemoryStream();
    entry(
      'usr/lib/tool',
      TarFile.symbolicLink,
      target: '../bin/tool',
    ).write(out);
    entry('usr/bin/tool', TarFile.hardLink, target: 'usr/lib/tool').write(out);
    out.writeBytes(Uint8List(1024));
    out.flush();

    final temp = await Directory.systemTemp.createTemp('rootfs-link-link-');
    addTearDown(() => temp.delete(recursive: true));
    final archive = File('${temp.path}/rootfs.tar.gz');
    await archive.writeAsBytes(GZipEncoder().encodeBytes(out.getBytes()));
    final root = Directory('${temp.path}/root')..createSync();
    await IosRootfs.extractForTest(
      archive,
      root,
      source: const RootfsSource(
        url: 'https://example.test/rootfs.tar.gz',
        sha256: '',
        sizeBytes: 1,
        layout: LinuxRootfsLayout.plain,
        compression: LinuxRootfsCompression.gzip,
        followsMirror: false,
      ),
    );

    expect(await Link('${root.path}/usr/lib/tool').target(), '../bin/tool');
    expect(await Link('${root.path}/usr/bin/tool').target(), '../bin/tool');
  });

  test('an iOS layer rejects an unsafe hard-link target', () async {
    final entry = TarFile()
      ..filename = 'usr/bin/tool'
      ..mode = 0x1ed
      ..lastModTime = 0
      ..typeFlag = TarFile.hardLink
      ..nameOfLinkedFile = '../outside/tool'
      ..fileSize = 0;
    final out = OutputMemoryStream();
    entry.write(out);
    out.writeBytes(Uint8List(1024));
    out.flush();

    final temp = await Directory.systemTemp.createTemp('rootfs-unsafe-link-');
    addTearDown(() => temp.delete(recursive: true));
    final archive = File('${temp.path}/rootfs.tar.gz');
    await archive.writeAsBytes(GZipEncoder().encodeBytes(out.getBytes()));
    final root = Directory('${temp.path}/root')..createSync();

    await expectLater(
      IosRootfs.extractForTest(
        archive,
        root,
        source: const RootfsSource(
          url: 'https://example.test/rootfs.tar.gz',
          sha256: '',
          sizeBytes: 1,
          layout: LinuxRootfsLayout.plain,
          compression: LinuxRootfsCompression.gzip,
          followsMirror: false,
        ),
      ),
      throwsA(
        isA<StateError>().having(
          (error) => error.message,
          'message',
          allOf(
            contains(libL10n.invalid),
            contains(libL10n.path),
            contains('../outside/tool'),
          ),
        ),
      ),
    );
    expect(File('${temp.path}/outside/tool').existsSync(), isFalse);
  });

  test('an iOS layer localizes a hard-link target below a symlink', () async {
    final temp = await Directory.systemTemp.createTemp('rootfs-link-parent-');
    addTearDown(() => temp.delete(recursive: true));

    await expectLater(
      IosRootfs.extractForTest(
        await archiveFile(temp, [
          linkEntry('usr/link', TarFile.symbolicLink, 'bin'),
          linkEntry('usr/bin/tool', TarFile.hardLink, 'usr/link/tool'),
        ]),
        Directory('${temp.path}/root')..createSync(),
        source: source,
      ),
      throwsA(
        isA<StateError>().having(
          (error) => error.message,
          'message',
          allOf(
            contains(libL10n.invalid),
            contains(libL10n.path),
            contains('usr/link/tool'),
          ),
        ),
      ),
    );
  });

  test('an iOS layer localizes a non-file hard-link target', () async {
    final temp = await Directory.systemTemp.createTemp('rootfs-missing-link-');
    addTearDown(() => temp.delete(recursive: true));

    await expectLater(
      IosRootfs.extractForTest(
        await archiveFile(temp, [
          linkEntry('usr/bin/tool', TarFile.hardLink, 'usr/bin/missing'),
        ]),
        Directory('${temp.path}/root')..createSync(),
        source: source,
      ),
      throwsA(
        isA<StateError>().having(
          (error) => error.message,
          'message',
          allOf(
            contains(libL10n.invalid),
            contains(libL10n.file),
            contains('usr/bin/missing'),
          ),
        ),
      ),
    );
  });

  group('the real Ubuntu rootfs', () {
    // Skipped rather than failed when absent: this needs a 32 MB download that
    // a checkout does not carry. Fetch it with the URL in
    // assets/rootfs_manifest.json.
    final tarball = File('build/test_fixtures/ubuntu-26.04-arm64.tar.gz');

    test('names its coreutils applets as hard links', () {
      if (!tarball.existsSync()) {
        markTestSkipped('no ${tarball.path}');
        return;
      }

      final decoder = TarDecoder();
      decoder.decodeBytes(GZipDecoder().decodeBytes(tarball.readAsBytesSync()));

      final hard = decoder.files
          .where((f) => f.typeFlag == TarFile.hardLink)
          .toList();

      // 115 of them at the time of writing, all pointing at one binary. The
      // assertion is that there are many and that they name a path from the
      // archive root — which is what makes reading them as symbolic wrong.
      expect(hard, hasLength(greaterThan(50)));
      final ls = hard.firstWhere(
        (f) => f.filename.endsWith('/coreutils/ls'),
        orElse: () => throw StateError('no hard-linked ls'),
      );
      expect(ls.nameOfLinkedFile, contains('usr/bin/coreutils'));
      // Read as a symbolic link, this resolves inside the applet directory
      // rather than at the root — which is exactly the failure.
      expect(ls.nameOfLinkedFile, isNot(startsWith('../')));
    });
  });

  group('unpacking the real Ubuntu rootfs', () {
    final tarball = File('build/test_fixtures/ubuntu-26.04-arm64.tar.gz');
    late Directory into;

    setUp(() async {
      into = await Directory.systemTemp.createTemp('rootfs_unpack_test');
    });

    /// Both tests below need the same three things, and neither is about any
    /// of them: the tarball being present, a manifest being in force, and the
    /// unpack having happened. Returns the directory it landed in, or null
    /// when there is nothing to unpack.
    Future<Directory?> unpacked(Directory into) async {
      if (!tarball.existsSync()) {
        markTestSkipped('no ${tarball.path}');
        return null;
      }
      LinuxDistros.adoptForTest(
        RootfsManifest.parse(
          File(LinuxDistros.bundledAsset).readAsStringSync(),
        ),
      );
      await IosRootfs.extractForTest(
        tarball,
        into,
        source: LinuxDistro.ubuntu.preferred.source,
      );
      return into;
    }

    tearDown(() async {
      if (await into.exists()) await into.delete(recursive: true);
    });

    test('leaves a coreutils applet that resolves to a real binary', () async {
      if (await unpacked(into) == null) return;

      // What the shell walks to run `ls`, one hop at a time. Each is a
      // separate way for the unpack to have gone wrong.
      final usrBinLs = Link('${into.path}/usr/bin/ls');
      expect(usrBinLs.existsSync(), isTrue, reason: '/usr/bin/ls is a symlink');
      expect(usrBinLs.targetSync(), '../lib/cargo/bin/coreutils/ls');

      final applet = File('${into.path}/usr/lib/cargo/bin/coreutils/ls');
      // The failure this test exists for: read as symbolic, the hard link
      // pointed at usr/bin/coreutils *inside the applet directory*, so this
      // was a dangling link rather than a file.
      expect(
        Link(applet.path).existsSync(),
        isFalse,
        reason: 'the applet must be a file, not a link to one',
      );
      expect(applet.existsSync(), isTrue);
      expect(await applet.length(), greaterThan(1000000));

      // And it is the same file as the binary it was linked to, rather than a
      // copy — 115 copies of 10 MB is a gigabyte.
      final multicall = File('${into.path}/usr/bin/coreutils');
      expect(multicall.existsSync(), isTrue);
      expect(applet.statSync().size, multicall.statSync().size);

      // Executable, or the shell finds it and still cannot run it.
      expect(applet.statSync().mode & 0x40, isNot(0), reason: 'owner execute');
    });

    test('every hard link in the archive landed as a file', () async {
      if (await unpacked(into) == null) return;

      final decoder = TarDecoder();
      decoder.decodeBytes(GZipDecoder().decodeBytes(tarball.readAsBytesSync()));
      final hard = decoder.files.where((f) => f.typeFlag == TarFile.hardLink);

      final missing = <String>[];
      for (final entry in hard) {
        final name = entry.filename.startsWith('./')
            ? entry.filename.substring(2)
            : entry.filename;
        final path = '${into.path}/$name';
        if (!File(path).existsSync() || Link(path).existsSync()) {
          missing.add(name);
        }
      }
      // Named rather than counted: which ones are wrong says what went wrong.
      expect(missing, isEmpty);
    });
  });

  group('linkGuestFile', () {
    late Directory dir;

    setUp(() async {
      dir = await Directory.systemTemp.createTemp('rootfs_hardlink_test');
    });

    tearDown(() async {
      if (await dir.exists()) await dir.delete(recursive: true);
    });

    test('makes a second name for one file, not a copy', () async {
      final target = File('${dir.path}/binary')..writeAsStringSync('multicall');
      final path = '${dir.path}/applet';

      expect(linkGuestFile(target.path, path), isTrue);

      final applet = File(path);
      expect(applet.existsSync(), isTrue);
      expect(applet.readAsStringSync(), 'multicall');
      // A link, not a symlink: nothing to resolve, so nothing to resolve
      // wrongly. This is the whole reason it is worth an FFI call.
      expect(Link(path).existsSync(), isFalse);
      expect(applet.statSync().type, FileSystemEntityType.file);

      // One file under two names: writing through one is visible through the
      // other, which a copy would not be.
      target.writeAsStringSync('changed');
      expect(applet.readAsStringSync(), 'changed');
    }, skip: Platform.isWindows);

    test('answers false rather than throwing when it cannot', () async {
      // The caller has a fallback and a system missing `ls` is worse than one
      // whose `ls` is a symlink, so this must not throw.
      expect(
        linkGuestFile('${dir.path}/nothing-here', '${dir.path}/applet'),
        isFalse,
      );
    });
  });
}
