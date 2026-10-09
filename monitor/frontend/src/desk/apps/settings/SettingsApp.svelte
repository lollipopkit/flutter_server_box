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
  import AgentSection from './AgentSection.svelte'
  import AgentMemoryPage from './AgentMemoryPage.svelte'
  import AgentPermissionsPage from './AgentPermissionsPage.svelte'
  import AgentProviderPage from './AgentProviderPage.svelte'
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
  /// Agent mode, on an agent that runs it, for an account that may use it.
  const agent = $derived(!!caps?.features?.includes('agent_mode') && caps.grants?.shell?.ok === true)
  const current = $derived((section === 'access' && !admin) || (section === 'agent' && !agent) ? 'account' : section)

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

  /// An Agent provider's page, over Agent (`{ section: 'agent', provider }`).
  const agentProvider = $derived.by(() => {
    if (current !== 'agent') return null
    const p = (win.appState as { provider?: unknown } | null)?.provider
    return typeof p === 'string' && p ? p : null
  })
  function openProvider(provider: string) {
    win.setAppState({ section: 'agent', provider })
  }
  /// The account's memory, a page over Agent (`{ section: 'agent', page:
  /// 'memory' }`), and one of its files over that (`file`; empty for a new one).
  const agentMemory = $derived.by(() => {
    if (current !== 'agent') return null
    const st = win.appState as { page?: unknown; file?: unknown } | null
    if (st?.page !== 'memory') return null
    return { file: typeof st.file === 'string' ? st.file : null }
  })
  /// How commands are approved, a page over Agent (`{ section: 'agent', page: 'permissions' }`).
  const agentPermissions = $derived(current === 'agent' && (win.appState as { page?: unknown } | null)?.page === 'permissions')
  function openPermissions() {
    win.setAppState({ section: 'agent', page: 'permissions' })
  }
  function openMemory(file: string | null = null) {
    win.setAppState(file === null ? { section: 'agent', page: 'memory' } : { section: 'agent', page: 'memory', file })
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
      {#if agent}
        <SidebarItem
          label={$LL.settingsAgent()}
          icon="auto_awesome"
          active={current === 'agent'}
          onclick={() => show('agent')}
        />
      {/if}
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
    key={appPage
      ? `apps/${appPage.id}`
      : storePage
        ? 'appearance/store'
        : agentPermissions
          ? 'agent/permissions'
          : agentMemory
          ? agentMemory.file === null
            ? 'agent/memory'
            : `agent/memory/${agentMemory.file}`
          : agentProvider
            ? `agent/${agentProvider}`
            : current}
    depth={appPage || storePage || agentPermissions ? 1 : agentMemory ? (agentMemory.file === null ? 1 : 2) : agentProvider ? (agentProvider === 'new' ? 1 : 2) : 0}
    back={appPage
      ? { key: 'apps', go: leaveApp }
      : storePage
        ? { key: 'appearance', go: leaveStore }
        : agentPermissions
          ? { key: 'agent', go: () => show('agent') }
          : agentMemory
          ? agentMemory.file === null
            ? { key: 'agent', go: () => show('agent') }
            : { key: 'agent/memory', go: () => openMemory() }
          : agentProvider
            ? { key: 'agent', go: () => show('agent') }
            : null}
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
  {:else if current === 'agent' && agentPermissions}
    <AgentPermissionsPage onback={() => show('agent')} />
  {:else if current === 'agent' && agentMemory}
    <AgentMemoryPage
      file={agentMemory.file}
      onback={() => (agentMemory.file === null ? show('agent') : openMemory())}
      onopen={openMemory}
    />
  {:else if current === 'agent' && agentProvider}
    <AgentProviderPage provider={agentProvider} onback={() => show('agent')} onopen={openProvider} />
  {:else if current === 'agent'}
    <AgentSection onprovider={openProvider} onmemory={() => openMemory()} onpermissions={openPermissions} />
  {:else}
    <AccessSection />
  {/if}
  </PageStack>
</SplitView>
