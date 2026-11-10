/// The server search's matching rule, which Spotlight uses to find a
/// server by its name or address.
import { describe, it, expect } from 'vitest'
import { serverMatches } from '../lib/serverSearch'

describe('serverMatches', () => {
  it('keeps everything for an empty query', () => {
    expect(serverMatches('', 'Alpha', 'https://alpha.example')).toBe(true)
    expect(serverMatches('   ', 'Alpha', 'https://alpha.example')).toBe(true)
  })

  it('matches the label, case-insensitively', () => {
    expect(serverMatches('alpha', 'Alpha', 'https://x.example')).toBe(true)
    expect(serverMatches('ALPHA', 'Alpha', 'https://x.example')).toBe(true)
    expect(serverMatches('alp', 'Alpha', 'https://x.example')).toBe(true)
  })

  it('matches the URL', () => {
    expect(serverMatches('beta.example', 'Beta', 'https://beta.example')).toBe(true)
    expect(serverMatches('https://beta', 'Beta', 'https://beta.example')).toBe(true)
  })

  it('drops a row neither matches', () => {
    expect(serverMatches('gamma', 'Alpha', 'https://alpha.example')).toBe(false)
  })
})
