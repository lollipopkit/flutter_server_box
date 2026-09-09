/// What a downgraded install is shown.
///
/// The refusal happens inside `_initApp`, before `runApp`, so until this page
/// existed the launch simply stopped: no window, no message. From the outside
/// that is a crash, and the one thing the user needed — *the data is intact,
/// reinstall the newer build* — was in a log file on the device.
library;

import 'dart:io';

import 'package:fl_lib/fl_lib.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:server_box/core/extension/context/locale.dart';
import 'package:server_box/data/store/schema.dart';
import 'package:server_box/view/page/schema_too_new.dart';

import 'helpers/test_db.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory tmp;

  // `Paths.doc` is `late` and refuses a second assignment, so it is set once
  // and its contents cleared per test instead.
  setUpAll(() async {
    tmp = await Directory.systemTemp.createTemp('schema-page-');
    Paths.doc = tmp.path;
  });

  tearDownAll(() {
    if (tmp.existsSync()) tmp.deleteSync(recursive: true);
  });

  setUp(() async {
    for (final e in tmp.listSync()) {
      e.deleteSync(recursive: true);
    }
    await openTestDb();
  });

  tearDown(closeTestDb);

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
      tmp.listSync().whereType<File>().where(
        (f) => f.path.contains('rescue'),
      ),
      isEmpty,
      reason: 'a copy was written before the user had answered',
    );
  });

  testWidgets('and writes one when the warning is accepted', (tester) async {
    await pump(tester);

    await tester.tap(find.text(l10n.schemaTooNewExportPlain));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    await tester.tap(find.text(libL10n.ok).last);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    final written = tmp
        .listSync()
        .whereType<File>()
        .where((f) => f.path.contains('rescue'))
        .toList();
    expect(written, hasLength(1));
    // Named for the version that wrote the data, which is what a future reader
    // has to match it against.
    expect(written.single.path, contains('v23'));
    expect(written.single.path, endsWith('-plain.db'));
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
    expect(find.text(libL10n.backup), findsNothing);
    expect(find.text(l10n.schemaTooNewWipe), findsNothing);
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
