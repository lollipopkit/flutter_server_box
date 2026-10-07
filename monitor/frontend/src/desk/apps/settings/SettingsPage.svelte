<script lang="ts">
  import type { Snippet } from 'svelte'
  import { AppToolbar } from '../../sys'

  /// One Settings page: its title in the bar, then one column capped at the
  /// form width and centred in the pane, opening with a line on what the
  /// page governs and where it applies (this browser, this server).

  interface Props {
    title: string
    subtitle?: string
    description?: string
    back?: () => void
    actions?: Snippet
    children: Snippet
  }

  const { title, subtitle, description, back, actions, children }: Props = $props()
</script>

<AppToolbar {title} {subtitle} {back} {actions} />

<main class="pane-form flex flex-col gap-[17px] pb-[27px] pt-[5px]">
  {#if description}<p class="px-[2px] text-[13px] text-(--text-secondary) [text-wrap:pretty]">{description}</p>{/if}
  {@render children()}
</main>
