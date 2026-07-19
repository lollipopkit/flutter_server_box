<script lang="ts">
  import { Pencil, Plus } from '@lucide/svelte'
  import { IconButton, Select } from '@serverbox/webui'
  import { LL } from '../i18n/i18n-svelte'
  import ServerFormModal from './ServerFormModal.svelte'
  import { displayName, servers, type ServerEntry } from '../lib/servers.svelte'

  interface Props {
    /// Show add/edit controls (login page); the dashboard header only switches
    manage?: boolean
  }

  const { manage = false }: Props = $props()

  let formOpen = $state(false)
  let editingEntry = $state<ServerEntry | undefined>(undefined)

  function openAdd() {
    editingEntry = undefined
    formOpen = true
  }

  function openEdit() {
    editingEntry = servers.current
    formOpen = true
  }
</script>

<div class="flex items-center gap-2">
  <Select
    class="text-sm {manage ? 'w-full' : 'min-w-28 max-w-40 sm:max-w-56'}"
    value={servers.currentId}
    onchange={(e: Event) => servers.select((e.currentTarget as HTMLSelectElement).value)}
  >
    {#each servers.list as s (s.id)}
      <option value={s.id}>
        {s.id === 'local' ? $LL.thisServer() : displayName(s)}{s.url ? ` (${s.url})` : ''}
      </option>
    {/each}
  </Select>
  {#if manage}
    <IconButton label={$LL.addServer()} onclick={openAdd}>
      <Plus class="w-4 h-4" />
    </IconButton>
    {#if servers.current?.id !== 'local'}
      <IconButton label={$LL.editServer()} onclick={openEdit}>
        <Pencil class="w-4 h-4" />
      </IconButton>
    {/if}
  {/if}
</div>

{#if manage}
  <ServerFormModal open={formOpen} entry={editingEntry} onclose={() => (formOpen = false)} />
{/if}
