/// What the firewall page phrases: refusals, issues and the ways in. Kept out
/// of the page so the switches over the agent's codes are tested on their own.
///
/// Nothing here decides anything about a firewall — what a change does is the
/// agent's plan (`sbm_parser::firewall::change`). These only put its words
/// into the viewer's language.
import { get } from 'svelte/store'
import { LL } from '../i18n/i18n-svelte'
import type {
  FirewallAccess,
  FirewallReach,
  FirewalldInputIssue,
  UfwDraftIssue,
  UfwEndpoint,
  UfwRule,
  UfwRuleDraft,
} from '../types'

export function draftIssueText(issue: UfwDraftIssue): string {
  const ll = get(LL)
  switch (issue) {
    case 'nothing_matched':
      return ll.fwNothingMatched()
    case 'invalid_port':
      return ll.fwInvalidPort()
    case 'too_many_ports':
      return ll.fwTooManyPorts()
    case 'ports_need_protocol':
      return ll.fwPortsNeedProtocol()
    case 'invalid_address':
      return ll.fwInvalidAddress()
    case 'mixed_ip_versions':
      return ll.fwMixedIpVersions()
    case 'invalid_interface':
      return ll.fwInvalidInterface()
    case 'invalid_comment':
      return ll.fwInvalidComment()
    case 'invalid_protocol':
      return ll.fwInvalidProtocol()
    default:
      return issue
  }
}

export function inputIssueText(issue: FirewalldInputIssue): string {
  const ll = get(LL)
  switch (issue) {
    case 'invalid_port':
      return ll.fwInvalidPort()
    case 'invalid_source':
      return ll.fwInvalidSource()
    case 'invalid_interface':
      return ll.fwInvalidInterface()
    case 'invalid_rich_rule':
      return ll.fwInvalidRichRule()
    case 'invalid_forward_port':
      return ll.fwInvalidForwardPort()
    default:
      return issue
  }
}

/// A change refused before anything ran, from the code the agent answered
/// with and, for a draft or a typed value, the issue in `body.issue`. An
/// unknown code is shown as sent: it is a refusal added since.
export function refusalText(code: string, body?: Record<string, unknown>): string {
  const ll = get(LL)
  const issue = (body?.issue as { issue?: string } | null | undefined)?.issue
  switch (code) {
    case 'invalidRule':
      return issue ? draftIssueText(issue as UfwDraftIssue) : code
    case 'invalidInput':
      return issue ? inputIssueText(issue as FirewalldInputIssue) : code
    case 'noSuchRule':
      return ll.fwNoSuchRule()
    case 'noSuchZone':
      return ll.fwNoSuchZone()
    case 'notInstalled':
      return ll.fwNotInstalled()
    case 'unreadable':
      return ll.fwUnreadable()
    default:
      return code
  }
}

export function accessName(access: FirewallAccess): string {
  const ll = get(LL)
  return access.via === 'monitor'
    ? ll.fwAccessPanel({ port: access.port })
    : ll.fwAccessSsh({ port: access.port })
}

export function reachText(reach: FirewallReach): string {
  const ll = get(LL)
  switch (reach) {
    case 'open':
      return ll.fwReachOpen()
    case 'limited':
      return ll.fwReachLimited()
    case 'unknown':
      return ll.fwReachUnknown()
    case 'blocked':
      return ll.fwReachBlocked()
  }
}

export function reachTone(reach: FirewallReach): 'success' | 'warning' | 'danger' {
  return reach === 'open' ? 'success' : reach === 'blocked' ? 'danger' : 'warning'
}

/// What a change would do to one way in, as the confirmation says it.
export function warningText(access: FirewallAccess, after: FirewallReach, later: boolean): string {
  const ll = get(LL)
  const name = accessName(access)
  switch (after) {
    case 'blocked':
      return later ? ll.fwDriftLockout({ access: name }) : ll.fwWillRefuse({ access: name })
    case 'unknown':
      return ll.fwMayRefuse({ access: name })
    case 'limited':
      return ll.fwRateLimited({ access: name })
    default:
      return ''
  }
}

/// One side of a ufw rule as `ufw status` would say it.
export function endpointText(endpoint: UfwEndpoint, protocol: string | null): string {
  const parts: string[] = []
  if (endpoint.address) parts.push(endpoint.address)
  if (endpoint.app) parts.push(endpoint.app)
  else if (endpoint.port) parts.push(protocol ? `${endpoint.port}/${protocol}` : endpoint.port)
  return parts.length ? parts.join(' ') : get(LL).fwAnywhere()
}

export function ruleText(rule: UfwRule): string {
  return `${rule.action} ${endpointText(rule.to, rule.protocol)}`
}

export function emptyDraft(): UfwRuleDraft {
  return {
    action: 'allow',
    direction: 'incoming',
    routed: false,
    protocol: null,
    port: '',
    source_port: '',
    app: null,
    from: '',
    to: '',
    interface_in: '',
    interface_out: '',
    log: null,
    comment: '',
    prepend: false,
  }
}
