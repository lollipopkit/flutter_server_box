---
title: Themes
description: How the built-in themes are packaged, loaded and distributed
---

This page covers how themes are implemented and distributed in this repository.
Authoring a theme, installing one, and publishing a repository of your own are
in [Theme Packages](/docs/advanced/theme-packages/); which upstream palettes the
built-in ones adapt, and the attribution each one carries, is in
[Theme sources](/docs/advanced/theme-packages/#theme-sources).

## Built-in themes

`BuiltinTheme` (`lib/data/model/app/builtin_theme.dart`) lists the packages this
build ships and the label each gets in the picker. `Default` is a Dart const and
reads no asset. The other five are source folders under `assets/themes/<id>/`,
one `manifest.toml` each, registered in `pubspec.yaml`.

A bundled folder goes through the same installer as an imported folder or a
`.fsbt` archive, so a theme shipped with the app offers no field an installed
one does not. The folders are checked in as source and Flutter bundles them
directly; no archive or other binary asset is committed for them.

Adding one is two edits beyond the folder itself: a line in `pubspec.yaml` and a
`BuiltinTheme` case for the picker label.

## Loading

`BuiltinThemeLoader` (`lib/core/service/theme_package.dart`) loads one on
demand. It keeps `_loaded` for what came back and `_pending` for a load in
flight, so two requests for one theme share a parse instead of starting two,
and a failure can be retried because nothing caches it.

Opening the picker loads nothing. A folder is read when it is selected, or at
startup when it is the saved selection. Built-in assets keep a separate runtime
cache from user-installed themes and do not appear in that list.

## The parser and the editor schema

Three files hold the grammar a manifest is checked against:
`theme_package.dart` (top-level tables, archive entries, the schema range),
`theme_components.dart` (component fields, states, and every numeric range) and
`theme_palette.dart` (the non-deprecated ColorScheme roles).
`docs/schemas/fsbt-manifest.schema.json` mirrors them so an editor can report a
mistake while the file is typed, which is why it is written from those files
rather than from this documentation.

It is as strict as the installer with one rule it cannot express: the installer
refuses a color under `icons.colors` whose key has no entry under `icons.images`
because the check spans two tables, and a JSON Schema has no way to say it.

Every checked-in manifest — the bundled folders, `docs/examples/aurora/` and the
published ones — has been validated against the schema with `uvx --from
check-jsonschema check-jsonschema`. Nothing in CI does that today, so a parser
change that the schema does not follow is silent.

## Theme store

`ThemeRepo` (`lib/core/service/theme_repo.dart`) reads the two levels: a catalog
of repositories, then one repository's tree. `assets/catalog/repos.toml` is the
floor — what a first run with no network offers — and `Urls.themeCatalog` is the
address the app reads instead whenever it answers.

A repository address is HTTPS and resolves to a tarball. A git repository is
fetched as `<address>/archive/HEAD.tar.gz`, because which branch a repository
calls default is not the app's to guess. `ThemePackages.download` refuses a URL
that carries credentials, and follows at most three redirects, re-checking each
target for HTTPS before it is used. Plain HTTP is refused for a repository: it
decides which bytes get installed.

Limits are in `ThemeRepo` — 100 repositories and 1 MiB for the catalog, a
repository tree at 16 MiB compressed, 64 MiB unpacked, 8 MiB per entry. A
section the build does not know is skipped rather than failing the repository,
which is how one tree carries `themes/` and `plugins/` and serves both this app
and the plugin feature.

## Official themes

`lollipopkit/serverbox-plugins` holds the official themes in `themes/`, one
source folder and one listing per theme, beside `plugins/`.

`scripts/publish-themes.sh <id> <version>` publishes one version. It reads the
id and the `[schema]` range out of the manifest, so the listing records what the
package itself says; packs the folder with `zip`, whose `-X` keeps per-machine
file attributes out of the archive; computes the digest and the size; creates
the release tagged `<id>-<version>` with `<tag>.fsbt` as its asset; and appends
a `[[version]]` block to the listing.

The two orders it enforces are the ones that break quietly. The release goes up
before the listing that names it, because a listing pointing at a 404 is broken
for every reader. A version already recorded with a different digest is refused
rather than republished, because a version number that no longer identifies
bytes makes every other check here meaningless.
