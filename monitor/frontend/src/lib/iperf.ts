/// What the iperf dialog phrases: the agent's refusal of a host or a port.
///
/// Nothing here decides anything about iperf — the rules are
/// `sbm_parser::iperf::normalize_host` / `valid_port`, and the command is
/// built there too. This only puts the issue code the agent sent into the
/// viewer's language.
import { get } from 'svelte/store'
import { LL } from '../i18n/i18n-svelte'

/// A refused iperf value, from the issue code. An unknown code is shown as
/// sent: it is a refusal added since.
export function iperfIssueText(issue: string): string {
  const ll = get(LL)
  switch (issue) {
    case 'empty_host':
      return ll.iperfErrEmptyHost()
    case 'invalid_host':
      return ll.iperfErrInvalidHost()
    case 'invalid_port':
      return ll.iperfErrInvalidPort()
    default:
      return issue
  }
}
