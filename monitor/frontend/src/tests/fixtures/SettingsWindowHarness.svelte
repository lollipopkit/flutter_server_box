<script lang="ts">
  /// Renders the Settings app inside a real window context, so a test can see
  /// what the app writes to `appState` — the only place `useWindow()` answers
  /// anything but its do-nothing fallback.

  import SettingsApp from '../../desk/apps/settings/SettingsApp.svelte'
  import { provideDesk, provideWindow, type Desk } from '../../desk/deskState.svelte'
  import { WindowChrome } from '../../desk/window/chrome.svelte'

  interface Props {
    desk: Desk
    id: string
  }

  const { desk, id }: Props = $props()

  // svelte-ignore state_referenced_locally
  provideDesk(desk)
  const chrome = new WindowChrome()
  // svelte-ignore state_referenced_locally
  provideWindow(desk, id, chrome)
</script>

<!-- What the window's frame would draw: the sidebar and the bar's title. -->
{#if chrome.sidebar}<nav>{@render chrome.sidebar.content()}</nav>{/if}
{#if chrome.toolbar?.title}<h1>{chrome.toolbar.title}</h1>{/if}
<SettingsApp />
