<script lang="ts">
  import {
    Activity,
    CalendarClock,
    Container,
    MonitorPlay,
    ServerCog,
    Users,
    type LucideIcon,
  } from '@lucide/svelte'
  import { enabledFeatures, type FeatureId } from '../lib/features'
  import { capabilitiesStore } from '../lib/capabilities.svelte'
  import { layout } from '../lib/layout.svelte'
  import { LL } from '../i18n/i18n-svelte'
  import { servers } from '../lib/servers.svelte'

  interface Props {
    /// Which of the tabs is the screen on screen, so the bar can mark it.
    active: FeatureId
  }

  const { active }: Props = $props()

  /// How each feature is drawn. Beside the bar rather than in
  /// `lib/features.ts`, because both halves of it belong to Svelte: a label is
  /// an `$LL` call and an icon is a component, and that module is imported by
  /// plain TypeScript.
  ///
  /// A `Record` over every `FeatureId` rather than a field on each spec, so a
  /// feature added to the list without a label here is a type error instead of
  /// a tab that renders an empty string.
  const PRESENTATION: Record<FeatureId, { label: () => string; icon: LucideIcon }> = {
    containers: { label: () => $LL.containers(), icon: Container },
    process: { label: () => $LL.processes(), icon: Activity },
    services: { label: () => $LL.services(), icon: ServerCog },
    users: { label: () => $LL.users(), icon: Users },
    cron: { label: () => $LL.cron(), icon: CalendarClock },
    desktop: { label: () => $LL.desktop(), icon: MonitorPlay },
  }

  // Read here rather than passed in: the bar is in three callers' headers and a
  // prop would be the same expression written three times, each free to drift.
  const served = $derived(
    enabledFeatures(capabilitiesStore.byServer[servers.currentId]?.remote_access),
  )
</script>

<!-- One row of tabs, under the title in the same sticky bar, rather than one
     icon per feature in the header actions. The actions row is for things done
     *to* the current screen; these are other screens, and a machine with every
     feature would otherwise wear ten indistinguishable icons. Scrolls rather
     than wraps: a wrapped bar changes the header's height as features appear. -->
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
