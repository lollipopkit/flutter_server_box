/// A dialog whose body is a plugin's tree. PLUGINS.md section 5.3.
///
/// The part with a decision in it is where the values live. **The plugin is
/// blocked while the dialog is up** — it called `sb.ui.prompt` and is waiting —
/// so it cannot answer events meanwhile, and the host has to hold what the
/// controls say. Two things follow, and both are what these check: a field's
/// starting value comes from the tree, and an untouched field still answers.
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:server_box/data/model/plugin/l10n.dart';
import 'package:server_box/data/model/plugin/node.dart';
import 'package:server_box/view/widget/plugin/dialog.dart';

PluginNode _tree(Object? json) => PluginNode.fromJson(json)!;

/// A form: a schedule, a command, and a choice.
Object? _editor({String when = '0 3 * * *'}) => {
  't': 'column',
  'c': [
    {
      't': 'input',
      'p': {'value': when, 'hint': 'l10n.fieldWhen'},
      'on': {'change': 'when'},
    },
    {
      't': 'input',
      'p': {'value': '/opt/backup.sh'},
      'on': {'change': 'command'},
    },
    {
      't': 'segmented',
      'p': {
        'value': 'cron',
        'options': [
          {'value': 'cron', 'label': 'Cron'},
          {'value': 'timer', 'label': 'Timer'},
        ],
      },
      'on': {'change': 'kind'},
    },
    // Not a field: no `change` message, so nobody asked for its value.
    {
      't': 'text',
      'p': {'value': 'Runs as you.'},
    },
  ],
};

void main() {
  Future<PluginNodeDialogState> open(WidgetTester tester, Object? json) async {
    final key = GlobalKey<PluginNodeDialogState>();
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: PluginNodeDialog(
            key: key,
            node: _tree(json),
            strings: const PluginL10n(fallback: {'fieldWhen': 'When'}),
          ),
        ),
      ),
    );
    return key.currentState!;
  }

  /// An editor opens with what is already there, and the user changes one
  /// field. Started empty, the untouched fields would come back blank and the
  /// save would wipe them.
  testWidgets('an untouched field answers with what it opened with', (
    tester,
  ) async {
    final dialog = await open(tester, _editor());

    expect(dialog.values, {
      'when': '0 3 * * *',
      'command': '/opt/backup.sh',
      'kind': 'cron',
    });
  });

  testWidgets('and a changed one answers with what was typed', (tester) async {
    final dialog = await open(tester, _editor());

    await tester.enterText(find.byType(TextField).first, '30 4 * * 0');
    await tester.tap(find.text('Timer'));
    await tester.pumpAndSettle();

    expect(dialog.values['when'], '30 4 * * 0');
    expect(dialog.values['kind'], 'timer');
    expect(dialog.values['command'], '/opt/backup.sh');
  });

  /// The body is drawn by the renderer, so it is the same controls a page is
  /// made of — including the translations.
  testWidgets('the body is drawn like any other surface', (tester) async {
    await open(tester, _editor());

    expect(find.text('When'), findsOneWidget);
    expect(find.text('Runs as you.'), findsOneWidget);
    expect(find.byType(SegmentedButton<String>), findsOneWidget);
  });

  /// A message that is not a name is not a field: the answer is a map of
  /// strings, and there is nothing to key an object by.
  testWidgets('a control whose message is not a name is not a field', (
    tester,
  ) async {
    final dialog = await open(tester, {
      't': 'column',
      'c': [
        {
          't': 'input',
          'p': {'value': 'x'},
          'on': {
            'change': {'m': 'when'},
          },
        },
      ],
    });

    await tester.enterText(find.byType(TextField).first, 'typed');
    expect(dialog.values, isEmpty);
  });
}
