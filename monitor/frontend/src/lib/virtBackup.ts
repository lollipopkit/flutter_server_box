/// Backups and backup-job helpers (`sbm_virt::backup`, PVE only).

import { get } from 'svelte/store'
import { LL } from '../i18n/i18n-svelte'
import type {
  VirtBackup,
  VirtBackupCompress,
  VirtBackupIssue,
  VirtBackupJob,
  VirtBackupJobEdit,
  VirtBackupMode,
} from '../types'
import { num, words } from './virtText'

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
  return [...new Set(names)].sort((a, b) => a.localeCompare(b))
}
