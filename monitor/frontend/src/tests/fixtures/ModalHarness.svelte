<script lang="ts">
  import { Modal, setWebuiLabels } from '@serverbox/webui'

  const { onclose = () => {}, closeLabel }: { onclose?: () => void; closeLabel?: string } = $props()

  // svelte-ignore state_referenced_locally
  if (closeLabel) setWebuiLabels({ close: () => closeLabel })

  let open = $state(false)
</script>

<button type="button" onclick={() => (open = true)}>Open</button>
<Modal
  {open}
  title="Dialog"
  onclose={() => {
    onclose()
    open = false
  }}
>
  <input aria-label="First" />
  <input aria-label="Second" />
</Modal>
