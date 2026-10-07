<script lang="ts">
  /// One pane of a window with panes: the app's content, given a
  /// `useWindow()` of its own (`PaneHost.svelte` says what each part means).

  import { onDestroy, setContext, type Component } from 'svelte'
  import { WINDOW, type LifecycleState, type WindowHandle } from '../sys/window.svelte'
  import type { PaneHostState } from './paneHostState.svelte'

  interface Props {
    host: PaneHostState
    paneId: string
    content: Component
  }

  const { host, paneId, content: Content }: Props = $props()

  // A pane keeps its id for life (the host's list is keyed by it).
  // svelte-ignore state_referenced_locally
  const id = paneId
  // svelte-ignore state_referenced_locally
  const parent = host.parent
  // svelte-ignore state_referenced_locally
  const chrome = host.chromeFor(id)

  const handle: WindowHandle = {
    id,
    get appId() {
      return parent.appId
    },
    get appState() {
      return host.stateOf(id)
    },
    setAppState: (state) => host.setState(id, state),
    setTitle: (title) => host.setTitle(id, title),
    setAppName: (name) => parent.setAppName(name),
    setIcon: (icon) => parent.setIcon(icon),
    setBadge: (badge) => parent.setBadge(badge),
    close: () => host.closePane(id),
    open: (appId, options) => parent.open(appId, options),
    openWindow: (appState) => parent.openWindow(appState),
    get canOpenWindow() {
      return parent.canOpenWindow
    },
    notify: (notice) => parent.notify(notice),
    get storage() {
      return parent.storage
    },
    handlers: (path, kind) => parent.handlers(path, kind),
    addPathIcon: (path, label) => parent.addPathIcon(path, label),
    get active() {
      return parent.active && host.focusId === id
    },
    get closed() {
      return host.wasClosed(id)
    },
    get lifecycle(): LifecycleState {
      const state = parent.lifecycle
      if (state === 'suspended' || state === 'background') return state
      // Another tab is on show: not drawn, still running.
      if (!host.shown(id)) return 'background'
      return state === 'active' && host.focusId !== id ? 'visible' : state
    },
    chrome,
    panes: {
      newTab: (state) => host.newTab(state),
      split: (side, state) => host.split(id, side, state),
      close: () => host.closePane(id),
      get count() {
        return host.count
      },
    },
  }
  setContext(WINDOW, handle)

  $effect.pre(() => {
    chrome.lifecycle = handle.lifecycle
  })

  onDestroy(() => host.release(id))
</script>

<Content />
