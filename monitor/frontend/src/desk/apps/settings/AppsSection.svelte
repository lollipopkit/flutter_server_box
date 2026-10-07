<script lang="ts">
  /// How the desk runs apps on this server: whether a hidden window keeps
  /// running. Saved with the desk's preferences (`useDeskPrefs`).

  import { Group, Row, Spinner, Switch } from '../../lk'
  import { AppToolbar } from '../../sys'
  import { LL } from '../../../i18n/i18n-svelte'
  import { useDeskPrefs } from '../../deskState.svelte'

  const desk = useDeskPrefs()
  const prefs = $derived(desk.prefs)
</script>

<AppToolbar title={$LL.settingsApps()} />

<main class="mx-auto max-w-[560px] px-[21px] pb-[21px] pt-[4px]">
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
  {/if}
</main>
