<script lang="ts">
  /// The one selection indicator of the design system: a single raised
  /// block that glides to the chosen one of N peers (TitleTabs, the login
  /// instance list) — `--dur-indicator` · `--ease-indicator`. Placed inside
  /// the positioned container of the peers; follows whichever of them
  /// matches [selector], wherever layout moves it.
  ///
  /// While the peers are added, removed or reordered it does not glide: it
  /// stays on the chosen one as the row reflows (a new tab growing in) and
  /// glides again once the container's animations have finished.

  interface Props {
    /// The chosen peer, inside the container.
    selector: string
    /// The block's look; `{class}--glide` is added while it may glide.
    class: string
  }

  const { selector, class: className }: Props = $props()

  let el = $state<HTMLSpanElement | null>(null)
  let box = $state<{ x: number; y: number; w: number; h: number } | null>(null)
  let glide = $state(false)
  /// Nothing chosen among the peers: it fades where it was.
  let gone = $state(false)

  $effect(() => {
    const parent = el?.parentElement
    if (!parent) return
    const sel = selector
    let raf = 0
    let settle = 0
    // What was last written, kept outside [box] so this effect never depends
    // on its own output.
    let last: { x: number; y: number; w: number; h: number } | null = null

    const measure = () => {
      const target = parent.querySelector<HTMLElement>(sel)
      gone = !target
      if (!target) return
      const p = parent.getBoundingClientRect()
      const t = target.getBoundingClientRect()
      const next = {
        x: t.left - p.left - parent.clientLeft + parent.scrollLeft,
        y: t.top - p.top - parent.clientTop + parent.scrollTop,
        w: t.width,
        h: t.height,
      }
      // Never write when nothing moved: the observers fire often while a
      // row reflows.
      if (last && Math.abs(last.x - next.x) < 0.5 && Math.abs(last.y - next.y) < 0.5 && Math.abs(last.w - next.w) < 0.5 && Math.abs(last.h - next.h) < 0.5) return
      last = next
      box = next
    }

    const resize = typeof ResizeObserver === 'undefined' ? null : new ResizeObserver(measure)
    const observeAll = () => {
      if (!resize) return
      resize.disconnect()
      resize.observe(parent)
      for (const child of parent.children) if (child !== el) resize.observe(child)
    }

    /// The peers changed: no glide while the row reflows, then glide again
    /// once whatever animates in the container (a tab growing in) is done.
    const reflow = () => {
      glide = false
      observeAll()
      cancelAnimationFrame(raf)
      raf = requestAnimationFrame(() => {
        measure()
        const running = parent.getAnimations?.({ subtree: true }).filter((a) => a.effect?.getTiming().iterations !== Infinity) ?? []
        const n = ++settle
        void Promise.allSettled(running.map((a) => a.finished)).then(() => {
          if (n !== settle) return
          measure()
          raf = requestAnimationFrame(() => (glide = true))
        })
      })
    }

    const mutation = new MutationObserver((records) => {
      // Only the peers themselves coming or going is a reflow; what changes
      // inside one (a close button, a dot) is not.
      if (records.some((r) => r.type === 'childList' && r.target === parent)) reflow()
      else measure()
    })
    mutation.observe(parent, { childList: true, subtree: true, attributes: true, attributeFilter: ['aria-selected', 'aria-current', 'class'] })

    observeAll()
    measure()
    // The first placement is where it starts, not a move.
    raf = requestAnimationFrame(() => (glide = true))
    return () => {
      cancelAnimationFrame(raf)
      settle++
      mutation.disconnect()
      resize?.disconnect()
    }
  })
</script>

<span
  bind:this={el}
  class="{className} {glide ? `${className}--glide` : ''}"
  style:display={box ? null : 'none'}
  style:opacity={gone ? 0 : null}
  style:top="0"
  style:left="0"
  style:width="{box?.w ?? 0}px"
  style:height="{box?.h ?? 0}px"
  style:transform="translate({box?.x ?? 0}px, {box?.y ?? 0}px)"
  aria-hidden="true"
></span>
