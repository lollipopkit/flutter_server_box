import 'package:fl_lib/fl_lib.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:server_box/core/extension/context/locale.dart';
import 'package:server_box/view/page/server/detail/readout.dart';

/// The lines a card row draws from a command's output.
///
/// The output is served exactly as the command printed it, so a single-line
/// `echo` ends in `\n`. Reading that ending as a second line makes the row
/// tappable and opens a dialog holding the one line the row already shows, so
/// one trailing line ending is dropped before the output is split.
void main() {
  test('a single line ending in a newline is one line', () {
    expect(readoutCommandLines('single line\n'), ['single line']);
    expect(readoutCommandLines('single line\r\n'), ['single line']);
  });

  test('a multi-line output ending in a newline keeps its lines', () {
    expect(readoutCommandLines('first line\nsecond line\n'), [
      'first line',
      'second line',
    ]);
  });

  test('only the ending at the very end is dropped', () {
    // An inner blank line is part of the output.
    expect(readoutCommandLines('a\n\n'), ['a', '']);
    expect(readoutCommandLines('\n'), ['']);
  });

  test('an output with no trailing ending is unchanged', () {
    expect(readoutCommandLines('no newline'), ['no newline']);
    expect(readoutCommandLines('a\nb'), ['a', 'b']);
    expect(readoutCommandLines(''), ['']);
  });

  cardTests();
}

/// A card cut to its first [kReadoutCardRows] rows lists the rest on demand:
/// a host with nine sensors showed six, and nothing reached the other three.
void cardTests() {
  testWidgets('a cut-off card lists every row on demand', (tester) async {
    var full = false;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: StatefulBuilder(
              builder: (context, setState) => ServerDetailReadoutCard(
                icon: Icons.thermostat,
                title: 'Sensors',
                rows: [
                  for (var i = 0; i < 9; i++)
                    ServerDetailReadoutRow(k: 'sensor $i', v: ''),
                ],
                footer: readoutCountNote(9, 'sensors', full: full),
                expanded: true,
                full: full,
                onFull: () => setState(() => full = !full),
              ),
            ),
          ),
        ),
      ),
    );

    expect(find.text('sensor 5'), findsOneWidget);
    expect(find.text('sensor 6'), findsNothing);
    expect(find.text('6 of 9 sensors'), findsOneWidget);

    await tester.tap(find.text(l10n.showAllFmt(9)));
    await tester.pumpAndSettle();
    expect(find.text('sensor 8'), findsOneWidget);
    expect(find.text('9 sensors'), findsOneWidget);

    await tester.tap(find.text(libL10n.fold));
    await tester.pumpAndSettle();
    expect(find.text('sensor 6'), findsNothing);
  });

  testWidgets('a card that fits has no such row', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ServerDetailReadoutCard(
            icon: Icons.thermostat,
            title: 'Sensors',
            rows: [
              for (var i = 0; i < kReadoutCardRows; i++)
                ServerDetailReadoutRow(k: 'sensor $i', v: ''),
            ],
            expanded: true,
          ),
        ),
      ),
    );
    expect(find.text(l10n.showAllFmt(kReadoutCardRows)), findsNothing);
  });
}
