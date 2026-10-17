<script lang="ts">
  import { Modal, setWebuiLabels } from '@serverbox/webui'

  const {
    onclose = () => {},
    oninnerclose = () => {},
    closeLabel,
    autofocusSecond = false,
  }: {
    onclose?: () => void
    oninnerclose?: () => void
    closeLabel?: string
    autofocusSecond?: boolean
  } = $props()

  // svelte-ignore state_referenced_locally
  if (closeLabel) setWebuiLabels({ close: () => closeLabel })

  let open = $state(false)
  let inner = $state(false)
</script>

<button type="button" onclick={() => (open = true)}>Open</button>
<button type="button">Behind</button>
<Modal
  {open}
  title="Dialog"
  onclose={() => {
    onclose()
    open = false
  }}
>
  <input aria-label="First" />
  <input aria-label="Second" data-autofocus={autofocusSecond || undefined} />
  <button type="button" onclick={() => (inner = true)}>Inner</button>
  <Modal
    open={inner}
    title="Inner dialog"
    onclose={() => {
      oninnerclose()
      inner = false
    }}
  >
    <input aria-label="Inner field" />
  </Modal>
</Modal>
