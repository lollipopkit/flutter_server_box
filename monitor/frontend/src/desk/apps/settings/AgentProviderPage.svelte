<script lang="ts">
  /// One of Agent mode's providers, a page over Settings → Agent, saved with
  /// its own button: a built-in one is its key; an endpoint of the admin's
  /// own is where it is, what it speaks, its key, and the models it lists —
  /// listed from it as it is typed, as the apps' provider page does. `new`
  /// picks what to add.

  import { Button, Group, IconButton, Input, Row, Select, Spinner, Switch, Textarea } from '../../lk'
  import SettingsPage from './SettingsPage.svelte'
  import { LL } from '../../../i18n/i18n-svelte'
  import { agentApi, type AgentSettings, type Provider, type ProviderInfo, type SettingsWrite } from '../../../lib/agentApi'
  import { ApiError } from '../../../lib/api'
  import { servers } from '../../../lib/servers.svelte'
  import { API_OPTIONS, insecure, LISTING_APIS, newId, urlOk, withProvider, withoutProvider, writeOf } from './agentSettings'

  interface Props {
    /// A provider's id, `custom` for a new endpoint, `new` to pick.
    provider: string
    onback: () => void
    onopen: (provider: string) => void
  }

  const { provider, onback, onopen }: Props = $props()

  let loading = $state(true)
  let error = $state<string | null>(null)
  let saving = $state(false)
  let settings = $state<AgentSettings | null>(null)
  let catalog = $state<ProviderInfo[]>([])

  // An endpoint's form.
  let name = $state('')
  let api = $state<Provider['api']>('openai-completions')
  let baseUrl = $state('')
  let allowInsecure = $state(false)
  let extra = $state('')
  let apiKey = $state('')

  let listing = $state(false)
  let listed = $state<{ id: string; name: string }[] | null>(null)
  let listError = $state<string | null>(null)
  let timer: ReturnType<typeof setTimeout> | undefined
  let probe = 0

  const existing = $derived(settings?.providers?.find((p) => p.id === provider) ?? null)
  const builtin = $derived(catalog.find((p) => p.id === provider && !p.custom) ?? null)
  const kind = $derived(provider === 'new' ? 'pick' : provider === 'custom' || existing ? 'custom' : 'builtin')
  const keyed = $derived((settings?.credentials ?? []).includes(provider))

  async function load() {
    const entry = servers.current
    if (!entry) return
    loading = true
    error = null
    try {
      settings = await agentApi.settings(entry)
      const p = settings.providers?.find((x) => x.id === provider)
      if (p) {
        name = p.name
        api = p.api
        baseUrl = p.baseUrl
        allowInsecure = p.allowInsecure
        extra = p.models.map((m) => m.id).join('\n')
      }
      apiKey = ''
      // The catalog names the built-in providers; an endpoint does not wait for it.
      if (!p) catalog = await agentApi.models(entry)
      else void agentApi.models(entry).then((c) => (catalog = c)).catch(() => {})
    } catch (e) {
      error = e instanceof Error ? e.message : String(e)
    } finally {
      loading = false
    }
    if (kind === 'custom') void list()
  }

  $effect(() => {
    void provider
    void servers.currentId
    void load()
  })

  const extraIds = $derived(
    extra
      .split(/[,\n]/)
      .map((l) => l.trim())
      .filter(Boolean),
  )

  function listSoon() {
    clearTimeout(timer)
    timer = setTimeout(() => void list(), 600)
  }

  /// Asks the endpoint for its models; a later ask supersedes an earlier one.
  async function list() {
    const entry = servers.current
    const n = ++probe
    if (!entry || !LISTING_APIS.includes(api) || !urlOk(baseUrl)) {
      listed = null
      listError = null
      listing = false
      return
    }
    listing = true
    listError = null
    try {
      const models = await agentApi.probe(entry, {
        api,
        baseUrl: baseUrl.trim(),
        allowInsecure: insecure(baseUrl) && allowInsecure,
        apiKey: apiKey.trim() || undefined,
        providerId: existing && keyed ? existing.id : undefined,
      })
      if (n !== probe) return
      listed = models
    } catch (e) {
      if (n !== probe) return
      listed = null
      listError = e instanceof ApiError ? ((e.body?.reason as string | undefined) ?? e.message) : String(e)
    } finally {
      if (n === probe) listing = false
    }
  }

  async function write(change: (w: SettingsWrite) => SettingsWrite, then: () => void = onback) {
    const entry = servers.current
    if (!entry || !settings || saving) return
    saving = true
    error = null
    try {
      settings = await agentApi.saveSettings(entry, change(writeOf(settings)))
      then()
    } catch (e) {
      error = e instanceof Error ? e.message : String(e)
    } finally {
      saving = false
    }
  }

  function saveBuiltin() {
    const key = apiKey.trim()
    if (!key) return onback()
    void write((w) => ({ ...w, credentials: { [provider]: key } }))
  }

  function saveCustom() {
    if (!name.trim() || !urlOk(baseUrl)) {
      error = $LL.settingsAgentEndpointIncomplete()
      return
    }
    if (!LISTING_APIS.includes(api) && !extraIds.length) {
      error = $LL.settingsAgentModelsRequired()
      return
    }
    const id = existing?.id ?? newId(name, [...(settings?.providers ?? []).map((p) => p.id), ...catalog.map((p) => p.id)])
    const p: Provider = {
      id,
      name: name.trim(),
      api,
      baseUrl: baseUrl.trim(),
      allowInsecure: insecure(baseUrl) && allowInsecure,
      models: extraIds.map((mid) => ({ id: mid })),
    }
    const key = apiKey.trim()
    void write((w) => {
      const next = withProvider(w, p)
      // An endpoint that takes no key still needs a credential, an empty one,
      // to be usable (as the apps do it).
      return key || !keyed ? { ...next, credentials: { [id]: key } } : next
    })
  }

  const title = $derived(
    kind === 'pick'
      ? $LL.settingsAgentAddProvider()
      : kind === 'builtin'
        ? (builtin?.name ?? provider)
        : name.trim() || $LL.settingsAgentCustomEndpoint(),
  )
  const unkeyedBuiltins = $derived(catalog.filter((p) => !p.custom && !(settings?.credentials ?? []).includes(p.id)))
