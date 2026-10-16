import { defineApp, feature } from '../../sys'

export default defineApp({
  publisher: 'serverbox',
  name: 'agent_tools',
  title: (ll) => ll.agentTools(),
  keywords: (ll) => [ll.agentToolsKeywords(), 'Codex', 'Claude Code', 'pi', 'opencode', 'Hermes', 'OpenClaw'],
  glyph: 'smart_toy',
  tone: 'teal',
  available: feature('agent_tools'),
  size: { width: 980, height: 700 },
  minSize: { width: 480, height: 400 },
  order: 137,
  load: () => import('./AgentToolsApp.svelte'),
})
