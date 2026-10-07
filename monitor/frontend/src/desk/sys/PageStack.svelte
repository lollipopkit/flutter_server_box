<script lang="ts" module>
  /// Somewhere a swipe can go from this page: the page's key there, and how
  /// the app gets there (the same thing its back/forward button does).
  export interface PageStep {
    key: string
    go: () => void
  }
</script>

<script lang="ts">
  /// Pages inside an app — a list and the item it opens, a folder and the
  /// folders in it — and the motion between them (fl_lib's pane slide,
  /// `pageMotion.ts`). The app keeps saying which page is shown: [key] names
  /// it, [depth] says how deep it is, so a deeper page arrives over this one
  /// and a shallower one is gone back to; a page as deep fades in (one of
  /// several peers, as tabs do).
  ///
  /// With [back] or [forward] a horizontal drag moves the page there: a
  /// pointer (touch, pen, or a mouse anywhere but on text), or a trackpad's
  /// two-finger swipe — unless what is under the pointer takes the drag
  /// itself (a field, a terminal, a box that can still scroll that way). The
  /// page the swipe heads for is shown as it was left (a still copy kept when
  /// the app moved away from it) and becomes the live page once the app has
  /// gone there.

  import { untrack, type Snippet } from 'svelte'
  import {
    PAGE_FADE_MS,
    PAGE_MS,
    commits,
    contentTakes,
    pageCurve,
    reducedMotion,
    releaseCurve,
    slide,
  } from './pageMotion'

  interface Props {
    key: string
    depth: number
    back?: PageStep | null
    forward?: PageStep | null
    children: Snippet
  }

  const { key, depth, back = null, forward = null, children }: Props = $props()

  let root = $state<HTMLDivElement | null>(null)

  /// What scrolls the pages (the window's content, a pane).
  function scrollerOf(el: HTMLElement): HTMLElement | null {
    for (let p = el.parentElement; p; p = p.parentElement) {
      const o = getComputedStyle(p).overflowY
      if (o === 'auto' || o === 'scroll') return p
    }
    return null
  }

  /// The colour behind the pages: a moving page carries it, so the page
  /// under it is covered rather than drawn through.
  function groundOf(el: HTMLElement): string {
    for (let p = el.parentElement; p; p = p.parentElement) {
      const c = getComputedStyle(p).backgroundColor
      if (c && c !== 'transparent' && !/rgba\(.*,\s*0\)$/.test(c)) return c
    }
    return 'var(--surface-window)'
  }

  // ---- what the app left: a still copy and where it was scrolled ---------

  const KEEP = 10
  // eslint-disable-next-line svelte/prefer-svelte-reactivity -- DOM bookkeeping, never rendered from
  const copies = new Map<string, { node: HTMLElement; scroll: number }>()

  function remember(k: string, page: HTMLElement, scroll: number) {
    const node = page.cloneNode(true) as HTMLElement
    // A copy of a canvas is blank and a field's copy has its first value.
    const from = page.querySelectorAll('canvas')
    node.querySelectorAll('canvas').forEach((c, i) => {
      try {
        c.getContext('2d')?.drawImage(from[i], 0, 0)
      } catch {
        // A canvas that cannot be read stays blank.
      }
    })
    const fields = page.querySelectorAll<HTMLInputElement>('input, textarea, select')
    node.querySelectorAll<HTMLInputElement>('input, textarea, select').forEach((f, i) => {
      f.value = fields[i].value
      if ('checked' in fields[i]) f.checked = fields[i].checked
    })
    node.querySelectorAll('[id]').forEach((el) => el.removeAttribute('id'))
    // Taken mid-swipe the live page is still displaced.
    undress(node)
    node.classList.add('page--copy')
    node.inert = true
    node.setAttribute('aria-hidden', 'true')
    copies.delete(k)
    copies.set(k, { node, scroll })
    if (copies.size > KEEP) copies.delete(copies.keys().next().value!)
  }

  // ---- a change of page ---------------------------------------------------

  type Plan = 'push' | 'pop' | 'fade' | 'none'
  let plan: Plan = 'none'
  let shown = untrack(() => ({ key, depth }))
  let fromScroll = 0
  let toScroll = 0
  let changed = false
  let scrollApplied = false
  /// The swipe went through and waits for the app's page to arrive.
  let swapping: { copy: HTMLElement; live: HTMLElement } | null = null
  let swapTimer = 0
  let leaving: HTMLElement | null = null
  let moving = $state(0)

  $effect.pre(() => {
    const k = key
    const d = depth
    untrack(() => {
      if (k === shown.key || !root) return
      const scroller = scrollerOf(root)
      const page = livePage()
      fromScroll = scroller?.scrollTop ?? 0
      if (page) remember(shown.key, page, fromScroll)
      plan = swapping ? 'none' : d > shown.depth ? 'push' : d < shown.depth ? 'pop' : 'fade'
      toScroll = plan === 'pop' || plan === 'none' ? (copies.get(k)?.scroll ?? 0) : 0
      shown = { key: k, depth: d }
      changed = true
      scrollApplied = false
    })
  })

  $effect(() => {
    void key
    untrack(() => {
      if (!changed || !root) return
      changed = false
      const scroller = scrollerOf(root)
      if (scroller) {
        scroller.scrollTop = toScroll
        scrollApplied = true
        if (leaving) leaving.style.top = `${scroller.scrollTop - fromScroll}px`
      }
      if (swapping) {
        clearTimeout(swapTimer)
        swapping.copy.remove()
        undress(swapping.copy)
        swapping = null
        moving--
      }
    })
  })

  function livePage(): HTMLElement | null {
    return root?.querySelector<HTMLElement>(':scope > .page:not(.page--leaving):not(.page--copy)') ?? null
  }

  /// A moving page: opaque, at least as tall as what can be seen of it.
  function dress(node: HTMLElement, z: number) {
    if (!root) return
    const scroller = scrollerOf(root)
    node.style.background = groundOf(root)
    node.style.zIndex = String(z)
    if (!node.style.position) node.style.position = 'relative'
    if (scroller) {
      const top = root.getBoundingClientRect().top - scroller.getBoundingClientRect().top + scroller.scrollTop
      node.style.minHeight = `${Math.max(0, Math.max(fromScroll, toScroll, scroller.scrollTop) + scroller.clientHeight - top)}px`
    }
  }

  function undress(node: HTMLElement) {
    for (const p of ['background', 'zIndex', 'minHeight', 'transform', 'opacity', 'position', 'top', 'left', 'right'] as const) node.style[p] = ''
  }

  /// Somewhere with no Web Animations (a test's DOM), pages change at once.
  const still = (node: HTMLElement) => typeof node.animate !== 'function'

  function enter(node: HTMLElement) {
    const p = plan
    if (p === 'none' || still(node)) return { duration: 0 }
    const reduce = reducedMotion(node)
    if (p === 'fade') return { duration: reduce ? 0 : 160, css: (t: number) => `opacity:${t}` }
    count(node)
    dress(node, p === 'push' ? 2 : 1)
    if (reduce) return p === 'push' ? { duration: PAGE_FADE_MS, css: (t: number) => `opacity:${t}` } : { duration: PAGE_FADE_MS, css: () => '' }
    return {
      duration: PAGE_MS,
      css: (t: number) =>
        p === 'push' ? `transform:translateX(${slide(pageCurve(t)).upper * 100}%)` : `transform:translateX(${slide(pageCurve(1 - t)).lower * 100}%)`,
    }
  }

  function leave(node: HTMLElement) {
    const p = plan
    // A view among peers has no exit; after a swipe the copy already shows
    // where it ends.
    if (p === 'none' || p === 'fade' || still(node)) return { duration: 0 }
    count(node)
    node.classList.add('page--leaving')
    node.style.position = 'absolute'
    node.style.left = '0'
    node.style.right = '0'
    const scroller = root ? scrollerOf(root) : null
    node.style.top = `${(scrollApplied && scroller ? scroller.scrollTop : toScroll) - fromScroll}px`
    leaving = node
    dress(node, p === 'pop' ? 2 : 1)
    const reduce = reducedMotion(node)
    if (reduce) return p === 'pop' ? { duration: PAGE_FADE_MS, css: (t: number) => `opacity:${t}` } : { duration: PAGE_FADE_MS, css: () => '' }
    // Svelte runs an exit from 1 to 0: the time gone is 1 - t.
    return {
      duration: PAGE_MS,
      css: (t: number) =>
        p === 'push' ? `transform:translateX(${slide(pageCurve(1 - t)).lower * 100}%)` : `transform:translateX(${slide(pageCurve(t)).upper * 100}%)`,
    }
  }

  /// A page in a slide: counted while it moves (the stack clips then).
  function count(node: HTMLElement) {
    if (node.dataset.moving) return
    node.dataset.moving = '1'
    moving++
  }

  function uncount(node: HTMLElement) {
    if (!node.dataset.moving) return
    delete node.dataset.moving
    moving--
  }

  function entered(node: HTMLElement) {
    if (!node.dataset.moving) return
    undress(node)
    uncount(node)
  }

  function left(node: HTMLElement) {
    if (leaving === node) leaving = null
    uncount(node)
  }

  // ---- swiping to the page behind or ahead --------------------------------

  type Dir = 'back' | 'forward'
  interface Swipe {
    dir: Dir
    step: PageStep
    source: 'pointer' | 'wheel'
    width: number
    live: HTMLElement
    copy: HTMLElement
    dx: number
    samples: { t: number; dx: number }[]
    reduce: boolean
  }
  let swipe: Swipe | null = null
  let pending: { id: number; x: number; y: number; target: Element | null; mouse: boolean } | null = null
  let settling = false
  let wheelEnd = 0
  /// A trackpad keeps sending its fling after a swipe has decided: quiet
  /// until it stops.
  let wheelQuietUntil = 0

  function stepFor(dx: number): { dir: Dir; step: PageStep } | null {
    if (dx > 0 && back) return { dir: 'back', step: back }
    if (dx < 0 && forward) return { dir: 'forward', step: forward }
    return null
  }

  function begin(dir: Dir, step: PageStep, source: Swipe['source']): boolean {
    const live = livePage()
    if (!root || !live || swapping) return false
    const scroller = scrollerOf(root)
    const kept = copies.get(step.key)
    let copy: HTMLElement
    if (kept) {
      copy = kept.node
      copy.style.top = `${(scroller?.scrollTop ?? 0) - kept.scroll}px`
    } else {
      // Never seen (a window restored deep): the page's ground alone.
      copy = document.createElement('div')
      copy.className = 'page page--copy'
      copy.style.top = '0'
    }
    copy.style.position = 'absolute'
    copy.style.left = '0'
    copy.style.right = '0'
    // A still copy outside what Svelte renders, after the page's anchor, and
    // taken out again before the page changes.
    // eslint-disable-next-line svelte/no-dom-manipulating -- see above
    root.append(copy)
    moving++
    dress(copy, dir === 'back' ? 1 : 2)
    dress(live, dir === 'back' ? 2 : 1)
    live.style.position = 'relative'
    swipe = { dir, step, source, width: root.clientWidth || 1, live, copy, dx: 0, samples: [], reduce: reducedMotion(root) }
    render(0)
    return true
  }

  /// [p]: how far towards the other page, 0 to 1.
  function render(p: number) {
    if (!swipe) return
    const { dir, live, copy, width, reduce } = swipe
    if (reduce) {
      if (dir === 'back') live.style.opacity = String(1 - p)
      else copy.style.opacity = String(p)
      return
    }
    // Back: the live page is the upper one, going (a from 1 to 0); ahead:
    // the copy is, arriving (a from 0 to 1).
    const at = slide(dir === 'back' ? 1 - p : p)
    const [upper, lower] = dir === 'back' ? [live, copy] : [copy, live]
    upper.style.transform = `translateX(${at.upper * width}px)`
    lower.style.transform = `translateX(${at.lower * width}px)`
  }

  function progress(s: Swipe): number {
    return Math.min(1, Math.max(0, (s.dir === 'back' ? s.dx : -s.dx) / s.width))
  }

  function move(dx: number) {
    if (!swipe) return
    swipe.dx = swipe.dir === 'back' ? Math.max(0, dx) : Math.min(0, dx)
    const now = performance.now()
    swipe.samples.push({ t: now, dx: swipe.dx })
    while (swipe.samples.length > 2 && now - swipe.samples[0].t > 100) swipe.samples.shift()
    render(progress(swipe))
  }

  function release() {
    const s = swipe
    if (!s) return
    const first = s.samples[0]
    const last = s.samples.at(-1)
    const velocity = first && last && last.t > first.t ? ((last.dx - first.dx) / (last.t - first.t)) * 1000 : 0
    const from = progress(s)
    const go = commits(from, velocity, s.dir === 'back' ? 1 : -1)
    settle(from, go ? 1 : 0, () => {
      if (!go) return finish()
      // The app's page arrives in its own time (a folder is listed first):
      // until then the copy stands where it will be.
      swapping = { copy: s.copy, live: s.live }
      swipe = null
      s.step.go()
      swapTimer = window.setTimeout(() => {
        // The app did not go there (it failed): the page comes back.
        if (!swapping) return
        swapping = null
        swipe = s
        settle(1, 0, finish)
      }, 4000)
    })
  }

  function settle(from: number, to: number, done: () => void) {
    settling = true
    const ms = Math.max(120, PAGE_MS * Math.abs(to - from))
    const start = performance.now()
    const frame = (now: number) => {
      const t = Math.min(1, (now - start) / ms)
      render(from + (to - from) * releaseCurve(t))
      if (t < 1) requestAnimationFrame(frame)
      else {
        settling = false
        done()
      }
    }
    requestAnimationFrame(frame)
  }

  function finish() {
    const s = swipe
    swipe = null
    if (!s) return
    s.copy.remove()
    undress(s.copy)
    undress(s.live)
    moving--
  }

  function onpointerdown(e: PointerEvent) {
    if (e.button !== 0 || swipe || settling || swapping || (!back && !forward)) return
    pending = { id: e.pointerId, x: e.clientX, y: e.clientY, target: e.target as Element, mouse: e.pointerType !== 'touch' }
  }

  function onpointermove(e: PointerEvent) {
    if (swipe?.source === 'pointer') {
      move(e.clientX - (pending?.x ?? 0))
      return
    }
    if (!pending || e.pointerId !== pending.id || !root) return
    const dx = e.clientX - pending.x
    const dy = e.clientY - pending.y
    if (Math.max(Math.abs(dx), Math.abs(dy)) < 8) return
    const to = Math.abs(dx) > Math.abs(dy) ? stepFor(dx) : null
    if (!to || contentTakes(pending.target, root, dx, pending.mouse ? { x: pending.x, y: pending.y } : null) || !begin(to.dir, to.step, 'pointer')) {
      pending = null
      return
    }
    root.setPointerCapture(e.pointerId)
    window.getSelection()?.removeAllRanges()
    move(dx)
  }

  function onpointerup() {
    if (swipe?.source === 'pointer') {
      // The press ends on whatever is under it: not a click.
      const swallow = (ev: Event) => {
        ev.stopPropagation()
        ev.preventDefault()
      }
      root?.addEventListener('click', swallow, { capture: true, once: true })
      setTimeout(() => root?.removeEventListener('click', swallow, { capture: true }))
      release()
    }
    pending = null
  }

  function onpointercancel() {
    if (swipe?.source === 'pointer') settle(progress(swipe), 0, finish)
    pending = null
  }

  function onwheel(e: WheelEvent) {
    if (e.ctrlKey || !root) return
    const horizontal = Math.abs(e.deltaX) > Math.abs(e.deltaY)
    const now = performance.now()
    if (settling || swapping || now < wheelQuietUntil) {
      if (horizontal && swipe?.source !== 'pointer') {
        wheelQuietUntil = now + 200
        e.preventDefault()
      }
      return
    }
    const delta = e.deltaX * (e.deltaMode === 1 ? 16 : e.deltaMode === 2 ? root.clientWidth : 1)
    if (!swipe) {
      if (!horizontal) return
      const to = stepFor(-delta)
      if (!to || contentTakes(e.target as Element, root, -delta, null) || !begin(to.dir, to.step, 'wheel')) return
    } else if (swipe.source !== 'wheel') return
    e.preventDefault()
    move(swipe!.dx - delta)
    clearTimeout(wheelEnd)
    wheelEnd = window.setTimeout(() => {
      wheelQuietUntil = performance.now() + 200
      release()
    }, 120)
  }

  $effect(() => {
    if (!root) return
    const el = root
    el.addEventListener('wheel', onwheel, { passive: false })
    return () => el.removeEventListener('wheel', onwheel)
  })

  $effect(() => () => {
    clearTimeout(swapTimer)
    clearTimeout(wheelEnd)
  })
</script>

<div
  bind:this={root}
  class="page-stack"
  class:page-stack--moving={moving > 0}
  class:page-stack--swipe={!!(back || forward)}
  role="presentation"
  {onpointerdown}
  {onpointermove}
  {onpointerup}
  {onpointercancel}
>
  {#key key}
    <div class="page" in:enter out:leave onintroend={(e) => entered(e.currentTarget)} onoutroend={(e) => left(e.currentTarget)}>
      {@render children()}
    </div>
  {/key}
</div>

<style>
  .page-stack {
    position: relative;
    display: flex;
    flex: 1 1 auto;
    flex-direction: column;
    min-width: 0;
  }
  /* A horizontal drag is the page's; a vertical one still scrolls. */
  .page-stack--swipe {
    touch-action: pan-y;
  }
  .page-stack--moving {
    overflow-x: clip;
    user-select: none;
  }
  .page-stack :global(.page) {
    display: flex;
    flex: 1 1 auto;
    flex-direction: column;
    min-width: 0;
  }
</style>
