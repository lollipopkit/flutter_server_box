/// The panel's half of `/api/v1/virt` that is not drawing: the host's
/// failures and a guest's state in the viewer's language, what a power
/// action is called, and the PVE form's draft.
///
/// What a guest offers and what its state is are the agent's
/// (`sbm_virt::model`); nothing here decides either.
import { get } from 'svelte/store'
import { LL } from '../i18n/i18n-svelte'
import { ApiError } from './api'
import type {
  PveConfigInput,
  PveConfigView,
  VirtError,
  VirtGuest,
  VirtGuestState,
  VirtPowerAction,
  VirtSnapshot,
  VirtStats,
} from '../types'

/// A host's failure (`sbm_virt::error::Error`) as a sentence. The host's own
/// words follow where it gave any.
export function virtErrorText(e: VirtError): string {
  const ll = get(LL)
  const own = e.message?.trim() || null
  const detail = e.detail
  if (detail) {
    switch (detail.code) {
      case 'no_user':
        return ll.virtErrNoUser()
      case 'password_required':
        return ll.virtErrPasswordRequired()
      case 'token_incomplete':
        return ll.virtErrTokenIncomplete()
      case 'otp_required':
        return ll.virtErrOtpRequired()
      case 'otp_empty':
        return ll.virtErrOtpEmpty()
      case 'otp_rejected':
        return ll.virtErrOtpRejected()
      case 'no_privileges':
        return ll.virtErrNoPrivileges({ account: detail.account, command: detail.command })
      case 'task_still_running':
        return ll.virtErrTaskRunning({ node: detail.node, minutes: detail.minutes, upid: detail.upid })
      case 'not_offered':
        return ll.virtErrNotOffered()
      case 'cert_not_presented':
        return ll.virtErrCertNotPresented()
      case 'invalid_body':
      case 'invalid_data':
      case 'missing_ticket':
        return ll.virtErrInvalidResponse()
    }
  }
  const title = (() => {
    switch (e.kind) {
      case 'unreachable':
        return ll.virtErrUnreachable()
      case 'not_configured':
        return ll.virtErrNotConfigured()
      case 'auth_failed':
        return ll.virtErrAuthFailed()
      case 'need_tfa':
        return ll.virtErrOtpRequired()
      case 'cert_unconfirmed':
        return ll.virtErrCertUnconfirmed()
      case 'cert_changed':
        return ll.virtErrCertChanged()
      case 'permission_denied':
        return ll.virtErrPermissionDenied()
      case 'invalid_response':
        return ll.virtErrInvalidResponse()
      case 'action_failed':
        return ll.virtErrActionFailed()
      case 'unsupported':
        return ll.virtErrNotOffered()
      case 'not_installed':
        return ll.virtErrNotInstalled()
      case 'sudo_password_required':
        return ll.virtErrSudoRequired()
      case 'sudo_password_rejected':
        return ll.virtErrSudoRejected()
      default:
        return null
    }
  })()
  if (title && own && own !== title) return `${title}\n${own}`
  return title ?? own ?? e.kind
}

/// The agent's own refusal of a request (not a host's failure).
export function virtRequestText(e: unknown): string {
  if (!(e instanceof ApiError)) return e instanceof Error ? e.message : String(e)
  const ll = get(LL)
  switch (e.message) {
    case 'invalidAddr':
      return ll.pveInvalidAddr()
    case 'invalidUsername':
      return ll.pveInvalidUsername()
    case 'invalidTokenId':
      return ll.pveInvalidTokenId()
    case 'invalidCertificate':
      return ll.bmcInvalidCertificate()
    default:
      return e.message
  }
}

export function stateText(state: VirtGuestState): string {
  const ll = get(LL)
  switch (state) {
    case 'running':
      return ll.virtStateRunning()
    case 'paused':
      return ll.virtStatePaused()
    case 'stopped':
      return ll.virtStateStopped()
    case 'starting':
      return ll.virtStateStarting()
    case 'stopping':
      return ll.virtStateStopping()
    case 'rebooting':
      return ll.virtStateRebooting()
    case 'migrating':
      return ll.virtStateMigrating()
    case 'backup':
      return ll.virtStateBackup()
    default:
      return ll.virtStateUnknown()
  }
}

export function stateTone(state: VirtGuestState): 'success' | 'warning' | 'neutral' {
  switch (state) {
    case 'running':
      return 'success'
    case 'stopped':
      return 'neutral'
    default:
      return 'warning'
  }
}

/// The dot before a row: `bg-*` utility per tone.
export function stateDot(state: VirtGuestState): string {
  switch (stateTone(state)) {
    case 'success':
      return 'bg-success'
    case 'warning':
      return 'bg-warning'
    default:
      return 'bg-faint-fg'
  }
}

