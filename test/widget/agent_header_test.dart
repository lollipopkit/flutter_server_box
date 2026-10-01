import 'package:fl_lib/fl_lib.dart';
import 'package:fl_pi_llm_ui/fl_pi_llm_ui.dart' show ChatMeta, LlmStores;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:server_box/core/extension/context/locale.dart' as app_locale;
import 'package:server_box/core/llm/scope.dart';
import 'package:server_box/data/res/store.dart';
import 'package:server_box/data/store/setting.dart';
import 'package:server_box/generated/l10n/l10n.dart';
import 'package:server_box/view/page/agent/view.dart';

import '../helpers/test_db.dart';

/// The Agent tab's own line over the conversation.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    await openTestDb();
    getIt.registerSingleton<SettingStore>(SettingStore('setting_test'));
    LlmStores.chat.put(ChatMeta(id: 'chat-1', updatedAt: DateTime(2026)));
    AgentChats.select(null, 'chat-1');
  });

  tearDown(() async {
    AgentChats.startNew(null);
    await getIt.reset();
    await SqliteDb.close();
  });

  Future<void> pump(WidgetTester tester, {required bool compact}) async {
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          localizationsDelegates: app_locale.appLocalizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Builder(
            builder: (context) {
              app_locale.l10n = AppLocalizations.of(context)!;
              return Scaffold(body: AgentConversationView(compact: compact));
            },
          ),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 400));
  }

  Finder newChat(WidgetTester tester) => find.byWidgetPredicate(
    (w) =>
        w is Btn &&
        w.text ==
            app_locale.l10n.askAiNewConversation,
  );

  testWidgets('beside the list, the list carries the new-chat button', (
    tester,
  ) async {
    await pump(tester, compact: false);
    expect(newChat(tester), findsNothing);
  });

  testWidgets('without it, the line does, as a bar button', (tester) async {
    await pump(tester, compact: true);
    // The `Btn.icon` the other tabs' bars use, at their 18pt.
    expect(newChat(tester), findsOneWidget);
    final icon = tester.widget<Icon>(
      find.descendant(of: newChat(tester), matching: find.byType(Icon)),
    );
    expect(icon.size, 18);
  });
}
