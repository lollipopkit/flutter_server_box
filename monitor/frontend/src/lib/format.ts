const UNITS = ['B', 'KB', 'MB', 'GB', 'TB']

export function fmtBytes(v: number | string | bigint): string {
  if (typeof v !== 'number') return fmtIntegerBytes(typeof v === 'bigint' ? v : BigInt(v))
  let size = Math.max(v, 0)
  let unit = 0
  while (size >= 1024 && unit < UNITS.length - 1) {
    size /= 1024
    unit++
  }
  return `${unit === 0 ? size.toFixed(0) : size.toFixed(1)} ${UNITS[unit]}`
}

function fmtIntegerBytes(value: bigint): string {
  const size = value < 0n ? 0n : value
  let divisor = 1n
  let unit = 0
  while (size >= divisor * 1024n && unit < UNITS.length - 1) {
    divisor *= 1024n
    unit++
  }
  if (unit === 0) return `${size} ${UNITS[unit]}`
  const tenths = (size * 10n + divisor / 2n) / divisor
  return `${tenths / 10n}.${tenths % 10n} ${UNITS[unit]}`
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

/// Time-only by default (matches the common case: a chart range within one
/// day). Pass withDate when the range being labeled spans multiple calendar
/// days — otherwise e.g. a 7d chart's axis reads "08:00 AM" at both ends
/// with no way to tell which day either point is on.
export function fmtTime(ts: string, opts: { withDate?: boolean } = {}): string {
  const d = parseTimestamp(ts)
  return opts.withDate
    ? d.toLocaleString([], { month: 'short', day: 'numeric', hour: '2-digit', minute: '2-digit' })
    : d.toLocaleTimeString([], { hour: '2-digit', minute: '2-digit' })
}

/// GPU power comes preformatted as "<draw> / <limit>" from the agent, with the
/// literal string "null" for whichever side the driver didn't report (e.g.
/// older nvidia-smi output, or GPUs that don't expose live power draw) —
/// display that as N/A instead of a raw null
export function fmtGpuPower(power: string): string {
  return power.replace(/\bnull\b/g, 'N/A')
}
