<script lang="ts">
  /// Agent mode's home: the timeline (in progress, waiting on the account,
  /// done) above the prompt that starts a task.

  import { LL } from '../../i18n/i18n-svelte'
  import { fmtDate } from '../../lib/format'
  import { AppIcon, Button, Icon } from '../lk'
  import Composer from './Composer.svelte'
  import type { Flow, OutLine } from '../../lib/agentApi'
  import type { AgentStore } from './agentStore.svelte'
  import { AREA, duration, greeting, segment, statusLook } from './agentView'
  import { byDay, columns, elapsed, firstOf, type Day } from './flowModel'

  interface Props {
    store: AgentStore
    now: Date
    /// Whom the greeting names.
    name: string
    onopen: (id: string, from: HTMLElement | null) => void
    onhistory: (from: HTMLElement | null) => void
    /// A started task opens at once, unless it waits its turn.
    onstarted: (flow: Flow) => void
    /// Not configured: where an admin sets it up.
    onsettings: () => void
    admin: boolean
  }

  const { store, now, name, onopen, onhistory, onstarted, onsettings, admin }: Props = $props()

  const cols = $derived(columns(store.flows))
  const doneGroups = $derived(firstOf(byDay(cols.done, now), 6))
  const empty = $derived(store.loaded && store.flows.length === 0)

  let composer = $state<ReturnType<typeof Composer> | null>(null)
  /// The composer has the focus: everything else steps back.
  let focused = $state(false)
  let dragging = $state(false)
  let dragDepth = 0

  const hasFiles = (e: DragEvent) => Array.from(e.dataTransfer?.types ?? []).includes('Files')
  function ondragenter(e: DragEvent) {
    if (!hasFiles(e) || !store.configured) return
    e.preventDefault()
    dragDepth += 1
    dragging = true
  }
  function ondragover(e: DragEvent) {
    if (!hasFiles(e) || !store.configured) return
    e.preventDefault()
    if (e.dataTransfer) e.dataTransfer.dropEffect = 'copy'
  }
  function ondragleave() {
    dragDepth = Math.max(0, dragDepth - 1)
    if (!dragDepth) dragging = false
  }
  function ondrop(e: DragEvent) {
    if (!hasFiles(e) || !store.configured) return
    e.preventDefault()
    dragDepth = 0
    dragging = false
    composer?.addFiles(e.dataTransfer?.files)
    composer?.focus()
  }

  const SUGGEST: { glyph: string; label: () => string }[] = [
    { glyph: 'hard_drive', label: () => $LL.deskAgentSuggestDisk() },
    { glyph: 'system_update', label: () => $LL.deskAgentSuggestUpdate() },
    { glyph: 'error', label: () => $LL.deskAgentSuggestFailed() },
    { glyph: 'cleaning_services', label: () => $LL.deskAgentSuggestDocker() },
  ]

  // Agent → New task: the prompt, even when this page came up for it.
  let handled = 0
  $effect(() => {
    const r = store.request
    if (!r || r.n === handled) return
    handled = r.n
    if (r.kind === 'new' && Date.now() - r.at < 1000) requestAnimationFrame(() => composer?.focus())
  })

  const DAYS: Record<Day, () => string> = {
    today: () => $LL.deskAgentToday(),
    yesterday: () => $LL.deskAgentYesterday(),
    earlier: () => $LL.deskAgentEarlier(),
  }

  /// The step a card's line is about: the first not done.
  function lineOf(f: Flow): string {
    const steps = f.steps ?? []
    const i = steps.findIndex((s) => s.state !== 'done')
    if (i < 0) return f.line || $LL.deskAgentThinking()
    return $LL.deskAgentStepLine({ n: i + 1, title: steps[i].title })
  }

  function when(f: Flow): string {
    const t = new Date(f.finishedAt ?? f.updatedAt)
    const today = t.toDateString() === now.toDateString()
    return fmtDate(t, today ? { hour: '2-digit', minute: '2-digit' } : { month: 'short', day: 'numeric', hour: '2-digit', minute: '2-digit' })
  }

  function tailColor(l: OutLine): string {
    return l[0] === 2 ? 'var(--color-danger)' : 'var(--text-primary)'
  }
</script>

