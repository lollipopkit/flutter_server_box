<script lang="ts">
  import { Menu, Plus, Trash2 } from '@lucide/svelte'
  import { Badge, Button, Card, IconButton, Input, Spinner } from '@serverbox/webui'
  import { LL } from '../i18n/i18n-svelte'
  import { api, ApiError } from '../lib/api'
  import { layout } from '../lib/layout.svelte'
  import { displayName, servers } from '../lib/servers.svelte'
  import type { MonitoringRule, SettingsPayload, SettingsView } from '../types'

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

  function applyLoaded(v: SettingsView) {
    settings = v
    intervalSeconds = String(v.interval_seconds)
    extendedIntervalSecs = v.extended_interval_secs != null ? String(v.extended_interval_secs) : ''
    idlePauseEnabled = v.idle_pause_enabled
    idlePauseThresholdSecs = v.idle_pause_threshold_secs != null ? String(v.idle_pause_threshold_secs) : ''
    rules = v.rules.map((r) => ({ ...r }))
    corsOrigins = [...v.cors_allowed_origins]
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
  }

  $effect(() => {
    if (servers.authenticated) void load()
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

  async function save() {
    if (!settings) return
    saving = true
    saveError = null
    saveOk = false
    const payload: SettingsPayload = {
      interval_seconds: Number(intervalSeconds) || settings.interval_seconds,
      extended_interval_secs: extendedIntervalSecs.trim() ? Number(extendedIntervalSecs) : null,
      idle_pause_enabled: idlePauseEnabled,
      idle_pause_threshold_secs: idlePauseThresholdSecs.trim() ? Number(idlePauseThresholdSecs) : null,
      rules,
      // No editor for retention this round — round-trip whatever was loaded
      // rather than risk silently clearing it
      data_retention: settings.data_retention,
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

<header class="bg-surface shadow-xs border-b border-line h-16 flex items-center">
  <div class="max-w-3xl mx-auto px-4 sm:px-6 lg:px-8 w-full">
    <div class="flex items-center gap-2">
      <IconButton class="lg:hidden -ml-2" label={$LL.menu()} onclick={() => (layout.mobileOpen = true)}>
        <Menu class="w-5 h-5" />
      </IconButton>
      <h1 class="text-lg font-semibold font-display text-fg-strong truncate">
        {$LL.settings()} · {displayName(servers.current)}
      </h1>
    </div>
  </div>
</header>

<main class="max-w-3xl mx-auto px-4 sm:px-6 lg:px-8 py-8 space-y-6">
  {#if !servers.authenticated}
    <p class="text-sm text-muted-fg">{$LL.settingsNeedsAuth()}</p>
  {:else if loading}
    <div class="flex justify-center py-12"><Spinner size="lg" /></div>
  {:else if loadError}
    <p class="text-sm text-danger">{loadError}</p>
  {:else if settings}
    <p class="text-sm text-muted-fg">{$LL.settingsIntro()}</p>

    <Card class="space-y-4">
      <h2 class="text-base font-semibold font-display text-fg-strong">{$LL.collection()}</h2>
      <div class="space-y-1">
        <div class="flex items-center justify-between gap-2">
          <span class="text-sm text-muted-fg">{$LL.intervalSeconds()}</span>
          {@render liveBadge('interval_seconds')}
        </div>
        <Input type="number" min="1" bind:value={intervalSeconds} />
      </div>
      <div class="space-y-1">
        <div class="flex items-center justify-between gap-2">
          <span class="text-sm text-muted-fg">{$LL.extendedIntervalSecs()}</span>
          {@render liveBadge('extended_interval_secs')}
        </div>
        <Input type="number" min="1" placeholder={$LL.defaultsToInterval()} bind:value={extendedIntervalSecs} />
      </div>
    </Card>

    <Card class="space-y-4">
      <h2 class="text-base font-semibold font-display text-fg-strong">{$LL.idlePause()}</h2>
      <p class="text-xs text-faint-fg">{$LL.idlePauseNote()}</p>
      <label class="flex items-center gap-2 text-sm">
        <input type="checkbox" bind:checked={idlePauseEnabled} class="w-4 h-4" />
        {$LL.idlePauseEnabled()}
        {@render liveBadge('idle_pause_enabled')}
      </label>
      <div class="space-y-1">
        <div class="flex items-center justify-between gap-2">
          <span class="text-sm text-muted-fg">{$LL.idlePauseThresholdSecs()}</span>
          {@render liveBadge('idle_pause_threshold_secs')}
        </div>
        <Input
          type="number"
          min="1"
          placeholder={$LL.defaultsToIntervalTimes4()}
          disabled={!idlePauseEnabled}
          bind:value={idlePauseThresholdSecs}
        />
      </div>
    </Card>

    <Card class="space-y-4">
      <div class="flex items-center justify-between gap-2">
        <h2 class="text-base font-semibold font-display text-fg-strong">{$LL.monitoringRules()}</h2>
        {@render liveBadge('rules')}
      </div>
      <div class="space-y-3">
        {#each rules as rule, i (i)}
          <div class="grid grid-cols-2 gap-2 p-3 rounded-lg border border-line">
            <Input placeholder={$LL.ruleName()} bind:value={rule.name} />
            <Input placeholder={$LL.ruleType()} bind:value={rule.monitor_type} />
            <Input placeholder={$LL.ruleThreshold()} bind:value={rule.threshold} />
            <div class="flex gap-2">
              <Input placeholder={$LL.ruleMatcher()} bind:value={rule.matcher} />
              <IconButton label={$LL.removeRule()} class="hover:text-danger shrink-0" onclick={() => removeRule(i)}>
                <Trash2 class="w-4 h-4" />
              </IconButton>
            </div>
          </div>
        {/each}
      </div>
      <Button variant="secondary" size="sm" onclick={addRule}>
        <Plus class="w-4 h-4 mr-1" />{$LL.addRule()}
      </Button>
    </Card>

    <Card class="space-y-4">
      <div class="flex items-center justify-between gap-2">
        <h2 class="text-base font-semibold font-display text-fg-strong">{$LL.corsOrigins()}</h2>
        {@render liveBadge('cors_allowed_origins')}
      </div>
      <div class="space-y-2">
        {#each corsOrigins as origin, i (i)}
          <div class="flex items-center gap-2">
            <span class="flex-1 text-sm font-mono truncate">{origin}</span>
            <IconButton label={$LL.removeOrigin()} class="hover:text-danger shrink-0" onclick={() => removeOrigin(i)}>
              <Trash2 class="w-4 h-4" />
            </IconButton>
          </div>
        {/each}
      </div>
      <div class="flex gap-2">
        <Input placeholder="https://panel.example.com" bind:value={newOrigin} />
        <Button variant="secondary" size="sm" onclick={addOrigin}>
          <Plus class="w-4 h-4" />
        </Button>
      </div>
    </Card>

    {#if saveError}
      <p class="text-sm text-danger">{saveError}</p>
    {/if}
    {#if saveOk}
      <p class="text-sm text-success">{$LL.settingsSaved()}</p>
    {/if}

    <div class="flex justify-end">
      <Button onclick={save} disabled={saving}>
        {saving ? $LL.saving() : $LL.save()}
      </Button>
    </div>
  {/if}
</main>
