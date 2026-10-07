<script lang="ts">
  /// How the desk runs apps on this server: whether a hidden window keeps
  /// running, for every app and for each. Saved with the desk's preferences
  /// (`useDeskPrefs`).

  import { AppIcon, Group, Icon, Row, Spinner, Switch } from '../../lk'
  import AppSettingsHost from '../../window/AppSettingsHost.svelte'
  import { AppToolbar } from '../../sys'
  import { LL } from '../../../i18n/i18n-svelte'
  import { useDeskPrefs } from '../../deskState.svelte'

  const desk = useDeskPrefs()
  const prefs = $derived(desk.prefs)
  /// The app whose own page is showing, if any.
  let page = $state<string | null>(null)
  const pageSpec = $derived(page ? desk.apps.find((a) => a.id === page && a.settings) : undefined)
  const withPages = $derived(desk.apps.filter((a) => a.settings))
</script>

{#if pageSpec}
  <AppToolbar title={pageSpec.title($LL)} back={() => (page = null)} />
  <main class="mx-auto max-w-[560px] px-[21px] pb-[21px] pt-[4px]">
    {#key pageSpec.id}<AppSettingsHost spec={pageSpec} />{/key}
  </main>
{:else}
<AppToolbar title={$LL.settingsApps()} />

<main class="mx-auto max-w-[560px] space-y-[13px] px-[21px] pb-[21px] pt-[4px]">
  {#if !prefs}
    <div class="flex justify-center py-12"><Spinner size={48} /></div>
  {:else}
    <Group>
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
    </Group>
    {#if withPages.length > 0}
      <Group>
        {#each withPages as spec (spec.id)}
          <button type="button" class="block w-full text-left" onclick={() => (page = spec.id)}>
            <Row label={spec.title($LL)}>
              {#snippet leading()}<AppIcon glyph={spec.glyph} tone={spec.tone} size={26} />{/snippet}
              <Icon name="chevron_right" size={17} class="text-(--text-tertiary)" />
            </Row>
          </button>
        {/each}
      </Group>
    {/if}
    {#if prefs.keepsBackground}
      <Group title={$LL.settingsBackgroundPerApp()}>
        {#each desk.apps as spec (spec.id)}
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
      </Group>
    {/if}
  {/if}
</main>
{/if}
