<script lang="ts">
  import { Languages } from '@lucide/svelte'
  import { IconButton } from '@serverbox/webui'
  import { LL, locale } from '../i18n/i18n-svelte'
  import { persistLocale } from '../i18n/init'
</script>

<IconButton
  label={$LL.language()}
  class="text-xs"
  onclick={() => persistLocale($locale === 'en' ? 'zh-CN' : 'en')}
>
  <Languages class="w-5 h-5" />
  {$locale === 'en' ? 'EN' : '中'}
</IconButton>
