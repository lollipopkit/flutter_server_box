<script lang="ts">
  import { tick } from 'svelte'
  import { useDesk } from '../deskState.svelte'
  import Menu from '../lk/Menu.svelte'

  const desk = useDesk()
  let el = $state<HTMLDivElement | null>(null)
  let pos = $state({ left: 0, top: 0 })

  // Placed where asked, then pulled back inside the screen once its size is known.
  $effect(() => {
    const menu = desk.menu
    if (!menu) return
    pos = { left: menu.x, top: menu.y }
    void tick().then(() => {
      if (!el) return
      const r = el.getBoundingClientRect()
      const top = menu.above ? menu.y - r.height : menu.y
      pos = {
        left: Math.max(6, Math.min(menu.x, window.innerWidth - r.width - 6)),
        top: Math.max(6, Math.min(top, window.innerHeight - r.height - 6)),
      }
      el.querySelector<HTMLButtonElement>('button:not(:disabled)')?.focus()
    })
  })
</script>

{#if desk.menu}
  <!-- svelte-ignore a11y_no_static_element_interactions -->
  <div
    class="fixed z-[100003]"
    style:left="{pos.left}px"
    style:top="{pos.top}px"
    onpointerdown={(e) => e.stopPropagation()}
  >
    <Menu bind:ref={el} items={desk.menu.items} onselect={() => (desk.menu = null)} onclose={() => (desk.menu = null)} />
  </div>
{/if}
