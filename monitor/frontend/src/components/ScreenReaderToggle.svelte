<script lang="ts">
  /// Turns the terminals' screen reader mode on and off. Placed before the
  /// terminal it serves, so Tab reaches it before focus enters the terminal,
  /// which keeps Tab for itself while the mode is off.
  import { Button } from '@serverbox/webui'
  import { LL } from '../i18n/i18n-svelte'
  import { screenReader } from '../lib/screenReader.svelte'
</script>

<Button
  variant={screenReader.enabled ? 'primary' : 'secondary'}
  size="sm"
  aria-pressed={screenReader.enabled}
  title={$LL.terminalScreenReaderHint()}
  onclick={() => screenReader.toggle()}
>
  {$LL.terminalScreenReader()}
</Button>
