<script lang="ts">
  import { Sun, Moon, MonitorCog } from '@lucide/svelte'
  import { LL } from '../i18n/i18n-svelte'
  import { theme, type Theme } from '../lib/theme.svelte'

  const options: { value: Theme; icon: typeof Sun; label: () => string }[] = [
    { value: 'system', icon: MonitorCog, label: () => $LL.themeSystem() },
    { value: 'light', icon: Sun, label: () => $LL.themeLight() },
    { value: 'dark', icon: Moon, label: () => $LL.themeDark() },
  ]
</script>

<!-- Segmented switch (not a single cycling icon button) — system/light/dark
     is a genuine 3-way choice, a binary on/off switch would lose "system".
     Stretches full width to match the language select box above it. -->
<div class="flex w-full rounded-full border border-line overflow-hidden">
  {#each options as opt (opt.value)}
    {@const active = theme.current === opt.value}
    <button
      type="button"
      class="flex-1 flex items-center justify-center gap-1.5 px-2 py-2 cursor-pointer transition-colors {active
        ? 'bg-fg-strong text-surface'
        : 'bg-surface text-muted-fg hover:bg-soft'}"
      title={opt.label()}
      onclick={() => theme.set(opt.value)}
    >
      <opt.icon class="w-4 h-4 shrink-0" />
      <span class="text-sm truncate">{opt.label()}</span>
    </button>
  {/each}
</div>
