<script lang="ts">
  import { AppToolbar, SplitView, systemPrefs, WindowFooter } from '../../sys'
  import {
    Button,
    Card,
    DataTable,
    Dialog,
    Icon,
    IconButton,
    Input,
    SearchField,
    SidebarItem,
    SidebarSection,
    Spinner,
    StatusBar,
    type Column,
  } from '../../lk'
  import ServiceDetail from './ServiceDetail.svelte'
  import { api } from '../../../lib/api'
  import { fmtBytes, fmtDate } from '../../../lib/format'
  import { LL } from '../../../i18n/i18n-svelte'
  import { servers } from '../../../lib/servers.svelte'
  import { untrack } from 'svelte'
  import type { ServiceAction, ServiceState, ServiceUnit, ServiceUnitType, ServiceView } from '../../../types'

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
  /// The filter is the window's own: it is not a question for the machine.
  let query = $state('')
  /// The selected unit's key; its detail sits over the status bar.
  let selected = $state<string | null>(null)
  /// The unit's log and definition, in a dialog.
  let detailOpen = $state(false)
  /// The action waiting for the account that owns the unit.
  let pending = $state<ServiceAction | undefined>(undefined)
  let password = $state('')
  /// The notice about the listing (a scope that could not be read), opened
  /// from the status bar.
  let noticeOpen = $state(false)

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
      // The selection goes where the unit is gone.
      if (selected && !next.units.some((u) => u.key === selected)) {
        selected = null
        pending = undefined
        detailOpen = false
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

  const units = $derived(view?.units ?? [])
  const manager = $derived(view?.manager ?? null)
  const userScope = $derived(view?.supports_user_scope === true)
  const opened = $derived(selected === null ? undefined : units.find((u) => u.key === selected))

  /// Which units the list shows: by state (the manager's), and by type.
  type StateFilter = 'all' | 'running' | 'stopped' | 'failed'
  let filter = $state<StateFilter>('all')
  let typeFilter = $state<'all' | ServiceUnitType>('all')

  const STATE_GROUPS: { id: StateFilter; label: () => string; icon: string }[] = [
    { id: 'all', label: () => $LL.servicesFilterAll(), icon: 'list' },
    { id: 'running', label: () => $LL.serviceStateRunning(), icon: 'play_circle' },
    { id: 'stopped', label: () => $LL.serviceStateStopped(), icon: 'stop_circle' },
    { id: 'failed', label: () => $LL.serviceStateFailed(), icon: 'error' },
  ]
  const TYPE_GROUPS: { id: 'all' | ServiceUnitType; label: () => string; icon: string }[] = [
    { id: 'all', label: () => $LL.serviceTypeAll(), icon: 'category' },
    { id: 'service', label: () => $LL.serviceTypeService(), icon: 'settings_suggest' },
    { id: 'timer', label: () => $LL.serviceTypeTimer(), icon: 'schedule' },
    { id: 'socket', label: () => $LL.serviceTypeSocket(), icon: 'cable' },
    { id: 'mount', label: () => $LL.serviceTypeMount(), icon: 'hard_drive' },
  ]

  const byState = (unit: ServiceUnit, id: StateFilter) => id === 'all' || unit.state === id
  const byType = (unit: ServiceUnit, id: 'all' | ServiceUnitType) => id === 'all' || unit.type === id

  const visible = $derived.by(() => {
    const needle = query.trim().toLowerCase()
    return units.filter((unit) => {
      if (!byState(unit, filter) || !byType(unit, typeFilter)) return false
      if (!needle) return true
      return unit.full_name.toLowerCase().includes(needle) || (unit.description ?? '').toLowerCase().includes(needle)
    })
  })

  /// How each state is drawn: its word, the dot's colour (none: a ring) and
  /// the word's colour. A `Record` over every state, so a state the agent
  /// grows without a look here is a type error.
  const STATES: Record<ServiceState, { label: () => string; dot: string | null; color: string }> = {
    running: { label: () => $LL.serviceStateRunning(), dot: 'var(--hue-green)', color: 'var(--color-success)' },
    stopped: { label: () => $LL.serviceStateStopped(), dot: null, color: 'var(--text-tertiary)' },
    failed: { label: () => $LL.serviceStateFailed(), dot: 'var(--hue-red)', color: 'var(--color-danger)' },
    starting: { label: () => $LL.serviceStateStarting(), dot: 'var(--hue-amber)', color: 'var(--color-warning)' },
    stopping: { label: () => $LL.serviceStateStopping(), dot: 'var(--hue-amber)', color: 'var(--color-warning)' },
    // Its own word: the manager did not say, which is not "stopped".
    unknown: { label: () => $LL.serviceStateUnknown(), dot: null, color: 'var(--text-tertiary)' },
  }

  /// How each action is drawn. The set a unit carries is the agent's; this is
  /// only the label, the icon and the weight.
  const ACTIONS: Record<ServiceAction, { label: () => string; icon: string; variant: 'primary' | 'secondary' | 'ghost' }> = {
    start: { label: () => $LL.serviceActionStart(), icon: 'play_arrow', variant: 'primary' },
    restart: { label: () => $LL.serviceActionRestart(), icon: 'restart_alt', variant: 'secondary' },
    stop: { label: () => $LL.serviceActionStop(), icon: 'stop', variant: 'ghost' },
    enable: { label: () => $LL.serviceActionEnable(), icon: 'toggle_on', variant: 'ghost' },
    disable: { label: () => $LL.serviceActionDisable(), icon: 'toggle_off', variant: 'ghost' },
  }

  function actionLabel(action: ServiceAction): string {
    return ACTIONS[action].label()
  }

  type Row = { key: string; dot: string | null; name: string; description: string; startup: string; state: string; stateColor: string }

  const rows = $derived(
    visible.map(
      (unit): Row => ({
        key: unit.key,
        dot: STATES[unit.state].dot,
        name: unit.full_name,
        description: unit.description ?? '',
        // The manager's own word, verbatim: `static` and `masked` differ from
        // `enabled`.
        startup: (unit.startup ?? '—') + (userScope && unit.scope === 'user' ? ` · ${$LL.serviceScopeUser()}` : ''),
        state: STATES[unit.state].label(),
        stateColor: STATES[unit.state].color,
      }),
    ),
  )

  const columns = $derived<Column<Row>[]>([
    { key: 'mark', label: '', width: '22px', dotKey: 'dot', sortable: false },
    { key: 'name', label: $LL.serviceUnit(), width: 'minmax(150px,1fr)', strong: true },
    { key: 'description', label: $LL.serviceDescription(), width: 'minmax(0,1.3fr)', dim: true },
    { key: 'startup', label: $LL.serviceStartup(), width: '96px', dim: true, small: true },
    { key: 'state', label: $LL.serviceStatus(), width: '76px', align: 'end', small: true, strong: true, colorKey: 'stateColor' },
  ])

  const title = $derived(filter === 'all' ? $LL.services() : STATE_GROUPS.find((g) => g.id === filter)!.label())

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
    return notice.notice === 'user_scope_unavailable' ? $LL.serviceUserScopeUnavailable() : $LL.serviceDetailsUnavailable()
  }

  /// A timestamp the machine wrote, as an instant: the commands force `TZ=UTC`
  /// and the agent reads the offset off the value itself, so this is the
  /// viewer's zone applied to the same moment rather than the machine's zone
  /// guessed at.
  function timeText(millis: number | null): string {
    if (millis === null) return '—'
    return fmtDate(millis, { month: 'short', day: 'numeric', hour: '2-digit', minute: '2-digit' })
  }

  /// What the selected unit is, at a glance.
  const facts = $derived.by(() => {
    const unit = opened
    if (!unit) return []
    const out = [
      { k: $LL.serviceStatus(), v: STATES[unit.state].label() },
      { k: $LL.serviceStartup(), v: unit.startup ?? '—' },
      { k: $LL.serviceMemory(), v: unit.memory_bytes === null ? '—' : fmtBytes(unit.memory_bytes) },
      { k: $LL.serviceSince(), v: timeText(unit.since_millis) },
    ]
    if (unit.next_elapse_millis !== null) out.push({ k: $LL.serviceNextRun(), v: timeText(unit.next_elapse_millis) })
    // The manager's finer state and why the last run ended, verbatim.
    if (unit.result) out.push({ k: $LL.serviceResult(), v: `${unit.result}${unit.exit_status !== null ? ` ${unit.exit_status}` : ''}` })
    return out
  })
