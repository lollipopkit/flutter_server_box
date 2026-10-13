/// The panel's apps that show a web app the agent deploys, by catalog id
/// (`store/apps/<publisher>.<name>`). Such an app is offered once its web app
/// is deployed; it is installed from the App Store.

import type { Capabilities } from '../../types'

export const STACK_APPS: Readonly<Record<string, string>> = { 'futo.immich': 'serverbox.photos' }

/// The catalog ids registered as desk apps of their own (`desk/stacks/register.ts`).
const registered = new Set<string>()

/// Remembers [ids] as registered; the returned function forgets them.
export function rememberStackApps(ids: string[]): () => void {
  ids.forEach((id) => registered.add(id))
  return () => ids.forEach((id) => registered.delete(id))
}

/// The desk app that shows web app [stackId]: the panel's own, else the one
/// registered by its id; undefined when there is none.
export function stackAppId(stackId: string): string | undefined {
  return STACK_APPS[stackId] ?? (registered.has(stackId) ? stackId : undefined)
}

/// The catalog id behind the panel's app [appId], if one is.
export function stackOf(appId: string): string | undefined {
  return Object.entries(STACK_APPS).find(([, app]) => app === appId)?.[0] ?? (registered.has(appId) ? appId : undefined)
}

/// Whether [stackId] is deployed for this account to use: set up for
/// everyone; an admin also sees one being set up or that failed, to finish it.
export function stackDeployed(caps: Capabilities | undefined, stackId: string): boolean {
  if (caps?.features?.includes('stacks') !== true) return false
  const stack = caps.stacks?.find((s) => s.id === stackId)
  return !!stack && (stack.state === 'installed' || caps.me?.admin === true)
}
