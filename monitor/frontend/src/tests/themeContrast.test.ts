import { describe, it, expect } from 'vitest'
import css from '@serverbox/webui/theme.css?raw'
/// The `--sb-*` values of one block of theme.css.
function tokens(block: string): Record<string, string> {
  return Object.fromEntries([...block.matchAll(/--sb-([\w-]+):\s*(#[0-9a-f]{6})/gi)].map((m) => [m[1], m[2]]))
}

function luminance(hex: string): number {
  const [r, g, b] = [1, 3, 5].map((i) => {
    const c = parseInt(hex.slice(i, i + 2), 16) / 255
    return c <= 0.03928 ? c / 12.92 : ((c + 0.055) / 1.055) ** 2.4
  })
  return 0.2126 * r + 0.7152 * g + 0.0722 * b
}

function contrast(a: string, b: string): number {
  const [hi, lo] = [luminance(a), luminance(b)].sort((x, y) => y - x)
  return (hi + 0.05) / (lo + 0.05)
}

const light = tokens(css.slice(css.indexOf(':root {'), css.indexOf('\n.dark {')))
const dark = tokens(css.slice(css.indexOf('\n.dark {'), css.indexOf('@media')))
const darkMedia = tokens(css.slice(css.indexOf('@media'), css.indexOf('@theme')))

describe.each([
  ['light', light],
  ['dark', dark],
])('theme text tiers (%s)', (_, t) => {
  it('meet 4.5:1 on the surface and the page', () => {
    for (const tier of ['stone', 'silver', 'success', 'warning', 'danger']) {
      expect(contrast(t[tier], t.white), tier).toBeGreaterThanOrEqual(4.5)
      expect(contrast(t[tier], t.snow), tier).toBeGreaterThanOrEqual(4.5)
    }
  })

  it('step down from the text: fg, then muted, then faint', () => {
    expect(contrast(t['near-black'], t.white)).toBeGreaterThan(contrast(t.stone, t.white))
    expect(contrast(t.stone, t.white)).toBeGreaterThan(contrast(t.silver, t.white))
    // A placeholder that reads as a value is no placeholder
    expect(contrast(t.silver, t['near-black'])).toBeGreaterThanOrEqual(2)
  })
})

describe('theme dark blocks', () => {
  it('agree between .dark and prefers-color-scheme', () => {
    expect(darkMedia).toEqual(dark)
  })
})
