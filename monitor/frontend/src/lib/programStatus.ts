/// What the programs in a terminal report about themselves: the Program Status
/// Protocol (OSC 7501), the ConEmu progress bar (OSC 9;4) and shell
/// integration marks (OSC 133).
///
/// Terminal emulation, like the rest of what xterm.js parses, so it lives
/// beside the emulator rather than in the agent. The app's emulator (xterm.dart,
/// `program_status.dart`) applies the same rules; keep the two in step.
/// Spec: https://gist.github.com/mitchellh/7acae3abd8355c1c00287d67e96c913a

/// From the most to the least urgent.
export const programStates = ['blocked', 'error', 'done', 'working', 'idle'] as const
export type ProgramState = (typeof programStates)[number]
export type BlockKind = 'permission' | 'question' | 'auth'

export interface ProgramStatusReport {
  /// `null` for `state=clear`.
  state: ProgramState | null
  /// The record's path; empty for the root record.
  id: string[]
  kind?: BlockKind
  progress?: number
  app?: string
  /// Decoded, and safe to show as plain text.
  title?: string
  msg?: string
}

export type ProgressState = 'normal' | 'error' | 'indeterminate' | 'paused'
export interface TerminalProgress {
  state: ProgressState
  percent?: number
}

export interface ShellCommand {
  running: boolean
  exitCode?: number
}

const MAX_SEQUENCE = 4096
const FRAMING = 9
const KEY = /^[a-z]+$/
const VALUE = /^[A-Za-z0-9_.,+/=-]*$/
const NAME = /^[A-Za-z0-9_.+-]{1,32}$/
const PERCENT = /^[0-9]{1,3}$/
const BASE64 = /^[A-Za-z0-9+/]*={0,2}$/
/// Text direction overrides and isolates, zero-width and other invisible
/// formatting characters.
const INVISIBLE =
  /[\u00AD\u061C\u180E\u200B-\u200F\u202A-\u202E\u2060-\u2064\u2066-\u206F\uFEFF\uFFF9-\uFFFB]/g
const CONTROL = /[\u0000-\u001F\u007F-\u009F]/

class Refused extends Error {}

/// `OSC 7501 ; ? ST`, and the terminal's answer to it.
export const QUERY = '?'
export const QUERY_REPLY = '\x1b]7501;?\x1b\\'

/// Parses the payload after `7501;`, or returns `null` when the spec says to
/// refuse the whole report.
export function parseReport(payload: string): ProgramStatusReport | null {
  if (payload.length + FRAMING > MAX_SEQUENCE) return null
  const pairs = new Map<string, string>()
  for (const pair of payload.split(':')) {
    const eq = pair.indexOf('=')
    if (eq <= 0) continue
    const key = pair.slice(0, eq)
    const value = pair.slice(eq + 1)
    if (!KEY.test(key) || !VALUE.test(value)) continue
    if (key.length > 16) return null
    pairs.set(key, value)
  }

  const stateName = pairs.get('state')
  if (stateName === undefined) return null
  let state: ProgramState | null
  if (stateName === 'clear') state = null
  else if ((programStates as readonly string[]).includes(stateName)) state = stateName as ProgramState
  else return null

  const rawId = pairs.get('id')
  let id: string[] = []
  if (rawId !== undefined) {
    if (rawId.length > 128) return null
    id = rawId.split('/')
    if (id.length > 8 || !id.every((s) => NAME.test(s))) return null
  }
  if (state === null) return { state, id }

  const app = pairs.get('app')
  if (app !== undefined && app.length > 32) return null

  let title: string | undefined
  let msg: string | undefined
  try {
    title = decodeText(pairs.get('title'), 256, 192)
    msg = decodeText(pairs.get('msg'), 2732, 2048)
  } catch (e) {
    if (e instanceof Refused) return null
    throw e
  }

  const report: ProgramStatusReport = { state, id }
  const kind = pairs.get('kind')
  if (state === 'blocked' && (kind === 'permission' || kind === 'question' || kind === 'auth')) {
    report.kind = kind
  }
  const progress = pairs.get('progress')
  if ((state === 'working' || state === 'blocked') && progress && PERCENT.test(progress)) {
    const n = Number(progress)
    if (n <= 100) report.progress = n
  }
  if (app !== undefined && NAME.test(app)) report.app = app
  if (title !== undefined) report.title = title
  if (msg !== undefined) report.msg = msg
  return report
}

