<script lang="ts">
  import { Card } from '@serverbox/webui'
  import LocaleToggle from '../components/LocaleToggle.svelte'
  import PageHeader from '../components/PageHeader.svelte'
  import ThemeToggle from '../components/ThemeToggle.svelte'
  import { LL } from '../i18n/i18n-svelte'
</script>

<PageHeader title={$LL.panelSettings()} containerClass="max-w-3xl mx-auto px-4 sm:px-6 lg:px-8 w-full" />

<main class="max-w-3xl mx-auto px-4 sm:px-6 lg:px-8 py-8 space-y-6">
  <!-- Browser-local prefs, not tied to any server — applies instantly, no
       save step (LocaleToggle/ThemeToggle persist on change themselves) -->
  <Card class="space-y-4">
    <h2 class="text-base font-semibold font-display text-fg-strong">{$LL.appearance()}</h2>
    <div class="flex items-end gap-3">
      <div class="flex-1 min-w-0 space-y-1">
        <span class="text-sm text-muted-fg">{$LL.language()}</span>
        <LocaleToggle />
      </div>
      <div class="flex-1 min-w-0 space-y-1">
        <span class="block text-sm text-muted-fg">{$LL.theme()}</span>
        <ThemeToggle />
      </div>
    </div>
  </Card>
</main>
