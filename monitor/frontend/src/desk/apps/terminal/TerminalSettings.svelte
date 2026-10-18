<script lang="ts">
  /// Terminal in Settings → Apps: font size, cursor, bell and screen reader
  /// mode (this browser's, for every terminal, a guest's console too).

  import { Row, SegmentedControl, Switch } from '../../lk'
  import { useWindow } from '../../sys'
  import { LL } from '../../../i18n/i18n-svelte'
  import { screenReader } from '../../../lib/screenReader.svelte'
  import { DEFAULT_LOOK, FONT_SIZES, loadLook, LOOK_KEY, type Look } from './look'

  const storage = useWindow().storage
  let look = $state<Look>(DEFAULT_LOOK)
  void loadLook(storage).then((l) => (look = l))

  function set(patch: Partial<Look>) {
    look = { ...look, ...patch }
    void storage.set(LOOK_KEY, look)
  }
</script>

<Row label={$LL.terminalFontSize()}>
  <SegmentedControl
    size="sm"
    label={$LL.terminalFontSize()}
    value={String(look.fontSize)}
    options={FONT_SIZES.map((s) => ({ value: String(s), label: String(s) }))}
    onchange={(v) => set({ fontSize: Number(v) })}
  />
</Row>
<Row label={$LL.terminalCursor()}>
  <SegmentedControl
    size="sm"
    label={$LL.terminalCursor()}
    value={look.cursor}
    options={[
      { value: 'block' as const, label: $LL.terminalCursorBlock() },
      { value: 'bar' as const, label: $LL.terminalCursorBar() },
      { value: 'underline' as const, label: $LL.terminalCursorUnderline() },
    ]}
    onchange={(cursor) => set({ cursor })}
  />
</Row>
<Row label={$LL.terminalBell()}>
  <Switch label={$LL.terminalBell()} checked={look.bell} onchange={(bell) => set({ bell })} />
</Row>
<Row label={$LL.terminalScreenReader()} sub={$LL.terminalScreenReaderHint()}>
  <Switch label={$LL.terminalScreenReader()} checked={screenReader.enabled} onchange={(on) => screenReader.set(on)} />
</Row>
