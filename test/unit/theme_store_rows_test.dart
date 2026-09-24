/// The theme store's list, as one list.
///
/// The page used to draw what the catalog offers and what this device has as
/// two lists, so a theme installed from the store appeared in both and read as
/// two themes. [buildThemeRows] is the merge that fixes it, and this is what
/// holds it: one row per theme, the catalog's record and this device's record
/// on that row, filtered by a query and ordered by a sort.
///
/// Kept out of the page for the reason it exists as a function at all — the
/// decision worth testing is the merge, and reaching it through the page would
/// need a filesystem of installed themes and a repository to fetch from.
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:server_box/core/service/theme_package.dart';
import 'package:server_box/core/service/theme_repo.dart';
import 'package:server_box/data/model/app/theme_sort.dart';
import 'package:server_box/data/model/app/theme_style.dart';
import 'package:server_box/view/page/theme_store/rows.dart';

const _digest = 'a3f1c07d5b2e8469a1c3f07d5b2e8469a1c3f07d5b2e8469a1c3f07d5b2e8469';

ThemeListing _listing({
  String id = 'aurora',
  String name = 'Aurora',
  String description = 'A green theme',
  String version = '1.0.0',
}) => ThemeListing.parse(
  'id = "$id"\nname = "$name"\ndescription = "$description"\n'
  '[[version]]\nversion = "$version"\nschema_min = 1\nschema_max = 1\n'
  'url = "https://example.org/$id-$version.fsbt"\nsha256 = "$_digest"\n',
  'themes/$id.toml',
);

ThemeStoreItem _item({
  String id = 'aurora',
  String name = 'Aurora',
  String? description,
  String repo = 'lollipopkit/themes',
  int? size,
}) {
  final listing = _listing(
    id: id,
    name: name,
    description: description ?? 'A green theme',
  );
  return ThemeStoreItem(
    repo: repo,
    repoUrl: 'https://example.org/$repo',
    listing: listing,
    release: ThemeRelease(
      version: '1.0.0',
      schemaMin: 1,
      schemaMax: 1,
      url: 'https://example.org/$id-1.0.0.fsbt',
      path: null,
      sha256: _digest,
      size: size,
      notes: null,
    ),
  );
}

/// A theme this device has, which carries far more than the row reads.
ThemePackage _package({
  String id = 'aurora',
  String name = 'Aurora',
  String installationId = 'b1e6d0f4a3c2',
}) => ThemePackage(
  installationId: installationId,
  id: id,
  name: name,
  schemaMin: 1,
  schemaMax: 1,
  mode: 0,
  modes: const {ThemeMode.light, ThemeMode.dark},
  seed: 0xFF880E4F,
  systemColor: false,
  paletteLight: const {},
  paletteDark: const {},
  iconStyle: IconStyle.classic,
  iconFiles: const {},
  backgroundStyle: BackgroundStyle.none,
  opacity: 0.18,
  blur: 0,
  cardRadius: 13,
  tileRadius: 9,
  buttonRadius: 30,
  directory: '',
);

List<ThemeRow> _rows({
  List<ThemePackage> installed = const [],
  List<ThemeStoreItem> items = const [],
  String active = '',
  String query = '',
  ThemeSort sort = ThemeSort.inUse,
}) => buildThemeRows(
  installed: installed,
  items: items,
  activeInstallationId: active,
  query: query,
  sort: sort,
);

