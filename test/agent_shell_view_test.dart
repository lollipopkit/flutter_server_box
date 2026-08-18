import 'dart:io';

import 'package:fl_lib/fl_lib.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:server_box/core/extension/context/locale.dart' as app_locale;
import 'package:server_box/data/model/ai/ask_ai_models.dart';
import 'package:server_box/data/provider/ai/agent_session.dart';
import 'package:server_box/data/provider/ai/agent_shell.dart';
import 'package:server_box/data/res/store.dart';
import 'package:server_box/data/store/agent_conversation.dart';
import 'package:server_box/data/store/setting.dart';
import 'package:server_box/generated/l10n/l10n.dart';
import 'package:server_box/view/page/agent/shell.dart';
import 'package:server_box/view/page/agent/view.dart';

/// An [AgentSession] frozen at one state, as in `agent_view_test.dart`: these
/// tests are about the window the conversation is shown in, not about the
/// conversation.
class _FixedSession extends AgentSession {
  @override
  AgentSessionState build() =>
      const AgentSessionState(protocol: AskAiProtocol.chatCompletions);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory tempDir;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('server-box-agent-shell-');
    SqliteDb.openInMemory();
    // In memory rather than on disk: the shell persists its mode the moment it
    // changes, so every test here writes, and none of them should leave a
    // database behind.
    getIt.registerSingleton<SettingStore>(SettingStore.forTest());
    getIt.registerSingleton<AgentConversationStore>(
      AgentConversationStore.forTest()..init(),
    );
  });

  tearDown(() async {
    await getIt.reset();
    await SqliteDb.close();
    await tempDir.delete(recursive: true);
  });

  /// Past the end of whatever is running.
  ///
  /// Counted out rather than `pumpAndSettle`: the conversation below carries a
  /// composer, and there is no frame in which nothing at all is scheduled.
  Future<void> settle(WidgetTester tester) async {
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pump(const Duration(milliseconds: 400));
  }

  /// The shell on a phone, in the stack the home page puts it in.
  Future<ProviderContainer> pumpPhone(WidgetTester tester) async {
    // The view, not `setSurfaceSize`: the latter changes what the tree is laid
    // out in but not what `MediaQuery` reports, and the breakpoint that picks
    // the pill and sheet over the desktop panel reads the latter. Sized the
    // other way these tests quietly exercised the desktop rendering.
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final container = ProviderContainer(
      overrides: [agentSessionProvider.overrideWith(_FixedSession.new)],
    );
    addTearDown(container.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(
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
                    children: [
                      const SizedBox.expand(),
                      AgentFloatingShell(area: cons.biggest),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
    await settle(tester);
    return container;
  }

  /// The sheet is the only one of the two renderings that holds a conversation.
  final sheet = find.byType(AgentConversationView);

  testWidgets('collapsing to the pill plays, rather than cutting', (
    tester,
  ) async {
    final container = await pumpPhone(tester);
    container.read(agentShellProvider.notifier).expand();
    await settle(tester);
    expect(sheet, findsOneWidget);

    container.read(agentShellProvider.notifier).collapse();
    await tester.pump();
    final start = tester.getTopLeft(sheet).dy;

    await tester.pump(const Duration(milliseconds: 80));
    expect(
      sheet,
      findsOneWidget,
      reason: 'the sheet leaves over time; it used to be gone the next frame',
    );
    expect(
      tester.getTopLeft(sheet).dy,
      greaterThan(start),
      reason: 'on its way down to the edge it came from',
    );

    await settle(tester);
    expect(
      sheet,
      findsNothing,
      reason: 'and once gone it stops watching the conversation',
    );
  });

  testWidgets('expanding from the pill plays too', (tester) async {
    final container = await pumpPhone(tester);
    container.read(agentShellProvider.notifier).collapse();
    await settle(tester);
    expect(sheet, findsNothing);

    container.read(agentShellProvider.notifier).expand();
    await tester.pump();
    final start = tester.getTopLeft(sheet).dy;

    await tester.pump(const Duration(milliseconds: 80));
    expect(tester.getTopLeft(sheet).dy, lessThan(start), reason: 'rising');

    await settle(tester);
    final settled = tester.getTopLeft(sheet).dy;
    expect(settled, lessThan(start));
    // Where a bottom sheet ends up: its own height above the bottom edge.
    expect(settled + tester.getSize(sheet).height, closeTo(844, 1));
  });

  testWidgets('hiding the shell does not also play a collapse', (tester) async {
    // Driving the expand animation from the mode alone would read `hidden` as
    // "not expanded" and slide the sheet down into a pill that is itself
    // fading away.
    final container = await pumpPhone(tester);
    container.read(agentShellProvider.notifier).expand();
    await settle(tester);
    final open = tester.getTopLeft(sheet).dy;

    container.read(agentShellProvider.notifier).hide();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 80));

    // Not exactly where it was — closing scales it a little as it fades — but
    // nowhere near the couple of hundred points a collapse covers in the same
    // 80ms.
    expect(tester.getTopLeft(sheet).dy - open, lessThan(40));

    await settle(tester);
    expect(sheet, findsNothing);
  });
}
