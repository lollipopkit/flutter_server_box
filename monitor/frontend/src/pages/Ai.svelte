<script lang="ts">
  import { Badge, Button, Card, IconButton, Input, Modal, Spinner } from '@serverbox/webui'
  import {
    Check,
    History,
    Pencil,
    Plus,
    Send,
    Settings,
    ShieldAlert,
    Square,
    Trash,
    X,
  } from '@lucide/svelte'
  import FeatureTabs from '../components/FeatureTabs.svelte'
  import PageHeader from '../components/PageHeader.svelte'
  import Markdown from '../components/Markdown.svelte'
  import { api, ApiError } from '../lib/api'
  import {
    emptyFollowState,
    followStateFrom,
    lastOrdinal,
    readFollow,
    reduceFollow,
    type AiFollowState,
  } from '../lib/aiFollow'
  import { aiRefusalText, aiStopText } from '../lib/aiRefusal'
  import { fmtTime } from '../lib/format'
  import { LL } from '../i18n/i18n-svelte'
  import { servers } from '../lib/servers.svelte'
  import { untrack } from 'svelte'
  import type {
    AiConversationView,
    AiDetailView,
    AiItemView,
    AiListView,
    AiSettingsView,
  } from '../types'

  interface Props {
    onback: () => void
  }

  const { onback }: Props = $props()

  /// How soon to re-open a follow stream the agent closed. The stream has no
  /// end of its own — it pings every fifteen seconds and the agent holds it —
  /// so a clean end means the connection dropped, and the page is left saying
  /// what it last heard rather than nothing.
  const RECONNECT_MS = 1_000

  /// The settled answer of a tool call, or the envelope this agent wrote for a
  /// call it did not run. Parsed for display only: what a person reads and what
  /// the model was told are the same bytes.
  interface ToolResult {
    tool: string
    ok: boolean
    summary: string
    data: Record<string, unknown>
    cancelled: boolean
    truncated: boolean
    local_failure: boolean
  }

  let conversations = $state<AiConversationView[]>([])
  let selected = $state<string | null>(null)
  let conversation = $state<AiConversationView | null>(null)
  /// Not named `state`, though that is what it holds: svelte2tsx 0.7.61 treats
  /// a variable named exactly `state` as a store when the same file declares
  /// more than one typed `$state<…>()`, appends `let $state = store_get(state)`
  /// beside the declaration, and every typed `$state<…>()` in the file then
  /// fails to typecheck (`$state` resolves to the auto-subscribed value).
  /// Renaming is the whole fix; nothing else about the name matters.
  let followState = $state<AiFollowState>(emptyFollowState())
  let editable = $state(false)
  let settings = $state<AiSettingsView | null>(null)

  let loading = $state(true)
  let opening = $state(false)
  let busy = $state(false)
  let error = $state('')
  let notice = $state('')
  /// The follow stream ended and has not been re-opened yet.
  let reconnecting = $state(false)

  let draft = $state('')
  /// Which output blocks are open, by item ordinal. Outside the markup because
  /// a frame rebuilds the list and a per-item flag would be dropped with it.
  let opened = $state<number[]>([])

  let historyOpen = $state(false)
  let settingsOpen = $state(false)
  let settingsDraft = $state({ base_url: '', model: '', api_key: '', clear_key: false, auto_run_safe_commands: false })
  let renaming = $state(false)
  let renameDraft = $state('')
  let removing = $state<AiConversationView | null>(null)

  let followCtl: AbortController | undefined
  let composer = $state<HTMLTextAreaElement | null>(null)
  let end = $state<HTMLDivElement | null>(null)

  /// The sidebar is the server selector, so a reply that arrives after the user
  /// has switched belongs to neither server.
  function stale(serverId: string | null) {
    return serverId !== servers.currentId
  }

  function failure(e: unknown): string {
    return aiRefusalText(e instanceof Error ? e.message : String(e))
  }

  async function reload(serverId: string | null = servers.currentId) {
    loading = true
    error = ''
    notice = ''
    stopFollowing()
    selected = null
    conversation = null
    followState = emptyFollowState()
    try {
      const [list, read] = await Promise.all([api.getAiConversations(), api.getAiSettings()])
      if (stale(serverId)) return
      conversations = (list as AiListView).conversations
      editable = (list as AiListView).editable
      settings = read
      // The newest conversation is what the tab opens on: a page that always
      // started empty would make the history the only way back to anything.
      const first = conversations[0]
      if (first) void open(first.id)
    } catch (e) {
      if (stale(serverId)) return
      error = failure(e)
    } finally {
      if (!stale(serverId)) loading = false
    }
  }

  /// Opens one conversation: its items, then the stream that follows it.
  async function open(id: string) {
    stopFollowing()
    selected = id
    opening = true
    error = ''
    notice = ''
    const serverId = servers.currentId
    try {
      const res = (await api.getAiConversations(id)) as AiDetailView
      if (stale(serverId) || selected !== id) return
      conversation = res.conversation
      editable = res.editable
      followState = followStateFrom(
        res.items,
        res.live,
        res.conversation.running,
        res.live?.phase ?? 'idle',
        res.live?.error ?? null,
        res.waiting,
      )
      scrollToEnd()
      void follow(id, serverId)
    } catch (e) {
      if (stale(serverId) || selected !== id) return
      error = failure(e)
    } finally {
      if (selected === id) opening = false
    }
  }

  /// Follows a conversation until the page leaves it.
  ///
  /// `after` climbs with every item, so a reconnect asks only for what it has
  /// not drawn. A conversation that is gone stops the loop rather than
  /// retrying: the answer will not change.
  async function follow(id: string, serverId: string | null) {
    const ctl = new AbortController()
    followCtl = ctl
    let after = lastOrdinal(followState)
    for (;;) {
      try {
        const res = await api.followAi(id, after, ctl.signal)
        if (!res.body) throw new Error('no_body')
        reconnecting = false
        await readFollow(
          res.body,
          (frame) => {
            if (ctl.signal.aborted || stale(serverId) || selected !== id) return
            followState = reduceFollow(followState, frame)
            after = lastOrdinal(followState)
            if (frame.type === 'item' || frame.type === 'state') scrollToEnd()
          },
          ctl.signal,
        )
      } catch (e) {
        if (ctl.signal.aborted) return
        if (e instanceof ApiError && e.status === 404) {
          conversations = conversations.filter((held) => held.id !== id)
          if (selected === id) {
            selected = null
            conversation = null
            followState = emptyFollowState()
            error = aiRefusalText('no_such_conversation')
          }
          return
        }
      }
      // Two loops cannot stack: a newer `follow` owns the controller, and this
      // one is the one to stop.
      if (followCtl !== ctl || ctl.signal.aborted || stale(serverId) || selected !== id) return
      reconnecting = true
      await new Promise((resolve) => setTimeout(resolve, RECONNECT_MS))
      if (followCtl !== ctl || ctl.signal.aborted) return
    }
  }

  function stopFollowing() {
    followCtl?.abort()
    followCtl = undefined
    reconnecting = false
  }

  function scrollToEnd() {
    // After the frame has been drawn, or the sentinel is still where the list
    // used to end.
    requestAnimationFrame(() => end?.scrollIntoView({ block: 'end' }))
  }

  $effect(() => {
    const serverId = servers.currentId
    untrack(() => void reload(serverId))
    return () => stopFollowing()
  })

  async function send() {
    const message = draft.trim()
    if (!message || busy) return
    busy = true
    error = ''
    notice = ''
    const serverId = servers.currentId
    try {
      const res = await api.actAi(
        conversation ? { action: 'chat', conversation: conversation.id, message } : { action: 'chat', message },
      )
      if (stale(serverId)) return
      draft = ''
      if (!conversation || res.conversation !== conversation.id) await open(res.conversation)
      else scrollToEnd()
    } catch (e) {
      if (stale(serverId)) return
      error = failure(e)
    } finally {
      busy = false
    }
  }

  /// Runs one approved call. An approval answers one call, which is why the
  /// buttons are per call and the refusal is the one that covers a batch.
  async function approve(item: AiItemView) {
    if (!conversation || !item.call_id || busy) return
    busy = true
    error = ''
    try {
      const res = await api.actAi({
        action: 'approve',
        conversation: conversation.id,
        call_id: item.call_id,
      })
      if (res.result) notice = res.result.ok ? res.result.summary : aiRefusalText('nothing_to_decline')
    } catch (e) {
      error = failure(e)
    } finally {
      busy = false
    }
  }

  async function declineAll() {
    if (!conversation || busy) return
    busy = true
    error = ''
    try {
      await api.actAi({ action: 'decline', conversation: conversation.id })
    } catch (e) {
      error = failure(e)
    } finally {
      busy = false
    }
  }

  async function stopTurn() {
    if (!conversation) return
    busy = true
    error = ''
    try {
      await api.actAi({ action: 'stop', conversation: conversation.id })
    } catch (e) {
      error = failure(e)
    } finally {
      busy = false
    }
  }

  async function rename() {
    const title = renameDraft.trim()
    const target = conversation
    renaming = false
    if (!target || !title || title === target.title) return
    busy = true
    error = ''
    try {
      await api.actAi({ action: 'rename', conversation: target.id, title })
      conversation = { ...target, title }
      conversations = conversations.map((held) => (held.id === target.id ? { ...held, title } : held))
    } catch (e) {
      error = failure(e)
    } finally {
      busy = false
    }
  }

  async function remove(target: AiConversationView) {
    removing = null
    busy = true
    error = ''
    try {
      await api.removeAiConversation(target.id)
      conversations = conversations.filter((held) => held.id !== target.id)
      if (selected === target.id) {
        stopFollowing()
        selected = null
        conversation = null
        followState = emptyFollowState()
      }
    } catch (e) {
      error = failure(e)
    } finally {
      busy = false
    }
  }

  function openSettings() {
    const held = settings
    settingsDraft = {
      base_url: held?.base_url ?? '',
      model: held?.model ?? '',
      api_key: '',
      clear_key: false,
      auto_run_safe_commands: held?.auto_run_safe_commands ?? false,
    }
    settingsOpen = true
  }

  /// Saves the endpoint. The key is write-only: blank keeps whatever the agent
  /// holds, and the checkbox is the only way to say "remove it" — a field that
  /// was never on screen cannot mean that by being left alone.
  async function saveSettings() {
    busy = true
    error = ''
    notice = ''
    try {
      const saved = await api.updateAiSettings({
        base_url: settingsDraft.base_url.trim(),
        model: settingsDraft.model.trim(),
        api_key: settingsDraft.clear_key ? '' : settingsDraft.api_key.trim() || null,
        auto_run_safe_commands: settingsDraft.auto_run_safe_commands,
      })
      settings = saved
      settingsOpen = false
      notice = $LL.save()
    } catch (e) {
      error = failure(e)
    } finally {
      busy = false
    }
  }

  function startNew() {
    stopFollowing()
    selected = null
    conversation = null
    followState = emptyFollowState()
    error = ''
    notice = ''
    composer?.focus()
  }

  function onComposerKey(event: KeyboardEvent) {
    if (event.key === 'Enter' && !event.shiftKey) {
      event.preventDefault()
      void send()
    }
  }

  function toggleOutput(ordinal: number) {
    opened = opened.includes(ordinal)
      ? opened.filter((held) => held !== ordinal)
      : [...opened, ordinal]
  }

  /// The tool call's own JSON, as the model wrote it. Only the two fields a
  /// reviewer needs are read out of it: what the call does is the description,
  /// and what it acts on is the command or the path.
  function callFields(item: AiItemView) {
    let parsed: Record<string, unknown> = {}
    try {
      parsed = JSON.parse(item.arguments ?? '{}') as Record<string, unknown>
    } catch {
      parsed = {}
    }
    const text = (key: string) => (typeof parsed[key] === 'string' ? (parsed[key] as string) : '')
    return {
      description: text('description'),
      command: text('command') || text('path'),
      content: text('content'),
    }
  }

  /// A tool result, or the envelope this agent writes for a call it did not
  /// run. `null` when the content is neither, which is text from a build that
  /// recorded something else.
  function toolResult(item: AiItemView): ToolResult | null {
    let parsed: Record<string, unknown>
    try {
      parsed = JSON.parse(item.content) as Record<string, unknown>
    } catch {
      return null
    }
    if (parsed.server_box_tool_result !== true) return null
    return {
      tool: typeof parsed.tool === 'string' ? parsed.tool : (item.tool ?? ''),
      ok: parsed.ok === true,
      summary: typeof parsed.summary === 'string' ? parsed.summary : '',
      data: (parsed.data ?? {}) as Record<string, unknown>,
      cancelled: parsed.cancelled === true,
      truncated: parsed.truncated === true,
      local_failure: parsed.local_failure === true,
    }
  }

  function declined(item: AiItemView): boolean {
    try {
      const parsed = JSON.parse(item.content) as { server_box_action?: string }
      return parsed.server_box_action === 'declined'
    } catch {
      return false
    }
  }

  /// The body of a result, as the lines worth reading: a command's output, or a
  /// file's contents. Absent for a call that wrote one.
  function resultText(result: ToolResult) {
    const asString = (value: unknown) => (typeof value === 'string' ? value : '')
    return {
      stdout: asString(result.data.stdout),
      stderr: asString(result.data.stderr),
      content: asString(result.data.content),
    }
  }

  /// Whether a result has anything to expand. A `write_file` answers with a
  /// path and a size, and a block that opened onto nothing would be a control
  /// that does not move.
  function resultBody(result: ToolResult): boolean {
    const text = resultText(result)
    return text.stdout.length > 0 || text.stderr.length > 0 || text.content.length > 0
  }

  function riskTone(risk: string | null): 'neutral' | 'success' | 'warning' | 'danger' {
    switch (risk) {
      case 'read_only':
        return 'success'
      case 'caution':
        return 'warning'
      case 'destructive':
        return 'danger'
      default:
        return 'neutral'
    }
  }

  function riskText(risk: string | null): string {
    switch (risk) {
      case 'read_only':
        return $LL.aiRiskReadOnly()
      case 'caution':
        return $LL.aiRiskCaution()
      case 'destructive':
        return $LL.aiRiskDestructive()
      default:
        return $LL.aiRiskUnknown()
    }
  }

  const configured = $derived(settings?.configured === true)
  const running = $derived(followState.running)
  const waiting = $derived(new Set(followState.waiting))
  const tokens = $derived(
    conversation && (conversation.prompt_tokens > 0 || conversation.completion_tokens > 0),
  )
