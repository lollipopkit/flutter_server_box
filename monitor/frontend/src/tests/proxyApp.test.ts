import { describe, it, expect } from 'vitest'
import { nameFor, withSite, withoutSite } from '../desk/apps/proxy/model'
import type { ProxySite } from '../types'

const site = (name: string, managed = true): ProxySite => ({ name, domains: [`${name}.example.com`], upstream: 'http://127.0.0.1:1', tls: false, managed })

describe('the reverse proxy model', () => {
  it('sends back ServerBox\'s sites alone, the edited one in its place', () => {
    const sites = [site('a'), site('other', false), site('b')]
    expect(withSite(sites, { ...site('a'), upstream: 'http://127.0.0.1:2' }, 'a').map((s) => [s.name, s.upstream])).toEqual([
      ['a', 'http://127.0.0.1:2'],
      ['b', 'http://127.0.0.1:1'],
    ])
    expect(withSite(sites, site('c'), null).map((s) => s.name)).toEqual(['a', 'b', 'c'])
    expect(withoutSite(sites, 'a').map((s) => s.name)).toEqual(['b'])
  })

  it('names a site after its first domain', () => {
    expect(nameFor('Photos.Example.com')).toBe('photos-example-com')
    expect(nameFor('*.lan')).toBe('wildcard-lan')
    expect(nameFor('')).toBe('site')
  })
})
