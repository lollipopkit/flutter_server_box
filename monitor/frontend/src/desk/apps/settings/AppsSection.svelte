<script lang="ts">
  /// The apps on this server, for this account: one row each, opening its
  /// page (`AppPage.svelte`: dock, running hidden, permissions, its own
  /// preferences); the switch that lets any app run hidden; and (for an
  /// administrator) the installed ones. Saved on the server, so they apply in
  /// every browser this account signs in from.

  import { AppIcon, Group, Row, Spinner, Switch } from '../../lk'
  import { capabilitiesStore } from '../../../lib/capabilities.svelte'
  import { servers } from '../../../lib/servers.svelte'
  import InstalledApps from './InstalledApps.svelte'
  import SettingsPage from './SettingsPage.svelte'
  import { LL } from '../../../i18n/i18n-svelte'
  import { useDeskPrefs } from '../../deskState.svelte'

  interface Props {
    /// Opens [appId]'s page.
    onopen: (appId: string) => void
  }

  const { onopen }: Props = $props()
  const desk = useDeskPrefs()
  const admin = $derived(capabilitiesStore.byServer[servers.currentId]?.me?.admin === true)
  const prefs = $derived(desk.prefs)

  function summary(id: string, kind: 'system' | 'web', permissions: readonly string[] | undefined): string {
    if (!prefs) return ''
    const parts: string[] = []
    if (prefs.value.dock.includes(id)) parts.push($LL.settingsAppInDock())
    const hidden = kind === 'system' || !!permissions?.includes('background')
    if (hidden && prefs.value.background && !prefs.value.background_denied.includes(id)) {
      parts.push($LL.settingsAppInBackground())
    }
    return parts.join(' · ')
  }
</script>

<SettingsPage title={$LL.settingsApps()} description={$LL.settingsAppsDesc()}>
  {#if !prefs}
    <div class="flex justify-center py-12"><Spinner size={48} /></div>
  {:else}
    <Group title={$LL.settingsAppList()}>
      {#each desk.apps as spec (spec.id)}
        <Row label={spec.title($LL)} sub={summary(spec.id, spec.kind, spec.permissions) || undefined} onclick={() => onopen(spec.id)}>
          {#snippet leading()}<AppIcon glyph={spec.glyph} tone={spec.tone} size={26} />{/snippet}
        </Row>
      {/each}
    </Group>

    <Group title={$LL.settingsBackgroundPerApp()}>
      <Row label={$LL.settingsBackgroundApps()} sub={$LL.settingsBackgroundAppsSub()}>
        <Switch
          label={$LL.settingsBackgroundApps()}
          checked={prefs.value.background}
          onchange={(on) => prefs.update({ background: on })}
        />
      </Row>
    </Group>

    {#if admin}
      <InstalledApps onchange={desk.reloadApps} />
    {/if}
  {/if}
</SettingsPage>
