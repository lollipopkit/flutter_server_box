/// The theme catalog as this device keeps it between runs.
///
/// The cache is what lets the store page open with themes on it rather than a
/// spinner, and it is written by a build and read by the next one — so what has
/// to hold is that a store which comes back is the one that went in, and that
/// one which no longer stands on its own comes back as nothing instead of as a
/// row offering an install that cannot happen.
library;

import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:fl_lib/fl_lib.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:server_box/core/service/theme_package.dart';
import 'package:server_box/core/service/theme_repo.dart';
import 'package:server_box/data/model/app/builtin_theme.dart';
import 'package:server_box/data/res/store.dart';
import 'package:server_box/data/store/setting.dart';
import 'package:toml/toml.dart';

import '../helpers/test_db.dart';

const _digest = 'a3f1c07d5b2e8469a1c3f07d5b2e8469a1c3f07d5b2e8469a1c3f07d5b2e8469';

String _versionToml({
  String version = '1.0.0',
  int schemaMin = 1,
  int schemaMax = 1,
  String? url = 'https://example.org/aurora-1.0.0.fsbt',
  String? path,
}) {
  final buffer = StringBuffer(
    '[[version]]\nversion = "$version"\n'
    'schema_min = $schemaMin\nschema_max = $schemaMax\n',
  );
  if (url != null) buffer.writeln('url = "$url"');
  if (path != null) buffer.writeln('path = "$path"');
  buffer.writeln('sha256 = "$_digest"');
  return buffer.toString();
}

ThemeListing _listing({String versions = ''}) => ThemeListing.parse(
  'id = "aurora"\nname = "Aurora"\ndescription = "Green"\n$versions',
  'themes/aurora.toml',
);

/// A store as a fetch of one repository would have left it.
ThemeStore _store({
  ThemeStoreItem? item,
  List<String> repos = const ['lollipopkit/aurora'],
}) => ThemeStore(
  items: [?item],
  repos: repos,
  catalogUrl: 'https://example.org/repos.toml',
  fetchedAt: DateTime.utc(2026, 9, 24, 11, 30),
);

ThemeStoreItem _item({
  ThemeListing? listing,
  ThemeRelease? release,
  ThemeRepoIndex? index,
  String? repoUrl = 'https://example.org/aurora',
}) {
  final theme = listing ?? _listing(versions: _versionToml());
  return ThemeStoreItem(
    repo: 'lollipopkit/aurora',
    repoUrl: repoUrl,
    index: index,
    listing: theme,
    release: release ?? theme.releases.first,
  );
}

Map<String, Object?> _manifest() => {
  'format': 1,
  'schema': {'min': 1, 'max': 1},
  'id': 'example.amethyst',
  'name': 'Amethyst',
  'modes': ['light', 'dark'],
  'colors': {'mode': 0, 'seed': 4287106639, 'systemColor': false},
  'icons': {'style': 'classic', 'images': <String, String>{}},
  'background': {'type': 'gradient', 'opacity': 0.18, 'blur': 8},
  'shapes': {'card': 13, 'tile': 9, 'button': 30},
};

List<int> _bundle() {
  final archive = Archive()
    ..add(
      ArchiveFile.string(
        'manifest.toml',
        TomlDocument.fromMap(_manifest()).toString(),
      ),
    );
  return ZipEncoder().encodeBytes(archive);
}

