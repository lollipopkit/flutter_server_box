<script lang="ts">
  /// The desk's search: apps, windows, servers and paths at once, and, where
  /// Agent mode runs, the agent's answer to what was typed (`/agent/search`):
  /// the things a term names, the answer to a question, or a change drafted
  /// as a plan — read only; a change runs once it is carried into Agent mode.

  import { LL } from '../../i18n/i18n-svelte'
  import Markdown from '../../components/Markdown.svelte'
  import { agentApi, type SearchEvent, type SearchFollowup, type SearchItem, type SearchKind, type SearchPlanStep } from '../../lib/agentApi'
  import { ApiError } from '../../lib/api'
  import { serverNames } from '../../lib/serverNames.svelte'
  import { serverMatches } from '../../lib/serverSearch'
  import { displayName, servers } from '../../lib/servers.svelte'
  import { app } from '../registry.svelte'
  import type { AppSpec } from '../sys/manifest'
  import { useDesk } from '../deskState.svelte'
  import LkAppIcon, { type IconTone } from '../lk/AppIcon.svelte'
  import Button from '../lk/Button.svelte'
  import Icon from '../lk/Icon.svelte'
  import AppIcon from './AppIcon.svelte'

  interface Props {
    /// Switches the panel to another server (its own desk).
    onswitch: (serverId: string) => void
  }

  const { onswitch }: Props = $props()
  const desk = useDesk()

  /// `autofocus` is ignored once anything on the page has focus.
  function focusNow(el: HTMLInputElement) {
    queueMicrotask(() => el.focus())
  }

  interface Hit {
    key: string
    group: string
    label: string
    detail?: string
    spec?: AppSpec
    /// For a hit that is not an app: its glyph and tone.
    glyph?: string
    tone?: IconTone
    run: () => void
  }

  let query = $state('')
  let selected = $state(0)

  const localHits = $derived.by((): Hit[] => {
    const q = query.trim().toLowerCase()
    const out: Hit[] = []
    if (q.startsWith('/') && app('files')?.available(desk.caps)) {
      out.push({
        key: 'path',
        group: $LL.files(),
        label: query.trim(),
        detail: $LL.deskOpenInFiles(),
        glyph: 'folder',
        tone: 'sky',
        run: () => desk.open('files', { appState: { path: query.trim() }, newWindow: true }),
      })
    }
    const matches = (words: string[]) => !q || words.some((w) => w.toLowerCase().includes(q))
    for (const spec of desk.apps) {
      if (matches([spec.title($LL), spec.id, ...(spec.keywords?.($LL) ?? [])])) {
        out.push({ key: `app:${spec.id}`, group: $LL.deskApps(), label: spec.title($LL), spec, run: () => desk.open(spec.id) })
      }
    }
    for (const w of desk.windows.windows) {
      const spec = app(w.appId)
      const label = w.title ?? spec?.title($LL) ?? w.appId
      if (q && matches([label])) {
        out.push({ key: `win:${w.id}`, group: $LL.deskWindows(), label, glyph: 'select_window', tone: 'mist', run: () => desk.windows.focus(w.id) })
      }
    }
    if (!servers.servedByAgent) {
      for (const s of servers.list) {
        if (s.id === desk.entry.id) continue
        const name = serverNames.byServer[s.id] ?? (s.id === 'local' ? $LL.thisServer() : displayName(s))
        if (q && serverMatches(q, name, s.url)) {
          out.push({ key: `srv:${s.id}`, group: $LL.deskServers(), label: name, detail: s.url, glyph: 'dns', tone: 'pale', run: () => onswitch(s.id) })
        }
      }
    }
    return out.slice(0, 30)
  })

  // ---------------------------------------------------------------------------
  // The agent's part

  interface AgentState {
    kind: SearchKind | null
    steps: { id: string; command: string; state: 'running' | 'done' | 'failed' }[]
    items: SearchItem[]
    followups: SearchFollowup[]
    plan: SearchPlanStep[]
    /// The model's words of its latest message, as they are written.
    words: string
    done: { id: string; answer: string; steps: number; ms: number } | null
    error: string | null
  }

  const fresh = (): AgentState => ({ kind: null, steps: [], items: [], followups: [], plan: [], words: '', done: null, error: null })
  let agent = $state<AgentState | null>(null)
  let busy = $state(false)
  let abort: AbortController | null = null
  let timer: ReturnType<typeof setTimeout> | undefined

  /// Typing waits this long for a pause before the agent is asked.
  const PAUSE_MS = 700

  function stop() {
    clearTimeout(timer)
    abort?.abort()
    abort = null
    agent = null
  }

  function ask(kind?: SearchKind) {
    const q = query.trim()
    stop()
    if (!desk.agentAvailable || q.length < 2) return
    const controller = new AbortController()
    abort = controller
    const state = fresh()
    agent = state
    const at = desk.entry
    void agentApi
      .search(at, q, kind, controller.signal, (e: SearchEvent) => {
        if (abort !== controller || !agent) return
        onEvent(agent, e)
      })
      .catch((e: unknown) => {
        if (abort !== controller || controller.signal.aborted || !agent) return
        // Not set up here: the search stays the desk's own.
        if (e instanceof ApiError && e.status === 409) agent = null
        else agent.error = e instanceof Error ? e.message : String(e)
      })
  }

  function onEvent(a: AgentState, e: SearchEvent) {
    switch (e.type) {
      case 'kind':
        a.kind = e.kind
        break
      case 'step': {
        const s = a.steps.find((x) => x.id === e.id)
        if (s) s.state = e.state
        else a.steps.push({ id: e.id, command: e.command, state: e.state })
        break
      }
      case 'items':
        a.items = e.items
        a.followups = e.followups
        break
      case 'plan':
        a.plan = e.steps
        break
      case 'said':
        a.words = ''
        break
      case 'delta':
        a.words += e.text
        break
      case 'done':
        a.done = { id: e.id, answer: e.answer, steps: e.steps, ms: e.ms }
        break
      case 'error':
        a.error = e.message
        break
    }
  }

  $effect(() => {
    const q = query.trim()
    selected = 0
    stop()
    if (q.length >= 2 && !q.startsWith('/')) timer = setTimeout(() => ask(), PAUSE_MS)
    return () => clearTimeout(timer)
  })
  $effect(() => () => abort?.abort())

  const ITEM: Record<SearchItem['kind'], { app: string; glyph: string; tone: IconTone }> = {
    service: { app: 'services', glyph: 'settings_suggest', tone: 'bright' },
    process: { app: 'process', glyph: 'memory', tone: 'ink' },
    file: { app: 'files', glyph: 'description', tone: 'soft' },
    container: { app: 'containers', glyph: 'deployed_code', tone: 'pale' },
  }
  const kindLabel = (k: SearchItem['kind']) => app(ITEM[k].app)?.title($LL) ?? k

  function openItem(i: SearchItem) {
    desk.spotlight = false
    switch (i.kind) {
      case 'file': {
        const dir = i.ref.includes('/') ? i.ref.slice(0, i.ref.lastIndexOf('/')) || '/' : i.ref
        desk.open('files', { appState: { path: dir }, newWindow: true })
        break
      }
      case 'service':
        desk.open('services', { appState: { query: i.ref } })
        break
      case 'process':
        desk.open('process', { appState: { query: i.title } })
        break
      case 'container':
        desk.open('containers')
        break
    }
  }

  /// The search as a task in Agent mode; run on with [text].
  async function carry(text?: string) {
    const id = agent?.done?.id
    if (!id || busy) return
    busy = true
    try {
      const flow = await agentApi.adoptSearch(desk.entry, id, text)
      desk.spotlight = false
      desk.toggleAgent(true)
      void desk.agent?.open(flow.id)
    } catch (e) {
      if (agent) agent.error = e instanceof Error ? e.message : String(e)
    } finally {
      busy = false
    }
  }

  const kind = $derived(agent?.kind ?? null)
  const answered = $derived(kind === 'question' || kind === 'change')
  const running = $derived(!!agent && !agent.done && !agent.error)
  const primary = $derived(kind === 'question' ? (agent?.items[0] ?? null) : null)
  const answerText = $derived(agent?.done?.answer || agent?.words || '')

  /// The rows ↑↓ walks: the agent's things, the desk's own, then asking.
  interface Row {
    key: string
    group: string
    run: () => void
    hit?: Hit
    item?: SearchItem
    askRow?: boolean
  }
  const rows = $derived.by((): Row[] => {
    const out: Row[] = []
    const items = agent?.items ?? []
    const related = answered ? $LL.deskSearchRelated() : null
    for (const i of items) out.push({ key: `item:${i.kind}:${i.ref}`, group: related ?? kindLabel(i.kind), run: () => openItem(i), item: i })
    for (const h of localHits) out.push({ key: h.key, group: h.group, run: () => run(h), hit: h })
    if (desk.agentAvailable && query.trim().length >= 2 && kind !== 'question' && kind !== 'change') {
      out.push({ key: 'ask', group: '', run: () => ask('question'), askRow: true })
    }
    return out
  })

  function run(hit: Hit | undefined) {
    if (!hit) return
    desk.spotlight = false
    hit.run()
  }

  function onkeydown(e: KeyboardEvent) {
    if (e.key === 'ArrowDown') {
      e.preventDefault()
      selected = Math.min(selected + 1, rows.length - 1)
    } else if (e.key === 'ArrowUp') {
      e.preventDefault()
      selected = Math.max(selected - 1, 0)
    } else if (e.key === 'Enter' && (e.metaKey || e.ctrlKey)) {
      e.preventDefault()
      if (agent?.done && kind === 'change') void carry($LL.deskSearchGoAhead())
      else if (agent?.done && kind === 'question') void carry()
    } else if (e.key === 'Enter') {
      e.preventDefault()
      if (primary && selected === 0) openItem(primary)
      else rows[selected]?.run()
    } else if (e.key === 'Tab' && !e.shiftKey && desk.agentAvailable && query.trim().length >= 2) {
      e.preventDefault()
      ask('question')
    } else if (e.key === 'Escape') {
      e.preventDefault()
      desk.spotlight = false
    }
  }

  const footerLeft = $derived.by(() => {
    if (kind === 'change') return $LL.deskSearchNoChange()
    if (kind === 'question' && agent?.followups.length) return $LL.deskSearchConfirmInAgent()
    if (running) return $LL.deskSearchLooking()
    if (agent?.done) return $LL.deskSearchAgentStats({ steps: agent.done.steps, s: (agent.done.ms / 1000).toFixed(1) })
    return ''
  })
  const footerRight = $derived.by(() => {
    if (kind === 'change') return $LL.deskSearchKeysChange()
    if (kind === 'question') return primary ? $LL.deskSearchKeysQuestion({ app: kindLabel(primary.kind) }) : $LL.deskSearchKeysTask()
    return desk.agentAvailable ? $LL.deskSearchKeys() : ''
  })
