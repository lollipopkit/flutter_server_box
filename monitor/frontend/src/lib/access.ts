/// What the signed-in account may do on an agent, asked of `/capabilities`.
///
/// The agent has one account, which may do what the system account it runs
/// as may do. The one question is whether it may act over this link:
/// `access.ok` false (plaintext, not loopback) leaves only reading. Each
/// function here answers it for one page.

import type { AccessWhy, Capabilities, MachineFeature } from '../types'
import { errorText } from './errorText'
import type { TranslationFunctions } from '../i18n/i18n-types'
import { ApiError } from './api'

/// Whether the account may act over this link. False until the capabilities
/// are in.
export function canAct(caps: Capabilities | undefined): boolean {
  return caps?.access?.ok === true
}

/// Whether a machine-management page is offered: the agent serves it and the
/// account may act over this link. Hidden otherwise, as the terminal and
/// files are — the agent re-checks on every request either way.
export function machineAccess(caps: Capabilities | undefined, feature: MachineFeature): boolean {
  return caps?.features?.includes(feature) === true && canAct(caps)
}

export interface PageAccess {
  available: boolean
  /// Why not, when the agent said.
  why?: AccessWhy
}

/// The terminal page's question. Capabilities not yet in are not read as a
/// refusal — the agent decides in the end.
export function terminalAccess(caps: Capabilities | undefined): PageAccess {
  const refused = caps?.access?.ok === false
  return { available: !refused, why: refused ? caps?.access?.why : undefined }
}

/// The file page's question: browsing and changing go together.
export const filesAccess = terminalAccess

/// The Status app's question: which entries go in its toolbar, and whether it
/// says this link can only watch.
export function dashboardAccess(caps: Capabilities | undefined): {
  terminal: boolean
  files: boolean
  /// Nothing beyond reading — no terminal, files, commands or forwards.
  viewOnly: boolean
} {
  const ok = canAct(caps)
  return { terminal: ok, files: ok, viewOnly: caps !== undefined && !ok }
}

// ---------------------------------------------------------------------------
// Errors
// ---------------------------------------------------------------------------

/// What went wrong with a change, when the agent said in a way worth a
/// sentence of its own; null for anything else, whose own message is the
/// best there is.
export type AccessProblem = 'reauth' | 'forbidden'

export function accessProblem(e: unknown): AccessProblem | null {
  if (!(e instanceof ApiError)) return null
  switch (e.code) {
    case 'reauth':
    case 'forbidden':
      return e.code
    default:
      return null
  }
}

/// [e] as a sentence: the agent's own message, unless its code says
/// something this panel can say better.
export function accessMessage(e: unknown, LL: TranslationFunctions): string {
  switch (accessProblem(e)) {
    case 'reauth':
      return LL.accessErrReauth()
    case 'forbidden':
      return LL.whyInsecureTransport()
    default:
      return errorText(e)
  }
}

/// Why the account may not act here, for the page that needed it.
export function whyText(why: AccessWhy | undefined, LL: TranslationFunctions): string {
  switch (why) {
    case 'insecure_transport':
      return LL.whyInsecureTransport()
    default:
      return LL.whyReadOnly()
  }
}
