import { describe, it, expect } from 'vitest'
import { i18nObject } from '../i18n/i18n-util'
import { mcpNotices } from '../components/stack/notices'
import type { StackManifest } from '../types'

const manifest = (mcp: StackManifest['mcp']) => ({ source: 'https://example.com/app', notices: [], mcp }) as unknown as StackManifest

describe("an app's MCP servers in the deploy dialog", () => {
  it('says whose code a sidecar is, and that a community one holds the credential', () => {
    const ll = i18nObject('en')
    const lines = mcpNotices(
      manifest([
        { port: 'port', path: '/api/mcp', publisher: 'builtin' },
        { port: 'mcp', path: '/mcp', publisher: 'community', service: 'mcp', source: 'https://example.com/mcp' },
      ]),
      ll,
    )
    expect(lines).toHaveLength(2)
    expect(lines[0]).toBe("Agent mode connects to the app's own MCP server.")
    expect(lines[1]).toContain("holding this app's credential")
    expect(lines[1]).toContain('https://example.com/mcp')
  })

  it('says nothing for an app without one, or from an older agent', () => {
    const ll = i18nObject('en')
    expect(mcpNotices(manifest([]), ll)).toEqual([])
    expect(mcpNotices(manifest(undefined), ll)).toEqual([])
  })
})
