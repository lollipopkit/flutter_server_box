import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:server_box/core/service/theme_package.dart';
import 'package:server_box/core/service/theme_repo.dart';

/// End-to-end against a catalog that is actually served.
///
/// Everything else about the store runs on bytes a test wrote, which is the gap
/// publishing goes wrong in: the digest in a file and the package in a release
/// are written one after the other, by different steps, and nothing local can
/// tell that they disagree. This fetches the catalog, every repository it
/// lists, and checks each version against what its file claims — then installs
/// the one an app of this build would pick.
///
/// ```sh
/// SBM_E2E_THEME_CATALOG=https://raw.githubusercontent.com/lollipopkit/flutter_server_box/feat/theme-packages/assets/catalog/repos.toml \
/// flutter test test/unit/theme_repo_live_test.dart
/// ```
///
/// The ref is the branch the catalog is on: `main` does not serve it yet, and an
/// address that answers 404 is what the check below is meant to catch rather
/// than to be run against. TODO: point this at `main` once the catalog is
/// merged.
///
/// Silently skipped when unset, since it needs the network.
void main() {
  final catalogUrl = Platform.environment['SBM_E2E_THEME_CATALOG'];

  if (catalogUrl == null || catalogUrl.isEmpty) {
    test(
      'theme store e2e (skipped: SBM_E2E_THEME_CATALOG unset)',
      () {},
      skip: true,
    );
    return;
  }

  test('every version the catalog serves is the one its file claims', () async {
    // Two things the binding does by default, and neither is what this wants.
    // It is needed because a catalog that cannot be fetched is answered with
    // the one bundled in the app, which is an asset — without it, an address
    // that answered nothing failed here on the fallback rather than on the
    // reason it took it. It also answers every request with a 400, and the
    // network is the whole point, so the override it installs goes.
    TestWidgetsFlutterBinding.ensureInitialized();
    HttpOverrides.global = null;

    // Read here what `store` would only read if it could: an address that
    // answered nothing is answered with the catalog compiled into the app — the
    // same repositories, behind it — so a store that came back from the
    // fallback would report the one that failed as the source of everything
    // below, and a non-empty list of repositories cannot tell the two apart.
    final catalog = ThemeRepoCatalog.parse(
      await ThemePackages.download(
        catalogUrl,
        maxBytes: ThemeRepos.maxCatalogBytes,
      ),
      base: ThemePackages.httpsUri(catalogUrl),
    );

    final store = await ThemeRepos.store(catalogUrl);
    // One entry per repository that answered, whatever it held, so the count is
    // what says the store read this catalog and every repository in it.
    expect(
      store.repos.length,
      catalog.repos.length,
      reason:
          'the store read ${store.repos.length} of the '
          '${catalog.repos.length} repositories $catalogUrl lists',
    );

    final root = await Directory.systemTemp.createTemp('fsbt-live-');
    addTearDown(() => root.delete(recursive: true));

    var versions = 0;
    var installable = 0;
    for (final item in store.items) {
      for (final release in item.listing.releases) {
        versions++;
        final address = release.url;
        // A cache rebuilt from disk carries no repository files, but this store
        // is one just read, so every item still has its index.
        final bytes = address != null
            ? await ThemePackages.download(address)
            : item.index?.packages[release.path];
        expect(
          bytes,
          isNotNull,
          reason:
              '${item.listing.id} ${release.version} names '
              '${release.path ?? address} and it was not served',
        );
        expect(
          sha256.convert(bytes!).toString(),
          release.sha256,
          reason: '${item.listing.id} ${release.version} is not the bytes listed',
        );
        if (release.size case final size?) {
          expect(
            bytes.length,
            size,
            reason:
                '${item.listing.id} ${release.version} is not the size listed',
          );
        }
      }

      if (item.release == null) continue;
      installable++;
      final installed = await ThemeRepos.install(item, rootDirectory: root.path);
      expect(installed.id, item.listing.id);
    }

    expect(versions, greaterThan(0), reason: 'the store offered no version');
    expect(installable, greaterThan(0), reason: 'nothing was installable');
  }, timeout: const Timeout(Duration(minutes: 5)));
}
