<script lang="ts" module>
  import type { Snippet } from 'svelte'

  /// One column of a `DataTable`. A cell shows `row[key]`; the flags style
  /// it, the `*Key`s add a dot, a glyph or a second line from the same row.
  export interface Column<R> {
    key: string
    label: string
    /// A grid track (`64px`, `minmax(200px,1fr)`); `minmax(0,1fr)` when absent.
    width?: string
    align?: 'start' | 'end'
    /// Sorts by `row[sortKey]` (the raw value behind a formatted cell).
    sortKey?: string
    sortable?: boolean
    /// The first direction when this column becomes the sort: -1 largest first.
    defaultDir?: 1 | -1
    dim?: boolean
    mono?: boolean
    small?: boolean
    strong?: boolean
    /// A zero reading (`0`, `0%`, `0 B/s`) drawn in the disabled colour.
    dimZero?: boolean
    /// Drawn bold in the primary colour (a reading worth seeing).
    emphasize?: (row: R) => boolean
    /// A dot before the value, `row[dotKey]` its colour (a ring when empty).
    dotKey?: string
    /// A glyph before the value.
    iconKey?: string
    iconColorKey?: string
    iconFillKey?: string
    /// A mono second part after the value (a command line).
    subKey?: string
    /// The value's colour, from the row.
    colorKey?: string
    /// Draws the cell instead.
    cell?: Snippet<[R, { selected: boolean }]>
  }

  export interface TableSort {
    key: string
    dir: 1 | -1
  }
</script>

<script lang="ts" generics="R extends Record<string, unknown>">
  import Icon from './Icon.svelte'

  /// A window's list: a sticky glass header (sorting by a column), compact
  /// rows, the selection in solid accent with white text. Its header sticks
  /// under the window's title bar.

  interface Props {
    columns: Column<R>[]
    rows: R[]
    rowKey: keyof R & string
    sort?: TableSort
    onsort?: (sort: TableSort) => void
    selected?: unknown
    /// Called with null when the selected row is clicked again.
    onselect?: (key: unknown, row: R | null) => void
    /// A double-click, Enter, or a tap on a touch screen.
    onopen?: (row: R) => void
    /// Opens a context menu for the row.
    onmenu?: (e: MouseEvent, row: R) => void
    density?: 'compact' | 'comfortable'
    striped?: boolean
    empty?: string
    emptyIcon?: string
    /// Below this the table scrolls sideways, in px.
    minWidth?: number
    /// Names the table for a screen reader.
    label?: string
    class?: string
  }

  const {
    columns,
    rows,
    rowKey,
    sort,
    onsort,
    selected,
    onselect,
    onopen,
    onmenu,
    density = 'compact',
    striped = false,
    empty,
    emptyIcon = 'search_off',
    minWidth,
    label,
    class: className = '',
  }: Props = $props()

  const ZERO = new Set<unknown>([0, '0', '0 B/s', '0.0%', '0%', '0 B'])
  const template = $derived(columns.map((c) => c.width ?? 'minmax(0,1fr)').join(' '))

  function headerClick(c: Column<R>) {
    const key = c.sortKey ?? c.key
    const on = sort?.key === key
    onsort?.({ key, dir: on ? (-sort!.dir as 1 | -1) : (c.defaultDir ?? 1) })
  }

  /// A touch has no double tap to speak of: there a tap opens.
  let touched = false

  function select(row: R) {
    const key = row[rowKey]
    if (selected != null && selected === key) onselect?.(null, null)
    else onselect?.(key, row)
  }

  function onkey(e: KeyboardEvent, row: R) {
    if (e.key === 'Enter') {
      e.preventDefault()
      onopen?.(row)
    } else if (e.key === ' ') {
      e.preventDefault()
      select(row)
    } else if (e.key === 'ArrowDown' || e.key === 'ArrowUp') {
      e.preventDefault()
      const at = rows.indexOf(row) + (e.key === 'ArrowDown' ? 1 : -1)
      const next = rows[at]
      if (!next) return
      onselect?.(next[rowKey], next)
      ;((e.currentTarget as HTMLElement)[e.key === 'ArrowDown' ? 'nextElementSibling' : 'previousElementSibling'] as HTMLElement | null)?.focus()
    }
  }
</script>

