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
  import Spinner from '../lk/Spinner.svelte'
  import AppToolbar from '../sys/AppToolbar.svelte'
  import { useIntents, useMenus, useWindow } from '../sys/window.svelte'
  import { WebAppBridge } from './bridge.svelte'

  const win = useWindow()
  const desk = useDesk()
  let frame = $state<HTMLIFrameElement | null>(null)
  let src = $state<string | null>(null)
  let failed = $state(false)

  const bridge = new WebAppBridge(
    {
      handle: win,
      allows: (p) => desk.allows(win.appId, p),
      theme: () => ({ dark: theme.dark }),
      locale: () => get(locale),
      backend: (method, params) => deskApi.callApp(desk.entry, win.appId, method, params),
    },
  )

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
        if (!cancelled) src = `${desk.entry.url ?? ''}${r.url}`
      })
      .catch(() => {
        if (!cancelled) failed = true
      })
    return () => {
      cancelled = true
    }
  })

  useMenus(() => bridge.menuEntries())
  useIntents((intent) => bridge.intent(intent))
  $effect(() => bridge.send('lifecycle', win.lifecycle))
  $effect(() => bridge.send('theme', { dark: theme.dark }))
  $effect(() => bridge.send('locale', $locale))
  onDestroy(() => bridge.close())
</script>

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
  {:else}
    <div class="flex h-full items-center justify-center"><Spinner /></div>
  {/if}
</div>
