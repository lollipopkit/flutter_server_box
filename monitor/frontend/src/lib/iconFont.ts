/// The whole icon font, added after the panel is up: the stylesheet starts
/// with the glyphs the panel's own source names (`desk/lk/icons-core.css`),
/// and an icon named at run time (a catalog app's glyph, an installed app's)
/// needs the rest. The face added last under a family wins, so once it has
/// loaded every icon draws from it.

import full from '../desk/lk/fonts/material-symbols-rounded.woff2?url'

export function loadFullIconFont(): void {
  if (typeof FontFace === 'undefined' || !document.fonts) return
  const load = () => {
    const face = new FontFace('Material Symbols Rounded', `url(${full}) format('woff2')`, { style: 'normal', weight: '300 700', display: 'block' })
    face
      .load()
      .then((loaded) => document.fonts.add(loaded))
      .catch(() => {
        // The core glyphs stay; a run-time icon shows its name.
      })
  }
  if ('requestIdleCallback' in window) window.requestIdleCallback(load, { timeout: 3000 })
  else setTimeout(load, 1000)
}
