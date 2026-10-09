<script lang="ts">
  /// One task: its steps on the left, the chosen one in the middle with the
  /// reply field, its output on the right.

  import { tick } from 'svelte'
  import { LL } from '../../i18n/i18n-svelte'
  import { fmtDate } from '../../lib/format'
  import { AppIcon, Button, Icon, IconButton, Spinner, ToolbarGroup } from '../lk'
  import type { AgentStore } from './agentStore.svelte'
  import { AREA, duration, fileGlyph, statusLook, stepLook, waitLabel } from './agentView'
  import AttachmentChips from './AttachmentChips.svelte'
  import { autosize } from './autosize'
  import { changesMemory, currentStep, deriveSteps, elapsed, type Step } from './flowModel'
  import OutputPane from './OutputPane.svelte'
  import StepBody from './StepBody.svelte'

  interface Props {
    store: AgentStore
    now: Date
    onback: () => void
    onopen: (id: string) => void
    admin: boolean
  }

  const { store, now, onback, onopen, admin }: Props = $props()

  const detail = $derived(store.detail)
  const flow = $derived(detail?.flow ?? store.flows.find((f) => f.id === store.openId) ?? null)
  const model = $derived(
    detail ? deriveSteps(detail.entries, detail.flow.status, detail.pending, detail.output, store.streaming) : { prompt: '', files: [], steps: [] as Step[] },
  )
  const steps = $derived(model.steps)

  /// The step shown; follows the task while the account has not picked one.
  let picked = $state<number | null>(null)
  let pickedFor: string | null = null
  $effect(() => {
    if (store.openId !== pickedFor) {
      pickedFor = store.openId
      picked = null
    }
  })
  const sel = $derived(Math.min(picked ?? currentStep(steps), Math.max(0, steps.length - 1)))
  const step = $derived(steps[sel] ?? null)

  let sending = $state(false)
  let replyError = $state<string | null>(null)
  let replyInput = $state<HTMLTextAreaElement | null>(null)
  let replyMulti = $state(false)
  let picker = $state<HTMLInputElement | null>(null)
  /// The open task's unsent words and files, kept by the store.
  const draft = $derived(store.draft(store.openId ?? ''))
  const atts = $derived(draft.atts)
  let dragging = $state(false)
  let dragDepth = 0

  const hasFiles = (e: DragEvent) => Array.from(e.dataTransfer?.types ?? []).includes('Files')
  function ondragenter(e: DragEvent) {
    if (!hasFiles(e) || offline) return
    e.preventDefault()
    dragDepth += 1
    dragging = true
  }
  function ondragover(e: DragEvent) {
    if (!hasFiles(e) || offline) return
    e.preventDefault()
    if (e.dataTransfer) e.dataTransfer.dropEffect = 'copy'
  }
  function ondragleave() {
    dragDepth = Math.max(0, dragDepth - 1)
    if (!dragDepth) dragging = false
  }
  function ondrop(e: DragEvent) {
    if (!hasFiles(e) || offline) return
    e.preventDefault()
    dragDepth = 0
    dragging = false
    atts.addFiles(e.dataTransfer?.files)
    replyInput?.focus()
  }
  const offline = $derived(!store.live && store.loaded)

  function move(d: number) {
    if (!steps.length) return
    pick(Math.max(0, Math.min(steps.length - 1, sel + d)), false)
  }

  async function send(text = draft.text) {
    const t = text.trim()
    if ((!t && !atts.length) || !flow || sending || offline) return
    sending = true
    replyError = null
    try {
      const ids = await atts.ids()
      if (!ids) return
      await store.reply(flow.id, t, ids)
      draft.clear(false)
      picked = null
    } catch (e) {
      replyError = e instanceof Error ? e.message : String(e)
    } finally {
      sending = false
    }
  }

  // View → Previous / Next step, from the menubar.
  // Only asks made while this view is up: one before it is not for it.
  let handledAsk: number | null = null
  $effect(() => {
    const r = store.request
    if (handledAsk === null) {
      handledAsk = r?.n ?? 0
      return
    }
    if (!r || r.n === handledAsk) return
    handledAsk = r.n
    if (r.kind === 'step' && r.d) move(r.d)
  })

  function onkeydown(e: KeyboardEvent) {
    const tag = ((e.target as HTMLElement | null)?.tagName ?? '').toLowerCase()
    const typing = tag === 'input' || tag === 'textarea'
    if (e.key === 'Escape' && !typing) {
      e.preventDefault()
      onback()
    } else if (!typing && (e.key === 'ArrowDown' || e.key === 'ArrowUp')) {
      e.preventDefault()
      move(e.key === 'ArrowDown' ? 1 : -1)
    } else if (!typing && /^[1-9]$/.test(e.key)) {
      const p = detail?.pending
      if (p?.kind === 'clarify' && step?.state === 'waiting' && p.options?.[+e.key - 1]) {
        void store.answer(flow!.id, { id: p.id, action: 'pick', index: +e.key - 1 })
      }
    }
  }

  const look = $derived(flow ? statusLook(flow) : null)
  const meta = $derived.by(() => {
    if (!flow) return ''
    if (flow.startedAt && (flow.status === 'running' || flow.status === 'waiting')) {
      return $LL.deskAgentStarted({
        time: fmtDate(new Date(flow.startedAt), { hour: '2-digit', minute: '2-digit' }),
        duration: duration($LL, elapsed(flow.startedAt, now)),
      })
    }
    return fmtDate(new Date(flow.finishedAt ?? flow.updatedAt), { month: 'short', day: 'numeric', hour: '2-digit', minute: '2-digit' })
  })
  const others = $derived(store.flows.filter((f) => f.id !== flow?.id && f.status === 'running'))

  function stepTitle(s: Step): string {
    if (s.kind === 'thinking') return $LL.deskAgentThinking()
    if (s.kind === 'reply') return $LL.deskAgentAnswer()
    if (s.kind === 'memory') return changesMemory(s) ? $LL.deskAgentMemoryWrite() : $LL.deskAgentMemoryRead()
    return s.title
  }

  /// [area]: a finished step with nothing to time says where it ran; the
  /// card's head names that already.
  function stepMeta(s: Step, area = true): string {
    switch (s.state) {
      case 'running':
        return s.kind === 'thinking' ? $LL.deskAgentThinking() : $LL.deskAgentCmdRunning()
      case 'waiting':
        return waitLabel($LL, s.waiting)
      case 'failed':
        return s.exitCode !== null ? $LL.deskAgentExitCode({ code: s.exitCode }) : s.timedOut ? $LL.deskAgentTimedOut() : $LL.deskAgentFailed()
      case 'cancelled':
        return $LL.deskAgentStatusCancelled()
      case 'pending':
        return $LL.deskAgentStatusQueued()
      default:
        return s.durationMs !== null && s.durationMs >= 1000 ? duration($LL, s.durationMs / 1000) : area ? AREA[s.area].name($LL) : ''
    }
  }

  function metaColor(s: Step): string {
    return s.state === 'failed' ? 'var(--color-danger)' : s.state === 'waiting' ? 'var(--color-warning)' : 'var(--text-tertiary)'
  }

  // Every step is a card in one scrolling column. Picking a step scrolls to
  // its card; scrolling picks the card at the top; the last card can always
  // reach the top.
  let listEl = $state<HTMLDivElement | null>(null)
  let cardsEl = $state<HTMLDivElement | null>(null)
  /// The pick came from the column itself: nothing to scroll to.
  let spied = false
  /// Until then, the column scrolls because a step was picked.
  let scrollingUntil = 0
  let shownFlow: string | null = null
  let shownSel = -1

  function pick(i: number, fromColumn: boolean) {
    if (i === sel) return
    spied = fromColumn
    // Back on the step the task is at: follow it again.
    picked = i === currentStep(steps) ? null : i
  }

  function spyScroll() {
    if (!listEl || !cardsEl || Date.now() < scrollingUntil) return
    let i = 0
    for (const el of cardsEl.querySelectorAll<HTMLElement>('[data-card]')) {
      if (el.offsetTop - listEl.scrollTop <= 90) i = Number(el.dataset.card)
    }
    pick(i, true)
  }

  $effect(() => {
    const i = sel
    const id = store.openId
    if (!steps.length) return
    if (spied) {
      spied = false
      shownSel = i
      return
    }
    if (id === shownFlow && i === shownSel) return
    const smooth = id === shownFlow
    shownFlow = id
    shownSel = i
    void tick().then(() => {
      const el = cardsEl?.querySelector<HTMLElement>(`[data-card="${i}"]`)
      if (!listEl || !el) return
      scrollingUntil = Date.now() + (smooth ? 700 : 50)
      // The first step's place is the top, with what was asked above it.
      listEl.scrollTo({ top: i === 0 ? 0 : el.offsetTop, behavior: smooth ? 'smooth' : 'auto' })
    })
  })

  $effect(() => {
    const list = listEl
    const cards = cardsEl
    void steps.length
    if (!list || !cards) return
    const fit = () => {
      const last = cards.lastElementChild as HTMLElement | null
      if (!last) return
      const pad = `${Math.max(34, list.clientHeight - last.offsetHeight)}px`
      if (cards.style.paddingBottom !== pad) cards.style.paddingBottom = pad
    }
    const ro = new ResizeObserver(fit)
    ro.observe(list)
    if (cards.lastElementChild) ro.observe(cards.lastElementChild)
    fit()
    return () => ro.disconnect()
  })

  const placeholder = $derived(
    offline ? $LL.deskAgentReplyOffline() : step?.state === 'waiting' ? $LL.deskAgentReplyWaiting() : $LL.deskAgentReplyHint(),
  )
