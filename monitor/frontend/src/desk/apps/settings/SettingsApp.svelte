<script lang="ts">
  /// Settings: a sidebar of sections with the chosen one's panel beside it,
  /// after the System Settings the desk imitates. The sections that belong to
  /// this browser come first; the agent's own configuration follows.

  import { SidebarItem, SidebarSection } from '../../lk'
  import { PageStack, SplitView, useWindow } from '../../sys'
  import { LL } from '../../../i18n/i18n-svelte'
  import { capabilitiesStore } from '../../../lib/capabilities.svelte'
  import { servers } from '../../../lib/servers.svelte'
  import AccessSection from './AccessSection.svelte'
  import AccountSection from './AccountSection.svelte'
  import AppearanceSection from './AppearanceSection.svelte'
  import AppPage from './AppPage.svelte'
  import AppsSection from './AppsSection.svelte'
  import ThemeStorePage from './ThemeStorePage.svelte'
  import { useDeskPrefs } from '../../deskState.svelte'
  import GeneralSection from './GeneralSection.svelte'
  import ServerSection from './ServerSection.svelte'
  import { resolveSection, type SettingsSection } from './sections'

  const win = useWindow()

  $effect(() => {
    if (servers.authenticated) void capabilitiesStore.ensure(servers.currentId)
  })
  const caps = $derived(capabilitiesStore.byServer[servers.currentId])
  /// Accounts and roles exist only on an agent that reports who is asking:
  /// without `me` (a watch token, an agent from before roles) there is
  /// nothing to manage here, as before; `admin: false` is refused.
  const admin = $derived(caps?.me?.admin === true)

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

  /// The app whose page is open under Apps (`{ section: 'apps', app }`), so a
  /// reload or another app can open Settings straight at it.
  const deskPrefs = useDeskPrefs()
  const appPage = $derived.by(() => {
    if (current !== 'apps') return null
    const id = (win.appState as { app?: unknown } | null)?.app
    return typeof id === 'string' ? (deskPrefs.apps.find((a) => a.id === id) ?? null) : null
  })

  function openApp(app: string) {
    win.setAppState({ section: 'apps', app })
  }

  /// The theme store, a page over Appearance (`{ section: 'appearance', page: 'store' }`).
  const storePage = $derived(
    current === 'appearance' && (win.appState as { page?: unknown } | null)?.page === 'store' && deskPrefs.themes !== null,
  )
  let leftStore = $state(false)
  function openStore() {
    win.setAppState({ section: 'appearance', page: 'store' })
  }
  function leaveStore() {
    leftStore = true
    show('appearance')
  }

  /// The app page last gone back from: a swipe forward on Apps reopens it.
  let leftApp = $state<string | null>(null)
  function leaveApp() {
    leftApp = appPage?.id ?? null
    show('apps')
  }
</script>

<SplitView>
  {#snippet sidebar()}
    <SidebarSection title={$LL.settingsThisBrowser()}>
      <SidebarItem
        label={$LL.settingsGeneral()}
        icon="tune"
        active={current === 'general'}
        onclick={() => show('general')}
      />
      <SidebarItem
        label={$LL.deskAppearance()}
        icon="palette"
        active={current === 'appearance'}
        onclick={() => show('appearance')}
      />
    </SidebarSection>
    <SidebarSection title={$LL.settingsThisServer()}>
      <SidebarItem
        label={$LL.settingsApps()}
        icon="apps"
        active={current === 'apps'}
        onclick={() => show('apps')}
      />
      <SidebarItem
        label={$LL.settingsAccount()}
        icon="person"
        active={current === 'account'}
        onclick={() => show('account')}
      />
      <SidebarItem
        label={$LL.serverSettings()}
        icon="dns"
        active={current === 'server'}
        onclick={() => show('server')}
      />
      {#if admin}
        <SidebarItem
          label={$LL.settingsAccess()}
          icon="shield_person"
          active={current === 'access'}
          onclick={() => show('access')}
        />
      {/if}
    </SidebarSection>
  {/snippet}

  <!-- An app's page is a page over Apps, the theme store one over
       Appearance; the sections are peers. -->
  <PageStack
    key={appPage ? `apps/${appPage.id}` : storePage ? 'appearance/store' : current}
    depth={appPage || storePage ? 1 : 0}
    back={appPage ? { key: 'apps', go: leaveApp } : storePage ? { key: 'appearance', go: leaveStore } : null}
    forward={current === 'apps' && !appPage && leftApp
      ? { key: `apps/${leftApp}`, go: () => openApp(leftApp!) }
      : current === 'appearance' && !storePage && leftStore
        ? { key: 'appearance/store', go: openStore }
        : null}
  >
  {#if current === 'general'}
    <GeneralSection />
  {:else if current === 'appearance' && storePage}
    <ThemeStorePage onback={leaveStore} />
  {:else if current === 'appearance'}
    <AppearanceSection onstore={openStore} />
  {:else if current === 'apps' && appPage}
    <AppPage spec={appPage} onback={leaveApp} />
  {:else if current === 'apps'}
    <AppsSection onopen={openApp} />
  {:else if current === 'account'}
    <AccountSection />
  {:else if current === 'server'}
    <ServerSection />
  {:else}
    <AccessSection />
  {/if}
  </PageStack>
</SplitView>
