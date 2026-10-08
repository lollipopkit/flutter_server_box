import { describe, it, expect, vi } from 'vitest'
import { render, screen, fireEvent } from '@testing-library/svelte'
import '@testing-library/jest-dom/vitest'
import TitleTabs from '@lollipopkit/desk-ui/TitleTabs.svelte'
import { viewIn } from '@lollipopkit/desk-ui/motion'

const props = (keys: string[], active: string) => ({
  tabs: keys.map((key) => ({ key, label: key, title: `/root/${key}` })),
  active,
  onselect: vi.fn(),
  onclose: vi.fn(),
  onadd: vi.fn(),
  addLabel: 'New tab',
  closeLabel: 'Close',
})

describe('TitleTabs', () => {
  it('marks the chosen tab and has one indicator', () => {
    const { container } = render(TitleTabs, props(['a', 'b'], 'b'))
    expect(screen.getByRole('tab', { name: /b/ })).toHaveAttribute('aria-selected', 'true')
    expect(container.querySelectorAll('.lk-ttabs__ind')).toHaveLength(1)
  })

  it('selects, closes and adds', async () => {
    const p = props(['a', 'b'], 'a')
    render(TitleTabs, p)
    await fireEvent.click(screen.getByText('b'))
    expect(p.onselect).toHaveBeenCalledWith('b')
    await fireEvent.click(screen.getByRole('button', { name: 'Close b' }))
    expect(p.onclose).toHaveBeenCalledWith('b')
    expect(p.onselect).toHaveBeenCalledTimes(1)
    await fireEvent.click(screen.getByRole('button', { name: 'New tab' }))
    expect(p.onadd).toHaveBeenCalled()
  })

  it('grows in only a tab added after the first render, until its animation ends', async () => {
    const { container, rerender } = render(TitleTabs, props(['a', 'b'], 'a'))
    expect(container.querySelector('.lk-ttabs__tab--new')).toBeNull()
    await rerender(props(['a', 'b', 'c'], 'c'))
    const fresh = container.querySelectorAll('.lk-ttabs__tab--new')
    expect(fresh).toHaveLength(1)
    expect(fresh[0]).toHaveTextContent('c')
    // jsdom has no AnimationEvent: an Event carrying the name stands in.
    await fireEvent(fresh[0], Object.assign(new Event('animationend', { bubbles: true }), { animationName: 'lk-ttab-in' }))
    expect(container.querySelector('.lk-ttabs__tab--new')).toBeNull()
  })

  it('offers no close on a single tab', () => {
    render(TitleTabs, props(['a'], 'a'))
    expect(screen.queryByRole('button', { name: /Close/ })).toBeNull()
  })
})

describe('viewIn', () => {
  it('fades a view in when its key changes, not on the first render or to null', () => {
    const node = document.createElement('div')
    const action = viewIn(node, 'list')
    expect(node.classList.contains('lk-view-in')).toBe(false)
    action.update('grid')
    expect(node.classList.contains('lk-view-in')).toBe(true)
    node.classList.remove('lk-view-in')
    action.update(null)
    expect(node.classList.contains('lk-view-in')).toBe(false)
  })
})
