<script lang="ts">
  import { onDestroy, onMount } from 'svelte'
  import {
    Monitor,
    LogOut,
    Cpu,
    HardDrive,
    MemoryStick,
    Thermometer,
    Network,
    CircleAlert,
    RefreshCw,
  } from '@lucide/svelte'
  import Spinner from '../components/Spinner.svelte'
  import StatCard from '../components/StatCard.svelte'
  import ThemeToggle from '../components/ThemeToggle.svelte'
  import { api } from '../lib/api'
  import { auth } from '../lib/auth.svelte'
  import { Poller } from '../lib/poller.svelte'

  const status = new Poller(api.getStatus, 5000)
  const metrics = new Poller(api.getMetrics, 5000)

  onMount(() => {
    status.start()
    metrics.start()
  })
  onDestroy(() => {
    status.stop()
    metrics.stop()
  })

  const thresholds = {
    cpu: { warning: 70, danger: 85 },
    memory: { warning: 80, danger: 90 },
    disk: { warning: 85, danger: 95 },
  }

  function statusBadge(value: string | undefined, type: keyof typeof thresholds): string {
    const percentage = parseFloat(value ?? '0')
    if (isNaN(percentage)) return 'status-success'
    const t = thresholds[type]
    if (percentage >= t.danger) return 'status-danger'
    if (percentage >= t.warning) return 'status-warning'
    return 'status-success'
  }

  const error = $derived(status.error ?? metrics.error)
</script>

{#if status.loading && metrics.loading}
  <div class="min-h-screen flex items-center justify-center">
    <Spinner size="lg" />
  </div>
{:else}
  <header class="bg-white shadow-sm border-b border-gray-200 dark:bg-gray-900 dark:border-gray-800">
    <div class="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8">
      <div class="flex justify-between items-center py-4">
        <div class="flex items-center">
          <Monitor class="w-8 h-8 text-primary-600 mr-3" />
          <div>
            <h1 class="text-xl font-semibold text-strong">ServerBox Monitor</h1>
            <p class="text-sm text-gray-500 dark:text-gray-400">
              {status.data?.name || 'Unknown Server'}
            </p>
          </div>
        </div>

        <div class="flex items-center space-x-4">
          <div class="text-sm text-muted">
            Welcome, <span class="font-medium">{auth.username}</span>
          </div>
          <ThemeToggle />
          <button onclick={() => auth.logout()} class="btn btn-secondary flex items-center">
            <LogOut class="w-4 h-4 mr-2" />
            Logout
          </button>
        </div>
      </div>
    </div>
  </header>

  <main class="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8 py-8">
    {#if error}
      <div
        class="mb-6 bg-danger-50 border border-danger-200 rounded-md p-4 dark:bg-danger-600/10 dark:border-danger-600/30"
      >
        <div class="flex">
          <CircleAlert class="w-5 h-5 text-danger-400" />
          <div class="ml-3">
            <p class="text-sm text-danger-700 dark:text-danger-400">{error}</p>
          </div>
        </div>
      </div>
    {/if}

    <div class="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-4 gap-6 mb-8">
      <StatCard
        icon={Cpu}
        iconClass="text-blue-500"
        label="CPU Usage"
        value={status.data?.cpu || '--'}
        badge={status.data?.cpu ? 'Active' : 'N/A'}
        badgeClass={statusBadge(status.data?.cpu, 'cpu')}
      />
      <StatCard
        icon={MemoryStick}
        iconClass="text-green-500"
        label="Memory"
        value={status.data?.memory || '--'}
        valueClass="text-lg"
        badge={status.data?.memory ? 'Active' : 'N/A'}
        badgeClass={statusBadge(status.data?.memory, 'memory')}
      />
      <StatCard
        icon={HardDrive}
        iconClass="text-yellow-500"
        label="Disk Usage"
        value={status.data?.disk || '--'}
        valueClass="text-lg"
        badge={status.data?.disk ? 'Active' : 'N/A'}
        badgeClass={statusBadge(status.data?.disk, 'disk')}
      />
      <StatCard
        icon={Network}
        iconClass="text-purple-500"
        label="Network"
        value={status.data?.network || '--'}
        valueClass="text-sm"
        badge="Active"
        badgeClass="status-success"
      />
    </div>

    {#if metrics.data}
      {@const m = metrics.data}
      <div class="grid grid-cols-1 lg:grid-cols-2 gap-6">
        <div class="card">
          <h3 class="text-lg font-semibold text-strong mb-4">System Information</h3>
          <div class="space-y-3">
            <div class="flex justify-between">
              <span class="text-sm text-muted">Server Name:</span>
              <span class="text-sm font-medium">{m.server_name}</span>
            </div>
            <div class="flex justify-between">
              <span class="text-sm text-muted">Last Updated:</span>
              <span class="text-sm font-medium">
                {new Date(m.timestamp).toLocaleString()}
              </span>
            </div>
            <div class="flex justify-between">
              <span class="text-sm text-muted">CPU Usage:</span>
              <span class="text-sm font-medium">{m.cpu_usage.toFixed(1)}%</span>
            </div>
            <div class="flex justify-between">
              <span class="text-sm text-muted">Memory Usage:</span>
              <span class="text-sm font-medium">{m.memory.usage_percent.toFixed(1)}%</span>
            </div>
            <div class="flex justify-between">
              <span class="text-sm text-muted">Disk Usage:</span>
              <span class="text-sm font-medium">{m.disk.usage_percent.toFixed(1)}%</span>
            </div>
            {#if m.temperature != null}
              <div class="flex justify-between">
                <span class="text-sm text-muted">Temperature:</span>
                <span class="text-sm font-medium flex items-center">
                  <Thermometer class="w-4 h-4 mr-1" />
                  {m.temperature.toFixed(1)}°C
                </span>
              </div>
            {/if}
          </div>
        </div>

        <div class="card">
          <h3 class="text-lg font-semibold text-strong mb-4">Quick Actions</h3>
          <div class="space-y-3">
            <button
              onclick={() => window.location.reload()}
              class="btn-primary w-full flex items-center justify-center"
            >
              <RefreshCw class="w-4 h-4 mr-2" />
              Refresh Data
            </button>
            <div class="text-xs text-gray-500 dark:text-gray-400 text-center mt-4">
              Data refreshes automatically every 5 seconds
            </div>
          </div>
        </div>
      </div>
    {/if}
  </main>
{/if}
