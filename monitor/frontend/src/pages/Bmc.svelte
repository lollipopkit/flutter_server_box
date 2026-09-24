<script lang="ts">
  import { Badge, Button, Card, IconButton, Modal, Spinner } from '@serverbox/webui'
  import {
    CircleStop,
    Fan,
    Play,
    Power,
    RefreshCw,
    RotateCw,
    Settings2,
    Thermometer,
    Zap,
    type LucideIcon,
  } from '@lucide/svelte'
  import BmcSettingsForm, {
    bmcSettingsState,
    type BmcSettingsState,
  } from '../components/BmcSettingsForm.svelte'
  import FeatureTabs from '../components/FeatureTabs.svelte'
  import PageHeader from '../components/PageHeader.svelte'
  import { api } from '../lib/api'
  import { bmcRefusalText } from '../lib/bmcRefusal'
  import { servers } from '../lib/servers.svelte'
  import { untrack } from 'svelte'
  import { LL } from '../i18n/i18n-svelte'
  import type { BmcIntent, BmcReading, BmcState, BmcSystem } from '../types'

  interface Props {
    onback: () => void
  }

  const { onback }: Props = $props()

  let view = $state<BmcState | null>(null)
  /// Set when the controller refused with `notConfigured`, which is a state of
  /// this agent rather than a failure: there is nothing to retry until an
  /// address is saved, so the page says so and offers the form instead of an
  /// error with a refresh button.
  let unconfigured = $state(false)
  let loading = $state(true)
  let error = $state('')
  let busy = $state(false)
  let notice = $state('')
  let actionError = $state('')
  /// The intent waiting for a confirmation. The confirmation is a dialog of its
  /// own rather than a state of the buttons, because what it says is what the
  /// intent *does* — `powerCycle` and `restart` are a sentence apart.
  let confirming = $state<BmcIntent | null>(null)
  /// Set while the page is reading the machine back after a power request. The
  /// machine takes tens of seconds to move and the request does not wait for
  /// it, so this is what says the press did something.
  let waiting = $state(false)
  let settingsOpen = $state(false)
  let settingsState = $state<BmcSettingsState | null>(null)
  let settingsEditable = $state(false)
  let settingsError = $state('')
  let probing = $state(false)

  /// The page follows the sidebar, so a reply that arrives after the user has
  /// switched servers belongs to neither.
  function stale(serverId: string | null) {
    return serverId !== servers.currentId
  }

  async function load(serverId: string | null = servers.currentId) {
    loading = true
    error = ''
    try {
      const next = await api.getBmc()
      if (stale(serverId)) return
      unconfigured = false
      view = next
    } catch (e) {
      if (stale(serverId)) return
      const code = e instanceof Error ? e.message : String(e)
      if (code === 'notConfigured') {
        unconfigured = true
        view = null
      } else {
        error = bmcRefusalText(code)
      }
    } finally {
      if (!stale(serverId)) loading = false
    }
  }

  $effect(() => {
    // Only the machine on screen re-runs this.
    const serverId = servers.currentId
    untrack(() => void load(serverId))
  })

  /// The dialog's fields come from the agent on every open rather than from a
  /// copy taken at load: what is stored is the agent's own configuration, and a
  /// panel that seeded itself from a page load would save a section it read
  /// before another tab changed it.
  async function openSettings() {
    settingsOpen = true
    settingsState = null
    settingsEditable = false
    settingsError = ''
    try {
      const next = await api.getBmcSettings()
      settingsEditable = next.editable
      settingsState = bmcSettingsState(next)
    } catch (e) {
      settingsError = bmcRefusalText(e instanceof Error ? e.message : String(e))
    }
  }

  function closeSettings() {
    settingsOpen = false
    settingsState = null
    settingsError = ''
  }

  /// Looks at the certificate at the address as the field has it, and puts the
  /// answer in the pin field. Nothing is sent to the machine, and nothing is
  /// saved: the operator reads the fingerprint and compares it against what the
  /// controller's own interface prints before pressing Save.
  async function probe() {
    if (!settingsState) return
    probing = true
    settingsError = ''
    try {
      const result = await api.probeBmc(settingsState.url)
      settingsState.fingerprint = result.fingerprint
    } catch (e) {
      settingsError = bmcRefusalText(e instanceof Error ? e.message : String(e))
    } finally {
      probing = false
    }
  }

  async function saveSettings(section: Parameters<typeof api.updateBmcSettings>[0]) {
    busy = true
    settingsError = ''
    try {
      const next = await api.updateBmcSettings(section)
      settingsEditable = next.editable
      settingsState = bmcSettingsState(next)
      settingsOpen = false
      notice = $LL.settingsSaved()
      // The page depends on what was just stored: an address that changed may
      // point at a different machine, and one that was cleared leaves nothing
      // to draw.
      await load()
    } catch (e) {
      // The dialog stays open, so the field that caused the refusal is still
      // there to be corrected.
      settingsError = bmcRefusalText(e instanceof Error ? e.message : String(e))
    } finally {
      busy = false
    }
  }

  /// Asks the machine for a power state, then reads it back until it has
  /// arrived.
  async function control(intent: BmcIntent) {
    busy = true
    actionError = ''
    try {
      const result = await api.controlBmc(intent)
      notice = $LL.bmcActionSent({
        action: intentLabel(intent),
        resetType: result.reset_type,
      })
      confirming = null
      await load()
      void settle(intent, servers.currentId)
    } catch (e) {
      actionError = bmcRefusalText(e instanceof Error ? e.message : String(e))
    } finally {
      busy = false
    }
  }

  /// Reads the machine again until it is where the intent asked it to be.
  ///
  /// Bounded, because a machine that will not move is something to be told
  /// about rather than waited on: a BMC can accept a reset and then have the
  /// host's OS ignore it. Every read here is a request the page would make
  /// anyway, and a request that fails drops out rather than retrying.
  async function settle(intent: BmcIntent, serverId: string | null) {
    const want = intentTarget(intent)
    if (!want) return
    waiting = true
    for (let attempt = 0; attempt < 20; attempt++) {
      await new Promise((resolve) => setTimeout(resolve, 3000))
      if (stale(serverId)) break
      await load(serverId)
      if (view?.system.power_state === want) {
        notice = $LL.bmcActionDone({ action: intentLabel(intent) })
        break
      }
    }
    waiting = false
  }

  /// What the intent is asking the machine to be, which is what the page waits
  /// for. `restart` and `powerCycle` both come back to `on`, and a transitional
  /// state is not it — reporting `poweringOff` as the result would be
  /// reporting the request back.
  function intentTarget(intent: BmcIntent): BmcSystem['power_state'] | null {
    if (intent === 'on' || intent === 'restart' || intent === 'powerCycle') return 'on'
    if (intent === 'gracefulShutdown' || intent === 'forceOff') return 'off'
    return null
  }

  function intentLabel(intent: BmcIntent): string {
    switch (intent) {
      case 'on':
        return $LL.bmcIntentOn()
      case 'gracefulShutdown':
        return $LL.bmcIntentGracefulShutdown()
      case 'forceOff':
        return $LL.bmcIntentForceOff()
      case 'restart':
        return $LL.bmcIntentRestart()
      case 'powerCycle':
        return $LL.bmcIntentPowerCycle()
    }
  }

  function intentIcon(intent: BmcIntent): LucideIcon {
    switch (intent) {
      case 'on':
        return Play
      case 'gracefulShutdown':
        return Power
      case 'forceOff':
        return CircleStop
      case 'restart':
        return RotateCw
      case 'powerCycle':
        return Zap
    }
  }

  /// Whether this intent ends or restarts the machine, and so is asked twice.
  ///
  /// `on` is not: turning a machine on loses nothing. Everything else here takes
  /// a running host down or interrupts it, and none of them can be taken back
  /// from this panel.
  function needsConfirm(intent: BmcIntent): boolean {
    return intent !== 'on'
  }

  function stateLabel(state: BmcSystem['power_state']): string {
    switch (state) {
      case 'on':
        return $LL.bmcStateOn()
      case 'off':
        return $LL.bmcStateOff()
      case 'poweringOn':
        return $LL.bmcStatePoweringOn()
      case 'poweringOff':
        return $LL.bmcStatePoweringOff()
      case 'paused':
        return $LL.bmcStatePaused()
      case 'unknown':
        return $LL.bmcStateUnknown()
    }
  }

  /// The tone a power state is drawn in. `unknown` is neutral rather than a
  /// failure: it is what a service newer than this build says, and it is a
  /// thing to display.
  function stateTone(state: BmcSystem['power_state']) {
    if (state === 'on') return 'success' as const
    if (state === 'off') return 'neutral' as const
    if (state === 'unknown') return 'neutral' as const
    return 'warning' as const
  }

  /// A reading with the service's own unit, except that `Cel` is drawn as the
  /// degree sign every reader recognises. `RPM` and `Percent` are passed
  /// through untouched: a fan in one and a fan in the other are different
  /// numbers, and rewriting either into the other would invent data.
  function readingValue(reading: BmcReading): string {
    if (!reading.unit) return String(reading.value)
    return `${reading.value} ${reading.unit === 'Cel' ? '°C' : reading.unit}`
  }

  /// The name a machine is known by: what the service called the product, else
  /// the chassis, else the address is the operator's own and is not read here.
  const name = $derived(view?.product || view?.chassis?.name || $LL.thisServer())
  const intents = $derived(view?.intents ?? [])
  /// The intents that had nothing behind them, shown as a count rather than as
  /// buttons that would fail: the service advertises a vocabulary and implements
  /// part of it.
  const unavailable = $derived(
    (['on', 'gracefulShutdown', 'forceOff', 'restart', 'powerCycle'] as BmcIntent[]).filter(
      (intent) => !intents.includes(intent),
    ),
  )
