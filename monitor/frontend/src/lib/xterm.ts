/// Mounts xterm.js on an element and drives a [`TerminalSession`] with it.
///
/// Kept out of the terminal page so the container shell — a dialog on the
/// containers page — mounts the same terminal rather than a copy of this:
/// xterm is loaded by dynamic `import()` so it stays out of the main bundle,
/// and the fit-after-a-frame dance is what keeps the size sent to the agent
/// correct.
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

/// Resolved from the document, not from the theme store: the store's 'system'
/// setting is decided by a media query at paint time, so the class on <html>
/// is the only place the answer actually exists.
function isDark(): boolean {
  const cls = document.documentElement.classList
  if (cls.contains('dark')) return true
  if (cls.contains('light')) return false
  return window.matchMedia?.('(prefers-color-scheme: dark)').matches ?? false
}

function terminalTheme() {
  return isDark()
    ? { background: '#0b0f14', foreground: '#d7dce2', cursor: '#d7dce2' }
    : { background: '#ffffff', foreground: '#1f2933', cursor: '#1f2933' }
}

/// The terminal's own background, for a container the terminal does not fill.
///
/// The rows are whole cells, so the last one rarely ends exactly at the
/// container's bottom edge: a container of a fixed height leaves a strip below
/// it. That strip is filled with this, rather than with whatever colour the
/// container happens to have, so it is invisible.
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
      },
      get cols() {
        return term.cols
      },
      get rows() {
        return term.rows
      },
    },
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
      term.dispose()
    },
  }
}
