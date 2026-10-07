<script lang="ts">
  /// The apps on this server, for this account: which sit in the dock,
  /// whether a hidden window keeps running, each app's own settings, and
  /// (for an administrator) the installed ones. Saved on the server, so they
  /// apply in every browser this account signs in from.

  import { AppIcon, Group, Row, Spinner, Switch } from '../../lk'
  import AppSettingsHost from '../../window/AppSettingsHost.svelte'
  import { capabilitiesStore } from '../../../lib/capabilities.svelte'
  import { servers } from '../../../lib/servers.svelte'
  import InstalledApps from './InstalledApps.svelte'
  import SettingsPage from './SettingsPage.svelte'
  import { LL } from '../../../i18n/i18n-svelte'
  import { useDeskPrefs } from '../../deskState.svelte'

  const desk = useDeskPrefs()
  const admin = $derived(capabilitiesStore.byServer[servers.currentId]?.me?.admin === true)
  const prefs = $derived(desk.prefs)
  const withPages = $derived(desk.apps.filter((a) => a.settings))
</script>

<SettingsPage title={$LL.settingsApps()} description={$LL.settingsAppsDesc()}>
  {#if !prefs}
    <div class="flex justify-center py-12"><Spinner size={48} /></div>
  {:else}
    <Group title={$LL.settingsDockApps()}>
      {#each desk.apps as spec (spec.id)}
        {@const title = spec.title($LL)}
        <Row label={title}>
          {#snippet leading()}<AppIcon glyph={spec.glyph} tone={spec.tone} size={26} />{/snippet}
          <Switch
            size="sm"
            label="{$LL.deskPin()}: {title}"
            checked={prefs.value.dock.includes(spec.id)}
            onchange={(on) => (on ? prefs.pin(spec.id) : prefs.unpin(spec.id))}
          />
        </Row>
      {/each}
    </Group>

    {#each withPages as spec (spec.id)}
      <!-- Each app's own settings, run as that app. -->
      <Group title={spec.title($LL)}>
        <AppSettingsHost {spec} />
      </Group>
    {/each}

    <Group title={$LL.settingsBackgroundPerApp()}>
      <Row
        label={$LL.settingsBackgroundApps()}
        sub={prefs.keepsBackground ? $LL.settingsBackgroundAppsSub() : $LL.settingsBackgroundAppsOld()}
      >
        <Switch
          label={$LL.settingsBackgroundApps()}
          disabled={!prefs.keepsBackground}
          checked={prefs.value.background}
          onchange={(on) => prefs.update({ background: on })}
        />
      </Row>
      {#if prefs.keepsBackground}
        <!-- An installed app runs hidden only with the `background` permission. -->
        {#each desk.apps.filter((a) => a.kind === 'system' || a.permissions?.includes('background')) as spec (spec.id)}
          {@const title = spec.title($LL)}
          <Row label={title}>
            {#snippet leading()}<AppIcon glyph={spec.glyph} tone={spec.tone} size={26} />{/snippet}
            <Switch
              size="sm"
              label="{$LL.settingsBackgroundApps()}: {title}"
              disabled={!prefs.value.background}
              checked={prefs.value.background && !prefs.value.background_denied.includes(spec.id)}
              onchange={(on) => prefs.setBackground(spec.id, on)}
            />
          </Row>
        {/each}
      {/if}
    </Group>

    {#if admin}
      <InstalledApps onchange={desk.reloadApps} />
    {/if}
  {/if}
</SettingsPage>
