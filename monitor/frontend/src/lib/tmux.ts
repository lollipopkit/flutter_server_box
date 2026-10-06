/// What the terminal page phrases: the agent's refusal of a tmux session id or
/// a new session's name.
///
/// Nothing here decides anything about tmux — the rules are
/// `sbm_parser::tmux`'s, and the command is built there too. This only puts the
/// issue code the agent sent into the viewer's language.
import { get } from 'svelte/store'
import { LL } from '../i18n/i18n-svelte'

/// A refused tmux value, from the issue code; null for a code this build does
/// not know, which is a refusal added since — the caller then shows the
/// agent's own message rather than the bare code.
export function tmuxIssueText(issue: string): string | null {
  const ll = get(LL)
  switch (issue) {
    case 'invalid_session_id':
      return ll.terminalTmuxErrInvalidSession()
    case 'empty_name':
      return ll.terminalTmuxErrEmptyName()
    case 'name_too_long':
      return ll.terminalTmuxErrNameTooLong()
    case 'name_control_char':
      return ll.terminalTmuxErrNameControl()
    case 'name_separator':
      return ll.terminalTmuxErrNameSeparator()
    case 'name_leading_dash':
      return ll.terminalTmuxErrNameLeadingDash()
    default:
      return null
  }
}
