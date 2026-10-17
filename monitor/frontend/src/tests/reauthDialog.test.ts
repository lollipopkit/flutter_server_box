import { describe, it, expect, vi } from 'vitest'
import { render, screen, fireEvent } from '@testing-library/svelte'
import '@testing-library/jest-dom/vitest'
import ReauthDialog from '../components/ReauthDialog.svelte'

describe('ReauthDialog', () => {
  const field = () => screen.getByLabelText('Current password') as HTMLInputElement

  it.each([
    ['Cancel', () => fireEvent.click(screen.getByRole('button', { name: 'Cancel' }))],
    ['Escape', () => fireEvent.keyDown(document.body, { key: 'Escape' })],
  ])('forgets the typed password when dismissed with %s', async (_, dismiss) => {
    const onclose = vi.fn()
    render(ReauthDialog, { open: true, onconfirm: vi.fn(), onclose })
    await fireEvent.input(field(), { target: { value: 'hunter2' } })
    expect(field().value).toBe('hunter2')

    await dismiss()
    expect(onclose).toHaveBeenCalledOnce()
    // Still drawn, since the test owns `open`: the field shows what is kept
    expect(field().value).toBe('')
  })
})
