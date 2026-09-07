/// A plugin on screen: loaded, opened, ticked, tapped and patched, on a real
/// QuickJS context. PLUGINS.md sections 5.2 and 5.3.
///
/// This is the one test where all the pieces are in the same place — the
/// runtime, the bridge, the surface and the renderer — so what it is for is
/// the joins between them, not any one of them.
///
/// Build the native library first: cargo build -p sbm_ffi
library;

import 'package:fl_lib/fl_lib.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:server_box/data/model/plugin/host_ops.dart';
import 'package:server_box/data/provider/plugin/bridge.dart';
import 'package:server_box/data/provider/plugin/runtime.dart';
import 'package:server_box/data/store/plugin.dart';
import 'package:server_box/view/widget/plugin/surface_view.dart';

import 'helpers/test_db.dart';
import 'rust_lib_helper.dart';

const _manifest = '''
{
  "id": "app.serverbox.demo",
  "version": "1.0.0",
  "abi": 1,
  "name": "Demo",
  "contributes": { "card": { "id": "demo", "label": "Demo" } }
}
''';

class _Ops implements PluginHostOps {
  final toasts = <String>[];

  @override
  Future<PluginExecResult> exec(
    String serverId,
    String script, {
    Duration? timeout,
  }) async => (code: 0, stdout: '', stderr: '');

  @override
  void toast(String text, String kind) => toasts.add('$kind:$text');

  @override
  Future<PluginPromptResult> prompt({
    required String title,
    String? message,
    List<PluginPromptField> fields = const [],
    String? confirm,
  }) async => (cancelled: true, values: const <String, String>{});

  @override
  Future<String?> pickServer() async => null;

  @override
  Future<String?> clipboardRead() async => null;

  @override
  Future<void> clipboardWrite(String text) async {}

  @override
  Future<void> openServer(String serverId) async {}

  @override
  Future<void> goTab(String tab) async {}

  @override
  void crumb(String pluginId, String name, String level) {}
}

