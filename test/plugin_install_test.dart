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
import 'package:server_box/core/utils/plugin/assets.dart';
import 'package:server_box/core/utils/plugin/package.dart';
import 'package:server_box/data/model/app/feature.dart';
import 'package:server_box/data/model/plugin/contributions.dart';
import 'package:server_box/data/model/plugin/install.dart';
import 'package:server_box/data/provider/plugin/installer.dart';
import 'package:server_box/data/res/store.dart';
import 'package:server_box/data/store/migrations/m025_plugin_previous.dart';
import 'package:server_box/data/store/plugin.dart';
import 'package:server_box/data/store/setting.dart';
import 'package:server_box/view/page/home_tab.dart';
import 'package:server_box/view/page/setting/entries/plugin_settings.dart';

import 'helpers/plugin_sbp.dart';
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
}) => buildSbp(
  manifest: manifest ?? _manifest(),
  source: source,
  l10n: l10n,
  icon: icon,
  extra: extra,
);

void main() {
  setUpAll(initRustLibForTest);

  _migration();

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

    test('Simplified Chinese aliases the zh-CN package locale', () {
      final package = PluginPackage.read(
        sbp(l10n: const {
          'en': {'title': 'Pools'},
          'zh-CN': {'title': '存储池'},
        }),
      );

      expect(package.l10nFor('zh').resolve('l10n.title'), '存储池');
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
    /// **An update that turns out to be broken has to be undoable.** The old
    /// files used to be deleted before the new ones moved in, so recovering
    /// meant finding a `.sbp` for the version before — which for a repository
    /// install is a release nobody keeps a link to.
    group('going back to the version before', () {
      Future<void> installVersion(
        String version, {
        int dataVersion = 0,
        Set<String> consented = const {'server.exec'},
      }) async {
        await installer.install(
          sbp(
            manifest: jsonEncode({
              'id': 'app.serverbox.zfs',
              'version': version,
              'abi': 1,
              if (dataVersion != 0) 'data_version': dataVersion,
              'name': 'ZFS',
              'permissions': {'server.exec': true},
            }),
            source: 'export function open() { return { ui: null }; }',
          ),
          consented: consented,
        );
      }

      test('a first install has nothing to go back to', () async {
        await installVersion('1.0.0');

        expect(await installer.rollbackOf('app.serverbox.zfs'), isNull);
        expect(installer.prevDirOf('app.serverbox.zfs').existsSync(), isFalse);
      });

      test('an update keeps the version it replaced', () async {
        await installVersion('1.0.0');
        await installVersion('1.1.0');

        final back = await installer.rollbackOf('app.serverbox.zfs');
        expect(back, isNotNull);
        expect(back!.from, '1.1.0');
        expect(back.to, '1.0.0');
        expect(back.dataCompatible, isTrue);
      });

      test('going back restores the files and the record', () async {
        await installVersion('1.0.0');
        await installVersion('1.1.0');

        final plugin = await installer.rollback('app.serverbox.zfs');

        expect(plugin?.manifest.version, '1.0.0');
        expect(PluginInstallStore().fetch('app.serverbox.zfs')?.version, '1.0.0');
        // The files on disk, not only the record: the two disagreeing is what
        // "installed 1.0.1 and ran 1.1.0" was.
        final manifest = File(
          installer.dirOf('app.serverbox.zfs').path.joinPath('manifest.json'),
        ).readAsStringSync();
        expect(jsonDecode(manifest), containsPair('version', '1.0.0'));
      });

      /// **`granted` is consent and cannot be re-derived.** Reading it back
      /// off the old manifest would grant whatever that version asked for,
      /// which is exactly what the install dialog exists to prevent.
      test('and what the user had agreed to, not what the manifest asks',
          () async {
        await installVersion('1.0.0', consented: const {});
        await installVersion('1.1.0', consented: const {'server.exec'});
        expect(
          PluginInstallStore().fetch('app.serverbox.zfs')?.granted,
          {'server.exec'},
        );

        await installer.rollback('app.serverbox.zfs');

        expect(PluginInstallStore().fetch('app.serverbox.zfs')?.granted, isEmpty);
      });

      /// One level. Two updates back is not a state anybody asked for, and
      /// keeping every version a plugin has ever been is a directory that only
      /// grows.
      test('only one version is kept, however many updates there were',
          () async {
        await installVersion('1.0.0');
        await installVersion('1.1.0');
        await installVersion('1.2.0');

        expect((await installer.rollbackOf('app.serverbox.zfs'))?.to, '1.1.0');
      });

      test('and going back twice is not offered', () async {
        await installVersion('1.0.0');
        await installVersion('1.1.0');
        await installer.rollback('app.serverbox.zfs');

        expect(await installer.rollbackOf('app.serverbox.zfs'), isNull);
        expect(installer.prevDirOf('app.serverbox.zfs').existsSync(), isFalse);
      });

      /// **A version that raised `data_version` writes records the version
      /// before it cannot read** — and the old code will not say so, it will
      /// misread them. Offered anyway, because whether that is worse than the
      /// update being broken is the user's call; what is not optional is
      /// telling them.
      test('a data format change is reported rather than hidden', () async {
        await installVersion('1.0.0');
        await installVersion('2.0.0', dataVersion: 1);

        final back = await installer.rollbackOf('app.serverbox.zfs');
        expect(back, isNotNull);
        expect(back!.dataCompatible, isFalse);
      });

      test('an unchanged data version reads as compatible', () async {
        await installVersion('1.0.0', dataVersion: 2);
        await installVersion('1.1.0', dataVersion: 2);

        expect(
          (await installer.rollbackOf('app.serverbox.zfs'))?.dataCompatible,
          isTrue,
        );
      });

      test('uninstalling takes the kept version with it', () async {
        await installVersion('1.0.0');
        await installVersion('1.1.0');

        await installer.uninstall('app.serverbox.zfs');

        expect(installer.prevDirOf('app.serverbox.zfs').existsSync(), isFalse);
      });

      /// The window between the two renames: a process that died there left a
      /// record naming files that are not on disk, and every launch after that
      /// skipped the plugin without saying why.
      test('an install interrupted between the two renames is put back',
          () async {
        await installVersion('1.0.0');
        await installVersion('1.1.0');

        // What a crash after the first rename and before the second leaves.
        installer.dirOf('app.serverbox.zfs').deleteSync(recursive: true);

        final plugins = await installer.refresh();

        expect(plugins.single.manifest.version, '1.0.0');
        expect(PluginInstallStore().fetch('app.serverbox.zfs')?.version, '1.0.0');
        expect(installer.prevDirOf('app.serverbox.zfs').existsSync(), isFalse);
      });

      /// And one that died while unpacking leaves a whole copy of a package
      /// nothing points at.
      test('a staging directory nothing finished is cleaned up', () async {
        await installVersion('1.0.0');
        final staging = Directory('${installer.dirOf('app.serverbox.zfs').path}.new');
        staging.createSync(recursive: true);
        File(staging.path.joinPath('manifest.json')).writeAsStringSync('{}');

        await installer.refresh();

        expect(staging.existsSync(), isFalse);
        // And the installed copy is untouched.
        expect(
          File(
            installer.dirOf('app.serverbox.zfs').path.joinPath('manifest.json'),
          ).existsSync(),
          isTrue,
        );
      });
    });

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

    /// A development directory is read where it sits, not copied.
    ///
    /// That is the whole point of it: editing `plugin.js` and restarting is
    /// the cycle, and a copy under the app would mean repackaging to see a
    /// one-line change. So the test edits the file and refreshes.
    test('a development directory is read where it sits', () async {
      final dir = await Directory.systemTemp.createTemp('sbm_plugin_dev');
      addTearDown(() => dir.delete(recursive: true));
      await File(dir.path.joinPath(PluginPackage.manifestName))
          .writeAsString(_manifest());
      await File(dir.path.joinPath(PluginPackage.sourceName))
          .writeAsString('export function statusCmd() { return { cmd: "a" }; }');

      final plugin = await installer.addDevDir(dir.path, consented: const {});
      expect(plugin.id, 'app.serverbox.zfs');
      expect(plugin.record.isDev, isTrue);
      expect(setting.pluginDevDirs.fetch(), [dir.path]);
      // Nothing copied: the app's own root has no directory for it.
      expect(installer.dirOf(plugin.id).existsSync(), isFalse);
      expect(
        FeatureSlot.detailCard.enabledIds(),
        contains('app.serverbox.zfs:zfs'),
      );

      // A refresh that read the same bytes is not a change, and must not
      // rebuild every open plugin surface. The settings page re-reads every
      // directory whenever it is opened, so this is the common case.
      final quiet = PluginContributions.revision.value;
      await installer.refresh();
      expect(
        PluginContributions.revision.value,
        quiet,
        reason: 'nothing changed, so nothing to tell anyone',
      );

      // An edit, and a refresh is enough to see it.
      await File(dir.path.joinPath(PluginPackage.sourceName))
          .writeAsString('export function statusCmd() { return { cmd: "b" }; }');
      final before = PluginContributions.revision.value;
      final refreshed = await installer.refresh();
      expect(refreshed.single.source, contains('"b"'));
      // The other half of picking that edit up: a surface already on screen
      // holds the plugin it was opened with, and this is what tells it to look
      // again. Without it the reload existed and nothing ever ran it.
      expect(
        PluginContributions.revision.value,
        greaterThan(before),
        reason: 'a republished set has to reach an open surface',
      );
      expect(
        PluginContributions.byId('app.serverbox.zfs')?.source,
        contains('"b"'),
      );

      // And removing it takes the record and the arrangement, but not the
      // developer's files.
      await installer.removeDevDir(dir.path);
      expect(setting.pluginDevDirs.fetch(), isEmpty);
      expect(PluginInstallStore().fetch('app.serverbox.zfs'), isNull);
      expect(
        FeatureSlot.detailCard.enabledIds(),
        isNot(contains('app.serverbox.zfs:zfs')),
      );
      expect(
        File(dir.path.joinPath(PluginPackage.sourceName)).existsSync(),
        isTrue,
      );
    });

    /// Uninstalling from the list has to reach the setting too, or the
    /// directory is loaded again on the next launch — an uninstall that does
    /// not stick.
    test('uninstalling a dev plugin forgets its directory', () async {
      final dir = await Directory.systemTemp.createTemp('sbm_plugin_dev');
      addTearDown(() => dir.delete(recursive: true));
      await File(dir.path.joinPath(PluginPackage.manifestName))
          .writeAsString(_manifest());
      await File(dir.path.joinPath(PluginPackage.sourceName))
          .writeAsString('export function statusCmd() { return { cmd: "a" }; }');

      await installer.addDevDir(dir.path, consented: const {});
      expect(await installer.devDirs(), {'app.serverbox.zfs': dir.path});

      await installer.uninstall('app.serverbox.zfs');
      expect(setting.pluginDevDirs.fetch(), isEmpty);
      expect(await installer.refresh(), isEmpty);
    });

    test('an install records where it came from', () async {
      final fromFile = await installer.install(
        sbp(),
        consented: const {},
        repo: PluginInstall.fileRepo,
      );
      expect(fromFile.record.origin, PluginOrigin.file);

      final dev = await installer.install(
        sbp(manifest: _manifest(id: 'app.serverbox.dev')),
        consented: const {},
        repo: PluginInstall.devRepo,
      );
      expect(dev.record.isDev, isTrue);
    });

    /// A directory used to win over the app's own copy for any id it named, so
    /// installing a package for a plugin that was also registered as a working
    /// tree wrote a record naming a version and a repository — and then kept
    /// loading the tree. The record said 1.0.1 from GitHub; the app ran 1.1.0
    /// from `dist/`, and nothing on either page could say so.
    test('installing a package takes the id back from a development directory',
        () async {
      final dir = await Directory.systemTemp.createTemp('sbm_plugin_dev');
      addTearDown(() => dir.delete(recursive: true));
      await File(dir.path.joinPath(PluginPackage.manifestName))
          .writeAsString(_manifest(version: '9.9.9'));
      await File(dir.path.joinPath(PluginPackage.sourceName))
          .writeAsString('export function statusCmd() { return { cmd: "d" }; }');

      await installer.addDevDir(dir.path, consented: const {});
      expect(setting.pluginDevDirs.fetch(), [dir.path]);

      await installer.install(
        sbp(manifest: _manifest(version: '1.0.1')),
        consented: const {},
        repo: 'https://github.com/o/r',
      );

      // The registration is gone, so the next refresh cannot bring the
      // directory back.
      expect(setting.pluginDevDirs.fetch(), isEmpty);
      final plugin = (await installer.refresh()).single;
      expect(plugin.record.origin, PluginOrigin.repo);
      expect(plugin.record.version, '1.0.1');
      expect(plugin.manifest.version, '1.0.1', reason: 'the package, not the tree');
    });

    /// What an `image` node draws. Written into the plugin's own directory, and
    /// the directory is what the surface is given — a package's pictures are
    /// not held in memory, because every installed plugin is read at launch and
    /// most of them are not on screen.
    test('the assets a package carries are installed beside it', () async {
      final plugin = await installer.install(
        sbp(extra: {'assets/logo.png': const [0x89, 0x50, 0x4e, 0x47]}),
        consented: {'server.exec'},
      );

      expect(plugin.dir, installer.dirOf(plugin.id).path);
      expect(
        File(plugin.dir!.joinPath('assets/logo.png')).existsSync(),
        isTrue,
      );
      expect(
        PluginAssets.pathOf(plugin.dir, 'logo.png'),
        endsWith('assets/logo.png'),
      );
    });

    /// The classic archive attack, in the one directory a plugin may name a
    /// file in. Refused rather than normalised: there is no `..` to reason
    /// about if a separator is not allowed at all.
    test('an asset name with a path in it reaches nothing', () async {
      for (final name in const ['../evil.png', 'a/b.png', '.hidden.png']) {
        expect(PluginAssets.isAllowed(name), isFalse, reason: name);
        expect(PluginAssets.pathOf('/tmp/p', name), isNull, reason: name);
      }
      // And a file this build would not draw is refused by the reader, so a
      // package cannot smuggle one in beside the pictures.
      expect(
        () => PluginPackage.read(sbp(extra: {'assets/run.sh': const [1, 2]})),
        throwsA(isA<PluginPackageError>()),
      );
    });

    /// A manifest is one document for every language, so a plugin names itself
    /// and its contributions with keys and the app resolves them where they are
    /// drawn. Left unresolved, they are what the interface says: a tab titled
    /// `l10n.pluginName`, a store dialog headed `l10n.pluginName 1.1.0`, in an
    /// app that is otherwise translated.
    test('a manifest that names itself with a key is read in a language',
        () async {
      final plugin = await installer.install(
        sbp(
          manifest: jsonEncode({
            'id': 'app.serverbox.zfs',
            'version': '1.0.0',
            'abi': 1,
            'name': 'l10n.pluginName',
            'description': 'l10n.pluginDescription',
            'permissions': const {'server.exec': true},
            'contributes': {
              'status': {
                'id': 'zfs',
                'label': 'l10n.pluginName',
                'platforms': ['linux'],
              },
              'card': {'id': 'c', 'label': 'l10n.cardLabel'},
              'page': {'id': 'p', 'label': 'l10n.pageLabel'},
              'tab': {'id': 't', 'label': 'l10n.tabLabel'},
              'settings': {'id': 's', 'label': 'l10n.settingsLabel'},
            },
          }),
          l10n: const {
            'en': {
              'pluginName': 'Pools',
              'pluginDescription': 'What ZFS has.',
              'cardLabel': 'Card',
              'pageLabel': 'Page',
              'tabLabel': 'Fleet',
              'settingsLabel': 'Prefs',
            },
          },
        ),
        consented: const {'server.exec'},
        repo: PluginInstall.fileRepo,
      );

      expect(plugin.name, 'Pools');
      expect(plugin.description, 'What ZFS has.');
      // Every surface the manifest can name, because each is drawn by a
      // different widget and each was a separate place to forget: the card and
      // the status reading on the server page, the button in the function bar,
      // the tab on the home page, the section in settings.
      expect(plugin.statusFeature?.label(), 'Pools');
      expect(plugin.cardFeature?.label(), 'Card');
      expect(plugin.pageFeature?.label(), 'Page');
      expect(plugin.tabFeature?.label(), 'Fleet');
      expect(PluginHomeTab(plugin).label, 'Fleet');
      PluginContributions.publish([plugin]);
      expect(
        PluginSettingsPage.nodes().single.title,
        'Prefs',
        reason: 'the settings menu leaf',
      );
      // And the manifest itself is untouched: the keys are what was installed,
      // and the language is decided every time one is drawn.
      expect(plugin.manifest.name, 'l10n.pluginName');
    });

    /// The record is the answer to "what is installed", including which files
    /// to read. A directory used to win for any id it named, whatever the
    /// record said — so a device already in that state (a directory listed from
    /// an older build, a record from the store) has to come out of it reading
    /// the copy the record describes.
    test('the record decides which files are read, not the directory list',
        () async {
      final dir = await Directory.systemTemp.createTemp('sbm_plugin_dev');
      addTearDown(() => dir.delete(recursive: true));
      await File(dir.path.joinPath(PluginPackage.manifestName))
          .writeAsString(_manifest(version: '9.9.9'));
      await File(dir.path.joinPath(PluginPackage.sourceName))
          .writeAsString('export function statusCmd() { return { cmd: "d" }; }');

      await installer.install(
        sbp(manifest: _manifest(version: '1.0.1')),
        consented: const {},
        repo: 'https://github.com/o/r',
      );
      // Listed behind the installer's back, which is the state an install
      // through the old code left.
      setting.pluginDevDirs.put([dir.path]);

      final plugin = (await installer.refresh()).single;
      expect(plugin.manifest.version, '1.0.1');
      expect(plugin.record.version, '1.0.1');
    });

    /// The version a development directory *is*, not the one it was when it
    /// was added: those files are edited in place, and a number frozen at
    /// registration is one nothing on disk agrees with.
    test('a development directory reports the version it currently has',
        () async {
      final dir = await Directory.systemTemp.createTemp('sbm_plugin_dev');
      addTearDown(() => dir.delete(recursive: true));
      final manifest = File(dir.path.joinPath(PluginPackage.manifestName));
      await manifest.writeAsString(_manifest(version: '1.0.0'));
      await File(dir.path.joinPath(PluginPackage.sourceName))
          .writeAsString('export function statusCmd() { return { cmd: "d" }; }');

      final added = await installer.addDevDir(dir.path, consented: const {});
      expect(added.record.version, '1.0.0');

      await manifest.writeAsString(_manifest(version: '1.1.0'));
      expect((await installer.refresh()).single.record.version, '1.1.0');
    });
  });
}

