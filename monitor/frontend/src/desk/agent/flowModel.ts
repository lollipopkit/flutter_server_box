/// What Agent mode draws, read from what the agent says: a task's steps from
/// its pi session's entries (each tool call is a step), and the home page's
/// columns from the list. Pure; `tests/agentFlowModel.test.ts`.

import type { Area, Choice, Entry, Flow, FlowStatus, LiveOutput, OutLine, Pending, PendingKind, PlanStep, StepState } from '../../lib/agentApi'

export type StepKind = 'command' | 'plan' | 'ask' | 'reply' | 'thinking' | 'memory'

export interface ChatLine {
  me: boolean
  text: string
}

export interface Step {
  /// The tool call's id; `reply:<n>` and `thinking` for the others.
  id: string
  kind: StepKind
  /// Empty for a `reply` and `thinking` step: the page names those. A
  /// `memory` step's is the file or directory it read or changed.
  title: string
  /// The tool called; empty for a `reply` and `thinking` step.
  tool: string
  area: Area
  state: StepState | 'pending'
  /// What the step waits on, while it waits.
  waiting: PendingKind | null
  /// What the model said leading up to it.
  summary: string
  command: string | null
  sudo: boolean
  plan: PlanStep[]
  options: Choice[]
  output: OutLine[]
  /// Lines left out of [output] after its first [omittedAt].
  omitted: number
  omittedAt: number
  exitCode: number | null
  timedOut: boolean
  durationMs: number | null
  /// How the account answered a plan or a question; what it chose instead
  /// of a command.
  answer: string | null
  /// The tool's failure, as the model was told.
  error: string | null
  /// Who decided it when nobody was asked (`auto`: the auto mode judge).
  by: string | null
  chat: ChatLine[]
}

const AREAS: Area[] = ['status', 'process', 'service', 'container', 'files', 'system']

/// The memory tools that change it; the others only read it.
const MEMORY_WRITES = ['memory_write', 'memory_edit', 'memory_delete', 'memory_move']

export function changesMemory(s: Step): boolean {
  return s.kind === 'memory' && MEMORY_WRITES.includes(s.tool)
}

function area(v: unknown, fallback: Area): Area {
  return AREAS.includes(v as Area) ? (v as Area) : fallback
}

function textOf(content: unknown): string {
  if (typeof content === 'string') return content
  if (!Array.isArray(content)) return ''
  return content
    .filter((p): p is { type: 'text'; text: string } => (p as { type?: string })?.type === 'text')
    .map((p) => p.text)
    .join('')
}

/// A file given with the account's words, as the agent listed it.
export interface Attachment {
  name: string
  mime: string
  /// As the agent wrote it (`2.0 KiB`).
  size: string
}

const ATTACHMENTS = '<attachments>'
const ATTACHMENT = /^- `(.+)` \(([^,()]+), ([^)]+)\) at `/

/// [text] without the `<attachments>` block the agent adds to a prompt with
/// files (`agent_mode/files.rs`), and the files it lists.
export function splitAttachments(text: string): { text: string; files: Attachment[] } {
  const at = text.lastIndexOf(ATTACHMENTS)
  if (at < 0 || !text.trimEnd().endsWith('</attachments>')) return { text, files: [] }
  const files: Attachment[] = []
  let fence: string | null = null
  for (const line of text.slice(at + ATTACHMENTS.length).split('\n')) {
    const ticks = /^(`{3,})$/.exec(line)?.[1]
    if (ticks && (fence === null || ticks === fence)) {
      fence = fence === null ? ticks : null
      continue
    }
    if (fence !== null) continue
    const m = ATTACHMENT.exec(line)
    if (m) files.push({ name: m[1], mime: m[2], size: m[3] })
  }
  return { text: text.slice(0, at).trimEnd(), files }
}

function str(v: unknown): string {
  return typeof v === 'string' ? v : ''
}

function blank(id: string, kind: StepKind, a: Area): Step {
  return {
    id,
    kind,
    title: '',
    tool: '',
    area: a,
    state: 'running',
    waiting: null,
    summary: '',
    command: null,
    sudo: false,
    plan: [],
    options: [],
    output: [],
    omitted: 0,
    omittedAt: 0,
    exitCode: null,
    timedOut: false,
    durationMs: null,
    answer: null,
    error: null,
    by: null,
    chat: [],
  }
}

function isActive(status: FlowStatus): boolean {
  return status === 'queued' || status === 'running' || status === 'waiting'
}

export interface Derived {
  /// The first thing the account asked.
  prompt: string
  /// The files given with it.
  files: Attachment[]
  steps: Step[]
}

