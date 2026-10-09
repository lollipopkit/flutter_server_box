import { describe, it, expect } from 'vitest'
import { commits, contentTakes, pageCurve, slide, COMMIT_FRACTION, FLING_VELOCITY } from '../desk/sys/pageMotion'

describe('page motion', () => {
  it("follows Flutter's fastEaseInToSlowEaseOut", () => {
    expect(pageCurve(0)).toBe(0)
    expect(pageCurve(1)).toBe(1)
    // The joint of its two cubics.
    expect(pageCurve(0.198)).toBeCloseTo(0.541, 2)
    // Fast early, slow late.
    expect(pageCurve(0.3)).toBeGreaterThan(0.75)
    for (let t = 0; t < 1; t += 0.05) expect(pageCurve(t + 0.05)).toBeGreaterThanOrEqual(pageCurve(t) - 1e-3)
  })

  it('slides the upper page over a full width and the lower a third', () => {
    expect(slide(0)).toEqual({ upper: 1, lower: -0 })
    expect(slide(1)).toEqual({ upper: 0, lower: -1 / 3 })
  })

  it('goes through past the threshold or on a fling that way', () => {
    expect(commits(COMMIT_FRACTION, 0, 1)).toBe(true)
    expect(commits(COMMIT_FRACTION - 0.01, 0, 1)).toBe(false)
    expect(commits(0.05, FLING_VELOCITY, 1)).toBe(true)
    expect(commits(0.9, -FLING_VELOCITY, 1)).toBe(false)
    expect(commits(0.05, -FLING_VELOCITY, -1)).toBe(true)
  })

  it('leaves a drag to fields, terminals and what handles its own pointer', () => {
    const page = document.createElement('div')
    page.innerHTML = '<input id="f"><div class="xterm"><span id="t"></span></div><div style="touch-action: none"><b id="h"></b></div><p id="p"></p>'
    document.body.append(page)
    expect(contentTakes(page.querySelector('#f'), page, 30, null)).toBe(true)
    expect(contentTakes(page.querySelector('#t'), page, 30, null)).toBe(true)
    expect(contentTakes(page.querySelector('#h'), page, 30, null)).toBe(true)
    expect(contentTakes(page.querySelector('#p'), page, 30, null)).toBe(false)
    page.remove()
  })
})
