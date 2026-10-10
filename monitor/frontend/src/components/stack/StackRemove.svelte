<script lang="ts">
  /// Uninstalling a web app: its containers go; its data stays unless the
  /// admin chooses otherwise (so installing again finds it); the admin's
  /// password is asked.

  import { Button, Checkbox, Dialog } from '../../desk/lk'
  import { LL } from '../../i18n/i18n-svelte'
  import { api } from '../../lib/api'
  import type { StackJob } from '../../types'
  import ReauthDialog from '../ReauthDialog.svelte'

  interface Props {
    open: boolean
    stackId: string
    /// What the panel calls it.
    name: string
    onstarted: (job: StackJob) => void
    onclose: () => void
  }

  const { open, stackId, name, onstarted, onclose }: Props = $props()

  let purge = $state(false)
  let asking = $state(false)

  $effect(() => {
    if (open) purge = false
  })

  async function remove(password: string) {
    const job = await api.removeStack(stackId, purge, password)
    onclose()
    onstarted(job)
  }
</script>

<Dialog open={open && !asking} title={$LL.stackRemoveTitle({ name })} {onclose}>
  <div class="space-y-[9px]">
    <p class="text-[13px] text-(--text-secondary)">{$LL.stackRemoveBody()}</p>
    <Checkbox bind:checked={purge} label={$LL.stackPurge()} />
    {#if purge}<p class="text-[12px] text-(--color-danger)">{$LL.stackPurgeWarning()}</p>{/if}
  </div>
  {#snippet actions()}
    <Button variant="secondary" onclick={onclose}>{$LL.cancel()}</Button>
    <Button variant="destructive" onclick={() => (asking = true)}>{$LL.stackRemove()}</Button>
  {/snippet}
</Dialog>

<ReauthDialog
  open={asking}
  message={purge ? $LL.stackRemoveReauthPurge({ name }) : $LL.stackRemoveReauth({ name })}
  onconfirm={remove}
  onclose={() => (asking = false)}
/>
