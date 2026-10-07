<script lang="ts">
  import { SegmentedControl } from '../../lk'
  import { LL } from '../../../i18n/i18n-svelte'
  import { theme, type Theme } from '../../../lib/theme.svelte'

  const options = $derived([
    { value: 'system' as Theme, icon: 'desktop_windows', title: $LL.themeSystem() },
    { value: 'light' as Theme, icon: 'light_mode', title: $LL.themeLight() },
    { value: 'dark' as Theme, icon: 'dark_mode', title: $LL.themeDark() },
  ])
</script>

<!-- Segmented switch (not a single cycling icon button) — system/light/dark
     is a genuine 3-way choice, a binary on/off switch would lose "system".
     Stretches full width to match the language select box above it. -->
<SegmentedControl options={options} value={theme.current} onchange={(value) => theme.set(value as Theme)} label={$LL.theme()} />
