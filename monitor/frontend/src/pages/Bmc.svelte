<script lang="ts">
  import { Badge, Button, Card, IconButton, Modal, Spinner } from '@serverbox/webui'
  import { Pencil, Plus, Power, RefreshCw, Trash2 } from '@lucide/svelte'
  import BmcForm from '../components/BmcForm.svelte'
  import FeatureTabs from '../components/FeatureTabs.svelte'
  import PageHeader from '../components/PageHeader.svelte'
  import { api } from '../lib/api'
  import { bmcErrorText, intentText, keepPasswords, powerStateText } from '../lib/bmc'
  import { servers } from '../lib/servers.svelte'
  import { onDestroy, untrack } from 'svelte'
  import { LL } from '../i18n/i18n-svelte'
  import type { BmcIntent, BmcList, BmcStatus, BmcTarget, BmcTargetInput } from '../types'

  /// The BMCs this agent reaches: each one's power state, system and sensors,
  /// and its power actions. Everything goes through the agent, which signs in
  /// with the stored credentials; the panel never sees a password.
  interface Props {
    onback: () => void
  }

  const { onback }: Props = $props()

  /// How often an open target is read again.
  const POLL_MS = 30_000

  let list = $state<BmcList | null>(null)
  let loading = $state(true)
  let error = $state('')
  let notice = $state('')
  let busy = $state(false)
  let selected = $state<string | null>(null)
  let status = $state<BmcStatus | null>(null)
  let statusError = $state('')
  let reading = $state(false)
  /// `undefined` = no form; `null` = a new target.
  let editing = $state<BmcTarget | null | undefined>(undefined)
  let removing = $state<BmcTarget | null>(null)
  let confirming = $state<BmcIntent | null>(null)
  let timer: ReturnType<typeof setInterval> | null = null

  function stale(serverId: string | null) {
    return serverId !== servers.currentId
  }

  async function load(serverId = servers.currentId) {
    loading = true
    error = ''
    try {
      const next = await api.getBmc()
      if (stale(serverId)) return
      list = next
      if (!next.targets.some((t) => t.id === selected)) select(next.targets[0]?.id ?? null)
    } catch (e) {
      if (stale(serverId)) return
      error = bmcErrorText(e)
    } finally {
      if (!stale(serverId)) loading = false
    }
  }

  $effect(() => {
    const serverId = servers.currentId
    untrack(() => {
      select(null)
      void load(serverId)
    })
  })

  onDestroy(() => stopPolling())

  function stopPolling() {
    if (timer !== null) clearInterval(timer)
    timer = null
  }

  function select(id: string | null) {
    stopPolling()
    selected = id
    status = null
    statusError = ''
    if (id === null) return
    void read(id)
    timer = setInterval(() => void read(id), POLL_MS)
  }

  async function read(id: string) {
    if (reading) return
    const serverId = servers.currentId
    reading = true
    try {
      const next = await api.bmcStatus(id)
      if (stale(serverId) || selected !== id) return
      status = next
      statusError = ''
    } catch (e) {
      if (stale(serverId) || selected !== id) return
      statusError = bmcErrorText(e)
    } finally {
      reading = false
    }
  }

  async function save(targets: BmcTargetInput[], done: string) {
    busy = true
    error = ''
    notice = ''
    try {
      list = await api.updateBmc(targets)
      notice = done
      return true
    } catch (e) {
      error = bmcErrorText(e)
      return false
    } finally {
      busy = false
    }
  }

  async function submit(target: BmcTargetInput) {
    const current = keepPasswords(list?.targets ?? [])
    const next = current.some((t) => t.id === target.id)
      ? current.map((t) => (t.id === target.id ? target : t))
      : [...current, target]
    if (await save(next, $LL.bmcSaved({ name: target.name }))) {
      editing = undefined
      select(target.id)
    }
  }

  async function remove(target: BmcTarget) {
    const next = keepPasswords(list?.targets ?? []).filter((t) => t.id !== target.id)
    if (await save(next, $LL.bmcRemoved({ name: target.name }))) {
      removing = null
      if (selected === target.id) select(next[0]?.id ?? null)
    }
  }

  async function power(id: string, intent: BmcIntent) {
    confirming = null
    busy = true
    error = ''
    notice = ''
    try {
      await api.bmcPower(id, intent)
      notice = $LL.bmcPowerSent({ action: intentText(intent) })
      // The state moves over seconds; the next read shows where it went.
      setTimeout(() => {
        if (selected === id) void read(id)
      }, 5_000)
    } catch (e) {
      error = bmcErrorText(e)
    } finally {
      busy = false
    }
  }

  const targets = $derived(list?.targets ?? [])
  const current = $derived(targets.find((t) => t.id === selected) ?? null)
  const system = $derived(status?.snapshot.topology.system ?? null)
  const sensors = $derived(status?.snapshot.sensors ?? null)

  function tone(state: string): 'success' | 'warning' | 'neutral' {
    return state === 'on' ? 'success' : state === 'off' ? 'neutral' : 'warning'
  }

  function fmtReading(value: number, unit: string | null): string {
    return `${Number.isInteger(value) ? value : value.toFixed(1)}${unit ? ` ${unit}` : ''}`
  }
