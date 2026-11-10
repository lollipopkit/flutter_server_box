<script lang="ts">
  import Icon from './Icon.svelte'

  /// Work under way: the `progress_activity` glyph turning (`lk-spin`), in
  /// the accent. Sizes as before: sm 16, md 32, lg 48 (or a number in px).

  interface Props {
    size?: 'sm' | 'md' | 'lg' | number
    /// Read out; absent, the spinner is decoration beside text that says it.
    label?: string
    class?: string
  }

  const { size = 'md', label, class: className = '' }: Props = $props()
  const px = $derived(typeof size === 'number' ? size : { sm: 16, md: 32, lg: 48 }[size])
</script>

<span class="lk-spinner {className}" role={label ? 'status' : undefined} aria-label={label}>
  <Icon name="progress_activity" size={px} weight={500} color="var(--color-accent)" class="lk-spinner" />
</span>

<style>
  :global(.lk-spinner) {
    animation: lk-spin 0.9s linear infinite;
  }
  @media (prefers-reduced-motion: reduce) {
    :global(.lk-spinner) {
      animation-duration: 2.4s;
    }
  }
</style>
