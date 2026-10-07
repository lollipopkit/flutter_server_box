<script lang="ts">
  import { Check } from '@lucide/svelte'
  import { tick } from 'svelte'
  import { useDesk } from '../deskState.svelte'

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

  function onkeydown(e: KeyboardEvent) {
    if (!el) return
    const items = [...el.querySelectorAll<HTMLButtonElement>('button:not(:disabled)')]
    const at = items.indexOf(document.activeElement as HTMLButtonElement)
    if (e.key === 'ArrowDown' || e.key === 'ArrowUp') {
      e.preventDefault()
      const next = e.key === 'ArrowDown' ? (at + 1) % items.length : (at - 1 + items.length) % items.length
      items[next]?.focus()
    } else if (e.key === 'Escape') {
      e.preventDefault()
      desk.menu = null
    }
  }
</script>

{#if desk.menu}
  <div
    bind:this={el}
    class="desk-sheet desk-pop fixed z-[100003] min-w-52 rounded-xl p-1 text-[0.78rem]"
    style:left="{pos.left}px"
    style:top="{pos.top}px"
    role="menu"
    tabindex="-1"
    {onkeydown}
    onpointerdown={(e) => e.stopPropagation()}
    oncontextmenu={(e) => e.preventDefault()}
  >
    {#each desk.menu.items as item, i (i)}
      {#if 'separator' in item}
        <div class="desk-separator mx-2 my-1"></div>
      {:else}
        {@const Icon = item.icon}
        <button
          class="desk-hover flex w-full items-center gap-2 px-2 py-1 text-left disabled:opacity-40"
          class:text-danger={item.danger}
          role="menuitem"
          disabled={item.disabled}
          onclick={() => {
            desk.menu = null
            item.action()
          }}
        >
          <span class="grid w-4 place-items-center">
            {#if item.checked}
              <Check class="h-3.5 w-3.5" />
            {:else if Icon}
              <Icon class="h-3.5 w-3.5" />
            {/if}
          </span>
          <span class="flex-1 truncate">{item.label}</span>
          {#if item.shortcut}<span class="desk-muted text-[0.7rem]">{item.shortcut}</span>{/if}
        </button>
      {/if}
    {/each}
  </div>
{/if}
