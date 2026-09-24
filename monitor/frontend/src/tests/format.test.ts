import { describe, expect, it } from 'vitest'
import { fmtBytes, fmtUptime } from '../lib/format'

describe('byte formatting', () => {
  it('preserves exact integer strings and bigint values', () => {
    expect(fmtBytes('9007199254740993')).toBe('8192.0 TB')
    expect(fmtBytes(1536n)).toBe('1.5 KB')
  })

  it('falls back to numeric formatting for non-integer strings', () => {
    expect(fmtBytes('1536.5')).toBe('1.5 KB')
    expect(fmtBytes('not-a-number')).toBe('NaN B')
  })
})

describe('uptime', () => {
  it('reports the unit an operator reads it as', () => {
    expect(fmtUptime(2_678_400)).toBe('31d')
    expect(fmtUptime(90_000)).toBe('1d')
    expect(fmtUptime(8_000)).toBe('2h')
    expect(fmtUptime(90)).toBe('1m')
    expect(fmtUptime(9)).toBe('9s')
  })

  it('rounds down, so a node up 23 hours is not said to have been up a day', () => {
    expect(fmtUptime(86_399)).toBe('23h')
  })
})
