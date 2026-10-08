<script lang="ts">
  import { AppIcon, Badge, Button, Card, Dialog, Icon, IconButton, SidebarItem, SidebarSection, Spinner } from '@lollipopkit/desk-ui'
  import { AppToolbar, SplitView } from '../../sys'
  import BmcForm from './BmcForm.svelte'
  import { api } from '../../../lib/api'
  import { bmcErrorText, intentText, keepPasswords, powerStateText } from '../../../lib/bmc'
  import { servers } from '../../../lib/servers.svelte'
  import { onDestroy, untrack } from 'svelte'
  import { LL } from '../../../i18n/i18n-svelte'
  import type { BmcIntent, BmcList, BmcStatus, BmcTarget, BmcTargetInput } from '../../../types'

  /// The BMCs this agent reaches: each one's power state, system and sensors,
  /// and its power actions. Everything goes through the agent, which signs in
  /// with the stored credentials; the panel never sees a password.

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

<AppToolbar subtitle={list ? $LL.bmcSubtitle({ count: targets.length }) : undefined}>
  {#snippet actions()}
    {#if list?.editable}<Button size="sm" variant="tinted" icon="add" onclick={() => (editing = null)}>{$LL.bmcAdd()}</Button>{/if}
    <IconButton icon="refresh" label={$LL.refresh()} disabled={loading} onclick={() => void load()} />
  {/snippet}
</AppToolbar>

<SplitView width={14}>
  {#snippet sidebar()}
    <SidebarSection title={$LL.bmc()}>
      {#each targets as target (target.id)}
        <SidebarItem label={target.name} icon="dns" active={target.id === selected} onclick={() => select(target.id)} />
      {/each}
    </SidebarSection>
  {/snippet}

  <div class="space-y-[9px] px-(--content-pad) pb-[17px] pt-[4px]">
    {#if error}<Card><p class="whitespace-pre-wrap break-all text-[13px] text-(--color-danger)">{error}</p></Card>{/if}
    {#if notice}<Card><p class="text-[13px] text-(--text-secondary)">{notice}</p></Card>{/if}

    {#if loading && !list}
      <Card class="grid place-items-center" padding="21px"><Spinner size={20} /></Card>
    {:else if list}
      {#if targets.length === 0}
        <div class="flex flex-col items-center gap-[9px] py-[34px] text-(--text-tertiary)">
          <Icon name="dns" size={48} weight={300} />
          <span class="text-[13px]">{$LL.bmcEmptyState()}</span>
          {#if list.editable}<p class="max-w-md text-center text-[12px]">{$LL.bmcEmptyAdmin()}</p>{/if}
        </div>
      {/if}

      {#if current}
        {@const target = current}
        <Card>
          <div class="flex flex-wrap items-center gap-[9px]">
            <div class="min-w-0 flex-1">
              <p class="truncate text-[15px] font-semibold">{target.name}</p>
              <p class="lk-mono truncate text-[12px] text-(--text-tertiary)">{target.url} · {target.username}</p>
            </div>
            {#if reading}<Spinner size="sm" />{/if}
            <IconButton icon="refresh" label={$LL.refresh()} disabled={reading} onclick={() => void read(target.id)} />
            {#if list.editable}
              <IconButton icon="edit" label={$LL.bmcEdit()} onclick={() => (editing = target)} />
              <IconButton icon="delete" label={$LL.bmcRemove()} onclick={() => (removing = target)} />
            {/if}
          </div>

          {#if statusError}<p class="mt-[9px] whitespace-pre-wrap break-all text-[13px] text-(--color-danger)">{statusError}</p>
          {:else if !status}<div class="mt-[9px]"><Spinner size={20} /></div>{/if}

          {#if system}
            <div class="mt-[13px] flex flex-wrap items-center gap-[7px]">
              <Badge tone={tone(system.power_state)} dot>{powerStateText(system.power_state)}</Badge>
              {#if system.health}<Badge tone={system.health === 'OK' ? 'success' : 'warning'} dot>{system.health}</Badge>{/if}
            </div>
            <dl class="mt-[9px] grid grid-cols-2 gap-x-[13px] @2xl:grid-cols-4">
              {#each [[$LL.bmcManufacturer(), system.manufacturer], [$LL.bmcModel(), system.model], [$LL.bmcSerial(), system.serial], [$LL.bmcBios(), system.bios_version]] as [label, value] (label)}
                <div class="border-t border-(--border-hairline) py-[7px]"><dt class="text-[12px] text-(--text-secondary)">{label}</dt><dd class="lk-mono break-all text-right text-[12px]">{value ?? '—'}</dd></div>
              {/each}
            </dl>

            {#if status && status.intents.length > 0}
              <div class="mt-[13px] flex flex-wrap gap-[7px]">
                {#each status.intents as intent (intent)}<Button variant="secondary" size="sm" icon="power_settings_new" disabled={busy} onclick={() => (confirming = intent)}>{intentText(intent)}</Button>{/each}
              </div>
            {:else if status}<p class="mt-[9px] text-[12px] text-(--text-secondary)">{$LL.bmcNotSupported()}</p>{/if}
          {/if}

          {#if sensors && (sensors.temperatures.length > 0 || sensors.fans.length > 0 || sensors.watts !== null)}
            <div class="mt-[13px] grid gap-[13px] @2xl:grid-cols-3">
              {#if sensors.temperatures.length > 0}
                <div><p class="lk-caps mb-[5px]">{$LL.bmcTemperatures()}</p>{#each sensors.temperatures as r (r.name)}<p class="flex justify-between gap-[9px] border-t border-(--border-hairline) py-[5px] text-[12px]"><span class="truncate text-(--text-secondary)">{r.name}</span><span class="lk-num">{fmtReading(r.value, r.unit)}</span></p>{/each}</div>
              {/if}
              {#if sensors.fans.length > 0}
                <div><p class="lk-caps mb-[5px]">{$LL.bmcFans()}</p>{#each sensors.fans as r (r.name)}<p class="flex justify-between gap-[9px] border-t border-(--border-hairline) py-[5px] text-[12px]"><span class="truncate text-(--text-secondary)">{r.name}</span><span class="lk-num">{fmtReading(r.value, r.unit)}</span></p>{/each}</div>
              {/if}
              {#if sensors.watts !== null}<div><p class="lk-caps mb-[5px]">{$LL.bmcPowerDraw()}</p><p class="border-t border-(--border-hairline) py-[5px] text-right text-[12px] lk-num">{fmtReading(sensors.watts, 'W')}</p></div>{/if}
            </div>
            {#if status?.snapshot.sensors_truncated}<p class="mt-[9px] text-[12px] text-(--text-tertiary)">{$LL.bmcSensorsTruncated()}</p>{/if}
          {/if}
        </Card>
      {/if}
    {/if}
  </div>
</SplitView>

{#if confirming && current}
  {@const intent = confirming}
  {@const target = current}
  <Dialog open title={$LL.bmcPowerConfirm({ action: intentText(intent), name: target.name })} onclose={() => (confirming = null)}>
    {#snippet icon()}<AppIcon glyph="dns" tone="amber" size={52} />{/snippet}
    {#snippet actions()}
      <Button variant="destructive" block disabled={busy} icon="power_settings_new" onclick={() => void power(target.id, intent)}>{intentText(intent)}</Button>
      <Button variant="secondary" block onclick={() => (confirming = null)}>{$LL.cancel()}</Button>
    {/snippet}
  </Dialog>
{/if}

{#if removing}
  {@const target = removing}
  <Dialog open title={$LL.bmcRemoveConfirm({ name: target.name })} onclose={() => (removing = null)}>
    {#snippet icon()}<AppIcon glyph="dns" tone="amber" size={52} />{/snippet}
    {#snippet actions()}
      <Button variant="destructive" block disabled={busy} onclick={() => void remove(target)}>{$LL.bmcRemove()}</Button>
      <Button variant="secondary" block onclick={() => (removing = null)}>{$LL.cancel()}</Button>
    {/snippet}
  </Dialog>
{/if}

{#if editing !== undefined}
  <Dialog open wide title={editing ? $LL.bmcEdit() : $LL.bmcAdd()} onclose={() => (editing = undefined)}>
    <BmcForm
      target={editing ?? undefined}
      {busy}
      onsaved={(target) => void submit(target)}
      oncancel={() => (editing = undefined)}
    />
  </Dialog>
{/if}
