<script lang="ts">
  /// One app's page under Settings → Apps: everything about it in one place —
  /// whether it sits in the dock, whether it keeps running hidden, what an
  /// installed one may do, and its own preferences (its manifest's `settings`
  /// page, run as the app).

  import { AppIcon, Group, Row, Spinner, Switch } from '@lollipopkit/desk-ui'
  import AppSettingsHost from '../../window/AppSettingsHost.svelte'
  import type { AppSpec } from '../../sys'
  import SettingsPage from './SettingsPage.svelte'
  import { LL } from '../../../i18n/i18n-svelte'
  import { useDeskPrefs } from '../../deskState.svelte'

  interface Props {
    spec: AppSpec
    onback: () => void
  }

  const { spec, onback }: Props = $props()
  const desk = useDeskPrefs()
  const prefs = $derived(desk.prefs)
  const title = $derived(spec.title($LL))
  /// An installed app runs hidden only with the `background` permission.
  const mayRunHidden = $derived(spec.kind === 'system' || !!spec.permissions?.includes('background'))

  function permissionText(p: string): string {
    if (p === 'notifications') return $LL.settingsPermNotifications()
    if (p === 'background') return $LL.settingsPermBackground()
    return p
  }
</script>

<SettingsPage {title} back={onback}>
  <div class="flex items-center gap-[13px] px-[2px] pb-[4px]">
    <AppIcon glyph={spec.glyph} tone={spec.tone} size={56} />
    <div class="flex min-w-0 flex-col gap-[3px]">
      <span class="truncate text-[21px] font-bold tracking-[-0.01em]">{title}</span>
      <span class="text-[12px] text-(--text-tertiary)">{spec.kind === 'system' ? $LL.settingsAppBuiltIn() : $LL.settingsAppInstalled()}</span>
    </div>
  </div>

  {#if !prefs}
    <div class="flex justify-center py-12"><Spinner size={48} /></div>
  {:else}
    <Group>
      <Row label={$LL.settingsAppShowInDock()}>
        <Switch
          label={$LL.settingsAppShowInDock()}
          checked={prefs.value.dock.includes(spec.id)}
          onchange={(on) => (on ? prefs.pin(spec.id) : prefs.unpin(spec.id))}
        />
      </Row>
      {#if prefs.keepsBackground && mayRunHidden}
        <Row
          label={$LL.settingsAppRunHidden()}
          sub={prefs.value.background ? $LL.settingsAppRunHiddenSub() : $LL.settingsAppRunHiddenOff()}
        >
          <Switch
            label={$LL.settingsAppRunHidden()}
            disabled={!prefs.value.background}
            checked={prefs.value.background && !prefs.value.background_denied.includes(spec.id)}
            onchange={(on) => prefs.setBackground(spec.id, on)}
          />
        </Row>
      {/if}
    </Group>

    {#if spec.kind === 'web'}
      <Group title={$LL.settingsAppPermissions()}>
        {#if spec.permissions?.length}
          {#each spec.permissions as p (p)}
            <Row label={permissionText(p)} />
          {/each}
        {:else}
          <Row label={$LL.settingsAppNoPermissions()} />
        {/if}
      </Group>
    {/if}

    {#if spec.settings}
      <Group title={$LL.settingsAppOwnSettings()}>
        {#key spec.id}<AppSettingsHost {spec} />{/key}
      </Group>
    {/if}
  {/if}
</SettingsPage>
