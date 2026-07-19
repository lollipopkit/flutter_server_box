<script lang="ts">
  import { Button, IconButton, Input, Modal } from '@serverbox/webui'
  import { Trash2 } from '@lucide/svelte'
  import { LL } from '../i18n/i18n-svelte'
  import { testConnection } from '../lib/api'
  import { servers, type ServerEntry } from '../lib/servers.svelte'

  interface Props {
    open: boolean
    /// Present = editing this entry; absent = adding a new one
    entry?: ServerEntry
    onclose: () => void
  }

  const { open, entry, onclose }: Props = $props()

  let name = $state('')
  let url = $state('')
  let testState = $state<'idle' | 'testing' | 'ok' | 'fail'>('idle')

  // Reset the form to the entry being edited (or blank for add) each time the
  // modal opens; re-running on every `open` toggle, not just mount
  $effect(() => {
    if (open) {
      name = entry?.name ?? ''
      url = entry?.url ?? ''
      testState = 'idle'
    }
  })

  async function handleTest() {
    if (!url.trim()) return
    testState = 'testing'
    testState = (await testConnection(url.trim())) ? 'ok' : 'fail'
  }

  function handleSubmit(e: SubmitEvent) {
    e.preventDefault()
    if (!url.trim()) return
    if (entry) {
      servers.update(entry.id, name, url)
    } else {
      servers.add(name, url)
    }
    onclose()
  }

  function handleDelete() {
    if (!entry) return
    if (confirm($LL.confirmDeleteServer())) {
      servers.remove(entry.id)
      onclose()
    }
  }
</script>

<Modal {open} title={entry ? $LL.editServer() : $LL.addServer()} {onclose}>
  <form class="space-y-4" onsubmit={handleSubmit}>
    <div class="space-y-1">
      <label class="text-sm text-muted-fg" for="server-name">
        {$LL.serverName()} ({$LL.optional()})
      </label>
      <Input id="server-name" bind:value={name} placeholder={$LL.serverName()} />
    </div>
    <div class="space-y-1">
      <label class="text-sm text-muted-fg" for="server-url">{$LL.serverUrlLabel()}</label>
      <Input
        id="server-url"
        bind:value={url}
        placeholder="https://server:3770"
        required
        oninput={() => (testState = 'idle')}
      />
    </div>

    <div class="flex items-center gap-2">
      <Button type="button" variant="secondary" size="sm" onclick={handleTest}>
        {testState === 'testing' ? $LL.testingConnection() : $LL.testConnection()}
      </Button>
      {#if testState === 'ok'}
        <span class="text-sm text-success">{$LL.connected()}</span>
      {:else if testState === 'fail'}
        <span class="text-sm text-danger">{$LL.disconnected()}</span>
      {/if}
    </div>

    <div class="flex items-center justify-between pt-2">
      {#if entry && entry.id !== 'local'}
        <IconButton label={$LL.removeServer()} class="hover:text-danger" onclick={handleDelete}>
          <Trash2 class="w-4 h-4" />
        </IconButton>
      {:else}
        <span></span>
      {/if}
      <div class="flex items-center gap-2">
        <Button type="button" variant="ghost" size="sm" onclick={onclose}>{$LL.cancel()}</Button>
        <Button type="submit" size="sm">{$LL.save()}</Button>
      </div>
    </div>
  </form>
</Modal>
