<script lang="ts">
  /// Agent mode: the desk turned over to the agent's tasks — the timeline
  /// and the prompt, or one task — under the menubar. The windows stay where
  /// they were, running; the tasks run on the agent whether this is open or
  /// not.

  import './agent.css'
  import { onMount } from 'svelte'
  import { LL } from '../../i18n/i18n-svelte'
  import { AppIcon, Notification } from '../lk'
  import type { Flow } from '../../lib/agentApi'
  import AgentFlow from './AgentFlow.svelte'
  import AgentHistory from './AgentHistory.svelte'
  import AgentHome from './AgentHome.svelte'
  import type { AgentStore } from './agentStore.svelte'
  import { agentIn, agentOut } from './transition'

  interface Props {
    store: AgentStore
    /// Whom the greeting names.
    name: string
    admin: boolean
    onsettings: () => void
    /// Back to the desk.
    onexit: () => void
  }

  const { store, name, admin, onsettings, onexit }: Props = $props()

  let now = $state(new Date())
  let history = $state<DOMRect | null | undefined>(undefined)
  let root = $state<HTMLDivElement | null>(null)
  /// Where the open task came from on the timeline, to go back into it.
  // svelte-ignore state_referenced_locally
  let back: string | null = store.openId

  let ground = $state<HTMLDivElement | null>(null)
  let stage = $state<HTMLDivElement | null>(null)

  /// Leaves: the content goes, the ground closes into the menubar's Agent
  /// mode item. The desk unmounts this once it resolves.
  export async function leave(): Promise<void> {
    if (ground && stage) await agentOut(ground, stage)
  }

  onMount(() => {
    if (ground && stage) agentIn(ground, stage)
    store.start()
    // Back where it was left: the task open then is read again.
    if (store.openId) void store.open(store.openId)
    const t = setInterval(() => (now = new Date()), 1000)
    return () => clearInterval(t)
  })

  function open(id: string, from: HTMLElement | null = null) {
    history = undefined
    back = id
    void store.open(id)
    if (from && root) grow(from)
  }

  /// The card the task came from grows into the flow view.
  function grow(from: HTMLElement) {
    const rect = from.getBoundingClientRect()
    requestAnimationFrame(() => {
      const center = root?.querySelector<HTMLElement>('.center')
      if (!center) return
      const to = center.getBoundingClientRect()
      center.animate(
        [
          {
            transformOrigin: '0 0',
            transform: `translate(${rect.left - to.left}px, ${rect.top - to.top}px) scale(${rect.width / to.width}, ${rect.height / to.height})`,
            opacity: 0.5,
            borderRadius: '42px',
          },
          { transformOrigin: '0 0', transform: 'none', opacity: 1, borderRadius: getComputedStyle(center).borderRadius },
        ],
        { duration: 560, easing: 'cubic-bezier(.2,.9,.25,1.04)' },
      )
    })
  }

  /// The task shrinks back into its card on the timeline: what was on
  /// screen is kept as a still copy while the timeline comes back under it.
  function home() {
    const id = back
    const grid = root?.querySelector<HTMLElement>('.grid')
    const ghost = grid && root ? still(grid, root) : null
    store.close()
    if (!ghost || !root) return
    const host = root
    requestAnimationFrame(() => {
      const center = ghost.querySelector<HTMLElement>('.center')
      const card = id ? host.querySelector<HTMLElement>(`[data-fid="${CSS.escape(id)}"]`) : null
      const timing = { duration: 480, easing: 'cubic-bezier(.3,0,.2,1)', fill: 'forwards' as const }
      for (const side of ghost.querySelectorAll<HTMLElement>('.left, .right')) side.animate([{ opacity: 1 }, { opacity: 0 }], { ...timing, duration: 240 })
      if (center) {
        const from = center.getBoundingClientRect()
        // A task not on the timeline (from the history) shrinks where it is.
        const to = card?.getBoundingClientRect() ?? new DOMRect(from.left + from.width * 0.3, from.top + from.height * 0.3, from.width * 0.4, from.height * 0.4)
        center.animate(
          [
            { transformOrigin: '0 0', transform: 'none', opacity: 1, borderRadius: getComputedStyle(center).borderRadius },
            {
              transformOrigin: '0 0',
              transform: `translate(${to.left - from.left}px, ${to.top - from.top}px) scale(${to.width / from.width}, ${to.height / from.height})`,
              opacity: 0,
              borderRadius: '42px',
            },
          ],
          timing,
        )
      }
      const home = host.querySelector<HTMLElement>('.stage > .home')
      home?.animate([{ opacity: 0 }, { opacity: 1 }], { duration: 320, easing: 'ease-out' })
      setTimeout(() => ghost.remove(), timing.duration)
    })
  }

  /// A copy of [el] laid over [host] where it is, scrolled as it is, that
  /// takes no input.
  function still(el: HTMLElement, host: HTMLElement): HTMLElement {
    const r = el.getBoundingClientRect()
    const h = host.getBoundingClientRect()
    const copy = el.cloneNode(true) as HTMLElement
    copy.setAttribute('aria-hidden', 'true')
    copy.inert = true
    Object.assign(copy.style, {
      position: 'absolute',
      left: `${r.left - h.left}px`,
      top: `${r.top - h.top}px`,
      width: `${r.width}px`,
      height: `${r.height}px`,
      zIndex: '5',
      pointerEvents: 'none',
    })
    host.appendChild(copy)
    const from = el.querySelectorAll<HTMLElement>('*')
    const to = copy.querySelectorAll<HTMLElement>('*')
    from.forEach((e, i) => {
      if (e.scrollTop || e.scrollLeft) to[i].scrollTo(e.scrollLeft, e.scrollTop)
    })
    return copy
  }

  // The menubar's Agent menus.
  let handled = 0
  $effect(() => {
    const r = store.request
    if (!r || r.n === handled) return
    handled = r.n
    if (r.kind === 'history') {
      if (store.openId) home()
      history = null
    } else if (r.kind === 'new' && store.openId) {
      home()
    }
  })

  function started(f: Flow) {
    if (f.status !== 'queued') open(f.id)
  }

  const notice = $derived(store.notice)
  const noticeTitle = $derived.by(() => {
    const n = notice
    if (!n) return ''
    if (n.status === 'done') return $LL.deskAgentNoticeDone({ title: n.title })
    if (n.status === 'failed') return $LL.deskAgentNoticeFailed({ title: n.title })
    return $LL.deskAgentNoticeWaiting({ title: n.title })
  })
