import { describe, it, expect, afterEach } from 'vitest'
import { get } from 'svelte/store'
import { detectLocale, persistLocale } from '../i18n/init'
import { locale } from '../i18n/i18n-svelte'
import { layout } from '../lib/layout.svelte'
import { servers } from '../lib/servers.svelte'
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

  afterEach(() => {
    Object.defineProperty(window, 'localStorage', real)
    persistLocale('en')
  })

  it('reads as absent and writes as nothing', () => {
    blockStorage()
    expect(readPref('locale')).toBeNull()
    expect(() => writePref('locale', 'de')).not.toThrow()
  })

  it('still detects and switches the language', () => {
    blockStorage()
    expect(detectLocale()).toBe('en')
    persistLocale('ja')
    expect(get(locale)).toBe('ja')
    expect(document.documentElement.lang).toBe('ja')
  })
})

describe('page transition direction', () => {
  afterEach(() => layout.navigate('dashboard'))

  it('runs back after a back, and forward once the server changes', () => {
    servers.currentId = 'a'
    layout.navigate('process')
    expect(layout.navDirection).toBe('forward')
    layout.back('dashboard')
    expect(layout.navDirection).toBe('back')
    servers.currentId = 'b'
    expect(layout.navDirection).toBe('forward')
  })
})
