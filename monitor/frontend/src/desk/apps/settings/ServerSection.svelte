<script lang="ts">
  /// This agent's configuration, as `GET/PUT /settings` and the custom-command
  /// files expose it, and the push channels beside it. Every change here is
  /// an administrator's: an account that has no admin role gets the note that
  /// says so and nothing to edit.

  import { Badge, Button, Checkbox, Group, IconButton, Input, Row, Spinner, Textarea } from '../../lk'
  import { AppToolbar } from '../../sys'
  import { fade } from 'svelte/transition'
  import Disclosure from '../../../components/Disclosure.svelte'
  import Markdown from '../../../components/Markdown.svelte'
  import { LL } from '../../../i18n/i18n-svelte'
  import { isAdmin } from '../../../lib/access'
  import { api, ApiError } from '../../../lib/api'
  import { capabilitiesStore } from '../../../lib/capabilities.svelte'
  import { serverNames } from '../../../lib/serverNames.svelte'
  import { displayName, servers } from '../../../lib/servers.svelte'
  import type {
    CustomCmd,
    DataRetentionConfig,
    MonitoringRule,
    SettingsPayload,
    SettingsView,
  } from '../../../types'
  import PushChannels from './PushChannels.svelte'

  let loading = $state(true)
  let loadError = $state<string | null>(null)
  let saving = $state(false)
  let saveError = $state<string | null>(null)
  let saveOk = $state(false)

  let settings = $state<SettingsView | null>(null)
  // Editable copies, kept as strings for the optional numeric fields so an
  // empty input can mean "unset" (falls back to the backend default) instead
  // of coercing to 0
  let intervalSeconds = $state('')
  let extendedIntervalSecs = $state('')
  let idlePauseEnabled = $state(true)
  let idlePauseThresholdSecs = $state('')
  let rules = $state<MonitoringRule[]>([])
  let corsOrigins = $state<string[]>([])
  let newOrigin = $state('')
  // Absent means no cleanup runs at all, not "the defaults apply" — so this is
  // a switch with four numbers behind it, and the numbers it starts from when
  // it is switched on come from the agent (`data_retention_defaults`).
  let retentionEnabled = $state(false)
  let retentionMetricsDays = $state('')
  let retentionAlertsDays = $state('')
  let retentionCleanupHours = $state('')
  let retentionMaxDbSizeMb = $state('')

  // Its own endpoint and its own save: these are files in a directory, not a
  // field of the config file, and a failure to write one should not read as
  // the settings above having failed.
  let customCmds = $state<CustomCmd[]>([])
  let customCmdsEditable = $state(false)
  let customCmdsSaving = $state(false)
  let customCmdsError = $state<string | null>(null)
  let customCmdsOk = $state(false)

  function applyLoaded(v: SettingsView) {
    settings = v
    intervalSeconds = String(v.interval_seconds)
    extendedIntervalSecs = v.extended_interval_secs != null ? String(v.extended_interval_secs) : ''
    idlePauseEnabled = v.idle_pause_enabled
    idlePauseThresholdSecs = v.idle_pause_threshold_secs != null ? String(v.idle_pause_threshold_secs) : ''
    rules = v.rules.map((r) => ({ ...r }))
    corsOrigins = [...v.cors_allowed_origins]
    // Switched off, the numbers shown are the agent's own defaults, so
    // switching it on is a save away rather than four fields to fill in.
    retentionEnabled = v.data_retention != null
    const retention = v.data_retention ?? v.data_retention_defaults
    retentionMetricsDays = String(retention.metrics_days)
    retentionAlertsDays = String(retention.alerts_days)
    retentionCleanupHours = String(retention.cleanup_interval_hours)
    retentionMaxDbSizeMb = String(retention.max_db_size_mb)
  }

  /// The four inputs as the agent wants them, or `null` when retention is off
  /// — which means no cleanup runs at all, not that the defaults apply.
  function retentionPayload(): DataRetentionConfig | null {
    if (!retentionEnabled) return null
    return {
      metrics_days: Number(retentionMetricsDays),
      alerts_days: Number(retentionAlertsDays),
      cleanup_interval_hours: Number(retentionCleanupHours),
      max_db_size_mb: Number(retentionMaxDbSizeMb),
    }
  }

  async function load() {
    loading = true
    loadError = null
    try {
      applyLoaded(await api.getSettings())
    } catch (e) {
      loadError = e instanceof ApiError ? e.message : String(e)
    } finally {
      loading = false
    }
    await loadCustomCmds()
  }

  /// Separate from the settings load and deliberately not fatal to it: an
  /// agent whose home directory is unreadable still has settings worth
  /// showing.
  async function loadCustomCmds() {
    customCmdsError = null
    try {
      const view = await api.getCustomCmds()
      customCmds = view.commands.map((c) => ({ ...c }))
      customCmdsEditable = view.editable
    } catch (e) {
      customCmdsError = e instanceof ApiError ? e.message : String(e)
    }
  }

  $effect(() => {
    if (servers.authenticated) void capabilitiesStore.ensure(servers.currentId)
  })
  const caps = $derived(capabilitiesStore.byServer[servers.currentId])
  /// Known not to administer this agent, which is what keeps the settings —
  /// readable by an administrator only — from being asked for at all.
  /// Unknown is not a refusal: the agent answers for itself.
  const nonAdmin = $derived(isAdmin(caps) === false)

  $effect(() => {
    if (servers.authenticated && !nonAdmin) void load()
  })

  const isLive = $derived(
    (field: string) => settings?.live_fields.includes(field) ?? false,
  )

  function addRule() {
    rules = [...rules, { name: '', monitor_type: 'cpu', threshold: '>=80%', matcher: 'cpu' }]
  }

  function removeRule(i: number) {
    rules = rules.filter((_, idx) => idx !== i)
  }

  function addOrigin() {
    const v = newOrigin.trim()
    if (v && !corsOrigins.includes(v)) corsOrigins = [...corsOrigins, v]
    newOrigin = ''
  }

  function removeOrigin(i: number) {
    corsOrigins = corsOrigins.filter((_, idx) => idx !== i)
  }

  function addCustomCmd() {
    customCmds = [...customCmds, { name: '', cmd: '' }]
  }

  function removeCustomCmd(i: number) {
    customCmds = customCmds.filter((_, idx) => idx !== i)
  }

  /// Order is what the agent stores, so moving one is an ordinary edit rather
  /// than a view preference.
  function moveCustomCmd(i: number, delta: number) {
    const to = i + delta
    if (to < 0 || to >= customCmds.length) return
    const next = [...customCmds]
    ;[next[i], next[to]] = [next[to], next[i]]
    customCmds = next
  }

  async function saveCustomCmds() {
    customCmdsSaving = true
    customCmdsError = null
    customCmdsOk = false
    try {
      const view = await api.updateCustomCmds(customCmds.map((c) => ({ ...c, name: c.name.trim() })))
      customCmds = view.commands.map((c) => ({ ...c }))
      customCmdsOk = true
    } catch (e) {
      customCmdsError = e instanceof ApiError ? e.message : String(e)
    } finally {
      customCmdsSaving = false
    }
  }

  /// The label of the first retention field the agent would refuse, or null.
  ///
  /// The agent checks three of these itself and answers a clear 400 — but
  /// `max_db_size_mb` accepts 0, and 0 is what `Number('')` gives, so a blank
  /// box would quietly switch the size cap off rather than being reported.
  function retentionError(): string | null {
    if (!retentionEnabled) return null
    const fields: [string, string, number][] = [
      [$LL.retentionMetricsDays(), retentionMetricsDays, 1],
      [$LL.retentionAlertsDays(), retentionAlertsDays, 1],
      [$LL.retentionCleanupHours(), retentionCleanupHours, 1],
      // The one legitimate zero: it turns the cap off.
      [$LL.retentionMaxDbSizeMb(), retentionMaxDbSizeMb, 0],
    ]
    for (const [label, raw, min] of fields) {
      const value = Number(raw)
      if (raw.trim() === '' || !Number.isInteger(value) || value < min) {
        return `${label} ${$LL.retentionInvalid()}`
      }
    }
    return null
  }

  async function save() {
    if (!settings) return

    const invalid = retentionError()
    if (invalid) {
      saveError = invalid
      saveOk = false
      return
    }

    saving = true
    saveError = null
    saveOk = false
    const payload: SettingsPayload = {
      interval_seconds: Number(intervalSeconds) || settings.interval_seconds,
      extended_interval_secs: extendedIntervalSecs.trim() ? Number(extendedIntervalSecs) : null,
      idle_pause_enabled: idlePauseEnabled,
      idle_pause_threshold_secs: idlePauseThresholdSecs.trim() ? Number(idlePauseThresholdSecs) : null,
      rules,
      data_retention: retentionPayload(),
      cors_allowed_origins: corsOrigins,
    }
    try {
      await api.updateSettings(payload)
      saveOk = true
      await load()
    } catch (e) {
      saveError = e instanceof ApiError ? e.message : String(e)
    } finally {
      saving = false
    }
  }
