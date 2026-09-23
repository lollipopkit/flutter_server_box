/// A write refused before it ran arrives as a stable code rather than as a
/// sentence, so the panel phrases it in the viewer's own language.
///
/// The codes are `sbm_parser::UserError`'s own — its `as_str` — plus the ones
/// the endpoint answers with about the machine rather than about the request.
/// Both are one list at the call site because a refusal is refused either way.
///
/// A word this build does not know is shown as the agent sent it: it is a
/// refusal added since, and a sentence invented here would misdescribe it.
import { get } from 'svelte/store'
import { LL } from '../i18n/i18n-svelte'

export function userRefusalText(code: string): string {
  const ll = get(LL)
  switch (code) {
    case 'invalidName':
      return ll.userInvalidName()
    case 'lineBreak':
      return ll.userInvalidLineBreak()
    // One sentence for both: what it says is that the name is not one this
    // machine accepts, and which of the two fields held it is on screen.
    case 'invalidPrimaryGroup':
    case 'invalidSupplementaryGroup':
      return ll.userInvalidGroup()
    case 'passwordLineBreak':
      return ll.userPasswordLineBreak()
    case 'renaming':
      return ll.userRenaming()
    case 'rootNotDeletable':
      return ll.userRootNotDeletable()
    case 'userExists':
      return ll.userUserExists()
    case 'agentAccount':
      return ll.userAgentAccount()
    case 'noSuchUser':
      return ll.userNoSuchUser()
    case 'unsupportedPlatform':
      return ll.userUnsupportedPlatform()
    case 'unreadable':
      return ll.userUnreadable()
    default:
      return code
  }
}
