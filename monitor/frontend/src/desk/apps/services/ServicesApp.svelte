<script lang="ts">
  import Spinner from '../../lk/Spinner.svelte'
  import { AppToolbar, SplitView } from '../../sys'
  import { Badge, Button, Card, Dialog, Icon, IconButton, Input, SidebarItem, SidebarSection, type BadgeTone } from '../../lk'
  import ServiceDetail from './ServiceDetail.svelte'
  import { api } from '../../../lib/api'
  import { fmtBytes } from '../../../lib/format'
  import { LL } from '../../../i18n/i18n-svelte'
  import { servers } from '../../../lib/servers.svelte'
  import { untrack } from 'svelte'
  import type { ServiceAction, ServiceState, ServiceUnit, ServiceView } from '../../../types'

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

  /// A reply that arrives after the desk has switched servers belongs to
  /// neither.
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

  const units = $derived(view?.units ?? [])
  const manager = $derived(view?.manager ?? null)
  const userScope = $derived(view?.supports_user_scope === true)

  /// Which units the list shows: all of them, or one of the states the manager
  /// reported. A state it does not use is an empty group rather than a missing
  /// row, since the set is the manager's.
  let filter = $state<'all' | ServiceState>('all')

  /// The sidebar's groups, with the manager's own states behind them.
  const GROUPS: { id: 'all' | ServiceState; label: () => string; icon: string }[] = [
    { id: 'all', label: () => $LL.servicesFilterAll(), icon: 'list' },
    { id: 'running', label: () => $LL.serviceStateRunning(), icon: 'play_arrow' },
    { id: 'failed', label: () => $LL.serviceStateFailed(), icon: 'error' },
    { id: 'stopped', label: () => $LL.serviceStateStopped(), icon: 'stop' },
  ]

  function countIn(id: 'all' | ServiceState): number {
    return id === 'all' ? units.length : units.filter((unit) => unit.state === id).length
  }

  const visible = $derived.by(() => {
    const needle = query.trim().toLowerCase()
    return units.filter((unit) => {
      if (filter !== 'all' && unit.state !== filter) return false
      if (!needle) return true
      return (
        unit.name.toLowerCase().includes(needle) ||
        (unit.description ?? '').toLowerCase().includes(needle)
      )
    })
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
  const ACTIONS: Record<ServiceAction, { label: () => string; icon: string }> = {
    start: { label: () => $LL.serviceActionStart(), icon: 'play_arrow' },
    stop: { label: () => $LL.serviceActionStop(), icon: 'stop' },
    restart: { label: () => $LL.serviceActionRestart(), icon: 'restart_alt' },
    enable: { label: () => $LL.serviceActionEnable(), icon: 'toggle_on' },
    disable: { label: () => $LL.serviceActionDisable(), icon: 'toggle_off' },
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

<AppToolbar subtitle={subtitle()}>
  {#snippet actions()}
    <IconButton icon="refresh" label={$LL.refresh()} onclick={() => void load()} disabled={loading} />
  {/snippet}
</AppToolbar>

<SplitView width={12}>
  {#snippet sidebar()}
    <SidebarSection>
      {#each GROUPS as group (group.id)}
        <SidebarItem
          label={group.label()}
          icon={group.icon}
          active={filter === group.id}
          trailing={countIn(group.id)}
          onclick={() => (filter = group.id)}
        />
      {/each}
    </SidebarSection>
  {/snippet}

  <div class="space-y-[9px] px-[17px] pb-[17px] pt-[4px]">
    {#if error}<Card><p class="text-[13px] text-(--color-danger)">{error}</p></Card>{/if}
    {#if notice}<Card><p class="text-[13px] text-(--text-secondary)">{notice}</p></Card>{/if}

    {#if loading && !view}
      <Card class="grid place-items-center" padding="21px"><Spinner class="h-5 w-5" /></Card>
    {:else if view && !view.available}
      <Card>
        <p class="text-[13px] text-(--text-secondary)">{reasonText(view)}</p>
        {#if view.reason && view.reason_kind !== 'unsupported_manager'}
          <pre class="lk-mono mt-[9px] whitespace-pre-wrap break-all text-[12px] text-(--text-tertiary)">{view.reason}</pre>
        {/if}
      </Card>
    {:else if view}
      {#if view.notice}<Card><p class="text-[13px] text-(--text-secondary)">{noticeText(view)}</p></Card>{/if}

      <Input bind:value={query} icon="search" placeholder={$LL.serviceSearchHint()} />

      {#if visible.length === 0}
        <div class="flex flex-col items-center gap-[9px] py-[34px] text-(--text-tertiary)">
          <Icon name="dns" size={48} weight={300} />
          <span class="text-[13px]">{query || filter !== 'all' ? $LL.serviceNoMatch() : $LL.servicesEmptyState()}</span>
          {#if !query && filter === 'all'}<p class="max-w-md text-center text-[12px]">{$LL.serviceEmpty()}</p>{/if}
        </div>
      {:else}
        <!-- One unit per card: manager name, startup registration and state. -->
        <ul class="space-y-[7px]">
          {#each visible as unit (unit.key)}
            {@const state = STATES[unit.state]}
            <li>
              <Card padding="11px 13px" onclick={() => open(unit)}>
                <div class="flex min-w-0 items-center gap-[13px]">
                  <span class="flex h-[34px] w-[34px] shrink-0 items-center justify-center rounded-[9px] bg-(--surface-raised) text-(--color-accent-text)">
                    <Icon name="dns" size={18} />
                  </span>
                  <div class="min-w-0 flex-1">
                    <div class="flex min-w-0 items-baseline gap-[7px]">
                      <span class="truncate text-[13px] font-semibold">{unit.full_name}</span>
                      <!-- The manager's own word for startup registration is shown
                           verbatim: `static` and `masked` differ from `enabled`. -->
                      {#if unit.startup}<span class="shrink-0 text-[12px] text-(--text-tertiary)">{unit.startup}</span>{/if}
                    </div>
                    {#if unit.description}<p class="truncate text-[12px] text-(--text-tertiary)">{unit.description}</p>{/if}
                  </div>
                  {#if userScope && unit.scope === 'user'}<span class="text-[12px] text-(--text-tertiary)">{$LL.serviceScopeUser()}</span>{/if}
                  <Badge tone={state.tone} dot>{state.label()}</Badge>
                </div>
              </Card>
            </li>
          {/each}
        </ul>
      {/if}

      {#if busy}<div class="flex items-center gap-[7px] px-[3px] text-[12px] text-(--text-tertiary)"><Spinner size="sm" /></div>{/if}
    {/if}
  </div>
</SplitView>

<!-- One unit: what it is, what may be done to it, and the three things the
     machine can be asked about it. The actions live here rather than on the row
     so an action is always taken with the unit's state on screen. -->
{#if opened}
  {@const unit = opened}
  {@const state = STATES[unit.state]}
  <Dialog open wide title={unit.full_name} onclose={() => (opened = undefined)}>
    {#snippet actions()}
      {#if unit.actions.length > 0}
        {#if pending !== undefined}
          <!-- Without a password the retry is the `sudo -n` the agent
               already tried. -->
          <Button variant="primary" disabled={busy || !password} onclick={() => void act(pending!, true)}>{$LL.serviceRetryAsRoot()}</Button>
        {:else}
          {#each unit.actions as action (action)}
            {@const { label, icon } = ACTIONS[action]}
            <Button variant="secondary" icon={icon} disabled={busy} onclick={() => run(action)}>{label()}</Button>
          {/each}
        {/if}
      {/if}
      <Button variant="secondary" onclick={() => (opened = undefined)}>{$LL.close()}</Button>
    {/snippet}
    <div class="flex flex-wrap items-center gap-[9px]">
      <Badge tone={state.tone} dot>{state.label()}</Badge>
      <span class="text-[12px] text-(--text-secondary)">{unit.scope === 'user' ? $LL.serviceScopeUser() : $LL.serviceScopeSystem()}</span>
      {#if unit.startup}<span class="text-[12px] text-(--text-tertiary)">{unit.startup}</span>{/if}
    </div>
    {#if unit.description}<p class="mt-[7px] text-[13px]">{unit.description}</p>{/if}
    <!-- The manager's finer state and why the last run ended, verbatim:
         `exit-code 3` and `signal` are the manager's vocabulary. -->
    {#if unit.sub_state || unit.result}
      <p class="lk-mono mt-[7px] text-[12px] text-(--text-secondary)">
        {unit.sub_state ?? ''}{#if unit.sub_state && unit.result} · {/if}{unit.result ?? ''}{#if unit.exit_status !== null} {unit.exit_status}{/if}
      </p>
    {/if}
    <dl class="mt-[13px] grid grid-cols-2 gap-x-[13px] @2xl:grid-cols-3">
      {#if unit.memory_bytes !== null}<div class="border-t border-(--border-hairline) py-[7px]"><dt class="text-[12px] text-(--text-secondary)">{$LL.serviceMemory()}</dt><dd class="lk-num text-right text-[13px]">{fmtBytes(unit.memory_bytes)}</dd></div>{/if}
      {#if unit.since_millis !== null}<div class="border-t border-(--border-hairline) py-[7px]"><dt class="text-[12px] text-(--text-secondary)">{$LL.serviceSince()}</dt><dd class="lk-num text-right text-[13px]">{timeText(unit.since_millis)}</dd></div>{/if}
      {#if unit.next_elapse_millis !== null}<div class="border-t border-(--border-hairline) py-[7px]"><dt class="text-[12px] text-(--text-secondary)">{$LL.serviceNextRun()}</dt><dd class="lk-num text-right text-[13px]">{timeText(unit.next_elapse_millis)}</dd></div>{/if}
    </dl>

    {#if actionError}<pre class="mt-[9px] whitespace-pre-wrap break-all text-[13px] text-(--color-danger)">{actionError}</pre>{/if}
    {#if pending !== undefined}
      <!-- The action needs an account the agent does not have. The password
           is sent as its own field so it never lands in a command line. -->
      <div class="mt-[13px]">
        <Input id="service-password" label={$LL.powerPassword()} type="password" bind:value={password} />
        <p class="mt-[5px] text-[12px] text-(--text-secondary)">{$LL.powerPasswordHint()}</p>
      </div>
    {/if}

    <!-- The three parts about one unit, fetched when it is opened. -->
    <div class="mt-[13px]"><ServiceDetail unitKey={unit.key} /></div>
  </Dialog>
{/if}