</script>

<PageHeader
  title={$LL.bmc()}
  subtitle={view ? `${stateLabel(view.system.power_state)} · ${name}` : undefined}
  containerClass="max-w-4xl mx-auto px-4 sm:px-6 lg:px-8 w-full"
  {onback}
>
  {#snippet tabs()}
    <FeatureTabs active="bmc" />
  {/snippet}

  {#snippet actions()}
    <IconButton label={$LL.bmcSettings()} onclick={() => void openSettings()}>
      <Settings2 class="w-4 h-4" />
    </IconButton>
    <IconButton label={$LL.refresh()} disabled={loading} onclick={() => void load()}>
      <RefreshCw class="w-4 h-4" />
    </IconButton>
  {/snippet}
</PageHeader>

<main class="max-w-4xl mx-auto px-4 sm:px-6 lg:px-8 py-8 space-y-4">
  {#if error}
    <Card class="border-danger/40 bg-danger/5">
      <p class="text-sm text-danger">{error}</p>
    </Card>
  {/if}
  {#if notice}
    <Card class="border-success/40 bg-success/5">
      <p class="text-sm text-success">{notice}</p>
    </Card>
  {/if}
  {#if actionError}
    <Card class="border-danger/40 bg-danger/5">
      <p class="text-sm text-danger">{actionError}</p>
    </Card>
  {/if}

  {#if loading && !view && !unconfigured}
    <Card><Spinner class="w-5 h-5" /></Card>
  {:else if unconfigured}
    <Card class="space-y-3">
      <p class="text-sm text-muted-fg">{$LL.bmcUnset()}</p>
      <Button onclick={() => void openSettings()}>{$LL.bmcSetUp()}</Button>
    </Card>
  {:else if view}
    {#if !view.editable}
      <Card class="space-y-1">
        <p class="text-sm text-muted-fg">{$LL.bmcReadOnly()}</p>
      </Card>
    {/if}

    <!-- The machine's own state first, then what can be asked of it. The
         buttons are only the intents the service said it implements: an intent
         with nothing behind it is not offered rather than offered and failing. -->
    <Card class="space-y-4">
      <div class="flex items-center gap-3">
        <Power class="h-5 w-5 shrink-0 text-muted-fg" />
        <div class="flex-1 min-w-0">
          <h2 class="truncate text-base font-semibold font-display text-fg-strong">{name}</h2>
          <p class="truncate text-xs text-muted-fg">
            {[view.vendor, view.system.manufacturer, view.system.model]
              .filter((part) => part)
              .join(' · ')}
          </p>
        </div>
        <Badge tone={stateTone(view.system.power_state)}>
          {stateLabel(view.system.power_state)}
        </Badge>
        {#if waiting}
          <Spinner size="sm" />
        {/if}
      </div>

      {#if view.editable}
        {#if intents.length > 0}
          <div class="flex flex-wrap gap-2">
            {#each intents as intent (intent)}
              {@const Icon = intentIcon(intent)}
              <Button
                variant={intent === 'forceOff' ? 'danger' : intent === 'on' ? 'primary' : 'secondary'}
                size="sm"
                disabled={busy || waiting}
                onclick={() => (needsConfirm(intent) ? (confirming = intent) : void control(intent))}
              >
                <Icon class="mr-1.5 h-4 w-4" />
                {intentLabel(intent)}
              </Button>
            {/each}
          </div>
        {:else}
          <p class="text-xs text-muted-fg">{$LL.bmcNoIntents()}</p>
        {/if}
        {#if unavailable.length > 0}
          <p class="text-xs text-muted-fg">
            {$LL.bmcUnavailableIntents({ intents: unavailable.map(intentLabel).join(', ') })}
          </p>
        {/if}
      {/if}
    </Card>

    <Card class="space-y-3">
      <h2 class="text-base font-semibold font-display text-fg-strong">{$LL.bmcMachine()}</h2>
      <div class="space-y-2">
        {#each [
          [$LL.bmcManufacturer(), view.system.manufacturer],
          [$LL.bmcModel(), view.system.model],
          [$LL.bmcSerial(), view.system.serial],
          [$LL.bmcBios(), view.system.bios_version],
          [$LL.bmcHealth(), view.system.health],
        ] as [label, value] (label)}
          {#if value}
            <div class="flex justify-between gap-4">
              <span class="text-sm text-muted-fg">{label}</span>
              <span class="truncate text-sm font-medium" title={value}>{value}</span>
            </div>
          {/if}
        {/each}
      </div>
    </Card>

    <Card class="space-y-3">
      <div class="flex items-center gap-2">
        <h2 class="text-base font-semibold font-display text-fg-strong">{$LL.bmcSensors()}</h2>
        {#if view.sensors.watts !== null}
          <span class="text-xs text-muted-fg">{$LL.bmcPowerDraw({ watts: view.sensors.watts })}</span>
        {/if}
      </div>

      {#if !view.sensors_read}
        <!-- `sensors_read: false` with an empty reading is the honest pair: an
             empty reading alone reads as a machine with no fans. -->
        <p class="text-sm text-muted-fg">{$LL.bmcSensorsUnread()}</p>
      {:else if view.sensors.temperatures.length === 0 && view.sensors.fans.length === 0}
        <p class="text-sm text-muted-fg">{$LL.bmcSensorsNone()}</p>
      {:else}
        {#if view.sensors.temperatures.length > 0}
          <div class="space-y-2">
            <div class="flex items-center gap-2 text-xs text-muted-fg">
              <Thermometer class="h-3.5 w-3.5" />
              {$LL.bmcTemperatures()}
            </div>
            {#each view.sensors.temperatures as reading (reading.name)}
              <div class="flex justify-between gap-4">
                <span class="truncate text-sm text-muted-fg">{reading.name}</span>
                <span class="text-sm font-medium">{readingValue(reading)}</span>
              </div>
            {/each}
          </div>
        {/if}
        {#if view.sensors.fans.length > 0}
          <div class="space-y-2">
            <div class="flex items-center gap-2 text-xs text-muted-fg">
              <Fan class="h-3.5 w-3.5" />
              {$LL.bmcFans()}
            </div>
            {#each view.sensors.fans as reading (reading.name)}
              <div class="flex justify-between gap-4">
                <span class="truncate text-sm text-muted-fg">{reading.name}</span>
                <span class="text-sm font-medium">{readingValue(reading)}</span>
              </div>
            {/each}
          </div>
        {/if}
      {/if}

      {#if view.sensors_truncated}
        <!-- A silently short list of fans reads as a machine that lost one. -->
        <p class="text-xs text-muted-fg">{$LL.bmcSensorsTruncated()}</p>
      {/if}
    </Card>
  {/if}
</main>

{#if confirming}
  <Modal open title={intentLabel(confirming)} onclose={() => (confirming = null)}>
    <div class="space-y-4">
      <p class="text-sm text-muted-fg">
        {$LL.bmcConfirm({ action: intentLabel(confirming) })}
      </p>
      <div class="flex justify-end gap-2">
        <Button variant="secondary" onclick={() => (confirming = null)}>{$LL.cancel()}</Button>
        <Button
          variant={confirming === 'forceOff' ? 'danger' : 'primary'}
          disabled={busy}
          onclick={() => void control(confirming!)}
        >
          {intentLabel(confirming)}
        </Button>
      </div>
    </div>
  </Modal>
{/if}

{#if settingsOpen}
  <Modal open title={$LL.bmcSettings()} onclose={closeSettings}>
    {#if settingsError}
      <p class="mb-4 text-sm text-danger">{settingsError}</p>
    {/if}
    {#if settingsState === null}
      <Spinner class="w-5 h-5" />
    {:else if !settingsEditable}
      <!-- A form that cannot be saved is a dead end, so it is a sentence
           instead. -->
      <p class="text-sm text-muted-fg">{$LL.bmcReadOnly()}</p>
    {:else}
      <BmcSettingsForm
        fields={settingsState}
        onsaved={(section) => void saveSettings(section)}
        onprobe={() => void probe()}
        {probing}
        oncancel={closeSettings}
      />
    {/if}
  </Modal>
{/if}
