<script lang="ts">
  /// Agent mode's composer: the words, the files given with them (picked,
  /// pasted, dropped; uploaded as they are added) and the permission mode the
  /// task starts in. Focused, it moves to the middle and grows; its box goes,
  /// leaving the text, the files and the key hints.

  import { LL } from '../../i18n/i18n-svelte'
  import type { Flow, PermissionMode } from '../../lib/agentApi'
  import { ApiError } from '../../lib/api'
  import { Button, Icon, IconButton } from '../lk'
  import type { AgentStore } from './agentStore.svelte'
  import AttachmentChips from './AttachmentChips.svelte'
  import { autosize } from './autosize'

  interface Props {
    store: AgentStore
    placeholder: string
    disabled: boolean
    /// The composer has the focus (or holds something): the page around it
    /// steps back.
    focused: boolean
    onfocuschange: (focused: boolean) => void
    onstarted: (flow: Flow) => void
  }

  const { store, placeholder, disabled, focused, onfocuschange, onstarted }: Props = $props()

  /// The new task's unsent words, files and mode, kept by the store.
  // svelte-ignore state_referenced_locally
  const d = store.draft('')
  const atts = d.atts
  let sending = $state(false)
  let error = $state<string | null>(null)
  let multi = $state(false)
  let cy = $state(0)
  let modeOpen = $state(false)
  let box = $state<HTMLDivElement | null>(null)
  let ta = $state<HTMLTextAreaElement | null>(null)
  let picker = $state<HTMLInputElement | null>(null)
  let menu = $state<HTMLDivElement | null>(null)

  const mode = $derived.by<PermissionMode>(() => {
    const m = d.mode ?? store.defaultMode
    return m === 'bypass' && !store.bypassAllowed ? 'manual' : m
  })

  const MODES: { id: PermissionMode; glyph: string; bg: string; fg: string }[] = [
    { id: 'auto', glyph: 'auto_mode', bg: 'var(--color-accent-soft)', fg: 'var(--color-accent-text)' },
    { id: 'manual', glyph: 'rule', bg: 'var(--fill-hover)', fg: 'var(--text-primary)' },
    { id: 'bypass', glyph: 'bolt', bg: 'var(--color-warning-soft)', fg: 'var(--color-warning)' },
  ]
  const cur = $derived(MODES.find((m) => m.id === mode) ?? MODES[1])
  const modeLabel = (id: PermissionMode) =>
    id === 'auto' ? $LL.settingsAgentModeAuto() : id === 'bypass' ? $LL.settingsAgentModeBypass() : $LL.settingsAgentModeManual()
  const modeDesc = (id: PermissionMode) =>
    id === 'auto'
      ? $LL.deskAgentModeAutoDesc()
      : id === 'bypass'
        ? store.bypassAllowed
          ? $LL.deskAgentModeBypassDesc()
          : $LL.deskAgentModeBypassOff()
        : $LL.deskAgentModeManualDesc()
  const usable = (id: PermissionMode) => id !== 'bypass' || store.bypassAllowed

  function cycleMode() {
    const ids = MODES.map((m) => m.id).filter(usable)
    d.mode = ids[(ids.indexOf(mode) + 1) % ids.length]
  }

  const keys = $derived([
    { key: '⏎', label: $LL.deskAgentHintSend() },
    { key: '⇧⏎', label: $LL.deskAgentHintNewline() },
    { key: '⌘V', label: $LL.deskAgentHintPaste() },
    { key: '⌘U', label: $LL.deskAgentHintPick() },
    { key: '⇧⇥', label: $LL.deskAgentHintMode() },
    { key: $LL.deskAgentHintDrop(), label: $LL.deskAgentHintDropLabel() },
    { key: 'esc', label: $LL.deskAgentHintCancel() },
  ])

  // ---------------------------------------------------------------------------
  // Size and place

  /// How far the composer moves so its middle is the area's middle: its
  /// bottom stays put as it grows, so measured once, from the bottom, and
  /// `translateY(calc(D + 50%))` keeps it centred at any height.
  function centre(): number {
    const el = box
    const parent = el?.offsetParent as HTMLElement | null
    if (!el || !parent) return 0
    return Math.round(parent.clientHeight / 2 - (el.offsetTop + el.offsetHeight))
  }

  function enter() {
    if (focused) return
    cy = centre()
    onfocuschange(true)
  }

  function onfocusout() {
    if (!d.text.trim() && !atts.length) onfocuschange(false)
  }

  export function focus() {
    ta?.focus()
  }

  export function addFiles(list: FileList | File[] | null | undefined) {
    atts.addFiles(list)
  }

  /// Empties it; [discard] also drops the uploads, which no task took.
  function clear(discard: boolean) {
    d.clear(discard)
    error = null
    modeOpen = false
    onfocuschange(false)
  }

  // ---------------------------------------------------------------------------
  // Sending

  export async function send(text = d.text) {
    const words = text.trim()
    if ((!words && !atts.length) || sending || disabled) return
    sending = true
    error = null
    try {
      const ids = await atts.ids()
      if (!ids) return
      const f = await store.startFlow(words, mode, ids)
      clear(false)
      d.mode = null
      ta?.blur()
      onstarted(f)
    } catch (e) {
      error = e instanceof ApiError ? e.message : String(e)
    } finally {
      sending = false
    }
  }

  function onkeydown(e: KeyboardEvent) {
    if (e.isComposing) return
    if (e.key === 'Enter' && !e.shiftKey) {
      e.preventDefault()
      void send()
    } else if (e.key === 'Tab' && e.shiftKey) {
      e.preventDefault()
      cycleMode()
    } else if (e.key === 'Escape') {
      // The draft goes; the next esc leaves Agent mode.
      e.preventDefault()
      e.stopPropagation()
      clear(true)
      ta?.blur()
    } else if ((e.metaKey || e.ctrlKey) && e.key.toLowerCase() === 'u') {
      e.preventDefault()
      picker?.click()
    }
  }

  function onpaste(e: ClipboardEvent) {
    // Files, and a long paste (a log), are carried as files, not in the field.
    if (atts.paste(e)) e.preventDefault()
  }

  // The mode menu closes on a press anywhere else.
  $effect(() => {
    if (!modeOpen) return
    const down = (e: MouseEvent) => {
      const t = e.target as Element | null
      if (menu?.contains(t) || t?.closest?.('[data-mode-chip]')) return
      modeOpen = false
    }
    document.addEventListener('mousedown', down)
    return () => document.removeEventListener('mousedown', down)
  })

  const keep = (e: Event) => e.preventDefault()
