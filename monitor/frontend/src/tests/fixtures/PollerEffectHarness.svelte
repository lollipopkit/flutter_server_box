<script lang="ts">
  import type { Poller } from '../../lib/poller.svelte'

  let { poller }: { poller: Poller<number> } = $props()

  $effect(() => {
    poller.reset()
    poller.start()
    return () => poller.stop()
  })
</script>
