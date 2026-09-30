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
    final catalog = ThemeRepoCatalog.parse(file.readAsBytesSync());
    expect(
      catalog.repos,
      isNotEmpty,
      reason: 'the bundled catalog offers no repository',
    );
    // `store/`, served by the website build (scripts/store-tarball.sh).
    expect(
      catalog.repos.single.url.toString(),
      'https://serverbox.lollipopkit.com/store.tar.gz',
      reason: 'the official repository moved',
    );
    expect(
      ThemeRepos.archiveUrlOf(catalog.repos.single.url.toString()),
      catalog.repos.single.url.toString(),
      reason: 'an address naming a tarball is fetched as it is',
    );
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
    expect(ThemeRepoLayout.idOf('themes/$id.toml'), id);
  });

  test('does not carry the catalog in a backup', () {
    // Which catalog a device reads is something it was pointed at; restoring
    // it elsewhere would spend the other device's requests on it.
    expect(SettingStore.deviceLocalKeys, contains('themeStoreCache'));
  });
}
