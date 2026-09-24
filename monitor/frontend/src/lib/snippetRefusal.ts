/// A library refused before it was stored arrives as a stable code rather than
/// as a sentence, so the panel phrases it in the viewer's own language.
///
/// The codes are `api::snippets`'s own — `Refusal`'s names — plus
/// `sbm_parser::snippet::PlanError`'s single one, which is a different question
/// asked of the same page: a save is about a set of rows and names the position
/// that was wrong, an expansion is about one script and names the placeholder
/// it could not answer.
///
/// A word this build does not know is shown as the agent sent it: it is a
/// refusal added since, and a sentence invented here would misdescribe it.
import { get } from 'svelte/store'
import { LL } from '../i18n/i18n-svelte'

export function snippetRefusalText(code: string): string {
  const ll = get(LL)
  switch (code) {
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
      return code
  }
}

/// Why a script could not be expanded, with the placeholder it named.
///
/// The placeholder is interpolated rather than appended: the fix is to answer
/// that one key, and a sentence ending in a bare word reads as a second
/// sentence the agent forgot to send.
export function snippetPlanRefusalText(error: string, key: string): string {
  const ll = get(LL)
  if (error === 'unanswerable') return ll.snippetUnanswerable({ key })
  return error
}
