/// Drawing a plugin's tree. PLUGINS.md section 5.
///
/// Most of these are about the three things section 5.2 adds to the node
/// format, because those are the ones with a mechanism behind them and a
/// failure that looks like nothing: a revision that reuses the wrong widget
/// shows stale numbers, a binding that rebuilds too much is only visible in a
/// profile, and a list that materialises builds four hundred rows for a screen
/// that holds twelve.
library;

import 'package:fl_chart/fl_chart.dart';
import 'package:fl_lib/fl_lib.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:server_box/data/model/plugin/l10n.dart';
import 'package:server_box/data/model/plugin/node.dart';
import 'package:server_box/view/widget/plugin/render.dart';
import 'package:server_box/view/widget/plugin/surface.dart';

final _harness = GlobalKey<_HarnessState>();

/// Pumps a tree and lets the test replace it, the way a tick does.
class _Harness extends StatefulWidget {
  const _Harness({super.key, required this.state, required this.first, this.onEvent});

  final PluginSurfaceState state;
  final PluginNode first;
  final void Function(Object? msg, Object? value)? onEvent;

  @override
  State<_Harness> createState() => _HarnessState();
}

class _HarnessState extends State<_Harness> {
  late PluginNode _tree = widget.first;

  /// How many times the renderer's own build has run.
  int builds = 0;

  void show(PluginNode tree) => setState(() => _tree = tree);

  @override
  Widget build(BuildContext context) {
    builds++;
    return PluginRenderer(
      tree: _tree,
      state: widget.state,
      onEvent: widget.onEvent,
    );
  }
}

Future<PluginSurfaceState> pump(
  WidgetTester tester,
  Object? json, {
  PluginSurfaceState? state,
  void Function(Object? msg, Object? value)? onEvent,
}) async {
  final surface = state ?? PluginSurfaceState();
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: _Harness(
          key: _harness,
          state: surface,
          first: PluginNode.fromJson(json)!,
          onEvent: onEvent,
        ),
      ),
    ),
  );
  return surface;
}

Future<void> show(WidgetTester tester, Object? json) async {
  _harness.currentState!.show(PluginNode.fromJson(json)!);
  await tester.pump();
}

Map<String, Object?> text(String value, {int? v, String? k}) => {
  't': 'text',
  'p': {'value': value},
  'v': ?v,
  'k': ?k,
};

Map<String, Object?> stub(String type, int v, {String? k}) => {
  't': type,
  'v': v,
  's': 1,
  'k': ?k,
};

