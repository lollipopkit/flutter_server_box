/// The desk's apps: every manifest registered, built in or added at run time
/// (`sys.registerApp`). The shell reads apps from here and nowhere else.

import type { Capabilities } from '../types'
import type { AppSpec } from './sys/manifest'

class AppRegistry {
  #apps = $state.raw<AppSpec[]>([])

  /// In the launchpad's order.
  get all(): AppSpec[] {
    return this.#apps
  }

  /// Adds [spec]; the returned function takes it away again (its open
  /// windows stay until closed, and are dropped on the next restore).
  register(spec: AppSpec): () => void {
    if (this.#apps.some((a) => a.id === spec.id)) throw new Error(`app ${spec.id} is registered already`)
    this.#apps = [...this.#apps, spec].sort((a, b) => a.order - b.order || a.id.localeCompare(b.id))
    return () => {
      this.#apps = this.#apps.filter((a) => a !== spec)
    }
  }

  get(id: string): AppSpec | undefined {
    return this.#apps.find((a) => a.id === id)
  }
}

export const registry = new AppRegistry()

export function app(id: string): AppSpec | undefined {
  return registry.get(id)
}

/// The apps this server and account can use, in the launchpad's order.
export function availableApps(caps: Capabilities | undefined): AppSpec[] {
  return registry.all.filter((a) => a.available(caps))
}

/// What a fresh desk's dock holds, before anyone arranged it.
export function defaultDock(): string[] {
  return registry.all.filter((a) => a.pinned).map((a) => a.id)
}
