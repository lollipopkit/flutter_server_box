import { describe, it, expect, vi, beforeEach } from 'vitest'
import { render, screen, fireEvent } from '@testing-library/svelte'
import '@testing-library/jest-dom/vitest'
import AgentToolsApp from '../desk/apps/agent_tools/AgentToolsApp.svelte'
import { api } from '../lib/api'
import { servers } from '../lib/servers.svelte'
import { capabilitiesStore } from '../lib/capabilities.svelte'
import type { AgentToolView } from '../types'

vi.mock('../lib/api', async (importOriginal) => ({
  ...(await importOriginal<typeof import('../lib/api')>()),
  api: { getAgentTools: vi.fn(), agentToolProviders: vi.fn(), changeAgentTool: vi.fn(), configureAgentTool: vi.fn(), agentToolsJob: vi.fn() },
}))

const mocked = vi.mocked(api)
const tool = (id: AgentToolView['tool'], apis: string[], path: string | null = null): AgentToolView => ({
  tool: id, path, version: path ? '1.0.0' : null, pinned: '1.0.0', homepage: 'https://example.com', gateway: id === 'openclaw', apis,
})

beforeEach(() => {
  vi.clearAllMocks()
  servers.list = [{ id: 'local', url: '', token: 't' }]
  servers.currentId = 'local'
  capabilitiesStore.byServer.local = { features: ['agent_tools'], access: { ok: true } } as never
  mocked.getAgentTools.mockResolvedValue({
    tools: [tool('codex', ['openai-responses']), tool('pi', ['openai-completions', 'anthropic-messages'], '/home/a/.local/bin/pi')],
    job: null,
  })
  mocked.agentToolProviders.mockResolvedValue({
    providers: [
      { id: 'app.ollama.ollama', name: 'Ollama (this machine)', api: 'openai-completions', baseUrl: 'http://127.0.0.1:11434/v1', models: ['qwen3:0.6b'] },
      { id: 'anthropic', name: 'Anthropic', api: 'anthropic-messages', baseUrl: 'https://api.anthropic.com', models: ['claude-x'] },
    ],
  })
  mocked.configureAgentTool.mockResolvedValue(undefined)
  mocked.changeAgentTool.mockResolvedValue({ id: 1, kind: 'install', state: 'running', error: null, lines: [], next: 0 })
  mocked.agentToolsJob.mockReturnValue(new Promise(() => {}))
})

describe('AI agents', () => {
  it('installs a tool that is not there', async () => {
    render(AgentToolsApp)
    await fireEvent.click(await screen.findByRole('button', { name: 'Install' }))
    expect(mocked.changeAgentTool).toHaveBeenCalledWith('codex', 'install', false)
  })

  it('points an installed tool at a provider it can speak to', async () => {
    render(AgentToolsApp)
    await fireEvent.click(await screen.findByText('pi'))
    await fireEvent.click(await screen.findByRole('button', { name: 'Use' }))
    expect(mocked.configureAgentTool).toHaveBeenCalledWith('pi', 'app.ollama.ollama', 'qwen3:0.6b')
    expect(await screen.findByText('Now uses qwen3:0.6b.')).toBeInTheDocument()
  })
})