void main() {
  setUpAll(initRustLibForTest);

  late _Ops ops;
  late PluginBridge bridge;
  late PluginRuntimeService service;

  setUp(() async {
    await openTestDb();
    ops = _Ops();
    bridge = PluginBridge(
      ops: ops,
      handles: PluginServerHandles(),
      store: PluginKvStore(),
    );
    service = PluginRuntimeService(bridge: bridge);
  });

  tearDown(() async {
    service.dispose();
    await closeTestDb();
  });

  /// Lets the real work happen, then draws what came of it.
  ///
  /// A `testWidgets` body runs in a fake-async zone, and loading a plugin is a
  /// real future: the module is compiled on a thread of its own and the answer
  /// comes back over a port. `pump` alone advances a clock that future is not
  /// waiting on, so without `runAsync` nothing here ever finishes.
  Future<void> settle(WidgetTester tester, [int ms = 200]) async {
    await tester.runAsync(
      () => Future<void>.delayed(Duration(milliseconds: ms)),
    );
    await tester.pump();
  }

  Future<void> mount(
    WidgetTester tester,
    String source, {
    Duration? refreshInterval,
  }) async {
    // Inside `runAsync`, so `initState` — and the load it starts — runs in the
    // real zone from the beginning. Started in the fake one, the first `await`
    // is a continuation nothing ever delivers.
    await tester.runAsync(() async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: PluginSurfaceView(
              spec: PluginSurfaceSpec(
                pluginId: 'app.serverbox.demo',
                manifestJson: _manifest,
                source: source,
                kind: 'card',
                contributionId: 'demo',
              ),
              service: service,
              refreshInterval: refreshInterval,
            ),
          ),
        ),
      );
      await Future<void>.delayed(const Duration(milliseconds: 300));
    });
    await tester.pump();
  }

  testWidgets('open draws what the plugin answered', (tester) async {
    await mount(tester, '''
      export function open(surface) {
        return { ui: { t: "card", v: 1, c: [
          { t: "kv", v: 2, p: { k: "Where", v: surface.kind + "/" + surface.id } },
        ] } };
      }
    ''');

    expect(find.text('Where'), findsOneWidget);
    expect(find.text('card/demo'), findsOneWidget);
  });

  /// A plugin that will not load is named rather than left as an empty space,
  /// which is indistinguishable from a card the user turned off.
  testWidgets('a plugin that does not parse says so', (tester) async {
    await mount(tester, 'export function (');

    expect(find.textContaining('app.serverbox.demo'), findsOneWidget);
  });

  testWidgets('a tap reaches onEvent and the answer redraws', (tester) async {
    await mount(tester, '''
      let taps = 0;
      const view = () => ({ t: "column", v: taps * 2 + 1, c: [
        { t: "text", v: taps * 2 + 2, p: { value: "taps: " + taps } },
        { t: "btn", p: { label: "Again" }, on: { tap: { m: "again" } } },
      ] });
      export function open() { return { ui: view() }; }
      export function onEvent(e) { if (e.msg.m === "again") taps++; return { ui: view() }; }
    ''');
    expect(find.text('taps: 0'), findsOneWidget);

    await tester.tap(find.text('Again'));
    await settle(tester);

    expect(find.text('taps: 1'), findsOneWidget);
  });

  /// The cheap path, and the common one: the shape does not change, so the
  /// plugin answers values and the app sets notifiers instead of rebuilding.
  testWidgets('a tick that answers only values moves the number', (tester) async {
    await mount(
      tester,
      '''
        let n = 0;
        export function open() {
          return { ui: { t: "kv", v: 1, p: { k: "CPU", v: { "\$": "cpu" } } },
                   values: { cpu: "0%" } };
        }
        export function tick() { n += 5; return { values: { cpu: n + "%" } }; }
      ''',
      refreshInterval: const Duration(milliseconds: 50),
    );

    // The timer runs in real time, so what matters is not which number is
    // showing but that the number moves while the shape does not.
    String value() => tester.widget<KvRow>(find.byType(KvRow)).v;
    expect(value(), endsWith('%'));
    final before = value();

    await settle(tester);

    expect(value(), isNot(before));
    expect(
      tester.widget<KvRow>(find.byType(KvRow)).k,
      'CPU',
      reason: 'the tree was never resent',
    );
  });

  /// For a plugin streaming a log: it replaces one subtree rather than
  /// resending the page per line.
  testWidgets('a patch replaces the subtree its pointer names', (tester) async {
    await mount(tester, '''
      export function open() {
        return { ui: { t: "column", v: 1, c: [
          { t: "text", v: 2, p: { value: "first" } },
          { t: "text", v: 3, p: { value: "second" } },
        ] } };
      }
      export async function go() {
        await sb.ui.patch({ path: "/c/1", node: { t: "text", p: { value: "patched" } } });
      }
    ''');
    expect(find.text('second'), findsOneWidget);

    // Called the way a long-running task would call it, from outside a build.
    await tester.runAsync(() async {
      await service.call(_onlyInstance(service), 'go', '');
    });
    await tester.pump();

    expect(find.text('patched'), findsOneWidget);
    expect(find.text('first'), findsOneWidget, reason: 'the sibling stays');
    expect(find.text('second'), findsNothing);
  });

  /// A pointer written against a tree the surface has already replaced. Being
  /// dropped is the only safe answer — there is no node there to replace.
  testWidgets('a patch that names nothing changes nothing', (tester) async {
    await mount(tester, '''
      export function open() {
        return { ui: { t: "column", v: 1, c: [
          { t: "text", v: 2, p: { value: "only" } },
        ] } };
      }
      export async function go() {
        try {
          await sb.ui.patch({ path: "/c/9", node: { t: "text", p: { value: "x" } } });
        } catch (e) { /* the app answered, which is what matters */ }
      }
    ''');

    await tester.runAsync(() async {
      await service.call(_onlyInstance(service), 'go', '');
    });
    await tester.pump();

    expect(find.text('only'), findsOneWidget);
    expect(find.text('x'), findsNothing);
  });

  /// The instance lives exactly as long as the widget. Without that, a surface
  /// closed and reopened would leave a thread behind each time.
  testWidgets('closing the surface unloads the instance', (tester) async {
    await mount(tester, 'export function open() { return { ui: { t: "spacer", v: 1 } }; }');
    final id = _onlyInstance(service);
    expect(service.exports(id), isNotEmpty);

    // In the real zone, for `mount`'s reason: `dispose` starts the unload and
    // its awaits are continuations the fake zone never delivers.
    await tester.runAsync(() async {
      await tester.pumpWidget(const MaterialApp(home: SizedBox.shrink()));
      await Future<void>.delayed(const Duration(milliseconds: 300));
    });
    await tester.pump();

    expect(service.exports(id), isEmpty, reason: 'the instance is gone');
  });
}

/// The one instance a surface loaded.
///
/// The service does not hand out its ids, so this walks the small range they
/// come from — which is enough for a test that loads exactly one.
BigInt _onlyInstance(PluginRuntimeService service) {
  for (var i = 0; i < 64; i++) {
    final id = BigInt.from(i);
    if (service.exports(id).isNotEmpty) return id;
  }
  throw StateError('no instance is loaded');
}
