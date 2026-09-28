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

`BuiltinTheme` (`lib/data/model/app/builtin_theme.dart`) lists the packages
bundled with this build and their labels in the picker. `Default` is a Dart
constant and does not read an asset. The other five themes each have a source
folder under `assets/themes/<id>/` containing a `manifest.toml`; each folder is
registered in `pubspec.yaml`.

Bundled folders use the same installer as imported folders and `.fsbt`
archives, so built-in themes support the same fields as installed themes. The
folders are committed as source and bundled directly by Flutter; no archive or
other binary asset is committed for them.

To add a theme, create its folder, register it in `pubspec.yaml`, and add a
`BuiltinTheme` case with its picker label.

## Loading

`BuiltinThemeLoader` (`lib/core/service/theme_package.dart`) loads themes on
demand. `_loaded` stores completed results and `_pending` tracks active loads,
so simultaneous requests for the same theme share one parse. Failed loads are
not cached and can be retried.

Opening the picker does not load theme files. A folder is read when selected or
at startup if it was the saved selection. Built-in assets use a separate
runtime cache and do not appear in the user-installed theme list.

## The parser and the editor schema

Three files define the manifest grammar:
`theme_package.dart` (top-level tables, archive entries, the schema range),
`theme_components.dart` (component fields, states, and every numeric range) and
`theme_palette.dart` (the non-deprecated ColorScheme roles).
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

`ThemeRepo` (`lib/core/service/theme_repo.dart`) reads a catalog of repositories
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

The store page is in `lib/view/page/theme_store/`. Its listing is persisted
between runs in `SettingStore.themeStoreCache` using `ThemeStore.toJson()` with
`updateLastModified: false`. The key is included in
`SettingStore.deviceLocalKeys` because this cache records catalog contents; it
is not user data to sync or restore on another device. Cached items do not
include repository files (`ThemeStoreItem.index` is null), so installing a
version stored in a repository fetches its tarball again. The digest is checked
in either case.

## Official themes

`lollipopkit/serverbox-plugins` stores official themes in `themes/`, with one
source folder and one listing per theme. The `plugins/` directory sits beside
it.

`scripts/publish-themes.sh <id> <version>` publishes one version. It reads the
id and `[schema]` range from the manifest, then packages the folder with `zip`.
The `-X` option excludes machine-specific file attributes. The script computes
the digest and size, creates a release tagged `<id>-<version>` with
`<tag>.fsbt` as its asset, and appends a `[[version]]` block to the listing.

The script enforces two ordering and integrity rules. It uploads the release
before updating the listing, so the listing never points to a missing asset. It
also refuses to republish a recorded version with a different digest; each
version must continue to identify the same bytes.
