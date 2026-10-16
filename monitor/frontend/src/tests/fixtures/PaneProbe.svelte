<script lang="ts" module>
  import type { WindowHandle } from '../../desk/sys/window.svelte'

  /// What each mounted probe saw: its pane's handle, and whether that said
  /// closed when it went.
  export const probes: { handle: WindowHandle; closedOnDestroy?: boolean }[] = []
</script>

<script lang="ts">
  import { onDestroy } from 'svelte'
  import { useWindow } from '../../desk/sys/window.svelte'

  const handle = useWindow()
  const probe: { handle: WindowHandle; closedOnDestroy?: boolean } = { handle }
  probes.push(probe)
  onDestroy(() => (probe.closedOnDestroy = handle.closed))
</script>

<p data-testid="probe">{handle.id}</p>
