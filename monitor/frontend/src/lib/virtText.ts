/// Small pure parsing and unit-conversion helpers shared across virtualization forms.

/// One entry per non-blank line (SSH keys).
export function lines(text: string): string[] {
  return text
    .split(/\r?\n/)
    .map((l) => l.trim())
    .filter(Boolean)
}

/// Entries separated by spaces or commas (DNS servers, search domains).
export function words(text: string): string[] {
  return text.split(/[\s,]+/).filter(Boolean)
}

/// A number as an input holds it (a number input hands back a number, an
/// emptied one null); null for blank or not a number.
export function num(value: string | number | null | undefined): number | null {
  if (value === null || value === undefined) return null
  const text = String(value).trim()
  if (text === '') return null
  const n = Number(text)
  return Number.isFinite(n) ? n : null
}

/// GiB as typed, in bytes; null for nothing typed.
export function gibBytes(value: string | number | null | undefined): number | null {
  const n = num(value)
  return n === null ? null : Math.round(n * 1024 ** 3)
}

/// GiB as typed, in MiB; null for nothing typed.
export function gibMib(value: string | number | null | undefined): number | null {
  const n = num(value)
  return n === null ? null : Math.round(n * 1024)
}

/// MiB as GiB for an input: at most two decimals, no trailing zeros.
export function mibGib(mib: number): string {
  return String(Math.round((mib / 1024) * 100) / 100)
}
