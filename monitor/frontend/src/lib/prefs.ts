/// Web storage for what the panel still works without: language, theme, the
/// server list across reloads. Storage can throw — blocked site data, some
/// private modes — and that must not stop the panel from starting; a value
/// that cannot be kept still applies to this visit.
type Area = 'localStorage' | 'sessionStorage'

export function readPref(key: string, area: Area = 'localStorage'): string | null {
  try {
    return window[area].getItem(key)
  } catch {
    return null
  }
}

export function writePref(key: string, value: string, area: Area = 'localStorage') {
  try {
    window[area].setItem(key, value)
  } catch {
    // Not remembered, by the browser's choice
  }
}

export function removePref(key: string, area: Area = 'localStorage') {
  try {
    window[area].removeItem(key)
  } catch {
    // Nothing kept to remove
  }
}
