/// What Settings → Agent and its provider pages share: one write of the
/// agent's configuration is the whole of it (`PUT /agent/settings`), so a
/// change is made on what the agent last said, never on another page's
/// unsaved form.

import type { AgentSettings, Provider, SettingsWrite } from '../../../lib/agentApi'

export const LISTING_APIS: Provider['api'][] = ['openai-completions', 'openai-responses']

export const API_OPTIONS = [
  { value: 'openai-completions', label: 'OpenAI Chat Completions' },
  { value: 'openai-responses', label: 'OpenAI Responses' },
  { value: 'anthropic-messages', label: 'Anthropic Messages' },
  { value: 'google-generative-ai', label: 'Google Generative AI' },
] as const

/// [s] as a write that changes nothing: credentials absent keep theirs.
export function writeOf(s: AgentSettings): SettingsWrite {
  return {
    model: s.model,
    thinkingLevel: s.thinkingLevel,
    maxRunning: s.maxRunning,
    providers: s.providers ?? [],
    credentials: {},
  }
}

/// [w] without the provider [id]: its credential goes with it, and so does
/// the model when it was one of its.
export function withoutProvider(w: SettingsWrite, id: string): SettingsWrite {
  return {
    ...w,
    model: w.model?.provider === id ? null : w.model,
    providers: w.providers.filter((p) => p.id !== id),
    credentials: { ...w.credentials, [id]: null },
  }
}

/// [w] with [p] in place of the provider of its id, or added last.
export function withProvider(w: SettingsWrite, p: Provider): SettingsWrite {
  const at = w.providers.findIndex((x) => x.id === p.id)
  const providers = at < 0 ? [...w.providers, p] : w.providers.map((x, i) => (i === at ? p : x))
  return { ...w, providers }
}

export function urlOk(url: string): boolean {
  try {
    const u = new URL(url.trim())
    return (u.protocol === 'https:' || u.protocol === 'http:') && !!u.hostname
  } catch {
    return false
  }
}

/// Plain HTTP off this machine: the agent refuses it unless allowed.
export function insecure(url: string): boolean {
  try {
    const u = new URL(url.trim())
    if (u.protocol !== 'http:') return false
    const h = u.hostname.replace(/^\[|\]$/g, '')
    return !(h === 'localhost' || h === '::1' || /^127\./.test(h))
  } catch {
    return false
  }
}

/// A free id for a new endpoint named [name].
export function newId(name: string, taken: string[]): string {
  const base =
    name
      .trim()
      .toLowerCase()
      .replace(/[^a-z0-9._-]+/g, '-')
      .replace(/^-+|-+$/g, '')
      .slice(0, 48) || 'custom'
  let id = base
  for (let n = 2; taken.includes(id); n++) id = `${base}-${n}`
  return id
}
