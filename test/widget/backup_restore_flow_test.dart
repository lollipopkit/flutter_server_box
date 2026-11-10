/// `BackupService.restoreData`: which dialog a backup leads to.
///
/// A wrong password is an answer, not an error — the saved one, out of date,
/// asks for another without saying so; a typed one asks whether to try again —
/// and every other failure is said once, by the loading dialog. The backups are
/// the fixtures under `test/fixtures/backup/`, never regenerated.
///
/// `tester.runAsync` throughout the decrypt: the key derivation does not
/// complete inside the fake-async zone a `testWidgets` body runs in.
/// `pumpAndSettle` is avoided: the password field always has something
/// scheduled.
@Timeout(Duration(minutes: 3))
library;

import 'dart:convert';
import 'dart:io';

import 'package:fl_lib/fl_lib.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:server_box/core/extension/context/locale.dart';
import 'package:server_box/data/model/app/bak/backup_service.dart';
import 'package:server_box/generated/l10n/l10n.dart';

import '../helpers/test_db.dart';

const _dir = 'test/fixtures/backup';
const _pwd = 'fixture-password';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    await openTestDb();
    FlutterSecureStorage.setMockInitialValues({});
  });
  tearDown(closeTestDb);

  /// Lets real time pass for the decrypt, then the tree catch up, until
  /// [until] shows (or [until] is null and the work had its time).
  Future<void> settle(WidgetTester tester, [Finder? until]) async {
    for (var round = 0; round < 40; round++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 500)),
      );
      for (var i = 0; i < 5; i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }
      if (until == null ? round >= 3 : until.evaluate().isNotEmpty) return;
    }
  }

  /// A page that hands [data] to the restore, on its own navigator as every
  /// real caller is.
  Future<void> open(WidgetTester tester, List<int> data) async {
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: appLocalizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: Builder(
            builder: (ctx) => TextButton(
              onPressed: () => BackupService.restoreData(ctx, data),
              child: const Text('open'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await settle(tester, find.byWidgetPredicate((w) => w is TextField || w is ErrorView || (w is Text && (w.data ?? '').contains('${libL10n.restore} ${libL10n.backup}('))));
  }

  List<int> fixture(String name) => File('$_dir/$name').readAsBytesSync();

  final confirm = find.textContaining('${libL10n.restore} ${libL10n.backup}(');
  final passwordField = find.byType(TextField);
  final retry = find.text(l10n.backupPasswordWrong);
  final errorDialog = find.byType(ErrorView);

  testWidgets('a plain backup goes straight to the confirmation', (
    tester,
  ) async {
    await open(tester, utf8.encode(File('$_dir/backup_v4.json').readAsStringSync()));

    expect(confirm, findsOneWidget);
    expect(passwordField, findsNothing);
  });

  testWidgets('the saved password opens it without asking', (tester) async {
    FlutterSecureStorage.setMockInitialValues({
      SecureStoreProps.bakPwd.key: _pwd,
    });
    await open(tester, fixture('age_armored.txt'));

    expect(confirm, findsOneWidget);
    expect(passwordField, findsNothing);
  });

  testWidgets('a saved password that no longer fits asks, and nothing else', (
    tester,
  ) async {
    FlutterSecureStorage.setMockInitialValues({
      SecureStoreProps.bakPwd.key: 'an-old-password',
    });
    await open(tester, fixture('age_armored.txt'));

    expect(passwordField, findsOneWidget);
    expect(errorDialog, findsNothing);
    expect(retry, findsNothing);
  });

  testWidgets('a typed password that is wrong asks to try again, once', (
    tester,
  ) async {
    await open(tester, fixture('age_armored.txt'));
    expect(passwordField, findsOneWidget);

    await tester.enterText(passwordField, 'wrong');
    await tester.pump();
    await tester.tap(find.text(libL10n.ok).last);
    await settle(tester, retry);

    expect(retry, findsOneWidget);
    expect(errorDialog, findsNothing, reason: 'the retry is the only dialog');

    await tester.tap(find.text(libL10n.retry));
    await settle(tester, passwordField);
    await tester.enterText(passwordField, _pwd);
    await tester.pump();
    await tester.tap(find.text(libL10n.ok).last);
    await settle(tester, confirm);

    expect(confirm, findsOneWidget);
  });

  testWidgets('a file that does not read is said once', (tester) async {
    await open(tester, utf8.encode('not a backup'));

    expect(errorDialog, findsOneWidget);
    expect(confirm, findsNothing);
  });
}
