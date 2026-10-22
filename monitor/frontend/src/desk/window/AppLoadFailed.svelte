<script lang="ts">
  /// An app's code that did not load. Most often the panel was updated after
  /// this page opened, and the files it names are gone: a reload fetches the
  /// new ones (the desk's windows are kept by the agent).

  import { Button } from '../lk'
  import { LL } from '../../i18n/i18n-svelte'
</script>

<div class="space-y-[9px] p-6 text-[13px]">
  <p class="text-(--color-danger)">{$LL.deskAppFailed()}</p>
  <p class="text-(--text-secondary)">{$LL.deskAppFailedHint()}</p>
  <Button size="sm" variant="secondary" icon="refresh" onclick={() => window.location.reload()}>{$LL.deskReload()}</Button>
</div>
