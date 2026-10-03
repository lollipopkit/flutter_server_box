/// The intro's Virtualization page: shown to every install that has not seen
/// feature revision 2, and saying more to one that had PVE configured.
///
/// Driven through the app's own intro rather than a seam onto its predicates:
/// what matters is the page a user is shown, and the two facts it reads are
/// facts about now, so they are asserted as the sentences that come out.
///
/// `introVer` stays 0, so the first-launch step always applies and there is
/// always an intro to look at — including in the case where the Virtualization
/// page has been seen, which is the one that would otherwise fall through to
/// the home page.
library;

import 'package:fl_lib/fl_lib.dart' show IntroPage;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:server_box/app.dart';
import 'package:server_box/core/extension/context/locale.dart' as app_locale;
import 'package:server_box/data/model/app/tab.dart';
import 'package:server_box/data/model/server/pve_config.dart';
import 'package:server_box/data/res/store.dart';
import 'package:server_box/data/store/pve.dart';
import 'package:server_box/data/store/server.dart';
import 'package:server_box/data/store/setting.dart';

import '../../helpers/spi_fixture.dart';
import '../../helpers/test_db.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    await openTestDb();
    getIt.registerSingleton<SettingStore>(SettingStore('setting_test'));
    getIt.registerSingleton<ServerStore>(ServerStore());
    getIt.registerSingleton<PveStore>(PveStore());
    FlutterSecureStorage.setMockInitialValues({});
    // A first launch: `introVer` 0 keeps the app-settings step applying, so
    // the intro is on screen whatever `featureIntroVer` says. `lastVer` 0
    // keeps the backup-password step off.
    Stores.setting.introVer.put(0);
    Stores.setting.lastVer.put(0);
    Stores.setting.diagnosticsConsentVer.put(999);
    Stores.setting.homeTabs.put([AppTab.server, AppTab.ssh]);
  });

  tearDown(() async {
    await getIt.reset();
    await closeTestDb();
  });

  /// Pumps the app and swipes through the intro's pages, answering whether the
  /// Virtualization page is one of them.
  ///
  /// Swiped rather than tapped: the last page's button ends the intro and
  /// builds the home page, which is another suite's subject, and the button's
  /// ink sparkle wants a shader stage the test backend does not carry.
  ///
  /// Unmounted first, because `MyApp` computes the page list once into a
  /// `late final`: a second pump of the same widget type would reuse the State
  /// and the list a previous revision produced.
  Future<bool> introShowsVirt(WidgetTester tester) async {
    tester.view.physicalSize = const Size(1280, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpWidget(const ProviderScope(child: MyApp()));
    await tester.pumpAndSettle();

    // The intro builds while its page list is being resolved.
    expect(find.byType(IntroPage), findsOneWidget, reason: 'no intro to look at');

    final title = app_locale.l10n.virtualization;
    // ` / N` is the page counter, drawn only when there is more than one page.
    final counter = find.byWidgetPredicate(
      (w) => w is Text && (w.data ?? '').startsWith(' / '),
    );
    final pages = counter.evaluate().isEmpty
        ? 1
        : int.parse(
            ((counter.evaluate().first.widget as Text).data!).substring(3),
          );

    for (var i = 0; i < pages; i++) {
      if (find.text(title).evaluate().isNotEmpty) return true;
      await tester.drag(find.byType(PageView), const Offset(-1400, 0));
      await tester.pumpAndSettle();
    }
    return find.text(title).evaluate().isNotEmpty;
  }

  testWidgets('is shown until feature revision 2 has been seen', (tester) async {
    // Revision 1: the page applies (it needs 2).
    Stores.setting.featureIntroVer.put(1);
    expect(await introShowsVirt(tester), isTrue);
    await tester.pumpWidget(const SizedBox.shrink());

    // Seen: it is not a page of the intro any more — while the intro itself is
    // still there, so this is not the absence of the whole thing.
    Stores.setting.featureIntroVer.put(2);
    expect(await introShowsVirt(tester), isFalse);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('says PVE moved only when a server has PVE, read at display time', (
    tester,
  ) async {
    Stores.setting.featureIntroVer.put(1);

    // No PVE row on any server: the sentence is not there at all.
    expect(await introShowsVirt(tester), isTrue);
    expect(find.textContaining(app_locale.l10n.virtIntroPveMoved), findsNothing);
    await tester.pumpWidget(const SizedBox.shrink());

    Stores.server.put(spiFixture(id: 'pve', name: 'pve', ip: 'h'));
    Stores.pve.put('pve', const PveConfig(addr: 'https://localhost:8006'));

    expect(await introShowsVirt(tester), isTrue);
    expect(
      find.textContaining(app_locale.l10n.virtIntroPveMoved),
      findsOneWidget,
    );
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('says where the tab is: the bar, or under more', (tester) async {
    // The sentence is part of the PVE block, so a PVE row is what brings it
    // within reach; what is asserted is which of the two it picks.
    Stores.setting.featureIntroVer.put(1);
    Stores.server.put(spiFixture(id: 'pve', name: 'pve', ip: 'h'));
    Stores.pve.put('pve', const PveConfig(addr: 'https://localhost:8006'));

    Stores.setting.homeTabs.put([AppTab.server, AppTab.virt]);
    expect(await introShowsVirt(tester), isTrue);
    expect(find.textContaining(app_locale.l10n.virtIntroInBar), findsOneWidget);
    await tester.pumpWidget(const SizedBox.shrink());

    Stores.setting.homeTabs.put([AppTab.server, AppTab.ssh]);
    expect(await introShowsVirt(tester), isTrue);
    expect(
      find.textContaining(app_locale.l10n.virtIntroInMore),
      findsOneWidget,
    );
    await tester.pumpWidget(const SizedBox.shrink());
  });
}
