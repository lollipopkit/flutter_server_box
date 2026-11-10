import { registry } from '../registry.svelte'
import { defineApp, type AppManifest } from './manifest'

/// Adds an app to this page's desk at run time; the returned function takes
/// it away again.
export function registerApp(manifest: AppManifest): () => void {
  return registry.register(defineApp(manifest))
}
