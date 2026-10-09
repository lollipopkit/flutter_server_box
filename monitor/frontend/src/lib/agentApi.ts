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
  start: (e: ServerEntry, prompt: string) =>
    requestFor<Flow>(e, '/agent/flows', { method: 'POST', body: JSON.stringify({ prompt }) }),
  detail: (e: ServerEntry, id: string) => requestFor<FlowDetail>(e, `/agent/flows/${enc(id)}`, {}, 'Request failed', undefined, 60_000),
  reply: (e: ServerEntry, id: string, text: string) =>
    requestFor<Flow>(e, `/agent/flows/${enc(id)}/reply`, { method: 'POST', body: JSON.stringify({ text }) }),
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
  events: (e: ServerEntry, signal: AbortSignal, onEvent: (event: Record<string, unknown>) => void, onOpen?: () => void) =>
    readEventStream(e, '/agent/events', signal, onEvent, onOpen),
}
