/// Putting a plugin on the device and taking it off again. PLUGINS.md
/// section 7, and the part of section 5 that decides where it shows up.
///
/// Build the native library first: cargo build -p sbm_ffi
library;

import 'dart:convert';
import 'dart:io';

import 'package:archive/archive.dart';
import 'package:fl_lib/fl_lib.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:server_box/core/utils/plugin/package.dart';
import 'package:server_box/data/model/app/feature.dart';
import 'package:server_box/data/model/plugin/contributions.dart';
import 'package:server_box/data/model/plugin/install.dart';
import 'package:server_box/data/provider/plugin/installer.dart';
import 'package:server_box/data/res/store.dart';
import 'package:server_box/data/store/plugin.dart';
import 'package:server_box/data/store/setting.dart';

import 'helpers/test_db.dart';
import 'rust_lib_helper.dart';

String _manifest({
  String id = 'app.serverbox.zfs',
  String version = '1.0.0',
  bool status = true,
  bool defaultOn = true,
  List<String> permissions = const ['server.exec'],
}) => jsonEncode({
  'id': id,
  'version': version,
  'abi': 1,
  'name': 'ZFS',
  'permissions': {for (final p in permissions) p: true},
  if (status)
    'contributes': {
      'status': {
        'id': 'zfs',
        'label': 'ZFS',
        'default_on': defaultOn,
        'platforms': ['linux'],
      },
    },
});

/// A `.sbp`, built the way one arrives.
List<int> sbp({
  String? manifest,
  String source = 'export function statusCmd() { return { cmd: "zpool list" }; }',
  Map<String, Object?> l10n = const {'en': {'title': 'Pools'}},
  List<int>? icon,
  Map<String, List<int>> extra = const {},
}) {
  final archive = Archive();
  void add(String name, List<int> bytes) =>
      archive.add(ArchiveFile.bytes(name, bytes));

  add(PluginPackage.manifestName, utf8.encode(manifest ?? _manifest()));
  add(PluginPackage.sourceName, utf8.encode(source));
  for (final e in l10n.entries) {
    add('${PluginPackage.l10nDir}${e.key}.json', utf8.encode(jsonEncode(e.value)));
  }
  if (icon != null) add(PluginPackage.iconName, icon);
  for (final e in extra.entries) {
    add(e.key, e.value);
  }
  return ZipEncoder().encode(archive);
}

