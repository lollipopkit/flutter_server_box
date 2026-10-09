<script lang="ts">
  import { Badge, Button, Group, IconButton, Input, Row, Select, Spinner, Textarea } from '../../lk'
  import { LL } from '../../../i18n/i18n-svelte'
  import { api, ApiError } from '../../../lib/api'
  import { servers } from '../../../lib/servers.svelte'
  import type { PushEntry, PushView } from '../../../types'
  import Disclosure from '../../../components/Disclosure.svelte'
  import Markdown from '../../../components/Markdown.svelte'

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
    /// Not in the channel's config, offered from its type's template so a
    /// setting left out before can still be filled in. Left blank, or off for
    /// a switch, it stays absent and the agent's default applies.
    optional: boolean
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

  type Kind = FieldRow['kind']

  interface Template {
    /// What a new channel starts with — the same fields `config.example.toml`
    /// documents, so a channel added here looks like one written by hand.
    values: Record<string, unknown>
    /// Settings the type also reads, offered blank.
    more?: Record<string, Kind>
  }

  /// Per type. An existing channel is rendered from whatever the agent sent,
  /// plus the template's keys it does not have, offered blank; a key this list
  /// does not mention is still editable once it is in the file.
  const TEMPLATES: Record<string, Template> = {
    webhook: {
      values: {
        url: '',
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body_template: { message: 'Server {{name}}: {{message}}' },
      },
    },
    serverchan: { values: { sc_key: '', title: 'ServerBox Monitor', desp: '{{message}}' } },
    bark: {
      values: {
        server: 'https://api.day.app',
        key: '',
        title: 'ServerBox Monitor',
        body: '{{message}}',
        level: 'active',
      },
      more: {
        subtitle: 'string',
        sound: 'string',
        group: 'string',
        icon: 'string',
        image: 'string',
        url: 'string',
        copy: 'string',
        action: 'string',
        badge: 'number',
        volume: 'number',
        ttl: 'number',
        markdown: 'boolean',
        call: 'boolean',
        auto_copy: 'boolean',
        is_archive: 'boolean',
        cipher_key: 'string',
      },
    },
    ios: {
      values: {
        token: '',
        title: 'ServerBox Monitor',
        content: '{{message}}',
        body_regex: '.*',
        code: 200,
      },
    },
    smtp: {
      values: {
        host: '',
        security: 'starttls',
        username: '',
        password: '',
        from: '',
        to: '',
        subject: 'ServerBox Monitor: {{name}}',
        body: '{{message}}',
      },
      more: { port: 'number' },
    },
    telegram: {
      values: { bot_token: '', chat_id: '', text: '{{name}}: {{message}}' },
      more: {
        parse_mode: 'string',
        message_thread_id: 'number',
        disable_notification: 'boolean',
        disable_link_preview: 'boolean',
        api_base: 'string',
      },
    },
    discord: {
      values: { webhook_url: '', content: '{{name}}: {{message}}' },
      // A thread id is a snowflake, past what a number holds exactly.
      more: { username: 'string', avatar_url: 'string', thread_id: 'string' },
    },
    ntfy: {
      values: { server: 'https://ntfy.sh', topic: '', title: '{{name}}', message: '{{message}}' },
      more: {
        priority: 'string',
        tags: 'string',
        click: 'string',
        icon: 'string',
        attach: 'string',
        delay: 'string',
        email: 'string',
        markdown: 'boolean',
        token: 'string',
        username: 'string',
        password: 'string',
      },
    },
  }

  function kindOf(value: unknown): Kind | null {
    if (typeof value === 'number') return 'number'
    if (typeof value === 'boolean') return 'boolean'
    if (typeof value === 'string') return 'string'
    return null
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
      ...fromConfig(view.config, TEMPLATES[view.push_type]),
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
  function fromConfig(config: Record<string, unknown>, template?: Template): Pick<Draft, 'fields' | 'headers' | 'json'> {
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
        fields.push({ key, value: '', kind: 'string', withheld: true, optional: false })
      } else if (typeof value === 'object') {
        json.push({ key, text: JSON.stringify(value, null, 2) })
      } else {
        fields.push({ key, value: String(value), kind: kindOf(value) ?? 'string', withheld: false, optional: false })
      }
    }

    const offered: [string, Kind | null][] = [
      ...Object.entries(template?.values ?? {}).map(([key, value]): [string, Kind | null] => [key, kindOf(value)]),
      ...Object.entries(template?.more ?? {}),
    ]
    for (const [key, kind] of offered) {
      if (kind === null || key in config) continue
      fields.push({ key, value: kind === 'boolean' ? 'false' : '', kind, withheld: false, optional: true })
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
      if (field.optional && field.kind === 'boolean' && field.value === 'false') continue
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

  function fromTemplate(type: string): Pick<Draft, 'fields' | 'headers' | 'json'> {
    const template = TEMPLATES[type]
    return fromConfig(structuredClone(template?.values ?? {}), template)
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
        ...fromTemplate(type),
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
      ...fromTemplate(type),
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

<Group title={$LL.pushChannels()}>
  <div class="flex items-center justify-between gap-[9px] border-b border-(--border-hairline) py-[7px]">
    <Row label={$LL.pushChannels()}>
      {#if appliesOnRestart}<Badge>{$LL.restartField()}</Badge>{/if}
    </Row>
    {#if !loading && !loadError}
      <Button size="sm" variant="primary" disabled={saving} onclick={save}>{saving ? $LL.saving() : $LL.save()}</Button>
    {/if}
  </div>

  <div class="border-b border-(--border-hairline) py-[9px]">
    <Disclosure summary={$LL.moreDetails()}>
      <Markdown text={$LL.pushNote()} class="text-[12px] text-(--text-tertiary)" />
    </Disclosure>
  </div>

  {#if loading}
    <div class="flex justify-center py-[13px]"><Spinner size={48} /></div>
  {:else if loadError}
    <p class="py-[7px] text-[13px] text-(--color-danger)">{loadError}</p>
  {:else}
    <Row label={$LL.pushRate()}>
      <Input class="w-[170px]" placeholder={$LL.pushRatePlaceholder()} bind:value={pushRate} />
    </Row>

    {#each drafts as draft, i (i)}
      <div class="space-y-[9px] border-b border-(--border-hairline) py-[9px] last:border-0">
        <div class="flex items-center gap-[5px]">
          <span class="lk-num text-[12px] text-(--text-tertiary)">{i + 1}</span>
          <span class="flex-1"></span>
          {#if draft.editable}<IconButton icon="send" label={$LL.pushTest()} disabled={draft.testing} onclick={() => test(i)} />{/if}
          <IconButton icon="arrow_upward" label={$LL.moveUp()} disabled={i === 0} onclick={() => moveChannel(i, -1)} />
          <IconButton icon="arrow_downward" label={$LL.moveDown()} disabled={i === drafts.length - 1} onclick={() => moveChannel(i, 1)} />
          <IconButton icon="delete" label={$LL.removePush()} onclick={() => removeChannel(i)} />
        </div>

        <div class="grid grid-cols-1 gap-[9px] @2xl:grid-cols-2">
          <Input label={$LL.ruleName()} bind:value={draft.name} />
          {#if draft.editable}
            <Select
              label={$LL.ruleType()}
              class="w-full"
              value={draft.push_type}
              options={[
                ...pushTypes.map((type) => ({ value: type, label: type })),
                ...(!pushTypes.includes(draft.push_type) ? [{ value: draft.push_type, label: draft.push_type }] : []),
              ]}
              onchange={(event: Event) => changeType(i, (event.currentTarget as HTMLSelectElement).value)}
            />
          {:else}
            <div class="lk-field"><span class="lk-field__label">{$LL.ruleType()}</span><p class="lk-mono text-[13px]">{draft.push_type}</p></div>
          {/if}
        </div>

        {#if !draft.editable}
          <p class="text-[12px] text-(--text-tertiary)">{$LL.pushUnknownType()}</p>
        {:else}
          <div class="grid grid-cols-1 gap-[9px] @2xl:grid-cols-2">
            {#each draft.fields as field (field.key)}
              {#if field.kind === 'boolean'}
                <Row label={field.key}>
                  {#if field.withheld}<Badge tone="success">{$LL.pushSecretSet()}</Badge>{/if}
                  <Select class="w-[170px]" bind:value={field.value} options={[{ value: 'true', label: 'true' }, { value: 'false', label: 'false' }]} />
                </Row>
              {:else}
                <Input
                  label={field.key}
                  class="font-mono"
                  type={field.kind === 'number' ? 'number' : 'text'}
                  placeholder={field.withheld ? $LL.pushSecretKeep() : ''}
                  bind:value={field.value}
                />
                {#if field.withheld}<Badge tone="success">{$LL.pushSecretSet()}</Badge>{/if}
              {/if}
            {/each}
          </div>

          {#if draft.headers}
            <div class="space-y-[7px]">
              <span class="lk-caps">headers</span>
              {#each draft.headers as header, h (h)}
                <div class="flex items-center gap-[7px]">
                  <Input class="flex-1" placeholder="Authorization" bind:value={header.key} />
                  <Input class="flex-1" placeholder={header.withheld ? $LL.pushSecretKeep() : ''} bind:value={header.value} />
                  <IconButton icon="delete" label={$LL.pushRemoveHeader()} onclick={() => removeHeader(i, h)} />
                </div>
              {/each}
              <Button variant="tinted" size="sm" icon="add" onclick={() => addHeader(i)}>{$LL.pushAddHeader()}</Button>
            </div>
          {/if}

          {#each draft.json as jsonRow (jsonRow.key)}
            <Textarea label={jsonRow.key} rows={3} bind:value={jsonRow.text} mono />
          {/each}
        {/if}

        {#if draft.testResult}
          {#if draft.testResult.ok}
            <p class="text-[13px] text-(--color-success)">{$LL.pushTestOk()}</p>
          {:else}
            <p class="text-[13px] text-(--color-danger)">{draft.testResult.error ?? $LL.pushTestFailed()}</p>
          {/if}
        {/if}
      </div>
    {/each}

    <div class="flex flex-wrap items-center gap-[9px] py-[7px]">
      <Button variant="tinted" size="sm" icon="add" onclick={addChannel}>{$LL.addPush()}</Button>
      {#if saving}<Spinner size={16} />{/if}
    </div>
    {#if saveError}<p class="py-[7px] text-[13px] text-(--color-danger)">{saveError}</p>{/if}
    {#if saveOk}<p class="py-[7px] text-[13px] text-(--color-success)">{$LL.settingsSaved()}</p>{/if}
  {/if}
</Group>
