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
    ops = FakePluginHostOps()..execResult = (code: 0, stdout: _out, stderr: '');
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

  /// Every string the tree would put on screen, in order.
  ///
  /// Reads the props that carry text and not only `text` nodes: a `tile`'s
  /// title and a `summary`'s figure are properties, so a walker looking for
  /// `text` children alone would say a page full of rows says nothing. Matches
  /// `texts` in `@serverbox/plugin-api/test`.
  List<String> texts(PluginNode node) {
    const keys = ['value', 'title', 'subtitle', 'label', 'detail', 'k', 'v'];
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
      await service.hook(
        instance,
        kind: 'enter',
        contributionId: 'usage',
        granted: const ['server.exec'],
        serverIds: const ['srv-1'],
      );
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

    expect(seen, {'m': 'open', 'path': '/var'});
  });

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

    /// `onEvent` takes the message and the control's value as two arguments,
    /// which is `{msg, value}` on the wire — see `PluginSurfaceView._onEvent`.
    Future<void> event(String m, [Object? value]) => service.call(
      instance,
      'onEvent',
      jsonEncode({
        'msg': {'m': m},
        'value': value,
      }),
    );

    test('it draws its fields and a way back to the defaults', () async {
      await openSettings();

      final drawn = texts(patches.last.node);
      expect(drawn, contains('l10n.prefsStartAt'));
      expect(drawn, contains('l10n.prefsSkip'));
      expect(drawn, contains('l10n.prefsHideBelow'));
      expect(drawn, contains('l10n.prefsReset'));
    });

    test('a good value is kept, and read back on the next open', () async {
      await openSettings();
      await event('setStartAt', '/srv');
      await openSettings();

      expect(texts(patches.last.node), contains('/srv'));
    });

    /// Rejected rather than ignored. A value silently dropped when it is read
    /// back is one the user believes is in effect.
    test('a path that is not one is refused, with the reason on screen', () async {
      await openSettings();
      await event('setStartAt', 'var');

      final drawn = texts(patches.last.node);
      expect(drawn, contains('l10n.prefsErrPath'));
      // And what was typed is still there to be corrected.
      expect(drawn, contains('var'));
    });

    test('reset takes every field back', () async {
      await openSettings();
      await event('setStartAt', '/srv');
      await event('resetPrefs');
      await openSettings();

      expect(texts(patches.last.node), isNot(contains('/srv')));
    });
  });

  test('the hook measures the root and draws what came back', () async {
    await service.hook(
      instance,
      kind: 'enter',
      contributionId: 'usage',
      granted: const ['server.exec'],
      serverIds: const ['srv-1'],
    );

    // Measuring first, then the answer — a level can take a minute.
    expect(patches, hasLength(2));
    expect(texts(patches.first.node), contains('l10n.measuring'));

    final drawn = texts(patches.last.node);
    expect(drawn, contains('var'));
    expect(drawn, contains('usr'));
    expect(drawn.any((t) => t.contains('32G')), isTrue);
  });

  /// `-x` is what keeps `du /` off every network mount on the machine.
  test('it stays on one filesystem and asks one level', () async {
    await service.hook(
      instance,
      kind: 'enter',
      contributionId: 'usage',
      granted: const ['server.exec'],
      serverIds: const ['srv-1'],
    );

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
    await service.hook(
      instance,
      kind: 'enter',
      contributionId: 'usage',
      granted: const ['server.exec'],
      serverIds: const ['srv-1'],
    );
    ops.calls.clear();

    await service.call(
      instance,
      'onEvent',
      jsonEncode({
        'msg': {'m': 'open', 'path': '/tmp/; touch /tmp/pwned'},
      }),
    );

    final script = ops.calls.single;
    // Whole and inside single quotes, which is the only quoting a shell does
    // nothing inside.
    expect(script, contains("'/tmp/; touch /tmp/pwned'"));
    // And never as its own command.
    expect(script, isNot(contains('du -x -d 1 -k /tmp/; touch')));

    // The shell agrees. Run for real, because the question is what `sh` does
    // with the string rather than what the test thinks it says.
    final marker = File('/tmp/pwned');
    if (marker.existsSync()) marker.deleteSync();
    await Process.run('sh', ['-c', script.split(':srv-1:').last]);
    expect(marker.existsSync(), isFalse);
  });

  /// A path a line-oriented command cannot answer about is refused before it
  /// reaches a command at all.
  test('a path with a newline never becomes a command', () async {
    await service.hook(
      instance,
      kind: 'enter',
      contributionId: 'usage',
      granted: const ['server.exec'],
      serverIds: const ['srv-1'],
    );
    ops.calls.clear();

    await service.call(
      instance,
      'onEvent',
      jsonEncode({
        'msg': {'m': 'open', 'path': '/tmp/two\nlines'},
      }),
    );

    // The plugin drew its failure rather than sending anything.
    expect(ops.calls, isEmpty);
  });
}
