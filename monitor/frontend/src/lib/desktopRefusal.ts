/// A route refused before it was written arrives as a stable code rather than
/// as a sentence, so the panel phrases it in the viewer's own language.
///
/// The codes are `api::desktop`'s own, and they are all about the request:
/// nothing here reports a state of the machine, because a route's address is
/// verified when a session dials it rather than when it is saved — a host that
/// happens to be down is a route worth keeping.
///
/// A word this build does not know is shown as the agent sent it: it is a
/// refusal added since, and a sentence invented here would misdescribe it.
import { get } from 'svelte/store'
import { LL } from '../i18n/i18n-svelte'

export function desktopRefusalText(code: string): string {
  const ll = get(LL)
  switch (code) {
    case 'invalidName':
      return ll.desktopInvalidName()
    case 'duplicateName':
      return ll.desktopDuplicateName()
    case 'invalidHost':
      return ll.desktopInvalidHost()
    case 'invalidPort':
      return ll.desktopInvalidPort()
    case 'invalidUsername':
      return ll.desktopInvalidUsername()
    case 'invalidDomain':
      return ll.desktopInvalidDomain()
    default:
      return code
  }
}
