import { describe, it, expect, vi, beforeEach, afterEach } from 'vitest'
import { render, screen, fireEvent } from '@testing-library/svelte'
import '@testing-library/jest-dom/vitest'
import ScreenReaderToggle from '../components/ScreenReaderToggle.svelte'
import { screenReader } from '../lib/screenReader.svelte'
import { mountTerminal } from '../lib/xterm'
import type { TerminalSession } from '../lib/terminal.svelte'

const terminals: FakeTerminal[] = []
class FakeTerminal {
  options: Record<string, unknown>
  parser = {
    registerOscHandler: () => ({ dispose() {} }),
    registerEscHandler: () => ({ dispose() {} }),
  }
  dispose = vi.fn()
  constructor(options: Record<string, unknown>) {
    this.options = { ...options }
    terminals.push(this)
  }
  loadAddon() {}
  open() {}
  onData() {}
  onResize() {}
  onBell() {}
  onTitleChange() {}
}
vi.mock('@xterm/xterm', () => ({ Terminal: FakeTerminal }))
vi.mock('@xterm/addon-fit', () => ({ FitAddon: class { fit() {} } }))
vi.mock('@xterm/xterm/css/xterm.css', () => ({}))

const session = { input() {}, resize() {} } as unknown as TerminalSession

beforeEach(() => {
  terminals.length = 0
  localStorage.clear()
  screenReader.set(false)
  vi.stubGlobal('requestAnimationFrame', (cb: () => void) => setTimeout(cb, 0))
})

afterEach(() => {
  vi.unstubAllGlobals()
  screenReader.set(false)
})

describe('terminal screen reader mode', () => {
  it('is off unless asked for, and follows the setting while mounted', async () => {
    const handle = await mountTerminal(document.createElement('div'), session)
    expect(terminals[0].options.screenReaderMode).toBe(false)

    screenReader.set(true)
    expect(terminals[0].options.screenReaderMode).toBe(true)

    handle.dispose()
    screenReader.set(false)
    expect(terminals[0].options.screenReaderMode).toBe(true)
  })

  it('opens a terminal with the stored choice', async () => {
    screenReader.set(true)
    await mountTerminal(document.createElement('div'), session)
    expect(terminals[0].options.screenReaderMode).toBe(true)
  })

  it('is remembered across a reload', async () => {
    screenReader.set(true)
    vi.resetModules()
    const reloaded = await import('../lib/screenReader.svelte')
    expect(reloaded.screenReader.enabled).toBe(true)

    reloaded.screenReader.set(false)
    vi.resetModules()
    const again = await import('../lib/screenReader.svelte')
    expect(again.screenReader.enabled).toBe(false)
  })

  it('says its state on the toggle', async () => {
    render(ScreenReaderToggle)
    const toggle = screen.getByRole('button', { name: 'Screen reader mode' })
    expect(toggle).toHaveAttribute('aria-pressed', 'false')
    await fireEvent.click(toggle)
    expect(toggle).toHaveAttribute('aria-pressed', 'true')
    expect(screenReader.enabled).toBe(true)
  })
})
