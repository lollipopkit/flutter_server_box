/// The settings a model server's stack (an engine, `ENGINE_STACKS`) is set
/// up with to serve a model on a backend the agent chose: its model setting
/// and its acceleration choice. Nothing here decides what fits.

import type { StackManifest, StackValue } from '../../types'

/// The `accel` option of a stack for each backend.
const ACCEL: Record<string, string> = { cuda: 'nvidia', rocm: 'rocm', vulkan: 'vulkan', metal: 'cpu', cpu: 'cpu' }

export function enginePreset(manifest: StackManifest, model: string | null, backend: string): Record<string, StackValue> {
  const preset: Record<string, StackValue> = {}
  const has = (key: string) => manifest.settings.some((s) => s.key === key)
  const key = manifest.llm?.model
  if (model && key && has(key)) preset[key] = model
  const accel = manifest.settings.find((s) => s.key === 'accel')
  if (accel?.type === 'choice' && accel.options.some((o) => o.value === ACCEL[backend])) preset.accel = ACCEL[backend]
  return preset
}
