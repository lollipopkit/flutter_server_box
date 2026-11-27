import 'dart:convert';
import 'dart:io';

import 'package:fl_lib/theme.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:server_box/core/service/theme_host.dart';
import 'package:server_box/data/store/setting.dart';
import 'package:toml/toml.dart';

/// The theme code is fl_lib's and tested there; these are about what this
/// repository carries for it — the documented example, the catalog it ships
/// and the backup rules of its settings store.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('ships an editable example theme folder', () async {
    final root = await Directory.systemTemp.createTemp('fsbt-example-test-');
    try {
      final installed = await ThemePackages.installFolder(
        'docs/examples/aurora',
        rootDirectory: root.path,
      );
      expect(installed.name, 'Aurora');
      expect(installed.paletteLight['primary'], isNotNull);
    } finally {
      await root.delete(recursive: true);
    }
  });

  test('Aurora documents every palette role and component field', () {
    final manifest = TomlDocument.parse(
      File('docs/examples/aurora/manifest.toml').readAsStringSync(),
    ).toMap();
    final palette = (manifest['colors'] as Map)['palette'] as Map;
    for (final mode in ['light', 'dark']) {
      expect((palette[mode] as Map).keys, unorderedEquals(ThemePalette.roles));
    }
    final components = manifest['components'] as Map;
    for (final entry in ThemeComponents.fields.entries) {
      final keys = (components[entry.key] as Map).keys.cast<String>().where(
        (key) => !ThemeComponents.states.contains(key),
      );
      expect(keys, unorderedEquals(entry.value), reason: entry.key);
    }
  });

  test('the catalog this repository ships is one this build reads', () {
    final file = File(themeCatalogAsset);
    final bytes = file.readAsBytesSync();
    final catalog = ThemeRepoCatalog.parse(bytes);
    expect(
      catalog.repos,
      isNotEmpty,
      reason: 'the bundled catalog offers no repository',
    );
    final raw = TomlDocument.parse(utf8.decode(bytes)).toMap();
    final rawRepos = raw['repo'] as List;
    expect(
      catalog.repos.length,
      rawRepos.length,
      reason: 'duplicate repository entries in $themeCatalogAsset',
    );
    // `store/`, served by the website build (scripts/store-tarball.sh), stays
    // first so the official repository takes precedence over third-party ones.
    final official = catalog.repos.first.url.toString();
    expect(
      official,
      'https://serverbox.lollipopkit.com/store.tar.gz',
      reason: 'the official repository must stay first',
    );
    expect(
      ThemeRepos.archiveUrlOf(official),
      official,
      reason: 'an address naming a tarball is fetched as it is',
    );
    final archives = <String>{};
    for (final repo in catalog.repos) {
      final archive = ThemeRepos.archiveUrlOf(repo.url.toString());
      final parsed = Uri.tryParse(archive);
      expect(
        parsed,
        isNotNull,
        reason: '${repo.url} must resolve to a valid archive URL',
      );
      expect(
        parsed!.scheme,
        'https',
        reason: '${repo.url} must resolve to an HTTPS archive URL',
      );
      expect(
        parsed.host,
        isNotEmpty,
        reason: '${repo.url} archive URL must have a host',
      );
      expect(
        parsed.userInfo,
        isEmpty,
        reason: '${repo.url} archive URL must not carry credentials',
      );
      expect(
        parsed.hasQuery,
        isFalse,
        reason: '${repo.url} must not carry a query string',
      );
      expect(
        parsed.hasFragment,
        isFalse,
        reason: '${repo.url} must not carry a fragment',
      );
      final path = parsed.path.toLowerCase();
      expect(
        path.endsWith('.tar.gz') || path.endsWith('.tgz'),
        isTrue,
        reason: '${repo.url} must resolve to a .tar.gz or .tgz archive: $archive',
      );
      expect(
        archives.add(archive),
        isTrue,
        reason: 'duplicate archive target in $themeCatalogAsset: ${repo.url} -> $archive',
      );
    }
  });

  test('the reference theme can be listed under the id it declares', () {
    // The two ids are one spelling, so a theme the app ships as an example is
    // one a repository can offer. A layout narrower than the manifest's own
    // would leave the reference theme unpublishable.
    final manifest = TomlDocument.parse(
      File('docs/examples/aurora/manifest.toml').readAsStringSync(),
    ).toMap();
    final id = manifest['id'] as String;
    expect(ThemePackages.idPattern.hasMatch(id), isTrue);
    expect(ThemeRepoLayout.pathOf(id), 'themes/$id.toml');
    expect(
      ThemeRepoLayout.listedAt('themes/$id.toml'),
      (ThemeListingKind.theme, id),
    );
  });

  test('does not carry the catalog in a backup', () {
    // Which catalog a device reads is something it was pointed at; restoring
    // it elsewhere would spend the other device's requests on it.
    expect(SettingStore.deviceLocalKeys, contains('themeStoreCache'));
  });
}
