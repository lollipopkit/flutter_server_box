/// The agent's `/api/v1/agent*` (`monitor/src/api/agent.rs`): Agent mode's
/// tasks on this machine, always to an explicit server.

import { readEventStream, requestFor } from './api'
import type { ServerEntry } from './servers.svelte'

export type FlowStatus = 'queued' | 'running' | 'waiting' | 'done' | 'failed' | 'cancelled'
export type StepState = 'running' | 'waiting' | 'done' | 'failed' | 'cancelled'
export type Area = 'status' | 'process' | 'service' | 'container' | 'files' | 'system'
export type PendingKind = 'confirm' | 'danger' | 'sudo' | 'clarify'
/// `[stream, text]`: 1 stdout, 2 stderr.
export type OutLine = [1 | 2, string]

export interface StepBrief {
  toolCallId: string
  title: string
  area: Area
  state: StepState
}

/// A task as the list has it.
export interface Flow {
  id: string
  title: string
  status: FlowStatus
  /// What it is doing, or what it did.
  line: string
  areas: Area[]
  /// The permission mode it was started in.
  mode: PermissionMode
  createdAt: string
  updatedAt: string
  startedAt: string | null
  finishedAt: string | null
  waiting: PendingKind | null
  /// While active.
  steps?: StepBrief[]
  tail?: OutLine[]
}

export interface PlanStep {
  text: string
  command?: string
}

export interface Choice {
  label: string
  hint?: string
}

/// What a task waits on the account for.
export interface Pending {
  id: string
  kind: PendingKind
  toolCallId: string
  title: string
  summary?: string
  steps?: PlanStep[]
  command?: string
  options?: Choice[]
  alternatives?: string[]
  /// What has to be typed to run a `danger` command: the machine's name.
  confirmText?: string
  /// Whose password `sudo` asks for.
  user?: string
  /// `wrongPassword` after a refused one.
  error?: string
}

export interface LiveOutput {
  toolCallId: string
  lines: OutLine[]
  omitted: number
}

/// One entry of a pi session (`type: message` for messages).
export interface Entry {
  id: string
  type: string
  seq: number
  timestamp?: number
  message?: Message
  [key: string]: unknown
}

export type Part =
  | { type: 'text'; text: string }
  | { type: 'thinking'; thinking: string }
  | { type: 'toolCall'; id: string; name: string; arguments: Record<string, unknown> }
  | { type: 'image'; data: string; mimeType: string }

export interface Message {
  role: 'user' | 'assistant' | 'toolResult'
  content: Part[] | string
  timestamp?: number
  toolCallId?: string
  toolName?: string
  details?: Record<string, unknown> | null
  isError?: boolean
  stopReason?: string
  errorMessage?: string
}

export interface FlowDetail {
  flow: Flow
  entries: Entry[]
  pending: Pending | null
  output: LiveOutput | null
}

export interface FlowList {
  flows: Flow[]
  /// A model is set: tasks can start.
  configured: boolean
  maxRunning: number
  hostname: string
  /// The mode a new task starts in unless another is picked.
  defaultMode: PermissionMode
  bypassAllowed: boolean
}

/// A file given to a task, uploaded before the task starts.
export interface Upload {
  id: string
  name: string
  mime: string
  size: number
}

export interface Answer {
  id: string
  action: 'run' | 'cancel' | 'edit' | 'pick' | 'text' | 'password' | 'alternative'
  text?: string
  index?: number
  password?: string
  remember?: boolean
  confirm?: string
}

export interface ModelRef {
  provider: string
  id: string
}

export interface Provider {
  id: string
  name: string
  api: 'openai-completions' | 'openai-responses' | 'anthropic-messages' | 'google-generative-ai'
  baseUrl: string
  allowInsecure: boolean
  models: { id: string; name?: string }[]
}

/// What an admin reads; any other account gets the first three.
export interface AgentSettings {
  model: ModelRef | null
  thinkingLevel: string
  maxRunning: number
  providers?: Provider[]
  /// Providers with a credential set.
  credentials?: string[]
}

export interface SettingsWrite {
  model: ModelRef | null
  thinkingLevel: string
  maxRunning: number
  providers: Provider[]
  /// A key sets, `null` removes, absent keeps.
  credentials: Record<string, string | null>
}

/// A provider and its models, as pi lists them.
export interface ProviderInfo {
  id: string
  name: string
  custom: boolean
  models: { provider: string; id: string; name: string }[]
}

/// How the commands a task runs are approved (`/agent/permissions`), picked
/// per task.
export type PermissionMode = 'manual' | 'auto' | 'bypass'

export interface CommandRules {
  allow: string[]
  ask: string[]
  deny: string[]
}

/// The auto mode judge's prose lists; absent is the built-in list.
export interface AutoModeRules {
  environment?: string[]
  allow?: string[]
  soft_deny?: string[]
  hard_deny?: string[]
}

export interface Permissions {
  defaultMode: PermissionMode
  disableBypass: boolean
  rules: CommandRules
  autoMode: AutoModeRules
}

export interface PermissionsView {
  permissions: Permissions
  defaults: Required<AutoModeRules>
}

/// What the desk's search was taken for.
export type SearchKind = 'keyword' | 'question' | 'change'

/// A thing a search found.
export interface SearchItem {
  kind: 'service' | 'process' | 'file' | 'container'
  title: string
  sub: string
  /// The unit, the PID, the path, the container's name.
  ref: string
}