/// A task's steps, from the entries of its session's current branch, what
/// it waits on, the running command's output and the words the model is
/// writing now.
export function deriveSteps(
  entries: Entry[],
  status: FlowStatus,
  pending: Pending | null,
  live: LiveOutput | null,
  streaming = '',
): Derived {
  const steps: Step[] = []
  const byCall = new Map<string, Step>()
  let prompt = ''
  let files: Attachment[] = []
  let seenPrompt = false
  let replies = 0
  const lastArea = (): Area => steps.at(-1)?.area ?? 'system'
  const conversation = (): Step => {
    const last = steps.at(-1)
    if (last) return last
    const s = blank(`reply:${replies++}`, 'reply', 'system')
    s.state = 'done'
    steps.push(s)
    return s
  }

  for (const e of [...entries].sort((a, b) => a.seq - b.seq)) {
    const m = e.type === 'message' ? e.message : undefined
    if (!m) continue
    if (m.role === 'user') {
      const text = textOf(m.content)
      if (!seenPrompt) {
        ;({ text: prompt, files } = splitAttachments(text))
        seenPrompt = true
      } else {
        conversation().chat.push({ me: true, text })
      }
      continue
    }
    if (m.role === 'assistant') {
      const parts = Array.isArray(m.content) ? m.content : []
      const text = textOf(parts).trim()
      const calls = parts.filter((p) => p.type === 'toolCall')
      for (const c of calls) {
        if (c.type !== 'toolCall') continue
        // A search's own (`agent_mode/search.rs`): shown by the search, not a step.
        if (c.name === 'report_results' || c.name === 'draft_plan') continue
        const args = c.arguments ?? {}
        let s: Step
        if (c.name === 'run_command') {
          s = blank(c.id, 'command', area(args.area, lastArea()))
          s.command = str(args.command)
          s.title = str(args.title) || s.command
          s.sudo = args.sudo === true
        } else if (c.name === 'propose_plan') {
          s = blank(c.id, 'plan', 'system')
          s.title = str(args.title)
          s.plan = Array.isArray(args.steps) ? (args.steps as PlanStep[]).filter((p) => typeof p?.text === 'string') : []
        } else if (c.name === 'ask_user') {
          s = blank(c.id, 'ask', lastArea())
          s.title = str(args.question)
          s.options = Array.isArray(args.options) ? (args.options as Choice[]).filter((o) => typeof o?.label === 'string') : []
        } else if (c.name.startsWith('memory_')) {
          s = blank(c.id, 'memory', lastArea())
          s.title = str(args.path) || str(args.from) || '/memories'
        } else {
          s = blank(c.id, 'command', lastArea())
          s.title = c.name
        }
        s.tool = c.name
        s.summary = text
        steps.push(s)
        byCall.set(c.id, s)
      }
      if (!calls.length) {
        if (m.stopReason === 'error' || m.stopReason === 'aborted') {
          if (m.errorMessage) conversation().error = m.errorMessage
        } else if (text) {
          // The first words with no step yet are the reply; later ones are
          // the conversation in the step they follow.
          const last = steps.at(-1)
          if (last) last.chat.push({ me: false, text })
          else {
            const s = blank(`reply:${replies++}`, 'reply', 'system')
            s.summary = text
            s.state = 'done'
            steps.push(s)
          }
        }
      }
      continue
    }
    if (m.role === 'toolResult' && m.toolCallId) {
      const s = byCall.get(m.toolCallId)
      if (!s) continue
      const d = (m.details ?? {}) as Record<string, unknown>
      const result = textOf(m.content)
      if (Array.isArray(d.lines)) s.output = d.lines as OutLine[]
      s.omitted = typeof d.omitted === 'number' ? d.omitted : 0
      s.omittedAt = typeof d.omittedAt === 'number' ? d.omittedAt : s.output.length
      s.exitCode = typeof d.exitCode === 'number' ? d.exitCode : null
      s.timedOut = d.timedOut === true
      s.durationMs = typeof d.durationMs === 'number' ? d.durationMs : null
      if (typeof d.alternative === 'string') s.answer = d.alternative
      if (typeof d.answer === 'string') s.answer = d.answer
      if (typeof d.decision === 'string') s.answer = d.decision
      if (typeof d.by === 'string') s.by = d.by
      if (m.isError || d.decision === 'blocked' || d.decision === 'refused') {
        s.state = 'failed'
        s.error = result
      } else if (d.declined === true || d.cancelled === true || d.decision === 'cancelled' || (s.kind === 'ask' && d.answer === null)) {
        s.state = 'cancelled'
      } else if (s.kind === 'command' && (s.exitCode !== 0 || s.timedOut)) {
        s.state = 'failed'
      } else {
        s.state = 'done'
      }
      byCall.delete(m.toolCallId)
    }
  }

  // Calls without a result: waiting on the account, running, or left behind
  // by a run that ended.
  for (const s of byCall.values()) {
    if (pending && pending.toolCallId === s.id) {
      s.state = 'waiting'
      s.waiting = pending.kind
    } else {
      s.state = isActive(status) ? 'running' : 'cancelled'
    }
  }
  if (live) {
    const s = steps.find((x) => x.id === live.toolCallId)
    if (s && s.state !== 'done') {
      s.output = live.lines
      s.omitted = live.omitted
      s.omittedAt = 0
    }
  }
  // The model at work between steps.
  if (status === 'running' && !steps.some((s) => s.state === 'running' || s.state === 'waiting')) {
    const s = blank('thinking', 'thinking', lastArea())
    s.summary = streaming
    steps.push(s)
  }
  if (status === 'queued') {
    const s = blank('thinking', 'thinking', lastArea())
    s.state = 'pending'
    steps.push(s)
  }
  return { prompt, files, steps }
}