void main() {
  group('the catalog and this device are one list', () {
    test('a theme the store has and this device has is one row', () {
      final rows = _rows(
        installed: [_package(installationId: 'aaa')],
        items: [_item()],
      );

      expect(rows, hasLength(1));
      expect(rows.single.id, 'aurora');
      // Both records, which is what lets the row name the version and the
      // repository as well as offer to switch to what is already here.
      expect(rows.single.installed, isNotNull);
      expect(rows.single.item, isNotNull);
      expect(rows.single.onDevice, isTrue);
    });

    test('the catalog names the row, since it is the newer record', () {
      final rows = _rows(
        installed: [_package(name: 'Aurora (local)')],
        items: [_item(name: 'Aurora')],
      );

      expect(rows.single.name, 'Aurora');
    });

    test('the manifest name is the only one a local-only theme has', () {
      final rows = _rows(installed: [_package(name: 'Amethyst')]);

      expect(rows, hasLength(1));
      expect(rows.single.name, 'Amethyst');
      expect(rows.single.item, isNull);
      expect(rows.single.id, 'aurora');
      expect(rows.single.key, 'b1e6d0f4a3c2');
    });

    test('a row is keyed by what an action on it takes', () {
      final catalogOnly = _rows(items: [_item(id: 'aurora')]).single;
      final installed = _rows(
        installed: [_package(installationId: 'aaa')],
      ).single;

      // The install lands under the manifest id, and a removal takes the
      // installation id.
      expect(catalogOnly.key, 'aurora');
      expect(installed.key, 'aaa');
    });

    test('what this device has comes before what only the catalog offers', () {
      final rows = _rows(
        installed: [_package(id: 'beta', name: 'Beta')],
        items: [
          _item(id: 'aurora', name: 'Aurora'),
          _item(id: 'cobalt', name: 'Cobalt'),
        ],
      );

      expect(rows.map((r) => r.name), ['Beta', 'Aurora', 'Cobalt']);
    });
  });

  group('what is in use', () {
    test('is the row whose installation is the one the app is drawing', () {
      final rows = _rows(
        installed: [
          _package(id: 'aurora', name: 'Aurora', installationId: 'aaa'),
          _package(id: 'cobalt', name: 'Cobalt', installationId: 'bbb'),
        ],
        active: 'bbb',
      );

      expect(rows.where((r) => r.inUse).map((r) => r.name), ['Cobalt']);
    });

    test('is nothing while the app is on a built-in preset', () {
      final rows = _rows(
        installed: [_package(installationId: 'aaa')],
        items: [_item()],
      );

      expect(rows.where((r) => r.inUse), isEmpty);
    });

    test('a catalog-only row of the same manifest id is the one in use', () {
      // The catalog and the device name the same theme by the same id, so the
      // row carries both and is in use even though the store has its own record.
      final row = _rows(
        installed: [_package(installationId: 'aaa')],
        items: [_item()],
        active: 'aaa',
      ).single;

      expect(row.inUse, isTrue);
    });
  });

  group('a query', () {
    final installed = [_package(id: 'amethyst', name: 'Amethyst')];
    final items = [
      _item(id: 'aurora', name: 'Aurora', description: 'A green theme'),
      _item(id: 'cobalt', name: 'Cobalt', description: 'A blue theme',
          repo: 'someone/cobalt'),
    ];

    List<String> found(String query) =>
        _rows(installed: installed, items: items, query: query)
            .map((r) => r.name)
            .toList();

    test('matches a name, whatever the case', () {
      expect(found('aurora'), ['Aurora']);
      expect(found('AURORA'), ['Aurora']);
      expect(found('  aur  '), ['Aurora']);
    });

    test('matches the manifest id and the repository', () {
      expect(found('amethyst'), ['Amethyst']);
      expect(found('someone/cobalt'), ['Cobalt']);
    });

    test('matches a description the row shows', () {
      expect(found('green'), ['Aurora']);
    });

    test('matches several, in the order the sort gives', () {
      expect(found('o'), ['Aurora', 'Cobalt']);
    });

    test('matching nothing leaves nothing', () {
      expect(found('nutmeg'), isEmpty);
    });

    test('a blank query is not a filter', () {
      expect(found('   '), hasLength(3));
    });
  });

  group('the order', () {
    final installed = [
      _package(id: 'cobalt', name: 'cobalt', installationId: 'aaa'),
      _package(id: 'beta', name: 'Beta', installationId: 'bbb'),
    ];
    final items = [
      _item(id: 'zinc', name: 'Zinc'),
      _item(id: 'beta', name: 'Beta'),
      _item(id: 'amide', name: 'Amide'),
    ];

    List<String> ordered(ThemeSort sort) =>
        _rows(installed: installed, items: items, active: 'aaa', sort: sort)
            .map((r) => r.name)
            .toList();

    test('the default puts what is in use first, then what is here, then the rest', () {
      expect(ordered(ThemeSort.inUse), ['cobalt', 'Beta', 'Amide', 'Zinc']);
    });

    test('a name sort ignores both', () {
      expect(ordered(ThemeSort.nameAsc), ['Amide', 'Beta', 'cobalt', 'Zinc']);
      expect(ordered(ThemeSort.nameDesc), ['Zinc', 'cobalt', 'Beta', 'Amide']);
    });

    test('names are compared folded, not by their letters', () {
      // `Aurora` and `amide` are one row each here, and a raw compare puts the
      // uppercase `A` first while a folded one does not.
      final rows = _rows(
        installed: [_package(id: 'amide', name: 'amide')],
        items: [_item(id: 'aurora', name: 'Aurora')],
        sort: ThemeSort.nameAsc,
      );

      expect(rows.map((r) => r.name), ['amide', 'Aurora']);
    });

    test('two themes of one name keep one order between rebuilds', () {
      // `List.sort` is not stable, so a tie left to it would swap places every
      // time the page rebuilt. The tie is broken by the key instead.
      final a = _package(id: 'zinc', name: 'Same', installationId: 'zzz');
      final b = _package(id: 'amide', name: 'Same', installationId: 'aaa');

      final first = _rows(installed: [a, b], sort: ThemeSort.nameAsc);
      final second = _rows(installed: [b, a], sort: ThemeSort.nameAsc);

      expect(first.map((r) => r.key), ['aaa', 'zzz']);
      expect(second.map((r) => r.key), ['aaa', 'zzz']);
    });
  });

  group('the stored sort', () {
    test('is read back by name', () {
      expect(ThemeSort.fromStored('nameAsc'), ThemeSort.nameAsc);
      expect(ThemeSort.fromStored('nameDesc'), ThemeSort.nameDesc);
      expect(ThemeSort.fromStored('inUse'), ThemeSort.inUse);
    });

    test('an index is not a name, and falls back to the default', () {
      // Every stored enum is written by name: an index silently gains a meaning
      // when a case is inserted, and this value outlives the build that wrote
      // it.
      expect(ThemeSort.fromStored(0), ThemeSort.inUse);
      expect(ThemeSort.fromStored(2), ThemeSort.inUse);
    });

    test('nothing stored, and a name no build has, fall back to the default', () {
      expect(ThemeSort.fromStored(null), ThemeSort.inUse);
      expect(ThemeSort.fromStored('name'), ThemeSort.inUse);
      expect(ThemeSort.fromStored(''), ThemeSort.inUse);
    });
  });
}
