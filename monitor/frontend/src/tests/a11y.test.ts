import { describe, it, expect, vi } from 'vitest'
import { render, screen, fireEvent } from '@testing-library/svelte'
import '@testing-library/jest-dom/vitest'
import ModalHarness from './fixtures/ModalHarness.svelte'
import LineChart from '../components/LineChart.svelte'
import { persistLocale } from '../i18n/init'

describe('Modal', () => {
  it('moves focus in, keeps Tab inside and gives focus back on Escape', async () => {
    const onclose = vi.fn()
    render(ModalHarness, { onclose })
    const opener = screen.getByRole('button', { name: 'Open' })
    opener.focus()
    await fireEvent.click(opener)

    const first = screen.getByLabelText('First')
    const second = screen.getByLabelText('Second')
    const close = screen.getByRole('button', { name: 'Close' })
    expect(first).toHaveFocus()

    second.focus()
    await fireEvent.keyDown(second, { key: 'Tab' })
    expect(close).toHaveFocus()
    await fireEvent.keyDown(close, { key: 'Tab', shiftKey: true })
    expect(second).toHaveFocus()

    await fireEvent.keyDown(second, { key: 'Escape' })
    expect(onclose).toHaveBeenCalledOnce()
    expect(screen.queryByRole('dialog')).not.toBeInTheDocument()
    expect(opener).toHaveFocus()
  })

  it('ignores Escape while closed', async () => {
    const onclose = vi.fn()
    render(ModalHarness, { onclose })
    await fireEvent.keyDown(window, { key: 'Escape' })
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

  it('lists every point in a table', () => {
    render(LineChart, props)
    const table = screen.getByRole('table', { hidden: true })
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
