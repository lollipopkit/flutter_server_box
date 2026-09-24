/// The two vocabularies the AI page draws as sentences.
///
/// A refusal is a code the agent answered with, and a stop is a code the agent
/// recorded on a turn that ended badly. Both are drawn here, in the viewer's
/// language, and neither is stored with its English.
///
/// A code this build does not know is shown as the agent sent it: it is a code
/// added since, and a sentence invented here would misdescribe it.
import { get } from 'svelte/store'
import { LL } from '../i18n/i18n-svelte'

/// Why the agent refused an action the page took.
export function aiRefusalText(code: string): string {
  const ll = get(LL)
  switch (code) {
    case 'invalid_base_url':
      return ll.aiRefusalInvalidBaseUrl()
    case 'empty_message':
      return ll.aiRefusalEmptyMessage()
    case 'message_too_long':
      return ll.aiRefusalMessageTooLong()
    case 'invalid_title':
      return ll.aiRefusalInvalidTitle()
    case 'not_configured':
      return ll.aiRefusalNotConfigured()
    case 'busy':
      return ll.aiRefusalBusy()
    case 'nothing_to_decline':
      return ll.aiRefusalNothingToDecline()
    case 'no_such_conversation':
      return ll.aiRefusalNoSuchConversation()
    case 'no_such_call':
      return ll.aiRefusalNoSuchCall()
    default:
      return code
  }
}

/// Why a turn stopped.
///
/// `declined` and `interrupted` are recorded as notice items rather than as the
/// live error, so this phrases those two where the notice is drawn as well.
export function aiStopText(code: string): string {
  const ll = get(LL)
  switch (code) {
    case 'interrupted':
      return ll.aiStopInterrupted()
    case 'storage':
      return ll.aiStopStorage()
    case 'not_configured':
      return ll.aiStopNotConfigured()
    case 'unreachable':
      return ll.aiStopUnreachable()
    case 'auth':
      return ll.aiStopAuth()
    case 'not_found':
      return ll.aiStopNotFound()
    case 'rejected':
      return ll.aiStopRejected()
    case 'rate_limited':
      return ll.aiStopRateLimited()
    case 'unavailable':
      return ll.aiStopUnavailable()
    case 'shape':
      return ll.aiStopShape()
    case 'declined':
      return ll.aiStopDeclined()
    default:
      return code
  }
}
