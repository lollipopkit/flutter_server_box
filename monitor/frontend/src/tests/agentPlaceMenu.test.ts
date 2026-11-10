import { describe, it, expect } from 'vitest'
import { placeMenu } from '../desk/agent/placeMenu'

/// An anchor from [top] to [bottom] in a viewport [height] tall, and a menu
/// [menu] tall inside it.
function place(top: number, bottom: number, height: number, menu: number) {
  Object.defineProperty(window, 'innerHeight', { value: height, configurable: true })
  const anchor = document.createElement('div')
  anchor.getBoundingClientRect = () => ({ top, bottom }) as DOMRect
  document.body.appendChild(anchor)
  const node = document.createElement('div')
  Object.defineProperty(node, 'scrollHeight', { value: menu })
  anchor.appendChild(node)
  placeMenu(node, anchor)
  return { down: node.style.top !== 'auto', max: node.style.getPropertyValue('--menu-max') }
}

describe('a menu placed past its anchor', () => {
  it('opens below where it fits', () => {
    expect(place(300, 400, 600, 150)).toEqual({ down: true, max: '183px' })
  })

  it('opens above where only that fits', () => {
    expect(place(300, 400, 600, 250)).toEqual({ down: false, max: '283px' })
  })

  it('takes the roomier side, cut to it, where neither fits', () => {
    expect(place(300, 400, 600, 500)).toEqual({ down: false, max: '283px' })
    expect(place(100, 200, 600, 500)).toEqual({ down: true, max: '383px' })
  })
})