void main() {
  group('the node format', () {
    test('a stub is told apart from a node that simply carries nothing', () {
      // `spacer` and `divider` look the same from outside — reading the shape
      // rather than the absence of `p` and `c` made one of those replacing a
      // real node count as "you already have this".
      expect(PluginNode.fromJson(stub('column', 7))!.stub, isTrue);
      // A spacer carries no properties and no children, so the marker is the
      // only thing that separates one from "reuse what you have".
      expect(PluginNode.fromJson({'t': 'spacer', 'v': 7})!.stub, isFalse);
      expect(PluginNode.fromJson(stub('spacer', 7))!.stub, isTrue);
      expect(
        PluginNode.fromJson({'t': 'spacer', 's': 1})!.stub,
        isFalse,
        reason: 'no revision is nothing to reuse',
      );
      expect(PluginNode.fromJson(text('a', v: 7))!.stub, isFalse);
    });

    test('a child that will not parse costs that child', () {
      final node = PluginNode.fromJson({
        't': 'column',
        'c': [text('a'), 'not a node', {'no': 'type'}, text('b')],
      })!;

      expect(node.children.map((c) => c.props['value']), ['a', 'b']);
    });

    test('a tree that is not JSON is null rather than a throw', () {
      expect(PluginNode.parse('{'), isNull);
      expect(PluginNode.parse('[]'), isNull);
      expect(PluginNode.fromJson({'t': ''}), isNull);
    });

    test('it can say which slots and which revisions it uses', () {
      final node = PluginNode.fromJson({
        't': 'column',
        'v': 1,
        'c': [
          {'t': 'kv', 'v': 2, 'p': {'k': 'CPU', 'v': {r'$': 'cpu'}}},
          {'t': 'text', 'v': 3, 'p': {'value': {r'$': 'up'}}},
          text('fixed', v: 4),
        ],
      })!;

      expect(node.boundSlots(), {'cpu', 'up'});
      expect(node.revisions(), {1, 2, 3, 4});
    });
  });

  group('translations', () {
    const l10n = PluginL10n(
      active: {'greet': '你好，{0}', 'only': '仅此'},
      fallback: {'greet': 'Hello, {0}', 'only': 'only', 'en_only': 'English'},
    );

    test('anything not starting l10n. is shown as typed', () {
      expect(l10n.resolve('zpool list'), 'zpool list');
      expect(l10n.resolve(''), '');
    });

    test('the active locale wins, and en is the fallback', () {
      expect(l10n.resolve('l10n.only'), '仅此');
      expect(l10n.resolve('l10n.en_only'), 'English');
    });

    /// The whole sentence is in the translation file and only the values
    /// cross, so a plugin cannot assemble something unnatural out of
    /// fragments.
    test('arguments are substituted into the translation', () {
      expect(l10n.resolve('l10n.greettank'), '你好，tank');
    });

    /// Showing the key is the one answer that says where to look. An empty
    /// string would be a card with a blank row.
    test('a key with no translation shows the key', () {
      expect(l10n.resolve('l10n.missing'), 'l10n.missing');
      expect(PluginL10n.empty.resolve('l10n.greetx'), 'l10n.greet');
    });

    test('a file that will not parse contributes nothing', () {
      expect(PluginL10n.parse('{'), isEmpty);
      expect(PluginL10n.parse('{"a": 1, "b": "ok"}'), {'b': 'ok'});
    });
  });

  group('revisions', () {
    /// The whole point: the app hands back the *same* Widget instance, which
    /// is what makes `Element.updateChild` return without walking the subtree.
    testWidgets('a stub reuses the widget instance', (tester) async {
      final state = await pump(tester, {
        't': 'column',
        'v': 1,
        'c': [text('first', v: 2)],
      });
      final built = state.widgetOf(2);
      expect(built, isNotNull);

      await show(tester, {
        't': 'column',
        'v': 3,
        'c': [stub('text', 2)],
      });

      expect(identical(state.widgetOf(2), built), isTrue);
      expect(find.text('first'), findsOneWidget);
    });

    /// A plugin that believes the app holds a subtree it does not. Nothing
    /// here can invent it, so it is reported where it happened rather than
    /// drawn as a gap.
    testWidgets('a revision the app never had is reported', (tester) async {
      await pump(tester, {
        't': 'column',
        'v': 1,
        'c': [stub('text', 99)],
      });

      expect(find.textContaining('stale revision 99'), findsOneWidget);
    });

    /// Without this a surface open for an hour remembers every widget it ever
    /// built. Safe because a revision absent from the current tree can never
    /// be named again — the plugin's own previous tree no longer holds it.
    testWidgets('a revision the tree no longer names is dropped', (tester) async {
      final state = await pump(tester, {
        't': 'column',
        'v': 1,
        'c': [text('a', v: 2), text('b', v: 3)],
      });
      expect(state.widgetOf(2), isNotNull);

      await show(tester, {
        't': 'column',
        'v': 4,
        'c': [text('a', v: 2)],
      });

      expect(state.widgetOf(2), isNotNull, reason: 'still named');
      expect(state.widgetOf(3), isNull, reason: 'no longer reachable');
    });
  });

  group('value bindings', () {
    /// A refresh that answers `values` and no tree: nothing above the bound
    /// leaf is rebuilt, no element is walked, and only the leaf's own render
    /// object is marked dirty. The renderer's build count is what says so.
    testWidgets('a value changes without rebuilding the tree', (tester) async {
      final state = await pump(tester, {
        't': 'column',
        'v': 1,
        'c': [
          {'t': 'kv', 'v': 2, 'p': {'k': 'CPU', 'v': {r'$': 'cpu'}}},
        ],
      });
      state.applyValues({'cpu': '12%'});
      await tester.pump();
      expect(find.text('12%'), findsOneWidget);

      final before = _harness.currentState!.builds;
      state.applyValues({'cpu': '87%'});
      await tester.pump();

      expect(find.text('87%'), findsOneWidget);
      expect(
        _harness.currentState!.builds,
        before,
        reason: 'the renderer was not rebuilt at all',
      );
    });

    testWidgets('a property that holds a value is not a binding', (tester) async {
      final state = await pump(tester, {
        't': 'kv',
        'v': 1,
        'p': {'k': 'CPU', 'v': '5%'},
      });

      state.applyValues({'cpu': '99%'});
      await tester.pump();

      expect(find.text('5%'), findsOneWidget);
    });
  });

  group('lists', () {
    /// `ListView.builder` builds what is on screen. A materialised list of
    /// four hundred rows builds four hundred widgets for a screen holding
    /// twelve, which is the thing the window exists to avoid.
    testWidgets('a windowed list builds only what fits', (tester) async {
      await pump(tester, {
        't': 'sized',
        'v': 1,
        'p': {'height': 300.0},
        'c': [
          {
            't': 'list',
            'v': 2,
            'p': {'count': 400, 'from': 0},
            'c': [
              for (var i = 0; i < 40; i++)
                {'t': 'kv', 'k': 'row-$i', 'v': 100 + i, 'p': {'k': 'row $i', 'v': '$i'}},
            ],
          },
        ],
      });

      expect(find.text('row 0'), findsOneWidget);
      expect(
        find.text('row 39'),
        findsNothing,
        reason: 'off screen, so never built',
      );
    });

    /// A row the window does not carry is a placeholder rather than an error:
    /// `listWindow` answers during a scroll, so it cannot be waited on.
    testWidgets('a row outside the window is a placeholder', (tester) async {
      await pump(tester, {
        't': 'sized',
        'v': 1,
        'p': {'height': 300.0},
        'c': [
          {
            't': 'list',
            'v': 2,
            'p': {'count': 100, 'from': 50},
            'c': [
              {'t': 'kv', 'k': 'r50', 'v': 3, 'p': {'k': 'row 50', 'v': 'x'}},
            ],
          },
        ],
      });

      // Row 0 is before the window, so nothing was given for it.
      expect(find.text('row 50'), findsNothing);
      expect(find.byType(KvRow), findsNothing);
    });

    testWidgets('with no window the rows given are the whole list', (tester) async {
      await pump(tester, {
        't': 'list',
        'v': 1,
        'c': [
          {'t': 'kv', 'k': 'a', 'v': 2, 'p': {'k': 'a', 'v': '1'}},
          {'t': 'kv', 'k': 'b', 'v': 3, 'p': {'k': 'b', 'v': '2'}},
        ],
      });

      expect(find.byType(KvRow), findsNWidgets(2));
    });
  });

  /// The set a page needs before it can look like the app around it: where
  /// things sit, how large the type is, and which of the two button weights it
  /// is. Each is a name rather than a number, so the app decides what it looks
  /// like — the same rule as `tone`.
  group('layout and type', () {
    testWidgets('a row and a column take named alignments', (tester) async {
      await pump(tester, {
        't': 'row',
        'p': {'main': 'between', 'cross': 'end'},
        'c': [text('a'), text('b')],
      });

      final row = tester.widget<Row>(find.byType(Row));
      expect(row.mainAxisAlignment, MainAxisAlignment.spaceBetween);
      expect(row.crossAxisAlignment, CrossAxisAlignment.end);
    });

    /// A column is `min` by default — a settings page whose whole content is
    /// one switch used to draw a card down the window. But an alignment only
    /// means anything with room to distribute, so asking for one is asking to
    /// fill.
    testWidgets('a column asked to distribute fills its axis', (tester) async {
      await pump(tester, {'t': 'column', 'c': [text('a')]});
      expect(
        tester.widget<Column>(find.byType(Column)).mainAxisSize,
        MainAxisSize.min,
      );

      await show(tester, {
        't': 'column',
        'p': {'main': 'center'},
        'c': [text('a')],
      });
      expect(
        tester.widget<Column>(find.byType(Column)).mainAxisSize,
        MainAxisSize.max,
      );
    });

    testWidgets('padding is all four sides or any one of them', (tester) async {
      await pump(tester, {
        't': 'padding',
        'p': {'all': 4, 't': 12},
        'c': [text('a')],
      });

      final padding = tester.widget<Padding>(
        find.ancestor(of: find.text('a'), matching: find.byType(Padding)).first,
      );
      expect(
        padding.padding.resolve(TextDirection.ltr),
        const EdgeInsets.fromLTRB(4, 12, 4, 4),
      );
    });

    /// Flutter throws at layout time for a `Positioned` outside a `Stack` and
    /// an `Expanded` outside a `Flex`, and that throw takes the whole surface
    /// — so both degrade to the child instead. A plugin can write either in
    /// the wrong place, and a bad node costs that node.
    testWidgets('a positioned outside a stack is just its child', (
      tester,
    ) async {
      await pump(tester, {
        't': 'card',
        'c': [
          {
            't': 'positioned',
            'p': {'t': 0},
            'c': [text('badge')],
          },
        ],
      });

      expect(find.text('badge'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('and inside one it is positioned', (tester) async {
      await pump(tester, {
        't': 'stack',
        'c': [
          text('under'),
          {
            't': 'positioned',
            'p': {'t': 2, 'r': 3},
            'c': [text('badge')],
          },
        ],
      });

      expect(find.byType(Positioned), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('a wrap starts a new line rather than overflowing', (
      tester,
    ) async {
      await pump(tester, {
        't': 'wrap',
        'p': {'spacing': 7, 'run': 3},
        'c': [text('a'), text('b')],
      });

      final wrap = tester.widget<Wrap>(find.byType(Wrap));
      expect(wrap.spacing, 7);
      expect(wrap.runSpacing, 3);
    });

    testWidgets('text carries a named size, a weight and a face', (
      tester,
    ) async {
      await pump(tester, {
        't': 'text',
        'p': {'value': 'df -h', 'size': 'xl', 'weight': 'bold', 'mono': true},
      });

      final style = tester.widget<Text>(find.text('df -h')).style!;
      expect(style.fontSize, 22);
      expect(style.fontWeight, FontWeight.w600);
      expect(style.fontFamily, 'monospace');
    });

    testWidgets('and can be truncated or selectable', (tester) async {
      await pump(tester, {
        't': 'column',
        'c': [
          {
            't': 'text',
            'p': {'value': 'long', 'max': 2},
          },
          {
            't': 'text',
            'p': {'value': 'pick me', 'select': true},
          },
        ],
      });

      expect(tester.widget<Text>(find.text('long')).maxLines, 2);
      expect(tester.widget<Text>(find.text('long')).overflow, TextOverflow.ellipsis);
      expect(find.byType(SelectableText), findsOneWidget);
    });

    testWidgets('a button is one of two weights, and says when it is busy', (
      tester,
    ) async {
      await pump(tester, {
        't': 'row',
        'c': [
          {
            't': 'btn',
            'p': {'label': 'Run', 'variant': 'filled'},
            'on': {'tap': 1},
          },
          {
            't': 'btn',
            'p': {'label': 'Wait', 'busy': true},
            'on': {'tap': 2},
          },
        ],
      });

      expect(find.byType(FilledButton), findsOneWidget);
      // A busy button shows a spinner instead of its label, and cannot be
      // asked to do the same thing twice.
      expect(find.text('Wait'), findsNothing);
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(
        tester.widget<TextButton>(find.byType(TextButton)).onPressed,
        isNull,
      );
    });
  });

  /// The controls a form and a list need. Each is the app's own widget, so a
  /// plugin's settings page reads like the settings pages beside it — and each
  /// answers with the *value*, so a plugin never tracks which way a control
  /// was.
  group('controls', () {
    testWidgets('a checkbox answers with the new value', (tester) async {
      Object? got;
      await pump(
        tester,
        {
          't': 'checkbox',
          'p': {'value': false, 'label': 'Recursive'},
          'on': {'change': 'r'},
        },
        onEvent: (msg, value) => got = [msg, value],
      );

      await tester.tap(find.byType(Checkbox));
      expect(got, ['r', true]);
    });

    testWidgets('a segmented choice answers with the chosen value', (
      tester,
    ) async {
      Object? got;
      await pump(
        tester,
        {
          't': 'segmented',
          'p': {
            'value': 'size',
            'options': [
              {'value': 'size', 'label': 'Size'},
              {'value': 'name', 'label': 'Name'},
            ],
          },
          'on': {'change': 'sort'},
        },
        onEvent: (msg, value) => got = [msg, value],
      );

      await tester.tap(find.text('Name'));
      expect(got, ['sort', 'name']);
    });

    /// A value none of the options carries throws inside `SegmentedButton`,
    /// and a plugin can produce one by answering with a stale value.
    testWidgets('a segmented value nothing offers selects nothing', (
      tester,
    ) async {
      await pump(tester, {
        't': 'segmented',
        'p': {
          'value': 'gone',
          'options': [
            {'value': 'size', 'label': 'Size'},
          ],
        },
      });

      expect(tester.takeException(), isNull);
      expect(find.text('Size'), findsOneWidget);
    });

    testWidgets('a slider shows its value and answers with the new one', (
      tester,
    ) async {
      Object? got;
      await pump(
        tester,
        {
          't': 'slider',
          'p': {
            'value': 4,
            'min': 0,
            'max': 10,
            'divisions': 10,
            'label': 'Depth',
          },
          'on': {'change': 'd'},
        },
        onEvent: (msg, value) => got = value,
      );

      // Read without touching it, which is the one thing a settings page is
      // for — and whole, because the steps are whole.
      expect(find.text('4'), findsOneWidget);
      await tester.tapAt(tester.getCenter(find.byType(Slider)));
      expect(got, isA<double>());
    });

    testWidgets('a chip is a choice and says which it is', (tester) async {
      await pump(tester, {
        't': 'wrap',
        'c': [
          {
            't': 'chip',
            'p': {'label': 'tcp', 'selected': true},
            'on': {'tap': 't'},
          },
          {
            't': 'chip',
            'p': {'label': 'udp'},
            'on': {'tap': 'u'},
          },
        ],
      });

      final chips = tester.widgetList<FilterChip>(find.byType(FilterChip));
      expect(chips.map((c) => c.selected), [true, false]);
    });

    testWidgets('a menu carries a message per item', (tester) async {
      Object? got;
      await pump(
        tester,
        {
          't': 'menu',
          'p': {
            'options': [
              {'value': 'a', 'label': 'Edit', 'msg': {'m': 'edit'}},
              {'value': 'b', 'label': 'Remove', 'msg': {'m': 'rm'}},
            ],
          },
        },
        onEvent: (msg, value) => got = msg,
      );

      await tester.tap(find.byType(PopupMenuButton<int>));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Remove'));
      await tester.pumpAndSettle();

      expect(got, {'m': 'rm'});
    });

    testWidgets('a long press is a second gesture on any node', (tester) async {
      final seen = <Object?>[];
      await pump(
        tester,
        {
          't': 'text',
          'p': {'value': 'row'},
          'on': {'tap': 'open', 'long_press': 'more'},
        },
        onEvent: (msg, value) => seen.add(msg),
      );

      await tester.longPress(find.text('row'));
      await tester.tap(find.text('row'));
      expect(seen, ['more', 'open']);
    });

    /// Flutter's `Dismissible` expects the list to lose the row at once, and
    /// the tree belongs to the plugin and arrives over a network. So the swipe
    /// asks, and the answer is the next tree.
    testWidgets('a swipe asks rather than removing the row', (tester) async {
      Object? got;
      await pump(
        tester,
        {
          't': 'dismiss',
          'k': 'job:1',
          'on': {'dismiss': 'rm'},
          'c': [
            {
              't': 'tile',
              'p': {'title': 'nightly'},
            },
          ],
        },
        onEvent: (msg, value) => got = msg,
      );

      await tester.drag(find.text('nightly'), const Offset(-500, 0));
      await tester.pumpAndSettle();

      expect(got, 'rm');
      // Still there: the plugin decides, and its next tree is what removes it.
      expect(find.text('nightly'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('tabs switch without asking the plugin first', (tester) async {
      final seen = <Object?>[];
      await pump(
        tester,
        {
          't': 'sized',
          'p': {'height': 400},
          'c': [
            {
              't': 'tabs',
              'p': {'labels': ['Cron', 'Timers']},
              'on': {'change': 'tab'},
              'c': [text('cron rows'), text('timer rows')],
            },
          ],
        },
        onEvent: (msg, value) => seen.add(value),
      );

      expect(find.text('cron rows'), findsOneWidget);
      await tester.tap(find.text('Timers'));
      await tester.pumpAndSettle();

      // Drawn immediately, and the plugin told afterwards.
      expect(find.text('timer rows'), findsOneWidget);
      expect(seen, [1]);
    });

    /// A `TabBarView` needs a height, and a plugin can put one in a card where
    /// there is none — which throws at layout time and takes the surface.
    testWidgets('tabs in an unbounded height do not take the surface down', (
      tester,
    ) async {
      await pump(tester, {
        't': 'scroll',
        'c': [
          {
            't': 'tabs',
            'p': {'labels': ['One', 'Two']},
            'c': [text('first'), text('second')],
          },
        ],
      });

      expect(tester.takeException(), isNull);
      expect(find.text('first'), findsOneWidget);
    });
  });

  /// What a page says about itself while it is loading, when it is wrong, and
  /// when the numbers are the point.
  group('display', () {
    testWidgets('a banner is a state, in the tone it is given', (tester) async {
      await pump(tester, {
        't': 'banner',
        'p': {'text': 'No crontab here', 'tone': 'warning', 'icon': 'clock'},
        'c': [
          {
            't': 'btn',
            'p': {'label': 'Install'},
            'on': {'tap': 'i'},
          },
        ],
      });

      expect(find.text('No crontab here'), findsOneWidget);
      // The action sits in it rather than under it, which is what makes a
      // banner one thing instead of two.
      expect(find.text('Install'), findsOneWidget);
    });

    testWidgets('a badge marks the corner of what it is about', (tester) async {
      await pump(tester, {
        't': 'badge',
        'p': {'label': '3'},
        'c': [
          {
            't': 'icon',
            'p': {'name': 'clock'},
          },
        ],
      });

      expect(find.byType(Badge), findsOneWidget);
      expect(find.text('3'), findsOneWidget);
    });

    testWidgets('a skeleton keeps the layout still', (tester) async {
      await pump(tester, {
        't': 'skeleton',
        'p': {'rows': 4},
      });

      // Two bars a row — a title and a subtitle, the shape of what is coming.
      expect(find.byType(FractionallySizedBox), findsNWidgets(8));
    });

    /// The node shape is v1's and has not moved; what moved is that these are
    /// charts now rather than a column of `label: latest value` rows.
    testWidgets('a line chart draws its series', (tester) async {
      await pump(tester, {
        't': 'line_chart',
        'p': {
          'series': [
            {'label': 'cpu', 'values': [1, 2, 3], 'unit': '%'},
            {'label': 'mem', 'values': [4, 5, 6], 'unit': '%'},
          ],
        },
      });

      expect(find.byType(LineChart), findsOneWidget);
      // A legend, because nothing else names the lines.
      expect(find.text('cpu'), findsOneWidget);
      expect(find.text('mem'), findsOneWidget);
    });

    testWidgets('a bar chart draws the same shape as bars', (tester) async {
      await pump(tester, {
        't': 'bar_chart',
        'p': {
          'series': [
            {'label': 'reads', 'values': [3, 1]},
          ],
        },
      });

      expect(find.byType(BarChart), findsOneWidget);
    });

    /// fl_chart throws a `LateInitializationError` on a series with no spots,
    /// which would take the whole surface — the same guard the app's own
    /// history chart carries.
    testWidgets('a chart with no values is a problem node, not a crash', (
      tester,
    ) async {
      await pump(tester, {
        't': 'line_chart',
        'p': {
          'series': [
            {'label': 'cpu', 'values': <Object>[]},
          ],
        },
      });

      expect(tester.takeException(), isNull);
      expect(find.textContaining('no values'), findsOneWidget);
    });

    testWidgets('a pie chart draws parts of a whole, with a legend', (
      tester,
    ) async {
      await pump(tester, {
        't': 'pie_chart',
        'p': {
          'slices': [
            {'label': '/var', 'value': 3},
            {'label': '/usr', 'value': 1},
          ],
        },
      });

      expect(find.byType(PieChart), findsOneWidget);
      expect(find.text('/var'), findsOneWidget);
    });

    testWidgets('a grid lays its children out in columns', (tester) async {
      await pump(tester, {
        't': 'grid',
        'p': {'columns': 3},
        'c': [text('a'), text('b'), text('c')],
      });

      final grid = tester.widget<GridView>(find.byType(GridView));
      final delegate =
          grid.gridDelegate as SliverGridDelegateWithFixedCrossAxisCount;
      expect(delegate.crossAxisCount, 3);
    });
  });

  /// The primitives a page is built out of once the app's own widgets run out:
  /// a box, a shape, a paragraph with two styles in it.
  group('primitives', () {
    testWidgets('a container takes a named background and a corner', (
      tester,
    ) async {
      await pump(tester, {
        't': 'container',
        'p': {'bg': 'danger', 'radius': 9, 'all': 7},
        'c': [text('careful')],
      });

      final box = tester.widget<Container>(find.byType(Container).first);
      final decoration = box.decoration! as BoxDecoration;
      // Faint, the way a tag draws its tone: a plugin asking for "danger"
      // wants a danger-coloured block, not unreadable text on solid red.
      expect(decoration.color!.a, lessThan(0.5));
      expect(decoration.borderRadius, BorderRadius.circular(9));
    });

    /// A plugin computing one from a reading can produce 1.4, and Flutter
    /// asserts on it.
    testWidgets('an opacity out of range is clamped, not refused', (
      tester,
    ) async {
      await pump(tester, {
        't': 'opacity',
        'p': {'value': 1.4},
        'c': [text('visible')],
      });

      expect(tester.takeException(), isNull);
      expect(tester.widget<Opacity>(find.byType(Opacity)).opacity, 1.0);
    });

    testWidgets('a rich paragraph carries styles and a tappable span', (
      tester,
    ) async {
      Object? got;
      await pump(
        tester,
        {
          't': 'rich',
          'c': [
            {
              't': 'span',
              'p': {'value': 'Running as '},
            },
            {
              't': 'span',
              'p': {'value': 'root', 'weight': 'bold', 'mono': true},
            },
            {
              't': 'span',
              'p': {'value': ' — change'},
              'on': {'tap': 'chg'},
            },
          ],
        },
        onEvent: (msg, value) => got = msg,
      );

      // One paragraph, so it wraps as a sentence — which a row of texts does
      // not, and which is the whole reason this node exists.
      final rich = tester.widget<Text>(find.byType(Text).first);
      final spans = (rich.textSpan! as TextSpan).children!.cast<TextSpan>();
      expect(spans.map((s) => s.text), [
        'Running as ',
        'root',
        ' — change',
      ]);
      expect(spans[1].style?.fontFamily, 'monospace');
      expect(spans[2].recognizer, isNotNull);
      expect(got, isNull);
    });

    /// An image is a file the plugin shipped, resolved under its own
    /// directory. A name with a path in it reaches nothing — see
    /// `PluginAssets`.
    testWidgets('an image names a file the plugin shipped', (tester) async {
      final state = PluginSurfaceState(assetDir: '/tmp/sbm-plugin-test');
      await pump(
        tester,
        {
          't': 'image',
          'p': {'asset': '../../etc/passwd'},
        },
        state: state,
      );

      expect(find.textContaining('no such asset'), findsOneWidget);
    });

    testWidgets('and says so when the plugin has no directory', (tester) async {
      await pump(tester, {
        't': 'image',
        'p': {'asset': 'logo.png'},
      });

      expect(find.textContaining('no such asset'), findsOneWidget);
    });
  });

  group('what a bad tree costs', () {
    /// `Expanded` outside a `Flex` is a layout-time throw, and a throw takes
    /// the whole surface — which a plugin can cause by writing `expanded(...)`
    /// at the top of a card. The parent's type is carried down so those two
    /// degrade instead.
    testWidgets('a flex-only node outside a flex is harmless', (tester) async {
      await pump(tester, {
        't': 'card',
        'v': 1,
        'c': [
          {'t': 'spacer', 'v': 2},
          {
            't': 'expanded',
            'v': 3,
            'c': [text('inside', v: 4)],
          },
        ],
      });

      expect(tester.takeException(), isNull);
      expect(find.text('inside'), findsOneWidget);
    });

    testWidgets('and inside one it still takes the space', (tester) async {
      await pump(tester, {
        't': 'row',
        'v': 1,
        'c': [
          {
            't': 'expanded',
            'v': 2,
            'c': [text('wide', v: 3)],
          },
        ],
      });

      expect(find.byType(Expanded), findsOneWidget);
      expect(find.text('wide'), findsOneWidget);
    });

    testWidgets('an unknown widget costs that node, not the card', (tester) async {
      await pump(tester, {
        't': 'card',
        'v': 1,
        'c': [
          text('above', v: 2),
          {'t': 'hologram', 'v': 3},
          text('below', v: 4),
        ],
      });

      expect(find.text('above'), findsOneWidget);
      expect(find.text('below'), findsOneWidget);
      expect(find.textContaining('unknown widget "hologram"'), findsOneWidget);
    });

    testWidgets('a table row shorter than its header pads', (tester) async {
      await pump(tester, {
        't': 'table',
        'v': 1,
        'p': {
          'header': ['a', 'b'],
          'rows': [
            ['1'],
          ],
        },
      });

      expect(find.text('1'), findsOneWidget);
      expect(find.text('a'), findsOneWidget);
    });

    testWidgets('an unknown icon is named rather than drawn blank', (tester) async {
      await pump(tester, {'t': 'icon', 'v': 1, 'p': {'name': 'unicorn'}});

      expect(find.textContaining('unknown icon "unicorn"'), findsOneWidget);
    });
  });

  group('keys and state', () {
    /// `Widget.canUpdate` compares `runtimeType` and `key`, so a reordered set
    /// of unkeyed children is matched positionally and every element — with
    /// its focus and its caret — is thrown away.
    testWidgets('what the user typed survives a tick', (tester) async {
      await pump(tester, {
        't': 'column',
        'v': 1,
        'c': [
          {'t': 'input', 'k': 'search', 'v': 2, 'p': {'value': ''}},
        ],
      });

      await tester.enterText(find.byType(TextField), 'web');
      await tester.pump();
      expect(find.text('web'), findsOneWidget);

      // A tick that redraws the surface. The node keeps its key, so the
      // element — and the controller it holds — survives.
      await show(tester, {
        't': 'column',
        'v': 3,
        'c': [
          {'t': 'input', 'k': 'search', 'v': 2, 'p': {'value': ''}},
        ],
      });

      expect(find.text('web'), findsOneWidget);
    });

    /// A list longer than the window scrolls rather than being cut off.
    ///
    /// `expanded(scroll([...]))` is what every one of these pages is built
    /// from, and it only works if the column above hands the scroll view a
    /// bounded height.
    testWidgets('a long list inside expanded scrolls', (tester) async {
      await pump(tester, {
        't': 'column',
        'v': 1,
        'c': [
          {'t': 'text', 'v': 2, 'p': {'value': 'header'}},
          {
            't': 'expanded',
            'v': 3,
            'c': [
              {
                't': 'scroll',
                'v': 4,
                'c': [
                  for (var i = 0; i < 60; i++)
                    {
                      't': 'tile',
                      'v': 100 + i,
                      'p': {'title': 'row $i'},
                    },
                ],
              },
            ],
          },
        ],
      });

      // A `SingleChildScrollView` builds every child, so the last row is in
      // the tree either way — where it *is* is the question.
      final viewport = tester.getSize(find.byType(SingleChildScrollView)).height;
      expect(
        tester.getTopLeft(find.text('row 59')).dy,
        greaterThan(viewport),
        reason: 'the last row starts below the fold',
      );

      await tester.drag(
        find.byType(SingleChildScrollView),
        const Offset(0, -2000),
      );
      await tester.pump();

      expect(tester.getTopLeft(find.text('row 59')).dy, lessThan(viewport));
    });

    /// A card is as tall as what is in it.
    ///
    /// `Column` defaults to `MainAxisSize.max`, so a settings page whose whole
    /// content was one switch drew a card down the entire window.
    testWidgets('a card does not fill the height it is offered', (tester) async {
      await pump(tester, {
        't': 'card',
        'v': 1,
        'c': [
          {'t': 'text', 'v': 2, 'p': {'value': 'one line'}},
        ],
      });

      final card = tester.getSize(find.byType(CardX));
      expect(card.height, lessThan(200));
    });

    /// And a plugin that *wants* the rest of the space still gets it: a tight
    /// flex child takes the free space, so the column fills after all.
    testWidgets('expanded still fills inside a min column', (tester) async {
      await pump(tester, {
        't': 'column',
        'v': 1,
        'c': [
          {'t': 'text', 'v': 2, 'p': {'value': 'top'}},
          {
            't': 'expanded',
            'v': 3,
            'c': [
              {'t': 'text', 'v': 4, 'p': {'value': 'rest'}},
            ],
          },
        ],
      });

      final column = tester.getSize(find.byType(Column).first);
      expect(column.height, greaterThan(400));
    });

    /// A settings page is mostly these, so the value it hands back has to be
    /// the new one — a plugin that had to remember which way it was would be
    /// keeping state the app already has.
    testWidgets('a toggle answers the value it moved to', (tester) async {
      Object? seen;
      Object? value;
      await pump(
        tester,
        {
          't': 'toggle',
          'v': 1,
          'p': {'label': 'Stay on one filesystem', 'value': false},
          'on': {
            'change': {'m': 'oneFs'},
          },
        },
        onEvent: (msg, v) {
          seen = msg;
          value = v;
        },
      );

      await tester.tap(find.byType(Switch));
      await tester.pump();

      expect(seen, {'m': 'oneFs'});
      expect(value, true);
    });

    /// `onTap` is declared for any node, and honouring it only on `btn` made
    /// every action a plugin puts in a list — a filter, a reload, a row that
    /// opens — draw a control that did nothing.
    testWidgets('a tap on anything else answers too', (tester) async {
      Object? seen;
      await pump(
        tester,
        {
          't': 'tag',
          'v': 1,
          'p': {'label': 'Reload'},
          'on': {
            'tap': {'m': 'reload'},
          },
        },
        onEvent: (msg, _) => seen = msg,
      );

      await tester.tap(find.text('Reload'));
      await tester.pump();

      expect(seen, {'m': 'reload'});
    });

    /// A row hands its tap to the `ListTile`, so the ripple is the row. It
    /// must not also be wrapped, or one tap would answer twice.
    testWidgets('a row answers once, not twice', (tester) async {
      var calls = 0;
      await pump(
        tester,
        {
          't': 'tile',
          'v': 1,
          'p': {'title': '/var', 'subtitle': '18M'},
          'on': {
            'tap': {'m': 'open'},
          },
        },
        onEvent: (msg, _) => calls++,
      );

      await tester.tap(find.text('/var'));
      await tester.pump();

      expect(calls, 1);
    });

    /// Nothing to answer, so nothing that looks answerable.
    testWidgets('a node with no tap is not made tappable', (tester) async {
      await pump(tester, {
        't': 'tag',
        'v': 1,
        'p': {'label': 'tcp'},
      });

      expect(find.byType(InkWell), findsNothing);
    });

    testWidgets('a tap hands back the message unchanged', (tester) async {
      Object? seen;
      var calls = 0;
      await pump(
        tester,
        {
          't': 'btn',
          'v': 1,
          'p': {'label': 'Start'},
          'on': {
            'tap': {'start': 101},
          },
        },
        onEvent: (msg, _) {
          seen = msg;
          calls++;
        },
      );

      await tester.tap(find.text('Start'));
      await tester.pump();

      expect(calls, 1);
      expect(seen, {'start': 101});
    });
  });

  group('the leaf cache', () {
    /// The same fast path revisions buy, for a node that carries none.
    ///
    /// Asserted on the widgets rather than on the cache's keys: what the cache
    /// is for is `Element.updateChild` finding the *same instance* and
    /// returning, and a test written against the signature breaks whenever a
    /// node grows a property without anything being wrong.
    testWidgets('two identical leaves are one widget', (tester) async {
      await pump(tester, {
        't': 'column',
        'c': [text('idle'), text('idle'), text('busy')],
      });

      final drawn = tester.widgetList<Text>(find.byType(Text)).toList();
      expect(drawn.map((t) => t.data), ['idle', 'idle', 'busy']);
      expect(identical(drawn[0], drawn[1]), isTrue);
      expect(identical(drawn[0], drawn[2]), isFalse);
    });

    /// The app tints a selected row rather than leaving a plugin to invent a
    /// mark for one. Before it, a plugin could say "this one is chosen" only by
    /// swapping its icon — one grey glyph for another, which in a list of five
    /// picked rows is not a state anybody reads.
    testWidgets('a chosen row is drawn the way the app draws one', (
      tester,
    ) async {
      await pump(tester, {
        't': 'card',
        'c': [
          {
            't': 'tile',
            'p': {'title': 'kept', 'selected': true},
          },
          {
            't': 'tile',
            'p': {'title': 'not kept'},
          },
        ],
      });

      final tiles = tester.widgetList<ListTile>(find.byType(ListTile)).toList();
      expect(tiles.map((t) => t.selected), [true, false]);
    });

    /// **A node with children is not a leaf.** `summary` builds its actions
    /// and `tile` its trailing out of `c`, and neither is in the signature —
    /// so a bar whose reading had not changed kept the buttons it was first
    /// drawn with. That is what "the button does nothing" looked like: the tap
    /// arrived, the plugin answered with a new tree, and the row on screen was
    /// the old one. A selection mode that cannot be entered, from a cache.
    testWidgets('a node with children is not cached on its value alone', (
      tester,
    ) async {
      Map<String, Object?> bar(String action) => {
        't': 'summary',
        'p': {'value': '3', 'label': 'Jobs'},
        'c': [
          {
            't': 'tag',
            'p': {'label': action},
            'on': {'tap': {'m': action}},
          },
        ],
      };

      await pump(tester, bar('select'));
      expect(find.text('select'), findsOneWidget);

      await show(tester, bar('cancel'));

      expect(find.text('cancel'), findsOneWidget);
      expect(find.text('select'), findsNothing);
    });

    testWidgets('and neither is a tile with a trailing widget', (tester) async {
      Map<String, Object?> row(String trailing) => {
        't': 'tile',
        'p': {'title': 'app.service'},
        'c': [
          {
            't': 'tag',
            'p': {'label': trailing},
          },
        ],
      };

      await pump(tester, row('on'));
      await show(tester, row('off'));

      expect(find.text('off'), findsOneWidget);
      expect(find.text('on'), findsNothing);
    });

    test('it does not grow without bound', () {
      final state = PluginSurfaceState();
      for (var i = 0; i <= PluginSurfaceState.leafCacheSize; i++) {
        state.rememberLeaf('$i', const SizedBox.shrink());
      }

      // Cleared rather than evicted one at a time: what this exists for is a
      // value alternating between a few strings, not a counter's history.
      expect(state.leaf('0'), isNull);
      state.dispose();
    });
  });
}
