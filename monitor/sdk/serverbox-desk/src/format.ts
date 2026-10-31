/// Sizes and times as the desk writes them.

const UNITS = ['B', 'KiB', 'MiB', 'GiB', 'TiB', 'PiB']

/// [bytes] in binary units, one decimal from KiB up: `1.5 GiB`.
export function formatBytes(bytes: number): string {
  let v = Math.max(0, bytes)
  let i = 0
  while (v >= 1024 && i < UNITS.length - 1) {
    v /= 1024
    i++
  }
  return i === 0 ? `${v} B` : `${v.toFixed(v >= 100 ? 0 : 1)} ${UNITS[i]}`
}

/// [ms] (Unix milliseconds) in [locale]: `17 Oct, 18:20`.
export function formatTime(ms: number, locale: string): string {
  return new Intl.DateTimeFormat(locale, { month: 'short', day: 'numeric', hour: '2-digit', minute: '2-digit' }).format(new Date(ms))
}

/// [when] (Unix milliseconds or an ISO text) as a date in [locale]: `17 Oct 2026`.
export function formatDate(when: number | string, locale: string): string {
  return new Intl.DateTimeFormat(locale, { year: 'numeric', month: 'short', day: 'numeric' }).format(new Date(when))
}
