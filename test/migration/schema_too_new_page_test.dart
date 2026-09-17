/// What a downgraded install is shown.
///
/// The refusal happens inside `_initApp`, before `runApp`, so until this page
/// existed the launch simply stopped: no window, no message. From the outside
/// that is a crash, and the one thing the user needed — *the data is intact,
/// reinstall the newer build* — was in a log file on the device.
library;

import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:fl_lib/fl_lib.dart';
import 'package:flutter/material.dart' show LinearProgressIndicator;
import 'package:flutter_secure_storage/flutter_secure_storage.dart'
    show FlutterSecureStorage;
import 'package:flutter_test/flutter_test.dart';
import 'package:server_box/core/extension/context/locale.dart';
import 'package:server_box/data/store/schema.dart';
import 'package:server_box/view/page/schema_too_new.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../helpers/deny_file_deletion.dart';

import '../helpers/test_db.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory tmp;
  late Directory dbDir;

  // `Paths.doc` is `late` and refuses a second assignment, so it is set once
  // and its contents cleared per test instead.
  setUpAll(() async {
    tmp = await Directory.systemTemp.createTemp('schema-page-');
    Paths.doc = tmp.path;

    final rng = Random(11);
    FlutterSecureStorage.setMockInitialValues({
      'hivePwd': base64UrlEncode(
        Uint8List.fromList(List<int>.generate(32, (_) => rng.nextInt(256))),
      ),
    });
    SharedPreferences.setMockInitialValues({});
    await PrefStore.shared.init();
  });

  tearDownAll(() {
    if (tmp.existsSync()) tmp.deleteSync(recursive: true);
  });

  setUp(() async {
    for (final e in tmp.listSync()) {
      e.deleteSync(recursive: true);
    }
    // A real file, not `openTestDb`'s in-memory database: the export runs on a
    // second isolate that opens the store by path, and an in-memory one has
    // none. `Paths.doc` is where the page writes its copies, so the store goes
    // in a subdirectory to keep the two apart.
    dbDir = Directory('${tmp.path}/store')..createSync();
    await SqliteDb.open(dbDir.path);
  });

  tearDown(closeTestDb);

  late _FakeDirectoryPicker picker;
  final original = FilePickerPlatform.instance;

  setUp(() {
    final out = Directory('${tmp.path}/chosen')..createSync();
    picker = _FakeDirectoryPicker(out);
    FilePickerPlatform.instance = picker;
  });

  tearDown(() => FilePickerPlatform.instance = original);

  /// The page's own temp directories that exist right now.
  Set<String> rescueTemps() => Directory.systemTemp
      .listSync()
      .map((e) => e.path)
      .where((p) => p.split(Platform.pathSeparator).last.startsWith('sbx-rescue-'))
      .toSet();

  /// What the export left in the directory the user picked.
  List<File> saved() => picker.dir.listSync().whereType<File>().toList();

  /// Lets real asynchronous work run for a moment.
  ///
  /// The export runs under `Isolate.run`, which a `testWidgets` fake-async zone
  /// does not drive on its own.
  Future<void> settle(WidgetTester tester) async {
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 200)),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
  }

  /// Drives both clocks until [done], or gives up after a few seconds.
  ///
  /// Both, alternately: the isolate finishes in real time, but what the page
  /// does after it — the copy, the cleanup, the dialog — is a continuation in
  /// the fake zone, which only a pump runs.
  Future<void> settleUntil(WidgetTester tester, bool Function() done) async {
    final deadline = DateTime.now().add(const Duration(seconds: 10));
    while (!done() && DateTime.now().isBefore(deadline)) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 50)),
      );
      await tester.pump();
    }
    await tester.pump(const Duration(milliseconds: 400));
  }

  /// Taps through to a plain export: the warning, then its OK.
  Future<void> exportPlain(WidgetTester tester) async {
    await tester.tap(find.text(l10n.schemaTooNewExportPlain));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    await tester.tap(find.text(libL10n.ok).last);
    await tester.pump();
  }

  Future<void> pump(WidgetTester tester) async {
    await tester.pumpWidget(
      const SchemaTooNewApp(
        err: SchemaTooNewException(stored: 23, supported: 21),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
  }

  testWidgets('it says which versions, and that nothing was touched', (
    tester,
  ) async {
    await pump(tester);

    expect(tester.takeException(), isNull);
    expect(find.text(l10n.schemaTooNewTitle), findsOneWidget);
    // Both numbers, because "newer" alone tells nobody which build to look for.
    expect(find.textContaining('23'), findsWidgets);
    expect(find.textContaining('21'), findsWidgets);
    // The answer that costs nothing is on screen, not just the destructive one.
    expect(find.text(l10n.schemaTooNewReinstall), findsOneWidget);
  });

  testWidgets('it offers a backup, an unencrypted one, and a wipe', (
    tester,
  ) async {
    await pump(tester);

    expect(find.text(libL10n.backup), findsOneWidget);
    expect(find.text(l10n.schemaTooNewExportPlain), findsOneWidget);
    expect(find.text(l10n.schemaTooNewWipe), findsOneWidget);
  });

  testWidgets('the unencrypted export warns before it writes anything', (
    tester,
  ) async {
    // The file holds every private key and password in the clear. Warning
    // after the fact is not a warning.
    await pump(tester);

    await tester.tap(find.text(l10n.schemaTooNewExportPlain));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    expect(find.text(l10n.schemaTooNewPlainWarn), findsOneWidget);
    expect(
      picker.asked,
      0,
      reason: 'the export began before the user answered',
    );
  });

  testWidgets('and saves one where the user chose when it is accepted', (
    tester,
  ) async {
    final tempsBefore = rescueTemps();
    await pump(tester);

    await exportPlain(tester);
    await settleUntil(tester, () => saved().isNotEmpty);

    expect(tester.takeException(), isNull);
    expect(picker.asked, 1);
    // The file is where the user pointed once the export returns. This page
    // used to reveal a temp copy and delete it in the same breath, so the file
    // manager opened on nothing.
    final files = saved();
    expect(files, hasLength(1));
    final name = files.single.path.split(Platform.pathSeparator).last;
    // Named for the version that wrote the data, which is what a future reader
    // has to match it against. One extension: a save panel on macOS made this
    // `.db.db`.
    expect(name, matches(RegExp(r'^serverbox-rescue-v23-\d{8}-\d{6}-plain\.db$')));
    // A whole SQLite file, readable by any tool, since this is the plain path.
    final head = files.single.readAsBytesSync().take(15).toList();
    expect(utf8.decode(head), 'SQLite format 3');
    // Nothing left in the temp directory: the only copy that outlives the
    // export is the one the user put somewhere.
    expect(rescueTemps().difference(tempsBefore), isEmpty);
    // Nor beside `store.db`, for the same reason: this is the whole database,
    // in the clear on this path.
    final strays = tmp
        .listSync(recursive: true)
        .whereType<File>()
        .where((f) => f.parent.path != picker.dir.path)
        .where(
          (f) => f.path
              .split(Platform.pathSeparator)
              .last
              .startsWith('serverbox-rescue-'),
        );
    expect(strays, isEmpty);
    // And the screen says where it went, since nothing else on it changes.
    expect(find.text(libL10n.success), findsOneWidget);
    expect(find.text(files.single.path), findsOneWidget);
    expect(find.text(libL10n.fail), findsNothing);
  });

  testWidgets('a second export sits beside the first', (tester) async {
    // Two in the same second get the same name. Replacing the first would be
    // replacing a backup the user already has.
    await pump(tester);

    await exportPlain(tester);
    await settleUntil(tester, () => saved().isNotEmpty);
    await tester.tap(find.text(libL10n.ok).last);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    await exportPlain(tester);
    await settleUntil(tester, () => saved().length > 1);

    expect(saved(), hasLength(2));
    expect(find.text(libL10n.fail), findsNothing);
  });

  testWidgets('cancelling the directory picker exports nothing', (
    tester,
  ) async {
    picker.cancel = true;
    final tempsBefore = rescueTemps();
    await pump(tester);

    await exportPlain(tester);
    await settle(tester);

    expect(picker.asked, 1);
    expect(saved(), isEmpty);
    expect(rescueTemps().difference(tempsBefore), isEmpty);
    // A cancel is an answer, not a failure.
    expect(find.text(libL10n.fail), findsNothing);
    expect(find.byType(LinearProgressIndicator), findsNothing);
    expect(find.text(libL10n.backup), findsOneWidget);
  });

  testWidgets('the wipe asks first, and says what is left afterwards', (
    tester,
  ) async {
    await pump(tester);

    await tester.tap(find.text(l10n.schemaTooNewWipe));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.text(l10n.schemaTooNewWipeConfirm), findsOneWidget);

    await tester.tap(find.text(libL10n.ok).last);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    expect(tester.takeException(), isNull);
    // The controls are gone: there is nothing left to export.
    expect(find.text(l10n.schemaTooNewWipeDone), findsOneWidget);
    expect(find.text(l10n.schemaTooNewWipeFailed), findsNothing);
    expect(find.text(libL10n.backup), findsNothing);
    expect(find.text(l10n.schemaTooNewWipe), findsNothing);
    // And a way out, rather than an instruction the user cannot act on:
    // reopening resumes this same process and this same dead screen.
    expect(find.text(libL10n.exit), findsOneWidget);
  });

  testWidgets('a wipe that cannot delete still closes the export routes', (
    tester,
  ) async {
    // `wipe` closes the connection before it deletes. If a delete then fails,
    // offering Backup again is offering a button that can only report "the
    // database is not open" — and it was the user's last chance at the data.
    await pump(tester);
    // Exercise the real wipe failure path on every OS, including root.
    final denied = DenyFileDeletion(File(SqliteDb.path!));
    final previous = IOOverrides.current;
    IOOverrides.global = denied;
    addTearDown(() => IOOverrides.global = previous);

    await tester.tap(find.text(l10n.schemaTooNewWipe));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    await tester.tap(find.text(libL10n.ok).last);
    await tester.pump();
    await settle(tester);

    expect(find.text(libL10n.backup), findsNothing);
    expect(find.text(l10n.schemaTooNewExportPlain), findsNothing);
    // And it does not claim the data is gone. It is not: a delete that failed
    // leaves a database this build still cannot open, and saying otherwise is
    // wrong in both directions.
    expect(find.text(l10n.schemaTooNewWipeDone), findsNothing);
    expect(find.text(l10n.schemaTooNewWipeFailed), findsOneWidget);
    expect(denied.attempted, isTrue);
  });

  testWidgets('declining the wipe leaves everything alone', (tester) async {
    await pump(tester);

    await tester.tap(find.text(l10n.schemaTooNewWipe));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    await tester.tap(find.text(libL10n.cancel).last);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    expect(find.text(l10n.schemaTooNewWipeDone), findsNothing);
    expect(find.text(libL10n.backup), findsOneWidget);
    expect(SqliteDb.isOpen, isTrue);
  });
}

/// Stands in for the platform's directory picker.
///
/// Replaces the platform rather than the page's call, so the page's own desktop
/// path runs: the picker answers, and the copy into that directory is the
/// page's.
class _FakeDirectoryPicker extends FilePickerPlatform {
  _FakeDirectoryPicker(this.dir);

  /// Where the user "chose" to save.
  final Directory dir;

  /// Answers as a user who dismissed the picker.
  bool cancel = false;

  /// How many times the picker was opened.
  int asked = 0;

  @override
  Future<String?> getDirectoryPath({
    String? dialogTitle,
    String? initialDirectory,
    AndroidOptions androidOptions = const AndroidOptions(),
    WindowsOptions windowsOptions = const WindowsOptions(),
    LinuxOptions linuxOptions = const LinuxOptions(),
    WebOptions webOptions = const WebOptions(),
  }) async {
    asked++;
    return cancel ? null : dir.path;
  }
}
