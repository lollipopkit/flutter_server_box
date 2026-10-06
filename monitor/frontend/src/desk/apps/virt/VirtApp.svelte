<script lang="ts">
  import { Badge, Button, Card, IconButton, Input, Modal, Spinner } from '@serverbox/webui'
  import { Archive, Box, Cpu, HardDrive, MemoryStick, Network, Pause, Play, Plus, Power, RefreshCw, RotateCcw, Settings, Square, Trash2 } from '@lucide/svelte'
  import SourceGroup from '../../ui/SourceGroup.svelte'
  import SourceItem from '../../ui/SourceItem.svelte'
  import SplitView from '../../ui/SplitView.svelte'
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
  import AppToolbar from '../../ui/AppToolbar.svelte'
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
    stateDot,
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
        { label: 'CPU', color: 'var(--color-chart-1, #3b82f6)', values: samples.map((s) => s.cpu) },
        {
          label: $LL.virtMemory(),
          color: 'var(--color-chart-2, #22c55e)',
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

  function actionIcon(action: VirtPowerAction) {
    switch (action) {
      case 'start':
      case 'resume':
        return Play
      case 'suspend':
        return Pause
      case 'reboot':
        return RotateCcw
      case 'force_stop':
        return Square
      default:
        return Power
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
      <IconButton label={$LL.virtNew()} onclick={() => (creating = true)}>
        <Plus class="w-4 h-4" />
      </IconButton>
    {/if}
    {#if admin && load?.host === 'pve'}
      <IconButton label={$LL.pveSettings()} onclick={() => (editing = true)}>
        <Settings class="w-4 h-4" />
      </IconButton>
    {/if}
    <IconButton label={$LL.refresh()} disabled={loading} onclick={() => void refresh()}>
      <RefreshCw class="w-4 h-4" />
    </IconButton>
  {/snippet}
  {#snippet tabs()}
    {#if showPaneTabs}
      <div class="inline-flex max-w-full items-center gap-0.5 overflow-x-auto rounded-lg border border-line bg-soft/60 p-0.5">
        {#each [['overview', $LL.virtViewOverview()], ['hardware', $LL.virtViewHardware()], ['console', $LL.virtViewConsole()], ...(view?.capabilities.snapshots && !current?.template ? [['snapshots', $LL.virtViewSnapshots()]] : []), ...(view?.capabilities.backup === true ? [['backup', $LL.virtViewBackup()]] : []), ['settings', $LL.virtViewSettings()]] as [id, label] (id)}
          <button
            class="shrink-0 rounded-md px-2.5 py-1 text-xs transition-colors {pane === id ? 'bg-surface text-fg-strong shadow-sm' : 'text-muted-fg hover:text-fg'}"
            aria-current={pane === id ? 'page' : undefined}
            onclick={() => (pane = id as typeof pane)}
          >
            {label}
          </button>
        {/each}
      </div>
    {/if}
  {/snippet}
</AppToolbar>

<div class="absolute inset-x-0 bottom-0 min-h-0" style:top={showPaneTabs ? 'calc(5rem + 1px)' : 'calc(3rem + 1px)'}>
  <SplitView width={14}>
    {#snippet sidebar()}
      <SourceGroup title={$LL.virt()}>
        <SourceItem
          label={$LL.virtSectionGuests()}
          icon={Box}
          selected={section === 'guests'}
          onclick={() => (section = 'guests')}
        />
        {#if view?.capabilities.storage}
          <SourceItem
            label={$LL.virtSectionStorage()}
            icon={HardDrive}
            selected={section === 'storage'}
            onclick={() => (section = 'storage')}
          />
        {/if}
        {#if view?.capabilities.network}
          <SourceItem
            label={$LL.virtSectionNetworks()}
            icon={Network}
            selected={section === 'networks'}
            onclick={() => (section = 'networks')}
          />
        {/if}
        {#if view?.capabilities.backup_jobs === true}
          <SourceItem
            label={$LL.virtSectionBackupJobs()}
            icon={Archive}
            selected={section === 'backup_jobs'}
            onclick={() => (section = 'backup_jobs')}
          />
        {/if}
      </SourceGroup>
    {/snippet}

    <main class="mx-auto max-w-6xl space-y-4 px-4 py-4 @3xl:px-6">
  {#if requestError}
    <Card class="border-danger/40 bg-danger/5">
      <p class="text-sm text-danger whitespace-pre-wrap break-all">{requestError}</p>
    </Card>
  {/if}
  {#if notice}
    <Card>
      <p class="text-sm text-muted-fg">{notice}</p>
    </Card>
  {/if}

  {#if hostError}
    {@const e = hostError}
    <Card class="space-y-3 border-warning/40 bg-warning/5">
      <p class="text-sm text-fg-strong whitespace-pre-wrap break-all">{virtErrorText(e)}</p>

      {#if (e.kind === 'cert_unconfirmed' || e.kind === 'cert_changed') && e.cert}
        {@const cert = e.cert}
        <dl class="grid grid-cols-[auto_1fr] gap-x-3 gap-y-1 text-xs">
          <dt class="text-faint-fg">{$LL.bmcCertSubject()}</dt>
          <dd class="break-all text-muted-fg">{cert.subject || '—'}</dd>
          <dt class="text-faint-fg">{$LL.bmcCertIssuer()}</dt>
          <dd class="break-all text-muted-fg">{cert.issuer || '—'}</dd>
          {#if cert.not_after > 0}
            <dt class="text-faint-fg">{$LL.bmcCertValid()}</dt>
            <dd class="text-muted-fg">{date(cert.not_before)} – {date(cert.not_after)}</dd>
          {/if}
          <dt class="text-faint-fg">SHA-256</dt>
          <dd class="break-all font-mono text-muted-fg">{prettyFingerprint(cert.fingerprint)}</dd>
          {#if e.previous_fingerprint}
            <dt class="text-faint-fg">{$LL.pveCertPrevious()}</dt>
            <dd class="break-all font-mono text-muted-fg">{prettyFingerprint(e.previous_fingerprint)}</dd>
          {/if}
        </dl>
        {#if admin}
          <p class="text-xs text-muted-fg">{$LL.pveCertCompare()}</p>
          <Button size="sm" disabled={busy} onclick={() => void trust(cert.fingerprint)}>{$LL.bmcCertTrust()}</Button>
        {:else}
          <p class="text-xs text-muted-fg">{$LL.pveCertAdmin()}</p>
        {/if}
      {:else if e.kind === 'need_tfa'}
        <form class="flex flex-wrap items-center gap-2" onsubmit={sendTfa}>
          <Input class="w-40" inputmode="numeric" autocomplete="one-time-code" bind:value={tfaInput} placeholder="123456" />
          <Button type="submit" size="sm" disabled={busy || tfaInput.trim() === ''}>{$LL.pveTfaSend()}</Button>
        </form>
      {:else if e.kind === 'sudo_password_required' || e.kind === 'sudo_password_rejected'}
        <form class="flex flex-wrap items-center gap-2" onsubmit={sendSudo}>
          <Input class="w-56" type="password" autocomplete="current-password" bind:value={sudoInput} placeholder={$LL.virtSudoPassword()} />
          <Button type="submit" size="sm" disabled={sudoInput === ''}>{$LL.virtSudoSend()}</Button>
        </form>
        <p class="text-xs text-muted-fg">{$LL.virtSudoHint()}</p>
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
    <Card class="space-y-3">
      {#if !load.supported}
        <p class="text-sm text-muted-fg">{$LL.virtUnsupported()}</p>
      {:else if load.host === 'pve' && !load.pve_configured}
        <p class="text-sm text-muted-fg">{admin ? $LL.pveSetupAdmin() : $LL.pveSetup()}</p>
        {#if admin}
          <Button size="sm" onclick={() => (editing = true)}>{$LL.pveSettings()}</Button>
        {/if}
      {:else}
        <p class="text-sm text-muted-fg">{$LL.virtNone()}</p>
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
    <div class="grid gap-4 @5xl:grid-cols-[minmax(16rem,20rem)_1fr]">
      <!-- The list: what the host holds, then every guest. -->
      <section class="space-y-3">
        <Card class="space-y-2">
          <div class="flex items-baseline justify-between gap-2">
            <span class="text-xs text-faint-fg">{$LL.virtAllocated()}</span>
            <span class="text-xs text-muted-fg">{$LL.virtRunningOf({ running: alloc.running, total: alloc.total })}</span>
          </div>
          {#each [{ label: 'vCPU', used: alloc.vcpu, cap: cpuCap, text: cpuCap ? `${alloc.vcpu} / ${cpuCap}` : String(alloc.vcpu) }, { label: $LL.virtMemory(), used: alloc.mem, cap: memCap, text: memCap ? `${fmtBytes(alloc.mem)} / ${fmtBytes(memCap)}` : fmtBytes(alloc.mem) }] as row (row.label)}
            <div class="space-y-1">
              <div class="flex justify-between text-xs">
                <span class="text-faint-fg">{row.label}</span>
                <span class="text-muted-fg">{row.text}</span>
              </div>
              {#if row.cap}
                <div class="h-0.5 overflow-hidden rounded bg-line">
                  <div class="h-full bg-primary" style="width: {Math.min(100, (row.used / row.cap) * 100)}%"></div>
                </div>
              {/if}
            </div>
          {/each}
        </Card>

        {#if guests.length === 0}
          <Card><p class="text-sm text-muted-fg">{$LL.virtNoGuests()}</p></Card>
        {:else}
          <Card class="p-1">
            <ul>
              {#each guests as g (g.id)}
                <li>
                  <button
                    class="w-full rounded-lg px-3 py-2 text-left transition-colors {g.id === selected && !creating
                      ? 'bg-primary/10'
                      : 'hover:bg-muted'}"
                    aria-current={g.id === selected && !creating ? 'true' : undefined}
                    onclick={() => pick(g.id)}
                  >
                    <div class="flex items-center gap-2">
                      <span class="h-2 w-2 shrink-0 rounded-full {stateDot(g.state)}"></span>
                      <span class="truncate text-sm text-fg-strong">{g.name}</span>
                      <span class="ml-auto shrink-0 font-mono text-xs text-faint-fg">
                        {g.template ? $LL.virtTemplate() : g.kind === 'lxc' ? `LXC ${shortId(g)}` : shortId(g)}
                      </span>
                    </div>
                    <p class="truncate pl-4 text-xs text-muted-fg">{sub(g)}</p>
                  </button>
                </li>
              {/each}
            </ul>
          </Card>
        {/if}
      </section>

      <!-- The guest. -->
      <section class="min-w-0 space-y-4">
        {#if creating}
          <VirtCreate {view} {sudoPassword} oncreated={created} oncancel={() => (creating = false)} />
        {:else if current}
          {@const g = current}
          {@const stats = view.stats[g.id] ?? null}
          {@const samples = history[g.id] ?? []}
          <Card class="space-y-3">
            <div class="flex flex-wrap items-start justify-between gap-3">
              <div class="min-w-0">
                <div class="flex items-center gap-2">
                  <Box class="h-4 w-4 shrink-0 text-muted-fg" />
                  <p class="truncate text-base font-semibold text-fg-strong">{g.name}</p>
                  <Badge tone={stateTone(g.state)}>{stateText(g.state)}</Badge>
                </div>
                <p class="truncate text-xs text-muted-fg">
                  {[g.kind === 'lxc' ? $LL.virtLxc() : $LL.virtVm(), g.vmid !== null ? `VMID ${g.vmid}` : g.id, g.node, g.state_reason].filter(Boolean).join(' · ')}
                </p>
              </div>
              <div class="flex flex-wrap items-center gap-1">
                {#if acting}
                  <Spinner size="sm" />
                {/if}
                {#each orderedActions(g) as action (action)}
                  {@const Icon = actionIcon(action)}
                  <Button
                    variant={destructive(action) ? 'danger' : 'secondary'}
                    size="sm"
                    disabled={acting !== null}
                    onclick={() => ask(action)}
                  >
                    <Icon class="h-4 w-4" />
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
              <Card><p class="text-sm text-danger whitespace-pre-wrap break-all">{detailError}</p></Card>
            {:else if !detail}
              <Card><Spinner class="w-5 h-5" /></Card>
            {:else if !g.state || g.state === 'stopped' || detail.consoles.length === 0}
              <Card><p class="text-sm text-muted-fg">{detail.consoles.length === 0 ? $LL.virtConsoleNone() : $LL.virtConsoleStopped()}</p></Card>
            {:else}
              {#each detail.consoles as kind (kind)}
                {#key g.id}
                  <VirtConsole guest={g} {kind} {sudoPassword} />
                {/key}
              {/each}
            {/if}
          {:else if g.state === 'stopped' || g.template}
            <Card class="flex flex-col items-center gap-3 py-10 text-center">
              <Power class="h-6 w-6 text-faint-fg" />
              <p class="text-sm text-fg-strong">{g.template ? $LL.virtTemplate() : stateText(g.state)}</p>
              <p class="text-xs text-muted-fg">{g.template ? $LL.virtTemplateNote() : $LL.virtStoppedNote()}</p>
              {#if g.actions.includes('start')}
                <Button disabled={acting !== null} onclick={() => ask('start')}>
                  <Play class="h-4 w-4" />
                  {actionText('start')}
                </Button>
              {/if}
            </Card>
          {:else}
            <Card class="space-y-3">
              {#if view.capabilities.stored_history}
                <div class="flex flex-wrap gap-1">
                  {#each [['live', $LL.virtRangeLive()], ['hour', $LL.virtRangeHour()], ['day', $LL.virtRangeDay()], ['week', $LL.virtRangeWeek()]] as [id, label] (id)}
                    <Button variant={range === id ? 'primary' : 'secondary'} size="sm" onclick={() => pickRange(g, id as typeof range)}>{label}</Button>
                  {/each}
                </div>
              {/if}
              {#if range !== 'live'}
                {#if storedError}
                  <p class="text-sm text-danger whitespace-pre-wrap break-all">{storedError}</p>
                {:else if stored === null}
                  <Spinner class="w-5 h-5" />
                {:else if stored.length > 1}
                  {@const c = chart(stored)}
                  <LineChart labels={c.labels} series={c.series} yMax={100} format={(v) => fmtPercent(v)} />
                {:else}
                  <p class="text-xs text-muted-fg">{$LL.virtChartNone()}</p>
                {/if}
              {:else if samples.length > 1}
                {@const c = chart(samples)}
                <LineChart labels={c.labels} series={c.series} yMax={100} format={(v) => fmtPercent(v)} />
              {:else}
                <p class="text-xs text-muted-fg">{$LL.virtChartWaiting()}</p>
              {/if}
              <ul class="divide-y divide-line">
                {#each [{ icon: Cpu, label: 'CPU', value: stats?.cpu != null ? fmtPercent(stats.cpu) : '—', frac: stats?.cpu != null ? stats.cpu / 100 : null, note: g.vcpu !== null ? `${g.vcpu} vCPU` : '' }, { icon: MemoryStick, label: $LL.virtMemory(), value: stats?.mem_used != null ? fmtBytes(stats.mem_used) : '—', frac: stats?.mem_used != null && stats.mem_total ? stats.mem_used / stats.mem_total : null, note: stats?.mem_total ? fmtBytes(stats.mem_total) : '' }, { icon: HardDrive, label: $LL.virtDisk(), value: stats?.disk_read != null || stats?.disk_write != null ? `↓ ${fmtBytesPerSec(stats?.disk_read ?? 0)} ↑ ${fmtBytesPerSec(stats?.disk_write ?? 0)}` : '—', frac: stats?.disk_used != null && stats.disk_total ? stats.disk_used / stats.disk_total : null, note: stats?.disk_used != null && stats.disk_total ? `${fmtBytes(stats.disk_used)} / ${fmtBytes(stats.disk_total)}` : '' }, { icon: Network, label: $LL.virtNetwork(), value: stats?.net_in != null || stats?.net_out != null ? `↓ ${fmtBytesPerSec(stats?.net_in ?? 0)} ↑ ${fmtBytesPerSec(stats?.net_out ?? 0)}` : '—', frac: null, note: '' }] as row (row.label)}
                  {@const Icon = row.icon}
                  <li class="flex items-center gap-3 py-2">
                    <Icon class="h-4 w-4 shrink-0 text-muted-fg" />
                    <div class="min-w-0 flex-1">
                      <p class="text-sm text-fg">{row.label}</p>
                      {#if row.frac !== null}
                        <div class="mt-1 h-0.5 overflow-hidden rounded bg-line">
                          <div class="h-full bg-primary" style="width: {Math.min(100, row.frac * 100)}%"></div>
                        </div>
                      {/if}
                      {#if row.note}
                        <p class="text-xs text-faint-fg">{row.note}</p>
                      {/if}
                    </div>
                    <p class="shrink-0 font-mono text-xs text-muted-fg">{row.value}</p>
                  </li>
                {/each}
              </ul>
            </Card>
          {/if}

          {#if pane === 'overview'}
          <Card>
            <dl class="grid grid-cols-2 gap-x-4 gap-y-2 text-xs @2xl:grid-cols-3">
              {#each [[$LL.virtKind(), g.kind === 'lxc' ? $LL.virtLxc() : $LL.virtVm()], [g.vmid !== null ? 'VMID' : 'UUID', g.vmid !== null ? String(g.vmid) : g.id], [$LL.virtNode(), g.node], ['vCPU', g.vcpu !== null ? String(g.vcpu) : null], [$LL.virtMemory(), g.mem_bytes !== null ? fmtBytes(g.mem_bytes) : null], [$LL.virtUptime(), g.uptime ? fmtUptime(g.uptime) : null], [$LL.virtAutostart(), g.autostart === null ? null : g.autostart ? $LL.yes() : $LL.no()], [$LL.virtTags(), g.tags.join(', ') || null]] as [label, value] (label)}
                {#if value}
                  <div class="min-w-0">
                    <dt class="text-faint-fg">{label}</dt>
                    <dd class="break-all text-muted-fg">{value}</dd>
                  </div>
                {/if}
              {/each}
            </dl>
          </Card>
          {/if}
        {:else if guests.length > 0}
          <Card><p class="text-sm text-muted-fg">{$LL.virtPick()}</p></Card>
        {/if}
      </section>
    </div>
  {/if}
</main>
  </SplitView>
</div>

{#if confirming && current}
  {@const action = confirming}
  {@const guest = current}
  <Modal open title={actionText(action)} onclose={() => (confirming = null)}>
    <div class="space-y-4">
      <p class="text-sm text-muted-fg">
        {destructive(action)
          ? $LL.virtConfirmForce({ name: guest.name })
          : $LL.virtConfirm({ action: actionText(action), name: guest.name })}
      </p>
      <div class="flex justify-end gap-2">
        <Button variant="secondary" onclick={() => (confirming = null)}>{$LL.cancel()}</Button>
        <Button variant={destructive(action) ? 'danger' : 'primary'} onclick={() => void power(action)}>
          {actionText(action)}
        </Button>
      </div>
    </div>
  </Modal>
{/if}

{#if editing}
  <Modal open title={$LL.pveSettings()} onclose={() => (editing = false)}>
    <div class="space-y-4">
      <PveForm current={pve} {busy} onsaved={(c) => void savePve(c)} oncancel={() => (editing = false)} />
      {#if pve?.configured}
        <div class="border-t border-line pt-3">
          <Button variant="secondary" size="sm" onclick={() => (removing = true)}>
            <Trash2 class="h-4 w-4" />
            {$LL.pveRemove()}
          </Button>
        </div>
      {/if}
    </div>
  </Modal>
{/if}

{#if removing}
  <Modal open title={$LL.pveRemove()} onclose={() => (removing = false)}>
    <div class="space-y-4">
      <p class="text-sm text-muted-fg">{$LL.pveRemoveConfirm()}</p>
      <div class="flex justify-end gap-2">
        <Button variant="secondary" onclick={() => (removing = false)}>{$LL.cancel()}</Button>
        <Button variant="danger" disabled={busy} onclick={() => void removePve()}>{$LL.pveRemove()}</Button>
      </div>
    </div>
  </Modal>
{/if}
