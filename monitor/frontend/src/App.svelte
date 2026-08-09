<script lang="ts">
  import { fly } from 'svelte/transition'
  import { servers } from './lib/servers.svelte'
  import { layout } from './lib/layout.svelte'
  import Sidebar from './components/Sidebar.svelte'
  import Dashboard from './pages/Dashboard.svelte'
  import PanelSettings from './pages/PanelSettings.svelte'
  import ServerSettings from './pages/ServerSettings.svelte'
  import Terminal from './pages/Terminal.svelte'

  // One key covering both axes (page view + selected server) so switching
  // either one gets the same page-level transition — not just Dashboard's
  // own internal card/detail switch, which has its own separate transition
  const pageKey = $derived(`${layout.view}:${servers.currentId}`)
</script>

<div class="min-h-screen bg-bg">
  <div class="flex min-h-screen">
    <Sidebar />
    <div class="flex-1 min-w-0">
      {#key pageKey}
        {@const back = layout.navDirection === 'back'}
        <div
          in:fly={{ x: back ? -16 : 16, duration: 200, delay: 150 }}
          out:fly={{ x: back ? 16 : -16, duration: 150 }}
        >
          {#if layout.view === 'panel'}
            <PanelSettings />
          {:else if layout.view === 'server-settings'}
            <ServerSettings onback={() => layout.back('dashboard')} />
          {:else if layout.view === 'terminal'}
            <Terminal />
          {:else}
            <Dashboard />
          {/if}
        </div>
      {/key}
    </div>
  </div>
</div>