export interface SearchFollowup {
  label: string
  request: string
}

export interface SearchPlanStep {
  text: string
  command: string | null
  effect: 'read' | 'change' | 'danger'
}

/// One event of a search's stream.
export type SearchEvent =
  | { type: 'kind'; kind: SearchKind }
  | { type: 'step'; id: string; command: string; state: 'running' | 'done' | 'failed' }
  | { type: 'items'; items: SearchItem[]; followups: SearchFollowup[] }
  | { type: 'plan'; steps: SearchPlanStep[] }
  | { type: 'said' }
  | { type: 'delta'; text: string }
  | { type: 'done'; id: string; answer: string; steps: number; ms: number }
  | { type: 'error'; message: string }

/// A file of the account's memory, below `/memories`.
export interface MemoryFileInfo {
  path: string
  /// UTF-16 code units, as the memory counts them.
  chars: number
  /// Milliseconds since the epoch.
  modified: number | null
}

const enc = encodeURIComponent

export const agentApi = {
  list: (e: ServerEntry) => requestFor<FlowList>(e, '/agent/flows'),
  start: (e: ServerEntry, prompt: string, mode?: PermissionMode, files: string[] = []) =>
    requestFor<Flow>(e, '/agent/flows', { method: 'POST', body: JSON.stringify({ prompt, mode, files }) }),
  upload: (e: ServerEntry, file: Blob, name: string) =>
    requestFor<Upload>(
      e,
      `/agent/files?name=${enc(name)}`,
      { method: 'POST', body: file, headers: { 'Content-Type': file.type || 'application/octet-stream' } },
      'Upload failed',
      undefined,
      120_000,
    ),
  discard: (e: ServerEntry, id: string) => requestFor<void>(e, `/agent/files/${enc(id)}`, { method: 'DELETE' }),
  detail: (e: ServerEntry, id: string) => requestFor<FlowDetail>(e, `/agent/flows/${enc(id)}`, {}, 'Request failed', undefined, 60_000),
  reply: (e: ServerEntry, id: string, text: string, files: string[] = []) =>
    requestFor<Flow>(e, `/agent/flows/${enc(id)}/reply`, { method: 'POST', body: JSON.stringify({ text, files }) }),
  answer: (e: ServerEntry, id: string, answer: Answer) =>
    requestFor<void>(e, `/agent/flows/${enc(id)}/answer`, { method: 'POST', body: JSON.stringify(answer) }),
  stop: (e: ServerEntry, id: string) => requestFor<void>(e, `/agent/flows/${enc(id)}/stop`, { method: 'POST' }),
  remove: (e: ServerEntry, id: string) => requestFor<void>(e, `/agent/flows/${enc(id)}`, { method: 'DELETE' }),
  settings: (e: ServerEntry) => requestFor<AgentSettings>(e, '/agent/settings'),
  saveSettings: (e: ServerEntry, w: SettingsWrite) =>
    requestFor<AgentSettings>(e, '/agent/settings', { method: 'PUT', body: JSON.stringify(w) }),
  /// What an endpoint being set up lists: with [apiKey], or the key stored
  /// for [providerId].
  probe: (e: ServerEntry, p: { api: Provider['api']; baseUrl: string; allowInsecure: boolean; apiKey?: string; providerId?: string }) =>
    requestFor<{ id: string; name: string }[]>(e, '/agent/models/probe', { method: 'POST', body: JSON.stringify(p) }, 'Request failed', undefined, 60_000),
  models: (e: ServerEntry) => requestFor<ProviderInfo[]>(e, '/agent/models', {}, 'Request failed', undefined, 60_000),
  memory: (e: ServerEntry) => requestFor<{ files: MemoryFileInfo[] }>(e, '/agent/memory'),
  memoryFile: (e: ServerEntry, path: string) =>
    requestFor<{ path: string; content: string; modified: number | null }>(e, `/agent/memory/file?path=${enc(path)}`),
  writeMemory: (e: ServerEntry, path: string, content: string) =>
    requestFor<void>(e, '/agent/memory/file', { method: 'PUT', body: JSON.stringify({ path, content }) }),
  deleteMemory: (e: ServerEntry, path: string) => requestFor<void>(e, `/agent/memory/file?path=${enc(path)}`, { method: 'DELETE' }),
  permissions: (e: ServerEntry) => requestFor<PermissionsView>(e, '/agent/permissions'),
  savePermissions: (e: ServerEntry, p: Permissions) =>
    requestFor<PermissionsView>(e, '/agent/permissions', { method: 'PUT', body: JSON.stringify(p) }),
  /// The desk's search, answered by the agent reading only, as it goes.
  search: (e: ServerEntry, query: string, kind: SearchKind | undefined, signal: AbortSignal, onEvent: (event: SearchEvent) => void) =>
    readEventStream(e, '/agent/search', signal, (ev) => onEvent(ev as unknown as SearchEvent), undefined, kind ? { query, kind } : { query }),
  /// The search [id] as a task; run on with [text].
  adoptSearch: (e: ServerEntry, id: string, text?: string) =>
    requestFor<Flow>(e, `/agent/search/${enc(id)}/task`, { method: 'POST', body: JSON.stringify(text ? { text } : {}) }),
  events: (e: ServerEntry, signal: AbortSignal, onEvent: (event: Record<string, unknown>) => void, onOpen?: () => void) =>
    readEventStream(e, '/agent/events', signal, onEvent, onOpen),
}
