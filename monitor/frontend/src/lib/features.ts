/// The machine-management pages, and which of them this agent offers the
/// caller (issue #1623).
///
/// One list: the tab bar draws it, the Dashboard opens its first entry, and a
/// page names itself in it. Ordered by what the thing is — the running
/// machine first, then its configuration, then what lies beyond it.
///
/// How each is drawn (label, icon) is `components/FeatureTabs.svelte`'s: a
/// label is `$LL` and an icon a component, and this module is plain
/// TypeScript.
import { machineAccess } from './access'
import type { Capabilities, GrantName } from '../types'

/// A machine-management page. Also a `View` — `layout.svelte.ts` widens it
/// with this type, so the two cannot drift.
export type FeatureId = 'containers' | 'process' | 'services' | 'cron' | 'benchmark'

export interface FeatureSpec {
  id: FeatureId
  /// What the caller's role must hold for the page to be offered.
  grant: GrantName
}

export const FEATURES: FeatureSpec[] = [
  { id: 'containers', grant: 'shell' },
  { id: 'process', grant: 'shell' },
  { id: 'services', grant: 'shell' },
  { id: 'cron', grant: 'shell' },
  { id: 'benchmark', grant: 'shell' },
]

/// The pages this agent serves and this caller may use — see
/// `machineAccess`. A page an older agent would 404, or one the role would
/// be refused, is left out rather than opened onto a refusal.
export function enabledFeatures(caps: Capabilities | undefined): FeatureSpec[] {
  return FEATURES.filter((feature) => machineAccess(caps, feature.id, feature.grant))
}
