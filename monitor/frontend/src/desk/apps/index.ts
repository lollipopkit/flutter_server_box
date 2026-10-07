/// Registers the built-in apps: every `apps/<id>/manifest.ts`. Adding an app
/// is adding its directory; nothing else lists it.

import { registry } from '../registry.svelte'
import type { AppSpec } from '../sys/manifest'

const manifests = import.meta.glob<AppSpec>('./*/manifest.ts', { eager: true, import: 'default' })

// A manifest edited in development registers again rather than twice.
const off = Object.values(manifests).map((spec) => registry.register(spec))
import.meta.hot?.dispose(() => off.forEach((f) => f()))