/// The column that keeps the replaced record, on an install that predates it.
///
/// A schema step is three edits — the class, `SchemaVersion.current` and
/// `kSchemaMigrations` — and none of them is visible in the step's own test,
/// which calls `apply()` directly. What is checkable here is the step itself:
/// a table without the column gets it, and one that already has it is left
/// alone. `ALTER TABLE ... ADD COLUMN` on an existing name is an error rather
/// than a no-op, and a migration is not repeatable.
void _migration() {
  group('the column an update is kept in', () {
    setUp(openTestDb);
    tearDown(closeTestDb);

    bool hasPrevious() => SqliteDb.instance
        .select('PRAGMA table_info(plugin_install);')
        .any((row) => row['name'] == 'previous');

    test('a table written before it gets it', () async {
      // What the table looked like at v25, from `m022`'s own DDL minus the
      // column being added.
      SqliteDb.instance.execute('DROP TABLE plugin_install;');
      SqliteDb.instance.execute('''
CREATE TABLE plugin_install (
  id TEXT NOT NULL PRIMARY KEY,
  version TEXT NOT NULL,
  repo TEXT,
  enabled INTEGER NOT NULL DEFAULT 1,
  granted TEXT NOT NULL,
  installed_at INTEGER NOT NULL
) WITHOUT ROWID;
''');
      expect(hasPrevious(), isFalse);

      await const PluginPreviousMigration().apply();

      expect(hasPrevious(), isTrue);
    });

    /// A fresh install gets the column from `createTables`, so this step runs
    /// over a table that already has it.
    test('and one that already has it is left alone', () async {
      expect(hasPrevious(), isTrue);

      await const PluginPreviousMigration().apply();

      expect(hasPrevious(), isTrue);
    });

    /// A record written before the column existed reads as "nothing to go
    /// back to", which is what it is.
    test('a row written without one has no previous version', () async {
      final store = PluginInstallStore();
      store.put(
        PluginInstall(
          id: 'app.serverbox.zfs',
          version: '1.0.0',
          granted: const {},
          installedAt: DateTime.now(),
        ),
      );

      expect(store.fetch('app.serverbox.zfs')?.previous, isNull);
    });
  });
}
