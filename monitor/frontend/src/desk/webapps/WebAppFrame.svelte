<script lang="ts">
  /// An installed app's window content: its UI in a sandboxed frame (an
  /// opaque origin: no cookies, no storage of the panel's, no token), and the
  /// bridge that carries what it asks of the desk (`bridge.svelte.ts`).

  import { onDestroy } from 'svelte'
  import { get } from 'svelte/store'
  import { LL, locale } from '../../i18n/i18n-svelte'
  import { theme } from '../../lib/theme.svelte'
  import { deskApi } from '../deskApi'
  import { useDesk } from '../deskState.svelte'
  import IconButton from '../lk/IconButton.svelte'
  import SidebarItem from '../lk/SidebarItem.svelte'
  import SidebarSection from '../lk/SidebarSection.svelte'
  import Spinner from '../lk/Spinner.svelte'
  import AppToolbar from '../sys/AppToolbar.svelte'
  import { useIntents, useMenus, useWindow } from '../sys/window.svelte'
  import { ApiError } from '../../lib/api'
  import type { SudoAsk } from '../../../../sdk/serverbox-desk/src/protocol'
  import AppSudoDialog from './AppSudoDialog.svelte'
  import PowerModal from '../../components/PowerModal.svelte'
  import StackSheet from '../../components/stack/StackSheet.svelte'
  import { app } from '../registry.svelte'
  import { BridgeError, WebAppBridge, type BackendHost, type SudoGiven } from './bridge.svelte'

  const win = useWindow()
  const desk = useDesk()
  let frame = $state<HTMLIFrameElement | null>(null)
  let src = $state<string | null>(null)
  let failed = $state(false)
  /// The desk's design system for the frame (the agent's `/desk-app/desk.css`),
  /// from an agent that serves one.
  let stylesheet: string | null = null

  /// The desk's mode and its installed theme's tokens (none for the design
  /// system's own), which `serverbox-desk` sets on the app's page.
  const appTheme = () => ({ dark: theme.dark, tokens: desk.themes?.vars(theme.dark) ?? {} })

  /// The sudo dialog shown now: what the app said, what runs once
  /// confirmed, and how the frame's call ends.
  let sudo = $state<{ ask: SudoAsk; remembered: boolean; run: (g: SudoGiven) => Promise<void>; decline: () => void } | null>(null)

  /// A refusal from the agent as the frame gets it: the backend's code and
  /// words.
  function bridged<T>(p: Promise<T>): Promise<T> {
    return p.catch((e: unknown) => {
      if (e instanceof ApiError) throw new BridgeError(e.code ?? (e.body?.error as string | undefined) ?? 'failed', (e.body?.message as string | undefined) ?? undefined)
      throw e
    })
  }

  /// A sudo dialog is asked for or open: one at a time.
  let asking = false

  const asSudo = (g?: SudoGiven) => (g ? { password: g.password || null, remember: g.remember } : undefined)

  const backend: BackendHost = {
    call: (fn, args, given) => bridged(deskApi.callApp(desk.entry, win.appId, fn, args, asSudo(given)).then((r) => r.value)),
    job: (fn, args, given) => bridged(deskApi.startAppJob(desk.entry, win.appId, fn, args, asSudo(given))),
    view: (since) => bridged(deskApi.appJob(desk.entry, win.appId, since)),
    cancel: () => bridged(deskApi.cancelAppJob(desk.entry, win.appId).then(() => undefined)),
    async sudo(ask, run) {
      // Taken before the first await: two asks at once must not both pass.
      if (asking) throw new BridgeError('busy')
      asking = true
      const remembered = await deskApi.sudoRemembered(desk.entry).then((r) => r.remembered, () => false)
      return new Promise((resolve, reject) => {
        sudo = {
          ask,
          remembered,
          // sudo's refusal stays in the dialog; anything else is the frame's.
          run: async (given) => {
            try {
              resolve(await run(given))
            } catch (e) {
              if (e instanceof BridgeError && (e.message === 'sudo_rejected' || e.message === 'sudo_unavailable')) {
                throw new ApiError(e.message, 403, e.message)
              }
              reject(e)
            }
            sudo = null
            asking = false
          },
          decline: () => {
            reject(new BridgeError('declined'))
            sudo = null
            asking = false
          },
        }
      })
    },
  }

  let power = $state<'reboot' | 'shutdown' | null>(null)
  let sheet = $state<{ id: string; model: string | null; backend: string; done: () => void } | null>(null)

  const bridge = new WebAppBridge({
    handle: win,
    allows: (p) => desk.allows(win.appId, p),
    theme: () => appTheme(),
    locale: () => get(locale),
    stylesheet: () => stylesheet,
    backend,
    power: (action) => (power = action),
    openStack: (id, model, backend) => new Promise<void>((done) => (sheet = { id, model, backend, done })),
  })

  /// The frame's first page gets the bridge's port. A second load is the app
  /// navigating away from its bundle (somewhere CSP does not reach): the
  /// bridge closes and the frame goes, so that page never acts as the app.
  let loads = 0
  function onload() {
    loads++
    if (loads > 1) {
      bridge.close()
      src = null
      failed = true
      return
    }
    const channel = new MessageChannel()
    bridge.attach(channel.port1)
    // An opaque origin cannot be named; the port goes to this frame's
    // window only.
    frame?.contentWindow?.postMessage({ sbm: 1, event: 'connect' }, '*', [channel.port2])
  }

  $effect(() => {
    let cancelled = false
    deskApi
      .launchApp(desk.entry, win.appId)
      .then((r) => {
        if (cancelled) return
        stylesheet = r.stylesheet ? `${desk.entry.url ?? ''}${r.stylesheet}` : null
        src = `${desk.entry.url ?? ''}${r.url}`
      })
      .catch(() => {
        if (!cancelled) failed = true
      })
    return () => {
      cancelled = true
    }
  })

  // The app's places, in the window's own inset sidebar. Pushed rather than
  // drawn through `SplitView`, which would remount the frame (a second load,
  // which ends it) when the app first describes them.
  $effect(() => {
    if (!win.chrome || bridge.sidebar.sections.length === 0) return
    return win.chrome.pushSidebar({ content: places, width: 196 })
  })

  useMenus(() => bridge.menuEntries())
  useIntents((intent) => bridge.intent(intent))
  $effect(() => bridge.send('lifecycle', win.lifecycle))
  $effect(() => bridge.send('theme', appTheme()))
  $effect(() => bridge.send('locale', $locale))
  onDestroy(() => {
    sudo?.decline()
    bridge.close()
  })
