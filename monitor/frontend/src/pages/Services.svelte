<script lang="ts">
  import { Badge, Button, Card, IconButton, Input, Modal, Spinner, type BadgeTone } from '@serverbox/webui'
  import {
    Play,
    RefreshCw,
    RotateCw,
    Search,
    Square,
    ToggleLeft,
    ToggleRight,
    type LucideIcon,
  } from '@lucide/svelte'
  import FeatureTabs from '../components/FeatureTabs.svelte'
  import PageHeader from '../components/PageHeader.svelte'
  import ServiceDetail from '../components/ServiceDetail.svelte'
  import { api } from '../lib/api'
  import { fmtBytes } from '../lib/format'
  import { LL } from '../i18n/i18n-svelte'
  import { servers } from '../lib/servers.svelte'
  import { untrack } from 'svelte'
  import type { ServiceAction, ServiceState, ServiceUnit, ServiceView } from '../types'

  interface Props {
    onback: () => void
  }

  const { onback }: Props = $props()

  let view = $state<ServiceView | null>(null)
  let loading = $state(true)
  let error = $state('')
  let busy = $state(false)
  /// Set after an action lands and cleared by the next one. Worth saying
  /// because the row it names is redrawn by the refresh that follows.
  let notice = $state('')
  /// What went wrong with the action, the machine's own words where it said
  /// anything — they are the only thing that distinguishes one failure from
  /// another.
  let actionError = $state('')
  /// The filter is the page's own: it is not a question for the machine, and
  /// leaving the page undoes it.
  let query = $state('')
  /// The unit whose detail is open, and the action waiting for the account
  /// that owns it.
  let opened = $state<ServiceUnit | undefined>(undefined)
  let pending = $state<ServiceAction | undefined>(undefined)
  let password = $state('')

  /// The page follows the sidebar, so a reply that arrives after the user has
  /// switched servers belongs to neither.
  function stale(serverId: string | null) {
    return serverId !== servers.currentId
  }

  async function load(serverId = servers.currentId) {
    loading = true
    error = ''
    try {
      const next = await api.getServices()
      if (stale(serverId)) return
      view = next
      // The open unit is replaced by the fresh one of the same key, so the
      // dialog shows the state the action just produced rather than the one the
      // row was opened with — and closes by itself where the unit is gone.
      if (opened) {
        opened = next.units.find((unit) => unit.key === opened?.key)
        if (!opened) pending = undefined
      }
    } catch (e) {
      if (stale(serverId)) return
      error = e instanceof Error ? e.message : String(e)
    } finally {
      if (!stale(serverId)) loading = false
    }
  }

  $effect(() => {
    // Only the machine on screen re-runs this.
    const serverId = servers.currentId
    untrack(() => void load(serverId))
  })

  async function act(action: ServiceAction, asRoot = false) {
    const unit = opened
    if (!unit) return
    busy = true
    notice = ''
    actionError = ''
    try {
      const result = await api.actService({
        key: unit.key,
        action,
        ...(asRoot && password ? { password } : {}),
      })
      if (result.sudo_rejected) {
        // The action needs an account the agent does not have. There is one way
        // forward and it is that account, so the dialog asks for what that
        // needs rather than reporting a refusal — unless this *was* the second
        // attempt, which has nowhere left to go.
        if (asRoot) actionError = $LL.powerRejected()
        else pending = action
        return
      }
      if (!result.succeeded) {
        // Where "Job for x.service failed" and the reason for it are. Nothing
        // is invented when the manager printed none.
        actionError = result.stderr.trim() || result.stdout.trim() || $LL.serviceActionFailed()
        return
      }
      notice = $LL.serviceActionDone({ action: actionLabel(action), name: unit.full_name })
      pending = undefined
      password = ''
      await load()
    } catch (e) {
      actionError = e instanceof Error ? e.message : String(e)
    } finally {
      busy = false
    }
  }

  function run(action: ServiceAction) {
    pending = undefined
    password = ''
    actionError = ''
    void act(action)
  }

  function open(unit: ServiceUnit) {
    opened = unit
    pending = undefined
    password = ''
    actionError = ''
  }

  const editable = $derived(view?.editable === true)
  const units = $derived(view?.units ?? [])
  const manager = $derived(view?.manager ?? null)
  const userScope = $derived(view?.supports_user_scope === true)

  const visible = $derived.by(() => {
    const needle = query.trim().toLowerCase()
    if (!needle) return units
    return units.filter(
      (unit) =>
        unit.name.toLowerCase().includes(needle) ||
        (unit.description ?? '').toLowerCase().includes(needle),
    )
  })

  /// How each state is drawn. A `Record` over every state rather than a chain,
  /// so a state the agent grows without a label here is a type error rather
  /// than a row that says nothing about itself.
  const STATES: Record<ServiceState, { label: () => string; tone: BadgeTone }> = {
    running: { label: () => $LL.serviceStateRunning(), tone: 'success' },
    stopped: { label: () => $LL.serviceStateStopped(), tone: 'neutral' },
    failed: { label: () => $LL.serviceStateFailed(), tone: 'danger' },
    starting: { label: () => $LL.serviceStateStarting(), tone: 'warning' },
    stopping: { label: () => $LL.serviceStateStopping(), tone: 'warning' },
    // Drawn as its own word rather than as a state: the manager did not say,
    // which is not "stopped".
    unknown: { label: () => $LL.serviceStateUnknown(), tone: 'neutral' },
  }

  /// How each action is drawn, in the agent's own order. The set a unit
  /// carries is the agent's; this is only the label and the icon. A `Record`
  /// over every action for the same reason as `STATES`.
  const ACTIONS: Record<ServiceAction, { label: () => string; icon: LucideIcon }> = {
    start: { label: () => $LL.serviceActionStart(), icon: Play },
    stop: { label: () => $LL.serviceActionStop(), icon: Square },
    restart: { label: () => $LL.serviceActionRestart(), icon: RotateCw },
    enable: { label: () => $LL.serviceActionEnable(), icon: ToggleRight },
    disable: { label: () => $LL.serviceActionDisable(), icon: ToggleLeft },
  }

  function actionLabel(action: ServiceAction): string {
    return ACTIONS[action].label()
  }

  function subtitle(): string {
    if (!view) return ''
    return $LL.serviceSubtitle({ manager: manager?.description ?? '', count: units.length })
  }

  function reasonText(reason: ServiceView): string {
    switch (reason.reason_kind) {
      case 'unsupported_manager':
        return $LL.serviceUnsupportedManager({
          manager: reason.manager?.detected_name || reason.reason || '?',
        })
      case 'unsupported_platform':
        return $LL.serviceUnsupportedPlatform()
      case 'no_such_unit':
        return $LL.serviceNoSuchUnit()
      case 'no_log':
        return $LL.serviceNoLog()
      default:
        // What the machine said, verbatim: it is the only thing that
        // distinguishes one failure from another.
        return reason.reason ?? $LL.serviceUnreadable()
    }
  }

  function noticeText(notice: ServiceView): string {
    const text =
      notice.notice === 'user_scope_unavailable'
        ? $LL.serviceUserScopeUnavailable()
        : $LL.serviceDetailsUnavailable()
    return notice.detail ? `${text} ${notice.detail}` : text
  }

  /// A timestamp the machine wrote, as an instant: the commands force `TZ=UTC`
  /// and the agent reads the offset off the value itself, so this is the
  /// viewer's zone applied to the same moment rather than the machine's zone
  /// guessed at.
  ///
  /// The one thing it cannot fix is the machine's own clock: a reader comparing
  /// this against `sampled_at_millis` in the listing can see how far off it is.
  function timeText(millis: number | null): string {
    if (millis === null) return '—'
    return new Date(millis).toLocaleTimeString([], { hour: '2-digit', minute: '2-digit' })
  }
