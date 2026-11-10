<script lang="ts">
  /// One of the agent's model server stacks (`ENGINE_STACKS`) as an installed
  /// app asked the desk to show it (`openStack`): its page (`StackDetail`) in
  /// a sheet over the app's window, set up with the app's model and backend
  /// when it is not deployed yet. Setting up still asks the account's
  /// password there; the app never sees the page.

  import { untrack } from 'svelte'
  import { Button, Dialog, Spinner } from '../../desk/lk'
  import { LL } from '../../i18n/i18n-svelte'
  import { api } from '../../lib/api'
  import { errorText } from '../../lib/errorText'
  import type { StackApp, StackValue } from '../../types'
  import StackDetail from './StackDetail.svelte'
  import { enginePreset } from './preset'

  interface Props {
    stackId: string
    model: string | null
    backend: string
    onclose: () => void
  }

  const { stackId, model, backend, onclose }: Props = $props()

  let app = $state<StackApp | null>(null)
  let error = $state('')

  $effect(() => {
    void untrack(async () => {
      try {
        app = (await api.listStacks()).apps.find((a) => a.manifest.id === stackId) ?? null
        if (!app) error = stackId
      } catch (e) {
        error = errorText(e)
      }
    })
  })

  const preset = $derived<Record<string, StackValue> | undefined>(app && !app.stack ? enginePreset(app.manifest, model, backend) : undefined)
</script>

<Dialog open wide {onclose}>
  {#snippet actions()}
    <Button variant="secondary" onclick={onclose}>{$LL.close()}</Button>
  {/snippet}
  {#if error}
    <p class="text-[13px] text-(--color-danger)">{error}</p>
  {:else if !app}
    <div class="grid place-items-center py-[34px]"><Spinner /></div>
  {:else}
    <!-- The page scrolls inside the sheet (the window body is a size container), so Close stays in reach. -->
    <div class="max-h-[65cqh] overflow-y-auto">
      <StackDetail {stackId} openable={false} {preset} />
    </div>
  {/if}
</Dialog>
