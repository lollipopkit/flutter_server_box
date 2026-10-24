/// The trusted host certificate authorities, edited from the SSH settings
/// (#1783): added from a pasted key line, refused when it is not one, and
/// removed again.
library;

import 'package:fl_lib/fl_lib.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:server_box/core/extension/context/locale.dart' as app_locale;
import 'package:server_box/data/res/store.dart';
import 'package:server_box/data/store/server.dart';
import 'package:server_box/data/store/setting.dart';
import 'package:server_box/data/store/snippet.dart';
import 'package:server_box/generated/l10n/l10n.dart';
import 'package:server_box/generated/l10n/l10n_en.dart';
import 'package:server_box/view/page/setting/entry.dart';

import '../helpers/test_db.dart';

const _key = 'ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIPKE1+CXgaJMCIcTuFpYsKdP'
    'TXBAm8Uyi5w1k1ugCRgX ca@example.com';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final en = AppLocalizationsEn();

  setUp(() async {
    await openTestDb();
    getIt.registerSingleton<SettingStore>(SettingStore('setting_test'));
    getIt.registerSingleton<ServerStore>(ServerStore());
    getIt.registerSingleton<SnippetStore>(SnippetStore());
  });

  tearDown(() async {
    await getIt.reset();
    await SqliteDb.close();
  });

  /// In the editor, not elsewhere on the settings page.
  Finder inDialog(Finder finder) =>
      find.descendant(of: find.byType(AlertDialog).first, matching: finder);

  Future<void> frames(WidgetTester tester, [int n = 6]) async {
    for (var i = 0; i < n; i++) {
      await tester.pump(const Duration(milliseconds: 50));
    }
  }

  Future<void> openEditor(WidgetTester tester) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(900, 2400);
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          locale: const Locale('en'),
          localizationsDelegates: const [...app_locale.appLocalizationsDelegates],
          supportedLocales: AppLocalizations.supportedLocales,
          home: Builder(
            builder: (context) {
              app_locale.l10n = AppLocalizations.of(context)!;
              context.setLibL10n();
              return SettingsSectionPage.route.toWidget(
                args: SettingsSection.ssh,
              );
            },
          ),
        ),
      ),
    );
    await frames(tester);
    await tester.tap(find.text(en.hostCertAuthorities).first);
    await frames(tester);
  }

  /// The page down, and the timers it left running with it.
  Future<void> close(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 10));
  }

  Future<void> add(WidgetTester tester, String key, {String? hosts}) async {
    await tester.tap(find.text(libL10n.add));
    await frames(tester);
    final fields = find.byType(TextField);
    await tester.enterText(fields.first, key);
    if (hosts != null) await tester.enterText(fields.last, hosts);
    await tester.tap(find.text(libL10n.ok).last);
    await frames(tester);
  }

  testWidgets('a pasted key is added, with the hosts it vouches for',
      (tester) async {
    await openEditor(tester);
    expect(inDialog(find.text(libL10n.empty)), findsOneWidget);

    await add(tester, _key, hosts: '*.example.com');

    expect(Stores.setting.sshHostCertAuthorities.get().single.hosts,
        '*.example.com');
    // Told apart by type and comment, which is what a person reads.
    expect(inDialog(find.text('ssh-ed25519 ca@example.com')), findsOneWidget);
    expect(inDialog(find.text('*.example.com')), findsOneWidget);
    await close(tester);
  });

  testWidgets('what is not a key is refused, and the dialog says so',
      (tester) async {
    await openEditor(tester);

    await add(tester, 'not a key');

    expect(find.text(en.hostCertAuthorityInvalid), findsOneWidget);
    expect(Stores.setting.sshHostCertAuthorities.get(), isEmpty);
    await close(tester);
  });

  testWidgets('one is removed again', (tester) async {
    await openEditor(tester);
    await add(tester, _key);
    expect(Stores.setting.sshHostCertAuthorities.get(), hasLength(1));

    await tester.tap(find.byTooltip(libL10n.delete));
    await frames(tester);
    // Asked first: every host it vouches for goes back to being asked about.
    expect(Stores.setting.sshHostCertAuthorities.get(), hasLength(1));
    await tester.tap(find.text(libL10n.ok).last);
    await frames(tester);

    expect(Stores.setting.sshHostCertAuthorities.get(), isEmpty);
    expect(inDialog(find.text(libL10n.empty)), findsOneWidget);
    await close(tester);
  });
}
