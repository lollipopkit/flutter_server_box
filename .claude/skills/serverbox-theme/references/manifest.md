# manifest.toml reference

Condensed from the theme authoring guide and the JSON Schema
(`docs/schemas/fsbt-manifest.schema.json`, which wins on any disagreement).

## Contents

- Top level and [schema]
- [colors] and palette roles
- [icons]
- [background], [splash], [shapes]
- [components] and [layout]
- [variants]
- Package limits
- Theme store

## Top level and [schema]

| Field | Required | Values |
|---|---|---|
| `id` | yes | `^[a-z0-9][a-z0-9._-]{0,63}$`, stable across versions |
| `name` | yes | shown in Theme preset |
| `modes` | yes | `["light"]`, `["dark"]` or `["light", "dark"]`; no duplicates |
| `format` | no | `1` (default) |
| `[schema] min`, `max` | yes | inclusive range; the app reads 1–3 and needs overlap |

Schema 2 added SVG icons, `[icons.colors]` and `[splash]`; a package using any
of them declares `min = 2`. Schema 3 added the components marked ³ below,
`minHeight` on button tables, `background.tile`, `[layout]` and `[variants]`; a package using any of them
declares `min = 3`.

Unknown top-level tables and fields are rejected. Explicit zero values are
kept; invalid values are errors, never replaced by defaults.

## [colors]

| Field | Default | Notes |
|---|---|---|
| `mode` | `0` | 0 system, 1 light, 2 dark; a single entry in `modes` overrides it |
| `seed` | `0xFF880E4F` | ARGB; generates every role a palette does not set |
| `systemColor` | `false` | use the OS accent as seed where available |
| `palette.light`, `palette.dark` | empty | explicit roles, ARGB integers only |

The 46 roles (deprecated ones such as `background` are rejected):

```
primary onPrimary primaryContainer onPrimaryContainer
primaryFixed primaryFixedDim onPrimaryFixed onPrimaryFixedVariant
secondary onSecondary secondaryContainer onSecondaryContainer
secondaryFixed secondaryFixedDim onSecondaryFixed onSecondaryFixedVariant
tertiary onTertiary tertiaryContainer onTertiaryContainer
tertiaryFixed tertiaryFixedDim onTertiaryFixed onTertiaryFixedVariant
error onError errorContainer onErrorContainer
surface onSurface surfaceDim surfaceBright
surfaceContainerLowest surfaceContainerLow surfaceContainer surfaceContainerHigh
surfaceContainerHighest onSurfaceVariant outline outlineVariant
shadow scrim inverseSurface onInverseSurface
inversePrimary surfaceTint
```

Where a role name is accepted as a color (components, `icons.colors`,
`splash.color`), it resolves against the final palette of the brightness in use.

## [icons]

| Field | Notes |
|---|---|
| `style` | `"classic"` (default) or `"mingcute"`, for every key without an image |
| `images` | key → `icons/<key with . as _>.png` or `.svg`; nothing else |
| `colors` | key → ARGB or role name; only keys that `images` carries (schema 2) |

Keys: `tab.<t>` and `tab.<t>.selected` for `server ssh file snippet agent
benchmark remoteDesktop virt`; `nav.more nav.settings nav.tune nav.privacy
nav.agent nav.tabs nav.server nav.sort nav.terminal nav.folder nav.cloud
nav.snippet nav.inbox nav.key nav.info nav.download nav.desktop`.

PNG: ≤ 512×512, ≤ 256 KiB. SVG: ≤ 256 KiB, UTF-8, root `<svg>`, no DTD or
entity, no `<script>`/`<style>`/`<foreignObject>`, no processing instruction,
no `href` or `url(…)` except `#fragment`s of the same file. Both are tinted
with one color, so draw with `currentColor`. A missing or refused icon falls
back to the built-in glyph.

## [background]

`type` `"none"` (default), `"gradient"` (from the palette) or `"image"`.
`image` only with `type = "image"`: `background.png`, `.jpg` or `.jpeg`
(≤ 8 MiB, ≤ 8192 px a side, ≤ 64 megapixels). `opacity` 0–0.6 (default
0.18) and `blur` 0–30 (default 0) apply to the image only. `tile` 16–1024
(schema 3, image only) repeats the image every that many logical pixels from
the top left instead of cover-fitting one copy — for a pattern: draw a seamless
tile on a transparent background; the surface shows through.

## [splash] (schema 2)

Absent unless present. `color`: ARGB or role name. `logo`: `splash_logo.png`,
`.jpg`, `.jpeg` or `.svg` at the root (≤ 512 KiB; raster ≤ 2048×2048; SVG
checked like an icon), drawn at 96 px in its own colors — not tinted;
`currentColor` in an SVG logo is `onSurface`.
`duration`: 100–3000 ms, default 600. Shown only at launch.

## [shapes]

`card`, `tile`, `button` radii, 0–40; defaults 12, 8, 10. A component's
`radius` takes precedence.

## [components]

`[components.<name>]` applies to both modes; `[components.light.<name>]` and
`[components.dark.<name>]` override per brightness. Colors: ARGB or role name.
Radii 0–40, `borderWidth` 0–8, `elevation` 0–24, sizes (`minHeight`, `height`,
`iconSize`, badge sizes) 0–96, thicknesses (`thickness`, `trackHeight`) 0–16,
insets `[l, t, r, b]` 0–64.

