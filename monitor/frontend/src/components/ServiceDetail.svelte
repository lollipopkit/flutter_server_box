<script lang="ts">
  import { FileText, Info, ScrollText, type Icon as LucideIcon } from '@lucide/svelte'
  import { Card, Spinner } from '@serverbox/webui'
  import { api } from '../lib/api'
  import { LL } from '../i18n/i18n-svelte'
  import type { ServicePart, ServiceView } from '../types'

  interface Props {
    /// The unit's `key` as its listing gave it. Never a name typed here: the
    /// agent resolves it against a listing it runs itself.
    unitKey: string
  }

  const { unitKey }: Props = $props()

  /// The parts that are about one unit. `list` is the page this dialog is
  /// drawn over, so it is not one of them — which is why the tab set is its own
  /// type rather than `ServicePart` with an entry nothing draws.
  type Tab = Exclude<ServicePart, 'list'>

  /// The log first: it is the part a unit is usually opened for.
  let part = $state<Tab>('logs')
  let view = $state<ServiceView | null>(null)
  let loading = $state(false)
  let error = $state('')
  /// Each tab change answers a question asked while the previous one was still
  /// in flight, and the two are about the same unit — so only the newest reply
  /// is drawn, and a slow definition cannot land under a log tab.
  let requestId = 0

  async function load() {
    const id = ++requestId
    loading = true
    error = ''
    try {
      const next = await api.getServices(part, unitKey)
      if (id !== requestId) return
      view = next
    } catch (e) {
      if (id !== requestId) return
      error = e instanceof Error ? e.message : String(e)
    } finally {
      if (id === requestId) loading = false
    }
  }

  $effect(() => {
    // Both are dependencies: a different unit remounts this in practice, but
    // the tab is what changes on every click.
    void unitKey
    void part
    void load()
  })

  const PARTS: Record<Tab, { label: () => string; icon: typeof LucideIcon }> = {
    logs: { label: () => $LL.serviceLogs(), icon: ScrollText },
    definition: { label: () => $LL.serviceDefinition(), icon: FileText },
    status: { label: () => $LL.serviceStatus(), icon: Info },
  }

  const tabs: Tab[] = ['logs', 'definition', 'status']

  function reasonText(reason: ServiceView): string {
    switch (reason.reason_kind) {
      case 'no_log':
        return $LL.serviceNoLog()
      case 'no_such_unit':
        return $LL.serviceNoSuchUnit()
      default:
        return reason.reason ?? $LL.serviceUnreadable()
    }
  }
</script>

<div class="space-y-2">
  <div class="flex flex-wrap items-center gap-1">
    {#each tabs as tab (tab)}
      {@const { label, icon: Icon } = PARTS[tab]}
      {@const current = tab === part}
      <button
        class="inline-flex items-center gap-1 rounded border px-2 py-1 text-xs transition-colors {current
          ? 'border-primary text-fg-strong'
          : 'border-border text-muted-fg hover:text-fg'}"
        aria-current={current ? 'page' : undefined}
        onclick={() => (part = tab)}
      >
        <Icon class="h-3.5 w-3.5" />
        {label()}
      </button>
    {/each}
  </div>

  {#if error}
    <p class="text-sm text-danger">{error}</p>
  {:else if loading && !view}
    <Spinner class="w-4 h-4" />
  {:else if view && !view.available}
    <div class="space-y-1">
      <p class="text-sm text-muted-fg">{reasonText(view)}</p>
      {#if view.reason && view.reason_kind !== 'no_log'}
        <pre class="text-xs font-mono text-faint-fg whitespace-pre-wrap break-all">{view.reason}</pre>
      {/if}
    </div>
  {:else if view}
    {#if part === 'logs'}
      {#if view.log && view.log.lines.length > 0}
        <Card class="max-h-72 overflow-auto p-0">
          <div class="divide-y divide-border">
            {#each view.log.lines as line, index (index)}
              <p class="px-3 py-1.5 text-xs font-mono break-all">
                {#if line.time}
                  <span class="mr-1 text-faint-fg">{line.time}</span>
                {/if}
                <span class="text-muted-fg">{line.text}</span>
              </p>
            {/each}
          </div>
        </Card>
      {:else}
        <!-- An empty log and one this account may not read are told apart by
             the agent, and they are not the same answer. -->
        <p class="text-sm text-muted-fg">
          {view.log?.unreadable ? $LL.serviceLogUnreadable() : $LL.serviceLogEmpty()}
        </p>
      {/if}
    {:else}
      <!-- The manager's own output, verbatim: a definition is the manager's
           syntax and a status is its formatting, and there is nothing here to
           translate. -->
      {#if view.text}
        <Card class="max-h-72 overflow-auto p-0">
          <pre class="px-3 py-2 text-xs font-mono text-muted-fg whitespace-pre-wrap break-all">{view.text}</pre>
        </Card>
      {:else}
        <p class="text-sm text-muted-fg">{$LL.serviceUnreadable()}</p>
      {/if}
    {/if}
  {/if}
</div>
