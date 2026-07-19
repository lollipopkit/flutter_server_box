<script lang="ts">
  import { Monitor, CircleAlert } from '@lucide/svelte'
  import { Button, Input, Spinner } from '@serverbox/webui'
  import LocaleToggle from '../components/LocaleToggle.svelte'
  import ServerPicker from '../components/ServerPicker.svelte'
  import ThemeToggle from '../components/ThemeToggle.svelte'
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

<div class="min-h-screen flex items-center justify-center">
  <div class="absolute top-4 right-4 flex items-center gap-1">
    <LocaleToggle />
    <ThemeToggle />
  </div>
  <div class="max-w-md w-full space-y-8 p-8">
    <div class="text-center">
      <div class="flex justify-center">
        <Monitor class="w-12 h-12 text-accent" />
      </div>
      <h2 class="mt-6 text-3xl font-bold font-display text-fg-strong">ServerBox Monitor</h2>
      <p class="mt-2 text-sm text-muted-fg">{$LL.signInSubtitle()}</p>
    </div>

    <ServerPicker manage={true} />

    <form class="mt-8 space-y-6" onsubmit={handleSubmit}>
      {#if error}
        <div class="bg-danger/10 border border-danger/30 rounded-(--radius-container) p-4">
          <div class="flex">
            <CircleAlert class="w-5 h-5 text-danger" />
            <div class="ml-3">
              <p class="text-sm text-danger">{error}</p>
            </div>
          </div>
        </div>
      {/if}

      <div class="space-y-4">
        <div>
          <label for="username" class="block text-sm font-medium text-fg">
            {$LL.username()}
          </label>
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
          <label for="password" class="block text-sm font-medium text-fg">
            {$LL.password()}
          </label>
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
  </div>
</div>
