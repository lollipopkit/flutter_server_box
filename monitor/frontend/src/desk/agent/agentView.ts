/// How Agent mode names and colours what the agent reports: an area as the
/// app it is about, a status as its glyph and tone, a duration in words.

import type { TranslationFunctions } from '../../i18n/i18n-types'
import type { IconTone } from '../lk/AppIcon.svelte'
import type { Area, Flow, PendingKind, StepState } from '../../lib/agentApi'

export interface AreaLook {
  glyph: string
  tone: IconTone
  name: (LL: TranslationFunctions) => string
}

/// Each area as the desk app it is about.
export const AREA: Record<Area, AreaLook> = {
  status: { glyph: 'monitoring', tone: 'berry', name: (LL) => LL.deskAgentAreaStatus() },
  process: { glyph: 'memory', tone: 'ink', name: (LL) => LL.deskAgentAreaProcess() },
  service: { glyph: 'settings_suggest', tone: 'bright', name: (LL) => LL.deskAgentAreaService() },
  container: { glyph: 'deployed_code', tone: 'pale', name: (LL) => LL.deskAgentAreaContainer() },
  files: { glyph: 'folder', tone: 'soft', name: (LL) => LL.deskAgentAreaFiles() },
  system: { glyph: 'tune', tone: 'mist', name: (LL) => LL.deskAgentAreaSystem() },
}

export interface StatusLook {
  glyph: string
  color: string
  label: (LL: TranslationFunctions) => string
}

const WAIT: Record<PendingKind, (LL: TranslationFunctions) => string> = {
  confirm: (LL) => LL.deskAgentWaitConfirm(),
  sudo: (LL) => LL.deskAgentWaitSudo(),
  clarify: (LL) => LL.deskAgentWaitClarify(),
  danger: (LL) => LL.deskAgentWaitDanger(),
}

export function waitLabel(LL: TranslationFunctions, kind: PendingKind | null): string {
  return kind ? WAIT[kind](LL) : LL.deskAgentWaitConfirm()
}

/// A task's status as the timeline shows it.
export function statusLook(f: Pick<Flow, 'status' | 'waiting'>): StatusLook {
  switch (f.status) {
    case 'running':
      return { glyph: 'progress_activity', color: 'var(--color-accent-text)', label: (LL) => LL.deskAgentStatusRunning() }
    case 'queued':
      return { glyph: 'hourglass_top', color: 'var(--text-tertiary)', label: (LL) => LL.deskAgentStatusQueued() }
    case 'waiting':
      return { glyph: 'radio_button_checked', color: 'var(--color-warning)', label: (LL) => waitLabel(LL, f.waiting) }
    case 'failed':
      return { glyph: 'error', color: 'var(--color-danger)', label: (LL) => LL.deskAgentStatusFailed() }
    case 'cancelled':
      return { glyph: 'do_not_disturb_on', color: 'var(--text-tertiary)', label: (LL) => LL.deskAgentStatusCancelled() }
    case 'done':
      return { glyph: 'check_circle', color: 'var(--color-success)', label: (LL) => LL.deskAgentStatusDone() }
  }
}

/// A step's glyph and colour in the step list, while it is not done or
/// still to come.
export function stepLook(state: StepState | 'pending'): { glyph: string; color: string; fill: boolean } | null {
  switch (state) {
    case 'running':
      return { glyph: 'progress_activity', color: 'var(--color-accent-text)', fill: false }
    case 'waiting':
      return { glyph: 'radio_button_checked', color: 'var(--color-warning)', fill: true }
    case 'failed':
      return { glyph: 'error', color: 'var(--color-danger)', fill: true }
    case 'cancelled':
      return { glyph: 'do_not_disturb_on', color: 'var(--text-tertiary)', fill: true }
    default:
      return null
  }
}

/// A step's segment in a timeline card's progress: its track, its fill and
/// how far the fill goes.
export function segment(state: StepState | 'pending'): { bg: string; fill: string; width: string; stripe: boolean } {
  switch (state) {
    case 'done':
      return { bg: 'var(--color-accent)', fill: 'var(--color-accent)', width: '100%', stripe: false }
    case 'running':
      return { bg: 'var(--color-accent-soft)', fill: 'var(--color-accent)', width: '50%', stripe: true }
    case 'failed':
      return { bg: 'var(--color-danger)', fill: 'var(--color-danger)', width: '100%', stripe: false }
    case 'waiting':
      return { bg: 'var(--color-warning)', fill: 'var(--color-warning)', width: '100%', stripe: false }
    case 'cancelled':
      return { bg: 'var(--fill-press)', fill: 'transparent', width: '0%', stripe: false }
    default:
      return { bg: 'var(--fill-hover)', fill: 'transparent', width: '0%', stripe: false }
  }
}

/// [seconds] in words: `42 秒`, `4 分 12 秒`, `1 小时 3 分`.
export function duration(LL: TranslationFunctions, seconds: number): string {
  const s = Math.max(0, Math.floor(seconds))
  if (s < 60) return LL.deskAgentSeconds({ s })
  if (s < 3600) return LL.deskAgentMinutes({ m: Math.floor(s / 60), s: s % 60 })
  return LL.deskAgentHours({ h: Math.floor(s / 3600), m: Math.floor(s / 60) % 60 })
}

/// The greeting for [hour], as the design system words it.
export function greeting(LL: TranslationFunctions, hour: number): string {
  if (hour < 5) return LL.deskAgentGreetNight()
  if (hour < 11) return LL.deskAgentGreetMorning()
  if (hour < 13) return LL.deskAgentGreetNoon()
  if (hour < 18) return LL.deskAgentGreetAfternoon()
  return LL.deskAgentGreetEvening()
}

/// The glyph for a file given to a task.
export function fileGlyph(name: string, mime: string): string {
  if (mime.startsWith('image/')) return 'image'
  if (/\.(log|txt|out)$/i.test(name)) return 'description'
  if (/\.(conf|cfg|ya?ml|json|toml|ini|env|service)$/i.test(name)) return 'settings'
  return 'draft'
}
