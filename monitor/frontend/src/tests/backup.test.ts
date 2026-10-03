import { describe, it, expect } from 'vitest'
import { ApiError } from '../lib/api'
import { backupRefusalText, validBackupName } from '../lib/backup'
import { enabledFeatures } from '../lib/features'
import type { Capabilities } from '../types'

describe('the backup page', () => {
  it('is offered to an admin of an agent that serves it, and nobody else', () => {
    const caps = (features: string[], admin: boolean) =>
      ({ features, me: { admin }, grants: { shell: { ok: true } } }) as unknown as Capabilities
    const ids = (c: Capabilities) => enabledFeatures(c).map((f) => f.id)
    expect(ids(caps(['backup'], true))).toEqual(['backup'])
    expect(ids(caps(['backup'], false))).toEqual([])
    expect(ids(caps([], true))).toEqual([])
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
