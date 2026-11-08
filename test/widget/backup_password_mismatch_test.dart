import 'dart:io';

import 'package:fl_lib/fl_lib.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:server_box/core/extension/context/locale.dart' as app_locale;
import 'package:server_box/core/sync/key.dart';
import 'package:server_box/core/sync/sync.dart';
import 'package:server_box/data/store/stores.dart';
import 'package:server_box/generated/l10n/l10n.dart';
import 'package:server_box/generated/l10n/l10n_en.dart';
import 'package:server_box/view/page/backup.dart';
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
    SyncKey.passwordMismatch.value = const {};
    BakSyncer.passwordRefused.value = false;
    await getIt.reset();
    await SqliteDb.close();
  });

  Future<void> pumpPage(WidgetTester tester) async {
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
              return const BackupPage();
            },
          ),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 300));
  }

  testWidgets('a password the synced key or backup does not open is said, and goes when it does', (tester) async {
    await pumpPage(tester);
    final said = find.text(AppLocalizationsEn().syncPasswordMismatch);
    expect(said, findsNothing);

    SyncKey.passwordMismatch.value = {'webdav:x'};
    await tester.pump();
    expect(said, findsOneWidget);

    // The backup's own failure, while it syncs somewhere; not once it does not.
    SyncKey.passwordMismatch.value = const {};
    BakSyncer.passwordRefused.value = true;
    await tester.pump();
    expect(said, findsNothing);
    await PrefProps.gistSync.set(true);
    addTearDown(() => PrefProps.gistSync.set(false));
    BakSyncer.passwordRefused.value = false;
    BakSyncer.passwordRefused.value = true;
    await tester.pump();
    expect(said, findsOneWidget);

    BakSyncer.passwordRefused.value = false;
    await tester.pump();
    expect(said, findsNothing);
    await tester.pumpWidget(const SizedBox.shrink());
  });
}