<!-- svelte-ignore a11y_no_static_element_interactions -->
<div class="home" class:home--focused={focused} {ondragenter} {ondragover} {ondragleave} {ondrop}>
  {#if dragging}
    <div class="drop">
      <div class="drop__box">
        <Icon name="upload_file" size={34} color="var(--color-accent-text)" />
        <span class="drop__title">{$LL.deskAgentDropTitle()}</span>
        <span class="drop__note">{$LL.deskAgentDropNote()}</span>
      </div>
    </div>
  {/if}
  <div class="top" inert={focused}>
    <div class="cols">
      {#if empty}
        <div class="nothing">
          <Icon name="history" size={44} />
          <span>{$LL.deskAgentNothing()}</span>
        </div>
      {/if}

      {#if cols.running.length + cols.queued.length > 0}
        <section class="col">
          <h2 class="col__head">
            <span>{$LL.deskAgentRunning()}</span><span class="col__count am-num">{cols.running.length}</span>
          </h2>
          <div class="col__list col__list--run">
            {#each cols.running.slice(0, 2) as f (f.id)}
              {@const look = statusLook(f)}
              <button class="am-tile run" data-fid={f.id} onclick={(e) => onopen(f.id, e.currentTarget)}>
                <div class="run__body">
                  <div class="run__status" style:color={look.color}>
                    <Icon name={look.glyph} size={15} fill class="am-spin" />
                    <span>{look.label($LL)}</span>
                    <span class="run__elapsed am-num">{$LL.deskAgentElapsed({ time: duration($LL, elapsed(f.startedAt, now)) })}</span>
                  </div>
                  <div class="run__title am-ellipsis">{f.title}</div>
                  <div class="run__line am-ellipsis am-shimmer">{lineOf(f)}</div>
                  <div class="grow"></div>
                  <div class="segs">
                    {#each f.steps ?? [] as s (s.toolCallId)}
                      {@const seg = segment(s.state)}
                      <div class="seg" style:background={seg.bg}>
                        <div
                          class="seg__fill"
                          style:width={seg.width}
                          style:background-color={seg.fill}
                          style:background-image={seg.stripe ? 'var(--am-stripe)' : 'none'}
                        ></div>
                      </div>
                    {:else}
                      <div class="seg" style:background="var(--color-accent-soft)">
                        <div class="seg__fill" style:width="50%" style:background-color="var(--color-accent)" style:background-image="var(--am-stripe)"></div>
                      </div>
                    {/each}
                  </div>
                  <div class="run__foot">
                    <div class="apps">
                      {#each f.areas as a (a)}
                        <AppIcon glyph={AREA[a].glyph} tone={AREA[a].tone} size={19} label={AREA[a].name($LL)} />
                      {/each}
                    </div>
                    <span class="run__desc am-ellipsis">{f.line}</span>
                  </div>
                </div>
                <div class="tail">
                  {#each f.tail ?? [] as l, i (i)}
                    <div class="am-ellipsis" style:color={tailColor(l)}>{l[1]}</div>
                  {/each}
                </div>
              </button>
            {/each}
          </div>
          {#if cols.running.length > 2}
            <button class="more" onclick={(e) => onopen(cols.running[2].id, e.currentTarget)}>{$LL.deskAgentMore({ n: cols.running.length - 2 })}</button>
          {/if}
          {#each cols.queued as q (q.id)}
            <button class="queued" data-fid={q.id} onclick={(e) => onopen(q.id, e.currentTarget)}>
              <Icon name="hourglass_top" size={16} color="var(--text-tertiary)" />
              <span class="queued__title am-ellipsis">{q.title}</span>
              <span class="queued__state">{$LL.deskAgentStatusQueued()}</span>
            </button>
          {/each}
        </section>
      {/if}

      {#if cols.waiting.length}
        <section class="col">
          <h2 class="col__head">
            <span>{$LL.deskAgentNeedsYou()}</span><span class="col__count am-num">{cols.waiting.length}</span>
          </h2>
          <div class="col__list col__list--wait">
            {#each cols.waiting.slice(0, 4) as f (f.id)}
              {@const look = statusLook(f)}
              {@const steps = f.steps ?? []}
              <button class="am-tile wait" data-fid={f.id} onclick={(e) => onopen(f.id, e.currentTarget)}>
                <div class="wait__status">
                  <span class="dot" style:background={look.color}></span>
                  <span class="wait__label" style:color={look.color}>{look.label($LL)}</span>
                  <span class="wait__time am-num">{when(f)}</span>
                </div>
                <div class="wait__title am-ellipsis">{f.title}</div>
                <div class="wait__line">{f.status === 'failed' ? f.line : lineOf(f)}</div>
                <div class="grow"></div>
                <div class="wait__foot">
                  {#if steps.length}
                    <div class="segs segs--small">
                      {#each steps as s (s.toolCallId)}
                        <div class="seg seg--small" style:background={segment(s.state).bg}></div>
                      {/each}
                    </div>
                    <span class="wait__count am-num">{steps.filter((s) => s.state === 'done').length} / {steps.length}</span>
                  {/if}
                  <div class="apps apps--end">
                    {#each f.areas as a (a)}
                      <AppIcon glyph={AREA[a].glyph} tone={AREA[a].tone} size={19} label={AREA[a].name($LL)} />
                    {/each}
                  </div>
                </div>
              </button>
            {/each}
          </div>
          {#if cols.waiting.length > 4}
            <button class="more" onclick={(e) => onopen(cols.waiting[4].id, e.currentTarget)}>{$LL.deskAgentMore({ n: cols.waiting.length - 4 })}</button>
          {/if}
        </section>
      {/if}

      {#if doneGroups.length}
        <section class="col">
          <h2 class="col__head">
            <span>{$LL.deskAgentDone()}</span><span class="col__count am-num">{cols.done.length}</span>
            <button class="all" onclick={(e) => onhistory(e.currentTarget.closest('.col')?.querySelector('.done') ?? null)}>
              {$LL.deskAgentSeeAll()}<Icon name="chevron_right" size={15} />
            </button>
          </h2>
          <div class="done">
            {#each doneGroups as g (g.day)}
              <div class="day">
                <div class="day__label am-label">{DAYS[g.day]()}</div>
                {#each g.flows as f (f.id)}
                  {@const look = statusLook(f)}
                  <button class="row" data-fid={f.id} onclick={(e) => onopen(f.id, e.currentTarget)}>
                    <Icon name={look.glyph} size={18} fill color={look.color} />
                    <span class="row__text">
                      <span class="row__title">{f.title}</span>
                      <span class="row__desc am-ellipsis">{f.line}</span>
                    </span>
                    <span class="row__time am-num">{when(f)}</span>
                  </button>
                {/each}
              </div>
            {/each}
          </div>
        </section>
      {/if}
    </div>
  </div>

  <div class="hero">
    <div class="hero__greet away away--up">{$LL.deskAgentGreeting({ greeting: greeting($LL, now.getHours()), name })}</div>
    <Composer
      bind:this={composer}
      {store}
      {focused}
      onfocuschange={(f) => (focused = f)}
      {onstarted}
      disabled={!store.configured}
      placeholder={store.atLimit ? $LL.deskAgentAskQueued() : $LL.deskAgentAskOn({ host: store.hostname || name })}
    />
    <div class="below away" inert={focused}>
    {#if !store.configured && store.loaded}
      <div class="setup">
        <Icon name="key" size={18} color="var(--color-warning)" />
        <div class="setup__text">
          <span class="setup__title">{$LL.deskAgentNoModel()}</span>
          <span class="setup__note">{admin ? $LL.deskAgentNoModelAdmin() : $LL.deskAgentNoModelUser()}</span>
        </div>
        {#if admin}
          <Button size="sm" variant="secondary" icon="settings" onclick={onsettings}>{$LL.deskAgentOpenSettings()}</Button>
        {/if}
      </div>
    {/if}
    {#if store.atLimit}
      <div class="limit">
        <Icon name="hourglass_top" size={15} color="var(--color-warning)" />
        {$LL.deskAgentAtLimit({ n: store.maxRunning })}
      </div>
    {/if}
    {#if store.configured}
      <div class="chips">
        {#each SUGGEST as s (s.glyph)}
          <button class="chip" onclick={() => composer?.send(s.label())}>
            <Icon name={s.glyph} size={15} color="var(--color-accent-text)" />
            {s.label()}
          </button>
        {/each}
      </div>
    {/if}
    {#if empty}
      <div class="intro">{$LL.deskAgentIntro({ host: store.hostname })}</div>
    {/if}
    <span class="leave">{$LL.deskAgentLeaveHint()}</span>
    </div>
  </div>
</div>

<style>
  .home {
    position: relative;
    flex: 1;
    min-height: 0;
    display: flex;
    flex-direction: column;
    animation: lk-fade-in var(--dur-tab-content) var(--ease-standard);
  }
  /* Focused, the composer moves to the middle and the rest steps back
     (the design system's storyboard). */
  .top {
    flex: 1 1 0;
    min-height: 0;
    overflow: hidden;
    transition:
      opacity 340ms var(--ease-standard) 150ms,
      transform 600ms var(--ease-emphasized);
  }
  .home--focused .top {
    opacity: 0;
    transform: scale(0.97);
    pointer-events: none;
    transition:
      opacity 200ms var(--ease-exit),
      transform 600ms var(--ease-emphasized);
  }
  .away {
    transition:
      opacity 340ms var(--ease-standard) 150ms,
      transform 340ms var(--ease-emphasized) 150ms;
  }
  .home--focused .away {
    opacity: 0;
    transform: translateY(7px);
    pointer-events: none;
    transition:
      opacity 200ms var(--ease-exit),
      transform 200ms var(--ease-exit);
  }
  .home--focused .away--up {
    transform: translateY(-7px);
  }
  .below {
    display: flex;
    flex-direction: column;
    align-items: center;
    gap: var(--space-17);
  }
  .drop {
    position: absolute;
    inset: 0;
    z-index: 5;
    display: flex;
    align-items: center;
    justify-content: center;
    pointer-events: none;
    background: color-mix(in srgb, var(--surface-window) 55%, transparent);
    animation: lk-fade-in 150ms var(--ease-standard);
  }
  .drop__box {
    width: min(880px, calc(100% - 42px));
    height: 220px;
    box-sizing: border-box;
    border-radius: 27px;
    border: 1.5px dashed color-mix(in srgb, var(--color-accent-text) 70%, transparent);
    display: flex;
    flex-direction: column;
    align-items: center;
    justify-content: center;
    gap: var(--space-9);
    animation: lk-pop-in 220ms var(--ease-spring);
  }
  .drop__title {
    font-size: var(--text-17);
    font-weight: 600;
  }
  .drop__note {
    font-size: var(--text-12);
    color: var(--text-tertiary);
  }
  .cols {
    max-width: 1280px;
    height: 100%;
    margin: 0 auto;
    padding: var(--space-27) calc(var(--space-55) - 10.5px) var(--space-13);
    box-sizing: border-box;
    display: flex;
  }
  .nothing {
    flex: 1;
    display: flex;
    flex-direction: column;
    align-items: center;
    justify-content: center;
    gap: var(--space-9);
    color: var(--text-tertiary);
    font-size: var(--text-13);
  }
  .col {
    flex: 1 1 0;
    min-width: 0;
    min-height: 0;
    padding: 0 10.5px;
    display: flex;
    flex-direction: column;
    gap: var(--space-13);
    overflow: hidden;
    animation: lk-fade-in var(--dur-base) var(--ease-standard);
  }
  .col__head {
    margin: 0;
    display: flex;
    align-items: baseline;
    gap: var(--space-9);
    font-size: var(--text-21);
    font-weight: var(--weight-semibold);
    letter-spacing: var(--tracking-display);
  }
  .col__count {
    font-size: var(--text-15);
    font-weight: 400;
    color: var(--text-tertiary);
    letter-spacing: 0;
  }
  .col__list {
    display: flex;
    flex-direction: column;
  }
  .col__list--run {
    gap: var(--space-13);
  }
  .col__list--wait {
    gap: var(--space-9);
  }
  .grow {
    flex: 1;
    min-height: var(--space-17);
  }

  .run {
    flex: none;
    display: flex;
    flex-direction: column;
    gap: var(--space-13);
    padding: var(--space-17) var(--space-21);
    box-sizing: border-box;
  }
  .run__body {
    display: flex;
    flex-direction: column;
    min-width: 0;
    padding: var(--space-3) 0;
  }
  .run__status {
    display: flex;
    align-items: center;
    gap: var(--space-7);
    font-size: var(--text-12);
    font-weight: 600;
  }
  .run__elapsed {
    margin-left: auto;
    font-weight: 400;
    color: var(--text-tertiary);
  }
  .run__title {
    margin-top: var(--space-9);
    font-size: var(--text-21);
    font-weight: var(--weight-semibold);
    letter-spacing: var(--tracking-display);
    line-height: var(--leading-tight);
  }
  .run__line {
    margin-top: var(--space-5);
    font-size: var(--text-13);
    animation-duration: 2.2s;
  }
  .segs {
    display: flex;
    gap: var(--space-3);
  }
  .seg {
    flex: 1;
    height: 5px;
    border-radius: var(--radius-full);
    overflow: hidden;
  }
  .seg__fill {
    height: 100%;
    background-size: 22px 100%;
    border-radius: inherit;
    animation: am-stripe 900ms linear infinite;
    transition: width 600ms var(--ease-standard);
  }
  .segs--small {
    width: 96px;
  }
  .seg--small {
    height: 4px;
  }
  .run__foot {
    display: flex;
    align-items: center;
    gap: var(--space-9);
    margin-top: var(--space-13);
    min-width: 0;
  }
  .apps {
    display: flex;
    gap: var(--space-3);
    flex: none;
  }
  .apps--end {
    margin-left: auto;
  }
  .run__desc {
    font-size: var(--text-12);
    color: var(--text-secondary);
  }
  .tail {
    height: 80px;
    box-sizing: border-box;
    flex: none;
    display: flex;
    flex-direction: column;
    justify-content: flex-end;
    min-width: 0;
    padding: var(--space-9) var(--space-13);
    border-radius: var(--radius-card);
    background: var(--surface-terminal);
    box-shadow: inset 0 0 0 0.5px var(--border-hairline);
    font-family: var(--font-mono);
    font-size: var(--text-11);
    line-height: 1.8;
    overflow: hidden;
    -webkit-mask-image: linear-gradient(transparent, #000 38%);
    mask-image: linear-gradient(transparent, #000 38%);
  }
  .tail > div {
    flex: none;
  }
  .more {
    flex: none;
    align-self: flex-start;
    border: 0;
    background: transparent;
    padding: var(--space-3) var(--space-5);
    font: inherit;
    font-size: var(--text-12);
    color: var(--text-tertiary);
    cursor: default;
    border-radius: var(--radius-sm);
  }
  .more:hover {
    background: var(--fill-hover);
    color: var(--text-primary);
  }
  .queued {
    display: flex;
    align-items: center;
    gap: var(--space-11);
    height: 44px;
    padding: 0 var(--space-17);
    border: 0;
    border-radius: var(--radius-card);
    background: var(--glass-tile);
    box-shadow: inset 0 0 0 0.5px var(--border-hairline);
    font: inherit;
    font-size: var(--text-13);
    color: inherit;
    text-align: left;
    cursor: default;
  }
  .queued__title {
    font-weight: 600;
    min-width: 0;
  }
  .queued__state {
    margin-left: auto;
    font-size: var(--text-12);
    color: var(--text-tertiary);
    white-space: nowrap;
  }

  .wait {
    flex: none;
    display: flex;
    flex-direction: column;
    padding: var(--space-13) var(--space-17);
    box-sizing: border-box;
  }
  .wait__status {
    display: flex;
    align-items: center;
    gap: var(--space-7);
    font-size: var(--text-12);
  }
  .dot {
    width: 7px;
    height: 7px;
    border-radius: 50%;
  }
  .wait__label {
    font-weight: 600;
  }
  .wait__time {
    margin-left: auto;
    color: var(--text-tertiary);
  }
  .wait__title {
    margin-top: var(--space-7);
    font-size: var(--text-15);
    font-weight: var(--weight-semibold);
    line-height: var(--leading-tight);
  }
  .wait__line {
    margin-top: var(--space-5);
    font-size: var(--text-13);
    color: var(--text-secondary);
    line-height: var(--leading-snug);
    display: -webkit-box;
    -webkit-line-clamp: 1;
    line-clamp: 1;
    -webkit-box-orient: vertical;
    overflow: hidden;
  }
  .wait .grow {
    min-height: var(--space-13);
  }
  .wait__foot {
    display: flex;
    align-items: center;
    gap: var(--space-13);
  }
  .wait__count {
    font-size: var(--text-12);
    color: var(--text-tertiary);
  }

  .all {
    margin-left: auto;
    align-self: center;
    display: flex;
    align-items: center;
    gap: var(--space-3);
    height: 24px;
    padding: 0 var(--space-7) 0 var(--space-9);
    border: 0;
    border-radius: var(--radius-full);
    background: transparent;
    font: inherit;
    font-size: var(--text-12);
    font-weight: 400;
    letter-spacing: 0;
    color: var(--color-accent-text);
    cursor: default;
  }
  .all:hover {
    background: var(--fill-hover);
  }
  .all:active {
    transform: scale(0.95);
  }
  .done {
    flex: none;
    display: flex;
    flex-direction: column;
    padding: var(--space-7);
    border-radius: var(--radius-panel);
    background: var(--glass-tile);
    box-shadow: inset 0 0 0 0.5px var(--border-hairline);
  }
  .day {
    display: flex;
    flex-direction: column;
  }
  .day__label {
    padding: var(--space-11) var(--space-13) var(--space-5);
    text-transform: uppercase;
  }
  .row {
    display: grid;
    grid-template-columns: 18px minmax(0, 1fr) auto;
    align-items: center;
    gap: var(--space-11);
    height: 40px;
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
    align-items: baseline;
    gap: var(--space-11);
    min-width: 0;
  }
  .row__title {
    font-size: var(--text-13);
    font-weight: 600;
    white-space: nowrap;
  }
  .row__desc {
    font-size: var(--text-12);
    color: var(--text-secondary);
  }
  .row__time {
    text-align: right;
    font-size: var(--text-12);
    color: var(--text-tertiary);
    white-space: nowrap;
  }

  .hero {
    flex: none;
    display: flex;
    flex-direction: column;
    align-items: center;
    gap: var(--space-17);
    padding: var(--space-13) var(--space-21) var(--space-55);
  }
  .hero__greet {
    font-size: 27px;
    font-weight: var(--weight-bold);
    letter-spacing: -0.02em;
    line-height: var(--leading-tight);
    text-align: center;
  }
  .leave {
    font-size: var(--text-12);
    color: var(--text-tertiary);
  }
  .limit {
    display: flex;
    align-items: center;
    gap: var(--space-7);
    font-size: var(--text-13);
    color: var(--text-secondary);
  }
  .chips {
    display: flex;
    flex-wrap: wrap;
    justify-content: center;
    gap: var(--space-7);
  }
  .chip {
    display: flex;
    align-items: center;
    gap: var(--space-7);
    height: 32px;
    padding: 0 var(--space-13);
    border: 0;
    border-radius: var(--radius-full);
    background: var(--glass-tile);
    box-shadow: inset 0 0 0 0.5px var(--border-glass);
    font: var(--weight-medium) var(--text-13) / 1 var(--font-ui);
    color: var(--text-primary);
    cursor: default;
    transition:
      background var(--dur-fast) var(--ease-standard),
      transform var(--dur-base) var(--ease-spring-bouncy);
  }
  .chip:hover {
    background: var(--surface-raised);
    color: var(--text-primary);
  }
  .chip:active {
    transform: scale(0.95);
  }
  .intro {
    font-size: var(--text-13);
    color: var(--text-tertiary);
    line-height: var(--leading-body);
    max-width: 480px;
    text-wrap: pretty;
  }
  .setup {
    display: flex;
    align-items: center;
    gap: var(--space-11);
    width: min(100%, 520px);
    box-sizing: border-box;
    padding: var(--space-11) var(--space-13);
    border-radius: var(--radius-card);
    background: var(--color-warning-soft);
  }
  .setup__text {
    flex: 1;
    min-width: 0;
    display: flex;
    flex-direction: column;
    gap: 1px;
  }
  .setup__title {
    font-size: var(--text-13);
    font-weight: 600;
  }
  .setup__note {
    font-size: var(--text-12);
    color: var(--text-secondary);
  }

  @container (max-width: 760px) {
    .cols {
      flex-direction: column;
      overflow-y: auto;
      gap: var(--space-21);
    }
    .hero {
      padding-bottom: var(--space-21);
    }
  }
</style>
