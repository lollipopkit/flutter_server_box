/// The store themes the app ships: the bytes the store publishes, installed
/// once on a device and updated from the store like any other.
library;

import 'dart:io';

import 'package:archive/archive.dart';
import 'package:fl_lib/theme.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:server_box/core/service/theme_host.dart';
import 'package:server_box/data/res/store.dart';
import 'package:server_box/data/store/setting.dart';

import '../helpers/test_db.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final bundled = Directory(themeBundledDir)
      .listSync()
      .whereType<File>()
      .where((f) => f.path.endsWith('.fsbt'))
      .toList();

  test('something is bundled', () => expect(bundled, isNotEmpty));

  for (final file in bundled) {
    final id = file.uri.pathSegments.last.replaceFirst(RegExp(r'\.fsbt$'), '');
    test('$id is the store folder, byte for byte', () {
      // Shipped bytes that drifted from `store/` would be a version the store
      // never published; repack with the skill's pack.py after editing it.
      final folder = Directory('store/themes/$id');
      final expected = {
        for (final f in folder.listSync(recursive: true).whereType<File>())
          if (!f.path
              .substring(folder.path.length + 1)
              .split('/')
              .any((part) => part.startsWith('.')))
            f.path.substring(folder.path.length + 1): f.readAsBytesSync(),
      };
      final archive = ZipDecoder().decodeBytes(file.readAsBytesSync());
      final actual = {
        for (final entry in archive.files)
          if (entry.isFile) entry.name: entry.content as List<int>,
      };
      expect(actual.keys, unorderedEquals(expected.keys));
      for (final MapEntry(:key, :value) in expected.entries) {
        expect(actual[key], value, reason: key);
      }
    });
  }

  group('seeding', () {
    late Directory root;
    setUp(() async {
      await openTestDb();
      getIt.registerSingleton<SettingStore>(SettingStore('setting_test'));
      root = await Directory.systemTemp.createTemp('bundled-themes-');
    });
    tearDown(() async {
      await root.delete(recursive: true);
      await getIt.unregister<SettingStore>();
      await closeTestDb();
    });

    test('installs once, and not again once removed', () async {
      // What a page showing the installed list listens to, since the install
      // happens after launch and off that page.
      final before = ThemePackages.installedChanged.value;
      await ThemePackages.seedBundled(
        bundle: rootBundle,
        rootDirectory: root.path,
      );
      final first = ThemePackages.listInstalled(rootDirectory: root.path);
      expect(first.map((t) => t.id), contains('serverbox.piggy'));
      expect(
        Stores.setting.bundledThemesSeeded.fetch(),
        contains('serverbox.piggy'),
      );

      expect(ThemePackages.installedChanged.value, greaterThan(before));

      final piggy = first.firstWhere((t) => t.id == 'serverbox.piggy');
      final installedAt = ThemePackages.installedChanged.value;
      await ThemePackages.remove(piggy.installationId, rootDirectory: root.path);
      expect(ThemePackages.installedChanged.value, installedAt + 1);
      await ThemePackages.seedBundled(
        bundle: rootBundle,
        rootDirectory: root.path,
      );
      expect(
        ThemePackages.listInstalled(rootDirectory: root.path).map((t) => t.id),
        isNot(contains('serverbox.piggy')),
      );
    });

    test('leaves a copy already on the device alone', () async {
      final folder = await ThemePackages.installFolder(
        'store/themes/serverbox.piggy',
        rootDirectory: root.path,
      );
      await ThemePackages.seedBundled(
        bundle: rootBundle,
        rootDirectory: root.path,
      );
      final installed = ThemePackages.listInstalled(rootDirectory: root.path);
      expect(installed.map((t) => t.installationId), [folder.installationId]);
      expect(
        Stores.setting.bundledThemesSeeded.fetch(),
        contains('serverbox.piggy'),
      );
    });
  });
}
