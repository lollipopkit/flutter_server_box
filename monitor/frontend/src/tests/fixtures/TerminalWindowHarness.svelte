<script lang="ts">
  /// The Terminal app under a window handle whose `closed` the test decides.

  import { setContext } from 'svelte'
  import TerminalApp from '../../desk/apps/terminal/TerminalApp.svelte'
  import { WINDOW, type WindowHandle } from '../../desk/sys/window.svelte'

  interface Props {
    window: { closed: boolean }
  }

  const { window: state }: Props = $props()

  const handle = {
    id: 'w1',
    appId: 'terminal',
    appState: null,
    setAppState() {},
    setTitle() {},
    close() {},
    open: () => null,
    openWindow: () => null,
    canOpenWindow: false,
    storage: { get: async () => undefined, set: async () => {}, remove: async () => {}, keys: async () => [] },
    active: true,
    get closed() {
      return state.closed
    },
    lifecycle: 'active',
    chrome: null,
  } as unknown as WindowHandle
  setContext(WINDOW, handle)
</script>

<TerminalApp />
