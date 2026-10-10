<script lang="ts">
  /// A web app window (`StackHost`) inside a real window context, in front or
  /// not.

  import StackHost from '../../components/stack/StackHost.svelte'
  import { provideDesk, provideWindow, type Desk } from '../../desk/deskState.svelte'
  import { WindowChrome } from '../../desk/window/chrome.svelte'
  import type { LifecycleState } from '../../desk/sys'

  interface Props {
    desk: Desk
    id: string
    state: LifecycleState
  }

  const props: Props = $props()

  // svelte-ignore state_referenced_locally
  provideDesk(props.desk)
  // svelte-ignore state_referenced_locally
  provideWindow(props.desk, props.id, new WindowChrome(), () => props.state)
</script>

<StackHost stackId="futo.immich" />
