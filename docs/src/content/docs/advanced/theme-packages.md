---
title: Theme Packages
description: Author, install and publish a theme package
---

`.fsbt` is a ZIP archive. Its root contains `manifest.toml` (UTF-8 TOML),
optional `background.png` / `background.jpg` / `background.jpeg`, optional
`icons/` files, and an optional `splash_logo.png` / `.jpg` / `.jpeg` / `.svg`.
Format version 1 contains UI colors, in-app icons, a background, component
radii, and a splash screen. Launcher icons and fonts are managed separately and
are not accepted in a theme package.

An editable example is available at
[Aurora](https://github.com/lollipopkit/flutter_server_box/blob/main/docs/examples/aurora/manifest.toml).
On desktop, select **Install theme → Folder** to import its directory during development.
This copies the validated files into the app; select the folder again after
editing it. For distribution, ZIP the directory contents so `manifest.toml`
is at the archive root, then rename the archive to `.fsbt`.
Installed packages appear in **Theme preset**. In its sheet, Up/Down previews
the focused theme without saving settings. Enter (or clicking an item) applies
it; Escape, tapping outside, or dismissing the sheet restores the original
appearance. Preset values are read-only;
select **Custom** to choose a local background image and edit in-app icons,
corners, opacity, and blur. The previous Custom image and settings are restored
when available.

How the themes bundled with the app are packaged, loaded and distributed is in
[Themes](/docs/development/themes/).

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

Default remains a Dart const with its original radii (`13`, `9`, `30`);
these manifest defaults apply to folder and `.fsbt` themes.


`modes` must declare `["light"]`, `["dark"]`, or `["light", "dark"]`.
Empty lists, duplicates, and unknown modes are rejected. A single supported mode
locks the app's ThemeMode, including when the system appearance changes; the
settings row explains that another theme is needed to change modes. Themes that
support both allow System, Light, and Dark.
`colors.mode` is the initial preference: 0 (system), 1 (light), or 2 (dark).
A single supported mode overrides this preference. AMOLED is a bundled theme supporting both modes: generated light colors and
black dark surfaces. Legacy AMOLED settings migrate to Dark + AMOLED; Auto
AMOLED migrates to System + AMOLED. It is no longer a ThemeMode option.
`format` versions the ZIP manifest structure. `schema` is the inclusive range
of theme UI schema versions the package supports. The app currently supports
schema **v1–v2** and shows this range in the **Install theme** help text. The installer
requires the package range to overlap the app range and checks it again when
loading an installed theme. Both `schema.min` and `schema.max` are required.
`seed` and palette colors are ARGB integers; hexadecimal TOML values such as
`0xFF61AFEF` are supported. `icons.style` is `classic` or `mingcute` and is used
where the package does not provide an image. `background.type` is `none`,
`gradient`, or `image`; omit `image` unless the type is `image`. Opacity is
0–0.6, blur is 0–30, and each shape radius is 0–40.
Image paths must match the fixed names above. The installer rejects other
archive entries, duplicate paths, symlinks, encrypted files, and path traversal.
A top-level table it does not know is refused rather than ignored, so a
misspelled section is a failure instead of a setting that silently does nothing.

## Manifest schema for editors

The manifest is validated against a JSON Schema, so an editor reports an
unknown table, an unknown field, a value out of range, an icon key with no such
key, and an icon file whose name does not match its key while it is typed:

```text
https://raw.githubusercontent.com/lollipopkit/flutter_server_box/main/docs/schemas/fsbt-manifest.schema.json
```

A TOML editor that reads the Taplo schema directive — Taplo, Even Better TOML
for VS Code, Tombi — attaches it from the first line of the file, which is what
[the example](https://github.com/lollipopkit/flutter_server_box/blob/main/docs/examples/aurora/manifest.toml) does:

```toml
#:schema https://raw.githubusercontent.com/lollipopkit/flutter_server_box/main/docs/schemas/fsbt-manifest.schema.json
```

Editors that associate a schema by file name instead take the same URL in their
own configuration. Only the directive is universal.

The schema is as strict as the installer, with one exception it cannot express:
it cannot tell that a color under `icons.colors` needs a matching entry under
`icons.images`, which is a check across two tables. Everything else it reports
is also what an install would have refused. It tracks the newest schema version;
a package that declares `min = 1` still validates. What the schema is written
from, and where it is validated, is in
[Themes](/docs/development/themes/#the-parser-and-the-editor-schema).

## Schema versions

`schema.min` is the oldest app that may read the package, and it is what a
build checks itself against. This is a refusal, not a migration: a package
whose range does not overlap the app's is not installed, and an installed one
whose range later stops overlapping is not loaded (it is shown as unreadable,
and its settings are left alone).

Schema **2** added SVG icons, `icons.colors`, and the `splash` table. A package
that uses any of them must declare `min = 2`, because a build that reads only
schema 1 would otherwise install the same bytes and drop the feature without
saying so: the SVG icon becomes the built-in glyph, and the color and the splash
simply do not happen. `max = 2` is the current ceiling; a range that reaches
past it still installs as long as it overlaps.

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
a `<script>`, a `<foreignObject>`, or anything that reaches outside the file —
an `http` `href` or an `url(http…)` — is refused. A refused or missing icon
draws the built-in glyph for that key rather than an empty box.

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
`file`, `snippet`, `agent`, `benchmark`, and `remoteDesktop`. Navigation keys
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

The store reads two levels. The first is a **catalog**: a TOML file listing
repositories, one entry each, naming no theme and no version. The second is a
**repository**: a git repository of TOML files, one per theme.

The address the app reads a catalog from is **Settings → Appearance → Theme
store URL**. It is editable, because a client that cannot be pointed at another
catalog serves one publisher. What that address defaults to, and what the app
falls back to when it does not answer, is in
[Themes](/docs/development/themes/#theme-store).

```toml
schema = 1
name = "ServerBox themes"

[[repo]]
url = "https://github.com/lollipopkit/serverbox-plugins"
```

A repository address is HTTPS, and either a git repository — fetched as
`<address>/archive/HEAD.tar.gz` — or a tarball address directly. `HEAD` rather
than a branch name, because which branch a repository calls default is not the
app's to guess.

The one it ships with is
[`lollipopkit/serverbox-plugins`](https://github.com/lollipopkit/serverbox-plugins),
which holds the official themes and the official plugins in one tree.

### A theme repository

`repo.toml` names the repository and its schema; one file per theme sits under
`themes/`, named after the theme's `id`, and a file whose path and id disagree
is refused.

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

A version names either `url` — its own release — or `path`, a `.fsbt` carried in
the repository's tree. `sha256` is required for the store to install it, and
`size` is for showing what an install will cost before it starts.

`schema_min` and `schema_max` are the manifest schema range the package
declares, which is how one repository serves apps of different ages at once:
**the app installs the newest version it can read**, not the newest version
listed. A theme whose only versions are too new is still listed, saying so.
A version whose package uses a schema 2 feature lists `schema_min = 2`, since
that is what the package itself must declare; listing 1 would offer an older
app a download that installs and then loses the icon, the color or the splash.

Publishing is a release per theme per version, tagged `<id>-<version>` with the
`.fsbt` as its asset. Adding a repository to the app's catalog is a pull request
against this repository that adds one `[[repo]]` entry.

A repository may carry a `plugins/` section beside `themes/`. This build
offers themes only, so that section is read as nothing: skipped, rather than
failing the repository it is in.

Direct URL installation accepts HTTPS `.fsbt` links without a store. The
installer follows at most three HTTPS redirects and does not send credentials.
The size limits a catalog and a repository tree are held to are in
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
