/// Local inference's service as the page reads it (`wit/inference.wit`), and
/// its words for sizes. Nothing here decides what fits.

export type Engine = 'ollama' | 'llamacpp' | 'vllm' | 'sglang' | 'mlx'

export const ENGINE_NAMES: Record<Engine, string> = {
  ollama: 'Ollama',
  llamacpp: 'llama.cpp',
  vllm: 'vLLM',
  sglang: 'SGLang',
  mlx: 'MLX',
}

export interface Gpu {
  vendor: string
  name: string
  memoryMib: number | null
  compute: number | null
}

export interface EngineFit {
  engine: Engine
  backend: string
  blocked: string | null
  cpuBecause: string | null
  stack: string | null
  deployed: { state: string; stopped: boolean; health: string | null } | null
}

export interface Overview {
  hardware: { os: string; arch: string; memoryMib: number; gpus: Gpu[]; docker: boolean; nvidiaContainers: boolean }
  engines: EngineFit[]
  mlx: { installed: boolean; version: string; service: { model: string | null; port: number | null; running: boolean } } | null
  ollama: { id: string; url: string; version: string | null }[]
  llmfitVersion: string
}

export interface Candidate {
  engine: Engine
  name: string
  setting: string
  fit: string
  score: number
  paramsB: number | null
  memoryGib: number | null
  tokensPerSecond: number | null
  contextLength: number | null
  license: string | null
}

export interface Recommendation {
  engines: Engine[]
  candidates: Candidate[]
}

export interface OllamaModel {
  name: string
  size: number
  parameterSize: string | null
  quantization: string | null
  loaded: boolean
}

export function gib(n: number | null | undefined): string {
  return n == null ? '—' : `${n.toFixed(n < 10 ? 1 : 0)} GiB`
}

export function mibAsGib(n: number | null | undefined): string {
  return n == null ? '—' : gib(n / 1024)
}
