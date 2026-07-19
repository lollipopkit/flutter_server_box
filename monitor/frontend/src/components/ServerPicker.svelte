<script lang="ts">
  import { Plus, Trash2 } from '@lucide/svelte'
  import { Button, IconButton, Input, Select } from '@serverbox/webui'
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
    <Select
      class="text-sm {manage ? 'w-full' : 'min-w-28 max-w-40 sm:max-w-56'}"
      value={servers.currentId}
      onchange={(e: Event) => servers.select((e.currentTarget as HTMLSelectElement).value)}
    >
      {#each servers.list as s (s.id)}
        <option value={s.id}>
          {s.id === 'local' ? $LL.thisServer() : s.name}{s.url ? ` (${s.url})` : ''}
        </option>
      {/each}
    </Select>
    {#if manage}
      <IconButton label={$LL.addServer()} onclick={() => (adding = !adding)}>
        <Plus class="w-4 h-4" />
      </IconButton>
      {#if servers.list.length > 1}
        <IconButton
          label={$LL.removeServer()}
          class="hover:text-danger"
          onclick={() => servers.remove(servers.currentId)}
        >
          <Trash2 class="w-4 h-4" />
        </IconButton>
      {/if}
    {/if}
  </div>

  {#if manage && adding}
    <form class="flex gap-2" onsubmit={submitAdd}>
      <Input class="text-sm" placeholder={$LL.serverName()} bind:value={newName} />
      <Input class="text-sm" placeholder="https://server:3770" bind:value={newUrl} required />
      <Button type="submit" size="sm" class="whitespace-nowrap">{$LL.add()}</Button>
    </form>
  {/if}
</div>
