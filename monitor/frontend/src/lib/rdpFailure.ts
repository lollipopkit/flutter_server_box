/// Why an RDP session did not come up, in the viewer's own language.
///
/// The RDP client reports a failure as a typed error rather than as a sentence:
/// `kind()` is a small enum and, for the kind that carries one, an
/// `RDCleanPathDetails` beside it. The agent answers a refusal of its own with
/// an RDCleanPath **error PDU**, so what arrives here is the agent's answer as
/// the client decoded it — an HTTP status for a request the agent would not
/// take, or the TLS alert from a session it could not open with the RDP server.
/// A negotiation the *server* refused arrives as its own kind instead, because
/// the client decodes that PDU into the failure code the server sent.
///
/// Every failure also carries the client's own error chain, and that is not
/// decoration: the chain names the one thing the kind cannot, which is what the
/// RDP server said — "server requires Enhanced RDP Security with CredSSP" is a
/// negotiation failure and so is "server only supports Standard RDP Security",
/// and they call for different things. It is English, like the agent's own
/// messages elsewhere in this panel.
///
/// A word neither table knows falls back to the panel's own "the connection
/// ended": a kind or a status added since would otherwise be reported as the
/// one before it.
import { get } from 'svelte/store'
import { LL } from '../i18n/i18n-svelte'
import type { RDCleanPathDetails } from '@devolutions/iron-remote-desktop'

/// The error kinds, restated.
///
/// `@devolutions/iron-remote-desktop` declares `IronErrorKind` in its `.d.ts`
/// as an exported enum and its bundle exports only `Config`, `ConfigBuilder`
/// and `default` — the enum is built and then dropped, so `import
/// { IronErrorKind }` type-checks and fails at runtime. `kind()` is what the
/// wasm returns, and a renumbering upstream would silently phrase every
/// failure as the one before it, which is why `tests/rdpFailure.test.ts` reads
/// the numbers back off the installed `.d.ts`.
export const KIND = {
  General: 0,
  WrongPassword: 1,
  LogonFailure: 2,
  AccessDenied: 3,
  RDCleanPath: 4,
  ProxyConnect: 5,
  NegotiationFailure: 6,
} as const

/// A failure, ready to draw: the panel's sentence over the client's own words.
export interface RdpFailure {
  message: string
  /// The client's error chain, empty when the error carried none.
  detail: string
}

export function rdpFailureText(error: unknown): RdpFailure {
  const ll = get(LL)
  const backtrace = call(error, 'backtrace')
  const detail = typeof backtrace === 'string' ? backtrace : ''

  switch (kindOf(error)) {
    // Nothing was reached: the client could not open the agent's socket at all,
    // which is the panel's own network, its origin, or the agent being down —
    // and not anything the RDP server did.
    case KIND.ProxyConnect:
      return { message: ll.desktopRdpProxy(), detail }
    case KIND.NegotiationFailure:
      return { message: ll.desktopRdpNegotiation(), detail }
    case KIND.WrongPassword:
    case KIND.LogonFailure:
    case KIND.AccessDenied:
      return { message: ll.desktopRdpCredentials(), detail }
    case KIND.RDCleanPath: {
      const details = detailsOf(error)
      // 502 is the agent's own answer for a server it could not open a session
      // with, and an alert code is the TLS handshake with that server failing —
      // both are "the agent did not get through", and the chain above says
      // which. Anything else is the agent refusing the *request*: a bad ticket,
      // the grant turned off, a destination it will not parse.
      if (details?.httpStatusCode === 502 || details?.tlsAlertCode !== undefined) {
        return { message: ll.desktopRdpUnreachable(), detail }
      }
      return { message: ll.desktopRdpRefused(), detail }
    }
    default:
      return { message: ll.desktopUnreachable(), detail }
  }
}

/// One sentence and the client's own words under it, as the page's error card
/// draws them — it is `whitespace-pre-wrap`, so the break is the separator.
export function rdpFailureSentence(failure: RdpFailure): string {
  return failure.detail ? `${failure.message}\n${failure.detail}` : failure.message
}

/// `kind()`'s answer, or `undefined` for anything that is not the client's own
/// error. Duck-typed rather than `instanceof`: the class is built inside the
/// wasm module, so the constructor is not something this bundle can hold a
/// reference to.
///
/// Every read of the error goes through `call` rather than reaching for the
/// method directly, because a wasm object is freed once its session is gone and
/// a call on one throws instead of answering — which is reachable here, since
/// the viewer reports a failure after the session it belonged to is over.
function kindOf(error: unknown): number | undefined {
  const kind = call(error, 'kind')
  return typeof kind === 'number' ? kind : undefined
}

function detailsOf(error: unknown): RDCleanPathDetails | undefined {
  const details = call(error, 'rdcleanpathDetails')
  return typeof details === 'object' && details !== null
    ? (details as RDCleanPathDetails)
    : undefined
}

/// Reads a method off the error and calls it, answering `undefined` when there
/// is none to call or it refuses to answer. A failure to describe a failure is
/// not worth a second one.
function call(error: unknown, method: string): unknown {
  if (typeof error !== 'object' || error === null) return undefined
  const fn = Reflect.get(error, method)
  if (typeof fn !== 'function') return undefined
  try {
    return fn.call(error) as unknown
  } catch {
    return undefined
  }
}
