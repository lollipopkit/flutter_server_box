<script lang="ts">
  import { AppWindow, FolderOpen, Search, Server } from '@lucide/svelte'
  import type { Component } from 'svelte'
  import { LL } from '../../i18n/i18n-svelte'
  import { serverNames } from '../../lib/serverNames.svelte'
  import { serverMatches } from '../../lib/serverSearch'
  import { displayName, servers } from '../../lib/servers.svelte'
  import { app, type AppSpec } from '../apps'
  import { useDesk } from '../deskState.svelte'
  import AppIcon from './AppIcon.svelte'

  interface Props {
    /// Switches the panel to another server (its own desk).
    onswitch: (serverId: string) => void
  }

  const { onswitch }: Props = $props()
  const desk = useDesk()

  /// `autofocus` is ignored once anything on the page has focus.
  function focusNow(el: HTMLInputElement) {
    queueMicrotask(() => el.focus())
  }

  interface Hit {
    key: string
    group: string
    label: string
    detail?: string
    spec?: AppSpec
    icon?: Component
    run: () => void
  }

  let query = $state('')
  let selected = $state(0)

  const hits = $derived.by((): Hit[] => {
    const q = query.trim().toLowerCase()
    const out: Hit[] = []
    if (q.startsWith('/') && app('files')?.available(desk.caps)) {
      out.push({
        key: 'path',
        group: $LL.files(),
        label: query.trim(),
        detail: $LL.deskOpenInFiles(),
        icon: FolderOpen,
        run: () => desk.open('files', { appState: { path: query.trim() }, newWindow: true }),
      })
    }
    const matches = (words: string[]) => !q || words.some((w) => w.toLowerCase().includes(q))
    for (const spec of desk.apps) {
      if (matches([spec.title($LL), spec.id, ...(spec.keywords?.($LL) ?? [])])) {
        out.push({ key: `app:${spec.id}`, group: $LL.deskApps(), label: spec.title($LL), spec, run: () => desk.open(spec.id) })
      }
    }
    for (const w of desk.windows.windows) {
      const spec = app(w.appId)
      const label = w.title ?? spec?.title($LL) ?? w.appId
      if (q && matches([label])) {
        out.push({
          key: `win:${w.id}`,
          group: $LL.deskWindows(),
          label,
          icon: AppWindow,
          run: () => desk.windows.focus(w.id),
        })
      }
    }
    if (!servers.servedByAgent) {
      for (const s of servers.list) {
        if (s.id === desk.entry.id) continue
        const name = serverNames.byServer[s.id] ?? (s.id === 'local' ? $LL.thisServer() : displayName(s))
        if (q && serverMatches(q, name, s.url)) {
          out.push({
            key: `srv:${s.id}`,
            group: $LL.deskServers(),
            label: name,
            detail: s.url,
            icon: Server,
            run: () => onswitch(s.id),
          })
        }
      }
    }
    return out.slice(0, 30)
  })

  $effect(() => {
    void query
    selected = 0
  })

  function run(hit: Hit | undefined) {
    if (!hit) return
    desk.spotlight = false
    hit.run()
  }

  function onkeydown(e: KeyboardEvent) {
    if (e.key === 'ArrowDown') {
      e.preventDefault()
      selected = Math.min(selected + 1, hits.length - 1)
    } else if (e.key === 'ArrowUp') {
      e.preventDefault()
      selected = Math.max(selected - 1, 0)
    } else if (e.key === 'Enter') {
      e.preventDefault()
      run(hits[selected])
    } else if (e.key === 'Escape') {
      e.preventDefault()
      desk.spotlight = false
    }
  }
</script>

<div
  class="desk-sheet desk-pop absolute bottom-(--dock-reserve) left-1/2 z-[100002] flex max-h-[calc(100%-var(--dock-reserve)-var(--menubar-h)-1.5rem)] w-[min(44rem,calc(100%-1.5rem))] -translate-x-1/2 flex-col rounded-(--radius-panel) p-5"
  role="dialog"
  aria-label={$LL.deskSearch()}
  tabindex="-1"
  onpointerdown={(e) => e.stopPropagation()}
>
  <label class="block">
    <span class="desk-eyebrow">{$LL.deskSearch()}</span>
    <span
      class="mt-1.5 flex items-center gap-2.5 rounded-xl border border-line px-3 py-2 transition-colors focus-within:border-primary"
    >
      <Search class="h-4 w-4 opacity-60" />
      <input
        class="w-full bg-transparent text-[0.95rem] outline-none placeholder:opacity-50"
        placeholder={$LL.deskSpotlightHint()}
        bind:value={query}
        {onkeydown}
        use:focusNow
        role="combobox"
        aria-expanded={hits.length > 0}
        aria-controls="desk-spotlight-results"
      />
    </span>
  </label>
  {#if hits.length > 0}
    <ul id="desk-spotlight-results" class="-mx-1 mt-3 min-h-0 overflow-y-auto px-1" role="listbox">
      {#each hits as hit, i (hit.key)}
        {#if i === 0 || hits[i - 1].group !== hit.group}
          <li class="desk-eyebrow px-2.5 pb-1 pt-2" role="presentation">
            {hit.group}
          </li>
        {/if}
        {@const Icon = hit.icon}
        <li role="option" aria-selected={i === selected}>
          <button
            class="flex w-full items-center gap-2.5 rounded-[0.6rem] border border-transparent px-2.5 py-1.5 text-left text-sm"
            class:desk-chosen={i === selected}
            onpointermove={() => (selected = i)}
            onclick={() => run(hit)}
          >
            {#if hit.spec}
              <AppIcon spec={hit.spec} size={1.75} />
            {:else if Icon}
              <span class="desk-glyph h-7 w-7 rounded-[0.5rem]"><Icon class="h-4 w-4" /></span>
            {/if}
            <span class="flex-1 truncate font-medium">{hit.label}</span>
            {#if hit.detail}<span class="desk-muted truncate text-xs">{hit.detail}</span>{/if}
          </button>
        </li>
      {/each}
    </ul>
  {/if}
</div>
