import 'package:fl_lib/fl_lib.dart';
import 'package:fl_lib/generated/l10n/lib_l10n.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:server_box/core/extension/context/locale.dart' as app_locale;
import 'package:server_box/data/model/ssh/virtual_key.dart';
import 'package:server_box/data/res/store.dart';
import 'package:server_box/data/store/setting.dart';
import 'package:server_box/generated/l10n/l10n.dart';
import 'package:server_box/view/page/setting/seq/virt_key.dart';

import 'helpers/test_db.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    await openTestDb();
    getIt.registerSingleton<SettingStore>(SettingStore('setting_test'));
  });

  tearDown(() async {
    await getIt.reset();
    await SqliteDb.close();
  });

  testWidgets('an unconfigured virtual key remains available to enable', (
    tester,
  ) async {
    Stores.setting.sshVirtKeys.put([VirtKey.esc.name]);

    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('en'),
        localizationsDelegates: const [
          LibLocalizations.delegate,
          ...AppLocalizations.localizationsDelegates,
        ],
        supportedLocales: AppLocalizations.supportedLocales,
        home: Builder(
          builder: (context) {
            app_locale.l10n = AppLocalizations.of(context)!;
            context.setLibL10n();
            return const SSHVirtKeySettingPage();
          },
        ),
      ),
    );
    addTearDown(() => tester.pumpWidget(const SizedBox.shrink()));

    await tester.scrollUntilVisible(
      find.text(VirtKey.underscore.text),
      300,
      scrollable: find.byType(Scrollable).last,
    );

    final row = find.ancestor(
      of: find.text(VirtKey.underscore.text),
      matching: find.byType(ListTile),
    );
    final checkbox = find.descendant(of: row, matching: find.byType(Checkbox));
    expect(tester.widget<Checkbox>(checkbox).value, isFalse);

    await tester.tap(checkbox);
    await tester.pump();

    expect(
      Stores.setting.sshVirtKeys.fetch(),
      contains(VirtKey.underscore.name),
    );
    expect(
      Stores.setting.sshVirtKeysDisabled.fetch(),
      isNot(contains(VirtKey.underscore.name)),
    );
  });
}
