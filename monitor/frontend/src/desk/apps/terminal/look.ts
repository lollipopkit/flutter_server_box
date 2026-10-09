/// How the terminal looks and sounds, kept in the app's storage (on the
/// server, per account): read by the terminal and by its settings page.

import type { TerminalLook } from '../../../lib/xterm'
import type { AppStorage } from '../../sys'

export const LOOK_KEY = 'look'
export const FONT_SIZES = [12, 13, 15] as const
export const CURSORS = ['block', 'bar', 'underline'] as const

export type Look = Required<TerminalLook>

export const DEFAULT_LOOK: Look = { fontSize: 13, cursor: 'block', bell: false }

export function parseLook(raw: unknown): Look {
  const v = (raw ?? {}) as Partial<Record<keyof Look, unknown>>
  return {
    fontSize: FONT_SIZES.find((s) => s === v.fontSize) ?? DEFAULT_LOOK.fontSize,
    cursor: CURSORS.find((c) => c === v.cursor) ?? DEFAULT_LOOK.cursor,
    bell: v.bell === true,
  }
}

export async function loadLook(storage: AppStorage): Promise<Look> {
  try {
    return parseLook(await storage.get(LOOK_KEY))
  } catch {
    return DEFAULT_LOOK
  }
}
