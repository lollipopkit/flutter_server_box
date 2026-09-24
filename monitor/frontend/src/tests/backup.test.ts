import { describe, expect, it, beforeAll } from 'vitest'
import { storedName, tooLarge } from '../pages/Backup.svelte'
import { setLocale } from '../i18n/i18n-svelte'

beforeAll(async () => {
  await setLocale('en')
})

describe('storing a backup', () => {
  it('keeps the name the file has', () => {
    // The app syncs `srvbox_bak_v3.json` and reads back what it wrote, so a
    // store that renamed an upload would leave it asking for a name that never
    // appears — and a name the agent cannot address is refused there rather
    // than rewritten here into something the operator did not choose.
    expect(storedName('srvbox_bak_v3.json')).toBe('srvbox_bak_v3.json')
    expect(storedName('2026-09-24-12-00-00-srvbox_bak_v3.json')).toBe(
      '2026-09-24-12-00-00-srvbox_bak_v3.json',
    )
  })

  it('refuses only what the agent would refuse', () => {
    // The cap is a maximum, so a file exactly at it is one the agent accepts.
    // A page stricter than the endpoint it is guarding would refuse a file that
    // would have worked.
    expect(tooLarge(1024, 1024)).toBe(false)
    expect(tooLarge(1025, 1024)).toBe(true)
    expect(tooLarge(0, 1024)).toBe(false)
  })
})
