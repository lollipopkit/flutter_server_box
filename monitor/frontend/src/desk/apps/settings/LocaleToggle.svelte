<script lang="ts">
  import { Select } from '@lollipopkit/desk-ui'
  import { locale } from '../../../i18n/i18n-svelte'
  import { persistLocale } from '../../../i18n/init'
  import type { Locales } from '../../../i18n/i18n-types'

  // Each option is labeled in its own language so users can find their
  // language without already understanding the current UI language.
  const options: Record<Locales, string> = {
    de: 'Deutsch',
    en: 'English',
    es: 'Español',
    fr: 'Français',
    id: 'Bahasa Indonesia',
    it: 'Italiano',
    ja: '日本語',
    ko: '한국어',
    nl: 'Nederlands',
    pt: 'Português',
    ru: 'Русский',
    tr: 'Türkçe',
    uk: 'Українська',
    'zh-CN': '简体中文',
    'zh-TW': '繁體中文',
  }
</script>

<Select
  class="w-[170px]"
  value={$locale}
  options={Object.entries(options).map(([value, label]) => ({ value, label }))}
  onchange={(e: Event) => persistLocale((e.currentTarget as HTMLSelectElement).value as Locales)}
/>
