import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_ce/hive.dart';
import 'package:riverpod/misc.dart' show Override;
import 'package:server_box/core/extension/context/locale.dart' as app_locale;
import 'package:server_box/data/model/ai/ask_ai_models.dart';
import 'package:server_box/data/provider/ai/agent_session.dart';
import 'package:server_box/data/res/store.dart';
import 'package:server_box/data/store/agent_conversation.dart';
import 'package:server_box/data/store/setting.dart';
import 'package:server_box/generated/l10n/l10n.dart';
import 'package:server_box/view/page/agent/view.dart';

/// An [AgentSession] frozen at one state.
///
/// The real one reaches for stored conversations in `build`; these tests are
/// about what a given state looks like on screen, not about how it got there.
class _FixedSession extends AgentSession {
  _FixedSession(this._state);

  final AgentSessionState _state;

  @override
  AgentSessionState build() => _state;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory tempDir;
  late Box<dynamic> settingBox;
  late Box<dynamic> conversationBox;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('server-box-agent-view-');
    Hive.init(tempDir.path);
    // In memory: the return-key tests below write the setting they are
    // about, and a real file write started inside a `testWidgets` body
    // completes on a callback the fake-async zone is no longer pumping —
    // so the box's write lock is never released and `close()` in tearDown
    // blocks forever, with no failure to say which file did it.
    settingBox = await Hive.openBox<dynamic>(
      'setting_test',
      bytes: Uint8List(0),
    );
    conversationBox = await Hive.openBox<dynamic>(
      'agent_conversation_test',
      bytes: Uint8List(0),
    );
    getIt.registerSingleton<SettingStore>(SettingStore.forBox(settingBox));
    getIt.registerSingleton<AgentConversationStore>(
      AgentConversationStore.forBox(conversationBox),
    );
  });

  tearDown(() async {
    await getIt.reset();
    await settingBox.close();
    await conversationBox.close();
    await tempDir.delete(recursive: true);
  });

  Future<void> pump(
    WidgetTester tester, {
    required Widget child,
    required Locale locale,
    List<Override> overrides = const [],
    Size surface = const Size(1200, 900),
  }) async {
    await tester.binding.setSurfaceSize(surface);
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      ProviderScope(
        overrides: overrides,
        child: MaterialApp(
          locale: locale,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Builder(
            builder: (context) {
              app_locale.l10n = AppLocalizations.of(context)!;
              return Scaffold(body: child);
            },
          ),
        ),
      ),
    );
    await tester.pump();
  }

  group('timeline notices follow the app language', () {
    // The reason Stage 1 could not simply move the timeline into a provider:
    // notices used to be built with `context.l10n` and stored as finished
    // text, so a conversation reopened after changing the language read in the
    // old one. They carry a reason now, and the sentence is chosen here.
    const state = AgentSessionState(
      protocol: AskAiProtocol.chatCompletions,
      timeline: [
        AgentNoticeEntry(AgentNoticeKind.declined),
        AgentNoticeEntry(AgentNoticeKind.interrupted),
      ],
    );

    Future<void> pumpIn(WidgetTester tester, Locale locale) => pump(
      tester,
      locale: locale,
      overrides: [
        agentSessionProvider.overrideWith(() => _FixedSession(state)),
      ],
      child: const AgentConversationView(compact: true, showHeader: false),
    );

    testWidgets('reads in English under en', (tester) async {
      await pumpIn(tester, const Locale('en'));
      final l10n = await AppLocalizations.delegate.load(const Locale('en'));

      expect(find.text(l10n.askAiActionDeclined), findsOneWidget);
      expect(find.text(l10n.askAiInterrupted), findsOneWidget);
    });

    testWidgets('reads in Chinese under zh, from the same state', (
      tester,
    ) async {
      await pumpIn(tester, const Locale('zh'));
      final zh = await AppLocalizations.delegate.load(const Locale('zh'));
      final en = await AppLocalizations.delegate.load(const Locale('en'));

      expect(find.text(zh.askAiActionDeclined), findsOneWidget);
      expect(find.text(zh.askAiInterrupted), findsOneWidget);
      // Guards the test itself: were the two languages to share a string, the
      // assertions above would pass without proving anything.
      expect(zh.askAiActionDeclined, isNot(en.askAiActionDeclined));
      expect(find.text(en.askAiActionDeclined), findsNothing);
    });
  });

  group('the return key follows the setting', () {
    // It used to follow the setting *and* the platform: on a phone the setting
    // was ignored, on the grounds that a soft keyboard has no Shift and so no
    // Shift+Enter to type a line break with. That is a reason to leave the
    // setting off, not a reason to override someone who turned it on — and a
    // phone is where reaching for the send button costs the most.
    const state = AgentSessionState(protocol: AskAiProtocol.chatCompletions);

    Future<TextInputAction?> actionWith(
      WidgetTester tester, {
      required bool sendOnEnter,
    }) async {
      Stores.setting.askAiSendOnEnter.put(sendOnEnter);
      await pump(
        tester,
        locale: const Locale('en'),
        overrides: [
          agentSessionProvider.overrideWith(() => _FixedSession(state)),
        ],
        child: const AgentConversationView(compact: true, showHeader: false),
      );
      return tester.widget<TextField>(find.byType(TextField)).textInputAction;
    }

    testWidgets('on, the keyboard offers send', (tester) async {
      expect(
        await actionWith(tester, sendOnEnter: true),
        TextInputAction.send,
        reason: 'this runs on no particular platform, and that is the point: '
            'the answer no longer depends on one',
      );
    });

    testWidgets('off, it offers a newline', (tester) async {
      expect(await actionWith(tester, sendOnEnter: false), TextInputAction.newline);
    });
  });
}