</script>

{#snippet chip(small: boolean)}
  <button
    type="button"
    class="mode"
    class:mode--small={small}
    data-mode-chip
    aria-haspopup="menu"
    aria-expanded={modeOpen}
    aria-label={$LL.deskAgentModeAria({ mode: modeLabel(mode) })}
    style:background={cur.bg}
    style:color={cur.fg}
    onmousedown={keep}
    onclick={() => (modeOpen = !modeOpen)}
  >
    <Icon name={cur.glyph} size={small ? 14 : 15} fill />{modeLabel(mode)}<Icon name="expand_more" size={small ? 14 : 15} />
  </button>
{/snippet}

<div bind:this={box} class="box" class:box--focused={focused} style:--cy="{cy}px">
  {#if atts.length}
    <div class="atts"><AttachmentChips {atts} /></div>
  {/if}
  <div class="row" class:row--multi={multi}>
    <label class="field">
      <span class="sr-only">{$LL.deskAgentTaskLabel()}</span>
      <textarea
        bind:this={ta}
        bind:value={d.text}
        rows="1"
        class="ta"
        use:autosize={{ value: d.text, max: 8, onmulti: (m) => (multi = m) }}
        {placeholder}
        {disabled}
        onfocus={enter}
        onblur={onfocusout}
        {onkeydown}
        {onpaste}
      ></textarea>
    </label>
    <div class="ctl" inert={focused}>
      {@render chip(false)}
      <IconButton icon="attach_file" label={$LL.deskAgentAttach()} {disabled} onmousedown={keep} onclick={() => picker?.click()} />
      <Button variant="primary" icon="arrow_upward" disabled={(!d.text.trim() && !atts.length) || sending || disabled} onclick={() => send()}>
        {$LL.deskAgentSend()}
      </Button>
    </div>
  </div>
  <div class="hintbox" inert={!focused}>
  <div class="hints" aria-label={$LL.deskAgentHints()}>
    {@render chip(true)}
    {#each keys as k (k.key)}
      <span class="hint"><kbd>{k.key}</kbd>{k.label}</span>
    {/each}
    {#if mode === 'bypass'}
      <span class="warn"><Icon name="warning" size={14} fill />{$LL.deskAgentBypassWarn()}</span>
    {/if}
  </div>
  </div>
  {#if error ?? atts.error}
    <div class="error"><Icon name="error" size={15} />{error ?? atts.error}</div>
  {/if}
  {#if modeOpen}
    <div bind:this={menu} class="menu" class:menu--down={focused} role="menu" aria-label={$LL.deskAgentModeTitle()}>
      <div class="lk-caps menu__head">{$LL.deskAgentModeTitle()}</div>
      {#each MODES as m (m.id)}
        <button
          type="button"
          role="menuitemradio"
          aria-checked={m.id === mode}
          class="item"
          class:item--on={m.id === mode}
          disabled={!usable(m.id)}
          onmousedown={keep}
          onclick={() => {
            d.mode = m.id
            modeOpen = false
          }}
        >
          <span class="item__mark" style:background={m.bg === 'var(--fill-hover)' ? 'var(--surface-control)' : m.bg} style:color={m.fg}>
            <Icon name={m.glyph} size={15} fill />
          </span>
          <span class="item__text">
            <span class="item__head"><span class="item__label">{modeLabel(m.id)}</span><span class="item__id">{m.id}</span></span>
            <span class="item__desc">{modeDesc(m.id)}</span>
          </span>
          {#if m.id === mode}<Icon name="check" size={16} weight={600} color="var(--color-accent-text)" />{/if}
        </button>
      {/each}
      <div class="menu__foot">{$LL.deskAgentModeFoot()}</div>
    </div>
  {/if}
  <input
    bind:this={picker}
    type="file"
    multiple
    tabindex="-1"
    aria-hidden="true"
    hidden
    onchange={(e) => {
      const input = e.currentTarget
      addFiles(input.files)
      input.value = ''
      enter()
      ta?.focus()
    }}
  />
</div>

<style>
  /* The design system's composer: 720 wide on glass; focused, 880 with no box. */
  .box {
    --grow: 600ms var(--ease-emphasized);
    position: relative;
    width: min(720px, 100%);
    box-sizing: border-box;
    display: flex;
    flex-direction: column;
    padding: 13px 13px 13px 21px;
    border-radius: 21px;
    background: var(--glass-tile);
    box-shadow:
      inset 0 0 0 0.5px var(--border-glass),
      var(--shadow-popover);
    transform: translateY(calc(0px + 0%));
    transition:
      transform var(--grow),
      width var(--grow),
      padding var(--grow),
      border-radius var(--grow),
      background-color 240ms var(--ease-standard),
      box-shadow 240ms var(--ease-standard);
  }
  .box--focused {
    width: min(880px, 100%);
    padding: 0;
    border-radius: 27px;
    background: transparent;
    box-shadow:
      inset 0 0 0 0.5px transparent,
      0 0 0 0 transparent,
      0 0 0 0 transparent;
    transform: translateY(calc(var(--cy) + 50%));
  }
  .atts {
    margin-bottom: 9px;
    transition: margin var(--grow);
  }
  .box--focused .atts {
    margin-bottom: 13px;
  }
  .row {
    display: flex;
    align-items: center;
    gap: var(--space-9);
  }
  .row--multi {
    align-items: flex-end;
  }
  .field {
    flex: 1;
    min-width: 0;
    display: flex;
  }
  /* One line until the text needs more (`autosize`); in em, so it follows
     the font size as it grows. */
  .ta {
    flex: 1;
    min-width: 0;
    display: block;
    box-sizing: border-box;
    height: calc(1.4em + 6px);
    margin: 0;
    padding: 3px 0;
    border: 0;
    outline: 0;
    resize: none;
    overflow-y: auto;
    background: transparent;
    font-family: var(--font-ui);
    font-weight: 400;
    line-height: 1.4;
    font-size: 17px;
    letter-spacing: 0;
    color: var(--text-primary);
    caret-color: var(--color-accent);
    transition:
      font-size var(--grow),
      letter-spacing var(--grow);
  }
  .box--focused .ta {
    font-size: 27px;
    letter-spacing: -0.01em;
  }
  .ta::placeholder {
    white-space: nowrap;
    overflow: hidden;
    text-overflow: ellipsis;
    color: var(--text-tertiary);
  }
  .ctl {
    flex: none;
    display: flex;
    align-items: center;
    gap: var(--space-5);
    overflow: hidden;
    max-width: 260px;
    opacity: 1;
    transition:
      max-width var(--grow),
      opacity 240ms var(--ease-standard) 240ms;
  }
  .box--focused .ctl {
    max-width: 0;
    opacity: 0;
    pointer-events: none;
    transition:
      max-width var(--grow),
      opacity 150ms var(--ease-exit);
  }
  .mode {
    flex: none;
    height: 30px;
    display: inline-flex;
    align-items: center;
    gap: var(--space-5);
    padding: 0 5px 0 9px;
    border: 0;
    border-radius: var(--radius-full);
    font: 600 var(--text-12) / 1 var(--font-ui);
    white-space: nowrap;
    cursor: default;
  }
  .mode--small {
    height: 24px;
    padding: 0 3px 0 7px;
  }
  /* Opens to the hints' own height, whatever they wrap to. */
  .hintbox {
    display: grid;
    grid-template-rows: 0fr;
    margin-top: 0;
    opacity: 0;
    transition:
      grid-template-rows var(--grow),
      margin var(--grow),
      opacity 120ms var(--ease-exit);
  }
  .box--focused .hintbox {
    grid-template-rows: 1fr;
    margin-top: 17px;
    opacity: 1;
    transition:
      grid-template-rows var(--grow),
      margin var(--grow),
      opacity 300ms var(--ease-standard) 260ms;
  }
  .hints {
    min-height: 0;
    overflow: hidden;
    display: flex;
    flex-wrap: wrap;
    align-items: center;
    gap: 5px 17px;
    font-size: var(--text-12);
    color: var(--text-tertiary);
  }
  .hint {
    display: inline-flex;
    align-items: center;
    gap: var(--space-5);
    white-space: nowrap;
  }
  kbd {
    font-family: var(--font-mono);
    font-size: var(--text-11);
    line-height: 1;
    padding: 3px 5px;
    border-radius: 5px;
    background: var(--fill-hover);
    box-shadow: inset 0 0 0 0.5px var(--border-strong);
    color: var(--text-secondary);
  }
  .warn {
    flex-basis: 100%;
    display: inline-flex;
    align-items: center;
    gap: var(--space-5);
    color: var(--color-warning);
  }
  .error {
    display: flex;
    align-items: center;
    gap: var(--space-7);
    margin-top: var(--space-9);
    font-size: var(--text-13);
    color: var(--color-danger);
  }
  .menu {
    position: absolute;
    bottom: calc(100% + 9px);
    right: 0;
    z-index: 10;
    width: 360px;
    max-width: 100%;
    box-sizing: border-box;
    padding: 5px;
    border-radius: 13px;
    background: var(--glass-menu);
    backdrop-filter: var(--blur-menu);
    -webkit-backdrop-filter: var(--blur-menu);
    box-shadow:
      var(--shadow-menu),
      inset 0 0 0 0.5px var(--border-glass);
    transform-origin: bottom right;
    animation: lk-menu-in 220ms var(--ease-spring);
    font-size: var(--text-13);
    color: var(--text-primary);
  }
  .menu--down {
    top: calc(100% + 9px);
    bottom: auto;
    left: 0;
    right: auto;
    transform-origin: top left;
  }
  .menu__head {
    padding: 7px 9px 5px;
  }
  .item {
    width: 100%;
    display: grid;
    grid-template-columns: 26px minmax(0, 1fr) 16px;
    gap: var(--space-11);
    align-items: start;
    padding: 9px;
    border: 0;
    border-radius: 9px;
    background: transparent;
    color: inherit;
    font: inherit;
    text-align: left;
    cursor: default;
  }
  .item:hover:not(:disabled) {
    background: var(--fill-hover);
  }
  .item--on {
    background: var(--fill-press);
  }
  .item:disabled {
    opacity: 0.5;
  }
  .item__mark {
    width: 26px;
    height: 26px;
    border-radius: 26px;
    display: inline-flex;
    align-items: center;
    justify-content: center;
  }
  .item__text {
    display: flex;
    flex-direction: column;
    gap: 3px;
    min-width: 0;
  }
  .item__head {
    display: flex;
    align-items: baseline;
    gap: var(--space-7);
  }
  .item__label {
    font-weight: 600;
  }
  .item__id {
    font-family: var(--font-mono);
    font-size: var(--text-11);
    color: var(--text-tertiary);
  }
  .item__desc {
    font-size: var(--text-12);
    line-height: 1.45;
    color: var(--text-secondary);
  }
  .menu__foot {
    margin-top: 3px;
    padding: 7px 9px 5px;
    border-top: 0.5px solid var(--border-hairline);
    font-size: var(--text-11);
    color: var(--text-tertiary);
  }
  .sr-only {
    position: absolute;
    width: 1px;
    height: 1px;
    overflow: hidden;
    clip: rect(0 0 0 0);
  }
</style>
