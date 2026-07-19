<script lang="ts">
  import { Button, IconButton, Input, Modal, Spinner } from '@serverbox/webui'
  import { Trash2 } from '@lucide/svelte'
  import { LL } from '../i18n/i18n-svelte'
  import { ApiError, loginTo, testConnection } from '../lib/api'
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
  let username = $state('')
  let password = $state('')
  let testState = $state<'idle' | 'testing' | 'ok' | 'fail'>('idle')
  let saving = $state(false)
  let loginError = $state('')

  // Reset the form to the entry being edited (or blank for add) each time the
  // modal opens; re-running on every `open` toggle, not just mount
  $effect(() => {
    if (open) {
      name = entry?.name ?? ''
      url = entry?.url ?? ''
      username = ''
      password = ''
      testState = 'idle'
      loginError = ''
    }
  })

  async function handleTest() {
    if (!url.trim()) return
    testState = 'testing'
    testState = (await testConnection(url.trim())) ? 'ok' : 'fail'
  }

  async function handleSubmit(e: SubmitEvent) {
    e.preventDefault()
    if (!url.trim()) return
    loginError = ''

    const id = entry ? entry.id : undefined
    if (entry) {
      servers.update(entry.id, name, url)
    } else {
      servers.add(name, url)
    }
    // add()/update() may have picked a fresh id (add) or kept the existing one
    const savedId = id ?? servers.currentId

    // Credentials are optional: a bare address can be saved and logged into
    // later from the dashboard's inline sign-in prompt
    if (username.trim() && password.trim()) {
      saving = true
      try {
        const response = await loginTo(url.trim(), { username: username.trim(), password })
        servers.setSession(savedId, response.token, username.trim())
      } catch (err) {
        loginError = err instanceof ApiError ? err.message : 'Login failed'
        saving = false
        return
      }
      saving = false
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

    <div class="space-y-1">
      <label class="text-sm text-muted-fg" for="server-username">
        {$LL.username()} ({$LL.optional()})
      </label>
      <Input id="server-username" bind:value={username} placeholder={$LL.enterUsername()} />
    </div>
    <div class="space-y-1">
      <label class="text-sm text-muted-fg" for="server-password">
        {$LL.password()} ({$LL.optional()})
      </label>
      <Input
        id="server-password"
        type="password"
        bind:value={password}
        placeholder={$LL.enterPassword()}
      />
    </div>
    {#if loginError}
      <p class="text-sm text-danger">{loginError}</p>
    {/if}

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
        <Button type="submit" size="sm" disabled={saving}>
          {#if saving}
            <Spinner size="sm" class="mr-2" />
          {/if}
          {$LL.save()}
        </Button>
      </div>
    </div>
  </form>
</Modal>
