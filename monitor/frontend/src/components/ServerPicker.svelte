<script lang="ts">
  import { Plus, Trash2 } from '@lucide/svelte'
  import { LL } from '../i18n/i18n-svelte'
  import { servers } from '../lib/servers.svelte'

  interface Props {
    /// Show add/remove controls (login page); the dashboard header only switches
    manage?: boolean
  }

  const { manage = false }: Props = $props()

  let adding = $state(false)
  let newName = $state('')
  let newUrl = $state('')

  function submitAdd(e: SubmitEvent) {
    e.preventDefault()
    if (!newUrl.trim()) return
    servers.add(newName, newUrl)
    newName = ''
    newUrl = ''
    adding = false
  }
</script>

<div class="space-y-2">
  <div class="flex items-center gap-2">
    <select
      class="input text-sm"
      value={servers.currentId}
      onchange={(e) => servers.select(e.currentTarget.value)}
    >
      {#each servers.list as s (s.id)}
        <option value={s.id}>
          {s.id === 'local' ? $LL.thisServer() : s.name}{s.url ? ` (${s.url})` : ''}
        </option>
      {/each}
    </select>
    {#if manage}
      <button
        type="button"
        class="p-2 rounded-md text-gray-500 hover:text-gray-900 hover:bg-gray-100 dark:text-gray-400 dark:hover:text-gray-100 dark:hover:bg-gray-800"
        title={$LL.addServer()}
        aria-label={$LL.addServer()}
        onclick={() => (adding = !adding)}
      >
        <Plus class="w-4 h-4" />
      </button>
      {#if servers.list.length > 1}
        <button
          type="button"
          class="p-2 rounded-md text-gray-500 hover:text-danger-600 hover:bg-gray-100 dark:text-gray-400 dark:hover:text-danger-400 dark:hover:bg-gray-800"
          title={$LL.removeServer()}
          aria-label={$LL.removeServer()}
          onclick={() => servers.remove(servers.currentId)}
        >
          <Trash2 class="w-4 h-4" />
        </button>
      {/if}
    {/if}
  </div>

  {#if manage && adding}
    <form class="flex gap-2" onsubmit={submitAdd}>
      <input class="input text-sm" placeholder={$LL.serverName()} bind:value={newName} />
      <input
        class="input text-sm"
        placeholder="https://server:3770"
        bind:value={newUrl}
        required
      />
      <button type="submit" class="btn-primary text-sm whitespace-nowrap">{$LL.add()}</button>
    </form>
  {/if}
</div>
