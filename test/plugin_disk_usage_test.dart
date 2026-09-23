/// The disk-usage plugin on the real host.
///
/// Its own tests against `MockHost` live beside it and prove it agrees with
/// the SDK. This proves the SDK and the app agree — the same bundle, in
/// QuickJS, with the app's `sb.*` under it — and it is where the one property
/// worth checking twice is checked: a path the *server* named goes back into a
/// shell command, and must arrive there as data.
///
/// Build the bundle first: cd packages/plugins/disk-usage && bun run build
/// Build the native library first too: cargo build -p sbm_ffi
library;

import 'dart:convert';
import 'dart:io';

import 'package:fl_lib/fl_lib.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:server_box/data/model/plugin/host_ops.dart';
import 'package:server_box/data/model/plugin/node.dart';
import 'package:server_box/data/provider/plugin/bridge.dart';
import 'package:server_box/data/provider/plugin/runtime.dart';
import 'package:server_box/view/widget/plugin/render.dart';
import 'package:server_box/view/widget/plugin/surface.dart';

import 'helpers/plugin_host_ops.dart';
import 'helpers/test_db.dart';
import 'rust_lib_helper.dart';

const _dir = 'packages/plugins/disk-usage';

const _out = '''
df
/dev/vda1 51475068 48901120 1934564 97% /
du
34041852	/var
8388608	/usr
51475068	/
''';

