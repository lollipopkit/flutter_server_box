/// Guest hardware, settings, and cloud-init draft helpers (`sbm_virt::hardware`).

import { get } from 'svelte/store'
import { LL } from '../i18n/i18n-svelte'
import type {
  VirtCloudInitEdit,
  VirtCloudInitState,
  VirtHardware,
  VirtHostKind,
  VirtHwChange,
  VirtHwDisk,
  VirtHwIssue,
  VirtHwNic,
  VirtHwOutcome,
} from '../types'
import { gibMib, lines, mibGib, num, words } from './virtText'

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
  const online = num(d.online)
  return {
    op: 'set_cpu',
    sockets: Math.floor(num(d.sockets) ?? 0),
    cores: Math.floor(num(d.cores) ?? 0),
    online: online === null ? null : Math.floor(online),
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