</script>

{#snippet liveBadge(field: string)}
  {#if isLive(field)}
    <Badge tone="success">{$LL.liveField()}</Badge>
  {:else}
    <Badge>{$LL.restartField()}</Badge>
  {/if}
{/snippet}

<AppToolbar
  title={$LL.serverSettings()}
  subtitle={serverNames.byServer[servers.currentId] ??
    (servers.current ? displayName(servers.current) : '')}
>
  {#snippet actions()}
    {#if settings && !nonAdmin}
      <Button size="sm" onclick={save} disabled={saving}>
        {saving ? $LL.saving() : $LL.save()}
      </Button>
    {/if}
  {/snippet}
</AppToolbar>

<main class="mx-auto max-w-[560px] space-y-[13px] px-[21px] pb-[21px] pt-[4px]">
  {#if !servers.authenticated}
    <p class="text-[13px] text-(--text-secondary)">{$LL.settingsNeedsAuth()}</p>
  {:else if nonAdmin}
    <div in:fade={{ duration: 200 }} class="space-y-4">
      <p class="text-[13px] text-(--text-secondary)">{$LL.adminOnlySettings()}</p>
    </div>
  {:else if loading}
    <div class="flex justify-center py-12"><Spinner size={48} /></div>
  {:else if loadError}
    <p class="text-sm text-danger">{loadError}</p>
  {:else if settings}
    <!-- The API round-trip (network latency to a remote agent, unlike
         Dashboard's already-cached poller data or Panel Settings' no-fetch
         local prefs) can land after the toolbar is drawn — fade this in on
         its own instead of popping in abruptly -->
    <div in:fade={{ duration: 200 }} class="space-y-4">
    <p class="text-[13px] text-(--text-secondary)">{$LL.settingsIntro()}</p>

    <Group title={$LL.collection()}>
      <Row label={$LL.intervalSeconds()}>
        <div class="flex items-center gap-[7px]">
          {@render liveBadge('interval_seconds')}
          <Input class="w-[170px]" type="number" min="1" bind:value={intervalSeconds} />
        </div>
      </Row>
      <Row label={$LL.extendedIntervalSecs()}>
        <div class="flex items-center gap-[7px]">
          {@render liveBadge('extended_interval_secs')}
          <Input class="w-[170px]" type="number" min="1" placeholder={$LL.defaultsToInterval()} bind:value={extendedIntervalSecs} />
        </div>
      </Row>
    </Group>

    <Group title={$LL.idlePause()}>
      <div class="mb-[9px] pt-[7px]">
        <Disclosure summary={$LL.moreDetails()}>
          <Markdown text={$LL.idlePauseNote()} class="text-[12px] text-(--text-tertiary)" />
        </Disclosure>
      </div>
      <Row label={$LL.idlePauseEnabled()}>
        <div class="flex items-center gap-[9px]">
          {@render liveBadge('idle_pause_enabled')}
          <Checkbox bind:checked={idlePauseEnabled} />
        </div>
      </Row>
      <Row label={$LL.idlePauseThresholdSecs()}>
        <div class="flex items-center gap-[7px]">
          {@render liveBadge('idle_pause_threshold_secs')}
          <Input class="w-[170px]" type="number" min="1" placeholder={$LL.defaultsToIntervalTimes4()} disabled={!idlePauseEnabled} bind:value={idlePauseThresholdSecs} />
        </div>
      </Row>
    </Group>

    <Group title={$LL.monitoringRules()}>
      <div class="flex justify-end py-[7px]">
        {@render liveBadge('rules')}
      </div>
      <div class="border-b border-(--border-hairline) py-[9px]">
        <Disclosure summary={$LL.moreDetails()}>
          <div class="space-y-[5px] rounded-[9px] bg-(--surface-control) p-[9px] text-[12px] leading-relaxed text-(--text-tertiary)">
            <Markdown text={$LL.ruleHelpType()} />
            <Markdown text={$LL.ruleHelpMatcher()} />
            <Markdown text={$LL.ruleHelpThreshold()} />
          </div>
        </Disclosure>
      </div>
      {#each rules as rule, i (i)}
        <div class="border-b border-(--border-hairline) py-[9px] last:border-0">
          <div class="mb-[7px] flex items-center gap-[7px]">
            <span class="lk-num text-[12px] text-(--text-tertiary)">{i + 1}</span>
            <span class="flex-1"></span>
            <IconButton icon="delete" label={$LL.removeRule()} onclick={() => removeRule(i)} />
          </div>
          <div class="grid grid-cols-2 gap-[7px] @2xl:grid-cols-4">
            <Input label={$LL.ruleName()} placeholder={$LL.ruleNamePlaceholder()} bind:value={rule.name} />
            <Input label={$LL.ruleType()} placeholder="cpu / memory / ..." bind:value={rule.monitor_type} />
            <Input label={$LL.ruleThreshold()} placeholder={$LL.ruleThresholdPlaceholder()} bind:value={rule.threshold} />
            <Input label={$LL.ruleMatcher()} placeholder={$LL.ruleMatcherPlaceholder()} bind:value={rule.matcher} />
          </div>
        </div>
      {/each}
      <div class="py-[7px]">
        <Button variant="tinted" size="sm" icon="add" onclick={addRule}>{$LL.addRule()}</Button>
      </div>
    </Group>

    <!-- Next to the rules because it is what a rule that fires delivers
         through, but its own endpoint and its own save: a credential must not
         have to travel through the payload above to be kept. -->
    <PushChannels />

    <Group title={$LL.dataRetention()}>
      <Row label={$LL.dataRetentionEnabled()}>
        <div class="flex items-center gap-[9px]">
          {@render liveBadge('data_retention')}
          <Checkbox bind:checked={retentionEnabled} />
        </div>
      </Row>
      <div class="border-b border-(--border-hairline) py-[9px]">
        <Disclosure summary={$LL.moreDetails()}>
          <Markdown text={$LL.dataRetentionNote()} class="text-[12px] text-(--text-tertiary)" />
        </Disclosure>
      </div>
      <Row label={$LL.retentionMetricsDays()}>
        <Input class="w-[170px]" type="number" min="1" disabled={!retentionEnabled} bind:value={retentionMetricsDays} />
      </Row>
      <Row label={$LL.retentionAlertsDays()}>
        <Input class="w-[170px]" type="number" min="1" disabled={!retentionEnabled} bind:value={retentionAlertsDays} />
      </Row>
      <Row label={$LL.retentionCleanupHours()}>
        <Input class="w-[170px]" type="number" min="1" disabled={!retentionEnabled} bind:value={retentionCleanupHours} />
      </Row>
      <Row label={$LL.retentionMaxDbSizeMb()}>
        <Input class="w-[170px]" type="number" min="0" disabled={!retentionEnabled} bind:value={retentionMaxDbSizeMb} />
      </Row>
    </Group>

    <Group title={$LL.corsOrigins()}>
      <Row label={$LL.corsOrigins()}>
        {@render liveBadge('cors_allowed_origins')}
      </Row>
      {#each corsOrigins as origin, i (i)}
        <Row label={origin}>
          <span class="flex items-center gap-[5px]">
            <span class="lk-num text-[12px] text-(--text-tertiary)">{i + 1}</span>
            <IconButton icon="delete" label={$LL.removeOrigin()} onclick={() => removeOrigin(i)} />
          </span>
        </Row>
      {/each}
      <div class="flex items-center gap-[7px] py-[7px]">
        <Input class="flex-1" label={$LL.corsOrigins()} placeholder="https://panel.example.com" bind:value={newOrigin} />
        <Button variant="tinted" size="sm" icon="add" onclick={addOrigin}>{$LL.save()}</Button>
      </div>
    </Group>

    <Group title={$LL.customCmds()}>
      {#if customCmdsEditable}
        <Row label={$LL.customCmds()}>
          <Button size="sm" variant="primary" disabled={customCmdsSaving} onclick={saveCustomCmds}>
            {customCmdsSaving ? $LL.saving() : $LL.save()}
          </Button>
        </Row>
      {/if}
      <div class="border-b border-(--border-hairline) py-[9px]">
        <Disclosure summary={$LL.moreDetails()}>
          <Markdown text={$LL.customCmdsNote()} class="text-[12px] text-(--text-tertiary)" />
        </Disclosure>
      </div>
      {#if !customCmdsEditable}
        <!-- With roles the gate is the admin role's shell grant; before them,
             the agent's full_access switch. -->
        <p class="py-[7px] text-[12px] text-(--text-tertiary)">
          {caps?.grants ? $LL.customCmdsReadOnlyRoles() : $LL.customCmdsReadOnly()}
        </p>
      {/if}
      {#each customCmds as cmd, i (i)}
        <div class="border-b border-(--border-hairline) py-[9px] last:border-0">
          <div class="mb-[7px] flex items-center gap-[5px]">
            <span class="lk-num text-[12px] text-(--text-tertiary)">{i + 1}</span>
            <span class="flex-1"></span>
            <IconButton icon="arrow_upward" label={$LL.moveUp()} disabled={!customCmdsEditable || i === 0} onclick={() => moveCustomCmd(i, -1)} />
            <IconButton icon="arrow_downward" label={$LL.moveDown()} disabled={!customCmdsEditable || i === customCmds.length - 1} onclick={() => moveCustomCmd(i, 1)} />
            <IconButton icon="delete" label={$LL.removeCustomCmd()} disabled={!customCmdsEditable} onclick={() => removeCustomCmd(i)} />
          </div>
          <div class="space-y-[9px]">
            <Input label={$LL.customCmdName()} disabled={!customCmdsEditable} bind:value={cmd.name} />
            <Textarea label={$LL.customCmdBody()} rows={3} disabled={!customCmdsEditable} bind:value={cmd.cmd} mono />
          </div>
        </div>
      {/each}
      {#if customCmdsEditable}
        <div class="flex flex-wrap items-center gap-[9px] py-[7px]">
          <Button variant="tinted" size="sm" icon="add" onclick={addCustomCmd}>{$LL.addCustomCmd()}</Button>
          {#if customCmdsSaving}<Spinner size={16} />{/if}
        </div>
      {/if}
      {#if customCmdsError}<p class="py-[7px] text-[13px] text-(--color-danger)" role="alert">{customCmdsError}</p>{/if}
      {#if customCmdsOk}<p class="py-[7px] text-[13px] text-(--color-success)">{$LL.settingsSaved()}</p>{/if}
    </Group>

    {#if saveError}
      <p class="text-sm text-danger">{saveError}</p>
    {/if}
    {#if saveOk}
      <p class="text-sm text-success">{$LL.settingsSaved()}</p>
    {/if}
    </div>
  {/if}
</main>
