<script lang="ts">
  import { Languages } from '@lucide/svelte'
  import { LL, locale } from '../i18n/i18n-svelte'
  import { persistLocale } from '../i18n/init'
</script>

<button
  type="button"
  class="p-2 rounded-md text-gray-500 hover:text-gray-900 hover:bg-gray-100 dark:text-gray-400 dark:hover:text-gray-100 dark:hover:bg-gray-800 transition-colors inline-flex items-center gap-1 text-xs"
  title={$LL.language()}
  aria-label={$LL.language()}
  onclick={() => persistLocale($locale === 'en' ? 'zh-CN' : 'en')}
>
  <Languages class="w-5 h-5" />
  {$locale === 'en' ? 'EN' : '中'}
</button>
