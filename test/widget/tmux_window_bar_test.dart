import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:fl_lib/fl_lib.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:server_box/data/model/server/shell_backend.dart';
import 'package:server_box/data/ssh/tmux/tmux_control_client.dart';
import 'package:server_box/data/ssh/tmux/tmux_control_models.dart';
import 'package:server_box/data/ssh/tmux/tmux_ids.dart';
import 'package:server_box/generated/l10n/l10n.dart';
import 'package:server_box/view/widget/tmux_window_bar.dart';

void main() {
  testWidgets('renders native tmux windows and reports selection', (
    tester,
  ) async {
    final shell = _FakeTmuxShell();
    final client = TmuxControlClient(shell);
    await tester.runAsync<void>(() async {
      final initialized = client.initialize();
      shell.emit('\x1bP1000p%begin 1 100 1\n%end 1 100 1\n');
      await initialized;
    });

    TmuxControlWindow? selected;
    TmuxControlWindow? closed;
    TmuxControlPane? selectedPane;
    TmuxControlPane? closedPane;
    var newWindowTaps = 0;
    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('en'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(
            context,
          ).copyWith(padding: const EdgeInsets.only(top: 27)),
          child: child!,
        ),
        home: Scaffold(
          body: TmuxWindowBar(
            client: client,
            onSelectWindow: (window) => selected = window,
            onSelectPane: (pane) => selectedPane = pane,
            onNewWindow: () => newWindowTaps++,
            onCloseWindow: (window) => closed = window,
            onClosePane: (pane) => closedPane = pane,
          ),
        ),
      ),
    );

    expect(find.text('main'), findsOneWidget);
    expect(tester.getTopLeft(find.text('main')).dy, greaterThanOrEqualTo(27));
    expect(find.text('0:shell'), findsOneWidget);
    expect(find.text('1:logs'), findsOneWidget);

    await tester.tap(find.text('1:logs'));
    await tester.pump();

    expect(selected?.id, TmuxWindowId('@1'));
    expect(newWindowTaps, 0);

    await tester.tap(find.byTooltip('New window'));
    expect(newWindowTaps, 1);

    await tester.tap(find.byTooltip('Delete'));
    expect(closed?.id, TmuxWindowId('@0'));

    shell.splitPanes = true;
    await tester.runAsync(() => client.refreshState());
    await tester.pump();

    expect(find.text('1/2'), findsOneWidget);
    // Named for a screen reader: which pane is on screen, of how many.
    final semantics = tester.ensureSemantics();
    expect(find.bySemanticsLabel('0:top 1/2'), findsOneWidget);
    semantics.dispose();
    expect(find.text('0:top'), findsNothing);
    expect(find.text('1:tail'), findsNothing);

    await tester.tap(find.text('1/2'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.byType(RowsSheet), findsNothing);
    expect(find.text('0:top'), findsOneWidget);
    expect(find.text('1:tail'), findsOneWidget);
    expect(
      tester.getTopLeft(find.text('0:top')).dy,
      lessThan(tester.getSize(find.byType(Scaffold)).height / 2),
    );

    await tester.tap(find.text('1:tail'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(selectedPane?.id, TmuxPaneId('%3'));

    await tester.tap(find.text('1/2'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    await tester.tap(find.byKey(const ValueKey('close_tmux_pane_%0')).first);
    await tester.pump();
    expect(closedPane?.id, TmuxPaneId('%0'));

    await tester.runAsync(() async {
      await client.dispose();
      shell.close();
    });
  });
}

final class _FakeTmuxShell implements ShellSession {
  final _stdout = StreamController<Uint8List>.broadcast(sync: true);
  final _done = Completer<void>();
  final writes = <String>[];
  bool splitPanes = false;
  int historyLimit = 100000;

  @override
  Stream<Uint8List>? get stdout => _stdout.stream;

  @override
  Stream<Uint8List>? get stderr => null;

  @override
  Future<void> get done => _done.future;

  @override
  void write(List<int> data) {
    final command = utf8.decode(data).trim();
    if (command.isEmpty) return;
    writes.add(command);
    if (command.startsWith('display-message')) {
      _result('\$0\tmain\t$historyLimit');
    } else if (command.startsWith('list-sessions')) {
      _result(r'$0	main	2	1');
    } else if (command.startsWith('list-windows')) {
      _result('@0	0	shell	1\n@1	1	logs	0');
    } else if (command.startsWith('list-panes -s')) {
      _result(splitPanes ? '%0\t@0\n%3\t@0' : '%0\t@0');
    } else if (command.startsWith('list-panes')) {
      if (splitPanes) {
        _result('%0	0	1	top	cat\n%3	1	0	tail	cat');
      } else {
        _result('%0	0	1	top	cat');
      }
    } else if (command.startsWith('capture-pane')) {
      _result('%0 prompt');
    } else {
      _result('');
    }
  }

  @override
  void resizeTerminal(int width, int height) {}

  @override
  void close() {
    unawaited(_stdout.close());
    if (!_done.isCompleted) _done.complete();
  }

  void emit(String data) => _stdout.add(utf8.encode(data));

  void _result(String output) {
    final id = writes.length;
    emit('%begin 1 $id 1\n$output\n%end 1 $id 1\n');
  }
}
