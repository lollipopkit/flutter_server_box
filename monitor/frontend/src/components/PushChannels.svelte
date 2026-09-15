<script lang="ts">
  import { ChevronDown, ChevronUp, Plus, Send, Trash2 } from '@lucide/svelte'
  import { Badge, Button, Card, IconButton, Input, Select, Spinner } from '@serverbox/webui'
  import { LL } from '../i18n/i18n-svelte'
  import { api, ApiError } from '../lib/api'
  import { servers } from '../lib/servers.svelte'
  import type { PushEntry, PushView } from '../types'
  import Disclosure from './Disclosure.svelte'
  import Markdown from './Markdown.svelte'

  /// A scalar setting of one channel, as a string because that is what an
  /// `<input>` holds. `kind` is recovered from what the agent sent so a number
  /// goes back a number — TOML is typed, and a port or an expected status
  /// arriving as a string would not compare against anything.
  interface FieldRow {
    key: string
    value: string
    kind: 'string' | 'number' | 'boolean'
    /// Arrived as `null`: set on the agent and deliberately not disclosed.
    /// Left blank, it goes back as `null`, which the agent reads as "keep".
    withheld: boolean
  }

  interface HeaderRow {
    key: string
    value: string
    withheld: boolean
  }

  /// A nested table other than `headers` — a webhook's `body_template`. Edited
  /// as JSON text because its shape is whatever the receiving service wants.
  interface JsonRow {
    key: string
    text: string
  }

  interface Draft {
    name: string
    push_type: string
    /// The position this channel was loaded from, and the only thing a
    /// withheld credential can be resolved against. `null` for a new one.
    from_index: number | null
    editable: boolean
    fields: FieldRow[]
    headers: HeaderRow[] | null
    json: JsonRow[]
    testing: boolean
    testResult: { ok: boolean; error?: string } | null
  }

  /// What a new channel of each type starts with — the same fields
  /// `config.example.toml` documents, so a channel added here looks like one
  /// written by hand. An existing channel is rendered from whatever the agent
  /// sent instead, so a key this list does not mention is still editable once
  /// it is in the file.
  const TEMPLATES: Record<string, Record<string, unknown>> = {
    webhook: {
      url: '',
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body_template: { message: 'Server {{name}}: {{message}}' },
    },
    serverchan: { sc_key: '', title: 'ServerBox Monitor', desp: '{{message}}' },
    bark: {
      server: 'https://api.day.app',
      key: '',
      title: 'ServerBox Monitor',
      body: '{{message}}',
      level: 'active',
    },
    ios: {
      token: '',
      title: 'ServerBox Monitor',
      content: '{{message}}',
      body_regex: '.*',
      code: 200,
    },
  }

  let loading = $state(true)
  let loadError = $state<string | null>(null)
  let saving = $state(false)
  let saveError = $state<string | null>(null)
  let saveOk = $state(false)

  let drafts = $state<Draft[]>([])
  let pushRate = $state('')
  let pushTypes = $state<string[]>([])
  let appliesOnRestart = $state(true)

  function toDraft(view: PushView, index: number): Draft {
    return {
      ...fromConfig(view.config),
      name: view.name,
      push_type: view.push_type,
      from_index: index,
      editable: view.editable,
      testing: false,
      testResult: null,
    }
  }

  /// Splits a channel's free-form config into the three things this editor can
  /// render. Anything that is not a scalar, `headers`, or a table becomes a
  /// JSON row rather than being dropped — losing a key on load would lose it on
  /// the next save too.
  function fromConfig(config: Record<string, unknown>): Pick<Draft, 'fields' | 'headers' | 'json'> {
    const fields: FieldRow[] = []
    const json: JsonRow[] = []
    let headers: HeaderRow[] | null = null

    for (const [key, value] of Object.entries(config)) {
      if (key === 'headers' && value !== null && typeof value === 'object') {
        headers = Object.entries(value as Record<string, unknown>).map(([name, header]) => ({
          key: name,
          value: header === null ? '' : String(header),
          withheld: header === null,
        }))
      } else if (value === null) {
        fields.push({ key, value: '', kind: 'string', withheld: true })
      } else if (typeof value === 'object') {
        json.push({ key, text: JSON.stringify(value, null, 2) })
      } else if (typeof value === 'number') {
        fields.push({ key, value: String(value), kind: 'number', withheld: false })
      } else if (typeof value === 'boolean') {
        fields.push({ key, value: String(value), kind: 'boolean', withheld: false })
      } else {
        fields.push({ key, value: String(value), kind: 'string', withheld: false })
      }
    }
    return { fields, headers, json }
  }

  /// The reverse, as the agent wants it. Throws with a message meant for the
  /// user, since the only way this fails is a body template that is not JSON.
  function toConfig(draft: Draft): Record<string, unknown> {
    const config: Record<string, unknown> = {}

    for (const field of draft.fields) {
      if (field.withheld) {
        // Blank means "keep": the value was never shown, so there is nothing
        // else an empty box could honestly be taken to mean.
        config[field.key] = field.value === '' ? null : field.value
        continue
      }
      // An empty box removes the key. Every sender reads its settings with a
      // default behind them, so absent and blank mean the same thing to the
      // agent — and absent is the one that lets the default apply.
      if (field.value === '') continue
      if (field.kind === 'number') {
        const parsed = Number(field.value)
        config[field.key] = Number.isFinite(parsed) ? parsed : field.value
      } else if (field.kind === 'boolean') {
        config[field.key] = field.value === 'true'
      } else {
        config[field.key] = field.value
      }
    }

    if (draft.headers) {
      const headers: Record<string, unknown> = {}
      for (const header of draft.headers) {
        const key = header.key.trim()
        if (!key) continue
        if (header.withheld) {
          headers[key] = header.value === '' ? null : header.value
        } else if (header.value !== '') {
          headers[key] = header.value
        }
      }
      if (Object.keys(headers).length > 0) config.headers = headers
    }

    for (const row of draft.json) {
      try {
        config[row.key] = JSON.parse(row.text)
      } catch {
        throw new Error(`${row.key} ${$LL.pushJsonInvalid()}`)
      }
    }
    return config
  }

  function toEntry(draft: Draft): PushEntry {
    return {
      name: draft.name.trim(),
      push_type: draft.push_type,
      from_index: draft.from_index,
      config: toConfig(draft),
    }
  }

  function applyLoaded(view: { pushes: PushView[]; push_rate: string | null; push_types: string[]; applies_on_restart: boolean }) {
    drafts = view.pushes.map(toDraft)
    pushRate = view.push_rate ?? ''
    pushTypes = view.push_types
    appliesOnRestart = view.applies_on_restart
  }

  async function load() {
    loading = true
    loadError = null
    try {
      applyLoaded(await api.getPush())
    } catch (e) {
      loadError = e instanceof ApiError ? e.message : String(e)
    } finally {
      loading = false
    }
  }

  $effect(() => {
    if (servers.authenticated) void load()
  })

  function addChannel() {
    const type = pushTypes[0] ?? 'webhook'
    drafts = [
      ...drafts,
      {
        name: '',
        push_type: type,
        from_index: null,
        editable: true,
        ...fromConfig(structuredClone(TEMPLATES[type] ?? {})),
        testing: false,
        testResult: null,
      },
    ]
  }

  function removeChannel(index: number) {
    drafts = drafts.filter((_, i) => i !== index)
  }

  function moveChannel(index: number, delta: number) {
    const to = index + delta
    if (to < 0 || to >= drafts.length) return
    const next = [...drafts]
    ;[next[index], next[to]] = [next[to], next[index]]
    drafts = next
  }

  /// Changing the type starts the settings over. The agent refuses to carry a
  /// credential across a type change — a Bark key is not an iOS token — so a
  /// form still showing "set, not disclosed" would be lying about what will be
  /// saved.
  function changeType(index: number, type: string) {
    const draft = drafts[index]
    drafts[index] = {
      ...draft,
      push_type: type,
      // And it is no longer the entry that was loaded from that position, so
      // nothing of the old one may be kept by pointing at it.
      from_index: null,
      ...fromConfig(structuredClone(TEMPLATES[type] ?? {})),
      testResult: null,
    }
  }

  function addHeader(index: number) {
    const draft = drafts[index]
    draft.headers = [...(draft.headers ?? []), { key: '', value: '', withheld: false }]
  }

  function removeHeader(index: number, headerIndex: number) {
    const draft = drafts[index]
    if (!draft.headers) return
    draft.headers = draft.headers.filter((_, i) => i !== headerIndex)
  }

  async function save() {
    saving = true
    saveError = null
    saveOk = false
    try {
      const payload = {
        pushes: drafts.map(toEntry),
        push_rate: pushRate.trim() === '' ? null : pushRate.trim(),
      }
      applyLoaded(await api.updatePush(payload))
      saveOk = true
    } catch (e) {
      saveError = e instanceof ApiError || e instanceof Error ? e.message : String(e)
    } finally {
      saving = false
    }
  }

  /// Sends through the channel as it is on screen, saved or not: the point is
  /// to find out whether what you just typed works, and a test that only
  /// covered what is already on disk would answer a different question.
  async function test(index: number) {
    const draft = drafts[index]
    draft.testing = true
    draft.testResult = null
    try {
      draft.testResult = await api.testPush(toEntry(draft), $LL.pushTestMessage())
    } catch (e) {
      draft.testResult = {
        ok: false,
        error: e instanceof ApiError || e instanceof Error ? e.message : String(e),
      }
    } finally {
      draft.testing = false
    }
  }
