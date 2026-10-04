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
  VirtCreateIssue,
  VirtCreateOptions,
  VirtCreateSpec,
  VirtError,
  VirtGuest,
  VirtGuestKind,
  VirtGuestRef,
  VirtGuestState,
  VirtHostKind,
  VirtIssue,
  VirtOffer,
  VirtPowerAction,
  VirtSnapshot,
  VirtStats,
  VirtVolumeRef,
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
      case 'needs_privilege':
        return ll.virtErrNeedsPrivilege({
          account: detail.account,
          privilege: detail.privilege,
          path: detail.path,
          command: detail.command,
        })
      case 'refused':
        return issueText(detail.issue)
      case 'create_refused':
        return createIssueText(detail.issue)
      case 'apply_touches_management':
        return ll.virtErrApplyManagement({ ifaces: detail.ifaces.join(', ') })
      case 'apply_unreadable':
        return ll.virtErrApplyUnreadable()
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

/// Why the agent refused a storage or network change
/// (`sbm_virt::resource::Issue`).
export function issueText(issue: VirtIssue): string {
  const ll = get(LL)
  switch (issue) {
    case 'name_empty':
      return ll.virtIssueNameEmpty()
    case 'name_invalid':
      return ll.virtIssueNameInvalid()
    case 'name_taken':
      return ll.virtIssueNameTaken()
    case 'source_invalid':
      return ll.virtIssueSourceInvalid()
    case 'target_invalid':
      return ll.virtIssueTargetInvalid()
    case 'cidr_invalid':
      return ll.virtIssueCidrInvalid()
    case 'dhcp_invalid':
      return ll.virtIssueDhcpInvalid()
    case 'subnet_taken':
      return ll.virtIssueSubnetTaken()
    case 'bridge_invalid':
      return ll.virtIssueBridgeInvalid()
    case 'size':
      return ll.virtIssueSize()
    case 'space':
      return ll.virtIssueSpace()
    case 'format':
      return ll.virtIssueFormat()
    case 'in_use':
      return ll.virtIssueInUse()
    case 'shrink':
      return ll.virtIssueShrink()
    case 'host_invalid':
      return ll.virtIssueHostInvalid()
    case 'management_iface':
      return ll.virtIssueManagementIface()
    case 'not_found':
      return ll.virtIssueNotFound()
    case 'unsupported':
      return ll.virtIssueUnsupported()
  }
}

/// Who a guest reference names, by the host's guests: its name, else its
/// VMID or id.
export function refText(ref: VirtGuestRef, guests: VirtGuest[]): string {
  const g = guests.find((g) => (ref.guest_id && g.id === ref.guest_id) || (ref.vmid !== null && g.vmid === ref.vmid))
  const who = g?.name ?? (ref.vmid !== null ? String(ref.vmid) : (ref.guest_id ?? '?'))
  return ref.device ? `${who} (${ref.device})` : who
}

/// Why the agent refused to create, copy, delete or make a template of a
/// guest (`sbm_virt::create::Issue`).
export function createIssueText(issue: VirtCreateIssue): string {
  const ll = get(LL)
  switch (issue) {
    case 'name_empty':
      return ll.virtCrIssueNameEmpty()
    case 'name_invalid':
      return ll.virtCrIssueNameInvalid()
    case 'name_taken':
      return ll.virtCrIssueNameTaken()
    case 'vmid_invalid':
      return ll.virtCrIssueVmidInvalid()
    case 'vmid_taken':
      return ll.virtCrIssueVmidTaken()
    case 'node':
      return ll.virtCrIssueNode()
    case 'cores':
      return ll.virtCrIssueCores()
    case 'memory':
      return ll.virtCrIssueMemory()
    case 'storage':
      return ll.virtCrIssueStorage()
    case 'disk_size':
      return ll.virtCrIssueDiskSize()
    case 'template':
      return ll.virtCrIssueTemplate()
    case 'media':
      return ll.virtCrIssueMedia()
    case 'credentials':
      return ll.virtCrIssueCredentials()
    case 'password':
      return ll.virtCrIssuePassword()
    case 'ssh_keys':
      return ll.virtCrIssueSshKeys()
    case 'image':
      return ll.virtCrIssueImage()
    case 'image_size':
      return ll.virtCrIssueImageSize()
    case 'network':
      return ll.virtCrIssueNetwork()
    case 'secure_boot':
      return ll.virtCrIssueSecureBoot()
    case 'not_offered':
      return ll.virtCrIssueNotOffered()
    case 'ci_user':
      return ll.virtCrIssueCiUser()
    case 'ci_credentials':
      return ll.virtCrIssueCiCredentials()
    case 'ci_hostname':
      return ll.virtCrIssueCiHostname()
    case 'ci_address':
      return ll.virtCrIssueCiAddress()
    case 'ci_gateway':
      return ll.virtCrIssueCiGateway()
    case 'ci_dns':
      return ll.virtCrIssueCiDns()
    case 'ci_search':
      return ll.virtCrIssueCiSearch()
    case 'clone_linked_target':
      return ll.virtCrIssueCloneLinkedTarget()
    case 'clone_storage':
      return ll.virtCrIssueCloneStorage()
    case 'clone_storage_content':
      return ll.virtCrIssueCloneStorageContent()
    case 'clone_storage_shared':
      return ll.virtCrIssueCloneStorageShared()
    case 'clone_node_unknown':
      return ll.virtCrIssueCloneNodeUnknown()
    case 'not_stopped':
      return ll.virtCrIssueNotStopped()
    case 'is_template':
      return ll.virtCrIssueIsTemplate()
    case 'not_found':
      return ll.virtCrIssueNotFound()
    case 'unsupported':
      return ll.virtCrIssueUnsupported()
  }
}

