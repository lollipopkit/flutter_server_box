<script lang="ts">
  /// Every finished task, searchable, over the timeline: it grows out of the
  /// done list and goes back into it.

  import { LL } from '../../i18n/i18n-svelte'
  import { fmtDate } from '../../lib/format'
  import { AppIcon, Icon, IconButton, SearchField } from '../lk'
  import type { Flow } from '../../lib/agentApi'
  import { AREA, statusLook } from './agentView'
  import { byDay, type Day } from './flowModel'

  interface Props {
    flows: Flow[]
    now: Date
    /// Where it grows from and shrinks back to: the done list.
    from: DOMRect | null
    onopen: (id: string) => void
    onclose: () => void
  }

  const { flows, now, from, onopen, onclose }: Props = $props()

  let query = $state('')
  let panel = $state<HTMLDivElement | null>(null)
  let scrim = $state<HTMLDivElement | null>(null)
  let closing = false
  const EASE_IN = 'cubic-bezier(.2,.9,.25,1.04)'

  const done = $derived(flows.filter((f) => f.status === 'done' || f.status === 'cancelled'))
  const matched = $derived.by(() => {
    const q = query.trim().toLowerCase()
    return q ? done.filter((f) => `${f.title} ${f.line}`.toLowerCase().includes(q)) : done
  })
  const groups = $derived(byDay(matched, now))
  const DAYS: Record<Day, () => string> = {
    today: () => $LL.deskAgentToday(),
    yesterday: () => $LL.deskAgentYesterday(),
    earlier: () => $LL.deskAgentEarlier(),
  }

  function flip(p: HTMLElement, src: DOMRect): string {
    const to = p.getBoundingClientRect()
    return `translate(${src.left - to.left}px, ${src.top - to.top}px) scale(${src.width / to.width}, ${src.height / to.height})`
  }

  $effect(() => {
    const p = panel
    if (!p) return
    if (from) {
      p.animate(
        [
          { transformOrigin: '0 0', transform: flip(p, from), borderRadius: '21px', opacity: 0.6 },
          { transformOrigin: '0 0', transform: 'none', borderRadius: '17px', opacity: 1 },
        ],
        { duration: 520, easing: EASE_IN },
      )
    }
    Array.from(p.children).forEach((c, i) => c.animate([{ opacity: 0 }, { opacity: 0, offset: 0.3 }, { opacity: 1 }], { duration: 520 + i * 60 }))
  })

  function close() {
    const p = panel
    if (!p || !from || closing) return onclose()
    closing = true
    scrim?.animate([{ opacity: 1 }, { opacity: 0 }], { duration: 380, easing: 'ease-out', fill: 'forwards' })
    Array.from(p.children).forEach((c) => c.animate([{ opacity: 1 }, { opacity: 0 }], { duration: 160, fill: 'forwards' }))
    const a = p.animate(
      [
        { transformOrigin: '0 0', transform: 'none', borderRadius: '17px' },
        { transformOrigin: '0 0', transform: flip(p, from), borderRadius: '21px' },
      ],
      { duration: 420, easing: 'cubic-bezier(.3,0,.2,1)', fill: 'forwards' },
    )
    a.onfinish = () => onclose()
  }

  function onkeydown(e: KeyboardEvent) {
    if (e.key === 'Escape') {
      e.preventDefault()
      e.stopPropagation()
      close()
    }
  }

  function when(f: Flow): string {
    return fmtDate(new Date(f.finishedAt ?? f.updatedAt), { month: 'short', day: 'numeric', hour: '2-digit', minute: '2-digit' })
  }
</script>

<svelte:window {onkeydown} />

