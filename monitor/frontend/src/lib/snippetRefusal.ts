/// Why the agent refused a library or a script, phrased in the viewer's
/// language. The codes are `api::snippets::Refusal`'s and
/// `sbm_parser::snippet::PlanError`'s; a code this build does not know is shown
/// as the agent sent it, since a sentence invented here would misdescribe it.
import { get } from 'svelte/store'
import { LL } from '../i18n/i18n-svelte'
import { ApiError } from './api'

/// A save's refusal: the code is the message, the row is `body.index`.
export function snippetRefusalText(e: unknown): string {
  if (!(e instanceof ApiError)) return e instanceof Error ? e.message : String(e)
  const ll = get(LL)
  switch (e.message) {
    case 'invalidId':
      return ll.snippetInvalidId()
    case 'duplicateId':
      return ll.snippetDuplicateId()
    case 'invalidName':
      return ll.snippetInvalidName()
    case 'duplicateName':
      return ll.snippetDuplicateName()
    case 'invalidTag':
      return ll.snippetInvalidTag()
    case 'duplicateTag':
      return ll.snippetDuplicateTag()
    default:
      return e.message
  }
}

/// A plan's refusal: `{error: 'unanswerable', key}`, the placeholder the panel
/// has no value for.
export function snippetPlanRefusalText(e: unknown): string {
  if (!(e instanceof ApiError)) return e instanceof Error ? e.message : String(e)
  const key = e.body?.key
  if (e.message === 'unanswerable' && typeof key === 'string') {
    return get(LL).snippetUnanswerable({ key: `\${${key}}` })
  }
  return e.message
}
