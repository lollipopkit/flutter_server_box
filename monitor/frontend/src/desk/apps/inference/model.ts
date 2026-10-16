/// Local inference's words for what the agent decided: engine names, the
/// stacks that run them, and a candidate's settings for its engine. Nothing
/// here decides what fits (`sbm_parser::inference` does).

import type { InferenceCandidate, InferenceEngine, InferenceEngineFit, StackManifest, StackValue } from '../../../types'

export const ENGINE_NAMES: Record<InferenceEngine, string> = {
  ollama: 'Ollama',
  llamacpp: 'llama.cpp',
  vllm: 'vLLM',
  sglang: 'SGLang',
  mlx: 'MLX',
}

/// The `accel` option of a stack for the backend the agent chose.
const ACCEL: Record<InferenceEngineFit['backend'], string> = { cuda: 'nvidia', rocm: 'rocm', vulkan: 'vulkan', metal: 'cpu', cpu: 'cpu' }

/// The settings an engine's stack is deployed with to serve [candidate].
export function presetFor(
  fit: InferenceEngineFit,
  manifest: StackManifest,
  candidate: InferenceCandidate | null,
): Record<string, StackValue> {
  const preset: Record<string, StackValue> = {}
  const has = (key: string) => manifest.settings.some((s) => s.key === key)
  const model = manifest.llm?.model
  if (candidate && model && has(model)) preset[model] = candidate.setting
  const accel = manifest.settings.find((s) => s.key === 'accel')
  if (accel?.type === 'choice' && accel.options.some((o) => o.value === ACCEL[fit.backend])) preset.accel = ACCEL[fit.backend]
  return preset
}

export function gib(n: number | null | undefined): string {
  return n == null ? '—' : `${n.toFixed(n < 10 ? 1 : 0)} GiB`
}

export function mibAsGib(n: number | null | undefined): string {
  return n == null ? '—' : gib(n / 1024)
}

export function bytes(n: number | null | undefined): string {
  if (n == null) return '—'
  const units = ['B', 'KB', 'MB', 'GB', 'TB']
  let v = n
  let i = 0
  while (v >= 1000 && i < units.length - 1) {
    v /= 1000
    i++
  }
  return `${v.toFixed(v < 10 && i > 0 ? 1 : 0)} ${units[i]}`
}