| Component | Fields |
|---|---|
| `card` | backgroundColor radius borderColor borderWidth elevation shadowColor surfaceTintColor margin |
| `tile` | backgroundColor selectedTileColor textColor iconColor selectedColor radius borderColor borderWidth padding |
| `button` | backgroundColor foregroundColor overlayColor radius borderColor borderWidth elevation shadowColor surfaceTintColor padding minHeight³ |
| `input` | filled fillColor radius borderColor borderWidth focusedBorderColor errorBorderColor disabledBorderColor padding |
| `navigation` | backgroundColor indicatorColor indicatorRadius selectedIconColor unselectedIconColor selectedLabelColor unselectedLabelColor elevation |
| `dialog` | backgroundColor radius borderColor borderWidth elevation shadowColor surfaceTintColor barrierColor insetPadding |
| `sheet` | backgroundColor radius borderColor borderWidth elevation shadowColor surfaceTintColor barrierColor dragHandleColor |
| `textButton`³ `outlinedButton`³ | the `button` fields |
| `iconButton`³ | the `button` fields, iconSize |
| `search`³ | backgroundColor radius borderColor borderWidth elevation iconColor textColor hintColor height padding |
| `appBar`³ | backgroundColor foregroundColor titleColor iconColor elevation shadowColor surfaceTintColor |
| `segmented`³ | backgroundColor selectedColor textColor selectedTextColor radius borderColor borderWidth |
| `sidebar`³ | backgroundColor selectedColor textColor selectedTextColor iconColor selectedIconColor radius padding |
| `menu`³ | backgroundColor textColor radius borderColor borderWidth elevation shadowColor surfaceTintColor |
| `tooltip`³ | backgroundColor textColor radius borderColor borderWidth padding |
| `toast`³ | backgroundColor textColor radius borderColor borderWidth elevation |
| `switch`³ | thumbColor trackColor trackOutlineColor selectedThumbColor selectedTrackColor selectedTrackOutlineColor |
| `slider`³ | activeTrackColor inactiveTrackColor thumbColor overlayColor trackHeight |
| `progress`³ | color trackColor thickness radius |
| `badge`³ | backgroundColor textColor smallSize largeSize |
| `chip`³ | backgroundColor selectedColor textColor radius borderColor borderWidth padding |
| `divider`³ | color thickness |
| `scrollbar`³ | thumbColor trackColor radius thickness |

³ schema 3.

`button` is the primary button only (elevated, filled, Btn.elevated). Text,
outlined and icon buttons keep the app's style unless their own table sets
them — a filled `button` no longer turns text actions into filled ones.
`search` is the pill-shaped search fields (settings, server switcher, in-bar);
the field inside never takes `input`'s border or fill. `sidebar` is the side
bar and settings menu rows; `segmented` also the app's segmented tabs; `toast`
also snack bars; `divider` also hairlines.

States: `[components.<button|textButton|outlinedButton|iconButton>.hovered|pressed|focused|selected|disabled]`
take that table's fields; priority disabled > pressed > hovered > focused >
selected > base.

## [layout] (schema 3)

| Field | Values |
|---|---|
| `density` | `"compact"`, `"standard"`, `"comfortable"`; omitted = platform default |

## [variants] (schema 3)

Several themes in one package (one install, one version); the picker offers
each as `<name> · <variant>`. Everything outside `[variants]` is shared.

| Field | Values |
|---|---|
| key | `^[a-z0-9][a-z0-9_-]{0,31}$`, at most 8 variants |
| `name` | required, the variant's label, e.g. `"Trans"` |
| `colors` `icons` `background` `splash` `shapes` `components` `layout` | drawn over the shared tables: tables merge key by key, other values replace |

`variants/<key>/background.png` (or `.jpg`/`.jpeg`) and
`variants/<key>/splash_logo.svg|png` replace the package's file of that name
for that variant. Icon files are shared: a variant may set `icons.style` and
`icons.colors`, never `icons.images`. Every variant must be a complete theme,
and a file no variant uses is refused. Worked example:
`store/themes/serverbox.pride`.

## Package limits

The `.fsbt` and the unpacked total are each ≤ 16 MiB; `manifest.toml`
≤ 64 KiB. Only `manifest.toml`, `icons/…` named by `images`, one background
and one splash logo may be in it; other entries, duplicates, symlinks,
encrypted entries and path traversal are rejected.

## Theme store

A theme repository is a git repository (fetched as `<repo>/archive/HEAD.tar.gz`)
or any HTTPS `.tar.gz`, holding:

```toml
# repo.toml
schema = 1
name = "Somebody's themes"
```

```toml
# themes/<id>.toml — the file name is the theme's id
id = "yourname.mytheme"
name = "My Theme"
description = "One line"  # or a table: [description] en = "…" zh = "…"
homepage = "https://…"
license = "MIT"

[[version]]
version = "1.0.0"
schema_min = 1          # the package's own [schema] range
schema_max = 3
url = "https://…/yourname.mytheme-1.0.0.fsbt"   # or path = "packages/….fsbt" in the tree
sha256 = "…64 hex…"     # required; the store refuses a mismatch
size = 1234
```

`description` as a table is looked up by the app's (or site's) language: the
full tag (`zh-TW`), the language (`zh`), `en`, then the first entry.

`scripts/publish.py` writes these `[[version]]` blocks: it packs each changed
theme, uploads it to the repository's `themes` pre-release and appends the
entry. List every version still offered: each app installs the newest one its
schema range can read. Never change the bytes behind a recorded version; publish a new
version instead. To appear in the app's store, open a pull request adding
`[[repo]] url = "…"` to `assets/catalog/repos.toml` in flutter_server_box.
Limits: tree ≤ 16 MiB compressed, 64 MiB unpacked, 8 MiB per file.
