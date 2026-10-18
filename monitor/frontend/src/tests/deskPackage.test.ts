import { describe, it, expect } from 'vitest'
import { compareVersions, standing } from '../desk/apps/store/deskPackage'
import type { InstalledApp, OfferedApp } from '../types'

const manifest = { publisher: 'serverbox', name: 'kernel', version: '', api: 2, kind: 'wasm' as const, title: 'Kernels', glyph: 'memory', tone: 'ink', permissions: ['root'] }
const offered = (version: string, sha: string): OfferedApp => ({ id: 'serverbox.kernel', version, sha256: sha, size: 1, manifest: { ...manifest, version }, signedBy: 'k', source: 'bundled', repo: null })
const installed = (version: string, sha: string, approved = true): InstalledApp => ({
  id: 'serverbox.kernel',
  version,
  sha256: sha,
  manifest: { ...manifest, version },
  approved_permissions: approved ? ['root'] : null,
  installed_at: '',
  approved_at: null,
})

describe('a desk package against the one installed', () => {
  it('offers only a later version as an update, never a step back', () => {
    expect(standing(offered('1.3.0', 'b'), [])).toBe('none')
    expect(standing(offered('1.3.0', 'b'), [installed('1.2.0', 'a')])).toBe('update')
    expect(standing(offered('1.2.0', 'a'), [installed('1.3.0', 'b')])).toBe('current')
    expect(standing(offered('1.3.0', 'b'), [installed('1.3.0', 'c')])).toBe('current')
    expect(standing(offered('1.3.0', 'b'), [installed('1.3.0', 'b', false)])).toBe('waiting')
  })

  it('compares versions by number, a pre-release before its release', () => {
    expect(compareVersions('1.10.0', '1.9.0')).toBe(1)
    expect(compareVersions('1.2', '1.2.0')).toBe(0)
    expect(compareVersions('2.0.0-rc1', '2.0.0')).toBe(-1)
  })
})
