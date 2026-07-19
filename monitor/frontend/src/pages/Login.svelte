<script lang="ts">
  import { Monitor, CircleAlert } from '@lucide/svelte'
  import LocaleToggle from '../components/LocaleToggle.svelte'
  import ServerPicker from '../components/ServerPicker.svelte'
  import Spinner from '../components/Spinner.svelte'
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
        <Monitor class="w-12 h-12 text-primary-600" />
      </div>
      <h2 class="mt-6 text-3xl font-bold text-strong">ServerBox Monitor</h2>
      <p class="mt-2 text-sm text-muted">{$LL.signInSubtitle()}</p>
    </div>

    <ServerPicker manage={true} />

    <form class="mt-8 space-y-6" onsubmit={handleSubmit}>
      {#if error}
        <div
          class="bg-danger-50 border border-danger-200 rounded-md p-4 dark:bg-danger-600/10 dark:border-danger-600/30"
        >
          <div class="flex">
            <CircleAlert class="w-5 h-5 text-danger-400" />
            <div class="ml-3">
              <p class="text-sm text-danger-700 dark:text-danger-400">{error}</p>
            </div>
          </div>
        </div>
      {/if}

      <div class="space-y-4">
        <div>
          <label for="username" class="block text-sm font-medium text-gray-700 dark:text-gray-300">
            {$LL.username()}
          </label>
          <input
            id="username"
            name="username"
            type="text"
            required
            bind:value={username}
            class="input mt-1"
            placeholder={$LL.enterUsername()}
          />
        </div>
        <div>
          <label for="password" class="block text-sm font-medium text-gray-700 dark:text-gray-300">
            {$LL.password()}
          </label>
          <input
            id="password"
            name="password"
            type="password"
            required
            bind:value={password}
            class="input mt-1"
            placeholder={$LL.enterPassword()}
          />
        </div>
      </div>

      <div>
        <button
          type="submit"
          disabled={loading}
          class="btn-primary w-full flex items-center justify-center"
        >
          {#if loading}
            <Spinner size="sm" class="mr-2" />
            {$LL.signingIn()}
          {:else}
            {$LL.signIn()}
          {/if}
        </button>
      </div>
    </form>
  </div>
</div>
