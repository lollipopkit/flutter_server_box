<script lang="ts">
  /// A window with panes on a real desk, running `PaneProbe` in each pane.

  import { provideDesk, provideWindow, type Desk } from '../../desk/deskState.svelte'
  import { WindowChrome } from '../../desk/window/chrome.svelte'
  import PaneHost from '../../desk/window/PaneHost.svelte'
  import PaneProbe from './PaneProbe.svelte'

  interface Props {
    desk: Desk
    id: string
  }

  const { desk, id }: Props = $props()

  // svelte-ignore state_referenced_locally
  provideDesk(desk)
  // svelte-ignore state_referenced_locally
  provideWindow(desk, id, new WindowChrome(), () => 'active')
</script>

<PaneHost content={PaneProbe} appTitle="Probe" />
