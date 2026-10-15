/// Store web apps as desk apps of their own (`desk/stacks/register.ts`).

import { describe, expect, it, vi } from 'vitest'
import { rememberStackApps, stackAppId, stackOf } from '../components/stack/apps'
import { stackAppSpec } from '../desk/stacks/register'
import type { Capabilities, StackApp, StackManifest } from '../types'

const manifest = (publisher: string, name: string, title: string): StackManifest => ({
  id: `${publisher}.${name}`,
  publisher,
  name,
  project: title,
  version: '1.0.0',
  homepage: 'https://example.com',
  source: 'https://example.com/src',
  glyph: 'monitor_heart',
  tone: 'leaf',
  categories: ['monitoring'],
  notices: [],
  title: { en: title },
  description: { en: `${title} does things.` },
  license: { spdx: 'MIT', url: 'https://example.com/LICENSE', accept: false },
  requirements: { arch: [], os: [] },
  web: { port: 'port', path: '/' },
  settings: [],
})

const caps = (stacks: Capabilities['stacks'], ok = false) =>
  ({ features: ['stacks'], stacks, access: { ok } }) as unknown as Capabilities

describe('a store web app as a desk app', () => {
  const app: StackApp = { manifest: manifest('louislam', 'uptime_kuma', 'Uptime Kuma'), stack: null, job: null, proxy: false } as StackApp

  it('is named, drawn and found by its manifest', () => {
    const spec = stackAppSpec(app)
    expect(spec.id).toBe('louislam.uptime_kuma')
    expect(spec.title({} as never)).toBe('Uptime Kuma')
    expect([spec.glyph, spec.tone]).toEqual(['monitor_heart', 'leaf'])
    expect(spec.keywords?.({} as never)).toEqual(['Uptime Kuma', 'monitoring'])
  })

  it('is offered while it is deployed', () => {
    const spec = stackAppSpec(app)
    expect(spec.available(caps([]))).toBe(false)
    expect(spec.available(caps([{ id: 'louislam.uptime_kuma', state: 'installed' }]))).toBe(true)
    expect(spec.available(caps([{ id: 'louislam.uptime_kuma', state: 'installing' }]))).toBe(false)
    expect(spec.available(caps([{ id: 'louislam.uptime_kuma', state: 'installing' }], true))).toBe(true)
  })

  it('maps both ways while registered', () => {
    expect(stackAppId('futo.immich')).toBe('serverbox.photos')
    expect(stackAppId('louislam.uptime_kuma')).toBeUndefined()
    const forget = rememberStackApps(['louislam.uptime_kuma'])
    expect(stackAppId('louislam.uptime_kuma')).toBe('louislam.uptime_kuma')
    expect(stackOf('louislam.uptime_kuma')).toBe('louislam.uptime_kuma')
    expect(stackOf('serverbox.photos')).toBe('futo.immich')
    forget()
    expect(stackOf('louislam.uptime_kuma')).toBeUndefined()
  })
})

vi.mock('../lib/api', () => ({ api: {} }))
