/// The development loop: edit, build, look. PLUGINS.md 8.2.
///
/// A plugin loaded from a directory is re-read on every refresh, and until this
/// existed nothing refreshed — so seeing a one-line change meant quitting the
/// app, starting it again and navigating back to the page. What these hold is
/// that a change to any of the three kinds of file the app reads brings the new
/// one in, and that nothing else does.
library;

import 'dart:convert';
import 'dart:io';

import 'package:fl_lib/fl_lib.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:server_box/core/utils/plugin/package.dart';
import 'package:server_box/data/model/plugin/contributions.dart';
import 'package:server_box/data/provider/plugin/dev_watcher.dart';
import 'package:server_box/data/provider/plugin/installer.dart';
import 'package:server_box/data/res/store.dart';
import 'package:server_box/data/store/plugin.dart';
import 'package:server_box/data/store/setting.dart';

import 'helpers/test_db.dart';
import 'rust_lib_helper.dart';

String _manifest({String name = 'ZFS'}) => jsonEncode({
  'id': 'app.serverbox.zfs',
  'version': '1.0.0',
  'abi': 1,
  'name': name,
  'permissions': {'server.exec': true},
  'l10n': ['en'],
});

void main() {
  setUpAll(initRustLibForTest);

  late Directory root;
  late Directory dev;
  late PluginInstaller installer;
  late SettingStore setting;

  setUp(() async {
    await openTestDb();
    setting = SettingStore('setting_test');
    getIt.registerSingleton<SettingStore>(setting);
    root = await Directory.systemTemp.createTemp('sbm_plugins');
    dev = await Directory.systemTemp.createTemp('sbm_plugin_dev');
    installer = PluginInstaller(root: root, store: PluginInstallStore());
    PluginContributions.clear();

    await File(dev.path.joinPath(PluginPackage.manifestName))
        .writeAsString(_manifest());
    await File(dev.path.joinPath(PluginPackage.sourceName))
        .writeAsString('export function open() { return { ui: null }; }');
    await Directory(dev.path.joinPath('l10n')).create();
    await File(dev.path.joinPath('l10n/en.json'))
        .writeAsString(jsonEncode({'greet': 'hello'}));

    await installer.addDevDir(dev.path, consented: {'server.exec'});
  });

  tearDown(() async {
    PluginContributions.clear();
    await getIt.reset();
    await closeTestDb();
    for (final d in [root, dev]) {
      if (d.existsSync()) d.deleteSync(recursive: true);
    }
  });

  /// The watcher polls, so a test drives it the way time would — with a
  /// timestamp that has actually moved. A filesystem's resolution is coarse
  /// enough that writing twice in the same millisecond looks like one write.
  Future<void> touch(File file, String content) async {
    await file.writeAsString(content);
    await file.setLastModified(DateTime.now().add(const Duration(seconds: 2)));
  }

  test('it watches the script, the manifest and the translations', () {
    final watched = PluginDevWatcher.filesOf(dev.path).map((f) => f.path);

    expect(watched, contains(dev.path.joinPath(PluginPackage.sourceName)));
    expect(watched, contains(dev.path.joinPath(PluginPackage.manifestName)));
    // A new key is exactly the edit somebody makes and then wonders why the
    // row still says `l10n.something`.
    expect(watched, contains(dev.path.joinPath('l10n/en.json')));
  });

  /// The loop itself: the app is holding one script and the directory has
  /// another, and a refresh is what closes the gap.
  test('a changed script is what the next load runs', () async {
    expect(
      (await installer.refresh()).single.source,
      contains('return { ui: null }'),
    );

    await touch(
      File(dev.path.joinPath(PluginPackage.sourceName)),
      'export function open() { return { ui: 1 }; }',
    );

    expect(
      (await installer.refresh()).single.source,
      contains('return { ui: 1 }'),
    );
  });

  /// The manifest decides what a plugin is called and where it appears, so an
  /// edit to it has to reach the registry rather than only the files.
  test('a changed manifest reaches what the app draws', () async {
    await installer.refresh();
    expect(PluginContributions.byId('app.serverbox.zfs')?.name, 'ZFS');

    await touch(
      File(dev.path.joinPath(PluginPackage.manifestName)),
      _manifest(name: 'Pools'),
    );
    await installer.refresh();

    expect(PluginContributions.byId('app.serverbox.zfs')?.name, 'Pools');
  });

  /// A directory that has been removed from the list is not watched, or the
  /// app would keep reading files the user has said it is done with.
  test('nothing is watched once the directory is forgotten', () async {
    setting.pluginDevDirs.put(const []);

    final watcher = PluginDevWatcher(installer: installer);
    watcher.start();
    addTearDown(watcher.stop);

    expect(setting.pluginDevDirs.fetch(), isEmpty);
  });
}
