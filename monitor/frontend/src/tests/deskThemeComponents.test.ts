import { describe, it, expect } from 'vitest'
import type { PackageTheme } from '../desk/deskApi'
import { themeVars } from '../desk/themeStyle'
import { drawn, drawnStates, stateFields, hook } from '../desk/themeComponents'
import components from '../desk/lk/components.css?raw'
import base from '../desk/lk/base.css?raw'
import tokens from '../desk/lk/tokens.css?raw'

const sheets = components + base

function theme(components: Record<string, unknown>, over: Partial<PackageTheme> = {}): PackageTheme {
  const scheme = (base: number) => ({ primary: base + 1, outline: base + 2, shadow: base + 3, surface: base + 4 })
  return {
    variant: null,
    modes: ['light', 'dark'],
    mode: 0,
    seed: 0xff6750a4,
    schemeLight: scheme(0xff100000),
    schemeDark: scheme(0xff200000),
    accentTones: {},
    neutralTones: {},
    background: { style: 'none', opacity: 1, blur: 0, tile: 0 },
    shapes: { card: 12, tile: 8, button: 20 },
    components,
    density: null,
    ...over,
  }
}

const hooksOf = (vars: Record<string, string>) => Object.keys(vars).filter((k) => k.startsWith('--lk-') && k !== '--lk-seed')

/// A table setting every field the desk draws, and every state.
function everything(): Record<string, unknown> {
  const sample = { color: 0xff123456, px: 4, insets: [1, 2, 3, 4], flag: false, elevation: 3, shadow: 0xff000000, border: 2, ring: 2 }
  const all: Record<string, unknown> = {}
  for (const [name, fields] of Object.entries(drawn)) {
    const table: Record<string, unknown> = Object.fromEntries(Object.entries(fields).map(([f, kind]) => [f, sample[kind]]))
    if (['button', 'textButton', 'outlinedButton', 'iconButton'].includes(name)) {
      for (const state of drawnStates) table[state] = Object.fromEntries(stateFields.map((f) => [f, 'primary']))
    }
    all[name] = table
  }
  return all
}

describe('theme components on the design system', () => {
  it('draws every hook it sets, and sets every hook the stylesheets read', () => {
    const set = new Set(hooksOf(themeVars(theme(everything()), false)))
    const read = new Set([...sheets.matchAll(/var\((--lk-[a-z-]+)/g)].map((m) => m[1]).filter((v) => v !== '--lk-seed'))
    expect([...set].filter((v) => !read.has(v))).toEqual([])
    expect([...read].filter((v) => !set.has(v))).toEqual([])
  })

  it('reads each hook with a fallback, so an unthemed desk is the design system', () => {
    const bare = [...sheets.matchAll(/var\(--lk-(?!seed)[a-z-]+\)/g)].map((m) => m[0])
    // Only the buttons' private properties take a hook bare: unset, it
    // leaves theirs unset, and they have the fallback.
    for (const v of bare) expect(sheets).toMatch(new RegExp(`--_btn-[a-z-]+:${v.replace(/[()]/g, '\\$&')}`))
  })

  it('writes values as the app reads them', () => {
    const vars = themeVars(
      theme({
        card: { radius: 20, backgroundColor: 'primary', borderColor: 0xff00ff00, elevation: 2 },
        input: { padding: [1, 2, 3, 4], filled: false, fillColor: 0xffffffff },
        segmented: { radius: 1 },
        button: { disabled: { backgroundColor: 0xff000000 } },
        missing: { radius: 3 },
      }),
      false,
    )
    expect(vars['--lk-card-radius']).toBe('20px')
    expect(vars['--lk-card-background-color']).toBe('#100001')
    // A color with no width is a 1px border.
    expect(vars['--lk-card-border']).toBe('1px solid #00ff00')
    expect(vars['--lk-card-border-offset']).toBe('-1px')
    expect(vars['--lk-card-shadow']).toBe('0 1px 3px color-mix(in srgb, #100003 28%, transparent)')
    // Insets are [left, top, right, bottom].
    expect(vars['--lk-input-padding']).toBe('2px 3px 4px 1px')
    expect(vars['--lk-input-fill-color']).toBe('transparent')
    expect(vars['--lk-segmented-thumb-radius']).toBe('0px')
    expect(vars['--lk-button-disabled-background-color']).toBe('#000000')
    expect(vars['--lk-button-disabled-opacity']).toBe('1')
    expect(Object.keys(vars).some((k) => k.startsWith('--lk-missing'))).toBe(false)
  })

  it('takes a brightness table over the common one, field by field', () => {
    const t = theme({
      card: { radius: 8, backgroundColor: 'primary' },
      button: { hovered: { backgroundColor: 0xff111111, foregroundColor: 0xff222222 } },
      dark: { card: { radius: 2 }, button: { hovered: { backgroundColor: 0xff333333 } } },
    })
    const light = themeVars(t, false)
    const dark = themeVars(t, true)
    expect(light[hook('card', 'radius')]).toBe('8px')
    expect(dark[hook('card', 'radius')]).toBe('2px')
    expect(dark[hook('card', 'backgroundColor')]).toBe('#200001')
    expect(dark[hook('button', 'hovered', 'backgroundColor')]).toBe('#333333')
    expect(dark[hook('button', 'hovered', 'foregroundColor')]).toBe('#222222')
  })

  it('loosens the sizes for a less compact density', () => {
    expect(themeVars(theme({}), false)['--control-height']).toBeUndefined()
    expect(themeVars(theme({}, { density: 'compact' }), false)['--control-height']).toBeUndefined()
    expect(themeVars(theme({}, { density: 'comfortable' }), false)['--control-height']).toBe('34px')
    expect(themeVars(theme({}, { density: 'standard' }), false)['--menu-item-height']).toBe('34px')
    // The base sizes are the design system's.
    expect(tokens).toContain('--control-height: 30px;')
    expect(tokens).toContain('--menu-item-height: 26px;')
  })
})