void main() {
  setUpAll(initRustLibForTest);

  group('reading a package', () {
    test('it comes back with everything that was in it', () {
      final package = PluginPackage.read(
        sbp(icon: [1, 2, 3], l10n: const {
          'en': {'title': 'Pools'},
          'zh': {'title': '存储池'},
        }),
      );

      expect(package.manifestJson, contains('app.serverbox.zfs'));
      expect(package.source, contains('zpool list'));
      expect(package.icon, [1, 2, 3]);
      expect(package.l10nFor('zh').resolve('l10n.title'), '存储池');
      expect(package.l10nFor('fr').resolve('l10n.title'), 'Pools');
      // A locale is more specific than its language, and a package may ship
      // both.
      expect(package.l10nFor('zh-Hans').resolve('l10n.title'), '存储池');
    });

    /// The classic archive attack. Nothing is written before the whole package
    /// has been read, which is what makes refusing here enough.
    test('a path that escapes the directory is refused', () {
      for (final name in const [
        '../../evil.js',
        '/etc/passwd',
        r'..\..\evil.js',
        r'C:\evil.js',
      ]) {
        expect(
          () => PluginPackage.read(sbp(extra: {name: utf8.encode('x')})),
          throwsA(isA<PluginPackageError>()),
          reason: name,
        );
      }
    });

    /// A zip bomb is a few kilobytes that decompresses to whatever the reader
    /// will hold, and this is an archive from somewhere else.
    test('an entry larger than the cap is refused', () {
      final huge = List.filled(PluginPackage.maxEntryBytes + 1, 0x41);
      expect(
        () => PluginPackage.read(sbp(extra: {'big.bin': huge})),
        throwsA(isA<PluginPackageError>()),
      );
    });

    test('a package missing either required file is refused', () {
      final archive = Archive()
        ..add(ArchiveFile.bytes('plugin.js', utf8.encode('x')));
      expect(
        () => PluginPackage.read(ZipEncoder().encode(archive)),
        throwsA(
          isA<PluginPackageError>().having(
            (e) => e.message,
            'message',
            contains('manifest.json'),
          ),
        ),
      );
      expect(
        () => PluginPackage.read(utf8.encode('not a zip')),
        throwsA(isA<PluginPackageError>()),
      );
    });

    /// One locale's file costs that locale: the plugin shows its keys there
    /// and works in `en`.
    test('a translation file that will not parse costs that locale', () {
      final archive = Archive()
        ..add(ArchiveFile.bytes('manifest.json', utf8.encode(_manifest())))
        ..add(ArchiveFile.bytes('plugin.js', utf8.encode('x')))
        ..add(ArchiveFile.bytes('l10n/en.json', utf8.encode('{"a": "A"}')))
        ..add(ArchiveFile.bytes('l10n/zh.json', utf8.encode('{')));

      final package = PluginPackage.read(ZipEncoder().encode(archive));

      expect(package.l10nFor('zh').resolve('l10n.a'), 'A');
    });
  });

  group('installing', () {
    late Directory root;
    late PluginInstaller installer;
    late SettingStore setting;

    setUp(() async {
      await openTestDb();
      setting = SettingStore('setting_test');
      getIt.registerSingleton<SettingStore>(setting);
      root = await Directory.systemTemp.createTemp('sbm_plugins');
      installer = PluginInstaller(root: root, store: PluginInstallStore());
      PluginContributions.clear();
    });

    tearDown(() async {
      PluginContributions.clear();
      await getIt.reset();
      await closeTestDb();
      if (await root.exists()) await root.delete(recursive: true);
    });

    test('the files, the record and the arrangement all move', () async {
      final plugin = await installer.install(sbp(), consented: {'server.exec'});

      expect(plugin.id, 'app.serverbox.zfs');
      expect(
        File(installer.dirOf(plugin.id).path.joinPath('plugin.js')).existsSync(),
        isTrue,
      );
      expect(PluginInstallStore().fetch(plugin.id)?.version, '1.0.0');
      // `default_on`, which is what replaces `introducedAfterBuild` for a
      // plugin: it is installed by the moment a boundary would have named.
      expect(
        FeatureSlot.detailCard.enabledIds(),
        contains('app.serverbox.zfs:zfs'),
      );
      expect(
        Features.of(FeatureSlot.detailCard).map((f) => f.id),
        contains('app.serverbox.zfs:zfs'),
      );
    });

    /// Each contribution goes in its own slot and only its own. An id in a row
    /// that has nothing to draw for it is a gap the user cannot explain.
    test('a status contribution does not land in the function bar', () async {
      await installer.install(sbp(), consented: {'server.exec'});

      expect(
        FeatureSlot.funcBtn.enabledIds(),
        isNot(contains('app.serverbox.zfs:zfs')),
      );
      expect(Features.of(FeatureSlot.funcBtn).map((f) => f.id),
          isNot(contains('app.serverbox.zfs:zfs')));
    });

    /// An update that adds a permission must not be able to use it before the
    /// user has seen it (section 6.2).
    test('only what was consented to is granted', () async {
      final plugin = await installer.install(
        sbp(manifest: _manifest(permissions: ['server.exec', 'clipboard'])),
        consented: {'server.exec'},
      );

      expect(plugin.record.granted, {'server.exec'});
      expect(plugin.granted, ['server.exec']);
      expect(plugin.needsConsent, isTrue);
    });

    test('consent to something the manifest never asked for grants nothing',
        () async {
      final plugin = await installer.install(
        sbp(),
        consented: {'server.exec', 'net.http'},
      );

      expect(plugin.record.granted, {'server.exec'});
    });

    /// The user took it out of their arrangement. An update putting it back
    /// would overrule that decision every time, forever.
    test('an update does not restore an entry the user removed', () async {
      await installer.install(sbp(), consented: {'server.exec'});
      FeatureSlot.detailCard.putEnabledIds(
        FeatureSlot.detailCard
            .enabledIds()
            .where((id) => id != 'app.serverbox.zfs:zfs')
            .toList(),
      );

      await installer.install(
        sbp(manifest: _manifest(version: '2.0.0')),
        consented: {'server.exec'},
      );

      expect(PluginInstallStore().fetch('app.serverbox.zfs')?.version, '2.0.0');
      expect(
        FeatureSlot.detailCard.enabledIds(),
        isNot(contains('app.serverbox.zfs:zfs')),
      );
    });

    test('and does not switch one the user turned off back on', () async {
      await installer.install(sbp(), consented: {'server.exec'});
      await installer.setEnabled('app.serverbox.zfs', false);

      await installer.install(
        sbp(manifest: _manifest(version: '2.0.0')),
        consented: {'server.exec'},
      );

      expect(
        PluginInstallStore().fetch('app.serverbox.zfs')?.enabled,
        isFalse,
      );
      // And a plugin that is off contributes nothing, while keeping its place.
      expect(Features.of(FeatureSlot.detailCard).map((f) => f.id),
          isNot(contains('app.serverbox.zfs:zfs')));
      expect(
        FeatureSlot.detailCard.enabledIds(),
        contains('app.serverbox.zfs:zfs'),
        reason: 'switching it off is not the same as removing it',
      );
    });

    test('uninstalling takes the files, the record and the place', () async {
      await installer.install(sbp(), consented: {'server.exec'});
      PluginKvStore().put('app.serverbox.zfs', 'k', 'v');

      await installer.uninstall('app.serverbox.zfs');

      expect(installer.dirOf('app.serverbox.zfs').existsSync(), isFalse);
      expect(PluginInstallStore().fetch('app.serverbox.zfs'), isNull);
      expect(PluginKvStore().fetch('app.serverbox.zfs', 'k'), isNull);
      expect(
        FeatureSlot.detailCard.enabledIds(),
        isNot(contains('app.serverbox.zfs:zfs')),
      );
    });

    test('and keeps the data when that is what was asked', () async {
      await installer.install(sbp(), consented: {'server.exec'});
      PluginKvStore().put('app.serverbox.zfs', 'k', 'v');

      await installer.uninstall('app.serverbox.zfs', keepData: true);

      expect(PluginKvStore().fetch('app.serverbox.zfs', 'k'), 'v');
    });

    /// An app that cannot start because of something the user installed is
    /// worse than one plugin that does not appear.
    test('a record whose files are gone is skipped, not fatal', () async {
      await installer.install(sbp(), consented: {'server.exec'});
      await installer.dirOf('app.serverbox.zfs').delete(recursive: true);

      final plugins = await installer.refresh();

      expect(plugins, isEmpty);
      expect(PluginContributions.active, isEmpty);
      expect(
        Features.of(FeatureSlot.detailCard).map((f) => f.id),
        isNot(contains('app.serverbox.zfs:zfs')),
      );
    });

    test('a manifest this build refuses is not installed at all', () async {
      final ahead = jsonEncode({
        'id': 'x',
        'version': '1',
        'abi': 99,
        'name': 'X',
      });

      await expectLater(
        installer.install(sbp(manifest: ahead), consented: const {}),
        throwsA(isA<Object>()),
      );
      expect(installer.dirOf('x').existsSync(), isFalse);
      expect(PluginInstallStore().readAll(), isEmpty);
    });

    test('reading them back gives the same plugin', () async {
      await installer.install(
        sbp(l10n: const {
          'en': {'title': 'Pools'},
          'zh': {'title': '存储池'},
        }),
        consented: {'server.exec'},
      );

      final plugins = await installer.refresh();

      expect(plugins, hasLength(1));
      final plugin = plugins.single;
      expect(plugin.manifest.status?.id, 'zfs');
      expect(plugin.source, contains('zpool list'));
      expect(plugin.l10nFor('zh').resolve('l10n.title'), '存储池');
      expect(
        PluginContributions.ofFeature('app.serverbox.zfs:zfs')?.id,
        'app.serverbox.zfs',
      );
    });

    test('a bundled plugin has no repository, a dev one says so', () async {
      final bundled = await installer.install(sbp(), consented: const {});
      expect(bundled.record.bundled, isTrue);

      final dev = await installer.install(
        sbp(manifest: _manifest(id: 'app.serverbox.dev')),
        consented: const {},
        repo: PluginInstall.devRepo,
      );
      expect(dev.record.isDev, isTrue);
    });
  });
}
