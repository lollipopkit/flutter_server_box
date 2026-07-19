<script lang="ts">
  import { Languages } from '@lucide/svelte'
  import { i18n } from '../lib/i18n.svelte'
</script>

<button
  type="button"
  class="p-2 rounded-md text-gray-500 hover:text-gray-900 hover:bg-gray-100 dark:text-gray-400 dark:hover:text-gray-100 dark:hover:bg-gray-800 transition-colors inline-flex items-center gap-1 text-xs"
  title={i18n.t('language')}
  aria-label={i18n.t('language')}
  onclick={() => i18n.toggle()}
>
  <Languages class="w-5 h-5" />
  {i18n.locale === 'en' ? 'EN' : '中'}
</button>
