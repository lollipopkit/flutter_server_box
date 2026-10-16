import { describe, it, expect } from 'vitest'
import { ApiError } from '../lib/api'
import { backupRefusalText, validBackupName } from '../lib/backup'
import backupApp from '../desk/apps/backup/manifest'
import type { Capabilities } from '../types'

describe('the backup page', () => {
  it('is offered by an agent that serves it, over a link the account may act on', () => {
    const caps = (features: string[], ok: boolean) => ({ features, access: { ok } }) as unknown as Capabilities
    expect(backupApp.available(caps(['backup'], true))).toBe(true)
    expect(backupApp.available(caps(['backup'], false))).toBe(false)
    expect(backupApp.available(caps([], true))).toBe(false)
  })

  it('takes the names the agent takes', () => {
    for (const name of ['srvbox_bak_v3.json', '2026-10-03-srvbox_bak_v3.json']) {
      expect(validBackupName(name)).toBe(true)
    }
    for (const name of ['', '.hidden', 'a b', 'a/b', '名.json', 'a'.repeat(129)]) {
      expect(validBackupName(name)).toBe(false)
    }
  })

  it('phrases the agent refusals and passes anything else on', () => {
    expect(backupRefusalText(new ApiError('tooMany', 409))).toMatch(/64/)
    expect(backupRefusalText(new ApiError('invalidName', 400))).toMatch(/letters/)
    expect(backupRefusalText(new ApiError('something else', 500))).toBe('something else')
  })
})