</script>

{#snippet places()}
  {#each bridge.sidebar.sections as section, i (i)}
    <SidebarSection title={section.title}>
      {#each section.items as item (item.id)}
        <SidebarItem label={item.label} icon={item.icon} trailing={item.trailing} active={bridge.sidebar.selected === item.id} onclick={() => bridge.navigate(item.id)} />
      {/each}
    </SidebarSection>
  {/each}
{/snippet}

<AppToolbar title={bridge.toolbar.title} subtitle={bridge.toolbar.subtitle}>
  {#snippet actions()}
    {#each bridge.toolbar.actions ?? [] as a, i (i)}
      {#if !a.separator}
        <IconButton icon={a.icon ?? 'radio_button_unchecked'} label={a.label} disabled={a.disabled} onclick={() => bridge.action(a.id)} />
      {/if}
    {/each}
  {/snippet}
</AppToolbar>

<div class="relative min-h-0 flex-1">
  {#if failed}
    <p class="p-6 text-[13px] text-(--color-danger)">{$LL.deskAppFailed()}</p>
  {:else if src}
    <iframe
      bind:this={frame}
      {src}
      title={win.appId}
      class="absolute inset-0 h-full w-full border-0 bg-(--surface-window)"
      sandbox="allow-scripts allow-forms"
      referrerpolicy="no-referrer"
      allow=""
      {onload}
    ></iframe>
    <!-- A click inside the frame never reaches the desk, so the window would
         not come forward: while it is not in front, the first click lands
         here instead. -->
    {#if win.lifecycle !== 'active'}<div class="absolute inset-0" aria-hidden="true"></div>{/if}
  {:else}
    <div class="flex h-full items-center justify-center"><Spinner /></div>
  {/if}
</div>

<AppSudoDialog app={app(win.appId)?.title($LL) ?? win.appId} ask={sudo?.ask ?? null} remembered={sudo?.remembered ?? false} run={(g) => sudo?.run(g) ?? Promise.resolve()} onclose={() => sudo?.decline()} />
{#if power}<PowerModal open initial={power} onclose={() => (power = null)} />{/if}
{#if sheet}
  <StackSheet
    stackId={sheet.id}
    model={sheet.model}
    backend={sheet.backend}
    onclose={() => {
      sheet?.done()
      sheet = null
    }}
  />
{/if}
