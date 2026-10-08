<script lang="ts">
  /// Processes in Settings → Apps: kernel threads at open, and whether a
  /// stop is asked about first.

  import { Row, Switch } from '@lollipopkit/desk-ui'
  import { useWindow } from '../../sys'
  import { LL } from '../../../i18n/i18n-svelte'
  import { DEFAULT_PREFS, loadPrefs, PREFS_KEY, type ProcessPrefs } from './prefs'

  const storage = useWindow().storage
  let prefs = $state<ProcessPrefs>(DEFAULT_PREFS)
  void loadPrefs(storage).then((p) => (prefs = p))

  function set(patch: Partial<ProcessPrefs>) {
    prefs = { ...prefs, ...patch }
    void storage.set(PREFS_KEY, prefs)
  }
</script>

<Row label={$LL.processShowKernelThreads()}>
  <Switch label={$LL.processShowKernelThreads()} checked={prefs.kernelThreads} onchange={(kernelThreads) => set({ kernelThreads })} />
</Row>
<Row label={$LL.processConfirmStop()} sub={$LL.processConfirmStopHint()}>
  <Switch label={$LL.processConfirmStop()} checked={prefs.confirmStop} onchange={(confirmStop) => set({ confirmStop })} />
</Row>
