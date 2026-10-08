/// Mounts xterm.js on an element and drives a [`TerminalSession`] with it.
///
/// Kept out of the terminal page so the container shell — a dialog on the
/// containers page — mounts the same terminal rather than a copy of this:
/// xterm is loaded by dynamic `import()` so it stays out of the main bundle,
/// and the fit-after-a-frame dance is what keeps the size sent to the agent
/// correct.
import { attachProgramStatus, ProgramStatusRecords } from './programStatus'
import type { Renderer, TerminalSession } from './terminal.svelte'

export interface TerminalHandle {
  renderer: Renderer
  /// What the programs in the terminal report about themselves (OSC 7501,
  /// OSC 9;4, OSC 133). The page says when the shell behind it has exited.
  status: ProgramStatusRecords
  /// Re-reads the theme from the document, for a theme change.
  setTheme(): void
  /// Puts the caret in the terminal, so typing reaches the shell rather than
  /// whichever element had focus before this one was opened.
  focus(): void
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

export async function mountTerminal(
  host: HTMLElement,
  session: TerminalSession,
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
    fontSize: 13,
    fontFamily: 'ui-monospace, SFMono-Regular, Menlo, monospace',
    theme: terminalTheme(),
  })
  const fit = new FitAddon()
  term.loadAddon(fit)
  term.open(host)
  const decoder = new TextDecoder()

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
    focus() {
      term.focus()
    },
    dispose() {
      resizeObserver?.disconnect()
      detachStatus()
      term.dispose()
    },
  }
}
