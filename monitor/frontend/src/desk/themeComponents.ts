/// A theme's `[components]` (and `[layout] density`) on the lollipopkit
/// Design System's components: each field the desk draws becomes a custom
/// property, `--lk-<component>-<field>` in kebab case (`--lk-text-button-
/// hovered-background-color`), which `lk/components.css` and `lk/base.css`
/// read with the design system's own value as the fallback. Set on the
/// desk's root with the rest of the theme, so an installed app's frame gets
/// them too.
///
/// What a component table holds (`fl_theme::components`): fields that are a
/// color (ARGB or a scheme role), a number (radius, border width, elevation,
/// size, thickness), insets (`[left, top, right, bottom]`) or a flag; the
/// buttons also take state tables; a `light` or `dark` table overrides the
/// rest in that brightness, field by field, as the app merges them.
///
/// Not drawn, as the desk has no counterpart:
/// - `tile`, `chip`, `sheet`: the desk's rows are the design system's rounded
///   selection; it has no chips and no bottom sheets.
/// - `surfaceTintColor`, buttons' `overlayColor`, slider `overlayColor`: the
///   design system draws its own hover and press tones (a button's state
///   tables set them); surfaces are tonal already.
/// - `card.margin`, `dialog.insetPadding`, `iconButton` `padding` /
///   `minHeight` / `iconSize`: the desk's grids place cards, dialogs are
///   sized by their window, icon buttons are fixed squares by size.
/// - `input.disabledBorderColor`: a disabled field is faded as a whole.
/// - `navigation`'s icon and label colors: the dock's items are app icons.
/// - `appBar.iconColor`, `elevation`: the title bar's tools are icon buttons
///   (`iconButton` draws them), and it floats over the content unshadowed.
/// - `progress.color` on a stat: its fill has its own metric's color (the
///   dock's launch bar takes it).
/// - `badge.smallSize`: the desk's badges always carry a label.
/// - the buttons' `focused` and `selected` states: focus is the design
///   system's ring, and its buttons have no selected state.

import type { PackageTheme } from './deskApi'

/// What a field holds, and so the custom properties it becomes: `border`
/// fields are one outline (`--lk-x-border`, `-border-offset`), `ring` fields
/// a color and a width the component draws as its inset ring, `shadow` is
/// the color of the `elevation`'s shadow (`--lk-x-shadow`), and a `flag`
/// says how another field is read.
type Kind = 'color' | 'px' | 'insets' | 'flag' | 'elevation' | 'shadow' | 'border' | 'ring'

const shape = { radius: 'px', borderColor: 'border', borderWidth: 'border' } as const
const ring = { radius: 'px', borderColor: 'ring', borderWidth: 'ring' } as const
const surface = { backgroundColor: 'color', elevation: 'elevation', shadowColor: 'shadow' } as const
const button = { ...shape, ...surface, foregroundColor: 'color', padding: 'insets', minHeight: 'px' } as const

/// The fields the desk draws, by component, and what each holds.
export const drawn: Record<string, Record<string, Kind>> = {
  card: { ...shape, ...surface },
  button,
  textButton: button,
  outlinedButton: button,
  iconButton: { ...shape, ...surface, foregroundColor: 'color' },
  input: { ...ring, filled: 'flag', fillColor: 'color', focusedBorderColor: 'color', errorBorderColor: 'color', padding: 'insets' },
  search: { ...shape, backgroundColor: 'color', elevation: 'elevation', iconColor: 'color', textColor: 'color', hintColor: 'color', height: 'px', padding: 'insets' },
  navigation: { backgroundColor: 'color', indicatorColor: 'color', indicatorRadius: 'px', elevation: 'elevation' },
  appBar: { backgroundColor: 'color', foregroundColor: 'color', titleColor: 'color' },
  segmented: { ...ring, backgroundColor: 'color', selectedColor: 'color', textColor: 'color', selectedTextColor: 'color' },
  sidebar: { backgroundColor: 'color', selectedColor: 'color', textColor: 'color', selectedTextColor: 'color', iconColor: 'color', selectedIconColor: 'color', radius: 'px', padding: 'insets' },
  dialog: { ...shape, ...surface, barrierColor: 'color' },
  menu: { ...shape, ...surface, textColor: 'color' },
  tooltip: { ...shape, backgroundColor: 'color', textColor: 'color', padding: 'insets' },
  toast: { ...shape, backgroundColor: 'color', textColor: 'color', elevation: 'elevation' },
  switch: { thumbColor: 'color', trackColor: 'color', trackOutlineColor: 'color', selectedThumbColor: 'color', selectedTrackColor: 'color', selectedTrackOutlineColor: 'color' },
  slider: { activeTrackColor: 'color', inactiveTrackColor: 'color', thumbColor: 'color', trackHeight: 'px' },
  progress: { color: 'color', trackColor: 'color', thickness: 'px', radius: 'px' },
  badge: { backgroundColor: 'color', textColor: 'color', largeSize: 'px' },
  divider: { color: 'color', thickness: 'px' },
  scrollbar: { thumbColor: 'color', trackColor: 'color', radius: 'px', thickness: 'px' },
}

/// The button states the desk draws, and the fields a state table sets.
export const drawnStates = ['hovered', 'pressed', 'disabled'] as const
export const stateFields = ['backgroundColor', 'foregroundColor'] as const
const stateful = new Set(['button', 'textButton', 'outlinedButton', 'iconButton'])

