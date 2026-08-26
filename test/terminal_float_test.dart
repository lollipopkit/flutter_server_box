import 'package:fl_lib/fl_lib.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:server_box/core/extension/context/locale.dart' as app_locale;
import 'package:server_box/data/model/ai/ask_ai_models.dart';
import 'package:server_box/data/model/app/float_shell.dart';
import 'package:server_box/data/provider/ai/agent_session.dart';
import 'package:server_box/data/provider/ai/agent_shell.dart';
import 'package:server_box/data/provider/app/terminal_shell.dart';
import 'package:server_box/data/res/store.dart';
import 'package:server_box/data/ssh/terminal_session.dart';
import 'package:server_box/data/ssh/terminal_source.dart';
import 'package:server_box/data/store/agent_conversation.dart';
import 'package:server_box/data/store/setting.dart';
import 'package:server_box/generated/l10n/l10n.dart';
import 'package:server_box/view/page/floating_panels.dart';
import 'package:server_box/view/page/ssh/float.dart';
import 'package:server_box/view/page/ssh/page/page.dart';
import 'package:xterm/ui.dart';

import 'helpers/fake_shell.dart';
import 'helpers/test_db.dart';

/// An [AgentSession] frozen at one state, as in `float_shell_view_test.dart`:
/// these tests are about the windows, not about the conversation.
class _FixedSession extends AgentSession {
  @override
  AgentSessionState build(String scope) =>
      const AgentSessionState(protocol: AskAiProtocol.chatCompletions);
}

