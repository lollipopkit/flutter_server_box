<script lang="ts">
  /// Gives a test the `sys` handle of one window on a real desk.

  import { provideDesk, provideWindow, type Desk } from '../../desk/deskState.svelte'
  import { useWindow, type WindowHandle } from '../../desk/sys/window.svelte'
  import { WindowChrome } from '../../desk/window/chrome.svelte'

  interface Props {
    desk: Desk
    id: string
    onhandle: (handle: WindowHandle) => void
  }

  const { desk, id, onhandle }: Props = $props()

  // svelte-ignore state_referenced_locally
  provideDesk(desk)
  // svelte-ignore state_referenced_locally
  provideWindow(desk, id, new WindowChrome(), () => 'active')
  // svelte-ignore state_referenced_locally
  onhandle(useWindow())
</script>
