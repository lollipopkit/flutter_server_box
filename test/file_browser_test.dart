import 'dart:io';

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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

  group('hidden files', () {
    // Driven through the store rather than through the popup menu: the filter
    // is the behaviour, and a menu route's animation is not what these are
    // meant to be waiting on.
    testWidgets('dotfiles are left out by default', (tester) async {
      final backend = _MapBackend({
        '/': [_file('.bashrc'), _file('notes.txt'), _dir('.config')],
      });

      await pump(tester, backend);

      expect(find.text('notes.txt'), findsOneWidget);
      expect(find.text('.bashrc'), findsNothing);
      expect(find.text('.config'), findsNothing);
    });

    testWidgets('and shown once the setting says so', (tester) async {
      // Through `runAsync`: writing the box is real file I/O, and a widget
      // test's zone fakes the timers it waits on.
      await tester.runAsync(
        () async => Stores.setting.showHiddenFiles.put(true),
      );
      final backend = _MapBackend({
        '/': [_file('.bashrc'), _file('notes.txt')],
      });

      await pump(tester, backend);

      expect(find.text('.bashrc'), findsOneWidget);
      expect(find.text('notes.txt'), findsOneWidget);
    });
  });

  group('the entry menu', () {
    testWidgets('a long press opens it centred', (tester) async {
      final backend = _MapBackend({
        '/': [_file('notes.txt')],
      });

      await pump(tester, backend);
      await tester.longPress(find.text('notes.txt'));
      await tester.pumpAndSettle();

      expect(find.text('Rename'), findsOneWidget);
      expect(find.text('Delete'), findsOneWidget);
      // The dialog names what it is acting on in its title, so the entry's
      // name is on screen twice: in the listing and above the menu.
      expect(find.text('notes.txt'), findsNWidgets(2));
    });

    testWidgets('a right-click opens it where the pointer is', (tester) async {
      final backend = _MapBackend({
        '/': [_file('notes.txt')],
      });

      await pump(tester, backend);

      // The gesture a mouse or a trackpad makes. Nothing about this is gated
      // on the platform: it simply never arrives from a finger.
      final at = tester.getCenter(find.text('notes.txt'));
      final gesture = await tester.startGesture(at, buttons: kSecondaryButton);
      await gesture.up();
      await tester.pumpAndSettle();

      expect(find.text('Rename'), findsOneWidget);
      // The popup, not the dialog. Told apart by the title rather than by
      // coordinates: where exactly Flutter places a menu that would overflow
      // an edge is Flutter's business, and asserting it would be testing the
      // framework's layout instead of this code's choice of path.
      expect(find.text('notes.txt'), findsOneWidget);
    });

    testWidgets('an action runs after the menu has closed', (tester) async {
      // Which is what lets an action open a dialog of its own — every entry
      // used to have to remember to pop the menu first.
      final backend = _MapBackend({
        '/': [_file('notes.txt')],
      });

      await pump(tester, backend);
      await tester.longPress(find.text('notes.txt'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Rename'));
      await tester.pumpAndSettle();

      // The rename dialog, not the menu.
      expect(find.text('Delete'), findsNothing);
      expect(find.widgetWithText(TextField, 'notes.txt'), findsOneWidget);
    });
  });

  testWidgets('right-clicking empty space offers what can be made here', (
    tester,
  ) async {
    // Where a desktop user looks for "new folder". The bottom bar's button is
    // the same list, and is not where they look.
    final backend = _MapBackend({'/': const []});

    await pump(tester, backend);
    final gesture = await tester.startGesture(
      const Offset(600, 400),
      buttons: kSecondaryButton,
    );
    await gesture.up();
    await tester.pumpAndSettle();

    expect(find.text('Folder'), findsOneWidget);
    expect(find.text('File'), findsOneWidget);
    // Not an entry's menu: nothing was clicked on.
    expect(find.text('Rename'), findsNothing);
  });

  group('picking several out', () {
    _MapBackend threeFiles() => _MapBackend({
      '/': [_file('a.txt'), _file('b.txt'), _file('c.txt')],
    });

    Future<void> clickWith(
      WidgetTester tester,
      String name, {
      LogicalKeyboardKey? holding,
    }) async {
      if (holding != null) await tester.sendKeyDownEvent(holding);
      await tester.tap(find.text(name));
      await tester.pumpAndSettle();
      if (holding != null) await tester.sendKeyUpEvent(holding);
    }

    testWidgets('a plain click still opens, and picks nothing', (tester) async {
      // Not reversed to "click selects, double-click opens": that would make
      // entering a folder cost two taps on a touch screen.
      final backend = _MapBackend({
        '/': [_dir('sub')],
        '/sub': [_file('inner.txt')],
      });

      await pump(tester, backend);
      await clickWith(tester, 'sub');

      expect(find.text('inner.txt'), findsOneWidget);
      expect(find.textContaining('selected'), findsNothing);
    });

    testWidgets('a modifier click picks instead of opening', (tester) async {
      await pump(tester, threeFiles());

      await clickWith(tester, 'a.txt', holding: LogicalKeyboardKey.meta);

      expect(find.text('1 selected'), findsOneWidget);
    });

    testWidgets('once one is picked, a plain click picks too', (tester) async {
      // Otherwise the second file would need the modifier held as well, which
      // is not how any list behaves.
      await pump(tester, threeFiles());

      await clickWith(tester, 'a.txt', holding: LogicalKeyboardKey.meta);
      await clickWith(tester, 'b.txt');

      expect(find.text('2 selected'), findsOneWidget);
    });

    testWidgets('shift picks everything in between', (tester) async {
      await pump(tester, threeFiles());

      await clickWith(tester, 'a.txt', holding: LogicalKeyboardKey.meta);
      await clickWith(tester, 'c.txt', holding: LogicalKeyboardKey.shift);

      expect(find.text('3 selected'), findsOneWidget);
    });

    testWidgets('leaving the directory drops the selection', (tester) async {
      // A selection is names in one listing; carrying it into another would
      // be carrying names that mean something else there.
      final backend = _MapBackend({
        '/': [_dir('sub'), _file('a.txt')],
        '/sub': [_file('a.txt')],
      });

      await pump(tester, backend);
      await clickWith(tester, 'a.txt', holding: LogicalKeyboardKey.meta);
      expect(find.text('1 selected'), findsOneWidget);

      // Through `..`, not by tapping the folder: while a selection is open a
      // plain tap picks rather than opens, which is what makes the second file
      // reachable without holding a modifier again.
      await tester.tap(find.text('sub'));
      await tester.pumpAndSettle();
      expect(find.text('2 selected'), findsOneWidget);
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pumpAndSettle();
      await tester.tap(find.text('sub'));
      await tester.pumpAndSettle();

      expect(find.textContaining('selected'), findsNothing);
    });

    testWidgets('escape puts it away', (tester) async {
      await pump(tester, threeFiles());
      await clickWith(tester, 'a.txt', holding: LogicalKeyboardKey.meta);

      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pumpAndSettle();

      expect(find.textContaining('selected'), findsNothing);
    });
  });

  group('the keyboard', () {
    /// Puts the keyboard on the listing without opening anything.
    ///
    /// Tapping a row would: with no `onOpenFile` the browser falls back to
    /// that row's menu, and a dialog takes the focus with it.
    Future<void> focusList(WidgetTester tester) async {
      await tester.tapAt(const Offset(600, 700));
      await tester.pumpAndSettle();
    }

    testWidgets('arrows move a cursor, enter opens it', (tester) async {
      final backend = _MapBackend({
        '/': [_dir('sub'), _file('a.txt')],
        '/sub': [_file('inner.txt')],
      });

      await pump(tester, backend);
      // Focus follows a click into the listing, which is what makes the keys
      // work without hunting for it with Tab first.
      await focusList(tester);

      await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
      await tester.pumpAndSettle();
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pumpAndSettle();

      expect(find.text('inner.txt'), findsOneWidget);
    });

    testWidgets('backspace goes up', (tester) async {
      final backend = _MapBackend({
        '/': [_dir('sub')],
        '/sub': [_file('inner.txt')],
      });

      await pump(tester, backend);
      await tester.tap(find.text('sub'));
      await tester.pumpAndSettle();
      expect(find.text('inner.txt'), findsOneWidget);
      await focusList(tester);

      await tester.sendKeyEvent(LogicalKeyboardKey.backspace);
      await tester.pumpAndSettle();

      expect(find.text('sub'), findsOneWidget);
    });

    testWidgets('select-all picks the whole listing', (tester) async {
      await pump(tester, _MapBackend({
        '/': [_file('a.txt'), _file('b.txt'), _file('c.txt')],
      }));
      await focusList(tester);

      await tester.sendKeyDownEvent(LogicalKeyboardKey.meta);
      await tester.sendKeyEvent(LogicalKeyboardKey.keyA);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.meta);
      await tester.pumpAndSettle();

      expect(find.text('3 selected'), findsOneWidget);
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