/// The step a task opens at: the first not done, or the last.
export function currentStep(steps: Step[]): number {
  const i = steps.findIndex((s) => s.state !== 'done')
  return i < 0 ? Math.max(0, steps.length - 1) : i
}

// -----------------------------------------------------------------------------
// The home page

export interface Columns {
  running: Flow[]
  queued: Flow[]
  /// Waiting on the account, or failed: both need it.
  waiting: Flow[]
  done: Flow[]
}

export function columns(flows: Flow[]): Columns {
  const by = (pred: (f: Flow) => boolean) => flows.filter(pred)
  return {
    running: by((f) => f.status === 'running'),
    queued: by((f) => f.status === 'queued'),
    waiting: by((f) => f.status === 'waiting' || f.status === 'failed'),
    done: by((f) => f.status === 'done' || f.status === 'cancelled'),
  }
}

export type Day = 'today' | 'yesterday' | 'earlier'

/// [flows] by the day they finished (or last changed), relative to [now],
/// in their order.
export function byDay(flows: Flow[], now: Date): { day: Day; flows: Flow[] }[] {
  const start = new Date(now.getFullYear(), now.getMonth(), now.getDate()).getTime()
  const day = (f: Flow): Day => {
    const t = new Date(f.finishedAt ?? f.updatedAt).getTime()
    if (t >= start) return 'today'
    if (t >= start - 86_400_000) return 'yesterday'
    return 'earlier'
  }
  const out: { day: Day; flows: Flow[] }[] = []
  for (const d of ['today', 'yesterday', 'earlier'] as Day[]) {
    const list = flows.filter((f) => day(f) === d)
    if (list.length) out.push({ day: d, flows: list })
  }
  return out
}

/// The first [n] of [groups]' flows, keeping the groups.
export function firstOf<T extends { flows: Flow[] }>(groups: T[], n: number): T[] {
  let left = n
  const out: T[] = []
  for (const g of groups) {
    if (left <= 0) break
    const flows = g.flows.slice(0, left)
    left -= flows.length
    out.push({ ...g, flows })
  }
  return out
}

/// Whole seconds from [from] to [to].
export function elapsed(from: string | null, to: Date): number {
  if (!from) return 0
  return Math.max(0, Math.floor((to.getTime() - new Date(from).getTime()) / 1000))
}

/// The lines [filter] keeps, numbered from 1 as the output has them, with a
/// fold where a long output is cut: the first and last [keep] lines unless
/// [expanded]. `omitted` lines the agent never kept are a fold of their own.
export type TermRow = { n: number; line: OutLine } | { fold: 'expand'; count: number } | { fold: 'omitted'; count: number }

export function termRows(
  lines: OutLine[],
  opts: { errorsOnly: boolean; expanded: boolean; omitted: number; omittedAt: number; keep?: number },
): TermRow[] {
  const keep = opts.keep ?? 40
  const numbered = lines.map((line, i) => ({ n: i + 1 + (i >= opts.omittedAt ? opts.omitted : 0), line }))
  if (opts.errorsOnly) return numbered.filter((r) => r.line[0] === 2)
  const rows: TermRow[] = []
  const push = (from: number, to: number) => {
    for (let i = from; i < to; i++) {
      if (opts.omitted > 0 && i === opts.omittedAt) rows.push({ fold: 'omitted', count: opts.omitted })
      rows.push(numbered[i])
    }
  }
  if (!opts.expanded && numbered.length > keep * 3) {
    push(0, keep)
    rows.push({ fold: 'expand', count: numbered.length - keep * 2 })
    push(numbered.length - keep, numbered.length)
  } else {
    push(0, numbered.length)
    if (opts.omitted > 0 && opts.omittedAt >= numbered.length) rows.push({ fold: 'omitted', count: opts.omitted })
  }
  return rows
}
