/// A refusal from the Proxmox endpoint arrives as a stable code rather than as
/// a sentence, so the panel phrases it in the viewer's own language.
///
/// The codes are `api::pve`'s plus the shared model's, and they are two
/// different things a reader needs told apart: the first group is about the
/// request or the configuration this agent holds — what the operator can fix —
/// and the second is what the cluster or the link to it did. None of them is an
/// upstream status: a 401 from PVE is `loginFailed`, because what failed is the
/// *agent's* credential to a machine the operator is not signed in to, and this
/// client logs the operator out on a 401 of its own.
///
/// A word this build does not know is shown as the agent sent it: it is a
/// refusal added since, and a sentence invented here would misdescribe it.
import { get } from 'svelte/store'
import { LL } from '../i18n/i18n-svelte'

export function pveRefusalText(code: string): string {
  const ll = get(LL)
  switch (code) {
    case 'notConfigured':
      return ll.pveNotConfigured()
    case 'invalidUrl':
      return ll.pveInvalidUrl()
    case 'missingUsername':
      return ll.pveMissingUsername()
    case 'missingRealm':
      return ll.pveMissingRealm()
    case 'missingTokenId':
      return ll.pveMissingTokenId()
    case 'invalidAuth':
      return ll.pveInvalidAuth()
    case 'invalidKind':
      return ll.pveInvalidKind()
    case 'invalidAction':
      return ll.pveInvalidAction()
    case 'invalidNode':
      return ll.pveInvalidNode()
    case 'invalidVmid':
      return ll.pveInvalidVmid()
    case 'unreachable':
      return ll.pveUnreachable()
    case 'loginFailed':
      return ll.pveLoginFailed()
    case 'needTfa':
      return ll.pveNeedTfa()
    case 'forbidden':
      return ll.pveForbidden()
    case 'invalidResponse':
      return ll.pveInvalidResponse()
    case 'upstream':
      return ll.pveUpstream()
    default:
      return code
  }
}

/// A refusal as the page shows it: the localized sentence, with the agent's own
/// detail under it when it sent one.
///
/// The detail is PVE's own words about what it refused, which is the only thing
/// that separates one `upstream` from another — a cluster that does not know a
/// node from one that refused a task. It is appended rather than substituted,
/// so a reader always gets a sentence in their own language first.
export function pveRefusalDetail(error: unknown): string {
  const code = error instanceof Error ? error.message : String(error)
  const detail = (error as { body?: { detail?: unknown } } | undefined)?.body?.detail
  const sentence = pveRefusalText(code)
  if (typeof detail !== 'string' || detail.length === 0) return sentence
  return `${sentence}\n${detail}`
}
