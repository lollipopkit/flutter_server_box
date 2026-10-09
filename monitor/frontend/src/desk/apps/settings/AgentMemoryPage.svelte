<script lang="ts">
  /// The account's memory: the text files the agent keeps across its tasks
  /// (`/agent/memory`), a page over Settings → Agent. With [file], one of
  /// them to read, change or delete; an empty [file] is a new one.

  import { Button, Group, Input, Row, Spinner, Textarea } from '../../lk'
  import SettingsPage from './SettingsPage.svelte'
  import { LL } from '../../../i18n/i18n-svelte'
  import { agentApi, type MemoryFileInfo } from '../../../lib/agentApi'
  import { ApiError } from '../../../lib/api'
  import { fmtDate } from '../../../lib/format'
  import { servers } from '../../../lib/servers.svelte'

  interface Props {
    file: string | null
    onback: () => void
    onopen: (file: string | null) => void
  }

  const { file, onback, onopen }: Props = $props()

  let loading = $state(true)
  let saving = $state(false)
  let error = $state<string | null>(null)
  let files = $state<MemoryFileInfo[]>([])
  let path = $state('')
  let content = $state('')
  /// What the file held when it was opened: nothing to save until it differs.
  let loaded = $state('')
  /// Delete was pressed once; the second press deletes.
  let confirming = $state(false)

  const isNew = $derived(file === '')

  function reason(e: unknown): string {
    if (e instanceof ApiError) return (e.body?.reason as string | undefined) ?? e.message
    return e instanceof Error ? e.message : String(e)
  }

  async function load() {
    const entry = servers.current
    if (!entry) return
    loading = true
    error = null
    confirming = false
    try {
      if (file === null) {
        files = (await agentApi.memory(entry)).files
      } else if (file === '') {
        path = ''
        content = loaded = ''
      } else {
        const f = await agentApi.memoryFile(entry, file)
        path = f.path
        content = loaded = f.content
      }
    } catch (e) {
      error = reason(e)
    } finally {
      loading = false
    }
  }

  $effect(() => {
    void file
    void servers.currentId
    void load()
  })

  async function save() {
    const entry = servers.current
    const p = (isNew ? path : (file ?? '')).trim()
    if (!entry || saving || !p) return
    saving = true
    error = null
    try {
      await agentApi.writeMemory(entry, p, content)
      onopen(null)
    } catch (e) {
      error = reason(e)
    } finally {
      saving = false
    }
  }

  async function remove() {
    const entry = servers.current
    if (!entry || saving || !file) return
    if (!confirming) {
      confirming = true
      return
    }
    saving = true
    error = null
    try {
      await agentApi.deleteMemory(entry, file)
      onopen(null)
    } catch (e) {
      error = reason(e)
    } finally {
      saving = false
    }
  }

  const sub = (f: MemoryFileInfo) =>
    [$LL.settingsAgentMemoryChars({ n: f.chars }), f.modified !== null ? fmtDate(f.modified, { year: 'numeric', month: 'short', day: 'numeric' }) : '']
      .filter(Boolean)
      .join(' · ')
  const title = $derived(file === null ? $LL.settingsAgentMemory() : isNew ? $LL.settingsAgentMemoryNew() : file)
  const dirty = $derived(isNew ? !!path.trim() : content !== loaded)
</script>

<SettingsPage {title} back={onback} description={file === null ? $LL.settingsAgentMemoryAbout() : undefined}>
  {#snippet actions()}
    {#if file !== null && !loading}
      <Button variant="primary" size="sm" icon="save" disabled={saving || !dirty} onclick={save}>{$LL.save()}</Button>
    {/if}
  {/snippet}

  {#if loading}
    <div class="grid place-items-center py-[34px]"><Spinner /></div>
  {:else}
    {#if error}<p class="px-[2px] text-[13px] break-all text-(--color-danger)">{error}</p>{/if}

    {#if file === null}
      <Group>
        {#each files as f (f.path)}
          <Row label={f.path} mono sub={sub(f)} onclick={() => onopen(f.path)} />
        {:else}
          <p class="px-[13px] py-[13px] text-[13px] text-(--text-tertiary)">{$LL.settingsAgentMemoryEmpty()}</p>
        {/each}
      </Group>
      <Group>
        <Row label={$LL.settingsAgentMemoryNew()} onclick={() => onopen('')} />
      </Group>
    {:else}
      <Group>
        <div class="flex flex-col gap-[11px] px-[13px] py-[13px]">
          {#if isNew}
            <Input label={$LL.settingsAgentMemoryPath()} mono placeholder="notes.md" bind:value={path} />
          {/if}
          <Textarea label={$LL.settingsAgentMemoryContent()} mono rows={16} bind:value={content} />
        </div>
      </Group>
      {#if !isNew}
        <div>
          <Button variant={confirming ? 'destructive' : 'ghost'} icon="delete" disabled={saving} onclick={remove}>
            {confirming ? $LL.settingsAgentMemoryDeleteConfirm() : $LL.settingsAgentMemoryDelete()}
          </Button>
        </div>
      {/if}
    {/if}
  {/if}
</SettingsPage>
