<script lang="ts">
  import { servers } from './lib/servers.svelte'
  import Sidebar from './components/Sidebar.svelte'
  import Dashboard from './pages/Dashboard.svelte'
</script>

<div class="min-h-screen bg-bg">
  <div class="flex min-h-screen">
    <Sidebar />
    <div class="flex-1 min-w-0">
      {#key servers.currentId}
        <Dashboard />
      {/key}
    </div>
  </div>
</div>
