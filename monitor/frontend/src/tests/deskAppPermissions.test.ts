import { describe, it, expect } from 'vitest'
import { loadAllLocales } from '../i18n/i18n-util.sync'
import { i18nObject, locales } from '../i18n/i18n-util'
import { permissionText } from '../desk/apps/settings/permissions'

loadAllLocales()

/// Every permission the agent lets a package ask for (`api::apps`,
/// `WEB_PERMISSIONS` and `WASM_PERMISSIONS`): the approval dialog says what
/// each allows, never its bare name.
const PERMISSIONS = ['notifications', 'background', 'status', 'files.read', 'exec']

describe('installed app permissions', () => {
  it('are described in every locale', () => {
    for (const locale of locales) {
      const ll = i18nObject(locale)
      for (const p of PERMISSIONS) expect(permissionText(ll, p), `${locale} ${p}`).not.toBe(p)
    }
  })

  it('shows an unknown one as is', () => {
    expect(permissionText(i18nObject('en'), 'net')).toBe('net')
  })
})
