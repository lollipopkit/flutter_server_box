<script lang="ts">
  /// The first-run guide over a desk, mounted while the account's
  /// preferences have not been marked — as `Desk.svelte` mounts it.

  import Guide from '../../desk/guide/Guide.svelte'
  import { provideDesk, type Desk } from '../../desk/deskState.svelte'
  import type { DeskPrefs } from '../../desk/prefs.svelte'

  interface Props {
    desk: Desk
    prefs: DeskPrefs
  }

  const props: Props = $props()
  // svelte-ignore state_referenced_locally
  provideDesk(props.desk)
</script>

{#if props.prefs.needsGuide}
  <Guide prefs={props.prefs} />
{/if}
