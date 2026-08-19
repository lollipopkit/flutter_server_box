import { describe, expect, it } from 'vitest'
import { isSecureAgentUrl, normalizeAgentUrl } from '../lib/agentUrl'

describe('agent urls', () => {
  it('requires https away from loopback', () => {
    expect(isSecureAgentUrl('https://agent.example')).toBe(true)
    expect(isSecureAgentUrl('http://agent.example')).toBe(false)
  })

  it('allows http only for loopback hosts', () => {
    expect(isSecureAgentUrl('http://localhost:3770')).toBe(true)
    expect(isSecureAgentUrl('http://127.0.0.1:3770')).toBe(true)
    expect(isSecureAgentUrl('http://[::1]:3770')).toBe(true)
  })

  it('normalizes a valid url and rejects an insecure one', () => {
    expect(normalizeAgentUrl(' https://agent.example/// ')).toBe('https://agent.example')
    expect(() => normalizeAgentUrl('http://agent.example')).toThrow(/require HTTPS/)
  })
})
