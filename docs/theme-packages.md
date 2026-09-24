# ServerBox theme packages

`.fsbt` is a ZIP archive. Its root contains `manifest.toml` (UTF-8 TOML),
optional `background.png` / `background.jpg` / `background.jpeg`, and optional
PNG files in `icons/`. Format version 1 contains UI colors, in-app icons, a
background, and component radii. Launcher icons and fonts are managed
separately and are not accepted in a theme package.

An editable example is available at [Aurora](examples/aurora/manifest.toml).
On desktop, select **Install theme → Folder** to import its directory during development.
This copies the validated files into the app; select the folder again after
editing it. For distribution, ZIP the directory contents so `manifest.toml`
is at the archive root, then rename the archive to `.fsbt`.
Keep built-in themes as editable source directories in Git rather than
committing generated `.fsbt` archives.
Installed packages appear in **Theme preset**. In its sheet, Up/Down previews
the focused theme without saving settings. Enter (or clicking an item) applies
it; Escape, tapping outside, or dismissing the sheet restores the original
appearance. Preset values are read-only;
select **Custom** to choose a local background image and edit in-app icons,
corners, opacity, and blur. The previous Custom image and settings are restored
when available.

```toml
id = "example.amethyst"
name = "Amethyst"
modes = ["dark"]

[schema]
min = 1
max = 1

[colors]
mode = 2
seed = 0xFF880E4F

[colors.palette.dark]
primary = 0xFFC87FD0
surface = 0xFF141014

[icons.images]
"tab.server" = "icons/tab_server.png"
"nav.settings" = "icons/nav_settings.png"

[background]
type = "image"
image = "background.png"
blur = 8
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
schema **v1–v1** and shows this range in the **Install theme** help text. The installer
requires the package range to overlap the app range and checks it again when
loading an installed theme. Both `schema.min` and `schema.max` are required.
`seed` and palette colors are ARGB integers; hexadecimal TOML values such as
`0xFF61AFEF` are supported. `icons.style` is `classic` or `mingcute` and is used
where the package does not provide an image. `background.type` is `none`,
`gradient`, or `image`; omit `image` unless the type is `image`. Opacity is
0–0.6, blur is 0–30, and each shape radius is 0–40.
Image paths must match the fixed names above. The installer rejects other
archive entries, duplicate paths, symlinks, encrypted files, and path traversal.

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

## Image assets

Package icon images must be PNG, at most 512 × 512 pixels and 256 KiB each.
Supported keys are `tab.<tab>` and `tab.<tab>.selected` for `server`, `ssh`,
`file`, `snippet`, `agent`, `benchmark`, and `remoteDesktop`. Navigation keys
are `nav.more`, `nav.settings`, `nav.tune`, `nav.privacy`, `nav.agent`,
`nav.tabs`, `nav.server`, `nav.sort`, `nav.terminal`, `nav.folder`, `nav.cloud`,
`nav.snippet`, `nav.inbox`, `nav.key`, `nav.info`, `nav.download`, and
`nav.desktop`. Additional keys are rejected in version 1.

The compressed archive and total extracted content are each limited to 16 MiB.
`manifest.toml` is limited to 64 KiB. The background is limited to 8 MiB,
8192 pixels on either side, and 64 megapixels. The installer decodes and checks
images before writing an isolated, content-addressed installation directory.

## Theme store catalog

The app accepts a user-configured HTTPS URL for a catalog with this shape:

```json
{
  "format": 1,
  "themes": [
    {
      "name": "Amethyst",
      "url": "https://example.org/themes/amethyst.fsbt",
      "sha256": "0000000000000000000000000000000000000000000000000000000000000000"
    }
  ]
}
```

The catalog can contain up to 100 entries and is limited to 1 MiB. Each entry
requires a SHA-256 digest; the app verifies it before installing the package.
Direct URL installation accepts HTTPS `.fsbt` links without a catalog. The
installer follows at most three HTTPS redirects and does not send credentials.
