/// A textarea one line tall until its text needs more, up to [max] lines,
/// then it scrolls. The height is in `em`, so it follows a font size that is
/// moving (the composer growing on focus) instead of jumping after it; it is
/// measured again when the text or the width changes.

export interface AutosizeOptions {
  /// The text, so a change made from outside is measured too.
  value: string
  max?: number
  /// Told whether it is more than one line.
  onmulti?: (multi: boolean) => void
}

export function autosize(ta: HTMLTextAreaElement, options: AutosizeOptions) {
  let opts = options
  let multi = false
  let width = 0

  function fit() {
    const cs = getComputedStyle(ta)
    const fs = parseFloat(cs.fontSize)
    const lh = parseFloat(cs.lineHeight) || fs * 1.4
    const pad = parseFloat(cs.paddingTop) + parseFloat(cs.paddingBottom)
    const max = opts.max ?? 8
    // One line is the stylesheet's height.
    ta.style.height = ''
    ta.style.overflowY = 'hidden'
    let lines = 1
    if (ta.value) {
      const needed = Math.round((ta.scrollHeight - pad) / lh)
      lines = Math.min(max, Math.max(1, needed))
      if (lines > 1) ta.style.height = `calc(${((lines * lh) / fs).toFixed(4)}em + ${pad}px)`
      if (needed > max) ta.style.overflowY = 'auto'
    }
    if (lines > 1 !== multi) {
      multi = lines > 1
      opts.onmulti?.(multi)
    }
  }

  const ro = new ResizeObserver(([e]) => {
    const w = Math.round(e.contentRect.width)
    if (w === width) return
    width = w
    fit()
  })
  ro.observe(ta)
  ta.addEventListener('input', fit)
  fit()

  return {
    update(next: AutosizeOptions) {
      opts = next
      fit()
    },
    destroy() {
      ro.disconnect()
      ta.removeEventListener('input', fit)
    },
  }
}
