<script lang="ts">
  import { AppIcon, Badge, Button, Card, Dialog, Icon, IconButton, Input, SegmentedControl, SidebarItem, SidebarSection, Spinner } from '../../lk/index'
  import { AppToolbar, SplitView } from '../../sys'
  import LineChart from '../../../components/LineChart.svelte'
  import PveForm from './PveForm.svelte'
  import VirtBackupJobs from './VirtBackupJobs.svelte'
  import VirtBackups from './VirtBackups.svelte'
  import VirtConsole from './VirtConsole.svelte'
  import VirtCreate from './VirtCreate.svelte'
  import VirtHardware from './VirtHardware.svelte'
  import VirtManage from './VirtManage.svelte'
  import VirtNetworks from './VirtNetworks.svelte'
  import VirtSnapshots from './VirtSnapshots.svelte'
  import VirtStorage from './VirtStorage.svelte'
  import { api } from '../../../lib/api'
  import { prettyFingerprint } from '../../../lib/bmc'
  import { fmtBytes, fmtBytesPerSec, fmtPercent } from '../../../lib/format'
  import { isAdmin } from '../../../lib/access'
  import { capabilitiesStore } from '../../../lib/capabilities.svelte'
  import { servers } from '../../../lib/servers.svelte'
  import {
    actionText,
    allocation,
    destructive,
    fmtUptime,
    orderedActions,
    pushSample,
    shortId,
    stateText,
    stateTone,
    virtErrorText,
    virtRequestText,
  } from '../../../lib/virt'
  import { onDestroy, untrack } from 'svelte'
  import { LL } from '../../../i18n/i18n-svelte'
  import type { PveConfigInput, PveConfigView, VirtCreated, VirtError, VirtGuest, VirtGuestDetail, VirtHistoryWindow, VirtLoad, VirtPowerAction, VirtStats } from '../../../types'

  /// This machine's guests, PVE or libvirt: the list on one side, the one
  /// selected on the other — its usage, its power. Everything is read and
  /// done by the agent (`/virt`, `sbm_virt`); this page keeps the readings of
  /// this session for its chart, and a sudo password in memory for a libvirt
  /// that refuses the agent's account.

  /// How often the host is read again. PVE's own listing moves every ~10 s.
  const POLL_MS = 5_000

  /// Failures that wait for the operator: refreshing would repeat them.
  const NEEDS_INPUT = new Set([
    'need_tfa',
    'cert_unconfirmed',
    'cert_changed',
    'sudo_password_required',
    'sudo_password_rejected',
    'auth_failed',
    'not_configured',
  ])

  let load = $state<VirtLoad | null>(null)
  let loading = $state(true)
  let requestError = $state('')
  let notice = $state('')
  let selected = $state<string | null>(null)
  let history = $state<Record<string, VirtStats[]>>({})
  /// Kept for this page's life, sent with every request, never stored.
  let sudoPassword = $state<string | null>(null)
  let sudoInput = $state('')
  let tfaInput = $state('')
  let busy = $state(false)
  let acting = $state<VirtPowerAction | null>(null)
  let confirming = $state<VirtPowerAction | null>(null)
  let pve = $state<PveConfigView | null>(null)
  let editing = $state(false)
  let removing = $state(false)
  let timer: ReturnType<typeof setTimeout> | null = null
  let generation = 0
  /// The selected guest's view, the design's tabs.
  let pane = $state<'overview' | 'hardware' | 'console' | 'snapshots' | 'backup' | 'settings'>('overview')
  /// The right side shows the create form instead of a guest.
  let creating = $state(false)
  /// A guest just made or copied: selected before the host lists it, kept
  /// selected until it does.
  let awaiting = $state<string | null>(null)
  /// What of the host the page shows: its guests, its storage, its networks,
  /// its backup jobs (PVE).
  let section = $state<'guests' | 'storage' | 'networks' | 'backup_jobs'>('guests')
  let detail = $state<VirtGuestDetail | null>(null)
  let detailFor = $state<string | null>(null)
  let detailError = $state('')
  /// `live` is this session's readings; the rest are what PVE stored.
  let range = $state<'live' | VirtHistoryWindow>('live')
  let stored = $state<VirtStats[] | null>(null)
  let storedError = $state('')

  const admin = $derived(isAdmin(capabilitiesStore.byServer[servers.currentId]) === true)
  const view = $derived(load?.view ?? null)
  const hostError = $derived<VirtError | null>(load?.error ?? null)
  const guests = $derived(view?.guests ?? [])
  const current = $derived(guests.find((g) => g.id === selected) ?? null)
  const cluster = $derived((view?.host.nodes.length ?? 0) > 1)
  const showPaneTabs = $derived(section === 'guests' && current !== null && !creating)
  const paneOptions = $derived([
    { value: 'overview', label: $LL.virtViewOverview() },
    { value: 'hardware', label: $LL.virtViewHardware() },
    { value: 'console', label: $LL.virtViewConsole() },
    ...(view?.capabilities.snapshots && !current?.template ? [{ value: 'snapshots', label: $LL.virtViewSnapshots() }] : []),
    ...(view?.capabilities.backup === true ? [{ value: 'backup', label: $LL.virtViewBackup() }] : []),
    { value: 'settings', label: $LL.virtViewSettings() },
  ])

  function stopPolling() {
    if (timer !== null) clearTimeout(timer)
    timer = null
  }

  onDestroy(() => {
    generation++
    stopPolling()
  })

  $effect(() => {
    const serverId = servers.currentId
    untrack(() => {
      load = null
      history = {}
      selected = null
      creating = false
      awaiting = null
      section = 'guests'
      sudoPassword = null
      pve = null
      void refresh(serverId)
    })
  })

  async function refresh(serverId = servers.currentId) {
    stopPolling()
    const mine = ++generation
    loading = true
    try {
      const next = await api.loadVirt(sudoPassword ?? undefined)
      if (mine !== generation || serverId !== servers.currentId) return
      load = next
      requestError = ''
      if (next.error?.kind === 'sudo_password_rejected') sudoPassword = null
      if (next.view) {
        const stats = next.view.stats
        const kept: Record<string, VirtStats[]> = {}
        for (const g of next.view.guests) {
          const s = stats[g.id]
          kept[g.id] = s ? pushSample(history[g.id] ?? [], s) : (history[g.id] ?? [])
        }
        history = kept
        if (awaiting !== null && next.view.guests.some((g) => g.id === awaiting)) awaiting = null
        if (!next.view.guests.some((g) => g.id === selected) && (selected === null || selected !== awaiting)) {
          selected = next.view.guests.find((g) => !g.template)?.id ?? next.view.guests[0]?.id ?? null
        }
      }
      if (next.host === 'pve' && admin && pve === null) void readPve()
      if (!next.error || !NEEDS_INPUT.has(next.error.kind)) schedule(serverId)
    } catch (e) {
      if (mine !== generation) return
      requestError = virtRequestText(e)
      schedule(serverId)
    } finally {
      if (mine === generation) loading = false
    }
  }

  function schedule(serverId: string | null) {
    stopPolling()
    timer = setTimeout(() => void refresh(serverId ?? servers.currentId), POLL_MS)
  }

  async function readPve() {
    try {
      pve = await api.getPve()
    } catch (e) {
      requestError = virtRequestText(e)
    }
  }

  async function savePve(config: PveConfigInput) {
    busy = true
    try {
      pve = await api.setPve(config)
      editing = false
      notice = $LL.pveSaved()
      void refresh()
    } catch (e) {
      requestError = virtRequestText(e)
    } finally {
      busy = false
    }
  }

  async function removePve() {
    busy = true
    try {
      pve = await api.removePve()
      removing = false
      editing = false
      notice = $LL.pveRemoved()
      void refresh()
    } catch (e) {
      requestError = virtRequestText(e)
    } finally {
      busy = false
    }
  }

  async function trust(fingerprint: string) {
    busy = true
    try {
      const { error } = await api.pinPve(fingerprint)
      if (error) requestError = virtErrorText(error)
      else {
        notice = $LL.pveCertTrusted()
        pve = null
        void refresh()
      }
    } catch (e) {
      requestError = virtRequestText(e)
    } finally {
      busy = false
    }
  }

  async function sendTfa(e: SubmitEvent) {
    e.preventDefault()
    busy = true
    try {
      const { error } = await api.pveTfa(tfaInput.trim())
      tfaInput = ''
      if (error) {
        load = load ? { ...load, error } : load
      } else void refresh()
    } catch (err) {
      requestError = virtRequestText(err)
    } finally {
      busy = false
    }
  }

  function sendSudo(e: SubmitEvent) {
    e.preventDefault()
    sudoPassword = sudoInput === '' ? null : sudoInput
    sudoInput = ''
    void refresh()
  }

  function ask(action: VirtPowerAction) {
    if (action === 'start' || action === 'resume') void power(action)
    else confirming = action
  }

  async function power(action: VirtPowerAction) {
    const guest = current
    confirming = null
    if (!guest) return
    acting = action
    notice = ''
    requestError = ''
    try {
      const { error } = await api.virtPower(guest.id, action, sudoPassword ?? undefined)
      if (error) requestError = virtErrorText(error)
      else notice = $LL.virtActDone({ action: actionText(action), name: guest.name })
    } catch (e) {
      requestError = virtRequestText(e)
    } finally {
      acting = null
      void refresh()
    }
  }

  async function loadDetail(g: VirtGuest) {
    detailFor = g.id
    detail = null
    detailError = ''
    try {
      const { detail: next, error } = await api.virtDetail(g.id, sudoPassword ?? undefined)
      if (detailFor !== g.id) return
      if (error) detailError = virtErrorText(error)
      else detail = next
    } catch (e) {
      if (detailFor === g.id) detailError = virtRequestText(e)
    }
  }

  async function loadStored(g: VirtGuest, window: VirtHistoryWindow) {
    stored = null
    storedError = ''
    try {
      const { history: points, error } = await api.virtHistory(g.id, window)
      if (selected !== g.id || range !== window) return
      if (error) storedError = virtErrorText(error)
      else stored = points ?? []
    } catch (e) {
      storedError = virtRequestText(e)
    }
  }

  function pickRange(g: VirtGuest, next: 'live' | VirtHistoryWindow) {
    range = next
    if (next !== 'live') void loadStored(g, next)
  }

  $effect(() => {
    // A new guest starts on its overview, with this session's readings.
    void selected
    untrack(() => {
      pane = 'overview'
      range = 'live'
      stored = null
      detail = null
      detailFor = null
    })
  })

  $effect(() => {
    const g = current
    if (g && pane === 'console' && detailFor !== g.id) untrack(() => void loadDetail(g))
  })

  /// A guest the host has just made: selected, the host read again.
  function adopt(id: string) {
    creating = false
    awaiting = id
    selected = id
    void refresh()
  }

  function created(c: VirtCreated, name: string) {
    requestError = ''
    if (c.start_error) notice = $LL.virtCreatedNotStarted({ name, why: c.start_error })
    else if (c.disk_kept_bytes !== null) notice = $LL.virtCreatedDiskKept({ name, size: fmtBytes(c.disk_kept_bytes) })
    else notice = $LL.virtCreated({ name })
    adopt(c.id)
  }

  function pick(id: string) {
    creating = false
    selected = id
  }

  function chart(samples: VirtStats[]) {
    return {
      labels: samples.map((s) => new Date(s.at).toISOString()),
      series: [
        { label: 'CPU', color: 'var(--hue-blue)', values: samples.map((s) => s.cpu) },
        {
          label: $LL.virtMemory(),
          color: 'var(--hue-teal)',
          values: samples.map((s) =>
            s.mem_used !== null && s.mem_total ? (s.mem_used / s.mem_total) * 100 : null,
          ),
        },
      ],
    }
  }

  function sub(g: VirtGuest): string {
    const parts = [stateText(g.state)]
    if (cluster && g.node) parts.push(g.node)
    if (g.vcpu !== null) parts.push(`${g.vcpu} vCPU`)
    if (g.mem_bytes !== null) parts.push(fmtBytes(g.mem_bytes))
    return parts.join(' · ')
  }

  function actionIcon(action: VirtPowerAction): string {
    switch (action) {
      case 'start':
      case 'resume':
        return 'play_arrow'
      case 'suspend':
        return 'pause'
      case 'reboot':
        return 'restart_alt'
      case 'force_stop':
        return 'stop'
      default:
        return 'power_settings_new'
    }
  }

  function date(seconds: number): string {
    return new Date(seconds * 1000).toLocaleDateString()
  }
