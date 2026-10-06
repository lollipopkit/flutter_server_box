<script lang="ts">
  /// Settings: a sidebar of sections with the chosen one's panel beside it,
  /// after the System Settings the desk imitates. The sections that belong to
  /// this browser come first; the agent's own configuration follows.

  import { CircleUserRound, Image, ServerCog, ShieldCheck, SlidersHorizontal } from '@lucide/svelte'
  import { LL } from '../../../i18n/i18n-svelte'
  import { isAdmin } from '../../../lib/access'
  import { capabilitiesStore } from '../../../lib/capabilities.svelte'
  import { servers } from '../../../lib/servers.svelte'
  import { useWindow } from '../../deskState.svelte'
  import SourceGroup from '../../ui/SourceGroup.svelte'
  import SourceItem from '../../ui/SourceItem.svelte'
  import SplitView from '../../ui/SplitView.svelte'
  import AccessSection from './AccessSection.svelte'
  import AccountSection from './AccountSection.svelte'
  import AppearanceSection from './AppearanceSection.svelte'
  import GeneralSection from './GeneralSection.svelte'
  import ServerSection from './ServerSection.svelte'
  import { resolveSection, type SettingsSection } from './sections'

  const win = useWindow()

  $effect(() => {
    if (servers.authenticated) void capabilitiesStore.ensure(servers.currentId)
  })
  const caps = $derived(capabilitiesStore.byServer[servers.currentId])
  /// An agent without roles reports no `me` (so the panel manages accounts on
  /// its own) and one that says `admin: false` is refused: as before, the
  /// Access section is offered only where administering is allowed.
  const admin = $derived(isAdmin(caps) === true)

  /// Which section is showing, read from the window's own state: a reload
  /// restores it, another app can open Settings straight at one, and a second
  /// `open('settings', { appState: { section } })` switches to it.
  const section = $derived(resolveSection(win.appState))
  /// An account that is no longer an administrator (or a window restored
  /// with `access`) falls back rather than showing a panel with nothing in it.
  const current = $derived(section === 'access' && !admin ? 'account' : section)

  function show(next: SettingsSection) {
    win.setAppState({ section: next })
  }
</script>

<SplitView width={14}>
  {#snippet sidebar()}
    <SourceGroup title={$LL.settingsThisBrowser()}>
      <SourceItem
        label={$LL.settingsGeneral()}
        icon={SlidersHorizontal}
        selected={current === 'general'}
        onclick={() => show('general')}
      />
      <SourceItem
        label={$LL.deskAppearance()}
        icon={Image}
        selected={current === 'appearance'}
        onclick={() => show('appearance')}
      />
    </SourceGroup>
    <SourceGroup title={$LL.settingsThisServer()}>
      <SourceItem
        label={$LL.settingsAccount()}
        icon={CircleUserRound}
        selected={current === 'account'}
        onclick={() => show('account')}
      />
      <SourceItem
        label={$LL.serverSettings()}
        icon={ServerCog}
        selected={current === 'server'}
        onclick={() => show('server')}
      />
      {#if admin}
        <SourceItem
          label={$LL.settingsAccess()}
          icon={ShieldCheck}
          selected={current === 'access'}
          onclick={() => show('access')}
        />
      {/if}
    </SourceGroup>
  {/snippet}

  {#if current === 'general'}
    <GeneralSection />
  {:else if current === 'appearance'}
    <AppearanceSection />
  {:else if current === 'account'}
    <AccountSection />
  {:else if current === 'server'}
    <ServerSection />
  {:else}
    <AccessSection />
  {/if}
</SplitView>
