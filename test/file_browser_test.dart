import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_ce/hive.dart';
import 'package:server_box/data/model/file/file_backend.dart';
import 'package:server_box/data/res/store.dart';
import 'package:server_box/data/store/setting.dart';
import 'package:server_box/generated/l10n/l10n.dart';
import 'package:server_box/view/page/storage/file_browser.dart';

/// A filesystem that is a map, so a browser test is about the browser.
class _MapBackend implements FileBackend {
  _MapBackend(this.tree, {this.failWith, this.sudoFallback = false});

  final Map<String, List<FileEntry>> tree;

  /// Thrown instead of listing, for the states that are not a listing.
  /// Cleared by a test that wants the retry to succeed.
  Object? failWith;

  final bool sudoFallback;

  /// Every path this was asked to list, in order, so a test can tell "showed
  /// the old listing" from "never asked for the new one".
  final listed = <String>[];

  @override
  FileBackendTraits get traits =>
      FileBackendTraits(sudoFallback: sudoFallback);

  @override
  Future<List<FileEntry>> list(String path) async {
    listed.add(path);
    if (failWith case final error?) throw error;
    return tree[path] ?? const [];
  }

  @override
  Future<void> close() async {}

  @override
  Future<void> chmod(String path, int mode) async {}

  @override
  Future<void> mkdir(String path) async {}

  @override
  Stream<List<int>> read(String path, {int offset = 0}) =>
      const Stream.empty();

  @override
  Future<void> remove(String path, {bool recursive = false}) async {}

  @override
  Future<void> rename(String from, String to) async {}

  @override
  Future<FileEntry?> stat(String path) async => null;

  @override
  Future<void> write(String path, Stream<List<int>> data, {int? size}) async {}
}

FileEntry _dir(String name) => FileEntry(name: name, kind: FileKind.dir);

FileEntry _file(String name) =>
    FileEntry(name: name, kind: FileKind.file, size: 1);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory tempDir;
  late Box<dynamic> settingBox;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('server-box-browser-');
    Hive.init(tempDir.path);
    settingBox = await Hive.openBox<dynamic>('setting_test');
    getIt.registerSingleton<SettingStore>(SettingStore.forBox(settingBox));
  });

  tearDown(() async {
    await getIt.reset();
    await settingBox.close();
    await tempDir.delete(recursive: true);
  });

  Future<void> pump(WidgetTester tester, FileBackend backend) async {
    await tester.binding.setSurfaceSize(const Size(1200, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: FileBrowserPage(
            args: FileBrowserArgs(backend: backend, root: '/'),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('opening a directory shows what is in it', (tester) async {
    final backend = _MapBackend({
      '/': [_dir('sub'), _file('top.txt')],
      '/sub': [_file('inner.txt')],
    });

    await pump(tester, backend);
    expect(find.text('top.txt'), findsOneWidget);

    await tester.tap(find.text('sub'));
    await tester.pumpAndSettle();

    expect(backend.listed, ['/', '/sub']);
    expect(find.text('inner.txt'), findsOneWidget);
    expect(find.text('top.txt'), findsNothing);
  });

  testWidgets('going up shows the directory above again', (tester) async {
    final backend = _MapBackend({
      '/': [_dir('sub')],
      '/sub': [_file('inner.txt')],
    });

    await pump(tester, backend);
    await tester.tap(find.text('sub'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('..'));
    await tester.pumpAndSettle();

    expect(find.text('sub'), findsOneWidget);
    expect(find.text('inner.txt'), findsNothing);
  });

  group('a directory that would not open', () {
    testWidgets('names what went wrong, and keeps the exception', (
      tester,
    ) async {
      final backend = _MapBackend(
        const {},
        failWith: const PathNotFoundException(
          '/gone',
          OSError('No such file or directory', 2),
          'Directory listing failed',
        ),
      );

      await pump(tester, backend);

      // The heading someone can act on...
      expect(find.text('This folder is no longer here'), findsOneWidget);
      // ...and the words the OS used, still there for whoever wants them.
      expect(
        find.textContaining('No such file or directory'),
        findsOneWidget,
      );
    });

    testWidgets('offers sudo only where there is somewhere to escalate', (
      tester,
    ) async {
      await pump(
        tester,
        _MapBackend(const {}, failWith: 'Permission denied'),
      );
      expect(find.text('Try using sudo'), findsNothing);

      await pump(
        tester,
        _MapBackend(
          const {},
          failWith: 'Permission denied',
          sudoFallback: true,
        ),
      );
      expect(find.text('Try using sudo'), findsOneWidget);
    });

    testWidgets('can be tried again', (tester) async {
      final backend = _MapBackend(
        {
          '/': [_file('back.txt')],
        },
        failWith: 'Connection closed',
      );

      await pump(tester, backend);
      expect(find.text('Failure'), findsOneWidget);

      backend.failWith = null;
      await tester.tap(find.text('Refresh'));
      await tester.pumpAndSettle();

      expect(find.text('back.txt'), findsOneWidget);
    });
  });

  testWidgets('an empty directory says so, and can still be left', (
    tester,
  ) async {
    final backend = _MapBackend({
      '/': [_dir('empty')],
      '/empty': const [],
    });

    await pump(tester, backend);
    await tester.tap(find.text('empty'));
    await tester.pumpAndSettle();

    expect(find.text('..'), findsOneWidget);

    await tester.tap(find.text('..'));
    await tester.pumpAndSettle();
    expect(find.text('empty'), findsOneWidget);
  });
}