</script>

<svelte:window
  onkeydown={(e) => {
    // On the timeline, esc goes back to the desk; whatever is open over it
    // (a task, the history, a panel) took the key first.
    const tag = ((e.target as HTMLElement | null)?.tagName ?? '').toLowerCase()
    if (e.key !== 'Escape' || e.defaultPrevented || store.openId || history !== undefined) return
    if (tag === 'input' || tag === 'textarea') return
    e.preventDefault()
    onexit()
  }}
/>

<div class="am-root agent" bind:this={root}>
  <!-- What the desk is covered with: opens from the Agent mode item. -->
  <div class="ground" bind:this={ground} aria-hidden="true"></div>
  <div class="stage" bind:this={stage}>
  {#if store.openId}
    <AgentFlow {store} {now} {admin} onback={home} onopen={(id) => open(id)} />
  {:else}
    <AgentHome
      {store}
      {now}
      {name}
      {admin}
      {onsettings}
      onopen={open}
      onhistory={(el) => (history = el?.getBoundingClientRect() ?? null)}
      onstarted={started}
    />
  {/if}
  </div>

  {#if history !== undefined}
    <AgentHistory flows={store.flows} {now} from={history} onopen={(id) => open(id)} onclose={() => (history = undefined)} />
  {/if}

  {#if notice}
    <div class="notice">
      <Notification
        app="Agent"
        time={$LL.deskAgentJustNow()}
        title={noticeTitle}
        closeLabel={$LL.deskAgentClose()}
        onclick={() => open(notice.id)}
        onclose={() => store.dismissNotice()}
      >
        {#snippet icon()}<AppIcon glyph="auto_awesome" tone="berry" size={34} />{/snippet}
        {notice.text}
      </Notification>
    </div>
  {/if}
</div>

<style>
  .ground {
    position: absolute;
    inset: 0;
    z-index: -1;
    background: linear-gradient(
      color-mix(in srgb, var(--surface-window) 80%, transparent),
      color-mix(in srgb, var(--surface-window) 62%, transparent)
    );
  }
  .stage {
    position: relative;
    flex: 1;
    min-height: 0;
    display: flex;
    flex-direction: column;
  }
  .agent {
    position: absolute;
    inset: 0;
    z-index: 10;
    display: flex;
    flex-direction: column;
    padding-top: var(--menubar-height, 36px);
    box-sizing: border-box;
    font-family: var(--font-ui);
    color: var(--text-primary);
    container-type: size;
    animation: lk-fade-in var(--dur-base) var(--ease-standard);
  }
  .notice {
    position: absolute;
    top: 45px;
    right: 13px;
    z-index: 60;
    max-width: calc(100% - 26px);
    animation: lk-notif-in var(--dur-slow) var(--ease-spring);
  }
</style>
