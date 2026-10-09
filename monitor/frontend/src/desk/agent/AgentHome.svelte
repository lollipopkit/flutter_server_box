<script lang="ts">
  /// Agent mode's home: the timeline (in progress, waiting on the account,
  /// done) above the prompt that starts a task.

  import { LL } from '../../i18n/i18n-svelte'
  import { fmtBytes, fmtDate } from '../../lib/format'
  import { AppIcon, Button, Icon, IconButton } from '../lk'
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

  let query = $state('')
  let paste = $state<string | null>(null)
  let focus = $state(false)
  let sending = $state(false)
  let error = $state<string | null>(null)
  let input = $state<HTMLInputElement | null>(null)
  let blurTimer: ReturnType<typeof setTimeout> | null = null

  const pasteLines = $derived(paste ? paste.split('\n') : [])
  const draft = $derived(!!(query.trim() || paste))

  const SUGGEST: { glyph: string; label: () => string }[] = [
    { glyph: 'hard_drive', label: () => $LL.deskAgentSuggestDisk() },
    { glyph: 'system_update', label: () => $LL.deskAgentSuggestUpdate() },
    { glyph: 'error', label: () => $LL.deskAgentSuggestFailed() },
    { glyph: 'cleaning_services', label: () => $LL.deskAgentSuggestDocker() },
  ]

  function onpaste(e: ClipboardEvent) {
    const t = e.clipboardData?.getData('text') ?? ''
    // A long paste (a log) is carried beside the words, not in the field.
    if (t.length > 240 || t.split('\n').length > 3) {
      e.preventDefault()
      paste = t
    }
  }

  async function submit(text = query) {
    const words = text.trim()
    if ((!words && !paste) || sending || !store.configured) return
    const prompt = paste ? `${words || $LL.deskAgentPasted()}\n\n\`\`\`\n${paste}\n\`\`\`` : words
    sending = true
    error = null
    try {
      const f = await store.startFlow(prompt)
      query = ''
      paste = null
      focus = false
      input?.blur()
      onstarted(f)
    } catch (e) {
      error = e instanceof Error ? e.message : String(e)
    } finally {
      sending = false
    }
  }

  function onkeydown(e: KeyboardEvent) {
    if (e.key === 'Enter' && !e.isComposing) {
      e.preventDefault()
      void submit()
    } else if (e.key === 'Escape') {
      query = ''
      paste = null
      focus = false
      input?.blur()
    }
  }

  function onfocus() {
    if (blurTimer) clearTimeout(blurTimer)
    focus = true
  }

  function onblur() {
    if (blurTimer) clearTimeout(blurTimer)
    blurTimer = setTimeout(() => {
      if (!query.trim() && !paste && document.activeElement !== input) focus = false
    }, 160)
  }

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

