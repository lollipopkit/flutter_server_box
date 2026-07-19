<script lang="ts">
  import { CircleAlert } from '@lucide/svelte'
  import { Button, Input, Spinner } from '@serverbox/webui'
  import { api, ApiError } from '../lib/api'
  import { LL } from '../i18n/i18n-svelte'
  import { servers } from '../lib/servers.svelte'

  let username = $state('')
  let password = $state('')
  let loading = $state(false)
  let error = $state('')

  async function handleSubmit(e: SubmitEvent) {
    e.preventDefault()
    loading = true
    error = ''
    try {
      const response = await api.login({ username, password })
      servers.login(response.token, username)
    } catch (err) {
      error = err instanceof ApiError ? err.message : 'Login failed'
    } finally {
      loading = false
    }
  }
</script>

<form class="mx-auto max-w-sm space-y-4" onsubmit={handleSubmit}>
  {#if error}
    <div class="bg-danger/10 border border-danger/30 rounded-(--radius-container) p-4">
      <div class="flex">
        <CircleAlert class="w-5 h-5 text-danger shrink-0" />
        <p class="ml-3 text-sm text-danger">{error}</p>
      </div>
    </div>
  {/if}

  <div>
    <label for="username" class="block text-sm font-medium text-fg">{$LL.username()}</label>
    <Input
      id="username"
      name="username"
      type="text"
      required
      bind:value={username}
      class="mt-1"
      placeholder={$LL.enterUsername()}
    />
  </div>
  <div>
    <label for="password" class="block text-sm font-medium text-fg">{$LL.password()}</label>
    <Input
      id="password"
      name="password"
      type="password"
      required
      bind:value={password}
      class="mt-1"
      placeholder={$LL.enterPassword()}
    />
  </div>

  <Button type="submit" block disabled={loading}>
    {#if loading}
      <Spinner size="sm" class="mr-2 text-surface" />
      {$LL.signingIn()}
    {:else}
      {$LL.signIn()}
    {/if}
  </Button>
</form>
