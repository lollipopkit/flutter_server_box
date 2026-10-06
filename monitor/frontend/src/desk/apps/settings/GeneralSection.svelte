<script lang="ts">
  /// This browser's own settings: the panel's language and its light/dark
  /// choice. Neither is tied to a server, and both persist on change — there
  /// is no save step here.

  import { Card } from '@serverbox/webui'
  import { LL } from '../../../i18n/i18n-svelte'
  import AppToolbar from '../../ui/AppToolbar.svelte'
  import LocaleToggle from './LocaleToggle.svelte'
  import ThemeToggle from './ThemeToggle.svelte'
</script>

<AppToolbar title={$LL.settingsGeneral()} />

<main class="mx-auto max-w-3xl space-y-4 px-4 py-4 @3xl:px-6">
  <Card class="space-y-4">
    <div class="space-y-1">
      <span class="text-sm text-muted-fg">{$LL.language()}</span>
      <LocaleToggle />
    </div>
    <div class="space-y-1">
      <span class="block text-sm text-muted-fg">{$LL.theme()}</span>
      <ThemeToggle />
    </div>
  </Card>
</main>
