<script lang="ts">
  /// This browser's own settings: language, clock and units, what the desk
  /// does at start, how often live figures are read, notifications, and the
  /// desk's keys. Kept here, never sent to the server; each takes effect on
  /// change.

  import { Group, Row, SegmentedControl, Select, Switch } from '../../lk'
  import { systemPrefs, type RefreshSeconds, type StartApp } from '../../sys'
  import { LL } from '../../../i18n/i18n-svelte'
  import { displayPrefs, type SizeUnits, type TimeFormat } from '../../../lib/displayPrefs.svelte'
  import { useDeskPrefs } from '../../deskState.svelte'
  import LocaleToggle from './LocaleToggle.svelte'
  import SettingsPage from './SettingsPage.svelte'

  const desk = useDeskPrefs()
  const sys = $derived(systemPrefs.value)
  /// The apps this browser may open at start: those this account can use.
  const startApps = $derived(
    (['status', 'process', 'files'] as const)
      .map((id) => desk.apps.find((a) => a.id === id))
      .filter((a) => a !== undefined)
      .map((a) => ({ value: a.id, label: a.title($LL) })),
  )
</script>

<SettingsPage title={$LL.settingsGeneral()} description={$LL.settingsGeneralDesc()}>
  <Group title={$LL.settingsLanguageRegion()}>
    <Row label={$LL.language()}>
      <LocaleToggle />
    </Row>
    <Row label={$LL.settingsTimeFormat()}>
      <SegmentedControl
        size="sm"
        label={$LL.settingsTimeFormat()}
        value={displayPrefs.time}
        options={[
          { value: '24' as TimeFormat, label: $LL.settingsClock24() },
          { value: '12' as TimeFormat, label: $LL.settingsClock12() },
        ]}
        onchange={(time) => displayPrefs.set({ time })}
      />
    </Row>
    <Row label={$LL.settingsSizeUnits()} sub={$LL.settingsSizeUnitsHint()}>
      <SegmentedControl
        size="sm"
        label={$LL.settingsSizeUnits()}
        value={displayPrefs.units}
        options={[
          { value: 'iec' as SizeUnits, label: 'GiB' },
          { value: 'si' as SizeUnits, label: 'GB' },
        ]}
        onchange={(units) => displayPrefs.set({ units })}
      />
    </Row>
  </Group>

  <Group title={$LL.settingsStartup()}>
    <Row label={$LL.settingsOpenAtStart()} sub={$LL.settingsOpenAtStartHint()}>
      <Select
        class="w-[150px]"
        value={sys.openOnStart}
        options={[...startApps, { value: 'none', label: $LL.settingsNothing() }]}
        onchange={(e: Event) => systemPrefs.set({ openOnStart: (e.currentTarget as HTMLSelectElement).value as StartApp })}
      />
    </Row>
    <Row label={$LL.settingsRestoreWindows()} sub={$LL.settingsRestoreWindowsHint()}>
      <Switch label={$LL.settingsRestoreWindows()} checked={sys.restoreWindows} onchange={(restoreWindows) => systemPrefs.set({ restoreWindows })} />
    </Row>
  </Group>

  <Group title={$LL.settingsRefresh()}>
    <Row label={$LL.settingsAutoRefresh()} sub={$LL.settingsAutoRefreshHint()}>
      <Switch label={$LL.settingsAutoRefresh()} checked={sys.autoRefresh} onchange={(autoRefresh) => systemPrefs.set({ autoRefresh })} />
    </Row>
    <Row label={$LL.settingsRefreshInterval()} sub={$LL.settingsRefreshIntervalHint()}>
      <SegmentedControl
        size="sm"
        label={$LL.settingsRefreshInterval()}
        value={String(sys.refreshSeconds)}
        options={[1, 2, 5].map((n) => ({ value: String(n), label: $LL.settingsSeconds({ n }) }))}
        onchange={(v) => systemPrefs.set({ refreshSeconds: Number(v) as RefreshSeconds })}
      />
    </Row>
  </Group>

  <Group title={$LL.deskNotifications()}>
    <Row label={$LL.settingsBanners()} sub={$LL.settingsBannersHint()}>
      <Switch label={$LL.settingsBanners()} checked={sys.banners} onchange={(banners) => systemPrefs.set({ banners })} />
    </Row>
    {#if desk.notifications}
      <Row label={$LL.deskDnd()} sub={$LL.settingsDndHint()}>
        <Switch label={$LL.deskDnd()} checked={desk.notifications.dnd} onchange={(on) => desk.notifications?.setDnd(on)} />
      </Row>
    {/if}
  </Group>

  <Group title={$LL.settingsShortcuts()}>
    <Row label={$LL.deskSearch()} value="⌘K" mono />
    <Row label={$LL.deskAppSettings()} value="⌘," mono />
    <Row label={$LL.settingsNextWindow()} value="⌥`" mono />
  </Group>
</SettingsPage>
