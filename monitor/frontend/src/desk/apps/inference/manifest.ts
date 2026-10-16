import { defineApp, feature } from '../../sys'

export default defineApp({
  publisher: 'serverbox',
  name: 'inference',
  title: (ll) => ll.inference(),
  keywords: (ll) => [ll.inferenceKeywords(), 'Ollama', 'llama.cpp', 'vLLM', 'SGLang', 'MLX'],
  glyph: 'neurology',
  tone: 'violet',
  available: feature('inference'),
  size: { width: 1080, height: 760 },
  minSize: { width: 520, height: 420 },
  order: 136,
  load: () => import('./InferenceApp.svelte'),
})
