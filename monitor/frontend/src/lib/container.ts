/// What the containers page phrases: refusals, and how an image is named.
///
/// Nothing here decides anything about a runtime — every command is the
/// agent's (`sbm_parser::container`), and whether an image is dangling comes
/// from the agent too (`ContainerImage.dangling`). These only put its words
/// into the viewer's language.
import { get } from 'svelte/store'
import { LL } from '../i18n/i18n-svelte'
import { ApiError } from './api'
import type { ContainerImage } from '../types'

/// `repository:tag`, or the image's id where there is no name to pull by.
export function imageReference(image: ContainerImage): string {
  if (image.dangling) return image.id ?? '<none>'
  const repository = image.repository.trim()
  const tag = (image.tag ?? '').trim()
  return tag === '' ? repository : `${repository}:${tag}`
}

/// Why an action was refused before it ran, from the issue the agent sent. An
/// unknown code is shown as sent: it is a refusal added since.
export function issueText(issue: string): string {
  const ll = get(LL)
  switch (issue) {
    case 'empty':
      return ll.containerErrEmpty()
    case 'control_character':
      return ll.containerErrControlCharacter()
    case 'leading_dash':
      return ll.containerErrLeadingDash()
    case 'too_long':
      return ll.containerErrTooLong()
    case 'invalid_reference':
      return ll.containerErrInvalidReference()
    case 'invalid_name':
      return ll.containerErrInvalidName()
    case 'invalid_args':
      return ll.containerErrInvalidArgs()
    default:
      return issue
  }
}

/// A refusal from a container action: the agent answers
/// `400 {error:"invalid_input", issue:<code>}`, which `errorFrom` turns into an
/// `ApiError` whose `message` is the code and whose `body.issue` is the issue.
/// Falls back to the message for anything else.
export function refusalText(error: unknown): string {
  if (error instanceof ApiError) {
    const issue = error.body?.issue
    if (typeof issue === 'string') return issueText(issue)
    return error.message
  }
  return error instanceof Error ? error.message : String(error)
}