<div
  class="lk-table {density === 'comfortable' ? 'lk-table--comfortable' : ''} {striped ? 'lk-table--striped' : ''} {className}"
  style:min-width={minWidth != null ? `${minWidth}px` : undefined}
  role="grid"
  aria-label={label}
  aria-rowcount={rows.length}
>
  <div class="lk-table__head" style:grid-template-columns={template} role="row">
    {#each columns as c (c.key)}
      {@const key = c.sortKey ?? c.key}
      {@const on = sort?.key === key}
      {#if onsort && c.sortable !== false}
        <button
          type="button"
          role="columnheader"
          aria-sort={on ? (sort!.dir < 0 ? 'descending' : 'ascending') : 'none'}
          class="lk-table__th"
          class:lk-table__th--on={on}
          class:lk-table__th--end={c.align === 'end'}
          onclick={() => headerClick(c)}
          >{c.label}{#if on}<Icon name={sort!.dir < 0 ? 'arrow_downward' : 'arrow_upward'} size={14} />{/if}</button
        >
      {:else}
        <span role="columnheader" class="lk-table__th" class:lk-table__th--on={on} class:lk-table__th--end={c.align === 'end'}
          >{c.label}</span
        >
      {/if}
    {/each}
  </div>
  <div class="lk-table__body" role="rowgroup">
    {#each rows as row, i (row[rowKey] ?? i)}
      {@const sel = selected != null && selected === row[rowKey]}
      <div
        class="lk-table__row"
        class:lk-table__row--sel={sel}
        style:grid-template-columns={template}
        role="row"
        aria-selected={sel}
        tabindex={sel || (selected == null && i === 0) ? 0 : -1}
        onpointerdown={(e) => (touched = e.pointerType === 'touch')}
        onclick={(e) => {
          e.stopPropagation()
          if (touched && onopen) {
            onselect?.(row[rowKey], row)
            onopen(row)
          } else select(row)
        }}
        ondblclick={() => onopen?.(row)}
        oncontextmenu={onmenu ? (e) => onmenu(e, row) : undefined}
        onkeydown={(e) => onkey(e, row)}
      >
        {#each columns as c (c.key)}
          {@const value = row[c.key]}
          {@const color = !sel && c.colorKey ? (row[c.colorKey] as string | undefined) : undefined}
          <div
            role="gridcell"
            class="lk-table__td"
            class:lk-table__td--flex={!!(c.dotKey || c.iconKey || c.subKey)}
            class:lk-table__td--end={c.align === 'end'}
            class:lk-table__td--dim={c.dim}
            class:lk-table__td--mono={c.mono}
            class:lk-table__td--small={c.small}
            class:lk-table__td--strong={c.strong}
            class:lk-table__td--emph={c.emphasize?.(row)}
            class:lk-table__td--zero={c.dimZero && !sel && ZERO.has(value)}
            style:color
          >
            {#if c.cell}
              {@render c.cell(row, { selected: sel })}
            {:else}
              {#if c.dotKey}
                {@const dot = row[c.dotKey] as string | null | undefined}
                <span
                  class="lk-table__dot"
                  style:background={dot ? (sel ? '#fff' : dot) : undefined}
                  style:box-shadow={dot ? undefined : `inset 0 0 0 1.5px ${sel ? '#fff' : 'var(--text-tertiary)'}`}
                ></span>
              {/if}
              {#if c.iconKey}
                <Icon
                  name={String(row[c.iconKey])}
                  size={17}
                  fill={c.iconFillKey ? !!row[c.iconFillKey] : false}
                  color={sel ? undefined : c.iconColorKey ? (row[c.iconColorKey] as string) : 'var(--text-secondary)'}
                />
              {/if}
              {value ?? ''}
              {#if c.subKey && row[c.subKey]}<span class="lk-table__sub">{row[c.subKey]}</span>{/if}
            {/if}
          </div>
        {/each}
      </div>
    {/each}
    {#if rows.length === 0 && empty}
      <div class="lk-table__empty">
        <Icon name={emptyIcon} size={44} weight={300} />
        {empty}
      </div>
    {/if}
  </div>
</div>

<style>
  .lk-table__row:focus-visible {
    outline: none;
    box-shadow: var(--focus-ring);
  }
</style>