void main() {
  late SettingStore setting;

  setUpAll(() async {
    // `late final`, so once per process: the theme packages a test installs are
    // read back from the app's own root.
    Paths.doc = (await Directory.systemTemp.createTemp('fsbt-cache-')).path;
  });

  tearDownAll(() => Directory(Paths.doc).delete(recursive: true));

  setUp(() async {
    await openTestDb();
    setting = SettingStore('setting_test');
    getIt.registerSingleton<SettingStore>(setting);
  });

  tearDown(() async {
    await getIt.reset();
    await closeTestDb();
  });

  group('a store that went into the cache', () {
    test('comes back with everything the page draws', () {
      final read = ThemeStore.fromJson(
        jsonDecode(jsonEncode(_store(item: _item()).toJson())),
      );

      expect(read, isNotNull);
      expect(read!.catalogUrl, 'https://example.org/repos.toml');
      expect(read.fetchedAt, DateTime.utc(2026, 9, 24, 11, 30));
      expect(read.repos, ['lollipopkit/aurora']);
      expect(read.neverFetched, isFalse);

      final item = read.items.single;
      expect(item.repo, 'lollipopkit/aurora');
      expect(item.repoUrl, 'https://example.org/aurora');
      expect(item.listing.id, 'aurora');
      expect(item.listing.name, 'Aurora');
      expect(item.listing.description, 'Green');
      expect(item.release?.version, '1.0.0');
      expect(item.release?.url, 'https://example.org/aurora-1.0.0.fsbt');
      expect(item.release?.sha256, _digest);
      // The files it was read from are not written down: a cached in-tree
      // version asks its repository for them again.
      expect(item.index, isNull);
    });

    test('names the version rather than copying the release', () {
      final raw = _item().toJson();

      // A release copied in could describe any version at all. The listing is
      // the one place a version is described; this only says which of them.
      expect(raw['release'], '1.0.0');
      expect((raw['listing'] as Map)['releases'], hasLength(1));
    });

    test('an in-tree version keeps the address that can fetch it again', () {
      final item = _item(
        listing: _listing(
          versions: _versionToml(url: null, path: 'packages/aurora.fsbt'),
        ),
        index: ThemeRepoIndex.fromFiles({
          'repo.toml': Uint8List.fromList(
            utf8.encode('schema = 1\nname = "A repository"\n'),
          ),
          'themes/aurora.toml': Uint8List.fromList(
            utf8.encode('id = "aurora"\nname = "Aurora"\n'),
          ),
        }),
      );

      final read = ThemeStoreItem.fromJson(jsonDecode(jsonEncode(item.toJson())));

      expect(read?.release?.path, 'packages/aurora.fsbt');
      expect(read?.repoUrl, 'https://example.org/aurora');
    });
  });

  group('a store that no longer stands on its own', () {
    test('a version the listing does not offer drops its item', () {
      final raw = _store(item: _item()).toJson();
      (raw['items'] as List).single['release'] = '9.9.9';

      expect(ThemeStoreItem.fromJson((raw['items'] as List).single), isNull);
    });

    test('and takes the whole store with it, rather than the rest of it', () {
      final raw = _store(item: _item()).toJson();
      (raw['items'] as List).single['release'] = '9.9.9';

      // Null rather than the remaining items: a page listing themes with some
      // of them missing is a page that cannot say what it is missing.
      expect(ThemeStore.fromJson(raw), isNull);
    });

    test('a release whose schema range is impossible is not read', () {
      // Written rather than parsed: a listing this app reads would have
      // dropped the version itself, and what this is about is a cache that
      // describes one no repository could have offered.
      final raw = _store(item: _item()).toJson();
      final listings = (raw['items'] as List).first['listing'] as Map;
      (listings['releases'] as List).first['schemaMin'] = 2;

      expect(ThemeStore.fromJson(raw), isNull);
    });

    test('a store with no timestamp is not a cache', () {
      final raw = _store(item: _item()).toJson()..remove('fetchedAt');

      expect(ThemeStore.fromJson(raw), isNull);
    });

    test('a store with no catalog address is not a cache', () {
      final raw = _store(item: _item()).toJson()..['catalogUrl'] = '';

      expect(ThemeStore.fromJson(raw), isNull);
    });
  });

  group('the age of what is on screen', () {
    const max = Duration(minutes: 5);
    final read = DateTime.utc(2026, 9, 24, 12);

    /// The store `_store` builds, read at [at].
    ThemeStore storeAt(DateTime at) => ThemeStore(
      items: [_item()],
      repos: const ['lollipopkit/aurora'],
      catalogUrl: 'https://example.org/repos.toml',
      fetchedAt: at,
    );

    test('is what tells the page whether to read the catalog again', () {
      expect(storeAt(read).staleAsOf(read.add(const Duration(minutes: 4)), max), isFalse);
      expect(storeAt(read).staleAsOf(read.add(max), max), isTrue);
      expect(storeAt(read).staleAsOf(read.add(const Duration(hours: 3)), max), isTrue);
    });

    test('is nothing when there is nothing to be old', () {
      // A store that was never read is always read now, whatever the clock
      // says: an empty page is waiting for an answer rather than showing one.
      expect(
        const ThemeStore().staleAsOf(read, max),
        isTrue,
      );
    });

    test('survives the cache, so a second launch does not read again', () {
      final readBack = ThemeStore.fromJson(
        jsonDecode(jsonEncode(storeAt(read).toJson())),
      )!;

      expect(readBack.fetchedAt, read);
      expect(readBack.staleAsOf(read.add(const Duration(minutes: 1)), max), isFalse);
    });
  });

  group('this device', () {
    test('keeps the catalog as one object, not as a string holding one', () async {
      await setting.themeStoreCache.set(_store(item: _item()).toJson());

      final rows = SqliteDb.instance.select(
        'SELECT value FROM kv WHERE store = ? AND key = ?;',
        ['setting_test', 'themeStoreCache'],
      );
      final column = rows.first['value'] as String;
      expect(
        jsonDecode(column),
        isA<Map<String, dynamic>>(),
        reason: 'a second encode would make this a String',
      );

      // What the page does on open.
      final read = ThemeStore.fromJson(setting.themeStoreCache.fetch());
      expect(read?.items.single.listing.id, 'aurora');
    });

    test('has nothing to show before the first fetch', () {
      // The default is the empty map, which is not a store: the page opens on
      // a spinner rather than on a catalog of no themes.
      expect(setting.themeStoreCache.fetch(), isEmpty);
      expect(ThemeStore.fromJson(setting.themeStoreCache.fetch()), isNull);
    });

    test('does not carry the catalog in a backup', () {
      // Which catalog a device reads is something it was pointed at; restoring
      // it elsewhere would spend the other device's requests on it.
      expect(SettingStore.deviceLocalKeys, contains('themeStoreCache'));
    });
  });

  group('removing an installed theme', () {
    // Installed and removed through the app's own root rather than an override
    // one: what makes a remove button worth having is that the theme in use is
    // reconciled, and `reconcileSelection` looks in the app's root.
    setUp(() async {
      final themes = Directory(Paths.doc.joinPath('themes'));
      if (await themes.exists()) await themes.delete(recursive: true);
    });

    test('takes its files off this device and says it was there', () async {
      final installed = await ThemePackages.install(_bundle());
      // Nothing is in use, so the selection is left exactly as it was.
      final preset = setting.appThemePreset.fetch();

      expect(await ThemePackages.remove(installed.installationId), isTrue);
      expect(ThemePackages.listInstalled(), isEmpty);
      expect(ThemePackages.installed(installed.installationId), isNull);
      expect(setting.appThemePreset.fetch(), preset);

      expect(
        await ThemePackages.remove(installed.installationId),
        isFalse,
        reason: 'the second remove has nothing left to delete',
      );
    });

    test('refuses anything that is not an installation id', () async {
      expect(await ThemePackages.remove('../../settings'), isFalse);
      expect(await ThemePackages.remove(''), isFalse);
    });

    test('of the theme in use returns the app to the default theme', () async {
      final installed = await ThemePackages.install(_bundle());
      setting.appThemePreset.put('package:${installed.installationId}');
      setting.appThemePackage.put(installed.installationId);

      await ThemePackages.remove(installed.installationId);

      // What the app is left drawing is a theme that exists: a preset naming
      // one whose files are gone is not a state anything else in the app draws.
      expect(setting.appThemePreset.fetch(), BuiltinTheme.defaultTheme.id);
      expect(setting.appThemePackage.fetch(), isEmpty);
    });
  });
}
