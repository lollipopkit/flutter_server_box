/// What the signed-in account may do on an agent, asked of `/capabilities`.
///
/// Two agents answer this question: one with roles, which reports `me` and a
/// `grants` entry per grant for the caller, and one from before them, which
/// reports `remote_access` for everyone alike. Each function here answers one
/// question a page has, for both — an older agent getting exactly the answer
/// it got before roles existed.

import type {
  Capabilities,
  FilesMode,
  GrantName,
  GrantStatus,
  GrantWhy,
  MachineFeature,
  Role,
  RoleGrants,
} from '../types'
import type { TranslationFunctions } from '../i18n/i18n-types'
import { ApiError } from './api'

/// Whether the caller administers this agent: accounts, roles, settings.
///
/// `undefined` until the capabilities are in. An agent from before roles has
/// no such thing as a non-admin — every login could change everything — so it
/// answers true.
/// Whether a machine-management page is offered: the agent serves it and the
/// caller's role may use it over this link. Hidden otherwise, as the
/// terminal and files are — the agent re-checks on every request either way.
export function machineAccess(
  caps: Capabilities | undefined,
  feature: MachineFeature,
  grant: GrantName = 'shell',
): boolean {
  if (!caps?.features?.includes(feature)) return false
  return caps.grants?.[grant]?.ok === true
}

export function isAdmin(caps: Capabilities | undefined): boolean | undefined {
  if (caps === undefined) return undefined
  return caps.me ? caps.me.admin : true
}

export interface TerminalAccess {
  /// Some terminal can be opened: through sshd, or as the agent's account.
  available: boolean
  /// A shell straight from the panel session, with no SSH credentials.
  direct: boolean
  /// The terminal that signs in to sshd with an SSH account.
  ssh: boolean
  /// Why neither is there, on an agent with roles.
  why?: GrantWhy
}

/// The terminal page's question.
///
/// An agent before roles: `terminal` is the gate for both kinds, and an
/// agent that says nothing about it is not read as a refusal — the agent
/// decides in the end.
export function terminalAccess(caps: Capabilities | undefined): TerminalAccess {
  const g = caps?.grants
  if (!g) {
    const available = caps?.remote_access?.terminal !== false
    return { available, direct: caps?.remote_access?.full_access === true, ssh: available }
  }
  const available = g.shell.ok || g.ssh_terminal.ok
  return {
    available,
    direct: g.shell.ok,
    ssh: g.ssh_terminal.ok,
    // The SSH terminal's reason first: it is the one that does not hand out a
    // shell, so it is what someone without a grant would be offered.
    why: available ? undefined : (g.ssh_terminal.why ?? g.shell.why),
  }
}

export interface FilesAccess {
  available: boolean
  /// Whether anything can be changed: upload, new folder, rename, chmod,
  /// delete. A read-only role browses and downloads.
  write: boolean
  why?: GrantWhy
}

/// The file page's question. An agent before roles had no read-only mode.
export function filesAccess(caps: Capabilities | undefined): FilesAccess {
  const g = caps?.grants
  if (!g) {
    const available = caps?.remote_access?.files !== false
    return { available, write: available }
  }
  return {
    available: g.files.ok,
    write: g.files.ok && g.files.mode !== 'read',
    why: g.files.ok ? undefined : g.files.why,
  }
}

/// The Status app's question: which entries go in its toolbar, and whether it
/// says this account can only watch.
///
/// Truthy rather than `!== false` for an agent before roles, which is what the
/// dashboard asked then: an entry it cannot vouch for is not offered there.
export function dashboardAccess(caps: Capabilities | undefined): {
  terminal: boolean
  files: boolean
  /// Nothing beyond reading — no terminal, files, commands or forwards.
  viewOnly: boolean
} {
  const g = caps?.grants
  if (!g) {
    const terminal = caps?.remote_access?.terminal === true
    const files = caps?.remote_access?.files === true
    return { terminal, files, viewOnly: caps !== undefined && !terminal && !files }
  }
  const terminal = g.shell.ok || g.ssh_terminal.ok
  const all: GrantStatus[] = [g.shell, g.ssh_terminal, g.files, g.connect, g.listen]
  if (g.virt) all.push(g.virt)
  return { terminal, files: g.files.ok, viewOnly: !all.some((s) => s.ok) }
}

// ---------------------------------------------------------------------------
// The role editor
// ---------------------------------------------------------------------------

/// A role as the editor holds it: every option a field, whether or not its
/// grant is on, so that switching a grant off and on again keeps what was
/// typed.
export interface RoleDraft {
  name: string
  admin: boolean
  builtin: boolean
  shell: boolean
  ssh_terminal: boolean
  files: 'none' | FilesMode
  connect: boolean
  /// One destination per line (commas also separate).
  connectAllow: string
  listen: boolean
  listenPublic: boolean
  /// `""` for any, `"8080"` or `"1024-65535"`.
  listenPorts: string
  /// Undefined when the agent does not know the grant: neither shown nor
  /// sent, since such an agent refuses a role that names it.
  virt: boolean | undefined
}

