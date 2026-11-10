import { describe, it, expect } from 'vitest'

/// The production build's CSS minifier keeps only the last of
/// `backdrop-filter` and `-webkit-backdrop-filter` in a block. Written
/// standard-first, the standard one went, and Chrome (which ignores the
/// prefixed property) drew every glass surface without its blur. So the
/// prefixed declaration always comes first.
const sources = import.meta.glob<string>(['../**/*.css', '../**/*.svelte'], { query: '?raw', import: 'default', eager: true })

describe('glass declarations', () => {
  it('put -webkit-backdrop-filter before backdrop-filter', () => {
    expect(Object.keys(sources).length).toBeGreaterThan(50)
    const offenders: string[] = []
    for (const [path, text] of Object.entries(sources)) {
      for (const block of text.split(/[{}]/)) {
        const standard = block.search(/(^|[^-])backdrop-filter\s*:/)
        const prefixed = block.search(/-webkit-backdrop-filter\s*:/)
        if (standard >= 0 && prefixed >= 0 && prefixed > standard) offenders.push(path)
      }
    }
    expect(offenders).toEqual([])
  })
})
