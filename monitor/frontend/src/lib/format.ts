import { displayPrefs } from './displayPrefs.svelte'

/// Binary units (1024, KiB) or decimal ones (1000, KB), as this browser chose.
function scale(): { base: number; units: string[] } {
  return displayPrefs.units === 'si'
    ? { base: 1000, units: ['B', 'KB', 'MB', 'GB', 'TB'] }
    : { base: 1024, units: ['B', 'KiB', 'MiB', 'GiB', 'TiB'] }
}

export function fmtBytes(v: number | string | bigint): string {
  if (typeof v === 'bigint') return fmtIntegerBytes(v)
  if (typeof v === 'string') {
    try {
      return fmtIntegerBytes(BigInt(v))
    } catch {
      return fmtNumericBytes(Number(v))
    }
  }
  return fmtNumericBytes(v)
}

function fmtNumericBytes(v: number): string {
  const { base, units } = scale()
  let size = Math.max(v, 0)
  let unit = 0
  while (size >= base && unit < units.length - 1) {
    size /= base
    unit++
  }
  return `${unit === 0 ? size.toFixed(0) : size.toFixed(1)} ${units[unit]}`
}

function fmtIntegerBytes(value: bigint): string {
  const { base, units } = scale()
  const step = BigInt(base)
  const size = value < 0n ? 0n : value
  let divisor = 1n
  let unit = 0
  while (size >= divisor * step && unit < units.length - 1) {
    divisor *= step
    unit++
  }
  if (unit === 0) return `${size} ${units[unit]}`
  const tenths = (size * 10n + divisor / 2n) / divisor
  return `${tenths / 10n}.${tenths % 10n} ${units[unit]}`
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
  return fmtDate(d, opts.withDate ? { month: 'short', day: 'numeric', hour: '2-digit', minute: '2-digit' } : { hour: '2-digit', minute: '2-digit' })
}

/// A moment as [options] ask, on this browser's clock (24 or 12 hours) and
/// in [locale] (the viewer's when absent). Every time on screen goes
/// through here, so the clock setting reaches all of them.
export function fmtDate(at: Date | number, options: Intl.DateTimeFormatOptions, locale?: string): string {
  const withClock = options.hour !== undefined || options.timeStyle !== undefined
  return new Intl.DateTimeFormat(locale, withClock ? { ...options, hourCycle: displayPrefs.time === '12' ? 'h12' : 'h23' } : options).format(at)
}

/// A date and time in full, for a moment that may be any day.
export const DATE_TIME: Intl.DateTimeFormatOptions = { year: 'numeric', month: 'short', day: 'numeric', hour: '2-digit', minute: '2-digit' }

/// Seconds since the epoch, as tmux and the file listing report them, in the
/// viewer's locale and with the date shown, since these are not from today
/// (a session may be weeks old). Date and time rather than time alone.
export function fmtEpochSeconds(seconds: number): string {
  return fmtDate(seconds * 1000, { month: 'short', day: 'numeric', hour: '2-digit', minute: '2-digit' })
}

/// GPU power comes preformatted as "<draw> / <limit>" from the agent, with the
/// literal string "null" for whichever side the driver didn't report (e.g.
/// older nvidia-smi output, or GPUs that don't expose live power draw) —
/// display that as N/A instead of a raw null
export function fmtGpuPower(power: string): string {
  return power.replace(/\bnull\b/g, 'N/A')
}
