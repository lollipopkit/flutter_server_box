<script lang="ts">
  /// Files in Settings → Apps: the view a window starts in, hidden files,
  /// and what a double-click on a file does.

  import { Row, SegmentedControl, Select, Switch } from '@lollipopkit/desk-ui'
  import { useWindow } from '../../sys'
  import { LL } from '../../../i18n/i18n-svelte'
  import { DEFAULT_PREFS, loadPrefs, PREFS_KEY, type FilesPrefs } from './prefs'

  const storage = useWindow().storage
  let prefs = $state<FilesPrefs>(DEFAULT_PREFS)
  void loadPrefs(storage).then((p) => (prefs = p))

  function set(patch: Partial<FilesPrefs>) {
    prefs = { ...prefs, ...patch }
    void storage.set(PREFS_KEY, prefs)
  }
</script>

<Row label={$LL.filesDefaultView()}>
  <SegmentedControl
    size="sm"
    label={$LL.filesDefaultView()}
    value={prefs.view}
    options={[
      { value: 'list' as const, label: $LL.filesViewList() },
      { value: 'grid' as const, label: $LL.filesViewGrid() },
    ]}
    onchange={(view) => set({ view })}
  />
</Row>
<Row label={$LL.filesShowHidden()} sub={$LL.filesShowHiddenHint()}>
  <Switch label={$LL.filesShowHidden()} checked={prefs.hidden} onchange={(hidden) => set({ hidden })} />
</Row>
<Row label={$LL.filesOpenFile()}>
  <Select
    class="w-[150px]"
    value={prefs.open}
    options={[
      { value: 'editor', label: $LL.filesEdit() },
      { value: 'download', label: $LL.filesDownload() },
    ]}
    onchange={(e: Event) => set({ open: (e.currentTarget as HTMLSelectElement).value === 'download' ? 'download' : 'editor' })}
  />
</Row>
