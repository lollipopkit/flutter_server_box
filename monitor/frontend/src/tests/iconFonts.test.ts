import { describe, it, expect } from 'vitest'
import all from '../desk/lk/fonts/all-icons.txt?raw'
import core from '../desk/lk/fonts/core-icons.txt?raw'

// What `scripts/icons.py` reads to choose the core glyphs.
const sources = import.meta.glob(['../**/*.svelte', '../**/*.ts', '!../tests/**', '!../i18n/**'], {
  query: '?raw',
  import: 'default',
  eager: true,
}) as Record<string, string>

describe('the icon font the panel starts with', () => {
  it('has every glyph the source names', () => {
    const glyphs = new Set(all.split('\n').filter(Boolean))
    const kept = new Set(core.split('\n').filter(Boolean))
    const named = new Set<string>()
    for (const text of Object.values(sources)) {
      for (const m of text.matchAll(/['"`]([a-z][a-z0-9_]{1,63})['"`]/g)) if (glyphs.has(m[1])) named.add(m[1])
    }
    const missing = [...named].filter((n) => !kept.has(n))
    // Named in the source but not in the core font: run `uv run scripts/icons.py`.
    expect(missing).toEqual([])
    expect(named.size).toBeGreaterThan(100)
  })
})
