<script lang="ts">
  import { Sun, Moon, MonitorCog } from '@lucide/svelte'
  import { theme } from '../lib/theme.svelte'

  const labels = { system: 'System theme', light: 'Light theme', dark: 'Dark theme' }
</script>

<button
  type="button"
  class="p-2 rounded-md text-gray-500 hover:text-gray-900 hover:bg-gray-100 dark:text-gray-400 dark:hover:text-gray-100 dark:hover:bg-gray-800 transition-colors"
  title={labels[theme.current]}
  aria-label={labels[theme.current]}
  onclick={() => theme.cycle()}
>
  {#if theme.current === 'light'}
    <Sun class="w-5 h-5" />
  {:else if theme.current === 'dark'}
    <Moon class="w-5 h-5" />
  {:else}
    <MonitorCog class="w-5 h-5" />
  {/if}
</button>
