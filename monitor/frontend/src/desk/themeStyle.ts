/// An installed theme (`.fsbt`, read by the agent's `sbm_theme`) drawn with
/// the lollipopkit Design System's tokens (desk-ui's `tokens.css`): the theme's
/// accent and neutral palettes take the places of `--berry-*` and `--ink-*`,
/// so every token the design system derives from them follows in its own
/// proportions, and the tokens it writes as values (surfaces, text, lines,
/// glass) take the theme's scheme roles that play the same part. Shapes round
/// the cards, list rows and buttons; the background is a wallpaper
/// (`themeWallpaper`).
///
/// What a theme's `[components]` say is kept and not drawn yet (TODO).

import type { PackageTheme } from './deskApi'

export function css(argb: number): string {
  const a = ((argb >>> 24) & 0xff) / 255
  const r = (argb >>> 16) & 0xff
  const g = (argb >>> 8) & 0xff
  const b = argb & 0xff
  return a >= 1 ? `#${[r, g, b].map((v) => v.toString(16).padStart(2, '0')).join('')}` : `rgba(${r}, ${g}, ${b}, ${+a.toFixed(3)})`
}

function alpha(argb: number, a: number): string {
  return `color-mix(in srgb, ${css(argb | 0xff000000)} ${Math.round(a * 100)}%, transparent)`
}

/// The brightness a theme is drawn in: its one mode when it declares one,
/// or the desk's.
export function themeDark(theme: PackageTheme, dark: boolean): boolean {
  return theme.modes.length === 1 ? theme.modes[0] === 'dark' : dark
}

/// The custom properties that draw [theme] in [dark] or light, to set on the
/// desk's root.
export function themeVars(theme: PackageTheme, dark: boolean): Record<string, string> {
  const s = dark ? theme.schemeDark : theme.schemeLight
  const vars: Record<string, string> = {}
  for (const [tone, argb] of Object.entries(theme.accentTones)) vars[`--berry-${tone}`] = css(argb)
  for (const [tone, argb] of Object.entries(theme.neutralTones)) vars[`--ink-${tone}`] = css(argb)
  vars['--lk-seed'] = css(theme.schemeLight.primary)

  const set = (name: string, role: string) => (vars[name] = css(s[role]))
  set('--color-accent', 'primary')
  vars['--color-accent-hover'] = `color-mix(in oklab, ${css(s.primary)} 88%, ${css(s.onPrimary)})`
  vars['--color-accent-press'] = `color-mix(in oklab, ${css(s.primary)} 85%, ${dark ? css(s.onPrimary) : '#000'})`
  set('--color-accent-text', 'primary')
  set('--color-accent-soft', 'primaryContainer')
  set('--color-on-accent-soft', 'onPrimaryContainer')
  set('--text-on-accent', 'onPrimary')
  set('--color-danger', 'error')
  set('--color-danger-soft', 'errorContainer')
  set('--text-on-danger', 'onError')

  // The surface each of the design system's surfaces is, by tone.
  const surfaces: Record<string, [string, string]> = {
    '--surface-desktop': ['surfaceContainer', 'surfaceDim'],
    '--surface-window': ['surface', 'surfaceContainerLow'],
    '--surface-content': ['surfaceContainerLowest', 'surface'],
    '--surface-card': ['surfaceContainerLow', 'surfaceContainer'],
    '--surface-raised': ['surfaceContainerLowest', 'surfaceContainerHighest'],
    '--surface-raised-hover': ['surfaceBright', 'surfaceBright'],
    '--surface-control': ['surfaceContainer', 'surfaceContainerHigh'],
    '--surface-field': ['surfaceContainerLowest', 'surfaceContainer'],
    '--surface-selected': ['primaryContainer', 'primaryContainer'],
    '--surface-terminal': ['surfaceContainerLowest', 'surfaceContainerLowest'],
  }
  for (const [name, [light, darkRole]] of Object.entries(surfaces)) set(name, dark ? darkRole : light)

  set('--text-primary', 'onSurface')
  set('--text-secondary', 'onSurfaceVariant')
  set('--text-tertiary', 'outline')
  set('--text-disabled', 'outlineVariant')
  // Lines and fills are the text color, faint, as the design system draws
  // them from its own ink.
  const ink = s.onSurface
  vars['--border-hairline'] = alpha(ink, dark ? 0.07 : 0.09)
  vars['--border-strong'] = alpha(ink, dark ? 0.14 : 0.17)
  vars['--fill-hover'] = alpha(ink, dark ? 0.07 : 0.06)
  vars['--fill-press'] = alpha(ink, dark ? 0.12 : 0.11)

  const glass: Record<string, [string, number, string, number]> = {
    '--glass-bar': ['surface', 0.6, 'surfaceContainerLow', 0.55],
    '--glass-dock': ['surface', 0.42, 'surfaceContainerHigh', 0.45],
    '--glass-menu': ['surface', 0.8, 'surfaceContainer', 0.8],
    '--glass-panel': ['surfaceContainerLow', 0.74, 'surfaceContainer', 0.74],
    '--glass-sidebar': ['surfaceContainer', 0.82, 'surfaceContainer', 0.8],
  }
  for (const [name, [light, la, darkRole, da]] of Object.entries(glass)) {
    vars[name] = dark ? alpha(s[darkRole], da) : alpha(s[light], la)
  }

  // Shadows and the scrim are tinted with the seed in the design system; here
  // with the theme's accent at the same tones.
  const tone = (t: number) => theme.accentTones[t] ?? s.shadow ?? 0xff000000
  vars['--shadow-ink'] = css(tone(20) | 0xff000000)
  vars['--shadow-ink-deep'] = css(tone(10) | 0xff000000)
  if (!dark) vars['--scrim'] = alpha(tone(10), 0.28)

  // The icon tones the design system writes as values in the dark.
  if (dark) {
    set('--icon-soft-bg', 'primaryContainer')
    vars['--icon-pale-bg'] = `color-mix(in oklab, ${css(s.primaryContainer)} 60%, ${css(s.surface)})`
  }

  // Its two wallpapers, drawn from the theme's palettes by the same recipe.
  vars['--wallpaper-berry'] = [
    'radial-gradient(120% 90% at 15% 10%, var(--berry-90) 0%, transparent 55%)',
    'radial-gradient(90% 80% at 90% 20%, color-mix(in oklab, var(--berry-90), var(--berry-80)) 0%, transparent 60%)',
    'radial-gradient(110% 90% at 60% 110%, var(--berry-50) 0%, transparent 60%)',
    'linear-gradient(160deg, var(--berry-95) 0%, var(--berry-80) 55%, var(--berry-40) 120%)',
  ].join(', ')
  vars['--wallpaper-dusk'] = [
    'radial-gradient(120% 90% at 20% 0%, var(--berry-30) 0%, transparent 55%)',
    'radial-gradient(90% 90% at 100% 100%, var(--berry-35) 0%, transparent 60%)',
    'linear-gradient(160deg, var(--ink-12) 0%, var(--berry-10) 100%)',
  ].join(', ')

  // Shapes name components (the app's cards, list tiles and buttons), so they
  // reach those components (`--shape-*` in desk-ui's `components.css`) and never the
  // design system's radius scale, which segmented thumbs, fields, menus and
  // windows share: a theme with square list rows keeps round controls. A
  // list tile is a row of a list (`DataTable`); sidebar items, menu items and
  // Spotlight results are navigation and menus, as they are in the app.
  vars['--shape-card'] = `${theme.shapes.card}px`
  vars['--shape-tile'] = `${theme.shapes.tile}px`
  vars['--shape-button'] = `${theme.shapes.button}px`
  return vars
}

