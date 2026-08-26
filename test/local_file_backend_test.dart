import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:server_box/core/utils/local_file_backend.dart';
import 'package:server_box/data/model/file/file_backend.dart';

void main() {
  late Directory root;
  const backend = LocalFileBackend();

  String at(String name) => '${root.path}/$name';

  setUp(() async {
    root = await Directory.systemTemp.createTemp('sb-local-files-');
  });

  tearDown(() async {
    if (await root.exists()) await root.delete(recursive: true);
  });

  group('listing', () {
    test('reports a file, a directory and a link as themselves', () async {
      await File(at('a.txt')).writeAsString('hello');
      await Directory(at('sub')).create();
      await Link(at('l')).create(at('a.txt'));

      final entries = await backend.list(root.path);
      final byName = {for (final e in entries) e.name: e};

      expect(byName.keys, unorderedEquals(['a.txt', 'sub', 'l']));
      expect(byName['a.txt']!.kind, FileKind.file);
      expect(byName['a.txt']!.size, 5);
      expect(byName['sub']!.kind, FileKind.dir);
      // A directory's size is whatever the OS says its inode weighs, which is
      // not a number anybody wants shown beside a folder.
      expect(byName['sub']!.size, isNull);
      expect(byName['l']!.kind, FileKind.link);
      expect(byName['l']!.linkTarget, at('a.txt').replaceAll(r'\', '/'));
    });

    test('a link to nowhere is still listed', () async {
      await Link(at('dangling')).create(at('gone'));

      final entries = await backend.list(root.path);

      expect(entries.single.kind, FileKind.link);
    });
  });

  group('stat', () {
    test('is null for something that is not there', () async {
      expect(await backend.stat(at('missing')), isNull);
    });

    test('reports a file it can see', () async {
      await File(at('a.txt')).writeAsString('hello');

      final entry = await backend.stat(at('a.txt'));

      expect(entry!.name, 'a.txt');
      expect(entry.kind, FileKind.file);
      expect(entry.size, 5);
    });

    test('reports a link as a link, not as what it points at', () async {
      // The same answer `list` gives. Following meant the two disagreed about
      // the same path, and a caller acting on the difference — deleting, or
      // replacing — acted on the target instead of the link.
      await File(at('a.txt')).writeAsString('hello');
      await Link(at('l')).create(at('a.txt'));
      await Directory(at('sub')).create();
      await Link(at('to-dir')).create(at('sub'));

      final entry = await backend.stat(at('l'));
      final linkedDir = await backend.stat(at('to-dir'));

      expect(entry!.kind, FileKind.link);
      // Slash-separated, as the backend reports every path: it converts on
      // the way out so a caller never has to ask which platform it is on.
      expect(entry.linkTarget, at('a.txt').replaceAll(r'\', '/'));
      // A link to a directory too, which `list` would otherwise call a dir.
      expect(linkedDir!.kind, FileKind.link);
      expect(linkedDir.linkTarget, at('sub').replaceAll(r'\', '/'));
      // Neither carries the target's size or time: those describe the target,
      // and the link's own describe the link. The SFTP backend says the same.
      expect(entry.size, isNull);
      expect(entry.modified, isNull);
    });

    test('a link to nowhere is still something, not nothing', () async {
      // Reported as absent, it read as "free to create something here" — and
      // the something would have replaced a link the user could see listed.
      await Link(at('broken')).create(at('missing'));

      final entry = await backend.stat(at('broken'));

      expect(entry, isNotNull);
      expect(entry!.kind, FileKind.link);
      expect(entry.linkTarget, at('missing').replaceAll(r'\', '/'));
      expect(entry.size, isNull);
    });
  });

  group('remove', () {
    test(
      'refuses a directory with contents unless asked recursively',
      () async {
        await Directory(at('sub')).create();
        await File(at('sub/a.txt')).writeAsString('x');

        await expectLater(backend.remove(at('sub')), throwsA(anything));
        await backend.remove(at('sub'), recursive: true);

        expect(await Directory(at('sub')).exists(), isFalse);
      },
    );

    test('deletes the link, not what it points at', () async {
      await File(at('a.txt')).writeAsString('hello');
      await Link(at('l')).create(at('a.txt'));

      await backend.remove(at('l'));

      expect(await Link(at('l')).exists(), isFalse);
      expect(await File(at('a.txt')).exists(), isTrue);
    });
  });

  group('write', () {
    test('replaces the contents', () async {
      await backend.write(at('a.txt'), Stream.value(utf8.encode('one')));
      await backend.write(at('a.txt'), Stream.value(utf8.encode('two')));

      expect(await File(at('a.txt')).readAsString(), 'two');
    });

    test('leaves nothing behind when the source fails', () async {
      // The point of staging: a transfer that dies halfway must not leave a
      // half-file under the name something else is about to open.
      final failing = Stream<List<int>>.fromIterable([utf8.encode('half')])
          .asyncMap((chunk) async {
            throw const FileSystemException('source went away');
          });

      await expectLater(
        backend.write(at('a.txt'), failing),
        throwsA(isA<FileSystemException>()),
      );

      expect(await File(at('a.txt')).exists(), isFalse);
      final leftovers = await root.list().toList();
      expect(leftovers, isEmpty, reason: 'the staging file was not cleaned up');
    });

    test('does not touch the destination until the source is done', () async {
      await File(at('a.txt')).writeAsString('original');
      final controller = StreamController<List<int>>();
      final write = backend.write(at('a.txt'), controller.stream);

      controller.add(utf8.encode('new'));
      await Future<void>.delayed(Duration.zero);
      expect(
        await File(at('a.txt')).readAsString(),
        'original',
        reason: 'a reader mid-transfer must still see the old file',
      );

      await controller.close();
      await write;
      expect(await File(at('a.txt')).readAsString(), 'new');
    });
  });

  group('read', () {
    test('honours an offset, which its traits promise', () async {
      await File(at('a.txt')).writeAsString('0123456789');

      final bytes = await backend
          .read(at('a.txt'), offset: 4)
          .expand((chunk) => chunk)
          .toList();

      expect(utf8.decode(bytes), '456789');
    });
  });

  test('a staged file is recognisable as one, by both sides', () async {
    // The cleanup after a killed transfer sweeps by this pattern rather than
    // by a path it was told, because the backend picks the name inside
    // `write`.
    expect(isStagingOf('report.txt.sb-part-3', '/a/b/report.txt'), isTrue);
    expect(isStagingOf('report.txt', '/a/b/report.txt'), isFalse);
    expect(isStagingOf('other.txt.sb-part-3', '/a/b/report.txt'), isFalse);
  });

  test('rename moves a directory as readily as a file', () async {
    await Directory(at('sub')).create();
    await File(at('sub/a.txt')).writeAsString('x');

    await backend.rename(at('sub'), at('moved'));

    expect(await File(at('moved/a.txt')).readAsString(), 'x');
  });
}