void main() {
  setUpAll(initRustLibForTest);

  late FakePluginHostOps ops;
  late PluginRuntimeService service;
  late BigInt instance;

  /// Registered in every test, as the app does the moment a surface opens:
  /// `sb.ui.patch` rejects when nothing is showing, and a plugin drawing into
  /// a surface that is not there is not what any of these are about.
  late List<PluginPatch> patches;

  setUp(() async {
    // The plugin reads `sb.store` on the way in, and that is the app's own
    // key-value store rather than a fake — so it needs somewhere to read from.
    await openTestDb();
    // `server_plugin_kv` is a child of `server`, so the plugin's own store has
    // somewhere to hang its row.
    SqliteDb.instance.execute(
      "INSERT INTO server (id, name, ssh_ip) VALUES ('srv-1', 'one', '10.0.0.1');",
    );
    ops = FakePluginHostOps()
      ..execResult = PluginExecResult(code: 0, stdout: _out, stderr: '');
    service = PluginRuntimeService(
      bridge: PluginBridge(ops: ops, handles: PluginServerHandles()),
    );
    await service.start();
    patches = [];
    instance = await service.load(
      manifestJson: File('$_dir/manifest.json').readAsStringSync(),
      source: File('$_dir/dist/plugin.js').readAsStringSync(),
      instanceId: 'inst-du',
      granted: const ['server.exec'],
      config: const {},
      boundServerId: 'srv-1',
    );
    service.bridge.onPatch['inst-du'] = patches.add;
  });

  tearDown(() async {
    await service.unload(instance);
    service.dispose();
    await closeTestDb();
  });

  /// The call the reading lands in.
  ///
  /// **The measurement is a `background` resource**, so the hook answers with
  /// `Measuring…` rather than holding the instance for the length of a `du` —
  /// which is what makes the Stop button reachable, since the host serves one
  /// call per instance at a time. The reading arrives on the next call in, and
  /// in the app that is the tick `PluginSurfaceView` fires the moment the
  /// answer is there.
  ///
  /// A beat first, then the call: the app answers `sb.server.exec` on its own
  /// turn, and a tick issued before that answer exists finds nothing to drain.
  /// `PluginSurfaceView` has this for free — it ticks *because* an answer
  /// arrived — and a test driving the service directly has to wait for one.
  Future<void> tick({int times = 3}) async {
    for (var i = 0; i < times; i++) {
      await Future<void>.delayed(const Duration(milliseconds: 10));
      await service.call(instance, 'tick', '');
    }
  }

  /// Every string the tree would put on screen, in order.
  ///
  /// Reads the props that carry text and not only `text` nodes: a `tile`'s
  /// title and a `summary`'s figure are properties, so a walker looking for
  /// `text` children alone would say a page full of rows says nothing. Matches
  /// `texts` in `@serverbox/plugin-api/test`.
  List<String> texts(PluginNode node) {
    // Matches `texts` in `@serverbox/plugin-api/test`: every prop carrying a
    // string the user reads, including an input's `hint` and a banner's `text`.
    const keys = [
      'value',
      'title',
      'subtitle',
      'label',
      'detail',
      'hint',
      'text',
      'k',
      'v',
    ];
    final out = <String>[];
    void walk(PluginNode n) {
      for (final key in keys) {
        final v = n.props[key];
        if (v is String && v.isNotEmpty) out.add(v);
      }
      for (final c in n.children) {
        walk(c);
      }
    }

    walk(node);
    return out;
  }


  /// The whole complaint the page drew and could not answer: a row that looks
  /// like it opens has to open.
  ///
  /// Through the renderer on purpose. The plugin's own tests call `onEvent`
  /// directly, and the gap was never there — it was between the tree and the
  /// tap: `onTap` is declared for any node and only `btn` read it, so every
  /// row in this list drew a control that did nothing.
  testWidgets('a row drawn by the plugin opens when it is tapped', (
    tester,
  ) async {
    await tester.runAsync(() async {
      // The app opens a surface before it hooks it, and a plugin holding
      // its state in providers builds on `open`.
      await service.call(
        instance,
        'open',
        jsonEncode({'kind': 'page', 'id': 'usage'}),
      );
      await service.hook(
        instance,
        kind: 'enter',
        contributionId: 'usage',
        granted: const ['server.exec'],
        serverIds: const ['srv-1'],
      );
      await tick();
    });

    Object? seen;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: PluginRenderer(
            tree: patches.last.node,
            state: PluginSurfaceState(),
            onEvent: (msg, _) => seen = msg,
          ),
        ),
      ),
    );

    await tester.tap(find.text('var'));
    await tester.pump();

    // A token rather than a message a test could write: what matters is that
    // the row carries *something* and the renderer delivers it. What the
    // plugin does with it is the plugin's own test.
    expect(seen, isNotNull);
  });

  /// The whole tree as it stands.
  ///
  /// A patch carries a diff and says what changed; `open` draws in full against
  /// the state the plugin holds, which is what a test wants to read.
  Future<PluginNode> screen({String kind = 'page', String id = 'usage'}) async {
    final out = await service.call(
      instance,
      'open',
      jsonEncode({'kind': kind, 'id': id}),
    );
    return PluginNode.fromJson((jsonDecode(out) as Map)['ui'])!;
  }

  /// What the thing labelled [label] sends on [event], as the app would.
  Object? eventOn(PluginNode node, String label, String event) {
    Object? search(PluginNode n) {
      final msg = n.events[event];
      if (msg != null && texts(n).contains(label)) return msg;
      for (final c in n.children) {
        final hit = search(c);
        if (hit != null) return hit;
      }
      return null;
    }

    return search(node);
  }

  /// The settings surface, which until this plugin grew a form was one switch.
  ///
  /// Through the real host because that is where the store is: the values the
  /// form reads and writes go through `sb.store` into the app's own tables, not
  /// into a fake, and a form that cannot read back what it wrote is a form that
  /// forgets every time it is opened.
  group('the settings form', () {
    /// Opened the way the app opens it: `open`, then the hook.
    ///
    /// **The hook is not optional here even though this surface ignores it.**
    /// The form draws from the store, so `open` starts a promise and returns —
    /// and nothing pumps that promise until the next call into the runtime.
    /// In the app that call is the hook, which every surface gets; a test that
    /// stopped after `open` would wait forever for a patch and read as the
    /// plugin never drawing.
    Future<void> openSettings() async {
      await service.call(
        instance,
        'open',
        jsonEncode({'kind': 'settings', 'id': 'prefs'}),
      );
      // No servers, which is what a settings surface gets: it is bound to no
      // machine. The plugin has to leave its page's "no server" branch alone
      // for this one, or the error draws over the form.
      await service.hook(
        instance,
        kind: 'enter',
        contributionId: 'prefs',
        granted: const ['server.exec'],
      );
    }

    /// Types [value] into the field whose placeholder is [placeholder].
    ///
    /// **The message is read off the tree.** A handler is a closure, so what
    /// crosses is a token the SDK made — a test that wrote `{m: 'setStartAt'}`
    /// would be speaking a protocol the plugin no longer has, and would pass
    /// just as well if nothing on screen sent it.
    Future<void> type(String placeholder, Object? value) async {
      final msg = eventOn(await screen(kind: 'settings', id: 'prefs'), placeholder, 'change');
      expect(msg, isNotNull, reason: 'no field with placeholder $placeholder');
      await service.call(
        instance,
        'onEvent',
        jsonEncode({'msg': msg, 'value': value}),
      );
    }

    /// Taps the thing labelled [label].
    Future<void> press(String label) async {
      final msg = eventOn(await screen(kind: 'settings', id: 'prefs'), label, 'tap');
      expect(msg, isNotNull, reason: 'nothing labelled $label is tappable');
      await service.call(instance, 'onEvent', jsonEncode({'msg': msg}));
    }

    test('it draws its fields and a way back to the defaults', () async {
      await openSettings();

      final drawn = texts(await screen(kind: 'settings', id: 'prefs'));
      expect(drawn, contains('l10n.prefsStartAt'));
      expect(drawn, contains('l10n.prefsSkip'));
      expect(drawn, contains('l10n.prefsHideBelow'));
      expect(drawn, contains('l10n.prefsReset'));
    });

    test('a good value is kept, and read back on the next open', () async {
      await openSettings();
      await type('/', '/srv');
      await openSettings();

      expect(texts(await screen(kind: 'settings', id: 'prefs')), contains('/srv'));
    });

    /// Rejected rather than ignored. A value silently dropped when it is read
    /// back is one the user believes is in effect.
    test('a path that is not one is refused, with the reason on screen', () async {
      await openSettings();
      await type('/', 'var');

      final drawn = texts(await screen(kind: 'settings', id: 'prefs'));
      expect(drawn, contains('l10n.prefsErrPath'));
      // And what was typed is still there to be corrected.
      expect(drawn, contains('var'));
    });

    test('reset takes every field back', () async {
      await openSettings();
      await type('/', '/srv');
      await press('l10n.prefsReset');
      // Re-read: the form's values come from the store, and the store has just
      // been emptied. A call is what lets that read finish.
      await openSettings();
      await openSettings();

      expect(
        texts(await screen(kind: 'settings', id: 'prefs')),
        isNot(contains('/srv')),
      );
    });
  });

  test('the hook measures the root and draws what came back', () async {
    // The app opens a surface before it hooks it, and a plugin holding
    // its state in providers builds on `open`.
    await service.call(
      instance,
      'open',
      jsonEncode({'kind': 'page', 'id': 'usage'}),
    );
    await service.hook(
      instance,
      kind: 'enter',
      contributionId: 'usage',
      granted: const ['server.exec'],
      serverIds: const ['srv-1'],
    );
    await tick();

    // Measuring first, then the answer — a level can take a minute.
    // One patch per state the page passed through: the measuring line, then
    // the reading. More of them is the diff working, not a fault.
    expect(patches.length, greaterThanOrEqualTo(2));
    expect(
      patches.any((p) => texts(p.node).contains('l10n.measuring')),
      isTrue,
    );

    final drawn = texts(await screen());
    expect(drawn, contains('var'));
    expect(drawn, contains('usr'));
    expect(drawn.any((t) => t.contains('32G')), isTrue);
  });

  /// `-x` is what keeps `du /` off every network mount on the machine.
  test('it stays on one filesystem and asks one level', () async {
    // The app opens a surface before it hooks it, and a plugin holding
    // its state in providers builds on `open`.
    await service.call(
      instance,
      'open',
      jsonEncode({'kind': 'page', 'id': 'usage'}),
    );
    await service.hook(
      instance,
      kind: 'enter',
      contributionId: 'usage',
      granted: const ['server.exec'],
      serverIds: const ['srv-1'],
    );
    await tick();

    final script = ops.calls.single;
    expect(script, contains('du -x -d 1 -k'));
    expect(script, contains('df -kP'));
    expect(script, isNot(contains('sudo')));
    expect(script, isNot(contains('rm ')));
  });

  /// **The property worth checking on the real host.** The path arrives out of
  /// a listing the server produced, and a directory called `; rm -rf ~` is a
  /// legal directory name. It must reach the command as one quoted word.
  test('a directory named like a command is quoted, not run', () async {
    // The listing the row comes out of. `; touch pwned` is a legal directory
    // name — no `/` in it, which is the only character a name cannot hold —
    // and the server is where it arrives from.
    ops.execResult = const PluginExecResult(
      code: 0,
      stdout: 'df\n/dev/vda1 100 50 50 50% /\n'
          'du\n1024\t/; touch pwned\n2048\t/\n',
      stderr: '',
    );
    // The app opens a surface before it hooks it, and a plugin holding
    // its state in providers builds on `open`.
    await service.call(
      instance,
      'open',
      jsonEncode({'kind': 'page', 'id': 'usage'}),
    );
    await service.hook(
      instance,
      kind: 'enter',
      contributionId: 'usage',
      granted: const ['server.exec'],
      serverIds: const ['srv-1'],
    );
    await tick();
    ops.calls.clear();

    // Tapped, which is where such a path comes from — and the only way in now
    // that a handler is a closure rather than a message a test could write.
    final row = eventOn(await screen(), '; touch pwned', 'tap');
    expect(row, isNotNull, reason: 'the listing has no such row');
    await service.call(instance, 'onEvent', jsonEncode({'msg': row}));
    // The measurement is a fetch the tap started and did not wait for, and the
    // host drives an instance only while it is inside a call — so this is the
    // call it gets to run in.
    await screen();

    final script = ops.calls.single;
    // Whole and inside single quotes, which is the only quoting a shell does
    // nothing inside.
    expect(script, contains("'/; touch pwned'"));
    // And never as its own command.
    expect(script, isNot(contains('du -x -d 1 -k /; touch')));

    // The shell agrees. Run for real, because the question is what `sh` does
    // with the string rather than what the test thinks it says.
    final marker = File('pwned');
    if (marker.existsSync()) marker.deleteSync();
    await Process.run('sh', ['-c', script.split(':srv-1:').last]);
    expect(marker.existsSync(), isFalse);
  });

  /// A path a line-oriented command cannot answer about is refused before it
  /// reaches a command at all.
  /// **Unreachable from here, and that is the answer.** A path with a newline
  /// in it cannot come out of a listing: `du` separates its rows by newlines,
  /// so such a directory arrives as two lines and never becomes one row. The
  /// command builder refuses it anyway — asserted in `scan.test.ts`, against a
  /// real shell, which is where a question about quoting belongs.
}
