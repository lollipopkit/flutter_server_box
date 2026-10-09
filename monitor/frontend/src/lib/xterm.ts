/// Mounts xterm.js on an element and drives a [`TerminalSession`] with it.
///
/// Kept out of the terminal page so the container shell — a dialog on the
/// containers page — mounts the same terminal rather than a copy of this:
/// xterm is loaded by dynamic `import()` so it stays out of the main bundle,
/// and the fit-after-a-frame dance is what keeps the size sent to the agent
/// correct.
import { attachProgramStatus, ProgramStatusRecords } from './programStatus'
import type { Renderer, TerminalSession } from './terminal.svelte'

/// How the terminal looks and sounds (Settings → Apps → Terminal).
export interface TerminalLook {
  fontSize?: number
  cursor?: 'block' | 'bar' | 'underline'
  /// A short tone on the bell character.
  bell?: boolean
}

export interface TerminalHandle {
  /// Applies a changed look to the running terminal.
  setLook(look: TerminalLook): void
  renderer: Renderer
  /// What the programs in the terminal report about themselves (OSC 7501,
  /// OSC 9;4, OSC 133). The page says when the shell behind it has exited.
  status: ProgramStatusRecords
  /// Re-reads the theme from the document, for a theme change.
  setTheme(): void
  /// Puts the caret in the terminal, so typing reaches the shell rather than
  /// whichever element had focus before this one was opened.
  focus(): void
  /// Calls [listener] with each title the shell sets (OSC 0/2), and once
  /// with the one set so far; the returned function stops it.
  onTitle(listener: (title: string) => void): () => void
  dispose(): void
}

/// Resolved from the document, not from the theme store: `data-theme` on
/// <html> is the mode in effect (a choice, the system's, or a theme's lock),
/// set before first paint.
function isDark(): boolean {
  const mode = document.documentElement.dataset.theme
  if (mode) return mode === 'dark'
  return window.matchMedia?.('(prefers-color-scheme: dark)').matches ?? false
}

/// What the terminal is drawn with when the desk's tokens cannot be read
/// (no desk on screen, no canvas): the design system's own values.
function fallbackTheme(dark: boolean) {
  return dark
    ? {
        background: '#0e0a0c',
        foreground: '#f5eef0',
        cursor: '#f5eef0',
        selectionBackground: 'rgba(184, 61, 104, 0.36)',
        selectionInactiveBackground: 'rgba(184, 61, 104, 0.2)',
      }
    : {
        background: '#ffffff',
        foreground: '#1f1619',
        cursor: '#1f1619',
        selectionBackground: 'rgba(115, 12, 55, 0.24)',
        selectionInactiveBackground: 'rgba(115, 12, 55, 0.12)',
      }
}

/// [css] (any colour CSS takes: a token, `color-mix()`) as `rgba()`, which is
/// what xterm parses; null without a canvas to resolve it on.
function concrete(css: string, probe: HTMLElement, ctx: CanvasRenderingContext2D): string | null {
  probe.style.color = ''
  probe.style.color = css
  if (!probe.style.color) return null
  ctx.clearRect(0, 0, 1, 1)
  ctx.fillStyle = getComputedStyle(probe).color
  ctx.fillRect(0, 0, 1, 1)
  const [r, g, b, a] = ctx.getImageData(0, 0, 1, 1).data
  return `rgba(${r}, ${g}, ${b}, ${+(a / 255).toFixed(3)})`
}

/// The terminal in the desk's tokens, so it follows the design system and an
/// installed theme alike: `--surface-terminal` under `--text-primary`, the
/// selection the accent's tint (xterm's own default is a translucent white,
/// which on a light background cannot be seen at all).
function terminalTheme() {
  const root = document.querySelector<HTMLElement>('.desk-root') ?? document.querySelector<HTMLElement>('.lk')
  const ctx = root ? document.createElement('canvas').getContext('2d', { willReadFrequently: true }) : null
  if (!root || !ctx) return fallbackTheme(isDark())
  const probe = document.createElement('span')
  probe.hidden = true
  root.append(probe)
  try {
    const read = (css: string) => concrete(css, probe, ctx)
    const background = read('var(--surface-terminal)')
    const foreground = read('var(--text-primary)')
    const [on, off] = isDark() ? [36, 20] : [24, 12]
    const selection = read(`color-mix(in srgb, var(--color-accent) ${on}%, transparent)`)
    const inactive = read(`color-mix(in srgb, var(--color-accent) ${off}%, transparent)`)
    if (!background || !foreground || !selection || !inactive) return fallbackTheme(isDark())
    return { background, foreground, cursor: foreground, selectionBackground: selection, selectionInactiveBackground: inactive }
  } finally {
    probe.remove()
  }
}