<div class="home">
  <div class="top" class:top--away={focus}>
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

  <div class="hero-wrap">
    <div class="hero" class:hero--focus={focus}>
      <div class="hero__greet">{$LL.deskAgentGreeting({ greeting: greeting($LL, now.getHours()), name })}</div>
      <input
        bind:this={input}
        bind:value={query}
        class="hero__input"
        placeholder={store.atLimit ? $LL.deskAgentAskQueued() : $LL.deskAgentAsk()}
        aria-label={$LL.deskAgentAsk()}
        disabled={!store.configured}
        {onkeydown}
        {onpaste}
        {onfocus}
        {onblur}
      />
      <div class="hero__below">
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
        {#if paste}
          <div class="paste">
            <div class="paste__icon"><Icon name="article" size={18} fill color="var(--color-accent-text)" /></div>
            <div class="paste__body">
              <div class="paste__head">
                <span class="paste__title">{$LL.deskAgentPasted()}</span>
                <span class="paste__meta am-num">{$LL.deskAgentPastedMeta({ lines: pasteLines.length.toLocaleString(), size: fmtBytes(new Blob([paste]).size) })}</span>
              </div>
              <div class="paste__lines">
                {#each pasteLines.slice(0, 3) as l, i (i)}<div class="am-ellipsis">{l}</div>{/each}
              </div>
            </div>
            <IconButton icon="close" label={$LL.deskAgentRemove()} size="sm" onclick={() => (paste = null)} />
          </div>
        {/if}
        {#if draft}
          <div class="send">
            <Button variant="primary" size="sm" icon="arrow_upward" disabled={sending} onclick={() => submit()}>{$LL.deskAgentSend()}</Button>
            <span class="send__hint">{$LL.deskAgentSendHint()}</span>
          </div>
        {/if}
        {#if error}
          <div class="limit" style:color="var(--color-danger)"><Icon name="error" size={15} color="var(--color-danger)" />{error}</div>
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
              <button class="chip" onclick={() => submit(s.label())}>
                <Icon name={s.glyph} size={15} color="var(--color-accent-text)" />
                {s.label()}
              </button>
            {/each}
          </div>
        {/if}
        {#if empty}
          <div class="intro">{$LL.deskAgentIntro({ host: store.hostname })}</div>
        {/if}
      </div>
    </div>
  </div>
  <div class="spacer" class:spacer--grow={focus}></div>
</div>

<style>
  .home {
    flex: 1;
    min-height: 0;
    display: flex;
    flex-direction: column;
    animation: lk-fade-in var(--dur-tab-content) var(--ease-standard);
  }
  .top {
    flex: 1 1 0;
    min-height: 0;
    overflow: hidden;
    transition:
      opacity 260ms var(--ease-standard),
      transform 600ms var(--ease-emphasized);
  }
  .top--away {
    opacity: 0;
    transform: scale(0.97);
    pointer-events: none;
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

  .hero-wrap {
    flex: none;
    width: 100%;
    max-width: 1280px;
    margin: 0 auto;
    box-sizing: border-box;
    padding: var(--space-13) var(--space-55) var(--space-34);
  }
  .hero {
    display: flex;
    flex-direction: column;
    gap: var(--space-7);
    max-width: 760px;
    transition: transform 600ms var(--ease-emphasized);
  }
  .hero--focus {
    margin: 0 auto;
  }
  .hero__greet,
  .hero__input {
    font-size: 27px;
    font-weight: var(--weight-semibold);
    letter-spacing: var(--tracking-display);
    line-height: var(--leading-tight);
    transition: font-size 600ms var(--ease-emphasized);
  }
  .hero__input {
    border: 0;
    outline: 0;
    background: transparent;
    padding: 0;
    font-family: inherit;
    font-weight: var(--weight-regular);
    color: var(--text-primary);
    caret-color: var(--color-accent);
  }
  .hero__input::placeholder {
    color: var(--text-tertiary);
  }
  .hero--focus .hero__greet,
  .hero--focus .hero__input {
    font-size: 41px;
  }
  .hero__below {
    display: flex;
    flex-direction: column;
    gap: var(--space-11);
    margin-top: var(--space-11);
  }
  .paste {
    display: flex;
    gap: var(--space-11);
    align-items: flex-start;
    width: min(100%, 460px);
    box-sizing: border-box;
    padding: var(--space-11) var(--space-11) var(--space-11) var(--space-13);
    border-radius: var(--radius-card);
    background: var(--surface-raised);
    box-shadow: var(--shadow-popover);
    animation: lk-pop-in var(--dur-slow) var(--ease-spring-bouncy);
  }
  .paste__icon {
    flex: none;
    display: grid;
    place-items: center;
    width: 34px;
    height: 34px;
    border-radius: var(--radius-control);
    background: var(--color-accent-soft);
  }
  .paste__body {
    flex: 1;
    min-width: 0;
    display: flex;
    flex-direction: column;
  }
  .paste__head {
    display: flex;
    align-items: baseline;
    gap: var(--space-7);
  }
  .paste__title {
    font-size: var(--text-13);
    font-weight: 600;
  }
  .paste__meta {
    font-size: var(--text-12);
    color: var(--text-tertiary);
  }
  .paste__lines {
    margin-top: var(--space-7);
    font-family: var(--font-mono);
    font-size: var(--text-11);
    line-height: 1.65;
    color: var(--text-secondary);
    -webkit-mask-image: linear-gradient(#000 45%, transparent);
    mask-image: linear-gradient(#000 45%, transparent);
  }
  .send {
    display: flex;
    align-items: center;
    gap: var(--space-11);
  }
  .send__hint {
    font-size: var(--text-12);
    color: var(--text-tertiary);
    white-space: pre;
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
    gap: var(--space-7);
  }
  .chip {
    display: flex;
    align-items: center;
    gap: var(--space-5);
    height: 32px;
    padding: 0 var(--space-13) 0 var(--space-11);
    border: 0;
    border-radius: var(--radius-full);
    background: var(--glass-tile);
    box-shadow: inset 0 0 0 0.5px var(--border-hairline);
    font: inherit;
    font-size: var(--text-13);
    color: var(--text-secondary);
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
  .spacer {
    flex: 0 1 0;
    min-height: 0;
    transition: flex-grow 600ms var(--ease-emphasized);
  }
  .spacer--grow {
    flex-grow: 1;
  }

  @container (max-width: 760px) {
    .cols {
      flex-direction: column;
      overflow-y: auto;
      gap: var(--space-21);
    }
    .hero-wrap {
      padding: var(--space-13) var(--space-21) var(--space-21);
    }
  }
</style>
