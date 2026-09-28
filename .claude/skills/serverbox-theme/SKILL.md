---
name: serverbox-theme
description: Make a ServerBox app theme — a `.fsbt` package (a folder with `manifest.toml`, optional icons, background and splash) — from a description, a brand color or an existing color scheme, then validate it, pack it and share it. Use this whenever someone wants to create, port, tweak, fix, validate or publish a theme for ServerBox (flutter_server_box), including requests that never say ".fsbt" or "manifest", such as "make ServerBox look like Nord", "port my VS Code theme to the app", "a dark purple theme for server box", "why does my theme fail to install", "add custom tab icons", or "put my theme in the theme store".
---

# ServerBox themes

A ServerBox theme is a folder that becomes a `.fsbt` file (a ZIP) when shared:

```
my-theme/
  manifest.toml          required
  icons/tab_server.svg   optional, one file per icon key
  background.png         optional (.jpg/.jpeg)
  splash_logo.svg        optional (.png/.jpg/.jpeg)
```

A theme changes the app's colors (the Material 3 ColorScheme, per light and
dark), component styles (cards, tiles, buttons, inputs, search fields, the top
bar, navigation, the side bar, segmented tabs, menus, dialogs, sheets, toasts,
switches, sliders, progress, badges, chips, dividers, scrollbars), control
density, corner radii, in-app icons, a background, and a launch splash. It does
**not** change fonts, the launcher icon, or terminal/editor colors — say so if
the request asks for those, rather than inventing fields: the installer rejects
unknown tables and fields.

The format is strict on purpose: every field is checked, and a misspelled table
is an error, not a no-op. So write the manifest from the reference, validate it
with the script, and only then pack it.

## Workflow

### 1. Settle the basics

Ask only for what cannot be decided from the request; propose defaults for the
rest and say what they were.

- **Name** and **id**. The id is stable and lowercase
  (`^[a-z0-9][a-z0-9._-]{0,63}$`); a reverse-DNS style such as
  `yourname.nord` avoids clashing with other people's themes.
- **Modes**: `["dark"]`, `["light"]`, or both. A single mode locks the app to
  it while the theme is selected, so a theme that only makes sense dark should
  say `["dark"]`. Both modes means two palettes to get right.
- **Where the colors come from**: a mood or a single brand color (use `seed`,
  optionally a few overrides), or an existing scheme to port (write full
  palettes — see step 3).
- **Extras**: icons, background, splash. Each is optional and adds files and
  checks; don't add them unless asked.

### 2. Start from the template

Copy `assets/manifest.template.toml` into a new folder as `manifest.toml` and
fill it in. Its first line is a schema directive, so editors with Taplo/Even
Better TOML/Tombi report mistakes as you type. For every field, its range and
default, read `references/manifest.md`.

Schema range: `[schema] min = 1, max = 3` unless the theme uses an SVG icon,
`[icons.colors]` or `[splash]` — those are schema 2 features and need
`min = 2`, or an older app installs the theme and silently drops them. Any
component beyond card, tile, button, input, navigation, dialog and sheet, a
button `minHeight`, `background.tile`, `[layout]`, or `[variants]` is schema 3 and needs `min = 3`.

### 3. Colors

Colors are ARGB integers written as hex: `0xFF1E1E2E` (the `FF` is opacity).
Palette values can also be named anywhere a component or icon color is
expected (`backgroundColor = "surfaceContainer"`).

- **Seed only**: `[colors] seed = 0xFF…` generates every role. Quick and always
  legible; the result is Material's interpretation of the color, not the color.
- **Porting a scheme** (Nord, Dracula, Catppuccin, a VS Code or terminal
  theme, a brand palette): set the roles in `[colors.palette.dark]` /
  `.light` explicitly, so the app looks like the source. Read
  `references/porting.md` for which source color goes to which role, how to
  derive the surface ladder and containers, and how to handle a source with
  only one mode. For a VS Code theme JSON, `scripts/port_vscode.py` drafts the
  palette block.
- Set `surfaceTint = 0x00000000` in a ported palette: Material otherwise tints
  elevated surfaces with `primary`, which shifts carefully chosen surfaces.
- Keep text legible: the validator reports contrast for the text pairs a
  palette sets and warns under 4.5:1 (3:1 for outline). Fix warnings by moving
  the foreground's lightness, not by giving up the source's hue. Upstream
  themes often have muted comment/description colors under 4.5:1; lighten
  (dark) or darken (light) them for `onSurfaceVariant`.

### 4. Optional parts

Only when asked; details in `references/manifest.md`.

- **Icons**: `[icons.images]` maps a key (`"tab.server"`, `"nav.settings"`, …)
  to `icons/<key with dots as underscores>.svg|.png`; no other name is
  accepted. Icons are tinted one color — draw SVGs with `currentColor`. An SVG
  may not contain `<script>`, `<style>`, `<foreignObject>`, a DTD, or any
  `href`/`url(…)` that is not a `#fragment` of the same file.
