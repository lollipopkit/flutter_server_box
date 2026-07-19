const UNITS = ['B', 'KB', 'MB', 'GB', 'TB']

export function fmtBytes(v: number): string {
  let size = Math.max(v, 0)
  let unit = 0
  while (size >= 1024 && unit < UNITS.length - 1) {
    size /= 1024
    unit++
  }
  return `${unit === 0 ? size.toFixed(0) : size.toFixed(1)} ${UNITS[unit]}`
}

export function fmtBytesPerSec(v: number): string {
  return `${fmtBytes(v)}/s`
}

export function fmtPercent(v: number): string {
  return `${v.toFixed(1)}%`
}

/// SQLite timestamps come as "YYYY-MM-DD HH:MM:SS[+00:00]"; normalize for Date
export function parseTimestamp(ts: string): Date {
  return new Date(ts.includes('T') ? ts : ts.replace(' ', 'T'))
}

export function fmtTime(ts: string): string {
  return parseTimestamp(ts).toLocaleTimeString([], { hour: '2-digit', minute: '2-digit' })
}