/// `undefined` when absent or unusable (the key is then ignored); throws
/// [Refused] when the whole report must be refused.
function decodeText(raw: string | undefined, maxEncoded: number, maxDecoded: number) {
  if (raw === undefined) return undefined
  if (raw.length > maxEncoded) throw new Refused()
  const padded = raw + '='.repeat((4 - (raw.length % 4)) % 4)
  if (!BASE64.test(padded)) return undefined
  let bytes: Uint8Array
  try {
    bytes = Uint8Array.from(atob(padded), (c) => c.charCodeAt(0))
  } catch {
    return undefined
  }
  if (bytes.length > maxDecoded) throw new Refused()
  let text: string
  try {
    text = new TextDecoder('utf-8', { fatal: true }).decode(bytes)
  } catch {
    return undefined
  }
  if (CONTROL.test(text)) throw new Refused()
  const shown = text.replace(INVISIBLE, '')
  return shown === '' ? undefined : shown
}

/// The arguments after `9;`, or `undefined` for anything but a valid `4`
/// subcommand (OSC 9 alone is a desktop notification). `null` removes the bar.
export function parseProgress(data: string): TerminalProgress | null | undefined {
  const [sub, st, pr] = data.split(';')
  if (sub !== '4') return undefined
  const code = st === undefined || st === '' ? 0 : Number(st)
  const n = pr === undefined || pr === '' ? undefined : Number(pr)
  const percent = n === undefined || Number.isNaN(n) ? undefined : Math.min(100, Math.max(0, n))
  switch (code) {
    case 0:
      return null
    case 1:
      return { state: 'normal', percent: percent ?? 0 }
    case 2:
      return { state: 'error', percent }
    case 3:
      return { state: 'indeterminate' }
    case 4:
      return { state: 'paused', percent }
    default:
      return undefined
  }
}

export interface ProgramStatusRecord {
  key: string
  report: ProgramStatusReport & { state: ProgramState }
}

/// The records of one terminal, by the spec's lifetime rules.
export class ProgramStatusRecords {
  /// From the least to the most recently reported.
  private readonly map = new Map<string, ProgramStatusRecord>()
  progress: TerminalProgress | null = null
  command: ShellCommand | null = null
  private readonly listeners = new Set<() => void>()

  constructor(readonly maxRecords = 256) {}

  get records(): ProgramStatusRecord[] {
    return [...this.map.values()]
  }

  get isEmpty(): boolean {
    return this.map.size === 0 && this.progress === null && this.command === null
  }

  get hasReports(): boolean {
    return this.map.size > 0 || this.progress !== null
  }

  subscribe(listener: () => void): () => void {
    this.listeners.add(listener)
    return () => this.listeners.delete(listener)
  }

  /// The record's program: its own, or that of its nearest ancestor naming one.
  appOf(record: ProgramStatusRecord): string | undefined {
    for (let depth = record.report.id.length; depth >= 0; depth--) {
      const app = this.map.get(record.report.id.slice(0, depth).join('/'))?.report.app
      if (app !== undefined) return app
    }
    return undefined
  }

  /// The most urgent state of all records and the progress bar.
  get state(): ProgramState | null {
    let best: ProgramState | null = null
    const rank = (s: ProgramState) => programStates.indexOf(s)
    for (const { report } of this.map.values()) {
      if (best === null || rank(report.state) < rank(best)) best = report.state
    }
    if (this.progress) {
      const fromBar: ProgramState = this.progress.state === 'error' ? 'error' : 'working'
      if (best === null || rank(fromBar) < rank(best)) best = fromBar
    }
    return best
  }

