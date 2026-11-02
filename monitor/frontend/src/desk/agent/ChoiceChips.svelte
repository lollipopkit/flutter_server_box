<script lang="ts">
  /// The model and thinking level a task runs with, beside a composer: what
  /// the account picked for the next message ([draft]), else what [flow] has,
  /// else the machine's. Nothing when the agent offers no choice.

  import { LL } from '../../i18n/i18n-svelte'
  import type { Flow, ModelChoice, ModelRef } from '../../lib/agentApi'
  import { Icon, Menu, type MenuEntry } from '../lk'
  import type { AgentStore } from './agentStore.svelte'
  import type { Draft } from './attachments.svelte'

  interface Props {
    store: AgentStore
    draft: Draft
    flow?: Flow | null
    small?: boolean
    /// Where the menus open: above (a composer at the bottom) or below.
    down?: boolean
    disabled?: boolean
    /// Where the menus are drawn, when the chips sit in a row that clips what
    /// leaves it (the composer's, which collapses on focus): the menu opens
    /// from there, under the chips.
    host?: HTMLElement | null
  }

  const { store, draft, flow = null, small = false, down = false, disabled = false, host = null }: Props = $props()

  let open = $state<'model' | 'thinking' | null>(null)
  let root = $state<HTMLDivElement | null>(null)
  let menu = $state<HTMLDivElement | null>(null)
  // The chips' offset in [host], where a menu drawn there starts.
  let left = $state(0)

  function inHost(node: HTMLElement) {
    if (!host || !root) return
    left = root.getBoundingClientRect().left - host.getBoundingClientRect().left
    host.appendChild(node)
    return { destroy: () => node.remove() }
  }

  const same = (a: ModelRef | null | undefined, b: ModelRef | null | undefined) => !!a && !!b && a.provider === b.provider && a.id === b.id
  const choices = $derived(store.choices)
  const ref = $derived(draft.model ?? flow?.model ?? choices?.model ?? null)
  const model = $derived<ModelChoice | null>(choices?.models.find((m) => same(m, ref)) ?? ref)
  const thinking = $derived(draft.thinking ?? flow?.thinkingLevel ?? choices?.thinkingLevel ?? 'off')
  const level = (l: string) =>
    ({
      off: $LL.settingsAgentThinkingOff(),
      low: $LL.settingsAgentThinkingLow(),
      medium: $LL.settingsAgentThinkingMedium(),
      high: $LL.settingsAgentThinkingHigh(),
    })[l] ?? l

  // A menu closes on a press anywhere else.
  $effect(() => {
    if (!open) return
    const down = (e: MouseEvent) => {
      const at = e.target as Node
      if (!root?.contains(at) && !menu?.contains(at)) open = null
    }
    document.addEventListener('mousedown', down)
    return () => document.removeEventListener('mousedown', down)
  })

  const keep = (e: Event) => e.preventDefault()

  const modelItems = $derived<MenuEntry[]>([
    { heading: $LL.deskAgentPickModel() },
    ...(choices?.models ?? []).map((m) => ({
      label: m.name ?? m.id,
      shortcut: m.provider,
      checked: same(m, model),
      action: () => (draft.model = { provider: m.provider, id: m.id }),
    })),
  ])
  const thinkingItems = $derived<MenuEntry[]>([
    { heading: $LL.deskAgentPickThinking() },
    ...(choices?.thinkingLevels ?? []).map((l) => ({ label: level(l), checked: l === thinking, action: () => (draft.thinking = l) })),
  ])
</script>

{#if choices && model && choices.models.length}
  <div bind:this={root} class="chips">
    <button
      type="button"
      class="chip chip--name"
      class:chip--small={small}
      aria-haspopup="menu"
      aria-expanded={open === 'model'}
      aria-label={$LL.deskAgentPickModel()}
      {disabled}
      onmousedown={keep}
      onclick={() => (open = open === 'model' ? null : 'model')}
    >
      <Icon name="auto_awesome" size={small ? 14 : 15} /><span class="chip__text">{model.name ?? model.id}</span><Icon
        name="expand_more"
        size={small ? 14 : 15}
      />
    </button>
    {#if model.reasoning}
      <button
        type="button"
        class="chip"
        class:chip--small={small}
        aria-haspopup="menu"
        aria-expanded={open === 'thinking'}
        aria-label={$LL.deskAgentPickThinking()}
        {disabled}
        onmousedown={keep}
        onclick={() => (open = open === 'thinking' ? null : 'thinking')}
      >
        <Icon name="psychology" size={small ? 14 : 15} />{level(thinking)}<Icon name="expand_more" size={small ? 14 : 15} />
      </button>
    {/if}
    {#if open}
      <!-- The design system's menu; this places it, above the chips or below. -->
      <div
        bind:this={menu}
        use:inHost
        class="menu"
        class:menu--narrow={open === 'thinking'}
        class:menu--down={down}
        style:left={host ? `${left}px` : null}
        role="presentation"
        onmousedown={keep}
      >
        <Menu items={open === 'model' ? modelItems : thinkingItems} onselect={() => (open = null)} onclose={() => (open = null)} />
      </div>
    {/if}
  </div>
{/if}

<style>
  .chips {
    position: relative;
    display: inline-flex;
    align-items: center;
    gap: var(--space-5);
    min-width: 0;
  }
  /* As the permission mode's chip, in the neutral fill. */
  .chip {
    flex: none;
    max-width: 200px;
    height: 30px;
    display: inline-flex;
    align-items: center;
    gap: var(--space-5);
    padding: 0 5px 0 9px;
    border: 0;
    border-radius: var(--radius-full);
    background: var(--fill-hover);
    color: var(--text-primary);
    font: 600 var(--text-12) / 1 var(--font-ui);
    white-space: nowrap;
    cursor: default;
  }
  /* The model's name is the one that gives way in a narrow row: cut short,
     never drawn over what follows it. */
  .chip--name {
    flex: 0 1 auto;
    min-width: 0;
  }
  .chip:disabled {
    opacity: 0.5;
  }
  .chip--small {
    height: 24px;
  }
  .chip__text {
    overflow: hidden;
    text-overflow: ellipsis;
  }
  .menu {
    position: absolute;
    bottom: calc(100% + 9px);
    left: 0;
    z-index: 10;
    width: 320px;
  }
  .menu--narrow {
    width: 200px;
  }
  .menu--down {
    top: calc(100% + 9px);
    bottom: auto;
  }
  .menu :global(.lk-menu) {
    max-height: 360px;
    overflow: auto;
    box-sizing: border-box;
    transform-origin: bottom left;
  }
  .menu--down :global(.lk-menu) {
    transform-origin: top left;
  }
</style>
