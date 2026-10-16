<script lang="ts">
  /// The MCP servers whose tools Agent mode's tasks get (`/agent/mcp`), a
  /// page over Settings → Agent. Each server is its address and the headers
  /// sent with it (a token): a header's value is written, never shown again.
  /// What each one is doing (connected, its tools, why not) is the agent's
  /// answer to the last read or save.

  import { Badge, Button, Group, IconButton, Input, Row, Spinner, Switch } from '../../lk'
  import { errorText } from '../../../lib/errorText'
  import SettingsPage from './SettingsPage.svelte'
  import { LL } from '../../../i18n/i18n-svelte'
  import { agentApi, type McpServerWrite, type McpView } from '../../../lib/agentApi'
  import { ApiError } from '../../../lib/api'
  import { servers } from '../../../lib/servers.svelte'

  interface Props {
    onback: () => void
  }

  const { onback }: Props = $props()

  let loading = $state(true)
  let saving = $state(false)
  let error = $state<string | null>(null)
  let view = $state<McpView | null>(null)
  /// The server whose tools are listed.
  let open = $state<string | null>(null)
  /// A server being added.
  let name = $state('')
  let url = $state('')
  let header = $state('Authorization')
  let token = $state('')

  function reason(e: unknown): string {
    if (e instanceof ApiError) return (e.body?.reason as string | undefined) ?? e.message
    return errorText(e)
  }

  async function load() {
    const entry = servers.current
    if (!entry) return
    loading = true
    error = null
    try {
      view = await agentApi.mcp(entry)
    } catch (e) {
      error = reason(e)
    } finally {
      loading = false
    }
  }

  $effect(() => {
    void servers.currentId
    void load()
  })

  /// Every server as it is, headers kept: what a change starts from.
  const current = (): McpServerWrite[] => (view?.servers ?? []).map((s) => ({ name: s.name, url: s.url, enabled: s.enabled }))

  async function save(next: McpServerWrite[]): Promise<boolean> {
    const entry = servers.current
    if (!entry || saving) return false
    saving = true
    error = null
    try {
      view = await agentApi.saveMcp(entry, next)
      return true
    } catch (e) {
      error = reason(e)
      return false
    } finally {
      saving = false
    }
  }

  async function add() {
    const s: McpServerWrite = { name: name.trim(), url: url.trim(), enabled: true }
    if (header.trim() && token) s.headers = { [header.trim()]: token }
    if (await save([...current(), s])) {
      name = url = token = ''
      header = 'Authorization'
    }
  }

  const status = (id: string) => view?.status.find((s) => s.id === id)
</script>

<SettingsPage title={$LL.settingsAgentMcp()} back={onback} description={$LL.settingsAgentMcpAbout()}>
  {#snippet actions()}
    {#if saving}<Spinner size="sm" />{/if}
  {/snippet}

  {#if loading}
    <div class="grid place-items-center py-[34px]"><Spinner /></div>
  {:else}
    {#if error}<p class="px-[2px] text-[13px] break-all text-(--color-danger)">{error}</p>{/if}

    {#each view?.servers ?? [] as s, i (s.id)}
      {@const st = status(s.id)}
      <Group title={s.name}>
        <Row label={s.url} mono sub={s.headers.length ? $LL.settingsAgentMcpHeaders({ names: s.headers.join(', ') }) : undefined}>
          <Switch
            label={$LL.settingsAgentMcpEnabled()}
            checked={s.enabled}
            disabled={saving}
            onchange={(on) => void save(current().map((w, j) => (j === i ? { ...w, enabled: on } : w)))}
          />
        </Row>
        {#if s.enabled}
          <Row
            label={$LL.settingsAgentMcpStatus()}
            sub={st?.error ?? undefined}
            onclick={st?.connected ? () => (open = open === s.id ? null : s.id) : undefined}
          >
            {#if st?.connected}
              <Badge tone="success">{$LL.settingsAgentMcpTools({ n: st.tools.length })}</Badge>
            {:else}
              <Badge tone="danger">{$LL.settingsAgentMcpOffline()}</Badge>
            {/if}
          </Row>
          {#if open === s.id && st}
            {#each st.tools as t (t.name)}
              <Row label={t.title ?? t.name} mono={!t.title} sub={t.description}>
                {#if t.readOnly}<Badge>{$LL.settingsAgentMcpReadOnly()}</Badge>{/if}
              </Row>
            {/each}
          {/if}
        {/if}
        <div class="flex flex-wrap items-center gap-[9px] px-[13px] py-[9px]">
          <Input
            class="min-w-[180px] flex-1"
            type="password"
            autocomplete="off"
            placeholder={$LL.settingsAgentMcpReplaceToken({ header: s.headers[0] ?? 'Authorization' })}
            disabled={saving}
            onchange={(e: Event) => {
              const v = (e.currentTarget as HTMLInputElement).value
              if (v) void save(current().map((w, j) => (j === i ? { ...w, headers: { [s.headers[0] ?? 'Authorization']: v } } : w)))
            }}
          />
          <IconButton
            icon="delete"
            label={$LL.settingsAgentMcpRemove()}
            disabled={saving}
            onclick={() => void save(current().filter((_, j) => j !== i))}
          />
        </div>
      </Group>
    {:else}
      <p class="px-[2px] text-[13px] text-(--text-tertiary)">{$LL.settingsAgentMcpEmpty()}</p>
    {/each}

    <Group title={$LL.settingsAgentMcpAdd()}>
      <div class="flex flex-col gap-[11px] px-[13px] py-[13px]">
        <Input label={$LL.settingsAgentMcpName()} placeholder="Home Assistant" bind:value={name} />
        <Input label={$LL.settingsAgentMcpUrl()} mono placeholder="https://example.com/mcp" bind:value={url} hint={$LL.settingsAgentMcpUrlHint()} />
        <div class="flex flex-wrap gap-[11px]">
          <Input class="w-[160px]" label={$LL.settingsAgentMcpHeader()} mono bind:value={header} />
          <Input class="min-w-[180px] flex-1" label={$LL.settingsAgentMcpToken()} type="password" autocomplete="off" bind:value={token} />
        </div>
        <div>
          <Button variant="primary" icon="add" disabled={saving || !name.trim() || !url.trim()} onclick={add}>{$LL.settingsAgentMcpAdd()}</Button>
        </div>
      </div>
    </Group>
  {/if}
</SettingsPage>
