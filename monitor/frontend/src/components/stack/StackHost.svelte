<script lang="ts">
  /// A web app the agent deploys (`api::stacks`), as one desk window: set up
  /// (admins), its progress, and once it runs, the service itself in a frame
  /// through the agent's proxy. An account that is not an admin sees the app
  /// once an admin has set it up.

  import { Button, Card, Icon, IconButton, Spinner } from '../../desk/lk'
  import { AppToolbar, useLifecycle, useMenus, useWindow } from '../../desk/sys'
  import { LL, locale } from '../../i18n/i18n-svelte'
  import { api } from '../../lib/api'
  import { capabilitiesStore } from '../../lib/capabilities.svelte'
  import { servers } from '../../lib/servers.svelte'
  import type { StackApp, StackJob } from '../../types'
  import StackProgress from './StackProgress.svelte'
  import StackRemove from './StackRemove.svelte'
  import StackSetup from './StackSetup.svelte'
  import { stackRefusal } from './refusal'
  import { enterUrl, pick } from './text'
  import { untrack } from 'svelte'

  interface Props {
    /// The catalog entry (`store/apps/<id>`).
    stackId: string
  }

  const { stackId }: Props = $props()

  let app = $state<StackApp | null>(null)
  let error = $state('')
  let job = $state<StackJob | null>(null)
  let src = $state('')
  /// The page is HTTPS and the proxy is not: the browser blocks the frame.
  let mixed = $state(false)
  let removing = $state(false)

  const lifecycle = useLifecycle()
  const win = useWindow()
  const admin = $derived(capabilitiesStore.byServer[servers.currentId]?.me?.admin === true)
  const stack = $derived(app?.stack ?? null)
  const title = $derived(app ? pick(app.manifest.title, $locale) : '')

  async function load(serverId = servers.currentId) {
    error = ''
    try {
      const found = (await api.listStacks()).apps.find((a) => a.manifest.id === stackId) ?? null
      if (serverId !== servers.currentId) return
      app = found
      if (found?.job?.state === 'running') {
        job = found.job
      } else if (found?.stack?.state === 'installed' && found.proxy) {
        await enter()
      }
    } catch (e) {
      error = e instanceof Error ? e.message : String(e)
    }
  }

  $effect(() => {
    const serverId = servers.currentId
    untrack(() => void load(serverId))
  })

  async function entryUrl(): Promise<{ url: string; tls: boolean }> {
    const entry = await api.enterStack(stackId)
    return { url: enterUrl(servers.current?.url ?? '', entry), tls: entry.url ? entry.url.startsWith('https:') : entry.tls }
  }

  async function enter() {
    const { url, tls } = await entryUrl()
    const loopback = ['localhost', '127.0.0.1', '[::1]'].includes(new URL(url).hostname)
    mixed = window.location.protocol === 'https:' && !tls && !loopback
    src = url
  }

  async function openTab() {
    try {
      window.open((await entryUrl()).url, '_blank', 'noopener')
    } catch (e) {
      error = e instanceof Error ? e.message : String(e)
    }
  }

  async function act(action: 'start' | 'stop' | 'restart' | 'update') {
    error = ''
    try {
      job = await api.stackAction(stackId, action)
      src = ''
    } catch (e) {
      error = app ? stackRefusal(e, app.manifest, stack?.settings, $LL, $locale).text : e instanceof Error ? e.message : String(e)
    }
  }

  function finished(done: StackJob) {
    job = null
    // Whether the panel offers this app follows what is deployed.
    void capabilitiesStore.refresh(servers.currentId)
    if (done.kind === 'remove' && done.state === 'succeeded') {
      win.close()
      return
    }
    void load()
  }

  function jobTitle(j: StackJob): string {
    if (j.kind === 'install') return $LL.stackInstalling({ name: title })
    if (j.kind === 'update') return $LL.stackUpdating({ name: title })
    if (j.kind === 'reconfigure') return $LL.stackReconfiguring({ name: title })
    if (j.kind === 'remove') return $LL.stackRemoving({ name: title })
    return $LL.stackWorking()
  }

  useMenus(() =>
    admin && stack
      ? [
          {
            label: title,
            items: [
              ...(app && stack.version !== app.manifest.version
                ? [{ label: $LL.stackUpdate({ version: app.manifest.version }), icon: 'system_update', action: () => void act('update') }]
                : []),
              { label: $LL.stackRestart(), icon: 'restart_alt', disabled: !!job, action: () => void act('restart') },
              { label: $LL.stackStop(), icon: 'stop', disabled: !!job, action: () => void act('stop') },
              { label: $LL.stackStart(), icon: 'play_arrow', disabled: !!job, action: () => void act('start') },
              { separator: true as const },
              {
                label: $LL.stackChangeSettings(),
                icon: 'tune',
                disabled: !!job,
                action: () => win.open('serverbox.settings', { appState: { section: 'apps', stack: stackId } }),
              },
              { label: $LL.stackRemove(), icon: 'delete', danger: true, disabled: !!job, action: () => (removing = true) },
            ],
          },
        ]
      : [],
  )