</script>

<AppToolbar
  subtitle={view ? [view.host.kind === 'pve' ? 'Proxmox VE' : 'libvirt', view.host.version, view.host.hypervisor].filter(Boolean).join(' · ') : undefined}
>
  {#snippet actions()}
    {#if view?.capabilities.create}
      <!-- The form lives in the guests view: taking the button from any other
           section goes there first, or it would open out of sight. -->
      <Button
        size="sm"
        variant="tinted"
        icon="add"
        onclick={() => {
          section = 'guests'
          creating = true
        }}
      >{$LL.virtNew()}</Button>
    {/if}
    {#if admin && load?.host === 'pve'}
      <IconButton icon="settings" label={$LL.pveSettings()} onclick={() => (editing = true)} />
    {/if}
    <IconButton icon="refresh" label={$LL.refresh()} disabled={loading} onclick={() => void refresh()} />
  {/snippet}
  {#snippet tabs()}
    {#if showPaneTabs}
      <SegmentedControl
        size="sm"
        label={$LL.virt()}
        value={pane}
        options={paneOptions}
        onchange={(next) => (pane = next as typeof pane)}
      />
    {/if}
  {/snippet}
</AppToolbar>

<SplitView width={14}>
    {#snippet sidebar()}
      <SidebarSection title={$LL.virt()}>
        <SidebarItem
          label={$LL.virtSectionGuests()}
          icon="deployed_code"
          active={section === 'guests'}
          onclick={() => (section = 'guests')}
        />
        {#if view?.capabilities.storage}
          <SidebarItem
            label={$LL.virtSectionStorage()}
            icon="hard_drive"
            active={section === 'storage'}
            onclick={() => (section = 'storage')}
          />
        {/if}
        {#if view?.capabilities.network}
          <SidebarItem
            label={$LL.virtSectionNetworks()}
            icon="lan"
            active={section === 'networks'}
            onclick={() => (section = 'networks')}
          />
        {/if}
        {#if view?.capabilities.backup_jobs === true}
          <SidebarItem
            label={$LL.virtSectionBackupJobs()}
            icon="backup"
            active={section === 'backup_jobs'}
            onclick={() => (section = 'backup_jobs')}
          />
        {/if}
      </SidebarSection>
    {/snippet}

    <main class="mx-auto max-w-6xl space-y-[13px] px-[17px] pb-[17px] pt-[4px] @3xl:px-[21px]">
  {#if requestError}
    <Card>
      <p class="whitespace-pre-wrap break-all text-[13px] text-(--color-danger)">{requestError}</p>
    </Card>
  {/if}
  {#if notice}
    <Card>
      <p class="text-[13px] text-(--text-secondary)">{notice}</p>
    </Card>
  {/if}

  {#if hostError}
    {@const e = hostError}
    <Card class="space-y-[13px]">
      <p class="whitespace-pre-wrap break-all text-[13px] text-(--text-primary)">{virtErrorText(e)}</p>

      {#if (e.kind === 'cert_unconfirmed' || e.kind === 'cert_changed') && e.cert}
        {@const cert = e.cert}
        <dl class="grid grid-cols-[auto_1fr] gap-x-[9px] gap-y-[5px] text-[12px]">
          <dt class="text-(--text-tertiary)">{$LL.bmcCertSubject()}</dt>
          <dd class="break-all text-(--text-secondary)">{cert.subject || '—'}</dd>
          <dt class="text-(--text-tertiary)">{$LL.bmcCertIssuer()}</dt>
          <dd class="break-all text-(--text-secondary)">{cert.issuer || '—'}</dd>
          {#if cert.not_after > 0}
            <dt class="text-(--text-tertiary)">{$LL.bmcCertValid()}</dt>
            <dd class="text-(--text-secondary)">{date(cert.not_before)} – {date(cert.not_after)}</dd>
          {/if}
          <dt class="text-(--text-tertiary)">SHA-256</dt>
          <dd class="break-all lk-mono text-(--text-secondary)">{prettyFingerprint(cert.fingerprint)}</dd>
          {#if e.previous_fingerprint}
            <dt class="text-(--text-tertiary)">{$LL.pveCertPrevious()}</dt>
            <dd class="break-all lk-mono text-(--text-secondary)">{prettyFingerprint(e.previous_fingerprint)}</dd>
          {/if}
        </dl>
        {#if admin}
          <p class="text-[12px] text-(--text-secondary)">{$LL.pveCertCompare()}</p>
          <Button size="sm" disabled={busy} onclick={() => void trust(cert.fingerprint)}>{$LL.bmcCertTrust()}</Button>
        {:else}
          <p class="text-[12px] text-(--text-secondary)">{$LL.pveCertAdmin()}</p>
        {/if}
      {:else if e.kind === 'need_tfa'}
        <form class="flex flex-wrap items-center gap-[9px]" onsubmit={sendTfa}>
          <Input class="w-40" inputmode="numeric" autocomplete="one-time-code" bind:value={tfaInput} placeholder="123456" />
          <Button type="submit" size="sm" disabled={busy || tfaInput.trim() === ''}>{$LL.pveTfaSend()}</Button>
        </form>
      {:else if e.kind === 'sudo_password_required' || e.kind === 'sudo_password_rejected'}
        <form class="flex flex-wrap items-center gap-[9px]" onsubmit={sendSudo}>
          <Input class="w-56" type="password" autocomplete="current-password" bind:value={sudoInput} placeholder={$LL.virtSudoPassword()} />
          <Button type="submit" size="sm" disabled={sudoInput === ''}>{$LL.virtSudoSend()}</Button>
        </form>
        <p class="text-[12px] text-(--text-secondary)">{$LL.virtSudoHint()}</p>
      {:else if admin && (e.kind === 'auth_failed' || e.kind === 'not_configured')}
        <Button variant="secondary" size="sm" onclick={() => (editing = true)}>{$LL.pveSettings()}</Button>
      {/if}
      {#if NEEDS_INPUT.has(e.kind) && e.kind !== 'need_tfa' && !e.kind.startsWith('sudo')}
        <Button variant="secondary" size="sm" disabled={loading} onclick={() => void refresh()}>{$LL.refresh()}</Button>
      {/if}
    </Card>
  {/if}

  {#if loading && !load}
    <Card><Spinner class="w-5 h-5" /></Card>
  {:else if load && !load.view && !hostError}
    <Card class="space-y-[9px]">
      {#if !load.supported}
        <p class="text-[13px] text-(--text-secondary)">{$LL.virtUnsupported()}</p>
      {:else if load.host === 'pve' && !load.pve_configured}
        <p class="text-[13px] text-(--text-secondary)">{admin ? $LL.pveSetupAdmin() : $LL.pveSetup()}</p>
        {#if admin}
          <Button size="sm" onclick={() => (editing = true)}>{$LL.pveSettings()}</Button>
        {/if}
      {:else}
        <p class="text-[13px] text-(--text-secondary)">{$LL.virtNone()}</p>
      {/if}
    </Card>
  {/if}

  {#if view && section === 'storage'}
    <VirtStorage {view} {sudoPassword} />
  {:else if view && section === 'networks'}
    <VirtNetworks {view} {sudoPassword} />
  {:else if view && section === 'backup_jobs'}
    <VirtBackupJobs {view} />
  {:else if view}
    {@const alloc = allocation(guests)}
    {@const cpuCap = view.host.nodes.reduce((n, node) => n + (node.max_cpu ?? 0), 0)}
    {@const memCap = view.host.nodes.reduce((n, node) => n + (node.mem_total ?? 0), 0)}
    <div class="grid gap-[9px] @5xl:grid-cols-[minmax(16rem,20rem)_1fr]">
      <!-- The list: what the host holds, then every guest. -->
      <section class="space-y-[9px]">
        <Card class="space-y-[9px]">
          <div class="flex items-baseline justify-between gap-[9px]">
            <span class="text-[12px] text-(--text-tertiary)">{$LL.virtAllocated()}</span>
            <span class="text-[12px] text-(--text-secondary)">{ $LL.virtRunningOf({ running: alloc.running, total: alloc.total }) }</span>
          </div>
          {#each [{ label: 'vCPU', used: alloc.vcpu, cap: cpuCap, text: cpuCap ? `${alloc.vcpu} / ${cpuCap}` : String(alloc.vcpu) }, { label: $LL.virtMemory(), used: alloc.mem, cap: memCap, text: memCap ? `${fmtBytes(alloc.mem)} / ${fmtBytes(memCap)}` : fmtBytes(alloc.mem) }] as row (row.label)}
            <div class="space-y-[5px]">
              <div class="flex justify-between text-[12px]">
                <span class="text-(--text-tertiary)">{row.label}</span>
                <span class="lk-num text-(--text-secondary)">{row.text}</span>
              </div>
              {#if row.cap}
                <div class="h-[3px] overflow-hidden rounded-full bg-(--surface-control)">
                  <div class="h-full bg-(--color-accent)" style="width: {Math.min(100, (row.used / row.cap) * 100)}%"></div>
                </div>
              {/if}
            </div>
          {/each}
        </Card>

        {#if guests.length === 0}
          <div class="flex flex-col items-center gap-[9px] py-[27px] text-(--text-tertiary)">
            <Icon name="deployed_code" size={48} weight={300} />
            <p class="text-[13px]">{$LL.virtEmptyGuests()}</p>
          </div>
        {:else}
          <ul class="flex flex-col gap-[7px]">
            {#each guests as g (g.id)}
              <li>
                <Card
                  onclick={() => pick(g.id)}
                  selected={g.id === selected && !creating}
                  selectedAs="current"
                  padding="11px 13px"
                  class="flex items-center gap-[13px]"
                >
                  <span class="flex h-[34px] w-[34px] shrink-0 items-center justify-center rounded-[9px] bg-(--surface-raised)">
                    <Icon name={g.kind === 'lxc' ? 'deployed_code' : 'desktop_windows'} size={18} color="var(--color-accent-text)" />
                  </span>
                  <span class="min-w-0 flex-1">
                    <span class="flex min-w-0 items-baseline gap-[7px]">
                      <span class="truncate text-[13px] font-semibold">{g.name}</span>
                      <span class="lk-mono shrink-0 text-[12px] text-(--text-tertiary)">#{g.template ? $LL.virtTemplate() : shortId(g)}</span>
                    </span>
                    <span class="block truncate text-[12px] text-(--text-tertiary)">{sub(g)}</span>
                  </span>
                  <Badge tone={stateTone(g.state)} dot>{stateText(g.state)}</Badge>
                </Card>
              </li>
            {/each}
          </ul>
        {/if}
      </section>

      <!-- The guest. -->
      <section class="min-w-0 space-y-[13px]">
        {#if creating}
          <VirtCreate {view} {sudoPassword} oncreated={created} oncancel={() => (creating = false)} />
        {:else if current}
          {@const g = current}
          {@const stats = view.stats[g.id] ?? null}
          {@const samples = history[g.id] ?? []}
          <Card class="space-y-[9px]">
            <div class="flex flex-wrap items-start justify-between gap-[13px]">
              <div class="min-w-0">
                <div class="flex items-center gap-[9px]">
                  <Icon name={g.kind === 'lxc' ? 'deployed_code' : 'desktop_windows'} size={18} color="var(--text-secondary)" />
                  <p class="truncate text-[15px] font-semibold">{g.name}</p>
                  <Badge tone={stateTone(g.state)} dot>{stateText(g.state)}</Badge>
                </div>
                <p class="truncate text-[12px] text-(--text-tertiary)">
                  {[g.kind === 'lxc' ? $LL.virtLxc() : $LL.virtVm(), g.vmid !== null ? `VMID ${g.vmid}` : g.id, g.node, g.state_reason].filter(Boolean).join(' · ')}
                </p>
              </div>
              <div class="flex flex-wrap items-center gap-[5px]">
                {#if acting}
                  <Spinner size="sm" />
                {/if}
                {#each orderedActions(g) as action (action)}
                  <Button
                    variant={destructive(action) ? 'destructive' : 'secondary'}
                    size="sm"
                    icon={actionIcon(action)}
                    disabled={acting !== null}
                    onclick={() => ask(action)}
                  >
                    {actionText(action)}
                  </Button>
                {/each}
              </div>
            </div>
          </Card>

          {#if pane === 'settings'}
            <VirtManage
              {view}
              guest={g}
              {sudoPassword}
              oncloned={(id, name) => {
                notice = $LL.virtCloned({ name: g.name, copy: name })
                adopt(id)
              }}
              ontemplated={(name) => {
                notice = $LL.virtMadeTemplate({ name })
                void refresh()
              }}
              ondeleted={(name) => {
                notice = $LL.virtDeleted({ name })
                selected = null
                void refresh()
              }}
              onchanged={() => void refresh()}
            />
          {:else if pane === 'backup'}
            <VirtBackups
              {view}
              guest={g}
              onchanged={() => void refresh()}
              onjobs={() => (section = 'backup_jobs')}
            />
          {:else if pane === 'snapshots'}
            <VirtSnapshots guest={g} {sudoPassword} onchanged={() => void refresh()} />
          {:else if pane === 'hardware'}
            <VirtHardware {view} guest={g} {sudoPassword} onchanged={() => void refresh()} />
          {:else if pane === 'console'}
            {#if detailError}
              <Card><p class="text-[13px] text-(--color-danger) whitespace-pre-wrap break-all">{detailError}</p></Card>
            {:else if !detail}
              <Card><Spinner class="w-5 h-5" /></Card>
            {:else if !g.state || g.state === 'stopped' || detail.consoles.length === 0}
              <Card><p class="text-[13px] text-(--text-secondary)">{detail.consoles.length === 0 ? $LL.virtConsoleNone() : $LL.virtConsoleStopped()}</p></Card>
            {:else}
              {#each detail.consoles as kind (kind)}
                {#key g.id}
                  <VirtConsole guest={g} {kind} {sudoPassword} />
                {/key}
              {/each}
            {/if}
          {:else if g.state === 'stopped' || g.template}
            <Card class="flex flex-col items-center gap-[13px] py-10 text-center">
              <Icon name="power_settings_new" size={48} weight={300} />
              <p class="text-[13px] text-(--text-primary)">{g.template ? $LL.virtTemplate() : stateText(g.state)}</p>
              <p class="text-[12px] text-(--text-secondary)">{g.template ? $LL.virtTemplateNote() : $LL.virtStoppedNote()}</p>
              {#if g.actions.includes('start')}
                <Button disabled={acting !== null} icon="play_arrow" onclick={() => ask('start')}>
                  {actionText('start')}
                </Button>
              {/if}
            </Card>
          {:else}
            <Card class="space-y-[9px]">
              {#if view.capabilities.stored_history}
                <SegmentedControl
                  size="sm"
                  label={$LL.virtRangeLive()}
                  value={range}
                  options={[
                    { value: 'live', label: $LL.virtRangeLive() },
                    { value: 'hour', label: $LL.virtRangeHour() },
                    { value: 'day', label: $LL.virtRangeDay() },
                    { value: 'week', label: $LL.virtRangeWeek() },
                  ]}
                  onchange={(next) => pickRange(g, next as typeof range)}
                />
              {/if}
              {#if range !== 'live'}
                {#if storedError}
                  <p class="text-[13px] text-(--color-danger) whitespace-pre-wrap break-all">{storedError}</p>
                {:else if stored === null}
                  <Spinner class="w-5 h-5" />
                {:else if stored.length > 1}
                  {@const c = chart(stored)}
                  <LineChart labels={c.labels} series={c.series} yMax={100} format={(v) => fmtPercent(v)} />
                {:else}
                  <p class="text-[12px] text-(--text-secondary)">{$LL.virtChartNone()}</p>
                {/if}
              {:else if samples.length > 1}
                {@const c = chart(samples)}
                <LineChart labels={c.labels} series={c.series} yMax={100} format={(v) => fmtPercent(v)} />
              {:else}
                <p class="text-[12px] text-(--text-secondary)">{$LL.virtChartWaiting()}</p>
              {/if}
              <ul>
                {#each [{ icon: 'speed', label: 'CPU', value: stats?.cpu != null ? fmtPercent(stats.cpu) : '—', frac: stats?.cpu != null ? stats.cpu / 100 : null, note: g.vcpu !== null ? `${g.vcpu} vCPU` : '' }, { icon: 'memory', label: $LL.virtMemory(), value: stats?.mem_used != null ? fmtBytes(stats.mem_used) : '—', frac: stats?.mem_used != null && stats.mem_total ? stats.mem_used / stats.mem_total : null, note: stats?.mem_total ? fmtBytes(stats.mem_total) : '' }, { icon: 'hard_drive', label: $LL.virtDisk(), value: stats?.disk_read != null || stats?.disk_write != null ? `↓ ${fmtBytesPerSec(stats?.disk_read ?? 0)} ↑ ${fmtBytesPerSec(stats?.disk_write ?? 0)}` : '—', frac: stats?.disk_used != null && stats.disk_total ? stats.disk_used / stats.disk_total : null, note: stats?.disk_used != null && stats.disk_total ? `${fmtBytes(stats.disk_used)} / ${fmtBytes(stats.disk_total)}` : '' }, { icon: 'lan', label: $LL.virtNetwork(), value: stats?.net_in != null || stats?.net_out != null ? `↓ ${fmtBytesPerSec(stats?.net_in ?? 0)} ↑ ${fmtBytesPerSec(stats?.net_out ?? 0)}` : '—', frac: null, note: '' }] as row (row.label)}
                  <li class="flex items-center gap-[13px] border-t border-(--border-hairline) py-[7px]">
                    <Icon name={row.icon} size={18} color="var(--text-secondary)" />
                    <div class="min-w-0 flex-1">
                      <p class="text-[13px] text-(--text-primary)">{row.label}</p>
                      {#if row.frac !== null}
                        <div class="mt-[5px] h-[3px] overflow-hidden rounded-full bg-(--surface-control)">
                          <div class="h-full bg-(--color-accent)" style="width: {Math.min(100, row.frac * 100)}%"></div>
                        </div>
                      {/if}
                      {#if row.note}
                        <p class="text-[12px] text-(--text-tertiary)">{row.note}</p>
                      {/if}
                    </div>
                    <p class="shrink-0 lk-num text-[12px] text-(--text-secondary)">{row.value}</p>
                  </li>
                {/each}
              </ul>
            </Card>
          {/if}

          {#if pane === 'overview'}
          <Card>
            <dl class="grid grid-cols-2 gap-x-[13px] gap-y-[9px] text-[12px] @2xl:grid-cols-3">
              {#each [[$LL.virtKind(), g.kind === 'lxc' ? $LL.virtLxc() : $LL.virtVm()], [g.vmid !== null ? 'VMID' : 'UUID', g.vmid !== null ? String(g.vmid) : g.id], [$LL.virtNode(), g.node], ['vCPU', g.vcpu !== null ? String(g.vcpu) : null], [$LL.virtMemory(), g.mem_bytes !== null ? fmtBytes(g.mem_bytes) : null], [$LL.virtUptime(), g.uptime ? fmtUptime(g.uptime) : null], [$LL.virtAutostart(), g.autostart === null ? null : g.autostart ? $LL.yes() : $LL.no()], [$LL.virtTags(), g.tags.join(', ') || null]] as [label, value] (label)}
                {#if value}
                  <div class="min-w-0">
                    <dt class="text-(--text-tertiary)">{label}</dt>
                    <dd class="break-all text-(--text-secondary)">{value}</dd>
                  </div>
                {/if}
              {/each}
            </dl>
          </Card>
          {/if}
        {:else if guests.length > 0}
          <Card><p class="text-[13px] text-(--text-secondary)">{$LL.virtPick()}</p></Card>
        {/if}
      </section>
    </div>
  {/if}
</main>
  </SplitView>

{#if confirming && current}
  {@const action = confirming}
  {@const guest = current}
  <Dialog
    open
    title={actionText(action)}
    message={destructive(action)
      ? $LL.virtConfirmForce({ name: guest.name })
      : $LL.virtConfirm({ action: actionText(action), name: guest.name })}
    onclose={() => (confirming = null)}
  >
    {#snippet icon()}<AppIcon glyph={actionIcon(action)} tone="amber" size={52} />{/snippet}
    {#snippet actions()}
      <Button block variant={destructive(action) ? 'destructive' : 'primary'} onclick={() => void power(action)}>
        {actionText(action)}
      </Button>
      <Button block variant="secondary" onclick={() => (confirming = null)}>{$LL.cancel()}</Button>
    {/snippet}
  </Dialog>
{/if}

{#if editing}
  <Dialog open wide title={$LL.pveSettings()} onclose={() => (editing = false)}>
    <PveForm current={pve} {busy} onsaved={(c) => void savePve(c)} oncancel={() => (editing = false)} />
    {#if pve?.configured}
      <div class="mt-[13px] border-t border-(--border-hairline) pt-[9px]">
        <Button variant="destructive" size="sm" icon="delete" onclick={() => (removing = true)}>
          {$LL.pveRemove()}
        </Button>
      </div>
    {/if}
    {#snippet actions()}
      <Button variant="secondary" onclick={() => (editing = false)}>{$LL.cancel()}</Button>
    {/snippet}
  </Dialog>
{/if}

{#if removing}
  <Dialog open title={$LL.pveRemove()} message={$LL.pveRemoveConfirm()} onclose={() => (removing = false)}>
    {#snippet icon()}<AppIcon glyph="delete" tone="amber" size={52} />{/snippet}
    {#snippet actions()}
      <Button block variant="destructive" disabled={busy} onclick={() => void removePve()}>{$LL.pveRemove()}</Button>
      <Button block variant="secondary" onclick={() => (removing = false)}>{$LL.cancel()}</Button>
    {/snippet}
  </Dialog>
{/if}
