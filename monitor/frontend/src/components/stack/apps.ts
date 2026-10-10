/// The panel's apps that show a web app the agent deploys, by catalog id
/// (`store/apps/<publisher>.<name>`). Such an app is offered once its web app
/// is deployed; it is installed from the App Store.

import type { Capabilities } from '../../types'

export const STACK_APPS: Readonly<Record<string, string>> = { 'futo.immich': 'serverbox.photos' }

/// The catalog id behind the panel's app [appId], if one is.
export function stackOf(appId: string): string | undefined {
  return Object.entries(STACK_APPS).find(([, app]) => app === appId)?.[0]
}

/// Whether [stackId] is deployed for this account to use: set up for
/// everyone; an admin also sees one being set up or that failed, to finish it.
export function stackDeployed(caps: Capabilities | undefined, stackId: string): boolean {
  if (caps?.features?.includes('stacks') !== true) return false
  const stack = caps.stacks?.find((s) => s.id === stackId)
  return !!stack && (stack.state === 'installed' || caps.me?.admin === true)
}
