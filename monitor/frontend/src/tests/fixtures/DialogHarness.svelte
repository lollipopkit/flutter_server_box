<script lang="ts">
  import Dialog from '../../desk/lk/Dialog.svelte'

  const {
    onclose = () => {},
    oninnerclose = () => {},
    autofocusSecond = false,
  }: {
    onclose?: () => void
    oninnerclose?: () => void
    autofocusSecond?: boolean
  } = $props()

  let open = $state(false)
  let inner = $state(false)
</script>

<button type="button" onclick={() => (open = true)}>Open</button>
<button type="button">Behind</button>
<Dialog
  {open}
  wide
  title="Dialog"
  onclose={() => {
    onclose()
    open = false
  }}
>
  <input aria-label="First" />
  <input aria-label="Second" data-autofocus={autofocusSecond || undefined} />
  <button type="button" onclick={() => (inner = true)}>Inner</button>
  <Dialog
    open={inner}
    title="Inner dialog"
    onclose={() => {
      oninnerclose()
      inner = false
    }}
  >
    <input aria-label="Inner field" />
  </Dialog>
</Dialog>
