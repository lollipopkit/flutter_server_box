<script lang="ts">
  import { servers } from './lib/servers.svelte'
  import { layout } from './lib/layout.svelte'
  import Sidebar from './components/Sidebar.svelte'
  import Dashboard from './pages/Dashboard.svelte'
  import Settings from './pages/Settings.svelte'
</script>

<div class="min-h-screen bg-bg">
  <div class="flex min-h-screen">
    <Sidebar />
    <div class="flex-1 min-w-0">
      {#if layout.view === 'settings'}
        <Settings />
      {:else}
        {#key servers.currentId}
          <Dashboard />
        {/key}
      {/if}
    </div>
  </div>
</div>
