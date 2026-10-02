// The app's built-in glyphs for the keys the preview draws, for a theme that
// carries no image of its own for one: what `ThemeIconAsset` falls back to
// (`lib/view/page/home_tab.dart` for the tabs, `theme_host.dart` for the rest),
// in both icon styles. A selected tab falls back to the built-in selected
// glyph, never to the theme's unselected image, as in the app.
//
// Google Material Icons (Apache-2.0), Boxicons (MIT) and MingCute (Apache-2.0),
// copied from their npm packages.
const files = import.meta.glob('./default-icons/*/*.svg', { query: '?url', import: 'default', eager: true })

const defaults = { classic: {}, mingcute: {} }
for (const [path, url] of Object.entries(files)) {
  const [, style, file] = path.match(/\.\/default-icons\/([^/]+)\/(.+)\.svg$/)
  defaults[style][file] = url
}

/** The built-in glyph for `key` in `style`, or null. */
export function defaultIcon(style, key) {
  return defaults[style]?.[key] ?? defaults.classic[key] ?? null
}