</script>

<!-- svelte-ignore a11y_no_static_element_interactions -->
<div
  class="absolute inset-0 z-[100002] flex justify-center"
  onpointerdown={(e) => {
    e.stopPropagation()
    if (e.target === e.currentTarget) desk.spotlight = false
  }}
>
  <div class="lk-spot mt-[18vh] self-start" role="dialog" aria-label={$LL.deskSearch()}>
    <label class="lk-spot__bar">
      <Icon name="search" size={22} />
      <input
        placeholder={desk.agentAvailable ? $LL.deskSpotlightHintAgent() : $LL.deskSpotlightHint()}
        bind:value={query}
        {onkeydown}
        use:focusNow
        role="combobox"
        aria-expanded={rows.length > 0}
        aria-controls="desk-spotlight-results"
      />
    </label>

    {#if agent && answered}
      <div class="answer">
        <div class="answer__head">
          {#if kind === 'change'}
            <span class="badge badge--change"><Icon name="edit_note" size={16} /></span>
            <span class="answer__who">{$LL.deskSearchChange()}</span>
          {:else}
            <span class="badge" class:badge--live={running}><Icon name="auto_awesome" size={15} fill /></span>
            <span class="answer__who">Agent</span>
          {/if}
          <span class="answer__meta lk-num">
            {#if agent.done}
              {kind === 'change'
                ? agent.done.steps
                  ? $LL.deskSearchRead({ n: agent.done.steps })
                  : ''
                : $LL.deskSearchReadOnlyStats({ steps: agent.done.steps, s: (agent.done.ms / 1000).toFixed(1) })}
            {:else}
              {$LL.deskSearchReadOnly()}
            {/if}
          </span>
        </div>
        {#if agent.steps.length && kind === 'question'}
          <div class="answer__steps">
            {#each agent.steps as s (s.id)}
              <div class="answer__step">
                {#if s.state === 'running'}
                  <Icon name="progress_activity" size={14} color="var(--color-accent-text)" class="spin" />
                {:else if s.state === 'done'}
                  <Icon name="check_circle" size={14} fill color="var(--color-success)" />
                {:else}
                  <Icon name="error" size={14} fill color="var(--color-danger)" />
                {/if}
                <span class="lk-mono"><span class="dollar">$</span> {s.command}</span>
              </div>
            {/each}
          </div>
        {/if}
        {#if kind === 'question'}
          {#if answerText}
            <div class="answer__text"><Markdown text={answerText} /></div>
          {:else if running}
            <div class="answer__text answer__text--wait">{$LL.deskSearchLooking()}</div>
          {/if}
        {:else if agent.plan.length}
          <div class="plan">
            {#each agent.plan as p, i (i)}
              <div class="plan__row">
                <span class="plan__n">{i + 1}</span>
                <span class="plan__text lk-mono">{p.text}</span>
                <span class="plan__tag plan__tag--{p.effect}">
                  {p.effect === 'read' ? $LL.deskSearchTagRead() : p.effect === 'danger' ? $LL.deskSearchTagDanger() : $LL.deskSearchTagChange()}
                </span>
              </div>
            {/each}
          </div>
        {:else if running}
          <div class="answer__text answer__text--wait">{$LL.deskSearchDrafting()}</div>
        {/if}
        {#if agent.error}<div class="answer__error">{agent.error}</div>{/if}
        {#if agent.done}
          <div class="answer__actions">
            {#if kind === 'question'}
              {#if primary}
                <Button variant="primary" size="sm" icon={ITEM[primary.kind].glyph} onclick={() => openItem(primary)}>
                  {$LL.deskSearchViewIn({ app: kindLabel(primary.kind) })}
                </Button>
              {/if}
              {#each agent.followups as f (f.request)}
                <Button variant="secondary" size="sm" disabled={busy} onclick={() => carry(f.request)}>{f.label}…</Button>
              {/each}
              <Button variant="ghost" size="sm" icon="arrow_outward" disabled={busy} onclick={() => carry()}>{$LL.deskSearchToTask()}</Button>
            {:else if agent.plan.length}
              <Button variant="primary" size="sm" icon="auto_awesome" disabled={busy} onclick={() => carry($LL.deskSearchGoAhead())}>
                {$LL.deskSearchContinue()}
              </Button>
              {#each agent.items.filter((i) => i.kind === 'file').slice(0, 1) as f (f.ref)}
                <Button variant="ghost" size="sm" onclick={() => openItem(f)}>{$LL.deskSearchOpenFile()}</Button>
              {/each}
            {/if}
          </div>
        {/if}
      </div>
    {/if}

    {#if query.trim() && (rows.length || !answered)}
      <ul id="desk-spotlight-results" class="lk-spot__list" role="listbox">
        {#if agent?.done && !answered && !agent.items.length && !localHits.length}
          <li class="lk-spot__empty">{$LL.deskNoResults()}</li>
        {/if}
        {#each rows as row, i (row.key)}
          {#if row.askRow}
            <li class="sep" role="presentation"></li>
          {:else if i === 0 || rows[i - 1].group !== row.group}
            <li class="lk-spot__group" role="presentation">{row.group}</li>
          {/if}
          <li role="option" aria-selected={i === selected}>
            <button
              class="lk-spot__row w-full text-left"
              class:lk-spot__row--on={i === selected}
              onpointermove={() => (selected = i)}
              onclick={() => row.run()}
            >
              {#if row.hit}
                {#if row.hit.spec}
                  <AppIcon spec={row.hit.spec} size={26} />
                {:else if row.hit.glyph}
                  <LkAppIcon glyph={row.hit.glyph} tone={row.hit.tone} size={26} />
                {/if}
                <span class="min-w-0">
                  <span class="lk-spot__title block truncate">{row.hit.label}</span>
                  {#if row.hit.detail}<span class="lk-spot__sub block truncate">{row.hit.detail}</span>{/if}
                </span>
                <span class="lk-spot__kind">{row.hit.group}</span>
              {:else if row.item}
                <LkAppIcon glyph={ITEM[row.item.kind].glyph} tone={ITEM[row.item.kind].tone} size={26} />
                <span class="min-w-0">
                  <span class="lk-spot__title block truncate">{row.item.title}</span>
                  {#if row.item.sub}<span class="lk-spot__sub block truncate">{row.item.sub}</span>{/if}
                </span>
                <span class="lk-spot__kind">{kindLabel(row.item.kind)}</span>
              {:else}
                <span class="badge" class:badge--live={running && !answered}><Icon name="auto_awesome" size={15} fill /></span>
                <span class="min-w-0">
                  <span class="lk-spot__title block truncate">{$LL.deskSearchAsk({ q: query.trim() })}</span>
                  <span class="lk-spot__sub block truncate">
                    {running && !answered ? $LL.deskSearchLooking() : $LL.deskSearchAskSub()}
                  </span>
                </span>
                <span class="lk-spot__kind lk-mono">⇥</span>
              {/if}
            </button>
          </li>
        {:else}
          {#if !agent || agent.done}<li class="lk-spot__empty">{$LL.deskNoResults()}</li>{/if}
        {/each}
      </ul>
    {/if}
    {#if query.trim()}
      {#if footerLeft || footerRight}
        <div class="foot">
          <span class="lk-num">{footerLeft}</span>
          <span>{footerRight}</span>
        </div>
      {/if}
    {/if}
  </div>
</div>

<style>
  .answer {
    border-top: 0.5px solid var(--border-hairline);
    padding: var(--space-13) var(--space-17) var(--space-17);
    display: flex;
    flex-direction: column;
    gap: var(--space-11);
  }
  .answer__head {
    display: flex;
    align-items: center;
    gap: var(--space-9);
  }
  .badge {
    width: 26px;
    height: 26px;
    flex: none;
    border-radius: 26px;
    display: inline-flex;
    align-items: center;
    justify-content: center;
    background: var(--color-accent-soft);
    color: var(--color-accent-text);
  }
  .badge--live {
    animation: breathe 2.4s ease-in-out infinite;
  }
  .badge--change {
    background: var(--color-warning-soft);
    color: var(--color-warning);
  }
  @keyframes breathe {
    50% {
      transform: scale(1.06);
    }
  }
  .answer__who {
    font-weight: var(--weight-bold);
  }
  .answer__meta {
    font-size: var(--text-12);
    color: var(--text-tertiary);
  }
  .answer__steps {
    display: flex;
    flex-direction: column;
    gap: var(--space-5);
    padding-left: 35px;
  }
  .answer__step {
    display: flex;
    align-items: center;
    gap: var(--space-7);
    font-size: var(--text-12);
    color: var(--text-secondary);
    min-width: 0;
  }
  .answer__step .lk-mono {
    overflow: hidden;
    text-overflow: ellipsis;
    white-space: nowrap;
  }
  .dollar {
    color: var(--color-accent-text);
  }
  .answer__step :global(.spin) {
    animation: lk-spin 1s linear infinite;
  }
  .answer__text {
    padding-left: 35px;
    font-size: var(--text-15);
    line-height: 1.5;
  }
  .answer__text--wait {
    font-size: var(--text-13);
    color: var(--text-tertiary);
  }
  .answer__error {
    padding-left: 35px;
    font-size: var(--text-12);
    color: var(--color-danger);
  }
  .answer__actions {
    padding-left: 35px;
    display: flex;
    flex-wrap: wrap;
    gap: var(--space-7);
  }
  .plan {
    margin-left: 35px;
    border-radius: var(--radius-card);
    background: var(--surface-card);
    display: flex;
    flex-direction: column;
  }
  .plan__row {
    display: flex;
    align-items: center;
    gap: var(--space-9);
    min-height: 36px;
    padding: 0 var(--space-13);
    border-bottom: 0.5px solid var(--border-hairline);
  }
  .plan__row:last-child {
    border-bottom: 0;
  }
  .plan__n {
    width: 18px;
    height: 18px;
    flex: none;
    border-radius: 18px;
    display: inline-flex;
    align-items: center;
    justify-content: center;
    font-size: var(--text-11);
    font-weight: 700;
    background: var(--surface-control);
    color: var(--text-secondary);
  }
  .plan__text {
    flex: 1;
    min-width: 0;
    font-size: var(--text-12);
    overflow-wrap: anywhere;
  }
  .plan__tag {
    font-size: var(--text-11);
    font-weight: 600;
    color: var(--text-tertiary);
  }
  .plan__tag--change {
    color: var(--color-warning);
  }
  .plan__tag--danger {
    color: var(--color-danger);
  }
  .sep {
    height: 0.5px;
    background: var(--border-hairline);
    margin: 5px 9px;
  }
  .foot {
    height: 34px;
    display: flex;
    align-items: center;
    justify-content: space-between;
    gap: var(--space-13);
    padding: 0 var(--space-17);
    border-top: 0.5px solid var(--border-hairline);
    font-size: var(--text-12);
    color: var(--text-tertiary);
    white-space: nowrap;
  }
</style>
