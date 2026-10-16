import { describe, it, expect, vi, beforeEach } from 'vitest'
import { render, screen, fireEvent } from '@testing-library/svelte'
import '@testing-library/jest-dom/vitest'
import InferenceApp from '../desk/apps/inference/InferenceApp.svelte'
import { presetFor } from '../desk/apps/inference/model'
import { api } from '../lib/api'
import { servers } from '../lib/servers.svelte'
import { capabilitiesStore } from '../lib/capabilities.svelte'
import type { InferenceCandidate, InferenceView, StackApp, StackManifest } from '../types'

vi.mock('../lib/api', async (importOriginal) => ({
  ...(await importOriginal<typeof import('../lib/api')>()),
  api: {
    getInference: vi.fn(),
    listStacks: vi.fn(),
    recommendModels: vi.fn(),
    ollamaModels: vi.fn(),
    pullOllama: vi.fn(),
    prepareStack: vi.fn(),
    startMlx: vi.fn(),
  },
}))

const mocked = vi.mocked(api)

const vllm = {
  id: 'vllm.vllm',
  publisher: 'vllm',
  name: 'vllm',
  project: 'vLLM',
  version: '0.30.0',
  homepage: 'https://vllm.ai',
  source: 'https://github.com/vllm-project/vllm',
  glyph: 'bolt',
  tone: 'violet',
  categories: ['ai'],
  notices: [],
  title: { en: 'vLLM' },
  description: { en: 'Serve one model.' },
  license: { spdx: 'Apache-2.0', url: 'https://example.com', accept: false },
  requirements: { arch: [], os: ['linux'] },
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

const view: InferenceView = {
  hardware: { os: 'linux', arch: 'x86_64', memoryMib: 40960, gpus: [{ vendor: 'nvidia', name: 'Tesla T10', memoryMib: 16384, compute: 75 }], docker: true, nvidiaContainers: true, rocmDevices: false, dri: false, python: true },
  engines: [
    { engine: 'vllm', backend: 'cuda', blocked: null, app: 'vllm.vllm' },
    { engine: 'llamacpp', backend: 'cuda', blocked: null, app: 'ggml.llama_cpp' },
    { engine: 'mlx', backend: 'metal', blocked: 'needsAppleSilicon', app: null },
  ],
  mlx: null,
  ollama: [],
  pulls: [],
  llmfit: { version: '1.1.16', installed: true },
  job: null,
}

const candidate = (setting: string): InferenceCandidate => ({
  engine: 'vllm', name: 'Qwen/Qwen3-4B-AWQ', setting, fit: 'perfect', score: 90, paramsB: 4, memoryGib: 4.2, tokensPerSecond: null, capabilities: [],
})

const part = (manifest: StackManifest): StackApp => ({ manifest, source: 'part', stack: null, job: null, proxy: false })

beforeEach(() => {
  vi.clearAllMocks()
  servers.list = [{ id: 'local', url: '', token: 't' }]
  servers.currentId = 'local'
  capabilitiesStore.byServer.local = { features: ['inference', 'stacks'], access: { ok: true } } as never
  mocked.getInference.mockResolvedValue(structuredClone(view))
  mocked.listStacks.mockResolvedValue({ apps: [part(vllm), part(llama), { ...part(vllm), source: 'bundled', manifest: { ...vllm, id: 'other.app' } }] })
  mocked.recommendModels.mockResolvedValue({ engines: ['vllm', 'llamacpp'], candidates: { vllm: [candidate('Qwen/Qwen3-4B-AWQ')], llamacpp: [] } })
  mocked.prepareStack.mockReturnValue(new Promise(() => {}))
})

describe('Local inference', () => {
  it('fills the engine stack with the model and the backend the agent chose', () => {
    const c = candidate('unsloth/Qwen3-8B-GGUF:Q4_K_M')
    expect(presetFor(view.engines[1], llama, c)).toEqual({ model: 'unsloth/Qwen3-8B-GGUF:Q4_K_M', accel: 'nvidia' })
    // No acceleration setting, no model: nothing chosen for it.
    expect(presetFor(view.engines[0], vllm, null)).toEqual({})
  })

  it('shows the machine and why an engine cannot run', async () => {
    render(InferenceApp)
    expect(await screen.findByText('Tesla T10')).toBeInTheDocument()
    expect(screen.getByText('Compute capability 7.5')).toBeInTheDocument()
    expect(screen.getByText('Best for this machine')).toBeInTheDocument()
    expect(screen.getByText('Needs a Mac with Apple silicon')).toBeInTheDocument()
  })

  it('runs a recommended model by setting its engine up with it', async () => {
    render(InferenceApp)
    await screen.findByText('Tesla T10')
    await fireEvent.click(screen.getAllByText('Models')[0])
    expect(await screen.findByText('Qwen/Qwen3-4B-AWQ')).toBeInTheDocument()
    expect(mocked.recommendModels).toHaveBeenCalledWith(null, false)
    await fireEvent.click(screen.getByRole('button', { name: 'Run' }))
    // vLLM's page, its setup open: the agent is asked what this machine has.
    await vi.waitFor(() => expect(mocked.prepareStack).toHaveBeenCalledWith('vllm.vllm'))
  })
})
