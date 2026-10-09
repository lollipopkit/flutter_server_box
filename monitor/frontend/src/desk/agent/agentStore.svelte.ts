/// Agent mode's state on one desk: the account's tasks, the one open, and
/// the agent's event stream that keeps both current (`/agent/events`). The
/// tasks run on the agent: this only shows them and passes on what the
/// account says.

import type { ServerEntry } from '../../lib/servers.svelte'
import { agentApi, type Answer, type Entry, type Flow, type FlowDetail, type FlowStatus, type LiveOutput, type OutLine, type Pending, type PermissionMode } from '../../lib/agentApi'

const RETRY_MIN_MS = 1000
const RETRY_MAX_MS = 30_000
const TAIL = 6
/// Kept of the running command in the open task; the agent keeps as many.
const LIVE_LINES = 2000

/// Something the account should know while looking elsewhere.
export interface AgentNotice {
  id: string
  title: string
  text: string
  status: FlowStatus
}

/// A menubar command for Agent mode's views: start a task from the prompt,
/// open every finished task, go to the previous or next step.
export interface AgentRequest {
  kind: 'new' | 'history' | 'step'
  /// For `step`: -1 or 1.
  d?: number
  n: number
  /// When it was asked: a view mounted by the ask still takes it.
  at: number
}

export class AgentStore {
  readonly entry: ServerEntry
  flows = $state<Flow[]>([])
  loaded = $state(false)
  configured = $state(false)
  hostname = $state('')
  maxRunning = $state(3)
  defaultMode = $state<PermissionMode>('manual')
  bypassAllowed = $state(true)
  error = $state<string | null>(null)
  /// The event stream is up: what is shown is current.
  live = $state(false)
  /// The task open in the flow view, whole.
  detail = $state<FlowDetail | null>(null)
  openId = $state<string | null>(null)
  /// The words the model is writing now in the open task.
  streaming = $state('')
  notice = $state<AgentNotice | null>(null)
  /// What the menubar's Agent menus last asked the views for; [n] tells two
  /// asks for the same thing apart.
  request = $state<AgentRequest | null>(null)

  #abort: AbortController | null = null
  #retry = RETRY_MIN_MS
  #noticeTimer: ReturnType<typeof setTimeout> | null = null
  #detailSeq = 0

  constructor(entry: ServerEntry) {
    this.entry = { ...entry }
  }

  get running(): number {
    return this.flows.filter((f) => f.status === 'running').length
  }

  get atLimit(): boolean {
    return this.running >= this.maxRunning
  }

  ask(kind: AgentRequest['kind'], d?: number): void {
    this.request = { kind, d, n: (this.request?.n ?? 0) + 1, at: Date.now() }
  }