</script>

<div class="flex h-full flex-1 flex-col">
  <AppToolbar subtitle={stack ? `${app?.manifest.project} ${stack.version}` : undefined}>
    {#snippet actions()}
      {#if src}
        <IconButton icon="open_in_new" label={$LL.stackOpenTab()} onclick={() => void openTab()} />
        <IconButton icon="refresh" label={$LL.refresh()} onclick={() => void enter()} />
      {/if}
    {/snippet}
  </AppToolbar>

  {#if src && !job}
    {#if mixed}
      <main class="pane-form pt-[5px]">
        <Card class="flex items-start gap-[9px] text-[13px] text-(--color-warning)">
          <Icon name="warning" size={17} />
          <p>{$LL.stackMixedContent()}</p>
        </Card>
      </main>
    {:else}
      <div class="relative min-h-0 flex-1">
        <iframe
          title={title}
          {src}
          class="absolute inset-0 h-full w-full border-0 bg-(--surface-window)"
          allow="clipboard-write; fullscreen"
          referrerpolicy="no-referrer"
        ></iframe>
        <!-- A click inside a frame never reaches this page, so the window
             would not come forward: while it is not in front, the first click
             lands here instead. -->
        {#if lifecycle.state !== 'active'}<div class="absolute inset-0" aria-hidden="true"></div>{/if}
      </div>
    {/if}
  {:else}
    <div class="flex-1 overflow-auto">
      <main class="pane-form space-y-[13px] pb-[21px] pt-[5px]">
        {#if error}
          <Card class="flex items-start gap-[9px] text-[13px] text-(--color-danger)">
            <Icon name="error" size={17} />
            <p>{error}</p>
          </Card>
        {/if}
        {#if !app}
          {#if !error}<Card><Spinner size={20} /></Card>{/if}
        {:else if job}
          {#key job.id}
            <StackProgress {stackId} {job} title={jobTitle(job)} ondone={finished} />
          {/key}
        {:else if !stack}
          {#if admin}
            <StackSetup manifest={app.manifest} onstarted={(j) => (job = j)} />
          {:else}
            <div class="flex flex-col items-center gap-[9px] py-[55px] text-(--text-tertiary)">
              <Icon name={app.manifest.glyph} size={48} />
              <p class="text-[15px] font-semibold text-(--text-secondary)">{$LL.stackNotSetUp()}</p>
              <p class="text-[13px]">{$LL.stackAskAdmin()}</p>
            </div>
          {/if}
        {:else if stack.state === 'failed'}
          <Card class="space-y-[9px]">
            <div class="flex items-center gap-[9px] text-(--color-danger)">
              <Icon name="error" size={17} />
              <p class="text-[15px] font-semibold">{$LL.stackFailed()}</p>
            </div>
            {#if stack.last_error}<p class="lk-mono text-[12px] text-(--text-secondary)">{stack.last_error}</p>{/if}
            {#if admin}
              <div class="flex justify-end gap-[9px]">
                <Button variant="secondary" onclick={() => (removing = true)}>{$LL.stackRemove()}</Button>
                <Button onclick={() => void act('update')}>{$LL.stackRetry()}</Button>
              </div>
            {/if}
          </Card>
        {:else}
          <Card class="flex items-start gap-[9px] text-[13px] text-(--text-secondary)">
            <Icon name="info" size={17} />
            <div class="flex-1 space-y-[9px]">
              <p>{$LL.stackNotReachable()}</p>
              <Button variant="secondary" size="sm" onclick={() => void load()}>{$LL.refresh()}</Button>
            </div>
          </Card>
        {/if}
      </main>
    </div>
  {/if}
</div>

<StackRemove
  open={removing}
  {stackId}
  name={title}
  onstarted={(j) => {
    src = ''
    job = j
  }}
  onclose={() => (removing = false)}
/>