- **Background**: `type = "gradient"` (from the palette) or `"image"` with
  `image = "background.png"`, `opacity` 0–0.6, `blur` 0–30. For a repeating
  pattern add `tile` (16–1024 logical px, schema 3) and draw one seamless,
  transparent tile; `store/themes/serverbox.piggy` is a worked example.
- **Splash**: `[splash] color`, optional `logo = "splash_logo.svg"`,
  `duration` 100–3000 ms. It is shown only at launch.
- **Shapes and components**: radii 0–40, border widths 0–8, elevations 0–24,
  sizes 0–96, thicknesses 0–16, insets `[left, top, right, bottom]` 0–64.
  Prefer role names over hex in components so both modes follow their palette.
- **Buttons**: `button` is the primary (filled/elevated) button only. Give text
  and icon buttons their own `textButton`/`iconButton` tables if they need a
  look; don't expect `button` to reach them.
- **Search fields**: style them with `search`, not `input` — `input` is for form
  fields, and the search pill's inner field ignores it.

### 5. Validate

```sh
python3 <skill>/scripts/validate.py path/to/my-theme
```

It runs the published JSON Schema (via `uvx`/`pipx` `check-jsonschema`; it
tells you if neither is installed) and then the rules only the installer
knows: icon color keys without an image, schema 2 features under `min = 1`,
schema 3 components or `[layout]` under `min < 3`,
file names, sizes, image dimensions, SVG content, stray files, and contrast.
Fix every error; read every warning and either fix it or tell the user why it
stays. Don't hand over a theme that has not passed.

### 6. Preview

On desktop (macOS, Windows, Linux): **Settings → Appearance → Install theme →
Folder**, pick the folder. It is validated and applied; select the folder
again after each edit. On a phone, pack it first and use **Install theme →
File**. Suggest the user look at the server list, a terminal tab, settings,
and a dialog in both modes, since those exercise surfaces, tiles, inputs and
dialogs.

### 7. Pack and share

```sh
python3 <skill>/scripts/pack.py path/to/my-theme --version 1.0.0 --url https://…/my-theme-1.0.0.fsbt
```

It writes the `.fsbt` (manifest at the archive root, dotfiles left out, same
files → same bytes) and prints its sha256, size and the `[[version]]` block a
theme repository listing needs. Ways to share, simplest first:

- **Send the file**: others use Install theme → File.
- **A link**: Install theme → URL takes an HTTPS `.fsbt` link.
- **The theme store**: the author's own GitHub repository is the theme
  repository; see "Publishing in your own repository" below.
- **Official themes** are maintained in flutter_server_box `store/themes/` and
  published by maintainers with `scripts/publish-themes.py` (this skill's
  `publish.py` with `store/` as the repository); propose one with a pull
  request adding `store/themes/<id>/` (the folder) and `store/themes/<id>.toml`
  (the listing, without versions). Only official themes are released from
  flutter_server_box.

## Publishing in your own repository

A third-party theme lives and is released in its author's repository; the
store only needs that repository's address. `scripts/publish.py` does the
releasing, the same tool the official themes use:

```sh
# once, in a new GitHub repository (git remote origin set):
python3 <skill>/scripts/publish.py --init --name "Somebody's themes"
# then per theme: themes/<id>/ (the folder) and themes/<id>.toml:
#   id = "<id>"   name = "..."   description = "..."   license = "MIT"
python3 <skill>/scripts/publish.py --dry-run   # what changed, and the versions it would get
python3 <skill>/scripts/publish.py             # upload, then append [[version]]s
git add themes && git commit -m "themes: release" && git push
```

- It packs every theme deterministically and compares the package with the
  newest version its listing records: unchanged themes are skipped, changed
  ones get the next patch version (`--bump minor|major`, or `<id>=<version>`).
- All new packages go into one release of the repository, tag `themes`,
  created as a pre-release with `--latest=false`, so it never becomes the
  repository's Latest; the script checks that before uploading.
- It never replaces an uploaded package and never gives one version number two
  sets of bytes; the store refuses a package whose sha256 differs from the
  listing's, so the recorded digest is always of the exact bytes served.
- Push the listings: the store reads the default branch
  (`<repo>/archive/HEAD.tar.gz`). Then open a pull request adding
  `[[repo]] url = "https://github.com/<you>/<repo>"` to
  `assets/catalog/repos.toml` in flutter_server_box.

Validate every theme (step 5) before publishing: the script checks ids, the
schema range and size, not the contents.

## When an install fails

The app's message names the rule. Common ones: an unknown table/field (typo, or
a field from a newer schema), an icon path that is not
`icons/<key_with_underscores>.<png|svg>`, `icons.colors` for an icon with no
image, a schema range that does not overlap the app's (the app currently reads
v1–v3), a file in the folder the installer has no name for, or SVG content it
refuses. Run the validator on the folder; it reports all of these at once.

## Source of truth

The format is defined by the app's parser and mirrored in
`docs/schemas/fsbt-manifest.schema.json`; the user guide is
<https://serverbox.lollipopkit.com/docs/development/theme-authoring/>. A full
example with every field is `docs/examples/aurora/manifest.toml`. If this skill
and the schema disagree, the schema wins — tell the user and follow it.
