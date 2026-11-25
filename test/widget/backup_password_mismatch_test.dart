import 'dart:io';

import 'package:fl_lib/fl_lib.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:server_box/core/extension/context/locale.dart' as app_locale;
import 'package:server_box/data/store/stores.dart';
import 'package:server_box/generated/l10n/l10n.dart';
import 'package:server_box/generated/l10n/l10n_en.dart';
import 'package:server_box/view/page/backup.dart';
import 'package:server_box/view/page/setting/group.dart';
import 'package:server_box/view/widget/group_title.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    Paths.doc = Directory.systemTemp.createTempSync('sbm-backup-mismatch-').path;
  });
  tearDownAll(() => Directory(Paths.doc).deleteSync(recursive: true));

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await PrefStore.shared.init();
    FlutterSecureStorage.setMockInitialValues({});
    SqliteDb.openInMemory();
    await Stores.init();
  });

  tearDown(() async {
    SyncKeyring.resetForTest();
    SyncKeyring.init(label: 'ServerBox sync key');
    await getIt.reset();
    await SqliteDb.close();
  });

  Future<void> pumpPage(
    WidgetTester tester, {
    BackupSection? section = BackupSection.sync,
  }) async {
    tester.view.physicalSize = const Size(800, 2400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          locale: const Locale('en'),
          localizationsDelegates: const [...app_locale.appLocalizationsDelegates],
          supportedLocales: AppLocalizations.supportedLocales,
          builder: ResponsivePoints.builder,
          home: Builder(
            builder: (context) {
              app_locale.l10n = AppLocalizations.of(context)!;
              context.setLibL10n();
              return BackupPage(section: section);
            },
          ),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 300));
  }

  testWidgets("a password the remote's key does not open is said, and goes when it does", (tester) async {
    await pumpPage(tester);
    final said = find.text(AppLocalizationsEn().syncPasswordMismatch);
    expect(said, findsNothing);

    // Said where the sync's status is: with a destination on.
    await PrefProps.webdavSync.set(true);
    addTearDown(() => PrefProps.webdavSync.set(false));
    SyncKeyring.passwordMismatch.value = {'webdav:x'};
    await tester.pump();
    expect(said, findsOneWidget);

    SyncKeyring.release('webdav:x');
    await tester.pump();
    expect(said, findsNothing);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('sync, import, and standalone backup pages use SettingsGroupView', (
    tester,
  ) async {
    await pumpPage(tester, section: BackupSection.sync);
    expect(find.byType(PageColumns), findsOneWidget);
    expect(find.byType(SettingsGroupView), findsNWidgets(3));
    expect(find.byType(GroupTitle), findsNWidgets(3));
    expect(find.byType(CenterGreyTitle), findsNothing);
    expect(find.byIcon(Icons.unfold_more), findsOneWidget);

    // Enabling a destination adds its status/config/action rows inside the
    // existing Auto Sync SettingsGroupView card.
    await PrefProps.webdavSync.set(true);
    addTearDown(() => PrefProps.webdavSync.set(false));
    await tester.pump();
    expect(find.byType(SettingsGroupView), findsNWidgets(3));
    expect(find.text(libL10n.server), findsOneWidget);

    // Opening the synced-data sheet shows its title.
    await tester.tap(find.text(app_locale.l10n.syncedData));
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text(app_locale.l10n.syncedData), findsNWidgets(2));
    await tester.tapAt(const Offset(10, 10));
    await tester.pump(const Duration(milliseconds: 300));

    await pumpPage(tester, section: BackupSection.import);
    expect(find.byType(PageColumns), findsOneWidget);
    expect(find.byType(SettingsGroupView), findsOneWidget);
    expect(find.byType(GroupTitle), findsOneWidget);
    expect(find.byType(CenterGreyTitle), findsNothing);

    await pumpPage(tester, section: null);
    expect(find.byType(PageColumns), findsOneWidget);
    expect(find.byType(SettingsGroupView), findsNWidgets(4));
    expect(find.byType(GroupTitle), findsNWidgets(4));
    expect(find.byType(CenterGreyTitle), findsNothing);
    await tester.pumpWidget(const SizedBox.shrink());
  });
}