const kebab = (name: string) => name.replace(/[A-Z]/g, (c) => `-${c.toLowerCase()}`)
export const hook = (...path: string[]) => `--lk-${path.map(kebab).join('-')}`

type Table = Record<string, unknown>
const isTable = (v: unknown): v is Table => typeof v === 'object' && v !== null && !Array.isArray(v)

/// [theme]'s component tables in [dark] or light: the brightness's own table
/// over the common one, field by field and state by state.
export function mergedComponents(theme: PackageTheme, dark: boolean): Record<string, Table> {
  const all = theme.components ?? {}
  const group = all[dark ? 'dark' : 'light']
  const specific = isTable(group) ? group : {}
  const out: Record<string, Table> = {}
  for (const name of new Set([...Object.keys(all), ...Object.keys(specific)])) {
    if (name === 'light' || name === 'dark') continue
    const common = isTable(all[name]) ? (all[name] as Table) : {}
    const own = isTable(specific[name]) ? (specific[name] as Table) : {}
    const merged: Table = { ...common, ...own }
    for (const state of drawnStates) {
      if (isTable(common[state]) || isTable(own[state])) {
        merged[state] = { ...(common[state] as Table | undefined), ...(own[state] as Table | undefined) }
      }
    }
    out[name] = merged
  }
  return out
}

/// The custom properties [theme]'s components draw with, in [dark] or light;
/// [color] writes a field's color (ARGB or a scheme role), or null for a role
/// the scheme lacks.
export function componentVars(theme: PackageTheme, dark: boolean, color: (value: unknown) => string | null): Record<string, string> {
  const vars: Record<string, string> = {}
  for (const [name, fields] of Object.entries(mergedComponents(theme, dark))) {
    const kinds = drawn[name]
    if (!kinds) continue
    for (const [field, kind] of Object.entries(kinds)) {
      const value = fields[field]
      if (value === undefined) continue
      switch (kind) {
        case 'color': {
          const c = color(value)
          if (c) vars[hook(name, field)] = c
          break
        }
        case 'px':
          if (typeof value === 'number') vars[hook(name, field)] = `${value}px`
          break
        case 'insets':
          if (Array.isArray(value) && value.length === 4) {
            const [l, t, r, b] = value as number[]
            vars[hook(name, field)] = `${t}px ${r}px ${b}px ${l}px`
          }
          break
        case 'elevation':
          if (typeof value === 'number') {
            const ink = color(fields.shadowColor) ?? color('shadow') ?? '#000'
            vars[hook(name, 'shadow')] =
              value === 0 ? 'none' : `0 ${value / 2}px ${value * 1.5}px color-mix(in srgb, ${ink} 28%, transparent)`
          }
          break
        case 'flag':
        case 'shadow':
        case 'border':
        case 'ring':
          break
      }
    }
    // A border as the app draws one: a width with no color is the scheme's
    // outline; a color with no width is 1.
    if (fields.borderColor !== undefined || fields.borderWidth !== undefined) {
      const width = typeof fields.borderWidth === 'number' ? fields.borderWidth : 1
      if (kinds.borderColor === 'border') {
        const c = color(fields.borderColor) ?? color('outline') ?? 'currentColor'
        vars[hook(name, 'border')] = width > 0 ? `${width}px solid ${c}` : 'none'
        vars[hook(name, 'border-offset')] = `${-width}px`
      } else if (kinds.borderColor === 'ring') {
        // The ring keeps the design system's color when only a width is given.
        const c = fields.borderColor === undefined ? null : color(fields.borderColor)
        if (c) vars[hook(name, 'border-color')] = c
        vars[hook(name, 'border-width')] = `${width}px`
      }
    }
    if (stateful.has(name)) {
      for (const state of drawnStates) {
        const table = fields[state]
        if (!isTable(table)) continue
        for (const field of stateFields) {
          const c = table[field] === undefined ? null : color(table[field])
          if (c) vars[hook(name, state, field)] = c
        }
        // A disabled state with its own colors is drawn in them, not faded
        // as well: the app's colors are the final ones.
        if (state === 'disabled' && stateFields.some((f) => table[f] !== undefined)) vars[hook(name, 'disabled-opacity')] = '1'
      }
    }
    if (name === 'input' && fields.filled === false) vars[hook('input', 'fill-color')] = 'transparent'
    if (name === 'segmented' && typeof fields.radius === 'number') {
      // The thumb sits 2px inside the track.
      vars[hook('segmented', 'thumb-radius')] = `${Math.max(fields.radius - 2, 0)}px`
    }
  }
  return vars
}

/// `[layout] density` on the design system's sizes. The desk is already as
/// dense as a desktop app (`compact`, the app's own on desktop); the others
/// add 4px a step, as Flutter's visual density does.
export function densityVars(theme: PackageTheme): Record<string, string> {
  const add = { comfortable: 4, standard: 8 }[theme.density ?? '']
  if (!add) return {}
  const sizes: Record<string, number> = {
    '--control-height': 30,
    '--control-height-sm': 24,
    '--control-height-lg': 36,
    '--row-height': 30,
    '--row-height-comfortable': 36,
    '--menu-item-height': 26,
  }
  return Object.fromEntries(Object.entries(sizes).map(([name, px]) => [name, `${px + add}px`]))
}