</script>

<PageHeader title={$LL.services()} subtitle={subtitle()} containerClass="max-w-5xl mx-auto px-4 sm:px-6 lg:px-8 w-full" {onback}>
  {#snippet tabs()}
    <FeatureTabs active="services" />
  {/snippet}

  {#snippet actions()}
    <IconButton label={$LL.refresh()} onclick={() => void load()} disabled={loading}>
      <RefreshCw class="w-4 h-4" />
    </IconButton>
  {/snippet}
</PageHeader>

<main class="max-w-5xl mx-auto px-4 sm:px-6 lg:px-8 py-8 space-y-4">
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

  {#if loading && !view}
    <Card><Spinner class="w-5 h-5" /></Card>
  {:else if view && !view.available}
    <Card class="space-y-2">
      <p class="text-sm text-muted-fg">{reasonText(view)}</p>
      {#if view.reason && view.reason_kind !== 'unsupported_manager'}
        <pre class="text-xs font-mono text-faint-fg whitespace-pre-wrap break-all">{view.reason}</pre>
      {/if}
    </Card>
  {:else if view}
    {#if !editable}
      <Card>
        <p class="text-sm text-muted-fg">{$LL.serviceReadOnly()}</p>
      </Card>
    {/if}

    {#if view.notice}
      <Card>
        <p class="text-sm text-muted-fg">{noticeText(view)}</p>
      </Card>
    {/if}

    <Card>
      <div class="relative">
        <Search class="pointer-events-none absolute left-2.5 top-1/2 h-4 w-4 -translate-y-1/2 text-faint-fg" />
        <Input class="pl-8" bind:value={query} placeholder={$LL.serviceSearchHint()} />
      </div>
    </Card>

    {#if visible.length === 0}
      <Card>
        <p class="text-sm text-muted-fg">
          {query ? $LL.serviceNoMatch() : $LL.serviceEmpty()}
        </p>
      </Card>
    {:else}
      <Card class="divide-y divide-border p-0">
        {#each visible as unit (unit.key)}
          {@const state = STATES[unit.state]}
          <button
            class="flex w-full items-center gap-3 px-4 py-3 text-left transition-colors hover:bg-soft/40"
            onclick={() => open(unit)}
          >
            <Badge tone={state.tone}>{state.label()}</Badge>
            <span class="min-w-0 flex-1">
              <span class="flex items-baseline gap-2">
                <span class="truncate text-sm font-medium text-fg-strong">{unit.full_name}</span>
                <!-- The manager's own word for startup registration, drawn
                     verbatim: `static` and `masked` are things `enabled` cannot
                     say, and there is nothing here to translate. -->
                {#if unit.startup}
                  <span class="shrink-0 text-xs text-faint-fg">{unit.startup}</span>
                {/if}
              </span>
              {#if unit.description}
                <span class="block truncate text-xs text-muted-fg">{unit.description}</span>
              {/if}
            </span>
            {#if userScope && unit.scope === 'user'}
              <span class="shrink-0 text-xs text-faint-fg">{$LL.serviceScopeUser()}</span>
            {/if}
          </button>
        {/each}
      </Card>
    {/if}

    {#if busy}
      <div class="flex items-center gap-2 text-xs text-muted-fg">
        <Spinner size="sm" />
      </div>
    {/if}
  {/if}
</main>

<!-- One unit: what it is, what may be done to it, and the three things the
     machine can be asked about it. The actions live here rather than on the row
     so the list stays one line per unit and an action is always taken with the
     unit's state on screen. -->
{#if opened}
  {@const state = STATES[opened.state]}
  <Modal open title={opened.full_name} onclose={() => (opened = undefined)}>
    <div class="space-y-4">
      <div class="space-y-2">
        <div class="flex flex-wrap items-center gap-2">
          <Badge tone={state.tone}>{state.label()}</Badge>
          <span class="text-xs text-muted-fg">
            {opened.scope === 'user' ? $LL.serviceScopeUser() : $LL.serviceScopeSystem()}
          </span>
          {#if opened.startup}
            <span class="text-xs text-faint-fg">{opened.startup}</span>
          {/if}
        </div>
        {#if opened.description}
          <p class="text-sm text-fg">{opened.description}</p>
        {/if}
        <!-- The manager's finer state and why the last run ended, verbatim:
             `exit-code 3` and `signal` are the manager's vocabulary. -->
        {#if opened.sub_state || opened.result}
          <p class="text-xs font-mono text-muted-fg">
            {opened.sub_state ?? ''}{#if opened.sub_state && opened.result} · {/if}{opened.result ??
              ''}{#if opened.exit_status !== null} {opened.exit_status}{/if}
          </p>
        {/if}
        <dl class="grid grid-cols-2 gap-x-4 gap-y-1 text-xs sm:grid-cols-3">
          {#if opened.memory_bytes !== null}
            <div>
              <dt class="text-faint-fg">{$LL.serviceMemory()}</dt>
              <dd class="text-muted-fg">{fmtBytes(opened.memory_bytes)}</dd>
            </div>
          {/if}
          {#if opened.since_millis !== null}
            <div>
              <dt class="text-faint-fg">{$LL.serviceSince()}</dt>
              <dd class="text-muted-fg">{timeText(opened.since_millis)}</dd>
            </div>
          {/if}
          {#if opened.next_elapse_millis !== null}
            <div>
              <dt class="text-faint-fg">{$LL.serviceNextRun()}</dt>
              <dd class="text-muted-fg">{timeText(opened.next_elapse_millis)}</dd>
            </div>
          {/if}
        </dl>
      </div>

      {#if actionError}
        <pre class="text-sm text-danger whitespace-pre-wrap break-all">{actionError}</pre>
      {/if}

      {#if editable && opened.actions.length > 0}
        {#if pending !== undefined}
          <!-- The action needs an account the agent does not have. The password
               is the second attempt's, sent as its own field so it never lands
               in a command line. -->
          <div class="space-y-1">
            <label class="text-sm text-muted-fg" for="service-password">{$LL.powerPassword()}</label>
            <Input id="service-password" type="password" bind:value={password} />
            <p class="text-xs text-muted-fg">{$LL.powerPasswordHint()}</p>
            <div class="flex justify-end gap-2 pt-2">
              <Button variant="secondary" onclick={() => (pending = undefined)}>{$LL.cancel()}</Button>
              <Button disabled={busy} onclick={() => void act(pending!, true)}>
                {$LL.serviceRetryAsRoot()}
              </Button>
            </div>
          </div>
        {:else}
          <div class="flex flex-wrap gap-2">
            {#each opened.actions as action (action)}
              {@const { label, icon: Icon } = ACTIONS[action]}
              <Button variant="secondary" disabled={busy} onclick={() => run(action)}>
                <Icon class="w-4 h-4" />
                {label()}
              </Button>
            {/each}
          </div>
        {/if}
      {/if}

      <!-- The three parts that are about one unit. Fetched when one is opened
           rather than with the listing: a log and a definition are the largest
           things here, and most rows are never opened. -->
      <ServiceDetail unitKey={opened.key} />
    </div>
  </Modal>
{/if}