/// How a theme's background is drawn as the desk's wallpaper, as the app
/// draws it behind its pages: a gradient between its surface and primary, or
/// its image, faint (`opacity`), blurred, and repeated at `tile` pixels or
/// cover-fitted, over its surface.
export interface ThemeWallpaper {
  ground: string
  /// An image layer, when the theme has one.
  image: { url: string; opacity: number; blur: number; tile: number } | null
}

export function themeWallpaper(theme: PackageTheme, dark: boolean, url: string | null): ThemeWallpaper | null {
  const s = dark ? theme.schemeDark : theme.schemeLight
  const surface = css(s.surface)
  const primary = css(s.primary)
  switch (theme.background.style) {
    case 'gradient':
      return {
        ground: `linear-gradient(to bottom right, color-mix(in srgb, ${surface}, ${primary} 22%), ${surface}, color-mix(in srgb, ${surface}, ${primary} 12%))`,
        image: null,
      }
    case 'image':
      return {
        ground: surface,
        image: url ? { url, opacity: theme.background.opacity, blur: theme.background.blur, tile: theme.background.tile } : null,
      }
    default:
      return null
  }
}

/// The theme a preferences value names in [packages]: `<installation>` or
/// `<installation>#<variant>`; a package with variants answers its first
/// when the value names none it has.
export function themeOf<P extends { installationId: string; package: { themes: PackageTheme[] } }>(
  packages: P[],
  value: string | null | undefined,
): { pkg: P; theme: PackageTheme } | null {
  if (!value) return null
  const [id, variant] = value.split('#')
  const pkg = packages.find((p) => p.installationId === id)
  if (!pkg) return null
  const theme = pkg.package.themes.find((t) => t.variant?.key === variant) ?? pkg.package.themes[0]
  return theme ? { pkg, theme } : null
}

/// The preferences value selecting [theme] of [installationId].
export function themeValue(installationId: string, theme: PackageTheme): string {
  return theme.variant ? `${installationId}#${theme.variant.key}` : installationId
}
