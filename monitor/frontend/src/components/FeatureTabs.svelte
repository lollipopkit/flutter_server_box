<script lang="ts">
  import { Activity, ArchiveRestore, Boxes, CalendarClock, Container, Cpu, Gauge, MonitorPlay, ScrollText, ServerCog, Users, type LucideIcon } from '@lucide/svelte'
  import { enabledFeatures, type FeatureId } from '../lib/features'
  import { capabilitiesStore } from '../lib/capabilities.svelte'
  import { layout } from '../lib/layout.svelte'
  import { LL } from '../i18n/i18n-svelte'
  import { servers } from '../lib/servers.svelte'

  interface Props {
    /// The page on screen, which the bar marks.
    active: FeatureId
  }

  const { active }: Props = $props()

  /// A `Record` over every `FeatureId`, so a page added to the list without a
  /// label here is a type error rather than an empty tab.
  const PRESENTATION: Record<FeatureId, { label: () => string; icon: LucideIcon }> = {
    containers: { label: () => $LL.containers(), icon: Container },
    process: { label: () => $LL.processes(), icon: Activity },
    services: { label: () => $LL.services(), icon: ServerCog },
    cron: { label: () => $LL.cron(), icon: CalendarClock },
    system_users: { label: () => $LL.systemUsers(), icon: Users },
    snippets: { label: () => $LL.snippets(), icon: ScrollText },
    desktop: { label: () => $LL.desktop(), icon: MonitorPlay },
    benchmark: { label: () => $LL.benchmark(), icon: Gauge },
    virt: { label: () => $LL.virt(), icon: Boxes },
    bmc: { label: () => $LL.bmc(), icon: Cpu },
    backup: { label: () => $LL.backup(), icon: ArchiveRestore },
  }

  const served = $derived(enabledFeatures(capabilitiesStore.byServer[servers.currentId]))
</script>

<!-- Under the title in the same sticky bar rather than as header icons: the
     actions row is for things done to this screen, these are other screens.
     Scrolls rather than wraps, so the header keeps its height. -->
{#if served.length > 0}
  <nav class="-mb-px flex items-center gap-1 overflow-x-auto">
    {#each served as feature (feature.id)}
      {@const { label, icon: Icon } = PRESENTATION[feature.id]}
      {@const current = feature.id === active}
      <button
        class="flex shrink-0 items-center gap-1.5 border-b-2 px-2.5 py-1.5 text-sm transition-colors {current
          ? 'border-primary text-fg-strong'
          : 'border-transparent text-muted-fg hover:text-fg'}"
        aria-current={current ? 'page' : undefined}
        onclick={() => layout.navigate(feature.id)}
      >
        <Icon class="h-4 w-4 shrink-0" />
        {label()}
      </button>
    {/each}
  </nav>
{/if}
