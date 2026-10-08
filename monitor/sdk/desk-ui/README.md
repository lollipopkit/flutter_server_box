# @lollipopkit/desk-ui

The lollipopkit Design System as the ServerBox desk draws it: tokens, the
`lk-*` component styles, and Svelte 5 components on top of them. The panel
uses it, and so can an installed desk app (`../template`). Apache-2.0
(`LICENSE`, `NOTICE`), so a closed-source app may use it; the fonts it depends on keep
their own licenses (Figtree and JetBrains Mono: OFL-1.1; Material Symbols:
Apache-2.0).

```ts
import '@lollipopkit/desk-ui/lk.css' // fonts, icons, tokens, base, components
import { applyTheme } from '@lollipopkit/desk-ui/theme'
import { Button, Card } from '@lollipopkit/desk-ui' // Svelte apps only

// The root carrying the `lk` class (`<body>` by default) is drawn the way
// the desk is: its mode, and the tokens of the theme the account installed.
applyTheme(desk.info.theme)
desk.on('theme', (theme) => applyTheme(theme))
```

- Everything is scoped to an element with the `lk` class; dark keys on
  `data-theme="dark"` on `<html>`, which `applyTheme` sets.
- Without Svelte, use the classes (`lk-btn lk-btn--primary`, `lk-card`, …,
  `src/components.css`) and the tokens (`var(--surface-card)`, …,
  `src/tokens.css`).
- Fonts are bundled, never fetched: the desk's frames have no network.
  `lk.css` is `fonts.css` (Figtree, JetBrains Mono: variable, woff2, about
  120 KB) + `icons.css` (Material Symbols Rounded, 3 MB) + `core.css`
  (tokens, base, components). An app that draws no icons imports `core.css`
  and `fonts.css` and stays near 130 KB (`../template`).
- The icon font keeps every glyph (icons are named at run time) with its
  axes narrowed to what `Icon` draws; `npm run icons` (uv + fonttools)
  rebuilds it from the `material-symbols` devDependency.
- Values are the design system's; a theme overrides tokens, never the
  `--radius-*` scale (its shapes reach `--shape-card`, `--shape-tile`,
  `--shape-button`).
