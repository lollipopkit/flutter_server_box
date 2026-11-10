<script lang="ts">
  /// One change to the disks, asked about ([SudoConfirm]): starting it hands
  /// the job to the page. Or a SMART reading (`readHealth`), which needs root
  /// as well, handed back when made.

  import SudoConfirm from '../../../components/SudoConfirm.svelte'
  import { LL } from '../../../i18n/i18n-svelte'
  import { api } from '../../../lib/api'
  import type { HealthReading, StackJob, StorageAction } from '../../../types'

  interface Props {
    action: StorageAction | 'readHealth' | null
    title: string
    /// What it does, said plainly.
    body: string
    /// Typed back before a change that loses data; none for the others.
    confirmWord?: string
    /// A LUKS passphrase the change needs, asked before.
    passphrase?: string
    onstarted: (job: StackJob) => void
    onhealth: (reading: HealthReading) => void
    onclose: () => void
  }

  const { action, title, body, confirmWord, passphrase: luks, onstarted, onhealth, onclose }: Props = $props()

  async function run(password: string) {
    if (!action) return
    if (action === 'readHealth') onhealth(await api.storageHealth(password))
    else onstarted(luks ? await api.storageAct(action, password, luks) : await api.storageAct(action, password))
  }

  function refusal(answer: { error?: string; device?: unknown }): string | undefined {
    switch (answer.error) {
      case 'inUse':
        return $LL.storageInUse({ device: typeof answer.device === 'string' ? answer.device : '' })
      case 'systemMount':
        return $LL.storageSystemMount()
      case 'notMounted':
        return $LL.storageNotMounted()
      case 'invalidPassphrase':
        return $LL.storageInvalidPassphrase()
      case 'mounted':
        return $LL.storageMountedInside()
      case 'notRemovable':
        return $LL.storageNotRemovable()
    }
  }
</script>

<SudoConfirm open={!!action} {title} {body} {confirmWord} {run} {refusal} {onclose} />
