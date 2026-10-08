<script lang="ts" module>
  export interface TitleTab {
    key: string
    label: string
    /// The full name (a path), shown on hover.
    title?: string
    /// Something runs in it (a terminal's foreground process).
    running?: boolean
  }

  /// A tab under the pointer, for a host that lets tabs be dragged
  /// (reordered along the strip, or pulled off it).
  export interface TitleTabsDrag {
    down: (e: PointerEvent, key: string) => void
    move: (e: PointerEvent) => void
    up: (e: PointerEvent) => void
    cancel: () => void
  }
</script>

<script lang="ts">
  /// Tabs in the window bar, in place of the title (two or more; one tab is
  /// an ordinary title). One raised indicator glides between them
  /// (`Indicator`); a tab added grows from nothing to its share
  /// (`--dur-tab-in`) and is chosen; a tab closed goes at once and the rest
  /// share the row again. The + is inside the well, after the last tab.

  import Icon from './Icon.svelte'
  import Indicator from './Indicator.svelte'

  interface Props {
    /// `data-*` attributes go on the well.
    [data: `data-${string}`]: unknown
    tabs: TitleTab[]
    active: string
    onselect: (key: string) => void
    onclose?: (key: string) => void
    onadd?: () => void
    addLabel: string
    closeLabel: string
    /// Names the strip for a screen reader.
    label?: string
    drag?: TitleTabsDrag
    /// The tab being dragged, drawn lifted.
    dragging?: string | null
    /// The well, for a host measuring its tabs.
    well?: HTMLDivElement | null
    class?: string
  }

  let {
    tabs,
    active,
    onselect,
    onclose,
    onadd,
    addLabel,
    closeLabel,
    label,
    drag,
    dragging = null,
    well = $bindable(null),
    class: className = '',
    ...rest
  }: Props = $props()

  const closable = $derived(!!onclose && tabs.length > 1)

  // A key not seen before is new until its grow-in ends, not for one render.
  // eslint-disable-next-line svelte/prefer-svelte-reactivity -- bookkeeping, never rendered from
  const seen = new Set<string>()
  let fresh = $state<string[]>([])
  let first = true
  $effect.pre(() => {
    const added = tabs.map((t) => t.key).filter((k) => !seen.has(k))
    for (const k of added) seen.add(k)
    if (first) {
      first = false
      return
    }
    if (added.length) fresh = [...fresh, ...added]
  })
</script>

<div class="lk-ttabs {className}">
  <div bind:this={well} class="lk-ttabs__well" role="tablist" aria-label={label} {...rest}>
    <Indicator selector=".lk-ttabs__tab--on" class="lk-ttabs__ind" />
    {#each tabs as t (t.key)}
      {@const on = t.key === active}
      <div
        role="tab"
        tabindex={on ? 0 : -1}
        aria-selected={on}
        title={t.title ?? t.label}
        class="lk-ttabs__tab"
        class:lk-ttabs__tab--on={on}
        class:lk-ttabs__tab--new={fresh.includes(t.key)}
        style:opacity={dragging === t.key ? 0.7 : null}
        style:touch-action={drag ? 'none' : null}
        onanimationend={(e) => {
          if (e.animationName === 'lk-ttab-in') fresh = fresh.filter((k) => k !== t.key)
        }}
        onclick={() => onselect(t.key)}
        onauxclick={(e) => {
          if (e.button === 1 && closable) onclose?.(t.key)
        }}
        onkeydown={(e) => {
          if (e.key === 'Enter' || e.key === ' ') {
            e.preventDefault()
            onselect(t.key)
          }
        }}
        onpointerdown={(e) => {
          if (!drag || e.button !== 0 || (e.target as HTMLElement).closest('button')) return
          drag.down(e, t.key)
        }}
        onpointermove={drag?.move}
        onpointerup={drag?.up}
        onpointercancel={drag?.cancel}
      >
        {#if closable}
          <button
            type="button"
            class="lk-ttabs__close"
            aria-label="{closeLabel} {t.label}"
            onclick={(e) => {
              e.stopPropagation()
              onclose?.(t.key)
            }}
          >
            <Icon name="close" size={14} />
          </button>
        {/if}
        <span class="lk-ttabs__label">{t.label}</span>
        {#if t.running}<span class="lk-ttabs__dot" aria-hidden="true"></span>{/if}
      </div>
    {/each}
    {#if onadd}
      <button type="button" class="lk-ttabs__add" title={addLabel} aria-label={addLabel} onclick={onadd}>
        <Icon name="add" size={17} />
      </button>
    {/if}
  </div>
</div>