</script>

<!-- One tool call, and one answered call. Snippets rather than branches inside
     the `{#each}`, because `{@const}` is only allowed as the immediate child of
     a block and these two read a parsed field four times each. -->
{#snippet callCard(item: AiItemView)}
  {@const call = callFields(item)}
  <Card class="space-y-2 py-4">
    <div class="flex flex-wrap items-center gap-2">
      <span class="font-mono text-xs text-fg-strong">{item.tool}</span>
      <Badge tone={riskTone(item.risk)}>{riskText(item.risk)}</Badge>
      <span class="flex-1"></span>
      {#if item.call_id && waiting.has(item.call_id) && editable}
        <Button variant="secondary" size="sm" disabled={busy} onclick={() => void approve(item)}>
          <Check class="w-4 h-4" />
          {$LL.aiApprove()}
        </Button>
      {/if}
    </div>
    {#if call.description}
      <p class="text-sm text-fg">{call.description}</p>
    {/if}
    {#if call.command}
      <pre
        class="overflow-x-auto rounded-lg border border-line bg-surface p-3 font-mono text-xs break-all whitespace-pre-wrap text-fg">{call.command}</pre>
    {/if}
    {#if call.content}
      <pre
        class="max-h-64 overflow-auto rounded-lg border border-line bg-surface p-3 font-mono text-xs break-all whitespace-pre-wrap text-muted-fg">{call.content}</pre>
    {/if}
  </Card>
{/snippet}

{#snippet outputCard(item: AiItemView)}
  {@const result = toolResult(item)}
  <Card class="space-y-2 py-4">
    {#if declined(item)}
      <p class="flex items-center gap-1.5 text-xs text-muted-fg">
        <X class="w-3.5 h-3.5 shrink-0" />
        {$LL.aiCallDeclined()}
      </p>
    {:else if result}
      <div class="flex flex-wrap items-center gap-2">
        <span class="font-mono text-xs text-muted-fg">{result.tool}</span>
        {#if typeof result.data.exit_code === 'number'}
          <span class="font-mono text-xs text-muted-fg">
            {$LL.aiExitCode({ code: result.data.exit_code })}
          </span>
        {/if}
        {#if !result.ok}
          <Badge tone="danger">{$LL.aiCallRefused()}</Badge>
        {/if}
        {#if result.cancelled}
          <Badge tone="warning">{$LL.aiCallStopped()}</Badge>
        {/if}
        {#if result.truncated}
          <Badge tone="neutral">{$LL.aiCallTruncated()}</Badge>
        {/if}
      </div>
      {#if result.summary}
        <p class="text-sm text-fg">{result.summary}</p>
      {/if}
      {#if resultBody(result)}
        <button class="text-xs text-accent underline" onclick={() => toggleOutput(item.ordinal)}>
          {opened.includes(item.ordinal) ? $LL.aiOutputHide() : $LL.aiOutputShow()}
        </button>
      {/if}
      {#if opened.includes(item.ordinal)}
        {@const text = resultText(result)}
        {#if text.stdout}
          <pre
            class="max-h-96 overflow-auto rounded-lg border border-line bg-surface p-3 font-mono text-xs break-all whitespace-pre-wrap text-fg">{text.stdout}</pre>
        {/if}
        {#if text.stderr}
          <div class="space-y-1">
            <p class="text-xs font-medium text-danger">stderr</p>
            <pre
              class="max-h-96 overflow-auto rounded-lg border border-line bg-surface p-3 font-mono text-xs break-all whitespace-pre-wrap text-danger">{text.stderr}</pre>
          </div>
        {/if}
        {#if text.content}
          <pre
            class="max-h-96 overflow-auto rounded-lg border border-line bg-surface p-3 font-mono text-xs break-all whitespace-pre-wrap text-fg">{text.content}</pre>
        {/if}
      {/if}
    {:else}
      <p class="text-xs text-muted-fg">{$LL.aiCallRefused()}</p>
    {/if}
  </Card>
{/snippet}

<PageHeader title={$LL.ai()} subtitle={$LL.aiSubtitle()} {onback} containerClass="w-full">
  {#snippet tabs()}
    <FeatureTabs active="ai" />
  {/snippet}

  {#snippet actions()}
    <IconButton label={$LL.aiNewChat()} onclick={startNew}>
      <Plus class="w-4 h-4" />
    </IconButton>
    <IconButton label={$LL.history()} onclick={() => (historyOpen = true)}>
      <History class="w-4 h-4" />
    </IconButton>
    <IconButton label={$LL.aiSettings()} onclick={openSettings}>
      <Settings class="w-4 h-4" />
    </IconButton>
  {/snippet}
</PageHeader>

<main class="max-w-3xl mx-auto px-4 sm:px-6 py-8 space-y-4">
  {#if error}
    <Card class="border-danger/40 bg-danger/5">
      <p class="text-sm text-danger">{error}</p>
    </Card>
  {/if}

  {#if notice}
    <Card>
      <p class="text-sm text-muted-fg">{notice}</p>
    </Card>
  {/if}

  {#if loading && conversations.length === 0 && !conversation}
    <Card><Spinner class="w-5 h-5" /></Card>
  {:else}
    {#if !editable}
      <Card>
        <p class="text-sm text-muted-fg">{$LL.aiNoGrant()}</p>
      </Card>
    {/if}

    {#if !configured}
      <Card>
        <p class="text-sm text-muted-fg">{$LL.aiNotConfigured()}</p>
        {#if editable}
          <div class="mt-3">
            <Button variant="secondary" onclick={openSettings}>{$LL.aiSettings()}</Button>
          </div>
        {/if}
      </Card>
    {/if}

    {#if conversation}
      <Card class="space-y-2 py-4">
        <div class="flex flex-wrap items-center gap-2">
          <span class="text-sm font-medium text-fg-strong">{conversation.title}</span>
          <span class="flex-1"></span>
          {#if editable}
            <IconButton
              label={$LL.aiRename()}
              onclick={() => {
                renameDraft = conversation?.title ?? ''
                renaming = true
              }}
            >
              <Pencil class="w-4 h-4" />
            </IconButton>
            <IconButton label={$LL.aiRemove()} onclick={() => (removing = conversation)}>
              <Trash class="w-4 h-4" />
            </IconButton>
          {/if}
        </div>
        <p class="text-xs text-muted-fg">
          {conversation.model || '—'}
          {#if tokens}
            · {$LL.aiTokens({
              prompt: conversation.prompt_tokens,
              completion: conversation.completion_tokens,
            })}
          {/if}
          · {fmtTime(conversation.updated_at, { withDate: true })}
        </p>
      </Card>
    {/if}

    {#if opening}
      <Card><Spinner class="w-5 h-5" /></Card>
    {:else if !conversation}
      <Card>
        <p class="text-sm text-muted-fg">{$LL.aiEmpty()}</p>
      </Card>
    {/if}

    {#each followState.items as item (item.ordinal)}
      {#if item.kind === 'message' && item.role === 'user'}
        <div class="flex justify-end">
          <div
            class="max-w-[85%] rounded-2xl rounded-br-sm bg-soft px-4 py-2.5 text-sm break-words whitespace-pre-wrap text-fg"
          >
            {item.content}
          </div>
        </div>
      {:else if item.kind === 'message'}
        <div class="space-y-1.5">
          {#if item.reasoning}
            <div class="rounded-lg border border-line bg-soft/40 px-3 py-2">
              <p class="text-xs font-medium text-muted-fg">{$LL.aiThinking()}</p>
              <p class="mt-1 text-xs break-words whitespace-pre-wrap text-muted-fg">
                {item.reasoning}
              </p>
            </div>
          {/if}
          <div class="text-sm text-fg">
            <Markdown text={item.content} />
          </div>
        </div>
      {:else if item.kind === 'function_call'}
        {@render callCard(item)}
      {:else if item.kind === 'function_output'}
        {@render outputCard(item)}
      {:else if item.kind === 'notice'}
        <p class="text-center text-xs text-muted-fg">{aiStopText(item.content)}</p>
      {/if}
    {/each}

    {#if followState.live}
      <div class="space-y-1.5">
        {#if followState.live.reasoning}
          <div class="rounded-lg border border-line bg-soft/40 px-3 py-2">
            <p class="text-xs font-medium text-muted-fg">{$LL.aiThinking()}</p>
            <p class="mt-1 text-xs break-words whitespace-pre-wrap text-muted-fg">
              {followState.live.reasoning}
            </p>
          </div>
        {/if}
        {#if followState.live.content}
          <div class="text-sm text-fg">
            <Markdown text={followState.live.content} />
          </div>
        {/if}
      </div>
    {/if}

    {#if followState.error}
      <p class="flex items-center gap-1.5 text-xs text-danger">
        <ShieldAlert class="w-3.5 h-3.5 shrink-0" />
        {aiStopText(followState.error)}
      </p>
    {:else if running}
      <p class="flex items-center gap-1.5 text-xs text-muted-fg">
        <Spinner size="sm" />
        {followState.phase === 'executing' ? $LL.aiOutput() : $LL.aiThinking()}
      </p>
    {/if}

    {#if reconnecting}
      <p class="text-xs text-muted-fg">{$LL.aiReconnecting()}</p>
    {/if}

    {#if followState.waiting.length > 0 && editable}
      <Card class="space-y-3 border-warning/40 bg-warning/5">
        <div class="flex flex-wrap items-center gap-2">
          <Badge tone="warning">{$LL.aiAwaiting()}</Badge>
          <span class="text-xs text-muted-fg">{$LL.aiAwaitingHint()}</span>
          <span class="flex-1"></span>
          <Button variant="secondary" size="sm" disabled={busy} onclick={() => void declineAll()}>
            {$LL.aiDeclineAll()}
          </Button>
        </div>
      </Card>
    {/if}

    <!-- The composer. Nothing runs without a message, so it is drawn even when
         a call is parked: approving is what moves that turn along. -->
    <Card class="space-y-3">
      <textarea
        bind:this={composer}
        bind:value={draft}
        class="w-full resize-y rounded-lg border border-line bg-surface px-3 py-2 text-sm text-fg placeholder:text-faint-fg focus:border-transparent focus:ring-2 focus:ring-ring focus:outline-hidden disabled:opacity-50"
        rows="3"
        disabled={!editable || busy}
        placeholder={$LL.aiPlaceholder()}
        onkeydown={onComposerKey}
      ></textarea>
      <div class="flex flex-wrap items-center gap-2">
        <span class="flex-1"></span>
        {#if running}
          <Button variant="secondary" disabled={busy} onclick={() => void stopTurn()}>
            <Square class="w-4 h-4" />
            {$LL.aiStop()}
          </Button>
        {/if}
        <Button disabled={!editable || busy || draft.trim().length === 0} onclick={() => void send()}>
          <Send class="w-4 h-4" />
          {$LL.aiSend()}
        </Button>
      </div>
    </Card>
    <div bind:this={end}></div>
  {/if}
</main>

{#if historyOpen}
  <Modal open title={$LL.history()} onclose={() => (historyOpen = false)} class="max-w-xl">
    <div class="space-y-3">
      {#if conversations.length === 0}
        <p class="text-sm text-muted-fg">{$LL.aiEmpty()}</p>
      {:else}
        <div class="max-h-96 divide-y divide-line overflow-auto">
          {#each conversations as held (held.id)}
            <div class="flex flex-wrap items-center gap-2 py-3">
              <button
                class="min-w-0 flex-1 text-left"
                onclick={() => {
                  historyOpen = false
                  void open(held.id)
                }}
              >
                <span class="block truncate text-sm text-fg-strong">{held.title}</span>
                <span class="block text-xs text-muted-fg">
                  {held.model || '—'} · {fmtTime(held.updated_at, { withDate: true })}
                </span>
              </button>
              {#if held.awaiting_review}
                <Badge tone="warning">{$LL.aiAwaiting()}</Badge>
              {:else if held.running}
                <Badge tone="neutral">{$LL.aiThinking()}</Badge>
              {/if}
              {#if editable}
                <IconButton label={$LL.aiRemove()} onclick={() => (removing = held)}>
                  <Trash class="w-4 h-4" />
                </IconButton>
              {/if}
            </div>
          {/each}
        </div>
      {/if}
      <div class="flex justify-end">
        <Button variant="secondary" onclick={() => (historyOpen = false)}>{$LL.close()}</Button>
      </div>
    </div>
  </Modal>
{/if}

{#if settingsOpen}
  <Modal open title={$LL.aiSettings()} onclose={() => (settingsOpen = false)} class="max-w-lg">
    <div class="space-y-4">
      <div class="space-y-1">
        <p class="text-xs text-muted-fg">{$LL.aiEndpoint()}</p>
        <Input bind:value={settingsDraft.base_url} placeholder="https://api.openai.com/v1" />
        <p class="text-xs text-muted-fg">{$LL.aiEndpointHint()}</p>
      </div>

      <div class="space-y-1">
        <p class="text-xs text-muted-fg">{$LL.aiModel()}</p>
        <Input bind:value={settingsDraft.model} placeholder="gpt-4o-mini" />
      </div>

      <div class="space-y-1">
        <p class="text-xs text-muted-fg">{$LL.aiApiKey()}</p>
        <Input
          bind:value={settingsDraft.api_key}
          type="password"
          disabled={settingsDraft.clear_key}
          placeholder={settings?.api_key_set ? '••••••••' : ''}
        />
        <p class="text-xs text-muted-fg">
          {settings?.api_key_set ? $LL.aiApiKeySet() : $LL.aiApiKeyUnset()}
        </p>
        {#if settings?.api_key_set}
          <label class="flex items-center gap-2 text-xs text-fg">
            <input type="checkbox" bind:checked={settingsDraft.clear_key} />
            {$LL.aiApiKeyClear()}
          </label>
        {/if}
      </div>

      <label class="flex items-start gap-2 text-sm text-fg">
        <input type="checkbox" class="mt-0.5" bind:checked={settingsDraft.auto_run_safe_commands} />
        <span>
          {$LL.aiAutoRun()}
          <span class="block text-xs text-muted-fg">{$LL.aiAutoRunHint()}</span>
        </span>
      </label>

      <div class="flex flex-wrap justify-end gap-2">
        <Button variant="secondary" onclick={() => (settingsOpen = false)}>{$LL.cancel()}</Button>
        <Button disabled={busy} onclick={() => void saveSettings()}>{$LL.save()}</Button>
      </div>
    </div>
  </Modal>
{/if}

{#if renaming}
  <Modal open title={$LL.aiRename()} onclose={() => (renaming = false)}>
    <div class="space-y-4">
      <div class="space-y-1">
        <p class="text-xs text-muted-fg">{$LL.aiRenameTitle()}</p>
        <Input bind:value={renameDraft} />
      </div>
      <div class="flex flex-wrap justify-end gap-2">
        <Button variant="secondary" onclick={() => (renaming = false)}>{$LL.cancel()}</Button>
        <Button disabled={busy} onclick={() => void rename()}>{$LL.save()}</Button>
      </div>
    </div>
  </Modal>
{/if}

{#if removing}
  <Modal open title={$LL.aiRemove()} onclose={() => (removing = null)}>
    <div class="space-y-4">
      <p class="text-sm text-fg">{$LL.aiRemoveConfirm()}</p>
      <div class="flex flex-wrap justify-end gap-2">
        <Button variant="secondary" onclick={() => (removing = null)}>{$LL.cancel()}</Button>
        <Button
          variant="danger"
          disabled={busy}
          onclick={() => {
            const target = removing
            if (target) void remove(target)
          }}
        >
          {$LL.aiRemove()}
        </Button>
      </div>
    </div>
  </Modal>
{/if}
