import { describe, expect, it } from 'vitest'
import { enginePreset } from '../components/stack/preset'
import type { StackManifest } from '../types'

const vllm = {
  id: 'vllm.vllm',
  llm: { port: 'port', path: '/v1', model: 'model', key: 'API_KEY' },
  settings: [
    { type: 'text', key: 'model', label: { en: 'Model' }, env: 'MODEL', pattern: '.*', default: 'Qwen/Qwen3-0.6B' },
    { type: 'port', key: 'port', label: { en: 'Port' }, env: 'PORT', default: 8000 },
  ],
} as unknown as StackManifest

const llama = {
  ...vllm,
  id: 'ggml.llama_cpp',
  settings: [
    ...vllm.settings,
    { type: 'choice', key: 'accel', label: { en: 'Acceleration' }, default: 'cpu', options: [{ value: 'cpu', label: { en: 'CPU' } }, { value: 'nvidia', label: { en: 'NVIDIA' } }] },
  ],
} as unknown as StackManifest

describe('a model server stack set up for a model', () => {
  it('fills the model and the acceleration for the backend the agent chose', () => {
    expect(enginePreset(llama, 'unsloth/Qwen3-8B-GGUF:Q4_K_M', 'cuda')).toEqual({ model: 'unsloth/Qwen3-8B-GGUF:Q4_K_M', accel: 'nvidia' })
    // No acceleration setting, no model: nothing chosen for it.
    expect(enginePreset(vllm, null, 'cuda')).toEqual({})
    // A backend the stack has no choice for keeps its default.
    expect(enginePreset(llama, null, 'rocm')).toEqual({})
  })
})
