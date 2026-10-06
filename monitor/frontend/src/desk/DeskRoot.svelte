<script lang="ts">
  import { onDestroy, onMount } from 'svelte'
  import { capabilitiesStore } from '../lib/capabilities.svelte'
  import { health } from '../lib/health.svelte'
  import { serverNames } from '../lib/serverNames.svelte'
  import { servers } from '../lib/servers.svelte'
  import Desk from './Desk.svelte'
  import LockScreen from './lock/LockScreen.svelte'
  import './desk.css'

  /// The panel: one server's desk, and the lock screen over it.
  ///
  /// As on a Mac with several accounts: locking keeps the desk underneath as
  /// it is; choosing another server on the lock screen is switching to its
  /// desk, and this one goes (its windows are kept by its own agent).

  let locked = $state(!servers.authenticated)

  onMount(() => {
    // Before the pollers: the list may still hold the assumed same-origin
    // entry, and on a static host there is nothing there to poll.
    void servers.confirmSameOrigin()
    health.start()
    serverNames.start()
  })
  onDestroy(() => {
    health.stop()
    serverNames.stop()
  })

  // A session that ended (a 401, a logout) is the lock screen.
  $effect(() => {
    if (!servers.authenticated) locked = true
  })

  // Names and capabilities as soon as a session exists, not at the next poll.
  $effect(() => {
    servers.list.map((s) => s.token).join(',')
    void serverNames.refresh()
    for (const s of servers.list) if (!s.token) capabilitiesStore.clear(s.id)
  })

  function unlock(serverId: string) {
    servers.select(serverId)
    locked = false
  }

  function switchTo(serverId: string) {
    servers.select(serverId)
    if (!servers.authenticated) locked = true
  }
</script>

{#if servers.current?.token}
  {#key `${servers.current.id}:${servers.current.token}`}
    <Desk entry={servers.current} onlock={() => (locked = true)} onswitch={switchTo} />
  {/key}
{/if}
{#if locked || !servers.current?.token}
  <LockScreen onunlock={unlock} />
{/if}
