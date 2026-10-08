import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:icons_plus/icons_plus.dart';
import 'package:material_ui/material_ui.dart';
import 'package:server_box/core/extension/context/locale.dart';
import 'package:server_box/data/model/server/server_private_info.dart';
import 'package:server_box/data/model/server/ssh_credential.dart';
import 'package:server_box/data/ssh/terminal_session.dart';
import 'package:server_box/data/ssh/terminal_source.dart';
import 'package:server_box/data/ssh/terminal_status.dart';
import 'package:server_box/data/ssh/tmux/tmux_ids.dart';
import 'package:server_box/view/widget/terminal_status_dot.dart';
import 'package:server_box/view/widget/terminal_status_sheet.dart';
import 'package:xterm/core.dart';

String b64(String text) => base64.encode(utf8.encode(text));

void main() {
  late TerminalSession session;

  setUp(() {
    session = TerminalSession(
      source: ServerSource(
        Spi(name: 'ssh', id: 'ssh', ssh: const SshCredential(ip: '10.0.0.1')),
      ),
    );
  });

  Future<void> pump(WidgetTester tester, Widget child) {
    return tester.pumpWidget(
      MaterialApp(
        locale: const Locale('en'),
        localizationsDelegates: appLocalizationsDelegates,
        home: Scaffold(appBar: AppBar(actions: [child])),
      ),
    );
  }

  testWidgets('the button shows only while something is reported', (
    tester,
  ) async {
    final live = ValueNotifier<TerminalSession?>(session);
    await pump(tester, TerminalStatusButton(session: live));
    expect(find.byType(TerminalStatusButton), findsOneWidget);
    expect(find.byTooltip(l10n.programStatus), findsNothing);

    session.status.shell.apply(
      ProgramStatusReport.parse([
        'state=blocked:kind=permission:title=${b64('Deploy')}:msg=${b64('Apply?')}',
      ])!,
    );
    await tester.pump();
    expect(find.byTooltip(l10n.programStatus), findsOneWidget);
  });

  testWidgets('the sheet lists the shell and each pane, and clears', (
    tester,
  ) async {
    final status = session.status;
    status.shell
      ..apply(ProgramStatusReport.parse(['state=done:app=cargo'])!)
      ..apply(const ShellMark(ShellMarkKind.commandFinished, exitCode: 2));
    status.applyPane(
      TmuxPaneId('%3'),
      ProgramStatusReport.parse([
        'state=working:id=eu:progress=40:title=${b64('EU')}',
      ])!,
    );

    await pump(
      tester,
      Builder(
        builder: (context) => IconButton(
          icon: const Icon(Icons.list),
          onPressed: () => showTerminalStatusSheet(
            context,
            status,
            paneLabel: (pane) => '1:logs',
          ),
        ),
      ),
    );
    await tester.tap(find.byIcon(Icons.list));
    await tester.pumpAndSettle();

    expect(find.text(l10n.programThisShell), findsOneWidget);
    expect(find.text('cargo'), findsOneWidget);
    expect(find.text(l10n.programCommandFailed(2)), findsOneWidget);
    expect(find.text('1:logs'), findsOneWidget);
    expect(find.text('EU'), findsOneWidget);
    expect(
      find.text(
        '${const TerminalStatusHeadline(state: ProgramState.working).stateLabel} 40%',
      ),
      findsOneWidget,
    );

    // Only what outlives its program can be cleared: `done` here.
    final clear = find.widgetWithIcon(IconButton, MingCute.close_line);
    await tester.ensureVisible(clear);
    await tester.pump();
    await tester.tap(clear);
    await tester.pump();
    expect(find.text('cargo'), findsNothing);
    expect(status.shell.records, isEmpty);
  });
}
