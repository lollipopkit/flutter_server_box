import { describe, it, expect, vi } from 'vitest'
import { render, screen, fireEvent } from '@testing-library/svelte'
import '@testing-library/jest-dom/vitest'
import type { InstalledTheme, PackageTheme } from '../desk/deskApi'
import type { DeskThemes } from '../desk/themes.svelte'
import { css, themeDark, themeOf, themeValue, themeVars, themeWallpaper } from '../desk/themeStyle'
import ThemesGroup from '../desk/apps/settings/ThemesGroup.svelte'

const role = (base: number) => (name: string) => base + name.length
function theme(over: Partial<PackageTheme> = {}): PackageTheme {
  const light: Record<string, number> = {}
  const dark: Record<string, number> = {}
  for (const r of ['primary', 'onPrimary', 'primaryContainer', 'onPrimaryContainer', 'error', 'errorContainer', 'surface', 'surfaceDim', 'surfaceBright', 'surfaceContainerLowest', 'surfaceContainerLow', 'surfaceContainer', 'surfaceContainerHigh', 'surfaceContainerHighest', 'onSurface', 'onSurfaceVariant', 'outline', 'outlineVariant']) {
    light[r] = (0xff000000 | role(0x100000)(r)) >>> 0
    dark[r] = (0xff000000 | role(0x200000)(r)) >>> 0
  }
  light.primary = 0xff6750a4
  return {
    variant: null,
    modes: ['light', 'dark'],
    mode: 0,
    seed: 0xff6750a4,
    schemeLight: light,
    schemeDark: dark,
    accentTones: { 40: 0xff6750a4, 90: 0xffeaddff },
    neutralTones: { 10: 0xff1d1b20 },
    background: { style: 'none', opacity: 1, blur: 0, tile: 0 },
    shapes: { card: 12, tile: 8, button: 20 },
    components: {},
    density: null,
    ...over,
  }
}

function pkg(id: string, themes: PackageTheme[], name = id): InstalledTheme {
  const p = { installationId: id, id: `com.example.${id}`, name, schemaMin: 1, schemaMax: 3, themes }
  return { installationId: id, id: p.id, name, installedAt: '', package: p }
}

describe('themeStyle', () => {
  it('writes colors as hex, or rgba when translucent', () => {
    expect(css(0xff6750a4)).toBe('#6750a4')
    expect(css(0x806750a4)).toBe('rgba(103, 80, 164, 0.502)')
  })

  it('maps palettes, roles by brightness and shapes onto the tokens', () => {
    const t = theme()
    const light = themeVars(t, false)
    expect(light['--berry-40']).toBe('#6750a4')
    expect(light['--ink-10']).toBe('#1d1b20')
    expect(light['--color-accent']).toBe('#6750a4')
    expect(light['--surface-window']).toBe(css(t.schemeLight.surface))
    expect(light['--shape-card']).toBe('12px')
    expect(light['--shape-tile']).toBe('8px')
    expect(light['--shape-button']).toBe('20px')
    // The design system's radius scale is shared by every control.
    expect(Object.keys(light).some((k) => k.startsWith('--radius-'))).toBe(false)
    const dark = themeVars(t, true)
    expect(dark['--surface-window']).toBe(css(t.schemeDark.surfaceContainerLow))
    expect(dark['--icon-soft-bg']).toBe(css(t.schemeDark.primaryContainer))
    expect(light['--icon-soft-bg']).toBeUndefined()
  })

  it('holds a theme with one mode at it', () => {
    expect(themeDark(theme({ modes: ['dark'] }), false)).toBe(true)
    expect(themeDark(theme({ modes: ['light'] }), true)).toBe(false)
    expect(themeDark(theme(), true)).toBe(true)
  })

  it('draws a background only when the theme has one, and its image once loaded', () => {
    expect(themeWallpaper(theme(), false, null)).toBeNull()
    expect(themeWallpaper(theme({ background: { style: 'gradient', opacity: 1, blur: 0, tile: 0 } }), false, null)?.image).toBeNull()
    const image = theme({ background: { style: 'image', opacity: 0.4, blur: 3, tile: 64 } })
    expect(themeWallpaper(image, false, null)).toEqual({ ground: css(image.schemeLight.surface), image: null })
    expect(themeWallpaper(image, true, 'blob:x')?.image).toEqual({ url: 'blob:x', opacity: 0.4, blur: 3, tile: 64 })
  })

  it('names a theme by installation and variant, falling back to the first variant', () => {
    const trans = theme({ variant: { key: 'trans', name: 'Trans' } })
    const rainbow = theme({ variant: { key: 'rainbow', name: 'Rainbow' } })
    const packages = [pkg('a', [theme()]), pkg('b', [rainbow, trans])]
    expect(themeValue('b', trans)).toBe('b#trans')
    expect(themeValue('a', packages[0].package.themes[0])).toBe('a')
    expect(themeOf(packages, 'b#trans')?.theme).toBe(trans)
    expect(themeOf(packages, 'b#gone')?.theme).toBe(rainbow)
    expect(themeOf(packages, 'a')?.pkg.installationId).toBe('a')
    expect(themeOf(packages, 'c')).toBeNull()
    expect(themeOf(packages, null)).toBeNull()
  })
})

describe('ThemesGroup', () => {
  function fake(installed: InstalledTheme[]) {
    return { installed, select: vi.fn(), remove: vi.fn(async () => {}), install: vi.fn() } as unknown as DeskThemes & {
      select: ReturnType<typeof vi.fn>
      remove: ReturnType<typeof vi.fn>
    }
  }

  it('lists a row per variant, marks the selection and selects one', async () => {
    const trans = theme({ variant: { key: 'trans', name: 'Trans' }, modes: ['dark'] })
    const themes = fake([pkg('p', [theme({ variant: { key: 'rainbow', name: 'Rainbow' } }), trans], 'Pride')])
    render(ThemesGroup, { themes, selected: 'p#rainbow', onstore: vi.fn() })
    expect(screen.getByRole('radio', { name: 'Pride · Rainbow' })).toBeChecked()
    expect(screen.getByText('Dark only')).toBeInTheDocument()
    await fireEvent.click(screen.getByRole('radio', { name: 'Pride · Trans' }))
    expect(themes.select).toHaveBeenCalledWith('p', trans)
    await fireEvent.click(screen.getByRole('radio', { name: 'Default' }))
    expect(themes.select).toHaveBeenCalledWith(null, null)
  })

  it('removes a package once, from its first row, and opens the store', async () => {
    const themes = fake([pkg('p', [theme({ variant: { key: 'a', name: 'A' } }), theme({ variant: { key: 'b', name: 'B' } })], 'Pride')])
    const onstore = vi.fn()
    render(ThemesGroup, { themes, selected: null, onstore })
    const removes = screen.getAllByRole('button', { name: 'Remove Pride' })
    expect(removes).toHaveLength(1)
    await fireEvent.click(removes[0])
    expect(themes.remove).toHaveBeenCalledWith('p')
    await fireEvent.click(screen.getByRole('button', { name: /Theme store/ }))
    expect(onstore).toHaveBeenCalled()
  })
})
