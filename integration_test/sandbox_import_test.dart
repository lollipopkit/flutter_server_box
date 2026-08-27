import 'dart:io';

import 'package:fl_lib/fl_lib.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:server_box/core/utils/sandbox_import.dart';
import 'package:server_box/data/res/build_data.dart';

/// What `flutter test` cannot answer about taking over the sandboxed build's
/// data.
///
/// The unit suite passes every dependency in, so it never asks where this
/// build's data actually goes, never runs `defaults`, and never touches the
/// keychain. Those are the three things that decide whether the import works
/// on a real machine, and all three need a real app around them.
///
/// Nothing here reads or writes the real container, the real preferences or
/// the real keychain item: the container is only ever read by the app itself,
/// and a test that wrote to any of those would be editing the data of whoever
/// ran it.
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    await Paths.init(BuildData.name);
  });

  test('the data directory follows the entitlement, not the platform', () {
    if (Pfs.isMacSandboxed) {
      // The container is the sandboxed build's documents directory, and where
      // every install to date has its data.
      expect(Paths.doc, contains('/Library/Containers/'));
      expect(Paths.doc, endsWith('/Data/Documents'));
      return;
    }

    // Not `~/Documents`, which is the user's own folder and behind a
    // permission prompt this app has no way to explain.
    expect(
      Paths.doc,
      endsWith('/Library/Application Support/${BuildData.name}'),
    );
    expect(Directory(Paths.doc).existsSync(), true);
  }, skip: !Platform.isMacOS ? 'macOS-only integration test' : null);

  test('the container is where the other build put it', () async {
    final container = SandboxImport.containerData;
    expect(container, isNotNull);
    expect(
      container,
      endsWith('/Library/Containers/${SandboxImport.bundleId}/Data'),
    );
    // Asked of this build, answered about the other one: the path must not
    // depend on which of the two is running.
    expect(container, isNot(contains('Application Support')));

    // And the id it is built from is this app's own. Both builds carry the
    // same one, so a rename here would leave the import reading a container
    // nothing has ever written to — silently, and only on a user's machine.
    final running = await _runningBundleId();
    if (running != null) expect(SandboxImport.bundleId, running);
  }, skip: !Platform.isMacOS ? 'macOS-only integration test' : null);

  test('the keychain answers whether the boxes could be decrypted', () async {
    // Only that the question can be asked in a real app — the answer depends
    // on the machine, and on a signed DMG it is the one thing this whole
    // feature rests on. `flutter test` cannot ask it at all: the plugin is not
    // there.
    expect(await SandboxImport.hasBoxKey(), isA<bool>());
  }, skip: !Platform.isMacOS ? 'macOS-only integration test' : null);

  test('preferences come across the way `defaults` reports them', () async {
    final dir = await Directory.systemTemp.createTemp('sbm_prefs');
    addTearDown(() => dir.delete(recursive: true));
    final plist = '${dir.path}/prefs';

    Future<void> write(String key, List<String> value) async {
      final res = await Process.run('defaults', [
        'write',
        plist,
        key,
        ...value,
      ]);
      expect(res.exitCode, 0, reason: res.stderr.toString());
    }

    await write('webdav_url', ['-string', 'https://dav.example/remote.php']);
    await write('webdav_sync', ['-bool', 'true']);
    await write('last_ver', ['-int', '1480']);
    // Not in the list of keys worth carrying: the container's plist is also
    // full of this app's pre-Hive settings and macOS's own window state.
    await write('setting.locale', ['-string', 'zh']);

    final imported = <String, Object>{};
    await SandboxImport.importPrefs(
      plist,
      write: (key, value) async => imported[key] = value,
    );

    expect(imported['webdav_url'], 'https://dav.example/remote.php');
    expect(imported['webdav_sync'], true);
    expect(imported['last_ver'], 1480);
    expect(imported.containsKey('setting.locale'), false);
  }, skip: !Platform.isMacOS ? 'macOS-only integration test' : null);

  test('a container of plain boxes is copied into a real directory', () async {
    final src = await Directory.systemTemp.createTemp('sbm_src');
    final dest = await Directory.systemTemp.createTemp('sbm_dest');
    addTearDown(() async {
      await src.delete(recursive: true);
      await dest.delete(recursive: true);
    });

    await File('${src.path}/conn_stats_index.hive').writeAsString('box');
    await File('${src.path}/app.db').writeAsString('db');

    final result = await SandboxImport.importFrom(
      src: src,
      dest: dest,
      importPrefs: () async {},
      // Plain boxes need none, and asking the real keychain here would make
      // the result depend on the machine.
      hasKey: () async => false,
    );

    expect(result, SandboxImportResult.imported);
    expect(File('${dest.path}/conn_stats_index.hive').existsSync(), true);
    expect(File('${dest.path}/app.db').existsSync(), true);
    expect(File('${dest.path}/${SandboxImport.doneMarker}').existsSync(), true);
  }, skip: !Platform.isMacOS ? 'macOS-only integration test' : null);
}

/// The bundle id of the app this test is running inside, or null when it is
/// not running from a bundle at all.
Future<String?> _runningBundleId() async {
  const marker = '.app/Contents/MacOS/';
  final exe = Platform.resolvedExecutable;
  final idx = exe.indexOf(marker);
  if (idx < 0) return null;
  final info = '${exe.substring(0, idx)}.app/Contents/Info';
  final res = await Process.run('defaults', [
    'read',
    info,
    'CFBundleIdentifier',
  ]);
  if (res.exitCode != 0) return null;
  final id = res.stdout.toString().trim();
  return id.isEmpty ? null : id;
}
