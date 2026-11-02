<script lang="ts">
  /// All Apps over a desk, as the desk shows it.

  import AppsPanel from '../../desk/shell/AppsPanel.svelte'
  import { provideDesk, type Desk } from '../../desk/deskState.svelte'

  interface Props {
    desk: Desk
  }

  const props: Props = $props()
  // svelte-ignore state_referenced_locally
  provideDesk(props.desk)
</script>

{#if props.desk.panel === 'apps'}<AppsPanel />{/if}