</script>

<PageHeader
  title={$LL.bmc()}
  subtitle={list ? $LL.bmcSubtitle({ count: targets.length }) : undefined}
  containerClass="max-w-5xl mx-auto px-4 sm:px-6 lg:px-8 w-full"
  {onback}
>
  {#snippet tabs()}
    <FeatureTabs active="bmc" />
  {/snippet}

  {#snippet actions()}
    {#if list?.editable}
      <IconButton label={$LL.bmcAdd()} onclick={() => (editing = null)}>
        <Plus class="w-4 h-4" />
      </IconButton>
    {/if}
    <IconButton label={$LL.refresh()} disabled={loading} onclick={() => void load()}>
      <RefreshCw class="w-4 h-4" />
    </IconButton>
  {/snippet}
</PageHeader>

<main class="max-w-5xl mx-auto px-4 sm:px-6 lg:px-8 py-8 space-y-4">
  {#if error}
    <Card class="border-danger/40 bg-danger/5">
      <p class="text-sm text-danger whitespace-pre-wrap break-all">{error}</p>
    </Card>
  {/if}
  {#if notice}
    <Card>
      <p class="text-sm text-muted-fg">{notice}</p>
    </Card>
  {/if}

  {#if loading && !list}
    <Card><Spinner class="w-5 h-5" /></Card>
  {:else if list}
    {#if targets.length === 0}
      <Card>
        <p class="text-sm text-muted-fg">{list.editable ? $LL.bmcEmptyAdmin() : $LL.bmcEmpty()}</p>
      </Card>
    {:else}
      <div class="flex flex-wrap gap-2">
        {#each targets as target (target.id)}
          <Button
            variant={target.id === selected ? 'primary' : 'secondary'}
            size="sm"
            onclick={() => select(target.id)}
          >
            {target.name}
          </Button>
        {/each}
      </div>
    {/if}

    {#if current}
      {@const target = current}
      <Card class="space-y-4">
        <div class="flex flex-wrap items-center justify-between gap-3">
          <div class="min-w-0">
            <p class="truncate text-base font-semibold text-fg-strong">{target.name}</p>
            <p class="truncate text-xs text-muted-fg">{target.url} · {target.username}</p>
          </div>
          <div class="flex items-center gap-1">
            {#if reading}
              <Spinner size="sm" />
            {/if}
            <IconButton label={$LL.refresh()} disabled={reading} onclick={() => void read(target.id)}>
              <RefreshCw class="w-4 h-4" />
            </IconButton>
            {#if list.editable}
              <IconButton label={$LL.bmcEdit()} onclick={() => (editing = target)}>
                <Pencil class="w-4 h-4" />
              </IconButton>
              <IconButton label={$LL.bmcRemove()} onclick={() => (removing = target)}>
                <Trash2 class="w-4 h-4" />
              </IconButton>
            {/if}
          </div>
        </div>

        {#if statusError}
          <p class="text-sm text-danger whitespace-pre-wrap break-all">{statusError}</p>
        {:else if !status}
          <Spinner class="w-5 h-5" />
        {/if}

        {#if system}
          <div class="flex flex-wrap items-center gap-2">
            <Badge tone={tone(system.power_state)}>{powerStateText(system.power_state)}</Badge>
            {#if system.health}
              <Badge tone={system.health === 'OK' ? 'success' : 'warning'}>{system.health}</Badge>
            {/if}
          </div>
          <dl class="grid grid-cols-2 gap-x-4 gap-y-1 text-xs sm:grid-cols-4">
            {#each [[$LL.bmcManufacturer(), system.manufacturer], [$LL.bmcModel(), system.model], [$LL.bmcSerial(), system.serial], [$LL.bmcBios(), system.bios_version]] as [label, value] (label)}
              <div>
                <dt class="text-faint-fg">{label}</dt>
                <dd class="break-all text-muted-fg">{value ?? '—'}</dd>
              </div>
            {/each}
          </dl>

          {#if status && status.intents.length > 0}
            <div class="flex flex-wrap gap-2">
              {#each status.intents as intent (intent)}
                <Button variant="secondary" size="sm" disabled={busy} onclick={() => (confirming = intent)}>
                  <Power class="w-4 h-4" />
                  {intentText(intent)}
                </Button>
              {/each}
            </div>
          {:else if status}
            <p class="text-xs text-muted-fg">{$LL.bmcNotSupported()}</p>
          {/if}
        {/if}

        {#if sensors && (sensors.temperatures.length > 0 || sensors.fans.length > 0 || sensors.watts !== null)}
          <div class="grid gap-4 sm:grid-cols-3">
            {#if sensors.temperatures.length > 0}
              <div class="space-y-1">
                <p class="text-xs text-faint-fg">{$LL.bmcTemperatures()}</p>
                {#each sensors.temperatures as r (r.name)}
                  <p class="flex justify-between gap-2 text-xs text-muted-fg">
                    <span class="truncate">{r.name}</span><span>{fmtReading(r.value, r.unit)}</span>
                  </p>
                {/each}
              </div>
            {/if}
            {#if sensors.fans.length > 0}
              <div class="space-y-1">
                <p class="text-xs text-faint-fg">{$LL.bmcFans()}</p>
                {#each sensors.fans as r (r.name)}
                  <p class="flex justify-between gap-2 text-xs text-muted-fg">
                    <span class="truncate">{r.name}</span><span>{fmtReading(r.value, r.unit)}</span>
                  </p>
                {/each}
              </div>
            {/if}
            {#if sensors.watts !== null}
              <div class="space-y-1">
                <p class="text-xs text-faint-fg">{$LL.bmcPowerDraw()}</p>
                <p class="text-xs text-muted-fg">{fmtReading(sensors.watts, 'W')}</p>
              </div>
            {/if}
          </div>
          {#if status?.snapshot.sensors_truncated}
            <p class="text-xs text-muted-fg">{$LL.bmcSensorsTruncated()}</p>
          {/if}
        {/if}
      </Card>
    {/if}
  {/if}
</main>

{#if confirming && current}
  {@const intent = confirming}
  {@const target = current}
  <Modal open title={intentText(intent)} onclose={() => (confirming = null)}>
    <div class="space-y-4">
      <p class="text-sm text-muted-fg">{$LL.bmcPowerConfirm({ action: intentText(intent), name: target.name })}</p>
      <div class="flex justify-end gap-2">
        <Button variant="secondary" onclick={() => (confirming = null)}>{$LL.cancel()}</Button>
        <Button variant="danger" disabled={busy} onclick={() => void power(target.id, intent)}>
          {intentText(intent)}
        </Button>
      </div>
    </div>
  </Modal>
{/if}

{#if removing}
  {@const target = removing}
  <Modal open title={$LL.bmcRemove()} onclose={() => (removing = null)}>
    <div class="space-y-4">
      <p class="text-sm text-muted-fg">{$LL.bmcRemoveConfirm({ name: target.name })}</p>
      <div class="flex justify-end gap-2">
        <Button variant="secondary" onclick={() => (removing = null)}>{$LL.cancel()}</Button>
        <Button variant="danger" disabled={busy} onclick={() => void remove(target)}>{$LL.bmcRemove()}</Button>
      </div>
    </div>
  </Modal>
{/if}

{#if editing !== undefined}
  <Modal open title={editing ? $LL.bmcEdit() : $LL.bmcAdd()} onclose={() => (editing = undefined)}>
    <BmcForm
      target={editing ?? undefined}
      {busy}
      onsaved={(target) => void submit(target)}
      oncancel={() => (editing = undefined)}
    />
  </Modal>
{/if}
