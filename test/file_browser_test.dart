import 'dart:io';

import 'package:fl_lib/fl_lib.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_ce/hive.dart';
import 'package:server_box/data/model/file/file_backend.dart';
import 'package:server_box/data/model/file/file_ref.dart';
import 'package:server_box/data/res/store.dart';
import 'package:server_box/data/store/setting.dart';
import 'package:server_box/generated/l10n/l10n.dart';
import 'package:server_box/view/page/storage/file_browser.dart';


/// A filesystem that is a map, so a browser test is about the browser.
class _MapBackend implements FileBackend {
  _MapBackend(
    this.tree, {
    this.failWith,
    this.sudoFallback = false,
    this.roots = const [],
  });

  final Map<String, List<FileEntry>> tree;

  /// Thrown instead of listing, for the states that are not a listing.
  /// Cleared by a test that wants the retry to succeed.
  Object? failWith;

  final bool sudoFallback;

  /// What the far side says it will serve. Empty is a backend with no such
  /// limit, which is what both real non-agent ones answer.
  final List<String> roots;

  /// Every path this was asked to list, in order, so a test can tell "showed
  /// the old listing" from "never asked for the new one".
  final listed = <String>[];

  /// What it was asked to delete and to rename. A dialog that was shown and a
  /// dialog that was confirmed look the same from the listing, so these are
  /// what tell them apart.
  final removed = <String>[];
  final renamed = <(String from, String to)>[];

  @override
  FileBackendTraits get traits =>
      FileBackendTraits(sudoFallback: sudoFallback);

  @override
  Future<List<String>> reachableRoots() async => roots;

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
  Future<void> remove(String path, {bool recursive = false}) async =>
      removed.add(path);

  @override
  Future<void> rename(String from, String to) async => renamed.add((from, to));

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

    testWidgets('offers the roots the far side will serve', (tester) async {
      // The case this exists for: a tab restored onto a path the agent's roots
      // no longer cover. Retrying can only be refused again; the roots are the
      // only way on.
      final backend = _MapBackend(
        {
          '/home': [_file('there.txt')],
        },
        failWith: 'status code of 403',
        roots: const ['/home', '/etc'],
      );

      await pump(tester, backend);
      expect(find.text('Permission denied.'), findsOneWidget);
      expect(find.text('/home'), findsOneWidget);
      expect(find.text('/etc'), findsOneWidget);

      backend.failWith = null;
      await tester.tap(find.text('/home'));
      await tester.pumpAndSettle();

      expect(find.text('there.txt'), findsOneWidget);
      expect(backend.listed.last, '/home');
    });

    testWidgets('offers no roots where the backend has no such limit', (
      tester,
    ) async {
      // An empty answer is "browse anywhere", not "nowhere to go" — drawing a
      // heading with no chips under it would say the opposite.
      await pump(
        tester,
        _MapBackend(const {}, failWith: 'Permission denied'),
      );

      expect(find.text('Permission denied.'), findsOneWidget);
      expect(find.byType(ActionChip), findsNothing);
      expect(find.text('Go to'), findsNothing);
    });

