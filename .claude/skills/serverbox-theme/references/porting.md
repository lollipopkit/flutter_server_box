# Porting an existing color scheme

The goal is that someone who uses the source scheme recognises the app at a
glance: same background, same accent, same text color. Material's generated
palette will not do that — `seed` alone gives Material's reading of one color —
so a port writes the palette roles explicitly. The official store port
`store/themes/serverbox.one-dark-pro` is a worked example of the level of
detail that is enough: about 35 roles per brightness, the rest generated from
`seed` (set `seed` to the source's accent).

## Role map

| Role | Take from the source | VS Code theme key(s) |
|---|---|---|
| `surface`, `surfaceDim` | the main background (editor) | `editor.background` |
| `surfaceContainerLowest` | the darkest (dark) / lightest (light) panel | `sideBar.background`, `activityBar.background` |
| `surfaceContainerLow`, `surfaceContainer` | panels, sidebars, cards | `sideBar.background`, `editorWidget.background` |
| `surfaceContainerHigh` | raised panels, menus, hovered rows | `menu.background`, `list.hoverBackground` (opaque) |
| `surfaceContainerHighest` | inputs, the most raised surface | `input.background`, `dropdown.background` |
| `surfaceBright` | a clearly lighter (dark) / whiter (light) surface | lift of `surface` |
| `onSurface` | main text | `editor.foreground`, `foreground` |
| `onSurfaceVariant` | secondary text, icons | `descriptionForeground`, comment color |
| `outline` | visible borders | `focusBorder` muted, `input.border` |
| `outlineVariant` | dividers | `panel.border`, `editorGroup.border`, `sideBar.border` |
| `primary` | the accent | `focusBorder`, `button.background`, `textLink.foreground` |
| `onPrimary` | text on the accent | `button.foreground` |
| `primaryContainer` | a soft fill of the accent | `list.activeSelectionBackground`, `editor.selectionBackground` (opaque) |
| `onPrimaryContainer` | text on that fill | `list.activeSelectionForeground` or `onSurface` |
| `secondary` | a second accent (keywords, links) | syntax keyword color, `badge.background` |
| `secondaryContainer` | selected tile / nav indicator fill | `list.inactiveSelectionBackground` |
| `tertiary` | a third accent | strings or numbers color |
| `error`, `onError` | the error red and text on it | `errorForeground`, `editorError.foreground` |
| `surfaceTint` | `0x00000000` | — |

Terminal / base16 schemes: `surface` = background (base00), containers =
base01/base02 steps, `onSurface` = foreground (base05), `onSurfaceVariant` =
comment (base03/base04, lightened for contrast), `primary` = blue (base0D),
`secondary` = magenta (base0E), `tertiary` = green or cyan (base0B/base0C),
`error` = red (base08), `outlineVariant` = base01/base02, `outline` = base03.

`scripts/port_vscode.py theme.json [--mode dark|light]` reads a VS Code color
theme (JSON with comments allowed) and prints a draft `[colors.palette.*]`
block following this table, then the contrast of each text pair. Treat it as a
draft: check the surface ladder and the containers by eye.

## Rules that keep a port working

- **The surface ladder must be monotonic.** In dark mode
  `surfaceContainerLowest` ≤ `surface` ≤ `Low` ≤ `(container)` ≤ `High` ≤
  `Highest` in lightness; reversed in light mode. The app draws cards, tiles,
  dialogs and inputs on different steps, so a step out of order makes one of
  them look wrong. When the source has fewer shades than steps, mix: move 3–5 %
  lightness per step toward white (dark) or black (light), keeping the hue.
- **Translucent source colors** (VS Code selection and hover colors are often
  `#RRGGBBAA`) must be flattened onto the background they sit on before they
  become a role — the palette takes opaque values for anything text sits on.
  Blend: `c = a·fg + (1 − a)·bg` per channel.
- **Contrast**: 4.5:1 for every text pair (`onX` on `X`, `onSurface` and
  `onSurfaceVariant` on the surfaces), 3:1 for `outline` on `surface`. Source
  themes frequently miss this for comments and descriptions; adjust lightness
  only, and mention the change to the user.
- **Containers are fills, not accents**: `primaryContainer` sits behind text,
  so it is a dark (dark mode) or pale (light mode) version of the accent, with
  `onPrimaryContainer` near `onSurface`.
- **One-mode sources**: port the mode the source has and declare only that
  mode, unless the user asks for both. If they do, and the source family has
  a sibling (One Dark / One Light, GitHub Dark / Light, Catppuccin
  Latte/Mocha), port the sibling; otherwise derive the light palette by keeping
  hues, inverting the surface ladder, and re-checking contrast — and say it is
  derived.
- **Attribution and license**: a port of someone else's theme should name the
  source and its license in the listing's `description`/`license` and, for a
  theme meant for the official store, in the pull request. Colors themselves
  are not usually protected, but the name often is a project's identity: call
  it "Nord-inspired" rather than "Nord" if the user is not the author and the
  project has asked for that.

## Checking the result

Run `scripts/validate.py`; it prints every text pair's contrast. Then preview
in the app (Install theme → Folder) and look at: the server list (cards), a
settings page (tiles, switches), a dialog, a text field, the bottom navigation
or the desktop rail, and a selected item. Those use every role above.
