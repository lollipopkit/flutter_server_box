---
title: Theme Package Authoring
description: Theme package format, validation, and publishing
---

`.fsbt` is a ZIP archive. Its root contains `manifest.toml` (UTF-8 TOML),
optional `background.png` / `background.jpg` / `background.jpeg`, optional
`icons/` files, and an optional `splash_logo.png` / `.jpg` / `.jpeg` / `.svg`.
Format version 1 contains UI colors, in-app icons, a background, component
radii, and a splash screen. Launcher icons and fonts are managed separately and
are not accepted in a theme package.

The [Aurora example](https://github.com/lollipopkit/flutter_server_box/blob/main/docs/examples/aurora/manifest.toml)
demonstrates the package format. To preview a theme while developing on
desktop, select **Install theme → Folder** and choose
its source directory. The app validates and copies the files; select the folder
again after editing to load the changes. To distribute the package, ZIP the
directory contents with `manifest.toml` at the archive root and use the `.fsbt`
extension.

For how built-in themes are packaged, loaded, and distributed, see
[Themes](/docs/development/themes/). For the user-facing guide to choosing and
installing themes, see [Themes for users](/docs/advanced/theme-packages/).

```toml
id = "example.amethyst"
name = "Amethyst"
modes = ["dark"]

# An SVG icon, an icon color, and a splash are schema 2 features, so the
# minimum this package is readable at is 2. See "Schema versions".
[schema]
min = 2
max = 2

[colors]
mode = 2
seed = 0xFF880E4F

[colors.palette.dark]
primary = 0xFFC87FD0
surface = 0xFF141014

[icons.images]
"tab.server" = "icons/tab_server.svg"
"nav.settings" = "icons/nav_settings.png"

# Per-icon colors: an ARGB integer or the name of a palette role.
[icons.colors]
"tab.server" = "primary"
"nav.settings" = 0xFFC87FD0

[background]
type = "image"
image = "background.png"
blur = 8

[splash]
color = "surface"
logo = "splash_logo.svg"
duration = 900
```

Only `id`, `name`, `modes`, and the `schema` table are required. Omitted fields use
these defaults; an entire table may be omitted. Partial tables override only
the fields supplied. Explicit zero values are preserved, and invalid values
are rejected rather than replaced with defaults.

| Field | Default |
| --- | --- |
| `format` | `1` |
| `colors.mode` | `0` (system) |
| `colors.seed` | `0xFF880E4F` |
| `colors.systemColor` | `false` |
| `colors.palette.light`, `colors.palette.dark` | Empty |
| `icons.style` | `"classic"` |
| `icons.images` | Empty |
| `icons.colors` | Empty (follow the ambient icon color) |
| `splash` | Absent (no splash) |
| `background.type` | `"none"` |
| `background.opacity` | `0.18` |
| `background.blur` | `0` |
| `shapes.card`, `shapes.tile`, `shapes.button` | `12`, `8`, `10` |
| `components` | Empty (inherit app styles) |

The Default theme remains a Dart const and keeps its original radii (`13`, `9`,
`30`). The defaults above apply to themes imported from folders and `.fsbt`
archives.


`modes` must declare `["light"]`, `["dark"]`, or `["light", "dark"]`.
Empty lists, duplicates, and unknown modes are rejected. A single supported mode
locks the app's ThemeMode even when the system appearance changes. The settings
row explains that switching modes requires a theme that supports the other
mode. Themes supporting both modes allow System, Light, and Dark.
`colors.mode` is the initial preference: 0 (system), 1 (light), or 2 (dark).
A single supported mode overrides this preference. AMOLED is a bundled theme
that supports both modes, with generated light colors and black dark surfaces.
Legacy AMOLED settings migrate to Dark + AMOLED; Auto AMOLED migrates to
System + AMOLED. AMOLED is no longer a ThemeMode option.
`format` versions the ZIP manifest structure. `schema` is the inclusive range
of theme UI schema versions the package supports. The app currently supports
schema **v1–v2** and shows this range in the **Install theme** help text. The
installer requires the package range to overlap the app range and checks it again when
loading an installed theme. Both `schema.min` and `schema.max` are required.
`seed` and palette colors are ARGB integers; hexadecimal TOML values such as
`0xFF61AFEF` are supported. `icons.style` is `classic` or `mingcute` and is used
where the package does not provide an image. `background.type` is `none`,
`gradient`, or `image`; omit `image` unless the type is `image`. Opacity is
0–0.6, blur is 0–30, and each shape radius is 0–40.
Image paths must match the fixed names above. The installer rejects other
archive entries, duplicate paths, symlinks, encrypted files, and path traversal.
Unknown top-level tables are rejected, so misspelled sections produce an error
instead of being silently ignored.

## Manifest schema for editors

The manifest is validated against a JSON Schema. Editors can report unknown
tables and fields, out-of-range values, unsupported icon keys, and icon file
names that do not match their keys as you edit:

```text
https://raw.githubusercontent.com/lollipopkit/flutter_server_box/main/docs/schemas/fsbt-manifest.schema.json
```

TOML editors that support the Taplo schema directive, including Taplo, Even
Better TOML for VS Code, and Tombi, read the schema from the first line of the
file. The [example](https://github.com/lollipopkit/flutter_server_box/blob/main/docs/examples/aurora/manifest.toml)
uses this directive:

```toml
#:schema https://raw.githubusercontent.com/lollipopkit/flutter_server_box/main/docs/schemas/fsbt-manifest.schema.json
```

For editors that associate schemas by file name, configure the same URL in the
editor's settings. The directive is the only editor-independent option.

The schema is as strict as the installer except for one rule: it cannot require
each key in `icons.colors` to appear in `icons.images`, because that check spans
two tables. The installer rejects all other errors reported by the schema.
The schema describes the latest version, so packages declaring `min = 1` still
validate. See
[Themes](/docs/development/themes/#the-parser-and-the-editor-schema).

## Schema versions

`schema.min` is the oldest app schema version that can read the package. The
installer checks compatibility against the app's supported range. It does not
migrate incompatible packages: packages with non-overlapping ranges are not
installed, and an installed package that later becomes incompatible is not
loaded. It is shown as unreadable, and its settings are left unchanged.

Schema **2** added SVG icons, `icons.colors`, and the `splash` table. A package
using any of these features must declare `min = 2`. Otherwise, a schema 1 build
could install the package but silently discard those features: SVG icons would
fall back to built-in glyphs, and custom colors and splash screens would not
appear. The current ceiling is `max = 2`; a package whose range extends beyond
it can still be installed if the ranges overlap.

## Icons

`icons.images` maps an icon key to the file that carries it, inside `icons/`.
The file name must be the key with dots replaced by underscores, and either
extension:

```toml
[icons.images]
"tab.server" = "icons/tab_server.svg"
"nav.settings" = "icons/nav_settings.png"
```

A PNG is at most 512 × 512 pixels and 256 KiB. An SVG has no raster size to
measure, so it is checked as a document instead: it must be UTF-8, its root
element must be `svg`, and it is at most 256 KiB. A DTD, an entity declaration,
a `<script>`, a `<style>`, a `<foreignObject>`, or anything that reaches outside
the file — an `href` that is not a fragment of this document, or a `url(…)` that
is not — is refused. A refused or missing icon draws the built-in glyph for that
key rather than an empty box.

Both formats are tinted with one color, so a drawing should use `currentColor`
for the parts that should follow it. Without `icons.colors` that color is the
ambient icon color, which is what every icon used before a package could say
otherwise. With it, each entry overrides that color for one icon:

```toml
[icons.colors]
"tab.server" = "primary"       # any palette role, resolved per brightness
"nav.settings" = 0xFFC87FD0    # or an ARGB integer
```

A color for a key the package carries no image for is refused: it would be a
typo that shows up as nothing at all.

## Color palettes

`colors.palette.light` and `.dark` accept all 46 non-deprecated ColorScheme
roles below. Unspecified roles come from the seed. Unknown and deprecated
roles are rejected. Palette values are ARGB integers.

```text
primary, onPrimary, primaryContainer, onPrimaryContainer
primaryFixed, primaryFixedDim, onPrimaryFixed, onPrimaryFixedVariant
secondary, onSecondary, secondaryContainer, onSecondaryContainer
secondaryFixed, secondaryFixedDim, onSecondaryFixed, onSecondaryFixedVariant
tertiary, onTertiary, tertiaryContainer, onTertiaryContainer
tertiaryFixed, tertiaryFixedDim, onTertiaryFixed, onTertiaryFixedVariant
error, onError, errorContainer, onErrorContainer
surface, onSurface, surfaceDim, surfaceBright
surfaceContainerLowest, surfaceContainerLow, surfaceContainer, surfaceContainerHigh
surfaceContainerHighest, onSurfaceVariant, outline, outlineVariant
shadow, scrim, inverseSurface, onInverseSurface
inversePrimary, surfaceTint
```

## Component styles

Use `[components.card]` for common values and `[components.light.card]` or
`[components.dark.card]` for brightness-specific overrides. All tables and
fields are optional. Missing fields preserve the app's style; explicit zero
and `false` are retained. Component `radius` takes precedence over `[shapes]`.
Colors accept an ARGB integer or any ColorScheme role name (for example
`backgroundColor = "surfaceContainer"`), resolved against the final palette.
Unknown component names, fields, states and role names are rejected.

| Component | Supported fields |
| --- | --- |
| `card` | `backgroundColor`, `radius`, `borderColor`, `borderWidth`, `elevation`, `shadowColor`, `surfaceTintColor`, `margin` |
| `tile` | `backgroundColor`, `selectedTileColor`, `textColor`, `iconColor`, `selectedColor`, `radius`, `borderColor`, `borderWidth`, `padding` |
| `button` | `backgroundColor`, `foregroundColor`, `overlayColor`, `radius`, `borderColor`, `borderWidth`, `elevation`, `shadowColor`, `surfaceTintColor`, `padding` |
| `input` | `filled`, `fillColor`, `radius`, `borderColor`, `borderWidth`, `focusedBorderColor`, `errorBorderColor`, `disabledBorderColor`, `padding` |
| `navigation` | `backgroundColor`, `indicatorColor`, `indicatorRadius`, `selectedIconColor`, `unselectedIconColor`, `selectedLabelColor`, `unselectedLabelColor`, `elevation` |
| `dialog` | `backgroundColor`, `radius`, `borderColor`, `borderWidth`, `elevation`, `shadowColor`, `surfaceTintColor`, `barrierColor`, `insetPadding` |
| `sheet` | `backgroundColor`, `radius`, `borderColor`, `borderWidth`, `elevation`, `shadowColor`, `surfaceTintColor`, `barrierColor`, `dragHandleColor` |

Radii are 0–40, border widths 0–8, elevations 0–24. Insets (`padding`, `margin`,
`insetPadding`) are four numbers `[left, top, right, bottom]`, each 0–64.
Numbers must be finite. `filled` is a boolean. Fonts remain separate settings.

Button state tables (`[components.button.hovered]`, `.pressed`, `.focused`,
`.selected`, `.disabled`) accept the same fields as the base button table.
State tables merge across common and brightness-specific configuration.
For each property, priority is disabled > pressed > hovered > focused > selected
> base. Unspecified properties inherit the existing button theme and Flutter defaults.

These styles apply to Material components. The custom NavigationRail also uses
navigation colors and indicator shape; CardX honors card shape and elevation;
Input honors input borders and padding; SideBarTile honors tile colors and borders
while retaining its compact spacing. Btn.elevated honors the button style;
compact Btn rows/columns retain their layout and use the themed radius.
Explicit per-widget overrides still take priority. Theme preview uses these
same settings in memory; dismissing the picker restores the previous appearance.

## Splash screen

`splash` covers the app with a color and an optional logo while it takes its
first frames, then fades out. It is absent unless the table is present, since
otherwise every package would carry one.

```toml
[splash]
color = "surface"          # any palette role, or an ARGB integer
logo = "splash_logo.svg"   # optional, one fixed name at the archive root
duration = 900             # milliseconds, 100–3000, default 600
```

The logo is one file named `splash_logo.png`, `splash_logo.jpg`,
`splash_logo.jpeg` or `splash_logo.svg` at the archive root — a name, not a
path. A PNG or JPEG is at most 2048 × 2048 pixels and 512 KiB, an SVG 512 KiB
and the same document checks as an icon. It is drawn at 96 logical pixels,
centered, tinted like an icon only when it is an SVG — a raster logo keeps its
own colors.

`duration` is how long the splash stays up before it fades, and what it delays
is the launch, which is why the ceiling is low. It is read once, when the app
builds its first frame: choosing another theme later does not play a splash
again, and a package selected during a launch does not play its own.

Only this half can follow a theme. What the operating system draws before Dart
starts — an Android window background or an iOS launch storyboard — is decided
when the app is built and can only change with the system's brightness.

## Image keys and limits

Supported icon keys are `tab.<tab>` and `tab.<tab>.selected` for `server`, `ssh`,
`file`, `snippet`, `agent`, `benchmark`, `remoteDesktop`, and `virt`. Navigation keys
are `nav.more`, `nav.settings`, `nav.tune`, `nav.privacy`, `nav.agent`,
`nav.tabs`, `nav.server`, `nav.sort`, `nav.terminal`, `nav.folder`, `nav.cloud`,
`nav.snippet`, `nav.inbox`, `nav.key`, `nav.info`, `nav.download`, and
`nav.desktop`. Additional keys are rejected in version 1.

The compressed archive and total extracted content are each limited to 16 MiB.
`manifest.toml` is limited to 64 KiB. An icon is limited to 256 KiB, the splash
logo to 512 KiB, and the background to 8 MiB, 8192 pixels on either side, and 64
megapixels. The installer checks every image — decoding a PNG or JPEG, reading
an SVG as a document — before writing an isolated, content-addressed
installation directory.

## Theme store

The store reads two levels. A **catalog** is a TOML file that lists
repositories without naming themes or versions. Each **repository** is a git
repository containing one TOML file per theme.

Open **Settings → Appearance → Theme store** to view one list combining themes
offered by the catalog and themes installed on this device. Each theme appears
once. Tap an uninstalled theme to install and apply it; tap an installed theme
to apply it. Use the trailing button to install or remove a theme, as
appropriate. Removing the active theme returns the app to its default theme.

The listing is cached between runs, so the page can show its previous contents
immediately. The caption below the app bar identifies the repositories and
when they were last read. Use the refresh button beside the caption to read the
catalog again. Versions this build cannot read remain listed with an
explanation, so users can still see that the theme exists.

```toml
schema = 1
name = "ServerBox themes"

[[repo]]
url = "https://github.com/lollipopkit/serverbox-plugins"
```

Repository URLs must use HTTPS and point to either a git repository or a
tarball. Git repositories are fetched from
`<address>/archive/HEAD.tar.gz`, which uses the repository's default branch
without assuming its name.

The bundled repository is
[`lollipopkit/serverbox-plugins`](https://github.com/lollipopkit/serverbox-plugins),
which contains the official themes and plugins in one tree.

### A theme repository

`repo.toml` identifies the repository and its schema. Each theme has a file
under `themes/`, named after its `id`; files whose paths do not match their IDs
are rejected.

```toml
schema = 1
name = "Somebody's themes"
```

```toml
# themes/amethyst.toml
id = "amethyst"
name = "Amethyst"
description = "A purple palette"
homepage = "https://example.org/amethyst"
license = "MIT"

[[version]]
version = "1.2.0"
schema_min = 1
schema_max = 1
url = "https://github.com/example/themes/releases/download/amethyst-1.2.0/amethyst.fsbt"
sha256 = "0000000000000000000000000000000000000000000000000000000000000000"
size = 40960

[[version]]
version = "1.1.0"
schema_min = 1
schema_max = 1
path = "packages/amethyst-1.1.0.fsbt"
sha256 = "1111111111111111111111111111111111111111111111111111111111111111"
```

Each version specifies either `url`, pointing to its release, or `path`, naming
a `.fsbt` file in the repository tree. The store requires `sha256` to install
the package. `size` is used to show the download size before installation.

`schema_min` and `schema_max` declare the package's manifest schema range. This
allows one repository to serve apps with different supported versions: **the
app installs the newest version it can read**, which may not be the newest
version listed. Themes with only newer, unreadable versions remain listed with
an explanation. Versions using schema 2 features must set `schema_min = 2`;
setting it to 1 could offer older apps a package that installs but silently
loses its icon, color, or splash screen.

Publish each theme version as a separate release tagged `<id>-<version>` and
attach its `.fsbt` archive. To add a repository to the app's catalog, open a
pull request to this repository that adds a `[[repo]]` entry.

Repositories may contain a `plugins/` section alongside `themes/`. This build
only reads themes and skips that section without rejecting the repository.

Direct URL installation accepts HTTPS `.fsbt` links without a store. The
installer follows at most three HTTPS redirects and does not send credentials.
Catalog and repository tree size limits are documented in
[Themes](/docs/development/themes/#theme-store).

## Theme sources

ServerBox adapts the UI palettes of these VS Code themes to Material surfaces,
selection states, cards and buttons. These are independent adaptations, not
VS Code extension bundles. Fonts and terminal/editor color settings remain
separate. Midnight and AMOLED are original ServerBox palettes. AMOLED uses black
surfaces in dark mode and generated colors in light mode, allowing System
appearance.

The selection uses Marketplace install counts for standalone color themes,
excluding icon themes and themes distributed with language tooling. GitHub
Theme, One Dark Pro and Dracula were the three leading entries in that
comparison. GitHub Dark uses the GitHub Theme dark palette. Muted text colors
are adjusted where needed to keep normal text at a contrast ratio of at least
4.5:1.

<details>
<summary>Upstream attribution</summary>

**One Dark Pro**

Source: [One Dark Pro](https://github.com/Binaryify/OneDark-Pro)

The MIT License (MIT)

Copyright (c) 2013-2022 Binaryify

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in
all copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
THE SOFTWARE.

**GitHub Theme**

Source: [GitHub Theme](https://github.com/primer/github-vscode-theme)

MIT License

Copyright (c) 2020 Primer

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.

**Dracula**

Source: [Dracula](https://github.com/dracula/visual-studio-code)

The MIT License (MIT)

Copyright (c) 2016 Dracula Theme

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in
all copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.

</details>