/// A terminal popped out of its tab, and the two windows sharing a screen.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    await openTestDb();
    // In memory rather than on disk: floating writes the window's placement the
    // moment it changes, so these tests write.
    getIt.registerSingleton<SettingStore>(SettingStore.forTest());
    getIt.registerSingleton<AgentConversationStore>(
      AgentConversationStore.forTest(),
    );
    // The terminal page opens this over itself on a first run, and it would sit
    // over everything these tests are looking at.
    Stores.setting.sshTermHelpShown.put(true);
  });

  tearDown(() async {
    await getIt.reset();
    await SqliteDb.close();
  });

  /// Past the end of whatever is running.
  ///
  /// Counted out rather than `pumpAndSettle`: a terminal always has something
  /// scheduled, so that would wait out its ten-minute default.
  Future<void> settle(WidgetTester tester) async {
    for (var i = 0; i < 12; i++) {
      await tester.pump(const Duration(milliseconds: 50));
    }
  }

  ProviderContainer container() {
    final it = ProviderContainer(
      overrides: [globalAgentSessionProvider.overrideWith(_FixedSession.new)],
    );
    addTearDown(it.dispose);
    return it;
  }

  Widget app(ProviderContainer container, Widget Function(Size area) build) {
    return UncontrolledProviderScope(
      container: container,
      child: MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        builder: ResponsivePoints.builder,
        home: Builder(
          builder: (context) {
            app_locale.l10n = AppLocalizations.of(context)!;
            return Scaffold(
              body: LayoutBuilder(
                builder: (_, cons) => Stack(
                  fit: StackFit.expand,
                  children: [build(cons.biggest)],
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  group('the tab stands its terminal down', () {
    /// The tab's page and the floating window in one tree, the way the home
    /// page holds them: one above the other, both watching the same provider.
    Future<(ProviderContainer, TerminalSession)> pump(
      WidgetTester tester,
    ) async {
      // The view, not `setSurfaceSize`: the breakpoint that picks the desktop
      // panel over the phone sheet reads what `MediaQuery` reports.
      tester.view.physicalSize = const Size(1200, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);

      // A session handed to the page is one it adopts — already connected,
      // already running — so it opens no shell of its own, which is what keeps
      // this off a socket.
      final session = TerminalSession.over(
        const LocalSource(),
        FakeShellBackend(),
      );
      final it = container();

      await tester.pumpWidget(
        app(
          it,
          (area) => Stack(
            children: [
              SSHPage(
                args: SshPageArgs(source: const LocalSource(), session: session),
              ),
              TerminalFloatingShell(area: area),
            ],
          ),
        ),
      );
      await settle(tester);
      return (it, session);
    }

    testWidgets('there is never a second view on one terminal', (tester) async {
      // The whole reason the page draws a placeholder. Two `TerminalView`s on
      // one `Terminal` both resize it as they lay out, each undoing the other
      // on the next frame and sending the far side a `SIGWINCH` for every one.
      final (container, session) = await pump(tester);
      expect(find.byType(TerminalView), findsOneWidget);

      container.read(terminalShellProvider.notifier).float(
        session,
        title: 'shell',
      );
      // One frame, not a settled tree: the handover is what has to be clean.
      await tester.pump();
      expect(find.byType(TerminalView), findsOneWidget);

      await settle(tester);
      expect(find.byType(TerminalView), findsOneWidget);
      expect(find.text(app_locale.l10n.termInFloatWindow), findsOneWidget);

      container.read(terminalShellProvider.notifier).hide();
      await tester.pump();
      expect(find.byType(TerminalView), findsOneWidget);

      await settle(tester);
      expect(find.byType(TerminalView), findsOneWidget);
      expect(find.text(app_locale.l10n.termInFloatWindow), findsNothing);
    });

    testWidgets('and the window goes with the page that owned the session', (
      tester,
    ) async {
      final (container, session) = await pump(tester);
      container.read(terminalShellProvider.notifier).float(
        session,
        title: 'shell',
      );
      await settle(tester);
      expect(container.read(terminalShellProvider), isNotNull);

      // The page is what holds the session's output subscriptions, so a window
      // left open on it would be a terminal that silently stopped answering.
      await tester.pumpWidget(
        app(container, (area) => TerminalFloatingShell(area: area)),
      );
      await settle(tester);

      expect(container.read(terminalShellProvider), isNull);
    });
  });

  group('both windows at once', () {
    Future<(ProviderContainer, TerminalSession)> pumpPanels(
      WidgetTester tester, {
      required Size view,
    }) async {
      tester.view.physicalSize = view;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);

      final session = TerminalSession.over(
        const LocalSource(),
        FakeShellBackend(),
      );
      final it = container();

      await tester.pumpWidget(
        app(it, (area) => FloatingPanels(area: area)),
      );
      await settle(tester);
      return (it, session);
    }

    testWidgets('a phone keeps one expanded, because a sheet is the screen', (
      tester,
    ) async {
      final (container, session) = await pumpPanels(
        tester,
        view: const Size(390, 844),
      );

      container.read(terminalShellProvider.notifier).float(
        session,
        title: 'shell',
      );
      await settle(tester);
      expect(container.read(terminalShellProvider).mode, FloatShellMode.expanded);

      container.read(agentShellProvider.notifier).expand();
      await settle(tester);

      expect(
        container.read(terminalShellProvider)?.collapsed,
        isTrue,
        reason: 'the Agent covered a terminal that could not be got back',
      );
      expect(container.read(agentShellProvider), FloatShellMode.expanded);

      // And the other way round.
      container.read(terminalShellProvider.notifier).expand();
      await settle(tester);

      expect(container.read(agentShellProvider), FloatShellMode.collapsed);
      expect(container.read(terminalShellProvider).mode, FloatShellMode.expanded);
    });

    testWidgets('and never conjures a window that was not open', (tester) async {
      // `collapse` on a hidden Agent would *show* it: the three modes are one
      // value, and collapsed is a way of being on screen.
      final (container, session) = await pumpPanels(
        tester,
        view: const Size(390, 844),
      );
      expect(container.read(agentShellProvider), FloatShellMode.hidden);

      container.read(terminalShellProvider.notifier).float(
        session,
        title: 'shell',
      );
      await settle(tester);

      expect(container.read(agentShellProvider), FloatShellMode.hidden);
    });

    testWidgets('a desktop leaves both open', (tester) async {
      final (container, session) = await pumpPanels(
        tester,
        view: const Size(1400, 900),
      );

      container.read(terminalShellProvider.notifier).float(
        session,
        title: 'shell',
      );
      container.read(agentShellProvider.notifier).expand();
      await settle(tester);

      expect(container.read(agentShellProvider), FloatShellMode.expanded);
      expect(container.read(terminalShellProvider).mode, FloatShellMode.expanded);
    });
  });
}
