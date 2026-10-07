<script lang="ts" module>
  /// How the login screen's clock looks, per browser: its font, spacing,
  /// weight and size (dragged).
  export interface ClockStyle {
    font: 'system' | 'sans' | 'mono'
    spacing: number
    weight: number
    size: number
  }

  const KEY = 'lock.clock'
  export const CLOCK_DEFAULT: ClockStyle = { size: 89, font: 'sans', spacing: -3, weight: 800 }

  const FAMILIES: Record<ClockStyle['font'], string> = {
    system: 'system-ui, -apple-system, "PingFang SC", "Microsoft YaHei", sans-serif',
    sans: 'var(--font-ui)',
    mono: 'var(--font-mono)',
  }

  function loadStyle(): ClockStyle {
    try {
      const saved = JSON.parse(window.localStorage.getItem(KEY) ?? '{}') as Partial<ClockStyle>
      const style = { ...CLOCK_DEFAULT, ...saved }
      if (!(style.font in FAMILIES)) style.font = CLOCK_DEFAULT.font
      return style
    } catch {
      return { ...CLOCK_DEFAULT }
    }
  }
</script>

<script lang="ts">
  import { LL, locale } from '../../i18n/i18n-svelte'
  import { fmtDate } from '../../lib/format'
  import Button from '../lk/Button.svelte'
  import SegmentedControl from '../lk/SegmentedControl.svelte'
  import Slider from '../lk/Slider.svelte'

  interface Props {
    /// Being restyled: the editor shows under it and a drag resizes it.
    editing: boolean
    ondone: () => void
  }

  const { editing, ondone }: Props = $props()

  let style = $state<ClockStyle>(loadStyle())

  function set(patch: Partial<ClockStyle>) {
    style = { ...style, ...patch }
    try {
      window.localStorage.setItem(KEY, JSON.stringify(style))
    } catch {
      // Only remembering it is lost.
    }
  }

  let now = $state(new Date())
  $effect(() => {
    const t = setInterval(() => (now = new Date()), 1000)
    return () => clearInterval(t)
  })
  const time = $derived(fmtDate(now, { hour: '2-digit', minute: '2-digit' }, $locale))
  const date = $derived(new Intl.DateTimeFormat($locale, { month: 'long', day: 'numeric', weekday: 'short' }).format(now))

  function onpointerdown(e: PointerEvent) {
    if (!editing) return
    e.preventDefault()
    const x = e.clientX
    const y = e.clientY
    const from = style.size
    const move = (ev: PointerEvent) =>
      set({ size: Math.round(Math.max(34, Math.min(200, from + (ev.clientX - x + (ev.clientY - y)) * 0.6))) })
    const up = () => {
      window.removeEventListener('pointermove', move)
      window.removeEventListener('pointerup', up)
    }
    window.addEventListener('pointermove', move)
    window.addEventListener('pointerup', up)
  }
</script>

<div class="relative z-[2] mt-[9vh] flex flex-col items-center gap-[13px]">
  <!-- svelte-ignore a11y_no_static_element_interactions -->
  <div
    class="clock"
    class:clock--editing={editing}
    title={editing ? $LL.lockDragResize() : undefined}
    {onpointerdown}
  >
    <div class="font-semibold text-(--lock-fg2)" style:font-size="{Math.max(13, Math.round(style.size * 0.19))}px">{date}</div>
    <div
      class="lk-num leading-none whitespace-nowrap"
      style:font-size="{style.size}px"
      style:font-family={FAMILIES[style.font]}
      style:font-weight={style.weight}
      style:letter-spacing="{style.spacing / 100}em"
    >
      {time}
    </div>
    {#if editing}<span class="clock__handle" aria-hidden="true"></span>{/if}
  </div>
  {#if editing}
    <div class="editor">
      <SegmentedControl
        size="sm"
        label={$LL.lockClockStyle()}
        options={[
          { value: 'system', label: $LL.lockFontSystem() },
          { value: 'sans', label: 'Figtree' },
          { value: 'mono', label: $LL.lockFontMono() },
        ]}
        value={style.font}
        onchange={(font) => set({ font })}
      />
      <div class="flex items-center gap-[7px] text-[12px] text-(--text-secondary)">
        <span>{$LL.lockSpacing()}</span>
        <Slider class="w-[120px]" min={-8} max={20} value={style.spacing} label={$LL.lockSpacing()} onchange={(spacing) => set({ spacing })} />
      </div>
      <div class="flex items-center gap-[7px] text-[12px] text-(--text-secondary)">
        <span>{$LL.lockWeight()}</span>
        <Slider class="w-[110px]" min={100} max={900} step={100} value={style.weight} label={$LL.lockWeight()} onchange={(weight) => set({ weight })} />
        <span class="lk-num min-w-[27px] text-(--text-tertiary)">{style.weight}</span>
      </div>
      <span class="lk-num min-w-[44px] text-[12px] text-(--text-tertiary)">{style.size} px</span>
      <div class="flex gap-[5px]">
        <Button variant="ghost" size="sm" onclick={() => set({ ...CLOCK_DEFAULT })}>{$LL.lockReset()}</Button>
        <Button variant="primary" size="sm" onclick={ondone}>{$LL.lockDone()}</Button>
      </div>
    </div>
  {/if}
</div>

<style>
  .clock {
    position: relative;
    display: flex;
    flex-direction: column;
    align-items: center;
    gap: var(--space-3);
    padding: var(--space-9) var(--space-21);
    border-radius: var(--radius-window);
    outline: 1px solid transparent;
    color: var(--lock-fg);
    user-select: none;
    touch-action: none;
    cursor: default;
    transition:
      color 450ms,
      background-color 200ms;
  }
  .clock--editing {
    outline: 1px dashed var(--border-strong);
    background: var(--fill-hover);
    cursor: nwse-resize;
  }
  .clock__handle {
    position: absolute;
    right: -8px;
    bottom: -8px;
    width: 17px;
    height: 17px;
    border-radius: 50%;
    background: var(--surface-raised);
    box-shadow:
      var(--shadow-control),
      0 0 0 0.5px var(--border-strong);
  }
  .editor {
    display: flex;
    flex-wrap: wrap;
    align-items: center;
    justify-content: center;
    gap: var(--space-13);
    padding: var(--space-7) var(--space-9) var(--space-7) var(--space-13);
    border-radius: var(--radius-card);
    background: var(--glass-menu);
    backdrop-filter: var(--blur-menu);
    -webkit-backdrop-filter: var(--blur-menu);
    box-shadow:
      var(--shadow-menu),
      inset 0 0 0 0.5px var(--border-glass);
  }
</style>
