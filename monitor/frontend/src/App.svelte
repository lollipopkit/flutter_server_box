<script lang="ts">
  import { auth } from './lib/auth.svelte'
  import Login from './pages/Login.svelte'
  import Dashboard from './pages/Dashboard.svelte'
</script>

<div class="min-h-screen bg-gray-50 dark:bg-gray-950">
  {#if auth.authenticated}
    <Dashboard />
  {:else}
    <Login />
  {/if}
</div>
