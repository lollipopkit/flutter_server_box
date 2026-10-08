<script lang="ts">
  /// One app's page in Settings → Apps, run as that app (`provideAppSettings`).

  import { LL } from '../../i18n/i18n-svelte'
  import { provideAppSettings, useDesk } from '../deskState.svelte'
  import Spinner from '@lollipopkit/desk-ui/Spinner.svelte'
  import type { AppSpec } from '../sys/manifest'
  import { useWindow } from '../sys/window.svelte'

  interface Props {
    spec: AppSpec
  }

  const { spec }: Props = $props()
  const settings = useWindow()
  const desk = useDesk()
  // svelte-ignore state_referenced_locally
  provideAppSettings(desk, spec.id, settings)
  // svelte-ignore state_referenced_locally
  const page = spec.settings?.()
</script>

{#if page}
  {#await page}
    <div class="flex justify-center py-12"><Spinner /></div>
  {:then mod}
    <mod.default />
  {:catch}
    <p class="p-6 text-[13px] text-(--color-danger)">{$LL.deskAppFailed()}</p>
  {/await}
{/if}