  /// Starts listening; idempotent.
  start(): void {
    if (this.#abort) return
    this.#abort = new AbortController()
    void this.refresh()
    void this.#listen(this.#abort.signal)
  }

  stop(): void {
    this.#abort?.abort()
    this.#abort = null
    this.live = false
    if (this.#noticeTimer) clearTimeout(this.#noticeTimer)
  }

  async refresh(): Promise<void> {
    try {
      const list = await agentApi.list(this.entry)
      this.flows = list.flows
      this.configured = list.configured
      this.hostname = list.hostname
      this.maxRunning = list.maxRunning
      this.defaultMode = list.defaultMode ?? 'manual'
      this.bypassAllowed = list.bypassAllowed ?? true
      this.error = null
    } catch (e) {
      this.error = e instanceof Error ? e.message : String(e)
    } finally {
      this.loaded = true
    }
    if (this.openId) await this.#loadDetail(this.openId)
  }

  async #listen(signal: AbortSignal): Promise<void> {
    // `start` has just listed the tasks.
    let first = true
    while (!signal.aborted) {
      try {
        await agentApi.events(
          this.entry,
          signal,
          (e) => this.#onEvent(e),
          () => {
            this.live = true
            this.#retry = RETRY_MIN_MS
            // Whatever happened while away.
            if (!first) void this.refresh()
            first = false
          },
        )
      } catch {
        // Refused or broken: tried again below.
      }
      this.live = false
      if (signal.aborted) return
      await new Promise((r) => setTimeout(r, this.#retry))
      this.#retry = Math.min(RETRY_MAX_MS, this.#retry * 2)
    }
  }

  // ---------------------------------------------------------------------------

  async open(id: string): Promise<void> {
    if (this.openId !== id) {
      this.openId = id
      this.detail = null
      this.streaming = ''
    }
    if (this.notice?.id === id) this.notice = null
    await this.#loadDetail(id)
  }

  close(): void {
    this.openId = null
    this.detail = null
    this.streaming = ''
  }

  async #loadDetail(id: string): Promise<void> {
    const seq = ++this.#detailSeq
    try {
      const d = await agentApi.detail(this.entry, id)
      // A later open, or a close, wins.
      if (seq !== this.#detailSeq || this.openId !== id) return
      this.detail = d
      this.#upsert(d.flow)
    } catch (e) {
      if (seq === this.#detailSeq) this.error = e instanceof Error ? e.message : String(e)
    }
  }

  async startFlow(prompt: string, mode?: PermissionMode, files: string[] = []): Promise<Flow> {
    const f = await agentApi.start(this.entry, prompt, mode, files)
    this.#upsert(f)
    return f
  }

  async reply(id: string, text: string, files: string[] = []): Promise<void> {
    this.#upsert(await agentApi.reply(this.entry, id, text, files))
  }

  async answer(id: string, answer: Answer): Promise<void> {
    await agentApi.answer(this.entry, id, answer)
    // Taken: what was asked goes now, before the agent says so.
    if (this.detail?.flow.id === id && this.detail.pending?.id === answer.id) this.detail.pending = null
  }

  async stopFlow(id: string): Promise<void> {
    await agentApi.stop(this.entry, id)
  }

  async remove(id: string): Promise<void> {
    await agentApi.remove(this.entry, id)
    this.flows = this.flows.filter((f) => f.id !== id)
    if (this.openId === id) this.close()
  }

  dismissNotice(): void {
    this.notice = null
  }

  // ---------------------------------------------------------------------------

  #upsert(f: Flow): void {
    const at = this.flows.findIndex((x) => x.id === f.id)
    if (at < 0) this.flows = [f, ...this.flows]
    else this.flows[at] = f
    if (this.detail?.flow.id === f.id) this.detail.flow = f
  }

  #onEvent(e: Record<string, unknown>): void {
    switch (e.type) {
      case 'flow': {
        const f = e.flow as Flow
        const before = this.flows.find((x) => x.id === f.id)?.status
        this.#upsert(f)
        if (before !== f.status) this.#maybeNotify(f)
        break
      }
      case 'removed':
        this.flows = this.flows.filter((f) => f.id !== e.id)
        if (this.openId === e.id) this.close()
        break
      case 'pending':
        if (this.detail && this.detail.flow.id === e.id) this.detail.pending = (e.pending as Pending | null) ?? null
        break
      case 'output':
        this.#output(e.id as string, e.toolCallId as string, e.lines as OutLine[])
        break
      case 'event':
        if (this.detail?.flow.id === e.id) this.#piEvent(e.event as Record<string, unknown>)
        break
      case 'resync':
        void this.refresh()
        break
    }
  }

  #output(id: string, toolCallId: string, lines: OutLine[]): void {
    const f = this.flows.find((x) => x.id === id)
    if (f) f.tail = [...(f.tail ?? []), ...lines].slice(-TAIL)
    const d = this.detail
    if (d?.flow.id !== id) return
    const out: LiveOutput = d.output?.toolCallId === toolCallId ? d.output : { toolCallId, lines: [], omitted: 0 }
    const all = [...out.lines, ...lines]
    const over = Math.max(0, all.length - LIVE_LINES)
    d.output = { toolCallId, lines: over ? all.slice(over) : all, omitted: out.omitted + over }
  }

  #piEvent(e: Record<string, unknown>): void {
    const d = this.detail
    if (!d) return
    switch (e.type) {
      case 'entry_added': {
        const entry = e.entry as Entry | undefined
        if (!entry || d.entries.some((x) => x.id === entry.id)) return
        d.entries = [...d.entries, entry].sort((a, b) => a.seq - b.seq)
        if (entry.message?.role === 'assistant') this.streaming = ''
        if (entry.message?.role === 'toolResult' && d.output?.toolCallId === entry.message.toolCallId) d.output = null
        break
      }
      case 'message_update': {
        const ame = e.event as { type?: string; delta?: string } | undefined
        if (ame?.type === 'text_delta' && typeof ame.delta === 'string') this.streaming += ame.delta
        break
      }
      case 'message_start':
        this.streaming = ''
        break
    }
  }

  #maybeNotify(f: Flow): void {
    if (this.openId === f.id) return
    if (f.status !== 'done' && f.status !== 'failed' && f.status !== 'waiting') return
    if (this.#noticeTimer) clearTimeout(this.#noticeTimer)
    this.notice = { id: f.id, title: f.title, text: f.line, status: f.status }
    this.#noticeTimer = setTimeout(() => (this.notice = null), 6000)
  }
}
