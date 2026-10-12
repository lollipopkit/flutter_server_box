<script lang="ts">
  /// The model and thinking level a task runs with, beside a composer: what
  /// the account picked for the next message ([draft]), else what [flow] has,
  /// else the machine's. Nothing when the agent offers no choice.

  import { LL } from '../../i18n/i18n-svelte'
  import type { Flow, ModelChoice, ModelRef } from '../../lib/agentApi'
  import { Icon } from '../lk'
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
  }

  const { store, draft, flow = null, small = false, down = false, disabled = false }: Props = $props()

  let open = $state<'model' | 'thinking' | null>(null)
  let root = $state<HTMLDivElement | null>(null)

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
      if (!root?.contains(e.target as Node)) open = null
    }
    document.addEventListener('mousedown', down)
    return () => document.removeEventListener('mousedown', down)
  })

  const keep = (e: Event) => e.preventDefault()
</script>

{#if choices && model && choices.models.length}
  <div bind:this={root} class="chips">
    <button
      type="button"
      class="chip"
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
    {#if open === 'model'}
      <div class="menu" class:menu--down={down} role="menu" aria-label={$LL.deskAgentPickModel()}>
        <div class="lk-caps menu__head">{$LL.deskAgentPickModel()}</div>
        {#each choices.models as m (`${m.provider}/${m.id}`)}
          <button
            type="button"
            role="menuitemradio"
            aria-checked={same(m, model)}
            class="item"
            class:item--on={same(m, model)}
            onmousedown={keep}
            onclick={() => {
              draft.model = { provider: m.provider, id: m.id }
              open = null
            }}
          >
            <span class="item__text"><span class="item__label">{m.name ?? m.id}</span><span class="item__id">{m.provider}</span></span>
            {#if same(m, model)}<Icon name="check" size={16} weight={600} color="var(--color-accent-text)" />{/if}
          </button>
        {/each}
      </div>
    {:else if open === 'thinking'}
      <div class="menu menu--narrow" class:menu--down={down} role="menu" aria-label={$LL.deskAgentPickThinking()}>
        <div class="lk-caps menu__head">{$LL.deskAgentPickThinking()}</div>
        {#each choices.thinkingLevels as l (l)}
          <button
            type="button"
            role="menuitemradio"
            aria-checked={l === thinking}
            class="item"
            class:item--on={l === thinking}
            onmousedown={keep}
            onclick={() => {
              draft.thinking = l
              open = null
            }}
          >
            <span class="item__text"><span class="item__label">{level(l)}</span></span>
            {#if l === thinking}<Icon name="check" size={16} weight={600} color="var(--color-accent-text)" />{/if}
          </button>
        {/each}
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
    max-height: 360px;
    overflow: auto;
    box-sizing: border-box;
    padding: 5px;
    border-radius: 13px;
    background: var(--glass-menu);
    -webkit-backdrop-filter: var(--blur-menu);
    backdrop-filter: var(--blur-menu);
    box-shadow: var(--shadow-menu);
  }
  .menu--narrow {
    width: 200px;
  }
  .menu--down {
    top: calc(100% + 9px);
    bottom: auto;
  }
  .menu__head {
    padding: 7px 9px 5px;
  }
  .item {
    width: 100%;
    display: grid;
    grid-template-columns: minmax(0, 1fr) 16px;
    gap: var(--space-11);
    align-items: center;
    padding: 9px;
    border: 0;
    border-radius: 9px;
    background: transparent;
    color: inherit;
    font: inherit;
    text-align: left;
    cursor: default;
  }
  .item:hover {
    background: var(--fill-hover);
  }
  .item--on {
    background: var(--fill-press);
  }
  .item__text {
    display: flex;
    flex-direction: column;
    gap: 2px;
    min-width: 0;
  }
  .item__label {
    font: 500 var(--text-13) / 1.3 var(--font-ui);
    overflow: hidden;
    text-overflow: ellipsis;
    white-space: nowrap;
  }
  .item__id {
    font: 400 var(--text-11) / 1.3 var(--font-mono);
    color: var(--text-tertiary);
  }
</style>
