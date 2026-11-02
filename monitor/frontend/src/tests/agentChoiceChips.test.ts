import { get } from 'svelte/store'
import { describe, it, expect } from 'vitest'
import { render, screen, fireEvent } from '@testing-library/svelte'
import '@testing-library/jest-dom/vitest'
import ChoiceChips from '../desk/agent/ChoiceChips.svelte'
import type { AgentStore } from '../desk/agent/agentStore.svelte'
import type { Draft } from '../desk/agent/attachments.svelte'
import { LL } from '../i18n/i18n-svelte'

const ll = get(LL)

const store = {
  choices: {
    models: [
      { provider: 'openai', id: 'gpt-6-luna', name: 'GPT-6 Luna', reasoning: true },
      { provider: 'anthropic', id: 'claude', name: 'Claude', reasoning: true },
    ],
    thinkingLevels: ['off', 'low', 'high'],
    model: { provider: 'openai', id: 'gpt-6-luna' },
    thinkingLevel: 'off',
  },
} as unknown as AgentStore

describe('the model and thinking chips', () => {
  // The composer's row clips what leaves it: the menus are drawn in its box.
  it('open their menus in the host, and pick from there', async () => {
    const host = document.createElement('div')
    document.body.appendChild(host)
    const draft = { model: null, thinking: null } as unknown as Draft
    render(ChoiceChips, { store, draft, host })

    await fireEvent.click(screen.getByRole('button', { name: ll.deskAgentPickModel() }))
    const models = screen.getByRole('menu', { name: ll.deskAgentPickModel() })
    expect(host.contains(models)).toBe(true)
    await fireEvent.mouseDown(screen.getByRole('menuitemradio', { name: /Claude/ }))
    await fireEvent.click(screen.getByRole('menuitemradio', { name: /Claude/ }))
    expect(draft.model).toEqual({ provider: 'anthropic', id: 'claude' })
    expect(screen.queryByRole('menu')).toBeNull()

    await fireEvent.click(screen.getByRole('button', { name: ll.deskAgentPickThinking() }))
    const levels = screen.getByRole('menu', { name: ll.deskAgentPickThinking() })
    expect(host.contains(levels)).toBe(true)
    await fireEvent.click(screen.getByRole('menuitemradio', { name: ll.settingsAgentThinkingHigh() }))
    expect(draft.thinking).toBe('high')
  })

  it('close on a press outside', async () => {
    const host = document.createElement('div')
    document.body.appendChild(host)
    render(ChoiceChips, { store, draft: { model: null, thinking: null } as unknown as Draft, host })
    await fireEvent.click(screen.getByRole('button', { name: ll.deskAgentPickModel() }))
    await fireEvent.mouseDown(document.body)
    expect(screen.queryByRole('menu')).toBeNull()
  })
})
