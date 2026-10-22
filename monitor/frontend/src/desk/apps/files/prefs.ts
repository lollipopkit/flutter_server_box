/// How Files opens, kept in the app's storage (on the server, per account):
/// read by the app and by its settings page.

import type { AppStorage } from '../../sys'

export const PREFS_KEY = 'prefs'

export interface FilesPrefs {
  /// The view a new window starts in.
  view: 'list' | 'grid'
  /// Entries whose name starts with a dot.
  hidden: boolean
  /// What a double-click on a file does.
  open: 'editor' | 'download'
}

export const DEFAULT_PREFS: FilesPrefs = { view: 'list', hidden: false, open: 'editor' }

export function parsePrefs(raw: unknown): FilesPrefs {
  const v = (raw ?? {}) as Partial<Record<keyof FilesPrefs, unknown>>
  return {
    view: v.view === 'grid' ? 'grid' : 'list',
    hidden: v.hidden === true,
    open: v.open === 'download' ? 'download' : 'editor',
  }
}

export async function loadPrefs(storage: AppStorage): Promise<FilesPrefs> {
  try {
    return parsePrefs(await storage.get(PREFS_KEY))
  } catch {
    return DEFAULT_PREFS
  }
}
