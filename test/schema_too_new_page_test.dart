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

import 'package:fl_lib/fl_lib.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:server_box/core/extension/context/locale.dart';
import 'package:server_box/data/store/schema.dart';
import 'package:server_box/view/page/schema_too_new.dart';
import 'package:shared_preferences/shared_preferences.dart';

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

  tearDown(SqliteDb.close);

  /// Paths handed to the share sheet, and what was in the file at that moment.
  ///
  /// Captured rather than found on disk afterwards: the copy lives in a
  /// temporary directory that is removed as soon as the share returns.
  late List<String> shared;
  late List<int> sharedSizes;

  setUp(() {
    shared = [];
    sharedSizes = [];
    SchemaTooNewPage.shareForTest = (path) async {
      shared.add(path);
      sharedSizes.add(File(path).lengthSync());
    };
  });

  tearDown(() => SchemaTooNewPage.shareForTest = null);

  /// Lets real asynchronous work finish.
  ///
  /// The export runs under `Isolate.run`, which a `testWidgets` fake-async zone
  /// does not drive on its own — without this the copy never completes and the
  /// share is never reached.
  Future<void> settle(WidgetTester tester) async {
    await tester.runAsync(() => Future<void>.delayed(
          const Duration(milliseconds: 200),
        ));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
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
    expect(shared, isEmpty, reason: 'a copy was made before the user answered');
  });

  testWidgets('and writes one when the warning is accepted', (tester) async {
    await pump(tester);

    await tester.tap(find.text(l10n.schemaTooNewExportPlain));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    await tester.tap(find.text(libL10n.ok).last);
    await tester.pump();
    await settle(tester);

    expect(shared, hasLength(1));
    // Named for the version that wrote the data, which is what a future reader
    // has to match it against.
    expect(shared.single, contains('v23'));
    expect(shared.single, endsWith('-plain.db'));
    expect(sharedSizes.single, greaterThan(0));
    // Not beside `store.db`: `sharePaths` reveals the file on desktop, and this
    // one is the whole database in the clear.
    expect(shared.single, isNot(startsWith(Paths.doc)));
    // And gone once the sheet has been answered.
    expect(File(shared.single).existsSync(), isFalse);
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
    // A directory the delete cannot write to. `wipe` skips a file that is
    // merely absent, so removing it first would let the wipe *succeed* — which
    // is how this case used to pass while asserting nothing about the message.
    // `runSync`, not `run`: real async I/O started in a `testWidgets`
    // fake-async zone completes on a callback the zone never pumps, and the
    // test simply hangs.
    final holding = Directory(SqliteDb.path!).parent;
    Process.runSync('chmod', ['500', holding.path]);
    addTearDown(() => Process.runSync('chmod', ['700', holding.path]));

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