export function actionText(action: VirtPowerAction): string {
  const ll = get(LL)
  switch (action) {
    case 'start':
      return ll.virtActStart()
    case 'shutdown':
      return ll.virtActShutdown()
    case 'reboot':
      return ll.virtActReboot()
    case 'force_stop':
      return ll.virtActForceStop()
    case 'suspend':
      return ll.virtActSuspend()
    case 'resume':
      return ll.virtActResume()
  }
}

/// Loses the guest's unsaved state, so it is asked about first.
export function destructive(action: VirtPowerAction): boolean {
  return action === 'force_stop'
}

/// The order a header shows a guest's actions in, gentlest first.
const ACTION_ORDER: VirtPowerAction[] = ['start', 'resume', 'shutdown', 'reboot', 'suspend', 'force_stop']

export function orderedActions(guest: VirtGuest): VirtPowerAction[] {
  return ACTION_ORDER.filter((a) => guest.actions.includes(a))
}

/// `3d 4h`, `5h 12m`, `42m`, `30s`.
export function fmtUptime(seconds: number): string {
  const d = Math.floor(seconds / 86_400)
  const h = Math.floor((seconds % 86_400) / 3_600)
  const m = Math.floor((seconds % 3_600) / 60)
  if (d > 0) return `${d}d ${h}h`
  if (h > 0) return `${h}h ${m}m`
  if (m > 0) return `${m}m`
  return `${Math.floor(seconds)}s`
}

/// A guest's id as the list shows it beside its name: PVE's VMID, libvirt's
/// UUID shortened.
export function shortId(guest: VirtGuest): string {
  return guest.vmid !== null ? String(guest.vmid) : guest.id.slice(0, 8)
}

/// What the running guests hold of the host: vCPUs and memory assigned, and
/// how many run.
export function allocation(guests: VirtGuest[]): { running: number; total: number; vcpu: number; mem: number } {
  const real = guests.filter((g) => !g.template)
  const active = real.filter((g) => g.state !== 'stopped' && g.state !== 'unknown')
  return {
    running: active.length,
    total: real.length,
    vcpu: active.reduce((n, g) => n + (g.vcpu ?? 0), 0),
    mem: active.reduce((n, g) => n + (g.mem_bytes ?? 0), 0),
  }
}

/// The readings of this session for one guest, kept by the page between
/// loads (the host keeps none the panel reads yet).
export const HISTORY_LEN = 60

export function pushSample(history: VirtStats[], sample: VirtStats): VirtStats[] {
  const last = history.at(-1)
  if (last && last.at === sample.at) return history
  const next = [...history, sample]
  return next.length > HISTORY_LEN ? next.slice(next.length - HISTORY_LEN) : next
}

/// The form's draft from what is stored: secrets kept (`null`).
export function pveDraft(view: PveConfigView | null): PveConfigInput {
  return {
    addr: view?.addr ?? 'https://127.0.0.1:8006',
    auth: view?.auth ?? 'token',
    username: view?.username ?? null,
    password: null,
    token_id: view?.token_id ?? null,
    token_secret: null,
    cert_sha256: view?.cert_sha256 ?? null,
  }
}

/// [snapshots] depth-first from the roots, each with its depth: how the list
/// draws a tree without drawing one. Siblings oldest first, undated last; a
/// snapshot whose parent is not listed is a root.
export function snapshotTree(snapshots: VirtSnapshot[]): [VirtSnapshot, number][] {
  const names = new Set(snapshots.map((s) => s.name))
  const children = new Map<string | null, VirtSnapshot[]>()
  for (const s of snapshots) {
    const key = s.parent && names.has(s.parent) && s.parent !== s.name ? s.parent : null
    children.set(key, [...(children.get(key) ?? []), s])
  }
  const byTime = (a: VirtSnapshot, b: VirtSnapshot) => {
    if (a.created_at === null) return b.created_at === null ? a.name.localeCompare(b.name) : 1
    if (b.created_at === null) return -1
    return a.created_at - b.created_at || a.name.localeCompare(b.name)
  }
  for (const list of children.values()) list.sort(byTime)
  const out: [VirtSnapshot, number][] = []
  const seen = new Set<string>()
  const walk = (parent: string | null, depth: number) => {
    for (const s of children.get(parent) ?? []) {
      if (seen.has(s.name)) continue
      seen.add(s.name)
      out.push([s, depth])
      walk(s.name, depth + 1)
    }
  }
  walk(null, 0)
  for (const s of snapshots) {
    if (!seen.has(s.name)) {
      seen.add(s.name)
      out.push([s, 0])
      walk(s.name, 1)
    }
  }
  return out
}
