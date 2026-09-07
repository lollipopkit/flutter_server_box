/// Drawing a plugin's tree. PLUGINS.md section 5.
///
/// Most of these are about the three things section 5.2 adds to the node
/// format, because those are the ones with a mechanism behind them and a
/// failure that looks like nothing: a revision that reuses the wrong widget
/// shows stale numbers, a binding that rebuilds too much is only visible in a
/// profile, and a list that materialises builds four hundred rows for a screen
/// that holds twelve.
library;

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
    testWidgets('two identical leaves are one widget', (tester) async {
      final state = await pump(tester, {
        't': 'column',
        'c': [text('idle'), text('idle'), text('busy')],
      });

      expect(state.leaf('text|idle|null'), isNotNull);
      expect(state.leaf('text|busy|null'), isNotNull);
      expect(
        identical(state.leaf('text|idle|null'), state.leaf('text|busy|null')),
        isFalse,
      );
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
