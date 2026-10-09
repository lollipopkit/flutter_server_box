/// How Processes behaves, kept in the app's storage (on the server, per
/// account): read by the app and by its settings page.

import type { AppStorage } from '../../sys'

export const PREFS_KEY = 'prefs'

export interface ProcessPrefs {
  /// Kernel threads listed when a window opens.
  kernelThreads: boolean
  /// A stop is asked about in the status bar first.
  confirmStop: boolean
}

export const DEFAULT_PREFS: ProcessPrefs = { kernelThreads: false, confirmStop: true }

export function parsePrefs(raw: unknown): ProcessPrefs {
  const v = (raw ?? {}) as Partial<Record<keyof ProcessPrefs, unknown>>
  return { kernelThreads: v.kernelThreads === true, confirmStop: v.confirmStop !== false }
}

export async function loadPrefs(storage: AppStorage): Promise<ProcessPrefs> {
  try {
    return parsePrefs(await storage.get(PREFS_KEY))
  } catch {
    return DEFAULT_PREFS
  }
}
