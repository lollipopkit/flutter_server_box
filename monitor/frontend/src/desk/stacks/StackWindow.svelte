<script lang="ts">
  /// A store web app without a desk app of its own (`register.ts`): its
  /// window is the deployed service, by the catalog id it is registered as.

  import StackHost from '../../components/stack/StackHost.svelte'
  import { useWindow } from '../sys'

  const win = useWindow()
</script>

<StackHost stackId={win.appId} />
