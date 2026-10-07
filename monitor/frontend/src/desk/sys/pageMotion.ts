/// How a page inside an app arrives and leaves (`PageStack`), after fl_lib's
/// pane slide: the page going in slides in from the end edge over the one
/// below, which moves a third of the way out; going back is the same motion
/// run backwards in time, so the page leaving starts slowly and falls away
/// fast. One curve, Flutter's `Curves.fastEaseInToSlowEaseOut`, 300 ms.

export const PAGE_MS = 300
/// The faded stand-in when motion is reduced.
export const PAGE_FADE_MS = 150

/// A swipe let go past this part of the width goes through; short of it the
/// page returns (fl_lib's `SwipeBackPageTransitionsBuilder`).
export const COMMIT_FRACTION = 0.35
/// A fling faster than this (px/s) decides by its direction alone.
export const FLING_VELOCITY = 700

export function cubic(x1: number, y1: number, x2: number, y2: number): (t: number) => number {
  const at = (a: number, b: number, m: number) => 3 * a * (1 - m) * (1 - m) * m + 3 * b * (1 - m) * m * m + m * m * m
  return (t) => {
    let lo = 0
    let hi = 1
    for (let i = 0; i < 30; i++) {
      const mid = (lo + hi) / 2
      if (at(x1, x2, mid) < t) lo = mid
      else hi = mid
    }
    return at(y1, y2, (lo + hi) / 2)
  }
}

/// Flutter's `ThreePointCubic`: two cubics joined at [mid].
function threePointCubic(
  a1: [number, number],
  b1: [number, number],
  mid: [number, number],
  a2: [number, number],
  b2: [number, number],
): (t: number) => number {
  const first = cubic(a1[0] / mid[0], a1[1] / mid[1], b1[0] / mid[0], b1[1] / mid[1])
  const sx = 1 - mid[0]
  const sy = 1 - mid[1]
  const second = cubic((a2[0] - mid[0]) / sx, (a2[1] - mid[1]) / sy, (b2[0] - mid[0]) / sx, (b2[1] - mid[1]) / sy)
  return (t) => {
    if (t <= 0) return 0
    if (t >= 1) return 1
    return t < mid[0] ? first(t / mid[0]) * mid[1] : second((t - mid[0]) / sx) * sy + mid[1]
  }
}

/// For a page let go mid-swipe: on from where the finger left it.
export const releaseCurve = cubic(0.2, 0.8, 0.2, 1)

export const pageCurve = threePointCubic([0.056, 0.024], [0.108, 0.3085], [0.198, 0.541], [0.3655, 1.0], [0.5465, 0.989])

/// [curve] as a CSS `linear()` easing, for the Web Animations API.
export function cssEasing(curve: (t: number) => number, steps = 40): string {
  const points: string[] = []
  for (let i = 0; i <= steps; i++) points.push(curve(i / steps).toFixed(4))
  return `linear(${points.join(', ')})`
}

/// Where the two pages are at [a] (0 at rest on the lower page, 1 at rest on
/// the upper one), as fractions of the width.
export function slide(a: number): { upper: number; lower: number } {
  return { upper: 1 - a, lower: -a / 3 }
}

/// Whether what is under the pointer takes a horizontal drag of [dx] itself,
/// so the page must not move: a field, a terminal, a canvas, something that
/// handles its own pointer (`touch-action: none`), a box that can still
/// scroll that way, or — for a mouse — text, which a drag selects.
export function contentTakes(
  target: Element | null,
  stop: Element,
  dx: number,
  point: { x: number; y: number } | null,
): boolean {
  for (let el = target; el && el !== stop; el = el.parentElement) {
    if (!(el instanceof HTMLElement)) continue
    if (/^(INPUT|TEXTAREA|SELECT|VIDEO|CANVAS|IFRAME)$/.test(el.tagName)) return true
    if (el.isContentEditable || el.getAttribute('draggable') === 'true') return true
    if (el.hasAttribute('data-no-page-swipe') || el.classList.contains('xterm')) return true
    const role = el.getAttribute('role')
    if (role === 'slider' || role === 'separator') return true
    const style = getComputedStyle(el)
    if (style.touchAction === 'none') return true
    if ((style.overflowX === 'auto' || style.overflowX === 'scroll') && el.scrollWidth > el.clientWidth + 1) {
      if (dx > 0 && el.scrollLeft > 0) return true
      if (dx < 0 && el.scrollLeft + el.clientWidth < el.scrollWidth - 1) return true
    }
  }
  return point !== null && overText(target, point)
}

/// Whether [point] is on the glyphs of selectable text under [target].
function overText(target: Element | null, point: { x: number; y: number }): boolean {
  const doc = target?.ownerDocument
  if (!doc) return false
  let node: Node | null = null
  if ('caretPositionFromPoint' in doc && typeof doc.caretPositionFromPoint === 'function') {
    node = doc.caretPositionFromPoint(point.x, point.y)?.offsetNode ?? null
  } else if ('caretRangeFromPoint' in doc && typeof doc.caretRangeFromPoint === 'function') {
    node = doc.caretRangeFromPoint(point.x, point.y)?.startContainer ?? null
  }
  if (!node || node.nodeType !== Node.TEXT_NODE || !node.textContent?.trim()) return false
  const host = node.parentElement
  if (!host || getComputedStyle(host).userSelect === 'none') return false
  const range = doc.createRange()
  range.selectNodeContents(node)
  for (const r of range.getClientRects()) {
    if (point.x >= r.left && point.x <= r.right && point.y >= r.top && point.y <= r.bottom) return true
  }
  return false
}

/// Whether a released swipe goes through: far enough, or flung that way.
export function commits(progress: number, velocity: number, sign: 1 | -1): boolean {
  if (Math.abs(velocity) >= FLING_VELOCITY) return Math.sign(velocity) === sign
  return progress >= COMMIT_FRACTION
}

export function reducedMotion(node: Element): boolean {
  return node.closest('[data-reduce-motion]') !== null || !!window.matchMedia?.('(prefers-reduced-motion: reduce)').matches
}
