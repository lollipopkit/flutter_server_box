<script lang="ts">
  import { Plus, Trash2 } from '@lucide/svelte'
  import { Badge, Button, Card, IconButton, Input, Spinner } from '@serverbox/webui'
  import { fade } from 'svelte/transition'
  import Disclosure from '../components/Disclosure.svelte'
  import Markdown from '../components/Markdown.svelte'
  import PageHeader from '../components/PageHeader.svelte'
  import { LL } from '../i18n/i18n-svelte'
  import { api, ApiError } from '../lib/api'
  import { serverNames } from '../lib/serverNames.svelte'
  import { displayName, servers } from '../lib/servers.svelte'
  import type { MonitoringRule, SettingsPayload, SettingsView } from '../types'

  interface Props {
    onback: () => void
  }

  const { onback }: Props = $props()

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

<PageHeader
  title={$LL.serverSettings()}
  subtitle={serverNames.byServer[servers.currentId] ?? displayName(servers.current)}
  {onback}
  containerClass="max-w-3xl mx-auto px-4 sm:px-6 lg:px-8 w-full"
>
  {#snippet actions()}
    {#if settings}
      <Button size="sm" onclick={save} disabled={saving}>
        {saving ? $LL.saving() : $LL.save()}
      </Button>
    {/if}
  {/snippet}
</PageHeader>

<main class="max-w-3xl mx-auto px-4 sm:px-6 lg:px-8 py-8 space-y-6">
  {#if !servers.authenticated}
    <p class="text-sm text-muted-fg">{$LL.settingsNeedsAuth()}</p>
  {:else if loading}
    <div class="flex justify-center py-12"><Spinner size="lg" /></div>
  {:else if loadError}
    <p class="text-sm text-danger">{loadError}</p>
  {:else if settings}
    <!-- The API round-trip (network latency to a remote agent, unlike
         Dashboard's already-cached poller data or Panel Settings' no-fetch
         local prefs) can land after the page-level fly-in finishes — fade
         this in on its own instead of popping in abruptly -->
    <div in:fade={{ duration: 200 }} class="space-y-6">
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
      <Disclosure summary={$LL.moreDetails()}>
        <Markdown text={$LL.idlePauseNote()} class="text-xs text-faint-fg" />
      </Disclosure>
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
      <Disclosure summary={$LL.moreDetails()}>
        <div class="bg-soft/50 rounded-lg p-3 text-xs text-faint-fg leading-relaxed space-y-1">
          <Markdown text={$LL.ruleHelpType()} />
          <Markdown text={$LL.ruleHelpMatcher()} />
          <Markdown text={$LL.ruleHelpThreshold()} />
        </div>
      </Disclosure>
      <div class="divide-y divide-line">
        {#each rules as rule, i (i)}
          <div class="py-4 first:pt-0 last:pb-0">
            <div class="flex items-center gap-2 mb-2">
              <span class="text-sm text-faint-fg tabular-nums">{i + 1}</span>
              <span class="flex-1"></span>
              <IconButton label={$LL.removeRule()} class="hover:text-danger" onclick={() => removeRule(i)}>
                <Trash2 class="w-4 h-4" />
              </IconButton>
            </div>
            <div class="grid grid-cols-2 sm:grid-cols-4 gap-2">
              <div class="space-y-1">
                <span class="text-xs text-muted-fg">{$LL.ruleName()}</span>
                <Input placeholder={$LL.ruleNamePlaceholder()} bind:value={rule.name} />
              </div>
              <div class="space-y-1">
                <span class="text-xs text-muted-fg">{$LL.ruleType()}</span>
                <Input placeholder="cpu / memory / ..." bind:value={rule.monitor_type} />
              </div>
              <div class="space-y-1">
                <span class="text-xs text-muted-fg">{$LL.ruleThreshold()}</span>
                <Input placeholder={$LL.ruleThresholdPlaceholder()} bind:value={rule.threshold} />
              </div>
              <div class="space-y-1">
                <span class="text-xs text-muted-fg">{$LL.ruleMatcher()}</span>
                <Input placeholder={$LL.ruleMatcherPlaceholder()} bind:value={rule.matcher} />
              </div>
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
      <div class="divide-y divide-line">
        {#each corsOrigins as origin, i (i)}
          <div class="flex items-center gap-3 py-2 first:pt-0 last:pb-0">
            <span class="w-5 shrink-0 text-sm text-faint-fg tabular-nums">{i + 1}</span>
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
    </div>
  {/if}
</main>