</script>

<SettingsPage {title} back={onback}>
  {#snippet actions()}
    {#if kind !== 'pick' && !loading}
      <Button variant="primary" size="sm" icon="save" disabled={saving} onclick={kind === 'builtin' ? saveBuiltin : saveCustom}>{$LL.save()}</Button>
    {/if}
  {/snippet}

  {#if loading}
    <div class="grid place-items-center py-[34px]"><Spinner /></div>
  {:else}
    {#if error}<p class="px-[2px] text-[13px] text-(--color-danger)">{error}</p>{/if}

    {#if kind === 'pick'}
      <Group>
        <Row label={$LL.settingsAgentCustomEndpoint()} sub={$LL.settingsAgentCustomEndpointHint()} onclick={() => onopen('custom')} />
      </Group>
      <Group title={$LL.settingsAgentBuiltin()}>
        {#each unkeyedBuiltins as p (p.id)}
          <Row label={p.name} sub={$LL.settingsAgentModelsCount({ n: p.models.length })} onclick={() => onopen(p.id)} />
        {/each}
      </Group>
    {:else if kind === 'builtin'}
      <Group>
        <div class="flex flex-col gap-[11px] px-[13px] py-[13px]">
          <Input
            type="password"
            autocomplete="off"
            label={$LL.settingsAgentKey()}
            placeholder={keyed ? $LL.settingsAgentKeySet() : ''}
            bind:value={apiKey}
          />
          {#if builtin}<span class="text-[12px] text-(--text-tertiary)">{$LL.settingsAgentModelsCount({ n: builtin.models.length })}</span>{/if}
        </div>
      </Group>
      {#if keyed}
        <div>
          <Button variant="ghost" icon="key_off" disabled={saving} onclick={() => write((w) => ({ ...w, model: w.model?.provider === provider ? null : w.model, credentials: { [provider]: null } }))}>
            {$LL.settingsAgentKeyClear()}
          </Button>
        </div>
      {/if}
    {:else}
      <Group>
        <div class="flex flex-col gap-[11px] px-[13px] py-[13px]">
          <Input label={$LL.settingsAgentProviderName()} bind:value={name} />
          <Select label={$LL.settingsAgentApi()} bind:value={api} options={[...API_OPTIONS]} onchange={listSoon} />
          <Input label={$LL.settingsAgentBaseUrl()} mono placeholder="https://api.example.com/v1" bind:value={baseUrl} oninput={listSoon} />
          {#if insecure(baseUrl)}
            <div class="flex items-center gap-[11px]">
              <div class="flex min-w-0 flex-1 flex-col gap-[1px]">
                <span class="text-[13px]">{$LL.settingsAgentAllowInsecure()}</span>
                <span class="text-[12px] text-(--text-tertiary)">{$LL.settingsAgentInsecureHint()}</span>
              </div>
              <Switch bind:checked={allowInsecure} label={$LL.settingsAgentAllowInsecure()} onchange={listSoon} />
            </div>
          {/if}
          <Input
            type="password"
            autocomplete="off"
            label={$LL.settingsAgentKey()}
            placeholder={keyed ? $LL.settingsAgentKeySet() : ''}
            bind:value={apiKey}
            oninput={listSoon}
          />
        </div>
      </Group>

      <Group title={$LL.settingsAgentModel()}>
        <div class="flex flex-col gap-[9px] px-[13px] py-[13px]">
          <div class="flex items-center gap-[7px] text-[12px] text-(--text-secondary)">
            {#if !LISTING_APIS.includes(api)}
              <span>{$LL.settingsAgentNoListing()}</span>
            {:else if listing}
              <Spinner size="sm" /><span>{$LL.settingsAgentDiscovering()}</span>
            {:else if listError}
              <span class="break-all text-(--color-danger)">{listError}</span>
            {:else if listed}
              <span>{$LL.settingsAgentDiscovered({ n: listed.length })}</span>
            {/if}
            {#if LISTING_APIS.includes(api) && urlOk(baseUrl) && !listing}
              <IconButton icon="refresh" label={$LL.settingsAgentDiscover()} size="sm" onclick={list} />
            {/if}
          </div>
          {#if listed?.length}
            <div class="flex max-h-[160px] flex-wrap gap-[5px] overflow-y-auto">
              {#each listed as m (m.id)}
                <span class="lk-mono rounded-(--radius-xs) bg-(--surface-card) px-[7px] py-[2px] text-[11px] text-(--text-secondary)">{m.id}</span>
              {/each}
            </div>
          {/if}
          <Textarea label={$LL.settingsAgentExtraModels()} hint={$LL.settingsAgentExtraHint()} mono rows={2} bind:value={extra} />
        </div>
      </Group>

      {#if existing}
        <div class="flex gap-[7px]">
          {#if keyed}
            <Button variant="ghost" icon="key_off" disabled={saving} onclick={() => write((w) => ({ ...w, credentials: { [existing.id]: null } }), () => {})}>
              {$LL.settingsAgentKeyClear()}
            </Button>
          {/if}
          <Button variant="ghost" icon="delete" disabled={saving} onclick={() => write((w) => withoutProvider(w, existing.id))}>
            {$LL.settingsAgentRemoveProvider()}
          </Button>
        </div>
      {/if}
    {/if}
  {/if}
</SettingsPage>