</script>

<svelte:window {onkeydown} />

<div class="grid">
  <aside class="left">
    <button class="back" onclick={onback}>
      <Icon name="arrow_back" size={16} />
      {$LL.deskAgentTimeline()}
      <span class="back__key">esc</span>
    </button>
    {#if flow && look}
      <div class="head">
        <div class="head__title">{flow.title}</div>
        <div class="head__meta">
          <span class="dot" style:background={look.color}></span>
          <span class="head__status" style:color={look.color}>{look.label($LL)}</span>
          <span class="head__time am-num">{meta}</span>
        </div>
      </div>
    {/if}
    <div class="rule"></div>
    <div class="steps">
      <div class="steps__list">
        {#if steps.length}
          <div class="pill" style:transform="translateY({sel * 49}px)"></div>
        {/if}
        {#each steps as s, i (s.id)}
          {@const sl = stepLook(s.state)}
          <button class="step" onclick={() => pick(i, false)}>
            <span class="step__icon">
              {#if s.state === 'done'}
                <span class="am-check"><Icon name="check_circle" size={18} fill color="var(--color-success)" /></span>
              {:else if s.state === 'pending'}
                <span class="step__num am-num">{i + 1}</span>
              {:else if sl}
                <Icon name={sl.glyph} size={18} fill={sl.fill} color={sl.color} class={s.state === 'running' ? 'am-spin' : s.state === 'waiting' ? 'am-pulse' : ''} />
              {/if}
            </span>
            <span class="step__text">
              <span
                class="step__title am-ellipsis"
                style:font-weight={i === sel ? 600 : 500}
                style:color={s.state === 'pending' || s.state === 'cancelled' ? 'var(--text-tertiary)' : 'var(--text-primary)'}
              >
                {stepTitle(s)}
              </span>
              <span
                class="step__meta am-ellipsis am-num"
                style:color={metaColor(s)}
              >
                {stepMeta(s)}
              </span>
            </span>
          </button>
        {/each}
      </div>
    </div>
    {#if others.length}
      <div class="others">
        <div class="am-label others__label">{$LL.deskAgentAlsoRunning()}</div>
        {#each others as o (o.id)}
          <button class="other" onclick={() => onopen(o.id)}>
            <Icon name="progress_activity" size={14} color="var(--color-accent-text)" class="am-spin" />
            <span class="other__title am-ellipsis">{o.title}</span>
            <span class="am-num other__n">{(o.steps ?? []).filter((x) => x.state === 'done').length}/{(o.steps ?? []).length}</span>
          </button>
        {/each}
      </div>
    {/if}
  </aside>

  <!-- svelte-ignore a11y_no_static_element_interactions -->
  <section class="center" {ondragenter} {ondragover} {ondragleave} {ondrop}>
    {#if dragging}
      <div class="drop">
        <div class="drop__box">
          <Icon name="upload_file" size={34} color="var(--color-accent-text)" />
          <span class="drop__title">{$LL.deskAgentDropTitle()}</span>
          <span class="drop__note">{$LL.deskAgentDropNote()}</span>
        </div>
      </div>
    {/if}
    <div class="bar">
      {#if step}
        <AppIcon glyph={AREA[step.area].glyph} tone={AREA[step.area].tone} size={22} />
        <span class="bar__title am-ellipsis">{stepTitle(step)}</span>
        <span class="bar__app">{AREA[step.area].name($LL)}</span>
        <span class="bar__pos am-num">{sel + 1} / {steps.length}</span>
      {:else}
        <span class="bar__pos"></span>
      {/if}
      <ToolbarGroup
        items={[
          { icon: 'keyboard_arrow_up', label: $LL.deskAgentPrevStep(), disabled: sel === 0, onclick: () => move(-1) },
          { icon: 'keyboard_arrow_down', label: $LL.deskAgentNextStep(), disabled: sel >= steps.length - 1, onclick: () => move(1) },
        ]}
      />
      {#if flow && (flow.status === 'running' || flow.status === 'waiting' || flow.status === 'queued')}
        <IconButton icon="stop_circle" label={$LL.deskAgentStop()} size="sm" onclick={() => store.stopFlow(flow.id)} />
      {:else if flow}
        <IconButton icon="delete" label={$LL.deskAgentDelete()} size="sm" onclick={() => store.remove(flow.id).then(onback)} />
      {/if}
    </div>

    {#if offline}
      <div class="offline">
        <Icon name="cloud_off" size={18} color="var(--color-warning)" />
        <div class="offline__text">
          <span class="offline__title">{$LL.deskAgentOffline({ host: store.hostname })}</span>
          <span class="offline__note">{$LL.deskAgentOfflineNote()}</span>
        </div>
        <Button size="sm" variant="secondary" icon="sync" onclick={() => store.refresh()}>{$LL.deskAgentReconnect()}</Button>
      </div>
    {/if}

    <div class="scroll" bind:this={listEl} onscroll={spyScroll}>
      {#if !detail}
        <div class="loading"><Spinner /></div>
      {:else}
        <div class="cards" bind:this={cardsEl}>
          {#if model.prompt || model.files.length}
            <div class="ask">
              {#if model.files.length}
                <div class="ask__files">
                  {#each model.files as f, i (i)}
                    <div class="ask__file">
                      <span class="ask__glyph"><Icon name={fileGlyph(f.name, f.mime)} size={15} fill /></span>
                      <span class="ask__name">{f.name}</span>
                      <span class="ask__size am-num">{f.size}</span>
                    </div>
                  {/each}
                </div>
              {/if}
              {#if model.prompt}<div class="ask__bubble">{model.prompt}</div>{/if}
            </div>
          {/if}
          {#each steps as s, i (s.id)}
            <!-- Pointer convenience only: the step list and the arrow keys pick a step from the keyboard. -->
            <!-- svelte-ignore a11y_no_static_element_interactions -->
            <section class="card" class:card--rule={i > 0} data-card={i} onpointerdown={() => pick(i, true)}>
              <div class="card__head">
                <span class="card__num am-num" class:card__num--on={i === sel}>{i + 1}</span>
                <span class="card__title am-ellipsis">{stepTitle(s)}</span>
                <span class="card__app">{AREA[s.area].name($LL)}</span>
                <span class="card__meta am-num" style:color={metaColor(s)}>{stepMeta(s, false)}</span>
              </div>
              <StepBody
                step={s}
                pending={detail.pending}
                status={detail.flow.status}
                onanswer={(a) => store.answer(detail.flow.id, a)}
                onreply={async (t) => {
                  await store.reply(detail.flow.id, t)
                  picked = null
                }}
                onbackground={onback}
                onretry={() => send($LL.deskAgentRetryPrompt())}
                {admin}
              />
            </section>
          {/each}
        </div>
      {/if}
    </div>

    <div class="reply">
      <div class="reply__inner">
        <div class="field" class:field--multi={replyMulti} class:field--files={atts.length > 0} style:opacity={offline ? 0.5 : 1}>
          {#if atts.length}<AttachmentChips {atts} />{/if}
          <div class="field__row">
          <Icon name="auto_awesome" size={15} color="var(--text-tertiary)" />
          <textarea
            bind:this={replyInput}
            bind:value={draft.text}
            rows="1"
            use:autosize={{ value: draft.text, max: 6, onmulti: (m) => (replyMulti = m) }}
            readonly={offline}
            {placeholder}
            aria-label={placeholder}
            onkeydown={(e) => {
              if (e.isComposing) return
              if (e.key === 'Enter' && !e.shiftKey) {
                e.preventDefault()
                void send()
              } else if (e.key === 'Escape') {
                replyInput?.blur()
              } else if ((e.metaKey || e.ctrlKey) && e.key.toLowerCase() === 'u') {
                e.preventDefault()
                picker?.click()
              }
            }}
            onpaste={(e) => {
              if (atts.paste(e)) e.preventDefault()
            }}
          ></textarea>
          <IconButton icon="attach_file" label={$LL.deskAgentAttach()} size="sm" disabled={offline} onmousedown={(e) => e.preventDefault()} onclick={() => picker?.click()} />
          <IconButton
            icon="arrow_upward"
            label={$LL.deskAgentSend()}
            variant="filled"
            size="sm"
            disabled={(!draft.text.trim() && !atts.length) || offline || sending}
            onclick={() => send()}
          />
          <input
            bind:this={picker}
            type="file"
            multiple
            tabindex="-1"
            aria-hidden="true"
            hidden
            onchange={(e) => {
              const input = e.currentTarget
              atts.addFiles(input.files)
              input.value = ''
              replyInput?.focus()
            }}
          />
          </div>
        </div>
        {#if replyError ?? atts.error}
          <div class="reply__error">{replyError ?? atts.error}</div>
        {:else}
          <div class="keys">
            <span>{$LL.deskAgentKeySteps()}</span><span>{$LL.deskAgentKeySend()}</span><span>⇧⏎ {$LL.deskAgentHintNewline()}</span>
            <span>⌘U {$LL.deskAgentHintPick()}</span><span>{$LL.deskAgentKeyBack()}</span>
          </div>
        {/if}
      </div>
    </div>
  </section>

  <section class="right">
    <OutputPane {step} />
  </section>
</div>

<style>
  .grid {
    flex: 1;
    min-height: 0;
    display: grid;
    grid-template-columns: 252px minmax(420px, 1fr) minmax(0, 420px);
    grid-template-rows: minmax(0, 1fr);
    gap: var(--space-13);
    padding: var(--space-9) var(--space-13) var(--space-13);
    box-sizing: border-box;
  }
  @container (max-width: 1179px) {
    .grid {
      grid-template-columns: 232px minmax(0, 1fr);
      grid-template-rows: minmax(0, 1fr) minmax(180px, 36%);
    }
    .left {
      grid-row: 1 / span 2;
    }
    .right {
      grid-column: 2;
    }
  }
  @container (max-width: 720px) {
    .grid {
      grid-template-columns: minmax(0, 1fr);
      grid-template-rows: auto minmax(0, 1fr) minmax(160px, 34%);
    }
    .left {
      grid-row: auto;
      max-height: 180px;
    }
    .right {
      grid-column: auto;
    }
  }
  .left {
    display: flex;
    flex-direction: column;
    min-height: 0;
    padding: var(--space-9);
    border-radius: var(--radius-panel);
    background: var(--glass-sidebar);
    backdrop-filter: var(--blur-sidebar);
    -webkit-backdrop-filter: var(--blur-sidebar);
    box-shadow:
      inset 0 0 0 0.5px var(--border-glass),
      var(--shadow-popover);
    animation: am-in-left 420ms var(--ease-emphasized) 90ms backwards;
  }
  @keyframes am-in-left {
    from {
      opacity: 0;
      transform: translateX(-17px);
    }
  }
  @keyframes am-in-right {
    from {
      opacity: 0;
      transform: translateX(17px);
    }
  }
  @keyframes am-in-center {
    from {
      opacity: 0;
      transform: scale(0.96);
    }
  }
  .back {
    display: flex;
    align-items: center;
    gap: var(--space-7);
    height: 30px;
    padding: 0 var(--space-9);
    border: 0;
    border-radius: var(--radius-sm);
    background: transparent;
    font: inherit;
    font-size: var(--text-13);
    color: var(--text-secondary);
    cursor: default;
    text-align: left;
  }
  .back:hover {
    background: var(--fill-hover);
    color: var(--text-primary);
  }
  .back:active {
    transform: scale(0.97);
  }
  .back__key {
    margin-left: auto;
    font-size: var(--text-11);
    color: var(--text-tertiary);
  }
  .head {
    padding: var(--space-17) var(--space-11) var(--space-13);
    display: flex;
    flex-direction: column;
    gap: var(--space-7);
  }
  .head__title {
    font-size: var(--text-21);
    font-weight: var(--weight-semibold);
    letter-spacing: var(--tracking-display);
    line-height: var(--leading-tight);
    text-wrap: pretty;
    overflow-wrap: anywhere;
  }
  .head__meta {
    display: flex;
    align-items: center;
    gap: var(--space-7);
    font-size: var(--text-12);
    min-width: 0;
  }
  .dot {
    flex: none;
    width: 7px;
    height: 7px;
    border-radius: 50%;
  }
  .head__status {
    font-weight: 600;
    white-space: nowrap;
  }
  .head__time {
    color: var(--text-tertiary);
    white-space: nowrap;
    overflow: hidden;
    text-overflow: ellipsis;
  }
  .rule {
    height: 0.5px;
    background: var(--border-hairline);
    margin: 0 var(--space-11) var(--space-9);
  }
  .steps {
    flex: 1;
    min-height: 0;
    overflow-y: auto;
  }
  .steps__list {
    position: relative;
    display: flex;
    flex-direction: column;
    gap: 3px;
  }
  .pill {
    position: absolute;
    left: 0;
    right: 0;
    top: 0;
    height: 46px;
    border-radius: var(--radius-control);
    background: var(--surface-raised);
    box-shadow: var(--shadow-control);
    transition: transform var(--dur-indicator) var(--ease-indicator);
  }
  .step {
    position: relative;
    display: grid;
    grid-template-columns: 20px minmax(0, 1fr);
    column-gap: var(--space-9);
    align-items: center;
    height: 46px;
    padding: 0 var(--space-11);
    border: 0;
    border-radius: var(--radius-control);
    background: transparent;
    font: inherit;
    text-align: left;
    cursor: default;
    color: var(--text-primary);
    transition: background var(--dur-fast) var(--ease-standard);
  }
  .step:hover {
    background: var(--fill-hover);
  }
  .step__icon {
    display: grid;
    place-items: center;
    width: 20px;
    height: 20px;
  }
  .step__num {
    display: grid;
    place-items: center;
    width: 16px;
    height: 16px;
    border-radius: 50%;
    box-shadow: inset 0 0 0 1.5px var(--border-strong);
    font-size: 10px;
    font-weight: 700;
    color: var(--text-tertiary);
  }
  .step__text {
    display: flex;
    flex-direction: column;
    min-width: 0;
    gap: 1px;
  }
  .step__title {
    font-size: var(--text-13);
  }
  .step__meta {
    font-size: var(--text-11);
  }
  .others {
    display: flex;
    flex-direction: column;
    gap: var(--space-3);
    padding-top: var(--space-9);
    border-top: 0.5px solid var(--border-hairline);
  }
  .others__label {
    padding: var(--space-5) var(--space-11);
  }
  .other {
    display: flex;
    align-items: center;
    gap: var(--space-9);
    height: 32px;
    padding: 0 var(--space-11);
    border: 0;
    border-radius: var(--radius-sm);
    background: transparent;
    font: inherit;
    font-size: var(--text-12);
    color: var(--text-secondary);
    cursor: default;
    text-align: left;
  }
  .other:hover {
    background: var(--fill-hover);
    color: var(--text-primary);
  }
  .other__title {
    flex: 1;
    min-width: 0;
  }
  .other__n {
    color: var(--text-tertiary);
  }

  .center {
    position: relative;
    display: flex;
    flex-direction: column;
    min-height: 0;
    min-width: 0;
    border-radius: var(--radius-window);
    background: var(--surface-content);
    box-shadow: var(--shadow-window);
    overflow: hidden;
    animation: am-in-center 420ms var(--ease-emphasized);
  }
  .bar {
    flex: none;
    display: flex;
    align-items: center;
    gap: var(--space-9);
    height: 52px;
    padding: 0 var(--space-13) 0 var(--space-21);
    border-bottom: 0.5px solid var(--border-hairline);
  }
  .bar__title {
    font-size: var(--text-15);
    font-weight: var(--weight-bold);
    min-width: 0;
  }
  .bar__app {
    font-size: var(--text-12);
    color: var(--text-tertiary);
    white-space: nowrap;
  }
  .bar__pos {
    margin-left: auto;
    font-size: var(--text-12);
    color: var(--text-tertiary);
    white-space: nowrap;
  }
  .offline {
    flex: none;
    display: flex;
    align-items: center;
    gap: var(--space-11);
    padding: var(--space-11) var(--space-13) var(--space-11) var(--space-21);
    background: var(--color-warning-soft);
    border-bottom: 0.5px solid var(--border-hairline);
    animation: am-rise var(--dur-slow) var(--ease-spring);
  }
  .offline__text {
    flex: 1;
    min-width: 0;
    display: flex;
    flex-direction: column;
    gap: 1px;
  }
  .offline__title {
    font-size: var(--text-13);
    font-weight: 600;
  }
  .offline__note {
    font-size: var(--text-12);
    color: var(--text-secondary);
  }
  .scroll {
    position: relative;
    flex: 1;
    min-height: 0;
    overflow-y: auto;
  }
  .loading {
    height: 100%;
    display: grid;
    place-items: center;
  }
  .cards {
    position: relative;
    max-width: 640px;
    margin: 0 auto;
    padding: 0 var(--space-27) var(--space-34);
  }
  .ask {
    display: flex;
    flex-direction: column;
    align-items: flex-end;
    gap: var(--space-7);
    padding-top: var(--space-27);
  }
  .ask__files {
    display: flex;
    flex-wrap: wrap;
    justify-content: flex-end;
    gap: var(--space-7);
    max-width: 80%;
  }
  .ask__file {
    display: flex;
    align-items: center;
    gap: var(--space-7);
    height: 34px;
    max-width: 280px;
    box-sizing: border-box;
    padding: 0 var(--space-9) 0 var(--space-7);
    border-radius: 9px;
    background: var(--surface-raised);
    box-shadow: var(--shadow-control);
  }
  .ask__glyph {
    flex: none;
    width: 24px;
    height: 24px;
    border-radius: 5px;
    display: inline-flex;
    align-items: center;
    justify-content: center;
    background: var(--color-accent-soft);
    color: var(--color-accent-text);
  }
  .ask__name {
    min-width: 0;
    overflow: hidden;
    text-overflow: ellipsis;
    white-space: nowrap;
    font-size: var(--text-12);
    font-weight: 600;
  }
  .ask__size {
    flex: none;
    font-size: var(--text-11);
    color: var(--text-tertiary);
  }
  .ask__bubble {
    max-width: 80%;
    padding: var(--space-9) var(--space-13);
    border-radius: var(--radius-card);
    background: var(--surface-selected);
    font-size: var(--text-13);
    line-height: var(--leading-snug);
    color: var(--text-primary);
    white-space: pre-wrap;
    overflow-wrap: anywhere;
    text-wrap: pretty;
  }
  .card {
    display: flex;
    flex-direction: column;
    gap: var(--space-21);
    padding: var(--space-27) 0 var(--space-34);
  }
  .card--rule {
    border-top: 0.5px solid var(--border-hairline);
  }
  .card__head {
    display: flex;
    align-items: center;
    gap: var(--space-9);
    min-width: 0;
  }
  .card__num {
    flex: none;
    display: grid;
    place-items: center;
    min-width: 20px;
    height: 20px;
    border-radius: var(--radius-full);
    background: var(--fill-hover);
    font-size: var(--text-11);
    font-weight: 700;
    color: var(--text-tertiary);
    transition:
      background var(--dur-fast) var(--ease-standard),
      color var(--dur-fast) var(--ease-standard);
  }
  .card__num--on {
    background: var(--color-accent);
    color: var(--text-on-accent, #fff);
  }
  .card__title {
    min-width: 0;
    font-size: var(--text-13);
    font-weight: 600;
  }
  .card__app {
    font-size: var(--text-12);
    color: var(--text-tertiary);
    white-space: nowrap;
  }
  .card__meta {
    margin-left: auto;
    font-size: var(--text-12);
    white-space: nowrap;
  }
  .reply {
    flex: none;
    padding: var(--space-11) var(--space-21) var(--space-13);
    border-top: 0.5px solid var(--border-hairline);
  }
  .reply__inner {
    max-width: 640px;
    margin: 0 auto;
    display: flex;
    flex-direction: column;
    gap: var(--space-7);
  }
  /* 38 tall with one line; the text grows it (`autosize`). */
  .field {
    display: flex;
    flex-direction: column;
    gap: var(--space-9);
    min-height: 38px;
    box-sizing: border-box;
    padding: 7px var(--space-5) 7px var(--space-13);
    border-radius: 19px;
    background: var(--surface-card);
  }
  .field--files {
    padding-top: var(--space-9);
    padding-left: var(--space-9);
  }
  .field__row {
    display: flex;
    align-items: center;
    gap: var(--space-9);
  }
  .field--files .field__row {
    padding-left: var(--space-3);
  }
  .field--multi .field__row {
    align-items: flex-end;
  }
  .field textarea {
    flex: 1;
    min-width: 0;
    box-sizing: border-box;
    height: calc(1.4em + 6px);
    margin: 0;
    padding: 3px 0;
    border: 0;
    outline: 0;
    resize: none;
    background: transparent;
    font: inherit;
    font-size: var(--text-13);
    line-height: 1.4;
    color: var(--text-primary);
  }
  .field textarea::placeholder {
    white-space: nowrap;
    overflow: hidden;
    text-overflow: ellipsis;
    color: var(--text-tertiary);
  }
  .keys {
    display: flex;
    gap: var(--space-13);
    padding-left: var(--space-13);
    font-size: var(--text-11);
    color: var(--text-tertiary);
  }
  .reply__error {
    padding-left: var(--space-13);
    font-size: var(--text-12);
    color: var(--color-danger);
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
    width: calc(100% - 42px);
    max-width: 640px;
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
  .right {
    min-height: 0;
    min-width: 0;
    animation: am-in-right 420ms var(--ease-emphasized) 140ms backwards;
  }
</style>
