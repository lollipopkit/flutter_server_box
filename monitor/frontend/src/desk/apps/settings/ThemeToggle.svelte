<script lang="ts">
  import { SegmentedControl } from '../../lk'
  import { LL } from '../../../i18n/i18n-svelte'
  import { theme, type Theme } from '../../../lib/theme.svelte'

  const options = $derived([
    { value: 'light' as Theme, label: $LL.deskThemeLight() },
    { value: 'dark' as Theme, label: $LL.deskThemeDark() },
    { value: 'system' as Theme, label: $LL.deskThemeSystem() },
  ])
</script>

<!-- Segmented switch (not a single cycling icon button) — system/light/dark
     is a genuine 3-way choice, a binary on/off switch would lose "system".
     Stretches full width to match the language select box above it. -->
<!-- A theme with one brightness holds it: shown, not choosable. -->
<SegmentedControl
  size="sm"
  options={options}
  value={theme.locked ?? theme.current}
  disabled={theme.locked !== null}
  onchange={(value) => theme.set(value as Theme)}
  label={$LL.theme()}
/>