/// [virtKnown]: whether the agent being edited knows `virt` — see
/// [RoleDraft.virt].
export function emptyDraft(virtKnown = false): RoleDraft {
  return {
    name: '',
    admin: false,
    builtin: false,
    shell: false,
    ssh_terminal: false,
    files: 'none',
    connect: false,
    connectAllow: '',
    listen: false,
    listenPublic: false,
    listenPorts: '',
    virt: virtKnown ? false : undefined,
  }
}

export function draftFromRole(role: Role): RoleDraft {
  const g = role.grants
  const ports = g.listen?.ports
  return {
    name: role.name,
    admin: role.admin,
    builtin: role.builtin,
    shell: g.shell,
    ssh_terminal: g.ssh_terminal,
    files: g.files?.mode ?? 'none',
    connect: g.connect !== null,
    connectAllow: (g.connect?.allow ?? []).join('\n'),
    listen: g.listen !== null,
    listenPublic: g.listen?.public ?? false,
    listenPorts: ports ? (ports[0] === ports[1] ? `${ports[0]}` : `${ports[0]}-${ports[1]}`) : '',
    virt: g.virt,
  }
}

/// What a draft fails on, for the editor to name.
export type DraftError = 'name' | 'ports'

const ROLE_NAME = /^[a-z0-9_-]{1,32}$/

/// `""` for any port (null), a single port, or `lo-hi`; `'invalid'` for
/// anything else, or for a port outside 1–65535.
export function parsePorts(text: string): [number, number] | null | 'invalid' {
  const t = text.trim()
  if (t === '') return null
  const m = /^(\d{1,5})(?:\s*-\s*(\d{1,5}))?$/.exec(t)
  if (!m) return 'invalid'
  const lo = Number(m[1])
  const hi = m[2] === undefined ? lo : Number(m[2])
  if (lo < 1 || hi > 65535 || lo > hi) return 'invalid'
  return [lo, hi]
}

/// The draft as the agent stores it, or what is wrong with it.
///
/// A grant switched off is `null` whatever its fields say: the options of a
/// grant the role does not hold are not part of the role.
export function roleFromDraft(draft: RoleDraft): Role | { error: DraftError } {
  const name = draft.name.trim()
  if (!ROLE_NAME.test(name)) return { error: 'name' }
  let listen: RoleGrants['listen'] = null
  if (draft.listen) {
    const ports = parsePorts(draft.listenPorts)
    if (ports === 'invalid') return { error: 'ports' }
    listen = { public: draft.listenPublic, ports }
  }
  const allow = draft.connectAllow
    .split(/[\n,]/)
    .map((s) => s.trim())
    .filter((s) => s !== '')
  return {
    name,
    admin: draft.admin,
    builtin: draft.builtin,
    grants: {
      shell: draft.shell,
      ssh_terminal: draft.ssh_terminal,
      files: draft.files === 'none' ? null : { mode: draft.files },
      connect: draft.connect ? { allow } : null,
      listen,
      ...(draft.virt === undefined ? {} : { virt: draft.virt }),
    },
  }
}

/// The grants a role holds, by name, for a one-line summary of it.
export function grantNames(grants: RoleGrants): string[] {
  const out: string[] = []
  if (grants.shell) out.push('shell')
  if (grants.ssh_terminal) out.push('ssh_terminal')
  if (grants.files) out.push(`files:${grants.files.mode}`)
  if (grants.connect) out.push('connect')
  if (grants.listen) out.push('listen')
  if (grants.virt) out.push('virt')
  return out
}

// ---------------------------------------------------------------------------
// Errors
// ---------------------------------------------------------------------------

/// What went wrong with an account or role change, when the agent said in a
/// way worth a sentence of its own; null for anything else, whose own message
/// is the best there is.
export type AccessProblem = 'reauth' | 'last_admin' | 'conflict' | 'forbidden'

export function accessProblem(e: unknown): AccessProblem | null {
  if (!(e instanceof ApiError)) return null
  switch (e.code) {
    case 'reauth':
    case 'last_admin':
    case 'conflict':
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
    case 'last_admin':
      return LL.accessErrLastAdmin()
    case 'conflict':
      return LL.accessErrConflict()
    case 'forbidden':
      return LL.accessErrForbidden()
    default:
      return e instanceof Error ? e.message : String(e)
  }
}

/// Why a grant is not usable, for the page that needed it.
export function whyText(why: GrantWhy | undefined, LL: TranslationFunctions): string {
  switch (why) {
    case 'insecure_transport':
      return LL.whyInsecureTransport()
    case 'not_configured':
      return LL.whyNotConfigured()
    default:
      return LL.whyNotGranted()
  }
}
