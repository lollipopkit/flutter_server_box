/// Which features a managed machine has, and which of them this agent serves.
///
/// The list is one list. The tab bar draws it, the Dashboard's entry opens it,
/// and a feature page says which of them it is — the alternative, every page
/// naming its neighbours, makes the set of features a property of whichever
/// page you happen to be looking at, and a page added later ends up reachable
/// only from the pages written after it.
///
/// Ordering is by what the thing is rather than by when it was built — the
/// running machine first (containers, processes, services), then the machine's
/// own configuration (users, schedule, desktops), then the operator's own
/// scripts to type into a shell (snippets), then the agent that operates it,
/// then a measurement of it (benchmark). TODO: PVE, BMC and sync join this
/// list as they land; the bar scrolls rather than wrapping.
///
/// How each one is *drawn* (its label and its icon) is deliberately not here:
/// a label is `$LL` and an icon is a component, and this module is imported by
/// plain TypeScript. `components/FeatureTabs.svelte` owns that.
import type { RemoteAccess } from '../types'

/// A machine-management screen this panel may open.
///
/// It is a subset of `View` — `layout.svelte.ts` widens `View` with this type
/// rather than repeating the names, so the two cannot drift.
export type FeatureId =
  | 'containers'
  | 'process'
  | 'services'
  | 'users'
  | 'cron'
  | 'desktop'
  | 'snippets'
  | 'ai'
  | 'benchmark'

export interface FeatureSpec {
  /// The `View` this feature renders as, and how `layout.navigate` names it.
  id: FeatureId
  /// The `remote_access` field that says this agent serves it.
  ///
  /// Its own field per feature rather than one shared grant: an agent older
  /// than the endpoint answers `full_access` and would 404 the request, so a
  /// check against the wider grant would put a tab on screen that cannot load.
  capability: keyof RemoteAccess
}

export const FEATURES: FeatureSpec[] = [
  { id: 'containers', capability: 'containers' },
  { id: 'process', capability: 'process' },
  { id: 'services', capability: 'services' },
  { id: 'users', capability: 'users' },
  { id: 'cron', capability: 'cron' },
  { id: 'desktop', capability: 'desktop' },
  { id: 'snippets', capability: 'snippets' },
  { id: 'ai', capability: 'ai' },
  { id: 'benchmark', capability: 'benchmark' },
]

/// The features this agent serves.
///
/// Strictly `=== true`, so a capability that is missing and one that is off
/// both leave the feature out. An agent older than the endpoint is the one that
/// answers 404, and a tab that opens onto a refusal is worse than one that is
/// not there — which is why each feature names its own field rather than
/// checking a shared grant, since a wider grant would put a tab on screen for
/// an agent that never served it.
///
/// A grant that only withholds *writes* does not remove a tab: the page goes
/// read-only off `editable` in the response instead, which is what `cron` and
/// `containers` report. The two cases are not told apart here because nothing
/// acts on the difference yet; when the Dashboard wants to say "this agent is
/// too old for that", it can say so where it lists servers rather than per tab.
export function enabledFeatures(remoteAccess: RemoteAccess | undefined): FeatureSpec[] {
  return FEATURES.filter((feature) => remoteAccess?.[feature.capability] === true)
}
