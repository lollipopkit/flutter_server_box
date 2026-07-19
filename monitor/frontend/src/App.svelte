<script lang="ts">
  import { servers } from './lib/servers.svelte'
  import Login from './pages/Login.svelte'
  import Dashboard from './pages/Dashboard.svelte'
</script>

<div class="min-h-screen bg-bg">
  {#key servers.currentId}
    {#if servers.authenticated}
      <Dashboard />
    {:else}
      <Login />
    {/if}
  {/key}
</div>
