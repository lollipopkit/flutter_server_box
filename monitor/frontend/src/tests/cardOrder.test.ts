import { describe, expect, it } from 'vitest'
import { moveAmongVisible } from '../lib/cardOrder'

describe('moveAmongVisible', () => {
  const order = ['cpu', 'gpu', 'memory', 'disk']
  const visible = ['cpu', 'memory', 'disk']

  it('trades places with the next shown card, keeping hidden slots', () => {
    expect(moveAmongVisible(order, visible, 'cpu', 1)).toEqual(['memory', 'gpu', 'cpu', 'disk'])
    expect(moveAmongVisible(order, visible, 'disk', -1)).toEqual(['cpu', 'gpu', 'disk', 'memory'])
  })

  it('leaves the order unchanged at either end', () => {
    expect(moveAmongVisible(order, visible, 'cpu', -1)).toEqual(order)
    expect(moveAmongVisible(order, visible, 'disk', 1)).toEqual(order)
  })
})
