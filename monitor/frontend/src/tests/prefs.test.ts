import { describe, it, expect, afterEach } from 'vitest'
import { get } from 'svelte/store'
import { detectLocale, persistLocale } from '../i18n/init'
import { locale } from '../i18n/i18n-svelte'
import { readPref, writePref } from '../lib/prefs'

describe('storage that throws', () => {
  const real = Object.getOwnPropertyDescriptor(window, 'localStorage')!

  function blockStorage() {
    Object.defineProperty(window, 'localStorage', {
      configurable: true,
      get() {
        throw new DOMException('blocked', 'SecurityError')
      },
    })
  }

  afterEach(async () => {
    Object.defineProperty(window, 'localStorage', real)
    await persistLocale('en')
  })

  it('reads as absent and writes as nothing', () => {
    blockStorage()
    expect(readPref('locale')).toBeNull()
    expect(() => writePref('locale', 'de')).not.toThrow()
  })

  it('still detects and switches the language', async () => {
    blockStorage()
    expect(detectLocale()).toBe('en')
    await persistLocale('ja')
    expect(get(locale)).toBe('ja')
    expect(document.documentElement.lang).toBe('ja')
  })
})
