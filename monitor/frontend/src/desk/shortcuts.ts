/// Menu shortcuts as menus show them (`⌘⇧N`, `⌥⌘K`, `⌘,`) and the key
/// presses that run them. `⌘` is Command on a Mac and Control elsewhere, as
/// the desk's own shortcuts are; `⌃` is Control everywhere.

import type { MenuEntry } from './lk/Menu.svelte'
import type { AppMenu } from './window/chrome.svelte'

export interface Shortcut {
  cmd: boolean
  ctrl: boolean
  alt: boolean
  shift: boolean
  /// Lowercase: a character, or a key name (`enter`, `backspace`, `f5`).
  key: string
}

const MODIFIERS: Record<string, keyof Omit<Shortcut, 'key'>> = { '⌘': 'cmd', '⌃': 'ctrl', '⌥': 'alt', '⇧': 'shift' }
const NAMED: Record<string, string> = { '↩': 'enter', '⌫': 'backspace', '⌦': 'delete', '⎋': 'escape', '⇥': 'tab', '←': 'arrowleft', '→': 'arrowright', '↑': 'arrowup', '↓': 'arrowdown', Space: ' ' }

export function parseShortcut(text: string): Shortcut | null {
  const s: Shortcut = { cmd: false, ctrl: false, alt: false, shift: false, key: '' }
  let i = 0
  const chars = [...text]
  while (i < chars.length && MODIFIERS[chars[i]]) s[MODIFIERS[chars[i++]]] = true
  const rest = chars.slice(i).join('')
  if (!rest) return null
  s.key = (NAMED[rest] ?? rest).toLowerCase()
  // Without a modifier a letter would be typing.
  if (!s.cmd && !s.ctrl && !s.alt && [...s.key].length === 1) return null
  return s
}

/// The key a press names: the layout's character, or for a letter or digit
/// with Option/Shift held (which change the character) the physical key's.
function pressedKey(e: KeyboardEvent): string {
  const code = /^(Key|Digit)(.)$/.exec(e.code)
  if (code && (e.altKey || e.shiftKey)) return code[2].toLowerCase()
  return e.key.toLowerCase()
}

export function matches(s: Shortcut, e: KeyboardEvent): boolean {
  const cmd = e.metaKey || (e.ctrlKey && !s.ctrl)
  return (
    s.cmd === cmd &&
    s.ctrl === (s.cmd ? e.ctrlKey && e.metaKey : e.ctrlKey) &&
    s.alt === e.altKey &&
    s.shift === e.shiftKey &&
    s.key === pressedKey(e)
  )
}

type Action = Extract<MenuEntry, { action: () => void }>

/// The enabled row of [menus] whose shortcut [e] is.
export function menuItemFor(e: KeyboardEvent, menus: AppMenu[]): Action | undefined {
  for (const menu of menus) {
    for (const item of menu.items) {
      if (!('action' in item) || item.disabled || !item.shortcut) continue
      const s = parseShortcut(item.shortcut)
      if (s && matches(s, e)) return item
    }
  }
  return undefined
}
