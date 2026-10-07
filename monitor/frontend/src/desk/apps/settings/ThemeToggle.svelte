<script lang="ts">
  import { Sun, Moon, MonitorCog } from '@lucide/svelte'
  import { LL } from '../../../i18n/i18n-svelte'
  import { theme, type Theme } from '../../../lib/theme.svelte'
  import Segmented from '../../ui/Segmented.svelte'

  const options = $derived([
    { value: 'system' as Theme, icon: MonitorCog, label: $LL.themeSystem() },
    { value: 'light' as Theme, icon: Sun, label: $LL.themeLight() },
    { value: 'dark' as Theme, icon: Moon, label: $LL.themeDark() },
  ])
</script>

<!-- Segmented switch (not a single cycling icon button) — system/light/dark
     is a genuine 3-way choice, a binary on/off switch would lose "system".
     Stretches full width to match the language select box above it. -->
<Segmented {options} value={theme.current} onchange={(v) => theme.set(v)} block label={$LL.theme()} />
