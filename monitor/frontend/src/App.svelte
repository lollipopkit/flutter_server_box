<script lang="ts">
  import { servers } from './lib/servers.svelte'
  import Sidebar from './components/Sidebar.svelte'
  import Login from './pages/Login.svelte'
  import Dashboard from './pages/Dashboard.svelte'
</script>

<div class="min-h-screen bg-bg">
  {#key servers.currentId}
    {#if servers.authenticated}
      <div class="flex min-h-screen">
        <Sidebar />
        <div class="flex-1 min-w-0">
          <Dashboard />
        </div>
      </div>
    {:else}
      <Login />
    {/if}
  {/key}
</div>
