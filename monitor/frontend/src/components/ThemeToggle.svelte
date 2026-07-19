<script lang="ts">
  import { Sun, Moon, MonitorCog } from '@lucide/svelte'
  import { IconButton } from '@serverbox/webui'
  import { LL } from '../i18n/i18n-svelte'
  import { theme } from '../lib/theme.svelte'

  const labels = $derived({
    system: $LL.themeSystem(),
    light: $LL.themeLight(),
    dark: $LL.themeDark(),
  })
</script>

<IconButton label={labels[theme.current]} onclick={() => theme.cycle()}>
  {#if theme.current === 'light'}
    <Sun class="w-5 h-5" />
  {:else if theme.current === 'dark'}
    <Moon class="w-5 h-5" />
  {:else}
    <MonitorCog class="w-5 h-5" />
  {/if}
</IconButton>