/// The terminal's own background, for a container the terminal does not fill.
///
/// The rows are whole cells, so the last one rarely ends exactly at the
/// container's bottom edge: a container of a fixed height leaves a strip below
/// it. That strip is filled with this, rather than with whatever colour the
/// container happens to have, so it is invisible.
export { terminalTheme }

export function terminalBackground(): string {
  return terminalTheme().background
}

/// Waits for the browser to have laid out. `requestAnimationFrame` runs after
/// style and layout for the coming frame, which is the earliest point a
/// flex-derived height can be measured.
const nextFrame = () =>
  new Promise<void>((resolve) => requestAnimationFrame(() => resolve()))

/// One short, quiet tone: the bell.
function ring() {
  try {
    const ctx = new AudioContext()
    const osc = ctx.createOscillator()
    const gain = ctx.createGain()
    osc.frequency.value = 880
    gain.gain.setValueAtTime(0.08, ctx.currentTime)
    gain.gain.exponentialRampToValueAtTime(0.001, ctx.currentTime + 0.15)
    osc.connect(gain).connect(ctx.destination)
    osc.start()
    osc.stop(ctx.currentTime + 0.15)
    osc.onended = () => void ctx.close()
  } catch {
    // No audio here: the bell is silent.
  }
}

export async function mountTerminal(
  host: HTMLElement,
  session: TerminalSession,
  look: TerminalLook = {},
): Promise<TerminalHandle> {
  // The stylesheet comes along in the same dynamic chunk, so it is fetched
  // with the terminal rather than on every panel load
  const [{ Terminal }, { FitAddon }] = await Promise.all([
    import('@xterm/xterm'),
    import('@xterm/addon-fit'),
    import('@xterm/xterm/css/xterm.css'),
  ])
  const term = new Terminal({
    convertEol: false,
    cursorBlink: true,
    fontSize: look.fontSize ?? 13,
    cursorStyle: look.cursor ?? 'block',
    fontFamily: 'ui-monospace, SFMono-Regular, Menlo, monospace',
    theme: terminalTheme(),
  })
  const fit = new FitAddon()
  term.loadAddon(fit)
  term.open(host)
  const decoder = new TextDecoder()

  let bell = look.bell ?? false
  term.onBell(() => {
    if (bell) ring()
  })
  let title = ''
  const titleListeners = new Set<(title: string) => void>()
  term.onTitleChange((next) => {
    title = next
    for (const listener of titleListeners) listener(next)
  })
  const status = new ProgramStatusRecords()
  const detachStatus = attachProgramStatus(term.parser, status, (data) => session.input(data))

  term.onData((data) => session.input(data))
  term.onResize(({ cols, rows }) => session.resize(cols, rows))

  let resizeObserver: ResizeObserver | null = null
  if (typeof ResizeObserver !== 'undefined') {
    resizeObserver = new ResizeObserver(() => fit.fit())
    resizeObserver.observe(host)
  }

  // Fitted a frame later, not inline with open(): the host's height comes from
  // flex sizing, which the browser has not resolved yet in this tick.
  // Measuring now would see zero and leave the terminal at its default 24
  // rows — the size then sent to the shell as well, so it would not just look
  // wrong, it would wrap wrong.
  await nextFrame()
  fit.fit()

  return {
    renderer: {
      write(data, done) {
        // Decoded with `stream: true` so a multi-byte character split across
        // two frames isn't rendered as replacement characters
        term.write(decoder.decode(data, { stream: true }), done)
      },
      reset() {
        term.reset()
        status.clear()
      },
      get cols() {
        return term.cols
      },
      get rows() {
        return term.rows
      },
    },
    status,
    setTheme() {
      term.options.theme = terminalTheme()
    },
    setLook(next) {
      if (next.fontSize !== undefined) term.options.fontSize = next.fontSize
      if (next.cursor !== undefined) term.options.cursorStyle = next.cursor
      if (next.bell !== undefined) bell = next.bell
      fit.fit()
    },
    focus() {
      term.focus()
    },
    onTitle(listener) {
      titleListeners.add(listener)
      if (title) listener(title)
      return () => titleListeners.delete(listener)
    },
    dispose() {
      resizeObserver?.disconnect()
      detachStatus()
      term.dispose()
    },
  }
}
