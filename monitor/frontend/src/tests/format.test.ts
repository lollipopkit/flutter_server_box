import { describe, expect, it } from 'vitest'
import { fmtBytes } from '../lib/format'

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
