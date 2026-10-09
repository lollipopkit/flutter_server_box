<script lang="ts">
  /// Agent mode's configuration (`/agent/settings`): the model the agent's
  /// tasks run with, applied as it is chosen, and the providers it reaches —
  /// each one a page of its own (`AgentProviderPage`), saved there. Built-in
  /// providers need only a key; an endpoint of the admin's own needs where it
  /// is and what it speaks.

  import { Group, Row, SegmentedControl, Select, Spinner } from '../../lk'
  import SettingsPage from './SettingsPage.svelte'
  import { LL } from '../../../i18n/i18n-svelte'
  import { agentApi, type AgentSettings, type ProviderInfo, type SettingsWrite } from '../../../lib/agentApi'
  import { capabilitiesStore } from '../../../lib/capabilities.svelte'
  import { servers } from '../../../lib/servers.svelte'
  import { writeOf } from './agentSettings'

  interface Props {
    /// Opens a provider's page: its id, or `new` to add one.
    onprovider: (id: string) => void
    /// Opens the account's memory.
    onmemory: () => void
    /// Opens how commands are approved.
    onpermissions: () => void
  }

  const { onprovider, onmemory, onpermissions }: Props = $props()

  const caps = $derived(capabilitiesStore.byServer[servers.currentId])
  const admin = $derived(caps?.me?.admin === true)

  let loading = $state(true)
  let error = $state<string | null>(null)
  let saving = $state(false)
  let saved = $state(false)
  let settings = $state<AgentSettings | null>(null)
  let catalog = $state<ProviderInfo[]>([])
  let listing = $state(false)

  const ref = (provider: string, id: string) => `${provider}\u0000${id}`
  const model = $derived(settings?.model ? ref(settings.model.provider, settings.model.id) : '')

  async function load() {
    const entry = servers.current
    if (!entry) return
    loading = true
    error = null
    try {
      settings = await agentApi.settings(entry)
    } catch (e) {
      error = e instanceof Error ? e.message : String(e)
    } finally {
      loading = false
    }
    if (admin) void loadCatalog()
  }

  async function loadCatalog() {
    const entry = servers.current
    if (!entry) return
    listing = true
    try {
      catalog = await agentApi.models(entry)
    } catch (e) {
      error = e instanceof Error ? e.message : String(e)
    } finally {
      listing = false
    }
  }

  $effect(() => {
    void servers.currentId
    void load()
  })

  /// Applies [change] to what the agent last said, at once.
  async function apply(change: (w: SettingsWrite) => SettingsWrite) {
    const entry = servers.current
    if (!entry || !settings || saving) return
    saving = true
    saved = false
    error = null
    try {
      settings = await agentApi.saveSettings(entry, change(writeOf(settings)))
      saved = true
      setTimeout(() => (saved = false), 1500)
    } catch (e) {
      error = e instanceof Error ? e.message : String(e)
    } finally {
      saving = false
    }
  }

  const keyed = (id: string) => (settings?.credentials ?? []).includes(id)
  const builtinsKeyed = $derived(catalog.filter((p) => !p.custom && keyed(p.id)))

  /// Every model of a provider that can be reached: a built-in one with a
  /// key, and every endpoint here.
  const modelOptions = $derived.by(() => {
    const out: { value: string; label: string }[] = [{ value: '', label: $LL.settingsAgentNoModel() }]
    const add = (provider: string, label: string, id: string, name?: string) => {
      const value = ref(provider, id)
      if (!out.some((o) => o.value === value)) out.push({ value, label: `${label} · ${name || id}` })
    }
    for (const p of catalog) if (p.custom || keyed(p.id)) for (const m of p.models) add(p.id, p.name, m.id, m.name)
    for (const p of settings?.providers ?? []) for (const m of p.models) add(p.id, p.name, m.id, m.name)
    if (model && !out.some((o) => o.value === model)) {
      const [provider, id] = model.split('\u0000')
      out.push({ value: model, label: `${provider} · ${id}` })
    }
    return out
  })

  function pickModel(v: string) {
    if (v === model) return
    const [provider, id] = v ? v.split('\u0000') : []
    void apply((w) => ({ ...w, model: v ? { provider, id } : null }))
  }

  const apiLabel: Record<string, string> = {
    'openai-completions': 'OpenAI Chat Completions',
    'openai-responses': 'OpenAI Responses',
    'anthropic-messages': 'Anthropic Messages',
    'google-generative-ai': 'Google Generative AI',
  }
