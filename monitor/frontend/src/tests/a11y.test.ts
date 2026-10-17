import { describe, it, expect, vi } from 'vitest'
import { render, screen, fireEvent } from '@testing-library/svelte'
import '@testing-library/jest-dom/vitest'
import ModalHarness from './fixtures/ModalHarness.svelte'
import LineChart from '../components/LineChart.svelte'
import { persistLocale } from '../i18n/init'

describe('Modal', () => {
  it('focuses the dialog, keeps Tab inside and gives focus back on Escape', async () => {
    const onclose = vi.fn()
    render(ModalHarness, { onclose })
    const opener = screen.getByRole('button', { name: 'Open' })
    opener.focus()
    await fireEvent.click(opener)

    const dialog = screen.getByRole('dialog', { name: 'Dialog' })
    const first = screen.getByLabelText('First')
    const inner = screen.getByRole('button', { name: 'Inner' })
    const close = screen.getByRole('button', { name: 'Close' })
    // Not the first control: it may be an action that runs on Enter
    expect(dialog).toHaveFocus()

    await fireEvent.keyDown(dialog, { key: 'Tab', shiftKey: true })
    expect(inner).toHaveFocus()
    await fireEvent.keyDown(inner, { key: 'Tab' })
    expect(close).toHaveFocus()
    await fireEvent.keyDown(close, { key: 'Tab', shiftKey: true })
    expect(inner).toHaveFocus()
    first.focus()

    await fireEvent.keyDown(first, { key: 'Escape' })
    expect(onclose).toHaveBeenCalledOnce()
    expect(screen.queryByRole('dialog')).not.toBeInTheDocument()
    expect(opener).toHaveFocus()
  })

  it('focuses what the content marks with data-autofocus', async () => {
    render(ModalHarness, { autofocusSecond: true })
    await fireEvent.click(screen.getByRole('button', { name: 'Open' }))
    expect(screen.getByLabelText('Second')).toHaveFocus()
  })

  it('still answers Escape and Tab once focus fell out of the dialog', async () => {
    const onclose = vi.fn()
    render(ModalHarness, { onclose })
    await fireEvent.click(screen.getByRole('button', { name: 'Open' }))
    // A focused button that became disabled leaves focus on the body
    ;(document.activeElement as HTMLElement).blur()
    expect(document.body).toHaveFocus()

    await fireEvent.keyDown(document.body, { key: 'Tab' })
    expect(screen.getByRole('button', { name: 'Close' })).toHaveFocus()

    ;(document.activeElement as HTMLElement).blur()
    await fireEvent.keyDown(document.body, { key: 'Escape' })
    expect(onclose).toHaveBeenCalledOnce()
  })

  it('pulls focus back from the page behind', async () => {
    render(ModalHarness)
    await fireEvent.click(screen.getByRole('button', { name: 'Open' }))
    screen.getByRole('button', { name: 'Behind' }).focus()
    expect(screen.getByRole('dialog', { name: 'Dialog' })).toHaveFocus()
  })

  it('closes only the innermost dialog on Escape', async () => {
    const onclose = vi.fn()
    const oninnerclose = vi.fn()
    render(ModalHarness, { onclose, oninnerclose })
    await fireEvent.click(screen.getByRole('button', { name: 'Open' }))
    await fireEvent.click(screen.getByRole('button', { name: 'Inner' }))
    expect(screen.getByRole('dialog', { name: 'Inner dialog' })).toHaveFocus()

    await fireEvent.keyDown(document.body, { key: 'Escape' })
    expect(oninnerclose).toHaveBeenCalledOnce()
    expect(onclose).not.toHaveBeenCalled()
    expect(screen.getByRole('dialog', { name: 'Dialog' })).toBeInTheDocument()
  })

  it('ignores Escape while closed', async () => {
    const onclose = vi.fn()
    render(ModalHarness, { onclose })
    await fireEvent.keyDown(document, { key: 'Escape' })
    expect(onclose).not.toHaveBeenCalled()
  })

  it('takes its close label from the app', async () => {
    render(ModalHarness, { closeLabel: 'Schließen' })
    await fireEvent.click(screen.getByRole('button', { name: 'Open' }))
    expect(screen.getByRole('button', { name: 'Schließen' })).toBeInTheDocument()
  })
})

describe('LineChart', () => {
  // jsdom has none; bind:clientWidth needs one
  vi.stubGlobal(
    'ResizeObserver',
    class {
      observe() {}
      unobserve() {}
      disconnect() {}
    },
  )

  const props = {
    title: 'Usage',
    labels: ['2026-10-17T10:00:00Z', '2026-10-17T10:01:00Z', '2026-10-17T10:02:00Z'],
    series: [{ label: 'CPU', color: '#000', values: [10, null, 30] }],
    format: (v: number) => `${v}%`,
  }

  it('steps through the points from the keyboard', async () => {
    render(LineChart, props)
    const slider = screen.getByRole('slider', { name: 'Usage' })
    expect(slider).toHaveAttribute('aria-valuenow', '2')
    expect(slider.getAttribute('aria-valuetext')).toContain('CPU: 30%')

    await fireEvent.keyDown(slider, { key: 'ArrowLeft' })
    expect(slider).toHaveAttribute('aria-valuenow', '1')
    expect(slider.getAttribute('aria-valuetext')).toContain('CPU: --')

    await fireEvent.keyDown(slider, { key: 'Home' })
    expect(slider).toHaveAttribute('aria-valuenow', '0')
    expect(slider.getAttribute('aria-valuetext')).toContain('CPU: 10%')
  })

  it('lists every point in a table, built only once opened', async () => {
    const { container } = render(LineChart, props)
    expect(container.querySelector('table')).toBeNull()
    const details = container.querySelector('details')!
    details.open = true
    await fireEvent(details, new Event('toggle'))
    const table = screen.getByRole('table')
    expect(table.querySelectorAll('tbody tr')).toHaveLength(3)
    expect(table).toHaveTextContent('30%')
  })
})

describe('html lang', () => {
  it('follows the panel language', () => {
    persistLocale('de')
    expect(document.documentElement.lang).toBe('de')
    persistLocale('en')
    expect(document.documentElement.lang).toBe('en')
  })
})
