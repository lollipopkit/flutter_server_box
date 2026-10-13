/// What a refusal from `/stacks*` says in the admin's words: the setting to
/// blame named (a port in use with its number), else what stopped it.

import type { TranslationFunctions } from '../../i18n/i18n-types'
import { ApiError } from '../../lib/api'
import type { StackManifest, StackValue } from '../../types'
import { pick } from './text'

export interface StackRefusal {
  text: string
  /// The setting to blame, when one is.
  field: string | null
  /// The agent's code, when it gave one.
  code: string | null
}

export function stackRefusal(
  e: unknown,
  manifest: StackManifest,
  settings: Record<string, StackValue> | undefined,
  ll: TranslationFunctions,
  locale: string,
): StackRefusal {
  const body = e instanceof ApiError ? (e.body as { error?: string; field?: string } | undefined) : undefined
  const code = body?.error ?? null
  const field = body?.field ?? null
  if (field) {
    const port = settings?.[field]
    if (code === 'portTaken' && port != null) return { text: ll.stackPortTaken({ port }), field, code }
    const label = manifest.settings.find((s) => s.key === field)?.label
    return { text: ll.stackInvalidSetting({ setting: label ? pick(label, locale) : field }), field, code }
  }
  const text = (() => {
    switch (code) {
      case 'noRuntime':
        return ll.stackNoRuntime()
      case 'noCompose':
        return ll.stackNoCompose()
      case 'busy':
        return ll.stackBusy()
      case 'installed':
        return ll.stackAlreadyInstalled()
      case 'noProxyPort':
        return ll.stackNoProxyPort()
      case 'sharedUnavailable':
        return ll.stackSharedUnavailable()
      default:
        return e instanceof Error ? e.message : String(e)
    }
  })()
  return { text, field, code }
}
