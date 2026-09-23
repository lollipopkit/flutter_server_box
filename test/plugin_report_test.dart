/// The report a user sends to a plugin's author. PLUGINS.md 8.4.
///
/// Two things are being held. **What it says**: which of three failures
/// happened — the collection did not run, the plugin threw, or what it drew
/// never landed — because from the user's side all three are "the plugin does
/// nothing" and an author cannot tell them apart from a screenshot.
///
/// **And what it does not say.** No command output, no configuration value, no
/// HTTP body, no error message. This is written to be pasted into a public
/// issue, and a report that leaks a path or a host name is one nobody should
/// send. A test is the only thing that keeps that true as fields are added:
/// nothing about writing a `StringBuffer` line stops the next one carrying a
/// value.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:server_box/core/utils/plugin/report.dart';
import 'package:server_box/data/model/plugin/health.dart';
import 'package:server_box/data/model/plugin/install.dart';
import 'package:server_box/data/model/plugin/installed.dart';
import 'package:server_box/data/store/plugin_health.dart';
import 'package:server_box/src/rust/api/plugin.dart' as ffi;

import 'rust_lib_helper.dart';

const _manifestJson = '''
{
  "id": "app.serverbox.zfs",
  "version": "1.1.0",
  "abi": 3,
  "name": "ZFS",
  "permissions": { "server.exec": true, "net.http": ["10.0.0.9"] }
}
''';

void main() {
  setUpAll(initRustLibForTest);

  final at = DateTime.utc(2026, 9, 10, 12, 30, 5);

  InstalledPlugin plugin({
    Set<String> granted = const {'server.exec'},
    PluginInstall? previous,
    String repo = 'https://github.com/lollipopkit/serverbox-plugins',
  }) => InstalledPlugin(
    record: PluginInstall(
      id: 'app.serverbox.zfs',
      version: '1.1.0',
      repo: repo,
      granted: granted,
      installedAt: at,
      previous: previous,
    ),
    manifestJson: _manifestJson,
    manifest: ffi.pluginReadManifest(manifestJson: _manifestJson),
    source: 'export function open() {}',
    l10n: const {},
  );

  String write({
    List<InstalledPlugin>? plugins,
    Map<String, PluginHealth> health = const {},
  }) => PluginReport(
    plugins: plugins ?? [plugin()],
    health: health,
    appVersion: '1.0.1600',
    abi: 4,
    at: at,
  ).write();

  PluginHealth healthWith({PluginEvent? ok, PluginEvent? failure, int since = 0}) =>
      PluginHealth(
        pluginId: 'app.serverbox.zfs',
        lastOk: ok,
        lastFailure: failure,
        failuresSinceOk: since,
      );

  test('it names the build and the ABI, not only the plugin', () {
    // A plugin's behaviour is half this app's, and the ABI is what decides
    // whether a version could have worked here at all.
    final text = write();

    expect(text, contains('1.0.1600'));
    expect(text, contains('abi 4'));
    expect(text, contains('abi 3'), reason: 'what the plugin was built for');
  });

  test('and what the plugin is', () {
    final text = write();

    expect(text, contains('app.serverbox.zfs 1.1.0'));
    expect(text, contains('lollipopkit/serverbox-plugins'));
    expect(text, contains('server.exec'));
  });

  /// The one list an author cannot guess: it is what the *user* agreed to
  /// rather than what the manifest asks, and it is where a "permission denied"
  /// comes from.
  test('a plugin running with less than it asks for says both', () {
    final text = write(plugins: [plugin(granted: const {'server.exec'})]);

    expect(text, contains('granted     server.exec'));
    expect(text, contains('asks for'));
    expect(text, contains('net.http'));
  });

  test('a plugin nothing has been recorded for says so', () {
    // Distinct from "it worked". A surface that was never opened has nothing
    // recorded, and reading that as healthy answers a question nobody asked.
    expect(write(), contains('nothing recorded yet'));
  });

  /// The three failures that look identical from outside.
  test('it says which stage failed, and how long it took', () {
    final text = write(
      health: {
        'app.serverbox.zfs': healthWith(
          ok: PluginEvent(
            stage: PluginStage.open,
            at: at,
            elapsed: const Duration(milliseconds: 41),
          ),
          failure: PluginEvent(
            stage: PluginStage.exec,
            at: at,
            elapsed: const Duration(seconds: 120),
            failure: 'timeout',
          ),
          since: 3,
        ),
      },
    );

    expect(text, contains('last ok     open, 2026-09-10 12:30:05Z, 41ms'));
    expect(text, contains('last fail   exec (timeout)'));
    expect(text, contains('120000ms'));
    expect(text, contains('3 in a row'));
  });

  /// Both, rather than the most recent of the two: a plugin whose page opens
  /// and whose collection fails is a different report from one that will not
  /// load, and keeping only the latest makes them read the same.
  test('the last success and the last failure are both kept', () {
    final text = write(
      health: {
        'app.serverbox.zfs': healthWith(
          ok: PluginEvent(
            stage: PluginStage.open,
            at: at,
            elapsed: Duration.zero,
          ),
          failure: PluginEvent(
            stage: PluginStage.hook,
            at: at,
            elapsed: Duration.zero,
            failure: 'threw',
          ),
        ),
      },
    );

    expect(text, contains('last ok     open'));
    expect(text, contains('last fail   hook (threw)'));
  });

  test('a kept version is named, so a rollback is visible in the report', () {
    final text = write(
      plugins: [
        plugin(
          previous: PluginInstall(
            id: 'app.serverbox.zfs',
            version: '1.0.0',
            granted: const {},
            installedAt: at,
          ),
        ),
      ],
    );

    expect(text, contains('kept        1.0.0'));
  });

  group('what it must not carry', () {
    /// **A failure is a tag this app chose, never the message.** The message
    /// holds paths, host names and whatever the plugin put in it — and this
    /// text is going into a public issue.
    test('a failure tag is a word, not an exception', () {
      final tag = pluginFailureTag(
        StateError('cannot read /home/alice/.ssh/id_ed25519 on bmc.corp.local'),
      );

      expect(tag, 'threw');
      expect(tag, isNot(contains('alice')));
      expect(tag, isNot(contains('bmc.corp.local')));
    });

    /// Each of these is a class of failure an author acts on differently, and
    /// none of them says where.
    test('and the tags that matter are told apart', () {
      expect(
        pluginFailureTag(Exception('permission denied: sb.server.exec needs')),
        'denied',
      );
      expect(
        pluginFailureTag(Exception('the app did not answer within 30s')),
        'timeout',
      );
      expect(
        pluginFailureTag(Exception('sb.ui.prompt is not available on agent')),
        'unavailable',
      );
      expect(
        pluginFailureTag(Exception('invalid plugin: unexpected token')),
        'module',
      );
    });

    /// The whole report, against the things that reach this code and must not
    /// come out the other side.
    test('nothing a plugin or a server said is in the text', () {
      final text = write(
        health: {
          'app.serverbox.zfs': healthWith(
            failure: PluginEvent(
              stage: PluginStage.exec,
              at: at,
              elapsed: Duration.zero,
              failure: pluginFailureTag(
                StateError('du: /srv/customer-data: Permission denied'),
              ),
            ),
            since: 1,
          ),
        },
      );

      expect(text, isNot(contains('customer-data')));
      expect(text, isNot(contains('/srv')));
      // And it says what it left out, where somebody deciding whether to send
      // it will read it.
      expect(text, contains('are not collected'));
    });
  });

  test('no plugins is a report that says so rather than an empty one', () {
    expect(write(plugins: const []), contains('No plugins are installed'));
  });
}