  /// The most recently reported record in [state].
  latest(state: ProgramState): ProgramStatusRecord | undefined {
    return this.records.filter((r) => r.report.state === state).at(-1)
  }

  report(report: ProgramStatusReport) {
    const key = report.id.join('/')
    if (report.state === null) {
      if (key === '') {
        if (this.map.size === 0) return
        this.map.clear()
      } else {
        const before = this.map.size
        for (const k of [...this.map.keys()]) {
          if (k === key || k.startsWith(`${key}/`)) this.map.delete(k)
        }
        if (this.map.size === before) return
      }
      return this.changed()
    }
    // Each report replaces its record whole, and makes it the most recent.
    this.map.delete(key)
    this.map.set(key, { key, report: report as ProgramStatusRecord['report'] })
    while (this.map.size > this.maxRecords) {
      this.map.delete(this.map.keys().next().value!)
    }
    this.changed()
  }

  setProgress(progress: TerminalProgress | null) {
    if (progress === null && this.progress === null) return
    this.progress = progress
    this.changed()
  }

  /// `OSC 133 ; A|B|C|D`.
  mark(kind: string, exitCode?: number) {
    switch (kind) {
      case 'A':
        // A new prompt means the programs before it have exited.
        if (this.dropTransient()) this.changed()
        return
      case 'C':
        this.command = { running: true }
        return this.changed()
      case 'D':
        this.command = { running: false, exitCode }
        return this.changed()
    }
  }

  /// The process attached to the terminal exited.
  processExited() {
    let changed = this.dropTransient()
    if (this.command?.running) {
      this.command = null
      changed = true
    }
    if (changed) this.changed()
  }

  /// A full reset, or a record the user dismissed with everything.
  clear() {
    if (this.isEmpty) return
    this.map.clear()
    this.progress = null
    this.command = null
    this.changed()
  }

  private dropTransient(): boolean {
    const before = this.map.size
    for (const [k, r] of this.map) {
      if (r.report.state !== 'done' && r.report.state !== 'error') this.map.delete(k)
    }
    let changed = this.map.size !== before
    if (this.progress && this.progress.state !== 'error') {
      this.progress = null
      changed = true
    }
    return changed
  }

  private changed() {
    for (const listener of [...this.listeners]) listener()
  }
}

/// The xterm.js parser hooks this needs, so the wiring is testable without a
/// terminal.
export interface OscParser {
  registerOscHandler(ident: number, callback: (data: string) => boolean | Promise<boolean>): {
    dispose(): void
  }
  registerEscHandler(
    id: { final: string },
    callback: () => boolean | Promise<boolean>,
  ): { dispose(): void }
}

/// Feeds [records] from [parser], and answers the support query through
/// [reply]. Returns what removes the hooks.
export function attachProgramStatus(
  parser: OscParser,
  records: ProgramStatusRecords,
  reply: (data: string) => void,
): () => void {
  const hooks = [
    parser.registerOscHandler(7501, (data) => {
      if (data === QUERY) {
        reply(QUERY_REPLY)
      } else {
        const report = parseReport(data)
        if (report) records.report(report)
      }
      // Refused reports are dropped whole, not left to anything else.
      return true
    }),
    parser.registerOscHandler(9, (data) => {
      const progress = parseProgress(data)
      if (progress === undefined) return false
      records.setProgress(progress)
      return true
    }),
    parser.registerOscHandler(133, (data) => {
      const [kind, code] = data.split(';')
      const exit = code === undefined || code === '' ? undefined : Number(code)
      records.mark(kind ?? '', exit === undefined || Number.isNaN(exit) ? undefined : exit)
      return true
    }),
    // RIS removes every record; xterm.js still performs the reset itself.
    parser.registerEscHandler({ final: 'c' }, () => {
      records.clear()
      return false
    }),
  ]
  return () => hooks.forEach((h) => h.dispose())
}
