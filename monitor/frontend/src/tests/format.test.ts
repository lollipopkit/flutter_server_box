import { afterEach, describe, expect, it } from 'vitest'
import { displayPrefs } from '../lib/displayPrefs.svelte'
import { fmtBytes, fmtDate } from '../lib/format'

describe('byte formatting', () => {
  afterEach(() => displayPrefs.set({ units: 'iec', time: '24' }))

  it('preserves exact integer strings and bigint values', () => {
    expect(fmtBytes('9007199254740993')).toBe('8192.0 TiB')
    expect(fmtBytes(1536n)).toBe('1.5 KiB')
  })

  it('falls back to numeric formatting for non-integer strings', () => {
    expect(fmtBytes('1536.5')).toBe('1.5 KiB')
    expect(fmtBytes('not-a-number')).toBe('NaN B')
  })

  it('writes decimal units when the browser asks for them', () => {
    displayPrefs.set({ units: 'si' })
    expect(fmtBytes(1500)).toBe('1.5 KB')
    expect(fmtBytes(2_000_000_000n)).toBe('2.0 GB')
  })
})

describe('time formatting', () => {
  afterEach(() => displayPrefs.set({ units: 'iec', time: '24' }))

  it('follows the clock the browser chose', () => {
    const at = new Date(2026, 9, 7, 17, 5)
    expect(fmtDate(at, { hour: '2-digit', minute: '2-digit' }, 'en-US')).toBe('17:05')
    displayPrefs.set({ time: '12' })
    expect(fmtDate(at, { hour: '2-digit', minute: '2-digit' }, 'en-US')).toMatch(/^05:05\sPM$/)
  })
})
