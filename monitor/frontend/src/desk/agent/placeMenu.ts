/// Places a menu that opens past [anchor]'s top or bottom edge (the menu is
/// absolutely positioned in it): below when it fits in what clips it, else
/// above when it fits there, else on the roomier side, cut to fit. Sets
/// `top`/`bottom`, and `--menu-max` (the height it may take) and
/// `--menu-origin` (where it grows from) for the menu's own styles.
export function placeMenu(node: HTMLElement, anchor: HTMLElement | null | undefined) {
  if (!anchor) return
  const gap = 9
  const margin = 8
  const at = anchor.getBoundingClientRect()
  const clip = clipOf(anchor)
  const below = clip.bottom - at.bottom - gap - margin
  const above = at.top - clip.top - gap - margin
  const height = node.scrollHeight
  const down = height <= below || (height > above && below >= above)
  node.style.top = down ? `calc(100% + ${gap}px)` : 'auto'
  node.style.bottom = down ? 'auto' : `calc(100% + ${gap}px)`
  node.style.setProperty('--menu-max', `${Math.max(120, Math.floor(down ? below : above))}px`)
  node.style.setProperty('--menu-origin', down ? 'top left' : 'bottom left')
}

/// The box of the nearest ancestor that cuts off what overflows it, else the
/// viewport.
function clipOf(el: HTMLElement): { top: number; bottom: number } {
  for (let p = el.parentElement; p; p = p.parentElement) {
    if (/hidden|clip|auto|scroll/.test(getComputedStyle(p).overflowY)) return p.getBoundingClientRect()
  }
  return { top: 0, bottom: window.innerHeight }
}
