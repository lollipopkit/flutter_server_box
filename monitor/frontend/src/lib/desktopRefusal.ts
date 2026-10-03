/// Why the agent refused a set of desktop routes, phrased in the viewer's
/// language: `sbm_parser::desktop::ProfileError`'s codes (the rules the app's
/// editor applies too) and the set's own (`api::desktops::Refusal`). A code
/// this build does not know is shown as the agent sent it.
import { get } from 'svelte/store'
import { LL } from '../i18n/i18n-svelte'
import { ApiError } from './api'

export function desktopRefusalText(e: unknown): string {
  if (!(e instanceof ApiError)) return e instanceof Error ? e.message : String(e)
  const ll = get(LL)
  switch (e.message) {
    case 'invalidId':
    case 'duplicateId':
      return ll.desktopInvalidId()
    case 'nameRequired':
    case 'invalidName':
      return ll.desktopInvalidName()
    case 'duplicateName':
      return ll.desktopDuplicateName()
    case 'invalidProtocol':
      return ll.desktopInvalidProtocol()
    case 'hostRequired':
    case 'invalidHost':
      return ll.desktopInvalidHost()
    case 'invalidPort':
      return ll.desktopInvalidPort()
    case 'usernameRequired':
      return ll.desktopRdpUsername()
    case 'invalidCredential':
      return ll.desktopInvalidCredential()
    default:
      return e.message
  }
}
