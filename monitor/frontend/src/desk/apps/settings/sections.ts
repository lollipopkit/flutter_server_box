/// The Settings app's sections: the sidebar's rows and the panel beside them.
/// Which one a window opens at comes from its `appState` (`{ section }`), so
/// another app can open Settings straight at what it is about — the desk's
/// control centre sends `appearance`, the status app's gear sends `server`.

export const SETTINGS_SECTIONS = ['general', 'appearance', 'apps', 'account', 'server', 'agent', 'access'] as const

export type SettingsSection = (typeof SETTINGS_SECTIONS)[number]

/// Whether [value] names a section this app has.
export function isSection(value: unknown): value is SettingsSection {
  return typeof value === 'string' && (SETTINGS_SECTIONS as readonly string[]).includes(value)
}

/// The section a window asked for; anything else — a fresh window, or state
/// written by an older panel — opens General.
export function resolveSection(appState: unknown): SettingsSection {
  const asked = (appState as { section?: unknown } | null | undefined)?.section
  return isSection(asked) ? asked : 'general'
}