</script>

<Card class="space-y-4">
  <div class="flex items-center justify-between gap-2">
    <h2 class="text-base font-semibold font-display text-fg-strong">{$LL.pushChannels()}</h2>
    <div class="flex items-center gap-2">
      {#if appliesOnRestart}
        <Badge>{$LL.restartField()}</Badge>
      {/if}
      {#if !loading && !loadError}
        <Button size="sm" variant="secondary" onclick={save} disabled={saving}>
          {saving ? $LL.saving() : $LL.save()}
        </Button>
      {/if}
    </div>
  </div>

  <Disclosure summary={$LL.moreDetails()}>
    <Markdown text={$LL.pushNote()} class="text-xs text-faint-fg" />
  </Disclosure>

  {#if loading}
    <div class="flex justify-center py-8"><Spinner size="lg" /></div>
  {:else if loadError}
    <p class="text-sm text-danger">{loadError}</p>
  {:else}
    <div class="space-y-1">
      <span class="text-sm text-muted-fg">{$LL.pushRate()}</span>
      <Input placeholder={$LL.pushRatePlaceholder()} bind:value={pushRate} />
    </div>

    <div class="divide-y divide-line">
      {#each drafts as draft, i (i)}
        <div class="py-4 first:pt-0 last:pb-0 space-y-2">
          <div class="flex items-center gap-2">
            <span class="text-sm text-faint-fg tabular-nums">{i + 1}</span>
            <span class="flex-1"></span>
            {#if draft.editable}
              <IconButton label={$LL.pushTest()} disabled={draft.testing} onclick={() => test(i)}>
                <Send class="w-4 h-4" />
              </IconButton>
            {/if}
            <IconButton label={$LL.moveUp()} disabled={i === 0} onclick={() => moveChannel(i, -1)}>
              <ChevronUp class="w-4 h-4" />
            </IconButton>
            <IconButton
              label={$LL.moveDown()}
              disabled={i === drafts.length - 1}
              onclick={() => moveChannel(i, 1)}
            >
              <ChevronDown class="w-4 h-4" />
            </IconButton>
            <IconButton label={$LL.removePush()} class="hover:text-danger" onclick={() => removeChannel(i)}>
              <Trash2 class="w-4 h-4" />
            </IconButton>
          </div>

          <div class="grid grid-cols-1 sm:grid-cols-2 gap-2">
            <div class="space-y-1">
              <span class="text-xs text-muted-fg">{$LL.ruleName()}</span>
              <Input bind:value={draft.name} />
            </div>
            <div class="space-y-1">
              <span class="text-xs text-muted-fg">{$LL.ruleType()}</span>
              {#if draft.editable}
                <Select
                  class="w-full"
                  value={draft.push_type}
                  onchange={(e: Event) => changeType(i, (e.currentTarget as HTMLSelectElement).value)}
                >
                  {#each pushTypes as type (type)}
                    <option value={type}>{type}</option>
                  {/each}
                  <!-- A spelling the agent still accepts but does not offer
                       (the Go agent's `server_chan`) would otherwise vanish
                       from the list and take the channel's type with it. -->
                  {#if !pushTypes.includes(draft.push_type)}
                    <option value={draft.push_type}>{draft.push_type}</option>
                  {/if}
                </Select>
              {:else}
                <p class="py-2 text-sm font-mono">{draft.push_type}</p>
              {/if}
            </div>
          </div>

          {#if !draft.editable}
            <p class="text-xs text-faint-fg">{$LL.pushUnknownType()}</p>
          {:else}
            <div class="grid grid-cols-1 sm:grid-cols-2 gap-2">
              {#each draft.fields as field (field.key)}
                <div class="space-y-1">
                  <div class="flex items-center justify-between gap-2">
                    <span class="text-xs text-muted-fg font-mono">{field.key}</span>
                    {#if field.withheld}
                      <Badge tone="success">{$LL.pushSecretSet()}</Badge>
                    {/if}
                  </div>
                  {#if field.kind === 'boolean'}
                    <Select class="w-full" bind:value={field.value}>
                      <option value="true">true</option>
                      <option value="false">false</option>
                    </Select>
                  {:else}
                    <Input
                      type={field.kind === 'number' ? 'number' : 'text'}
                      placeholder={field.withheld ? $LL.pushSecretKeep() : ''}
                      bind:value={field.value}
                    />
                  {/if}
                </div>
              {/each}
            </div>

            {#if draft.headers}
              <div class="space-y-2">
                <span class="text-xs text-muted-fg font-mono">headers</span>
                {#each draft.headers as header, h (h)}
                  <div class="flex items-center gap-2">
                    <Input class="flex-1" placeholder="Authorization" bind:value={header.key} />
                    <Input
                      class="flex-1"
                      placeholder={header.withheld ? $LL.pushSecretKeep() : ''}
                      bind:value={header.value}
                    />
                    <IconButton
                      label={$LL.pushRemoveHeader()}
                      class="hover:text-danger shrink-0"
                      onclick={() => removeHeader(i, h)}
                    >
                      <Trash2 class="w-4 h-4" />
                    </IconButton>
                  </div>
                {/each}
                <Button variant="secondary" size="sm" onclick={() => addHeader(i)}>
                  <Plus class="w-4 h-4 mr-1" />{$LL.pushAddHeader()}
                </Button>
              </div>
            {/if}

            {#each draft.json as row (row.key)}
              <div class="space-y-1">
                <span class="text-xs text-muted-fg font-mono">{row.key}</span>
                <textarea
                  class="w-full rounded-lg bg-soft/50 border border-line px-3 py-2 text-sm font-mono
                         focus:outline-none focus:ring-2 focus:ring-accent/40"
                  rows="3"
                  bind:value={row.text}
                ></textarea>
              </div>
            {/each}
          {/if}

          {#if draft.testResult}
            {#if draft.testResult.ok}
              <p class="text-sm text-success">{$LL.pushTestOk()}</p>
            {:else}
              <p class="text-sm text-danger">{draft.testResult.error ?? $LL.pushTestFailed()}</p>
            {/if}
          {/if}
        </div>
      {/each}
    </div>

    <Button variant="secondary" size="sm" onclick={addChannel}>
      <Plus class="w-4 h-4 mr-1" />{$LL.addPush()}
    </Button>

    {#if saveError}
      <p class="text-sm text-danger">{saveError}</p>
    {/if}
    {#if saveOk}
      <p class="text-sm text-success">{$LL.settingsSaved()}</p>
    {/if}
  {/if}
</Card>
