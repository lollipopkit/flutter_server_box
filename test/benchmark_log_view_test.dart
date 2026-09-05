/// The benchmark log, rendered by a terminal rather than as text.
///
/// yabs animates its progress with carriage returns and `\e[0K`, so the same
/// bytes read as either three tidy lines or one run-on line full of mojibake,
/// depending entirely on what interprets them. Both failures below are silent:
/// nothing throws, the widget builds, and the output is simply wrong.
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:server_box/data/res/store.dart';
import 'package:server_box/data/store/setting.dart';
import 'package:server_box/view/page/benchmark/log_view.dart';
import 'package:xterm/xterm.dart';

import 'helpers/test_db.dart';

void main() {
  // The view takes its font and colours from the terminal settings, which are
  // read through the store like everywhere else in the app.
  setUp(() async {
    await openTestDb();
    getIt.registerSingleton<SettingStore>(SettingStore('setting_test'));
  });

  tearDown(() async {
    await getIt.reset();
    await closeTestDb();
  });

  /// The terminal the view is driving.
  Terminal terminalOf(WidgetTester tester) =>
      tester.widget<TerminalView>(find.byType(TerminalView)).terminal;

  /// One rendered row, as text.
  String row(WidgetTester tester, int i) =>
      terminalOf(tester).buffer.lines[i].getText();

  Future<void> pump(WidgetTester tester, Widget child) async {
    await tester.pumpWidget(MaterialApp(home: Scaffold(body: child)));
    await tester.pump();
  }

  testWidgets('a progress line is overwritten, not run together', (
    tester,
  ) async {
    // Exactly what the disk phase emits, and what the page used to show as
    // `Preparing… ␛[0KGenerating… ␛[0KRunning…` on one line.
    await pump(
      tester,
      const BenchmarkLogView(
        log: 'Preparing system for disk tests...\r\x1b[0K'
            'Generating fio test file...\r\x1b[0K'
            'Running fio random mixed R+W disk test with 4k block size...',
      ),
    );

    final first = row(tester, 0);
    expect(first, contains('Running fio random mixed'));
    expect(
      first,
      isNot(contains('Preparing system')),
      reason: 'the erase sequence did not erase anything',
    );
    expect(first, isNot(contains('[0K')));
  });

  testWidgets('a file\'s bare newlines do not staircase the output', (
    tester,
  ) async {
    // The log is a file, not a pty, so its lines end in `\n` alone. A terminal
    // reads that as "down one row" and not "back to column one", which walks
    // every line further right than the last.
    await pump(
      tester,
      const BenchmarkLogView(log: 'Uptime : 1 day\nProcessor : Xeon\n'),
    );

    expect(row(tester, 0), 'Uptime : 1 day');
    expect(
      row(tester, 1),
      'Processor : Xeon',
      reason: 'the second line was indented under the first',
    );
  });

  testWidgets('an update writes only what is new', (tester) async {
    // Every poll brings the whole log, not a delta. Writing all of it each time
    // would repeat the run once per poll — and replay its cursor movements
    // against lines they were not drawn for.
    await pump(tester, const BenchmarkLogView(log: 'one\n'));
    await pump(tester, const BenchmarkLogView(log: 'one\ntwo\n'));

    expect(row(tester, 0), 'one');
    expect(row(tester, 1), 'two');
    expect(row(tester, 2), isEmpty, reason: 'the log was written twice');
  });

  testWidgets('a log that is not an extension starts over', (tester) async {
    // A different run, or one whose directory was recreated. Appending would
    // interleave two transcripts.
    await pump(tester, const BenchmarkLogView(log: 'first run\n'));
    await pump(tester, const BenchmarkLogView(log: 'second run\n'));

    expect(row(tester, 0), 'second run');
    expect(row(tester, 1), isEmpty);
  });

  testWidgets('an empty log is not an error', (tester) async {
    await pump(tester, const BenchmarkLogView(log: ''));
    expect(tester.takeException(), isNull);
    expect(find.byType(TerminalView), findsOneWidget);
  });
}
