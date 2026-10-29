/// A stored private key opens hidden, and shows only after the app lock's
/// authentication when that lock is on (#1730).
library;

import 'package:fl_lib/fl_lib.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:server_box/core/extension/context/locale.dart' as app_locale;
import 'package:server_box/core/utils/ssh_key_passphrase.dart';
import 'package:server_box/data/model/server/private_key_info.dart';
import 'package:server_box/data/provider/private_key.dart';
import 'package:server_box/data/res/store.dart';
import 'package:server_box/data/store/setting.dart';
import 'package:server_box/generated/l10n/l10n.dart';
import 'package:server_box/view/page/private_key/edit.dart';

import '../helpers/rust_lib_helper.dart';
import '../helpers/test_db.dart';

const _secret = 'b3BlbnNzaC1rZXktdjEAAAAABG5vbmUAAAAEbm9uZQ';
const _pki = PrivateKeyInfo(
  id: 'k1',
  name: 'work',
  key: '-----BEGIN OPENSSH PRIVATE KEY-----\n$_secret\n-----END OPENSSH PRIVATE KEY-----\n',
);

void main() {
  var auth = AuthResult.success;
  var asked = 0;

  setUpAll(initRustLibForTest);

  setUp(() async {
    FlutterSecureStorage.setMockInitialValues({});
    await openTestDb();
    getIt.registerSingleton<SettingStore>(SettingStore('setting_test'));
    asked = 0;
    auth = AuthResult.success;
    LocalAuth.isAvailForTest = () async => true;
    LocalAuth.goWithResultForTest = ({bool onlyBio = false}) async {
      asked++;
      return auth;
    };
  });

  tearDown(() async {
    LocalAuth.isAvailForTest = null;
    LocalAuth.goWithResultForTest = null;
    await getIt.reset();
    await closeTestDb();
  });

  Future<void> pumpEditor(WidgetTester tester, {PrivateKeyInfo? pki}) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [privateKeyProvider.overrideWithValue(const PrivateKeyState())],
        child: MaterialApp(
          locale: const Locale('en'),
          localizationsDelegates: const [...app_locale.appLocalizationsDelegates],
          supportedLocales: AppLocalizations.supportedLocales,
          home: Builder(
            builder: (context) {
              app_locale.l10n = AppLocalizations.of(context)!;
              context.setLibL10n();
              return PrivateKeyEditPage(args: PrivateKeyEditPageArgs(pki: pki));
            },
          ),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 300));
  }

  // The password field has a visibility toggle of its own.
  Finder showKey() => find.byTooltip(libL10n.view);
  Finder secret() => find.textContaining(_secret, findRichText: true);

  testWidgets('a stored key opens hidden', (tester) async {
    await pumpEditor(tester, pki: _pki);
    expect(secret(), findsNothing);
    expect(showKey(), findsOneWidget);
  });

  testWidgets('with the app lock on, showing it asks, and a failure keeps it hidden', (tester) async {
    Stores.setting.useBioAuth.put(true);
    auth = AuthResult.fail;
    await pumpEditor(tester, pki: _pki);

    await tester.tap(showKey());
    await tester.pump(const Duration(milliseconds: 300));
    expect(asked, 1);
    expect(secret(), findsNothing);

    auth = AuthResult.success;
    await tester.tap(showKey());
    await tester.pump(const Duration(milliseconds: 300));
    expect(asked, 2);
    expect(secret(), findsOneWidget);
  });

  testWidgets('with the app lock off, it shows without asking', (tester) async {
    await pumpEditor(tester, pki: _pki);
    await tester.tap(showKey());
    await tester.pump(const Duration(milliseconds: 300));
    expect(asked, 0);
    expect(secret(), findsOneWidget);
  });

  TextField pwdField(WidgetTester tester) =>
      tester.widget<TextField>(find.widgetWithText(TextField, libL10n.pwd));

  testWidgets('a kept passphrase is filled in, and shows behind the app lock', (tester) async {
    await tester.runAsync(() => KeyPassphrases.write(_pki.key, 'hunter2'));
    Stores.setting.useBioAuth.put(true);
    await pumpEditor(tester, pki: _pki);
    expect(find.widgetWithText(TextField, libL10n.pwd), findsNothing);

    await tester.tap(find.byTooltip(libL10n.showPwd));
    await tester.pump(const Duration(milliseconds: 300));
    expect(asked, 1);
    expect(pwdField(tester).controller!.text, 'hunter2');
  });

  testWidgets('a key being added is shown: the user just put it there', (tester) async {
    await pumpEditor(tester);
    expect(showKey(), findsNothing);
    expect(find.widgetWithText(TextField, app_locale.l10n.privateKey), findsOneWidget);
  });
}
