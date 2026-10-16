<script lang="ts">
  import Icon from './Icon.svelte'

  /// A Control Center tile: a round glyph (accent when on), a label, a
  /// detail. A toggle when [ontoggle] is given, else an action ([onclick]).

  interface Props {
    icon: string
    label: string
    detail?: string
    on?: boolean
    ontoggle?: (on: boolean) => void
    onclick?: () => void
    class?: string
  }

  const { icon, label, detail, on = false, ontoggle, onclick, class: className = '' }: Props = $props()
</script>

<button
  type="button"
  role={ontoggle ? 'switch' : undefined}
  aria-checked={ontoggle ? on : undefined}
  class="lk-ctile lk-ctile--toggle {className}"
  class:lk-ctile--on={on}
  onclick={() => (ontoggle ? ontoggle(!on) : onclick?.())}
>
  <span class="lk-ctile__glyph"><Icon name={icon} size={18} fill={on} /></span>
  <span class="lk-ctile__text">
    <span class="lk-ctile__label">{label}</span>
    {#if detail}<span class="lk-ctile__detail">{detail}</span>{/if}
  </span>
</button>
