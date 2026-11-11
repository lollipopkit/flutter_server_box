import 'package:fl_lib/fl_lib.dart' show PromptSheet;
import 'package:fl_lib/generated/l10n/lib_l10n_en.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:server_box/data/terminal/tmux/tmux_ids.dart';
import 'package:server_box/generated/l10n/l10n.dart';
import 'package:server_box/generated/l10n/l10n_en.dart';
import 'package:server_box/view/page/ssh/widget/tmux_session_picker_sheet.dart';

void main() {
  final en = AppLocalizationsEn();
  final libEn = LibLocalizationsEn();
  final sessions = [
    TmuxPickerSession(
      id: TmuxSessionId(r'$0'),
      name: 'main',
      windowCount: 2,
      attached: true,
    ),
    TmuxPickerSession(
      id: TmuxSessionId(r'$1'),
      name: 'build',
      windowCount: 1,
      attached: false,
    ),
  ];

  testWidgets('shows existing sessions in the bottom sheet', (tester) async {
    await tester.pumpWidget(const _PickerHost());
    final context = tester.element(find.byType(Scaffold));
    final future = showTmuxSessionPickerSheet(
      context,
      sessions: sessions,
      defaultSessionName: 'server_box',
      selectedSessionId: TmuxSessionId(r'$0'),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.byType(BottomSheet), findsOneWidget);
    expect(find.byType(ListView), findsOneWidget);
    expect(
      tester.getTopLeft(find.byType(BottomSheet)).dy,
      greaterThan(tester.getSize(find.byType(Scaffold)).height / 2),
    );
    expect(find.text('main'), findsOneWidget);
    expect(find.text('${en.tmuxWindowCount(2)} · ${en.tmuxAttached}'), findsOneWidget);
    expect(find.text('build'), findsOneWidget);
    expect(find.text(en.tmuxWindowCount(1)), findsOneWidget);
    expect(find.byIcon(Icons.check), findsOneWidget);
    expect(find.text(en.tmuxSkip), findsNothing);
    expect(find.text(en.disconnect), findsNothing);
    expect(
      tester.getTopLeft(find.text(en.tmuxNewSession)).dy,
      lessThan(tester.getTopLeft(find.text('main')).dy),
    );
    final rows = find.byType(ListTile);
    final newRowRect = tester.getRect(rows.first);
    final existingSessionRect = tester.getRect(rows.at(1));
    expect(newRowRect.height, closeTo(existingSessionRect.height, 8));

    await tester.tap(find.text('build'));
    await tester.pump();
    final result = await future;
    expect(result, isA<TmuxPickExisting>());
    final existing = result as TmuxPickExisting;
    expect(existing.sessionId, TmuxSessionId(r'$1'));
    expect(existing.sessionName, 'build');
  });

  testWidgets('submits a new session from the sheet itself', (tester) async {
    await tester.pumpWidget(const _PickerHost());
    final context = tester.element(find.byType(Scaffold));
    final future = showTmuxSessionPickerSheet(
      context,
      sessions: sessions,
      defaultSessionName: 'server_box',
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    await tester.tap(find.text(en.tmuxNewSession));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.byType(PromptSheet), findsOneWidget);

    await tester.enterText(find.byType(TextField), ' work ');
    await tester.pump();
    await tester.tap(find.text(libEn.ok));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    final result = await future;
    expect(result, isA<TmuxPickNew>());
    expect((result as TmuxPickNew).sessionName, 'work');
  });

  testWidgets('a name confirmed after the sheet is gone is dropped', (
    tester,
  ) async {
    await tester.pumpWidget(const _PickerHost());
    final context = tester.element(find.byType(Scaffold));
    final future = showTmuxSessionPickerSheet(
      context,
      sessions: sessions,
      defaultSessionName: 'server_box',
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    await tester.tap(find.text(en.tmuxNewSession));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    // The name's sheet is above the picker on the root navigator; the picker
    // goes first, as when the page under it is torn down.
    final sheet = ModalRoute.of(tester.element(find.byType(BottomSheet).first))!;
    Navigator.of(context).removeRoute(sheet);
    await tester.pump();
    expect(await future, isNull);

    await tester.tap(find.text(libEn.ok));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(tester.takeException(), isNull);
    expect(find.byType(PromptSheet), findsNothing);
  });

  testWidgets('prefills a non-conflicting session name', (tester) async {
    final conflictedSessions = [
      TmuxPickerSession(
        id: TmuxSessionId(r'$0'),
        name: 'server_box',
        windowCount: 1,
        attached: false,
      ),
      TmuxPickerSession(
        id: TmuxSessionId(r'$1'),
        name: 'server_box-2',
        windowCount: 1,
        attached: false,
      ),
    ];
    await tester.pumpWidget(const _PickerHost());
    final context = tester.element(find.byType(Scaffold));
    final future = showTmuxSessionPickerSheet(
      context,
      sessions: conflictedSessions,
      defaultSessionName: 'server_box',
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text('server_box-3'), findsOneWidget);
    await tester.tap(find.text(en.tmuxNewSession));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    final field = tester.widget<TextField>(find.byType(TextField));
    expect(field.controller?.text, 'server_box-3');
    await tester.tap(find.text(libEn.ok));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    final result = await future;
    expect(result, isA<TmuxPickNew>());
    expect((result as TmuxPickNew).sessionName, 'server_box-3');
  });

  testWidgets('warns when the new session name conflicts', (tester) async {
    await tester.pumpWidget(const _PickerHost());
    final context = tester.element(find.byType(Scaffold));
    final future = showTmuxSessionPickerSheet(
      context,
      sessions: sessions,
      defaultSessionName: 'server_box',
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    await tester.tap(find.text(en.tmuxNewSession));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    await tester.enterText(find.byType(TextField), 'main');
    await tester.pump();
    expect(find.text(en.nameAlreadyExistsFmt('main')), findsOneWidget);
    final okay = tester.widget<TextButton>(
      find.widgetWithText(TextButton, libEn.ok),
    );
    expect(okay.onPressed, isNull);

    await tester.enterText(find.byType(TextField), 'work');
    await tester.pump();
    expect(find.text(en.nameAlreadyExistsFmt('main')), findsNothing);
    await tester.tap(find.text(libEn.ok));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    final result = await future;
    expect(result, isA<TmuxPickNew>());
    expect((result as TmuxPickNew).sessionName, 'work');
  });

  testWidgets('offers skipping only where it is meaningful', (tester) async {
    await tester.pumpWidget(const _PickerHost());
    final context = tester.element(find.byType(Scaffold));
    final future = showTmuxSessionPickerSheet(
      context,
      sessions: sessions,
      defaultSessionName: 'server_box',
      showSkip: true,
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    await tester.tap(find.text(en.tmuxSkip));
    await tester.pump();
    expect(await future, isA<TmuxPickSkip>());
  });

  testWidgets('offers detaching only for an attached client', (tester) async {
    await tester.pumpWidget(const _PickerHost());
    final context = tester.element(find.byType(Scaffold));
    final future = showTmuxSessionPickerSheet(
      context,
      sessions: sessions,
      defaultSessionName: 'server_box',
      showDetach: true,
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text(en.disconnect), findsOneWidget);
    await tester.tap(find.text(en.disconnect));
    await tester.pump();
    expect(await future, isA<TmuxPickDetach>());
  });
}

final class _PickerHost extends StatelessWidget {
  const _PickerHost();

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      locale: const Locale('en'),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: const Scaffold(body: SizedBox.expand()),
    );
  }
}