</script>

{#snippet memoryRow()}
  <Group>
    <Row label={$LL.settingsAgentPermissions()} sub={$LL.settingsAgentPermissionsSub()} onclick={onpermissions} />
    <Row label={$LL.settingsAgentMemory()} sub={$LL.settingsAgentMemorySub()} onclick={onmemory} />
  </Group>
{/snippet}

<SettingsPage title={$LL.settingsAgent()} description={$LL.settingsAgentAbout()}>
  {#snippet actions()}
    {#if saving || listing}<Spinner size="sm" />{:else if saved}<span class="text-[12px] text-(--text-tertiary)">{$LL.settingsAgentSaved()}</span>{/if}
  {/snippet}

  {#if loading}
    <div class="grid place-items-center py-[34px]"><Spinner /></div>
  {:else}
    {#if error}<p class="px-[2px] text-[13px] text-(--color-danger)">{error}</p>{/if}
    {#if !admin}
      <Group>
        <Row label={$LL.settingsAgentModel()} value={settings?.model ? `${settings.model.provider} · ${settings.model.id}` : $LL.settingsAgentNoModel()} />
        <Row label={$LL.settingsAgentThinking()} value={settings?.thinkingLevel ?? 'off'} />
        <Row label={$LL.settingsAgentMaxRunning()} value={String(settings?.maxRunning ?? 3)} />
      </Group>
      <p class="px-[2px] text-[12px] text-(--text-tertiary)">{$LL.settingsAgentAdminOnly()}</p>
      {@render memoryRow()}
    {:else if settings}
      <Group>
        <Row label={$LL.settingsAgentModel()}>
          <Select value={model} options={modelOptions} disabled={saving} onchange={(e: Event) => pickModel((e.currentTarget as HTMLSelectElement).value)} />
        </Row>
        <Row label={$LL.settingsAgentThinking()}>
          <SegmentedControl
            size="sm"
            value={settings.thinkingLevel}
            disabled={saving}
            onchange={(v) => apply((w) => ({ ...w, thinkingLevel: v }))}
            options={[
              { value: 'off', label: $LL.settingsAgentThinkingOff() },
              { value: 'low', label: $LL.settingsAgentThinkingLow() },
              { value: 'medium', label: $LL.settingsAgentThinkingMedium() },
              { value: 'high', label: $LL.settingsAgentThinkingHigh() },
            ]}
          />
        </Row>
        <Row label={$LL.settingsAgentMaxRunning()}>
          <Select
            value={settings.maxRunning}
            disabled={saving}
            options={[1, 2, 3, 4, 5, 6, 7, 8].map((n) => ({ value: n, label: String(n) }))}
            onchange={(e: Event) => {
              const n = Number((e.currentTarget as HTMLSelectElement).value)
              void apply((w) => ({ ...w, maxRunning: n }))
            }}
          />
        </Row>
      </Group>

      <Group title={$LL.settingsAgentProviders()}>
        {#each builtinsKeyed as p (p.id)}
          <Row label={p.name} sub={$LL.settingsAgentBuiltinKeyed()} onclick={() => onprovider(p.id)} />
        {/each}
        {#each settings.providers ?? [] as p (p.id)}
          <Row
            label={p.name}
            sub={`${p.baseUrl} · ${apiLabel[p.api] ?? p.api}${keyed(p.id) ? '' : ` · ${$LL.settingsAgentNoKey()}`}`}
            onclick={() => onprovider(p.id)}
          />
        {/each}
        <Row label={$LL.settingsAgentAddProvider()} onclick={() => onprovider('new')} />
      </Group>
      {@render memoryRow()}
    {/if}
  {/if}
</SettingsPage>