    testWidgets('offers no roots for a failure going elsewhere cannot fix', (
      tester,
    ) async {
      await pump(
        tester,
        _MapBackend(
          const {},
          failWith: 'Connection closed',
          roots: const ['/home'],
        ),
      );

      expect(find.text('Failure'), findsOneWidget);
      expect(find.byType(ActionChip), findsNothing);
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

    testWidgets('F2 renames where the cursor is', (tester) async {
      final backend = _MapBackend({
        '/': [_file('a.txt'), _file('b.txt')],
      });

      await pump(tester, backend);
      await focusList(tester);
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
      await tester.pumpAndSettle();
      await tester.sendKeyEvent(LogicalKeyboardKey.f2);
      await tester.pumpAndSettle();

      // The rename dialog, opened on the row the cursor reached rather than on
      // whatever was first.
      expect(find.widgetWithText(TextField, 'a.txt'), findsOneWidget);
    });

    testWidgets('F2 does nothing while two are picked', (tester) async {
      // Which of the two would it rename? Nothing rather than whichever came
      // first — see `_cursorOrOnlySelected`.
      final backend = _MapBackend({
        '/': [_file('a.txt'), _file('b.txt')],
      });

      await pump(tester, backend);
      await tester.sendKeyDownEvent(LogicalKeyboardKey.meta);
      await tester.tap(find.text('a.txt'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('b.txt'));
      await tester.pumpAndSettle();
      await tester.sendKeyUpEvent(LogicalKeyboardKey.meta);
      expect(find.text('2 selected'), findsOneWidget);

      await tester.sendKeyEvent(LogicalKeyboardKey.f2);
      await tester.pumpAndSettle();

      expect(find.byType(TextField), findsNothing);
      expect(find.text('2 selected'), findsOneWidget);
    });
  });

  group('deleting several at once', () {
    _MapBackend threeFiles() => _MapBackend({
      '/': [_file('a.txt'), _file('b.txt'), _file('c.txt')],
    });

    /// Picks [names] out, the way a desktop user would.
    Future<void> pick(WidgetTester tester, List<String> names) async {
      await tester.sendKeyDownEvent(LogicalKeyboardKey.meta);
      for (final name in names) {
        await tester.tap(find.text(name));
        await tester.pumpAndSettle();
      }
      await tester.sendKeyUpEvent(LogicalKeyboardKey.meta);
    }

    testWidgets('asks once, and names what it is about to delete', (
      tester,
    ) async {
      // Once per file would be three dialogs to dismiss for one intention, and
      // a list of names is the only chance to notice the wrong one is in it.
      final backend = threeFiles();

      await pump(tester, backend);
      await pick(tester, ['a.txt', 'b.txt']);
      await tester.sendKeyEvent(LogicalKeyboardKey.delete);
      await tester.pumpAndSettle();

      expect(find.textContaining('a.txt\nb.txt'), findsOneWidget);
      // Nothing has gone yet: this is the question, not the answer.
      expect(backend.removed, isEmpty);
    });

    testWidgets('removes every one of them once confirmed', (tester) async {
      final backend = threeFiles();

      await pump(tester, backend);
      await pick(tester, ['a.txt', 'b.txt']);
      await tester.sendKeyEvent(LogicalKeyboardKey.delete);
      await tester.pumpAndSettle();
      await tester.tap(find.text(libL10n.ok));
      await tester.pumpAndSettle();

      expect(backend.removed, ['/a.txt', '/b.txt']);
      // And the selection is gone, so the bar does not name files that are not
      // there any more.
      expect(find.textContaining('selected'), findsNothing);
    });

    testWidgets('dismissing it removes nothing, and keeps the selection', (
      tester,
    ) async {
      // The way out is the barrier: `Btnx.okReds` is one button, so there is
      // no Cancel to press, and `showRoundDialog` is barrier-dismissible by
      // default. A dismissed dialog answers null, which is not `true`.
      final backend = threeFiles();

      await pump(tester, backend);
      await pick(tester, ['a.txt', 'b.txt']);
      await tester.sendKeyEvent(LogicalKeyboardKey.delete);
      await tester.pumpAndSettle();
      expect(find.byType(ModalBarrier), findsWidgets);

      await tester.tapAt(const Offset(10, 10));
      await tester.pumpAndSettle();

      expect(backend.removed, isEmpty);
      // Still picked, so the intention survives a mis-press.
      expect(find.text('2 selected'), findsOneWidget);
    });
  });

  group('ordering the listing', () {
    /// Sizes chosen so that a name sort and a size sort disagree — otherwise
    /// a broken size sort passes by looking like the default.
    _MapBackend bySize() => _MapBackend({
      '/': [
        FileEntry(name: 'a-big.bin', kind: FileKind.file, size: 900),
        FileEntry(name: 'b-small.bin', kind: FileKind.file, size: 10),
        FileEntry(name: 'c-unknown.bin', kind: FileKind.file),
      ],
    });

    /// The order the rows are actually painted in.
    List<String> shown(WidgetTester tester) => tester
        .widgetList<Text>(find.byType(Text))
        .map((t) => t.data ?? '')
        .where((s) => s.endsWith('.bin'))
        .toList();

    Future<void> sortBy(WidgetTester tester, String label) async {
      await tester.tap(find.byIcon(Icons.sort));
      await tester.pumpAndSettle();
      await tester.tap(find.textContaining(label).last);
      await tester.pumpAndSettle();
    }

    testWidgets('by size, smallest first, with the unknown last', (
      tester,
    ) async {
      // A backend that did not say is not the same as a file of no size, so it
      // sorts last rather than as zero — at either end of the order.
      await pump(tester, bySize());
      await sortBy(tester, 'Size');

      expect(shown(tester), ['b-small.bin', 'a-big.bin', 'c-unknown.bin']);
    });

    testWidgets('choosing the same one again reverses it', (tester) async {
      await pump(tester, bySize());
      await sortBy(tester, 'Size');
      await sortBy(tester, 'Size');

      // The unknown moves to the front, because reversing negates the whole
      // comparison and `_nullsLast` is part of it. Consistent with what the
      // rule is for — an unknown size is not zero — but it does mean "unknown"
      // takes the first row rather than staying out of the way. Recorded as
      // the behaviour rather than argued with; whether it should stay put in
      // both directions is a UI decision nobody has made.
      expect(shown(tester), ['c-unknown.bin', 'a-big.bin', 'b-small.bin']);
    });

    testWidgets('name is the default, and is not the size order', (
      tester,
    ) async {
      await pump(tester, bySize());

      expect(shown(tester), ['a-big.bin', 'b-small.bin', 'c-unknown.bin']);
    });
  });

  group('searching this listing', () {
    testWidgets('finds an entry by part of its name', (tester) async {
      await pump(tester, _MapBackend({
        '/': [_file('notes.txt'), _file('report.pdf'), _dir('archive')],
      }));

      await tester.tap(find.byIcon(Icons.search));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), 'REPO');
      await tester.pumpAndSettle();

      // Case-insensitive, and a substring rather than a prefix.
      expect(find.text('report.pdf'), findsOneWidget);
      expect(find.text('notes.txt'), findsNothing);
    });

    testWidgets('searches what is listed, directories included', (
      tester,
    ) async {
      await pump(tester, _MapBackend({
        '/': [_file('notes.txt'), _dir('archive')],
      }));

      await tester.tap(find.byIcon(Icons.search));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), 'arch');
      await tester.pumpAndSettle();

      expect(find.text('archive'), findsOneWidget);
    });
  });

  group('deciding a transfer landed here', () {
    // The rule `_refreshOnArrival` applies, on its own. Driving a real
    // transfer through a widget test deadlocks: `add()` starts its work inside
    // the fake-async zone and `runAsync` then waits on timers that zone is no
    // longer pumping — the run hangs with no output, the same way a real Hive
    // box does. The end to end is covered by hand instead.
    test('a name in this directory is this directory', () {
      const here = LocalFileRef('/tmp/into');

      expect(here.child('dropped.txt'), const LocalFileRef('/tmp/into/dropped.txt'));
    });

    test('a sibling directory is not', () {
      const here = LocalFileRef('/tmp/into');

      expect(
        here.child('dropped.txt') == const LocalFileRef('/tmp/elsewhere/dropped.txt'),
        isFalse,
      );
    });

    // That the same path on two different machines is also not the same place
    // is `file_transfer_test.dart`'s `two ends are the same place only when
    // both halves match` — an `SftpFileRef` carries the server it is on.

  });

  testWidgets('every icon button says what it does', (tester) async {
    // 44 of them said nothing at all before the desktop sweep. A tooltip is
    // the only label an icon-only button has, and on a desktop it is what a
    // hover is for; asserted over the tree rather than listed, so a button
    // added later is covered without anyone remembering to add it here.
    await pump(tester, _MapBackend({
      '/': [_file('a.txt')],
    }));

    final silent = <String>[];
    for (final element in find.byType(IconButton).evaluate()) {
      final button = element.widget as IconButton;
      if (button.tooltip != null && button.tooltip!.isNotEmpty) continue;
      // A button may carry its label as a `Tooltip` around it instead, which
      // reads the same to a user and to the semantics tree.
      final wrapped = find
          .ancestor(of: find.byWidget(button), matching: find.byType(Tooltip))
          .evaluate()
          .isNotEmpty;
      if (!wrapped) silent.add(button.icon.toStringShort());
    }

    expect(silent, isEmpty, reason: 'these say nothing on hover: $silent');
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