</script>

<AppToolbar {title} subtitle={view?.available ? $LL.serviceUnits({ count: visible.length }) : undefined} flush={!!view?.available}>
  {#snippet actions()}
    <SearchField bind:value={query} placeholder={$LL.serviceSearchHint()} width={220} class="min-w-[90px]" />
    <IconButton icon="refresh" label={$LL.refresh()} onclick={() => void load()} disabled={loading} />
  {/snippet}
</AppToolbar>

<SplitView>
  {#snippet sidebar()}
    <SidebarSection title={$LL.serviceSectionState()}>
      {#each STATE_GROUPS as group (group.id)}
        {@const count = units.filter((u) => byState(u, group.id) && byType(u, typeFilter)).length}
        <SidebarItem
          label={group.label()}
          icon={group.icon}
          active={filter === group.id}
          trailing={count}
          onclick={() => {
            filter = group.id
            selected = null
          }}
        />
      {/each}
    </SidebarSection>
    <SidebarSection title={$LL.serviceSectionType()}>
      {#each TYPE_GROUPS as group (group.id)}
        <SidebarItem
          label={group.label()}
          icon={group.icon}
          active={typeFilter === group.id}
          trailing={units.filter((u) => byType(u, group.id) && byState(u, filter)).length}
          onclick={() => {
            typeFilter = group.id
            selected = null
          }}
        />
      {/each}
    </SidebarSection>
  {/snippet}

  {#if error}<div class="px-(--content-pad) pb-[9px]"><Card><p class="text-[13px] text-(--color-danger)">{error}</p></Card></div>{/if}

  {#if loading && !view}
    <div class="grid flex-1 place-items-center"><Spinner /></div>
  {:else if view && !view.available}
    <div class="px-(--content-pad) pb-[17px]">
      <Card>
        <p class="text-[13px] text-(--text-secondary)">{reasonText(view)}</p>
        {#if view.reason && view.reason_kind !== 'unsupported_manager'}
          <pre class="lk-mono mt-[9px] whitespace-pre-wrap break-all text-[12px] text-(--text-tertiary)">{view.reason}</pre>
        {/if}
      </Card>
    </div>
  {:else if view}
    <DataTable
      density={systemPrefs.value.density}
      label={$LL.services()}
      {columns}
      {rows}
      rowKey="key"
      {selected}
      onselect={(key) => {
        selected = key as string | null
        pending = undefined
        actionError = ''
      }}
      onopen={(row) => {
        selected = row.key
        detailOpen = true
      }}
      empty={filter === 'failed' && !query ? $LL.serviceNoFailed() : units.length ? $LL.serviceNoMatch() : $LL.servicesEmptyState()}
      emptyIcon={filter === 'failed' && !query ? 'check_circle' : 'search_off'}
    />
  {/if}
</SplitView>

<WindowFooter>
  {#if opened}
    {@const unit = opened}
    {@const state = STATES[unit.state]}
    <!-- The selected unit: what it is, and what may be done to it, with its
         state on screen as the action is taken. -->
    <div class="mx-[9px] mb-[7px] flex flex-col gap-[9px] rounded-[13px] bg-(--surface-card) py-[13px] pl-[17px] pr-[13px]">
      <div class="flex min-w-0 items-center gap-[9px]">
        <span
          class="h-[9px] w-[9px] shrink-0 rounded-full"
          style:background={state.dot ?? 'transparent'}
          style:box-shadow={state.dot ? undefined : 'inset 0 0 0 1.5px var(--text-tertiary)'}
        ></span>
        <span class="truncate text-[15px] font-bold">{unit.full_name}</span>
        {#if unit.description}<span class="min-w-0 truncate text-[12px] text-(--text-secondary)">{unit.description}</span>{/if}
        <span class="flex-1"></span>
        <IconButton icon="close" label={$LL.close()} size="sm" onclick={() => (selected = null)} />
      </div>
      <div class="grid grid-cols-[repeat(auto-fit,minmax(90px,1fr))] gap-[9px]">
        {#each facts as f (f.k)}
          <div class="flex min-w-0 flex-col gap-[3px]">
            <span class="text-[11px] font-bold tracking-[.04em] text-(--text-tertiary)">{f.k}</span>
            <span class="lk-num truncate font-semibold">{f.v}</span>
          </div>
        {/each}
      </div>
      {#if actionError && pending === undefined}<p class="truncate text-[12px] text-(--color-danger)" title={actionError}>{actionError}</p>{/if}
      <div class="flex flex-wrap gap-[7px]">
        {#each unit.actions as action (action)}
          {@const a = ACTIONS[action]}
          <Button variant={a.variant} size="sm" icon={a.icon} disabled={busy} onclick={() => run(action)}>{a.label()}</Button>
        {/each}
        {#if busy}<Spinner size="sm" />{/if}
        <span class="flex-1"></span>
        <Button variant="ghost" size="sm" icon="receipt_long" onclick={() => (detailOpen = true)}>{$LL.serviceLogs()}</Button>
      </div>
    </div>
  {/if}
  <StatusBar>
    <span class="truncate">{notice || (manager ? $LL.serviceSubtitle({ manager: manager.description, count: units.length }) : '')}</span>
    <span class="flex-1"></span>
    {#if view?.notice}
      <div class="relative">
        <button
          type="button"
          class="flex h-6 max-w-[260px] items-center gap-[5px] truncate rounded-full px-[9px] text-[12px] text-(--text-secondary) hover:bg-(--fill-hover)"
          class:bg-(--fill-press)={noticeOpen}
          aria-expanded={noticeOpen}
          onclick={() => (noticeOpen = !noticeOpen)}
        >
          <Icon name="info" size={15} />{noticeText(view)}
        </button>
      </div>
    {/if}
  </StatusBar>
  {#if noticeOpen && view?.notice}
    <div class="service-notice">
      <span class="text-[13px] font-bold">{noticeText(view)}</span>
      {#if view.detail}
        <code class="lk-mono whitespace-pre-wrap break-all rounded-[7px] bg-(--surface-control) px-[9px] py-[7px] text-[11px] leading-normal text-(--text-secondary)">{view.detail}</code>
      {/if}
    </div>
  {/if}
</WindowFooter>

<!-- The unit's log and definition; and the second attempt of an action that
     needs the account owning the unit. -->
{#if opened && (detailOpen || pending !== undefined)}
  {@const unit = opened}
  <Dialog
    open
    wide
    title={unit.full_name}
    onclose={() => {
      detailOpen = false
      pending = undefined
      password = ''
    }}
  >
    {#snippet actions()}
      {#if pending !== undefined}
        <!-- Without a password the retry is the `sudo -n` the agent
             already tried. -->
        <Button variant="primary" disabled={busy || !password} onclick={() => void act(pending!, true)}>{$LL.serviceRetryAsRoot()}</Button>
      {/if}
      <Button
        variant="secondary"
        onclick={() => {
          detailOpen = false
          pending = undefined
        }}>{$LL.close()}</Button
      >
    {/snippet}
    {#if pending !== undefined}
      <!-- The password is sent as its own field so it never lands in a
           command line. -->
      {#if actionError}<pre class="mb-[9px] whitespace-pre-wrap break-all text-[13px] text-(--color-danger)">{actionError}</pre>{/if}
      <Input id="service-password" label={$LL.powerPassword()} type="password" bind:value={password} />
      <p class="mt-[5px] text-[12px] text-(--text-secondary)">{$LL.powerPasswordHint()}</p>
    {:else}
      <ServiceDetail unitKey={unit.key} />
    {/if}
  </Dialog>
{/if}

<style>
  .service-notice {
    position: absolute;
    right: 9px;
    bottom: calc(var(--statusbar-height) + 7px);
    z-index: 4;
    width: min(340px, calc(100% - 18px));
    display: flex;
    flex-direction: column;
    gap: 7px;
    padding: 13px;
    border-radius: var(--radius-card);
    background: var(--glass-menu);
    backdrop-filter: var(--blur-menu);
    -webkit-backdrop-filter: var(--blur-menu);
    box-shadow: var(--shadow-menu);
    user-select: text;
    transform-origin: bottom right;
    animation: lk-menu-in var(--dur-base) var(--ease-spring);
  }
</style>