<!-- svelte-ignore a11y_click_events_have_key_events, a11y_no_static_element_interactions -->
<div class="scrim" bind:this={scrim} onclick={close}>
  <!-- svelte-ignore a11y_click_events_have_key_events -->
  <div class="panel" bind:this={panel} onclick={(e) => e.stopPropagation()} role="dialog" aria-label={$LL.deskAgentDone()} tabindex="-1">
    <div class="head">
      <span class="head__title">{$LL.deskAgentDone()}</span>
      <span class="head__count am-num">{$LL.deskAgentTasks({ n: matched.length })}</span>
      <div class="grow"></div>
      <SearchField bind:value={query} placeholder={$LL.deskAgentSearch()} width={180} />
      <IconButton icon="close" label={$LL.deskAgentClose()} size="sm" onclick={close} />
    </div>
    <div class="list">
      {#if !matched.length}
        <div class="empty">
          <Icon name="search_off" size={44} />
          <span>{$LL.deskAgentNoMatch()}</span>
        </div>
      {/if}
      {#each groups as g (g.day)}
        <div class="day">
          <div class="day__label am-label">{DAYS[g.day]()}</div>
          {#each g.flows as f (f.id)}
            {@const look = statusLook(f)}
            <button class="row" onclick={() => onopen(f.id)}>
              <Icon name={look.glyph} size={18} fill color={look.color} />
              <span class="row__text">
                <span class="row__title am-ellipsis">{f.title}</span>
                <span class="row__desc am-ellipsis">{f.line}</span>
              </span>
              <span class="row__apps">
                {#each f.areas as a (a)}
                  <AppIcon glyph={AREA[a].glyph} tone={AREA[a].tone} size={17} label={AREA[a].name($LL)} />
                {/each}
              </span>
              <span class="row__time am-num">{when(f)}</span>
            </button>
          {/each}
        </div>
      {/each}
    </div>
  </div>
</div>

<style>
  .scrim {
    position: absolute;
    inset: 0;
    z-index: 65;
    display: flex;
    justify-content: center;
    align-items: flex-start;
    padding: var(--space-34) var(--space-21);
    box-sizing: border-box;
    background: color-mix(in srgb, var(--surface-window) 40%, transparent);
    backdrop-filter: blur(13px);
    -webkit-backdrop-filter: blur(13px);
    animation: lk-fade-in var(--dur-base) var(--ease-standard);
  }
  .panel {
    width: 100%;
    max-width: 640px;
    max-height: 100%;
    display: flex;
    flex-direction: column;
    border-radius: var(--radius-window);
    background: var(--surface-content);
    box-shadow: var(--shadow-window);
    overflow: hidden;
    outline: none;
  }
  .head {
    flex: none;
    display: flex;
    align-items: center;
    gap: var(--space-9);
    height: 52px;
    padding: 0 var(--space-13) 0 var(--space-21);
    border-bottom: 0.5px solid var(--border-hairline);
  }
  .head__title {
    font-size: var(--text-15);
    font-weight: var(--weight-bold);
  }
  .head__count {
    font-size: var(--text-12);
    color: var(--text-tertiary);
  }
  .grow {
    flex: 1;
  }
  .list {
    flex: 1;
    min-height: 0;
    overflow-y: auto;
    padding: var(--space-7);
  }
  .empty {
    display: flex;
    flex-direction: column;
    align-items: center;
    gap: var(--space-9);
    padding: var(--space-55) 0;
    color: var(--text-tertiary);
    font-size: var(--text-13);
  }
  .day {
    display: flex;
    flex-direction: column;
  }
  .day__label {
    position: sticky;
    top: -7px;
    z-index: 1;
    padding: var(--space-11) var(--space-13) var(--space-5);
    background: var(--surface-content);
    text-transform: uppercase;
  }
  .row {
    display: grid;
    grid-template-columns: 18px minmax(0, 1fr) auto 84px;
    align-items: center;
    gap: var(--space-13);
    height: 48px;
    padding: 0 var(--space-13);
    border: 0;
    border-radius: var(--radius-control);
    background: transparent;
    font: inherit;
    color: inherit;
    text-align: left;
    cursor: default;
    transition: background var(--dur-fast) var(--ease-standard);
  }
  .row:hover {
    background: var(--fill-hover);
  }
  .row:active {
    background: var(--fill-press);
  }
  .row__text {
    display: flex;
    flex-direction: column;
    gap: 1px;
    min-width: 0;
  }
  .row__title {
    font-size: var(--text-13);
    font-weight: 600;
  }
  .row__desc {
    font-size: var(--text-12);
    color: var(--text-secondary);
  }
  .row__apps {
    display: flex;
    gap: var(--space-3);
  }
  .row__time {
    text-align: right;
    font-size: var(--text-12);
    color: var(--text-tertiary);
    white-space: nowrap;
  }
</style>
