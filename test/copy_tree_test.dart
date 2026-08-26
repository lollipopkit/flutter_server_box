import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:server_box/core/utils/local_file_backend.dart';
import 'package:server_box/data/model/file/copy_tree.dart';
import 'package:server_box/data/model/file/file_backend.dart';

void main() {
  late Directory tempDir;
  const backend = LocalFileBackend();

  String at(String relative) => '${tempDir.path}/$relative';

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('server-box-copy-tree-');
  });

  tearDown(() => tempDir.delete(recursive: true));

  test('a single file is a plan of one, sized', () async {
    await File(at('a.txt')).writeAsString('0123456789');

    final plan = await planCopy(
      backend,
      at('a.txt'),
      at('b.txt'),
      isDir: false,
    );

    expect(plan.items, hasLength(1));
    expect(plan.dirs, isEmpty);
    expect(plan.totalBytes, 10);
  });

  test('a tree is walked before anything is moved', () async {
    // So progress has a denominator from the first byte, rather than a total
    // that keeps growing as the copy discovers more work.
    await Directory(at('src/deep')).create(recursive: true);
    await File(at('src/one.txt')).writeAsString('aaa');
    await File(at('src/deep/two.txt')).writeAsString('bbbb');

    final plan = await planCopy(backend, at('src'), at('dst'), isDir: true);

    expect(plan.totalBytes, 7);
    expect(
      plan.items.map((e) => e.to),
      containsAll([at('dst/one.txt'), at('dst/deep/two.txt')]),
    );
    // The destination itself, and every directory under it.
    expect(plan.dirs, containsAll([at('dst'), at('dst/deep')]));
  });

  test('copying a tree reproduces it, contents and all', () async {
    await Directory(at('src/deep')).create(recursive: true);
    await File(at('src/one.txt')).writeAsString('hello');
    await File(at('src/deep/two.txt')).writeAsString('world');

    final plan = await planCopy(backend, at('src'), at('dst'), isDir: true);
    final progress = <int>[];
    await runCopy(plan, backend, backend, onProgress: progress.add);

    expect(File(at('dst/one.txt')).readAsStringSync(), 'hello');
    expect(File(at('dst/deep/two.txt')).readAsStringSync(), 'world');
    // Running total, not per-chunk deltas: the last one is everything.
    expect(progress.last, 10);
    expect(progress, orderedEquals(List.of(progress)..sort()));
  });

  test('an empty directory is still created', () async {
    await Directory(at('src/empty')).create(recursive: true);

    final plan = await planCopy(backend, at('src'), at('dst'), isDir: true);
    await runCopy(plan, backend, backend, onProgress: (_) {});

    expect(Directory(at('dst/empty')).existsSync(), isTrue);
    expect(plan.items, isEmpty);
  });

  test(
    'a destination that already has the directory is not a failure',
    () async {
      await Directory(at('src')).create();
      await File(at('src/one.txt')).writeAsString('x');
      await Directory(at('dst')).create();

      final plan = await planCopy(backend, at('src'), at('dst'), isDir: true);
      await runCopy(plan, backend, backend, onProgress: (_) {});

      expect(File(at('dst/one.txt')).readAsStringSync(), 'x');
    },
  );

  test(
    'a file that dies halfway leaves nothing under its final name',
    () async {
      // What `write` promises, inherited by every copy that goes through it.
      await File(at('dest.txt')).writeAsString('the good one');

      await expectLater(
        backend.write(
          at('dest.txt'),
          Stream<List<int>>.fromIterable([
            utf8.encode('partial'),
          ]).followedBy(Stream.error(StateError('link died'))),
        ),
        throwsA(isA<StateError>()),
      );

      expect(File(at('dest.txt')).readAsStringSync(), 'the good one');
      expect(
        Directory(tempDir.path).listSync().map((e) => p.basename(e.path)),
        ['dest.txt'],
      );
    },
  );

  test(
    'a replay reopens the source without double-counting progress',
    () async {
      final source = _ReplaySource();
      final dest = _ReplayDestination();
      final progress = <int>[];
      const plan = CopyPlan(
        items: [CopyItem(from: '/from', to: '/to', size: 6)],
        dirs: [],
        totalBytes: 6,
      );

      await runCopy(plan, source, dest, onProgress: progress.add);

      expect(source.reads, 2);
      expect(dest.attempts, [
        [1, 2, 3, 4, 5, 6],
        [1, 2, 3, 4, 5, 6],
      ]);
      expect(progress, [1, 3, 6]);
    },
  );
}

extension _Follow<T> on Stream<T> {
  Stream<T> followedBy(Stream<T> other) async* {
    yield* this;
    yield* other;
  }
}

abstract class _TestBackend implements FileBackend {
  @override
  FileBackendTraits get traits => const FileBackendTraits();

  @override
  Future<void> chmod(String path, int mode) async {}

  @override
  Future<void> close() async {}

  @override
  Future<List<FileEntry>> list(String path) async => const [];

  @override
  Future<void> mkdir(String path) async {}

  @override
  Future<List<String>> reachableRoots() async => const [];

  @override
  Future<void> remove(String path, {bool recursive = false}) async {}

  @override
  Future<void> rename(String from, String to) async {}

  @override
  Future<FileEntry?> stat(String path) async => null;
}

final class _ReplaySource extends _TestBackend {
  int reads = 0;

  @override
  Stream<List<int>> read(String path, {int offset = 0}) async* {
    reads++;
    yield const [1];
    yield const [2, 3];
    yield const [4, 5, 6];
  }

  @override
  Future<void> write(
    String path,
    Stream<List<int>> data, {
    int? size,
    void Function(String staging)? onStaging,
    Stream<List<int>> Function()? replayData,
  }) => throw UnsupportedError('source only');
}

final class _ReplayDestination extends _TestBackend {
  final attempts = <List<int>>[];

  @override
  Stream<List<int>> read(String path, {int offset = 0}) =>
      throw UnsupportedError('destination only');

  @override
  Future<void> write(
    String path,
    Stream<List<int>> data, {
    int? size,
    void Function(String staging)? onStaging,
    Stream<List<int>> Function()? replayData,
  }) async {
    attempts.add(await data.expand((chunk) => chunk).toList());
    attempts.add(await replayData!().expand((chunk) => chunk).toList());
  }
}
