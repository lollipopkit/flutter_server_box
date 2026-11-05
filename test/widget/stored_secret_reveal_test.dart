/// A saved password shows only after the app lock's authentication when that
/// lock is on; one being typed shows without asking.
library;

import 'dart:convert';

import 'package:fl_lib/fl_lib.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:server_box/core/extension/context/locale.dart' as app_locale;
import 'package:server_box/data/model/server/bmc_credential.dart';
import 'package:server_box/data/model/server/server_private_info.dart';
import 'package:server_box/data/provider/private_key.dart';
import 'package:server_box/data/provider/server/all.dart';
import 'package:server_box/data/store/bmc_credential.dart';
import 'package:server_box/data/store/private_key.dart';
import 'package:server_box/data/store/pve.dart';
import 'package:server_box/data/store/server.dart';
import 'package:server_box/data/store/setting.dart';
import 'package:server_box/data/store/stores.dart';
import 'package:server_box/generated/l10n/l10n.dart';
import 'package:server_box/view/page/bmc_credential/edit.dart';
import 'package:server_box/view/page/server/edit/edit.dart';

import '../helpers/spi_fixture.dart';
import '../helpers/test_db.dart';

const _secret = 'hunter2';

void main() {
  var auth = AuthResult.success;
  var asked = 0;

  setUp(() async {
    FlutterSecureStorage.setMockInitialValues({});
    await openTestDb();
    getIt.registerSingleton<SettingStore>(SettingStore('setting_test'));
    getIt.registerSingleton<ServerStore>(ServerStore());
    getIt.registerSingleton<PveStore>(PveStore());
    getIt.registerSingleton<PrivateKeyStore>(PrivateKeyStore());
    getIt.registerSingleton<BmcCredentialStore>(BmcCredentialStore());
    Stores.setting.useBioAuth.put(true);
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

  Future<void> pumpPage(WidgetTester tester, Widget page) async {
    await tester.pumpWidget(
      MaterialApp(
        builder: ResponsivePoints.builder,
        locale: const Locale('en'),
        localizationsDelegates: const [...app_locale.appLocalizationsDelegates],
        supportedLocales: AppLocalizations.supportedLocales,
        home: Builder(
          builder: (context) {
            app_locale.l10n = AppLocalizations.of(context)!;
            context.setLibL10n();
            return page;
          },
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 300));
  }

  Finder field(String text) => find.byWidgetPredicate(
    (w) => w is TextField && w.controller?.text == text,
  );

  bool masked(WidgetTester tester, String text) =>
      tester.widget<TextField>(field(text)).obscureText;

  Future<void> tapEye(WidgetTester tester, String text) async {
    final eye = find.descendant(
      of: find.ancestor(of: field(text), matching: find.byType(Input)),
      matching: find.byTooltip(libL10n.showPwd),
    );
    await tester.ensureVisible(eye);
    await tester.tap(eye);
    await tester.pump(const Duration(milliseconds: 300));
  }

  group('server editor', () {
    Widget editor(Spi server) => ProviderScope(
      overrides: [
        serversProvider.overrideWith(() => _Servers(server)),
        privateKeyProvider.overrideWithValue(const PrivateKeyState()),
      ],
      child: ServerEditPage(args: ServerEditArgs(server)),
    );

    testWidgets('a saved SSH password asks, and a failure keeps it hidden', (
      tester,
    ) async {
      final server = spiFixture(
        name: 's',
        id: 's1',
        ip: '10.0.0.1',
        pwd: _secret,
      );
      Stores.server.put(server);
      auth = AuthResult.fail;
      await pumpPage(tester, editor(server));

      await tapEye(tester, _secret);
      expect(asked, 1);
      expect(masked(tester, _secret), isTrue);

      auth = AuthResult.success;
      await tapEye(tester, _secret);
      expect(asked, 2);
      expect(masked(tester, _secret), isFalse);
    });

    testWidgets('a password typed for a server without one shows freely', (
      tester,
    ) async {
      final server = spiFixture(name: 's', id: 's1', ip: '10.0.0.1');
      Stores.server.put(server);
      await pumpPage(tester, editor(server));

      final pwd = find.widgetWithText(TextField, libL10n.pwd).first;
      await tester.ensureVisible(pwd);
      await tester.enterText(pwd, 'typed');
      await tester.pump();
      await tapEye(tester, 'typed');
      expect(asked, 0);
      expect(masked(tester, 'typed'), isFalse);
    });
  });

  group('BMC account', () {
    Widget page(BmcCredential? cred) => ProviderScope(
      child: BmcCredentialEditPage(args: BmcCredentialEditPageArgs(cred: cred)),
    );

    testWidgets('a saved password asks', (tester) async {
      auth = AuthResult.fail;
      await pumpPage(
        tester,
        page(const BmcCredential(id: 'c1', name: 'a', user: 'u', pwd: _secret)),
      );
      await tapEye(tester, _secret);
      expect(asked, 1);
      expect(masked(tester, _secret), isTrue);
    });

    testWidgets('a new account shows what is typed freely', (tester) async {
      await pumpPage(tester, page(null));
      await tester.enterText(
        find.widgetWithText(TextField, libL10n.pwd),
        'typed',
      );
      await tester.pump();
      await tapEye(tester, 'typed');
      expect(asked, 0);
      expect(masked(tester, 'typed'), isFalse);
    });
  });
}

final class _Servers extends ServersNotifier {
  _Servers(this.initial);

  final Spi initial;

  @override
  ServersState build() => ServersState(
    servers: {initial.id: initial},
    serverOrder: [initial.id],
  );

  @override
  Future<void> updateServer(Spi old, Spi newSpi) async {
    final persisted = Spi.fromJson(
      jsonDecode(jsonEncode(newSpi)) as Map<String, dynamic>,
    );
    state = state.copyWith(servers: {persisted.id: persisted});
  }
}
