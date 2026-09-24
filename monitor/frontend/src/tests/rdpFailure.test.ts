import { get } from 'svelte/store'
import { describe, expect, it } from 'vitest'
// The installed client's own two files — the `types` and `main` entries of its
// package.json — so the table in `rdpFailure.ts` is checked against what this
// build actually has rather than against a copy of it. Imported rather than
// read through `node:fs`, which this project's tsconfig has no types for. A
// file that moved upstream fails the import, which is louder than a check that
// quietly stops running.
import declarations from '@devolutions/iron-remote-desktop/index.d.ts?raw'
import bundle from '@devolutions/iron-remote-desktop/iron-remote-desktop.js?raw'
import { LL } from '../i18n/i18n-svelte'
import { KIND, rdpFailureSentence, rdpFailureText } from '../lib/rdpFailure'

/// An enum's members as numbers, straight out of the `.d.ts`.
function enumMembers(name: string): Record<string, number> {
  const body = new RegExp(`export declare enum ${name} \\{([^}]*)\\}`).exec(declarations)?.[1]
  if (!body) throw new Error(`${name} is not declared in the client's types`)
  return Object.fromEntries([...body.matchAll(/(\w+)\s*=\s*(\d+)/g)].map((m) => [m[1], Number(m[2])]))
}

/// What the client throws, as far as anything outside the wasm module can tell:
/// three methods and nothing else. Duck-typed here for the same reason
/// `rdpFailure.ts` reads it that way — the class is built inside the module.
function clientError(kind: number, backtrace = 'ironrdp: server requires CredSSP') {
  return {
    kind: () => kind,
    backtrace: () => backtrace,
    rdcleanpathDetails: () => undefined,
  }
}

function withDetails(kind: number, details: Record<string, number>) {
  return { ...clientError(kind), rdcleanpathDetails: () => details }
}

const ll = get(LL)

describe('the error kinds', () => {
  it('matches the client build in use', () => {
    // A renumbering upstream would phrase every failure as the one before it
    // and nothing else would notice.
    expect(KIND).toEqual(enumMembers('IronErrorKind'))
  })

  it('is a table because the bundle exports no such enum', () => {
    // `IronErrorKind` is declared as an exported enum, so importing it
    // type-checks — and the bundle exports `Config`, `ConfigBuilder` and
    // `default` only, so the import would throw at runtime. This is what makes
    // the table a copy rather than an alias.
    const exported = /export\s*\{([^}]*)\}\s*;?\s*$/.exec(bundle.trim())?.[1] ?? ''
    expect(exported).not.toBe('')
    expect(exported).toContain('Config')
    expect(exported).not.toContain('IronErrorKind')
    expect(bundle).not.toContain('IronErrorKind')
  })
})

describe('rdpFailureText', () => {
  it('names the client\'s own connection failure as the panel\'s', () => {
    // The client could not open the agent's socket at all, so this is the
    // panel's network or the agent's origin check — nothing the desktop did.
    expect(rdpFailureText(clientError(KIND.ProxyConnect)).message).toBe(ll.desktopRdpProxy())
  })

  it('tells the agent failing to reach the desktop from the agent refusing the request', () => {
    // 502 is the agent's answer for a desktop it could not open a session with,
    // and an alert code is that session's TLS handshake failing.
    expect(rdpFailureText(withDetails(KIND.RDCleanPath, { httpStatusCode: 502 })).message).toBe(
      ll.desktopRdpUnreachable(),
    )
    expect(rdpFailureText(withDetails(KIND.RDCleanPath, { tlsAlertCode: 40 })).message).toBe(
      ll.desktopRdpUnreachable(),
    )
    // Anything else is the agent refusing the request itself: a spent ticket,
    // the grant turned off, a destination it will not parse.
    expect(rdpFailureText(withDetails(KIND.RDCleanPath, { httpStatusCode: 400 })).message).toBe(
      ll.desktopRdpRefused(),
    )
    expect(rdpFailureText(clientError(KIND.RDCleanPath)).message).toBe(ll.desktopRdpRefused())
  })

  it('separates what the desktop refused from how it refused', () => {
    // A security the desktop will not negotiate and credentials it rejected are
    // both answers from the desktop, and the operator's next move differs.
    expect(rdpFailureText(clientError(KIND.NegotiationFailure)).message).toBe(
      ll.desktopRdpNegotiation(),
    )
    for (const kind of [KIND.WrongPassword, KIND.LogonFailure, KIND.AccessDenied]) {
      expect(rdpFailureText(clientError(kind)).message).toBe(ll.desktopRdpCredentials())
    }
  })

  it('falls back rather than reporting the kind before it', () => {
    // `General`, and any kind added since this build, which is a word the table
    // does not know and must not guess at.
    expect(rdpFailureText(clientError(KIND.General)).message).toBe(ll.desktopUnreachable())
    expect(rdpFailureText(clientError(99)).message).toBe(ll.desktopUnreachable())
  })

  it('keeps the client\'s own words, which name what the kind cannot', () => {
    const failure = rdpFailureText(clientError(KIND.NegotiationFailure, 'ironrdp: no common security'))
    expect(failure.detail).toBe('ironrdp: no common security')
    expect(rdpFailureSentence(failure)).toBe(`${ll.desktopRdpNegotiation()}\nironrdp: no common security`)
  })

  it('answers one sentence when the client said nothing', () => {
    const failure = rdpFailureText(clientError(KIND.ProxyConnect, ''))
    expect(failure.detail).toBe('')
    expect(rdpFailureSentence(failure)).toBe(ll.desktopRdpProxy())
  })

  it('describes a thrown value that is not the client\'s error', () => {
    // Anything may be thrown, and a failure to describe a failure is not worth
    // a second one.
    expect(rdpFailureText('boom')).toEqual({ message: ll.desktopUnreachable(), detail: '' })
    expect(rdpFailureText(null)).toEqual({ message: ll.desktopUnreachable(), detail: '' })
    expect(rdpFailureText(new Error('boom')).detail).toBe('')
  })

  it('survives a client object whose wasm has already been freed', () => {
    // A freed wasm object throws on every call rather than returning, and the
    // viewer can reach here after its session is gone.
    const freed = {
      kind: () => {
        throw new Error('null pointer passed to rust')
      },
      backtrace: () => {
        throw new Error('null pointer passed to rust')
      },
      rdcleanpathDetails: () => {
        throw new Error('null pointer passed to rust')
      },
    }
    expect(rdpFailureText(freed).detail).toBe('')
  })
})
