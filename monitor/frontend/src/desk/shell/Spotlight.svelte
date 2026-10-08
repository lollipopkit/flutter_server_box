<script lang="ts">
  import { LL } from '../../i18n/i18n-svelte'
  import { serverNames } from '../../lib/serverNames.svelte'
  import { serverMatches } from '../../lib/serverSearch'
  import { displayName, servers } from '../../lib/servers.svelte'
  import { app } from '../registry.svelte'
  import type { AppSpec } from '../sys/manifest'
  import { useDesk } from '../deskState.svelte'
  import LkAppIcon, { type IconTone } from '@lollipopkit/desk-ui/AppIcon.svelte'
  import Icon from '@lollipopkit/desk-ui/Icon.svelte'
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
    /// For a hit that is not an app: its glyph and tone.
    glyph?: string
    tone?: IconTone
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
        glyph: 'folder',
        tone: 'sky',
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
          glyph: 'select_window',
          tone: 'mist',
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
            glyph: 'dns',
            tone: 'pale',
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

<!-- svelte-ignore a11y_no_static_element_interactions -->
<div
  class="absolute inset-0 z-[100002] flex justify-center"
  onpointerdown={(e) => {
    e.stopPropagation()
    if (e.target === e.currentTarget) desk.spotlight = false
  }}
>
  <div class="lk-spot mt-[18vh] self-start" role="dialog" aria-label={$LL.deskSearch()}>
    <label class="lk-spot__bar">
      <Icon name="search" size={22} />
      <input
        placeholder={$LL.deskSpotlightHint()}
        bind:value={query}
        {onkeydown}
        use:focusNow
        role="combobox"
        aria-expanded={hits.length > 0}
        aria-controls="desk-spotlight-results"
      />
    </label>
    {#if query.trim()}
      <ul id="desk-spotlight-results" class="lk-spot__list" role="listbox">
        {#each hits as hit, i (hit.key)}
          {#if i === 0 || hits[i - 1].group !== hit.group}
            <li class="lk-spot__group" role="presentation">{hit.group}</li>
          {/if}
          <li role="option" aria-selected={i === selected}>
            <button
              class="lk-spot__row w-full text-left"
              class:lk-spot__row--on={i === selected}
              onpointermove={() => (selected = i)}
              onclick={() => run(hit)}
            >
              {#if hit.spec}
                <AppIcon spec={hit.spec} size={26} />
              {:else if hit.glyph}
                <LkAppIcon glyph={hit.glyph} tone={hit.tone} size={26} />
              {/if}
              <span class="min-w-0">
                <span class="lk-spot__title block truncate">{hit.label}</span>
                {#if hit.detail}<span class="lk-spot__sub block truncate">{hit.detail}</span>{/if}
              </span>
              <span class="lk-spot__kind">{hit.group}</span>
            </button>
          </li>
        {:else}
          <li class="lk-spot__empty">{$LL.deskNoResults()}</li>
        {/each}
      </ul>
    {/if}
  </div>
</div>