/// The create form as typed: numbers as the inputs hold them (a number
/// input hands back a number despite the type), offers by [offerKey], lists
/// as text. [createSpec] turns it into the request.
export interface CreateDraft {
  kind: VirtGuestKind
  name: string
  /// PVE.
  node: string
  /// PVE; empty takes the next free one.
  vmid: string
  cores: string
  memoryGib: string
  /// Pool id.
  storage: string
  diskGib: string
  /// A VM's: install media or a cloud image.
  source: 'media' | 'image'
  media: string
  image: string
  /// Network id; empty for none.
  network: string
  /// A container's root login.
  password: string
  sshKeys: string
  unprivileged: boolean
  bus: string
  nicModel: string
  uefi: boolean
  secureBoot: boolean
  tpm: boolean
  ci: {
    user: string
    password: string
    sshKeys: string
    hostname: string
    /// A static address; otherwise DHCP.
    static: boolean
    address: string
    gateway: string
    dns: string
    search: string
  }
  start: boolean
}

/// An offer as a select's value.
export function offerKey(o: VirtOffer): string {
  return `${o.pool}\n${o.volume.id}`
}

function offerRef(key: string): VirtVolumeRef | undefined {
  const at = key.indexOf('\n')
  return at < 0 ? undefined : { pool: key.slice(0, at), volume: key.slice(at + 1) }
}

/// One entry per non-blank line (SSH keys).
export function lines(text: string): string[] {
  return text
    .split(/\r?\n/)
    .map((l) => l.trim())
    .filter(Boolean)
}

/// Entries separated by spaces or commas (DNS servers, search domains).
export function words(text: string): string[] {
  return text.split(/[\s,]+/).filter(Boolean)
}

function whole(value: string): number {
  const n = Math.floor(Number(value))
  return Number.isFinite(n) ? n : 0
}

/// Whether a VM is made from a cloud image rather than install media.
export function usesImage(d: CreateDraft, options: VirtCreateOptions): boolean {
  return d.kind === 'qemu' && d.source === 'image' && options.cloud_images
}

/// The request for `d`: trimmed, optional fields omitted when empty, only
/// what applies to its kind and host. Whether the host takes it is the
/// agent's answer.
export function createSpec(d: CreateDraft, host: VirtHostKind, options: VirtCreateOptions): VirtCreateSpec {
  const pve = host === 'pve'
  const lxc = d.kind === 'lxc'
  const image = usesImage(d, options)
  const spec: VirtCreateSpec = {
    kind: d.kind,
    name: d.name.trim(),
    cores: whole(d.cores),
    memory_mib: Math.round((Number(d.memoryGib) || 0) * 1024),
    storage: d.storage,
    disk_gib: whole(d.diskGib),
    ssh_keys: lxc ? lines(d.sshKeys) : [],
    unprivileged: lxc ? d.unprivileged : true,
    uefi: !lxc && d.uefi,
    secure_boot: !lxc && d.uefi && d.secureBoot,
    tpm: !lxc && d.tpm,
    start: d.start,
  }
  if (pve && d.node) spec.node = d.node
  const vmid = String(d.vmid ?? '').trim()
  if (pve && vmid !== '') spec.vmid = whole(vmid)
  const media = offerRef(image ? '' : d.media)
  if (media) spec.media = media
  const img = image ? offerRef(d.image) : undefined
  if (img) spec.image = img
  if (d.network) spec.network = d.network
  if (lxc && d.password !== '') spec.password = d.password
  if (!lxc) {
    if (d.bus) spec.bus = d.bus
    if (d.nicModel) spec.nic_model = d.nicModel
  }
  const ci = d.ci
  const ciTyped = [ci.user, ci.password, ci.sshKeys, ci.hostname, ci.dns, ci.search].some((x) => x.trim() !== '') || ci.static
  if (image && options.cloud_init && ciTyped) {
    spec.cloud_init = { user: ci.user.trim(), ssh_keys: lines(ci.sshKeys), dns: words(ci.dns), search_domains: words(ci.search) }
    if (ci.password !== '') spec.cloud_init.password = ci.password
    if (!pve && ci.hostname.trim()) spec.cloud_init.hostname = ci.hostname.trim()
    if (ci.static) {
      if (ci.address.trim()) spec.cloud_init.address = ci.address.trim()
      if (ci.gateway.trim()) spec.cloud_init.gateway = ci.gateway.trim()
    }
  }
  return spec
}
