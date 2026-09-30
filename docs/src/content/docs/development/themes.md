---
title: Themes
description: How the built-in themes are packaged, loaded and distributed
---

This page explains how built-in themes are implemented and distributed in this
repository. For the package format and publishing instructions, see
[Theme Package Authoring](/docs/development/theme-authoring/). For the
user-facing guide to choosing and installing themes, see
[Themes](/docs/advanced/theme-packages/). Upstream palette sources and their
attributions are listed in the authoring guide.

## Built-in themes

`BuiltinTheme` (`packages/fl_lib/lib/src/theme/builtin.dart`) lists the packages
bundled with this build: only what the app needs without a network. `Default`
is a Dart constant and does not read an asset; its picker label is localized
(fl_lib `defaultLabel`). AMOLED, which legacy AMOLED theme modes migrate
to, has a source folder under `packages/fl_lib/assets/themes/amoled/` containing a
`manifest.toml`, registered in fl_lib's `pubspec.yaml`. Every other official theme is in
the theme store (see [Official themes](#official-themes)); a saved preset that
names a bundled theme this build no longer carries falls back to Default
(`ThemePackages.reconcileSelection`).

Bundled folders use the same installer as imported folders and `.fsbt`
archives, so built-in themes support the same fields as installed themes. The
folders are committed as source and bundled directly by Flutter; no archive or
other binary asset is committed for them.

A new official theme goes to the store, not here. Bundle one only if the app
must have it offline, by creating its folder, registering it in fl_lib's `pubspec.yaml`,
and adding a `BuiltinTheme` case.

## Loading

`BuiltinThemeLoader` (`packages/fl_lib/lib/src/theme/package.dart`) loads themes on
demand. `_loaded` stores completed results and `_pending` tracks active loads,
so simultaneous requests for the same theme share one parse. Failed loads are
not cached and can be retried.

Opening the picker does not load theme files. A folder is read when selected or
at startup if it was the saved selection. Built-in assets use a separate
runtime cache and do not appear in the user-installed theme list.

## The parser and the editor schema

Three files in `packages/fl_lib/lib/src/theme/` define the manifest grammar:
`package.dart` (top-level tables, archive entries, the schema range),
`components.dart` (component fields, states, and every numeric range) and
`palette.dart` (the non-deprecated ColorScheme roles).
`docs/schemas/fsbt-manifest.schema.json` mirrors these definitions so editors
can report errors while a file is being edited. The schema is derived from the
parser definitions, not from this documentation.

The schema is as strict as the installer except for one rule it cannot express:
the installer rejects an `icons.colors` key without a matching `icons.images`
entry. This check spans two tables and cannot be represented in JSON Schema.

The CI `docs` job validates every checked-in manifest, including the bundled
folders and `docs/examples/aurora/`, against the schema.
`test/unit/theme_schema_test.dart` checks the schema against the parser, so the
fields, enums, and bounds offered by editors match what the installer accepts.

## Theme store

`ThemeRepo` (`packages/fl_lib/lib/src/theme/repo.dart`) reads a catalog of repositories
and then each repository's tree. `assets/catalog/repos.toml` provides the
initial catalog when no network is available. When `Urls.themeCatalog`
responds, the app reads that catalog instead.

Repository URLs must use HTTPS and resolve to a tarball. Git repositories are
fetched from `<address>/archive/HEAD.tar.gz`, which follows the repository's
default branch without assuming its name. `ThemePackages.download` rejects URLs
containing credentials and follows at most three redirects, checking that each
target still uses HTTPS. Plain HTTP is rejected because the repository
determines which bytes are installed.

`ThemeRepo` enforces these limits: at most 100 repositories and 1 MiB per
catalog; 16 MiB compressed and 64 MiB unpacked per repository tree; and 8 MiB
per entry. Unknown sections are skipped, allowing one tree to contain both
`themes/` and `plugins/` for the app and plugin feature.

The store page is in `packages/fl_lib/lib/src/theme/view/store/`. Its listing is persisted
between runs in `SettingStore.themeStoreCache` using `ThemeStore.toJson()` with
`updateLastModified: false`. The key is included in
`SettingStore.deviceLocalKeys` because this cache records catalog contents; it
is not user data to sync or restore on another device. Cached items do not
include repository files (`ThemeStoreItem.index` is null), so installing a
version stored in a repository fetches its tarball again. The digest is checked
in either case.

A listing's `description` is a string or a table of language tags
(`ThemeText`); the page resolves it with the app's locale, and the cache keeps
the table. A row's preview (`packages/fl_lib/lib/src/theme/view/store/preview.dart`)
is built only while the row is expanded. It renders real widgets under the
`ThemeData` that `buildAppTheme` (`packages/fl_lib/lib/src/theme/view/app_theme.dart`)
makes from the package, the same function the app uses for itself with
`AppThemeSource.current()`. An uninstalled theme is installed for the preview
under `<app name>_theme_preview` in the system's temporary directory, apart
from the user's themes, and that directory is deleted when the page is
disposed.

A package with `[variants]` installs once; each variant is written as a
complete, normalized theme directory under `variants/<key>/` of the
installation, so `ThemePackages.installed(id, variant: key)` reads it with the
same code as a package without variants. The preset carries the variant as
`package:<installation id>#<key>`; `appThemePackage` keeps the installation id
alone.

## Bundled store themes

A store theme can ship with the app: `assets/store_themes/<id>.fsbt`, the
exact package `scripts/publish-themes.py` builds from `store/themes/<id>/`
(the packing is deterministic, so it is the same digest the listing records).
`ThemePackages.seedBundled` installs each one once at launch into the ordinary
themes directory, unless the device already has that manifest id, and records
it in `SettingStore.bundledThemesSeeded` (device-local) so a removed theme stays
removed. From then on it is an installed theme like any other, and the store
offers an update when its release digest differs from the installation id.

`test/unit/theme_bundled_test.dart` fails when a bundled package no longer
matches its store folder byte for byte: after editing such a theme, repack it
with the serverbox-theme skill's `scripts/pack.py -o
assets/store_themes/<id>.fsbt`.

Installing a manifest id that is already installed replaces the earlier
installation (`_replaceOlder`), handing over the selection when it was in use.

## Official themes

Official themes live in `store/` in this repository: `store/repo.toml`, and
for each theme a listing `store/themes/<id>.toml` beside its source folder
`store/themes/<id>/`. `test/unit/theme_store_tree_test.dart` reads the folder
the way the store does, so a listing the reader would drop fails a test rather
than disappearing from the store.

The app does not download this repository. The website build runs
`scripts/store-tarball.sh`, which writes `store/` at `HEAD` with `git archive`
to `public/store.tar.gz`, and the catalog lists
`https://serverbox.lollipopkit.com/store.tar.gz`. A change to `store/` reaches
the store when the website is deployed: the Cloudflare Pages project builds on
changes under `store/` as well as `website/` and `docs/`. The same build lists
the themes on the site (`website/store-data.js`). `git archive` is used rather than `tar`
because macOS `tar` writes binary xattr records the reader refuses.

`scripts/publish-themes.py` publishes every theme that changed since its newest
recorded version, in one run. It runs the serverbox-theme skill's
`scripts/publish.py` with `store/` as the theme repository — the same publisher
a third-party author runs in their own repository, where their themes are
released; only official themes are released from this repository. It packs each folder and compares the package's
digest with the newest version in the listing: the same digest means nothing
changed, and the theme is skipped. A changed theme gets the next patch version
(`--bump minor|major` for another part, `<id>=<version>` for an exact one, 1.0.0
for a theme with no version yet). `--dry-run` shows the plan; naming ids limits
the run to those themes.

Comparing digests works because the package is deterministic: entries sorted,
one fixed timestamp and permission, and stored rather than deflated, so the
bytes depend on the files alone and not on a checkout's modification times or a
machine's zlib.

All new packages are uploaded together, as `<id>-<version>.fsbt`, to one
release of this repository tagged `themes`; then each listing gets a
`[[version]]` block with the digest and size, and the listings are committed
afterwards. One release holds every package: the app's update check reads this
repository's releases, a tag without a build number is skipped there, and a
release per theme version would push the app's releases off the first page. The
release is a pre-release, created with `--latest=false`, and is never this
repository's Latest: GitHub does not mark a pre-release Latest, so Latest is
always an app release, and the script checks that before it uploads anything.

The script keeps two ordering and integrity rules. It uploads packages before
updating the listings, so a listing never points to a missing asset. It never
replaces an uploaded asset — one left by an interrupted run is accepted only if
its bytes are the same — and never records a version number for a second set of
bytes.
