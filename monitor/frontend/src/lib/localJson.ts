/// Best-effort browser `localStorage` JSON helpers that tolerate private mode
/// and malformed stored payloads.

export function readLocalJson<T extends object>(key: string): Partial<T> {
  try {
    const parsed: unknown = JSON.parse(window.localStorage.getItem(key) ?? '{}')
    return parsed && typeof parsed === 'object' ? (parsed as Partial<T>) : {}
  } catch {
    return {}
  }
}

export function writeLocalJson(key: string, value: unknown): void {
  try {
    window.localStorage.setItem(key, JSON.stringify(value))
  } catch {
    // Private mode or storage quota: keep changes in memory for this tab.
  }
}
