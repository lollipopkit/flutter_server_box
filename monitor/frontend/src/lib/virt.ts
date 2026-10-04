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
  VirtBackup,
  VirtBackupCompress,
  VirtBackupIssue,
  VirtBackupJob,
  VirtBackupJobEdit,
  VirtBackupMode,
  PveConfigView,
  VirtCloudInitEdit,
  VirtCloudInitState,
  VirtCreateIssue,
  VirtCreateOptions,
  VirtCreateSpec,
  VirtError,
  VirtGuest,
  VirtGuestKind,
  VirtGuestRef,
  VirtGuestState,
  VirtHardware,
  VirtHostKind,
  VirtHwChange,
  VirtHwDisk,
  VirtHwIssue,
  VirtHwNic,
  VirtHwOutcome,
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
      case 'hardware_refused':
        return hwIssueText(detail.issue)
      case 'backup_refused':
        return backupIssueText(detail.issue)
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

export function offerRef(key: string): VirtVolumeRef | undefined {
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

// --- A guest's hardware and settings (`sbm_virt::hardware`) ---

/// Why the agent refused a hardware or settings change
/// (`sbm_virt::hardware::Issue`).
export function hwIssueText(issue: VirtHwIssue): string {
  const ll = get(LL)
  switch (issue) {
    case 'cpu_count':
      return ll.virtHwIssueCpuCount()
    case 'cpu_online':
      return ll.virtHwIssueCpuOnline()
    case 'memory':
      return ll.virtHwIssueMemory()
    case 'memory_min':
      return ll.virtHwIssueMemoryMin()
    case 'disk_shrink':
      return ll.virtHwIssueDiskShrink()
    case 'disk_size':
      return ll.virtHwIssueDiskSize()
    case 'storage_space':
      return ll.virtHwIssueStorageSpace()
    case 'mount_point':
      return ll.virtHwIssueMountPoint()
    case 'boot_empty':
      return ll.virtHwIssueBootEmpty()
    case 'name_invalid':
      return ll.virtHwIssueNameInvalid()
    case 'name_running':
      return ll.virtHwIssueNameRunning()
    case 'description':
      return ll.virtHwIssueDescription()
    case 'mac':
      return ll.virtHwIssueMac()
    case 'stop_first':
      return ll.virtHwIssueStopFirst()
    case 'storage_missing':
      return ll.virtHwIssueStorageMissing()
    case 'device':
      return ll.virtHwIssueDevice()
    case 'volume_in_use':
      return ll.virtHwIssueVolumeInUse()
    case 'media':
      return ll.virtHwIssueMedia()
    case 'not_offered':
      return ll.virtHwIssueNotOffered()
    case 'not_found':
      return ll.virtHwIssueNotFound()
    case 'unsupported':
      return ll.virtHwIssueUnsupported()
  }
}

/// What a change came to, beyond succeeding.
export function outcomeText(outcome: VirtHwOutcome | null): string {
  const ll = get(LL)
  if (outcome?.live_error) return ll.virtHwLiveError({ why: outcome.live_error })
  if (outcome?.volume_kept) return ll.virtHwVolumeKept()
  return ll.virtHwSaved()
}

/// A number as an input holds it (a number input hands back a number, an
/// emptied one null); null for blank or not a number.
export function num(value: string | number | null | undefined): number | null {
  if (value === null || value === undefined) return null
  const text = String(value).trim()
  if (text === '') return null
  const n = Number(text)
  return Number.isFinite(n) ? n : null
}

/// GiB as typed, in bytes; null for nothing typed.
export function gibBytes(value: string | number | null | undefined): number | null {
  const n = num(value)
  return n === null ? null : Math.round(n * 1024 ** 3)
}

/// GiB as typed, in MiB; null for nothing typed.
export function gibMib(value: string | number | null | undefined): number | null {
  const n = num(value)
  return n === null ? null : Math.round(n * 1024)
}

/// MiB as GiB for an input: at most two decimals, no trailing zeros.
export function mibGib(mib: number): string {
  return String(Math.round((mib / 1024) * 100) / 100)
}

/// `list` with the item at `i` moved one place by `dir`; the same order
/// when it would leave the list.
export function moveItem<T>(list: T[], i: number, dir: -1 | 1): T[] {
  const j = i + dir
  if (i < 0 || i >= list.length || j < 0 || j >= list.length) return list
  const next = [...list]
  ;[next[i], next[j]] = [next[j], next[i]]
  return next
}

/// Two changes ask for the same.
export function sameChange(a: VirtHwChange | null, b: VirtHwChange | null): boolean {
  return JSON.stringify(a) === JSON.stringify(b)
}

export interface CpuDraft {
  sockets: string
  cores: string
  /// Empty for all of them.
  online: string
  /// PVE's model; empty where the host decides.
  type: string
}

export function cpuDraft(hw: VirtHardware): CpuDraft {
  return {
    sockets: String(hw.cpu.sockets),
    cores: String(hw.cpu.cores),
    online: hw.cpu.online === null ? '' : String(hw.cpu.online),
    type: hw.cpu.type ?? '',
  }
}

export function cpuChange(d: CpuDraft): VirtHwChange {
  return {
    op: 'set_cpu',
    sockets: Math.floor(num(d.sockets) ?? 0),
    cores: Math.floor(num(d.cores) ?? 0),
    online: num(d.online) === null ? null : Math.floor(num(d.online)!),
    type: d.type === '' ? null : d.type,
  }
}

export interface MemoryDraft {
  gib: string
  /// The balloon's floor or target; empty for none.
  minGib: string
  /// A container's swap.
  swapMib: string
}

export function memoryDraft(hw: VirtHardware): MemoryDraft {
  return {
    gib: mibGib(hw.memory.mib),
    minGib: hw.memory.min_mib === null ? '' : mibGib(hw.memory.min_mib),
    swapMib: hw.memory.swap_mib === null ? '' : String(hw.memory.swap_mib),
  }
}

/// The balloon only where there is one, swap only for a container.
export function memoryChange(d: MemoryDraft, hw: VirtHardware): VirtHwChange {
  const swap = num(d.swapMib)
  return {
    op: 'set_memory',
    mib: gibMib(d.gib) ?? 0,
    min_mib: hw.memory.balloon ? gibMib(d.minGib) : null,
    swap_mib: hw.kind === 'lxc' && swap !== null ? Math.floor(swap) : null,
  }
}

/// A disk's bus and cache as picked; null when neither changed.
export function diskUpdate(disk: VirtHwDisk, bus: string, cache: string): VirtHwChange | null {
  const newBus = bus !== '' && bus !== (disk.bus ?? '') ? bus : null
  const newCache = cache !== '' && cache !== (disk.cache ?? 'default') ? cache : null
  return newBus === null && newCache === null ? null : { op: 'update_disk', key: disk.key, bus: newBus, cache: newCache }
}

export interface NicDraft {
  /// Network id; empty keeps the one it is on.
  network: string
  linkUp: boolean
  firewall: boolean
  model: string
  mac: string
}

export function nicDraft(nic: VirtHwNic): NicDraft {
  return { network: '', linkUp: nic.link_up, firewall: nic.firewall ?? false, model: nic.model ?? '', mac: nic.mac ?? '' }
}

/// Its network, link and (PVE) firewall; null when none changed.
export function nicUpdate(nic: VirtHwNic, d: NicDraft): VirtHwChange | null {
  const firewall = nic.firewall !== null && d.firewall !== nic.firewall ? d.firewall : null
  if (d.network === '' && d.linkUp === nic.link_up && firewall === null) return null
  return { op: 'update_nic', key: nic.key, network: d.network === '' ? null : d.network, link_up: d.linkUp, firewall }
}

/// Its model and MAC; null when neither changed.
export function nicHardware(nic: VirtHwNic, d: NicDraft): VirtHwChange | null {
  const model = d.model !== '' && d.model !== (nic.model ?? '') ? d.model : null
  const typed = d.mac.trim()
  const mac = typed !== '' && typed.toLowerCase() !== (nic.mac ?? '').toLowerCase() ? typed : null
  return model === null && mac === null ? null : { op: 'set_nic_hardware', key: nic.key, model, mac }
}

export interface DisplayDraft {
  protocol: string
  listen: string
  gpu: string
}

export function displayDraft(hw: VirtHardware): DisplayDraft {
  return { protocol: hw.display?.protocol ?? '', listen: hw.display?.listen ?? '', gpu: hw.display?.gpu ?? '' }
}

/// What changed of the console and video card; null when nothing did.
export function displayChange(hw: VirtHardware, d: DisplayDraft): VirtHwChange | null {
  const was = displayDraft(hw)
  const pick = (now: string, before: string) => (now.trim() !== '' && now.trim() !== before ? now.trim() : null)
  const change = { op: 'set_display' as const, protocol: pick(d.protocol, was.protocol), listen: pick(d.listen, was.listen), gpu: pick(d.gpu, was.gpu) }
  return change.protocol === null && change.listen === null && change.gpu === null ? null : change
}

/// The boot list as edited: the devices in the order first, then the rest
/// of the guest's disks and NICs, off.
export function bootDraft(hw: VirtHardware): { key: string; on: boolean }[] {
  const order = hw.boot ?? []
  const rest = [...hw.disks.map((d) => d.key), ...hw.nics.map((n) => n.key)].filter((k) => !order.includes(k))
  return [...order.map((key) => ({ key, on: true })), ...rest.map((key) => ({ key, on: false }))]
}

export function bootOrder(draft: { key: string; on: boolean }[]): string[] {
  return draft.filter((b) => b.on).map((b) => b.key)
}

/// The cloud-init form as typed; [cloudInitEdit] turns it into the request.
export interface CiDraft {
  user: string
  /// A new one; empty keeps the one set.
  password: string
  removePassword: boolean
  sshKeys: string
  hostname: string
  static: boolean
  address: string
  gateway: string
  dns: string
  search: string
  passwordExpires: boolean
}

export function ciDraft(state: VirtCloudInitState): CiDraft {
  return {
    user: state.user,
    password: '',
    removePassword: false,
    sshKeys: state.ssh_keys.join('\n'),
    hostname: state.hostname ?? '',
    static: state.address !== null,
    address: state.address ?? '',
    gateway: state.gateway ?? '',
    dns: state.dns.join(' '),
    search: state.search_domains.join(' '),
    passwordExpires: state.password_expires,
  }
}

/// The values as they are to be, made from the read `state`. libvirt alone
/// has a hostname and an expiring password.
export function cloudInitEdit(d: CiDraft, state: VirtCloudInitState, host: VirtHostKind): VirtCloudInitEdit {
  const values: VirtCloudInitEdit['values'] = { user: d.user.trim(), ssh_keys: lines(d.sshKeys), dns: words(d.dns), search_domains: words(d.search) }
  if (d.password !== '' && !d.removePassword) values.password = d.password
  if (host === 'libvirt' && d.hostname.trim()) values.hostname = d.hostname.trim()
  if (d.static) {
    if (d.address.trim()) values.address = d.address.trim()
    if (d.gateway.trim()) values.gateway = d.gateway.trim()
  }
  return {
    values,
    remove_password: state.password_set && d.removePassword,
    password_expires: host === 'libvirt' && d.passwordExpires,
    revision: state.revision,
  }
}

// --- Backups and backup jobs (`sbm_virt::backup`, PVE only) ---

/// Why the agent refused a backup request (`sbm_virt::backup::Issue`).
export function backupIssueText(issue: VirtBackupIssue): string {
  const ll = get(LL)
  switch (issue) {
    case 'schedule_empty':
      return ll.virtBakIssueScheduleEmpty()
    case 'schedule_invalid':
      return ll.virtBakIssueScheduleInvalid()
    case 'storage':
      return ll.virtBakIssueStorage()
    case 'mode':
      return ll.virtBakIssueMode()
    case 'compress':
      return ll.virtBakIssueCompress()
    case 'guests':
      return ll.virtBakIssueGuests()
    case 'node_offline':
      return ll.virtBakIssueNodeOffline()
    case 'not_stopped':
      return ll.virtBakIssueNotStopped()
    case 'not_found':
      return ll.virtBakIssueNotFound()
    case 'unsupported':
      return ll.virtBakIssueUnsupported()
  }
}

export const BACKUP_MODES: VirtBackupMode[] = ['snapshot', 'suspend', 'stop']
export const BACKUP_COMPRESSIONS: VirtBackupCompress[] = ['zstd', 'lzo', 'gzip', '0']

/// A compression as a button or a summary says it: `0` is none.
export function compressText(compress: string | null): string {
  return !compress || compress === '0' ? get(LL).virtBakCompressNone() : compress
}

/// `snapshot · zstd`: how a job or a backup is taken.
export function modeText(mode: string | null, compress: string | null): string {
  return `${mode || 'snapshot'} · ${compressText(compress)}`
}

/// Newest first; undated last.
export function newestFirst(backups: VirtBackup[]): VirtBackup[] {
  return [...backups].sort((a, b) => (b.created_at ?? -Infinity) - (a.created_at ?? -Infinity) || a.id.localeCompare(b.id))
}

/// The guest's own job among those that take it: the one that takes its
/// VMID and no other guest (`BackupJob::takes_only`). The Plan group edits
/// it; any other job is the datacenter's.
export function ownJob(jobs: VirtBackupJob[], vmid: number | null): VirtBackupJob | null {
  if (vmid === null) return null
  return jobs.find((j) => !j.all && j.pool === null && j.exclude.length === 0 && j.vmids.length === 1 && j.vmids[0] === vmid) ?? null
}

/// Which guests a job takes, in words.
export function selectionText(job: Pick<VirtBackupJob, 'all' | 'vmids' | 'exclude' | 'pool'>): string {
  const ll = get(LL)
  if (job.pool) return ll.virtBakSelPool({ pool: job.pool })
  if (job.all) return job.exclude.length ? ll.virtBakSelAllExcept({ vmids: job.exclude.join(', ') }) : ll.virtBakSelAll()
  return ll.virtBakSelVmids({ vmids: job.vmids.join(', ') })
}

/// VMIDs as typed: separated by spaces or commas, whole numbers only.
export function vmidList(text: string): number[] {
  return words(text)
    .map(Number)
    .filter((n) => Number.isInteger(n) && n > 0)
}

/// The `keep-*` rules a retention is made of, in PVE's order.
export const KEEP_KEYS = ['keep-last', 'keep-hourly', 'keep-daily', 'keep-weekly', 'keep-monthly', 'keep-yearly'] as const
export type KeepKey = (typeof KEEP_KEYS)[number]

/// A retention as edited: a count per rule (empty for none), and what else
/// the string held (`keep-all=1`), kept as it was.
export interface RetentionDraft {
  keep: Record<KeepKey, string>
  extra: string[]
}

export function retentionDraft(prune: string | null): RetentionDraft {
  const keep = Object.fromEntries(KEEP_KEYS.map((k) => [k, ''])) as Record<KeepKey, string>
  const extra: string[] = []
  for (const part of (prune ?? '').split(',').map((p) => p.trim()).filter(Boolean)) {
    const [key, value = ''] = part.split('=', 2)
    if ((KEEP_KEYS as readonly string[]).includes(key.trim())) keep[key.trim() as KeepKey] = value.trim()
    else extra.push(part)
  }
  return { keep, extra }
}

/// PVE's `prune-backups` string; null for none set (the storage's own).
export function pruneString(d: RetentionDraft): string | null {
  const parts = KEEP_KEYS.flatMap((k) => {
    const n = num(d.keep[k])
    return n === null ? [] : [`${k}=${Math.floor(n)}`]
  })
  const all = [...parts, ...d.extra]
  return all.length ? all.join(',') : null
}

/// A retention in words: `last 7 · daily 4`.
export function pruneText(prune: string | null): string {
  const ll = get(LL)
  const d = retentionDraft(prune)
  const names: Record<KeepKey, string> = {
    'keep-last': ll.virtBakKeepLast(),
    'keep-hourly': ll.virtBakKeepHourly(),
    'keep-daily': ll.virtBakKeepDaily(),
    'keep-weekly': ll.virtBakKeepWeekly(),
    'keep-monthly': ll.virtBakKeepMonthly(),
    'keep-yearly': ll.virtBakKeepYearly(),
  }
  const parts = [...KEEP_KEYS.filter((k) => d.keep[k] !== '').map((k) => `${names[k]} ${d.keep[k]}`), ...d.extra]
  return parts.length ? parts.join(' · ') : ll.virtBakRetentionDefault()
}

/// A backup job's editor as typed; [jobEdit] turns it into the request.
export interface JobDraft {
  /// A new job's own id; empty lets PVE name it.
  id: string
  isNew: boolean
  /// Empty: every node.
  node: string
  storage: string
  schedule: string
  mode: VirtBackupMode
  compress: VirtBackupCompress
  enabled: boolean
  selection: 'all' | 'vmids' | 'pool'
  vmids: string
  exclude: string
  pool: string
  comment: string
  notesTemplate: string
  /// Empty keeps what is set (PVE's default for a new job).
  mail: '' | 'always' | 'failure'
  retention: RetentionDraft
}

function isMode(v: string | null): v is VirtBackupMode {
  return (BACKUP_MODES as (string | null)[]).includes(v)
}

function isCompress(v: string | null): v is VirtBackupCompress {
  return (BACKUP_COMPRESSIONS as (string | null)[]).includes(v)
}

/// The editor's draft for `job`, or for a new job (on `storage`).
export function jobDraft(job: VirtBackupJob | null, storage = ''): JobDraft {
  if (!job) {
    return {
      id: '',
      isNew: true,
      node: '',
      storage,
      schedule: '02:00',
      mode: 'snapshot',
      compress: 'zstd',
      enabled: true,
      selection: 'all',
      vmids: '',
      exclude: '',
      pool: '',
      comment: '',
      notesTemplate: '{{guestname}}',
      mail: '',
      retention: retentionDraft(null),
    }
  }
  return {
    id: job.id,
    isNew: false,
    node: job.node ?? '',
    storage: job.storage ?? '',
    schedule: job.schedule ?? '',
    mode: isMode(job.mode) ? job.mode : 'snapshot',
    // PVE leaves `compress` out for none.
    compress: isCompress(job.compress) ? job.compress : '0',
    enabled: job.enabled,
    selection: job.pool ? 'pool' : job.all ? 'all' : 'vmids',
    vmids: job.vmids.join(', '),
    exclude: job.exclude.join(', '),
    pool: job.pool ?? '',
    comment: job.comment ?? '',
    notesTemplate: job.notes_template ?? '',
    mail: job.mail_notification === 'always' || job.mail_notification === 'failure' ? job.mail_notification : '',
    retention: retentionDraft(job.prune),
  }
}

/// The guest's own job as a draft: its VMID and no other guest.
export function ownJobDraft(job: VirtBackupJob | null, vmid: number, storage = ''): JobDraft {
  return { ...jobDraft(job, storage), selection: 'vmids', vmids: String(vmid), exclude: '', pool: '' }
}

/// The request for `d`: the whole job, an empty optional field left out
/// (PVE clears it). Whether the host takes it is the agent's answer.
export function jobEdit(d: JobDraft): VirtBackupJobEdit {
  const edit: VirtBackupJobEdit = {
    is_new: d.isNew,
    storage: d.storage,
    schedule: d.schedule.trim(),
    mode: d.mode,
    compress: d.compress,
    enabled: d.enabled,
    all: d.selection === 'all',
    vmids: d.selection === 'vmids' ? vmidList(d.vmids) : [],
    exclude: d.selection === 'all' ? vmidList(d.exclude) : [],
  }
  const id = d.id.trim()
  if (id) edit.id = id
  if (d.node) edit.node = d.node
  if (d.selection === 'pool' && d.pool.trim()) edit.pool = d.pool.trim()
  if (d.comment.trim()) edit.comment = d.comment.trim()
  if (d.notesTemplate.trim()) edit.notes_template = d.notesTemplate.trim()
  if (d.mail) edit.mail_notification = d.mail
  const prune = pruneString(d.retention)
  if (prune) edit.prune = prune
  return edit
}

/// The names of the backup storages a job on `node` can use: that node's,
/// or with none every node's, once each.
export function storageNames(storages: { name: string; node: string | null }[], node: string): string[] {
  const names = storages.filter((p) => node === '' || p.node === null || p.node === node).map((p) => p.name)
  return [...new Set(names)].sort()
}
