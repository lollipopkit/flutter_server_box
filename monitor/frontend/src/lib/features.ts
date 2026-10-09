/// The machine-management pages, and which of them this agent offers the
/// caller (issue #1623).
///
/// What each needs of the caller; the desk's app manifests (`desk/apps/<id>/manifest.ts`) ask
/// it whether an app is offered. Ordered by what the thing is — the running
/// machine first, then its configuration, then what lies beyond it.
import { isAdmin, machineAccess } from './access'
import type { Capabilities, GrantName } from '../types'

/// A machine-management page.
export type FeatureId =
  | 'containers'
  | 'process'
  | 'services'
  | 'cron'
  | 'system_users'
  | 'firewall'
  | 'snippets'
  | 'desktop'
  | 'benchmark'
  | 'virt'
  | 'bmc'
  | 'backup'

export interface FeatureSpec {
  id: FeatureId
  /// What the caller's role must hold for the page to be offered, or
  /// `admin` for a page only an admin account may open.
  grant: GrantName | 'admin'
}

export const FEATURES: FeatureSpec[] = [
  { id: 'containers', grant: 'shell' },
  { id: 'process', grant: 'shell' },
  { id: 'services', grant: 'shell' },
  { id: 'cron', grant: 'shell' },
  { id: 'system_users', grant: 'shell' },
  { id: 'firewall', grant: 'shell' },
  { id: 'snippets', grant: 'shell' },
  { id: 'desktop', grant: 'connect' },
  { id: 'benchmark', grant: 'shell' },
  { id: 'virt', grant: 'virt' },
  { id: 'bmc', grant: 'virt' },
  { id: 'backup', grant: 'admin' },
]

/// The pages this agent serves and this caller may use — see
/// `machineAccess`. A page an older agent would 404, or one the role would
/// be refused, is left out rather than opened onto a refusal.
export function enabledFeatures(caps: Capabilities | undefined): FeatureSpec[] {
  return FEATURES.filter((feature) =>
    feature.grant === 'admin'
      ? caps?.features?.includes(feature.id) === true && isAdmin(caps) === true
      : machineAccess(caps, feature.id, feature.grant),
  )
}
